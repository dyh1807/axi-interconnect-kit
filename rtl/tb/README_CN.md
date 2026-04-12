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
- `tb_llc_smic12_store_contract.v`

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
