# AXI Bridge Read Pack Formal

这个目录验证生产 C helper 与生产 RTL helper `axi_llc_axi_read_pack.v` 的 AXI
`R` channel beat merge 与 mode2 aligned read extract 逻辑一致。

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_read_pack.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- 普通 read 按 beat index 把 AXI `RDATA` 合并到 read response buffer。
- 非 mode2 aligned read 的最终返回数据等于合并后的 buffer。
- mode2 DDR-aligned read 按 `req_addr - issued_addr` 从合并 buffer 中提取返回窗口。
- 小参数实例覆盖 8B response / 4B AXI beat，用于保持状态空间可快速求解。

运行方式：

```sh
formal/axi_read_pack/run_hw_cbmc.sh
```
