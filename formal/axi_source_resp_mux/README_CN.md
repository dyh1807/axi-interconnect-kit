# AXI Bridge Source Response Mux Formal

这个目录验证生产 C helper 与生产 RTL helper `axi_llc_axi_source_resp_mux.v` 的
source-local response mux 逻辑一致。

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_source_resp_mux.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- read response valid 时优先返回 read response。
- 没有 read response 且 write response valid 时返回 write response，rdata 为 0。
- `rd_pop` / `wr_pop` 只在对应 source 的 `resp_ready` 允许时产生。
- 同一拍不会同时 pop read response 和 write response。

运行方式：

```sh
formal/axi_source_resp_mux/run_hw_cbmc.sh
```
