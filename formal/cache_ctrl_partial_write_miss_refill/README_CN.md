# cache_ctrl_partial_write_miss_refill

状态：稳定 formal smoke，目标纳入 `formal/run_passed_hw_cbmc.sh`。

该 bounded formal 直接实例化生产 `rtl/src/llc_cache_ctrl.v`。wrapper 只缩小参数、
提供固定 store/memory 环境并暴露观测信号，不重写 cache-control 行为。

运行：

```bash
formal/cache_ctrl_partial_write_miss_refill/run_hw_cbmc.sh
```

覆盖目标：

- 空 set 下 partial write miss 不得直接安装写数据，必须先发整行 refill read。
- refill `mem_req` 必须是 read，地址为 line-aligned 地址，size 为整行。
- refill response 被接受后，按 `req_addr` offset 和 `req_wstrb` merge 写数据。
- 安装的新 line 必须 valid+dirty，replacement way 更新，并返回 upstream write response。

边界：

- 仅验证 `llc_cache_ctrl.v` 边界，不实例化完整 native dual top 和 DDR AXI bridge。
- dirty victim/writeback 由 `formal/cache_ctrl_dirty_evict_writeback` 覆盖。
