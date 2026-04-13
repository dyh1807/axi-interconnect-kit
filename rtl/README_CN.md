# RTL 子目录

本目录用于开发与当前 C++ submodule 语义对齐的 **Verilog（不是 SystemVerilog）**
版 AXI/LLC 子模块。

## 快速定位

如果你只想先找到顶层、IO 和层次，先看下面 4 个文件：

- `src/axi_llc_subsystem.v`
  - 当前对外 RTL 顶层
  - 上游是 C++ 风格多 `read_masters[] / write_masters[]`
  - 下游是一组 AXI4 `AW/W/B/AR/R`
- `src/axi_llc_subsystem_compat.v`
  - 兼容层
  - 把多 master 请求收敛成单流核心接口
- `src/axi_llc_subsystem_core.v`
  - 单流核心
  - 负责 mode 路由、reconfig、shared store、mode1 cache、mode2 mapped-window
- `src/axi_llc_axi_bridge.v`
  - AXI 翻译层
  - 把内部 lower request/response 转成单组 AXI4 master 五通道

建议阅读顺序：

1. `src/axi_llc_subsystem.v`
2. `src/axi_llc_subsystem_compat.v`
3. `src/axi_llc_subsystem_core.v`
4. `src/axi_llc_axi_bridge.v`

## 层次关系

当前主层次如下：

```text
axi_llc_subsystem
|-- axi_llc_subsystem_compat
|   `-- axi_llc_subsystem_core
|       |-- axi_reconfig_ctrl
|       |-- llc_invalidate_sweep
|       |-- llc_valid_ram
|       |-- llc_repl_ram
|       |-- llc_data_store
|       |   |-- llc_data_store_generic
|       |   `-- llc_data_store_smic12
|       |-- llc_meta_store
|       |   |-- llc_meta_store_generic
|       |   `-- llc_meta_store_smic12
|       |-- llc_cache_ctrl
|       `-- llc_mapped_window_ctrl
`-- axi_llc_axi_bridge
```

更详细的层次、文件职责和 IO 分层见：

- [rtl_hierarchy_CN.md](docs/rtl_hierarchy_CN.md)

## IO 快速定位

- 对外控制面：
  - `mode_req`
  - `llc_mapped_offset_req`
  - `invalidate_line_*`
  - `invalidate_all_*`
  - 入口在 `src/axi_llc_subsystem.v`
- 对外上游请求/响应：
  - `read_req_* / read_resp_*`
  - `write_req_* / write_resp_*`
  - 入口在 `src/axi_llc_subsystem.v`
- 对外下游 AXI：
  - `axi_aw* / axi_w* / axi_b* / axi_ar* / axi_r*`
  - 入口在 `src/axi_llc_subsystem.v`
- 单流核心接口：
  - `up_req_* / up_resp_*`
  - `cache_req_* / cache_resp_*`
  - `bypass_req_* / bypass_resp_*`
  - 入口在 `src/axi_llc_subsystem_core.v`

当前实现优先冻结并保持以下语义边界：

- `mode=1`：正常 LLC cache path
- `mode=2`：direct-mapped 本地 LLC window
- `mode=0/3`：请求仍先进入 LLC resident lookup，但按 bypass 语义处理
- `mode=1` 命中 `MMIO_BASE/MMIO_SIZE` 窗口的请求会被强制按 bypass 语义处理
- 模式切换统一走 `block accepts -> drain -> valid-sweep invalidate -> activate`
- `invalidate_all` 只有在 cache 已 quiescent 且没有 dirty resident line 时才会被接受，
  不主动触发 dirty flush

当前目录是**自包含**的，不接入根 CMake，也不影响现有 C++/CTest 构建。

## 当前已落地内容

- `include/axi_llc_params.vh`
  - 当前默认参数
- `src/axi_reconfig_ctrl.v`
  - 模式切换 + `invalidate_all` 维护控制 FSM
  - 默认上电先执行一次 startup valid sweep，完成后 `active_mode=mode1`
- `src/llc_data_store.v`
  - `mode=1/2` 共享的 resident data set-row 存储
  - 当前已支持两种实现：
    - 默认通用数组实现
    - `USE_SMIC12_STORES=1` 时的 SMIC12 宏封装实现
  - 读返回通过 `rd_valid` 显式标记，默认 `TABLE_READ_LATENCY=1`
- `src/llc_meta_store.v`
  - 预留给 `mode=1` cache 语义使用的 resident meta set-row 存储
  - 当前已支持两种实现：
    - 默认通用数组实现
    - `USE_SMIC12_STORES=1` 时的 SMIC12 宏封装实现
  - 读返回通过 `rd_valid` 显式标记，默认 `TABLE_READ_LATENCY=1`
- `src/llc_valid_ram.v`
  - 独立 valid bit-array
  - 不做整表 reset，依赖 startup / reconfig sweep 清零
  - 读接口已收口成 `rd_en -> rd_valid`
- `src/llc_repl_ram.v`
  - 每 set 一个 next-victim-way 的 replacement 小表
  - 不做整表 reset
  - 读接口已收口成 `rd_en -> rd_valid`
- `src/llc_invalidate_sweep.v`
  - 顺序清 valid 的 sweep 控制器
- `src/llc_cache_ctrl.v`
  - `mode=1` 的 resident lookup / hit / miss / refill / victim writeback
- `src/llc_mapped_window_ctrl.v`
  - mode=2 地址翻译 / set-way 计算 / 共享 data-store 的 line 选择 / zero-read /
    zero-merge
- `src/axi_llc_subsystem_core.v`
  - 单流核心：
    - 集成 reconfig + shared data/meta/valid/repl store
    - `mode=1`、`mode=0/3`、以及 `mode=2` 窗口外都进入内建 `llc_cache_ctrl`
    - `cache_*` 口现在承载 line-memory miss/refill/writeback
    - `bypass_*` 口只承载 `llc_cache_ctrl` 发出的 lower bypass read/write
    - 当前已接入 `up_req_total_size`、`cache_req_size`、`bypass_req_size`
    - 当前已接入单平面 `id`：
      - `up_req_id / up_resp_id`
      - `cache_req_id / cache_resp_id`
      - `bypass_req_id / bypass_resp_id`
    - 当前已接入 `invalidate_line` / `invalidate_line_accepted`
    - 当前已接入 `invalidate_all_valid` / `invalidate_all_accepted`
    - `invalidate_all_accepted` 当前表示一次维护 sweep 已完成，并与配置提交同拍对外可见
- `src/axi_llc_subsystem_compat.v`
  - 多读/多写 master 兼容层
  - 补回 `accepted/accepted_id`、独立写响应槽位
  - 当前通过 per-master request FIFO 把外部接口收敛到单流核心
  - reconfig / `invalidate_all` 会先在 compat 层排空本地 queue / inflight / response slot，
    之后再把维护请求交给 core
  - `MASTER_DCACHE_R` 保留 same-cycle accept；其它 read master 仍保持 ready-first
  - `ready` 采用 sticky-grant 语义：一次只对一个 read master、一个 write master
    给出 ready，并在握手或请求撤销前保持
- `src/axi_llc_axi_bridge.v`
  - 把内部 `cache_* / bypass_*` lower 请求统一转换成单组 AXI4 `AW/W/B/AR/R`
  - 当前对齐 C++ 原型的下游打包合同：
    - `len = ceil((total_size + 1) / beat_bytes) - 1`
    - `size` 固定等于下游 AXI beat 宽度
    - `burst` 固定为 `INCR`
    - beat `data/strb` 按低地址连续切片
- `src/axi_llc_subsystem.v`
  - 当前对外 RTL 子模块顶层
  - 上游保持 C++ 风格的多 read/write master 自定义接口
  - 下游收敛成一组 AXI4 master 五通道
  - 不在本层再分出独立 DDR/MMIO 两组 AXI；地址分流留给外部系统

## 当前保留的微架构差异

- `axi_llc_subsystem_compat` 与 `axi_llc_subsystem_core` 仍然是单流收敛结构，因此整个子模块
  能向下游制造的并发度仍受上层单 inflight / per-master FIFO 调度限制
- 但 `axi_llc_axi_bridge` 已经补成 lower AXI 多 outstanding / 独立 `axi_id` remap：
  - read / write 各自独立分配 `axi_id`
  - `req_id` 保持 source-local，不直接暴露到 AXI
  - completion 进入 source-local response queue 后再回给 cache / bypass
- 带 timing-check 的外部宏模型直连时序隔离还没有接入日常回归
- `prefetch` 仍未进入 RTL，本轮继续保持关闭

## 文档

- [rtl_hierarchy_CN.md](docs/rtl_hierarchy_CN.md)
- [rtl_scope_CN.md](docs/rtl_scope_CN.md)
- [rtl_microarch_CN.md](docs/rtl_microarch_CN.md)
- [rtl_timing_model_CN.md](docs/rtl_timing_model_CN.md)
- [rtl_verif_plan_CN.md](docs/rtl_verif_plan_CN.md)

## 验证文件

当前提供 directed/contract 验证集与 filelist：

- `tb/tb_llc_data_store.v`
- `tb/tb_llc_meta_store.v`
- `tb/tb_llc_valid_ram.v`
- `tb/tb_llc_repl_ram.v`
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
- `tb/tb_axi_llc_subsystem_read_slice_contract.v`
- `tb/tb_axi_llc_subsystem_bypass_contract.v`
- `tb/tb_axi_llc_subsystem_compat_contract.v`
- `tb/tb_axi_llc_subsystem_compat_read_queue_contract.v`
- `tb/tb_axi_llc_subsystem_axi_cache_refill_contract.v`
- `tb/tb_axi_llc_subsystem_axi_bypass_read_contract.v`
- `tb/tb_axi_llc_subsystem_axi_bypass_write_contract.v`
- `tb/tb_axi_llc_axi_bridge_read_outstanding_contract.v`
- `tb/tb_axi_llc_axi_bridge_write_outstanding_contract.v`
- `tb/tb_axi_llc_axi_bridge_write_id_reuse_contract.v`
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
- 顶层默认上电会先跑一次 startup valid sweep，因此 reset 释放后需要等待维护流程回到 idle。
- 请求接口当前已经带 `total_size`，并参与 mode2 整体判窗与下游 `*_size` 发射。
- `mode=1` resident hit/refill 读响应、以及 `mode=2` direct-window 读响应，当前都按请求
  地址的 32-bit word offset 提取返回数据，与 C++ 原型的 `extract_line_response()` 语义对齐。
- resident table 读当前按 C++ 外部表 bundle 合同收口：
  - `data/meta/valid/repl` 各自有独立 `rd_valid`
  - `mode=1` lookup 会等四表同拍返回后再消费
  - `mode=2` direct-window 会等 `data + valid` 返回后再消费
- `TABLE_READ_LATENCY` 默认值是 `1`，保持当前功能回归时序；如果做更保守的 SMIC12
  wrapper 级 timing 建模，可提到 `2/3`
- `data/meta` 当前都采用同步单端口行为模型，因此 `mode=2` 写路径已经改成“先读
  row，再 merge，再写回”的顺序语义。
- bypass 读命中当前直接从 resident 返回；只有 miss 才通过 `bypass_*` 口访问 lower memory。
- `invalidate_all` 当前已经接入顶层，不做 whole-array reset，而是通过
  `llc_invalidate_sweep` 顺序清 `valid`。
- `invalidate_all_accepted` 不再表示“请求已被 FSM 吸收”，而表示“本次维护 sweep 已完成；
  active 配置在同一拍提交”。
- `invalidate_all` 当前与 C++ 原型保持一致：
  - 外部 `invalidate_all_valid` 需要保持到 `invalidate_all_accepted`
  - dirty resident line 存在时不会主动 flush
  - 只有 quiescent 且 `dirty_count==0` 时才接受
- 因此如果要在 mode1 脏写之后切换 mode，bench 或上层驱动必须先做 maintenance
  清掉脏 line，不能依赖 mode switch 隐式 flush
- `invalidate_line` 当前已经接入：
  - 所有非 direct-window 请求都通过 `llc_cache_ctrl` 复用 resident lookup 做 maintenance
  - `mode=2` direct-window resident line 仍不复用这条 maintenance 语义
  - compat 层会先挡住新的 write 接受，并等待同 line 的本地 write hazard 消失后，
    才把 `invalidate_line` 交给 core
- 当前 `id` 采用单个 `4-bit` 平面：
  - 直接路径返回捕获的 `up_req_id`
  - bypass lower 路径当前仍向下传 `bypass_req_id`，响应需带回匹配 id
  - cache 路径对上游仍返回原始 `up_req_id`
- bypass write 的 `write_resp_code` 当前已经透传 lower / AXI `bresp`
  - `mode=1` demand refill 对下游 line-memory 使用内部读事务 id `1`
  - cache miss 的 victim writeback 与 reconfig/flush 维护写回固定使用维护 id `0`
- `axi_llc_subsystem_compat` 已补回：
  - 多 read/write master 的 `ready/accepted`
  - read `accepted_id`
  - 独立 write response `id/code`
  - per-master request FIFO
  - sticky-grant `ready`
  - 当前内部 lower-issue 仍由单流核心串行化，因此上层能制造的并发度不等价于 C++
    interconnect 的完整多事务发射
- `axi_llc_axi_bridge` 当前已补回 lower AXI 多 outstanding / remap：
  - read pending table 与 write pending table 分离
  - AXI `R/B` 完成后再进入 cache / bypass 各自的 completion queue
  - write `axi_id` 在 `B` 握手后立即释放，可在 source response 尚未被消费时重用
  - `cache/bypass` 两个 source 可以跨源乱序完成，但对外仍保持各自 source-local `req_id`
    回传
- `axi_llc_subsystem` 已把当前对外边界收敛成：
  - 上游 `read_masters[] / write_masters[]`
  - 下游单组 AXI4 `AW/W/B/AR/R`
  - `mode / offset / invalidate_line / invalidate_all`
- 当前 AXI 顶层仍保持 C++ 原型的简化合同：
  - 只使用 `addr/len/size/burst/id/data/strb/last/resp/ready/valid`
  - 不引入 `axcache` 等当前 simulator 未使用的 AXI 扩展侧带
- 共享 `data/meta` 当前支持 `USE_SMIC12_STORES=1` 的宏封装实现；在真实外部宏模型
  上做功能仿真时，当前建议关闭 timing check（例如 `+notimingcheck`），因为零延迟
  RTL 直接连接详细 timing model 还会触发 hold 违例。
- 当前 DC 可直接综合到“宏实例 + 标准单元”这一级；但 SRAM 目前只有文本 `Liberty (.lib)`，
  若要在 DC 中得到带真实宏时序的 WNS/TNS，仍需要可用的 `.db` 或可用的 Library Compiler。
- prefetch 当前仍未进入 RTL：
  - C++ 原型里已有专门的 prefetch 单测与实现
  - 但本轮没有在当前分支上完成一次干净、可复现的端到端重验证
  - 因此 RTL 暂不引入 `prefetch` 状态机，只保留后续重新评估的空间
- 当前已在 `eda-10 + bash_eda10 + VCS` 跑通 store/mode/reconfig/顶层 contract bench。
