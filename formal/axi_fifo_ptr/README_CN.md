# AXI Bridge FIFO Pointer Formal

这个目录验证生产 C helper 与生产 RTL helper `axi_llc_axi_fifo_ptr.v` 的 FIFO
head/tail/count 更新逻辑一致。

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_fifo_ptr.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- push-only 推进 tail，count 加 1。
- pop-only 推进 head，count 减 1。
- push 与 pop 同拍发生时 head/tail 同时推进，count 保持不变。
- 无 push/pop 时 head/tail/count 保持不变。

运行方式：

```sh
formal/axi_fifo_ptr/run_hw_cbmc.sh
```
