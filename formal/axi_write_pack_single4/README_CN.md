# AXI Bridge Write Pack Single4 Formal

这个目录验证生产 RTL helper `axi_llc_axi_write_pack.v` 在 4B line / 4B AXI beat
single-beat 特化路径下，与生产 C helper `axi_bridge_write_pack64()` 保持一致。

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_write_pack.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- 普通 4B write 直接透传 `WDATA/WSTRB`。
- mode2 DDR-aligned write 按 `req_addr - issued_addr` 左移有效 byte 到 4B beat 内。
- `WSTRB` 与 `WDATA` 使用同一 byte 映射。

运行方式：

```sh
formal/axi_write_pack_single4/run_hw_cbmc.sh
```
