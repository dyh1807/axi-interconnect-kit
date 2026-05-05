# subsystem_dual_cache_dirty_evict_b_response

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

## 生产对象

- `rtl/src/axi_llc_subsystem_dual.v`
- `rtl/src/axi_llc_subsystem_compat.v`
- `rtl/src/axi_llc_subsystem_core.v`
- `rtl/src/llc_cache_ctrl.v`
- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

## 覆盖范围

- 直接复用 `formal/subsystem_dual_cache_dirty_evict_writeback` 的 native dual top wrapper；formal top 只缩小 cache/AXI 参数、tie-off 未关注端口并暴露观测信号。
- MODE_CACHE 下连续三笔 full-line write miss：前两笔写入同一 set 的两个 way，第三笔同 set 不同 tag 触发 dirty victim writeback。
- dirty victim writeback 的 DDR `AW/W` 握手完成后，驱动匹配 `BID` 的 DDR `B` response。
- DDR `B` 可接收时，native dual top 必须拉高 `BREADY`。
- 第三笔 upstream write response 只能在 DDR `B` 已被接受或同拍接受后返回，且 `write_resp_id/code` 必须正确。
- 同一过程中不得误发 DDR `AR` 或 MMIO `AR/AW/W`。

## 明确不覆盖

- 该入口使用 8B line / 8B DDR beat 小参数，以保持完整 top 可收敛；生产 64B/256-bit AXI payload 由 `bridge_prod_width_cacheline_*` 覆盖。
- 该入口证明完整 native dual top 的 dirty writeback `B -> upstream write response` split；B 后新 dirty line read-hit 已由 `formal/subsystem_dual_cache_dirty_evict_post_b_hit` 在完整 native dual top 边界覆盖，更细的安装状态更新仍由 `formal/cache_ctrl_dirty_evict_writeback` 在生产 `llc_cache_ctrl.v` 边界覆盖。
- 该入口使用确定性的 `B` 返回窗口，不覆盖任意长 `B` 延迟下的公平性。
- 不覆盖实际 C++ reference 与实际 RTL top 的端到端 EC。
