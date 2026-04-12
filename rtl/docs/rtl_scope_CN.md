# RTL 开发范围

## 目标

把当前 C++ 原型中已经稳定下来的 submodule 语义，收敛成可综合 Verilog RTL。

当前优先做 GPT-Pro 审核建议里的高优先级收敛项：

1. `mode=2` direct-mapped local window
2. `drain -> valid-sweep invalidate -> activate`
3. `valid` 独立于 `meta`
4. 顶层把 `cache` 与 `direct-window` 的控制语义拆开
5. 冻结最小 `id` 平面，并补回兼容 C++ 顶层的多 master 兼容层

## 当前包含

- 自包含 `rtl/` 目录
- 可综合 Verilog 源文件
- directed / contract testbench
- filelist
- 与 C++ 原型一致的关键语义文档
- 面向 C++ 顶层接口的兼容层
- 面向当前 C++ submodule 边界的对外 RTL 顶层：
  上游多 master 自定义接口 + 下游单组 AXI4

## 当前不包含

- 与 C++ interconnect 完整等价的多 outstanding / AXI remap 语义
- parent simulator 对接层
- 顶层 CMake/CTest 接入
- 性能优化 / prefetch / debug counter
- 未重新验证的 prefetch 状态机

## 当前完成标准

- mode2 window 的地址翻译、direct set/way 计算正确
- invalid read 返回 0
- invalid partial write 采用 zero-merge，再置 `valid=1`
- 模式切换通过统一 FSM 驱动 valid sweep
- `mode=1` cache path 已具备最小 hit/miss/refill/writeback/dirty flush 语义
- bypass hit/miss/write-through 语义与当前 C++ 原型一致
- `invalidate_all_accepted` 与配置提交同拍可见
- 单流核心已具备最小 `id` 接口，并有独立 contract bench
- 兼容层已补回多 read/write master 的 `accepted/resp` 接口
- 对外 RTL 顶层已补成单组 AXI4 master 接口，不在本层做 DDR/MMIO 二次拆分
