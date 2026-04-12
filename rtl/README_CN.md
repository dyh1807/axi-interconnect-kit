# RTL 子目录（第二阶段进行中）

本目录用于开发与当前 C++ submodule 语义对齐的 **Verilog（不是 SystemVerilog）**
版 AXI/LLC 子模块。

当前阶段优先实现并冻结 GPT-Pro 评审明确建议先落地的语义边界：

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
- `src/llc_data_store.v`
  - `mode=1/2` 共享的 resident data set-row 存储
  - 当前行为模型已按同步单端口读语义实现
- `src/llc_meta_store.v`
  - 预留给 `mode=1` cache 语义使用的 resident meta set-row 存储
  - 当前行为模型已按同步单端口读 + 写侧 busy 语义实现
- `src/llc_valid_ram.v`
  - 独立 valid bit-array
- `src/llc_repl_ram.v`
  - 每 set 一个 next-victim-way 的 replacement 小表
- `src/llc_invalidate_sweep.v`
  - 顺序清 valid 的 sweep 控制器
- `src/llc_cache_ctrl.v`
  - `mode=1` 的 resident lookup / hit / miss / refill / victim writeback / reconfig 前 dirty flush
- `src/llc_mapped_window_ctrl.v`
  - mode=2 地址翻译 / set-way 计算 / 共享 data-store 的 line 选择 / zero-read /
    zero-merge
- `src/axi_llc_subsystem_top.v`
  - 顶层子模块：
    - 集成 reconfig + shared data/meta/valid/repl store
    - `mode=1` 进入内建 `llc_cache_ctrl`
    - `cache_*` 口现在承载 line-memory miss/refill/writeback
    - `mode=0/3` 与 mode2 窗口外通过 `bypass_*` 口下发

## 当前未落地内容

- 与 C++ 子模块边界完全对齐的最终接口
- 多读/多写 master、`id`、`total_size` 等完整字段
- `invalidate_line` 维护接口
- 固定几何的 SMIC12 SRAM wrapper 正式接入
- 真正面向父仓库的最终 wrapper / 系统级 AXI4 接口对接

## 文档

- [rtl_scope_CN.md](docs/rtl_scope_CN.md)
- [rtl_microarch_CN.md](docs/rtl_microarch_CN.md)
- [rtl_verif_plan_CN.md](docs/rtl_verif_plan_CN.md)

## 验证文件

当前提供最小 directed testbench 与 filelist：

- `tb/tb_llc_data_store.v`
- `tb/tb_llc_meta_store.v`
- `tb/tb_llc_valid_ram.v`
- `tb/tb_llc_invalidate_sweep.v`
- `tb/tb_llc_mapped_window_ctrl.v`
- `tb/tb_axi_reconfig_ctrl.v`
- `tb/tb_axi_llc_subsystem_directed.v`
- `tb/tb_axi_llc_subsystem_handshake_contract.v`
- `tb/tb_axi_llc_subsystem_mode_contract.v`
- `tb/tb_axi_llc_subsystem_cache_contract.v`
- `flist/*.f`

## 说明

- 本目录中的 Verilog 均按可综合写法约束组织，不依赖 SystemVerilog 语法。
- RTL 模块中不使用 `initial + $display/$finish` 之类仅用于仿真的写法；静态几何
  约束通过文档和外部验证流程约束。
- `valid` 不再放回 `meta`。
- `mode=1` 与 `mode=2` 共享 `data + valid`；其中 `mode=1` 额外使用 `meta + repl`，
  `mode=2` 只把固定 way-slice 当作 direct-mapped 本地映射窗口使用，不访问 `meta/repl`。
- `data/meta` 当前都采用同步单端口行为模型，因此 `mode=2` 写路径已经改成“先读
  row，再 merge，再写回”的顺序语义。
- `invalidate_all` 不做 whole-array reset，而是通过 `llc_invalidate_sweep` 顺序清
  `valid`。
- 当前已在 `eda-10 + bash_eda10 + VCS` 跑通 store/mode/reconfig/top-level contract bench。
