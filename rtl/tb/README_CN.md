# RTL Testbench 说明

本目录存放当前 RTL 的 directed / contract testbench。

当前目标不是跑完整系统，而是先把已经落地的语义边界独立验证：

- 同步 `data/meta` store 合同
- `valid` 表掩码更新
- `invalidate_sweep`
- mode2 direct-window 地址翻译与 zero-merge
- reconfiguration FSM
- 顶层 mode 路由、mode2 可见性、mode 切换失效

## 当前提供

- `tb_llc_data_store.v`
- `tb_llc_meta_store.v`
- `tb_llc_valid_ram.v`
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

目标是独立卡住新 wrapper `axi_llc_subsystem_compat.v` 的接口合同：

- read / write `accepted` 为单拍脉冲
- read `accepted_id` 回显被接受请求的 `id`
- 不同 read / write master 的请求可以先排队，再分别回到各自 response 槽
- write response code 当前固定为 `OKAY`
- wrapper 不破坏已有 lower 接口区分：
  - `mode=1` cache miss 仍走 `cache_req`
  - `mode=1` bypass 仍走 `bypass_req`
  - `mode=2` direct-window 访问不触发 lower 请求

这个 bench 只验证 wrapper 合同，不要求知道 `mode=1` cache 路径内部怎样实现 `mem_id`；
对于 cache lower response，它只回传观测到的 `cache_req_id`。

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
