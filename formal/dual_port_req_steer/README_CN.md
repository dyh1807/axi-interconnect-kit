# Dual Port Request Steer Formal Smoke

这个目录验证生产 C helper 与生产 RTL helper 的请求分流/ready 合同一致。

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_dual_port_req_steer.v`
- 消费者：`rtl/src/axi_llc_axi_bridge_dual.v`

覆盖：

- DDR 请求只驱动 DDR valid，并从 DDR ready 回传 upstream ready。
- supported MMIO 请求只驱动 MMIO valid，并从 MMIO ready 回传 upstream ready。
- unsupported MMIO 请求不驱动任一端口，且 upstream ready 为 0。
- `req_valid=0` 时不产生下游 valid，但 ready 仍只反映所选端口/支持性，保持标准
  valid-ready 组合合同。

运行方式：

```sh
formal/dual_port_req_steer/run_hw_cbmc.sh
```
