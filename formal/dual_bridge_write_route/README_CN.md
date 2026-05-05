# dual_bridge_write_route

这个 formal 用例把实际生产 RTL `axi_llc_axi_bridge.v` 和
`axi_llc_axi_bridge_dual.v` 绑定到一个小参数 wrapper 中，检查 4B cache
write 在双外部 AXI 口上的路由、基础 AW/W 形态，以及 unsupported MMIO
大 write 不被接受且不逃逸到下游 AXI 口。

覆盖点：

- 地址 `>= 0x4000_0000` 的写请求只走 DDR AXI 口。
- 地址 `< 0x4000_0000` 的 4B 写请求只走 MMIO AXI 口。
- 写请求被接受后，正确端口会在有限窗口内发出 AW 和 W。
- DDR 小参数 wrapper 使用 8B beat，因此 AWLEN=0、AWSIZE=3。
- MMIO 使用固定 32-bit/1-beat 写，因此 AWLEN=0、AWSIZE=2。
- WSTRB/WLAST 与 4B 写请求一致。
- unsupported MMIO 大 write 的 upstream ready 必须为 0，且 DDR/MMIO
  `AW/W` 均不得发射。

限制：

- 为控制 hw-cbmc 状态空间，DDR 数据宽度在 wrapper 内缩小为 64-bit，
  pending 深度缩小为 1。
- 该用例验证写路由、unsupported MMIO 大 write 阻断和单 beat 写形态，
  不验证 B response 回收、多 outstanding interleaving 或完整子系统拓扑。
