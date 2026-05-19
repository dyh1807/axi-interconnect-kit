# AXI Bridge Read Pack Single4 Formal

这个目录验证生产 RTL helper `axi_llc_axi_read_pack.v` 在 4B response / 4B AXI beat
single-beat 特化路径下，与生产 C helper `axi_bridge_read_pack64()` 保持一致。

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_read_pack.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- beat 0 把 32-bit `RDATA` 合并到 4B response buffer。
- 非 mode2 aligned read 的最终返回数据等于合并后的 buffer。
- mode2 DDR-aligned read 按 `req_addr - issued_addr` 做 4B 窗口提取。

运行方式：

```sh
formal/axi_read_pack_single4/run_hw_cbmc.sh
```
