# subsystem_dual_mmio_write_route

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

这个 formal 用例直接实例化实际生产 `rtl/src/axi_llc_subsystem_dual.v`，在小参数
wrapper 中检查 native dual top 的 4B MMIO write direct-route 行为。formal top 只做
参数缩小、未关注端口 tie-off、以及暴露 AW/W 观测信号，不重写路由逻辑。

覆盖点：

- 4B MMIO write 最终必须被 upstream 接受。
- 被接受后的请求最终必须只向 MMIO `AW/W` 发出。
- MMIO `AWADDR` 等于原始地址，`AWLEN=0`，`AWSIZE=2`，`AWBURST=INCR`。
- MMIO `WDATA/WSTRB/WLAST` 与原始 32-bit write 请求一致。
- 同一过程中不得误发 DDR `AR/AW/W`，也不得误发 MMIO `AR`。
- unsupported MMIO 大 write 必须保持 upstream `write_req_ready=0`，不得产生
  `write_req_accepted`，也不得驱动 DDR/MMIO `AW/W`。

明确不覆盖：

- 不验证 `B` response 回收；该项已经由 bridge-level `dual_bridge_write_b_response`
  覆盖，native dual top 后续可再补 end-to-end response smoke。
- 不把 reset 后 reconfig/active-mode 收敛作为本入口证明目标；该项应拆独立
  reconfig smoke。
