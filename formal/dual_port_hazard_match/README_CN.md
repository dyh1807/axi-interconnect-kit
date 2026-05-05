# Dual Port Hazard Match Formal Smoke

这个目录验证生产 C helper 与生产 RTL helper `axi_llc_dual_port_hazard_match.v`
一致。

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_dual_port_hazard_match.v`
- 消费者：`rtl/src/axi_llc_dual_port_hazard_scoreboard.v`

覆盖：

- DDR line/id match 只对 DDR port entry 生效。
- MMIO line/id match 只对 MMIO port entry 生效。
- invalid entry 不产生任何 match。

运行方式：

```sh
formal/dual_port_hazard_match/run_hw_cbmc.sh
```
