# compat DC elaborate 诊断备忘

记录时间：2026-05-06 22:02 CST。

更新：2026-05-09 01:23 CST。后续已在
`axi_llc_subsystem_compat.v` 中进一步把 read response payload pool/pop/output
register bank 化：外部 `READ_RESP_BITS=2048` 接口不变，内部按
`min(READ_RESP_BITS, LINE_BITS)` 分块存储。生产配置下等价于把 shared pool 从
`32 x 2048-bit` 的单个大选择锥拆为 4 组 `32 x 512-bit` chunk。该修改已通过
LLC hit-only、bounded non-hit 和全量 RTL contracts `53/53`；新的 compat DC run
为 `rtl/dc/runs/compat_quick_map_low_resp_chunk_direct_9t20_20260509_012043_eda-05`。

更新：2026-05-09 23:49 CST。23:11 CST 又在
`axi_llc_subsystem_compat.v` 中增加 per-master read/write ID busy bitmap，用它替代
ready 路径中对 FIFO/core/direct/response queue 的 same-ID 重复扫描。该修改通过
LLC hit-only、bounded non-hit 和全量 RTL contracts `53/53`。当前有效 DC run 为：

- compat quick-map：`rtl/dc/runs/compat_quick_map_low_id_busy_direct_9t20_20260509_231547_eda-05`
- full top compile：`rtl/dc/runs/full_compile_1g_id_busy_9t20_20260509_234201_eda-05`
- host：`eda-05`
- compat 当前阶段：23:46 CST 已 `elaborate_done`，23:49 CST 进入 `quick_map_low_start`
- full top 当前阶段：23:42 CST `elaborate_start`，尚无 post-link reports
- 节点内存：23:49 CST available memory 约 `355GiB`

23:49 CST 的 compat post-link reference 显示，ID-busy cleanup 没有减少旧报告中
`MUX_OP_32_5_2048`、`MUX_OP_32_5_512`、`SELECT_OP_2/3.8192`、
`SELECT_OP_2/3.16384` 的计数；`SEQGEN` 也基本持平。因此剩余宽 mux/select 热点
主要不在 ID conflict 扫描，而更像来自变量索引写入的宽 payload/register array。
该 run 仍处于正常等待窗口，不应现在停止或重跑。本文只记录如果后续 timing 失败或
长期无进展时的候选整改点。

更新：2026-05-10 02:05 CST。01:22-01:54 CST 复查发现
`compat_quick_map_low_id_busy_direct_9t20_20260509_231547_eda-05` 虽然仍在推进，
但 Pass 1 Mapping 中 `DW01_cmp6` 已超过 3000、`DW01_cmp2` 约 1900、`DW01_add`
约 670，说明 slow point 已从 same-ID 扫描转向 line/address hazard compare 网络。
因此 01:55 CST 后对 production `axi_llc_subsystem_compat.v` 做纯组合 summary 复用：
预计算每个 read/write master 的 supported、direct、path/dispatch-clear、id-clear
predicate，并同时供 selection 与 ready 输出使用。该修改不新增 pipeline/register，
目标是减少 DC 对同一 hazard 函数的重复展开。

该 hazard-summary RTL 已通过：

- LLC hit-only performance：
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_hazard_summary_20260510_020108`，
  `PERF LLC_HIT_READ64 CHECKED ready=0 resp=7 external=-1`。
- bounded non-hit performance：
  `rtl/local_debug/vcs_cpp_perf_contract_hazard_summary_20260510_020130`，
  `max_extra_observed=5`，阈值 direct `<=6`、LLC miss `<=8`。
- 全量 RTL contracts：
  `rtl/local_debug/vcs_all_contracts_hazard_summary_20260510_020253`，`53/53` PASS。

02:02 CST 已停止过期 compat quick-map，并启动当前 RTL 的新 DC：

- compat quick-map：
  `rtl/dc/runs/compat_quick_map_low_hazard_summary_direct_9t20_20260510_020217_eda-05`
- full top compile：
  `rtl/dc/runs/full_compile_1g_hazard_summary_9t20_20260510_020217_eda-05`

两条新 run 均确认使用 SMIC12 9T20 stdcell 和 SMIC12 data/meta SRAM `.db`，02:02 CST
已完成 analyze 并进入 elaborate，早期无 fatal/error/OOM。旧 full-top
`full_compile_1g_id_busy_9t20_20260509_234201_eda-05` 保留继续跑，用于提供旧 RTL 的
top setup 趋势；其 precompile setup 参考为 Critical Path Slack `+0.33ns`、TNS `0`、
setup violating paths `0`，但这不是最终 postcompile pass 证据。

## 结论

`axi_llc_subsystem_compat.v` 当前 1843 行。前面已处理过两类主要问题：

- read response payload：从每 master 队列持有 128 份 `2048-bit` payload 改为
  32 份 shared pool，显著降低寄存器阵列规模。
- invalid wide payload clear/reset：已去掉无效 entry 上的宽 payload 清零，避免
  大量无意义 reset/clear mux。

此前更可疑的是 compat 组合 ready/dispatch 逻辑中的重复全槽扫描。ID-busy cleanup
已经去掉 same-ID 的重复扫描，但 post-link reference 证明大宽度 mux/select 没有明显
下降；因此当前剩余更可疑的是宽 payload/register array 的变量索引写入和变量索引读取，
不是 SRAM macro，也不是 valid/repl regfile。

## 主要热点

生产参数：

- `MAX_OUTSTANDING = 32`
- `READ_FIFO_DEPTH = 32`
- `WRITE_FIFO_DEPTH = 32`
- `RD_SLOT_COUNT = 4 * 32 = 128`
- `WR_SLOT_COUNT = 2 * 32 = 64`
- `RD_RESP_SLOT_COUNT = 4 * 32 = 128`
- `RD_RESP_POOL_COUNT = 32`
- `READ_RESP_BITS = 2048`

剩余宽数组：

- `wr_payload_wdata[0:31]`，每项 `512-bit`
- `direct_slot_wdata_r[0:31]`，每项 `512-bit`
- `rd_resp_pool_data`，逻辑容量仍为 32 份 `2048-bit` response，但内部已拆成
  4 组 `512-bit` chunk。
- `rd_resp_data_r`，逻辑容量仍为 4 份 `2048-bit` output register，但内部已拆成
  4 组 `512-bit` chunk。
- `rd_resp_pop_data_r`，逻辑容量为 4 份 `2048-bit` pop stage，也已拆成 4 组
  `512-bit` chunk。

这些数组现在都受 valid/count 保护，且 invalid clear 已清理；目前不建议仅为 OOM
继续拆它们，除非 DC timing/area 证明仍是主要瓶颈。若后续 DC 仍显示 response
pool mux 是 setup/mapping 热点，下一步应看是否能按实际请求大小进一步拆 direct
DDR 256B response 与 LLC/cacheline 64B response，而不是改变外部 2048-bit 接口。

23:49 CST post-link 对比的关键计数：

| 对象 | 旧 direct-store split compat | 新 ID-busy compat |
| --- | ---: | ---: |
| `SEQGEN` | `133661` | `133757` |
| `MUX_OP_32_5_512` | `8` | `8` |
| `MUX_OP_32_5_2048` | `4` | `4` |
| `SELECT_OP_2.8192` | `2` | `2` |
| `SELECT_OP_2.16384` | `6` | `6` |
| `SELECT_OP_3.8192` | `2` | `2` |
| `SELECT_OP_3.16384` | `4` | `4` |

因此如果新 compat quick-map 最终 setup 失败，下一步优先看这些结构：

- `direct_slot_wdata_r[direct_slot_free_w]` / `direct_slot_wdata_r[direct_issue_slot_w]`
  相关的 direct bypass slot data path。
- `wr_payload_wdata[wr_payload_free_w]` 和
  `wr_payload_wdata[wr_q_payload_idx[...]]` 相关的 write payload pool。
- `rd_resp_pool_data_c0..c3[pool_slot_idx]` 相关的 response pool variable-index
  write/pop path。
- `rd_resp_data_r` / `rd_resp_pop_data_r` 相关的 output/pop response staging。

23:53-00:00 CST 做了一个独立小 probe，不触碰 production RTL：

- `payload_pool512_timing_probe_quick_map_low_9t20_20260509_235324_eda-05`
- `payload_pool64_timing_probe_quick_map_low_9t20_20260509_235754_eda-05`

该 probe 对比 `32 x 512-bit` 变量索引 payload pool 与拆成 `8 x (32 x 64-bit)`
的写法。两个版本在 1GHz quick-map 下都 setup pass，WNS/TNS 均为 `0.00/0.00`，
cell area 分别约 `24602.85` 与 `24584.76`。关键是 64-bit chunk 版本仍被 DC
重组为 `MUX_OP_32_5_512`，没有证明简单细拆 chunk 能消除 512-bit mux cone。
因此如果 production compat 后续 timing 失败，不应盲目做机械 `512 -> 8x64`
拆分；应先看 final timing endpoint，再决定是否做 per-slot output staging、把
response/direct payload pool 独立成小模块，或按实际 consumer 宽度缩窄输出。

00:03-00:12 CST 追加了更贴近 `rd_resp_q_pool_idx -> rd_resp_pool_data` 的间接读取
probe：

- `payload_pool_indirect_timing_probe_quick_map_low_9t20_20260510_000318_eda-05`
- `payload_pool_indirect_staged_timing_probe_quick_map_low_9t20_20260510_000742_eda-05`

该 probe 对比“同拍从 response queue 读 pool index 后再读 32x512 pool”和“先把
pool index 打一拍、下一拍读 pool”。两个版本同样都 setup pass，WNS/TNS 均为
`0.00/0.00`，cell area 分别约 `24836.28` 与 `24840.48`，post-link reference 都仍有
`MUX_OP_32_5_5` 和 `MUX_OP_32_5_512`。因此仅把 pool index 打一拍也没有形成明显
结构收益；它只会给 queued response 增加潜在延迟，不能作为无 endpoint 证据时的默认
修复。

01:22 CST 复查 current compat quick-map raw log：仍在 Pass 1 Mapping，但日志正在
推进到大量 DesignWare compare/add 单元处理。当前已观察到：

| DesignWare 族 | 计数 |
| --- | ---: |
| `axi_llc_subsystem_compat_DW01_cmp6` | `775` |
| `axi_llc_subsystem_compat_DW01_cmp2` | `426` |
| `axi_llc_subsystem_compat_DW01_add` | `150` |
| `axi_llc_subsystem_compat_DW01_inc` | `25` |
| `axi_llc_subsystem_compat_DW01_dec` | `8` |
| `axi_llc_subsystem_compat_DW01_sub` | `5` |

这说明当前 quick-map 慢点更可能是 address/line hazard compare 网络，而不是 ID-busy
扫描或 payload chunk 本身。若该 run 后续 timeout 或 timing fail，优先整改方向应回到：

- `local_write_line_pending()`、`read_capture_line_hazard()`、
  `dispatch_path_line_hazard()`、`core_path_line_hazard()` 的重复展开。
- read accept selection 与 read ready 输出对同一 incoming address 的 hazard 函数
  重复调用。
- invalidate-line hazard 对 write req / write queue / core slot / direct slot 的
  多处 line-tag 比较。

候选实现仍应先做纯组合 summary 复用或小 CAM helper 模块，不应直接切流水；因为 LLC
hit 性能 contract 已收敛，新增 pipeline 会重新影响 C++/RTL cycle 对齐。

更可疑的组合扫描：

- `local_write_line_pending()`：4 个 loop，扫描 write req、`WR_SLOT_COUNT`、
  `MAX_OUTSTANDING`、`DIRECT_SLOT_COUNT`。
- `read_capture_line_hazard()`：组合调用 `dispatch_path_line_hazard()`、
  `queued_core_read_line_pending()`、`local_write_line_pending()`。
- `read_id_conflict()`：4 个 loop，扫描 read FIFO、core slots、read response queue、
  direct slots。
- `write_id_conflict()`：3 个 loop，扫描 write FIFO、core slots、direct slots。
- 顶层 `always @(*)` 自身还有 12 个显式 loop。

函数调用重复点：

- read accept 选择逻辑调用一次 `local_write_line_pending()` 或
  `read_capture_line_hazard()`，并调用 `read_id_conflict()`。
- read ready 输出逻辑对每个 read master 再调用一次同类函数。
- write accept 选择逻辑调用 `write_id_conflict()`。
- write ready 输出逻辑对每个 write master 再调用一次 `write_id_conflict()`。
- dispatch 逻辑还会调用 `dispatch_path_line_hazard()`。

这意味着 DC 可能在一个组合块中重复展开大量 32/64/128 深度比较网络。

## 后续候选整改

若 `eda-09` full DC 长时间停在 compat elaborate 且无 log 更新，优先考虑以下低风险
方向：

1. 预计算 hazard/id-conflict bitmap。
   将每个 master 的 `read_accept_safe_w` / `write_accept_safe_w` / `read_ready_safe_w`
   等中间条件在组合块中只算一次，避免 selection 和 output ready 两处重复展开同一个
   函数调用。该改动理论上不改变时序语义，只减少重复组合网络。

2. 将 line hazard 拆成分类 summary。
   例如分别维护 `local_write_line_pending_for_read[master]`、
   `core_line_hazard_for_req[master]`、`direct_line_hazard_for_req[master]`，避免每个
   ready/dispatch 分支直接嵌套调用多层函数。注意这些仍然是组合 summary，不引入
   新拍，除非后续明确接受 pipeline 改动。

3. 将宽 payload pool 隔离为 per-slot enable 小模块。
   目标不是改变外部 `READ_RESP_BITS=2048` 或 `LINE_BITS=512` 语义，而是让 DC 在
   top-level compat 中看到更明确的 per-slot register enable 和较短 mux cone。若
   timing 报告指向 response pool 或 direct slot payload，这是优先级最高的整改。

4. 保持 valid/repl 为 regfile。
   valid 表本来就应是 regfile，不应因为此前 global OOM 改成 SRAM macro。data/meta
   才继续使用 SMIC12 SRAM macro。
   如果后续 DC 再报 OOM，先核对 `dmesg -T` 是否为 shared-server `global_oom`、
   killed pid/uid 是否对应当前 DC、同时段其它用户 RSS、以及 console 中
   `USE_SMIC12=1`/SRAM `.db` 是否已生效，再决定是否需要 RTL 结构整改。

5. 不在没有证据时切流水。
   切流水会影响接受时序、Linux 性能和 C++ reference 对齐。只有在 full DC timing
   明确指出 setup 路径无法靠组合重构解决时，再讨论新增 pipeline，并同步更新 C++/RTL
   语义和 Linux perf gate。

## 当前判断

现在 `eda-05` current RTL run 仍在正常窗口，不能判定失败。下一步继续通过
`rtl/dc/dc_status_latest.txt` 和 run log 低频观察：

- 如果出现 `elaborate_done`，继续等待 compile/QoR/timing。
- 如果出现 `quick_map_low_done`，优先读 final quick-map timing/QoR；只有 final
  timing 失败或 path 指向宽 payload/select cone，才按本文候选点整改 compat。
- 如果 RSS 快速增长到几十 GB 且 log 长时间不动，再检查是否为 payload/register
  array 展开导致，避免盲目继续改 ID/ready 逻辑。
- 如果出现 OOM，需要同时检查 `dmesg -T` 和全机其它用户进程，避免把 shared-server
  `global_oom` 误判成 RTL 必然 OOM。
- 检查频率保持低频：早期 elaborate 阶段约每 1 小时一次；进入 compile/QoR 后按
  30-60 分钟一次；只有退出、OOM、log 报错或 RSS 异常快速增长时才立即处理。
