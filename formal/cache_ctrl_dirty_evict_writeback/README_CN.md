# cache_ctrl_dirty_evict_writeback

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/cache_ctrl_dirty_evict_writeback/run_hw_cbmc.sh
```

实际生产对象：

- RTL：`rtl/src/llc_cache_ctrl.v`
- 消费者：`rtl/src/axi_llc_subsystem_core.v`

覆盖范围：

- 构造同一 set 两个 way 均 valid+dirty，replacement way 指向 way0。
- 对第三个同 set 不同 tag 的 full-line write miss，必须先发 dirty victim writeback。
- writeback `mem_req` 必须是写请求，地址为 victim line，数据/strobe/size 为完整 cacheline。
- writeback response 被接受后，才允许安装新 dirty line 并返回 upstream write response。
- 安装阶段必须同时更新 data/meta/valid，并推进 replacement way。

明确不覆盖：

- 不实例化完整 `axi_llc_subsystem_dual.v` 和 DDR AXI bridge；完整 subsystem dirty-evict
  harness 当前作为探索项保留，300s 内未收敛。
- DDR AXI `AW/W/B` channel 形状由现有 `dual_bridge_*` 和 production-width bridge
  smoke 覆盖。
