# Dual Port Hazard Scoreboard One-Entry Formal Smoke

状态：辅助 smoke，已通过；主稳定入口使用
`formal/dual_port_hazard_scoreboard/run_hw_cbmc.sh` 的 2-entry 覆盖。

该入口实例化实际生产 RTL `axi_llc_dual_port_hazard_scoreboard.v`，但把参数缩到
1 个 read entry / 1 个 write entry，用于快速覆盖单 entry 状态转移。

实际生产对象：

- RTL helper：`rtl/src/axi_llc_dual_port_hazard_scoreboard.v`
- 消费者：`rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- DDR `AR` fire 后，同 port 同 line `AW` 看到 pending-read hazard。
- 匹配 `R last` fire 后，该 read hazard 被释放。
- DDR `AW` fire 后，同 port 同 line `AR` 看到 pending-write hazard。
- 匹配 `B` fire 后，该 write hazard 被释放。
- 单 entry 被占用时，对应 read/write slot hazard 必须拉高。

明确不覆盖：

- DDR/MMIO 同周期双 fire 需要第二个空槽的场景；该场景由
  `formal/dual_port_slot_hazard` 覆盖组合 slot 规则。
- 多 entry 搜索优先级和大参数规模；完整 scoreboard harness 仍保留为实验入口。

运行：

```sh
formal/dual_port_hazard_scoreboard_one_entry/run_hw_cbmc.sh
```

当前观察：

- 2026-05-03 该 1-entry 辅助入口已通过。
- 2-entry 主入口 `formal/dual_port_hazard_scoreboard/run_hw_cbmc.sh` 也已通过并纳入
  `formal/run_passed_hw_cbmc.sh`；因此本目录只作为更小约束的调试入口保留。
