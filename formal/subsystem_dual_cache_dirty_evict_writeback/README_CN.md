# subsystem_dual_cache_dirty_evict_writeback

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

## 生产对象

- `rtl/src/axi_llc_subsystem_dual.v`
- `rtl/src/axi_llc_subsystem_compat.v`
- `rtl/src/axi_llc_subsystem_core.v`
- `rtl/src/llc_cache_ctrl.v`
- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

## 覆盖范围

- 直接实例化 native dual top；formal top 只缩小 cache/AXI 参数、tie-off 未关注端口并暴露观测信号。
- MODE_CACHE 下连续三笔 full-line write miss：前两笔写入同一 set 的两个 way，第三笔同 set 不同 tag 必须触发 dirty victim writeback。
- 第三笔写触发的 dirty victim writeback 必须只走 DDR `AW/W`，不得误发 DDR `AR` 或 MMIO `AR/AW/W`。
- DDR writeback 的 `AWADDR/AWLEN/AWSIZE/AWBURST` 必须对应被替换 dirty line。
- DDR writeback 的 `WDATA/WSTRB/WLAST` 必须对应被替换 dirty line 数据。
- 在未提供 DDR `B` 前，第三笔 upstream write response 不得提前返回。

## 明确不覆盖

- 该入口刻意不驱动 DDR `B`，因此不在完整 subsystem 层证明 B 后返回第三笔 write response。
- B 后 upstream response split 已由 `formal/subsystem_dual_cache_dirty_evict_b_response` 在完整 native dual top 边界覆盖。
- B 后新 dirty line 安装细节已由 `formal/cache_ctrl_dirty_evict_writeback` 在生产 `llc_cache_ctrl.v` 边界覆盖。
- 该入口使用 8B line / 8B DDR beat 小参数，以保持完整 top 可收敛；生产 64B/256-bit AXI payload 由 `bridge_prod_width_cacheline_*` 覆盖。
