# dual_port_slot_hazard formal smoke

该入口验证生产 C helper 与生产 RTL helper `rtl/src/axi_llc_dual_port_slot_hazard.v`
一致，用于
`axi_llc_dual_port_hazard_scoreboard.v` 中 DDR/MMIO 共享 scoreboard entry 的
slot hazard 计算。

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_dual_port_slot_hazard.v`
- 消费者：`rtl/src/axi_llc_dual_port_hazard_scoreboard.v`

覆盖范围：

- primary port 没有第一个空槽时必须报告 slot hazard。
- secondary port 只有在没有第一个空槽，或 primary port 本周期实际 fire 且没有第二个空槽时，
  才报告 slot hazard。
- primary port 只是 valid 但没有 fire 时，不应因为“可能占用第一个空槽”而阻塞 secondary port。

运行：

```sh
formal/dual_port_slot_hazard/run_hw_cbmc.sh
```
