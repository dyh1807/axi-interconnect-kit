# RTL 微架构说明（第一阶段）

## 总体结构

第一阶段 RTL 采用“控制分离、存储共享”的组织方式：

- `mode=1`
  - 未来进入 `cache` 子路径
  - 使用共享 `data + valid`
  - 额外需要 `meta/repl/MSHR/refill`
- `mode=2`
  - 进入 direct-mapped 本地 window 子路径
  - 使用同一套共享 `data + valid`
  - 不访问 `meta/repl/MSHR`
- `mode=0/3`
  - 全 bypass

本阶段先把 `mode=2 + reconfig/invalidate` 独立落地，`mode=1` 只保留抽象子路径端
口，不在当前阶段实现完整 cache 控制器。

## 模块

### `axi_reconfig_ctrl`

统一模式切换 FSM：

- `RCFG_IDLE`
- `RCFG_DRAIN`
- `RCFG_INV_SWEEP`
- `RCFG_ACTIVATE`

语义：

- `requested != active` 时进入切换
- 切换期间阻止新的上游 accept
- 只有 `global_quiescent=1` 后才启动 invalidate sweep
- 只有 `sweep_done=1` 后才更新 active `mode/offset`

### `llc_valid_ram`

独立 valid 表：

- `valid[set][way]`
- 单读口 + 单写口
- 只支持掩码写
- 不提供 whole-array reset

### `llc_invalidate_sweep`

顺序清 valid：

- 每周期清一个 set 的 valid word
- 不清 `data/meta/repl`
- 与最终硬件语义一致，不做“accepted 即全清”

### `llc_data_store`

共享 resident data store：

- 按 `set-row` 组织
- 一行包含所有 `way` 的 line 数据
- `mode=1` 和 `mode=2` 共用
- 第一阶段先由行为模型实现

### `llc_meta_store`

共享 resident meta store：

- 按 `set-row` 组织
- 当前只为 `mode=1` 预留
- `mode=2` 明确不访问
- 第一阶段先由行为模型实现

### `llc_mapped_window_ctrl`

负责 mode2 direct-window 的纯组合语义：

- `addr - active_offset`
- `line_idx -> set + way`
- 从共享 `data_store` row 中选择 direct line
- invalid read 返回 0
- invalid partial write 以 0 line 做 merge

## 存储边界

### 保留

- `data`
- `valid`

### 暂缓到 cache path 阶段

- `meta`
- `repl`
- `MSHR`

## 参数约束

当前默认几何：

- `8MB LLC`
- `64B line`
- `16 ways`
- `8192 sets`
- `4MB mapped window`
- `8 mapped ways`

本阶段 RTL 依赖以下静态几何约束：

- `WINDOW_BYTES <= LLC_SIZE_BYTES`
- `WINDOW_BYTES` 必须是整 `way-slice`
- `WINDOW_WAYS <= WAY_COUNT`

运行时约束：

- `mode=2` 时 `offset` 必须 line 对齐
- 非对齐 offset 会被 `axi_llc_subsystem_top` 显式拒绝，不会切进新配置

## SRAM 选型约束

按当前外部 SRAM 分析工作区 `qm-rocky/sram` 中的结论：

- `data` 推荐宏：`1024x128 CM4`
- `meta` 推荐宏：`1024x128 CM4`

第一阶段先把共享存储接口定型成：

- `data_store`: `set-row` 读 + `way mask` 写
- `meta_store`: `set-row` 读 + `way mask` 写

后续再把这两类接口绑定到固定几何的 SMIC12 SRAM 宏阵列。

当前已经确认可直接参考的宏模型目录为外部 handoff 工作区中的：

- data 1024x128:
  `profile_wrapper/llc_lookup_latency_codex_handoff/inputs/llc_data/compout/views/sadcls0c4l1p1024x128m4b1w1c0p0d0t0s2sdz1rw00/tt0p8v25c/sadcls0c4l1p1024x128m4b1w1c0p0d0t0s2sdz1rw00.mv`
- meta 1024x128:
  `profile_wrapper/llc_lookup_latency_codex_handoff/inputs/llc_meta/compout/views/sassls0c4l1p1024x128m4b1w0c0p0d0t0s2sdz0rw00__1/tt0p8v25c/sassls0c4l1p1024x128m4b1w0c0p0d0t0s2sdz0rw00__1.mv`
