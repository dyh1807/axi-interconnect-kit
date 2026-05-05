# dual_bridge_prod_width_same_line_read_blocks_write

该入口直接实例化实际 `axi_llc_axi_bridge_dual.v`，使用生产宽度参数：

- cache line：64B / 512-bit
- DDR AXI data：32B / 256-bit
- read/write pending：各 1 entry

验证目标：同一 cache line 的 DDR read 已发出、但 `R` 尚未返回前，后续同 line write
可以被上游接收排队，但不得向 DDR 发出 `AW/W`。该入口只证明 production-width 的阻塞
安全属性；完成后的恢复发出由小参数 same-line proof 与 production-width write shape proof
分担覆盖，避免把 bounded smoke 放大成不可持续的大 SAT 问题。
