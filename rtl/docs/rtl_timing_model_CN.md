# RTL SRAM Timing 建模

本文档只描述当前 RTL 对 resident SRAM wrapper 的时序建模口径，不涉及架构功能语义。

## 背景

当前标准单元库已经有稳定 `.db`，但 SRAM 宏库还没有完整接入常规综合时序流。
因此，如果要对 `data/meta` 共享存储做 1GHz / 500MHz 级别的早期评估，需要一个在
没有宏 `.db` 时仍然可重复的方法。

## 当前建议

- 保持当前 `parallel lookup`
- 不把架构改成 `meta-first`
- 对 SMIC12 宏做 wrapper 级 timing 评估时：
  - 标准单元继续使用现有 `.db`
  - SRAM 侧按宏边界 `Tcq/ASU` 建模
  - 如果要评估 `2/3-cycle`，采用 deferred first-capture

关键点是：

- 真正紧的路径通常是 `macro_q -> first response register`
- 如果只是把 response 后面再补一拍，并不会改善这条最差路径
- 只有把第一次 capture 本身延后，`2/3-cycle` 才有真实意义

## RTL 结构钩子

当前 resident table store 已经暴露统一参数：

- `TABLE_READ_LATENCY`

口径如下：

- `1`
  - 显式覆盖后的快速功能时序
  - 适合纯功能小规模 bench
- `2`
  - 适合更保守的 SMIC12 wrapper 级 timing 评估
  - 对应“延后 first-capture”而不是“response 后补拍”的设计意图
- `3`
  - 当前默认 SMIC12 wrapper timing 评估值

## 与功能语义的关系

- `TABLE_READ_LATENCY` 只改变 resident table 的读返回时刻
- 不改变 mode0/1/2/3 的架构语义
- cache/direct 仍然只在对应 `rd_valid` 返回时消费数据
- `invalidate_all` / mode switch 的 drain 语义不受这个参数影响

## 当前限制

- 这仍是 wrapper 级 timing model，不是 signoff
- 没有宏 `.db` 时，拿不到真正包含宏内部时序弧的 WNS/TNS
- 当前目标是：
  - 给 RTL 结构一个合理的时序切分方式
  - 给早期频率评估提供可重复口径
