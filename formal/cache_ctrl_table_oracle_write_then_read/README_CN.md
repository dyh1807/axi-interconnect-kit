# cache_ctrl_table_oracle_write_then_read

状态：table-oracle / state-IO cutpoint 原型。

该入口直接实例化实际生产 `rtl/src/llc_cache_ctrl.v`，formal top 只缩小 cache 参数并把
data/meta/valid/repl store 建模为一个 tracked set 的 shadow row oracle。

覆盖场景：

- 初始 tracked set 中 way0 是 clean valid 命中行。
- 第一笔请求是 partial write hit。
- RTL 必须输出正确的 data/meta/valid/repl 写表意图，且不得发 lower memory request。
- harness shadow row 接收这次写表意图并更新 tracked set。
- 第二笔同地址 read hit 必须从 shadow row 返回更新后的 line。

该 proof 重点不是证明整张表实现，而是证明“给定合法 table 返回值时，真实
`llc_cache_ctrl` 的写表意图和后续读取行为一致”。store primitive 的真实 latency/mask
仍由 `llc_data_store` / `llc_meta_store` / `llc_valid_ram` / `llc_repl_ram` 的 VCS
contract 或后续 primitive proof 覆盖。

运行：

```bash
formal/cache_ctrl_table_oracle_write_then_read/run_hw_cbmc.sh
```
