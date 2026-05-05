# Dual Port Hazard Scoreboard Formal Smoke

这个目录验证生产 RTL helper `axi_llc_dual_port_hazard_scoreboard.v` 的小参数状态行为。

状态：已通过，并已纳入 `formal/run_passed_hw_cbmc.sh`。

实际生产对象：

- RTL helper：`rtl/src/axi_llc_dual_port_hazard_scoreboard.v`
- 消费者：`rtl/src/axi_llc_axi_bridge_dual.v`

覆盖：

- DDR `AR` fire 后，同 port 同 line `AW` 会看到 pending-read hazard。
- 匹配 `R last` fire 后，该 read hazard 被释放。
- DDR `AW` fire 后，同 port 同 line `AR` 会看到 pending-write hazard。
- 匹配 `B` fire 后，该 write hazard 被释放。
- DDR/MMIO 同拍各发一笔 `AR` 时，在 2-entry 小参数实例中会占满 read scoreboard，
  并对各自 port/line 产生 pending-read hazard。

运行方式：

```sh
formal/dual_port_hazard_scoreboard/run_hw_cbmc.sh
```

说明：

- 2026-05-03 生产 RTL 默认参数已缩到
  `READ_HAZARD_COUNT=2 / WRITE_HAZARD_COUNT=2`，用于让 hw-cbmc 的未参数化 generic
  实例快速完成转换和求解。
- 实际生产 bridge 实例仍在 `axi_llc_axi_bridge_dual.v` 中显式覆盖为 64-entry，不受
  默认参数变化影响。
