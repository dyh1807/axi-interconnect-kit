# dual_bridge_ddr_multibeat_write

这个 bounded formal smoke 实例化实际生产 `axi_llc_axi_bridge_dual.v`，并通过缩小参数
验证 DDR cache write 的 2-beat 行为：

- formal 参数为 16B line、8B DDR beat，对应生产 64B line、32B DDR beat 的同构
  2-beat transaction。
- 验证 DDR `AW` 只走 DDR 端口，`AWLEN=1`、`AWSIZE=3`。
- 验证 `W` 通道顺序：第一拍输出低 64-bit 数据且 `WLAST=0`，第二拍输出高
  64-bit 数据且 `WLAST=1`。
- 当前专注 `AW/W` multi-beat shape；`B` response 回收由
  `formal/dual_bridge_write_b_response` 覆盖。
