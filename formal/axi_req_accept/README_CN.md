# AXI Request Accept Formal Smoke

这个目录验证生产 C helper 与生产 RTL helper `axi_llc_axi_req_accept.v` 的 bridge
source-side request acceptance 控制一致性。

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_req_accept.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖：

- cache source 对 bypass source 的接受优先级。
- read request 只有在 read pending slot、AXI read ID 和 read issue queue 都有资源时接受。
- write request 只有在 write pending slot、AXI write ID、AW issue queue 和 W issue queue
  都有资源时接受。
- 接受后记录的 slot、AXI ID 和 total beats 来自对应 read/write 资源与对应 source。

运行方式：

```sh
formal/axi_req_accept/run_hw_cbmc.sh
```
