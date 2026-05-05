# subsystem_dual_mmio_write_response

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

这个 formal 用例直接实例化实际生产 `rtl/src/axi_llc_subsystem_dual.v`，在小参数
wrapper 中发起一笔 4B MMIO write，等待真实 `AW/W` 发出后注入 MMIO `B` response，
再检查上游 `write_resp_*`。

覆盖点：

- 4B MMIO write 最终必须被 upstream 接受。
- 请求最终必须只向 MMIO `AW/W` 发出，不得误发 DDR `AR/AW/W`。
- MMIO `AWADDR/AWLEN/AWSIZE/AWBURST` 与 4B MMIO write 语义一致。
- MMIO `WDATA/WSTRB/WLAST` 与原始 32-bit write 请求一致。
- 注入匹配 `BID` 的 MMIO `B` response 后，`mmio_axi_bready` 必须允许回收。
- 上游 `write_resp_valid/id/code` 必须回传原始 request ID 和 MMIO `BRESP`。

明确不覆盖：

- 不验证 DDR/cacheable write response；bridge-level 已覆盖双端口 `B` response
  route，native top 后续可拆 DDR refill/writeback 相关 smoke。
- 不覆盖多 outstanding 同时返回重排；该项应继续由 bridge/route-level formal 覆盖。
