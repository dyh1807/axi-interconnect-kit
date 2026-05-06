# cache_ctrl_table_oracle_invalidate_then_read_miss

状态：table-oracle / state-IO cutpoint 原型。

该入口直接实例化实际生产 `rtl/src/llc_cache_ctrl.v`，formal top 只缩小 cache 参数并把
data/meta/valid/repl store 建模为一个 tracked set 的 shadow row oracle。

覆盖场景：

- 初始 tracked set 中 way0 是 clean valid hit line。
- 第一阶段发 `invalidate_line`，RTL 必须通过 valid 表写口清掉该 way。
- harness shadow row 接收 valid clear 并更新 tracked set。
- 第二阶段发同地址 read；该 read 不得命中旧 line，必须发 lower-memory refill read。
- refill response 后，RTL 安装 refill line 并返回 read response。

该 proof 重点是证明 invalidate 对 valid 表的写表意图会被后续 lookup 观察到，避免
旧 line 在 valid clear 后继续命中。store primitive 的真实 latency/mask 仍由
`llc_data_store` / `llc_meta_store` / `llc_valid_ram` / `llc_repl_ram` 的 VCS contract
或后续 primitive proof 覆盖。

运行：

```bash
formal/cache_ctrl_table_oracle_invalidate_then_read_miss/run_hw_cbmc.sh
```
