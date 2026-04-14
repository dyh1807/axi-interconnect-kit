# RTL Testbench 说明

本目录存放当前 RTL 的 directed / contract testbench。

当前目标不是跑完整系统，而是先把已经落地的语义边界独立验证：

- 同步 `data/meta/valid/repl` store 合同
- `invalidate_sweep`
- mode2 direct-window 地址翻译与 zero-merge
- reconfiguration FSM
- 顶层 mode 路由、mode2 可见性、mode 切换失效
- 对外顶层到单组 AXI4 的请求打包合同

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
- `tb_axi_llc_subsystem_compat_reconfig_drain_contract.v`
- `tb_axi_llc_subsystem_compat_invalidate_line_hazard_contract.v`
- `tb_axi_llc_subsystem_compat_write_victim_multiflow_contract.v`
- `tb_axi_llc_subsystem_compat_victim_line_hazard_contract.v`
- `tb_axi_llc_subsystem_compat_victim_snapshot_refresh_contract.v`
- `tb_axi_llc_subsystem_axi_cache_refill_contract.v`
- `tb_axi_llc_subsystem_axi_bypass_read_contract.v`
- `tb_axi_llc_subsystem_axi_bypass_write_contract.v`
- `tb_axi_llc_subsystem_axi_mode1_multiflow_contract.v`
- `tb_axi_llc_subsystem_axi_cache_multiread_contract.v`
- `tb_axi_llc_subsystem_axi_same_master_multiread_contract.v`
- `tb_axi_llc_subsystem_compat_direct_bypass_contract.v`
- `tb_axi_llc_subsystem_compat_same_line_hol_contract.v`
- `tb_axi_llc_axi_bridge_read_outstanding_contract.v`
- `tb_axi_llc_axi_bridge_write_outstanding_contract.v`
- `tb_axi_llc_axi_bridge_write_id_reuse_contract.v`
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

### `tb_axi_llc_subsystem_axi_mode1_multiflow_contract.v`

目标是钉住当前 `mode=1` 的非单流合同：

- 一个 cache miss read 已经在 AXI lower 侧 outstanding 时
- 另一个 read master 的 bypass read 仍然可以继续下发第二笔 AXI AR
- bypass read 的上游 response 可以先于 cache miss refill 返回
- reset 后的独立场景中
- 一个 cache miss read outstanding 时，另一个 write master 的 bypass write 仍然可以继续下发 AXI AW/W/B
- bypass write 的上游 response 可以先于 cache miss refill 返回

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

### `tb_axi_llc_subsystem_compat_same_line_hol_contract.v`

覆盖：

- 某个 queue 头部的 same-line blocked cacheable request 不会被 compat 提前弹出
- 其它 master 上不相关 line 的 cacheable miss 仍可继续进入 core / lower
- same-line hazard 消失后，原先被挡住的请求仍会继续推进并正常回包

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

- 同 line write 仍处于 inflight 时，`invalidate_line` 不能被 accepted
- 同 line write 已在 compat queue 中排队、但尚未 drain 时，`invalidate_line` 仍不能被 accepted
- 所有 same-line write hazard 清空后，`invalidate_line` 才允许重新 accepted

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

### `tb_axi_llc_axi_bridge_write_id_reuse_contract.v`

- 直接面向 `axi_llc_axi_bridge.v`
- 覆盖“`B` 已返回但 source response 仍 backpressure”场景
- 合同要求：
  - 已完成 write 的 AXI `id` 可以被下一笔 write 立即重用
  - 第 1 笔 source response 尚未消费时，第 2 笔仍可继续进入 lower AXI

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

目前已在 `eda-10` 上通过 `bash_eda10 + VCS` 跑通当前这些 testbench。
