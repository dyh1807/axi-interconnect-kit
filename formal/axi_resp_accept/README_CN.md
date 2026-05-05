# AXI Response Accept Formal Smoke

这个目录验证生产 C helper 与生产 RTL helper `axi_llc_axi_resp_accept.v` 的 AXI
response ready/accept 控制一致性。

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_resp_accept.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖：

- `RREADY` 只取决于是否找到匹配 read slot，不被 upstream cache/bypass
  `resp_ready` 回压。
- `rd_resp_accept` 等价于 `RVALID && read slot match`。
- `BREADY` 需要匹配 write slot 且对应 source-local write response queue 有空间。
- `wr_resp_accept` 等价于 `BVALID && BREADY`。

运行方式：

```sh
formal/axi_resp_accept/run_hw_cbmc.sh
```
