# compat DC elaborate 诊断备忘

记录时间：2026-05-06 22:02 CST。

当前有效 full DC：

- run root：`rtl/dc/runs/full_compile_1g_strict_template_9t20_5274f9d_20260506_2154_eda09`
- host：`eda-09`
- DC PID：`3230092`
- 当前阶段：`DC_STAGE elaborate_start`，building `axi_llc_subsystem_compat`
- 当前 RSS：约 `4.9GB`
- 节点内存：约 `582GiB` available

该 run 仍处于早期正常等待窗口，不应现在停止或重跑。本文只记录如果后续长期无
日志更新时的候选整改点。

## 结论

`axi_llc_subsystem_compat.v` 当前 1843 行。前面已处理过两类主要问题：

- read response payload：从每 master 队列持有 128 份 `2048-bit` payload 改为
  32 份 shared pool，显著降低寄存器阵列规模。
- invalid wide payload clear/reset：已去掉无效 entry 上的宽 payload 清零，避免
  大量无意义 reset/clear mux。

剩余更可疑的不是 SRAM macro，也不是 valid/repl regfile，而是 compat 组合 ready/
dispatch 逻辑中的重复全槽扫描。DC elaborate 需要展开这些函数和循环，可能造成
build `axi_llc_subsystem_compat` 时间很长。

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

- `wr_q_wdata[0:63]`，每项 `512-bit`
- `direct_slot_wdata_r[0:31]`，每项 `512-bit`
- `rd_resp_pool_data[0:31]`，每项 `2048-bit`
- `rd_resp_data_r[0:3]`，每项 `2048-bit`

这些数组现在都受 valid/count 保护，且 invalid clear 已清理；目前不建议仅为 OOM
继续拆它们，除非 DC timing/area 证明仍是主要瓶颈。

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

3. 将 ID conflict 检查拆成 read/write per-master summary。
   当前 `read_id_conflict()` 会扫描 FIFO、core slot、resp queue、direct slot；如果
   DC 卡在 elaborate，可以先做组合 summary 复用，不改 outstanding 语义。

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

现在 `eda-09` run 还只跑了数分钟，RSS 仍在个位 GB，不能判定失败。下一步继续用
`rtl/dc/check_dc_run.sh --host eda-09 <run>` 定期观察：

- 如果出现 `elaborate_done`，继续等待 compile/QoR/timing。
- 如果 RSS 快速增长到几十 GB 且 log 长时间不动，再按本文候选点优先整改 compat。
- 如果出现 OOM，需要同时检查 `dmesg -T` 和全机其它用户进程，避免把 shared-server
  `global_oom` 误判成 RTL 必然 OOM。
- 检查频率保持低频：早期 elaborate 阶段约每 1 小时一次；进入 compile/QoR 后按
  30-60 分钟一次；只有退出、OOM、log 报错或 RSS 异常快速增长时才立即处理。
