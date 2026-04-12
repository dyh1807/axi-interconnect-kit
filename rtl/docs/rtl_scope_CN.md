# RTL 开发范围（第一阶段）

## 目标

把当前 C++ 原型中已经稳定下来的 submodule 语义，收敛成可综合 Verilog 的第一阶
段 RTL 骨架。

本阶段只做 GPT-Pro 审核建议里的优先级最高部分：

1. `mode=2` direct-mapped local window
2. `drain -> valid-sweep invalidate -> activate`
3. `valid` 独立于 `meta`
4. 顶层把 `cache` 与 `direct-window` 的控制语义拆开

## 本阶段包含

- 自包含 `rtl/` 目录
- 可综合 Verilog 源文件
- 最小 directed testbench
- filelist
- 与 C++ 原型一致的关键语义文档

## 本阶段不包含

- 完整 cache path RTL
- MSHR / refill / victim writeback
- parent simulator wrapper
- 顶层 CMake/CTest 接入
- 性能优化 / prefetch / debug counter

## 第一阶段完成标准

- mode2 window 的地址翻译、direct set/way 计算正确
- invalid read 返回 0
- invalid partial write 采用 zero-merge，再置 `valid=1`
- 模式切换通过统一 FSM 驱动 valid sweep
- `mode=1` 不再和 `mode=2` 控制逻辑混在一个大状态机里
