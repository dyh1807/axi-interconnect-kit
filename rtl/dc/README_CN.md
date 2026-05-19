# AXI LLC DC 入口

本目录保存当前分支可复用的 Design Compiler 入口。目标是避免长综合时使用过期 RTL
列表或过期 SRAM 宏配置。

当前 1GHz setup 收敛状态、已 pass 的小 probe、正在运行的 DC 和未关闭的小模块列表
见 `current_setup_status_CN.md`。该文档的判断口径是：只有 final
`report_timing` / `report_qor` 显示 setup violating paths 为 0，才把对应对象标为
setup pass。

当前 thread goal 的逐项完成审计见 `goal_completion_audit_CN.md`。该文档把 LLC hit
精确对齐、bounded non-hit、RTL contracts、Linux sanity、DC source/liveness/macro
binding 和 full top postcompile setup signoff 映射到具体 artifact，避免用 proxy
信号误判完成。

当前推荐的只读检查入口：

- `dc_status_latest.txt`：由 `monitor_dc_status.sh` 单次刷新生成；每个 active run 都包含
  `SETUP_GATE`，可直接看到 `WAIT` / `PASS` / `FAIL`。该 gate 要求 final QoR 和对应
  final timing report 成对出现；只有 QoR 但 timing 尚未写出时仍保持 `WAIT`。若 timing
  report 已写出但没有可解析的 `slack (...)` 行，或包含 `slack (VIOLATED)`，则直接
  `FAIL`。该文件还包含 `NEXT_ACTION` 和 `LOG_HEALTH` 段，分别来自
  `decide_dc_next_action.sh` 与 `summarize_dc_log_health.sh`。低频自动检查优先使用
  `./schedule_dc_check_once.sh 1800 <tag>` 安排一次性 30 分钟延迟检查；长驻 loop 在
  共享服务器/会话切换时可能静默退出，不再作为唯一依赖。
- `./summarize_dc_reports.sh`：手动汇总当前 active DC marker，打印 final report 是否
  存在、QoR/timing 摘要、worst endpoint、final timing 路径类别、post-link 大
  mux/select 结构热点和 mapped output 清单。final timing 路径类别与
  `decide_dc_next_action.sh` 保持一致，用于第一轮定位 compat dispatch、write payload、
  response pool、bridge/hazard、refill-response 或 SRAM/store 相关违例。
- `./summarize_dc_log_health.sh`：只读汇总当前 active DC launcher log 的阶段进度、
  `Error` / `Fatal` / OOM 线索、warning code 计数和 `OPT-1206` 常量寄存器删除热点。
  该脚本用于区分“值得后续清理的 RTL hygiene 线索”和“当前不应中途改动的非 fatal
  综合器提示”，不作为 setup signoff 证据。
- `./check_goal_gate.sh`：手动执行当前目标的机器可检查 gate；只有 LLC hit、bounded
  non-hit、RTL contracts 和 DC setup 都通过时才会输出 `GOAL status=PASS`。其中 DC
  source freshness 会检查 active run 的 `rtl/src`、`rtl/include`、`rtl/flist`，
  以及 `run_metadata.txt` 中记录的 `SCRIPT=` 和 `rtl/dc/axi_llc_dc_common.tcl`，避免
  用旧 DC 脚本产物签核。`DC_LIBRARY_BINDING` 会检查所有 active run 的 `link.rpt`
  都链接 SMIC12 9T20 RVT/LVT，且没有链接 7p5t 标准单元库。DC setup 的最终签核只看 `.latest_full_compile_1g` 对应 full top 的
  `*postcompile_1g_qor.rpt` 和 `*postcompile_1g_timing.rpt`；quick-map run 是诊断入口，
  只用于提前暴露 endpoint，不作为 final signoff blocker。该脚本只能作为第一层审计入口；
  final DC endpoint 仍需要人工复核。若 DC 已退出但只写出 QoR、未写出对应 timing，
  `DC_RUN_LIVENESS` 会直接 FAIL，避免长期误判为等待。若 timing report 中出现
  `slack (VIOLATED)` 或缺少 slack 行，`DC_SETUP` 也会 FAIL，避免只凭 QoR proxy 通过。
- `./selftest_goal_gate_signoff.sh`：用临时 fake postcompile QoR / netlist / active marker
  测试 `check_goal_gate.sh` 的 final signoff 判定逻辑；不会调用 Synopsys 工具，也不会
  触碰正在运行的 DC。该脚本通过 `AXI_LLC_DC_ACTIVE_MARKERS` 和
  `AXI_LLC_DC_SIGNOFF_MARKER` 指向临时目录，因此不依赖真实 active DC run 的状态。
  它同时覆盖 `summarize_dc_reports.sh` 和 `monitor_dc_status.sh` 的 final QoR/timing
  成对判定，避免三套入口出现不一致。

## 当前目标

- 默认 top：`axi_llc_subsystem_dual`
- 默认 RTL：`rtl/flist/axi_llc_rtl.f`
- 默认 SRAM：
  - data：`4096x256 SASS`
  - meta：`4096x16 SASS`
- 默认标准单元：SMIC12 `9T20` (`SCC12NSFE_90SDB_9TC20_RVT/LVT_V1P0F`)。
  最终 1GHz/full DC signoff 必须使用 9T20 标准单元库；不要使用早期实验中的
  `SCC12NSFE_96SDB_7P5TC*` 7p5t 库作为收敛结论。
- 默认时钟：`1.0ns`
- 默认 `USE_SMIC12_STORES=1`，由 RTL parameter 默认值决定
- full compile 入口按组内模板 `/share/personal/S/chengshuyao/Qimeng_3_syn/dc_core.tcl`
  对齐：`create_clock -period 1`、I/O delay 为 0、`set_fix_multiple_port_nets
  -all -buffer_constant -feedthrough`、模板中的 `dont_use` 规则，以及
  `compile_ultra -retime`。当前脚本只应在 RTL/filelist、SMIC12 9T20+SRAM
  `.db` 路径和额外 QoR/输出报告上偏离该模板。
- 库语义按模板保持收敛：不显式加入额外 `synthetic_library`/DesignWare 库；
  `target_library` 只由 SMIC12 9T20 RVT/LVT 组成，`link_library` 由 9T20 RVT/LVT
  加当前实际 data/meta SRAM `.db` 组成。SRAM 是 hard macro，只参与 link/reference
  解析，不作为可映射的标准单元 target。

2026-05-06 复核 `/share/personal/S/chengshuyao/Qimeng_3_syn/dc_core.tcl` 后确认：
当前 full compile 入口与组内模板保持相同的关键综合策略，包括 `uniquify`、
`create_clock -period 1`、0 input/output delay、`set_fix_multiple_port_nets
-all -buffer_constant -feedthrough`、`SED/DEL/LANQ/CLK/PULL` `dont_use` 规则、
`compile_ultra -retime`、`change_names -rules verilog -hierarchy`、`set_svf -off`
以及 netlist/ddc/sdc/sdf/spf 输出。当前脚本的有意差异仅为：
使用本仓库 RTL/flist/top、使用 SMIC12 9T20 RVT/LVT 与实际 data/meta SRAM `.db`、
将 SRAM hard macro 作为 link-only 而非 target cell、去掉本子模块不需要的 IO/PLL
库映射、并额外保留 pre/post QoR、timing、area、constraint、power、check_design
等报告。

## 快速 link sanity

在 `eda-05`/`eda-09`/`eda-10` 等可用节点上运行。启动前先确认当前节点的 Synopsys
环境脚本和 `dc_shell` 可用，不要复用上一台服务器的假设。2026-05-06 探测结果：
`eda-10`/`eda-09`/`eda-05` 可以启动 `dc_shell`，其中 `eda-10` 当前负载最低、内存
充足，优先用于下一轮长 DC；`eda-05` 可用但负载很高且已有旧 DC 任务；
`eda-08` 当前 license vendor daemon 不可用，不应作为 DC 首选。

当前拆分 link sanity 证据：

- `axi_llc_axi_bridge_dual` 已通过 link sanity，日志
  `rtl/dc/runs/link_sanity_bridge_dual_current_20260504_222137.log`，CPU 约 `0.23h`。
- `axi_llc_subsystem_core` 已通过 link sanity，日志
  `rtl/dc/runs/link_sanity_core_current_20260505_230513.log`，CPU 约 `1.01h`。
- full top / strict-template probe 的未完成点均落在 building
  `axi_llc_subsystem_compat` 阶段；2026-05-06 live full DC 也仍停在该阶段但进程高 CPU
  活跃。因此若后续 full DC 被确认失败或无法接受地长时间无进展，下一步优先做
  `AXI_LLC_DC_TOP=axi_llc_subsystem_compat` 的限时 link sanity/compile 诊断，而不是
  直接重复 full top。
- 2026-05-06 对 `axi_llc_subsystem_compat` 做静态规模复核：在生产参数
  `NUM_READ_MASTERS=4`、`READ_RESP_QUEUE_DEPTH=32`、`READ_RESP_BITS=2048` 下，
  旧结构仅 `rd_resp_q_data` 就是 `4*32*2048=262144` bit 的寄存器阵列；compat 内部
  主要显式寄存器阵列合计约 `338338` bit，且组合逻辑中存在多个对
  `MAX_OUTSTANDING` / `RD_SLOT_COUNT` / `WR_SLOT_COUNT` / `RD_RESP_SLOT_COUNT`
  的扫描。因此 compat elaborate/compile 很慢可能是 RTL 结构规模问题，不只是
  SRAM macro 或库路径问题。若限时 compat link sanity 超时，优先评估 read-response
  payload queue 的存储方式、深度/宽度拆分和扫描结构，而不是只重复启动 full DC。
- 2026-05-06 19:42 CST 之后做了一项 conservative RTL hygiene：去掉
  `axi_llc_subsystem_compat` 中 invalid wide payload entries 的 reset/pop/free clear，
  保留 valid/head/tail/count reset 和所有有效 payload 写入。targeted C++ trace replay
  与全量 RTL contract 53/53 已通过。该轮已废弃的 compat link sanity 为
  `rtl/dc/runs/compat_link_sanity_payload_no_clear_9b05923_20260506_194526_eda10`；
  旧 full DC 和旧 compat sanity 启动早于该 RTL 修改，只能作为旧 RTL bottleneck 证据，
  不能作为该修改后的 signoff。
- 2026-05-06 19:53 CST 继续对 `axi_llc_axi_bridge` 做同类 conservative RTL hygiene：
  去掉 invalid pending/rsp slot 的 wide payload reset/free clear，但保留 read accept
  时 `rd_rdata_r` 清零以初始化 multi-beat read merge buffer。全量 RTL contract 53/53
  已通过，目录为
  `rtl/local_debug/vcs_all_contracts_bridge_payload_no_clear_20260506_195341_eda10`。
  因该修改发生在 `compat_link_sanity_payload_no_clear_9b05923_20260506_194526_eda10`
  启动之后，该 sanity 已被停止并 supersede；后续 current-HEAD sanity 需要基于
  compat+bridge 两处 hygiene 后的 RTL 重新启动。
- 2026-05-06 20:00 CST 继续对 `llc_cache_ctrl` MSHR 做同类 conservative RTL hygiene：
  去掉 invalid MSHR slot 的 victim/refill/write payload reset/free clear，保留
  MSHR valid/status/address/tag/way 等控制状态清零。全量 RTL contract 53/53 已通过，
  目录为 `rtl/local_debug/vcs_all_contracts_mshr_payload_no_clear_20260506_200052_eda10`。
  因该修改发生在 `compat_link_sanity_payload_hygiene_c6aba0a_20260506_195734_eda10`
  启动之后，该 sanity 已被停止并 supersede；后续 current-HEAD sanity 需要基于
  compat+bridge+MSHR 三处 hygiene 后的 RTL 重新启动。
- 2026-05-06 20:16 CST 继续对 `axi_llc_subsystem_compat` read response buffering
  做结构优化：per-master FIFO 只保留顺序和 pool index，2048-bit payload 改为
  `MAX_OUTSTANDING=32` 个共享 pool slot。read-response backing 从旧结构约
  `262656` bit 降至约 `66720` bit，减少约 `195936` bit。全量 RTL contract
  53/53 已通过，目录为
  `rtl/local_debug/vcs_all_contracts_resp_pool_idx_cleanup_20260506_202344_eda10`。
  DC elaborate 早期暴露的新增 pool-index signedness warning 已通过 8-bit pool index
  类型 cleanup 消除。该修改 supersede 此前所有 compat link sanity；下一轮 sanity/DC
  必须基于包含 response-pool 和 signedness cleanup 的 current HEAD 启动。
- 2026-05-06 20:45 CST 的 compat link sanity OOM 不是 valid/repl regfile 必然导致
  的单进程极限。`dmesg -T` 显示该事件是 `global_oom`，OOM killer 记录中同时存在大量
  其它用户的 `simulator` 进程，单个 RSS 为数 GB 量级；被杀的 `common_shell_ex`
  当时 `anon-rss` 约 `35150324 kB`。因此直接触发因素是全机内存压力。不过该日志也
  说明旧 RTL 在 `llc_cache_ctrl` elaborate 前内存已升至 35GB 量级，仍应降低组合展开
  复杂度以减少被共享服务器挤掉的风险。
- 2026-05-06 21:17 CST 当前 RTL 上的
  `AXI_LLC_DC_TOP=axi_llc_subsystem_compat` link sanity 已通过，目录为
  `rtl/dc/runs/compat_link_sanity_cache_helper_slim_wip_20260506_205627_eda10`，
  使用 SMIC12 9T20 RVT/LVT 标准单元与 data/meta SRAM `.db`，`LINK_SANITY_PASS`，
  `Memory usage for this session 9351 Mbytes`，CPU `0.42h`。该 run 证明
  data/meta macro link 正常，`valid_mem_reg`/`repl_mem_reg` 仍按预期保持 regfile。
- 2026-05-06 21:32 CST 为避免新增 signedness 噪声，对 `llc_cache_ctrl` 的
  `merge_line` 和 `extract_read_response` 保持单层循环但使用无符号 `reg [31:0]`
  loop/index 变量。全量 RTL contract 53/53 已通过，目录为
  `rtl/local_debug/vcs_all_contracts_cache_helper_slim_unsigned_20260506_212255_eda10`；
  `AXI_LLC_DC_TOP=llc_cache_ctrl` link sanity 也已通过，目录为
  `rtl/dc/runs/cache_ctrl_link_sanity_helper_slim_unsigned_wip_20260506_212515_eda10`，
  `LINK_SANITY_PASS`，`Memory usage for this session 6567 Mbytes`，CPU `0.14h`，
  且未再出现该文件新增的 signedness warning。
- 2026-05-06 21:45 CST 停止 `eda-07` 上旧的
  `rtl/dc/runs/full_compile_1g_9t20_622b6e4_20260506_104636_eda07`。该 run 基于旧
  `622b6e4`，console log 最后更新时间停在 10:47 CST，只到 `elaborate_start` /
  building `axi_llc_subsystem_compat`，已跑近 11 小时且不能代表当前 RTL。
  随后在 `eda-07` 重新启动当前 `c98464a` clean full DC，run root 为
  `rtl/dc/runs/full_compile_1g_strict_template_9t20_c98464a_20260506_2147_eda07`，
  launcher PID `2692139`，DC PID `2692359`。早期日志已完成 9T20 RVT/LVT、
  data/meta SRAM `.db` 加载和 42 个 RTL analyze，进入 `elaborate_start` /
  building `axi_llc_subsystem_compat`；该 run 已在 21:51 CST 停止，因为 `eda-07`
  可用内存快速降到约 17GiB 且 swap 已满，主要由其它用户 simulator 进程占用。
  停止前尚无 compile/QoR/timing/netlist 结果。
- 2026-05-06 21:53 CST 在 `eda-09` 启动当前 `5274f9d` clean full DC，run root 为
  `rtl/dc/runs/full_compile_1g_strict_template_9t20_5274f9d_20260506_2154_eda09`，
  launcher PID `3230090`，DC PID `3230092`。启动时 `eda-09` 约有 `588GiB`
  available memory，无正在运行的我方 DC；早期日志已完成 data/meta SRAM `.db`
  读取并进入 RTL analyze，当前尚无 compile/QoR/timing/netlist 结果。
- 2026-05-06 23:26 CST 复查该 `eda-09` run：`elaborate_done` 已在 22:32 CST 完成，
  link sanity 通过，post-link DDC 已写出；进程仍在运行，RSS 约 `88.9GB`，`eda-09`
  available memory 约 `502GiB`。当前已有 precompile QoR report，但尚无 postcompile
  QoR/timing/area/netlist signoff 产物。
- 2026-05-07 00:05 CST 复查该 `eda-09` run：进程仍在运行，DC PID `3230092`
  CPU 约 `99%`，RSS 约 `95.0GB`，`eda-09` available memory 约 `498GiB`。
  `compile_start` 已在 00:01:53 CST 出现，当前正在执行
  `compile_ultra -retime`；新增 precompile timing report
  `reports/axi_llc_subsystem_dual_timing_precompile.rpt`。尚无 postcompile
  QoR/timing/area/netlist signoff 产物，因此不能标记 DC/timing 完成。
  precompile QoR/timing 当前只作为参考：setup WNS/TNS 为 `0.00/0.00`，最差
  setup path 是 data SRAM Q 到 `llc_data_store_smic12` read-row capture，slack
  约 `+0.33ns`；hold 仍有大量违例，当前 top 尚未完整建 CTS/IO/pad，不能据此做
  signoff 结论。
- 2026-05-07 16:01 CST 复查该 `eda-09` run：进程仍在运行，elapsed 约 `18h07m`，
  RSS 约 `95.4GB`，`eda-09` available memory 约 `896GiB`；已进入
  `Beginning Delay Optimization` / `Beginning WLM Backend Optimization` 后续阶段。
  `compile_ultra` 内部第一张优化表曾出现 `WORST NEG SLACK` / `SETUP COST`
  为 `1e13` / `1e17` 量级的异常 transient 数字，但随后同一轮表格恢复到正常量级。
  注意该列不是普通正 slack；`WORST NEG SLACK` 当前约 `4.63` 应先按 WNS violation
  magnitude 解读，即约 `-4.63ns` 级 setup 违例。当前仍需等待 postcompile
  `report_qor` / `report_timing` 给出准确 endpoint，但不应把该 `4.63` 解读成
  `+4.63ns` 余量。
  该 run 的 DC 压力主要来自综合规模和可优化常量结构：当前 console 中约有 `118k`
  条 constant/register removal，其中最大来源是 dual bridge 的宽 response queue，
  例如 `bridge/mmio_bridge/cache_rd_rsp_data_r_reg[][]` 约 `65k` 条、
  `bridge/ddr_bridge/cache_rd_rsp_data_r_reg[][]` 约 `49k` 条。这会拖慢 compile
  并放大中间 cost；若最终 timing/area 仍不可接受，后续应优先考虑把 DDR/MMIO
  bridge 的 cache/bypass response queue 做结构化参数裁剪，并审视 32-entry
  pending scan / 2048-bit mux，而不是仅重复重启 DC。
- 2026-05-07 16:35 CST 根据上述 WNS 口径先做了一处低风险 RTL 裁剪：
  `axi_llc_axi_bridge_dual` 中 MMIO bridge 内部改为
  `READ_RESP_BYTES=4` / `READ_RESP_BITS=32`，再在 dual wrapper 出口零扩展回全局
  response 宽度。该修改符合 MMIO 只支持 32-bit / 1-beat 的接口约束，可避免 MMIO
  bridge 内部生成 32-entry x 2048-bit read response 存储和 mux。验证结果：
  dual AXI targeted contracts `4/4` 通过，全量 RTL contracts `53/53` 通过，
  `AXI_LLC_DC_TOP=axi_llc_axi_bridge_dual` 的 DC link sanity 通过，目录为
  `rtl/dc/runs/bridge_dual_link_sanity_mmio_width_20260507_162715_eda05`。
	  注意当前 `eda-09` 上的 full DC 已在该 RTL 修改前完成 analyze/elaborate，因此它
	  只能作为旧结构 timing baseline；若要验证该优化对 WNS 的影响，需要使用新 RTL
	  重跑 bridge-only / full-top DC。当前已在 `eda-05` 启动新的 bridge-only 1GHz probe，
	  最新目录记录在 `rtl/dc/runs/.latest_bridge_dual_mmio_width_compile`。
- 2026-05-07 17:26 CST 复查当前 run：`eda-09` full-top DC 仍在跑，DC PID `3230092`
  elapsed 约 `19h29m`，RSS 约 `95.4GB`；`compile_start` 到现在约 `17h25m`。
  console 最新可见中间优化表仍显示 `WORST NEG SLACK` 约 `4.40`、`SETUP COST`
  约 `8.77e5`，尚无 postcompile QoR/timing/area/netlist 产物。按当前斜率判断，
  该 full-top run 不应作为唯一等待路径：若最终可收敛，预计仍至少是十小时量级；
  若继续卡在多 ns WNS，可能运行数十小时也不给出有效 signoff。
- 同时在 `eda-05` 运行三条新 RTL 的快速隔离 DC：`axi_llc_axi_bridge_dual`
  run root 为
  `rtl/dc/runs/bridge_dual_fast_compile_mmio_width_9t20_20260507_165504_eda05`，
  1h timeout，17:08 CST 进入 compile；`axi_llc_subsystem_compat` run root 为
  `rtl/dc/runs/compat_fast_compile_9t20_20260507_171542_eda05`，2h timeout，
  当前仍在 elaborate；补充启动的 `axi_llc_subsystem_core` run root 为
  `rtl/dc/runs/core_fast_compile_9t20_20260507_172525_eda05`，90min timeout，
  已完成 analyze 并进入 elaborate。三者使用同一套 9T20 RVT/LVT + data/meta SRAM
  `.db`，用于判断 bridge、compat、core/cache_ctrl 中哪一块仍是 1GHz 主瓶颈。
- 2026-05-07 17:38 CST 又补充一条更小的 `llc_cache_ctrl` standalone fast DC，
  run root 为
  `rtl/dc/runs/cache_ctrl_fast_compile_9t20_20260507_173754_eda05`，45min timeout。
  该 run 主要用于绕开 full core 中 valid/repl regfile 和 SRAM wrapper 规模，快速判断
  cache controller 组合控制路径本身是否已经接近 1GHz。它不能替代 full-top signoff，
  但若该 run 都出现多 ns setup 违例，就应优先修改 controller/lookup/response 逻辑，
  而不是继续等待 full-top 自动修复。
- 2026-05-07 17:42 CST 根据 full-top compile log 中的 `DW01_ash_A_width2048`
  迹象，清理了 `axi_llc_axi_read_pack` / `axi_llc_axi_write_pack` 的按字节 pack/unpack
  实现：从超宽动态移位改为 indexed part-select。该修改不改变协议或 cycle 语义，
  RTL 全量 contracts `53/53` 通过，LLC hit-only performance contract 仍为
  `ready=0/resp=7/no external`。注意 17:08 启动的 bridge fast DC 和 eda-09 full-top
  DC 都是在该修改前 analyze 的，不能反映这一 cleanup；旧 bridge run 释放后应启动
  新的 bridge fast DC 验证 mapped timing 是否改善。
- 若 `compile_ultra -retime` 的 fast run 在 timeout 前不给 report，可用
  `rtl/dc/run_dual_quick_map_1g.tcl` 做低 effort mapped timing probe。该入口使用同一套
  flist、9T20 cell rule、SRAM `.db` 和 1GHz constraint，但只执行
  `compile -map_effort medium`，目的是快速生成 `report_timing/report_qor` 用于比较
  RTL cleanup 的方向性收益；它不是 signoff，也不能替代 full compile。
- 2026-05-07 17:57 CST 旧 `bridge_dual_fast_compile_mmio_width_...165504_eda05`
  在 1h timeout 后被 kill，未生成 postcompile timing/QoR；已改用新 RTL 启动
  bridge quick-map，run root 为
  `rtl/dc/runs/bridge_dual_quick_map_read_pack_cleanup_9t20_20260507_175718_eda05`。
- 2026-05-07 18:00 CST 复查 `eda-09` full-top 旧 RTL run：进程仍在跑，elapsed
  约 `20h07m`，RSS 约 `95.4GB`。console 中间优化表在 17:34-17:38 出现明显改善，
  `WORST NEG SLACK` violation magnitude 从约 `4.40` 降到约 `2.42`，`SETUP COST`
  从约 `8.97e5` 降到约 `7.40e5`。因此该旧 full-top baseline 仍有继续观察价值，
  但它不包含 17:42 后的 read/write pack cleanup，不能代表当前 RTL 的最终结果。
- 2026-05-07 19:48-20:38 CST 完成多组小 probe：DDR64 pack probe、MMIO4 pack probe、
  32-entry/64-entry hazard scoreboard probe 均在 1GHz quick-map 下无 setup violating
  paths；其中 hazard scoreboard 32/64 的 setup WNS 均为 `0.00`，面积分别约
  `7248` / `14631`。这些 probe 说明 pack datapath 和 scoreboard 本身不是明显的
  多 ns setup blocker，但 margin 很小，仍不能替代集成 bridge/cache_ctrl timing。
- 2026-05-07 22:12 CST 第一条新 RTL `axi_llc_axi_bridge_dual` quick-map
  `rtl/dc/runs/bridge_dual_quick_map_hazard32_9t20_20260507_204253_eda-05`
  因 5400s timeout 结束，未生成最终 timing/QoR report。console 中间表显示
  WNS violation magnitude 从约 `6.4ns` 级降到 `0.42`，setup cost 约 `4.98e4`，
  因此 bridge 很可能接近但尚未证明 1GHz setup pass。已在 22:14 CST 启动 4h
  long quick-map：
  `rtl/dc/runs/bridge_dual_quick_map_hazard32_long_9t20_20260507_221445_eda-05`。
  22:32 CST 复查时该 run 已完成 link sanity，进入 `compile -map_effort medium`
  mapping pass。
- 2026-05-07 22:00 CST 启动的 grouped-MSHR `llc_cache_ctrl` quick-map 最初误用了
  full RTL flist，运行 30+ 分钟仍停在 elaborate 前端，因此已停止并改用
  `rtl/dc/probes/cache_ctrl_only.f` 只分析 `src/llc_cache_ctrl.v`。新的 run 为
  `rtl/dc/runs/cache_ctrl_only_quick_map_grouped_mshr_9t20_20260507_2234_eda-05`，
  22:36 CST 启动，使用同一 9T20 + SMIC12 SRAM `.db`，目标是快速得到
  grouped-MSHR 后 controller 本体的 1GHz quick-map timing。
- 2026-05-07 22:32 CST 复查 `eda-09` 旧 full-top baseline：
  `rtl/dc/runs/full_compile_1g_strict_template_9t20_5274f9d_20260506_2154_eda09`
  仍在运行，DC PID `3230092`，elapsed 约 `24h39m`，RSS 约 `95.4GB`。最新中间表
  WNS violation magnitude 约 `2.28`，setup cost 约 `1.05e6`，改善很慢；该 run
  仍只作为旧 RTL baseline，不代表 grouped-MSHR、read/write pack cleanup 或最新
  perf-contract 文档变更后的当前 RTL signoff。
- 2026-05-07 22:47 CST 复查当前有效状态：`bridge_dual` long quick-map 和
  `cache_ctrl_only` quick-map 的 `common_shell_exec` 子进程都在 `eda-05` 上以约
  `99%` CPU 运行，不是死等。`bridge_dual` run 已完成 post-link reports，并在
  22:27 CST 进入 `compile -map_effort medium` 的 mapping pass，尚无最终
  timing/QoR；`cache_ctrl_only` run 已完成 SRAM/9T20 `.db` 读取和 analyze，22:38 CST
  进入 elaborate，尚无 reports。旧 full-top baseline console 仍在更新，但没有新的
  postcompile report；它继续只能作为旧 RTL setup 收敛趋势参考。
- 同一时点的 performance contract 状态：LLC hit read64 已精确对齐
  `ready=0/resp=7/no external`；MODE_CACHE clean read miss/refill 已直接量测，C++
  事件为 `AR=5/R0=7/R1=8/resp=14`，RTL 为 `AR=9/R0=11/R1=12/resp=21`，最大额外
  延迟 `+7`，在 miss 专用 `<=8 cycle` gate 内；direct DDR/MMIO 和 overlap 当前最大
  额外延迟 `+5`，在 `<=6 cycle` gate 内。因此短期工作重心应继续放在
  bridge/cache_ctrl/top setup 收敛，而不是重复 LLC hit performance 调试。
- 后续 DC gate：当前不需要立刻启动新的 full_top 长跑，应先把 `bridge_dual`、
  `cache_ctrl`/`core`、`compat` 等拆分小模块的 1GHz setup quick-map/fast compile
  收敛清楚；一旦这些小模块都确认 setup 可收敛，必须再基于同一版 current RTL 启动
  新的 `axi_llc_subsystem_dual` full_top 1GHz DC。当前正在跑的旧 full_top baseline
  启动早于后续 RTL cleanup，只能用于趋势判断，不能替代该最终 full_top gate；该
  full_top 补跑虽然不是当前动作，但属于后续 signoff 必做项。
- 2026-05-07 23:04 CST 继续清理 bridge pack 逻辑：`axi_llc_axi_read_pack` 和
  `axi_llc_axi_write_pack` 中剩余的 mode2/data beat 动态 shift 已改为按字节
  indexed copy，避免 DC 推断宽 barrel shifter。该修改不改变 cycle 语义；验证结果：
  LLC hit-only perf contract 通过
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_no_shift_20260507_2306_eda-05`，
  bounded perf contract 通过
  `rtl/local_debug/vcs_cpp_perf_contract_no_shift_20260507_2307_eda-05`，全量 RTL
  contracts 通过 `53/53`
  `rtl/local_debug/vcs_all_contracts_no_shift_20260507_2308_eda-05`。因此 22:14 CST
  启动的 `bridge_dual_quick_map_hazard32_long_...` 已被停止，exit code 为 `1`，只作为
  旧 RTL/stale run；新的 current-RTL bridge quick-map 为
  `rtl/dc/runs/bridge_dual_quick_map_no_shift_9t20_20260507_2318_eda-05`。
- 2026-05-07 23:37 CST，旧的 `cache_ctrl_only_quick_map_grouped_mshr_...2234_eda-05`
  到 1h timeout，exit code 为 `124`，仍停留在 elaborate 阶段，没有 timing/QoR report。
  这说明 `llc_cache_ctrl` 本体的前端展开仍偏重。随后对 `llc_cache_ctrl` 的
  `extract_line`、`extract_meta`、`place_line_in_row`、`place_meta_in_row` 和
  `way_onehot` 做语义等价 cleanup：从显式 `WAY_COUNT` 循环改为 indexed
  part-select/bit-select，以减少嵌套循环展开规模。验证结果：LLC hit-only perf
  contract 通过
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_indexed_way_20260507_2340_eda-05`，
  bounded perf contract 通过
  `rtl/local_debug/vcs_cpp_perf_contract_indexed_way_20260507_2341_eda-05`，全量 RTL
  contracts 通过 `53/53`
  `rtl/local_debug/vcs_all_contracts_indexed_way_20260507_2342_eda-05`。新的
  current-RTL cache_ctrl-only quick-map 为
  `rtl/dc/runs/cache_ctrl_only_quick_map_indexed_way_9t20_20260507_2356_eda-05`。
- 2026-05-08 00:32 CST，`cache_ctrl_only_quick_map_indexed_way_...2356_eda-05`
  运行约 39 分钟后仍未越过 elaborate，console 停在 `elaborate_start` 后，RSS 已到
  约 `5.6GB`，因此停止为 stale run，exit code 为 `1`。继续做一处不改 cycle 的
  cleanup：去掉 `llc_cache_ctrl` 中 `mshr_commit_group_*` / `mshr_issue_group_*`
  staging payload 的 reset，以及无效期 `mshr_commit_refill_line_payload_r`、
  `mshr_issue_req_wdata_r`、`mshr_refill_line_r` 的宽清零。验证结果：LLC hit-only
  perf contract 通过
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_mshr_group_no_reset_20260508_0035_eda-05`，
  bounded perf contract 通过
  `rtl/local_debug/vcs_cpp_perf_contract_mshr_group_no_reset_20260508_0036_eda-05`，全量
  RTL contracts 通过 `53/53`
  `rtl/local_debug/vcs_all_contracts_mshr_group_no_reset_20260508_0037_eda-05`。新的
  current-RTL cache_ctrl-only quick-map 为
  `rtl/dc/runs/cache_ctrl_only_quick_map_mshr_group_no_reset_9t20_20260508_0050_eda-05`。
- 2026-05-08 01:45 CST，上述 `cache_ctrl_only_quick_map_mshr_group_no_reset...`
  因后续 RTL cleanup 已变成 stale run，已停止并写入 `exit_code=1`。继续做一处
  不改 cycle 的 `llc_cache_ctrl` cleanup：`mem_resp_id` 匹配 MSHR 从 32-entry
  组合扫描改为 range-guarded direct slot lookup，并把同 cacheline hazard 比较改为
  高位 line key 比较；range guard 使用嵌套 `if`，避免 out-of-range ID 在同一条件
  表达式中索引 MSHR 数组。验证结果：LLC hit-only perf contract 通过
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_mshr_direct_resp_guard_20260508_0145_eda-05`，
  bounded perf contract 通过
  `rtl/local_debug/vcs_cpp_perf_contract_mshr_direct_resp_guard_20260508_0145_eda-05`，全量
  RTL contracts 通过 `53/53`
  `rtl/local_debug/vcs_all_contracts_mshr_direct_resp_guard_20260508_0145_eda-05`。中间
  `cache_ctrl_only_quick_map_mshr_direct_resp_fix_...0138_eda-05` 也因嵌套 guard
  cleanup 发生在启动后而被停止为 stale run，`exit_code=1`。新的
  current-RTL cache_ctrl-only quick-map 为
  `rtl/dc/runs/cache_ctrl_only_quick_map_mshr_direct_resp_guard_9t20_20260508_0156_eda-05`。
- 2026-05-08 03:05 CST，`cache_ctrl_only_quick_map_mshr_direct_resp_guard...0156_eda-05`
  已被 `timeout 3600` 终止，console 只到 `elaborate_start`，随后出现
  `Received Signal 15` / `Process terminated by kill`，没有 `elaborate_done`、
  timing 或 QoR report；该 run 目录也未写出 `exit_code.txt`。结论不是 setup 已
  失败，而是当前 `llc_cache_ctrl` 形态仍使 DC 前端展开过慢，后续需要继续做结构化
  cleanup 或拆分后再重跑 small-module quick-map。`bridge_dual_quick_map_no_shift...2318_eda-05`
  同一时点仍在 `Beginning Mapping Optimizations (Medium effort)` 后运行，尚无最终
  timing/QoR report。
- full_top 后置要求再次确认：只有当 `bridge_dual`、`cache_ctrl`/`core`、`compat`
  等拆分小模块的 1GHz setup 都已经收敛或至少给出可信的 setup-pass 小模块证据后，
  才启动新的同版 current RTL `axi_llc_subsystem_dual` full_top 1GHz DC；这个动作
  当前不必要，但后续 signoff 必须补做，不能用任何旧 RTL full_top baseline 替代。
  用户已再次明确：小模块 setup 收敛后，新增 full_top 不是可选优化，而是必须执行的
  最终集成时序 gate。
- 2026-05-08 03:19 CST，`bridge_dual_quick_map_no_shift...2318_eda-05` 到
  `timeout 14400`，`exit_code=124`。该 run 已完成 analyze/elaborate/link 和
  post-link reports，但停在 `Beginning Mapping Optimizations (Medium effort)` 后，
  没有最终 timing/QoR report；结论是 `bridge_dual` 当前可 link，但 mapping 阶段仍过慢，
  还不能证明 setup 收敛。
- 2026-05-08 03:26 CST，撤掉此前让 `llc_cache_ctrl` elaborate 变慢的
  `mshr_commit_group_*` / `mshr_issue_group_*` staging，恢复直接 MSHR slot 访问；
  保留 `mem_resp_id` direct lookup、line-key hazard compare 和 invalid payload
  不清零。验证结果：LLC hit-only perf contract 通过
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_mshr_direct_no_group_20260508_0311_eda-05`，
  bounded perf contract 通过
  `rtl/local_debug/vcs_cpp_perf_contract_mshr_direct_no_group_20260508_0312_eda-05`，全量
  RTL contracts 通过 `53/53`
  `rtl/local_debug/vcs_all_contracts_mshr_direct_no_group_20260508_0313_eda-05`。新的
  current-RTL cache_ctrl-only quick-map 已启动：
  `rtl/dc/runs/cache_ctrl_only_quick_map_mshr_direct_no_group_9t20_20260508_0326_eda-05`。
- 2026-05-08 03:34 CST，针对 `bridge_dual` mapping 过慢继续做一处等价裁剪：
  MMIO 子 bridge 只允许 4B/1-beat，因此不再以 `LINE_BITS=512/LINE_BYTES=64`
  实例化 generic bridge，而是用 `LINE_BITS=32/LINE_BYTES=4` 并只接低 32-bit data /
  4-bit strobe。该修改减少 MMIO bridge 内部 32-entry pending/write payload 队列宽度，
  不改变合法 MMIO 事务语义。验证结果：LLC hit-only perf contract 通过
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_mmio_slim_20260508_0332_eda-05`，
  bounded perf contract 通过
  `rtl/local_debug/vcs_cpp_perf_contract_mmio_slim_20260508_0333_eda-05`，全量 RTL
  contracts 通过 `53/53`
  `rtl/local_debug/vcs_all_contracts_mmio_slim_20260508_0334_eda-05`。需要基于该
  current RTL 重跑 `bridge_dual` quick-map；03:26 的 cache_ctrl-only run 不受该
  bridge 文件修改影响。为避免 bridge probe 被无关 top 文件污染，新增
  `rtl/dc/probes/bridge_dual_only.f`，只包含 `axi_llc_axi_bridge_dual` 及其 helper
  依赖；新的 bridge current-RTL quick-map 已启动：
  `rtl/dc/runs/bridge_dual_quick_map_mmio_slim_9t20_20260508_0346_eda-05`。
- 2026-05-08 07:39 CST，`bridge_dual_quick_map_mmio_slim...0346_eda-05` 已越过
  analyze/elaborate/link 并进入 medium mapping，但 3h37m 后中间优化表仍显示
  `WORST NEG SLACK` 约 `6.4ns`，随后 4h timeout 被杀掉，没有最终 timing/QoR report。
  基于该反馈，继续做一处语义等价的 bridge cleanup：`axi_llc_axi_bridge` 在 read/write
  slot 完成释放时只清 `valid` / issue-done / complete 等控制位，不再对已无效 slot 的
  地址、ID、size、beat count 等小字段做动态索引清零。这些 payload 只在 `valid` 或
  complete gate 下使用，保持 stale payload 不改变可观察协议语义，但可减少 32-entry
  表的写入 mux。验证结果：LLC hit-only perf contract 通过
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_bridge_slot_free_cleanup_20260508_073937_eda-05`，
  bounded perf contract 通过
  `rtl/local_debug/vcs_cpp_perf_contract_bridge_slot_free_cleanup_20260508_074023_eda-05`，
  全量 RTL contracts 通过 `53/53`
  `rtl/local_debug/vcs_all_contracts_bridge_slot_free_cleanup_20260508_074104_eda-05`。
  旧 bridge low probe 因 RTL 已变为 stale 已停止；新的 current-RTL bridge low-effort
  诊断 run 已启动：
  `rtl/dc/runs/bridge_dual_quick_map_low_slot_free_cleanup_9t20_20260508_0755_eda-05`。
  注意：Synopsys O-2018.06-SP1 会提示 `compile -map_effort low` 已废弃并按 medium
  处理，因此该入口是“诊断 quick-map”而不是真正低努力度 compile；不能据此预期显著
  短于 medium run。为定位 bridge 侧 6ns 量级 setup 压力，新增两个 DC-only 单桥 probe：
  `rtl/dc/probes/axi_llc_axi_bridge_ddr64_probe.v` /
  `rtl/dc/probes/axi_llc_axi_bridge_mmio4_probe.v`，分别实例化实际 DDR64/256-bit
  single bridge 和 MMIO4/32-bit single bridge；对应 flist 为
  `rtl/dc/probes/bridge_ddr64_probe.f` /
  `rtl/dc/probes/bridge_mmio4_probe.f`，当前诊断 run 已启动。
- 2026-05-08 03:56 CST，针对 `llc_cache_ctrl` DC 前端展开继续做一处语义等价
  cleanup：将 MSHR 的 1-bit 状态表从 unpacked reg array 改为 packed bit-vector，
  保留地址/数据等多 bit payload 数组不变。该修改不改变任意 slot 的读写语义，也不
  改变 LLC hit cycle。验证结果：LLC hit-only perf contract 通过
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_mshr_flags_packed_20260508_035620_eda-05`，
  仍为 `ready=0/resp=7/no external`；bounded perf contract 通过
  `rtl/local_debug/vcs_cpp_perf_contract_mshr_flags_packed_20260508_035655_eda-05`，
  clean read miss/refill 仍为 `+2` cycle，direct/overlap 最大额外延迟仍为 `+5`；
  全量 RTL contracts 通过 `53/53`
  `rtl/local_debug/vcs_all_contracts_mshr_flags_packed_20260508_035850_eda-05`。
  原 03:26 cache_ctrl quick-map 在该 RTL 修改后已是 stale run；新的 current-RTL
  cache_ctrl-only quick-map 已启动：
  `rtl/dc/runs/cache_ctrl_only_quick_map_mshr_flags_packed_9t20_20260508_0358_eda-05`。
  04:12 CST 复查时该 run 已完成 analyze，并停在 `elaborate_start` 后等待；同一时点
  bridge MMIO slim quick-map 已完成 elaborate/link，正在 `Beginning Pass 1 Mapping`。
- 2026-05-08 04:23 CST，继续把 `llc_cache_ctrl` 中剩余 MSHR 多 bit payload 表
  从 unpacked reg array 改为 flat packed vector，并通过 slice macro 保持实际生产 RTL
  使用同一份存储语义。该修改仍不改变 MSHR slot 语义或 LLC hit cycle。验证结果：
  LLC hit-only perf contract 通过
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_mshr_flat_packed_20260508_042114_eda-05`，
  仍为 `ready=0/resp=7/no external`；bounded perf contract 通过
  `rtl/local_debug/vcs_cpp_perf_contract_mshr_flat_packed_20260508_042150_eda-05`，
  clean read miss/refill 仍为 `+2` cycle，direct/overlap 最大额外延迟仍为 `+5`；
  全量 RTL contracts 通过 `53/53`
  `rtl/local_debug/vcs_all_contracts_mshr_flat_packed_20260508_042325_eda-05`。此前
  `mshr_flags_packed` cache_ctrl-only quick-map 在该 RTL 修改后已是 stale run；新的
  current-RTL cache_ctrl-only quick-map 为
  `rtl/dc/runs/cache_ctrl_only_quick_map_mshr_flat_packed_9t20_20260508_0423_eda-05`。
  04:38 CST 复查时该 run 已完成 analyze，仍在 `elaborate_start` 后等待；bridge
  MMIO slim quick-map 仍在 mapping pass。若 flat packed 版本仍长期无法越过
  elaborate/link，应继续将 MSHR hazard/issue/commit scan 抽成可综合 helper 层级，
  但必须继续使用实际 production RTL，而不是 test-only 片段。
- 2026-05-08 04:44 CST，`mshr_flat_packed` cache_ctrl-only quick-map 在
  `elaborate_start` 后约 20 分钟仍无新阶段且 RSS 继续增长，因此主动终止该 stale run。
  随后将 `llc_cache_ctrl` 中的 MSHR pending/victim hazard scan、issue/commit priority
  scan、write-hit victim update mask 拆成生产 RTL helper：
  `llc_mshr_pending_scan`、`llc_mshr_select_scan`、`llc_mshr_write_hit_scan`。MSHR
  状态寄存器仍完全由 `llc_cache_ctrl` 持有，helper 只消费 packed snapshot 并输出组合
  结果，不是 test-only 片段。验证结果：LLC hit-only perf contract 通过
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_mshr_helper_scan_20260508_0448_eda-05`，
  bounded perf contract 通过
  `rtl/local_debug/vcs_cpp_perf_contract_mshr_helper_scan_20260508_0450_eda-05`，全量 RTL
  contracts 通过 `53/53`
  `rtl/local_debug/vcs_all_contracts_mshr_helper_scan_20260508_0450_eda-05`。新的
  current-RTL cache_ctrl-only quick-map 已启动：
  `rtl/dc/runs/cache_ctrl_only_quick_map_mshr_helper_scan_9t20_20260508_0503_eda-05`。
  05:06 CST 复查时该 run 已完成 analyze，刚进入 `elaborate_start`；仍需继续观察是否
  能越过 elaborate/link 并产出 timing/QoR。
- 2026-05-08 05:14 CST，`mshr_helper_scan` run 在 `elaborate_start` 后仍无新阶段，
  因后续 RTL 清理而终止为 stale run。新增低风险组合复用：写命中路径先计算一次
  `write_hit_merged_line_w = merge_line(...)`，`install_line_r` 与所有需要 snapshot 的
  MSHR victim entry 共用该结果，避免在 32-entry MSHR 更新循环里重复展开同一个
  `merge_line()`。验证结果：LLC hit-only perf contract 通过
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_mshr_helper_merge_reuse_20260508_0514_eda-05`，
  bounded perf contract 通过
  `rtl/local_debug/vcs_cpp_perf_contract_mshr_helper_merge_reuse_20260508_0514_eda-05`，
  全量 RTL contracts 通过 `53/53`
  `rtl/local_debug/vcs_all_contracts_mshr_helper_merge_reuse_20260508_0515_eda-05`。新的
  current-RTL cache_ctrl-only quick-map 已启动：
  `rtl/dc/runs/cache_ctrl_only_quick_map_mshr_helper_merge_reuse_9t20_20260508_0528_eda-05`。
  05:56 CST 复查时该 run 已完成 analyze，但 `elaborate_start` 后约 25 分钟仍未
  `elaborate_done`，已经慢于历史上可 link 的 cache_ctrl run 约 22-24 分钟窗口；因此
  该清理仍不足以证明 DC 前端收敛。若该 run 后续不能自行越过 elaborate，下一步应把
  MSHR 状态本体迁入独立 production 子模块，而不是继续做零散表达式 cleanup。
- 2026-05-08 06:00 CST，根据历史 run 对照，cache_ctrl 前端变慢的第一个明显拐点是
  `indexed_way` cleanup：`extract_line`、`extract_meta`、`place_line_in_row`、
  `place_meta_in_row`、`way_onehot` 从显式 `WAY_COUNT` 循环改成 variable indexed
  part-select/bit-select 后，后续 cache_ctrl-only run 开始长期停在 elaborate。当前已将
  这些 helper 回退为显式循环形式，保留 MSHR helper/merge-reuse 修改。验证结果：
  LLC hit-only perf contract 通过
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_mshr_helper_loop_way_20260508_0600_eda-05`，
  bounded perf contract 通过
  `rtl/local_debug/vcs_cpp_perf_contract_mshr_helper_loop_way_20260508_0601_eda-05`，全量
  RTL contracts 通过 `53/53`
  `rtl/local_debug/vcs_all_contracts_mshr_helper_loop_way_20260508_0601_eda-05`。新的
  current-RTL cache_ctrl-only quick-map 已启动：
  `rtl/dc/runs/cache_ctrl_only_quick_map_mshr_helper_loop_way_9t20_20260508_0614_eda-05`。
  06:19 CST 复查时该 run 已完成 analyze，刚进入 `elaborate_start`，需继续等到历史
  22-24 分钟窗口后再判断。06:53 CST 该 run 完成 elaborate/link，证明回退
  variable indexed part-select 后 DC 前端可继续推进；但 07:17 CST 该 run 在
  `compile -map_effort medium` 的 `Processing llc_cache_ctrl` 阶段被 1h timeout 杀掉，
  未生成 timing/QoR/area。结论：当前瓶颈已从 frontend elaborate 转为
  `llc_cache_ctrl` 本体 mapping 复杂度，后续需要更小 timing probe 或继续拆 controller
  datapath/state，而不是继续等待同一 quick-map。
- 2026-05-08 07:20 CST，为了尽快拿到粗略 timing/QoR 方向，新增并启动非 signoff 的
  low-effort 诊断入口 `rtl/dc/run_dual_quick_map_low_1g.tcl`：
  `rtl/dc/runs/cache_ctrl_only_quick_map_low_mshr_helper_loop_way_9t20_20260508_0720_eda-05`。
  该 run 只用于确认 `llc_cache_ctrl` mapping 后的主要 setup 风险和面积量级；不能替代
  9t20l 正式 medium/compile-ultra 小模块收敛证据。
- 2026-05-08 08:29 CST，继续对 bridge pending scan 做等价 cleanup：当
  `AXI_ID_COUNT >= ENTRY_COUNT` 时进入 slot-ID mode，pending slot index 即 AXI ID，
  allocation 直接返回 free slot，response match 直接比较 `match_axi_id == slot`；
  ID 空间小于 entry 数时保留 tracked-ID fallback。`formal/axi_pending_scan/run_hw_cbmc.sh`
  通过，LLC hit-only perf contract 仍为 `ready=0/resp=7/no external`，bounded perf
  contract 仍为 `max_extra_observed=5` 且 LLC miss `+2`，全量 RTL contracts
  `53/53` 通过。该 RTL 修改使 07:55/07:59 启动的 slot-free bridge DC probes 全部
  stale，已手动停止并在对应 run 目录记录 `manual_status.log`。
- 2026-05-08 08:44 CST，基于 slot-ID pending-scan RTL 重新启动三条 bridge 诊断 DC：
  `rtl/dc/runs/bridge_dual_quick_map_low_slot_id_scan_slot_id_scan_9t20_20260508_0844_eda-05`、
  `rtl/dc/runs/bridge_ddr64_probe_quick_map_low_slot_id_scan_slot_id_scan_9t20_20260508_0844_eda-05`、
  `rtl/dc/runs/bridge_mmio4_probe_quick_map_low_slot_id_scan_slot_id_scan_9t20_20260508_0844_eda-05`。
  08:45 CST 复查时三者均未早期退出，已完成 SRAM `.db` 读取并进入 analyze 初段；
  `cache_ctrl_only_quick_map_low_mshr_helper_loop_way...0720_eda-05` 已越过
  analyze/elaborate/link，08:02 CST 进入 `Beginning Pass 1 Mapping`，仍在运行。
  当前仍只把这些 run 用作小模块 setup 诊断；所有小模块 setup 收敛后，必须再补同版
  current RTL 的 `axi_llc_subsystem_dual` full_top 1GHz DC 作为最终集成时序 gate。
  08:59 CST 复查时，MMIO4 single-bridge probe 已进入 `Beginning Mapping Optimizations
  (Medium effort)`；DDR64 single-bridge probe 和 `bridge_dual` 已完成 elaborate/link 并
  进入 `Beginning Pass 1 Mapping`；`cache_ctrl` low-effort 诊断仍在 mapping。四条 run
  均未写出最终 timing/QoR report，因此此时不能判断 setup 是否已收敛。
  09:01 CST，MMIO4 probe 首次打印中间 mapping optimization 表，面积约
  `24.4k -> 25.1k`，`WORST NEG SLACK` 显示 `0.80`，setup cost 约
  `3451 -> 2984`。按此前 DC log 约定该数值先按约 `0.80ns` 级 setup 违例幅度理解；
  由于该 run 仍在优化且尚未写最终 timing/QoR report，只能作为“MMIO4 single-bridge
  自身仍可能有 setup 压力”的早期信号。
- 2026-05-08 09:35 CST，针对 MMIO4 4B/4B single-beat 路径做生产 RTL helper fast path：
  `axi_llc_axi_mode2_shape.v` 在 4B/4B 参数下直接给出 4B aligned issue addr/size；
  `axi_llc_axi_write_pack.v` 和 `axi_llc_axi_read_pack.v` 对 4B single-beat mode2
  byte shift/extract 做显式 case，generic 路径保持原 byte loop 写法以兼容 hw-cbmc。
  新增并通过 `formal/axi_mode2_shape_single4`、`formal/axi_write_pack_single4`、
  `formal/axi_read_pack_single4`，同时复跑 `axi_mode2_shape`、`axi_write_pack`、
  `axi_read_pack`、`axi_write_pack_prod_width`、`axi_read_pack_prod_width`；随后又把
  `axi_llc_axi_write_pack.v` 的 4B fast path 从 procedural constant-if 改为
  generate-isolated branch，使 DC 不在 4B 实例中构建 generic packer；相关 write-pack
  formal 再次通过。VCS hit-only、bounded perf 和全量 RTL contracts 通过，最新全量目录为
  `rtl/local_debug/vcs_all_contracts_single4_generate_20260508_100218_eda-05`。因此 08:44 CST
  三条 bridge DC 只保留为 stale 诊断，不再作为当前 RTL setup 证据。
- 2026-05-08 09:49 CST，先尝试用 `nohup &` 启动新 bridge probes，但该执行环境没有保留
  活进程，也没有写 console log；09:51 CST 改由 Codex 长期 exec session 托管三条
  procedural constant-if RTL DC。它们在 10:00 CST 因 write-pack 改为 generate-isolated
  branch 被手动 SIGTERM 停止并写入 `manual_status.log`，不再作为当前 RTL setup 证据：
  `rtl/dc/runs/bridge_dual_quick_map_low_single4_helper_direct_9t20_20260508_0951_eda-05`、
  `rtl/dc/runs/bridge_ddr64_probe_quick_map_low_single4_helper_direct_9t20_20260508_0951_eda-05`、
  `rtl/dc/runs/bridge_mmio4_probe_quick_map_low_single4_helper_direct_9t20_20260508_0951_eda-05`。
  三者均使用 SMIC12 9T20 RVT/LVT std-cell db 以及 process-corner data/meta SRAM db；
  MMIO4 在停止前已进入 mapping。`cache_ctrl_only`
  low-effort 诊断 run
  `rtl/dc/runs/cache_ctrl_only_quick_map_low_mshr_helper_loop_way_9t20_20260508_0720_eda-05`
  已在 `Beginning Pass 1 Mapping` 后被 `timeout` SIGTERM 结束，只留下 post-link
  报告，没有 timing/QoR，因此不能作为 setup 结论。小模块 setup 都收敛后，仍必须
  再补同版 current RTL 的 `axi_llc_subsystem_dual` full_top 1GHz DC。
- 2026-05-08 10:12 CST，基于最新 generate-isolated RTL 重新启动三条 current-RTL
  bridge quick-map low probes，均使用 SMIC12 9T20 RVT/LVT std-cell `.db` 和
  process-corner data/meta SRAM `.db`：
  `rtl/dc/runs/bridge_dual_quick_map_low_single4_generate_direct_9t20_20260508_1012_101255_eda-05`、
  `rtl/dc/runs/bridge_ddr64_probe_quick_map_low_single4_generate_direct_9t20_20260508_1012_101255_eda-05`、
  `rtl/dc/runs/bridge_mmio4_probe_quick_map_low_single4_generate_direct_9t20_20260508_1012_101254_eda-05`。
  10:15 CST 早期复查：三者均已越过 `analyze_start`；MMIO4 已 `LINK_SANITY_PASS`
  并进入 `quick_map_low_start`，且 single4 `axi_llc_axi_write_pack` 只展开
  generate fast-path case block，不再触发旧 generic byte-loop warning。当前仍无最终
  timing/QoR，不能作为 setup 收敛结论。后续必须先看这些 bridge probes 与
  core/compat 小模块 setup 是否收敛，再启动同版 current RTL 的
  `axi_llc_subsystem_dual` full_top 1GHz DC。
- 2026-05-08 10:22 CST，启动 current-RTL `llc_cache_ctrl` low quick-map probe：
  `rtl/dc/runs/cache_ctrl_only_quick_map_low_single4_generate_direct_9t20_20260508_1022_102245_eda-05`，
  使用 `rtl/dc/probes/cache_ctrl_only.f`。该 run 用于补 core/cache-control 侧 setup
  证据；10:23 CST 已完成 analyze 并进入 elaborate，尚无 timing/QoR。
- 为避免 bridge/cache_ctrl 结束后还要临时整理入口，已新增两个 DC-only flist：
  `rtl/dc/probes/core_only.f` 覆盖 `axi_llc_subsystem_core` 及实际 SRAM/store/cache_ctrl
  依赖，`rtl/dc/probes/compat_only.f` 在 core 依赖上补 `axi_llc_subsystem_compat`。
  这两个入口只用于后续 current-RTL core/compat setup probe，不改变生产 RTL。

```sh
source /centos7/eda-tools/eda-software/synopsys/source-scripts/bash_eda10
dc_shell -x 'echo DC_SMOKE_OK; quit'
dc_shell -f rtl/dc/run_dual_link_sanity.tcl | tee rtl/dc/runs/link_sanity.log
```

该入口只做 `read_db/analyze/elaborate/link/check_design/report_reference`，不会做
`compile_ultra`。用于确认当前 flist、SRAM `.db` 和 top 选择没有脱节。

## 1GHz full compile

```sh
source /centos7/eda-tools/eda-software/synopsys/source-scripts/bash_eda10
dc_shell -f rtl/dc/run_dual_full_compile_1g.tcl | tee rtl/dc/runs/full_compile_1g.log
```

输出会保留在 `rtl/dc/runs/<run_tag>/outputs/`：

- `ddc/axi_llc_subsystem_dual_postcompile_1g.ddc`
- `netlist/axi_llc_subsystem_dual_postcompile_1g.v`
- `db/axi_llc_subsystem_dual_postcompile_1g.db`
- `sdc/axi_llc_subsystem_dual_postcompile_1g.sdc`
- `sdf/axi_llc_subsystem_dual_postcompile_1g.sdf`
- `spf/axi_llc_subsystem_dual_postcompile_1g.spf`

报告会保留在 `rtl/dc/runs/<run_tag>/reports/`，包括 timing/qor/area/reference/cell/
constraint/power/check_design。

可通过环境变量覆盖路径：

- `AXI_LLC_DC_RUN_ROOT`
- `AXI_LLC_DC_STD_DB`，可传入一个 Tcl list；如果覆盖，仍应保持 SMIC12 9T20
  signoff 库配置。
- `AXI_LLC_DC_DATA_DB`
- `AXI_LLC_DC_META_DB`
- `AXI_LLC_DC_FLIST`
- `AXI_LLC_DC_TOP`

## 检查运行状态

长 DC 运行期间优先使用只读状态脚本，避免重复手写 `ssh/ps/stat/grep/find`：

```sh
rtl/dc/check_dc_run.sh --host eda-09 \
  rtl/dc/runs/full_compile_1g_strict_template_9t20_5274f9d_20260506_2154_eda09
```

该脚本会输出目标节点时间、`run_metadata.txt`、launcher/DC 子进程状态、节点内存、
console log mtime、最新 `DC_STAGE`/warning/error、`exit_code.txt` 和已生成的
reports/outputs。脚本只读，不会启动、停止或修改 DC run。
