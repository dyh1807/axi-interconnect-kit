# AXI Beat Shape Formal Smoke

这个目录验证生产 C helper 与生产 RTL helper 的 AXI beat 形状一致性。

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_beat_shape.v`

覆盖：

- 32B beat：用于 DDR/SDRAM 口。
- 4B beat：用于 MMIO 口。
- `total_size -> total_beats`
- `total_size -> axi_len`
- `beat_bytes -> axi_size`

运行方式：

```sh
formal/axi_beat_shape/run_hw_cbmc.sh
```
