# Dual AXI 当前目标审计

审计时间：2026-05-06 20:02 CST，主机 `eda-10`。

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
| RTL contract suite | 全量 contract 通过 | 已通过 53/53；compat/bridge/MSHR invalid-payload no-clear RTL hygiene 后均已复跑 | `local_debug/vcs_all_contracts_mshr_payload_no_clear_20260506_200052_eda10/driver.log` |
| hw-cbmc invariant gate | 当前 stable targeted invariant gate 通过 | 已通过 6/6 | `local_debug/hw_cbmc_invariant_gate_20260506_191142.log` |
| EC 扩展策略 | 避免继续无边界补同类 directed case | 已冻结 | `docs/dual_axi_ec_closure_plan_CN.md`，`docs/dual_axi_verification_checklist_CN.md` |
| DC 脚本产物保留 | 保留 report/results/QoR/timing/netlist/ddc/svf/sdc/sdf/spf | 脚本已覆盖，等待实际 full DC 产出 | `rtl/dc/run_dual_full_compile_1g.tcl`，`rtl/dc/axi_llc_dc_common.tcl` |
| DC/timing | eda-10 full DC 使用 9T20 + SMIC12 SRAM，完成后检查 timing/QoR/netlist | 未完成 | `rtl/dc/runs/full_compile_1g_strict_template_9t20_e4a6434_20260506_115655_eda10_live/full_compile_1g.console.log` |

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
后续若 production C++/RTL 再变化，必须重新跑 300k/5M 并用同样口径报告。

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

仍未声称完成的是“完整 C++ class / RTL top 同 harness 的端到端形式 EC”。该项属于长期
探索，不作为继续无限补 directed case 的理由。

## DC 状态

当前 full DC：

- run dir：`rtl/dc/runs/full_compile_1g_strict_template_9t20_e4a6434_20260506_115655_eda10_live`
- 状态：仍在 `elaborate_start` 后的 `axi_llc_subsystem_compat` PRESTO/Building 阶段
- 进程：`dc_shell` 子进程仍以约 100% CPU 运行，约 28GB RSS
- 当前已有产物：`outputs/axi_llc_subsystem_dual.svf`
- 尚未产生 post-compile QoR/timing/area/netlist/ddc 等完整结果
- 该 run 启动早于 19:42 CST 的 RTL hygiene，因此后续只能作为旧 RTL 的
  compat bottleneck 证据，不能作为新工作树 signoff

静态瓶颈复核：

- `axi_llc_subsystem_compat.v` 当前约 `1795` 行，比 wrapper top 更大，内部包含多个
  flattened FIFO / slot / response queue。
- 生产参数下 `RD_RESP_SLOT_COUNT = NUM_READ_MASTERS * READ_RESP_QUEUE_DEPTH = 4*32=128`。
- `rd_resp_q_data[0:127]` 每槽 `READ_RESP_BITS=2048`，仅这一项就是 `262144` bit
  的寄存器阵列。
- 按显式主要数组估算，compat 自身寄存器阵列约 `338338` bit，其中还不含 core 内部
  SRAM/valid/repl/MSHR 状态。
- 组合路径还包含多个 `MAX_OUTSTANDING=32`、`RD_SLOT_COUNT=128`、
  `WR_SLOT_COUNT=64`、`RD_RESP_SLOT_COUNT=128` 的扫描函数，用于 ID conflict、
  same-line hazard、maintenance drain 和 response queue 管理。
- 因此若 compat link sanity 的 2h 限时最终 timeout，优先怀疑 compat 结构规模和
  full-width response queue，而不是库路径或 SRAM macro 配置。

并行 compat link sanity：

- run dir：`rtl/dc/runs/compat_link_sanity_9t20_536c510_20260506_192341_eda10`
- 状态：仍在 `elaborate_start` 后运行，早期 `read_db/analyze` 已完成，未见路径/库早期错误
- 该 run 有 `timeout 7200` 限制，用于判断 compat elaborate 是否能在较短窗口内完成
- 该 run 同样启动早于 19:42 CST 的 RTL hygiene，因此只能作为旧 RTL 诊断。
- 2026-05-06 19:55 CST 已停止该旧 sanity，避免继续消耗 eda-10 资源。

当前工作树的新 compat link sanity：

- run dir：`rtl/dc/runs/compat_link_sanity_payload_no_clear_9b05923_20260506_194526_eda10`
- 状态：已完成 `read_db/analyze` 并进入 `elaborate_start`，但启动早于 19:53 CST
  bridge hygiene
- 目的：验证去掉 invalid wide payload reset/clear 是否能改善 compat elaborate/link
- 2026-05-06 19:55 CST 已停止该旧 sanity；后续 current-HEAD sanity 应基于
  compat+bridge+MSHR 三处 hygiene 后的 RTL 启动

## 下一步

1. 基于当前 HEAD 启动新的 `axi_llc_subsystem_compat` link sanity，覆盖 compat+bridge+MSHR
   invalid-payload hygiene 后的 RTL；若仍 timeout，则 invalid-payload clear 不是主因，
   需要评估 response queue 存储结构/接口宽度/扫描结构。
2. 继续定期检查旧 `full_compile_1g_strict_template_9t20_e4a6434_20260506_115655_eda10_live`
   和旧 `compat_link_sanity_9t20_536c510_20260506_192341_eda10`，但只作为瓶颈证据。
3. 不再新增 EC directed case，除非发现真实 bug、production 语义变化，或能抽象为新的
   production helper/formal invariant。
