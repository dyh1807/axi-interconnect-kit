# Dual AXI EC 收敛计划

本文档用于冻结后续 C++ reference / RTL EC 的收敛边界，避免继续按“想到一个
case 就补一个”的开放式方式扩展。目标不是枚举所有交叉组合，而是用有限矩阵、
固定随机种子和形式化不变量覆盖需求中的关键风险。

## 收敛原则

- 不做完整笛卡尔积枚举。`mode`、master、DDR/MMIO、maintenance、dirty/victim、
  response-held 等维度组合过多，继续手写单点 case 会无穷展开。
- EC 目标按“属性类别”收敛，而不是按“所有可能波形”收敛。每个类别必须说明由
  deterministic trace、fixed seed、formal invariant 或 Linux/image gate 中哪一种覆盖；
  没有归属到类别的新增 case 不进入短期收敛范围。
- 每个需求必须至少有一个正向路径和一个阻断/回压路径。例：合法 DDR 64B read
  要能发出两拍 256-bit `AR/R`，非法 MMIO 8B 要 ready=0 且不发任一外部 AXI。
- 每类 drain 不变量只用代表性组合覆盖。例：`invalidate_all` / `invalidate_line`
  都必须覆盖 pending lower response、held upstream response、dirty resident blocked
  和 retire 后恢复。
- 多 master 不再继续按所有 master 组合枚举。当前固定代表组合为
  `ICACHE + DCACHE_R`，因为它覆盖 ready-first 与 same-cycle accept 的差异。
- 后续新增 case 必须满足以下条件之一：补齐矩阵缺口、复现真实 bug、或验证一个尚未
  被形式化/随机 seed 覆盖的不变量。

## EC Freeze Policy

短期 EC 不再采用“每轮想到一个场景就补一个 directed case”的方式推进。后续判断规则为：

- 先按需求抽象成有限属性类别，再为每类选择一种主验证手段：deterministic trace
  覆盖具体可观察行为，固定 seed suite 覆盖扰动交叉，formal invariant 覆盖不适合枚举的
  安全性质，Linux/image gate 覆盖集成性能/功能回归。不要把所有维度做完整笛卡尔积。
- 若需求已经落在下方 deterministic matrix，且代表 trace、固定 seed 和对应 formal
  invariant 均已通过，则该类别视为短期收敛；不再继续手写同类排列组合。
- 若发现真实 bug，新增用例归类为 bug regression，并记录它修复的是哪个矩阵类别或
  formal 不变量；该行为不是重新打开整个类别。
- 若新增需求引入新语义，先扩展矩阵类别，再决定需要 deterministic trace、seed 扰动、
  formal invariant 还是 Linux/image gate；不能直接追加零散 case。
- 固定 seed suite 初始规模锁定为 `32`。除非 seed 暴露真实 bug、覆盖矩阵新增维度，
  或需要阶段性加严到下一档固定规模，否则不逐轮增加随机 seed。
- DC/timing 失败不自动意味着 EC 未覆盖。若为时序整改修改了生产 C++/RTL 语义，
  才需要重新跑对应 EC/perf gate。

因此，“一次性想好各种可能 case”的可行做法不是枚举所有波形，而是一次性冻结属性矩阵、
代表样例、固定 seed 扰动和形式化不变量。这个矩阵满足 Stop Criteria 后，EC 工作应切换
到 bug regression 和长期 gate，而不是继续无边界扩展。

当前短期执行结论：不再继续补充同类 directed EC case。下一步 EC 只允许三类变化：
生产 C++/RTL 被修改后的必要回归、真实 bug regression、或把现有需求提炼成新的生产
helper/formal invariant。否则继续新增 case 会增加维护成本，但不会显著提高当前风险覆盖。

## Deterministic Trace Matrix

| 类别 | 必须覆盖的行为 | 当前状态 |
| --- | --- | --- |
| 地址分类 | DDR/SDRAM `>=0x4000_0000`，MMIO 其它地址，mapped local window | 已覆盖 |
| DDR 形状 | 4B/8B/16B/32B/64B read/write，DDR 固定 256-bit beat，64B 为 2 beat | 已覆盖 |
| MMIO 形状 | 仅 32-bit / 1 beat，unsupported wider MMIO ready=0 且不外发 AXI | 已覆盖 |
| outstanding/ID | read/write 独立，ID reuse/release，response route 不串线 | 已覆盖 |
| 同地址 AR/AW hazard | pending read/write 下相同 hazard granule 不允许相反方向提前 accepted | 已覆盖 |
| response 不回压 lower | upstream response held 时 DDR/MMIO `RREADY/BREADY` 不被错误拉低 | 已覆盖代表场景 |
| `invalidate_all` drain | pending MMIO/cache read/write、held response、dirty resident blocked、retire 后恢复 | 已覆盖代表场景 |
| `invalidate_line` drain | target-line pending read/write、unrelated line compat-local drain、scope survivor hit | 已覆盖代表场景 |
| multi-master maintenance | `ICACHE + DCACHE_R` drain 与 recovery，覆盖 ready-first / same-cycle accept 差异 | 已覆盖代表场景 |
| reconfig drain | MODE_CACHE -> MODE_MAPPED 下 pending MMIO/cache read/write drain | 已覆盖代表场景 |
| dirty victim | dirty victim writeback 与 MMIO read/write 并发时 drain/blocked | 已覆盖代表场景 |
| production-width smoke | production-size mapped window / direct DDR read smoke | 已覆盖 smoke，仍非 full EC |

## 固定随机 Seed Suite

后续不再继续手写大量相似组合，而应补一个固定 seed suite：

- 目标：随机产生 read/write/MMIO/cacheable/maintenance/reconfig 序列，C++ 产生 trace，
  RTL TB 消费同一 trace，比较所有可观察外部 AXI 和 upstream response 事件。
- 初始规模：`32` 个短 seed，每个 seed 控制在仿真可接受范围内。
- 必选扰动：response held、DDR/MMIO 返回乱序但合法、maintenance pending、same-line
  AR/AW hazard、dirty victim、multi-master read。
- 固定准入：seed 失败必须保存 JSON/trace；修复后 seed 进入回归集，不再丢弃。

当前初始落地版本已建立 `32` 个固定 seed 的 maintenance/recovery trace suite：
`axi_interconnect_dual_port_trace_vectors_test.cpp` 使用实际 `AXI_Interconnect`
comb/seq 路径生成 `CPP_SEEDED_MAINT_*` 数组，`tb_axi_llc_subsystem_dual_cpp_trace_contract.v`
在 RTL 中 replay。该 suite 当前覆盖随机化地址、`ICACHE/DCACHE_R` master 顺序、
`invalidate_all` / target-line `invalidate_line`、maintenance accepted 后的 miss/refill
或 survivor hit/no-external。C++ `ctest` 24/24、targeted VCS
`local_debug/vcs_dual_cpp_trace_seeded_maintenance_20260506_190137_eda-10` 和全量
RTL contract `local_debug/vcs_all_contracts_seeded_maintenance_20260506_190155_eda-10`
均通过。后续只有在发现真实 bug 或矩阵缺口时再扩展 seed 维度。

## 形式化/不变量 Gate

形式化不用于替代全系统 EC，但用于卡住不适合靠枚举发现的错误：

- address classifier/router：同一请求不得同时走 DDR/MMIO，unsupported MMIO 不外发。
- hazard scoreboard：同一 hazard granule 上 pending AR/AW 约束必须保持。
- response mux：upstream held response 不应对 lower `RREADY/BREADY` 产生非法依赖。
- maintenance gate：有 pending lower response、held upstream response 或 dirty resident
  line 时，maintenance accepted 必须为 0。

形式化 harness 必须引用实际会使用的 RTL/C++ 文件，不接受另写一个“按理解重做”的
模型作为替代。

当前短期 invariant gate 复核：

- 2026-05-06 targeted hw-cbmc gate 已通过 6/6，日志：
  `local_debug/hw_cbmc_invariant_gate_20260506_191142.log`。
- 覆盖入口：`dual_port_route_shape`、`dual_port_req_steer`、`dual_port_issue_gate`、
  `dual_port_hazard_match`、`dual_port_hazard_scoreboard`、`dual_port_resp_mux`。
- 这些入口分别卡住地址/端口互斥、unsupported no-issue、同地址 AR/AW issue gate、
  pending read/write hazard 记录/释放、以及 response mux ready/选择逻辑。
- maintenance gate 的完整 top 级状态空间当前仍主要由 deterministic trace、固定 32 seed
  maintenance/recovery suite 和 RTL contract 覆盖；不再通过 monolithic top formal
  强行证明，除非后续把 maintenance accepted 条件拆成生产 helper。

## Table-Oracle / State-IO Cutpoint 方向

长期端到端形式 EC 的主要风险是 monolithic top 会同时拉入 compat queue、core MSHR、
store table、bridge pending、hazard scoreboard 和宽 payload。后续不应把整张 LLC
data/meta/valid/repl 表作为 PI/PO 展开，而应采用 table-oracle / state-IO cutpoint：

- table read 只输入本次查询 set/row 的返回值。
- table write 只输出本次写表意图：`wr_en/wr_set/wr_data/wr_mask`。
- 同一 tracked set 的 read-after-write 由 harness shadow row 保证一致。
- store primitive 的 latency/mask 行为仍由独立 proof 或 VCS contract 负责。

具体规划见 [formal_table_oracle_cutpoints_CN.md](formal_table_oracle_cutpoints_CN.md)。
2026-05-06 已落地首个原型 `formal/cache_ctrl_table_oracle_write_then_read`：直接实例化
实际 `llc_cache_ctrl.v`，在 table 边界用 tracked set shadow row 证明 partial write
hit 后同地址 read 返回 merge 后数据，targeted log 为
`local_debug/hw_cbmc_cache_ctrl_table_oracle_write_then_read_20260506_233439.log`。该方向是
后续结构化补强，不是重新打开 directed case 笛卡尔积。

## Linux / Performance Gate

只要 production C++/RTL 路径发生修改，就必须重新跑：

- large + `CONFIG_BPU` Linux 300k quick gate。
- 300k 正常后跑 5M gate。
- 结论不能只写 pass/error；必须报告 cycles、IPC、commit/load/store、相对 baseline
  delta，以及差异是否可接受。
- 若改动理论上不应影响性能，优先要求 `--require-exact`；允许抖动时暂用
  `--max-cycle-delta-pct 1.0 --max-ipc-drop-pct 1.0`。

## DC / Timing Gate

DC 不作为 EC 完成的替代信号。EC freeze 后再进入长期 DC：

- 使用 9T20 标准单元库和 SMIC12 SRAM macro。
- 保留完整 console log、report、qor/timing/area/power、netlist、ddc/svf。
- 若 full top 长期停在 elaborate 且无新日志，需要记录状态后考虑在可用 EDA
  服务器启动 clean DC，而不是无限等待单一 run。

## Stop Criteria

短期 EC 可认为收敛的条件：

- Deterministic trace matrix 中所有“必须覆盖”项均为已覆盖或明确 out-of-scope。
- C++ `ctest` 全通过。
- RTL `run_all_contracts.sh` 全通过。
- 固定随机 seed suite 建立并通过初始 `32` seeds。
- 已有 hw-cbmc/formal manifest 中的实际模块 harness 全通过。
- 若有 production 路径修改，Linux 300k/5M perf gate 通过且 cycles/IPC delta 可接受。

未满足上述条件前，不应宣称 C++/RTL EC 完成；但满足后也不再继续手工新增零散 case，
除非发现真实 bug 或矩阵/不变量缺口。
