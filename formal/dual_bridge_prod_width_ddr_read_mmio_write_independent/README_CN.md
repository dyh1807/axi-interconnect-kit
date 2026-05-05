# dual_bridge_prod_width_ddr_read_mmio_write_independent

该入口直接实例化实际 `rtl/src/axi_llc_axi_bridge_dual.v`，参数使用生产宽度
`LINE_BYTES=64`、`DDR_AXI_DATA_BYTES=32`。

覆盖目标：

- 同周期接受 cache source 的 DDR 64B read 与 bypass source 的 MMIO 32-bit write。
- DDR `AR` 与 MMIO `AW` 通道必须同时可见，不允许因为共享 bridge/scoreboard 控制而串行化。
- DDR `AR` 必须是 2-beat 256-bit cacheline read，MMIO `AW/W` 必须是 1-beat 32-bit write。
- MMIO `B` 先返回时，bypass write response id/code 正确，且不阻塞 pending DDR read 的 `RREADY`。
- DDR 两拍 `R` 后，cache read response id/data/code 正确，且交叉读写场景不得误发无关通道。

该证明仍是 bridge-level bounded formal，不替代实际 C++ reference 与 RTL subsystem 的
端到端 hw-cbmc EC。
