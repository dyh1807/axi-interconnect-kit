# cache_ctrl_partial_write_hit_merge

该入口是 actual `llc_cache_ctrl.v` 的 bounded formal smoke。Formal top 只缩小参数、
固定一个命中的 clean line 环境，不重写 cache-control 行为。

覆盖场景：

- clean line 命中后收到 partial write。
- cache control 不得发外部 memory request。
- data store 写回必须只更新命中 way，且按 request offset 和 `WSTRB` merge 写数据。
- meta store 写回必须把该 way 标记为 dirty，valid/replacement 同步更新。
- upstream write response 的 id/code 必须正确。

运行：

```bash
formal/cache_ctrl_partial_write_hit_merge/run_hw_cbmc.sh
```
