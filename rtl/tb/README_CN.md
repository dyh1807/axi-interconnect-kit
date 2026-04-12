# RTL Testbench 说明

本目录存放第一阶段 RTL 的最小 directed testbench。

当前目标不是跑完整系统，而是把 GPT-Pro 评审要求优先冻结的语义先独立验证：

- `valid` 表掩码更新
- mode2 direct-window 地址翻译与 zero-merge
- reconfiguration FSM
- 顶层第一阶段 wrapper 的路由与 invalidate 行为

## 当前提供

- `tb_llc_valid_ram.v`
- `tb_llc_mapped_window_ctrl.v`
- `tb_axi_reconfig_ctrl.v`
- `tb_axi_llc_subsystem_directed.v`

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

当前工作机上的 HDL 工具链可用性尚未确认完成，因此这些 testbench 先作为源码与
filelist 一并进入仓库。
