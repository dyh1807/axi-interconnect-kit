# Dual AXI / LLC EC 验证 Checklist

本文档用于跟踪当前 submodule 内 C++ reference、生产 RTL helper、formal EC、VCS
contract 的覆盖进度。原则是：放进 formal 的对象必须来自实际生产路径，不能使用单独
重写的 formal-only 逻辑替代生产 RTL/C helper。

当前计数：done=195 / open=2。本轮新增 MODE_CACHE MMIO read 与 MMIO write 同时
在途时请求 MODE_MAPPED 的 actual C++ trace 到实际 RTL subsystem 一致性检查，刻意让
MMIO `B` 先于 `R` 返回并先消费 write response，要求此时 active mode 仍不能完成切换、
后续 MMIO `RREADY` 也不能被回压，直到 read response 被上游消费后才允许进入
MODE_MAPPED。本轮此前新增 MODE_CACHE MMIO write 已发出且 upstream response
未 retire 时请求 MODE_MAPPED 的 actual C++ trace 到实际 RTL subsystem 一致性检查，
要求 MMIO `BREADY` 不被模式切换回压，且 active mode 必须等 MMIO write response
被上游消费后才能完成切换。本轮此前新增 MODE_CACHE MMIO read
已发出且 upstream response 未 retire 时请求 MODE_MAPPED 的 actual C++ trace 到实际
RTL subsystem 一致性检查，要求 MMIO `RREADY` 不被模式切换回压，且 active mode
必须等 MMIO read response 被上游消费后才能完成切换。本轮此前新增 actual `llc_cache_ctrl.v`
`invalidate_line` hit bounded formal，证明 accepted 后在 bounded window 内出现与 C++
trace 对齐的 valid clear payload；side-effect safety 仍由实际 RTL VCS trace contract
覆盖。本轮新增 MODE_CACHE `invalidate_line` 与 cacheable
write miss/refill + MMIO write 同时在途的 actual C++ trace 到实际 RTL subsystem
一致性检查，要求 MMIO `BREADY` 与 DDR refill `RREADY` 不被 maintenance 或 held
upstream response 回压，且 MMIO/cache write response 均 retire 后才允许 target-line
maintenance accepted。本轮此前新增 MODE_CACHE dirty victim writeback + pending
MMIO write + `invalidate_all` 同时存在的 actual C++ trace 到实际 RTL subsystem
一致性检查，要求 MMIO `BREADY` 与 DDR victim `BREADY` 不被 maintenance 或 held
upstream response 回压，且 MMIO/cache response retire 前 `invalidate_all_accepted=0`；
response retire 后因为仍存在 dirty resident line，`invalidate_all` 仍必须保持 blocked。
本轮此前新增 MODE_CACHE `invalidate_line` 与 cacheable read miss/refill + MMIO read
同时在途的 actual C++ trace 到实际 RTL subsystem 一致性检查，要求 MMIO/DDR
`RREADY` 不被 maintenance 或 held upstream response 回压，且 MMIO/cache response
均 retire 后才允许目标 line maintenance accepted。本轮此前新增 MODE_CACHE cacheable read miss/refill +
MMIO read + MMIO write 同时在途时拉起 `invalidate_all` 的 actual C++ trace 到实际
RTL subsystem 一致性检查，要求 MMIO `RREADY/BREADY` 与 DDR `RREADY` 不被
maintenance/held upstream response 回压，且只有 MMIO read/write response 与 cache
response 均 retire 后才允许 maintenance accepted。本轮此前新增 MODE_OFF 同一
upstream write master 两笔
DDR direct write 的多 ID / out-of-order `B` response actual C++ trace 到实际 RTL
subsystem 一致性检查，并将 C++ direct write response 路径改为按 master queue
buffer 外部 `B` response，避免上游 write response 被 hold 时无谓反压外部 `BREADY`；
本轮继续新增 MODE_CACHE cacheable read miss 的 DDR
refill `AR` 已发且 `R` 未返回时，同 line cacheable write 必须 `ready=0`、
不 accepted、且不向 DDR/MMIO 外部 `AW/W/AR` 逃逸的 actual C++ trace 到实际
RTL subsystem 一致性检查；本轮继续新增 MODE_OFF DDR direct-bypass write 的
`AW/W` 已发且 `B` 未返回时，同 line read 必须 `ready=0`、不 accepted、且不向
DDR/MMIO 外部 `AR/AW/W` 逃逸的 actual C++ trace 到实际 RTL subsystem 一致性检查；
本轮继续新增 actual native dual subsystem 下 DDR direct write `AW/W` 已发且
`B` 未返回时，MMIO read 仍可独立 accepted 并发出 MMIO `AR` 的 bounded formal；
并继续新增同条件下 MMIO write 仍可独立 accepted 并发出 MMIO `AW/W` 的 bounded
formal；本轮继续新增 actual native dual subsystem 下 DDR direct read `AR` 已发且
`R` 未返回时，MMIO read 仍可独立 accepted 并发出 MMIO `AR` 的 bounded formal；
本轮新增 MODE_MAPPED local-window actual C++ trace
到实际 RTL subsystem 的 write/read 一致性检查，并补齐 mapped-window 上/下边界外
MMIO read/write 双向路由检查，以及 mapped-window 跨界 8B unsupported blocked
检查；继续补齐 MODE_CACHE `invalidate_all` 挂起时新 read/write blocked，以及
`invalidate_all` 被接受并完成后 MMIO read 恢复的 actual C++ trace 到实际 RTL
subsystem 一致性检查；补齐 MODE_CACHE 到 MODE_MAPPED 真实 reconfig 后 MMIO read
恢复的 actual C++ trace 到实际 RTL subsystem 一致性检查；补齐 MODE_OFF DDR
16B read/write 以及 DDR 1B/2B/8B/32B 补充 size/offset 组合的 actual C++ trace
到实际 RTL subsystem size/pack/slice 一致性检查，
并补齐 MODE_MAPPED local-window 在当前 RTL contract 窗口内的起点
`0x30000000` 与末端 line `0x3001ffc0/0x3001fffc` 写后读边界一致性检查，
并补齐实际 RTL `llc_mapped_window_ctrl.v` 在生产 4MB window 参数下的
`0x303ffffc` 最后 4B 命中、同地址 8B 跨界阻断和 `0x30400000` 窗口外阻断，
并补齐 MODE_CACHE 下 MMIO read pending/response held 时 `invalidate_all` 不提前
accepted、外部 MMIO `RREADY` 不被回压、response retire 后才接受 maintenance 的
actual C++ trace 到实际 RTL subsystem 一致性检查；并补齐 MODE_CACHE 下 MMIO
write pending/B response held 时 `invalidate_all` 不提前 accepted、外部 MMIO
`BREADY` 不被回压、write response retire 后才接受 maintenance 的 actual C++ trace
到实际 RTL subsystem 一致性检查；并补齐 external MMIO `AR/AW/WVALID` 已经拉起
但尚未 handshake 时 `invalidate_all` 不能提前 accepted，直到对应 `R/B` 和 upstream
response 均 retire 后才接受 maintenance 的 pre-handshake actual C++ trace 到实际 RTL
subsystem 一致性检查；并补齐 MODE_CACHE 同 64B hazard granule direct MMIO read
pending write 持续保持时不提前外发 `AW/W` 的 actual C++ trace 到实际 RTL subsystem
一致性检查；并补齐对称的 MODE_CACHE 同 64B hazard granule direct MMIO write
pending read 场景，要求外部 `B` 未返回前 held read 不被错误接受、也不向 DDR/MMIO
外发新的 `AR/AW/W`；
并补齐 MODE_CACHE cache write miss/refill + pending MMIO write + `invalidate_all`
pending 场景，要求 MMIO `BREADY` 与 DDR `RREADY` 不被 held upstream response 或
maintenance 回压，且 cache write 留下 dirty resident line 后 `invalidate_all` 继续
blocked；
并补齐 dual bridge 生产宽度下 DDR cacheline read/write 与 MMIO 32-bit read/write
并发，以及 DDR cacheline read 与 MMIO 32-bit write 交叉并发、DDR cacheline
write 与 MMIO 32-bit read 对称交叉并发的 bridge-level bounded formal；继续补入
production-width same-line read-before-write / write-before-read 的 bridge-level safety smoke；
并补齐 production-width dual bridge bypass-source 64B read 的两拍 DDR `R` merge 和
512-bit response 回收 formal；
并补跑 `axi_llc_axi_bridge_dual` 子模块 DC link sanity；
并在父仓库临时适配 cacheability/MMIO 分类后，补跑 large + `CONFIG_BPU`
Linux 300k/5M commit sanity，确认不再触发低地址 cacheline read deadlock 且 300k
周期数未出现可见回退；并新增实际 `axi_llc_subsystem_core.v` startup idle RTL
contract，验证 reset 后 valid sweep 收敛到 MODE_CACHE idle 且无伪请求/响应；
并新增实际 `axi_llc_subsystem_dual.v` 在 8192 set / 16 way / 4MB mapped window
参数下的 production-size RTL contract，覆盖 `0x303ffffc` 窗口末端 4B local
write/read 写后读且不逃逸到 DDR/MMIO；并完成两个未纳入 stable manifest 的
hw-cbmc 入口分流：均保留为 experimental/non-stable，不作为当前生产 RTL 失败结论；
并扩展同一个 production-size native dual top RTL contract，在 MODE_OFF 下覆盖 64B
DDR direct read 的 `ARLEN=1`、两拍 256-bit `R` merge、`RLAST` 前不回包和 512-bit
upstream response 回收；继续扩展该 bench 在 MODE_CACHE 下覆盖 64B cacheable read
miss/refill 与随后同 line read hit，确认 miss 只发一笔 DDR `ARLEN=1` refill，hit
不再逃逸到 DDR/MMIO；并复核短门槛顺序：submodule 已在非 `main` 分支 push 备份后
继续长 `full_dc`，本轮再补跑 C++ 24/24、bridge dual response mux targeted VCS 和
全量 RTL contract 53/53；并补齐 dual bridge response stall 后 request issue 恢复
smoke，覆盖上游 read/write response stall 被释放后，相同 upstream ID 的新 DDR 请求
仍可重新 accepted、发出 AXI 并完成回包；并补齐 MODE_CACHE 下 cacheable read
miss/refill、MMIO read response held 与 `invalidate_all` 同时存在时的 drain/recovery
actual C++ trace 到实际 RTL subsystem 一致性检查，要求 MMIO/DDR `RREADY` 不因
maintenance pending 被回压，且 maintenance 只能在 MMIO/cache response 均 retire
后最终 accepted；并新增 production C helper `axi_bridge_downstream_read_issue_shape()`
到实际 `axi_llc_axi_bridge_dual.v` 的 hw-cbmc bounded EC，覆盖 nondet DDR/MMIO
bypass read issue shape 与 unsupported MMIO 阻断；并新增对称的 production C helper
`axi_bridge_downstream_write_issue_shape()` 到实际 `axi_llc_axi_bridge_dual.v`
的 hw-cbmc bounded EC，覆盖 nondet DDR/MMIO bypass write issue shape 与
unsupported MMIO ready/no-`AW` 阻断。
剩余 open 项主要集中在端到端 hw-cbmc 形式 EC、更完整 production-width cacheable
subsystem/formal 组合、RTL 可综合性/1GHz pre-DC gate，以及 Linux/image 级回归。

## 当前稳定回归

- [x] C++ regression：`ctest --test-dir build_dual_axi_scope_20260428 --output-on-failure`
  当前通过 24/24；最近一次复跑目录：
  `local_debug/ctest_invline_cache_mmio_write_20260506_130721.log`。
- [x] 2026-05-06 same-master write response queue 复核：targeted VCS
  `tb_axi_llc_subsystem_dual_cpp_trace_contract` 通过，目录
  `rtl/local_debug/vcs_dual_cpp_trace_same_master_write_20260506_020403_eda07`；
  C++ regression 24/24 通过；全量 RTL contract 53/53 通过，目录
  `rtl/local_debug/vcs_all_contracts_same_master_write_queue_20260506_020432_eda07`。
- [x] 2026-05-06 same-line write-pending/read RTL fix 复核：targeted VCS
  `tb_axi_llc_subsystem_dual_cpp_trace_contract` 通过，目录
  `rtl/local_debug/vcs_dual_cpp_trace_write_pending_read_fix_20260506_011527_eda10`；
  C++ regression 24/24 通过；全量 RTL contract 53/53 通过，目录
  `rtl/local_debug/vcs_all_contracts_after_write_pending_read_20260506_011554_eda10`。
- [x] 2026-05-06 push 前短门槛复核：`git diff --check` 通过；C++ regression 24/24
  通过；`cache_ctrl_*` hw-cbmc 4 项、`subsystem_dual_cache_*` hw-cbmc 3 项、
  production helper read/write issue-shape hw-cbmc 2 项均通过；并在 `eda-10`
  复跑 RTL dual-only 4/4 与全量 RTL contract 53/53。
- [x] C++ dual-port state-machine directed smoke：`axi_interconnect_dual_port_test`
  内部当前通过 38/38。
- [x] actual C++ LLC DCache read accepted/id parent-facing pulse smoke：
  `axi_interconnect_dual_port_test` 已补实际 `AXI_Interconnect` comb/seq 路径下
  `MASTER_DCACHE_R` cacheable read 被 LLC capture 后，下一拍 `req.accepted=1`
  且 `req.accepted_id` 等于原始 MSHR slot ID，并检查该 pulse 再下一拍清零。
- [x] actual C++ issue-shape wrapper regression：`axi_interconnect_issue_probe_test`
  已纳入 C++ regression；该测试通过 `AXI_Interconnect.cpp` 中实际 production probe
  wrapper 调用 comb 路径共用的 `make_downstream_read_issue` /
  `make_downstream_write_issue`，并对比生产 C helper
  `axi_bridge_downstream_*_issue_shape`，覆盖 DDR/MMIO、4B/8B/line 和 force-align 边界。
- [x] actual C++ MODE_OFF DDR direct read state-machine smoke：
  `axi_interconnect_dual_port_test` 已覆盖实际 `AXI_Interconnect` comb/seq 路径下，
  mode0 DDR 4B 未对齐、8B 对齐 direct read 和 64B cacheline 2-beat read 从 upstream
  request accept、DDR `AR` 对齐发射、DDR `R` beat 接收、aligned-beat slice / two-beat
  merge 到 upstream response retire 的闭环。该项只证明 C++ production state machine
  自洽，尚不是 RTL/C++ 同 harness EC。
- [x] actual C++ MODE_OFF DDR direct write state-machine smoke：
  `axi_interconnect_dual_port_test` 已覆盖实际 `AXI_Interconnect` comb/seq 路径下，
  mode0 DDR 4B 未对齐 direct write 和 64B cacheline 2-beat write 从 upstream request
  accept、DDR `AW/W` 对齐发射、256-bit `WDATA/WSTRB` lane 映射 / two-beat split、
  DDR `B` 接收，到 upstream write response retire 的闭环。该项只证明 C++
  production state machine 自洽，尚不是 RTL/C++ 同 harness EC。
- [x] actual C++ trace -> actual RTL subsystem functional EC：
  `axi_interconnect_dual_port_trace_vectors` 从实际 `AXI_Interconnect` comb/seq 路径生成
  `rtl/include/axi_dual_cpp_trace_vectors.vh`；`tb_axi_llc_subsystem_dual_cpp_trace_contract`
  直接实例化实际 `axi_llc_subsystem_dual.v`，消费该向量并覆盖 MODE_OFF 下 DDR
  4B/8B/64B read 和 4B/64B write 的 upstream 请求、DDR `AR/AW/W/R/B` 形状、
  256-bit beat packing/slicing、原 upstream ID response 回收，以及不误走 MMIO；同时覆盖
  MODE_OFF 下 MMIO 4B read/write 的 upstream 请求、MMIO `AR/AW/W/R/B` 形状、32-bit
  payload/strobe、原 upstream ID response 回收，以及不误走 DDR；还覆盖 unsupported
  MMIO 8B read/write 在 C++ 与 RTL 中均 `ready=0`、不 accepted、且不向任一外部
  AXI 口发出 `AR/AW/W`；并覆盖 MODE_OFF 下 DDR/MMIO read 同时在途、MMIO `R`
  先返回且上游 read response 被 stall 时外部 MMIO/DDR `RREADY` 仍按实际 C++ trace
  拉高并缓存 response，以及 DDR/MMIO write 同时在途、MMIO `B` 先返回且上游 write
  response 被 stall 时外部 MMIO/DDR `BREADY` 仍按实际 C++ trace 拉高并缓存 response。
  本轮新增 MODE_OFF 下 DDR 64B 两拍 read 与 MMIO 4B read 同时在途，检查 DDR
  `ARLEN=1`、两拍 `R` 合并、第一拍未提前回 upstream response、MMIO response 可先
  被缓存且不反压 DDR `RREADY`；并新增 DDR 64B 两拍 write 与 MMIO 4B write 同时
  在途，检查 DDR `AWLEN=1`、两拍 `W` split/strobe/last、MMIO `B` 可先被缓存且不反压
  DDR `BREADY`。本轮继续新增同一 upstream read master 多 ID DDR read 交错返回场景：
  后发请求先完成且 upstream response ready=0 时 response 必须按完成顺序 FIFO 保持，
  早发请求随后完成不能覆盖当前 held response，且外部 DDR `RREADY` 仍不被上游回压。
  还新增 read response retire 后的 release/reuse 场景：第一笔 DDR read 完成并被 upstream
  消费后，第二笔 DDR read 必须继续 accepted/发 `AR`，并复用已释放的 downstream AXI ID。
  本轮补充 write response retire 后的 release/reuse 场景：第一笔 DDR write 完成并被
  upstream 消费后，第二笔 DDR write 必须继续 accepted/发 `AW/W`，并复用已释放的
  downstream AWID。继续补充 read full-budget release 场景：实际 C++ 填满 32 个 read
  outstanding 后，第 33 笔 read 必须 `ready=0` 且不发 `AR`；消费一笔 response 后，
  新 read 必须重新 accepted/发 `AR` 并复用释放的 downstream ARID。继续补充 write
  full-budget release 场景：实际 C++ 填满 32 个 write outstanding 后，第 33 笔 write
  必须 `ready=0` 且不发 `AW/W`；消费一笔 `B` response 后，新 write 必须重新
  accepted/发 `AW/W` 并复用释放的 downstream AWID。由于 write 侧为 2 个 master、
  upstream ID 为 4 bit，32 笔填满时每个 master 的 0..15 ID 均在途；after-release
  请求显式使用刚释放的 upstream ID 0，避免把 ID conflict 误当成预算未释放。
  trace generator 同步修正了响应注入前先用空请求跑 `comb_inputs()` 的驱动顺序，避免
  测试向量生成时上一拍 `AR/AW/W` 输出在后续 `seq()` 中被重复登记。
  同一 bench 还覆盖 MODE_CACHE 下 MMIO 4B read/write 不进入 LLC core，
  而是按实际 C++ trace 直接走 MMIO AXI 口并回到原 upstream ID。本轮继续新增
  MODE_CACHE 下 cacheable read miss/refill 与 MMIO read direct-bypass 同时在途：
  cacheable read 先经实际 C++/RTL LLC lookup 发出 DDR 64B refill `ARLEN=1`，
  MMIO `R` 先返回且 upstream response stall 时，MMIO/DDR `RREADY` 均不被上游回压；
  DDR 两拍 `R` 回填后，cache response ID/data 与实际 C++ trace 一致。本轮继续新增
  同一 read 并发下拉起 `invalidate_all` 的 drain/recovery trace：MMIO read response
  被 upstream hold 时，DDR refill `RREADY` 仍不能被 maintenance 或 held MMIO response
  反压；MMIO response 与 cache response 均 retire 前，实际 RTL `invalidate_all_accepted`
  必须保持为 0，retire 后等待 RTL valid-sweep 完成并最终 accepted。该场景同时修复了
  C++ production trace/model 在两阶段 comb 顺序下可能重复发出同一 LLC refill `AR`
  的 stale request 问题，RTL contract 显式检查第一笔 DDR refill `AR` handshake 后
  下一拍不会重复发同地址 refill `AR`。本轮继续新增
  MODE_CACHE 下 partial cache write miss/refill 与 MMIO write direct-bypass
  同时在途：partial cache write miss 先经实际 C++/RTL LLC lookup 发出 DDR 64B refill
  `ARLEN=1`，refill 未返回时 MMIO 4B write 仍直接走独立 MMIO `AW/W/B`；MMIO `B`
  先返回且 upstream write response stall 时，MMIO `BREADY` 与 DDR `RREADY` 均不被上游
  回压；DDR 两拍 `R` 回填并 merge 后，cache write response ID/code 与实际 C++ trace 一致。
  本轮继续新增 MODE_CACHE 下 dirty victim writeback 与 MMIO write direct-bypass 同时
  在途：先通过实际 C++/RTL full-line write miss 安装两条同 set dirty line，第三笔
  full-line write miss 触发 DDR dirty victim `AW/W`；victim `B` 未返回时，另一 write
  master 的 MMIO 4B write 仍可经独立 MMIO `AW/W/B` 完成并 hold upstream response，
  且不反压后续 DDR victim `BREADY`；DDR `B` 返回后 cache write response ID/code 与
  实际 C++ trace 一致。该场景同时修正了生产 C++ dirty victim 语义：不再在 victim
  `WLAST` 后合成 OKAY，而是等待真实 downstream `B`；并将 C++ `BREADY` 计算收敛为
  per-target/slot 局部回压，避免 held MMIO response 错误阻塞 unrelated DDR victim `B`。
  本轮继续新增 MODE_MAPPED 下 mapped local-window full-line write 后局部 read：
  actual C++ trace 和实际 `axi_llc_subsystem_dual.v` 均要求写读请求不逃逸到 DDR/MMIO
  外部 AXI 口，write response ID/code 与 read response ID/data 一致，并覆盖 DCACHE_R
  同拍 ready/accept 的 trace driver 采样语义。随后补齐 MODE_MAPPED mapped-window
  边界外 MMIO 路由：`0x2ffffffc` 4B read/write 必须走 MMIO `AR/R` 或
  `AW/W/B`，`0x30400000` 4B read/write 也必须走 MMIO `AR/R` 或 `AW/W/B`，
  均不得逃逸到 DDR 或 LLC local path。
  还新增从 `0x303ffffc` 开始、跨出 4MB mapped window 的 8B read/write
  unsupported 场景：actual C++ trace 与实际 RTL subsystem 均要求 `ready=0`、
  不 accepted、且不向 DDR/MMIO 发 `AR/AW/W`。该场景暴露并修复了 C++ production
  LLC-enabled 路径把非 direct-mapped-local 的 unsupported MMIO 错误落入 LLC core
  capture 的问题。本轮继续新增实际 RTL `llc_mapped_window_ctrl.v` 在生产 4MB
  window 参数下的 helper 级边界合同：`0x303ffffc` 最后 4B 命中，
  同地址 8B 跨界阻断，`0x30400000` 与 `0x2ffffffc` 窗口外阻断。
  本轮继续新增 MODE_CACHE `invalidate_all` 挂起时新 read/write blocked：
  actual C++ trace 与实际 RTL subsystem 均要求新 upstream request `ready=0`、
  不 accepted、且不向 DDR/MMIO 发 `AR/AW/W`。
  本轮继续新增 MODE_CACHE cacheable read miss 的 DDR refill `AR` 已发且 `R`
  未返回时，同 line cacheable write 在 actual C++ 与实际 RTL subsystem 中均必须
  `ready=0`、不 accepted、且不向 DDR/MMIO 发出新的 `AW/W/AR`；该场景同步修正了
  C++ production write-ready 判定只检查外部 pending read、未覆盖 LLC 内部
  read/MSHR/refill pending 的语义缺口。
  本轮继续新增对称的 MODE_OFF DDR direct-bypass write 的 `AW/W` 已发且 `B`
  未返回时，同 line read 在 actual C++ 与实际 RTL subsystem 中均必须 `ready=0`、
  不 accepted、且不向 DDR/MMIO 发出新的 `AR/AW/W`；该场景同步修正了 RTL compat
  direct-bypass read ready 路径绕过 `local_write_line_pending` 的语义缺口，只对同
  line pending write 施加阻断，不串行化无关 line。
  为避免缩小 RTL 参数时 meta tag 截断 DDR 高位，该 trace contract 使用 2048 set /
  2-way 小缓存，使 `TAG_BITS <= META_BITS-1`，dirty victim 地址可完整重建为外部 DDR 地址。
  trace generator 使用 thin table adapter 只响应实际 C++ `AXI_Interconnect::get_llc_table_out()` 的表读，
  期望值仍来自 production C++ comb/seq，不重写 cache 行为 reference。
  2026-05-05 复核 trace 生成链路：`axi_interconnect_dual_port_trace_vectors` 重新生成的
  stdout Verilog include 与仓库 `rtl/include/axi_dual_cpp_trace_vectors.vh` byte-level
  一致，log 为 `local_debug/cpp_ec_sanity_20260505_194045_stderr_trace`；同时把
  `AXI_Interconnect` runtime config 诊断改为 stderr，避免污染后续 trace header 生成。
  最新 targeted VCS 目录：
  `rtl/local_debug/vcs_dual_cpp_trace_write_pending_read_fix_20260506_011527_eda10`。该项是
  trace-based 功能 EC，不等同于 hw-cbmc 端到端形式 EC。
- [x] actual C++ LLC cache trace -> actual RTL cache-control functional EC：
  `axi_llc_cache_trace_vectors` 从实际 `AXI_LLC` comb/seq 路径生成
  `rtl/include/axi_llc_cache_cpp_trace_vectors.vh`；`tb_llc_cache_ctrl_cpp_trace_contract`
  直接实例化实际 `llc_cache_ctrl.v`，消费该向量并覆盖 8B line/2-way 小参数下的
  partial write hit merge、read miss/refill/install/read response、partial write
  miss/refill/merge/install/write response、dirty victim full-line writeback/B 后
  install/write response、dirty victim + partial-write miss 先 refill/merge/install/回包并
  外部化 victim writeback，以及 `invalidate_line` hit 只清 valid 表、不写 meta/data/repl：
  lookup set、data/meta/valid/repl 写回、dirty/clean meta 更新、lower mem request/response、
  dirty victim 写回顺序，以及不误发 bypass request。
  最新 targeted VCS 目录：`rtl/local_debug/vcs_llc_cache_cpp_trace_dvpw_20260504_081121`。
  该项是 trace-based 功能 EC，meta/valid/repl 只做 C++ 抽象表项到 RTL row encoding
  的接口适配。
- [x] 稳定 formal smoke：`formal/run_passed_hw_cbmc.sh` 当前 manifest 为 79 项；
  `formal/*/run_hw_cbmc.sh` 当前共有 81 个入口，其中 2 个实验/未收敛入口暂未纳入
  稳定 manifest。原 68/68 已有 split-run 通过证据。前 20 项见
  `local_debug/run_passed_hw_cbmc_after_ddr_write_mmio_read_20260504_202454.log`；
  该 log 在 `dual_bridge_prod_width_ddr_read_mmio_write_independent` 处因默认 240s
  timeout wrapper 返回 124，但该 proof 本体已输出 `VERIFICATION SUCCESSFUL`；
  后续从该项开始用 `HW_CBMC_TIMEOUT_SEC=600` 继续跑 48/48 通过，log 为
  `local_debug/run_passed_hw_cbmc_tail_after_ddr_write_mmio_read_20260504_205451.log`
  （该临时 tail wrapper 末尾多解析了一条非 manifest 的脚本命令行，真实 manifest
  `RUN/PASS` 条目为 48/48）。
  本轮新增 `formal/dual_bridge_prod_width_cacheline_write_shape/run_hw_cbmc.sh` 和
  `formal/dual_bridge_prod_width_mode2_write/run_hw_cbmc.sh` targeted proof 均已通过并
  纳入 manifest；随后补入的
  `formal/dual_bridge_prod_width_cacheline_read_response/run_hw_cbmc.sh` 也已通过并纳入
  manifest；本轮继续补入并通过
  `formal/dual_bridge_prod_width_ddr_write_mmio_write_independent/run_hw_cbmc.sh`，覆盖
  生产宽度下 DDR 64B write 与 MMIO 32-bit write 的同周期独立发射；
  `formal/dual_bridge_prod_width_ddr_read_mmio_read_independent/run_hw_cbmc.sh` 和
  `formal/dual_bridge_prod_width_ddr_read_mmio_write_independent/run_hw_cbmc.sh` 也已通过
  并纳入 manifest，分别覆盖 DDR 64B read + MMIO 32-bit read、DDR 64B read +
  MMIO 32-bit write 的 production-width bridge-level 并发流；本轮新增
  `formal/dual_bridge_prod_width_ddr_write_mmio_read_independent/run_hw_cbmc.sh`，覆盖
  DDR 64B write + MMIO 32-bit read 的对称交叉并发流；本轮新增
  `formal/dual_bridge_prod_width_same_line_read_blocks_write/run_hw_cbmc.sh` 和
  `formal/dual_bridge_prod_width_same_line_write_blocks_read/run_hw_cbmc.sh`，分别覆盖
  production-width 下同 line DDR read 未完成前阻塞 write `AW/W`、同 line DDR write
  `B` 未返回前阻塞 read `AR` 的 bridge-level safety smoke，targeted logs 为
  `local_debug/hw_cbmc_dual_bridge_prod_width_same_line_read_blocks_write_witness_20260504_220600.log`
  和
  `local_debug/hw_cbmc_dual_bridge_prod_width_same_line_write_blocks_read_witness_20260504_220903.log`。
  2026-05-05 重新校准 71 项 manifest split-run 证据：前 20 项见
  `local_debug/run_passed_hw_cbmc_manifest71_20260505_144134.log`，该 log 在第 21 项
  本体已 `VERIFICATION SUCCESSFUL` 后因旧 240s timeout wrapper 退出；随后从第 21 项
  用 600s timeout 继续跑 51/51 通过，log 为
  `local_debug/run_passed_hw_cbmc_tail_manifest71_from21_20260505_151021.log`。
  之后新增并通过
  `formal/dual_bridge_prod_width_bypass_cacheline_read_response/run_hw_cbmc.sh`，targeted
  log 为
  `local_debug/hw_cbmc_dual_bridge_prod_width_bypass_cacheline_read_response_20260505_154112.log`，
  并已纳入 manifest；本轮新增并通过
  `formal/dual_bridge_prod_helper_read_issue_shape/run_hw_cbmc.sh`，targeted log 为
  `local_debug/hw_cbmc_dual_bridge_prod_helper_read_issue_shape_20260505_215117.log`，
  覆盖 production C helper `axi_bridge_downstream_read_issue_shape()` 与实际
  `axi_llc_axi_bridge_dual.v` 的 bypass read `AR` issue shape 一致性，并已纳入
  manifest；本轮新增并通过
  `formal/dual_bridge_prod_helper_write_issue_shape/run_hw_cbmc.sh`，targeted log 为
  `local_debug/hw_cbmc_dual_bridge_prod_helper_write_issue_shape_20260505_220230.log`，
  覆盖 production C helper `axi_bridge_downstream_write_issue_shape()` 与实际
  `axi_llc_axi_bridge_dual.v` 的 bypass write `AW` issue shape 一致性，并已纳入
  manifest；本轮新增并通过
  `formal/subsystem_dual_ddr_write_mmio_read_independent/run_hw_cbmc.sh`，targeted log 为
  `local_debug/hw_cbmc_subsystem_dual_ddr_write_mmio_read_independent_20260506_012742.log`，
  覆盖 native dual top 中 DDR direct write 已发 `AW/W` 且 `B` 未返回时，MMIO read
  仍可独立 accepted 并发出 MMIO `AR`，并已纳入 manifest；
  本轮新增并通过
  `formal/subsystem_dual_ddr_write_mmio_write_independent/run_hw_cbmc.sh`，targeted log 为
  `local_debug/hw_cbmc_subsystem_dual_ddr_write_mmio_write_independent_20260506_013416.log`，
  覆盖 native dual top 中 DDR direct write 已发 `AW/W` 且 `B` 未返回时，MMIO write
  仍可独立 accepted 并发出 MMIO `AW/W`，并已纳入 manifest；
  本轮新增并通过
  `formal/subsystem_dual_ddr_read_mmio_read_independent/run_hw_cbmc.sh`，targeted log 为
  `local_debug/hw_cbmc_subsystem_dual_ddr_read_mmio_read_independent_20260506_014057.log`，
  覆盖 native dual top 中 DDR direct read 已发 `AR` 且 `R` 未返回时，MMIO read
  仍可独立 accepted 并发出 MMIO `AR`，并已纳入 manifest；
  本轮新增并通过
  `formal/cache_ctrl_invalidate_line_hit/run_hw_cbmc.sh`，targeted log 为
  `local_debug/hw_cbmc_cache_ctrl_invalidate_line_hit_20260506_132948.log`，覆盖实际
  `llc_cache_ctrl.v` 在 `invalidate_line` hit 后产生与 C++ trace 对齐的 valid clear
  payload，并已纳入 manifest；
  `formal/run_passed_hw_cbmc.sh` 默认单项 timeout 已提升为 600s。
- [x] 全量 RTL contract：`rtl/run_all_contracts.sh` 当前通过 53/53，最新目录
  `rtl/local_debug/vcs_all_contracts_after_same_line_20260506_005229_eda10`。本轮新增
  `tb_axi_llc_subsystem_core_startup_idle_contract`，直接实例化实际
  `axi_llc_subsystem_core.v`，小参数/generic store 下验证 reset startup sweep 结束后
  `active_mode=MODE_CACHE`、`reconfig_state=IDLE`、`config_error=0`，且无意外
  upstream response、cache/bypass lower request 或 victim-line 输出；并新增
  `tb_axi_llc_subsystem_dual_mapped_window_prod_contract`，直接实例化实际
  `axi_llc_subsystem_dual.v` 的 8192 set / 16 way / 4MB mapped-window 参数，
  验证窗口末端 4B local write/read 写后读且不逃逸到 DDR/MMIO；该 bench 继续扩展
  MODE_OFF direct DDR 64B read，检查 `ARLEN=1`、两拍 `R` 合并、`RLAST` 前不回包和
  upstream 512-bit response 数据/ID；本轮继续扩展 MODE_CACHE 64B cacheable read
  miss/refill 与同 line hit，检查 refill 只向 DDR 发一笔 `ARLEN=1` 请求、两拍 `R`
  合并为 512-bit upstream response，随后 hit 不再向 DDR/MMIO 发 `AR/AW/W`。
- [x] native dual-AXI RTL contract：`rtl/run_dual_axi_contracts.sh` 当前通过 4/4，最新目录
  `rtl/local_debug/vcs_dual_axi_contracts_20260504_235450`。
- [x] `axi_llc_axi_bridge_dual` 子模块 DC link sanity：`AXI_LLC_DC_TOP=axi_llc_axi_bridge_dual`
  跑 `rtl/dc/run_dual_link_sanity.tcl` 当前通过 `LINK_SANITY_PASS`，run root 为
  `rtl/dc/runs/dual_link_sanity_20260504_222138`，log 为
  `rtl/dc/runs/link_sanity_bridge_dual_current_20260504_222137.log`。该入口使用当前
  production RTL flist 和 SMIC12 data/meta SRAM `.db`，生成
  `outputs/ddc/axi_llc_axi_bridge_dual_link_sanity.ddc`。耗时约 832s CPU、峰值约 5.2GB；
  `check_design` 仍有较多 LINT-1/LINT-52/高 fanout/signedness warning，需作为后续
  RTL hygiene 和时序检查输入，不把它等同于 1GHz setup 通过。
- [x] actual bridge read-route bounded formal：`formal/dual_bridge_read_route/run_hw_cbmc.sh`
  当前通过；使用实际 bridge/dual-bridge module body，formal top 仅做参数缩小和 tie-off。
- [x] actual bridge read-R-response bounded formal：
  `formal/dual_bridge_read_r_response/run_hw_cbmc.sh` 当前通过；使用实际
  bridge/dual-bridge module body，覆盖 4B read 的 `RREADY`、`RRESP`、`RDATA` merge 和
  cache response id/code/data 回收。
- [x] actual bridge write-route bounded formal：`formal/dual_bridge_write_route/run_hw_cbmc.sh`
  当前通过；使用实际 bridge/dual-bridge module body，覆盖 4B write 的 DDR/MMIO AW/W
  归属、基础 channel 形状，以及 unsupported MMIO 大 write 不被接受且不逃逸到任一
  AXI `AW/W` 口。
- [x] actual bridge write-B-response bounded formal：
  `formal/dual_bridge_write_b_response/run_hw_cbmc.sh` 当前通过；使用实际
  bridge/dual-bridge module body，覆盖 4B write 的 `BREADY`、`BRESP` 和 cache response
  id/code 回收。
- [x] actual bridge DDR multi-beat read bounded formal：
  `formal/dual_bridge_ddr_multibeat_read/run_hw_cbmc.sh` 当前通过；使用实际
  bridge/dual-bridge module body，以 16B line / 8B DDR beat 的同构 2-beat 参数覆盖
  cacheline read 的 `ARLEN=1`、两拍 `R` 合并、`RLAST` 前不回包和最终 id/code/data 回收。
- [x] actual bridge DDR multi-beat write bounded formal：
  `formal/dual_bridge_ddr_multibeat_write/run_hw_cbmc.sh` 当前通过；使用实际
  bridge/dual-bridge module body，以 16B line / 8B DDR beat 的同构 2-beat 参数覆盖
  cacheline write 的 `AWLEN=1`、两拍 `W` 数据顺序、`WSTRB` 和 `WLAST`。
- [x] actual bridge same-line read-blocks-write bounded formal：
  `formal/dual_bridge_same_line_read_blocks_write/run_hw_cbmc.sh` 当前通过；使用实际
  bridge/dual-bridge module body，覆盖 DDR read `AR` 发出后、对应 `R last` 接收前，
  同 line write 不得提前发出 `AW/W`，且 `R last` 后该 write 继续完成。
- [x] actual bridge same-line write-blocks-read bounded formal：
  `formal/dual_bridge_same_line_write_blocks_read/run_hw_cbmc.sh` 当前通过；使用实际
  bridge/dual-bridge module body，覆盖 DDR write `AW/W` 发出后、对应 `B` 接收前，
  同 line read 不得提前发出 `AR`，且 `B` 后该 read 继续完成。
- [x] actual bridge different-line multi-read outstanding bounded formal：
  `formal/dual_bridge_multi_read_outstanding/run_hw_cbmc.sh` 当前通过；使用实际
  bridge/dual-bridge module body，覆盖第一笔 DDR read 未收到 `R` 前，第二笔不同 line
  DDR read 仍可被接受并发出 `AR`，且两笔 read 使用不同 AXI ID。
- [x] actual bridge read-pending then different-line write bounded formal：
  `formal/dual_bridge_read_then_write_outstanding/run_hw_cbmc.sh` 当前通过；使用实际
  bridge/dual-bridge module body，覆盖 DDR read `AR` 已发出且未收到 `R` 时，不同 line
  DDR write 仍可被接受并继续发出 `AW/W`。
- [x] actual bridge write-pending then different-line read bounded formal：
  `formal/dual_bridge_write_then_read_outstanding/run_hw_cbmc.sh` 当前通过；使用实际
  bridge/dual-bridge module body，覆盖 DDR write `AW/W` 已发出且未收到 `B` 时，不同 line
  DDR read 仍可被接受并继续发出 `AR`。
- [x] actual bridge mode2 aligned write bounded formal：
  `formal/dual_bridge_mode2_aligned_write/run_hw_cbmc.sh` 当前通过；使用实际
  bridge/dual-bridge module body，覆盖 bypass mode2 DDR-aligned 4B write 的
  `AWADDR/AWLEN/AWSIZE`、`WDATA/WSTRB` 移位和 `B` 回包。
- [x] actual bridge mode2 aligned read bounded formal：
  `formal/dual_bridge_mode2_aligned_read/run_hw_cbmc.sh` 当前通过；使用实际
  bridge/dual-bridge module body，覆盖 bypass mode2 DDR-aligned 4B read 的
  `ARADDR/ARLEN/ARSIZE`、`RDATA` 截取和 `R` 回包。
- [x] actual bridge production-width cacheline AW/AR shape bounded formal：
  `formal/bridge_prod_width_cacheline_aw_shape/run_hw_cbmc.sh` 和
  `formal/bridge_prod_width_cacheline_ar_shape/run_hw_cbmc.sh` 当前通过；直接实例化实际
  `axi_llc_axi_bridge.v`，在 64B line / 32B DDR beat / 64B response buffer 参数下覆盖
  cacheline write/read 的 `AW/AR ADDR/LEN/SIZE/BURST` 形状。
- [x] actual bridge production-width cacheline write payload bounded formal：
  `formal/bridge_prod_width_cacheline_write_shape/run_hw_cbmc.sh` 当前通过；直接实例化实际
  `axi_llc_axi_bridge.v`，在 64B line / 32B DDR beat 参数下覆盖 cacheline write 的两拍
  256-bit `W` payload、32-bit `WSTRB` 和 `WLAST`。
- [x] actual bridge production-width cacheline read response bounded formal：
  `formal/bridge_prod_width_cacheline_read_response/run_hw_cbmc.sh` 当前通过；直接实例化实际
  `axi_llc_axi_bridge.v`，在 64B line / 32B DDR beat 参数下覆盖 cacheline read 的两拍
  256-bit `R` payload、`RREADY`、`RLAST` 前不回包和 512-bit upstream response 回收。
- [x] actual dual bridge production-width cacheline AR-shape bounded formal：
  `formal/dual_bridge_prod_width_cacheline_ar_shape/run_hw_cbmc.sh` 当前通过；直接实例化实际
  `axi_llc_axi_bridge_dual.v`，在 64B line / 32B DDR beat 参数下覆盖 dual bridge cache
  source 64B read 必须非空发出 DDR `AR`，`ARADDR/ARLEN/ARSIZE/ARBURST` 形状正确，且
  不误发 MMIO 或 write channel。该入口暴露并已修复 scoreboard pending hazard 显式 valid
  gate / dual bridge 隐式 net 缺口。
- [x] actual dual bridge production-width cacheline read response bounded formal：
  `formal/dual_bridge_prod_width_cacheline_read_response/run_hw_cbmc.sh` 当前通过；直接实例化
  实际 `axi_llc_axi_bridge_dual.v`，在 64B line / 32B DDR beat 参数下覆盖 cache source
  64B read 的两拍 DDR `R` 接收、`RREADY`、`RLAST` 前不回包、512-bit upstream data 拼接、
  `id/code` 回收，且不误向 MMIO read response 通道拉 `RREADY`。
- [x] actual dual bridge production-width bypass cacheline read response bounded formal：
  `formal/dual_bridge_prod_width_bypass_cacheline_read_response/run_hw_cbmc.sh` 当前通过；
  直接实例化实际 `axi_llc_axi_bridge_dual.v`，在 64B line / 32B DDR beat 参数下覆盖
  bypass source 64B read 的两拍 DDR `R` 接收、`RREADY`、`RLAST` 前不回包、512-bit
  upstream data 拼接、`id/code` 回收，用于替代 monolithic native top production-width
  direct-bypass read-response proof 的过重部分。
- [x] actual dual bridge production-width cacheline write payload bounded formal：
  `formal/dual_bridge_prod_width_cacheline_write_shape/run_hw_cbmc.sh` 当前通过；直接实例化
  实际 `axi_llc_axi_bridge_dual.v`，在 64B line / 32B DDR beat 参数下覆盖 cache source
  64B write 必须发出 DDR `AW`，两拍 256-bit `W` payload、32-bit `WSTRB` 和 `WLAST`
  形状正确，且不误发 MMIO `AW/W`。
- [x] actual dual bridge production-width mode2 write bounded formal：
  `formal/dual_bridge_prod_width_mode2_write/run_hw_cbmc.sh` 当前通过；直接实例化实际
  `axi_llc_axi_bridge_dual.v`，在 64B line / 32B DDR beat 参数下覆盖 bypass/mode2 4B
  write 发到 DDR 256-bit 单 beat，检查 `AWADDR/AWLEN/AWSIZE`、按 offset 移位后的
  `WDATA/WSTRB/WLAST`、不误发 MMIO `AW/W`，以及 DDR `B` 到 upstream bypass response 的
  `id/code` 回收。
- [x] actual dual bridge production-width DDR read + MMIO read independent bounded formal：
  `formal/dual_bridge_prod_width_ddr_read_mmio_read_independent/run_hw_cbmc.sh` 当前通过；
  直接实例化实际 `axi_llc_axi_bridge_dual.v`，在 64B line / 32B DDR beat 参数下覆盖
  cache source DDR 64B read 与 bypass source MMIO 32-bit read 同周期接受，两个外部
  `AR` 通道同时可见且形状正确；MMIO `R` 先返回时 bypass response 正确，且不阻塞
  pending DDR read 的 `RREADY`；DDR 两拍 `R` 后 cache response data/id/code 正确。
- [x] actual dual bridge production-width DDR read + MMIO write independent bounded formal：
  `formal/dual_bridge_prod_width_ddr_read_mmio_write_independent/run_hw_cbmc.sh` 当前通过；
  直接实例化实际 `axi_llc_axi_bridge_dual.v`，在 64B line / 32B DDR beat 参数下覆盖
  cache source DDR 64B read 与 bypass source MMIO 32-bit write 同周期接受，DDR `AR`
  与 MMIO `AW` 同时可见且形状正确；MMIO `W/B` 完成并先返回时 bypass write response
  正确，且不阻塞 pending DDR read 的 `RREADY`；DDR 两拍 `R` 后 cache response
  data/id/code 正确。
- [x] actual dual bridge production-width DDR write + MMIO read independent bounded formal：
  `formal/dual_bridge_prod_width_ddr_write_mmio_read_independent/run_hw_cbmc.sh`
  当前通过；直接实例化实际 `axi_llc_axi_bridge_dual.v`，在 64B line / 32B DDR beat
  参数下覆盖 cache source DDR 64B write 与 bypass source MMIO 32-bit read 同周期
  接受，DDR `AW` 与 MMIO `AR` 同时可见且形状正确；DDR 两拍 `W`
  payload/strobe/last 正确，MMIO `R` 在 DDR write 仍 pending 时可被接收并返回
  bypass response，且不误发 DDR read 或 MMIO write channel。
- [x] actual dual bridge production-width DDR write + MMIO write independent bounded formal：
  `formal/dual_bridge_prod_width_ddr_write_mmio_write_independent/run_hw_cbmc.sh` 当前通过；
  直接实例化实际 `axi_llc_axi_bridge_dual.v`，在 64B line / 32B DDR beat 参数下覆盖
  cache source DDR 64B write 与 bypass source MMIO 32-bit write 同周期接受，两个外部
  `AW` 和首个 `W` 通道均同时可见且 shape/payload/strobe 正确，不退化成单口串行化。
- [x] actual dual bridge production-width same-line read-before-write safety formal：
  `formal/dual_bridge_prod_width_same_line_read_blocks_write/run_hw_cbmc.sh` 当前通过；
  直接实例化实际 `axi_llc_axi_bridge_dual.v`，在 64B line / 32B DDR beat 参数下覆盖
  DDR cacheline read 的 `AR` 已发出但 `R` 未返回前，同 line write 即使被上游接受排队，
  也不得向 DDR 发出 `AW/W`，且不得误走 MMIO write channel。
- [x] actual dual bridge production-width same-line write-before-read safety formal：
  `formal/dual_bridge_prod_width_same_line_write_blocks_read/run_hw_cbmc.sh` 当前通过；
  直接实例化实际 `axi_llc_axi_bridge_dual.v`，在 64B line / 32B DDR beat 参数下覆盖
  DDR cacheline write 的 `AW/WLAST` 已发出但 `B` 未返回前，同 line read 即使被上游接受
  排队，也不得向 DDR 发出 `AR`，且不得误走 MMIO read channel。
- [x] actual cache-control dirty eviction writeback bounded formal：
  `formal/cache_ctrl_dirty_evict_writeback/run_hw_cbmc.sh` 当前通过；直接实例化实际
  `llc_cache_ctrl.v`，覆盖 valid+dirty 满 set 下 full-line write miss 必须先发 dirty
  victim writeback，`mem_req` 地址/数据/strobe/size 正确，writeback response 后再安装
  新 dirty line 并返回 write response。
- [x] actual cache-control partial write miss refill bounded formal：
  `formal/cache_ctrl_partial_write_miss_refill/run_hw_cbmc.sh` 当前通过；直接实例化实际
  `llc_cache_ctrl.v`，覆盖空 set 下 partial write miss 必须先发整行 refill read，
  refill response 后按 offset/`WSTRB` merge 写数据，安装 valid+dirty line 并返回 write
  response。
- [x] actual cache-control read miss refill response bounded formal：
  `formal/cache_ctrl_read_miss_refill_response/run_hw_cbmc.sh` 当前通过；直接实例化实际
  `llc_cache_ctrl.v`，覆盖空 set 下 read miss 必须先发整行 refill read，refill
  response 后安装 valid+clean line，并返回 upstream read id/code/data。
- [x] actual cache-control partial write hit merge bounded formal：
  `formal/cache_ctrl_partial_write_hit_merge/run_hw_cbmc.sh` 当前通过；直接实例化实际
  `llc_cache_ctrl.v`，覆盖 clean line 命中 partial write 时不发外部 memory request，
  按 offset/`WSTRB` merge 写数据，meta 变 dirty，并返回 upstream write id/code。
- [x] actual cache-control invalidate_line hit valid-clear bounded formal：
  `formal/cache_ctrl_invalidate_line_hit/run_hw_cbmc.sh` 当前通过；直接实例化实际
  `llc_cache_ctrl.v`，覆盖命中 dirty line 的 `invalidate_line` 被接受后，在 bounded
  window 内出现与 C++ trace 对齐的 valid clear payload：`valid_wr_mask=2'b10`、
  `valid_wr_bits=2'b00`。同周期不误写 data/meta/repl、不发 lower/bypass/response
  的 side-effect safety 仍由 `tb_llc_cache_ctrl_cpp_trace_contract` 直接覆盖，最近一次
  targeted VCS 目录为
  `rtl/local_debug/vcs_llc_cache_ctrl_cpp_trace_invline_formal_boundary_20260506_133152_eda10`。
- [x] actual native dual subsystem MMIO read-route bounded formal：
  `formal/subsystem_dual_mmio_read_route/run_hw_cbmc.sh` 当前通过；直接实例化实际
  `axi_llc_subsystem_dual.v`，覆盖 4B MMIO read 被接受后只向 MMIO `AR` 发出，且
  `ARADDR/ARLEN/ARSIZE/ARBURST` 正确、不得误发 DDR `AR/AW/W`；同一入口也覆盖
  unsupported MMIO 大 read 在 top 接受面不被接受且不逃逸到 DDR/MMIO `AR`。
- [x] actual native dual subsystem MMIO read-response bounded formal：
  `formal/subsystem_dual_mmio_read_response/run_hw_cbmc.sh` 当前通过；直接实例化实际
  `axi_llc_subsystem_dual.v`，覆盖 MMIO `R` 被接受后 upstream `read_resp_valid/id/data`
  端到端回收正确。
- [x] actual native dual subsystem MMIO write-route bounded formal：
  `formal/subsystem_dual_mmio_write_route/run_hw_cbmc.sh` 当前通过；直接实例化实际
  `axi_llc_subsystem_dual.v`，覆盖 4B MMIO write 被接受后只向 MMIO `AW/W` 发出，
  且 `AWADDR/AWLEN/AWSIZE/AWBURST`、`WDATA/WSTRB/WLAST` 正确，不得误发 DDR
  `AR/AW/W` 或 MMIO `AR`；同一入口也覆盖 unsupported MMIO 大 write 在 top 接受面
  不被接受且不逃逸到 DDR/MMIO `AW/W`。
- [x] actual native dual subsystem MMIO write-response bounded formal：
  `formal/subsystem_dual_mmio_write_response/run_hw_cbmc.sh` 当前通过；直接实例化实际
  `axi_llc_subsystem_dual.v`，覆盖 MMIO `B` 被接受后 upstream `write_resp_valid/id/code`
  端到端回收正确。
- [x] actual native dual subsystem DDR-read/MMIO-read independent bounded formal：
  `formal/subsystem_dual_ddr_read_mmio_read_independent/run_hw_cbmc.sh` 当前通过；直接
  实例化实际 `axi_llc_subsystem_dual.v`，覆盖 DDR 4B read 已经发出 `AR` 且未返回
  `R` 时，MMIO 4B read 仍可被接受并发向 MMIO `AR`，不得误发 DDR `AW/W` 或 MMIO
  `AW/W`。
- [x] actual native dual subsystem DDR-read/MMIO-write independent bounded formal：
  `formal/subsystem_dual_ddr_read_mmio_write_independent/run_hw_cbmc.sh` 当前通过；直接
  实例化实际 `axi_llc_subsystem_dual.v`，覆盖 DDR 4B read 未返回 `R`、MMIO 4B write
  未返回 `B` 时，两笔 direct-bypass 请求仍可被接受并分别发向 DDR `AR` 与 MMIO `AW/W`。
- [x] actual native dual subsystem DDR-write/MMIO-read independent bounded formal：
  `formal/subsystem_dual_ddr_write_mmio_read_independent/run_hw_cbmc.sh` 当前通过；直接
  实例化实际 `axi_llc_subsystem_dual.v`，覆盖 DDR 4B write 已经发出 `AW/W` 且未返回
  `B` 时，MMIO 4B read 仍可被接受并发向 MMIO `AR`，不得误发 DDR `AR` 或 MMIO
  `AW/W`。
- [x] actual native dual subsystem DDR-write/MMIO-write independent bounded formal：
  `formal/subsystem_dual_ddr_write_mmio_write_independent/run_hw_cbmc.sh` 当前通过；直接
  实例化实际 `axi_llc_subsystem_dual.v`，覆盖 DDR 4B write 已经发出 `AW/W` 且未返回
  `B` 时，MMIO 4B write 仍可被接受并发向 MMIO `AW/W`，不得误发 DDR `AR` 或 MMIO
  `AR`。
- [x] actual native dual subsystem cache-refill/MMIO-read independent bounded formal：
  `formal/subsystem_dual_cache_refill_mmio_read_independent/run_hw_cbmc.sh` 当前通过；直接
  实例化实际 `axi_llc_subsystem_dual.v`，覆盖 MODE_CACHE 下 DDR cache miss/refill
  `AR` 被 `DDR_ARREADY=0` hold 时，4B MMIO read 仍可被接受并发出 MMIO `AR`。
- [x] actual native dual subsystem cache-refill/MMIO-write independent bounded formal：
  `formal/subsystem_dual_cache_refill_mmio_write_independent/run_hw_cbmc.sh` 当前通过；直接
  实例化实际 `axi_llc_subsystem_dual.v`，覆盖 MODE_CACHE 下 DDR cache miss/refill
  `AR` 被 `DDR_ARREADY=0` hold 时，4B MMIO write 仍可被接受并发出 MMIO `AW/W`。
- [x] actual native dual subsystem cache-refill response bounded formal：
  `formal/subsystem_dual_cache_refill_response/run_hw_cbmc.sh` 当前通过；直接实例化实际
  `axi_llc_subsystem_dual.v`，覆盖 MODE_CACHE 下 DDR cache miss/refill `AR` 握手、
  DDR `R` 接收、`RREADY` 以及 upstream `read_resp_valid/id/data` 回收。
- [x] actual native dual subsystem cache fill-hit response bounded formal：
  `formal/subsystem_dual_cache_fill_hit_response/run_hw_cbmc.sh` 当前通过；直接实例化实际
  `axi_llc_subsystem_dual.v`，覆盖 MODE_CACHE 下第一次 cache miss/refill 返回后，
  第二次同地址 read 命中已安装 cacheline，不再发出第二个 DDR `AR`，并回收新的
  upstream response ID/data。
- [x] actual native dual subsystem cache full-line write-hit response bounded formal：
  `formal/subsystem_dual_cache_full_write_hit_response/run_hw_cbmc.sh` 当前通过；直接实例化
  实际 `axi_llc_subsystem_dual.v`，覆盖 MODE_CACHE 下空 cache 的 full-line write miss
  直接安装 dirty line、不误发 DDR/MMIO 外部访问，写响应后同地址 read 命中并返回写入数据。
- [x] actual native dual subsystem mode0 DDR bypass align bounded formal：
  `formal/subsystem_dual_mode0_ddr_bypass_align/run_hw_cbmc.sh` 当前通过；直接实例化实际
  `axi_llc_subsystem_dual.v`，并引用生产 C++ 共用 helper，覆盖 MODE_OFF/direct-bypass
  下 4B 未对齐/8B 对齐 DDR read 和 4B 未对齐 DDR write 必须对齐到 DDR beat，
  `AR/AW LEN/SIZE`、write payload/strobe byte lane 与 C++ helper 一致，且不得误走 MMIO。
- [x] actual native dual subsystem mode0 DDR bypass read-response bounded formal：
  `formal/subsystem_dual_mode0_ddr_bypass_read_response/run_hw_cbmc.sh` 当前通过；直接实例化
  实际 `axi_llc_subsystem_dual.v`，并引用生产 C++ 共用 helper，覆盖 MODE_OFF/direct-bypass
  下未对齐 4B DDR read 的 `RREADY`、DDR `RDATA` byte slice、upstream
  `read_resp_valid/id/data` 与 C++ read-pack helper 一致。
- [x] actual native dual subsystem mode0 DDR bypass 8B read-response bounded formal：
  `formal/subsystem_dual_mode0_ddr_bypass_read_response_8b/run_hw_cbmc.sh` 当前通过；复用同一
  actual native dual top 和生产 C++ helper，对 MODE_OFF/direct-bypass 8B 对齐 DDR read
  的 `AR` shape、`RREADY` 和 upstream `read_resp_valid/id/data` 回收进行独立确定性覆盖。
- [x] actual native dual subsystem dirty-evict writeback AW/W bounded formal：
  `formal/subsystem_dual_cache_dirty_evict_writeback/run_hw_cbmc.sh` 当前通过；直接实例化
  实际 `axi_llc_subsystem_dual.v`，覆盖 MODE_CACHE 下三笔同 set full-line write miss 中
  第三笔必须触发 dirty victim DDR writeback，且 `AW/W` 地址、数据、strobe、last 形状正确，
  不得误发 DDR `AR` 或 MMIO `AR/AW/W`，并且未收到 `B` 前不得提前返回第三笔写响应。
- [x] actual native dual subsystem dirty-evict writeback B-response bounded formal：
  `formal/subsystem_dual_cache_dirty_evict_b_response/run_hw_cbmc.sh` 当前通过；直接实例化
  实际 `axi_llc_subsystem_dual.v`，覆盖 dirty victim DDR `AW/W` 握手后接收匹配 `BID` 的
  DDR `B`，要求 `BREADY` 拉高，且第三笔 upstream write response 只能在 `B` 被接受或同拍
  接受后返回，`id/code` 正确。
- [x] actual native dual subsystem dirty-evict post-B read-hit bounded formal：
  `formal/subsystem_dual_cache_dirty_evict_post_b_hit/run_hw_cbmc.sh` 当前通过；直接实例化
  实际 `axi_llc_subsystem_dual.v`，覆盖 dirty victim DDR `AW/W/B` 完成并返回第三笔
  upstream write response 后，对第三笔地址发起 read 必须命中新安装的 dirty line，不得再发
  DDR `AR` 或 MMIO 访问，且 read response `id/data` 正确。

## 已收敛的生产 C/RTL helper

- [x] `rtl/src/axi_llc_axi_id_shape.v`：AXI ID width resize。
- [x] `rtl/src/axi_llc_axi_beat_shape.v`：AXI `len/size/total_beats` shape。
- [x] `rtl/src/axi_llc_axi_mode2_shape.v`：mode2 aligned issue addr/size shape。
- [x] `rtl/src/axi_llc_axi_pending_scan.v`：pending slot / AXI ID / response match scan。
- [x] `rtl/src/axi_llc_axi_issue_select.v`：queue-head `AR/AW/W` issue select。
- [x] `rtl/src/axi_llc_axi_fifo_ptr.v`：FIFO head/tail/count update。
- [x] `rtl/src/axi_llc_axi_queue_ctrl.v`：queue space / valid / handshake / push-pop control。
- [x] `rtl/src/axi_llc_axi_write_pack.v`：AXI `W` data/strobe packing；已补
  `formal/axi_write_pack_prod_width` 覆盖 64B line / 32B DDR beat 生产宽度。
- [x] `rtl/src/axi_llc_axi_read_pack.v`：AXI `R` beat merge / mode2 read extract；已补
  `formal/axi_read_pack_prod_width` 覆盖 64B response / 32B DDR beat 生产宽度。
- [x] `rtl/src/axi_llc_axi_read_resp_ctrl.v`：AXI `R` last-beat / response-code accumulation。
- [x] `rtl/src/axi_llc_axi_req_accept.v`：cache/bypass request accept control。
- [x] `rtl/src/axi_llc_axi_resp_accept.v`：AXI `R/B` accept/ready control。
- [x] `rtl/src/axi_llc_axi_resp_route.v`：response owner route / response queue push。
- [x] `rtl/src/axi_llc_axi_source_resp_mux.v`：source-local read/write response mux/pop。
- [x] `rtl/src/axi_llc_dual_port_route_shape.v`：DDR/MMIO address route/support 和
  `axi_len/axi_size` shape；`formal/dual_port_route_shape` 已对比生产 C helper。
- [x] `rtl/src/axi_llc_dual_port_req_steer.v`：single upstream request to DDR/MMIO steering。
- [x] `rtl/src/axi_llc_dual_port_issue_gate.v`：same-line `AR/AW` hazard issue gate。
- [x] `rtl/src/axi_llc_dual_port_hazard_match.v`：scoreboard entry line/id match。
- [x] `rtl/src/axi_llc_dual_port_slot_hazard.v`：shared scoreboard slot hazard。
- [x] `rtl/src/axi_llc_dual_port_hazard_scoreboard.v`：小参数 sequential formal 覆盖
  `AR/AW` hazard 记录与 `R/B` 匹配释放；`formal/dual_port_hazard_scoreboard_one_entry`
  已在 2026-05-04 重跑通过并纳入 `formal/run_passed_hw_cbmc.sh`，生产实例仍由 bridge
  显式覆盖为 64-entry。
- [x] `rtl/src/axi_llc_dual_port_resp_mux.v`：DDR/MMIO response mux and ready routing。
- [x] `formal/cache_ctrl_dirty_evict_writeback`：actual `llc_cache_ctrl.v` bounded smoke，
  覆盖 dirty victim writeback 和 writeback response 后安装新 dirty line。
- [x] `formal/cache_ctrl_partial_write_miss_refill`：actual `llc_cache_ctrl.v` bounded
  smoke，覆盖 partial write miss 先 refill、再按 byte strobe merge 并安装 dirty line。
- [x] `formal/cache_ctrl_read_miss_refill_response`：actual `llc_cache_ctrl.v` bounded
  smoke，覆盖 read miss 先 refill、安装 clean line 并返回 refill data。
- [x] `formal/cache_ctrl_partial_write_hit_merge`：actual `llc_cache_ctrl.v` bounded
  smoke，覆盖 partial write hit 的 byte merge、clean-to-dirty meta 更新和 write response。
- [x] `formal/dual_bridge_read_route`：actual bridge/dual-bridge 小参数 bounded
  read-route smoke，覆盖 supported DDR/MMIO read 被接受后只能向对应 `AR` 口发出。
- [x] `formal/dual_bridge_read_r_response`：actual bridge/dual-bridge 小参数 bounded
  read response smoke，覆盖 4B read 的外部 `R` 被正确端口接收并回到 cache source。
- [x] `formal/dual_bridge_write_route`：actual bridge/dual-bridge 小参数 bounded
  write-route smoke，覆盖 4B write 被接受后只能向对应 DDR/MMIO `AW/W` 口发出，
  并覆盖 unsupported MMIO 大 write 不被接受且不逃逸到任一 AXI `AW/W` 口。
- [x] `formal/dual_bridge_write_b_response`：actual bridge/dual-bridge 小参数 bounded
  write response smoke，覆盖 4B write 的外部 `B` 被正确端口接收并回到 cache source。
- [x] `formal/dual_bridge_ddr_multibeat_read`：actual bridge/dual-bridge 小参数
  bounded multi-beat read smoke，覆盖同构 2-beat DDR cacheline read。
- [x] `formal/dual_bridge_ddr_multibeat_write`：actual bridge/dual-bridge 小参数
  bounded multi-beat write smoke，覆盖同构 2-beat DDR cacheline write。
- [x] `formal/dual_bridge_same_line_read_blocks_write`：actual bridge/dual-bridge
  小参数 bounded smoke，覆盖同 line read pending 期间阻塞后续 write `AW/W`。
- [x] `formal/dual_bridge_same_line_write_blocks_read`：actual bridge/dual-bridge
  小参数 bounded smoke，覆盖同 line write pending 期间阻塞后续 read `AR`。
- [x] `formal/dual_bridge_multi_read_outstanding`：actual bridge/dual-bridge 小参数
  bounded smoke，覆盖不同 line DDR read 在无 `R` 返回前不被串行化，并使用不同 AXI ID。
- [x] `formal/dual_bridge_read_then_write_outstanding`：actual bridge/dual-bridge 小参数
  bounded smoke，覆盖 read pending 期间不同 line write 不被串行化。
- [x] `formal/dual_bridge_write_then_read_outstanding`：actual bridge/dual-bridge 小参数
  bounded smoke，覆盖 write pending 期间不同 line read 不被串行化。
- [x] `formal/dual_bridge_mode2_aligned_write`：actual bridge/dual-bridge 小参数
  bounded smoke，覆盖 bypass mode2 aligned write 的 DDR beat 对齐、data/strobe
  移位和 response 回收。
- [x] `formal/dual_bridge_mode2_aligned_read`：actual bridge/dual-bridge 小参数
  bounded smoke，覆盖 bypass mode2 aligned read 的 DDR beat 对齐、read slice
  和 response 回收。
- [x] `formal/bridge_prod_width_cacheline_aw_shape`：actual bridge 生产宽度 bounded
  smoke，覆盖 64B cacheline write 的 `AWADDR/AWLEN/AWSIZE/AWBURST`。
- [x] `formal/bridge_prod_width_cacheline_ar_shape`：actual bridge 生产宽度 bounded
  smoke，覆盖 64B cacheline read 的 `ARADDR/ARLEN/ARSIZE/ARBURST`。
- [x] `formal/bridge_prod_width_cacheline_write_shape`：actual bridge 生产宽度 bounded
  smoke，覆盖 64B cacheline write 的两拍 256-bit `W` payload、`WSTRB` 和 `WLAST`。
- [x] `formal/bridge_prod_width_cacheline_read_response`：actual bridge 生产宽度 bounded
  smoke，覆盖 64B cacheline read 的两拍 256-bit `R` payload、`RREADY`、`RLAST` 前不回包
  和最终 512-bit response id/code/data 回收。
- [x] `formal/dual_bridge_prod_width_cacheline_ar_shape`：actual dual bridge 生产宽度
  bounded smoke，覆盖 64B cacheline read 的 DDR `ARADDR/ARLEN/ARSIZE/ARBURST` 和不误走
  MMIO/write channel。
- [x] `formal/dual_bridge_prod_width_cacheline_read_response`：actual dual bridge 生产宽度
  bounded smoke，覆盖 64B cacheline read 的两拍 DDR `R` 接收、`RREADY`、`RLAST` 前不回包、
  512-bit response id/code/data 回收，以及不误走 MMIO read response。
- [x] `formal/dual_bridge_prod_width_bypass_cacheline_read_response`：actual dual bridge
  生产宽度 bounded smoke，覆盖 bypass source 64B cacheline read 的两拍 DDR `R`
  接收、`RREADY`、`RLAST` 前不回包、512-bit response id/code/data 回收，用于分担
  native top MODE_OFF direct-bypass 64B read response 的 production-width 覆盖。
- [x] `formal/dual_bridge_prod_width_cacheline_write_shape`：actual dual bridge 生产宽度
  bounded smoke，覆盖 64B cacheline write 的 DDR `AW`、两拍 256-bit `W` payload、
  `WSTRB/WLAST` 和不误走 MMIO write channel。
- [x] `formal/dual_bridge_prod_width_mode2_write`：actual dual bridge 生产宽度 bounded
  smoke，覆盖 bypass/mode2 4B write 到 DDR 256-bit beat 的 `AW/W` 形状、payload/strobe
  移位和 `B` response 回收。
- [x] `formal/dual_bridge_prod_width_ddr_read_mmio_read_independent`：actual dual bridge
  生产宽度 bounded smoke，覆盖 DDR 64B read 与 MMIO 32-bit read 同周期接受、双 `AR`
  同时发射、MMIO `R` 先返回不阻塞 DDR `RREADY`，以及 DDR 两拍 `R` 后 cache response。
- [x] `formal/dual_bridge_prod_width_ddr_read_mmio_write_independent`：actual dual bridge
  生产宽度 bounded smoke，覆盖 DDR 64B read 与 MMIO 32-bit write 同周期接受、DDR
  `AR` 与 MMIO `AW/W` 发射、MMIO `B` 先返回不阻塞 DDR `RREADY`，以及 DDR 两拍
  `R` 后 cache response。
- [x] `formal/dual_bridge_prod_width_ddr_write_mmio_write_independent`：actual dual bridge
  生产宽度 bounded smoke，覆盖 DDR 64B write 与 MMIO 32-bit write 同周期接受、双 `AW`
  和首个 `W` 同时发射，以及对应 shape/payload/strobe。
- [x] `formal/dual_bridge_prod_width_same_line_read_blocks_write`：actual dual bridge
  生产宽度 safety smoke，覆盖 DDR 64B read 未完成前，同 line write 不得逃逸到 DDR
  `AW/W` 或 MMIO write channel。
- [x] `formal/dual_bridge_prod_width_same_line_write_blocks_read`：actual dual bridge
  生产宽度 safety smoke，覆盖 DDR 64B write 未收到 `B` 前，同 line read 不得逃逸到
  DDR `AR` 或 MMIO read channel。
- [x] `formal/subsystem_dual_mode0_ddr_bypass_align`：actual native dual top 小参数
  bounded smoke，覆盖 MODE_OFF/direct-bypass 下 4B 未对齐/8B 对齐 DDR read 和 4B
  未对齐 DDR write 与生产 C++ issue-shape helper 一致，地址对齐到 DDR beat，
  write data/strobe 按 byte offset 移位。
- [x] `formal/subsystem_dual_mode0_ddr_bypass_read_response`：actual native dual top 小参数
  bounded smoke，覆盖 MODE_OFF/direct-bypass 下未对齐 4B DDR read 的 DDR `R` 接收、
  aligned beat byte slice 和 upstream read response 回收与生产 C++ read-pack helper 一致。
- [x] `formal/subsystem_dual_mode0_ddr_bypass_read_response_8b`：actual native dual top
  小参数 bounded smoke，覆盖 MODE_OFF/direct-bypass 下 8B 对齐 DDR read 的 DDR `R`
  接收和 upstream read response 回收与生产 C++ read-pack helper 一致。
- [x] `formal/subsystem_dual_cache_dirty_evict_writeback`：actual native dual top 小参数
  bounded smoke，覆盖三笔同 set full-line write miss 后 dirty victim writeback 的 DDR
  `AW/W` 形状、不误发 MMIO/DDR read、以及未收到 `B` 前不提前返回第三笔 write response。
- [x] `formal/subsystem_dual_cache_dirty_evict_b_response`：actual native dual top 小参数
  bounded smoke，覆盖 dirty victim writeback 的 DDR `B` 被接收后，第三笔 upstream
  write response 才能返回且 `id/code` 正确。
- [x] `formal/subsystem_dual_cache_dirty_evict_post_b_hit`：actual native dual top 小参数
  bounded smoke，覆盖 dirty victim writeback 的 DDR `AW/W/B` 完成后，B 后 read 必须命中
  新安装的 dirty line，不得再发 DDR `AR` 或 MMIO 访问，且 read `id/data` 正确。
- [x] `formal/subsystem_dual_ddr_write_mmio_read_independent`：actual native dual top
  小参数 bounded smoke，覆盖 MODE_OFF/direct-bypass 下 DDR write `AW/W` 已发且
  `B` 未返回时，MMIO read 仍可 accepted 并发出 MMIO `AR`，不被 DDR write outstanding
  串行化。
- [x] `formal/subsystem_dual_ddr_write_mmio_write_independent`：actual native dual top
  小参数 bounded smoke，覆盖 MODE_OFF/direct-bypass 下 DDR write `AW/W` 已发且
  `B` 未返回时，MMIO write 仍可 accepted 并发出 MMIO `AW/W`，不被 DDR write
  outstanding 串行化。
- [x] `formal/subsystem_dual_ddr_read_mmio_read_independent`：actual native dual top
  小参数 bounded smoke，覆盖 MODE_OFF/direct-bypass 下 DDR read `AR` 已发且
  `R` 未返回时，MMIO read 仍可 accepted 并发出 MMIO `AR`，不被 DDR read outstanding
  串行化。

## 待继续收敛的生产边界

- [x] 未纳入稳定 manifest 的 formal 入口已按优先级分流：
  当前 `formal/run_passed_hw_cbmc.sh` 已纳入 77 个稳定入口，`formal/*/run_hw_cbmc.sh`
  当前共有 79 个入口，剩余未纳入入口为
  `formal/subsystem_dual_mode0_ddr_bypass_cacheline_read_response` 和
  `formal/subsystem_core_dirty_evict_writeback` 两项；二者均已明确归类为
  experimental/non-stable，不计入稳定回归缺口。dual bridge production-width
  `AR` shape、cacheline read response、bypass-source cacheline read response、cacheline write payload
  和 mode2 write targeted proof 已通过并纳入 manifest；
  `formal/subsystem_dual_mode0_ddr_bypass_cacheline_read_response` 是 native dual top
  production-width direct-bypass 64B read response 入口，当前 300 秒 timeout 仍停在
  `axi_llc_subsystem_dual` top
  type-check/展开阶段，因为它会拉入 core/compat/store；该项暂不作为生产 RTL 失败结论，
  bridge-level production-width bypass-source cacheline read-response proof 已通过并分担
  payload/merge 覆盖；若必须做 native-top 级别，应把 compat direct-bypass accept/slot/response-owner
  逻辑抽成生产子模块再证明，避免 monolithic top proof 拉入 core/store；
  `formal/dual_port_hazard_scoreboard_one_entry` 已在 2026-05-04 重跑通过并纳入
  `formal/run_passed_hw_cbmc.sh`，不再视为稳定 manifest 缺口；
  `formal/subsystem_core_dirty_evict_writeback`
  是 core-alone 实验入口，当前本地复跑仍失败，失败集中在 startup/reconfig idle harness
  收敛约束与 dirty-evict 进度断言混在同一 harness，不作为生产
  RTL 失败结论。startup/reconfig idle 已改由 VCS contract 直接验证实际
  `axi_llc_subsystem_core.v` 并通过；已有 `cache_ctrl` 与 `subsystem_dual`
  dirty-evict proof 分担 dirty victim 主链路覆盖；后续若继续推进 core-alone formal，
  应拆成两路 dirty fill、dirty writeback issue、dirty writeback response 等小入口。
- [ ] 更完整 `axi_llc_axi_bridge.v` 组合场景仍可继续扩展：生产宽度 64B cacheline
  read/write 的 `AR/AW`、两拍 `W` payload、两拍 `R` payload/response 已分别由
  `bridge_prod_width_cacheline_*` 覆盖；4B read/write route、unsupported MMIO 大
  read/write 阻断、`R/B` response 基础回收、
  同构 2-beat DDR cacheline read/write、same-line hazard、mode2 aligned data
  packing/slicing、不同 line read-read outstanding、不同 line read/write 混合 outstanding
  已由 `dual_bridge_*` smoke 覆盖。后续如要继续加强，应优先补 production-width
  dual-bridge DDR/MMIO 组合流，而不是再验证单个 pack helper。
- [ ] `axi_llc_subsystem_dual.v` 顶层 formal 已开始覆盖 MMIO read/write direct route、
  top 接受面对 unsupported MMIO 大 read/write 的阻断、
  MMIO read/write response 回收、DDR-read/MMIO-write 独立发射和 DDR cache-refill/MMIO-read
  独立发射、DDR cache-refill/MMIO-write 独立发射、cache-refill response 回收和
  fill 后同地址 hit、full-line write miss 后同地址 hit、MODE_OFF/direct DDR 未对齐 read
  的 response slice、dirty victim writeback DDR `AW/W` 和 `B -> upstream write response`、
  B 后新 dirty line read-hit；
  read miss/refill response、partial write miss/refill merge 与 partial write hit merge 已先在生产
  `llc_cache_ctrl.v` 边界覆盖。`formal/subsystem_core_dirty_evict_writeback` 已作为
  core-level 实验入口落地，但当前未通过，失败集中在 core-alone startup/reconfig idle
  收敛约束；生产宽度 cacheable 场景仍需继续拆分补齐。
- [ ] C++ reference 与 RTL 的 hw-cbmc EC 仍未完成端到端接线：当前稳定集覆盖生产
  C helper/RTL helper 等价和实际 RTL bounded smoke，但还没有把实际 C++ LLC/AXI
  reference 与实际 RTL top 放入同一个形式化 harness。后续应先选小 top（route/beat
  shape/read-pack/write-pack 或桥接子集），再逐步接到 `axi_llc_subsystem_dual.v`。
- [ ] Linux/image 级长期性能与 difftest 回归仍需作为功能验证补项：当前不是本 checklist
  的每轮必跑项，需在较大功能合并或关键语义改动后单独补跑。

## 剩余验证拆分

- [x] C helper vs 实际 RTL helper/top 的局部 EC：route/beat/read-pack/write-pack、
  MODE_OFF DDR direct issue/read-response、MMIO unsupported 阻断、same-line hazard 和
  dirty eviction 等当前已进入稳定 manifest。
- [x] 实际 RTL `llc_mapped_window_ctrl.v` 生产 4MB window helper 级边界：
  `tb_llc_mapped_window_ctrl` 已补 `LINE_BYTES=64`、`WINDOW_BYTES=0x00400000`
  参数实例，覆盖 `0x30000000` 起点命中、`0x303ffffc` 最后 4B 命中并写入
  line 高 4B、`0x303ffffc` 8B 跨界阻断，以及 `0x30400000`/`0x2ffffffc`
  窗口外阻断。最新 targeted VCS 目录：
  `rtl/local_debug/vcs_mapped_window_prod_boundary_20260504_233508`。
- [x] 实际 C++ `AXI_Interconnect` issue-shape wrapper vs 生产 C helper 的第一层回归：
  `probe_downstream_read_issue` / `probe_downstream_write_issue` 是 production thin wrapper，
  `axi_interconnect_issue_probe_test` 已覆盖 read/write issue addr/size/extract 和 write
  payload/strobe 对齐；结合 `formal/axi_*`、`formal/subsystem_dual_mode0_ddr_bypass_*`
  可作为 issue-shape wrapper 到 RTL helper/top 的传递证据。
- [x] 实际 C++ `AXI_Interconnect` 状态机 vs RTL subsystem 的 trace-based bounded
  functional EC：`axi_interconnect_dual_port_trace_vectors` 使用实际 C++ comb/seq 生成
  MODE_OFF DDR/MMIO direct read/write 向量，`tb_axi_llc_subsystem_dual_cpp_trace_contract`
  在实际 `axi_llc_subsystem_dual.v` 上消费这些向量并通过 targeted VCS。该项覆盖
  DDR 4B/8B/64B read、DDR 4B/64B write、MMIO 4B read/write 的生产宽度端口形状、
  payload/strobe、response ID/data/code，并覆盖 unsupported MMIO 8B read/write 的
  no-accept/no-escape；同时覆盖 DDR/MMIO read/write 同时在途、MMIO response 先返回、
  上游 response stall 时外部 `RREADY/BREADY` 不被反压的实际 C++ trace，以及
  DDR 64B 两拍 read/write 与 MMIO 同时在途的实际 C++ trace；同一 upstream read
  master 多 ID DDR response out-of-order 完成时，按实际 C++/RTL 完成顺序 FIFO 输出，
  且 held response 在上游不 ready 时保持稳定；read response retire 后第二笔 read
  可继续 accepted/发 `AR` 并复用已释放 downstream AXI ID；同一 upstream write master
  多 ID DDR `B` response out-of-order 完成时，按实际 C++/RTL 完成顺序 FIFO 输出，
  held write response 在上游不 ready 时保持稳定，且外部 `BREADY` 只受内部 queue 空间
  保护、不被当前 held upstream write response 无谓反压；还覆盖 MODE_CACHE 下 MMIO 4B
  read/write direct-bypass 不进入 LLC core 的实际 C++ trace，以及 MODE_CACHE
  cacheable read miss/refill 与 MMIO read direct-bypass 同时在途时的 DDR 64B refill
  两拍合并、MMIO response 先返回和外部 `RREADY` 不回压；还覆盖 MODE_CACHE
  partial cache write miss/refill 与 MMIO write direct-bypass 同时在途时，MMIO `B`
  先返回不回压、DDR refill `RREADY` 不回压，以及 refill merge 后 cache write response
  与实际 C++ trace 一致；它不是独立重写 reference。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_CACHE MMIO direct-bypass 第一组：
  已补 LLC-on/MODE_CACHE 下 MMIO 4B read/write，验证请求仍直接走 MMIO AXI 口、
  `AR/AW/W/R/B` 形状和 response ID/data/code 与实际 C++ comb/seq trace 一致，且不误走
  DDR 口或 cacheable LLC core 路径。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_CACHE cacheable read
  miss/refill + MMIO direct-bypass 第一组：已补 cacheable 4B read miss 触发 DDR
  64B/2-beat refill，同时 MMIO 4B read 走独立 MMIO 口；MMIO `R` 先返回且上游 response
  stall 时，MMIO/DDR `RREADY` 均保持可接收，DDR 两拍 refill 后 cache response
  ID/data 与实际 C++ trace 一致。C++ trace 侧的 thin table adapter 只对实际
  `get_llc_table_out()` 表读返回 invalid row，用于驱动 production C++ LLC lookup
  前进，不生成独立参考结果。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_CACHE partial write
  miss/refill + MMIO direct-bypass 第一组：已补 cacheable 4B partial write miss 触发 DDR
  64B/2-beat refill，同时 MMIO 4B write 走独立 MMIO `AW/W/B`；MMIO `B` 先返回且上游
  response stall 时，MMIO `BREADY` 与 DDR `RREADY` 均保持可接收，DDR 两拍 refill 后
  cache write response ID/code 与实际 C++ trace 一致。该项同时修正了 trace 场景对
  C++ ready-first write handshake 的驱动方式，避免把本周期新拉高的 ready 误当成已握手。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_MAPPED local-window
  write/read 第一组：已补 mapped window 内 full-line write 后局部 read，actual C++
  trace 和实际 RTL subsystem 均检查请求不发出任何 DDR/MMIO `AR/AW/W`，write response
  ID/code 与 read response ID/data 一致；trace driver 同步按 DCACHE_R 的同拍
  ready/accept 语义采样，避免把验证驱动误判为读请求未接受。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_MAPPED local-window
  边界 write/read 第一组：已补当前 RTL contract 窗口内起点 `0x30000000`
  4B write/read，以及末端 line `0x3001ffc0` full-line write 后最后 4B
  `0x3001fffc` read；actual C++ trace 与实际 RTL subsystem 均要求请求不发出
  任何 DDR/MMIO `AR/AW/W`，write response ID/code 与 read response ID/data
  一致。该 contract 使用缩小参数，`WINDOW_BYTES=0x20000`，因此不能替代生产
  4MB mapped window 高边界 `0x303ffffc` 的完整 top-width 证明。最新 targeted
  VCS 目录：`rtl/local_debug/vcs_dual_cpp_trace_mapped_boundaries_clean_20260504_232615`。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_MAPPED window 外 MMIO
  边界第一组：已补 mapped offset 下方 `0x2ffffffc` 4B read 和 mapped window 上方
  `0x30400000` 4B write，actual C++ trace 与实际 RTL subsystem 均要求走 MMIO
  `AR/R` 或 `AW/W/B`，不误走 DDR，也不进入 mapped local-window LLC path。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_MAPPED window 外 MMIO
  双向边界补充：已补 mapped offset 下方 `0x2ffffffc` 4B write 和 mapped window
  上方 `0x30400000` 4B read，actual C++ trace 与实际 RTL subsystem 均要求走
  MMIO `AW/W/B` 或 `AR/R`，不误走 DDR，也不进入 mapped local-window LLC path。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_MAPPED mapped-window
  跨界 unsupported 第一组：已补从 `0x303ffffc` 开始跨出 4MB mapped window 的
  8B read/write，actual C++ trace 与实际 RTL subsystem 均要求 `ready=0`、不
  accepted、且不发任何 DDR/MMIO `AR/AW/W`。该项同时修复 C++ production
  LLC-enabled 路径对非 direct-mapped-local unsupported MMIO 的错误接收。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_CACHE `invalidate_all`
  挂起 blocked 第一组：已补 `invalidate_all` 有效时新 read/write request 的阻断，
  actual C++ trace 与实际 RTL subsystem 均要求 `ready=0`、不 accepted、且不发任何
  DDR/MMIO `AR/AW/W`。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_CACHE `invalidate_all`
  drain/recovery 第一组：已补 `invalidate_all_valid` 保持到实际 RTL
  `invalidate_all_accepted` 后再撤销，并等待 `reconfig_busy` 归零；随后发 MMIO
  4B read，actual C++ trace 与实际 RTL subsystem 均要求请求恢复为 ready/accepted，
  走 MMIO `AR/R`，不误走 DDR，也不被 maintenance 状态永久阻塞。最新 targeted VCS
  目录：`rtl/local_debug/vcs_dual_cpp_trace_inval_recovery_20260504_201240`。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_CACHE `invalidate_all`
  pending direct MMIO read drain 第一组：已补 MMIO 4B read 已发 `AR` 但 `R`
  未返回、以及 `R` 已被接收但 upstream response 被 hold 两个阶段；
  actual C++ 与实际 RTL subsystem 均要求 `invalidate_all_accepted=0`，
  外部 MMIO `RREADY` 不因 maintenance pending 被回压，直到 upstream response
  retire 后 `invalidate_all` 才能被 accepted。该项同时修复 C++ production
  `prepare_llc_inputs()` 对显式 `invalidate_all` 缺少 full quiescent gate 的问题，
  并将 LLC-enabled quiescent 判定扩展到非 LLC 直通 AXI pending read/write。
  最新 targeted VCS 目录：
  `rtl/local_debug/vcs_dual_cpp_trace_pending_inval_mmio_read_20260504_235035`。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_CACHE `invalidate_all`
  pending direct MMIO write drain 第一组：已补 MMIO 4B write 已发 `AW/W` 但
  `B` 未返回、以及 `B` 已被接收但 upstream write response 被 hold 两个阶段；
  actual C++ 与实际 RTL subsystem 均要求 `invalidate_all_accepted=0`，
  外部 MMIO `BREADY` 不因 maintenance pending 或 upstream response held 被回压，
  直到 upstream write response retire 后 `invalidate_all` 才能被 accepted。该项同时
  将 LLC-enabled quiescent 判定扩展到 `w_resp_valid` held response。最新 targeted
  VCS 目录：
  `rtl/local_debug/vcs_dual_cpp_trace_pending_inval_mmio_write_20260505_141827`。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_CACHE `invalidate_all`
  pending direct MMIO read+write drain 组合：已补 MMIO 4B read 已发 `AR` 且未收
  `R`，随后不同 64B hazard granule 的 MMIO 4B write 仍可 accepted 并发 `AW/W`；
  `invalidate_all` 拉起后，实际 C++ 与实际 RTL subsystem 均要求在 `R/B` 未返回、
  `R/B` 同拍返回 handshake、两个 upstream response 同时 held、只 retire read 后 write
  response 仍 held 这些阶段 `invalidate_all_accepted=0`，且外部 `RREADY/BREADY`
  均不得因 maintenance pending 或 held upstream response 被回压；只有两个 upstream
  response 都 retire 后才允许 `invalidate_all` accepted。最新 targeted VCS 目录：
  `rtl/local_debug/vcs_cpp_trace_rw_20260506_103904`；全量 RTL contract 复跑目录：
  `rtl/local_debug/vcs_all_contracts_20260506_103930_mmio_rw`。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_CACHE 同 64B hazard granule
  direct MMIO read-pending write 约束：已补 MMIO 4B read 发出 `AR` 且 `R` 未返回时，
  同 granule MMIO 4B write 持续保持的场景；actual C++ trace 与实际 RTL subsystem
  均要求在观察窗口内不向 DDR/MMIO 发出新的外部 `AR/AW/W`，并最终允许内部 accepted。
  该 contract 有意不比较该场景的 `ready` 相位细节，避免把 C++ 两阶段 comb 观察点和
  RTL registered ready 相位差误判为外部协议差异；强约束是 `accepted` 与无外发
  `AW/W`。最新 targeted VCS 目录：
  `rtl/local_debug/vcs_cpp_trace_mmio_same_line_20260506_110622`；全量 RTL contract
  复跑目录：`rtl/local_debug/vcs_all_contracts_20260506_110652_mmio_same_line`，
  wrapper log 为 `rtl/local_debug/run_all_contracts_mmio_same_line_20260506_110652.log`。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_CACHE 同 64B hazard granule
  direct MMIO write-pending read 约束：已补 MMIO 4B write 发出 `AW/W` 且 `B`
  未返回时，同 granule MMIO 4B read 持续保持的场景；actual C++ trace 与实际
  RTL subsystem 均要求观察窗口内不向 DDR/MMIO 发出新的外部 `AR/AW/W`，且
  read 在 pending write 清除前不被 accepted。该场景同步修正 C++ production
  LLC-enabled read arbitration：direct-MMIO read 如果因同 granule write-pending
  hazard 被阻断，不能继续 fall-through 到 LLC core accept 路径。最新 targeted
  VCS 目录：`rtl/local_debug/vcs_cpp_trace_mmio_same_line_rw_20260506_112216`；
  全量 RTL contract 复跑目录：
  `rtl/local_debug/vcs_all_contracts_20260506_112239_mmio_same_line_rw`，wrapper log 为
  `rtl/local_debug/run_all_contracts_mmio_same_line_rw_20260506_112239.log`。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_CACHE `invalidate_all`
  cache-refill + held MMIO read drain 第一组：已补 cacheable read miss/refill 已发
  DDR 64B refill `ARLEN=1`、另一 read master 的 MMIO 4B read 先返回并被 upstream
  response slot hold 时拉起 `invalidate_all` 的场景；actual C++ 与实际 RTL subsystem
  均要求 MMIO/DDR `RREADY` 不被 maintenance pending 回压，MMIO response held 与
  cache response held 两个阶段 `invalidate_all_accepted=0`，两类 response 均 retire
  后才允许 RTL 完成 valid-sweep 并最终 accepted。该项同时修复 C++ production
  两阶段 comb 下 stale LLC read request 可能重复发同一 DDR refill `AR` 的问题，并在
  RTL contract 中显式检查首个 refill `AR` handshake 后无同地址重复发射。最新
  targeted VCS 目录：
  `rtl/local_debug/vcs_dual_cpp_trace_invalidate_all_cache_mmio_20260505_211212`。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_CACHE `invalidate_all`
  cache-refill + MMIO read/write drain 组合：已补 cacheable read miss/refill、
  另一 read master 的 MMIO 4B read、另一 write master 的 MMIO 4B write 同时在途后
  拉起 `invalidate_all` 的场景；actual C++ 与实际 RTL subsystem 均要求外部
  MMIO `RREADY/BREADY` 和 DDR refill `RREADY` 不因 maintenance pending 或 held
  upstream response 被回压，且 MMIO read response、MMIO write response、cache
  read response 均 retire 之前 `invalidate_all_accepted=0`，三者均 retire 后才允许
  maintenance accepted。该 trace 刻意让 MMIO read/write 落在不同 64B hazard
  granule；同 granule AR/AW hazard 已由独立 same-line 测试覆盖。最新 targeted
  VCS 目录：`rtl/local_debug/vcs_cpp_trace_inval_cache_mmio_rw_20260506_122639`；
  全量 RTL contract 复跑目录：
  `rtl/local_debug/vcs_all_contracts_20260506_122656_inval_cache_mmio_rw`。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_CACHE `invalidate_line`
  cache-refill + MMIO read drain 组合：已补 cacheable read miss/refill、另一 read
  master 的 MMIO 4B read 同时在途后拉起 target-line `invalidate_line` 的场景；
  actual C++ 与实际 RTL subsystem 均要求外部 MMIO `RREADY` 和 DDR refill
  `RREADY` 不因 maintenance pending 或 held upstream response 被回压，且 MMIO
  read response 与 target cache read response 均 retire 之前 `invalidate_line_accepted=0`，
  两者均 retire 后才允许目标 line maintenance accepted。最新 targeted VCS 目录：
  `rtl/local_debug/vcs_cpp_trace_invline_cache_mmio_20260506_123952`；全量 RTL
  contract 复跑目录：
  `rtl/local_debug/vcs_all_contracts_20260506_124010_invline_cache_mmio`。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_CACHE `invalidate_line`
  cache-write-refill + MMIO write drain 组合：已补 cacheable partial write miss/refill、
  另一 write master 的 MMIO 4B write 同时在途后拉起 target-line `invalidate_line` 的场景；
  actual C++ 与实际 RTL subsystem 均要求外部 MMIO `BREADY` 和 DDR refill `RREADY`
  不因 maintenance pending 或 held upstream response 被回压，且 MMIO write response
  与 target cache write response 均 retire 之前 `invalidate_line_accepted=0`，两者均
  retire 后才允许 target-line maintenance accepted。最新 targeted VCS 目录：
  `rtl/local_debug/vcs_cpp_trace_invline_cache_mmio_write_20260506_130801`；全量 RTL
  contract 复跑目录：
  `rtl/local_debug/vcs_all_contracts_20260506_130824_invline_cache_mmio_write`。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_CACHE `invalidate_all`
  dirty-victim/MMIO write drain 组合：已补 dirty victim writeback `AW/W` 发出后，
  另一 write master 的 MMIO 4B write 先完成并被 upstream response hold，同时持续拉起
  `invalidate_all` 的场景；actual C++ 与实际 RTL subsystem 均要求外部 MMIO `BREADY`
  与 DDR victim `BREADY` 不因 maintenance pending 或 held upstream response 被回压，
  且 MMIO response held、DDR victim `B` handshake、cache response held/retire 前
  `invalidate_all_accepted=0`。该 trace 还检查所有 response retire 后，因为 cache write
  留下 dirty resident line，`invalidate_all` 仍保持 blocked，不允许通过依赖 B 返回先清
  buffer 再收 cache response 的错误顺序。最新 targeted VCS 目录：
  `rtl/local_debug/vcs_cpp_trace_dirty_victim_inval_20260506_125247`；全量 RTL
  contract 复跑目录：
  `rtl/local_debug/vcs_all_contracts_20260506_125307_dirty_victim_inval`。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_CACHE `invalidate_all`
  pre-handshake external MMIO drain 第一组：已补外部 MMIO read `ARVALID` 已拉起
  但 `ARREADY=0`、外部 MMIO write `AWVALID/WVALID` 已拉起但 `AWREADY/WREADY=0`
  时拉起 `invalidate_all` 的场景；actual C++ 与实际 RTL subsystem 均要求
  `invalidate_all_accepted=0`，`AR/AW/W` payload 保持到 lower handshake，
  且后续 `R/B` 和 upstream response 均 retire 后 `invalidate_all` 才能被 accepted。
  最新 targeted VCS 目录：
  `rtl/local_debug/vcs_dual_cpp_trace_pre_handshake_inval_20260505_143134`。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_CACHE -> MODE_MAPPED
  reconfig/recovery 第一组：已补 actual C++ 通过真实 `mode/llc_mapped_offset`
  运行 reconfig/invalidate 流程后，再发 mapped window 上方 `0x30400004` MMIO
  4B read；实际 RTL contract 通过 `enter_mode(MODE_CACHE)` 再
  `enter_mode(MODE_MAPPED)` 后消费同一组 C++ 向量，要求请求恢复为 ready/accepted，
  走 MMIO `AR/R`，不误走 DDR。最新 targeted VCS 目录：
  `rtl/local_debug/vcs_dual_cpp_trace_mode_switch_20260504_212921`。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_OFF DDR 16B size
  组合第一组：已补 DDR 16B read/write，actual C++ trace 与实际 RTL subsystem
  均检查 16B 请求对齐到 256-bit 单 beat DDR `AR/AW`，read response 在 beat 内按
  offset 切片，write `WDATA/WSTRB/WLAST` 按 offset pack。最新 targeted VCS 目录：
  `rtl/local_debug/vcs_dual_cpp_trace_ddr16_20260504_213152`。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_OFF DDR size/offset
  补充组合：已补 DDR read 1B/2B/32B 和 write 1B/2B/8B/32B，覆盖
  256-bit DDR beat 边缘 byte/halfword 截取、32B 整 beat 对齐、以及窄写
  `WDATA/WSTRB/WLAST` 按 byte offset pack。READ1/READ2 使用高字节非零的
  C++ DDR beat seed，避免只比较到 0 数据。最新 targeted VCS 目录：
  `rtl/local_debug/vcs_dual_cpp_trace_size_corners_nonzero_20260504_224613`。
- [ ] 实际 C++ `AXI_Interconnect` trace-based EC 的剩余功能场景：MODE_CACHE
  dirty victim writeback 与 MMIO write direct-bypass 已补齐并通过 actual C++ trace
  + actual RTL subsystem contract；MODE_MAPPED local-window write/read 第一组已补；
  MODE_MAPPED 窗口外 MMIO 上/下边界 read/write 双向边界已补，mapped-window
  跨界 8B unsupported 第一组已补；MODE_CACHE `invalidate_all` 新请求 blocked 第一组
  已补，`invalidate_all` 完成后 MMIO read 恢复第一组已补，MODE_CACHE -> MODE_MAPPED
  reconfig 后 MMIO read 恢复第一组已补，MODE_OFF DDR 1B/2B/4B/8B/16B/32B/64B
  read/write size sweep 已补；本轮补齐当前 RTL contract 窗口内 mapped local-window
  起点与末端 line 写后读边界；本轮继续补齐 pending direct MMIO write drain
  与 external MMIO `AR/AW/W` pre-handshake drain；本轮继续补齐 cache write
  miss/refill + pending MMIO write + `invalidate_all` pending 下的 dirty-line blocked
  组合；本轮继续补齐 cacheable read miss/refill + MMIO read/write 同时在途时的
  `invalidate_all` drain/recovery 组合；本轮继续补齐 target-line `invalidate_line`
  与 cacheable read miss/refill + MMIO read 同时在途时的 drain/recovery 组合；
  本轮继续补齐 target-line `invalidate_line` 与 cacheable write miss/refill + MMIO write
  同时在途时的 drain/recovery 组合；
  本轮继续补齐 dirty victim writeback + pending MMIO write + `invalidate_all`
  同时存在时的 drain/blocked 组合；本轮继续补齐同一路径 drain 后 targeted dirty
  resident line `invalidate_line` 可被 accepted 的 C++/RTL 对齐检查，最新 targeted VCS
  目录：`rtl/local_debug/vcs_dual_cpp_trace_dirty_victim_invline_20260506_134755_eda10`；
  本轮继续补齐 dirty victim writeback + pending MMIO read + `invalidate_all` 同时存在时
  的 drain/blocked 组合，要求 MMIO `RREADY` 与 DDR victim `BREADY` 均不被 pending
  maintenance 或 held response 回压，并在 drain 后确认 targeted dirty resident line
  `invalidate_line` 可被 accepted；最新 targeted VCS 目录：
  `rtl/local_debug/vcs_dual_cpp_trace_dirty_victim_mmio_read_20260506_135823_eda10`；
  后续主要剩更长随机 trace，以及更高覆盖度的 multi-master/multi-outstanding
  maintenance/recovery 组合。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_OFF DDR/MMIO 并发第一组：
  已补 DDR/MMIO read/write 同时在途、MMIO `R/B` 先返回、上游 response stall 下外部
  `RREADY/BREADY` 不被回压，并按实际 C++ trace 检查原 upstream ID/data/code 回收。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 read-side release/reuse 第一组：
  已补 read response 被 upstream 消费后，下一笔 read 可继续 accepted/发 `AR`，并复用
  已释放 downstream AXI ID，覆盖实际 C++ comb/seq 与实际 RTL subsystem 的一致性。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 write-side release/reuse 第一组：
  已补 write response 被 upstream 消费后，下一笔 write 可继续 accepted/发 `AW/W`，
  并复用已释放 downstream AWID，覆盖实际 C++ comb/seq 与实际 RTL subsystem 的一致性。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 write-side same-master
  out-of-order 第一组：已补同一 upstream write master 连续两笔 DDR direct write，
  downstream `B` 以 newer-before-older 顺序返回且上游 write response 被 hold 的场景；
  actual C++ 与实际 RTL subsystem 均要求 held newer response 的 ID/code 稳定，
  older `B` 在内部 queue 有空间时仍可被接收，随后按完成顺序回收 newer/older 两个
  upstream write response。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 read full-budget release 第一组：
  已补 32 个 read outstanding 填满后第 33 个 read `ready=0` 且 no-`AR`；消费第一笔
  response 后，新 read 可重新 accepted/发 `AR`，并复用已释放 downstream ARID。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 write full-budget release 第一组：
  已补 32 个 write outstanding 填满后第 33 个 write `ready=0` 且 no-`AW/W`；消费第一笔
  `B` response 并释放 upstream response 后，新 write 可重新 accepted/发 `AW/W`，并复用
  已释放 downstream AWID。因 32 笔填满时 2 个 write master 的 4-bit upstream ID 空间
  也被用满，after-release 请求使用刚释放的 upstream ID 0，避免 ID conflict 干扰释放检查。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_CACHE cache refill/MMIO
  read direct-bypass 并发第一组：已补 cache refill 期间 MMIO read response 先返回、
  upstream response stall 下不回压 MMIO/DDR `RREADY`，并检查 cache refill 的两拍
  DDR `R` 合并与 upstream cache response。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的 MODE_CACHE dirty victim
  writeback + MMIO direct-bypass 并发第一组：已补两条同 set dirty line setup 后第三笔
  full-line write miss 触发 DDR victim `AW/W`，victim `B` pending 期间另一 write master
  的 MMIO 4B write 仍可独立发出并回收/hold response；held MMIO response 不回压 DDR
  victim `BREADY`，DDR `B` 后 cache write response 与实际 C++ trace 一致。随后补齐
  对称的 MMIO read direct-bypass：victim `B` pending 期间另一 read master 的 MMIO
  4B read 可独立发出，pending maintenance 下 MMIO `RREADY` 与 DDR victim `BREADY`
  均不被 held response 回压，MMIO/cache response retire 前不接受 `invalidate_all`，
  drain 后 targeted `invalidate_line` 可 accepted。
- [x] 实际 C++ `AXI_Interconnect` trace-based EC 的剩余并发场景：DDR 64B 两拍
  read/write 与 MMIO 同时在途、同一 upstream read master 多 ID response out-of-order
  完成与 held response 稳定性、同一 upstream write master 多 ID `B` response
  out-of-order 完成与 held response 稳定性、read-side/write-side release-reuse、read/write
  full-budget release、MODE_CACHE read refill/MMIO read direct-bypass、MODE_CACHE
  partial write miss/refill/MMIO write direct-bypass、MODE_CACHE dirty victim/MMIO
  write direct-bypass 已由 `tb_axi_llc_subsystem_dual_cpp_trace_contract` 覆盖；后续如继续
  扩展，应优先做随机 trace 和更复杂 maintenance/recovery 与并发请求组合。
- [ ] 实际 C++ request/response 状态机 vs RTL bridge/subsystem 的 hw-cbmc 同 harness
  bounded EC：当前已有 trace-based 功能 EC，但还没有把实际 C++ 对象和实际 RTL top
  放进同一个 hw-cbmc harness；后续需要解决 C++ 标准库/frontend 接入或建立可复用的
  production-thin C wrapper，避免验证对象与实际使用对象分叉。本轮已补两条
  production-thin C wrapper 切片：`dual_bridge_prod_helper_read_issue_shape`
  和 `dual_bridge_prod_helper_write_issue_shape` 使用实际生产 C helper 与实际
  dual bridge，分别证明 bypass read/write issue shape 一致；
  但这还不是完整 C++ class / RTL top 端到端 EC，因此本项保持 open。
- [x] 实际 C++ LLC cache 行为 vs RTL cache-control 的 trace-based bounded
  functional EC 第一组：`axi_llc_cache_trace_vectors` +
  `tb_llc_cache_ctrl_cpp_trace_contract` 已覆盖 partial write hit merge、read miss
  refill、partial write miss refill、dirty victim full-line writeback、dirty victim +
  partial-write miss refill/merge/victim writeback，以及 `invalidate_line` valid-only
  clear，期望值来自实际 C++ `AXI_LLC`，RTL 端实例化实际 `llc_cache_ctrl.v`。本轮该项
  暴露并修复了 RTL invalidate lookup 时 valid/repl 表 set 选择未跟随 invalidate 地址的问题；
  dirty-partial 路径也澄清了实际语义不是“先写回 victim 再 refill”，而是 refill 先返回，
  install/response 时 dirty victim snapshot 已外部化并继续写回。
- [ ] 实际 C++ LLC cache 行为 vs RTL subsystem/core 的剩余 bounded EC：继续按
  bypass/direct-mapped、更完整 maintenance/drain 与 subsystem/core 边界拆分；优先扩展到
  `llc_cache_ctrl.v`，再逐步上移到 subsystem/core，避免一次性证明大 top。
- [x] production-width dual bridge response mux 竞争与外部 ready 不回压 smoke：
  `tb_axi_llc_axi_bridge_dual_contract` 已覆盖 DDR/MMIO `R` 同拍返回且上游
  `cache_resp_ready=0` 时，外部 DDR/MMIO `RREADY` 仍拉高并先缓存 response；也覆盖
  DDR/MMIO `B` 同拍返回且上游 `cache_resp_ready=0` 时，外部 DDR/MMIO `BREADY`
  仍拉高，并按 MMIO 优先、DDR 后续保留的顺序回收 response。最近一次 targeted
  VCS 目录：`local_debug/short_ec_gate_20260505_195710`。
- [x] production-width dual bridge 组合流与 recovery smoke：当前 production-width single bridge 的
  AR/AW/W/R payload 已覆盖，dual bridge production-width DDR read `AR` shape、cacheline
  read `R` response、cacheline write `AW/W` payload、mode2 write `AW/W/B` 已覆盖；
  DDR 64B read + MMIO 32-bit read、DDR 64B read + MMIO 32-bit write、DDR 64B write
  + MMIO 32-bit read、DDR 64B write + MMIO 32-bit write 的生产宽度 independent
  smoke 已覆盖；production-width same-line read-before-write / write-before-read safety
  smoke 也已覆盖；response mux 竞争已由上一个 smoke 覆盖。本轮新增 response stall
  后 request issue 恢复 smoke：read response 被上游 stall 并缓存后释放，随后相同
  upstream read ID 的新 DDR cache read 仍可 accepted/发 `AR`/完成 `R`；write response
  被上游 stall 并缓存后释放，随后相同 upstream write ID 的新 DDR bypass write 仍可
  accepted/发 `AW/W`/完成 `B`。targeted VCS 目录：
  `local_debug/vcs_bridge_dual_recovery_20260505_200333`；全量 RTL contract 复跑目录：
  `local_debug/vcs_all_contracts_20260505_200356_bridge_recovery`。
- [x] Native dual top 在更完整生产参数下的 smoke：已新增
  `tb_axi_llc_subsystem_dual_mapped_window_prod_contract`，直接实例化实际
  `axi_llc_subsystem_dual.v`，参数为 8192 set / 16 way / 64B line / 4MB mapped
  window / 32B DDR beat，覆盖 reset startup sweep 后 `0x303ffffc` 末端 4B
  mapped-window local write/read 写后读，且不得向 DDR/MMIO `AR/AW/W` 逃逸；并在
  reconfig 到 MODE_OFF 后覆盖 64B DDR direct read 的两拍 256-bit `R` merge 和
  upstream response 回收，用 VCS actual RTL 补充 formal monolithic native-top
  timeout 无法稳定覆盖的路径。本轮继续 reconfig 到 MODE_CACHE，覆盖同一 actual
  production 参数下 64B cacheable read miss/refill 与随后同 line read hit：miss 检查
  DDR `ARADDR/ARLEN/ARSIZE/ARBURST/ARID`、两拍 `R` merge、`RLAST` 前不回包和 upstream
  512-bit 数据/ID；hit 检查不再出现新的 DDR/MMIO `AR/AW/W`。
  targeted VCS 目录为
  `rtl/local_debug/vcs_dual_prod_cacheable_20260505_193342`，全量 RTL contract 目录为
  `rtl/local_debug/vcs_all_contracts_20260505_193402_prod_cacheable`。本轮短门槛复跑
  全量 RTL contract 53/53 通过，log 为
  `local_debug/short_ec_gate_20260505_195710/run_all_contracts.log`；新增 bridge
  recovery smoke 后再次复跑全量 RTL contract 53/53，log 为
  `local_debug/vcs_all_contracts_20260505_200356_bridge_recovery/run_all_contracts.log`；
  新增 `invalidate_all` + cache refill + held MMIO read trace 后再次复跑全量
  RTL contract 53/53，wrapper log 为
  `local_debug/vcs_all_contracts_20260505_211304_invall_cache_mmio/run_all_contracts.log`，
  VCS out_dir 为 `rtl/local_debug/vcs_all_contracts_20260505_211305`。2026-05-06
  新增 cache write miss/refill + pending MMIO write + `invalidate_all` dirty-line
  blocked trace 后，C++ `ctest --test-dir build_dual_axi_scope_20260428 --output-on-failure`
  24/24 通过；targeted VCS
  `rtl/local_debug/vcs_cpp_trace_inval_cache_mmio_write_20260506_121103` 通过；全量
  RTL contract 53/53 通过，out_dir 为
  `rtl/local_debug/vcs_all_contracts_20260506_121125_inval_cache_mmio_write`。随后新增
  cache read miss/refill + pending MMIO read + pending MMIO write + `invalidate_all`
  drain/recovery 组合 trace 后，C++ regression 24/24 通过，log 为
  `local_debug/ctest_inval_cache_mmio_rw_20260506_122940.log`；targeted VCS
  `rtl/local_debug/vcs_cpp_trace_inval_cache_mmio_rw_20260506_122639` 通过；全量
  RTL contract 53/53 通过，out_dir 为
  `rtl/local_debug/vcs_all_contracts_20260506_122656_inval_cache_mmio_rw`。随后新增
  target-line `invalidate_line` + cache read miss/refill + pending MMIO read
  drain/recovery 组合 trace 后，C++ regression 24/24 通过，log 为
  `local_debug/ctest_invline_cache_mmio_20260506_124110.log`；targeted VCS
  `rtl/local_debug/vcs_cpp_trace_invline_cache_mmio_20260506_123952` 通过；全量 RTL
  contract 53/53 通过，out_dir 为
  `rtl/local_debug/vcs_all_contracts_20260506_124010_invline_cache_mmio`。随后新增
  target-line `invalidate_line` + cache write miss/refill + pending MMIO write
  drain/recovery 组合 trace 后，C++ regression 24/24 通过，log 为
  `local_debug/ctest_invline_cache_mmio_write_20260506_130721.log`；targeted VCS
  `rtl/local_debug/vcs_cpp_trace_invline_cache_mmio_write_20260506_130801` 通过；全量
  RTL contract 53/53 通过，out_dir 为
  `rtl/local_debug/vcs_all_contracts_20260506_130824_invline_cache_mmio_write`。
- [ ] RTL 可综合性与 1GHz pre-DC hygiene gate：VCS/formal 只能证明已覆盖功能，不等价于
  可综合性或 1GHz 时序余量。后续在进入长 DC 前至少应补一组快速综合/结构检查：
  no-latch/no-multi-driver/no-unsized-debug-only 语句、实际 production RTL flist 可被
  DC/VCS 统一读入、关键新增 helper 保持寄存器边界清晰；最终仍需要使用 SMIC12
  `9T20` 标准单元库（`SCC12NSFE_90SDB_9TC20_RVT/LVT_V1P0F`，不得使用早期误配的
  `7P5TC*` 库）跑 full/top 或拆分 submodule DC 报告确认 1GHz setup。2026-05-04 曾尝试
  `rtl/dc/run_dual_link_sanity.tcl` full `axi_llc_subsystem_dual` link sanity，已完成
  SRAM `.db` 读取和 42 个 RTL 文件 `analyze`，但在 full-top elaborate/uniquify 阶段
  运行约 36 分钟、RSS 约 22GB 仍无阶段推进，手动终止；该结果不计为通过，后续应拆
  bridge/compat/core 子模块 link sanity，或为 full-top sanity 提供跳过 `uniquify` 的快速入口。
  当前已补 `axi_llc_axi_bridge_dual` 子模块 link sanity 并通过，说明新增 dual bridge
  生产 RTL 可被 DC analyze/elaborate/link；但 compat/core/subsystem/full-top 仍未完成该
  gate，且 bridge 报告中的大宽度寄存器/多处 2048-bit mux、LINT-1/LINT-52、高 fanout
  和 signedness warning 仍需继续清理或在 DC 时序报告中审视。
  2026-05-05 根据旧 full DC elaborate log 暴露的大量 `axi_llc_subsystem_compat.v`
  `VER-318` signed-to-unsigned warning，已先做一轮低风险 RTL cleanup：把 signed
  `integer` 下标进入 variable part-select、8-bit master/slot id 和 FIFO pointer 前显式
  转为无符号表达式，并把 FIFO next-pointer helper / round-robin port cursor 改为
  8-bit typed expression。该改动已通过
  VCS 53/53 与实际 dual-subsystem hw-cbmc 子集 16/16；但 warning 是否消除仍需新
  DC link sanity 或 full DC 验证，因此本 gate 仍保持 open。
  2026-05-06 又补了一轮低风险 RTL hygiene cleanup：把 cache/core/maintenance 侧
  loop 下标改为无符号寄存器、补齐 typed last-index localparam，并把 SRAM wrapper
  `READ_LATENCY_CYCLES - 2` 的延迟初值改为显式 guarded localparam，避免 DC 对负值/
  宽度推导产生无关 warning。该轮已通过 C++ 24/24、9 个相关 hw-cbmc proof、
  `eda-10` 上 dual-only RTL contract 4/4 和全量 RTL contract 53/53；是否消除 DC
  warning 仍需新 link/full DC 证明。
  同日 DC 服务器探测结果：`eda-10`、`eda-09`、`eda-05` 均可启动 `dc_shell` 并通过
  `DC_SMOKE_OK`；`eda-10` 当前负载低、内存充足，是下一轮 full 1GHz DC 首选；
  `eda-05` 可用但负载高且有旧 DC 任务；`eda-08` 当前 `Design Compiler is not enabled`
  / vendor daemon 不可用，不应作为 DC 首选。2026-05-06 用户补充最终 DC signoff
  必须使用 9T20 标准单元；`rtl/dc/axi_llc_dc_common.tcl` 已把默认 stdcell 从 7p5t
  改为 9TC20 RVT/LVT list，当前已经启动且使用旧默认库的 eda-10 长跑不能作为最终
  signoff 结论，只能作为调试参考。随后在 `eda-09` 做 DC library setup smoke，
  默认加载 9TC20 RVT/LVT、data SRAM 和 meta SRAM `.db` 并打印 `DC_LIB_SETUP_PASS`；
  run root 为 `rtl/dc/runs/lib_setup_smoke_9t20_20260506_104253_eda09`。同日已停止
  旧 7p5t eda-10 长跑，并在 `eda-07` 启动新的 9T20 clean full 1GHz DC，PID
  `2673318`，run root 为
  `rtl/dc/runs/full_compile_1g_9t20_622b6e4_20260506_104636_eda07`；早期日志显示
  已完成 analyze，进入 elaborate/build `axi_llc_subsystem_compat` 阶段。后续用户补充
  DC 脚本还必须与组内模板
  `/share/personal/S/chengshuyao/Qimeng_3_syn/dc_core.tcl` 保持等价，只允许 RTL/filelist、
  SRAM `.db` 和额外 QoR/输出报告差异；检查发现此前脚本额外使用了 0.05ns
  clock uncertainty/I/O delay、`compile_ultra -no_autoungroup` 和局部 hierarchy
  guard，不能作为严格模板 signoff 入口。已修正 `rtl/dc/run_dual_full_compile_1g.tcl`
  / `rtl/dc/axi_llc_dc_common.tcl`，回到模板语义：1ns clock、0 I/O delay、
  `set_fix_multiple_port_nets -all -buffer_constant -feedthrough`、模板 `dont_use`
  规则、`compile_ultra -retime`，并保留 9T20+SRAM `.db`、QoR/report、netlist/ddc/db/
  sdc/sdf/spf 输出。修正后在 `eda-10` 执行 library setup smoke，9T20 RVT/LVT 与
  data/meta SRAM `.db` 均加载通过，且无 `DDB-24`/Error/Warning；run root 为
  `rtl/dc/runs/lib_setup_smoke_template_9t20_20260506_112133_eda10`。因此当前 eda-07
  已启动长跑最多作为调试参考，最终 clean signoff 应使用修正后的脚本重新启动。
  修正提交 `4ac96ae` 推送后，已在 `eda-10` 启动 strict-template 9T20 full 1GHz DC，
  run root 为
  `rtl/dc/runs/full_compile_1g_template_9t20_4ac96ae_20260506_112854_eda10`，
  parent PID `2469192`，dc_shell child PID `2469465`；早期日志已进入
  `read_data_db_start`，并确认加载 9T20 RVT/LVT 与 data/meta SRAM `.db`。
  后续复核组内模板差异时发现该版本仍显式加入了 `standard.sldb/dw_foundation.sldb`，
  不属于 RTL/filelist、SRAM `.db` 或 QoR/report 输出差异；已修正为不显式设置
  `synthetic_library`，且 `target_library` 只包含 9T20 RVT/LVT，`link_library`
  包含 9T20 RVT/LVT 与实际 data/meta SRAM `.db`。这样仍满足新增 SRAM `.db` 的需求，
  同时避免把 hard macro 放入可映射 standard-cell target 集合。此前短暂尝试把 SRAM
  也加入 `target_library` 时，DC 在 analyze 后加载 target db 阶段直接退出，未进入
  elaborate，因此不能作为有效长跑。`4ac96ae` 长跑也不能作为最终 strict-template
  signoff，需要用修正后的脚本重新启动 clean full DC。修正后执行 120s 限时
  link-sanity probe，run root 为
  `rtl/dc/runs/link_sanity_probe_strict_template_9t20_20260506_115105_eda10`，
  结果已越过此前失败点：RVT/LVT target db 均加载完成，出现 `analyze_done` 和
  `elaborate_start`，随后在 build `axi_llc_subsystem_compat` 阶段因 120s 探针超时退出；
  该超时符合预期，不是早期配置失败。修正提交 `e4a6434` 推送后，已用
  foreground unified exec 会话启动新的 clean full DC，run root 为
  `rtl/dc/runs/full_compile_1g_strict_template_9t20_e4a6434_20260506_115655_eda10_live`；
  早期日志已完成 `analyze_done` 并进入 `elaborate_start`，正在 build
  `axi_llc_subsystem_compat`。此前尝试用普通 `nohup` 后台方式启动的两轮会被当前执行
  环境清理，均停在加载 RVT db 附近，不能作为有效 DC。
- [x] RTL contract 回归：实际 RTL 改动后已重跑 `rtl/run_all_contracts.sh` 和
  `rtl/run_dual_axi_contracts.sh`；当前通过 53/53 与 4/4。compat signedness cleanup
  后最新全量 RTL contract 53/53 目录为
  `rtl/local_debug/vcs_all_contracts_20260505_185352_compat_cast_cleanup3`；此前
  第二轮 cleanup 53/53 目录为
  `rtl/local_debug/vcs_all_contracts_20260505_183249_compat_cast_cleanup2`，第一轮 cleanup
  53/53 目录为
  `rtl/local_debug/vcs_all_contracts_20260505_180837_compat_cast_cleanup`，此前
  production-width direct read 补测目录为
  `rtl/local_debug/vcs_all_contracts_20260505_175032_with_prod_read64`，dual-only 4/4
  目录为 `rtl/local_debug/vcs_dual_axi_contracts_20260505_143514`。2026-05-06 RTL
  hygiene cleanup 后又在 `eda-10` 复跑 dual-only 4/4，目录为
  `rtl/local_debug/vcs_dual_axi_contracts_push_check_20260506_001419_eda10`；全量 RTL
  contract 53/53，目录为
  `rtl/local_debug/vcs_all_contracts_push_check_20260506_001441_eda10`。2026-05-06
  新增 `invalidate_all` + pending MMIO read/write 组合 trace 后，又复跑全量 RTL
  contract 53/53，目录为
  `rtl/local_debug/vcs_all_contracts_20260506_103930_mmio_rw`；新增同 64B direct
  MMIO read-pending write 后复跑 53/53，目录为
  `rtl/local_debug/vcs_all_contracts_20260506_110652_mmio_same_line`；新增对称的
  direct MMIO write-pending read 与 C++ fall-through 修复后再次复跑 53/53，目录为
  `rtl/local_debug/vcs_all_contracts_20260506_112239_mmio_same_line_rw`。新增
  MODE_CACHE pending MMIO read 期间请求 MODE_MAPPED 的 actual C++ trace 到实际 RTL
  subsystem targeted VCS 已通过，目录为
  `rtl/local_debug/vcs_dual_cpp_trace_reconfig_pending_mmio_read_20260506_140801_eda10`；
  对称的 pending MMIO write 期间请求 MODE_MAPPED targeted VCS 也已通过，目录为
  `rtl/local_debug/vcs_dual_cpp_trace_reconfig_pending_mmio_rw_20260506_141306_eda10`；
  进一步补齐 pending MMIO read/write 同时在途且 `B` 先于 `R` 返回时请求
  MODE_MAPPED 的 targeted VCS，目录为
  `rtl/local_debug/vcs_dual_cpp_trace_reconfig_pending_mmio_rw_b_before_r_20260506_141938_eda10`。
  随后复跑全量 RTL contract 53/53 通过，目录为
  `rtl/local_debug/vcs_all_contracts_reconfig_rw_20260506_142058_eda10`。
- [x] 受 `axi_llc_subsystem_compat.v` 影响的 actual dual-subsystem hw-cbmc 子集：
  compat signedness cleanup 后已复跑稳定 manifest 中 16 个 `subsystem_dual_*`
  proof，全部通过，覆盖 MMIO read/write route/response、DDR/MMIO independent、
  cache refill/hit/full-write、mode0 DDR bypass、dirty-evict writeback/B response/post-B hit。
  第三轮 cleanup 汇总 log 为
  `local_debug/hw_cbmc_subsystem_dual_subset_20260505_185651_compat_cast_cleanup3.log`；
  第二轮 cleanup 汇总 log 为
  `local_debug/hw_cbmc_subsystem_dual_subset_20260505_183554_compat_cast_cleanup2.log`；
  第一轮 cleanup 汇总 log 为
  `local_debug/hw_cbmc_subsystem_dual_subset_20260505_181213_compat_cast_cleanup.log`。
- [x] C++ 模块功能回归：实际 C++ 改动后需重跑
  `ctest --test-dir build_dual_axi_scope_20260428 --output-on-failure`；本轮已复跑并通过
  24/24，其中 `axi_interconnect_dual_port_test` 内部通过 38/38。最新 targeted log：
  `local_debug/axi_interconnect_dual_port_test_accepted_id_20260505.log`；最新 ctest log：
  `local_debug/ctest_after_accepted_id_20260505.log`。2026-05-06 新增 trace-only
  `invalidate_all` + pending MMIO read/write 组合后再次执行同一 ctest 命令，24/24
  通过；同日新增同 64B hazard granule direct MMIO read-pending write trace 后又复跑
  同一 ctest 命令，24/24 通过；随后新增对称的 direct MMIO write-pending read trace
  及 C++ fall-through 修复后再次复跑同一 ctest 命令，24/24 通过。新增 MODE_CACHE
  pending MMIO read 期间请求 MODE_MAPPED 的 trace 后再次复跑同一 ctest 命令，24/24
  通过；继续补入对称 pending MMIO write trace 后再次复跑同一 ctest 命令，24/24 通过；
  继续补入 pending MMIO read/write 同时在途、`B` 先于 `R` 返回的 reconfig drain
  trace 后再次复跑同一 ctest 命令，24/24 通过。
- [x] Linux/image 级 300k/5M 功能与性能 sanity：父仓库临时适配 cacheability/MMIO
  分类后，large + `CONFIG_BPU` + `../img/linux.bin` 已补跑 300k 与 5M commit。
  该 gate 不能只看退出码或 difftest/error；每轮都必须同时记录并比较
  baseline/current 的 cycles、IPC、commit/load/store 计数和关键 memory latency。
  对 deterministic boot quick gate，若当前改动理论上不应影响性能，则 cycle/IPC
  应尽量完全一致；任何 cycle 上升或 IPC 下降都要给出百分比和解释，超过约 1% 或
  无法解释时按性能回归处理。
  之前失败点是约 58,695 commit 后父仓库 MSHR 以 cacheline read 请求
  `0x00000040`，而新双口合同下非 DDR/MMIO 只支持 32-bit/1-beat，导致 interconnect
  合理保持 `ready=0/accepted=0` 并触发 ROB deadlock；该问题已通过父仓库临时把
  `< CONFIG_AXI_KIT_DDR_BASE` 归入 MMIO/peripheral 路径消除。原失败 log：
  `../local_logs/dual_axi_ec_20260505/linux_large_bpu_5m_after_ec_push_imgroot_20260505_160533.log`。
  新 300k log：
  `../local_logs/dual_axi_ec_20260505/linux_large_bpu_300k_mmio_contract_20260505.log`，
  结果为 300001 commit、120687 cycles、IPC 2.485777；对照旧 binary 300k
  `../local_logs/dual_axi_ec_20260505/linux_300k_old_binary_semantics_20260502_20260505_160931.log`
  为 120719 cycles、IPC 2.485118，未见性能回退。新 5M log：
  `../local_logs/dual_axi_ec_20260505/linux_large_bpu_5m_mmio_contract_20260505.log`，
  结果为 5000005 commit、2078844 cycles、IPC 2.405185，`Success!!!!`。稳定后仍需
  在最终父仓库集成点补 10M 或更长 difftest/perf 回归。
  submodule 推到 `998c008` 后又用当前代码重建
  `build_dual_axi_ec_20260505_large_bpu_998c008` 并复跑同一 Linux 5M gate，log 为
  `../local_logs/dual_axi_ec_20260505/linux_large_bpu_5m_998c008_20260505_194456.log`，
  结果仍为退出码 0、5000005 commit、2078844 cycles、IPC 2.405185、墙钟 6:10.23；
  与上一条 5M 基线 cycle/IPC 完全一致。新增 `invalidate_all` + cache refill +
  held MMIO read trace 以及 C++ stale LLC read issue 修复后，又用
  `build_dual_axi_ec_20260505_large_bpu_inval_cache_mmio` 复跑同一 Linux 5M gate，
  log 为
  `../local_logs/dual_axi_ec_20260505/linux_large_bpu_5m_inval_cache_mmio_20260505_212056.log`，
  结果为退出码 0、5000005 commit、2078844 cycles、IPC 2.405185、墙钟 6:12.53；
  与上一条 5M 基线 cycle/IPC 完全一致。
  2026-05-06 在 submodule `0dce8d4` 上又按 large + `CONFIG_BPU` 重建
  `build_dual_axi_ec_20260506_large_bpu_0dce8d4`，先跑 300k：
  `../local_logs/dual_axi_ec_20260506/linux_large_bpu_300k_0dce8d4_20260506_113340.log`，
  对照 `a9ee8e8` 300k baseline，结果同为 300001 commit、120687 cycles、IPC
  2.485777。随后跑 5M：
  `../local_logs/dual_axi_ec_20260506/linux_large_bpu_5m_0dce8d4_20260506_113425.log`，
  对照 `../local_logs/dual_axi_ec_20260506/linux_large_bpu_5m_a9ee8e8_20260506_102229.log`，
  两者同为退出码 0、5000005 commit、2078844 cycles、IPC 2.405185；L1D AMAT
  2.373202、L1D miss penalty 61.364674 cycles、LLC->DDR read avg 52.000000 cycles
  也完全一致，因此本轮 cycle delta=0、IPC delta=0，未出现可观测性能回退。2026-05-06
  submodule 继续推进到 `605012b` 后只新增 trace/TB/docs，不改变生产 C++/RTL
  路径；用同一 large+BPU binary 再跑 300k quick：
  `../local_logs/dual_axi_ec_20260506/linux_large_bpu_300k_605012b_20260506_124549.log`，
  结果为退出码 0、300001 commit、120687 cycles、IPC 2.485777、load/store
  40586/51609、L1D AMAT 2.776803；与 `0dce8d4` 300k baseline 完全一致。
  2026-05-06 submodule 继续推进到 `0397b98` 后仍只新增 trace/formal/TB/docs/DC
  脚本，不改变 production simulator 路径；用同一 large+BPU binary 再跑 300k 与
  5M gate。300k log：
  `../local_logs/dual_axi_ec_20260506/linux_large_bpu_300k_0397b98_prodeq_0dce8d4_20260506_133657.log`，
  对照 `a9ee8e8` baseline，结果同为 300001 commit、120687 cycles、IPC 2.485777。
  5M log：
  `../local_logs/dual_axi_ec_20260506/linux_large_bpu_5m_0397b98_prodeq_0dce8d4_20260506_133746.log`，
  对照 `../local_logs/dual_axi_ec_20260506/linux_large_bpu_5m_a9ee8e8_20260506_102229.log`，
  两者同为退出码 0、5000005 commit、2078844 cycles、IPC 2.405185、load/store
  530423/921658；L1D AMAT 2.373202、L1D miss penalty 61.364674 cycles、
  LLC->DDR read avg 52.000000 cycles 也完全一致，因此本轮 cycle delta=0、IPC
  delta=0，未出现可观测性能回退。
	  后续所有 Linux 5M 或更长 boot gate 都必须沿用这个判定标准：不允许只报告
	  pass/error，必须同时给出 cycles、IPC 及相对 baseline 的 delta；若当前改动理论上不应
	  影响性能，任何非零 cycle/IPC 差异都需要先解释来源，再决定是否接受。
	  2026-05-06 后续推进到 `3a2020c` 期间只新增 trace generator、RTL TB、
	  generated TB include 和 docs，不改 production C++/RTL 路径，因此仍沿用上述
	  300k/5M cycle delta=0、IPC delta=0 的性能结论；下一次 production 路径改动后必须
	  重新跑 300k/5M 并按同一口径报告。

## Multi-Agent 并行推进边界

- 可并行推进的只读/低冲突工作：formal manifest/README 校准、production-width
  dual bridge response mux/forward-progress witness 分析、native dual top 64B line /
  32B DDR beat smoke 方案拆分、trace-based EC 随机/maintenance 场景筛选、DC/RTL
  hygiene 静态审查。
- 不应并行改同一文件的工作：`AXI_Interconnect.cpp`、trace generator、同一个 RTL
  contract testbench。此类应由一个主线 agent 持有写权限，其他 agent 做只读审查或
  分析独立文件，避免 patch 冲突和语义漂移。
- 不能被 multi-agent 替代的最终 gate：同一稳定代码点上的 C++ `ctest`、RTL
  `run_all_contracts.sh` / `run_dual_axi_contracts.sh`、hw-cbmc manifest、DC link/full
  compile、Linux/image difftest/perf。多 agent 可以准备输入和拆分方案，但最终仍需
  等待可信工具结果。
- 备份/长跑顺序：C++/RTL 等价性短回归和 checklist 收敛到可交付点后，先在
  submodule 内建/复用非 `main` 分支并 `git push` 备份；full DC 这类长耗时验证放在
  push 之后启动。Linux large + `CONFIG_BPU` + 5M commit 属于中等耗时 gate，一切顺利
  时可在 push 前后作为功能/性能 sanity 补跑。2026-05-06 探测后，下一轮 full DC
  首选 `eda-10`；若 license/资源变化，再按 `rtl/dc/README_CN.md` 的 smoke test
  重探测 `eda-09`/`eda-05`。
- 短期收敛预估：不含 Linux 长跑和 full 1GHz signoff 时，单 agent 串行约 3-4 个
  工作日；5-7 个 agent 分工后可压到约 1-1.5 个工作日外加最终 gate 时间。若包含
  full-top DC/1GHz 和 Linux/image 回归，主要瓶颈变成工具运行时间，预计只能从
  5-7 天压到约 4-6 天。

## 功能合同跟踪

- [x] DDR/MMIO 双外部 AXI 口分流。
- [x] DDR/MMIO read/write outstanding 共享预算与读写预算独立性。
- [x] 同 line `AR` 未完成前阻塞同地址 `AW`。
- [x] 同 line `AW/B` 未完成前阻塞同地址 `AR`。
- [x] 外部 `RREADY` 不被上游 response stall 回压。
- [x] 外部 `BREADY` 不被上游 response stall 回压，但仍受内部 response queue 空间保护。
- [x] 同一 upstream read master 多 ID response 交错：后完成/先完成不按 AR 顺序覆盖，
  而按 downstream 完成顺序 FIFO 输出；held response 在 upstream ready=0 时保持稳定。
- [x] 同一 upstream write master 多 ID `B` response 交错：后完成/先完成不按 AW 顺序覆盖，
  而按 downstream 完成顺序 FIFO 输出；held write response 在 upstream ready=0 时保持
  稳定，且外部 `BREADY` 不被当前 held response 串行化。
- [x] read-side owner/ID release-reuse：read response 被 upstream 消费后，下一笔 read
  可继续 accepted/发 `AR`，并复用已释放 downstream AXI ID。
- [x] write-side owner/ID release-reuse：write response 被 upstream 消费后，下一笔 write
  可继续 accepted/发 `AW/W`，并复用已释放 downstream AWID。
- [x] read full-budget release-reaccept：32 个 read outstanding 满后阻塞第 33 笔 read；
  消费一笔 response 后重新接受新 read，并复用释放的 downstream ARID。
- [x] write full-budget release-reaccept：32 个 write outstanding 满后阻塞第 33 笔 write；
  消费一笔 `B` response 后重新接受新 write，并复用释放的 downstream AWID。
- [x] 64B cacheline DDR read/write 的 2-beat 256-bit AXI 形状。
- [x] 窄 DDR/MMIO read/write 的 data/strobe 对齐与切片；MODE_OFF/direct DDR
  1B/2B/4B/8B/16B/32B/64B actual C++ trace 到实际 RTL subsystem contract 已覆盖
  read slice/write pack；4B read/write 与 8B read 的 beat 对齐已由
  `formal/subsystem_dual_mode0_ddr_bypass_align` 覆盖，4B read response slice 已由
  `formal/subsystem_dual_mode0_ddr_bypass_read_response` 覆盖，8B read response 已由
  `formal/subsystem_dual_mode0_ddr_bypass_read_response_8b` 覆盖。
- [x] MMIO 口只支持 32-bit / 1 beat：C++ direct test 覆盖 unsupported MMIO 大请求阻塞；
  bridge-level 与 native dual top formal 均覆盖 unsupported MMIO 大 read/write 不被接受、
  不逃逸到外部 AXI。
- [x] mode2 mapped window aligned read/write；全量 RTL contract 已覆盖 legacy single-AXI
  mode2 下起始地址命中 MMIO、但请求尾部越过 MMIO 末端时仍保持 MMIO passthrough，
  不误走 DDR aligned `AR/AW`；本轮补齐 dual-subsystem actual C++ trace 下 mapped
  local-window write/read 不逃逸到外部 DDR/MMIO AXI 口且写后读数据一致，同时补齐
  当前 RTL contract 窗口内起点/末端 line 写后读边界，以及 mapped-window
  下边界外 MMIO read 和上边界外 MMIO write 路由。
- [x] MODE_CACHE 到 MODE_MAPPED reconfig drain：MMIO read `AR` 已发且 `R`/upstream
  response 尚未 retire 时，请求 MODE_MAPPED 不得回压外部 MMIO `RREADY`，也不得提前
  完成 active mode 切换；对称地，MMIO write `AW/W` 已发且 `B`/upstream response
  尚未 retire 时，不得回压外部 MMIO `BREADY`，也不得提前完成 active mode 切换；
  read/write 同时在途且 `B` 先于 `R` 返回时，即使 write response 已被上游消费，也必须
  等 read `R` 和 upstream read response 完成后才允许进入 MODE_MAPPED。
- [x] MODE_CACHE cacheable read miss/refill 与 MMIO read direct-bypass 并发：cache miss
  发 DDR 64B/2-beat refill，同时 MMIO read 独立走 MMIO 口；上游 response stall 不回压
  MMIO/DDR `RREADY`，两拍 refill 后 cache response 与实际 C++ trace 一致。
- [x] MODE_CACHE partial cache write miss/refill 与 MMIO write direct-bypass 并发：
  partial write miss 发 DDR 64B/2-beat refill，同时 MMIO write 独立走 MMIO `AW/W/B`；
  上游 response stall 不回压 MMIO `BREADY` 或 DDR `RREADY`，两拍 refill/merge 后
  cache write response 与实际 C++ trace 一致。
- [x] MODE_CACHE dirty victim writeback 与 MMIO write direct-bypass 并发：dirty victim
  `AW/W` 已发出但 DDR `B` 未返回时，另一 write master 的 MMIO 4B write 仍独立走
  MMIO `AW/W/B`，MMIO held response 不反压 DDR victim `BREADY`，DDR `B` 后 cache
  write response 与实际 C++ trace 一致；本轮扩展同一路径叠加 `invalidate_all` pending，
  要求 MMIO/victim `BREADY` 不被回压，且 MMIO/cache response retire 前不接受
  maintenance，retire 后仍因 dirty resident line 保持 blocked。
- [x] invalidate_line / invalidate_all 相关 hazard、drain 与 recovery 合同；
  MODE_CACHE 下 cacheable read miss/refill 未完成和 read response 被上游 hold 时，
  `invalidate_line` 必须保持阻塞，response 被消费后才允许 accepted，且该场景已由
  actual C++ trace 到实际 RTL subsystem contract 覆盖；本轮补齐对称的 cacheable
  write miss/refill + pending MMIO write + target-line `invalidate_line` 组合，要求
  MMIO `BREADY`/DDR refill `RREADY` 不被回压，两个 write response 均 retire 后才
  accepted。
- [ ] C++ reference 与 RTL 端到端形式 EC；当前已有 production-helper read issue
  shape 切片，但完整 C++ class / RTL top 同 harness 仍未完成。
- [ ] RTL 可综合性与 1GHz pre-DC hygiene gate。
- [ ] Linux/image 级长期性能与 difftest 回归。
