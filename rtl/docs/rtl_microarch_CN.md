# RTL 微架构说明

## 快速导航

如果你当前的目标是“先找到顶层和 IO，再看细节”，建议按下面顺序阅读：

1. `src/axi_llc_subsystem.v`
   - 当前对外 RTL 顶层
2. `src/axi_llc_subsystem_compat.v`
   - 多 master 兼容层
3. `src/axi_llc_subsystem_core.v`
   - 单流核心
4. `src/axi_llc_axi_bridge.v`
   - AXI 翻译层

如果只需要层次图和文件职责索引，直接看：

- [rtl_hierarchy_CN.md](rtl_hierarchy_CN.md)

## 总体结构

当前 RTL 采用“控制分离、存储共享”的组织方式：

- `mode=1`
  - 进入内建 `llc_cache_ctrl`
  - 使用共享 `data + meta + valid + repl`
  - 通过 `cache_*` 口下发 line-memory read/write
- `mode=2`
  - 进入 direct-mapped 本地 window 子路径
  - 使用同一套共享 `data + valid`
  - 不访问 `meta/repl/MSHR`
- `mode=0/3`
  - 请求仍进入 `llc_cache_ctrl`
  - resident hit 直接返回 / shadow update
  - miss 或 write-through 再走 `bypass_*` 下游端口

当前已把 `mode=2 + reconfig/invalidate + mode=1 最小 cache 控制` 落地。

## 模块

### `axi_reconfig_ctrl`

统一模式切换 FSM：

- `RCFG_IDLE`
- `RCFG_DRAIN`
- `RCFG_INV_SWEEP`
- `RCFG_ACTIVATE`

语义：

- `requested != active` 或外部 `invalidate_all` 时进入维护流程
- 切换期间阻止新的上游 accept
- 只有 `global_quiescent=1` 后才启动 invalidate sweep
- 默认上电 `active_mode=mode1`
- 只有 `sweep_done=1` 后才进入 `RCFG_ACTIVATE`
- `RCFG_ACTIVATE` 当拍同时：
  - 脉冲 `invalidate_all_accepted`
  - 提交新的 active `mode/offset`

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
- 当前模块已经支持两种实现：
  - 默认通用数组实现
  - `USE_SMIC12=1` 且几何为 `8192 sets / 16 ways / 512-bit line` 时，切到
    `1024x128` 宏阵列封装
- 宏阵列映射按 `set[12:10] -> bank`、`set[9:0] -> macro ADR`、`line[511:0] -> 4`
  个 `128-bit` chunk 展开

### `llc_meta_store`

共享 resident meta store：

- 按 `set-row` 组织
- 当前只为 `mode=1` 预留
- `mode=2` 明确不访问
- 当前行为模型采用：
  - 同步单端口读
  - 写侧 `busy` 语义
  - 这对应后续宏阵列实现里按 `way` 做 RMW 的最小合同
- 当前模块已经支持两种实现：
  - 默认通用数组实现
  - `USE_SMIC12=1` 且几何为 `8192 sets / 16 ways` 时，切到 `1024x128` 宏阵列封装
- 当前宏封装为了保持接口简单，按“每个 `way` 独占一个 `128-bit` macro word”的方式
  保存 `24-bit meta`，其余高位保留为 0

### `llc_mapped_window_ctrl`

负责 mode2 direct-window 的纯组合语义：

- `addr - active_offset`
- `addr + total_size` 必须整体落在 window 内
- `line_idx -> set + way`
- 从共享 `data_store` row 中选择 direct line
- invalid read 返回 0
- invalid partial write 以 0 line 做 merge
- 因为 `data_store` 是同步单端口读，mode2 write 现在必须先读 row，再下一阶段写回
- mode2 write merge 当前按请求地址的 line offset 写入 resident line，不再默认从 byte 0 开始覆盖
- direct-window 读响应在顶层再按请求地址的 32-bit word offset 做提取，不直接把 whole line
  原样返回上游

### `llc_cache_ctrl`

当前 `mode=1` 最小 cache 控制器：

- resident lookup 使用 `data/meta/valid/repl`
- 当前请求接口已带 `total_size`
- `req_bypass=1` 时按 C++ bypass 语义处理：
  - read hit 直接返回 resident 数据，不更新 `repl`
  - read miss 只发 lower bypass read，不安装 resident
  - write hit 做 resident shadow update，保留 dirty 位，并继续 lower bypass write-through
  - write miss 只发 lower bypass write，不安装 resident
- read hit 直接返回 resident line
- read miss 发起下游 line read，refill 后安装并返回
- write hit 按 byte mask merge，并置 dirty
- full-line write miss 直接安装 dirty line
- partial write miss 先 refill，再 merge 安装 dirty line
- 上述 merge 当前都按请求地址的 line offset 写入 resident line，不再假定请求从 line 起始字节发起
- victim dirty line 先 writeback，再覆盖安装
- reconfig 期间若存在 dirty resident line，会先顺序 flush 再允许 valid sweep
- `invalidate_line` 已接入：
  - idle 时接受 maintenance 请求
  - 复用一次 resident lookup
  - hit 时只清 valid；若该 line 为 dirty，同时更新 dirty 计数
- `invalidate_all` 通过顶层维护控制面触发，不在 `llc_cache_ctrl` 内单独实现 whole-array
  reset
- read hit / refill response 当前都按请求地址的 32-bit word offset 做提取，对齐 C++
  `extract_line_response()` 的打包语义
- 当前已接入单平面 `id`：
  - 上游 `req_id`
  - 上游 `resp_id`
  - 下游 `mem_req_id / mem_resp_id`
  - bypass lower 请求当前仍复用上游 `req_id`
  - demand miss 触发的 line-memory read 使用内部读事务 id `1`
  - reconfig/flush 产生的维护写回固定使用维护 id `0`

### `axi_llc_subsystem_compat`

`axi_llc_subsystem_compat` 负责把当前单流核心适配成更接近 C++ 顶层的接口：

- 多 read master / 多 write master
- read `ready/accepted/accepted_id`
- write `ready/accepted`
- 独立 write response `id/code`
- 每个 master 单深度请求队列 + 独立 response 槽位

当前限制：

- 该兼容层还不是 C++ interconnect 的完整等价物
- 内部 lower-memory issue 仍由单流核心串行化
- 还没有 C++ 那套 `orig_id / mem_id / axi_id` 三层 remap table

### `axi_llc_axi_bridge`

把内部 lower 抽象请求收敛成单组 AXI4 master 五通道：

- 输入：
  - `cache_req/cache_resp`
  - `bypass_req/bypass_resp`
- 输出：
  - 单组 `AW/W/B/AR/R`
- 当前合同对齐 C++ 原型：
  - `len = ceil((total_size + 1) / beat_bytes) - 1`
  - `size` 固定等于下游 AXI beat 宽度
  - `burst` 固定 `INCR`
  - 写 `data/strb` 按低地址连续切片
  - 读 beat 也按低地址连续拼回 `LINE_BITS` 缓冲

### `axi_llc_subsystem`

当前对外 RTL 子模块顶层：

- 上游：
  - C++ 风格多 `read master / write master` 自定义接口
- 下游：
  - 单组 AXI4 master 接口
- 控制面：
  - `mode_req`
  - `llc_mapped_offset_req`
  - `invalidate_line`
  - `invalidate_all`

这里故意只保留一组 AXI，对齐当前 C++ `AXI_Interconnect` 的边界；
DDR/MMIO 地址分流属于外部系统功能，不在本 RTL 顶层重复展开。

## 存储边界

### 保留

- `data`
- `valid`

### 当前仍未落地

- 与 C++ 原型同等级的多请求并发状态
- 与 C++ 原型完全对齐的更完整 `id` / tag / 多 outstanding 语义
- 带 timing-check 的外部宏模型直连时序隔离
- 重新验证后的 prefetch 控制面与预取状态机

## `id` 合同

当前 RTL 已有一套可运行的最小 `id` 平面，目的是先冻结接口边界并支撑后续独立
contract bench：

- `axi_llc_subsystem_core`
  - `up_req_id / up_resp_id`
  - `cache_req_id / cache_resp_id`
  - `bypass_req_id / bypass_resp_id`
- `mode=2`
  - direct 路径不向外发请求
  - 直接把捕获的 `up_req_id` 原样带回 `up_resp_id`
- `mode=0/3`
  - resident lookup 仍在 `llc_cache_ctrl` 内完成
  - 只有 bypass miss / write-through 才会发 `bypass_req_*`
- `mode=1`
  - hit 响应把当前请求 `req_id` 原样带回上游
  - miss/refill 对下游 line-memory 使用内部读事务 id `1`
  - cache miss 的 victim writeback 使用维护写 id `0`
  - flush 写回同样使用维护 id `0`
  - 上游 `up_resp_id` 仍保持原始请求 `req_id`

这套合同在 `axi_llc_subsystem_core` 内仍是单流简化版；`axi_llc_subsystem_compat`
已经把多 master 的 `accepted/resp` 接口补回；`axi_llc_subsystem` 再把 lower 请求
收敛成单组 AXI4。但它们还没有做到 C++ 的完整多 outstanding / AXI remap 语义。

## `prefetch` 状态

当前 RTL 仍不实现 prefetch。原因不是接口难接，而是原型语义还没有重新冻结：

- C++ 原型中确实存在 prefetch 实现与专门测试：
  - stream prefetch table fill
  - degree-two queue
  - demand mem issue preempts prefetch
- 但这些测试本轮没有在“当前分支 + 当前父仓库依赖”下完成一次干净、可复现的完整重跑
- 因此本轮只补 `id` 与维护控制，不把 prefetch 状态机直接带进 RTL

后续若要继续推进 prefetch，建议先单独完成 C++ 原型重验证，再决定 RTL 只补
`prefetch_allow` 控制面还是直接补完整预取队列/状态机。

## 参数约束

当前默认几何：

- `8MB LLC`
- `64B line`
- `16 ways`
- `8192 sets`
- `4MB mapped window`
- `8 mapped ways`

当前 RTL 依赖以下静态几何约束：

- `WINDOW_BYTES <= LLC_SIZE_BYTES`
- `WINDOW_BYTES` 必须是整 `way-slice`
- `WINDOW_WAYS <= WAY_COUNT`

运行时约束：

- `mode=2` 时 `offset` 必须 line 对齐
- 非对齐 offset 会被 `axi_llc_subsystem_core` 显式拒绝，不会切进新配置

## SRAM 选型约束

按当前外部 SRAM 分析工作区 `qm-rocky/sram` 中的结论：

- `data` 推荐宏：`1024x128 CM4`
- `meta` 推荐宏：`1024x128 CM4`

当前先把共享存储接口定型成：

- `data_store`: 同步 `set-row` 读 + `way mask` 写
- `meta_store`: 同步 `set-row` 读 + `way mask` 写 + 写侧 `busy`

当前已经把这两类接口绑定到固定几何的 SMIC12 SRAM 宏阵列封装，并保留默认通用数组
实现作为日常回归路径。

当前已经确认可直接参考的宏模型目录为外部 handoff 工作区中的：

- data 1024x128:
  `profile_wrapper/llc_lookup_latency_codex_handoff/inputs/llc_data/compout/views/sadcls0c4l1p1024x128m4b1w1c0p0d0t0s2sdz1rw00/tt0p8v25c/sadcls0c4l1p1024x128m4b1w1c0p0d0t0s2sdz1rw00.mv`
- meta 1024x128:
  `profile_wrapper/llc_lookup_latency_codex_handoff/inputs/llc_meta/compout/views/sassls0c4l1p1024x128m4b1w0c0p0d0t0s2sdz0rw00__1/tt0p8v25c/sassls0c4l1p1024x128m4b1w0c0p0d0t0s2sdz0rw00__1.mv`

当前已确认：

- 在默认通用数组实现下，单元 bench 与顶层 contract bench 可直接跑通
- 在 `USE_SMIC12=1` 且显式带入外部 `.mv` 的功能仿真下，shared store 语义可以跑通
- 若直接启用外部宏模型自带 timing check，零延迟 RTL 仍会触发 hold 违例；这一点属于
  当前 RTL 与详细 timing model 之间的接口约束问题，尚未做额外隔离
