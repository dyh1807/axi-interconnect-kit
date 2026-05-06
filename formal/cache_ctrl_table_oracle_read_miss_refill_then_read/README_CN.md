# cache_ctrl_table_oracle_read_miss_refill_then_read

状态：table-oracle / state-IO cutpoint 原型。

该入口直接实例化实际生产 `rtl/src/llc_cache_ctrl.v`，formal top 只缩小 cache 参数并把
data/meta/valid/repl store 建模为一个 tracked set 的 shadow row oracle。

覆盖场景：

- 初始 tracked set 为空，因此第一笔 read 必须 miss。
- RTL 必须发出整行 lower-memory refill read，且 refill response 后写回 data/meta/valid/repl。
- harness shadow row 接收安装写表意图并更新 tracked set。
- 第一笔 read response 必须返回 refill line。
- 第二笔同地址 read hit 必须从 shadow row 返回相同 refill line，且不得再次发 lower
  memory request。

该 proof 重点是证明“read miss 安装到 table 后，真实 `llc_cache_ctrl` 后续 lookup 能
观察到同一 tracked set 的写入结果”。store primitive 的真实 latency/mask 仍由
`llc_data_store` / `llc_meta_store` / `llc_valid_ram` / `llc_repl_ram` 的 VCS contract
或后续 primitive proof 覆盖。

运行：

```bash
formal/cache_ctrl_table_oracle_read_miss_refill_then_read/run_hw_cbmc.sh
```
