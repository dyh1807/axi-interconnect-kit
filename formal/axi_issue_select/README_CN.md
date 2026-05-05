# AXI Bridge Issue Select Formal

这个目录验证生产 C helper 与生产 RTL helper `axi_llc_axi_issue_select.v` 的 queue-head
发射选择逻辑一致。

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_issue_select.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- `queue_has_entry && slot_valid && ready_to_issue && !issue_done` 才产生 issue valid。
- cache source 不允许产生 mode2 DDR aligned 修正。
- bypass mode2 DDR aligned 时，对外 issue addr/size 按 32B beat 或 64B line 对齐。
- AXI ID、W beat index 和 total beats 直接来自当前 queue-head slot。

运行方式：

```sh
formal/axi_issue_select/run_hw_cbmc.sh
```
