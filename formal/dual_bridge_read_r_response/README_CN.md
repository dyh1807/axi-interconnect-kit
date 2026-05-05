# dual_bridge_read_r_response

这个 formal 用例绑定实际生产 RTL `axi_llc_axi_bridge.v` 和
`axi_llc_axi_bridge_dual.v`，在小参数 wrapper 中检查 4B cache read 的 `R`
response 回收路径。

覆盖点：

- 4B read 被接受后会在正确 DDR/MMIO 端口发出 `AR`。
- 按发出的 `ARID` 注入对应端口 `RVALID/RID/RDATA/RRESP/RLAST` 后，正确端口
  `RREADY` 必须拉高。
- 被接收的 `R` response 必须进入 cache source response path。
- 返回给 cache source 的 `cache_resp_id/cache_resp_code` 必须等于原始 request id 和
  外部 `RRESP`。
- 单 beat data merge 必须把 DDR 64-bit 或 MMIO 32-bit `RDATA` 放入 64-bit
  `cache_resp_rdata`。

限制：

- 为控制 hw-cbmc 状态空间，DDR 数据宽度在 wrapper 内缩小为 64-bit，pending 深度缩小为 1。
- 该用例只验证单笔 4B read 的 `R` 回收，不覆盖多 outstanding、DDR 64B multi-beat
  cacheline read 或 mode2 aligned read slice。
