# AXI ID Shape Formal

状态：已通过，已加入 `formal/run_passed_hw_cbmc.sh`。

该入口验证生产 C helper 与生产 RTL helper 的 AXI ID width conversion 语义一致：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_id_shape.v`
- RTL 消费者：`rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- 6-bit AXI ID zero-extend 到 8-bit 时不得截断高于 bit2 的 ID。
- 3-bit AXI ID zero-extend 到 8-bit 时只保留低 3 bit。
- 8-bit AXI ID resize 到 6-bit 时只保留低 6 bit。
- 6-bit 到 6-bit 保持不变。

该 smoke 用来防止 C++/RTL 在 lower AXI ID 宽度上再次出现旧的 `& 0x7`
截断类问题。
