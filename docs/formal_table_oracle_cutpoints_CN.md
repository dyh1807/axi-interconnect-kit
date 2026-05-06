# Formal Table-Oracle / State-IO Cutpoint 规划

本文档记录后续用 hw-cbmc 收敛 C++/RTL 等价性时的一个长期方向：不要把整张
LLC table 展开进 formal，而是在真实生产 RTL 的 table 访问边界上做 cutpoint。

该方案不改变生产 RTL top 的真实 IO，只用于 formal/EC wrapper。

## 背景

当前完整 `axi_llc_subsystem_dual` 的生产 IO 很宽，默认参数下 PI 约 `1836 bits`，
PO 约 `8834 bits`。其中最大的输出是 `read_resp_data = 4 * 2048 bits`，最大的输入
之一是 `write_req_wdata = 2 * 512 bits`。

但更大的问题不是外部 IO 本身，而是 monolithic top 会把以下内容同时放入 BMC：

- compat queue / slot / response owner。
- core MSHR / dirty victim / refill / maintenance 状态机。
- data/meta/valid/repl table 的读写时序。
- DDR/MMIO bridge pending、hazard scoreboard 和 response mux。
- 512-bit line、2048-bit upstream response 的 pack/merge/slice。

因此继续把整 top 直接喂给 hw-cbmc 不划算。更合理的是把证明拆成：

- table primitive proof：证明真实 store wrapper 的读写 latency/mask 行为。
- table-oracle control proof：证明真实控制逻辑在给定 table 返回值下的下一步行为。
- actual-top smoke：证明真实连接没有把 cutpoint 接错。

## 基本模型

不要输入整张表。

只对本次访问相关的 set/row 建模：

```text
真实 RTL 控制逻辑
  table_rd_en/table_rd_addr  --->  harness oracle 返回 rd_valid/rd_row
  table_wr_en/table_wr_addr/table_wr_data/table_wr_mask  --->  被观测并检查
```

读表处理：

- RTL 发出 `rd_en/rd_set`。
- harness 在合法 latency 后返回 `rd_valid` 和当前 set 的抽象 row。
- 该 row 可以是 nondet，但必须满足本 proof 的前置 invariant。

写表处理：

- RTL 输出 `wr_en/wr_set/wr_data/wr_mask`。
- harness 不需要真的更新整表，只需要检查这次写意图是否符合 C++/规格。
- 如果同一个 proof 内后续还会再次读同一个 `wr_set`，harness 必须追踪这一个 set 的
  shadow row，并把前一次写入反映到后续读返回中。

不同 set：

- 没有被当前 proof 跟踪的其它 set 可以保持 nondet。
- 不要对 8192 个 set 建数组。

## 一致性约束

table oracle 不能随意返回不可能的状态，否则会证明出虚假的通过或虚假的失败。

必须约束：

- `rd_valid` 的出现时序与真实 table primitive 一致，或被明确限制在该 proof 的抽象
  latency 合同内。
- 同一 tracked set 在没有写入时必须稳定。
- 同一 tracked set 被写入后，下一次读同 set 必须反映写入后的 row。
- 同周期 read/write 同 set 的语义必须与真实 primitive 对齐；如果暂时不想证明该
  corner，应在 proof 前置条件中排除，而不是让 oracle 任意选择。
- `valid`、`meta`、`data`、`repl` 之间的关系必须满足本 proof 需要的合法 cache
  invariant，例如 valid way 的 meta tag 与 data line 对应，repl way 在合法范围内。

## 适合的 RTL 边界

### `llc_cache_ctrl`

这是最适合 table-oracle 的第一目标。它已经把 store 读写做成外部端口：

- data：`data_rd_en/data_rd_set/data_rd_valid/data_rd_row`，
  `data_wr_en/data_wr_set/data_wr_way_mask/data_wr_row`
- meta：`meta_rd_en/meta_rd_set/meta_rd_valid/meta_rd_row`，
  `meta_wr_en/meta_wr_set/meta_wr_way_mask/meta_wr_row`
- valid：`valid_rd_en/valid_rd_set/valid_rd_valid/valid_rd_bits`，
  `valid_wr_en/valid_wr_set/valid_wr_mask/valid_wr_bits`
- repl：`repl_rd_en/repl_rd_set/repl_rd_valid/repl_rd_way`，
  `repl_wr_en/repl_wr_set/repl_wr_way`

可拆 proof：

- read hit：给定 tracked set 中某 way valid/tag 命中，检查 response 与无 lower request。
- read miss/refill：给定 miss 和可选 invalid/victim way，检查 lower read、install 写表。
- partial write hit：给定 hit line，检查 merge 后 `data_wr_row` 和 meta/repl/valid 写意图。
- partial write miss/refill：给定 refill line，检查 refill+merge+install。
- dirty victim：给定 victim valid+dirty，检查 writeback address/data/strobe，再检查后续 install。
- `invalidate_line`：给定目标 line hit/miss，检查 clear valid 或 rejected/drain。

### `llc_mapped_window_ctrl`

该模块本身已经是 table-oracle 风格组合逻辑：

- 输入当前 row：`row_data_in`、`valid_bits_in`
- 输出本次结果：`read_line_out`、`write_line_out`、`next_valid_bit_out`

后续只需要保证 mapped-window wrapper 的 proof 使用实际模块，并覆盖：

- offset/window 边界。
- direct set/way 选择。
- valid miss zero-read。
- write line merge 和下一次同 set 读的一致性。

### Store primitive

`llc_data_store`、`llc_meta_store`、`llc_valid_ram`、`llc_repl_ram` 不应该被 table-oracle
替代掉。它们需要保留小 proof 或 VCS contract，证明：

- `rd_en -> rd_valid` latency。
- `wr_mask/way_mask` 生效。
- 同 set read/write corner 与真实实现一致。
- SMIC12 wrapper 与 generic fallback 的 observable contract 对齐。

### `axi_llc_subsystem_core`

core 当前集成 reconfig/store/core datapath。若直接绑定完整 core，仍会拉入较多状态。
更合适的推进方式：

- 短期继续在 `llc_cache_ctrl` 边界做 table-oracle proof。
- 如果必须证明 core 层，应先把“startup 已完成且 active mode 稳定”作为前置条件，
  不要把 startup/reconfig 和 dirty victim 进度断言混在一个 proof。
- 如后续需要 core-level table cutpoint，应优先抽一个生产使用的 external-store core
  边界，避免 formal-only 重写。

### `axi_llc_subsystem_compat`

compat 的瓶颈不是表，而是 queue/slot/response owner。这里适合 state-IO cutpoint，
不是 table-oracle：

- 输入：当前 queue/slot/owner 的合法抽象状态。
- 输出：本周期 accept/ready/handoff/response intent。
- invariant：slot ID 唯一、valid slot 对应 owner 合法、held response 不回压 lower
  `R/B`。

## 与 C++ reference 的关系

Table-oracle proof 仍必须避免“按理解重写一份 spec”。

可接受做法：

- 对 route/pack/merge 等已经抽成生产 C helper 和生产 RTL helper 的逻辑，继续做 helper EC。
- 对 LLC table 行为，优先让 C++ trace 生成实际可观察事件，再由 table-oracle proof
  检查 RTL 在同等 row 前置条件下的写表/外发意图。
- 如果需要新增 C++ 侧 transition helper，必须从实际 `AXI_LLC` / `AXI_Interconnect`
  语义中抽取并在生产或测试路径共用，不能为 formal 单独写一份不被实际使用的模型。

## 并行化策略

可以并行，但按以下粒度：

- 优先并行跑独立 proof 入口。
- 对 payload proof，可按 word/byte slice 拆分，例如 512-bit line 拆成 8 个 64-bit
  或 16 个 32-bit slice。
- 控制 proof 不能按 bit 切开；`valid/id/ready/rlast/hazard` 必须整体证明。

按输出 bit 切分只对 payload equality 有明显帮助。若瓶颈来自 state machine、queue
或 hazard 约束，bit-slice 的收益有限。

## Stop Criteria

该方向不是要替代所有 existing gates，而是补长期 EC 的可维护路径。

进入 stable manifest 前，每个新增 table-oracle proof 至少需要：

- README 说明被证明的真实 RTL module、cutpoint、前置 invariant 和不覆盖项。
- run 脚本可复现，默认 timeout 内通过。
- 如果使用 C++ helper，说明 helper 是生产/共用逻辑，不是 formal-only spec。
- 对应 store primitive proof 或 VCS contract 已存在。
- 至少一个 actual-top smoke 覆盖该 cutpoint 到生产 top 的连接。

## 当前建议顺序

1. 先补 `llc_cache_ctrl` 的 table-oracle README/小 proof 原型，优先选择 read-hit 或
   partial-write-hit，因为它们不需要 lower memory 多阶段闭环。
2. 再做 dirty-victim proof 的拆分：victim detect、writeback issue、writeback response、
   install/post-B hit 分开证明。
3. 对 compat 另开 state-IO plan，不把 queue proof 和 table proof 混在一起。
4. 保持现有 stable manifest，不把 monolithic native-top production-width 入口直接加入
   stable。
