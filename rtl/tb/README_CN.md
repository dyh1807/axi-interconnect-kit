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
- `tb_axi_llc_subsystem_size_contract.v`
- `tb_axi_llc_subsystem_invalidate_all_contract.v`
- `tb_axi_llc_subsystem_read_slice_contract.v`
- `tb_axi_llc_subsystem_bypass_contract.v`
- `tb_axi_llc_subsystem_compat_contract.v`
- `tb_axi_llc_subsystem_compat_read_queue_contract.v`
- `tb_axi_llc_subsystem_axi_cache_refill_contract.v`
- `tb_axi_llc_subsystem_axi_bypass_read_contract.v`
- `tb_axi_llc_subsystem_axi_bypass_write_contract.v`
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

### `tb_axi_llc_subsystem_compat_contract.v`

目标是独立卡住兼容层 `axi_llc_subsystem_compat.v` 的接口合同：

- read / write `accepted` 为单拍脉冲
- read `accepted_id` 回显被接受请求的 `id`
- 不同 read / write master 的请求可以先排队，再分别回到各自 response 槽
- bypass write 的 `write response code` 会透传 lower response
- 非 bypass write 当前仍返回 `OKAY`
- 兼容层不破坏已有 lower 接口区分：
  - `mode=1` cache miss 仍走 `cache_req`
  - `mode=1` bypass 仍走 `bypass_req`
  - `mode=2` direct-window 访问不触发 lower 请求

这个 bench 只验证兼容层合同，不要求知道 `mode=1` cache 路径内部怎样实现 `mem_id`；
对于 cache lower response，它只回传观测到的 `cache_req_id`。

### `tb_axi_llc_subsystem_compat_read_queue_contract.v`

目标是把 `axi_llc_subsystem_compat.v` 当前的 read queue 合同单独钉住，不和 cache/mode2 其它行为混在一起：

- 每个 read master 可在已有未完成 read 存在时继续排队多个请求
- 每次成功入队都必须产生单拍 `read_req_accepted`
- 每次成功入队都必须给出匹配的 `read_req_accepted_id`
- 同一 master 上，相同 `req_id` 的 read 在前一笔未完成前必须被 `ready/accept` 拒绝
- 不同 read master 可以各自建立独立的排队深度

这个 bench 采用 `mode=0` 的 bypass read 环境来隔离 compat 层合同，并显式覆盖：

- `master0` 上 `id=2` / `id=3` 两笔不同 read 的连续入队
- `master0` 上对未完成 `id=1` 的重复入队拒绝
- `master0` 与 `master1` 在同一轮 inflight read 未完成时各自继续入队

对应 flist：

- `flist/tb_axi_llc_subsystem_compat_read_queue_contract.f`

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
