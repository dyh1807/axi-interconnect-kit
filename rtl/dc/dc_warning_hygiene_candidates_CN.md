# DC Warning / Constant-Removal Hygiene 候选项

更新时间：2026-05-12 14:03 CST。

本文只记录当前 DC log 中的非 fatal warning 和常量删除热点，作为后续 RTL hygiene
候选项。当前 active DC 正在运行，不应为了这些非 fatal 提示中途修改 RTL 或 DC Tcl，
否则正在运行的 fulltop / compat quick 结果会变 stale。

## 当前结论

- 当前 72h fresh fulltop 没有 `Error` / `Fatal` / OOM：`ERROR_FATAL_SUMMARY count=0`。
- 当前 72h fresh fulltop 已完成 link，macro/library 绑定 PASS，已进入
  `compile_ultra -retime`。
- warning 当前主要是 signedness 和 unreachable default；这些不是当前 setup signoff
  blocker。
- constant-register removal 在 compat quick 中较多，当前应作为结构/日志噪声线索，
  等 final timing 出来后再决定是否清理。

## Warning 观察

| 类别 | 当前样例 | 判断 | 后续动作 |
| --- | --- | --- | --- |
| `VER-318` signed/unsigned | `llc_valid_ram.v:77`、`llc_data_store_smic12.v:151`、`llc_meta_store_smic12.v:154`、`llc_mshr_select_scan.v:39/47/64` | 非 fatal，通常来自 integer/part-select 到 unsigned signal | 若 final timing 已通过，可低优先级清理；若同一表达式出现在 hot path，再优先清理 |
| `ELAB-311` unreachable default | `axi_reconfig_ctrl.v:65`、`llc_cache_ctrl.v:439/462` | 非 fatal，通常是 full/constant case 被 DC 证明 default 不可达 | 不应在 active DC 中途修改；后续可用 explicit full-case style 或删除 default 前先确认仿真语义 |
| `OPT-1303` low map obsolete | compat quick 的 `compile -map_effort low` 被 DC 视为 medium | 影响 quick probe 的提示，不是 RTL 问题 | 后续若要清理，只能在没有 active run 依赖该 Tcl 时改 quick script |
| `UISN-40` DesignWare synthetic auto-added | full compile log 中由 `compile_ultra` 自动加入 | 常规 DC 信息，不是当前 blocker | 不处理 |

## Constant-Removal 热点

| 热点 | 当前数量示例 | 可能原因 | 后续动作 |
| --- | ---: | --- | --- |
| `resp_data_r_reg` | compat quick `1536` | 某些 response data 位在当前参数/路径下常量化 | 先等 final timing；若仍拖慢/占面积，再结合 endpoint 判断是否需要缩窄或拆存储 |
| `rd_resp_q_pool_idx_reg[*][5:7]` | compat quick `384` | pool count 为 32，但索引寄存器声明为 8-bit，高 3 位恒 0 | 低风险候选：后续可把 pool index 相关寄存器/临时变量收敛到 5-bit 或参数化 width |
| `mshr_victim_addr_r_reg` | compat quick `192` | victim address 部分位在当前参数/路径下常量化 | 只有 final timing/area 指向该结构时再处理 |
| `wr_capture_rr_r_reg[2:7]` | compat/full `6` | write master 数量为 2，RR pointer 高位恒 0 | 低风险候选：后续可缩窄 capture/dispatch pointer width，但需小心 plain-Verilog index 使用 |
| `rd_capture_rr_r_reg[3:7]` | compat/full `5` | read master 数量为 4，RR pointer 高位恒 0 | 同上 |
| `core_req_stage_slot_r_reg[5:7]` | compat/full `3` | slot count / ID width 只需要低位 | 低风险候选，但需确认与 `SLOT_ID_BITS` / outstanding count 一致 |

## 执行策略

1. 当前不修改 RTL/Tcl，先等待 compat quick 或 72h fulltop final timing。
2. 如果 final timing PASS，只把这些作为低优先级 cleanup，避免无收益改动。
3. 如果 final timing FAIL，优先按 final endpoint 分类修最高占比路径。
4. 只有当 warning/constant-removal 对应结构出现在 failing endpoint 或明显拖慢 DC 时，才把它升级为修复项。
5. 每次 hygiene 改动后必须重跑 LLC-hit exact、bounded non-hit、53/53 RTL contracts，再启动 source-fresh DC。
