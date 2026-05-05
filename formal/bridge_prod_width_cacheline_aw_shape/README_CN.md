# bridge_prod_width_cacheline_aw_shape

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

该 bounded formal smoke 直接实例化实际生产 `axi_llc_axi_bridge.v`，在
64B line / 32B DDR beat / 64B read response buffer 的 production-width 参数下，
验证 64B cacheline write 的 AXI `AW` 地址通道形状：

- 请求被 bridge 接受。
- `AWADDR` 保持 64B-aligned cacheline 地址。
- `AWLEN=1`，表示 2 个 256-bit beat。
- `AWSIZE=5`，表示 32B beat。
- `AWBURST=INCR`。

该 proof 只看地址通道，避免完整 512-bit payload 和 response 状态空间导致 hw-cbmc
超时；payload packing 由 `formal/axi_write_pack_prod_width` 覆盖，两拍 `W` 顺序由
小参数 actual bridge smoke 覆盖。
