# RTL 验证计划

## 目标

当前验证优先覆盖已经落地的共享存储、mode 控制、mode2 直映窗口，以及 mode1 最小 cache 语义。
当前也覆盖“上游自定义接口 -> 单组 AXI4”的打包合同。

## P0 单元级

### `tb_llc_data_store.v`

- 同步 set-row 读
- 默认 `TABLE_READ_LATENCY=1` 的 `rd_en -> rd_valid` 时序
- 按 way mask 写
- 不同 way 更新互不破坏

### `tb_llc_meta_store.v`

- meta row 的按 way mask 写
- 写阶段 `busy`
- 读回一致

### `tb_llc_valid_ram.v`

- 掩码写
- 同一 set 多次更新
- 未更新位保持
- 通过显式写零替代整表 reset 假设

### `tb_llc_repl_ram.v`

- 默认 `TABLE_READ_LATENCY=1` 的 `rd_en -> rd_valid` 时序
- 写后读回一致

### `tb_llc_invalidate_sweep.v`

- `start -> busy -> done`
- 逐 set 顺序扫描
- `valid_wr_mask` 恒全 1
- `valid_wr_bits` 恒全 0
- busy 期间重复 `start` 被忽略

### `tb_llc_mapped_window_ctrl.v`

- window 内地址翻译
- `addr + total_size` 整体判窗
- direct set/way 计算
- invalid read 返回 0
- valid read 返回 resident line
- invalid partial write 走 zero-merge
- out-of-window 判定

### `tb_axi_reconfig_ctrl.v`

- `requested != active` 进入 `DRAIN`
- `global_quiescent` 后进入 `INV_SWEEP`
- `sweep_done` 后 `ACTIVATE`
- DRAIN 期间 target 收敛到最后一次请求值

## P1 子模块级 directed

### `tb_axi_llc_subsystem_directed.v`

覆盖：

- `mode=2` direct write/read
- `mode=2` 顺序读改写后再响应
- `mode=2` invalid read=0
- `mode=0` bypass 路由
- `mode=1` cache 路由
- `mode=2 -> mode=0 -> mode=2` 后旧 valid 被 sweep 清除

### `tb_axi_llc_subsystem_mode_contract.v`

覆盖：

- `mode=0/1/2/3` 基本路由合同
- `mode=2` invalid read 返回 0
- `mode=2` write/read 回读
- 切换后旧 mapped valid 不可见

### `tb_axi_llc_subsystem_handshake_contract.v`

覆盖：

- `up_req_ready` 回压
- `up_resp_ready=0` 时响应保持
- bypass 下游 `ready` 延迟
- cache 下游 `ready` 延迟
- `mode=1 + up_req_bypass=1`
- 读写属性透传
- 现有 simple responder 对 `id` 端口做透传，不因新增 `id` 接口破坏原合同

### `tb_axi_llc_subsystem_cache_contract.v`

覆盖：

- `mode=1` read miss -> refill -> respond
- 同地址第二次 read hit 不再发外部 `cache_req`
- write hit 更新 resident data
- full-line write miss 直接安装 dirty line
- partial write miss 先 refill 再 merge
- dirty victim writeback + refill
- simple memory model 回传 `cache_req_id`，避免新增 `id` 接口破坏 mode1 主路径

### `tb_axi_llc_subsystem_invalidate_line_contract.v`

覆盖：

- `mode=1` invalidate_line 后同地址重新 miss
- `mode=2` invalidate_line 为 no-op，同地址 direct-window resident data 保持可见
- LLC_OFF / window 外 no-op accept

### `tb_axi_llc_subsystem_size_contract.v`

覆盖：

- mode2 只有整体落窗才 direct
- 跨窗请求走 bypass
- `bypass_req_size` 透传
- `cache_req_size` 对 cache miss 为 line_bytes-1
- simple responder 回传 `cache_req_id / bypass_req_id`

### `tb_axi_llc_subsystem_read_slice_contract.v`

覆盖：

- `mode=1` read miss 的 refill 响应按地址 word offset 切片
- `mode=1` 同地址 read hit 继续按同一 word offset 切片
- `mode=1` unaligned write hit 在 line offset 处 merge，再按同一 word offset 回读
- `mode=2` direct-window resident read 按地址 word offset 切片
- `mode=2` unaligned partial write 在 line offset 处 merge，再按同一 word offset 回读
- 上述场景不允许退化成“无条件回整条 line”

### `tb_axi_llc_subsystem_bypass_contract.v`

覆盖：

- `mode=1 + up_req_bypass=1` 的 bypass read hit 不触发 lower bypass read，直接返回 resident 数据
- bypass read miss 只触发 lower bypass read，且不安装 resident
- bypass write hit 更新 resident shadow line、保持 clean、同时发 lower bypass write
- bypass write miss 只发 lower bypass write，不安装 resident

说明：

- 该 bench 使用 generic store 的层次化预装载来制造 resident 命中场景，因此只用于 `USE_SMIC12_STORES=0` 的合同验证。
- 这是对 bypass 合同的独立验证；如果 bypass 请求仍然被硬送到 lower bypass，或者 bypass write hit 不能完成 write-through 回包，该 bench 会直接报错。

### `tb_axi_llc_subsystem_compat_contract.v`

覆盖：

- 兼容层的 read / write `accepted` 单拍脉冲
- read `accepted_id` 与被接受请求 `id` 一致
- 不同 read / write master 可先入队，再按各自 slot 收到 response
- bypass write 的 `write response code` 透传 lower response
- 非 bypass write 当前返回 `OKAY`
- 兼容层不破坏既有 lower 路由合同：
  - `mode=1` cache miss 走 `cache_req`
  - `mode=1` bypass 走 `bypass_req`
  - `mode=2` direct-window 不触发 lower 请求

说明：

- 该 bench 只验证兼容层暴露给上层的多 master 队列与 response 槽合同，不改 `src/`。
- 对 cache lower response，只要求把观测到的 `cache_req_id` 原样回传，不额外约束 cache 内部 `mem_id` 编码。

### `tb_axi_llc_subsystem_compat_read_queue_contract.v`

覆盖：

- `axi_llc_subsystem_compat` 的 read queue 支持同一 master 多请求排队
- 每次 read 入队都产生单拍 `accepted`
- 每次 read 入队的 `accepted_id` 与入队 `req_id` 一致
- 同一 master 的重复 `req_id` 在未完成前被 `ready/accept` 拒绝
- 不同 read master 可各自排队，且后续都能回到各自 response 槽

说明：

- 该 bench 固定在 `mode=0` 的 bypass read 环境下，只验证 compat 层的 read queue 合同。
- 场景中显式覆盖 `master0` 上两笔不同 `req_id` 的连续入队。
- 该 bench 不约束 queued read 的全局调度顺序，只要求每个已接受请求最终都能被正确下发并回到正确 master。

### `tb_axi_llc_subsystem_compat_reconfig_drain_contract.v`

覆盖：

- compat 层在 mode change / `invalidate_all` 时先排空本地 queue / inflight / response slot
- drain 期间旧模式下已经入队的请求仍按旧模式继续下发
- `invalidate_all_accepted` 只能在 compat 本地排空后出现

### `tb_axi_llc_subsystem_compat_invalidate_line_hazard_contract.v`

覆盖：

- `invalidate_line` 在 same-line write inflight 期间不能被 accepted
- `invalidate_line` 在 same-line write 仍停留于 compat queue / response slot 期间不能被 accepted
- 所有 same-line write hazard 清空后，`invalidate_line` 才允许被 accepted

### `tb_axi_llc_subsystem_read_master_timing_contract.v`

覆盖：

- `MASTER_DCACHE_R` 保留 same-cycle accept
- `MASTER_ICACHE` 仍保持 ready-first
- 上游 `accepted / accepted_id`、下游 AXI `AR`、以及最终 read response 的闭环一致性

### `tb_axi_llc_subsystem_axi_cache_refill_contract.v`

覆盖：

- 对外顶层 `axi_llc_subsystem.v` 的 `mode=1` cache refill 只使用单组 AXI4 读通道
- 64B refill 对应 `AR len=1 / size=5 / burst=INCR`
- 两个 32B `R` beat 组回 1 个 64B line
- cache refill 期间不得误触发 `AW/W/B`

### `tb_axi_llc_subsystem_axi_bypass_read_contract.v`

覆盖：

- bypass 4B read 在对外顶层只发 single-beat `AR`
- `arlen=0 / arsize=5 / arburst=INCR`
- 只消费 1 个 `R` beat
- 上游 `read_resp_id` 保持原始事务 `id`
- `RDATA` 仍按单个 32B beat 返回，使用方只消费低几个字节

### `tb_axi_llc_subsystem_axi_bypass_write_contract.v`

覆盖：

- bypass 4B write 必须经过单组 AXI 的 `AW/W/B`
- `awlen=0 / awsize=5 / awburst=INCR`
- `W` 数据与 `WSTRB` 采用低地址连续打包，不再按地址低位二次移位
- `B` 回来后生成 write response

### `tb_axi_llc_subsystem_invalidate_all_contract.v`

覆盖：

- mode1 下 dirty line 存在时外部 `invalidate_all` 不会被接受，也不会主动 flush
- mode1 下 clean resident 状态时，`invalidate_all` 经过 drain 后触发 valid sweep
- mode1 invalidate 后同地址重新 miss
- mode2 下外部 `invalidate_all` 后 direct-window resident data 不再可见
- mode 切换与 `invalidate_all` 同时出现时只做一轮维护流程
- clean reread 过程继续通过 `id` 接口回传响应

### `tb_axi_llc_subsystem_id_contract.v`

覆盖：

- cache / direct / bypass 三条路径的 request id 下传与 response id 回传
- invalidate_all 期间不误接收新 id
- mode1 lower-memory request id 的基本合同
  当前 cache miss 验证的是内部 line-memory mem-id，不要求等于上游 `up_req_id`

### `tb_llc_smic12_store_contract.v`

覆盖：

- `USE_SMIC12=1` 下 data/meta shared store 的读写往返
- 默认通用数组实现与 SMIC12 宏封装实现的接口合同一致
- 显式带入外部 `.mv` 的功能仿真 smoke

## 当前限制

- 当前 bench 仍以 directed contract 为主，更大规模的 randomized / long-run backpressure 还没有接入。
- lower AXI 多 outstanding / remap 已经有独立 bridge-local contract bench；当前验证重点转到：
  - bridge 的 `req_id -> axi_id -> req_id` 回路由
  - write `axi_id` 在 `B` 后即可复用
  - top/compat 侧旧合同在新 bridge 下不回归
- 当前已在 `eda-10` 上确认 VCS 可用，并实际跑通：
  - `tb_llc_data_store`
  - `tb_llc_meta_store`
  - `tb_llc_valid_ram`
  - `tb_llc_repl_ram`
  - `tb_llc_invalidate_sweep`
  - `tb_llc_mapped_window_ctrl`
  - `tb_axi_reconfig_ctrl`
  - `tb_axi_llc_axi_bridge_read_outstanding_contract`
  - `tb_axi_llc_axi_bridge_write_outstanding_contract`
  - `tb_axi_llc_axi_bridge_write_id_reuse_contract`
  - `tb_axi_llc_subsystem_directed`
  - `tb_axi_llc_subsystem_handshake_contract`
  - `tb_axi_llc_subsystem_mode_contract`
  - `tb_axi_llc_subsystem_cache_contract`
  - `tb_axi_llc_subsystem_invalidate_line_contract`
  - `tb_axi_llc_subsystem_size_contract`
  - `tb_axi_llc_subsystem_invalidate_all_contract`
  - `tb_axi_llc_subsystem_id_contract`
  - `tb_axi_llc_subsystem_axi_cache_refill_contract`
  - `tb_axi_llc_subsystem_axi_bypass_read_contract`
  - `tb_axi_llc_subsystem_axi_bypass_write_contract`
  - `tb_axi_llc_subsystem_compat_contract`
  - `tb_axi_llc_subsystem_compat_read_queue_contract`
  - `tb_axi_llc_subsystem_compat_reconfig_drain_contract`
  - `tb_axi_llc_subsystem_compat_invalidate_line_hazard_contract`
  - `tb_axi_llc_subsystem_read_master_timing_contract`
  - `tb_axi_llc_subsystem_compat_reconfig_drain_contract`
  - `tb_axi_llc_subsystem_compat_invalidate_line_hazard_contract`
  - `tb_axi_llc_subsystem_read_master_timing_contract`
  - `tb_llc_smic12_store_contract`
