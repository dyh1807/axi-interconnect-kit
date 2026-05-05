# AXI Bridge Response Route Formal

这个目录验证生产 C helper 与生产 RTL helper `axi_llc_axi_resp_route.v` 的 response
enqueue route 控制一致。

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_resp_route.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- completed read 根据 pending slot owner 进入 cache/bypass read response queue。
- read response queue 没有空间时不得 dequeue completed read slot。
- write `B` response 根据 pending slot owner 进入 cache/bypass write response queue。
- `wr_match_rsp_space` 选择对应 owner 的 write response queue 空间，并反馈到
  `axi_llc_axi_resp_accept.v` 的 `BREADY` 门控。

运行方式：

```sh
formal/axi_resp_route/run_hw_cbmc.sh
```
