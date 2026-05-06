# AXI LLC DC 入口

本目录保存当前分支可复用的 Design Compiler 入口。目标是避免长综合时使用过期 RTL
列表或过期 SRAM 宏配置。

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
