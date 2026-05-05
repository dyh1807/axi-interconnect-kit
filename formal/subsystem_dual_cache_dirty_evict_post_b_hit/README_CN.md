# subsystem_dual_cache_dirty_evict_post_b_hit

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

## 生产对象

- `rtl/src/axi_llc_subsystem_dual.v`
- `rtl/src/axi_llc_subsystem_compat.v`
- `rtl/src/axi_llc_subsystem_core.v`
- `rtl/src/llc_cache_ctrl.v`
- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

## 覆盖目标

- 直接实例化 native dual top；formal top 只缩小 cache/AXI 参数、tie-off 未关注端口并暴露观测信号。
- MODE_CACHE 下连续三笔 full-line write miss：第三笔触发 dirty victim writeback。
- dirty victim DDR `AW/W/B` 完成并返回第三笔 upstream write response 后，再对第三笔地址发起 read。
- 该 read 必须命中新安装的 dirty line，不得再发 DDR `AR` 或 MMIO 访问。
- read response 的 `id/data` 必须对应第三笔写入的新 line。

## 明确不覆盖

- 小参数 8B line / 8B DDR beat smoke 不覆盖生产 64B/256-bit AXI payload；生产宽度 payload 由 `bridge_prod_width_cacheline_*` 覆盖。
- 不覆盖任意长 `B` 延迟公平性。
- 不覆盖实际 C++ reference 与实际 RTL top 的端到端 EC。
