# RTL Testbench 说明

本目录存放当前 RTL 的 directed / contract testbench。

当前目标不是跑完整系统，而是先把已经落地的语义边界独立验证：

- 同步 `data/meta/valid/repl` store 合同
- `invalidate_sweep`
- mode2 direct-window 地址翻译与 zero-merge
- reconfiguration FSM
- 顶层 mode 路由、mode2 可见性、mode 切换失效
- 对外顶层到单组 AXI4 的请求打包合同
- mode2 窗口外 DDR 对齐读写合同（含跨 32B 回退和 MMIO passthrough）
- mode1 bypass 重新进入 core 后的 resident-hit / shadow-update 合同

## 当前提供

- `tb_llc_data_store.v`
- `tb_llc_meta_store.v`
- `tb_llc_valid_ram.v`
- `tb_llc_repl_ram.v`
- `tb_llc_invalidate_sweep.v`
- `tb_llc_mapped_window_ctrl.v`
- `tb_axi_reconfig_ctrl.v`
- `tb_axi_llc_subsystem_directed.v`
- `tb_axi_llc_subsystem_handshake_contract.v`
- `tb_axi_llc_subsystem_mode_contract.v`
- `tb_axi_llc_subsystem_cache_contract.v`
- `tb_axi_llc_subsystem_invalidate_line_contract.v`
- `tb_axi_llc_subsystem_invalidate_line_read_hazard_contract.v`
- `tb_axi_llc_subsystem_size_contract.v`
- `tb_axi_llc_subsystem_invalidate_all_contract.v`
- `tb_axi_llc_subsystem_id_contract.v`
- `tb_axi_llc_subsystem_read_slice_contract.v`
- `tb_axi_llc_subsystem_bypass_contract.v`
- `tb_axi_llc_subsystem_mode1_bypass_resident_contract.v`
- `tb_axi_llc_subsystem_compat_reconfig_drain_contract.v`
- `tb_axi_llc_subsystem_compat_invalidate_line_hazard_contract.v`
- `tb_axi_llc_subsystem_compat_write_victim_multiflow_contract.v`
- `tb_axi_llc_subsystem_compat_victim_line_hazard_contract.v`
- `tb_axi_llc_subsystem_compat_victim_snapshot_refresh_contract.v`
- `tb_axi_llc_subsystem_axi_cache_refill_contract.v`
- `tb_axi_llc_subsystem_axi_bypass_read_contract.v`
- `tb_axi_llc_subsystem_axi_bypass_write_contract.v`
- `tb_axi_llc_subsystem_axi_mode2_aligned_read_contract.v`
- `tb_axi_llc_subsystem_axi_mode2_aligned_write_contract.v`
- `tb_axi_llc_subsystem_axi_mode1_multiflow_contract.v`
- `tb_axi_llc_subsystem_axi_cache_multiread_contract.v`
- `tb_axi_llc_subsystem_axi_same_master_multiread_contract.v`
- `tb_axi_llc_subsystem_compat_direct_bypass_contract.v`
- `tb_axi_llc_subsystem_compat_same_line_hol_contract.v`
- `tb_axi_llc_subsystem_compat_read_accept_contract.v`
- `tb_axi_llc_axi_bridge_read_outstanding_contract.v`
- `tb_axi_llc_axi_bridge_write_outstanding_contract.v`
- `tb_axi_llc_axi_bridge_32_outstanding_contract.v`
- `tb_axi_llc_axi_bridge_write_id_reuse_contract.v`
- `tb_axi_llc_axi_bridge_dual_contract.v`
- `tb_axi_llc_axi_dual_port_router_contract.v`
- `tb_axi_llc_dual_port_hazard_scoreboard_contract.v`
- `tb_axi_llc_subsystem_dual_mmio_contract.v`
- `tb_axi_llc_subsystem_dual_outstanding_contract.v`
- `tb_axi_llc_subsystem_dual_cpp_trace_contract.v`
- `tb_axi_llc_subsystem_read_master_timing_contract.v`
- `tb_llc_smic12_store_contract.v`

### `tb_axi_llc_subsystem_bypass_contract.v`

目标是独立卡住 `mode=1 + up_req_bypass=1` 这条 C++-style bypass 合同：

- bypass read hit 直接从 resident 返回，不触发 lower bypass read
- bypass read miss 触发 lower bypass read，但不安装 resident
- bypass write hit 做 resident shadow update，不置 dirty，同时保持 lower bypass write-through
- bypass write miss 只做 lower bypass write，不安装 resident

这个 bench 在 `USE_SMIC12_STORES=0` 的前提下，层次化预装载 generic `data/meta/valid`
store 来构造 resident 命中场景。它只检查 bypass 合同，不要求固定实现路径；
如果 bypass 请求仍然被硬送到 lower bypass，或者 bypass write hit 不能完成 write-through
响应，该 bench 会失败。

### `tb_axi_llc_subsystem_mode1_bypass_resident_contract.v`

目标是把最终顶层 `axi_llc_subsystem.v` 上最关键的 mode1 bypass 路由合同单独钉住：

- `mode=1 bypass read hit` 必须进入 core，直接返回 resident 数据，不触发 AXI `AR`
- `mode=1 bypass write hit` 必须进入 core，做 resident shadow update，并且继续 write-through
- dirty resident 上的 `mode=1 bypass read` 必须优先返回 resident 数据，而不是 lower 旧值

这个 bench 直接实例化最终顶层，并通过层次化预装载 internal resident store 来构造 hit 场景；
因此它能明确区分“core 内部 bypass 语义正确”与“顶层实际有没有把 mode1 bypass 接回 core”。

### `tb_axi_llc_subsystem_axi_mode1_multiflow_contract.v`

目标是钉住当前 `mode=1` 的非单流合同：

- 一个 cache miss read 已经在 AXI lower 侧 outstanding 时
- 另一个 read master 的 bypass read 仍然可以继续下发第二笔 AXI AR
- bypass read 的上游 response 可以先于 cache miss refill 返回
- reset 后的独立场景中
- 一个 cache miss read outstanding 时，另一个 write master 的 bypass write 仍然可以继续下发 AXI AW/W/B
- bypass write 的上游 response 可以先于 cache miss refill 返回
- 反向顺序下：
  - bypass read miss 在途时，后续 cache miss 仍可继续发 AXI `AR`
  - bypass write-through 在途时，后续 cache miss 仍可继续发 AXI `AR`

这个 bench 直接挂在最终顶层 `axi_llc_subsystem.v` 上验证 cache miss 与 bypass 的并发下发/返回。
旧的 `tb_axi_llc_subsystem_compat_contract.v` /
`tb_axi_llc_subsystem_compat_read_queue_contract.v`
假定 bypass lower id 直接等于 upstream id，且 queued bypass 不会在前一笔完成前继续发射；
当前实现已经不再满足这两条旧假设，因此改由本 bench 与下面的
`tb_axi_llc_subsystem_compat_direct_bypass_contract.v` 共同覆盖新的合同。

### `tb_axi_llc_subsystem_axi_cache_multiread_contract.v`

目标是钉住“不同 read master 的两个 cacheable read miss 都能进入 core/read-miss slot，
并在 lower AXI 上形成两笔 read outstanding”：

- 两个 cacheable read miss 都必须发出各自的 AXI `AR`
- 在看到任何 `R` 之前，必须已经看到这两笔 `AR`
- 两个上游 read response 必须回到各自原始 master / `req_id`

### `tb_axi_llc_subsystem_axi_same_master_multiread_contract.v`

目标是钉住“`MASTER_DCACHE_R` 同一 master 的多笔 cacheable read miss + read response queue”：

- 同一 master 的两笔 cacheable read miss 都必须发出各自的 AXI `AR`
- lower `R` 返回后，两笔 response 必须按 `req_id` 顺序依次在同一个 master 的前台 response slot 上可见
- 该 bench 同时验证 compat 侧 per-master read response queue

### `tb_axi_llc_subsystem_compat_direct_bypass_contract.v`

目标是把 direct-bypass 路径里最容易出错的 compat 合同单独钉住：

- read `accepted` / `accepted_id` 仍然必须和上游请求匹配
- 同一 master 上，direct-bypass request 还在 slot / response 槽中时，重复 `req_id` 必须被拒绝
- 当 master 的 read response 槽被占住时，lower bypass completion 必须停在 `bypass_resp_ready=0`
- 槽位释放后，挂起的 lower bypass completion 必须继续前进并回到正确 master/`req_id`

### `tb_axi_llc_subsystem_compat_bypass_pending_issue_contract.v`

目标是钉住 `mode=1 bypass miss / write-through` 的 pending-issue handoff 合同：

- 当 lower ready 被故意拉低时，core 判定出的 bypass miss / write-through 必须先 handoff 到
  compat direct slot
- handoff 之后，后续 cache miss 不需要等 bypass lower 真正 handshake 才能继续推进
- 该 bench 同时覆盖 read-miss 与 write-through 两种路径

### `tb_axi_llc_subsystem_compat_non_dcache_bypass_master_contract.v`

目标是钉住非 `MASTER_DCACHE_R` same-master `mode=1 bypass read` 的限制仍然保持：

- 第一笔 bypass read 在 compat direct slot 中未退休时
- 第二笔 same-master bypass read 不能被提前 accept
- 第一笔退休后，第二笔才允许重新推进

### `tb_axi_llc_subsystem_compat_same_line_hol_contract.v`

覆盖：

- same-line blocked cacheable request 在接受面就会被 backpressure 挡住，
  不会先被 accept 到 compat FIFO
- 其它 master 上不相关 line 的 cacheable miss 仍可继续进入 core / lower
- same-line hazard 消失后，原先被挡住的请求仍会继续推进并正常回包

### `tb_axi_llc_subsystem_compat_read_accept_contract.v`

目标是把 compat 外层 read `ready/accepted` 合同单独钉住：

- same-line blocked cacheable read 不能先被 accept 到 compat FIFO
- 非 `MASTER_DCACHE_R` 在已有 core-path read 未退休时，不能继续 accept 新的 cacheable read
- 当前台 read response slot / response queue 仍忙时，该 master 不能继续 accept
  新的 cacheable read

### `tb_axi_llc_subsystem_compat_reconfig_drain_contract.v`

目标是把 compat 层和 reconfig 边界之间的 drain 合同单独钉住：

- `mode_req` 变化触发的 reconfig 不能在 compat queued read / inflight read 未清空时提前完成
- drain 期间旧模式下已入队的请求必须继续按旧模式路由
- `invalidate_all_accepted` 必须等到 compat 队列与 inflight 都排空后才允许脉冲

这个 bench 采用 `mode=0 -> mode=1` 的切模场景，并故意在同一个 read master 上制造：

- 1 笔已经发往 lower 的 inflight bypass read
- 1 笔尚未出队的 compat queued read
- 第 1 笔 response slot 被上游暂时 backpressure 持有

要求第 2 笔 queued read 在 `active_mode` 仍保持旧值时先通过 `bypass_req` drain，之后才允许切到新模式。

对应 flist：

- `flist/tb_axi_llc_subsystem_compat_reconfig_drain_contract.f`

### `tb_axi_llc_subsystem_compat_invalidate_line_hazard_contract.v`

目标是把 `invalidate_line` 与 same-line write hazard 的合同单独钉住：

- compat-local queue / inflight / response slot 未排空时，`invalidate_line` 不能被 accepted
- 同 line write 仍处于 inflight / compat queue / response slot 时，仍是显式覆盖的局部 hazard
- 只有 compat-local drain 完成后，`invalidate_line` 才允许重新 accepted

### `tb_axi_llc_subsystem_compat_pending_direct_maintenance_contract.v`

目标是把 pending-issue direct slot 与 maintenance 边界的合同单独钉住：

- 当 `mode=1 bypass read miss` 已 handoff 到 compat direct slot、但 lower 仍未 ready 时，
  unrelated `invalidate_line` 不能被 accepted
- 同样条件下，`invalidate_all` 也不能被 accepted
- 只有该 pending direct slot 退休后，maintenance 才允许继续前推

这个 bench 采用 `mode=1` cache write 路径，显式覆盖：

- 第 1 笔 same-line write 已发往 lower cache，形成 active write hazard
- 第 2 笔 same-line write 已被 compat 接收但因 response slot/backpressure 暂留队列

对应 flist：

- `flist/tb_axi_llc_subsystem_compat_invalidate_line_hazard_contract.f`

### `tb_axi_llc_subsystem_invalidate_line_read_hazard_contract.v`

目标是把 core 侧 `invalidate_line` 的 same-line read hazard 合同单独钉住：

- 同 line lookup 尚未结束时，`invalidate_line` 不能被 accepted
- 同 line read miss / refill 仍在 MSHR 中挂起时，`invalidate_line` 不能被 accepted
- pending dirty victim 仍归属该 line 时，`invalidate_line` 仍不能被 accepted
- 所有上述 read-side hazard 清空后，`invalidate_line` 才允许被 accepted

这个 bench 直接实例化 `axi_llc_subsystem_core.v`，避免 compat 的 coarse drain 把
core 内部 hazard 遮掉。

对应 flist：

- `flist/tb_axi_llc_subsystem_invalidate_line_read_hazard_contract.f`

### `tb_axi_llc_subsystem_compat_write_victim_multiflow_contract.v`

目标是钉住 dirty-victim 的 cacheable full-line write miss 不再把其它 cache miss 全部串死：

- full-line write miss 遇到 dirty victim 时，先发 victim writeback
- victim writeback 在途时，另一条不相关 cache miss 仍可继续进入 lower cache
- write miss 和 read miss 最终都要正常回包

对应 flist：

- `flist/tb_axi_llc_subsystem_compat_write_victim_multiflow_contract.f`

### `tb_axi_llc_subsystem_compat_victim_line_hazard_contract.v`

目标是钉住 pending dirty victim 的 victim-line access 合同：

- dirty-victim read miss 先发 refill；refill ready 后 victim-line read/write 在 compat
  接受面不会被提前吞入
- victim hazard 清空后，该 victim line 会重新变得可访问

对应 flist：

- `flist/tb_axi_llc_subsystem_compat_victim_line_hazard_contract.f`

### `tb_axi_llc_subsystem_compat_victim_snapshot_refresh_contract.v`

目标是钉住 C++ 的 pending-read-victim 特化语义：

- dirty-victim read miss 必须先发 refill read
- refill 返回前，victim-line write hit 仍应被接受
- 随后的 victim writeback 必须带走刷新后的 snapshot
- miss 的 read response 不依赖 victim writeback 完成

对应 flist：

- `flist/tb_axi_llc_subsystem_compat_victim_snapshot_refresh_contract.f`

### 对外 AXI 顶层 contract bench

下面这 3 个 bench 直接面向当前对外顶层 `axi_llc_subsystem.v`：

- 上游沿用当前 C++ 风格的 `read_masters[] / write_masters[]`
- 下游只保留一组 AXI4 `AW/W/B/AR/R`
- 这组 bench 只卡事务合同，不直接观测内部 `cache_* / bypass_*`

### `tb_axi_llc_subsystem_axi_cache_refill_contract.v`

- `mode=1` 的 64B cache refill 必须发 1 次 `AR`
- `arlen=1`，`arsize=5`，`arburst=INCR`
- 必须消费 2 个 32B `R` beat 并组回 1 个 64B line
- refill 期间不得误驱动 `AW/W/B`

### `tb_axi_llc_subsystem_axi_bypass_read_contract.v`

- bypass 4B read 必须发 single-beat `AR`
- `arlen=0`，`arsize=5`，`arburst=INCR`
- 只允许消费 1 个 `R` beat
- 读响应 `id` 必须回到上游原始事务 `id`
- `RDATA` 仍按单个 32B beat 返回，使用方只消费低几个字节

### `tb_axi_llc_subsystem_axi_bypass_write_contract.v`

- bypass 4B write 必须发 `AW -> W -> B`
- `awlen=0`，`awsize=5`，`awburst=INCR`
- `W` 必须 single-beat，且 `wlast=1`
- `WDATA/WSTRB` 采用低地址连续打包，不再按 `awaddr[4:0]` 二次移位
- `B` 回来后必须生成上游 write response

### `tb_axi_llc_axi_bridge_read_outstanding_contract.v`

- 直接面向 `axi_llc_axi_bridge.v`
- 覆盖 `cache read + bypass read` 同时 outstanding
- 要求两个 read 使用不同 AXI `ARID`
- 允许跨 source 乱序返回
- response 最终仍按各自 source-local `req_id` 回传

### `tb_axi_llc_axi_bridge_write_outstanding_contract.v`

- 直接面向 `axi_llc_axi_bridge.v`
- 覆盖 `cache write + bypass write` 同时 outstanding
- 要求两个 write 使用不同 AXI `AWID`
- `BID` 可以先回 bypass、后回 cache
- 两类 source 必须仍回到各自的 `req_id`

### `tb_axi_llc_axi_bridge_32_outstanding_contract.v`

- 直接面向 `axi_llc_axi_bridge.v`
- 先保持 32 个 read outstanding 不返回，确认第 33 个 read 被 backpressure
- 在 read outstanding 已满时继续接受 32 个 write outstanding，确认读写预算相互独立
- 再确认第 33 个 write 被 backpressure

### `tb_axi_llc_axi_bridge_write_id_reuse_contract.v`

- 直接面向 `axi_llc_axi_bridge.v`
- 覆盖“`B` 已返回但 source response 仍 backpressure”场景
- 合同要求：
  - 已完成 write 的 AXI `id` 可以被下一笔 write 立即重用
  - 第 1 笔 source response 尚未消费时，第 2 笔仍可继续进入 lower AXI

### `tb_axi_llc_axi_dual_port_router_contract.v`

- 直接面向 `axi_llc_axi_dual_port_router.v`
- 覆盖过渡 shim 的 DDR/MMIO 地址分类和双口 response 回路由
- DDR 请求保持既有 256-bit beat / multi-beat 形状
- MMIO 请求改写为 32-bit / 1 beat
- 覆盖 DDR/MMIO read response 乱序返回，以及 DDR/MMIO write `B` response 回路由

这个 bench 只验证过渡 shim，不代表最终 native dual-port bridge 的性能结构。

### `tb_axi_llc_axi_bridge_dual_contract.v`

- 直接面向 `axi_llc_axi_bridge_dual.v`
- 覆盖 lower request 层直接分流，不经过单 AXI 中间口
- 验证 DDR cache read 与 MMIO bypass read 可以同周期都被接受，并分别发到两个 AXI 口
- 验证 DDR cache write 与 MMIO bypass write 可以同周期都被接受，并分别发到两个 AXI 口
- 验证 MMIO 口为 32-bit / 1 beat
- 验证大于 4B 的 MMIO 请求会被 backpressure 挡住
- 验证 MMIO write `B` 先于 DDR write `B` 返回时，response 仍分别回到 bypass/cache source
- 验证同一 cache response source 同时有 DDR/MMIO read response 待回、且
  `cache_resp_ready=0` 时，外部 DDR/MMIO `R` 仍先被各自 bridge 用 `RREADY` 接收并
  缓存；之后 response mux 再按 MMIO 优先级送回上游
- 验证同一 cache response source 同时有 DDR/MMIO write `B` 待回、且
  `cache_resp_ready=0` 时，外部 DDR/MMIO `B` 仍先被各自 bridge 用 `BREADY` 接收并
  缓存；之后 response mux 再按 MMIO 优先级送回上游
- 验证 native bridge 外部 `AR/AW` 同 line hazard：读未返回时同 line 写不能发
  `AW/W`，写未完成时同 line 读不能发 `AR`，不同 line 不被该 gate 串行化
- 验证 same-line 写已被 read hazard 挡住、且上游 read response ready 拉低时，DDR
  `R` 两个 beat 仍必须被 `RREADY` 接收，不能把外部 `R` 接收依赖到 response mux /
  上游 ready / 写侧完成
- 验证 same-line 读已被 write hazard 挡住、且上游 write response ready 拉低时，
  DDR `B` 仍必须被 `BREADY` 接收；bridge 层外部 `AR` issue hazard 在 `B` fire 后
  释放，不等待上游 write response 被消费

当前该 bench 仍不验证全局 shared outstanding 计数；该预算由上游 compat/top 层约束。

### `tb_axi_llc_dual_port_hazard_scoreboard_contract.v`

- 直接面向 `axi_llc_dual_port_hazard_scoreboard.v`
- 覆盖 DDR `AR` 记录 pending-read hazard，并验证错误 `RID` 不释放、匹配 `RID`
  释放
- 覆盖 DDR `AW` 记录 pending-write hazard，并验证错误 `BID` 不释放、匹配 `BID`
  释放
- 覆盖 DDR/MMIO read/write entries 可以同时占用 shared slots，并按 port/id 分别释放
- 该 bench 直接解析生产 `axi_llc_dual_port_hazard_match.v` 和
  `axi_llc_dual_port_slot_hazard.v`，用于补足完整 scoreboard formal harness 暂时
  不能在默认 timeout 内收敛的状态覆盖

### `tb_axi_llc_subsystem_dual_mmio_contract.v`

- 直接面向 `axi_llc_subsystem_dual.v`
- 覆盖 mode1 普通 MMIO 读写请求不依赖上游 `*_bypass` 标志，也会直接走 MMIO AXI 口
- 验证 MMIO 读写不会驱动 DDR AXI 口
- 验证 MMIO 口为 32-bit / 1 beat，读写 response 回到原 upstream ID
- 覆盖 DDR cache refill `AR` 被 backpressure 保持时，MMIO read/write 仍可在独立
  MMIO AXI 口发射和返回，不被 DDR 口串行化
- 覆盖 DDR bypass read 已发 `AR`、尚未收到 `R` 时，同 line DDR bypass write 不得
  提前发 `AW/W`；`R` 返回后写事务继续完成并回到原 upstream ID
- 进一步把 upstream read response ready 拉低，验证 DDR `R` 仍会先被 `RREADY`
  接收并缓存在内部；同 line 写只依赖外部 `R` 已接收，不等待 upstream read response
  被消费
- 覆盖对称 write-then-read 场景：同 line read 在 write 完成前不会被 top/compat
  接收；upstream write response ready 拉低时，DDR `B` 仍会先被 `BREADY` 接收并
  缓存在内部；当前 core-path 接收面会等 write response slot 被上游消费后，再接收
  并继续该 same-line read

### `tb_axi_llc_subsystem_dual_outstanding_contract.v`

- 直接面向 `axi_llc_subsystem_dual.v`
- 在 `MODE_OFF` direct-bypass 场景验证 DDR/MMIO 两个外部口共享 read outstanding 总预算 32
- 先让 DDR/MMIO read 合计 32 个 outstanding 不返回，确认第 33 个 read 被挡住
- 在 read outstanding 已满时继续接受 32 个 write，确认读写预算相互独立
- reset 后反向验证 write outstanding 已满时仍能接受 32 个 read，并挡住第 33 个 read
- 验证 DDR read 与 MMIO read 同时在途时，MMIO `R` 先返回、DDR `R` 后返回，
  response 仍分别回到原 read master
- 验证 DDR write 与 MMIO write 同时在途时，MMIO `B` 先返回、DDR `B` 后返回，
  response 仍分别回到原 write master
- 验证 DDR/MMIO `R` 同时返回且上游 `read_resp_ready=0` 时，外部 `RREADY` 不被
  top/compat response stall 反压，两个 response 都能缓存并回到正确 master
- 验证 DDR/MMIO `B` 同时返回且上游 `write_resp_ready=0` 时，外部 `BREADY` 不被
  top/compat response stall 反压，两个 response 都能缓存并回到正确 master

### `tb_axi_llc_subsystem_dual_cpp_trace_contract.v`

- 直接面向实际 `axi_llc_subsystem_dual.v`
- 期望值不是手写 RTL reference，而是由
  `axi_interconnect/axi_interconnect_dual_port_trace_vectors.cpp` 调用实际
  `AXI_Interconnect` comb/seq 路径生成到 `rtl/include/axi_dual_cpp_trace_vectors.vh`
- 覆盖 MODE_OFF 下 DDR direct 4B 未对齐 read、8B read、64B cacheline 2-beat read、
  4B 未对齐 write、64B cacheline 2-beat write、MMIO direct 4B read/write，以及
  unsupported MMIO 8B read/write
- 覆盖 MODE_OFF 下 DDR/MMIO read 同时在途：MMIO `R` 先返回且上游 read response
  被 stall 时，外部 MMIO/DDR `RREADY` 仍必须按实际 C++ trace 拉高并先缓存 response，
  最终回到各自原 upstream ID/data
- 覆盖 MODE_OFF 下 DDR/MMIO write 同时在途：MMIO `B` 先返回且上游 write response
  被 stall 时，外部 MMIO/DDR `BREADY` 仍必须按实际 C++ trace 拉高并先缓存 response，
  最终回到各自原 upstream ID/code
- 覆盖 MODE_CACHE 下 MMIO 4B read/write：LLC-on 时 MMIO 请求仍按实际 C++
  `AXI_Interconnect` trace 直接走 MMIO AXI 口，`AR/AW/W/R/B` 形状与 response
  ID/data/code 对齐，且不误走 DDR/cacheable LLC core 路径
- 对比 upstream 请求、DDR/MMIO `AR/AW/W/R/B` 形状、DDR 256-bit beat
  payload/strobe、MMIO 32-bit payload/strobe、response ID/data/code，并检查 DDR/MMIO
  trace 不误走对侧 AXI 口；unsupported MMIO trace 还要求 ready=0、不 accepted、不发出
  任一外部 AXI `AR/AW/W`
- 该 bench 是 trace-based 功能 EC；它用于缩小实际 C++/RTL 语义差距，但不替代
  后续 hw-cbmc 同 harness 端到端形式 EC

### `tb_llc_cache_ctrl_cpp_trace_contract.v`

- 直接面向实际 `llc_cache_ctrl.v`
- 期望值由 `axi_interconnect/axi_llc_cache_trace_vectors.cpp` 调用实际 `AXI_LLC`
  comb/seq 路径生成到 `rtl/include/axi_llc_cache_cpp_trace_vectors.vh`
- 当前覆盖 8B line/2-way 小参数下的 partial write hit merge、read miss refill、
  partial write miss refill、dirty victim full-line writeback、dirty victim + partial-write
  miss 和 `invalidate_line` hit：lookup set、data/meta/valid/repl 写回、clean/dirty meta
  更新、lower memory request/response、dirty victim 写回顺序、read/write response
  ID/code、invalidate valid-only clear，以及不误发 bypass request
- dirty victim + partial-write miss 路径按实际 C++/RTL 语义检查：先发 refill read，
  refill 后 merge/install 并返回写响应，同时 dirty victim snapshot 必须外部化并继续发
  full-line writeback；该合同不要求等待 victim `B` 后才回包
- 该 bench 只做必要的接口编码适配：C++ meta/valid/repl 抽象表项映射到 RTL
  `llc_cache_ctrl` row encoding；行为期望仍来自实际 C++ 状态机

### `tb_axi_llc_subsystem_read_master_timing_contract.v`

这个 bench 直接卡顶层多 read master 的时序差异合同：

- `MASTER_DCACHE_R` 必须支持 same-cycle accept
- `MASTER_ICACHE` 仍保持 ready-first，不允许单拍脉冲在未先看到 `ready` 时被 accepted
- 两类 master 的 accepted / accepted_id / AXI `AR` / 上游 response 都必须闭环一致

对应 flist：

- `flist/tb_axi_llc_subsystem_read_master_timing_contract.f`

## 运行方式

推荐从 `rtl/` 目录下使用 `flist/*.f` 驱动仿真器，例如：

```sh
vcs -full64 -f flist/tb_axi_reconfig_ctrl.f -o simv_reconfig
./simv_reconfig
```

或：

```sh
iverilog -f flist/tb_axi_reconfig_ctrl.f -o simv_reconfig
vvp simv_reconfig
```

当前 native dual-AXI 相关 contract 可用统一入口运行：

```sh
./run_dual_axi_contracts.sh
```

该脚本会编译并运行 bridge dual、native dual top MMIO、native dual top outstanding/owner、
以及 hazard scoreboard 四个 contract，并检查 `PASS` 标记；由于 VCS 对 `$finish(1)`
不一定返回非零码，脚本同时会扫描 `FAIL`。

全量 RTL directed / contract tests 可用统一入口运行：

```sh
./run_all_contracts.sh
```

该脚本按 `flist/tb_*.f` 排序编译并运行当前 51 个 testbench，扫描 `FAIL`，并兼容
`<test> PASS` 与旧 bench 的独立 `PASS` marker。2026-05-04 在 `eda-05` 上通过
`bash_eda05 + VCS` 跑通，结果为 51 passed / 0 failed。最新输出目录为
`rtl/local_debug/vcs_all_contracts_20260504_103301`。
