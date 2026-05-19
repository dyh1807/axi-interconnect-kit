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
- 生产配置 slot-ID mode：`ENTRY_COUNT=4`、`AXI_ID_BITS=2`，ID 数覆盖所有 pending
  slot，slot index 即 AXI ID。
- fallback tracked-ID mode：`ENTRY_COUNT=5`、`AXI_ID_BITS=2`，pending entry 数超过
  AXI ID 数，必须使用 stored ID 做 first-free-ID 和 response match。

运行方式：

```sh
formal/axi_pending_scan/run_hw_cbmc.sh
formal/axi_pending_scan/run_hw_cbmc_fallback.sh
```
