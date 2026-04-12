# RTL 子目录（第一阶段）

本目录用于开发与当前 C++ submodule 语义对齐的 **Verilog（不是 SystemVerilog）**
版 AXI/LLC 子模块。

当前阶段只实现并冻结 GPT-Pro 评审明确建议先落地的语义边界：

- `mode=1`：正常 LLC cache path
- `mode=2`：direct-mapped 本地 LLC window
- `mode=0/3`：全 bypass
- 模式切换统一走 `block accepts -> drain -> valid-sweep invalidate -> activate`

当前目录是**自包含**的，不接入根 CMake，也不影响现有 C++/CTest 构建。

## 当前已落地内容

- `include/axi_llc_params.vh`
  - 第一阶段默认参数
- `src/axi_reconfig_ctrl.v`
  - 模式切换控制 FSM
- `src/llc_valid_ram.v`
  - 独立 valid bit-array
- `src/llc_invalidate_sweep.v`
  - 顺序清 valid 的 sweep 控制器
- `src/llc_data_ram.v`
  - direct-window 第一阶段使用的 line 数据存储
- `src/llc_mapped_window_ctrl.v`
  - mode=2 地址翻译 / set-way 计算 / zero-read / zero-merge
- `src/axi_llc_subsystem_top.v`
  - 第一阶段顶层 bring-up wrapper：
    - 集成 reconfig + valid/data + mode2 direct path
    - `mode=1` 暂时通过抽象 `cache_*` 子路径端口接出去
    - `mode=0/3` 与 mode2 窗口外通过抽象 `bypass_*` 子路径端口接出去

## 当前未落地内容

- 完整 `mode=1` cache datapath
- `meta/repl/MSHR/refill/victim writeback`
- 真正面向父仓库的最终 wrapper
- 系统级 AXI4 接口对接

## 文档

- [rtl_scope_CN.md](docs/rtl_scope_CN.md)
- [rtl_microarch_CN.md](docs/rtl_microarch_CN.md)
- [rtl_verif_plan_CN.md](docs/rtl_verif_plan_CN.md)

## 验证文件

当前提供最小 directed testbench 与 filelist：

- `tb/tb_llc_valid_ram.v`
- `tb/tb_llc_mapped_window_ctrl.v`
- `tb/tb_axi_reconfig_ctrl.v`
- `tb/tb_axi_llc_subsystem_directed.v`
- `flist/*.f`

## 说明

- 本目录中的 Verilog 均按可综合写法约束组织，不依赖 SystemVerilog 语法。
- `valid` 不再放回 `meta`。
- `invalidate_all` 不做 whole-array reset，而是通过 `llc_invalidate_sweep` 顺序清
  `valid`。
- 当前环境下尚未验证可用的本地 Verilog 仿真工具链，因此 filelist 与 testbench
  先随源一并提供，后续再接入统一仿真命令。
