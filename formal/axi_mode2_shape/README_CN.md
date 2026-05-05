# AXI Bridge Mode2 Shape Formal

这个目录验证生产 C helper 与生产 RTL helper `axi_llc_axi_mode2_shape.v` 的 mode2
DDR-aligned issue shape 逻辑一致。

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_mode2_shape.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`
- 消费者：`rtl/src/axi_llc_axi_issue_select.v`

覆盖范围：

- 判断请求是否可以落在单个 AXI beat 内。
- 单 beat 请求按 AXI data bytes 对齐，issue size 为 `AXI_DATA_BYTES-1`。
- 跨 beat/line 请求按 cacheline bytes 对齐，issue size 为 `LINE_BYTES-1`。
- 小参数实例覆盖 8-bit addr / 8B line / 4B AXI beat。

运行方式：

```sh
formal/axi_mode2_shape/run_hw_cbmc.sh
```
