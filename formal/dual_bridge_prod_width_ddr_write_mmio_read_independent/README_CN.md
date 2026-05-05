# dual_bridge_prod_width_ddr_write_mmio_read_independent

该入口直接实例化实际 `rtl/src/axi_llc_axi_bridge_dual.v`，参数使用生产宽度
`LINE_BYTES=64`、`DDR_AXI_DATA_BYTES=32`。

覆盖目标：

- 同周期接受 cache source 的 DDR 64B write 与 bypass source 的 MMIO 32-bit read。
- DDR `AW` 与 MMIO `AR` 通道必须同时可见，不允许因为单外部口或共享内部选择而串行化。
- DDR `AW/W` 必须是 2-beat 256-bit cacheline write，MMIO `AR` 必须是 1-beat 32-bit read。
- MMIO `R` 在 DDR write 仍 pending 时返回，`RREADY` 必须可接收，bypass response
  id/data/code 正确。
- 该 mixed read/write 场景不得误发 DDR read 或 MMIO write channel。

该证明仍是 bridge-level bounded formal，不替代实际 C++ reference 与 RTL subsystem 的
端到端 hw-cbmc EC。
