# subsystem_dual_mode0_ddr_bypass_align

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

该 bounded formal smoke 直接实例化实际生产 `axi_llc_subsystem_dual.v`，在
`MODE_OFF`/direct-bypass 下覆盖 DDR read/write 的 C++/RTL issue-shape 一致性。

实际生产对象：

- C/C++ helper：`include/axi_dual_port_route_shape.h` 中
  `axi_bridge_downstream_read_issue_shape`、
  `axi_bridge_downstream_write_issue_shape` 和 `axi_bridge_write_pack64`。
- C++ 消费者：`axi_interconnect/AXI_Interconnect.cpp` 的
  `make_downstream_read_issue` / `make_downstream_write_issue`。
- RTL top：`rtl/src/axi_llc_subsystem_dual.v`，内部使用实际 compat、dual bridge、
  single bridge 和 pack helper。

覆盖范围：

- mode0/direct DDR read 覆盖 4B 未对齐 offset 0..4 与 8B 对齐两类请求，必须对齐到
  DDR beat 地址，`ARLEN/ARSIZE` 与 C++ helper 一致，不得误走 MMIO。
- mode0/direct DDR 未对齐 4B write 必须对齐到 DDR beat 地址，`AWLEN/AWSIZE`
  与 C++ helper 一致，不得误走 MMIO。
- write payload/strobe 必须按原始地址到 issued 地址的 byte offset 移位到 DDR beat
  内正确 byte lane，且单 beat `WLAST=1`。

运行：

```sh
formal/subsystem_dual_mode0_ddr_bypass_align/run_hw_cbmc.sh
```
