# RTL 微架构说明（第二阶段进行中）

## 总体结构

第一阶段 RTL 采用“控制分离、存储共享”的组织方式：

- `mode=1`
  - 进入内建 `llc_cache_ctrl`
  - 使用共享 `data + meta + valid + repl`
  - 通过 `cache_*` 口下发 line-memory read/write
- `mode=2`
  - 进入 direct-mapped 本地 window 子路径
  - 使用同一套共享 `data + valid`
  - 不访问 `meta/repl/MSHR`
- `mode=0/3`
  - 全 bypass

本阶段已经把 `mode=2 + reconfig/invalidate + mode=1 最小 cache 控制` 落地。

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
- reset 后清零

### `llc_repl_ram`

独立 replacement 表：

- `repl[set] = next victim way`
- 组合读 + 同步写
- 当前采用 round-robin next-way 语义

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
- 当前行为模型采用**同步单端口读**：
  - `rd_en` 当拍发起
  - 下一拍 `rd_valid` 返回 `rd_row`
  - `wr_en` 同步按 `way mask` 更新
- 这一步是为后续绑定 `1024x128 CM4` 宏阵列做接口对齐

### `llc_meta_store`

共享 resident meta store：

- 按 `set-row` 组织
- 当前只为 `mode=1` 预留
- `mode=2` 明确不访问
- 当前行为模型采用：
  - 同步单端口读
  - 写侧 `busy` 语义
  - 这对应后续宏阵列实现里按 `way` 做 RMW 的最小合同

### `llc_mapped_window_ctrl`

负责 mode2 direct-window 的纯组合语义：

- `addr - active_offset`
- `line_idx -> set + way`
- 从共享 `data_store` row 中选择 direct line
- invalid read 返回 0
- invalid partial write 以 0 line 做 merge
- 因为 `data_store` 是同步单端口读，mode2 write 现在必须先读 row，再下一阶段写回

### `llc_cache_ctrl`

当前 `mode=1` 最小 cache 控制器：

- resident lookup 使用 `data/meta/valid/repl`
- read hit 直接返回 resident line
- read miss 发起下游 line read，refill 后安装并返回
- write hit 按 byte mask merge，并置 dirty
- full-line write miss 直接安装 dirty line
- partial write miss 先 refill，再 merge 安装 dirty line
- victim dirty line 先 writeback，再覆盖安装
- reconfig 期间若存在 dirty resident line，会先顺序 flush 再允许 valid sweep

## 存储边界

### 保留

- `data`
- `valid`

### 当前仍未落地

- 与 C++ 原型同等级的多请求并发状态
- `invalidate_line`
- `id/total_size` 与更完整的上游/下游接口
- 固定几何 SRAM wrapper

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

当前先把共享存储接口定型成：

- `data_store`: 同步 `set-row` 读 + `way mask` 写
- `meta_store`: 同步 `set-row` 读 + `way mask` 写 + 写侧 `busy`

后续再把这两类接口绑定到固定几何的 SMIC12 SRAM 宏阵列。

当前已经确认可直接参考的宏模型目录为外部 handoff 工作区中的：

- data 1024x128:
  `profile_wrapper/llc_lookup_latency_codex_handoff/inputs/llc_data/compout/views/sadcls0c4l1p1024x128m4b1w1c0p0d0t0s2sdz1rw00/tt0p8v25c/sadcls0c4l1p1024x128m4b1w1c0p0d0t0s2sdz1rw00.mv`
- meta 1024x128:
  `profile_wrapper/llc_lookup_latency_codex_handoff/inputs/llc_meta/compout/views/sassls0c4l1p1024x128m4b1w0c0p0d0t0s2sdz0rw00__1/tt0p8v25c/sassls0c4l1p1024x128m4b1w0c0p0d0t0s2sdz0rw00__1.mv`
