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
  - 模式切换 + `invalidate_all` 维护控制 FSM
  - 默认上电 `active_mode=mode1`
- `src/llc_data_store.v`
  - `mode=1/2` 共享的 resident data set-row 存储
  - 当前已支持两种实现：
    - 默认通用数组实现
    - `USE_SMIC12_STORES=1` 时的 SMIC12 宏封装实现
- `src/llc_meta_store.v`
  - 预留给 `mode=1` cache 语义使用的 resident meta set-row 存储
  - 当前已支持两种实现：
    - 默认通用数组实现
    - `USE_SMIC12_STORES=1` 时的 SMIC12 宏封装实现
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
    - 当前已接入 `up_req_total_size`、`cache_req_size`、`bypass_req_size`
    - 当前已接入单平面 `id`：
      - `up_req_id / up_resp_id`
      - `cache_req_id / cache_resp_id`
      - `bypass_req_id / bypass_resp_id`
    - 当前已接入 `invalidate_line` / `invalidate_line_accepted`
    - 当前已接入 `invalidate_all_valid` / `invalidate_all_accepted`
    - `invalidate_all_accepted` 当前表示一次维护 sweep 已完成，并与配置提交同拍对外可见

## 当前未落地内容

- 与 C++ 子模块边界完全对齐的最终接口
- 多读/多写 master、与 C++ 一致的更完整 `id` / tag 平面
- 真正面向父仓库的最终 wrapper / 系统级 AXI4 接口对接
- 带 timing-check 的外部宏模型直连时序隔离
- 重新验证后的 prefetch 控制面与预取状态机

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
- `tb/tb_axi_llc_subsystem_invalidate_line_contract.v`
- `tb/tb_axi_llc_subsystem_size_contract.v`
- `tb/tb_axi_llc_subsystem_invalidate_all_contract.v`
- `tb/tb_axi_llc_subsystem_id_contract.v`
- `tb/tb_llc_smic12_store_contract.v`
- `flist/*.f`

## 说明

- 本目录中的 Verilog 均按可综合写法约束组织，不依赖 SystemVerilog 语法。
- RTL 模块中不使用 `initial + $display/$finish` 之类仅用于仿真的写法；静态几何
  约束通过文档和外部验证流程约束。
- `valid` 不再放回 `meta`。
- `mode=1` 与 `mode=2` 共享 `data + valid`；其中 `mode=1` 额外使用 `meta + repl`，
  `mode=2` 只把固定 way-slice 当作 direct-mapped 本地映射窗口使用，不访问 `meta/repl`。
- `active_offset` 只在目标模式为 `mode=2` 时参与重配置；`mode=0/1/3` 下单独改变
  offset 不会触发无意义的 sweep。
- 顶层默认上电模式是 `mode=1`；bench 如果需要从其它模式起步，会显式覆盖 `RESET_MODE`。
- 请求接口当前已经带 `total_size`，并参与 mode2 整体判窗与下游 `*_size` 发射。
- `data/meta` 当前都采用同步单端口行为模型，因此 `mode=2` 写路径已经改成“先读
  row，再 merge，再写回”的顺序语义。
- `invalidate_all` 当前已经接入顶层，不做 whole-array reset，而是通过
  `llc_invalidate_sweep` 顺序清 `valid`。
- `invalidate_all_accepted` 不再表示“请求已被 FSM 吸收”，而表示“本次维护 sweep 已完成；
  active 配置在同一拍提交”。
- `invalidate_line` 当前已经接入：
  - `mode=1` 通过 `llc_cache_ctrl` 查表并清对应 valid
  - `mode=0/2/3` 接受为 no-op，不改变 direct-window resident data
- 当前 `id` 采用单个 `4-bit` 平面：
  - 直接路径返回捕获的 `up_req_id`
  - bypass 路径向下传 `bypass_req_id`，响应需带回匹配 id
  - cache 路径向下传 `cache_req_id`
  - `mode=1` demand miss 触发的 writeback/refill 继承当前请求 id
  - reconfig/flush 产生的维护写回固定使用维护 id `0`
- 共享 `data/meta` 当前支持 `USE_SMIC12_STORES=1` 的宏封装实现；在真实外部宏模型
  上做功能仿真时，当前建议关闭 timing check（例如 `+notimingcheck`），因为零延迟
  RTL 直接连接详细 timing model 还会触发 hold 违例。
- prefetch 当前仍未进入 RTL：
  - C++ 原型里已有专门的 prefetch 单测与实现
  - 但本轮没有在当前分支上完成一次干净、可复现的端到端重验证
  - 因此 RTL 暂不引入 `prefetch` 状态机，只保留后续重新评估的空间
- 当前已在 `eda-10 + bash_eda10 + VCS` 跑通 store/mode/reconfig/top-level contract bench。
