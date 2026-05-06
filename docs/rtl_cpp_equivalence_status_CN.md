# RTL / C++ 等价性验证状态

更新时间：2026-05-07 CST。

当前对象：`axi-interconnect-kit` submodule，分支
`merge/main-cb56e2b-into-review-20260416`，记录时 HEAD 为 `692d1f3`。

## 结论

当前 RTL / C++ 等价性验证可以支持继续等待 DC，并支持当前 dual external AXI / LLC
语义的短期收敛判断。证据包括 C++ regression、C++ trace 到实际 RTL replay、RTL VCS
contracts、hw-cbmc stable manifest、以及 large + `CONFIG_BPU` Linux 300k/5M
quick perf/difftest gate。

这不是“完整数学意义上的端到端形式等价证明”。目前仍未声称完成的是：把完整 C++
`AXI_Interconnect` class 和完整 RTL top 放进同一个 hw-cbmc harness 中做全状态空间证明。
该项仍属于长期探索，不作为继续无限补 directed case 的理由。

当前短期 EC 策略已经冻结：不再开放式追加同类手写 case。只有 production C++/RTL 语义
发生变化、DC/timing 修正引入语义变化、或发现真实 bug 时，才补对应 regression /
formal invariant / Linux gate。

## 证据总览

| 类型 | 当前状态 | 说明 / 证据 |
| --- | --- | --- |
| C++ regression | 通过 24/24 | `local_debug/ctest_invline_cache_mmio_write_20260506_130721.log` |
| C++ trace -> RTL replay | 短期 category gate 已通过 | 实际 `AXI_Interconnect` 生成 trace，实际 `axi_llc_subsystem_dual.v` replay；见 `docs/dual_axi_ec_closure_plan_CN.md` 和 `docs/dual_axi_verification_checklist_CN.md` |
| RTL VCS contract suite | 通过 53/53 | `rtl/local_debug/vcs_all_contracts_cache_helper_slim_unsigned_20260506_212255_eda10/driver.log` |
| hw-cbmc stable manifest | stable 83 项 | `formal/run_passed_hw_cbmc.sh` 当前纳入 83 个已通过入口；`formal/*/run_hw_cbmc.sh` 总数 85 |
| hw-cbmc non-stable | 2 项 experimental | `subsystem_core_dirty_evict_writeback`、`subsystem_dual_mode0_ddr_bypass_cacheline_read_response`，未作为生产 RTL 失败结论 |
| Linux 300k quick gate | exact match | cycles `120687 -> 120687`，IPC `2.485777 -> 2.485777` |
| Linux 5M gate | exact match | cycles `2078844 -> 2078844`，IPC `2.405185 -> 2.405185` |
| DC/timing | 未完成 signoff | full DC 仍需等待 9T20 + SMIC12 SRAM macro 的最终 timing/QoR/netlist 结果 |

## Formal 检查状态

Formal 检查以 hw-cbmc 为主。原则是：放进 formal 的对象必须来自实际生产路径；wrapper
只能做端口约束、复位/ready 固定、未关注端口 tie-off、以及观测信号暴露，不能另写一个
“按理解重做”的 C++/RTL 替身。

已稳定通过的 formal 类别包括：

- AXI helper EC：ID resize、beat shape、mode2 shape、pending scan、FIFO pointer、
  queue control、write pack、issue select 等生产 helper。
- Dual bridge / dual port helper：DDR/MMIO route shape、read/write issue shape、
  unsupported MMIO no-issue、same-line hazard match/scoreboard、response mux ready/选择。
- Bridge / subsystem bounded smoke：DDR/MMIO 读写形状、production-width cacheline read/write
  response、same-line read/write safety、mode0 bypass smoke、部分 cache dirty evict / refill 场景。
- Cache-control table-oracle proof：直接实例化实际 `llc_cache_ctrl.v`，在 table 边界使用
  tracked set shadow row，覆盖 write-then-read、read miss refill、partial write miss refill、
  dirty evict then read、invalidate then read miss 五类原型。
- Invariant gate：2026-05-06 targeted gate 通过 6/6，覆盖 route/steer/issue/hazard/
  scoreboard/resp mux 等安全属性。

当前 formal 的明确边界：

- 没有完成完整 C++ class 与完整 RTL top 的单一 monolithic hw-cbmc 端到端证明。
- 不把整张 LLC data/meta/valid/repl 表作为 PI/PO 展开；后续更合理方向是 table-oracle /
  state-IO cutpoint，只输入本次查询 row，只输出本次写表意图。
- 两个入口保留为 experimental/non-stable，不计入当前生产 signoff，也不要求在等待 DC 期间
  强行收敛。

## TB / Trace 检查状态

TB 检查分为三层。

第一层是 C++ 自身 regression。它验证 reference 的 dual-port state machine、DDR/MMIO
地址分类、256-bit DDR beat pack/slice、MMIO 32-bit 访问、LLC cache/mapped/off mode
基础语义，以及部分 Linux/image 集成行为。

第二层是 C++ trace 到 RTL replay。流程是：

1. 实际 `AXI_Interconnect` comb/seq 路径生成 trace/vector。
2. RTL testbench 直接实例化实际 `axi_llc_subsystem_dual.v`。
3. TB replay 同一组 upstream stimulus 和 downstream DDR/MMIO response。
4. 对比外部可观测行为：upstream accept/response、DDR/MMIO `AR/AW/W/R/B` handshake、
   ID、地址、len/size、data/strobe、response ordering、maintenance accepted 等。

这个比较不是逐拍比较所有内部寄存器，也不是比较单个 event 名字后就结束；它比较的是
需求相关的外部协议行为和响应语义。内部实现可以不同，但不能改变可观察协议、响应顺序、
数据、ready/backpressure 约束。

第三层是 RTL VCS contracts。当前全量 contract 通过 53/53，覆盖 top/compat/core/bridge
的 directed 行为，并在近期 RTL-only DC hygiene 后复跑过。

已经覆盖的关键 TB 类别包括：

- 地址分类：DDR/SDRAM `>=0x4000_0000`，MMIO 其它地址，mapped local window。
- DDR 形状：4B/8B/16B/32B/64B read/write，DDR 固定 256-bit beat，64B 为 2 beat。
- MMIO 形状：仅 32-bit / 1 beat；unsupported wider MMIO ready=0 且不外发 AXI。
- Outstanding/ID：read/write 独立，ID reuse/release，response route 不串线。
- Same-line AR/AW 约束：同一 hazard granule 上 pending read/write 时，不允许相反方向提前 accepted。
- Lower response 不回压：upstream response held 时，DDR/MMIO `RREADY/BREADY` 不被错误拉低。
- Maintenance drain/recovery：`invalidate_all`、`invalidate_line`、reconfig、dirty resident、
  pending lower response、held upstream response、multi-master representative cases。
- Dirty victim / refill：dirty victim writeback、refill、post-B hit、cache read/write miss
  与 MMIO 并发代表场景。
- 固定随机 seed suite：32 个 maintenance/recovery seed，作为扰动覆盖，不继续逐轮无限扩大。

## Linux / 性能 gate

Linux quick gate 的用途不是证明 RTL 等价，而是确认 production C++ 语义修改没有造成
明显功能或性能回退。最近一次 large + `CONFIG_BPU` 结果：

- 300k：cycles `120687 -> 120687`，commits `300001 -> 300001`，IPC
  `2.485777 -> 2.485777`，loads/stores `40586/51609 -> 40586/51609`。
- 5M：cycles `2078844 -> 2078844`，commits `5000005 -> 5000005`，IPC
  `2.405185 -> 2.405185`，loads/stores `530423/921658 -> 530423/921658`。
- L1D AMAT、miss penalty、AXI read latency、LLC->DDR read avg 均 exact match。

因此，最近已验证的 production C++ queue / invalidate-line 相关语义修复没有可观测性能
回退。后续只要 production C++/RTL 再变化，就需要先跑 300k，正常后再跑 5M，并报告
cycles、IPC、commit/load/store delta，不能只写是否 error。

## 当前不能保证什么

不能把当前结论理解为“只要 C++ 模拟器不出错，RTL 就一定不会出错”。更准确的说法是：
在当前已冻结的属性矩阵、固定 seed、formal invariant、RTL contract、Linux gate 所覆盖
的行为上，C++ reference 与 RTL 的可观察行为已经收敛；未覆盖的新语义、DC 后引入的
RTL 修改、或完整形式端到端状态空间，仍需要按变更触发回归。

当前仍 open 的工程项：

- Full DC/timing signoff：需要等待 9T20 + SMIC12 SRAM macro 的 full/top 1GHz 结果。
- 长期端到端 formal EC：如果继续推进，应优先走 production helper 和 table-oracle /
  state-IO cutpoint，而不是 monolithic top 直接塞进 hw-cbmc。
- Production 路径变化后的 Linux/image 长期回归：当前文档不替代未来改动后的重跑。

## 重跑策略

仅文档、测试说明、DC 状态记录变化：不需要重跑 Linux gate，也不改变现有 EC 结论。

production C++ 变化：至少重跑 C++ regression、受影响 trace/TB、Linux 300k；若 300k
正常，再跑 5M。

production RTL 变化：至少重跑 `git diff --check`、受影响 targeted VCS/TB、全量 RTL
contracts；若改变可观察语义，还要同步更新 C++ reference/trace 并重跑 C++ regression。

DC/timing 修正引入 RTL 结构变化：先判断是否改变可观察协议行为；若改变，按 production
RTL/C++ 变化处理；若只是 invalid payload reset/clear 这类 RTL-only hygiene，也至少跑
targeted VCS 与全量 RTL contracts。

formal harness 变化：只把默认 timeout 内稳定返回 `VERIFICATION SUCCESSFUL` 的入口加入
`formal/run_passed_hw_cbmc.sh`；experimental/non-stable 入口不能作为生产失败结论。

## 参考文档

- `formal/README_CN.md`：hw-cbmc 入口与 stable/non-stable 状态。
- `docs/dual_axi_ec_closure_plan_CN.md`：短期 EC freeze policy、deterministic matrix、
  seed suite、formal invariant gate。
- `docs/dual_axi_verification_checklist_CN.md`：历史覆盖证据与日志索引。
- `docs/formal_table_oracle_cutpoints_CN.md`：table-oracle / state-IO cutpoint 规划。
- `docs/dual_axi_goal_audit_20260506_CN.md`：Linux gate、EC gate、DC gate 的最新审计。
- `rtl/dc/README_CN.md`：DC/timing 状态与脚本要求。
