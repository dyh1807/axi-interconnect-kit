# RTL 开发范围（阶段性收敛）

## 目标

把当前 C++ 原型中已经稳定下来的 submodule 语义，收敛成可综合 Verilog 的第二阶
段 RTL。

当前阶段优先做 GPT-Pro 审核建议里的高优先级收敛项：

1. `mode=2` direct-mapped local window
2. `drain -> valid-sweep invalidate -> activate`
3. `valid` 独立于 `meta`
4. 顶层把 `cache` 与 `direct-window` 的控制语义拆开
5. 冻结最小 `id` 平面，为后续独立验证留出稳定接口

## 本阶段包含

- 自包含 `rtl/` 目录
- 可综合 Verilog 源文件
- 最小 directed testbench
- filelist
- 与 C++ 原型一致的关键语义文档

## 本阶段不包含

- 与 C++ 子模块边界完全对齐的最终接口
- 多读/多写 master，以及与 C++ 一致的更完整 `id` / tag / 多 outstanding 语义
- parent simulator wrapper
- 顶层 CMake/CTest 接入
- 性能优化 / prefetch / debug counter
- 未重新验证的 prefetch 状态机

## 当前阶段完成标准

- mode2 window 的地址翻译、direct set/way 计算正确
- invalid read 返回 0
- invalid partial write 采用 zero-merge，再置 `valid=1`
- 模式切换通过统一 FSM 驱动 valid sweep
- `mode=1` cache path 已具备最小 hit/miss/refill/writeback/dirty flush 语义
- `invalidate_all_accepted` 与配置提交同拍可见
- 顶层与 mode1 lower-memory 路径已具备最小 `id` 接口，并有独立 contract bench
