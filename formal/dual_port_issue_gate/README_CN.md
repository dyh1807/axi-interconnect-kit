# Dual Port Issue Gate Formal Smoke

这个目录验证生产 C helper 与生产 RTL helper 的单 AXI port `AR/AW` 发射屏蔽合同一致。

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_dual_port_issue_gate.v`
- 消费者：`rtl/src/axi_llc_axi_bridge_dual.v`

覆盖：

- `AR` 存在 slot/pending-write hazard 时不能发出，也不给内部 bridge `arready`。
- `AW` 存在 slot/pending-read hazard 时不能发出，也不给内部 bridge `awready`。
- 同周期同 line 的 `AR/AW` 同时可发时，`AR` 优先，`AW` 被屏蔽。
- 不同 line 时，只要没有已有 hazard，`AR/AW` 可在同周期各自发出。

运行方式：

```sh
formal/dual_port_issue_gate/run_hw_cbmc.sh
```
