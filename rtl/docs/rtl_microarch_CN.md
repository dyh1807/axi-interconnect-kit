# RTL 微架构说明（第一阶段）

## 总体结构

第一阶段 RTL 采用“控制分离、存储共享”的组织方式：

- `mode=1`
  - 未来进入 `cache` 子路径
  - 需要 `meta/repl/MSHR/refill`
- `mode=2`
  - 进入 direct-mapped 本地 window 子路径
  - 只访问 `data + valid`
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

### `llc_data_ram`

第一阶段给 `mode=2` direct-window 使用的 line 存储：

- `data[set][way]`
- 单读口 + 单写口
- 无阵列 reset

### `llc_mapped_window_ctrl`

负责 mode2 direct-window 的纯组合语义：

- `addr - active_offset`
- `line_idx -> set + way`
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

本阶段 RTL 内已经把以下约束显式做成参数检查：

- `WINDOW_BYTES <= LLC_SIZE_BYTES`
- `WINDOW_BYTES` 必须是整 `way-slice`
- `WINDOW_WAYS <= WAY_COUNT`

运行时约束：

- `mode=2` 时 `offset` 必须 line 对齐
- 非对齐 offset 会被 `axi_llc_subsystem_top` 显式拒绝，不会切进新配置
