# dual_bridge_prod_width_ddr_write_mmio_write_independent

这个入口验证实际 `axi_llc_axi_bridge_dual.v` 在生产宽度参数下的一个组合流：
同一周期接受 DDR 64B cacheline write 和 MMIO 32-bit write 后，两条外部 AXI 写通道
不得退化成互相串行化。

覆盖点：

- cache source 的 DDR 64B write 被接受，生成 DDR `AWLEN=1/AWSIZE=5`。
- bypass source 的 MMIO 32-bit write 被接受，生成 MMIO `AWLEN=0/AWSIZE=2`。
- `AWREADY` 被压低时，DDR/MMIO `AWVALID` 必须同时可见并保持可握手形状。
- `AW` 放行后，DDR first `W` beat 和 MMIO single `W` beat 必须同时可见；
  DDR `WSTRB=32'hffff_ffff` 且 first beat `WLAST=0`，MMIO `WSTRB=4'hf/WLAST=1`。
- 该场景是 production-width dual bridge 组合流 smoke；不是 full-top/cache 状态空间证明。
