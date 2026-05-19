# AXI Bridge Mode2 Shape Single4 Formal

这个目录验证生产 RTL helper `axi_llc_axi_mode2_shape.v` 在 4B line / 4B AXI beat
single-beat 特化路径下，与生产 C helper `axi_bridge_mode2_shape()` 保持一致。

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_mode2_shape.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- `LINE_BYTES == AXI_DATA_BYTES == 4` 时，issue addr 恒按 4B 对齐。
- issue size 恒为 `3`，与 generic C helper 在该参数下的结果一致。
- `single_axi_beat` 仍由原生产 helper 判定，不因为 issue addr/size 特化而改变。

运行方式：

```sh
formal/axi_mode2_shape_single4/run_hw_cbmc.sh
```
