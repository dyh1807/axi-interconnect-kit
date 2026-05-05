# bridge_prod_width_cacheline_write_shape

状态：已通过，并已计入稳定 `formal/run_passed_hw_cbmc.sh`。

该 bounded formal smoke 直接实例化实际生产 `axi_llc_axi_bridge.v`，使用
production-width 参数：

- 64B line / 512-bit cacheline payload。
- 32B DDR beat / 256-bit AXI data。
- 64B read response buffer。

覆盖目标：

- cache source 发出 64B DDR cacheline write 后，实际 bridge 产生单笔 AXI write
  transaction。
- `AWADDR` 保持 64B-aligned cacheline 地址，`AWLEN=1`，`AWSIZE=5`。
- `W` 通道必须发出两拍 256-bit beat：第一拍 `WLAST=0`、第二拍 `WLAST=1`。
- 两拍 `WSTRB` 均为 32-bit 全 1。
- 固定 512-bit payload 被拆成低 256-bit beat 和高 256-bit beat，证明 production-width
  actual bridge 端到端连接到生产 `axi_llc_axi_write_pack.v`。

当前结论：

- 已在默认 180s timeout 内通过，规模约 43.4M variables / 120.7M clauses。
- 该入口补齐 actual bridge production-width cacheline write 的 `W` payload/`WSTRB`/
  `WLAST` 端到端窗口；`B` response 回收仍由小参数
  `formal/dual_bridge_write_b_response` 覆盖。
