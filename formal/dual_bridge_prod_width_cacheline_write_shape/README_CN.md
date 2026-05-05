# dual_bridge_prod_width_cacheline_write_shape

状态：实验入口，当前不纳入稳定 `formal/run_passed_hw_cbmc.sh`。

该 bounded formal smoke 实例化实际生产 `axi_llc_axi_bridge_dual.v` 和
`axi_llc_axi_bridge.v`，使用 production-width 参数：

- 64B line / 512-bit cacheline payload。
- 32B DDR beat / 256-bit AXI data。
- 64B read response buffer。

覆盖目标：

- cache source 发出 64B DDR cacheline write 后，实际 bridge 必须走 DDR 口，不得误走
  MMIO 口。
- `AWADDR` 保持 64B-aligned cacheline 地址，`AWLEN=1`，`AWSIZE=5`。
- `W` 通道必须发出两拍 256-bit beat：第一拍 `WLAST=0`、第二拍 `WLAST=1`。
- 两拍 `WSTRB` 均为 32-bit 全 1。
- 固定 512-bit payload 被拆成低 256-bit beat 和高 256-bit beat，证明 production-width
  actual bridge 端到端连接到生产 `axi_llc_axi_write_pack.v`。

当前实验结论：

- 即使 payload 固定为常量，完整 production-width dual bridge 仍会在 180s timeout；
  已观察到规模约 66.6M variables / 188.6M clauses。
- 因此稳定 smoke 改为直接实例化 single `axi_llc_axi_bridge.v` 的
  `bridge_prod_width_cacheline_aw_shape` / `bridge_prod_width_cacheline_ar_shape`，
  并将 payload packing 保持在 `formal/axi_write_pack_prod_width`。
