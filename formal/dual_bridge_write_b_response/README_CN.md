# dual_bridge_write_b_response

这个 formal 用例绑定实际生产 RTL `axi_llc_axi_bridge.v` 和
`axi_llc_axi_bridge_dual.v`，在小参数 wrapper 中检查 4B cache write 的 `B`
response 回收路径。

覆盖点：

- 4B write 被接受后会在正确 DDR/MMIO 端口发出 `AW/W`。
- 按发出的 `AWID` 注入对应端口 `BVALID/BID/BRESP` 后，正确端口 `BREADY` 必须拉高。
- 被接收的 `B` response 必须进入 cache source response path。
- 返回给 cache source 的 `cache_resp_id/cache_resp_code` 必须等于原始 request id 和
  外部 `BRESP`。

限制：

- 为控制 hw-cbmc 状态空间，DDR 数据宽度在 wrapper 内缩小为 64-bit，pending 深度缩小为 1。
- 该用例只验证单笔 4B write 的 `B` 回收，不覆盖多 outstanding、DDR 64B multi-beat
  write 或 read `R` response 回收。
