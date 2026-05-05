# dual_bridge_prod_helper_write_issue_shape

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

targeted log：

`local_debug/hw_cbmc_dual_bridge_prod_helper_write_issue_shape_20260505_220230.log`

覆盖对象：

- RTL：实际 `rtl/src/axi_llc_axi_bridge_dual.v`
- C reference：生产头文件 `include/axi_dual_port_route_shape.h` 中的
  `axi_dual_port_route_shape()` 与 `axi_bridge_downstream_write_issue_shape()`
- 参数：64B line / 32B DDR beat / 64B upstream response / 1-entry pending

覆盖范围：

- nondet DDR/MMIO bypass write request 被实际 dual bridge route/issue 后，外部
  `AWADDR/AWLEN/AWSIZE/AWBURST` 必须匹配 production C helper 的结果。
- DDR case 使用 `bypass_req_mode2_ddr_aligned=1`，对应 mode0/direct DDR 侧固定
  256-bit aligned write 的硬件可实现语义。
- MMIO case 覆盖 4B supported 和非 4B unsupported；unsupported 必须
  `bypass_req_ready=0` 且不发外部 `AR/AW`。
- 该入口实例化实际 dual bridge；formal top 只负责参数缩小和 tie-off，不重写 RTL 行为。

运行：

```sh
formal/dual_bridge_prod_helper_write_issue_shape/run_hw_cbmc.sh
```

明确不覆盖：

- 不覆盖 write data/strobe payload、unsupported `WVALID` no-escape、`B` response
  route，也不宣称完整 C++ class 与 RTL top 端到端等价。它只收敛一个可控的
  production-helper/actual-RTL EC 切片。
