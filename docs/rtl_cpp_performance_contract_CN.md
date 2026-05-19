# RTL / C++ 性能周期对齐检查

更新时间：2026-05-11 CST。

本文档记录等待 full DC 期间新增的 RTL/C++ performance diagnostic，以及已经进入
production C++ 的 LLC hit cycle 对齐修正。direct path diagnostic 仍是手动检查项，
不进入当前正在综合的 `rtl/flist/axi_llc_rtl.f`，也不作为默认
`rtl/run_all_contracts.sh` 的一部分；LLC hit 对齐使用实际 `AXI_Interconnect`
C++ 和实际 RTL top `axi_llc_subsystem_dual.v`。

## 目标

功能等价只能说明协议行为、ID、数据和约束正确，不能保证 RTL 实际周期数达到 C++
模拟器预测。该 diagnostic 用实际 `AXI_Interconnect` C++ comb/seq 路径生成关键事件周期，
再由实际 RTL top `axi_llc_subsystem_dual.v` 在 testbench 中 replay 同类 microbench，
比较这些事件的 cycle：

- upstream request ready。
- DDR/MMIO `AR/AW/W` 发射。
- DDR/MMIO `R/B` 返回被接收。
- upstream read/write response fire。

## 文件

- C++ generator：`axi_interconnect/axi_interconnect_dual_port_perf_vectors_test.cpp`
- CMake target：`axi_interconnect_dual_port_perf_vectors`
- 生成头文件：`rtl/include/axi_dual_cpp_perf_vectors.vh`
- RTL diagnostic TB：`rtl/tb/tb_axi_llc_subsystem_dual_cpp_perf_contract.v`
- 手动 flist：`rtl/flist/perf_axi_llc_subsystem_dual_cpp_perf_contract.f`
- direct path 手动运行脚本：`rtl/run_cpp_perf_contract.sh`
- LLC hit-only 手动运行脚本：`rtl/run_cpp_llc_hit_perf_contract.sh`
- LLC miss-only 手动运行脚本：`rtl/run_cpp_llc_miss_perf_contract.sh`

该 flist 故意不命名为 `tb_*.f`，避免被 `rtl/run_all_contracts.sh` 自动纳入默认功能回归。
当前口径是：LLC hit 必须精确 cycle 对齐；非 hit direct DDR/MMIO 场景作为
bounded performance gate，默认允许 RTL 比 C++ 晚不超过 6 cycle；MODE_CACHE clean
read miss/refill 单独允许最多 8 cycle 额外延迟。若需要复现逐事件精确比较，可设置
`EXACT_NON_HIT=1`。

## 运行

生成 C++ expected cycle header：

```sh
cmake --build build_dual_axi_scope_20260428 --target axi_interconnect_dual_port_perf_vectors -j8
./build_dual_axi_scope_20260428/axi_interconnect_dual_port_perf_vectors \
  rtl/include/axi_dual_cpp_perf_vectors.vh
```

运行 RTL diagnostic：

```sh
cd rtl
source /centos7/eda-tools/eda-software/synopsys/source-scripts/bash_eda05
OUT_DIR=local_debug/vcs_cpp_perf_contract_20260507_eda05_standalone \
  ./run_cpp_perf_contract.sh
```

最近一次运行：

- C++ generator：通过，生成 `rtl/include/axi_dual_cpp_perf_vectors.vh`。
- VCS compile：通过。
- bounded RTL/C++ perf compare：通过，包含 MODE_CACHE clean read miss/refill
  和 MODE_OFF direct DDR/MMIO / overlap 场景；当前 `max_extra_observed=5`，
  direct path 上限为 6 cycle，LLC miss/refill 上限为 8 cycle。
- 日志：
  `rtl/local_debug/vcs_cpp_perf_contract_read_write_hit_20260511_065640_eda-05/run.log`
- 若运行 `EXACT_NON_HIT=1 ./run_cpp_perf_contract.sh`，仍会按逐事件精确 cycle
  对比并复现 LLC miss/direct DDR/MMIO 的 mismatch，用于调试 latency 来源。
  最近一次调试日志：
  `rtl/local_debug/vcs_cpp_perf_contract_exact_non_hit_with_llc_miss_expected_fail_20260507_2232_eda-05/run.log`
  当前 mismatch 计数为 45。

运行 LLC hit-only contract：

```sh
cd rtl
source /centos7/eda-tools/eda-software/synopsys/source-scripts/bash_eda05
OUT_DIR=local_debug/vcs_cpp_llc_hit_perf_contract_20260507_173316_eda05 \
  ./run_cpp_llc_hit_perf_contract.sh
```

最近一次 LLC hit-only 结果：

- C++ generator：通过，`CPP_PERF_LLC_HIT_READ64_REQ_READY_CYCLE=0`、
  `CPP_PERF_LLC_HIT_READ64_RESP_CYCLE=7`、
  `CPP_PERF_LLC_HIT_READ64_EXTERNAL_CYCLE=-1`；写 hit 为
  `CPP_PERF_LLC_HIT_WRITE64_REQ_READY_CYCLE=1`、
  `CPP_PERF_LLC_HIT_WRITE64_RESP_CYCLE=9`、
  `CPP_PERF_LLC_HIT_WRITE64_EXTERNAL_CYCLE=-1`。
- RTL hit-only contract：通过，
  `PERF LLC_HIT_READ64 CHECKED ready=0 resp=7 external=-1` 和
  `PERF LLC_HIT_WRITE64 CHECKED ready=1 resp=9 external=-1`。
- 日志：
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_read_write_hit_20260511_065617_eda-05/run.log`
- 2026-05-07 23:06 CST，在 `axi_llc_axi_read_pack` /
  `axi_llc_axi_write_pack` 清理 dynamic shift 后重跑 hit-only contract 仍通过，日志：
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_no_shift_20260507_2306_eda-05/run.log`。
- C++ 模块回归：`ctest --test-dir build_dual_axi_scope_20260428 --output-on-failure`
  通过 `25/25`。
- RTL 全量 contract 回归：`rtl/run_all_contracts.sh` 通过 `53/53`，日志目录为
  `rtl/local_debug/vcs_all_contracts_slot_payload_20260511_020415_eda-05`。
  dynamic shift cleanup、head-payload cleanup 以及 per-slot write payload cleanup 后均保持
  `53/53` 通过。
- parent simulator 短程 Linux sanity：独立 build
  `build_goal_llc_hit_large_bpu_20260511` 使用 `PROFILE=large EXTRA_CXXFLAGS=-DCONFIG_BPU`，
  `AXI_SUBMODULE_MODE=1` 跑 `../img/linux.bin --max-commit 300000` 通过；日志：
  `local_logs/goal_llc_hit_dc_20260511/linux_large_bpu_mode1_300k_after_cpp_resp_boundary_20260511_071015.log`。
  该 run 显示 `bpu=1`、LLC enabled、`sim-time(cycle)=121383`、IPC `2.471524`；
  ROB 512 由 `include/config.h.large` / 当前 `include/config.h` 的 `ROB_NUM = 512` 和二者一致性证明。
  相比 2026-04-29 旧 300k 参考 `120719` / `2.485118`，cycle +0.55%、IPC -0.55%，
  未见 Difftest/abort/deadlock。
- parent simulator 5M Linux sanity：同一独立 build 跑 `../img/linux.bin --max-commit 5000000`
  通过；日志：
  `local_logs/goal_llc_hit_dc_20260511/linux_large_bpu_mode1_5m_after_cpp_resp_boundary_20260511_071224.log`。
  该 run 显示 `sim-time(cycle)=2086921`、IPC `2.395877`。相比 2026-04-28 旧 5M
  参考 `2103181` / `2.377352`，cycle -0.77%、IPC +0.78%，未见 Difftest/abort/deadlock。

运行 LLC miss-only contract：

```sh
cd rtl
source /centos7/eda-tools/eda-software/synopsys/source-scripts/bash_eda05
OUT_DIR=local_debug/vcs_cpp_llc_miss_perf_contract_20260507_2228_eda-05 \
  ./run_cpp_llc_miss_perf_contract.sh
```

最近一次 LLC miss-only 结果：

- C++ generator：通过，`CPP_PERF_LLC_MISS_READ64_REQ_READY_CYCLE=0`、
  `CPP_PERF_LLC_MISS_READ64_AR_CYCLE=5`、`R0/R1=7/8`、
  `CPP_PERF_LLC_MISS_READ64_RESP_CYCLE=14`。
- 最新 bounded gate 中的 LLC miss contract：通过，`ready=0`、`AR=8`、
  `R0/R1=10/11`、`resp=18`，最大额外延迟为 overlap MMIO read 的 +5 cycle；
  LLC miss response 本身额外延迟为 +4 cycle。
- 日志：
  `rtl/local_debug/vcs_cpp_perf_contract_read_write_hit_20260511_065640_eda-05/run.log`
- dynamic shift cleanup 后，完整 bounded perf contract 仍通过，日志：
  `rtl/local_debug/vcs_cpp_perf_contract_no_shift_20260507_2307_eda-05/run.log`。

## 当前结果

### MODE_CACHE LLC Hit

LLC hit read64/write64 当前已经按实际生产路径对齐：C++ 不再直接把 LLC core
read response 同拍暴露给 upstream，而是加入和 RTL `axi_llc_subsystem_compat`
对应的 read response 寄存器边界，并避免在 C++ core fresh response 当拍消费。
写 hit 也加入与 RTL compat `wr_resp_valid_r` 对应的 response 边界，因此 C++ 不再比
RTL 提前暴露 write response。对齐后的关键事件为：

| 场景 | 事件 | C++ cycle | RTL cycle | 差异 |
| --- | --- | --- | --- | --- |
| LLC_HIT_READ64 | upstream request ready | 0 | 0 | 0 |
| LLC_HIT_READ64 | upstream response | 7 | 7 | 0 |
| LLC_HIT_READ64 | external DDR/MMIO issue | -1 | -1 | 0 |
| LLC_HIT_WRITE64 | upstream request ready | 1 | 1 | 0 |
| LLC_HIT_WRITE64 | upstream response | 9 | 9 | 0 |
| LLC_HIT_WRITE64 | external DDR/MMIO issue | -1 | -1 | 0 |

该结果满足当前目标中“LLC hit 必须性能/cycles 对齐”的要求。注意它只说明 hit 关键路径
已对齐；miss/refill/dirty victim 仍按协议、约束和可接受性能差距处理。

### MODE_CACHE Clean Read Miss/Refill

新增的 `LLC_MISS_READ64` microbench 使用实际 C++ `AXI_Interconnect` + table-driver
产生空 cache 下的 64B DCache read miss，再由实际 RTL top replay 同类场景。该场景
覆盖 clean miss 的 request accept、DDR 64B/2-beat refill `AR/R`、lower `RREADY`
不回压以及最终 upstream response。

| 场景 | 事件 | C++ cycle | RTL cycle | 差异 |
| --- | --- | --- | --- | --- |
| LLC_MISS_READ64 | upstream request ready | 0 | 0 | 0 |
| LLC_MISS_READ64 | DDR `AR` | 5 | 8 | +3 |
| LLC_MISS_READ64 | DDR `R0/R1` accepted | 7/8 | 10/11 | +3/+3 |
| LLC_MISS_READ64 | upstream response | 14 | 18 | +4 |

该差异当前小于 direct DDR/MMIO 的默认 6-cycle 上限，但 miss/refill 仍保留独立的
8-cycle 上限，防止后续时序 cleanup 让该路径无界退化。这个选择不是把 hit 放宽；
hit 仍要求精确。原因是 miss/refill 经过 LLC lookup、
MSHR issue、refill install/commit 和 upstream response 寄存器边界，并且当前 RTL 已为了
1GHz 时序把 MSHR issue/commit payload 选择拆成多拍。以当前 microbench 的 2-cycle
DDR latency 衡量，+4 cycle 是可见固定成本；放到真实 DDR latency 下是固定项，但仍需要
bounded gate 防止后续无界退化。

### MODE_OFF Direct DDR/MMIO

direct DDR/MMIO microbench 不覆盖 LLC hit/miss/refill 或 maintenance。结果已经足以说明：
RTL 的实际周期行为并不等于当前 C++ 模拟器的 direct path 周期预测。

| 场景 | 事件 | C++ cycle | RTL cycle | 差异 |
| --- | --- | --- | --- | --- |
| READ64_DDR | `AR` | 0 | 2 | +2 |
| READ64_DDR | `R0/R1` | 2/3 | 4/5 | +2/+2 |
| READ64_DDR | upstream response | 4 | 8 | +4 |
| READ32_DDR | `AR/R0/response` | 0/2/3 | 2/4/7 | +2/+2/+4 |
| READ32_MMIO | ready/`AR/R0/response` | 0/1/3/4 | 1/3/5/8 | +1/+2/+2/+4 |
| WRITE64_DDR | request ready | 0 | 1 | +1 |
| WRITE64_DDR | `AW/W0/W1/B` | 2/3/4/6 | 3/4/5/7 | +1 |
| WRITE64_DDR | upstream response | 7 | 9 | +2 |
| WRITE32_MMIO | ready/`AW/W0/B/response` | 0/2/3/5/6 | 1/3/4/6/8 | +1/+1/+1/+1/+2 |
| OVERLAP_READ DDR | `AR/R0/R1/response` | 0/2/3/4 | 2/4/5/8 | +2/+2/+2/+4 |
| OVERLAP_READ MMIO | ready/`AR/R0/response` | 0/1/3/4 | 2/4/6/9 | +2/+3/+3/+5 |
| OVERLAP_WRITE DDR | ready/`AW/W0/W1/B/response` | 0/2/3/4/6/7 | 1/3/4/5/7/9 | +1/+1/+1/+1/+1/+2 |
| OVERLAP_WRITE MMIO | ready/`AW/W0/B/response` | 2/4/5/7/8 | 3/5/6/8/10 | +1/+1/+1/+1/+2 |

该差异不是 reset 后 warm-up 造成的；TB 已在 reset settle 后增加 idle warm-up，结果不变。

## 2026-05-07 差异原因拆解

本轮在 `eda-05` 恢复后重新检查了 RTL/C++ 源码和正在运行的 DC。当前判断是：
这些差异主要来自 RTL 为 1GHz 时序、队列隔离和 lower AXI response 不回压而引入的
寄存器边界，不是数据/ID/协议功能错误。

请求发射路径：

- C++ direct read 对 `MASTER_DCACHE_R` 有 same-cycle accept，同一轮
  `comb_read_arbiter()` 可以从 upstream request 直接驱动 DDR/MMIO `AR`。
- RTL `axi_llc_subsystem_compat` 虽然也保留了 DCache read 的 same-cycle ready，
  但 request 仍先在 compat 内部 `rd_q` 捕获，下一拍形成 `direct_bypass_req`，
  再由 `axi_llc_axi_bridge` 捕获到 pending slot / issue FIFO，之后才驱动 `AR`。
- 因此 READ64_DDR 的 `AR` 从 C++ cycle 0 变成 RTL cycle 2。若要消掉这 2 拍，
  需要做 compat direct-request fall-through 和 bridge issue-FIFO fall-through，
  这会把 request decode、hazard、slot scan、ID 分配、地址整形和 lower AXI ready
  串成更长组合路径，对当前 1GHz DC 风险较大。

响应返回路径：

- C++ `comb_read_response()` 在 lower `R` beat 被 `seq()` 处理后，下一拍就能把
  completed direct read response 暴露给 upstream。
- RTL `axi_llc_axi_bridge` 对 lower `R` 的处理是：先无条件按 ID 接收 lower `R`
  到 read pending slot；完整 line 完成后，再推入 source-local response queue；
  `axi_llc_subsystem_compat` 再把 `bypass_resp` 接收并打一拍到 upstream
  `read_resp_valid`。
- 这个结构让 external AXI `RREADY` 不依赖 upstream response ready 或 dual-port
  response mux 是否当拍选中该 port，符合“不允许 lower R 被上游依赖顺序回压”的约束。
  代价是 READ64_DDR 最后一拍 `R1` 到 upstream response 从 C++ 的 +1 拍变成 RTL
  的 +3 拍。

写路径：

- C++ 和 RTL 写请求都更接近 ready-first 语义，因此 lower `AW/W/B` 大多只差 1 拍。
- RTL write response 仍需要 bridge response queue 和 compat upstream response
  register，因此 upstream write response 相比 lower `B` 多 2 拍，而 C++ 多 1 拍。

overlap 场景：

- `OVERLAP_READ`/`OVERLAP_WRITE` 中的 overlap 是 DDR port 与 MMIO port 同时有请求，
  不是地址重叠。
- MMIO read 在 overlap 下额外更慢，主要来自 compat direct dispatch 仍是一个共享
  round-robin/slot 路径，且 dual-port response mux 对已入队 response 做单路返回；
  这不会回压 external AXI `R`，但会影响 upstream response 可见 cycle。

LLC miss/refill 路径：

- C++ clean read miss 在 lookup miss 后发出 DDR refill `AR`，按 2-cycle DDR model
  接收 `R0/R1`，并在 refill/install 后返回 upstream，当前事件为 `AR=5`、
  `R0/R1=7/8`、`resp=14`。
- RTL 同一场景事件为 `AR=8`、`R0/R1=10/11`、`resp=18`。其中 `AR/R` 的 +3 拍主要
  来自 cache-mode lookup、compat/core 边界和 MSHR issue staging；response 额外再多
  约 1 拍，来自 refill install/commit staging 与 upstream response 寄存器边界。
- 这些边界是当前 1GHz setup 修正方向的一部分，短期不建议为了 miss microbench 把它们
  重新合成单拍组合路径；如果后续真实程序 IPC 或 miss penalty 出现明显回退，再针对
  miss/refill 做有限 fall-through 优化。

## 当前 DC 状态

2026-05-11 当前有效 DC 进度与 setup pass/fail 结论以
`rtl/dc/current_setup_status_CN.md` 为准。当前有效 RTL 是 `slot_payload`
版本，已同步启动 `compat` quick-map、`full_top` quick-map 和 `full_top`
1GHz full compile。当前 top 只有 precompile setup `+0.33ns` 可作为早期趋势；
quick-map/final postcompile timing 尚未生成，因此不能把 setup 视作已收敛。
本节下面保留 2026-05-07 的历史分析，不能作为当前 RTL 的 DC 结论。

2026-05-07 15:44 CST 复查：

- 当前有效 full DC 仍在 `eda-09` 运行，run root 为
  `rtl/dc/runs/full_compile_1g_strict_template_9t20_5274f9d_20260506_2154_eda09`。
- `dc_shell` 子进程 PID `3230092`，已运行约 17h51m，RSS 约 95.4GB；节点 available
  memory 约 896GiB，当前不是 OOM 风险状态。
- `compile_ultra -retime` 已进入 `Beginning Delay Optimization` /
  `Beginning WLM Backend Optimization` 后续优化阶段。日志中内部表格的列名为
  `WORST NEG SLACK`；当前约 `4.6` 应按 WNS violation magnitude 解读，即 setup
  仍有约 `-4.6ns` 级违例，而不是 `+4.6ns` 余量。
- 尚未生成 postcompile `report_qor` / `report_timing` / netlist signoff 产物，因此不能
  认为 DC/timing 已完成。
- 16:35 CST 后 RTL 已针对 MMIO bridge 内部 read response 宽度做结构裁剪；当前
  `eda-09` full DC 已在该修改前完成 analyze/elaborate，因此它只能作为旧结构 baseline，
  不能代表新 RTL 的最终 timing。
- 17:42 CST 后 RTL 又把 `axi_llc_axi_read_pack` / `axi_llc_axi_write_pack` 中按字节
  pack/unpack 的超宽动态移位改为 indexed part-select。该修改是功能等价的 timing
  cleanup，用于避免 DC 从 `READ_RESP_BITS=2048` / `LINE_BITS=512` 的动态 shift
  推出 `DW01_ash_A_width2048` 等宽 barrel shifter。修改后 RTL 全量 contracts `53/53`
  通过，LLC hit-only performance contract 仍为 `ready=0/resp=7/no external`。
  已启动的旧 bridge/full DC 不包含该修改，需要用新 RTL 重跑 bridge/full-top 才能衡量
  setup 改善。
- 23:04 CST 又完成了一处更直接的 production RTL cleanup：彻底去掉
  `axi_llc_axi_read_pack` / `axi_llc_axi_write_pack` 的 mode2/data beat 动态 shift，
  改成按字节 indexed copy。该修改不改变 pipeline cycle，只减少综合推断宽 barrel
  shifter 的机会。验证结果：LLC hit-only perf contract 通过
  (`local_debug/vcs_cpp_llc_hit_perf_contract_no_shift_20260507_2306_eda-05`)，
  bounded perf contract 通过
  (`local_debug/vcs_cpp_perf_contract_no_shift_20260507_2307_eda-05`)，全量 RTL
  contracts 通过 `53/53`
  (`local_debug/vcs_all_contracts_no_shift_20260507_2308_eda-05`)。
- 23:38 CST 针对 `llc_cache_ctrl` 前端展开过重的问题，又把 way-index row helper
  从显式 `WAY_COUNT` 循环改成 indexed part-select/bit-select，包括 `extract_line`、
  `extract_meta`、`place_line_in_row`、`place_meta_in_row` 和 `way_onehot`。该修改
  不改变功能或 cycle，只减少 Presto 展开的嵌套循环规模。验证结果：LLC hit-only
  perf contract 通过
  (`local_debug/vcs_cpp_llc_hit_perf_contract_indexed_way_20260507_2340_eda-05`)，
  bounded perf contract 通过
  (`local_debug/vcs_cpp_perf_contract_indexed_way_20260507_2341_eda-05`)，全量 RTL
  contracts 通过 `53/53`
  (`local_debug/vcs_all_contracts_indexed_way_20260507_2342_eda-05`)。
- 00:35 CST 继续清理 `llc_cache_ctrl` MSHR group staging：去掉
  `mshr_commit_group_*` / `mshr_issue_group_*` 宽 payload staging 寄存器的 reset，以及
  无效期 `mshr_commit_refill_line_payload_r` / `mshr_issue_req_wdata_r` /
  `mshr_refill_line_r` 的清零。它们都由状态机 valid/state 保护，使用前会被写入，
  因此该修改不改变可见功能或 cycle，只减少 DC reset process 中的宽清零网络。
  验证结果：LLC hit-only perf contract 通过
  (`local_debug/vcs_cpp_llc_hit_perf_contract_mshr_group_no_reset_20260508_0035_eda-05`)，
  bounded perf contract 通过
  (`local_debug/vcs_cpp_perf_contract_mshr_group_no_reset_20260508_0036_eda-05`)，全量
  RTL contracts 通过 `53/53`
  (`local_debug/vcs_all_contracts_mshr_group_no_reset_20260508_0037_eda-05`)。
- 01:45 CST 继续做一处不改 cycle 的 `llc_cache_ctrl` cleanup：`mem_resp_id`
  匹配 MSHR 从 32-entry 组合扫描改为 range-guarded direct slot lookup，并把同
  cacheline hazard 比较改为高位 line key 比较，减少重复 `line_align_addr()` 拼接/
  比较。range guard 使用嵌套 `if`，避免 out-of-range ID 在同一条件表达式中索引
  MSHR 数组。该修改不改变 LLC hit 响应路径；验证结果：LLC hit-only perf contract 通过
  (`local_debug/vcs_cpp_llc_hit_perf_contract_mshr_direct_resp_guard_20260508_0145_eda-05`)，
  bounded perf contract 通过
  (`local_debug/vcs_cpp_perf_contract_mshr_direct_resp_guard_20260508_0145_eda-05`)，全量
  RTL contracts 通过 `53/53`
  (`local_debug/vcs_all_contracts_mshr_direct_resp_guard_20260508_0145_eda-05`)。
- 03:13 CST 回滚此前让 `llc_cache_ctrl` DC elaborate 明显变慢的
  `mshr_commit_group_*` / `mshr_issue_group_*` staging，恢复直接 MSHR slot 访问；
  保留 range-guarded response lookup、line-key hazard compare 和无效 payload 不清零。
  该修改不影响 LLC hit 路径，并把 clean read miss/refill 的额外延迟从 `+7`
  降到 `+2` cycle。验证结果：LLC hit-only perf contract 通过
  (`local_debug/vcs_cpp_llc_hit_perf_contract_mshr_direct_no_group_20260508_0311_eda-05`)，
  bounded perf contract 通过
  (`local_debug/vcs_cpp_perf_contract_mshr_direct_no_group_20260508_0312_eda-05`)，全量
  RTL contracts 通过 `53/53`
  (`local_debug/vcs_all_contracts_mshr_direct_no_group_20260508_0313_eda-05`)。
- 03:34 CST 针对 `bridge_dual` 做 MMIO bridge 结构裁剪：合法 MMIO 只有 4B/1 beat，
  因此 MMIO 子 bridge 改为 `LINE_BITS=32/LINE_BYTES=4`，只接低 32-bit data 与
  4-bit strobe，避免保留不必要的 512-bit pending payload 队列。验证结果：LLC
  hit-only perf contract 通过
  (`local_debug/vcs_cpp_llc_hit_perf_contract_mmio_slim_20260508_0332_eda-05`)，
  bounded perf contract 通过
  (`local_debug/vcs_cpp_perf_contract_mmio_slim_20260508_0333_eda-05`)，全量 RTL
  contracts 通过 `53/53`
  (`local_debug/vcs_all_contracts_mmio_slim_20260508_0334_eda-05`)。
- 03:56 CST 针对 `llc_cache_ctrl` 做 MSHR flag cleanup：1-bit 状态表改为 packed
  bit-vector，减少 DC 对小 flag memory 的展开压力，不改变 payload 存储、slot 语义或
  LLC hit cycle。验证结果：LLC hit-only perf contract 通过
  (`local_debug/vcs_cpp_llc_hit_perf_contract_mshr_flags_packed_20260508_035620_eda-05`)，
  仍为 `ready=0/resp=7/no external`；bounded perf contract 通过
  (`local_debug/vcs_cpp_perf_contract_mshr_flags_packed_20260508_035655_eda-05`)，
  clean read miss/refill 仍为 `+2` cycle，direct/overlap 最大额外延迟仍为 `+5`；
  全量 RTL contracts 通过 `53/53`
  (`local_debug/vcs_all_contracts_mshr_flags_packed_20260508_035850_eda-05`)。
- 04:23 CST 继续把 `llc_cache_ctrl` 剩余 MSHR 多 bit payload 表改为 flat packed
  vector，使用 slice macro 访问各 slot，仍保持生产 RTL 同一份语义。验证结果：
  LLC hit-only perf contract 通过
  (`local_debug/vcs_cpp_llc_hit_perf_contract_mshr_flat_packed_20260508_042114_eda-05`)，
  仍为 `ready=0/resp=7/no external`；bounded perf contract 通过
  (`local_debug/vcs_cpp_perf_contract_mshr_flat_packed_20260508_042150_eda-05`)，
  clean read miss/refill 仍为 `+2` cycle，direct/overlap 最大额外延迟仍为 `+5`；
  全量 RTL contracts 通过 `53/53`
  (`local_debug/vcs_all_contracts_mshr_flat_packed_20260508_042325_eda-05`)。
- 04:44 CST 因 flat packed cache_ctrl-only DC 仍长期停在 `elaborate_start`，进一步将
  MSHR pending/victim hazard scan、issue/commit priority scan、write-hit victim update
  mask 拆为生产 RTL helper，状态仍在 `llc_cache_ctrl` 中。验证结果：LLC hit-only perf
  contract 通过
  (`local_debug/vcs_cpp_llc_hit_perf_contract_mshr_helper_scan_20260508_0448_eda-05`)，
  bounded perf contract 通过
  (`local_debug/vcs_cpp_perf_contract_mshr_helper_scan_20260508_0450_eda-05`)，全量 RTL
  contracts 通过 `53/53`
  (`local_debug/vcs_all_contracts_mshr_helper_scan_20260508_0450_eda-05`)。
- 05:14 CST 又把写命中路径的 `merge_line()` 结果预先计算为 `write_hit_merged_line_w`，
  `install_line_r` 与所有需要 snapshot 的 MSHR victim entry 复用同一结果，避免在
  32-entry MSHR 更新循环中重复展开同一个组合函数。验证结果：LLC hit-only perf
  contract 通过
  (`local_debug/vcs_cpp_llc_hit_perf_contract_mshr_helper_merge_reuse_20260508_0514_eda-05`)，
  bounded perf contract 通过
  (`local_debug/vcs_cpp_perf_contract_mshr_helper_merge_reuse_20260508_0514_eda-05`)，全量
  RTL contracts 通过 `53/53`
  (`local_debug/vcs_all_contracts_mshr_helper_merge_reuse_20260508_0515_eda-05`)。
- 06:00 CST 根据 DC 历史对照，回退 way helper 中的 variable indexed part-select/
  bit-select，恢复显式 `WAY_COUNT` 循环形式，以避开 DC 前端展开过慢；MSHR helper 与
  `merge_line()` 复用保持不变。验证结果：LLC hit-only perf contract 通过
  (`local_debug/vcs_cpp_llc_hit_perf_contract_mshr_helper_loop_way_20260508_0600_eda-05`)，
  bounded perf contract 通过
  (`local_debug/vcs_cpp_perf_contract_mshr_helper_loop_way_20260508_0601_eda-05`)，全量
  RTL contracts 通过 `53/53`
  (`local_debug/vcs_all_contracts_mshr_helper_loop_way_20260508_0601_eda-05`)。
- 07:39 CST 针对 `axi_llc_axi_bridge` 做 slot-free cleanup：释放 read/write pending
  slot 时只清必要控制位，不再清已经由 `valid` gate 保护的地址、ID、size、beat count
  等 payload 小字段，减少动态索引清零 mux。验证结果：LLC hit-only perf contract
  通过
  (`local_debug/vcs_cpp_llc_hit_perf_contract_bridge_slot_free_cleanup_20260508_073937_eda-05`)，
  bounded perf contract 通过
  (`local_debug/vcs_cpp_perf_contract_bridge_slot_free_cleanup_20260508_074023_eda-05`)，
  全量 RTL contracts 通过 `53/53`
  (`local_debug/vcs_all_contracts_bridge_slot_free_cleanup_20260508_074104_eda-05`)。
- 08:19 CST 在继续 DC setup 收敛前重新跑当前工作树 hit-only 基线：
  `local_debug/vcs_cpp_llc_hit_perf_contract_recheck_20260508_081908_eda-05`
  通过，仍为 `PERF LLC_HIT_READ64 CHECKED ready=0 resp=7 external=-1`。
- 08:23 CST 重新跑当前工作树 bounded performance contract：
  `local_debug/vcs_cpp_perf_contract_recheck_20260508_082335_eda-05` 通过，
  `LLC_MISS_READ64` 仍为 `+2` cycle，direct/overlap 最大额外延迟仍为 `+5`
  cycle，未放宽既有上限。
- 08:29 CST 针对 `axi_llc_axi_pending_scan` 做 slot-ID mode cleanup：当
  `AXI_ID_COUNT >= ENTRY_COUNT` 时，pending slot index 本身作为 AXI ID，allocation
  直接返回 free slot，response match 直接比较 `match_axi_id == slot`，避免额外
  first-free-ID scan 和 stored-ID priority match；ID 空间小于 entry 数时仍保留原
  tracked-ID fallback。验证结果：`formal/axi_pending_scan/run_hw_cbmc.sh` 通过；
  hit-only perf contract
  `local_debug/vcs_cpp_llc_hit_perf_contract_slot_id_scan_20260508_082944_eda-05`
  通过，仍为 `PERF LLC_HIT_READ64 CHECKED ready=0 resp=7 external=-1`；
  bounded perf contract
  `local_debug/vcs_cpp_perf_contract_slot_id_scan_20260508_083014_eda-05` 通过，
  仍为 `max_extra_observed=5` 且 LLC miss `+2`；全量 RTL contracts
  `local_debug/vcs_all_contracts_slot_id_scan_20260508_083103_eda-05` 通过
  `53/53`。
- 09:35 CST 针对 4B/4B single-beat helper fast path cleanup 重新验证当前 RTL：
  `formal/axi_mode2_shape_single4/run_hw_cbmc.sh`、
  `formal/axi_write_pack_single4/run_hw_cbmc.sh`、`formal/axi_read_pack_single4/run_hw_cbmc.sh`
  均通过，并已纳入 stable manifest；生产宽度 pack formal 也复跑通过，其中
  `formal/axi_read_pack_prod_width/run_hw_cbmc.sh` 默认 timeout 调整为 180s 以避免
  solver 输出成功后被 120s wrapper 杀掉。随后又把 `axi_llc_axi_write_pack.v`
  的 4B fast path 从 procedural constant-if 改为 generate-isolated branch，以便 DC
  不再在 4B 实例中构建 generic packer；相关 write-pack formal 再次通过。VCS hit-only
  perf contract
  `local_debug/vcs_cpp_llc_hit_perf_contract_single4_generate_retry_20260508_100142_eda-05` 通过，
  仍为 `PERF LLC_HIT_READ64 CHECKED ready=0 resp=7 external=-1`；bounded perf
  contract `local_debug/vcs_cpp_perf_contract_single4_generate_retry_20260508_100153_eda-05`
  通过，`LLC_MISS_READ64` 仍为 `+2` cycle，direct/overlap 最大额外延迟仍为
  `+5` cycle；全量 RTL contracts
  `local_debug/vcs_all_contracts_single4_generate_20260508_100218_eda-05` 通过 `53/53`。

## 结论

当前功能 EC 可以继续作为 correctness 证据，但不能声称 RTL 所有路径的 cycle 已经达到
C++ 模拟器逐事件预测。当前 LLC hit read64 已经闭合到
`ready=0/resp=7/no external`；最新 `slot_payload` bounded gate 中，MODE_CACHE
clean read miss/refill 的 RTL upstream response 比 C++ 晚 `+4` cycle，DDR
`AR/R` 比 C++ 晚 `+3` cycle；MODE_OFF direct DDR/MMIO microbench 上，RTL 仍比 C++
多出 1-5 cycle，尤其 read response 侧比 C++ 更慢。按当前目标，这些非 hit 差异已被
记录为 bounded performance cost：direct path 上限 6 cycle，LLC miss/refill 上限
8 cycle，当前最大观测额外延迟为 5 cycle。

短期下一步应继续做小模块 DC setup 收敛，而不是继续放宽 performance gate：

- 2026-05-11 版本已经不再等待小模块全部完成后才启动 top；当前已并行运行
  `compat` quick-map、`full_top` quick-map 和 `full_top` 1GHz full compile，以便尽早
  获得 top setup 趋势和最终 postcompile 证据。若 quick-map 或 full compile 给出真实
  violating endpoint，再按 endpoint 做 targeted RTL 修复；若只看到 endpoint 为空的
  early mapping cost table，则不据此修改 RTL。
- 当前 `llc_cache_ctrl` 已移除导致 elaborate 变慢的 staging，并将 MSHR flags 与
  payload 表都改为 packed vector；进一步把 MSHR 扫描/选择拆成 helper 层级，并复用
  写命中 `merge_line()` 结果；同时回退 way helper 的 variable indexed part-select。
  当前 medium quick-map 已重新越过 elaborate/link，但在 `Processing llc_cache_ctrl`
  阶段被 1h timeout 杀掉，没有 timing/QoR；low-effort 诊断 quick-map 已启动，用于
  快速判断主要 setup/面积方向。
- `bridge_dual` medium quick-map 已完成 link 并进入 mapping optimization，但 3h37m
  后中间 WNS 仍约 `6.4ns`，4h timeout 后没有最终 timing/QoR；已做 slot-free cleanup
  以及 slot-ID pending-scan cleanup，并启动新的 bridge 诊断 run。注意当前 DC 版本会把
  `compile -map_effort low` 自动按 medium 处理；因此 “low” run 只是命名上的诊断入口，
  不代表真正低努力度。已新增 DDR64/MMIO4 single-bridge probes 来定位底层单桥 setup
  来源；slot-free cleanup 版本和 08:44 CST slot-ID 版本的 bridge probes 在后续
  4B/4B helper fast path RTL 修改后均是 stale；09:51 CST 的 procedural constant-if
  版本 bridge probes 又在 generate-isolated 修改后被手动停止并标记 stale。10:12 CST
  已基于 10:02 CST 复验后的 generate-isolated RTL 重新启动 current-RTL bridge
  DC probes：`bridge_dual_quick_map_low_single4_generate_direct_9t20_20260508_1012_101255_eda-05`、
  `bridge_ddr64_probe_quick_map_low_single4_generate_direct_9t20_20260508_1012_101255_eda-05`、
  `bridge_mmio4_probe_quick_map_low_single4_generate_direct_9t20_20260508_1012_101254_eda-05`。
  早期日志显示 MMIO4 已进入 quick-map，4B write-pack helper 走 generate fast path，
  不再构建旧 single4 generic byte-loop；仍需等待最终 timing/QoR。
- `bridge_dual`、`cache_ctrl`/`core`、`compat` 等小模块 setup 证据仍然有助于定位
  top violation，但它们不再阻塞当前这一轮 full_top DC；旧 full_top baseline 不能替代
  当前 `slot_payload` RTL 的 final top timing。
- 2026-05-08 10:22 CST 已补开 `llc_cache_ctrl` current-RTL low quick-map probe，并
  新增 `rtl/dc/probes/core_only.f` / `rtl/dc/probes/compat_only.f` 作为后续 core/compat
  current-RTL setup probe 入口。当前这些入口还没有最终 timing/QoR，因此不能把
  小模块 setup 视作整体收敛。

## 后续扩展

当前 diagnostic 已覆盖 LLC hit、clean read miss/refill、direct DDR/MMIO 和 overlap
代表场景。后续如果要形成更完整 performance contract，还需要继续添加：

- dirty victim writeback latency。
- same-line hazard blocked cycle。
- 32 read outstanding / 32 write outstanding 的 steady-state issue throughput。
- maintenance pending 对 DDR/MMIO lower response 的额外 stall cycle。

这些扩展仍应保持 testbench-only，直到明确要改 production C++/RTL cycle model。
