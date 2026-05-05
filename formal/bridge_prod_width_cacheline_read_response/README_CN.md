# bridge_prod_width_cacheline_read_response

状态：已通过，并已纳入稳定 `formal/run_passed_hw_cbmc.sh`。

该 bounded formal smoke 直接实例化实际生产 `axi_llc_axi_bridge.v`，使用
production-width 参数：

- 64B line / 512-bit cacheline payload。
- 32B DDR beat / 256-bit AXI data。
- 64B read response buffer。

覆盖目标：

- cache source 发出 64B DDR cacheline read 后，实际 bridge 产生单笔 AXI read
  transaction。
- `ARADDR` 保持 64B-aligned cacheline 地址，`ARLEN=1`，`ARSIZE=5`，`ARBURST=INCR`。
- 外部 `R` 通道接收两拍 256-bit beat，第一拍 `RLAST=0` 时不得提前回 upstream。
- 第二拍 `RLAST=1` 后，实际 bridge 必须返回 512-bit cache response。
- 返回的 upstream response `id/code/data` 必须匹配请求 ID、OKAY code 和低/高两拍
  256-bit payload 拼接结果。

该入口补齐 actual bridge production-width cacheline read 的 `R` payload/response
端到端窗口；组合层 256-bit beat merge 仍由 `formal/axi_read_pack_prod_width` 做更细
粒度覆盖。
