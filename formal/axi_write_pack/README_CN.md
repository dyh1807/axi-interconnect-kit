# AXI Bridge Write Pack Formal

这个目录验证生产 C helper 与生产 RTL helper `axi_llc_axi_write_pack.v` 的 AXI
`W` channel data/strobe 打包逻辑一致。

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_write_pack.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- 普通 cacheline write 按 beat index 从 line data/strb 切出当前 AXI beat。
- mode2 DDR-aligned write 按 `req_addr - issued_addr` 把窄写数据移入 256-bit beat。
- `WSTRB` 与 `WDATA` 使用同一 byte 映射，不允许二次地址移位。
- 小参数实例覆盖 8B line / 4B AXI beat，用于保持状态空间可快速求解。

运行方式：

```sh
formal/axi_write_pack/run_hw_cbmc.sh
```
