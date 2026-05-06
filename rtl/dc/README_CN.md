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

## 快速 link sanity

在 `eda-05`/`eda-09`/`eda-10` 等可用节点上运行。启动前先确认当前节点的 Synopsys
环境脚本和 `dc_shell` 可用，不要复用上一台服务器的假设。2026-05-06 探测结果：
`eda-10`/`eda-09`/`eda-05` 可以启动 `dc_shell`，其中 `eda-10` 当前负载最低、内存
充足，优先用于下一轮长 DC；`eda-05` 可用但负载很高且已有旧 DC 任务；
`eda-08` 当前 license vendor daemon 不可用，不应作为 DC 首选。

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
