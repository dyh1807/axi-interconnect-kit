# dual_bridge_mode2_aligned_write

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

这个 bounded formal smoke 实例化实际生产 `axi_llc_axi_bridge_dual.v` 和
`axi_llc_axi_bridge.v`，验证 bypass mode2 DDR-aligned write 的实际 bridge 路径：

- bypass mode2 write 在 DDR 地址上被 DDR bridge 接受，不误走 MMIO。
- 4B write 从 `req_addr=issue_addr+2` 对齐成 8B DDR beat，`AWADDR` 为
  `issue_addr`，`AWLEN=0`，`AWSIZE=3`。
- `WDATA/WSTRB` 按 `req_addr - issue_addr` 移位，覆盖生产 `axi_llc_axi_write_pack.v`
  在 actual bridge 中的接入。
- DDR `B` 返回后，write response 回到 bypass source 的原 ID/code。

当前 formal 参数缩小为 8B line / 8B DDR beat；结构上对应生产 64B line / 32B DDR
beat 的 mode2 aligned write path。
