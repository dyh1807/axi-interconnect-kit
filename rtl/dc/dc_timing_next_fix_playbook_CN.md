# DC Timing 下一步修复 Playbook

更新时间：2026-05-12 23:57 CST。

本文用于 active DC final report 期间的下一步执行准备。23:46 CST 已基于 compat
quick final timing 执行 payload circular-store RTL 修复并重启 source-fresh DC；
后续动作以 `rtl/dc/decide_dc_next_action.sh` 和新的 compat/fulltop timing endpoint
分类为准。

## 当前不应提前修改的原因

- `LLC_HIT` gate 已经 PASS：read hit `ready=0 resp=7 external=-1`，write hit
  `ready=1 resp=9 external=-1`。任何新增 stage 都必须证明不破坏该 exact-cycle 结果。
- bounded non-hit、53 个 RTL contracts、large+BPU Linux sanity 当前均 PASS。
- 旧 direct-pop/predecode-clean fulltop 已因 RTL 修改停止，不能再作为 current signoff。
- payload-circular 新 DC 已启动：
  `compat_quick_map_low_payload_circular_9t20_20260512_235452_eda-05` 和
  `full_compile_1g_payload_circular_long72h_9t20_20260512_235452_eda-05`。
  23:55 CST 早期状态为 source freshness / liveness PASS，正在 elaborate，link 前
  macro/library binding WAIT 属于正常状态。
- 触发修复的旧 compat quick-map final 失败：WNS `-0.06ns`、TNS `-9719.26`、
  violating paths `279048`。max20 主体是 `compat_write_payload` 13 条和
  `compat_dispatch` 2 条，代表路径为
  `direct_rr_ptr_r_reg_3_ -> wr_q_wdata_reg_25__270_`、
  `wr_q_head_reg_1__3_ -> core_req_stage_addr_r_reg_6_`。

## Report 出来后的动作表

| final timing 分类 | 源码关注点 | 可尝试修复 | 必须避免 |
| --- | --- | --- | --- |
| `compat_dispatch` | `axi_llc_subsystem_compat.v` 中 `rr_ptr_r -> core_req_stage_*`，当前组合选择在 `core_rd_dispatch_ready_w/core_wr_dispatch_ready_w` 后经 round-robin 选择写入 `core_req_stage_*` | 若仍主导，优先继续把 per-master head/ready/payload 做更明确的注册或 one-hot 化，使 `rr_ptr_r` 不穿过宽 payload/address mux；尽量只优化 dispatch 准备逻辑 | 不增加 LLC-hit read/write 可见 cycle；不改变 outstanding/id/同地址 hazard 约束 |
| `compat_write_payload` | `wr_q_head_wdata_r/wstrb_r`、`wr_q_wdata/wstrb` per-master shift 和 `core_req_stage_wdata_r/wstrb_r` | 若写 payload 仍主导，可进一步拆分 head payload 与尾部 shift，或让 pop 后 payload 更新与 dispatch stage 解耦；写侧优化通常不应影响 LLC-hit read 快路径 | 不恢复动态 master-indexed 512-bit/2048-bit mux；不把 direct/core 写响应变成串行瓶颈 |
| `compat_response_pool` | `rd_resp_data_r`、`rd_resp_q_pool_idx`、response pool 分配/回收 | 只有 final endpoint 指向 response pool 时再处理：优先缩窄 pool idx 到参数化宽度，或拆分 data/metadata valid 选择 | 不为清理 constant-removal 而盲目修改；response ready/valid 语义必须保持 |
| `bridge_or_hazard` | `axi_llc_axi_bridge.v` 的 `wr_aw_head_r -> wr_aw_q_slot_r -> wr_addr_r`，以及 `axi_llc_axi_bridge_dual.v` 的 `line_tag_of_addr(ddr/mmio_axi_awaddr)` 到 `axi_llc_dual_port_hazard_scoreboard.wr_hazard_line_r` | 若成为主导，优先考虑在 bridge AW issue 侧预寄存 issued line/tag，或在 hazard scoreboard 输入前加语义保持的 issue-stage register | 不能引入 R 通道回压依赖；不能违反“AR 未完成前不发同地址 AW / AW 未完成前不发同地址 AR”的约束 |
| `refill_response` | `axi_llc_axi_bridge.cache_rd_rsp_head_r -> cache_rd_rsp_data_r[head]` 经 response mux 到 `llc_cache_ctrl.mshr_refill_line_r` | 若成为主导，可考虑 cache refill response 到 MSHR refill line 的 staging。该路径属于 miss/refill，允许 bounded 性能差距，但需要重新量化 | 不影响 LLC-hit exact cycle；不能把 writeback B 完成作为释放 buffer 且仍未接收 R 的前置依赖 |
| `store_or_sram` | data/meta store wrapper、SRAM Q 到 capture register | 只有 postcompile 显示该类为 setup fail 时再处理；当前 precompile data SRAM Q -> capture slack 为 `+0.33ns`，不是首要怀疑点 | 不随意改 SRAM latency，除非同时更新 C++/RTL/harness 语义并重测性能 |
| `other` | DC alias `R_*` 或未分类 endpoint | 先用 final netlist/report 反查真实寄存器名，再归入上面类别；不要直接按 `other` 修 | 不基于别名猜测改 RTL |

## 已执行的 compat 修复与剩余候选

payload circular-store 修复已经执行；如果新的 DC 仍失败，按以下顺序继续收敛：

1. `compat_write_payload` 已修：`wr_q_wdata/wstrb` 改为与 metadata 使用同一个 circular
   slot。写入使用 `wr_q_tail` 对应 slot；pop 只刷新 `wr_q_head_wdata_r/wstrb_r`
   到 `next_wr_ptr(wr_q_head[idx])` 对应 slot，不再 shift 尾部 payload array。
   该修复已通过 direct-bypass payload 顺序、LLC-hit exact、bounded non-hit 和全量
   53 contracts；等待新 DC 验证是否消除 `direct_rr_ptr_r -> wr_q_wdata_reg[*]`
   主路径。
2. `compat_dispatch` 第二优先级：若新 DC final 仍有
   `wr_q_head_reg -> core_req_stage_addr` 或 `rr_ptr -> core_req_stage_*`，再考虑把
   per-master head metadata 的 ready/payload 进一步注册或 one-hot 化。该方向可能影响
   core request stage 可见 cycle，必须先证明 LLC-hit read `ready=0 resp=7`、write
   `ready=1 resp=9` 不变；否则不采用。
3. `core/cache_ctrl` 的 `req_addr/req_tag -> install_line/mshr_victim_data` 在旧 compat
   quick max20 中只占少量 `other`，不作为第一刀；除非 fulltop final 显示它成为主导。

## 修复后的硬性验证闭环

每次 RTL 或语义修改后，至少重新执行并保存以下证据：

1. LLC-hit exact-cycle contract：必须继续得到 read hit `ready=0 resp=7 external=-1`、
   write hit `ready=1 resp=9 external=-1`。
2. bounded non-hit contract：LLC miss / direct / MMIO / DDR 非 hit 场景可以有 bounded
   cycle 差距，但不能无界退化。
3. 全量 RTL contracts：当前基线是 `53/53` PASS，不能引入 FAIL/ERROR/MISMATCH。
4. large+BPU Linux sanity：至少保持已有 300k / 5M smoke 的无 difftest error 和性能边界。
5. source-fresh DC：修改 RTL 后旧 active run 全部只能作为 stale 诊断，必须重启新的
   fulltop signoff run，并重新检查 SRAM macro DB、9T20 标准单元库、final netlist macro refs。

## 当前等待策略

- 不在 payload-circular 新 DC 给出 endpoint 前继续做 speculative RTL 修改。
- 一小时低频检查已经通过 `rtl/dc/schedule_dc_check_once.sh` 安排。
- 如果新 compat quick 先出 final report，则优先判断 payload circular-store 是否消除了
  `compat_write_payload`；如果仍失败，再按剩余 endpoint 进入 dispatch/core 修复。
- 如果新 72h fulltop final 通过，则进入 completion audit；如果失败，以 fulltop
  postcompile endpoint 为最高优先级。
