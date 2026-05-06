# Dual AXI 当前目标审计

审计时间：2026-05-06 21:49 CST，主机 `eda-10`。

当前审计 HEAD：`dbee062 refactor(cache): simplify line helper selects`，分支
`merge/main-cb56e2b-into-review-20260416` 已推送到
`origin/merge/main-cb56e2b-into-review-20260416`。

本文档把当前 active goal 拆成可检查交付项，并记录实际证据。结论：Linux quick
perf/difftest 和短期 EC category gate 已有证据闭合；DC/timing 尚未闭合，因此整体目标
不能标记完成。

## 目标拆解

| 要求 | 成功标准 | 当前状态 | 证据 |
| --- | --- | --- | --- |
| Linux quick perf/difftest 300k | large + `CONFIG_BPU`，对比 baseline，报告 cycles/IPC/commits/load/store delta | 已通过，exact match | `tools/compare_linux_boot_perf.py --require-exact ../local_logs/dual_axi_ec_20260506/linux_large_bpu_300k_0397b98_prodeq_0dce8d4_20260506_133657.log ../local_logs/dual_axi_ec_20260506/linux_large_bpu_300k_invline_quiescent_20260506_180629.log` |
| Linux quick perf/difftest 5M | 300k 正常后跑 5M，同样报告性能指标 | 已通过，exact match | `tools/compare_linux_boot_perf.py --require-exact ../local_logs/dual_axi_ec_20260506/linux_large_bpu_5m_0397b98_prodeq_0dce8d4_20260506_133746.log ../local_logs/dual_axi_ec_20260506/linux_large_bpu_5m_invline_quiescent_20260506_180710.log` |
| C++ unit regression | 当前 C++ reference 测试全通过 | 已通过 24/24 | `local_debug/ctest_invline_cache_mmio_write_20260506_130721.log` |
| Trace-based C++/RTL EC | 实际 `AXI_Interconnect` 生成 trace，实际 RTL replay | 短期 category gate 已冻结并通过代表场景 | `docs/dual_axi_ec_closure_plan_CN.md`，`local_debug/vcs_dual_cpp_trace_seeded_maintenance_20260506_190137_eda-10/run.log` |
| RTL contract suite | 全量 contract 通过 | 已通过 53/53；`dbee062` cache helper 简化后已复跑 | `rtl/local_debug/vcs_all_contracts_cache_helper_slim_unsigned_20260506_212255_eda10/driver.log` |
| hw-cbmc invariant gate | 当前 stable targeted invariant gate 通过 | 已通过 6/6 | `local_debug/hw_cbmc_invariant_gate_20260506_191142.log` |
| EC 扩展策略 | 避免继续无边界补同类 directed case | 已冻结 | `docs/dual_axi_ec_closure_plan_CN.md`，`docs/dual_axi_verification_checklist_CN.md` |
| DC 脚本产物保留 | 保留 report/results/QoR/timing/netlist/ddc/svf/sdc/sdf/spf | 脚本已覆盖，等待实际 full DC 产出 | `rtl/dc/run_dual_full_compile_1g.tcl`，`rtl/dc/axi_llc_dc_common.tcl` |
| DC link sanity | current RTL 关键子模块可被 DC 读入/elaborate/link，且使用 9T20 + SMIC12 SRAM `.db` | `axi_llc_subsystem_compat` 与 `llc_cache_ctrl` 已通过 | `rtl/dc/runs/compat_link_sanity_cache_helper_slim_wip_20260506_205627_eda10/compat_link_sanity.console.log`，`rtl/dc/runs/cache_ctrl_link_sanity_helper_slim_unsigned_wip_20260506_212515_eda10/cache_ctrl_link_sanity.console.log` |
| DC/timing | full/top 1GHz DC 使用 9T20 + SMIC12 SRAM，完成后检查 timing/QoR/netlist | 当前 `5274f9d` clean full DC 已在 `eda-09` 启动；尚未完成，不能 signoff | `rtl/dc/runs/full_compile_1g_strict_template_9t20_5274f9d_20260506_2154_eda09/full_compile_1g.console.log` |

## Linux 指标

300k quick gate：

- cycles `120687 -> 120687`，delta `0`
- commits `300001 -> 300001`，delta `0`
- IPC `2.485777 -> 2.485777`，delta `0`
- loads/stores `40586/51609 -> 40586/51609`

5M gate：

- cycles `2078844 -> 2078844`，delta `0`
- commits `5000005 -> 5000005`，delta `0`
- IPC `2.405185 -> 2.405185`，delta `0`
- loads/stores `530423/921658 -> 530423/921658`
- L1D AMAT、miss penalty、AXI read latency、LLC->DDR read avg 均 exact match

因此，当前 C++ queue / invalidate-line 相关 production 语义修复没有可观测性能回退。
`dbee062` 之后的最新 production C++ 路径未变化，最新 RTL helper 简化只影响 DC hygiene
结构；后续若 production C++/RTL 再变化，必须重新跑 300k/5M 并用同样口径报告。

## EC 结论

短期 EC 不再继续开放式补同类 directed case。当前闭合依据是：

- deterministic trace matrix 覆盖地址分类、DDR/MMIO 形状、outstanding/ID、same-line
  AR/AW hazard、lower response 不回压、maintenance drain/recovery、dirty victim 和
  production-width smoke。
- 固定 32 seed maintenance/recovery suite 已落地并通过 targeted VCS。
- 全量 RTL contract 通过 `53/53`。
- targeted hw-cbmc invariant gate 通过 `6/6`。

2026-05-06 19:42 CST 之后新增一项 RTL-only DC hygiene：`axi_llc_subsystem_compat`
不再 reset/clear invalid wide payload entries，仍保留 valid/head/tail/count reset 与
所有有效写入。该修改只影响 RTL，不改变 C++ reference；targeted
`tb_axi_llc_subsystem_dual_cpp_trace_contract` 已通过，目录为
`rtl/local_debug/vcs_dual_cpp_trace_payload_no_clear_20260506_194236_eda10`；
全量 RTL contract 已通过 `53/53`，目录为
`rtl/local_debug/vcs_all_contracts_payload_no_clear_20260506_194248_eda10`。

2026-05-06 19:53 CST 继续对 `axi_llc_axi_bridge` 做同类 RTL-only DC hygiene：
去掉 invalid pending/rsp slot 的 wide payload reset/free clear，但保留 read accept
时 `rd_rdata_r` 的清零，因为它是 multi-beat read merge buffer 初始化。全量 RTL
contract 已通过 `53/53`，目录为
`rtl/local_debug/vcs_all_contracts_bridge_payload_no_clear_20260506_195341_eda10`。

2026-05-06 20:00 CST 继续对 `llc_cache_ctrl` 的 MSHR wide payload arrays 做同类
RTL-only DC hygiene：去掉 invalid MSHR slot 的 victim/refill/write payload
reset/free clear，保留 MSHR valid/status/address/tag/way 等控制状态清零。全量 RTL
contract 已通过 `53/53`，目录为
`rtl/local_debug/vcs_all_contracts_mshr_payload_no_clear_20260506_200052_eda10`。

2026-05-06 20:16 CST 继续对 `axi_llc_subsystem_compat` 的 read response buffering
做结构优化：per-master FIFO 只保留顺序和 shared pool index，2048-bit read payload
改为 `MAX_OUTSTANDING=32` 个全局共享 pool slot。该修改利用全局 read outstanding
上限，避免为 `NUM_READ_MASTERS * READ_RESP_QUEUE_DEPTH = 128` 个逻辑队列槽各自保留
一份 2048-bit payload。全量 RTL contract 已通过 `53/53`，目录为
`rtl/local_debug/vcs_all_contracts_resp_pool_20260506_201648_eda10`。随后清理该新增逻辑
在 DC elaborate 早期暴露的 pool-index signedness warning，把 pool index 从 signed
`integer` 改为 8-bit reg；全量 RTL contract 再次通过 `53/53`，目录为
`rtl/local_debug/vcs_all_contracts_resp_pool_idx_cleanup_20260506_202344_eda10`。

2026-05-06 21:25 CST 继续对 `llc_cache_ctrl` 的 line helper 做 RTL-only DC hygiene：
`merge_line` 和 `extract_read_response` 从双层循环/嵌套选择改为单层目标字节/word
选择，循环下标改成无符号 typed reg，避免 DC signedness warning 并降低 helper
组合展开复杂度。全量 RTL contract 已通过 `53/53`，目录为
`rtl/local_debug/vcs_all_contracts_cache_helper_slim_unsigned_20260506_212255_eda10`。
随后 `llc_cache_ctrl` link sanity 已通过，目录为
`rtl/dc/runs/cache_ctrl_link_sanity_helper_slim_unsigned_wip_20260506_212515_eda10`，
`Memory usage for this session 6567 Mbytes`，CPU `0.14h`。

仍未声称完成的是“完整 C++ class / RTL top 同 harness 的端到端形式 EC”。该项属于长期
探索，不作为继续无限补 directed case 的理由。

## DC 状态

旧 full DC：

- run dir：`rtl/dc/runs/full_compile_1g_strict_template_9t20_e4a6434_20260506_115655_eda10_live`
- 状态：已停止/废弃，启动早于后续 compat/bridge/MSHR/response-pool RTL 修改
- 当前已有产物：`outputs/axi_llc_subsystem_dual.svf`
- 尚未产生 post-compile QoR/timing/area/netlist/ddc 等完整结果
- 该 run 启动早于 19:42 CST 之后的一系列 RTL hygiene，因此后续只能作为旧 RTL 的
  compat bottleneck 证据，不能作为新工作树 signoff

`eda-10` 当前无我方 `dc_shell` / `common_shell` full DC 后台在跑，且全机内存压力
较高：`qimeng1` 用户的 `simulator --mode ckpt` 进程组约占 `801.7GiB RSS`，因此不
建议在该节点未确认资源窗口前贸然启动新的 full DC。

`eda-07` 上旧的
`rtl/dc/runs/full_compile_1g_9t20_622b6e4_20260506_104636_eda07` 已停止。该 run
基于旧 `622b6e4`，console log 最后更新时间停在 10:47 CST，只到
`elaborate_start` / building `axi_llc_subsystem_compat`，已跑近 11 小时且不能代表
当前 RTL。

随后曾在 `eda-07` 基于当前 `c98464a` 启动新的 clean full DC：

- run root：
  `rtl/dc/runs/full_compile_1g_strict_template_9t20_c98464a_20260506_2147_eda07`
- launcher PID：`2692139`
- DC PID：`2692359`
- 早期状态：已完成 9T20 RVT/LVT、data SRAM `.db`、meta SRAM `.db` 加载和 42 个
  RTL analyze，进入 `elaborate_start` / building `axi_llc_subsystem_compat`
- 该 run 已在 21:51 CST 停止，因为 `eda-07` 可用内存快速降到约 17GiB 且 swap 已满，
  主要由其它用户 simulator 进程占用。停止前尚无 compile/QoR/timing/netlist 结果。

当前有效 clean full DC 已转到 `eda-09`：

- run root：
  `rtl/dc/runs/full_compile_1g_strict_template_9t20_5274f9d_20260506_2154_eda09`
- launcher PID：`3230090`
- DC PID：`3230092`
- 启动时 `eda-09` 约有 `588GiB` available memory，无正在运行的我方 DC；早期日志已
  完成 data/meta SRAM `.db` 读取并进入 RTL analyze
- 当前仍无 compile/QoR/timing/netlist 结果，因此不能 signoff

OOM 诊断：

- `rtl/dc/runs/compat_link_sanity_resp_pool_idx_db0faed_20260506_202711_eda10`
  的失败发生在 2026-05-06 20:45 CST，DC console 显示工具在约 `35142 MB`
  allocation 后报告 `Out of memory`。
- 同一时间 `dmesg -T` 显示 `global_oom`，OOM killer 杀掉的是 `common_shell_ex`
  `pid=431368`，`anon-rss` 约 `35150324 kB`；OOM 列表中同时存在大量其它用户
  `simulator` 进程，单个 RSS 为数 GB 到十余 GB。
- 该失败 log 已经显示 `llc_data_store`/`llc_meta_store` 参数为 `USE_SMIC12=1`，
  后续 current RTL link sanity 也证明 data/meta SRAM `.db` link 正常。
- 因此该 OOM 的直接触发因素是共享服务器全局内存压力，不是 valid/repl regfile 或
  generic SRAM table 必然导致。valid/repl 继续保持 regfile；data/meta 继续使用
  SMIC12 SRAM macro。

已通过的 current RTL link sanity：

- `axi_llc_subsystem_compat`：
  `rtl/dc/runs/compat_link_sanity_cache_helper_slim_wip_20260506_205627_eda10`，
  `LINK_SANITY_PASS`，使用 SMIC12 9T20 RVT/LVT 标准单元和 data/meta SRAM `.db`，
  `Memory usage for this session 9351 Mbytes`，CPU `0.42h`。该 run 证明
  compat/current RTL 可读入、elaborate、link，并且 `valid_mem_reg`/`repl_mem_reg`
  仍保持 regfile。
- `llc_cache_ctrl`：
  `rtl/dc/runs/cache_ctrl_link_sanity_helper_slim_unsigned_wip_20260506_212515_eda10`，
  `LINK_SANITY_PASS`，`Memory usage for this session 6567 Mbytes`，CPU `0.14h`。

静态瓶颈复核：

- `axi_llc_subsystem_compat.v` 当前约 `1843` 行，比 wrapper top 更大，内部包含多个
  flattened FIFO / slot / response queue。
- 生产参数下 `RD_RESP_SLOT_COUNT = NUM_READ_MASTERS * READ_RESP_QUEUE_DEPTH = 4*32=128`。
- 旧结构中 `rd_resp_q_data[0:127]` 每槽 `READ_RESP_BITS=2048`，仅这一项就是
  `262144` bit；加上每槽 `ID_BITS=4` 后 read-response queue backing 约 `262656` bit。
- 当前结构改为 128 个小 `pool_idx` 加 32 个共享 2048-bit payload pool 和 32 个 ID，
  read-response backing 约 `66720` bit，减少约 `195936` bit，约 `74.6%`。
- 按此前显式主要数组估算口径，compat 自身主要寄存器阵列从约 `338338` bit 降到约
  `142402` bit，其中仍不含 core 内部 SRAM/valid/repl/MSHR 状态。
- 组合路径还包含多个 `MAX_OUTSTANDING=32`、`RD_SLOT_COUNT=128`、
  `WR_SLOT_COUNT=64`、`RD_RESP_SLOT_COUNT=128` 的扫描函数，用于 ID conflict、
  same-line hazard、maintenance drain 和 response queue 管理。
- 因此若 compat link sanity 的 2h 限时最终 timeout，优先怀疑 compat 结构规模和
  full-width response queue，而不是库路径或 SRAM macro 配置。

旧 compat link sanity：

- run dir：`rtl/dc/runs/compat_link_sanity_9t20_536c510_20260506_192341_eda10`
- 状态：已停止/废弃；早期 `read_db/analyze` 已完成，未见路径/库早期错误
- 该 run 有 `timeout 7200` 限制，用于判断 compat elaborate 是否能在较短窗口内完成
- 该 run 同样启动早于 19:42 CST 的 RTL hygiene，因此只能作为旧 RTL 诊断。
- 2026-05-06 19:55 CST 已停止该旧 sanity，避免继续消耗 eda-10 资源。

已废弃的 payload-no-clear compat link sanity：

- run dir：`rtl/dc/runs/compat_link_sanity_payload_no_clear_9b05923_20260506_194526_eda10`
- 状态：已停止/废弃；已完成 `read_db/analyze` 并进入 `elaborate_start`，但启动早于 19:53 CST
  bridge hygiene
- 目的：验证去掉 invalid wide payload reset/clear 是否能改善 compat elaborate/link
- 2026-05-06 19:55 CST 已停止该旧 sanity；后续 current-HEAD sanity 应基于
  compat+bridge+MSHR 三处 hygiene 后的 RTL 启动
- 2026-05-06 20:16 CST response-pool RTL 修改后，所有更早的 compat sanity 继续
  supersede；下一轮 current-HEAD sanity 必须基于包含 response-pool 的 HEAD 启动。

## 下一步

1. 不再因 20:45 的 OOM 单独修改 valid/repl 或 SRAM 映射；该事件按共享服务器
   `global_oom` 处理。
2. 定期检查 `eda-09` 新 full DC 的 log mtime、阶段、RSS、是否产生
   precompile/postcompile QoR/timing/area/netlist/ddc/db/svf/sdc/sdf/spf；若长期停在
   `axi_llc_subsystem_compat` elaborate 且无日志更新，再继续做 compat 局部结构诊断，
   不再盲目重复 full top。
3. EC 不再开放式新增同类 directed case；只在发现真实 bug、production 语义变化，
   或能抽象为新的 production helper/formal invariant 时补充。
