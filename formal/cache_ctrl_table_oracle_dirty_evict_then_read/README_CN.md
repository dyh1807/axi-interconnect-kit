# cache_ctrl_table_oracle_dirty_evict_then_read

状态：table-oracle / state-IO cutpoint 原型。

该入口直接实例化实际生产 `rtl/src/llc_cache_ctrl.v`，formal top 只缩小 cache 参数并把
data/meta/valid/repl store 建模为一个 tracked set 的 shadow row oracle。

覆盖场景：

- 初始 tracked set 已满，replacement way 指向 dirty victim。
- 第一笔 full-line write miss 必须先发 dirty victim writeback。
- writeback response 后，RTL 必须把新 dirty line 安装到 victim way 并返回 write response。
- harness shadow row 接收安装写表意图并更新 tracked set。
- 第二笔同地址 read hit 必须从 shadow row 返回新安装 line，且不得再次发 lower memory
  request。

该 proof 重点是证明 dirty victim writeback 后的 install/post-B hit 行为可以通过真实
`llc_cache_ctrl` 的 table 端口自洽观察到。store primitive 的真实 latency/mask 仍由
`llc_data_store` / `llc_meta_store` / `llc_valid_ram` / `llc_repl_ram` 的 VCS contract
或后续 primitive proof 覆盖。

运行：

```bash
formal/cache_ctrl_table_oracle_dirty_evict_then_read/run_hw_cbmc.sh
```
