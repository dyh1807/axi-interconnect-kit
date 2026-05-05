# dual_bridge_ddr_multibeat_read

这个 bounded formal smoke 实例化实际生产 `axi_llc_axi_bridge_dual.v`，并通过缩小参数
验证 DDR cache read 的 2-beat 行为：

- formal 参数为 16B line、8B DDR beat，对应生产 64B line、32B DDR beat 的同构
  2-beat transaction。
- 验证 DDR `AR` 只走 DDR 端口，`ARLEN=1`、`ARSIZE=3`。
- 注入两拍 `R`，第一拍 `RLAST=0` 时不能产生 cache response。
- 第二拍 `RLAST=1` 后必须返回 cache response，并检查 request id、response code 和
  低/高 64-bit 数据合并顺序。
