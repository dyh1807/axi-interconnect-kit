# dual_bridge_same_line_read_blocks_write

状态：已通过，并已纳入 `formal/run_passed_hw_cbmc.sh`。

这个 bounded formal smoke 实例化实际生产 `axi_llc_axi_bridge_dual.v`，验证同 line
`AR -> AW` hazard：

- DDR read `AR` 发出后，在对应 `R last` 被外部 `RREADY` 接收前，同 line DDR write
  不得发出 `AW/W`。
- `R last` 被接收后，同 line write 必须继续发出 `AW/W`。
- wrapper 只做参数缩小、tie-off 和观测信号暴露；验证对象仍是生产 bridge/dual-bridge
  module body。
