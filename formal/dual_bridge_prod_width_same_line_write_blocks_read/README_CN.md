# dual_bridge_prod_width_same_line_write_blocks_read

该入口直接实例化实际 `axi_llc_axi_bridge_dual.v`，使用生产宽度参数：

- cache line：64B / 512-bit
- DDR AXI data：32B / 256-bit
- read/write pending：各 1 entry

验证目标：同一 cache line 的 DDR write 已发出、但 `B` 尚未返回前，后续同 line read
可以被上游接收排队，但不得向 DDR 发出 `AR`。该入口只证明 production-width 的阻塞
安全属性；完成后的恢复发出由小参数 same-line proof 与 production-width read shape proof
分担覆盖。
