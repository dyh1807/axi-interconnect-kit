# dual_bridge_same_line_write_blocks_read

状态：已通过，并已纳入 `formal/run_passed_hw_cbmc.sh`。

这个 bounded formal smoke 实例化实际生产 `axi_llc_axi_bridge_dual.v`，验证同 line
`AW -> AR` hazard：

- DDR write `AW/W` 发出后，在对应 `B` 被外部 `BREADY` 接收前，同 line DDR read
  不得发出 `AR`。
- `B` 被接收后，同 line read 必须继续发出 `AR`。
- wrapper 只做参数缩小、tie-off 和观测信号暴露；验证对象仍是生产 bridge/dual-bridge
  module body。
