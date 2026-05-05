# subsystem_dual_mode0_ddr_bypass_read_response

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

该 bounded formal smoke 直接实例化实际生产 `axi_llc_subsystem_dual.v`，在
`MODE_OFF`/direct-bypass 下覆盖未对齐 4B DDR read 的发起和返回路径。8B 对齐 DDR
read 已拆到 `formal/subsystem_dual_mode0_ddr_bypass_read_response_8b`，避免把实际
subsystem top 的 request size/offset 做成符号值后导致 hw-cbmc 状态空间超时。

实际生产对象：

- C/C++ helper：`include/axi_dual_port_route_shape.h` 中
  `axi_bridge_downstream_read_issue_shape` 和 `axi_bridge_read_pack64`。
- C++ 消费者：`axi_interconnect/AXI_Interconnect.cpp` 的
  `make_downstream_read_issue` 与 direct read response extract 路径。
- RTL top：`rtl/src/axi_llc_subsystem_dual.v`，内部使用实际 compat、dual bridge、
  single bridge 和 read-pack helper。

覆盖范围：

- mode0/direct DDR 未对齐 4B read 必须对齐到 DDR beat 地址，`ARLEN/ARSIZE`
  与 C++ helper 一致，不得误走 MMIO 或写通道。
- DDR `R` 返回后必须保持 `RREADY` 可接收，并按原始 read 地址到 issued 地址的 byte
  offset 截取 aligned beat 中的数据。
- upstream `read_resp_valid/id/data` 必须与生产 C helper 的 `axi_bridge_read_pack64`
  一致。

说明：

- 本入口的 `harness.c` 支持通过宏复用为其它确定性 case；稳定 manifest 中的 8B case
  使用 `harness_8b.c` 复用同一实际 RTL top 和断言集合。

运行：

```sh
formal/subsystem_dual_mode0_ddr_bypass_read_response/run_hw_cbmc.sh
```
