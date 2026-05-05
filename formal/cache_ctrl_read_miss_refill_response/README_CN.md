# cache_ctrl_read_miss_refill_response

该入口是 actual `llc_cache_ctrl.v` 的 bounded formal smoke。Formal top 只缩小参数、
固定空 set 环境和固定 refill 数据，不重写 cache-control 行为。

覆盖场景：

- 空 set 上收到 aligned read miss。
- cache control 必须先发整行 refill read，地址按 line 对齐，`mem_req_write=0`，
  `mem_req_size=LINE_BYTES-1`。
- refill response 被接受后，实际 `llc_cache_ctrl.v` 必须把 refill line 安装到 way0，
  写 valid/meta/data store，meta 为 clean。
- 上游 read response 的 id/code/data 必须与请求和 refill line 一致。

运行：

```bash
formal/cache_ctrl_read_miss_refill_response/run_hw_cbmc.sh
```
