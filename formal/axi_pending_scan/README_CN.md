# AXI Pending Scan Formal Smoke

这个目录验证生产 C helper 与生产 RTL helper `axi_llc_axi_pending_scan.v` 的 pending
table 组合扫描一致性。

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_pending_scan.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖：

- first-free pending slot。
- first-free AXI ID。
- response AXI ID match slot。
- first completed read slot。

运行方式：

```sh
formal/axi_pending_scan/run_hw_cbmc.sh
```
