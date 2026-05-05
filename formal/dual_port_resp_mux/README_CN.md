# Dual Port Response Mux Formal Smoke

这个目录验证生产 C helper 与生产 RTL helper 的 DDR/MMIO response mux 与 ready
回压合同一致。

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_dual_port_resp_mux.v`
- 消费者：`rtl/src/axi_llc_axi_bridge_dual.v`

覆盖：

- MMIO response valid 时优先选择 MMIO。
- MMIO 不 valid 时选择 DDR。
- selected port 才收到 upstream `resp_ready`。
- non-selected port 被 backpressure。

运行方式：

```sh
formal/dual_port_resp_mux/run_hw_cbmc.sh
```
