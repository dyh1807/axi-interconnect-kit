# 当前 1GHz Setup 收敛状态

更新时间：2026-05-14 14:35 CST。

## 当前目标 Gate

| 要求 | 当前证据 | 状态 |
| --- | --- | --- |
| LLC hit C++/RTL cycles 必须精确对齐 | `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_payload_circular_20260512_234630_eda-05/run.log` 显示 `PERF LLC_HIT_READ64 CHECKED ready=0 resp=7 external=-1`、`PERF LLC_HIT_WRITE64 CHECKED ready=1 resp=9 external=-1` 和 `PASS LLC_HIT_ONLY`；该日志对应当前 `payload_circular` RTL | 已满足，后续相关输入改动必须重跑 |
| LLC miss / 非 hit 允许 bounded 协议/性能差距 | `rtl/local_debug/vcs_cpp_perf_contract_payload_circular_20260512_234659_eda-05/run.log` 显示 `PASS bounded_non_hit max_extra_observed=5 direct_max_extra_allowed=6 llc_miss_max_extra_allowed=8`；该日志对应当前 `payload_circular` RTL | 已满足当前 bounded gate |
| 当前 RTL 功能回归 | `rtl/local_debug/vcs_all_contracts_payload_circular_20260512_234723_eda-05.wrapper.log` 汇总为 `SUMMARY total=53 passed=53 failed=0`，未见 FAIL/ERROR/MISMATCH | 已满足 |
| parent simulator large+BPU Linux smoke / 性能 sanity | `rtl/dc/check_goal_gate.sh` 21:13 CST 输出 `LINUX_SANITY status=PASS reason=large_bpu_300k_5m_success_perf_within_recorded_bounds`；该项复用 `../local_logs/goal_llc_hit_dc_20260511/` 下已记录的 300k/5M large+BPU smoke | 已满足；性能仍在已记录容忍范围内 |
| DC source freshness | `.latest_full_compile_1g` 指向 source-fresh 的 eda-10 retry：`full_compile_1g_payload_circular_oom_retry72h_9t20_20260513_200542_eda-10`；`source_status.txt` 记录当前综合 RTL 和 DC Tcl SHA256 | 已满足；21:13 CST gate 输出 `PASS reason=all_active_dc_runs_match_current_synth_inputs_and_dc_scripts` |
| DC run liveness | completion gate 默认以 `.latest_full_compile_1g` 作为 signoff active marker；eda-10 retry 已正常结束，`exit_code.txt=0`；log 显示 `compile_done 2026-05-14 13:38:43`、`reports_done 13:44:24`、`write_done 13:46:39`，DC session CPU time 约 `17.53 hours`，memory 约 `10190 Mbytes` | 已满足；14:30 CST gate 输出 `PASS reason=active_runs_alive_or_have_final_qor_and_timing` |
| current RTL 1GHz setup 收敛 | eda-10 retry 已写出 postcompile QoR/timing。`axi_llc_subsystem_dual_postcompile_1g_qor.rpt` 显示 Critical Path Slack `0.00`、TNS `0.00`、violating paths `0.00`、Cell Area `9446885.041434`；`axi_llc_subsystem_dual_postcompile_1g_timing.rpt` 有 `slack (MET) 0.00` 且无 `slack (VIOLATED)` | 已满足；14:30 CST `DC_SETUP PASS reason=signoff_full_compile_setup_pass` |
| SRAM macro link / netlist 保留可信度 | eda-10 retry 的 `link.rpt` 已确认 data SRAM `sassls0c4l1p4096x256.../ssgs_ccw0p72v125c/*.db` 和 meta SRAM `sassls0c4l1p4096x16.../ssgs_ccw0p72v125c/*.db`；final netlist `outputs/netlist/axi_llc_subsystem_dual_postcompile_1g.v` 保留 data macro refs `64`、meta macro refs `32`，未见 generic/DW/stub memory refs | 已满足；14:30 CST `DC_MACRO_BINDING PASS reason=db_linked_and_signoff_netlist_keeps_macros` |
| 9T20 标准单元库绑定 | eda-10 retry 的 `link.rpt` 已确认 9T20 RVT/LVT 标准单元库并未链接 7p5t：`scc12nsfe_90sdb_9tc20_rvt_ssg_v0p72_-40c_ccs.db`、`scc12nsfe_90sdb_9tc20_lvt_ssg_v0p72_-40c_ccs.db` | 已满足；14:30 CST `DC_LIBRARY_BINDING PASS reason=all_active_runs_link_9t20_rvt_lvt_and_no_7p5t` |

22:19 CST 补充：`dc_1h_20260513_211618` one-shot 检查已完成。当前 monitor 的
`LOG_HEALTH` 显示 full_top run `ERROR_FATAL_SUMMARY count=0`，warning 主要是
`VER-318` / `ELAB-311` / `UISN-40`，并记录到 `resp_rdata_r_reg`、
`resp_data_r_reg`、`rd_resp_q_pool_idx_reg` 等常量寄存器删除；这些是后续若 setup
失败时可复查的结构线索，但不替代 postcompile signoff。

22:24 CST 已安排下一次低频 one-shot 检查 `dc_1h_20260513_222404`，PID `3635748`，
计划在 23:24 CST 左右触发。

23:27 CST 补充：`dc_1h_20260513_222404` one-shot 检查已完成。当前 full_top
`LOG_HEALTH` 仍为 `ERROR_FATAL_SUMMARY count=0`，stage 已从 `Beginning Pass 1 Mapping`
推进到 `Mapping Optimization (Phase 2)`。常量删除热点进一步显示
`compat/rd_resp_pool_data_c{1,2,3}_reg` 各 `16384` 位、`compat/rd_resp_pop_data_r_reg`
和 `compat/rd_resp_data_r_reg` 各 `6144` 位等；这些只作为后续失败时的结构复查线索，
当前不据此修改 RTL。

23:28 CST 已安排下一次低频 one-shot 检查 `dc_1h_20260513_232847`，PID `3968764`，
计划在 00:28 CST 左右触发。

2026-05-14 00:31 CST 补充：`dc_1h_20260513_232847` one-shot 检查已完成。当前
full_top `LOG_HEALTH` 仍为 `ERROR_FATAL_SUMMARY count=0`，stage 已推进到
`Mapping Optimization (Phase 5)`，但仍缺 postcompile QoR/timing 和 final netlist。

00:33 CST 已安排下一次低频 one-shot 检查 `dc_1h_20260514_003321`，PID `79600`，
计划在 01:33 CST 左右触发。

01:36 CST 补充：`dc_1h_20260514_003321` one-shot 检查已完成。当前 full_top
`LOG_HEALTH` 仍为 `ERROR_FATAL_SUMMARY count=0`，stage 已推进到
`Mapping Optimization (Phase 6)`，仍缺 postcompile QoR/timing 和 final netlist。

01:38 CST 已安排下一次低频 one-shot 检查 `dc_1h_20260514_013837`，PID `291794`，
计划在 02:38 CST 左右触发。

02:43 CST 补充：`dc_1h_20260514_013837` one-shot 检查已完成。当前 full_top 仍缺
postcompile QoR/timing 和 final netlist；但远端 `ps` 显示 DC 主进程仍在运行态且占用
CPU，内存余量充足，不是 OOM 或静止卡死。log tail 显示仍在 `Mapping Optimization
(Phase 6)`，并可见 `compat` 约 `544732` inst 的 ungroup/优化工作，因此继续低频等待。

02:43 CST 已安排下一次低频 one-shot 检查 `dc_1h_20260514_024354`，PID `612535`，
计划在 03:43 CST 左右触发。

03:46 CST 补充：`dc_1h_20260514_024354` one-shot 检查已完成。当前 full_top
`LOG_HEALTH` 仍为 `ERROR_FATAL_SUMMARY count=0`，stage 已推进到
`Mapping Optimization (Phase 7)`，仍缺 postcompile QoR/timing 和 final netlist。

03:48 CST 已安排下一次低频 one-shot 检查 `dc_1h_20260514_034802`，PID `941010`，
计划在 04:48 CST 左右触发。

04:51 CST 补充：`dc_1h_20260514_034802` one-shot 检查已完成。当前 full_top 仍缺
postcompile QoR/timing 和 final netlist；stage 仍为 `Mapping Optimization (Phase 7)`。
虽然 `launcher.log` mtime 停在 `03:04:35`，但远端 `ps` 显示 DC 主进程仍为运行态且
CPU 约 `80.7%`，内存余量充足，因此不是 OOM 或静止卡死。

04:52 CST 已安排下一次低频 one-shot 检查 `dc_1h_20260514_045234`，PID `1274562`，
计划在 05:52 CST 左右触发。

05:54 CST 补充：`dc_1h_20260514_045234` one-shot 检查已完成。当前 full_top
`LOG_HEALTH` 仍为 `ERROR_FATAL_SUMMARY count=0`，stage 已推进到
`Mapping Optimization (Phase 8)`，仍缺 postcompile QoR/timing 和 final netlist。

05:56 CST 已安排下一次低频 one-shot 检查 `dc_1h_20260514_055636`，PID `1603772`，
计划在 06:56 CST 左右触发。

06:58/07:03 CST 补充：`dc_1h_20260514_055636` one-shot 检查已完成。当前 full_top
仍缺 postcompile QoR/timing 和 final netlist；`DC_SETUP` 仍为
`WAIT reason=missing_signoff_postcompile_qor`。latest stage 仍为
`Mapping Optimization (Phase 8)`，`LOG_HEALTH` 仍为 `ERROR_FATAL_SUMMARY count=0`。
07:03 CST 远端 `ps` 显示 eda-10 DC 主进程仍在运行态，CPU 约 `84.5%`、RSS 约
`9.94GB`，available memory 约 `742GiB`；swap 已满但物理内存余量充足，因此当前不按
OOM/卡死处理。

07:03 CST 已安排下一次低频 one-shot 检查 `dc_1h_20260514_070334`，PID `1949994`，
计划在 08:03 CST 左右触发。

07:05 CST 抽查当前 signoff run 的 `reports/link.rpt`：标准单元库为
`scc12nsfe_90sdb_9tc20_rvt_ssg_v0p72_-40c_ccs.db` 和
`scc12nsfe_90sdb_9tc20_lvt_ssg_v0p72_-40c_ccs.db`，未见 7p5t；SRAM DB 为
data `sassls0c4l1p4096x256m4b4w1c1p0d0t0s2sdz1rw00/ssgs_ccw0p72v125c` 和
meta `sassls0c4l1p4096x16m16b1w1c1p0d0t0s2sdz1rw00/ssgs_ccw0p72v125c`。

08:05/08:07 CST 补充：`dc_1h_20260514_070334` one-shot 检查已完成。当前 full_top
仍缺 postcompile QoR/timing 和 final netlist；`DC_SETUP` 仍为
`WAIT reason=missing_signoff_postcompile_qor`。latest stage 已推进到
`Mapping Optimization (Phase 9)`，`LOG_HEALTH` 仍为 `ERROR_FATAL_SUMMARY count=0`。
08:06 CST 远端 `ps` 显示 eda-10 DC 主进程仍在运行态，CPU 约 `85.8%`、RSS 约
`10.55GB`，available memory 约 `934GiB`。`outputs/axi_llc_subsystem_dual.svf`
mtime 已更新到 07:59 CST，但 `reports/` 仍只有 link/post-link/precompile 报告。

08:07 CST 已安排下一次低频 one-shot 检查 `dc_1h_20260514_080702`，PID `2274529`，
计划在 09:07 CST 左右触发。

09:09/09:11 CST 补充：`dc_1h_20260514_080702` one-shot 检查已完成。当前 full_top
仍缺 postcompile QoR/timing 和 final netlist；`DC_SETUP` 仍为
`WAIT reason=missing_signoff_postcompile_qor`。latest stage 仍为
`Mapping Optimization (Phase 9)`，`LOG_HEALTH` 仍为 `ERROR_FATAL_SUMMARY count=0`。
09:10 CST 远端 `ps` 显示 eda-10 DC 主进程仍在运行态，CPU 约 `86.9%`、RSS 约
`10.56GB`，available memory 约 `934GiB`。`outputs/axi_llc_subsystem_dual.svf`
mtime 已更新到 09:01 CST，但 `reports/` 仍只有 link/post-link/precompile 报告。

09:10 CST 已安排下一次低频 one-shot 检查 `dc_1h_20260514_091051`，PID `2599608`，
计划在 10:10 CST 左右触发。

10:13/10:14 CST 补充：`dc_1h_20260514_091051` one-shot 检查已完成。当前 full_top
仍缺 postcompile QoR/timing 和 final netlist；`DC_SETUP` 仍为
`WAIT reason=missing_signoff_postcompile_qor`。latest stage 已从 `Mapping Optimization
(Phase 9)` 推进到 `Beginning Constant Register Removal` / `Beginning Global
Optimizations`，`LOG_HEALTH` 仍为 `ERROR_FATAL_SUMMARY count=0`。10:13 CST 远端
`ps` 显示 eda-10 DC 主进程仍在运行态，CPU 约 `87.9%`、RSS 约 `10.56GB`，
available memory 约 `934GiB`。`outputs/axi_llc_subsystem_dual.svf` mtime 已更新到
09:56 CST，但 `reports/` 仍只有 link/post-link/precompile 报告。

10:13 CST 已安排下一次低频 one-shot 检查 `dc_1h_20260514_101338`，PID `2914571`，
计划在 11:13 CST 左右触发。

11:15/11:17 CST 补充：`dc_1h_20260514_101338` one-shot 检查已完成。当前 full_top
仍缺 postcompile QoR/timing 和 final netlist；`DC_SETUP` 仍为
`WAIT reason=missing_signoff_postcompile_qor`。latest stage 已推进到 `Beginning
Delay Optimization` / `Beginning WLM Backend Optimization`，`LOG_HEALTH` 仍为
`ERROR_FATAL_SUMMARY count=0`。11:17 CST 远端 `ps` 显示 eda-10 DC 主进程仍在运行态，
CPU 约 `88.7%`、RSS 约 `10.56GB`，available memory 约 `934GiB`。`reports/` 仍只有
link/post-link/precompile 报告。

11:17 CST 已安排下一次低频 one-shot 检查 `dc_1h_20260514_111721`，PID `3235480`，
计划在 12:17 CST 左右触发。

12:19/12:21 CST 补充：`dc_1h_20260514_111721` one-shot 检查已完成。当前 full_top
仍缺 postcompile QoR/timing 和 final netlist；`DC_SETUP` 仍为
`WAIT reason=missing_signoff_postcompile_qor`。latest stage 已推进到 `Beginning
Design Rule Fixing  (max_transition)  (max_capacitance)` / `Beginning Leakage Power
Optimization  (max_leakage_power 0)`，`LOG_HEALTH` 仍为 `ERROR_FATAL_SUMMARY count=0`。
12:20 CST 远端 `ps` 显示 eda-10 DC 主进程仍在运行态，CPU 约 `89.4%`、RSS 约
`10.56GB`，available memory 约 `912GiB`。`outputs/axi_llc_subsystem_dual.svf`
mtime 已更新到 12:02 CST，但 `reports/` 仍只有 link/post-link/precompile 报告。

12:21 CST 已安排下一次低频 one-shot 检查 `dc_1h_20260514_122110`，PID `3453949`，
计划在 13:21 CST 左右触发。

13:23/13:28 CST 补充：`dc_1h_20260514_122110` one-shot 检查已完成。当前 full_top
仍缺 postcompile QoR/timing 和 final netlist；`DC_SETUP` 仍为
`WAIT reason=missing_signoff_postcompile_qor`。latest stage 已推进到
`Beginning Delay Optimization HSVT Pass`，`LOG_HEALTH` 仍为
`ERROR_FATAL_SUMMARY count=0`。13:28 CST 远端 `ps` 显示 eda-10 DC 主进程仍在运行态，
CPU 约 `90.1%`、RSS 约 `10.57GB`，available memory 约 `896GiB`。compile log
中间表显示 setup cost `0.0`、design rule cost `0.0`，这是有利趋势，但在
`reports/` 仍只有 link/post-link/precompile 报告时不能作为 signoff。

13:35 CST 只读解析 compile log 中间优化表：表头里的 `WORST NEG SLACK` 是 violation
magnitude，数值 `0.00` 才表示当前优化阶段没有 setup violation。当前 run 在 delay
optimization 末期曾从 `0.67` / `0.31` / `0.21` / `0.18` 逐步修到 `0.00`；
design rule fixing 又把 design rule cost 从 `7.8` 修到 `0.0`。随后 leakage power
optimization 一度把 violation magnitude 拉回到约 `0.97`，再由 `Beginning Delay
Optimization HSVT Pass` 逐步修到 `0.00`，最终中间表显示 setup cost `0.0`、design
rule cost `0.0`。因此当前趋势比旧 full_top `-0.10ns` signoff 更乐观，但仍必须等
postcompile QoR/timing 和 final netlist 才能判定目标收敛。

13:30 CST 已安排下一次低频 one-shot 检查 `dc_1h_20260514_133022`，PID `3745823`，
计划在 14:30 CST 左右触发。

14:30/14:35 CST 最终复查：`dc_1h_20260514_133022` one-shot 检查已完成，current
full_top signoff run 已正常结束。`rtl/dc/check_goal_gate.sh` 输出 `GOAL status=PASS`，
`BLOCKERS none`。final QoR/timing 为 WNS `0.00`、TNS `0.00`、violating paths `0`；
final timing report 含 `slack (MET) 0.00` 且无 `slack (VIOLATED)`。final netlist 已
写出并保留 data SRAM macro refs `64`、meta SRAM macro refs `32`；DDC、Verilog
netlist、SDC、SDF、SPF 均已生成。hold 仍有 violation（Worst Hold Violation `-0.13`、
hold violating paths `16834`），按当前目标口径不作为 setup 收敛 blocker。

## 下一份 DC Report 判定动作表

| 新证据 | 判定 | 下一步 |
| --- | --- | --- |
| `compat_quick_map_low` 生成 final QoR/timing 且 WNS/TNS/violating paths 通过 | compat 层趋势基本解除 | 不改 RTL，继续等待 72h full_top postcompile；只把 compat 结果记录为 supporting evidence |
| `compat_quick_map_low` 生成 final QoR/timing 且仍失败，主路径仍是 `compat_rr_ptr` / `compat_direct_rr_ptr` 到 stage/payload | 当前 10:50 direct/core payload 展开还不够 | 先分析 final timing endpoint，再考虑继续拆 compat dispatch 或增加不影响 LLC-hit exact cycles 的 staging；改 RTL 后必须重跑 LLC-hit、bounded non-hit、53 contracts，并重开 DC |
| `compat_quick_map_low` 失败但主路径转移到 bridge/hazard 或 refill-response | 旧 top80 残余路径成为新瓶颈 | 优先按 13:05 记录的候选方向修：AW issue/line tag 预寄存或 cache refill response staging；修改前确认不会破坏 AXI no-R-backpressure/LLC-hit exact cycles |
| 72h full_top 完成 link，macro/library gate 变 PASS | 配置可信度恢复 | 继续等待 precompile/postcompile；不要把 link pass 当 setup 收敛 |
| 72h full_top 只有 precompile `+0.33ns` 或其它正 slack | 仅趋势 | 继续等待 postcompile；precompile 不能作为 completion evidence |
| 72h full_top postcompile setup PASS，且 final timing 无 `slack (VIOLATED)` | setup 基本满足 | 继续检查 final netlist 是否保留 data/meta SRAM macro refs；随后执行 goal completion audit |
| 72h full_top postcompile setup FAIL | goal 未完成 | 按 final timing top endpoints 分类，优先修占比最高且与 LLC-hit cycles 不冲突的路径；修后重跑功能/性能 gate 和新的 source-fresh DC |
| 72h full_top 被 timeout/OOM/fatal 提前结束 | 无 signoff 结论 | 保留 log，定位资源/脚本原因后重开；不能用旧 12h 或 precompile 替代 |

## Completion Checklist（历史记录）

本节以下内容保留为 direct-pop / 早期 72h run 迭代的历史审计记录。当前
`payload_circular` RTL 的权威完成判定以上方“当前目标 Gate”和
`rtl/dc/goal_completion_audit_CN.md` 顶部“当前有效审计”为准。

当前 goal 的可验收交付物拆成以下八项，必须全部满足后才能标记 complete：

| 交付物 / 明确要求 | 实际 artifact / 命令 | 当前判定 |
| --- | --- | --- |
| `LLC hit` 必须和 C++ reference 性能/cycles 精确对齐 | `rtl/run_cpp_llc_hit_perf_contract.sh` 生成 `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_direct_pop_predecode_clean_20260512_1050_eda-05/run.log`；检查 read hit `ready=0 resp=7 external=-1`、write hit `ready=1 resp=9 external=-1` | PASS |
| `LLC miss` 和非 hit 场景允许协议/约束对齐，性能差距不能无界 | `rtl/run_cpp_perf_contract.sh` 生成 `rtl/local_debug/vcs_cpp_perf_contract_direct_pop_predecode_clean_20260512_1050_eda-05/run.log`；检查 `LLC_MISS_READ64 ready=0 ar=8 r0=10 r1=11 resp=18` 和 `max_extra_observed=5 <= 8` | PASS |
| 当前 RTL 功能 contract 不能因性能/时序修正退化 | `rtl/local_debug/vcs_all_contracts_second_burst_20260512_233702_eda-05` 共 53 个 `run.log`，无 `FAIL/ERROR/MISMATCH`；`tb_axi_llc_subsystem_compat_direct_bypass_contract` 覆盖连续 bypass write，以及队列 drain 后 head/tail 非零时的第二轮 payload/address/wstrb/response 顺序检查 | PASS |
| C++ production response-boundary 修改不能破坏 parent simulator Linux 行为或造成显著性能衰退 | `make PROFILE=large BUILD_DIR=build_goal_llc_hit_large_bpu_20260511 EXTRA_CXXFLAGS=-DCONFIG_BPU -j8` 后运行 `AXI_SUBMODULE_MODE=1 ./build_goal_llc_hit_large_bpu_20260511/simulator --max-commit 300000 ../img/linux.bin` 和 `--max-commit 5000000`；日志分别为 `local_logs/goal_llc_hit_dc_20260511/linux_large_bpu_mode1_300k_after_cpp_resp_boundary_20260511_071015.log`、`local_logs/goal_llc_hit_dc_20260511/linux_large_bpu_mode1_5m_after_cpp_resp_boundary_20260511_071224.log` | PASS，300k cycle +0.55%、IPC -0.55%；5M cycle -0.77%、IPC +0.78%；无 Difftest/abort/deadlock |
| DC final report 必须对应当前可综合 RTL 和 DC 脚本 | `rtl/dc/check_goal_gate.sh` 默认检查 signoff active marker `.latest_full_compile_1g` 的 `source_status.txt`，要求它覆盖当前 `rtl/src`、`rtl/include`、`rtl/flist` 下所有 `.v/.vh/.f` 综合输入，以及 `rtl/dc/axi_llc_dc_common.tcl` 和入口 `SCRIPT=` Tcl；compat quick/reference 由 summary/decision 脚本单独诊断 | PASS，当前输出 `all_active_dc_runs_match_current_synth_inputs_and_dc_scripts` |
| DC run 在 final report 缺失时必须仍能证明 alive，不能早退失败 | `rtl/dc/check_goal_gate.sh` 默认检查 signoff active marker `.latest_full_compile_1g`：若 final QoR/timing 尚未成对存在，则要求没有 `exit_code.txt`，且 `DC_PID` / `TIMEOUT_PID` / `LAUNCHER_PID` 至少一个仍存活；否则 FAIL | PASS，当前输出 `active_runs_alive_or_have_final_qor_and_timing` |
| DC setup 必须用 current RTL 的 final QoR/timing 判定，而不是 precompile 或 mapping 中间表 | `rtl/dc/check_goal_gate.sh` 汇总三条 active run 的诊断状态，但最终 setup signoff 只由 `.latest_full_compile_1g` 的 `*postcompile_1g_qor.rpt` / `*postcompile_1g_timing.rpt` 判定；要求 WNS 非负、TNS=0、violating paths=0，timing report 有 slack 行且无 `slack (VIOLATED)` | WAIT，仍缺 signoff postcompile QoR |
| DC 必须使用真实 SMIC12 SRAM macro，而不是 generic/table 误综合 | `rtl/dc/check_goal_gate.sh` 的 `DC_MACRO_BINDING` 已检查 signoff run 的 `link.rpt`，确认 data/meta SRAM `.db`；若 signoff full compile setup 通过，还会要求 final netlist 已写出并保留 `sassls0c4l1p4096x256...` / `sassls0c4l1p4096x16...` 引用 | DB link PASS；final netlist macro refs 仍 WAIT |
| DC 必须使用 SMIC12 9T20 标准单元库 | `rtl/dc/check_goal_gate.sh` 的 `DC_LIBRARY_BINDING` 已检查 signoff run 的 `link.rpt`，确认 9T20 RVT/LVT `.db` 且未链接 7p5t 标准单元库 | PASS |

## 阅读说明

2026-05-12 13:00 CST 起的当前权威状态：由于上一轮完成的 full_top 用时约 13h20m，而
12:55 CST 发现当前 full_top/compat quick 是 `timeout 43200` 启动，12h 上限可能提前杀掉
full_top。13:00 CST 已补开同源 72h timeout 的 `.latest_full_compile_1g`
`full_compile_1g_direct_pop_predecode_clean_long72h_9t20_20260512_125943_eda-05`，
并保留旧 12h full_top
`full_compile_1g_direct_pop_predecode_clean_9t20_20260512_105623_eda-05`
继续运行为参考，不杀任何现有进程。13:55 CST 72h run 已完成 elaborate/link：
`LINK_SANITY_PASS`、`SRAM_HIERARCHY_PROTECTED 96`，`link.rpt` 确认 9T20 RVT/LVT
标准单元和 data/meta SRAM `.db` 均来自当前 signoff marker，因此
`DC_MACRO_BINDING` / `DC_LIBRARY_BINDING` 已从 link-pending 变为 PASS。当前仍等待
precompile report 完成和最终 postcompile QoR/timing；不能把 link pass 当 setup pass。

13:08 CST 监控入口更新：`rtl/dc/monitor_dc_status.sh` 的 reference marker 已补充
`rtl/dc/.reference_full_compile_1g_12h_direct_pop_predecode_clean`；当前 monitor 已从旧
PID `313618` 重启为 PID `479667`。`rtl/dc/summarize_dc_reports.sh` 默认 now 同时汇总
`.latest_full_compile_1g`、`.latest_compat_low_probe` 和上述 12h full_top reference，
便于持续对照 72h signoff、compat quick 和旧 12h 参考 run。13:07 CST summarize
确认 72h run 仍无 link/precompile report；compat quick 仍无 final QoR/timing；旧 12h
run 仍只有 precompile `+0.33ns` 趋势。

13:10 CST 复查 compat post-link `report_reference_post_link.rpt`：仍有
`**SEQGEN** 152097`，以及若干 `*SELECT_OP_2.16384_2.1_16384`、
`*SELECT_OP_3.16384_3.1_16384`、`*MUX_OP_32_5_2048` 等 generic operator。该报告
发生在 quick-map final timing 之前，只能作为结构观察项，不能直接判定 setup 是否失败。
这些宽度大致对应 32-slot/512-bit、32-slot/2048-bit 或多 master/slot payload 选择结构；
是否需要继续拆分，必须以后续 compat quick 或 full_top final timing endpoint 为准。

13:16 CST 新增只读判定脚本 `rtl/dc/decide_dc_next_action.sh`。该脚本不调用
Synopsys、不修改 RTL/DC Tcl，只读取 `check_goal_gate.sh`、`.latest_full_compile_1g`、
`.latest_compat_low_probe` 和 12h reference marker，输出 compat quick、72h fulltop
signoff、旧 12h precompile reference 的状态与下一步动作。13:16 CST 实测输出：
compat quick `WAIT missing_quick_map_qor_or_timing`、72h fulltop `WAIT
missing_signoff_qor_or_timing`、旧 12h reference precompile PASS，整体决策为
`overall=WAIT action=wait_for_current_fulltop_postcompile_or_compat_quick_final_report`。
13:18 CST 用旧失败 full_top final report
`full_compile_1g_route_predecode_sram_protect_9t20_20260511_203051_eda-09` 的
`axi_llc_subsystem_dual_postcompile_1g_timing_max80.rpt` 回放该分类逻辑：`70/80`
条归到 `compat_dispatch_or_payload`，`4/80` 条归到 `bridge_or_hazard`，`1/80`
条归到 `refill_response`，剩余 `5/80` 是 DC 生成 `R_*` alias 或其它。该结果与
13:02/13:05 的手工诊断一致，说明该脚本可作为后续 final timing 出来后的第一轮
路径分类入口；真正修 RTL 前仍需查看具体 endpoint 和语义影响。
13:20 CST 增强该脚本输出：每个 run 现在会显示 `launcher.log` mtime、latest stage
和 `exit_code` 状态。当前输出显示 compat quick 在 `Mapping Optimization (Phase 1)`，
72h fulltop 仍停留在 `DC_STAGE elaborate_start 2026-05-12 13:00:11` 后、尚未生成
link/precompile/final report，旧 12h reference 仍在 `Beginning Pass 1 Mapping`。
13:22 CST 继续增强该脚本输出：根据 `run_metadata.txt` 的 `HOST` / `LAUNCHER_PID` /
`TIMEOUT_PID` / `DC_PID` 做每-run liveness 摘要。当前三条 run 均显示 `liveness=alive`；
compat quick 仍为 `Mapping Optimization (Phase 1)`，72h fulltop 仍为
`DC_STAGE elaborate_start`，旧 12h reference 仍为 `Beginning Pass 1 Mapping`。
13:25 CST 将 `rtl/dc/decide_dc_next_action.sh` 集成进 `rtl/dc/monitor_dc_status.sh` 的
`NEXT_ACTION` 段，并重启 monitor。新 monitor PID 为 `526358`；`rtl/dc/dc_status_latest.txt`
已确认包含 `NEXT_ACTION`、compat quick / 72h fulltop / old12 reference 三段以及
`overall=WAIT action=wait_for_current_fulltop_postcompile_or_compat_quick_final_report`。

13:33-13:38 CST 发现长驻 monitor loop 仍可能在单次写完 `dc_status_latest.txt` 后静默
退出，因此新增 `rtl/dc/schedule_dc_check_once.sh`，改用一次性延迟检查：脚本通过
`setsid` 启动独立后台 shell，先 `sleep` 指定秒数，再以 `DC_MONITOR_ONCE=1` 执行一次
`monitor_dc_status.sh` 并退出。`setsid` 版 2 秒 smoke 已通过，
`rtl/dc/dc_status_schedule.log` 显示 `SCHEDULED_CHECK_DONE`，且
`rtl/dc/dc_status_latest.txt` 更新成功。当前已安排 30 分钟后的下一次检查，
PID `560226` 记录在 `rtl/dc/dc_status_schedule.pid`；后续低频轮询优先使用该脚本，
而不是依赖长驻 loop。

13:41 CST 复查 compat quick：`decide_dc_next_action.sh` 已显示
`latest_stage=Mapping Optimization (Phase 2)`，仍无 quick final QoR/timing。post-link
`report_reference_post_link.rpt` 中较大的 generic operator 主要为
`*SELECT_OP_2.512_2.1_512` 共 304 个、`*MUX_OP_32_5_2048` 共 4 个、
`*SELECT_OP_2.16384_2.1_16384` 共 5 个、`*SELECT_OP_3.16384_3.1_16384` 共 4 个、
`*SELECT_OP_2.15872_2.1_15872` 共 9 个，以及少量 8192/2048/1984/1024-bit select。
这仍只是 post-link 结构观察，不作为 setup fail 证据；如果 quick final timing 失败，
优先用 final endpoint 判断是否落在 response-pool payload mux、direct/core write payload
shift、或 dispatch/hazard scan。该轮 log 还显示 `rd_resp_q_pool_idx_reg[*][5:7]`
会被常量删除，原因是 pool count 为 32 而该索引暂存仍声明为 8-bit；这是后续可做的
低风险 RTL 清理项，但当前不提前修改，以免使正在运行的 DC 变 stale。

13:43 CST 复查 72h fulltop：`launcher.log` mtime 已更新，tail 显示仍在
elaborate/build 阶段，已构建到 `llc_cache_ctrl`；目前没有 fatal/OOM，也没有
`link.rpt` / precompile report / postcompile report，`outputs` 下仅有
`axi_llc_subsystem_dual.svf`。当前看到的 `llc_valid_ram.v:77` signedness warning、
`llc_cache_ctrl.v:439/462` unreachable default warning 只作为后续 RTL hygiene
候选项记录，不在本轮 active DC 中途修改。

13:47 CST 修正 `rtl/dc/decide_dc_next_action.sh` 的 timing 分类逻辑：原脚本的
refill-response awk 条件可能漏掉 `mshr_refill_line`，现在已改为显式检查
`cache_rd_rsp*` / `mshr_refill_line`，并把 compat 内部的 `response_pool`、
`write_payload`、`dispatch` 分成不同类别。用旧 top80 timing 回放验证后分类为：
`compat_dispatch 52`、`compat_write_payload 18`、`bridge_or_hazard 4`、
`refill_response 1`、`other 5`。该修改只影响后续报告分类，不改变 RTL/DC 输入。
13:50 CST 将同一套 final timing 分类同步到 `rtl/dc/summarize_dc_reports.sh` 的
`TIMING_PATH_CATEGORIES` 段。旧失败 run 回放显示普通 final timing 报告的 worst path
归到 `compat_dispatch`，`timing_max80.rpt` 分类与 `decide_dc_next_action.sh` 一致。

13:52 CST 新增只读日志健康检查入口 `rtl/dc/summarize_dc_log_health.sh`。该脚本汇总
active run 的 stage tail、Error/Fatal/OOM 计数、warning code 计数和
`OPT-1206` 常量寄存器删除热点，不调用 Synopsys、不修改 run artifacts。当前 72h
fulltop 日志显示 `ERROR_FATAL_SUMMARY count=0`，warning 主要是 `VER-318` 和
`ELAB-311`，暂无常量寄存器删除；compat quick 的常量删除热点包括 `resp_data_r_reg`
和 `rd_resp_q_pool_idx_reg`，只作为后续 hygiene 线索，不作为当前 setup 结论。
13:54 CST 将上述 log health 汇总接入 `rtl/dc/monitor_dc_status.sh` 的 `LOG_HEALTH`
段。`DC_MONITOR_ONCE=1 bash rtl/dc/monitor_dc_status.sh` 已验证
`rtl/dc/dc_status_latest.txt` 同时包含 `GOAL_GATE`、`NEXT_ACTION`、`LOG_HEALTH`
和 `ACTIVE_RUNS`，后续一次性延迟检查会自动带出 fatal/warning/constant-removal 摘要。

13:59 CST 72h fulltop signoff run 已写出 precompile QoR/timing 并进入 compile：
`axi_llc_subsystem_dual_qor_precompile.rpt` 显示 WNS `+0.33ns`、TNS `0.00`、
violating paths `0`、Cell Area `8622370.250000`；
`axi_llc_subsystem_dual_timing_precompile.rpt` 已生成；launcher log 显示
`=== DC_STAGE compile_start 2026-05-12 13:59:36 ===` 后执行 `compile_ultra -retime`。
这说明 current RTL 的 early top setup 趋势仍健康，但最终 completion 仍必须等待
postcompile QoR/timing 和 final netlist macro refs。

14:01 CST `rtl/dc/decide_dc_next_action.sh` 输出更新：compat quick 已推进到
`Mapping Optimization (Phase 3)`；72h fulltop latest stage 为
`DC_STAGE compile_start 2026-05-12 13:59:36`；`LLC_HIT`、bounded non-hit、
RTL contracts、Linux sanity、source freshness、run liveness、macro binding、library
binding 全部 PASS。当前唯一 blocker 仍是
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。

14:07 CST 手动刷新 `rtl/dc/check_goal_gate.sh`、`rtl/dc/decide_dc_next_action.sh`
和 `rtl/dc/monitor_dc_status.sh`：`LLC_HIT` 仍为
`PASS reason=exact_read_ready0_resp7_write_ready1_resp9_no_external`，bounded
non-hit、53 个 RTL contracts、Linux sanity、DC source freshness、run liveness、
SRAM macro link、9T20 library binding 均为 PASS。72h fulltop 仍在
`Beginning Pass 1 Mapping`，compat quick 仍在 `Mapping Optimization (Phase 3)`，
两者尚未生成 final QoR/timing；`DC_SETUP` 仍为
`WAIT reason=missing_signoff_postcompile_qor`。日志健康检查显示三条 active run
均无 Error/Fatal/OOM。已启动下一次一小时后的低频检查
`dc_1h_20260512_140736`，避免继续密集轮询。

14:10 CST 新增 `rtl/dc/dc_timing_next_fix_playbook_CN.md`。该文档把后续 final
timing 分类后的动作拆成 `compat_dispatch`、`compat_write_payload`、
`compat_response_pool`、`bridge_or_hazard`、`refill_response`、`store_or_sram`
和 `other`，并明确每类可尝试修复、必须避免的语义/性能破坏，以及 RTL 修改后的
LLC-hit exact、bounded non-hit、53/53 contracts、Linux sanity、source-fresh DC
验证闭环。该文档只读梳理，不改变 RTL 或 DC Tcl。

14:47 CST 修复只读 gate/summary 工具的 marker 解析和自测耗时问题：`check_goal_gate.sh`
现在同时接受文本 marker、目录路径和 symlink-to-directory；`summarize_dc_reports.sh`
会把 symlink marker 解析为真实 run 目录；`monitor_dc_status.sh` 新增
`DC_MONITOR_LIGHTWEIGHT=1`，并让 `selftest_goal_gate_signoff.sh` 在 fake run 自测时
跳过非 DC gate 和真实 reference dump。验证结果：`bash -n` 通过，
`timeout 300s bash rtl/dc/selftest_goal_gate_signoff.sh` 输出
`PASS goal gate signoff selftest`；14:47 CST 真实 `check_goal_gate.sh` 仍为
LLC-hit / bounded non-hit / 53 contracts / Linux sanity / source freshness /
liveness / macro-library binding PASS，唯一 blocker 仍是
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。compat quick 已推进到
`Mapping Optimization (Phase 4)`；72h fulltop 仍在 `Beginning Pass 1 Mapping`，
两者仍无 final QoR/timing。

14:59 CST 手动刷新 `rtl/dc/monitor_dc_status.sh`，`rtl/dc/dc_status_latest.txt`
已更新到 `2026-05-12 14:59:28 +0800`。当前结论不变：`DC_SETUP` 仍为
`WAIT reason=missing_signoff_postcompile_qor`，compat quick latest stage 为
`Mapping Optimization (Phase 4)`，72h fulltop latest stage 仍为
`Beginning Pass 1 Mapping`，三条 tracked run 的 log health 均无 Error/Fatal/OOM。
已额外安排下一次一小时检查 `dc_1h_20260512_145848`；原 14:07 安排的一小时检查
仍会在 15:07 左右触发一次，因此短时间内会有一次重叠快照，但不会改 RTL/DC Tcl。

15:08 CST 定时检查 `dc_1h_20260512_140736` 已完成并刷新
`rtl/dc/dc_status_latest.txt` 到 `2026-05-12 15:08:08 +0800`。结论仍不变：
`DC_SETUP` 等待 `missing_signoff_postcompile_qor`，compat quick 仍在
`Mapping Optimization (Phase 4)`，72h fulltop 仍在 `Beginning Pass 1 Mapping`，
无新的 final QoR/timing。下一次已排定的检查为 `dc_1h_20260512_145848`。

15:13 CST 轻量 liveness / log-health 复查：72h fulltop 的 `launcher.log` mtime
已更新到 `2026-05-12 15:11:01 +0800`，`TIMEOUT_PID=458095`、
`DC_PID=458096` 和子进程 `619771` 均存活，子进程仍在跑 CPU；compat quick
`DC_PID=287594` 也存活。两条 run 均没有 Error/Fatal/OOM，仍没有 final QoR/timing。
fulltop log 仍只显示 `Beginning Pass 1 Mapping`，因此当前没有可用于修 RTL 的
新 final endpoint。

15:26 CST 复查 goal gate 与 next-action：LLC-hit exact、bounded non-hit、53 个
RTL contracts、large+BPU Linux sanity、source freshness、run liveness、SRAM macro
DB 绑定和 9T20 library 绑定仍全部 PASS；唯一 blocker 仍是
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。当前 `.latest_full_compile_1g`
仍指向 72h signoff run
`full_compile_1g_direct_pop_predecode_clean_long72h_9t20_20260512_125943_eda-05`，
该 run 仍只有 precompile QoR/timing：WNS `+0.33ns`、TNS `0.00`、violating paths
`0`，没有 final postcompile QoR/timing 或 final netlist。compat quick 仍在
`Mapping Optimization (Phase 4)`；72h fulltop 仍在 `Beginning Pass 1 Mapping`。
已有一次性延迟检查 `dc_1h_20260512_145848` 正在 sleep，预计 15:58:48 CST
左右刷新；不再叠加新的后台 sleep，避免增加 codex background terminal 压力。

15:59 CST 一次性延迟检查 `dc_1h_20260512_145848` 已正常触发并在 15:59:39 CST
刷新 `rtl/dc/dc_status_latest.txt`。该检查与手动 gate 复查结论一致：LLC-hit exact、
bounded non-hit、53 个 RTL contracts、large+BPU Linux sanity、source freshness、
run liveness、SRAM macro DB 绑定和 9T20 library 绑定仍全部 PASS；唯一 blocker
仍是 `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。72h fulltop 已运行约 3 小时，
仍无 postcompile QoR/timing 或 final netlist；当前可用的 top setup 证据仍只有
precompile WNS `+0.33ns`、TNS `0.00`、violating paths `0`。compat quick 已运行约
5 小时，仍无 quick-map final QoR/timing；post-link 结构热点仍只是线索，不能作为
修 RTL 的 final endpoint。

16:02 CST 已排定下一次一小时低频检查 `dc_1h_20260512_160217`，PID `878568`，
预计 17:02 CST 左右触发。当前只保留这一条新的 sleep 检查，避免堆积后台进程。

17:03 CST 一小时检查 `dc_1h_20260512_160217` 已在 17:02:27 CST 正常完成并刷新
`rtl/dc/dc_status_latest.txt`。当前 gate 仍为 LLC-hit exact、bounded non-hit、
53 个 RTL contracts、large+BPU Linux sanity、source freshness、run liveness、
SRAM macro DB 绑定和 9T20 library 绑定全部 PASS；唯一 blocker 仍是
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。72h fulltop 已运行约 4 小时，
仍无 postcompile QoR/timing 或 final netlist，当前 setup 仍只能引用 precompile
WNS `+0.33ns`、TNS `0.00`、violating paths `0` 作为趋势。compat quick 已运行
约 6 小时，仍无 quick-map final QoR/timing；post-link 结构热点仍不能替代 final
timing endpoint。

17:04 CST 已排定下一次一小时低频检查 `dc_1h_20260512_170411`，PID `944616`，
预计 18:04 CST 左右触发。当前只保留这一条新的 sleep 检查。

18:05 CST 一小时检查 `dc_1h_20260512_170411` 已在 18:05:12 CST 正常完成并刷新
`rtl/dc/dc_status_latest.txt`。当前 gate 仍为 LLC-hit exact、bounded non-hit、
53 个 RTL contracts、large+BPU Linux sanity、source freshness、run liveness、
SRAM macro DB 绑定和 9T20 library 绑定全部 PASS；唯一 blocker 仍是
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。72h fulltop 已运行约 5 小时，
仍无 postcompile QoR/timing 或 final netlist；当前 setup 仍只能引用 precompile
WNS `+0.33ns`、TNS `0.00`、violating paths `0` 作为趋势。compat quick 已运行
约 7 小时，仍无 quick-map final QoR/timing；post-link 结构热点仍不能替代 final
timing endpoint。

18:07 CST 已排定下一次一小时低频检查 `dc_1h_20260512_180709`，PID `1009419`，
预计 19:07 CST 左右触发。当前只保留这一条新的 sleep 检查。

19:08 CST 一小时检查 `dc_1h_20260512_180709` 已在 19:07:55 CST 正常完成并刷新
`rtl/dc/dc_status_latest.txt`。当前 gate 仍为 LLC-hit exact、bounded non-hit、
53 个 RTL contracts、large+BPU Linux sanity、source freshness、run liveness、
SRAM macro DB 绑定和 9T20 library 绑定全部 PASS；唯一 blocker 仍是
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。72h fulltop 已运行约 6 小时，
仍无 postcompile QoR/timing 或 final netlist；当前 setup 仍只能引用 precompile
WNS `+0.33ns`、TNS `0.00`、violating paths `0` 作为趋势。compat quick 已运行
约 8 小时，仍无 quick-map final QoR/timing；post-link 结构热点仍不能替代 final
timing endpoint。

19:09 CST 已排定下一次一小时低频检查 `dc_1h_20260512_190939`，PID `1082278`，
预计 20:09 CST 左右触发。当前只保留这一条新的 sleep 检查。

20:10 CST 一小时检查 `dc_1h_20260512_190939` 已在 20:09:43 CST 正常完成并刷新
`rtl/dc/dc_status_latest.txt`。当前 gate 仍为 LLC-hit exact、bounded non-hit、
53 个 RTL contracts、large+BPU Linux sanity、source freshness、run liveness、
SRAM macro DB 绑定和 9T20 library 绑定全部 PASS；唯一 blocker 仍是
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。72h fulltop 已运行约 7 小时，
仍无 postcompile QoR/timing 或 final netlist；当前 setup 仍只能引用 precompile
WNS `+0.33ns`、TNS `0.00`、violating paths `0` 作为趋势。compat quick 已运行
约 9 小时，仍无 quick-map final QoR/timing；post-link 结构热点仍不能替代 final
timing endpoint。

20:11 CST 已排定下一次一小时低频检查 `dc_1h_20260512_201105`，PID `1153286`，
预计 21:11 CST 左右触发。当前只保留这一条新的 sleep 检查。

21:12 CST 一小时检查 `dc_1h_20260512_201105` 已在 21:11:09 CST 正常完成并刷新
`rtl/dc/dc_status_latest.txt`。当前 gate 仍为 LLC-hit exact、bounded non-hit、
53 个 RTL contracts、large+BPU Linux sanity、source freshness、run liveness、
SRAM macro DB 绑定和 9T20 library 绑定全部 PASS；唯一 blocker 仍是
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。72h fulltop 已运行约 8 小时，
仍无 postcompile QoR/timing 或 final netlist；当前 setup 仍只能引用 precompile
WNS `+0.33ns`、TNS `0.00`、violating paths `0` 作为趋势。compat quick 已运行
约 10 小时，仍无 quick-map final QoR/timing 且尚未 timeout；post-link 结构热点
仍不能替代 final timing endpoint。

21:13 CST 已排定下一次一小时低频检查 `dc_1h_20260512_211323`，PID `1217037`，
预计 22:13 CST 左右触发。当前只保留这一条新的 sleep 检查。

22:14 CST 一小时检查 `dc_1h_20260512_211323` 已在 22:13:27 CST 正常完成并刷新
`rtl/dc/dc_status_latest.txt`。当前 gate 仍为 LLC-hit exact、bounded non-hit、
53 个 RTL contracts、large+BPU Linux sanity、source freshness、run liveness、
SRAM macro DB 绑定和 9T20 library 绑定全部 PASS；唯一 blocker 仍是
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。72h fulltop 已运行约 9 小时，
仍无 postcompile QoR/timing 或 final netlist；当前 setup 仍只能引用 precompile
WNS `+0.33ns`、TNS `0.00`、violating paths `0` 作为趋势。compat quick 已运行
约 11 小时 18 分，仍无 quick-map final QoR/timing 且尚未 timeout；post-link 结构热点
仍不能替代 final timing endpoint。

22:15 CST 已排定下一次一小时低频检查 `dc_1h_20260512_221531`，PID `1367903`，
预计 23:15 CST 左右触发。当前只保留这一条新的 sleep 检查；该检查预计会覆盖
compat quick 12h timeout 后的状态。

23:22 CST 复核：`rtl/dc/check_goal_gate.sh` 仍显示 LLC-hit exact、bounded non-hit、
53 个 RTL contracts、large+BPU Linux sanity、source freshness、run liveness、
SRAM macro DB 绑定和 9T20 library 绑定全部 PASS；唯一 blocker 仍是
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。LLC-hit 性能对齐证据仍为
read hit `ready=0 resp=7 external=-1`、write hit `ready=1 resp=9 external=-1`。
72h fulltop `full_compile_1g_direct_pop_predecode_clean_long72h_9t20_20260512_125943_eda-05`
仍存活，已运行约 10 小时 23 分，latest stage 为 `Mapping Optimization (Phase 5)`，
仍无 postcompile QoR/timing 或 final netlist；setup 仍只能引用 precompile WNS
`+0.33ns`、TNS `0.00`、violating paths `0` 作为趋势。compat quick
`compat_quick_map_low_direct_pop_predecode_clean_9t20_20260512_105623_eda-05`
已完成 final quick-map report，但 setup 未通过：WNS `-0.06ns`、TNS `-9719.26`、
violating paths `279048`。max20 分类为 `compat_write_payload` 13 条、
`compat_dispatch` 2 条、`other` 5 条；代表路径包括
`direct_rr_ptr_r_reg_3_ -> wr_q_wdata_reg_25__270_` 和
`wr_q_head_reg_1__3_ -> core_req_stage_addr_r_reg_6_`。该结果是下一轮 RTL
优化的重要趋势证据，但最终 signoff 仍等待当前 fulltop postcompile report；在 fulltop
结果落地前暂不改 RTL，避免让 active fulltop 证据变 stale。

23:25 CST 已排定下一次一小时低频检查 `dc_1h_20260512_232526`，PID `1634589`，
预计 00:25 CST 左右触发。当前只保留这一条新的 sleep 检查。

23:35 CST 在不修改综合 RTL 的前提下补强
`tb_axi_llc_subsystem_compat_direct_bypass_contract.v`：原有连续 3 个 direct-bypass
write 已覆盖 payload/address/wstrb/response 顺序；新增第二轮 write burst，在第一轮
drain 后、write queue head/tail 已经非零时再次入队并检查 `addr/wdata/wstrb/req_id`
顺序。该覆盖点用于约束后续可能执行的 compat payload circular-store 修复，避免从压缩
payload 队列改为 slot-aligned payload store 时破坏写数据对应关系。单 bench VCS 已通过：
`rtl/local_debug/vcs_compat_direct_bypass_second_burst_20260512_233505_eda-05/run.log`
显示 `tb_axi_llc_subsystem_compat_direct_bypass_contract PASS`。

23:40 CST 因上述 TB 修改会使旧全量 contract 目录早于 `rtl/tb`，已重跑
`rtl/run_all_contracts.sh` 全量 53 个 VCS contracts，输出目录为
`rtl/local_debug/vcs_all_contracts_second_burst_20260512_233702_eda-05`，wrapper log
显示 `SUMMARY total=53 passed=53 failed=0`。随后已把 `rtl/dc/check_goal_gate.sh`
的 `contracts_dir` 更新到该新目录并复查 gate：LLC-hit exact、bounded non-hit、
RTL contracts、Linux sanity、DC source freshness、run liveness、SRAM macro DB 绑定和
9T20 library 绑定均 PASS；唯一 blocker 已恢复为
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。

23:46-23:50 CST 按 compat quick final 的主违例路径执行 RTL 修复：
`rtl/src/axi_llc_subsystem_compat.v` 的 write payload 队列从“压缩 payload 队列 + pop
时宽数据 shift”改为“payload 与 metadata 使用同一个 circular slot”。写入时
`wr_q_wdata/wstrb` 使用 `wr_q_tail` 对应的 metadata slot；pop 时只刷新
`wr_q_head_wdata_r/wstrb_r` 到 `next_wr_ptr(wr_q_head[idx])` 对应 slot，不再移动尾部
payload array。该修复目标是删除 `direct_rr_ptr_r/core_req_stage_master_r` 到大量
`wr_q_wdata/wstrb` register D 端的宽 shift cone，同时不增加 LLC-hit 可见 cycle。

23:46-23:50 CST 新 RTL 验证通过：direct-bypass payload 顺序单 bench
`rtl/local_debug/vcs_compat_payload_circular_direct_bypass_20260512_234630_eda-05/run.log`
显示 `tb_axi_llc_subsystem_compat_direct_bypass_contract PASS`；LLC-hit exact contract
`rtl/local_debug/vcs_cpp_llc_hit_perf_contract_payload_circular_20260512_234630_eda-05/run.log`
显示 read hit `ready=0 resp=7 external=-1`、write hit `ready=1 resp=9 external=-1`；
bounded non-hit
`rtl/local_debug/vcs_cpp_perf_contract_payload_circular_20260512_234659_eda-05/run.log`
显示 `PASS bounded_non_hit max_extra_observed=5 direct_max_extra_allowed=6 llc_miss_max_extra_allowed=8`；
全量 RTL contracts
`rtl/local_debug/vcs_all_contracts_payload_circular_20260512_234723_eda-05` 通过
`SUMMARY total=53 passed=53 failed=0`。已把 `rtl/dc/check_goal_gate.sh` 的 hit、
bounded 和 contracts 证据路径更新到上述新目录。

23:52 CST 停止旧 source-fresh fulltop run
`full_compile_1g_direct_pop_predecode_clean_long72h_9t20_20260512_125943_eda-05`，因为
RTL 已变更，该 run 已 stale。23:53 CST 第一次重开 payload-circular DC 失败于 launcher
参数传递，未进入 `dc_shell`，无 `launcher.log`，已废弃。23:54 CST 重新启动两条有效 DC：
`compat_quick_map_low_payload_circular_9t20_20260512_235452_eda-05` 和
`full_compile_1g_payload_circular_long72h_9t20_20260512_235452_eda-05`。23:55 CST 早期
健康检查显示两条 run 都已完成 SRAM DB 读取和 analyze，正在 elaborate；无 fatal/error；
`rtl/dc/check_goal_gate.sh` 显示 LLC-hit exact、bounded non-hit、RTL contracts、
Linux sanity、DC source freshness 和 run liveness 均 PASS。当前 link report 尚未生成，
所以 `DC_MACRO_BINDING` / `DC_LIBRARY_BINDING` 为 `WAIT link_report_pending`，这是
link 前正常状态；`DC_SETUP` 仍等待 fulltop final QoR/timing。

23:58 CST 复查 payload-circular 新 DC：两条 run 均存活并接近满 CPU。
`compat_quick_map_low_payload_circular_9t20_20260512_235452_eda-05` 已运行约 4 分钟，
RSS 约 `4.1GB`；`full_compile_1g_payload_circular_long72h_9t20_20260512_235452_eda-05`
已运行约 4 分钟，RSS 约 `4.2GB`。当前仍在 elaborate 阶段，尚无 link report、
precompile QoR/timing 或 final QoR/timing。`rtl/dc/check_goal_gate.sh` 仍显示
LLC-hit exact、bounded non-hit、RTL contracts、Linux sanity、DC source freshness 和
run liveness PASS；blocker 仅为 `DC_SETUP` 以及 link 前的 macro/library binding WAIT。
既有低频检查 `dc_1h_20260512_232526` 仍存活，预计 00:25 CST 左右会读取新的
payload-circular active markers。

同日 13:02 CST 对旧 `-0.10ns` full_top 的 top80 timing path 做了结构化复查：
约 `47/80` 条是 `compat_rr_ptr_r` / DC 复制寄存器到 `compat_core_req_stage_*`，
约 `19/80` 条是 `compat_direct_rr_ptr_r` 到 write payload queue，另有 `R_9870`
等 DC 生成寄存器经 final netlist 确认为 `compat_rr_ptr_r[2]` 的复制寄存器。因此 top80
里的大部分 `other` 实质仍属于已经针对性修过的 compat dispatch 路径。真正不同的残余
主要是 `bridge_*_wr_aw_head_r` 到 `bridge_hazard_scoreboard/wr_hazard_line_r` 约
5 条，以及 `bridge_ddr_bridge/cache_rd_rsp_head_r` 到
`compat_core_cache_ctrl/mshr_refill_line_r` 的一条路径。后续如果 72h full_top 或
compat quick final report 仍失败，应先确认新的违例是否已经从 compat rr/payload
转移到这些 bridge/hazard 或 refill-response 路径。

同日 13:05 CST 对这两类残余路径做了只读 RTL 对应：bridge/hazard 残余来自
`axi_llc_axi_bridge` 内 `wr_aw_head_r -> wr_aw_q_slot_r[head] -> wr_addr_r[slot]`
再经 `axi_llc_axi_bridge_dual` 的 `line_tag_of_addr(ddr/mmio_axi_awaddr)` 捕获到
`axi_llc_dual_port_hazard_scoreboard.wr_hazard_line_r`；refill-response 残余来自
`axi_llc_axi_bridge.cache_rd_rsp_head_r -> cache_rd_rsp_data_r[head]` 经 dual-port
response mux 到 `llc_cache_ctrl`，再在 `mshr_resp_match_r` 时写
`mshr_refill_line_r[mem_resp_id]`。如果新报告确认这些路径成为主导，候选修法分别是：
给 AW issue/line tag 做预寄存或输出 staging，给 cache refill response 到 MSHR refill
line 加语义保持的 response staging。但当前不提前改 RTL，避免使正在运行的 72h full_top
和 compat quick 变 stale。

2026-05-12 12:55 CST 状态：12h source-fresh full_top
`full_compile_1g_direct_pop_predecode_clean_9t20_20260512_105623_eda-05` 已完成
link 和 precompile report，并在 11:43 CST 进入 `compile_start` / `Beginning Pass 1 Mapping`。
当前 full_top precompile QoR 为 WNS `+0.33ns`、TNS `0.00`、violating paths `0`、
cell area `8622370.250000`；最紧路径仍是 data SRAM macro Q 到
`compat/core/data_store/.../rd_row_capture_r_reg[*]`，slack `MET 0.33`。这说明 current
RTL 在 mapping 前没有明显恶化，但最终签核仍只看 postcompile QoR/timing。
同轮 compat quick `compat_quick_map_low_direct_pop_predecode_clean_9t20_20260512_105623_eda-05`
已在 11:37 CST 进入 `quick_map_low_start` / `Beginning Pass 1 Mapping`，12:50 CST
推进到 `Beginning Implementation Selection`，但 12:55 CST 仍未生成 quick QoR/timing。
12:55 CST gate 状态为前置功能/性能项 PASS、
`DC_SOURCE_FRESHNESS PASS`、
`DC_RUN_LIVENESS PASS`、`DC_MACRO_BINDING PASS`、`DC_LIBRARY_BINDING PASS`，
唯一 blocker 是 `DC_SETUP WAIT reason=missing_signoff_postcompile_qor`。

2026-05-12 10:57 CST 状态：`rtl/src/axi_llc_subsystem_compat.v` 在 10:50
后继续修复 direct/core write-pop payload shift：把动态 master 索引的
`wr_q_wdata/wstrb` pop/shift 改成 per-master 展开逻辑，不增加 stage。该修改后
`rtl/local_debug/vcs_cpp_llc_hit_perf_contract_direct_pop_predecode_clean_20260512_1050_eda-05/run.log`
通过 LLC-hit exact cycles；
`rtl/local_debug/vcs_cpp_perf_contract_direct_pop_predecode_clean_20260512_1050_eda-05/run.log`
通过 bounded non-hit；
`rtl/local_debug/vcs_all_contracts_direct_pop_predecode_clean_20260512_1050_eda-05`
通过 `53/53` contracts。10:56 CST 已在 `eda-05` 启动 source-fresh full_top
`full_compile_1g_direct_pop_predecode_clean_9t20_20260512_105623_eda-05` 和 compat
quick 趋势实验 `compat_quick_map_low_direct_pop_predecode_clean_9t20_20260512_105623_eda-05`。
10:57 CST `rtl/dc/check_goal_gate.sh` 输出前置功能/性能项 PASS、
`DC_SOURCE_FRESHNESS PASS`、`DC_RUN_LIVENESS PASS`，当前等待 current full_top
link/postcompile 报告。

2026-05-12 10:30 CST 状态：上一轮 `.latest_full_compile_1g`
`full_compile_1g_route_predecode_sram_protect_9t20_20260511_203051_eda-09`
已正常结束并写出 postcompile 报告和 final netlist，但 setup 未收敛。最终 QoR 为
WNS `-0.10ns`、TNS `-8173.00`、violating paths `246460`、cell area
`9446722.833983`；`axi_llc_subsystem_dual_postcompile_1g_timing.rpt` 含
`slack (VIOLATED)`，gate 输出 `DC_SETUP FAIL reason=signoff_timing_report_has_violated_setup_path`。
该 run 使用真实 SRAM DB 和 9T20 RVT/LVT 标准单元库，`DC_MACRO_BINDING` /
`DC_LIBRARY_BINDING` 仍为 PASS。最坏路径集中在 `axi_llc_subsystem_compat`：
`compat_rr_ptr_r` / `compat_direct_rr_ptr_r` 到 `compat_core_req_stage_*` 或 write
payload queue registers，说明 compat dispatch arbitration 到 payload/hazard 选择链仍是瓶颈。

同日 10:12-10:30 已对 `rtl/src/axi_llc_subsystem_compat.v` 继续修复：预计算每个
read/write master head entry 的 core-path dispatch payload 与 hazard eligibility，
使 round-robin loop 只选择这些 per-master 结果。当前最新 RTL 的验证证据已刷新：
`rtl/local_debug/vcs_cpp_llc_hit_perf_contract_core_dispatch_predecode_clean_20260512_101430_eda-05/run.log`
通过 LLC-hit exact cycles；`rtl/local_debug/vcs_cpp_perf_contract_core_dispatch_predecode_clean_20260512_101433_eda-05/run.log`
通过 bounded non-hit；`rtl/local_debug/vcs_all_contracts_core_dispatch_predecode_clean_20260512_101447_eda-05`
通过 `53/53` contracts。`rtl/dc/check_goal_gate.sh` 10:30 CST 因此显示
`LLC_HIT/BOUNDED_NON_HIT/RTL_CONTRACTS PASS`，但由于 full_top DC 仍是修改前 RTL，
`DC_SOURCE_FRESHNESS WAIT reason=source_hash_mismatch_rtl_src_axi_llc_subsystem_compat.v`，
`DC_SETUP FAIL`。10:17 CST 已启动新的 compat quick-map-low 小综合
`compat_quick_map_low_core_dispatch_predecode_clean_9t20_20260512_101738_eda-05`，
当前还在 elaborate，尚无 quick QoR/timing；它只用于快速趋势判断，不替代最终 full_top signoff。

本文件顶部表格和后续较早时间线保留了旧 run 的 blocker 名称
（例如 `missing_final_qor_or_timing` / `missing_signoff_postcompile_qor`）和已停止/
已过期 run 的记录，只用于追溯；当前 active 状态以上述 10:30 CST 段落和
`rtl/dc/check_goal_gate.sh` 的最新输出为准：当前关键 blocker 是
`DC_SOURCE_FRESHNESS WAIT`（full_top DC 尚未覆盖最新 RTL）与 `DC_SETUP FAIL`
（上一轮 signoff full_top postcompile setup 违例）。

2026-05-11 20:34 CST 更新：18:25 eda-05 `route_predecode_clean` full_top run
不是 setup 失败，而是在只有 precompile top setup 趋势（WNS `+0.33ns`、TNS `0.00`、
violating paths `0`）后发生 DC internal fatal，且后续 `axi_llc_dc_common.tcl` 已新增
`axi_llc_protect_sram_hierarchy`，旧 run 因此不能作为当前签核。20:30 CST 已在
`eda-09` 启动新的 `.latest_full_compile_1g`：
`full_compile_1g_route_predecode_sram_protect_9t20_20260511_203051_eda-09`。
该 run 使用 9T20 脚本入口 `rtl/dc/run_dual_full_compile_1g.tcl`，launcher PID
`2660421`，DC parent `2661056`，20:33 CST 仍在 elaborate 阶段，无早期 DB/RTL
错误，无 `exit_code.txt`。20:33 CST gate 状态为：功能/性能前置 gate PASS，
`DC_SOURCE_FRESHNESS PASS`、`DC_RUN_LIVENESS PASS`，`DC_SETUP WAIT`，
`DC_MACRO_BINDING/DC_LIBRARY_BINDING WAIT reason=link_report_pending`。

2026-05-11 20:50 CST 复查：新 full_top 仍在 `eda-09` 存活，launcher `2660421`、
timeout `2661055`、DC parent `2661056` 均可见，DC parent CPU 约 `98.7%`、RSS
约 `7.3GB`；`eda-09` 内存约 `1.0TiB total`、`921GiB available`，没有 OOM 迹象。
launcher log 仍停在 `elaborate_start` 后 building `axi_llc_subsystem_compat`，尚未生成
`link.rpt`、precompile QoR/timing 或 postcompile QoR/timing。历史同类 full_top
18:25 run 的 elaborate/link 约 49 分钟，因此当前约 19 分钟 elaborate 仍在可接受范围。
20:50 CST gate 仍为 `DC_SOURCE_FRESHNESS PASS`、`DC_RUN_LIVENESS PASS`、
`DC_SETUP WAIT reason=missing_signoff_postcompile_qor`、
`DC_MACRO_BINDING/DC_LIBRARY_BINDING WAIT reason=link_report_pending`。

2026-05-11 21:23 CST 复查：新 full_top 已完成 elaborate/link，21:19 CST 进入
`compile_start` / `Beginning Pass 1 Mapping`。`link.rpt` 确认 9T20 RVT/LVT 标准单元
库和 data/meta SRAM `.db` 均已链接，`rtl/dc/check_goal_gate.sh` 输出
`DC_MACRO_BINDING PASS reason=db_linked_signoff_netlist_pending` 和
`DC_LIBRARY_BINDING PASS reason=all_active_runs_link_9t20_rvt_lvt_and_no_7p5t`。
precompile top setup 已生成：Critical Path Slack `+0.33ns`、TNS `0.00`、violating paths
`0`、Cell Area `8622370.25`；最紧路径为 data SRAM macro Q 到
`compat/core/data_store/.../rd_row_capture_r_reg[*]`，slack `MET 0.33`。这仍只是
precompile 趋势，不替代 postcompile signoff；当前唯一 gate blocker 是
`DC_SETUP WAIT reason=missing_signoff_postcompile_qor`。

同轮检查还确认 `axi_llc_protect_sram_hierarchy` 已执行并打印
`SRAM_HIERARCHY_PROTECTED 96`。compile log 后续仍出现
`Ungrouping hierarchy compat/core/{data_store,meta_store}/.../u_macro before Pass 1`，
这里被展开的是 RTL wrapper 层级；precompile timing startpoint 仍为实际 SRAM macro
`.../u_macro/u_macro`，且 macro `.db` link 已通过。因此当前不判断为 generic table 或
SRAM DB 丢失问题；最终仍需等待 mapped netlist 中 macro 引用检查。

2026-05-11 22:02 CST 复查：full_top 仍在 `eda-09` mapping 阶段，launcher
`2660421` 已运行约 `1h31m`，DC parent `2661056` 与 child `2871830` 均存活，child CPU
约 `93.9%`，`eda-09` 内存约 `1.0TiB total`、`915GiB available`。launcher log
更新时间为 `22:02:04 CST`，没有 `Fatal:`、OOM、killed 或 `exit_code.txt`。尚未生成
`*postcompile_1g_qor.rpt` / `*postcompile_1g_timing.rpt`，因此 `GOAL status=WAIT`，
唯一 blocker 仍是 `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。

2026-05-11 22:38 CST 复查：full_top 仍在 `Beginning Pass 1 Mapping` 后的长优化阶段，
launcher `2660421` 已运行约 `2h07m`，active child `2871830` 已运行约 `1h16m` 且 CPU
约 `96.5%`；`eda-09` 内存约 `1.0TiB total`、`966GiB available`。无 `exit_code.txt`，
未新增 postcompile report；当前 QoR 仍只有 precompile WNS `+0.33ns`、TNS `0.00`、
violating paths `0`。22:38 CST gate 仍为所有前置项 PASS，唯一 blocker 为
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。

2026-05-11 23:12 CST 复查：full_top 仍在同一 Pass 1 mapping 长优化阶段，launcher
`2660421` 已运行约 `2h41m`，active child `2871830` 已运行约 `1h50m` 且 CPU 约
`97.5%`；`eda-09` 内存约 `1.0TiB total`、`969GiB available`。没有 `exit_code.txt`，
没有新增 postcompile report，precompile setup 趋势仍为 WNS `+0.33ns`、TNS `0.00`、
violating paths `0`。23:12 CST gate 仍为所有前置项 PASS，唯一 blocker 为
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。

2026-05-11 23:47 CST 复查：full_top 仍在同一 Pass 1 mapping 长优化阶段，launcher
`2660421` 已运行约 `3h16m`，active child `2871830` 已运行约 `2h25m` 且 CPU 约
`98.0%`；`eda-09` 内存约 `1.0TiB total`、`963GiB available`。没有 `exit_code.txt`，
没有新增 postcompile report，precompile setup 趋势仍为 WNS `+0.33ns`、TNS `0.00`、
violating paths `0`。23:47 CST gate 仍为所有前置项 PASS，唯一 blocker 为
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。由于连续多轮无阶段变化，后续人工
复查间隔降为约 1 小时，后台 monitor 继续按 30 分钟刷新 `dc_status_latest.txt`。

2026-05-12 00:50 CST 复查：full_top 仍在 `eda-09` 正常运行，launcher `2660421`
已运行约 `4h19m`，DC parent `2661056` 存活且 CPU 约 `34.3%`，`eda-09` 内存约
`1.0TiB total`、`970GiB available`。launcher log 已从 `Beginning Pass 1 Mapping`
推进到 `Beginning Mapping Optimizations (Ultra High effort)` / `Mapping Optimization
(Phase 1)`，说明综合仍在推进而非卡死。当前仍无 `exit_code.txt`，无 postcompile
QoR/timing，precompile setup 趋势仍为 WNS `+0.33ns`、TNS `0.00`、violating paths
`0`。00:50 CST gate 仍为所有前置项 PASS，唯一 blocker 为
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。

2026-05-12 01:52 CST 复查：full_top 仍在 `eda-09` 正常运行，launcher `2660421`
已运行约 `5h21m`，DC parent `2661056` 存活且 CPU 约 `46.9%`，`eda-09` 内存约
`1.0TiB total`、`964GiB available`。launcher log 已推进到 `Mapping Optimization
(Phase 2)`，仍无 `exit_code.txt`，无 postcompile QoR/timing；precompile setup 趋势
仍为 WNS `+0.33ns`、TNS `0.00`、violating paths `0`。01:52 CST gate 仍为所有前置项
PASS，唯一 blocker 为 `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。

2026-05-12 02:54 CST 复查：full_top 仍在 `eda-09` 正常运行，launcher `2660421`
已运行约 `6h23m`，DC parent `2661056` 存活且 CPU 约 `55.4%`，`eda-09` 内存约
`1.0TiB total`、`964GiB available`。launcher log 已推进到 `Mapping Optimization
(Phase 3)` / `Mapping Optimization (Phase 4)`，仍无 `exit_code.txt`，无 postcompile
QoR/timing；precompile setup 趋势仍为 WNS `+0.33ns`、TNS `0.00`、violating paths
`0`。02:54 CST gate 仍为所有前置项 PASS，唯一 blocker 为
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。

2026-05-12 03:58 CST 复查：full_top 仍在 `eda-09` 正常运行，launcher `2660421`
已运行约 `7h27m`，DC parent `2661056` 存活且 CPU 约 `61.7%`，`eda-09` 内存约
`1.0TiB total`、`976GiB available`。launcher log 已推进到 `Mapping Optimization
(Phase 5)` / `(Phase 6)` / `(Phase 7)`，仍无 `exit_code.txt`，无 postcompile
QoR/timing；precompile setup 趋势仍为 WNS `+0.33ns`、TNS `0.00`、violating paths
`0`。03:58 CST gate 仍为所有前置项 PASS，唯一 blocker 为
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。

2026-05-12 06:03 CST 复查：full_top 仍在 `eda-09` 正常运行，launcher `2660421`
已运行约 `9h32m`，DC parent `2661056` 存活且 CPU 约 `69.9%`，`eda-09` 内存约
`1.0TiB total`、`973GiB available`。launcher log 已从 `Mapping Optimization
(Phase 7)` 推进到 `Beginning Delay Optimization`，说明已经进入延迟/时序优化阶段。
当前仍无 `exit_code.txt`，无 postcompile QoR/timing；precompile setup 趋势仍为
WNS `+0.33ns`、TNS `0.00`、violating paths `0`。06:03 CST gate 仍为所有前置项 PASS，
唯一 blocker 为 `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。

2026-05-12 06:39 CST 复查：full_top 仍在 `eda-09` 正常运行，launcher `2660421`
已运行约 `10h08m`，DC parent `2661056` 存活且 CPU 约 `71.7%`，RSS 约 `10.6GB`；
`eda-09` 内存约 `1.0TiB total`、`973GiB available`。launcher log 在
`Beginning Delay Optimization` 后已推进到 `Beginning WLM Backend Optimization`，
说明不是未启动 full_top，也不是静止等待。当前仍无 `exit_code.txt`，无 postcompile
QoR/timing；可提供的 top setup 仍只有 precompile 趋势：WNS `+0.33ns`、TNS `0.00`、
violating paths `0`、cell area `8622370.25`。06:37 CST gate 为所有功能/性能/库/macro
前置项 PASS，唯一 blocker 仍是 `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。

2026-05-12 07:48 CST 复查：后台 monitor 在 07:29 CST 已自动刷新，gate 仍为
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。手工复查显示 full_top 仍在 `eda-09`
运行，launcher `2660421` 已运行约 `11h16m`，DC parent `2661056` 存活且 CPU 约
`74.5%`，RSS 约 `10.6GB`；`eda-09` 内存约 `1.0TiB total`、`971GiB available`。
launcher log 已从 `Beginning WLM Backend Optimization` 继续推进到
`Beginning Design Rule Fixing (max_transition) (max_capacitance)`，随后进入
`Global Optimization (Phase 35/36/37)`。当前仍无 `exit_code.txt`，无 postcompile
QoR/timing；precompile setup 趋势仍为 WNS `+0.33ns`、TNS `0.00`、violating paths `0`。

2026-05-12 08:49 CST 复查：full_top 继续在 `eda-09` 运行，launcher `2660421`
已运行约 `12h18m`，DC parent `2661056` 存活且 CPU 约 `76.6%`，RSS 约 `10.6GB`；
`eda-09` 内存约 `1.0TiB total`、`972GiB available`。launcher log 已从 design-rule
fixing 继续推进到 `Beginning Leakage Power Optimization (max_leakage_power 0)`，
随后进入 `Global Optimization (Phase 38)` 到 `Global Optimization (Phase 53)`。
当前仍无 `exit_code.txt`，无 postcompile QoR/timing；08:49 CST gate 仍为所有功能/
性能/库/macro 前置项 PASS，唯一 blocker 为
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。

2026-05-11 10:12 CST 复查：full top 1GHz DC 已经在跑，不是缺失。
`.latest_full_compile_1g` 对应
`full_compile_1g_payload_shift_9t20_20260511_073614_eda-05`，`TOP=axi_llc_subsystem_dual`，
脚本为 `rtl/dc/run_dual_full_compile_1g.tcl`，launcher `2881754`、timeout `2882006`、
DC parent `2882007` 和 active child `3138683` 均存活；full compile 已运行约 2h35m，
active child 已运行约 1h40m 且接近满 CPU。该 run 当前仍只有
`axi_llc_subsystem_dual_qor_precompile.rpt` / `axi_llc_subsystem_dual_timing_precompile.rpt`，
precompile setup 为 Critical Path Slack `+0.33ns`、TNS `0.00`、violating paths `0`；
没有 `*postcompile*` report、没有 `exit_code.txt`，因此只能说明 top 早期 setup 趋势
不是负 slack，不能作为最终 signoff。两条 quick-map 辅助实验也仍在运行且无 final QoR：
`compat_quick_map_low` 已运行约 2h36m，post-link 仍可见较大 generic select/SEQGEN 结构；
`full_quick_map_low` 已运行约 2h36m。`rtl/dc/selftest_goal_gate_signoff.sh` 10:12 CST
仍输出 `PASS goal gate signoff selftest`，说明当前 gate 不会把 precompile/缺 timing 的
proxy 状态误判为完成。

2026-05-11 10:18 CST 只读核对 DC Tcl 与 gate 命名：`rtl/dc/run_dual_full_compile_1g.tcl`
在 compile 后调用 `axi_llc_write_reports ${top_name}_postcompile_1g` 和
`axi_llc_write_mapped_outputs ${top_name}_postcompile_1g`；公共过程会写
`reports/${top_name}_postcompile_1g_qor.rpt`、`reports/${top_name}_postcompile_1g_timing.rpt`
以及 `outputs/netlist/${top_name}_postcompile_1g.v`。`rtl/dc/check_goal_gate.sh` 对
`*postcompile_1g_qor.rpt`、`*postcompile_1g_timing.rpt` 和 `*postcompile_1g.v` 的匹配
与脚本实际输出一致，因此当前 `DC_SETUP WAIT` 不是文件命名不一致导致的假等待。

2026-05-11 10:46 CST 低频复查：`rtl/dc/check_goal_gate.sh` 仍显示
`LLC_HIT/BOUNDED_NON_HIT/RTL_CONTRACTS/LINUX_SANITY/DC_SOURCE_FRESHNESS/DC_RUN_LIVENESS/
DC_MACRO_BINDING/DC_LIBRARY_BINDING` 均 PASS，唯一 blocker 仍是
`DC_SETUP WAIT reason=missing_signoff_postcompile_qor`。`.latest_full_compile_1g` 仍在运行，
launcher `2881754` 已运行约 3h10m，active child `3138683` 已运行约 2h14m 且接近满 CPU。
当前仍只有 precompile QoR/timing：WNS `+0.33ns`、TNS `0.00`、violating paths `0`，最紧
路径仍是 data SRAM macro Q 到 `compat/core/data_store/.../rd_row_capture_r_reg[*]`。仍无
`*postcompile_1g_qor.rpt`、`*postcompile_1g_timing.rpt`、final netlist、`exit_code.txt`。

2026-05-11 11:16 CST 第二轮低频复查：所有非 DC setup gate 仍 PASS，`GOAL status=WAIT`。
`.latest_full_compile_1g` 仍在运行，launcher `2881754` 已运行约 3h41m，active child
`3138683` 已运行约 2h45m 且接近满 CPU。仍未生成 `*postcompile_1g_qor.rpt` /
`*postcompile_1g_timing.rpt`，也没有 final netlist 或 `exit_code.txt`。当前 top setup
趋势仍只来自 precompile：WNS `+0.33ns`、TNS `0.00`、violating paths `0`。

2026-05-11 11:48 CST 第三轮低频复查：所有非 DC setup gate 仍 PASS，唯一 blocker 仍为
`DC_SETUP WAIT reason=missing_signoff_postcompile_qor`。`.latest_full_compile_1g` 仍在运行，
launcher `2881754` 已运行约 4h12m，active child `3138683` 已运行约 3h16m 且接近满 CPU。
仍未生成 `*postcompile_1g_qor.rpt` / `*postcompile_1g_timing.rpt`，也没有 final netlist 或
`exit_code.txt`。当前 top setup 趋势仍只来自 precompile：WNS `+0.33ns`、TNS `0.00`、
violating paths `0`，最紧路径仍是 data SRAM macro Q 到
`compat/core/data_store/.../rd_row_capture_r_reg[*]`。

2026-05-11 12:19 CST 第四轮低频复查：所有非 DC setup gate 仍 PASS，唯一 blocker 仍为
`DC_SETUP WAIT reason=missing_signoff_postcompile_qor`。`.latest_full_compile_1g` 仍在运行，
launcher `2881754` 已运行约 4h43m；DC parent `2882007` 仍存活，新的 active child
`106288` 已运行约 0h49m 且接近满 CPU，说明 DC 内部子进程阶段已切换，并非原子进程静止
卡死。launcher log 更新时间为 `2026-05-11 12:18:52 CST`，尾部仍在输出
`OPT-1206` 常量寄存器删除以及 `Implement Synthetic` / `Processing
llc_mapped_window_ctrl...`，说明综合仍在推进。仍未生成 `*postcompile_1g_qor.rpt` /
`*postcompile_1g_timing.rpt`，也没有 final netlist 或 `exit_code.txt`。两条 quick-map
辅助实验也仍 alive，但仍无 final QoR/timing。

2026-05-11 12:50 CST 第五轮低频复查：所有非 DC setup gate 仍 PASS，唯一 blocker 仍为
`DC_SETUP WAIT reason=missing_signoff_postcompile_qor`。`.latest_full_compile_1g` 仍在运行，
launcher `2881754` 已运行约 5h14m；本轮 summary 中 DC parent `2882007` 自身为 running，
上一轮的 child `106288` 已结束，说明内部阶段继续变化。仍未生成
`*postcompile_1g_qor.rpt` / `*postcompile_1g_timing.rpt`，也没有 final netlist 或
`exit_code.txt`。当前 top setup 趋势仍只来自 precompile：WNS `+0.33ns`、TNS `0.00`、
violating paths `0`。

2026-05-11 13:50 CST 第六轮低频复查：所有非 DC setup gate 仍 PASS，唯一 blocker 仍为
`DC_SETUP WAIT reason=missing_signoff_postcompile_qor`。`.latest_full_compile_1g` 仍在运行，
launcher `2881754` 已运行约 6h15m，DC parent `2882007` 处于 running。仍未生成
`*postcompile_1g_qor.rpt` / `*postcompile_1g_timing.rpt`，也没有 final netlist 或
`exit_code.txt`。launcher log 更新时间为 `2026-05-11 13:46:56 CST`，尾部已经进入
`Beginning Mapping Optimizations (Ultra High effort)`，并显示 `Mapping Optimization
(Phase 1/2/3)`，说明 full compile 已经进入 mapping optimization 阶段。系统内存正常：
约 `376GiB total`、`325GiB available`，没有 OOM 迹象。

2026-05-11 14:52 CST 第七轮低频复查：所有非 DC setup gate 仍 PASS，唯一 blocker 仍为
`DC_SETUP WAIT reason=missing_signoff_postcompile_qor`。`.latest_full_compile_1g` 仍在运行，
launcher `2881754` 已运行约 7h16m，DC parent `2882007` 处于 running。仍未生成
`*postcompile_1g_qor.rpt` / `*postcompile_1g_timing.rpt`，也没有 final netlist 或
`exit_code.txt`。launcher log 更新时间为 `2026-05-11 14:49:19 CST`，尾部已经推进到
`Mapping Optimization (Phase 4/5)`，说明相比 13:50 CST 的 phase 3 仍有进展。当前 top
setup 趋势仍只来自 precompile：WNS `+0.33ns`、TNS `0.00`、violating paths `0`。

2026-05-11 15:52 CST 第八轮低频复查：所有非 DC setup gate 仍 PASS，唯一 blocker 仍为
`DC_SETUP WAIT reason=missing_signoff_postcompile_qor`。`.latest_full_compile_1g` 仍在运行，
launcher `2881754` 已运行约 8h16m，DC parent `2882007` 处于 running。仍未生成
`*postcompile_1g_qor.rpt` / `*postcompile_1g_timing.rpt`，也没有 final netlist 或
`exit_code.txt`。launcher log 更新时间为 `2026-05-11 15:27:33 CST`，尾部已经推进到
`Mapping Optimization (Phase 6)`，说明相比 14:52 CST 的 phase 5 仍有进展。当前 top
setup 趋势仍只来自 precompile：WNS `+0.33ns`、TNS `0.00`、violating paths `0`。

2026-05-11 16:53 CST 第九轮低频复查：所有非 DC setup gate 仍 PASS，唯一 blocker 仍为
`DC_SETUP WAIT reason=missing_signoff_postcompile_qor`。`.latest_full_compile_1g` 仍在运行，
launcher `2881754` 已运行约 9h17m，DC parent `2882007` 处于 running。仍未生成
`*postcompile_1g_qor.rpt` / `*postcompile_1g_timing.rpt`，也没有 final netlist 或
`exit_code.txt`。launcher log 更新时间为 `2026-05-11 16:18:04 CST`，尾部已经推进到
`Mapping Optimization (Phase 7)`，说明相比 15:52 CST 的 phase 6 仍有进展。当前 top
setup 趋势仍只来自 precompile：WNS `+0.33ns`、TNS `0.00`、violating paths `0`。

## 当前时间线

2026-05-11 09:10 CST：修正 goal gate 口径，避免把 quick-map 诊断 run 当作最终签核
blocker。当前 full top 并没有停止：`.latest_full_quick_map_low_probe` 和
`.latest_full_compile_1g` 都指向 `axi_llc_subsystem_dual`，均在 `eda-05` 上运行。
`full_compile_1g_payload_shift_9t20_20260511_073614_eda-05` 已运行约 1h34m，已有
precompile top setup：Critical Path Slack `+0.33ns`、TNS `0.00`、violating paths
`0`，最坏路径为 data SRAM macro Q 到
`compat/core/data_store/.../rd_row_capture_r_reg[*]`。该数字可以作为当前 top 早期
setup 趋势，但不替代 postcompile signoff；`rtl/dc/check_goal_gate.sh` 当前输出
`DC_SETUP status=WAIT reason=missing_signoff_postcompile_qor`。

2026-05-11 09:14 CST 复查：`rtl/dc/check_goal_gate.sh` 当前仍为
`LLC_HIT PASS`、`BOUNDED_NON_HIT PASS`、`RTL_CONTRACTS PASS`、`LINUX_SANITY PASS`、
`DC_SOURCE_FRESHNESS PASS`、`DC_RUN_LIVENESS PASS`、`DC_MACRO_BINDING PASS`，唯一
blocker 是 `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。三条 DC 均 alive：
`compat_quick_map_low` 运行约 1h38m，`full_quick_map_low` 运行约 1h38m，
`full_compile_1g` 运行约 1h38m，正式 full compile 还有子进程运行约 42m 且接近满
CPU。整机内存约 `376GiB total` / `328GiB available`，没有 OOM 迹象。两条 quick-map
仍无 final QoR；`full_compile_1g` 仍只有 precompile QoR/timing。raw launcher log 尚未
出现 `WORST NEG SLACK` / `SETUP COST` 中间优化表；09:08 附近仍在输出 constant
register removal，例如 `rd_resp_q_pool_idx_reg[*][5..7]` 和部分
`core_req_stage_slot_r` / `*_capture_rr_r` 高位常量删除。这些目前只能说明综合仍在推进
和做常量化，不能作为 setup endpoint；不建议在没有 final timing endpoint 前修改
可综合 RTL 或重启 full top。

2026-05-11 09:16 CST 只读检查 current post-link reference：最新 `compat` post-link
仍有较宽选择结构，例如 `MUX_OP_32_5_2048` x4、`SELECT_OP_2.8192` x2、
`SELECT_OP_2.16384` x5、`SELECT_OP_2.31744` x6、`SELECT_OP_3.8192` x2、
`SELECT_OP_3.16384` x4，`SEQGEN` 约 `151681`。这说明如果 final timing 失败，
`compat` 的 response/cache-row/payload 选择结构仍是优先排查方向。但当前缺少 final
timing endpoint，不能仅凭 post-link generic reference 继续改 RTL；应等待
quick-map final timing 或 full compile postcompile timing 来确认具体 startpoint /
endpoint。

2026-05-11 09:20 CST 工具补强：`rtl/dc/summarize_dc_reports.sh` 和
`rtl/dc/monitor_dc_status.sh` 新增 `POST_LINK_STRUCTURAL_HOTSPOTS` 段，只读解析
`report_reference_post_link.rpt` 中的 `SEQGEN`、大宽度 `MUX_OP` / `SELECT_OP`。该修改
不触碰 RTL，也不会影响正在运行的 DC；用途是后续将 final timing endpoint 和
post-link 大结构风险快速关联。`bash -n rtl/dc/summarize_dc_reports.sh`、
`bash -n rtl/dc/monitor_dc_status.sh` 均通过，`DC_MONITOR_ONCE=1` 已刷新
`rtl/dc/dc_status_latest.txt`。

2026-05-11 09:21 CST 工具补强：`rtl/dc/summarize_dc_reports.sh` 和
`rtl/dc/monitor_dc_status.sh` 的 `PROCESS` 段已改为递归收集 launcher/timeout/DC PID 的
子进程，避免 full compile 内部 fork 出的高 CPU 子进程不显示。验证：
`bash rtl/dc/summarize_dc_reports.sh rtl/dc/.latest_full_compile_1g` 现在同时列出
launcher `2881754`、timeout `2882006`、DC parent `2882007` 和 active child
`3138683`；`DC_MONITOR_ONCE=1` 刷新的 `rtl/dc/dc_status_latest.txt` 也能显示同一子进程。
该修改只影响监控输出，不影响 DC。

2026-05-11 09:22 CST 新增完成审计文档 `rtl/dc/goal_completion_audit_CN.md`。该文档把
当前 goal 拆成 LLC hit 精确对齐、bounded non-hit、RTL contracts、Linux sanity、DC
source freshness、DC liveness、SRAM macro binding、full top postcompile setup signoff
和 final netlist macro 引用等逐项 checklist。当前审计结论仍是不能 complete：唯一
阻塞项为 `.latest_full_compile_1g` 缺少 `*postcompile_1g_qor.rpt` /
`*postcompile_1g_timing.rpt`，precompile `+0.33ns` 只作为趋势。

2026-05-11 09:25 CST 补强 `rtl/dc/check_goal_gate.sh` 可测试性：新增环境变量
`AXI_LLC_DC_SIGNOFF_MARKER`，默认仍为 `rtl/dc/.latest_full_compile_1g`，仅用于测试或
人工 override signoff marker。新增 `rtl/dc/selftest_goal_gate_signoff.sh`，用临时 fake
postcompile QoR / final netlist 验证：正 slack QoR 会得到 `DC_SETUP PASS` 和
`DC_MACRO_BINDING PASS`，负 slack QoR 会得到 `DC_SETUP FAIL`。已执行
`bash -n rtl/dc/check_goal_gate.sh`、`bash -n rtl/dc/selftest_goal_gate_signoff.sh` 和
`bash rtl/dc/selftest_goal_gate_signoff.sh`，输出 `PASS goal gate signoff selftest`。

2026-05-11 09:27 CST 继续增强 selftest 独立性：`rtl/dc/check_goal_gate.sh` 新增
`AXI_LLC_DC_ACTIVE_MARKERS`，默认仍使用三条真实 active marker；`selftest_goal_gate_signoff.sh`
现在同时 override active marker 和 signoff marker，并在临时 run 内写入 `source_status.txt`
与 fake `link.rpt`，因此 final signoff gate 自测不再依赖真实 active DC run 的
`summarize_dc_reports.sh` 输出。验证：`bash -n` 通过，`bash rtl/dc/selftest_goal_gate_signoff.sh`
仍输出 `PASS goal gate signoff selftest`；默认真实 gate 09:27 CST 仍保持
`DC_SETUP WAIT reason=missing_signoff_postcompile_qor`。

2026-05-11 09:29 CST 扩展 `rtl/dc/selftest_goal_gate_signoff.sh` 覆盖面：现在同时验证
四种 final signoff 情况：正 slack QoR + 正确 netlist 应 PASS；正 slack QoR + 缺 final
netlist 应保持 `DC_MACRO_BINDING WAIT`；正 slack QoR + netlist 缺 SRAM macro 引用应
`DC_MACRO_BINDING FAIL`；负 slack QoR 应 `DC_SETUP FAIL`。验证：
`bash -n rtl/dc/selftest_goal_gate_signoff.sh` 通过，`bash rtl/dc/selftest_goal_gate_signoff.sh`
输出 `PASS goal gate signoff selftest`。真实 gate 09:29 CST 仍为
`DC_SETUP WAIT reason=missing_signoff_postcompile_qor`。

2026-05-11 09:31 CST 修正 final DC setup gate 的覆盖缺口：`rtl/dc/check_goal_gate.sh`
现在要求 `.latest_full_compile_1g` 同时存在 `*postcompile_1g_qor.rpt` 和
`*postcompile_1g_timing.rpt`。若 QoR 已出现但 timing report 缺失，会输出
`DC_SETUP WAIT reason=missing_signoff_postcompile_timing`，避免只凭 QoR proxy 完成
goal。`rtl/dc/selftest_goal_gate_signoff.sh` 已增加缺 timing report 的 WAIT 自测，并且
`bash -n` / selftest 均通过。真实 gate 09:31 CST 仍先卡在
`missing_signoff_postcompile_qor`。

2026-05-11 09:34 CST 回应 full top 是否运行的疑问：full top 没有停止，也不只是等待
子模块。`.latest_full_compile_1g` 当前指向
`full_compile_1g_payload_shift_9t20_20260511_073614_eda-05`，`TOP=axi_llc_subsystem_dual`，
脚本为 `rtl/dc/run_dual_full_compile_1g.tcl`，launcher `2881754`、timeout `2882006`、
DC parent `2882007` 和 active child `3138683` 均存活；该 run 已运行约 1h58m。另有一条
`full_quick_map_low_payload_shift_9t20_20260511_073614_eda-05` 同样是
`axi_llc_subsystem_dual` 的 full-top quick-map probe，也在运行。因此当前不应再开一条
重复 full top，避免资源浪费和 marker 混乱。当前能提供的 top setup 信息仍是
precompile 趋势：Critical Path Slack `+0.33ns`、TNS `0.00`、violating paths `0`；final
setup 结论等待 `.latest_full_compile_1g` 生成 `*postcompile_1g_qor.rpt` 和
`*postcompile_1g_timing.rpt`。

2026-05-11 09:36 CST 复查三条 active DC：`rtl/dc/check_goal_gate.sh` 仍为
`LLC_HIT/BOUNDED_NON_HIT/RTL_CONTRACTS/LINUX_SANITY/DC_SOURCE_FRESHNESS/DC_RUN_LIVENESS`
全部 PASS，唯一 blocker 仍是 `DC_SETUP WAIT reason=missing_signoff_postcompile_qor`。
三条 run 都没有 `exit_code.txt`，也没有 final QoR/timing；宽松扫描 launcher log 中的
`fatal` / `error:` / `out of memory` / `cannot allocate` / `killed` /
license fail/denied/error 均无命中。当前 log 更新时间：`compat` quick-map 08:35、
`full_top` quick-map 09:36、`full_top` full compile 09:08；其中 full compile 仍有
active child `3138683` 约满 CPU 运行，判断为 DC 内部阶段少输出，不是退出。整机内存约
`376GiB total`、`328GiB available`，没有 OOM 压力迹象。

2026-05-11 09:38 CST 轻量复查 `.latest_full_compile_1g`：仍未生成任何
`*postcompile*` report，仍无 `exit_code.txt`；launcher `2881754`、timeout `2882006`、
DC parent `2882007`、active child `3138683` 均存活，full compile 已运行约 2h02m。
因此 goal 仍不能 complete；下一次有价值的人工检查应等待 monitor 下一个 30min 刷新点
或 DC 写出 postcompile QoR/timing，不建议继续分钟级轮询。

2026-05-11 09:43 CST 修正 DC gate 的一处假等待风险：`DC_RUN_LIVENESS` 现在只有在
final QoR 与对应 final timing report 成对出现时，才认为该 run 已产生 final report。
如果 DC 已退出但只写出 QoR、未写出 timing，会直接 FAIL 为
`without_final_qor_or_timing`，避免长期显示 `DC_SETUP WAIT missing timing` 但实际已无
进程可继续写 timing。`summarize_dc_reports.sh` 和 `monitor_dc_status.sh` 的
`SETUP_GATE` 同步要求 final QoR/timing 成对出现。`selftest_goal_gate_signoff.sh`
已新增覆盖：live run 缺 timing 继续 WAIT，exited run 缺 timing 必须 FAIL liveness。
`bash -n` 与 selftest 均通过，真实 gate 09:43 CST 仍为
`DC_SETUP WAIT reason=missing_signoff_postcompile_qor`。

2026-05-11 09:46 CST 继续扩展 `rtl/dc/selftest_goal_gate_signoff.sh`：新增对
`rtl/dc/summarize_dc_reports.sh` 的 signoff QoR/timing 成对判定自测，覆盖正 slack
QoR/timing 应使 summary `SETUP_GATE` PASS、缺 timing 应使 summary `SETUP_GATE` WAIT。
`bash -n`、selftest 和真实 `check_goal_gate.sh` 均通过。真实 gate 仍为
`DC_SETUP WAIT reason=missing_signoff_postcompile_qor`；`.latest_full_compile_1g` 仍只有
precompile QoR/timing，没有 `*postcompile*` report，也没有 `exit_code.txt`。

2026-05-11 09:48 CST 继续补强 monitor 可测试性：`rtl/dc/monitor_dc_status.sh` 现在支持
`AXI_LLC_DC_ACTIVE_MARKERS` override，与 `check_goal_gate.sh` 一致。`selftest_goal_gate_signoff.sh`
已把 monitor 单次刷新纳入 fake signoff 自测，覆盖 monitor 的 `GOAL_GATE` 和
`ACTIVE_RUNS SETUP_GATE` 在正 slack QoR/timing 下 PASS、缺 timing 下 WAIT。验证：
`bash -n rtl/dc/monitor_dc_status.sh`、`bash -n rtl/dc/selftest_goal_gate_signoff.sh`、
`bash rtl/dc/selftest_goal_gate_signoff.sh` 均通过；真实 gate 09:47 CST 仍为
`DC_SETUP WAIT reason=missing_signoff_postcompile_qor`。

2026-05-11 09:49 CST 修正 `DC_MACRO_BINDING` 的 timing 依赖表达：signoff QoR 出现后，
只有对应 signoff timing report 也存在，才会继续检查 final netlist 中的 data/meta SRAM
macro 引用；若只有 QoR、缺 timing，则输出非阻塞状态
`DC_MACRO_BINDING PASS reason=db_linked_signoff_timing_pending`，由 `DC_SETUP` 负责阻塞。
`selftest_goal_gate_signoff.sh` 已覆盖该缺 timing 分支。`bash -n`、selftest 和真实
`check_goal_gate.sh` 均通过；真实 gate 09:49 CST 仍为
`DC_SETUP WAIT reason=missing_signoff_postcompile_qor`，`.latest_full_compile_1g` 仍无
`*postcompile*` report 和 `exit_code.txt`。

2026-05-11 09:51 CST 扩展 negative signoff 自测：`selftest_goal_gate_signoff.sh` 现在
不仅检查 `check_goal_gate.sh` 在负 slack QoR 下输出 `DC_SETUP FAIL`，还检查
`summarize_dc_reports.sh` 和 `monitor_dc_status.sh` 的 `SETUP_GATE` 都会 FAIL 为
`one_or_more_final_qor_has_setup_violation_or_parse_gap`。验证：`bash -n`、selftest 和真实
`check_goal_gate.sh` 均通过。真实 gate 仍为 `DC_SETUP WAIT reason=missing_signoff_postcompile_qor`；
`.latest_full_compile_1g` 仍只有 precompile QoR/timing，没有 `*postcompile*` report，
也没有 `exit_code.txt`。

2026-05-11 09:53 CST 补强 final timing report 内容检查：`check_goal_gate.sh`、
`summarize_dc_reports.sh` 和 `monitor_dc_status.sh` 现在不仅要求 final QoR/timing 成对出现，
还要求 timing report 至少包含一条 `slack (...)` 行，且不能包含 `slack (VIOLATED)`。
若 timing report 缺 slack 行，`DC_SETUP` 会 FAIL 为 `signoff_timing_parse_gap`；若出现
`slack (VIOLATED)`，会 FAIL 为 `signoff_timing_report_has_violated_setup_path`。
`selftest_goal_gate_signoff.sh` 已覆盖正 QoR 但 timing violated、正 QoR 但 timing 无 slack
两类场景，并检查 goal gate、summary、monitor 三套入口均 FAIL。验证：`bash -n`、selftest、
真实 `check_goal_gate.sh` 和 full compile summary 均通过。真实 gate 09:53 CST 仍为
`DC_SETUP WAIT reason=missing_signoff_postcompile_qor`；`full_compile_1g` 已运行约 2h17m，
active child `3138683` 仍满 CPU，尚无 `*postcompile*` report 和 `exit_code.txt`。

2026-05-11 09:57 CST 轻量复查当前 active DC：`rtl/dc/check_goal_gate.sh` 仍为
`LLC_HIT/BOUNDED_NON_HIT/RTL_CONTRACTS/LINUX_SANITY/DC_SOURCE_FRESHNESS/DC_RUN_LIVENESS`
PASS，`DC_SETUP WAIT reason=missing_signoff_postcompile_qor`，`GOAL status=WAIT`。
`.latest_full_compile_1g` 仍只有 precompile QoR/timing，没有任何 `*postcompile*` report，
也没有 `exit_code.txt`。full compile launcher `2881754`、timeout `2882006`、DC parent
`2882007`、active child `3138683` 均存活；active child 已运行约 1h25m 且接近满 CPU。
整机内存仍正常，约 `376GiB total` / `328GiB available`。后台 monitor PID `3324065`
仍 alive，子进程为 `sleep 1800`；最近一次 `dc_status_latest.txt` 刷新为 09:47 CST，
属于 30 分钟 sleep 周期内，不是 monitor 退出。

2026-05-11 10:01 CST 补强 `DC_SOURCE_FRESHNESS` 的覆盖范围：除 `rtl/src`、
`rtl/include`、`rtl/flist` 外，现在还检查 `rtl/dc/axi_llc_dc_common.tcl` 和每条 active
run 的 `run_metadata.txt` 中 `SCRIPT=` 指向的 Tcl 入口。这样如果 full/quick/common DC
脚本在 run 启动后变新，gate 会 WAIT，避免用旧脚本产物签核。`selftest_goal_gate_signoff.sh`
已加入 fake `SCRIPT=` 变新时必须触发 `DC_SOURCE_FRESHNESS WAIT` 的覆盖。验证：
`bash -n rtl/dc/check_goal_gate.sh`、`bash -n rtl/dc/selftest_goal_gate_signoff.sh`、
`bash rtl/dc/selftest_goal_gate_signoff.sh` 和真实 `check_goal_gate.sh` 均通过；真实 gate
10:00 CST 输出 `DC_SOURCE_FRESHNESS PASS reason=all_active_dc_runs_match_current_synth_inputs_and_dc_scripts`，
唯一 blocker 仍为 `DC_SETUP WAIT reason=missing_signoff_postcompile_qor`。

2026-05-11 10:07 CST 新增 `DC_LIBRARY_BINDING`：`summarize_dc_reports.sh` 和
`monitor_dc_status.sh` 现在从每条 active run 的 `link.rpt` 输出
`stdcell_9t20_rvt_db_linked`、`stdcell_9t20_lvt_db_linked`、`stdcell_7p5t_db_linked`；
`check_goal_gate.sh` 要求所有 active run 均链接 9T20 RVT/LVT，且不允许出现 7p5t。
`selftest_goal_gate_signoff.sh` 已覆盖 9T20 通过和意外 7p5t 失败。验证：
`bash -n`、selftest、真实 `check_goal_gate.sh`、`summarize_dc_reports.sh` 和
`DC_MONITOR_ONCE=1 bash rtl/dc/monitor_dc_status.sh` 均通过。真实 gate 10:07 CST 新增
`DC_LIBRARY_BINDING PASS reason=all_active_runs_link_9t20_rvt_lvt_and_no_7p5t`；唯一
blocker 仍为 `DC_SETUP WAIT reason=missing_signoff_postcompile_qor`。

2026-05-11 07:37 CST：根据 `compat` 中间 optimization endpoint
反复指向 `wr_q_head_wdata_r/wstrb` 和 `core_req_stage_*`，已将
`axi_llc_subsystem_compat.v` 的写 payload 存储从环形 slot 读取改为每 master 有序
payload 队列：metadata 仍使用原环形 FIFO，payload 按 count 入队，pop 时用固定
position1 刷新 head 并 shift 后续 payload。该修改目标是消除
`master/head pointer -> 64x512` 动态宽 mux，不改变对外 ready/resp 周期。验证结果：
LLC hit-only `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_payload_shift_20260511_073033_eda-05`
通过，read hit `ready=0 resp=7 external=-1`、write hit `ready=1 resp=9 external=-1`；
bounded non-hit
`rtl/local_debug/vcs_cpp_perf_contract_payload_shift_20260511_073045_eda-05` 通过，
`max_extra_observed=5`；全量 RTL contracts
`rtl/local_debug/vcs_all_contracts_payload_shift_20260511_073111_eda-05` 为 `53/53`
PASS。

2026-05-11 07:52 CST：针对 payload-shift timing fix 的功能盲点，已扩展
`tb_axi_llc_subsystem_compat_direct_bypass_contract`：在 direct-bypass mode0 下先回压
lower bypass request，连续接受三笔写请求，再逐笔检查 lower 侧 `bypass_req_addr`、
`bypass_req_wdata`、`bypass_req_wstrb` 与 upstream write response `id/code` 的顺序。
单测目录 `rtl/local_debug/vcs_direct_bypass_payload_order_20260511_074923_eda-05` PASS。
随后复跑全量 RTL contract：
`rtl/local_debug/vcs_all_contracts_payload_shift_plus_write_order_20260511_074942_eda-05`
汇总 `SUMMARY total=53 passed=53 failed=0`。这是 TB-only 补强，不改变正在运行 DC 的
可综合 RTL 输入。

2026-05-11 07:55 CST completion audit：`rtl/dc/check_goal_gate.sh` 当前输出
`LLC_HIT PASS`、`BOUNDED_NON_HIT PASS`、`RTL_CONTRACTS PASS`、`DC_SETUP WAIT`、
`GOAL WAIT`。`RTL_CONTRACTS` freshness 判据已增强为：全量 contracts 目录中最早的
`run.log` 也必须晚于 `rtl/src`、`rtl/tb`、`rtl/include`、`rtl/flist` 下所有
Verilog/header/flist 输入，避免目录 mtime 或部分测试运行顺序导致旧验证误判。当前最早
contract run log 为 07:49:45，晚于最新相关 RTL/TB 输入 07:49:05，因此当前
`53/53` contract 证据有效。三条 payload-shift DC 均仍在运行，CPU 接近满载，未见
fatal/OOM；但三条 launcher log 仍停在 `elaborate_start` 后内部 build 阶段，尚未出现
`quick_map_low_start` / `compile_start`，也没有 final QoR/timing report。因此当前唯一
blocker 仍是 `DC_SETUP:WAIT:missing_final_qor_or_timing`。

2026-05-11 07:56 CST 环境风险复查：`eda-05` 当前内存 `376GiB total`、
`347GiB available`，三条 DC child RSS 分别约 `7.47GiB`、`7.59GiB`、`7.53GiB`，
CPU 均约 `99.7%`。当前没有 OOM 或共享服务器内存挤压迹象；日志未更新更像是 DC 在
elaborate/internal build 阶段未刷新 stdout，而不是进程挂死。现阶段不建议因为没有
report 就重跑；应等任一 run 进入 quick-map/compile 或生成 final report 后再决策。

等待 final endpoint 时的下一步判据：若后续 timing 仍指向
`wr_q_head_wdata_r/wstrb` 或 `wr_q_wdata[wr_slot_index(...)]`，优先考虑把 per-master
payload queue 进一步物理拆成显式 master bank / unrolled shift，减少 dynamic master
index 写使能和宽 mux；若 endpoint 转到 `core_req_stage_*` 或 read/write hazard scan，
再按实际 report 定位 dispatch/hazard 组合逻辑。不要在没有 final timing endpoint 前继续
修改 RTL，否则会让当前三条 DC 结果再次失效。

2026-05-11 07:58 CST DC freshness 审计：以
`full_compile_1g_payload_shift_9t20_20260511_073614_eda-05/source_status.txt`
为捕获时间点，检查 `rtl/src`、`rtl/include`、`rtl/flist` 下所有 `.v/.vh/.f`
综合输入，没有任何文件晚于该捕获点。因此当前三条 DC 仍对应最新可综合 RTL；后续新增的
TB、gate 脚本和状态文档修改不会使这些 DC 失效。

2026-05-11 08:28 CST 低频检查：三条 payload-shift DC 均已完成 elaborate/link sanity。
`compat_quick_map_low` 于 08:17:13 `elaborate_done`、08:22:08
`quick_map_low_start`，当前在 Pass 1 Mapping；`full_quick_map_low` 于 08:15:25
`elaborate_done`、08:19:39 `quick_map_low_start`，当前在 Pass 1 Mapping；
`full_compile_1g` 于 08:17:55 `elaborate_done`，已写 post-link DDC，并开始生成
`axi_llc_subsystem_dual_qor_precompile.rpt`，但该 precompile QoR 文件目前只有
`report_qor` 开头的 info/warning，缺少 WNS/TNS/area 数字，判定为
`incomplete_or_in_progress_precompile_not_final`。因此当前仍没有可用于 setup 收敛判断的
final QoR/timing；`DC_SETUP` 继续为 `WAIT reason=missing_final_qor_or_timing`。

2026-05-11 08:32 CST 复查：当前不是没有跑 full top。`full_quick_map_low` 和
`full_compile_1g` 两条 `axi_llc_subsystem_dual` full-top DC 都在 `eda-05` 上运行，
CPU 均接近满载，RSS 约 10GB，整机可用内存约 340GiB，未见 OOM/fatal。`full_quick_map_low`
处于 Pass 1 Mapping；`full_compile_1g` 已在 08:29:38 进入 `compile_ultra -retime`。
`full_compile_1g` 的 precompile QoR 显示 `Critical Path Slack +0.33ns`、TNS `0.00`、
violating paths `0`，最坏 setup path 是 data SRAM macro Q 到
`compat/core/data_store/.../rd_row_capture_r_reg[*]`。这可以作为当前 full-top 约束、
9T20 stdcell 和 data/meta SRAM DB link 的 sanity，但不能替代 final quick-map 或
postcompile setup 结论。

2026-05-11 08:35 CST 对 `compile_ultra` 中 `Ungrouping hierarchy .../u_macro`
日志做了配置风险复查：`link.rpt` 明确列出 9T20 RVT/LVT stdcell DB，以及
`sassls0c4l1p4096x256...db`、`sassls0c4l1p4096x16...db` 两个 SRAM library；
`check_design_post_link.rpt` 未见 unresolved/missing DB。当前 `u_macro` ungroup 更可能是
展开 RTL wrapper `llc_smic12_{data,meta}_4096x...`，保留真实 `sass...` library macro
leaf，而不是把 SRAM 退化成 generic flop/table。现阶段不因此中断当前 DC；若 final netlist
生成后仍需确认，应检查 netlist/reference 中是否仍存在 `sassls0c4l1p4096x256...` 和
`sassls0c4l1p4096x16...` 实例。

2026-05-11 08:35 CST gate 刷新：`rtl/dc/check_goal_gate.sh` 仍显示
`LLC_HIT PASS`、`BOUNDED_NON_HIT PASS`、`RTL_CONTRACTS PASS`、
`DC_SETUP WAIT reason=missing_final_qor_or_timing`、`GOAL WAIT`。三条 DC 均 alive，
`compat_quick_map_low` 已继续处理到 `axi_llc_subsystem_core` 一带，
`full_quick_map_low` 已继续处理到 `llc_repl_ram` 一带，`full_compile_1g` 仍在
`compile_ultra -retime` / Pass 1 Mapping 后续阶段。当前仍没有
`*quick_map_low_qor.rpt` 或 `*postcompile_1g_qor.rpt`，因此不能用 precompile
`+0.33ns` 标记 setup 收敛。

2026-05-11 08:36 CST 已把 SRAM macro binding 检查接入
`rtl/dc/monitor_dc_status.sh`。后续 `rtl/dc/dc_status_latest.txt` 的每个 active run
会包含 `MACRO_BINDING_SUMMARY`：当前三条 run 均显示 `data_macro_db_linked=yes`、
`meta_macro_db_linked=yes`，但 `final_netlist_missing_or_not_yet_written`。这意味着
SRAM `.db` link 证据已持续纳入 monitor；final netlist 生成后还会自动统计
`sassls0c4l1p4096x256...` / `sassls0c4l1p4096x16...` 的引用数量，用于确认 macro
leaf 没有在输出网表中丢失。

2026-05-11 08:37 CST 已重启后台 monitor 以加载上述脚本变更。旧 PID `2621958`
已停止，新 PID 写入 `rtl/dc/dc_status_monitor.pid`，当前为 `3165417`，子进程为
`sleep 1800`。这只影响状态刷新脚本，不影响三条 DC 进程。最新
`dc_status_latest.txt` 已验证包含 `MACRO_BINDING_SUMMARY`。

2026-05-11 08:39 CST 已把 SRAM macro 可信度纳入最终 goal gate：
`rtl/dc/check_goal_gate.sh` 新增 `DC_MACRO_BINDING`。当前输出为
`DC_MACRO_BINDING PASS reason=db_linked_final_netlist_pending`，表示三条 active run
的 data/meta SRAM `.db` link 均已确认；该段记录的是 08:39 的旧 gate 行为。09:10
之后 gate 已改为 signoff 口径：所有 active run 仍需确认 `.db` link，但只有
`.latest_full_compile_1g` 的 postcompile setup 通过后，才进一步要求 signoff final
netlist 已写出并保留 `sassls0c4l1p4096x256...` / `sassls0c4l1p4096x16...` 引用。

2026-05-11 08:43 CST 已把 current RTL freshness 纳入最终 goal gate：
`rtl/dc/check_goal_gate.sh` 新增 `DC_SOURCE_FRESHNESS`，检查三条 active DC run 的
`source_status.txt` 捕获时间均不早于当前 `rtl/src`、`rtl/include`、`rtl/flist`
下所有 `.v/.vh/.f` 综合输入。当前输出为
`DC_SOURCE_FRESHNESS PASS reason=all_active_dc_runs_match_current_synth_inputs`。后续如果
修改任何可综合 RTL/header/filelist 而未重跑 DC，该 gate 会变为 WAIT，防止用 stale
DC 结果完成验收。

2026-05-11 08:44 CST 已重启后台 monitor 以加载 `DC_SOURCE_FRESHNESS` 输出。旧 PID
`3165417` 已停止，新 PID 为 `3201586`，`PPID=1`，子进程为 `sleep 1800`。
最新 `rtl/dc/dc_status_latest.txt` 时间戳为 08:43:57，已包含
`DC_SOURCE_FRESHNESS PASS`、`DC_SETUP WAIT`、`DC_MACRO_BINDING PASS`。

2026-05-11 08:48 CST 复查用户关心的 full top：当前不是没有跑 full top。active run 中
`full_quick_map_low_payload_shift_9t20_20260511_073614_eda-05` 和
`full_compile_1g_payload_shift_9t20_20260511_073614_eda-05` 均为
`axi_llc_subsystem_dual`，均在 `eda-05` 上 alive。前者运行约 `1h11m`，仍未生成
`quick_map_low_qor/timing`；后者运行约 `1h11m`，仍未生成 `postcompile_1g_qor/timing`。
后者已有的 precompile top setup 为 WNS `+0.33ns`、TNS `0.00`、violating paths `0`，
worst path 为 data SRAM macro Q 到 `compat/core/data_store/.../rd_row_capture_r_reg[*]`。
该 precompile 数字只能说明当前约束、9T20 stdcell、SMIC12 SRAM DB link 和早期 setup
趋势正常，不能替代 final setup pass。后台 monitor 仍按 30 分钟周期 sleep 刷新；Codex
自身不会因为该后台文件更新而自动醒来，因此人工继续推进时仍需要显式触发一次状态检查。

2026-05-11 08:49 CST 追加进程/日志活性判断：`full_quick_map_low` 的 launcher log 最新
mtime 为 08:37:38，最后阶段标记为 `quick_map_low_start 08:19:39` / `Beginning Pass 1 Mapping`；
`full_compile_1g` 的 launcher log 最新 mtime 为 08:32:44，最后阶段标记为
`compile_start 08:29:38` / `Beginning Pass 1 Mapping`。两条 full top 进程仍在跑：
`full_quick_map_low` DC PID `2881694` 约 `99.7%` CPU，RSS 约 `10.0GB`；
`full_compile_1g` DC PID `2882007` 下还有子进程 `3138683` 约 `99.7%` CPU，RSS 约 `12.3GB`。
整机内存约 `332GiB available`。因此当前缺少 final report 更像是 DC mapping/compile
阶段未刷新 stdout，而不是 OOM、fatal 或进程退出；仍不应重复启动新的 full top。

2026-05-11 08:52 CST completion gate 覆盖补强：`rtl/dc/check_goal_gate.sh` 新增
`LINUX_SANITY`，直接检查已有 parent simulator large+BPU 300k/5M 日志。该 gate 要求日志
晚于 production C++ interconnect 输入，包含 `bpu=1(real-bpu)`、`Success!!!!`、已记录的
cycle/commit/IPC 数字，并排除 `Difftest: error`、abort、panic、deadlock、timeout 等
真实失败关键词；不会用泛化 `error` 过滤，因为日志中存在性能计数器字段 `addr error`。
08:52 CST 运行 `rtl/dc/check_goal_gate.sh` 输出 `LINUX_SANITY PASS`，并保持
`LLC_HIT PASS`、`BOUNDED_NON_HIT PASS`、`RTL_CONTRACTS PASS`、
`DC_SOURCE_FRESHNESS PASS`、`DC_MACRO_BINDING PASS`。唯一 blocker 仍是
`DC_SETUP:WAIT:missing_final_qor_or_timing`。

2026-05-11 08:54 CST 已同步修正 `rtl/dc/monitor_dc_status.sh` 的 gate 白名单，使
`rtl/dc/dc_status_latest.txt` 也记录 `LINUX_SANITY`。后台 monitor 已用 `setsid` 方式
重新启动，当前 PID 为 `3270314`、`PPID=1`，子进程为 `sleep 1800`；最新
`dc_status_latest.txt` 时间戳为 08:54:28，顶部 `GOAL_GATE` 已包含
`LINUX_SANITY PASS`。这只影响状态监控，不影响三条 DC 进程。

2026-05-11 08:57 CST 进一步补强 `LINUX_SANITY` 证据链：gate 现在检查
`../build_goal_llc_hit_large_bpu_20260511/simulator` 存在且晚于 `Makefile`、
`include/config.h(.large)`、`front-end/config/frontend_feature_config.h(.large)`；
检查当前 active config 与 `.large` 文件一致；检查 `include/config.h.large` 和当前
`include/config.h` 都包含 `ROB_NUM = 512`；再检查 300k/5M 日志晚于该 simulator
二进制、包含 `bpu=1(real-bpu)` / `Success!!!!` / 已记录 cycle/IPC，并无 Difftest、abort、
panic、deadlock、timeout 等失败关键词。08:57 CST 运行 `rtl/dc/check_goal_gate.sh`
仍输出 `LINUX_SANITY PASS`，唯一 blocker 仍是 `DC_SETUP:WAIT:missing_final_qor_or_timing`。

2026-05-11 09:00 CST 审计 DC final report / output 命名与 gate 匹配关系：当前 quick-map
脚本 `rtl/dc/run_dual_quick_map_low_1g.tcl` 在 `quick_reports_start` 后写
`${top_name}_quick_map_low_qor.rpt` 和 `${top_name}_quick_map_low_timing.rpt`；当前 full
compile 脚本 `rtl/dc/run_dual_full_compile_1g.tcl` 通过 `axi_llc_write_reports
${top_name}_postcompile_1g` 写 `${top_name}_postcompile_1g_qor.rpt` 和
`${top_name}_postcompile_1g_timing.rpt`。这些文件名与 `rtl/dc/summarize_dc_reports.sh` /
`rtl/dc/check_goal_gate.sh` 中的 final QoR 识别规则 `*quick_map_low_qor.rpt` /
`*postcompile_1g_qor.rpt` 一致。`axi_llc_write_mapped_outputs` 会把最终 Verilog 网表写到
`outputs/netlist/${stem}.v`，也与 `DC_MACRO_BINDING` 的 final netlist macro 引用扫描路径
一致。`bash -n rtl/dc/summarize_dc_reports.sh`、`bash -n rtl/dc/check_goal_gate.sh`、
`bash -n rtl/dc/monitor_dc_status.sh` 均通过。后台 monitor PID `3270314` 仍在运行，子进程为
`sleep 1800`，最新 `dc_status_latest.txt` 为 08:59:06。

2026-05-11 09:03 CST 补强 DC 活性 gate：`rtl/dc/check_goal_gate.sh` 新增
`DC_RUN_LIVENESS`。该 gate 对每条 active marker 检查：若 final QoR/timing 已成对存在则
通过；若 final QoR/timing 尚未成对存在，则不允许出现 `exit_code.txt`，并要求
`run_metadata.txt` 中记录的 `DC_PID` / `TIMEOUT_PID` / `LAUNCHER_PID` 至少一个仍存活；
否则认为 run 已退出且没有完整 final report，直接 FAIL，避免把“早退失败”长期误显示成
`missing_final_qor` 或 `missing_signoff_postcompile_timing`。09:03 CST 运行
`rtl/dc/check_goal_gate.sh` 输出 `DC_RUN_LIVENESS PASS`，唯一 blocker 仍为
`DC_SETUP:WAIT:missing_final_qor_or_timing`。`rtl/dc/monitor_dc_status.sh` 白名单已同步加入
`DC_RUN_LIVENESS`，后台 monitor 已重启为 PID `3324065`、`PPID=1`，子进程为 `sleep 1800`；
最新 `dc_status_latest.txt` 时间戳为 09:03:56，顶部 `GOAL_GATE` 已包含该项。

2026-05-11 07:36 CST：因为 payload-shift 修改了可综合 RTL，02:09 启动的
`slot_payload` 三条 DC 已停止，run 目录保留作旧 RTL 参考。已按最新 RTL 重新启动三条
payload-shift DC：
`compat_quick_map_low_payload_shift_9t20_20260511_073614_eda-05`、
`full_quick_map_low_payload_shift_9t20_20260511_073614_eda-05`、
`full_compile_1g_payload_shift_9t20_20260511_073614_eda-05`。三条 run 目录均保存
`source_status.txt`、`source_diff.patch`、`source_diff.stat`、
`verify_llc_hit_contract.log`、`verify_bounded_perf_contract.log` 和
`verify_all_contracts_summary.log`，用于追溯启动时的 RTL/验证基线。07:36 CST 早期检查
显示三条均已读取 SMIC12 9T20 stdcell 和 SMIC12 data/meta SRAM `.db`，无早期
fatal/OOM，正在 analyze/elaborate；当前 setup gate 仍为
`WAIT reason=missing_final_qor`。

2026-05-11 07:18 CST 复跑 `rtl/dc/check_goal_gate.sh`：前三项 gate 均 PASS，Linux
300k / 5M sanity 也通过；唯一 blocker 为
`DC_SETUP:WAIT:missing_final_qor_or_timing`。因此当前不能调用 goal complete，也不能把
`full_compile_1g` 的 precompile `+0.33ns` 当作最终 setup 收敛。

2026-05-11 07:01 CST 复查结论：不是没有跑 full top。当前仍有两条
`axi_llc_subsystem_dual` full-top DC 在 `eda-05` 上运行：
`full_quick_map_low_slot_payload_9t20_20260511_020948_eda-05` 已运行约
`4h50m`，处于 `Mapping Optimization`，尚无 quick-map final
QoR/timing；`full_compile_1g_slot_payload_9t20_20260511_020948_eda-05`
已运行约 `4h50m`，处于 `Mapping Optimization`，尚无
postcompile final QoR/timing。当前可提供的 top setup 趋势仍是
`full_compile_1g` 的 precompile report：Critical Path Slack `+0.33ns`、
TNS `0.00`、violating paths `0`，最坏路径为 data SRAM macro 到
`compat/core/data_store/.../rd_row_capture_r_reg[*]`。该数字可以作为 full-top
当前约束/link/SRAM DB 配置 sanity 与早期 setup 趋势，但不能替代 final
quick-map/postcompile setup 结论；当前 goal gate 仍为
`BLOCKERS DC_SETUP:WAIT:missing_final_qor_or_timing`。

## DC 结束后的有效证据

2026-05-11 06:21 CST 复查脚本：当前 quick-map 脚本在 `quick_map_low_done`
后会写 `check_timing`、max1/max20 `report_timing`、`report_qor`、层级面积报告，并通过
`axi_llc_write_mapped_outputs` 写出 DDC、Verilog netlist、SDC、SDF、SPF。当前
full compile 脚本在 `compile_done` 后会调用 `axi_llc_write_reports`，写
`check_timing`、max1/max80 `report_timing`、`report_qor`、面积、reference、cell、
constraint all-violators、power 和 check_design；随后也会写 mapped DDC、Verilog
netlist、SDC、SDF、SPF。因此后续判断 setup 是否收敛时，应优先使用这些 final
quick-map/postcompile report；`*_precompile.rpt` 和 early mapping cost table 只能作为趋势。

2026-05-11 06:27 CST 复查库/link 可信度：三条 current RTL DC 的 launcher log 均明确
打印 `DC_STD_DB` 为 SMIC12 9T20 RVT/LVT `ssg_v0p72` 标准单元库，`DC_DATA_DB` 为
`sassls0c4l1p4096x256.../ssgs_ccw0p72v125c/...db`，`DC_META_DB` 为
`sassls0c4l1p4096x16.../ssgs_ccw0p72v125c/...db`，并且均已完成
`read_data_db_done` / `read_meta_db_done`。三条 `link.rpt` 也列出了相同的 9T20
stdcell library 和 data/meta SRAM library，未见 missing DB 或 unresolved link error。
`report_reference_post_link.rpt` 中的 GTECH/DesignWare/unmapped operator 属于 compile
前 post-link 状态，不能解释成 generic memory；`check_design_post_link.rpt` 中 SRAM
wrapper `rst_n` 未连接等 LINT-28 是当前 wrapper 端口 unused 的既有现象，不构成这轮
DC 可信度 blocker。后续仍应以 final mapped timing/QoR 判断 setup。

2026-05-11 07:01 CST completion audit：当前目标拆为四项验收条件。
1. LLC hit cycles 精确对齐：当前 `axi_llc_subsystem_compat.v` 修改时间为 02:03:03，
hit-only 日志时间为 06:56:22，日志显示 read hit `ready=0 resp=7 external=-1`、
write hit `ready=1 resp=9 external=-1` 且 `PASS LLC_HIT_ONLY`；该日志也晚于当前
perf TB/header/C++ 相关输入，因此该项已由当前输入后生成的证据覆盖。
2. LLC miss / 非 hit 允许 bounded 差距：bounded 日志时间为 06:56:45，`LLC_MISS_READ64`
为 `ready=0 ar=8 r0=10 r1=11 resp=18`，`resp` 相比 C++ `+4` cycle；
`max_extra_observed=5`，低于 direct `6` / LLC miss `8` 上限，因此当前 bounded gate
通过。
3. RTL 功能回归：`vcs_all_contracts_slot_payload_20260511_020415_eda-05` 晚于当前
RTL 修改，53 个 run log 未发现 FAIL/ERROR/MISMATCH，当前功能证据可接受。
4. current RTL 1GHz setup 收敛：三条有效 DC 仍在运行，`compat` 和 `full_top`
quick-map 尚无 final QoR/timing；`full_compile_1g` 只有 precompile QoR/timing，
没有 postcompile final report。因此 goal 仍未完成，不能标记 complete。

2026-05-11 06:28 CST 新增只读汇总脚本：
`rtl/dc/summarize_dc_reports.sh`。默认读取
`.latest_compat_low_probe`、`.latest_full_quick_map_low_probe`、
`.latest_full_compile_1g` 三个 marker，输出 run metadata、PID/CPU/RSS、final
quick-map/postcompile report 是否存在、precompile/final QoR 摘要、worst timing
endpoint 摘要和 mapped output 产物清单。刚运行的结果显示两条 quick-map 当前
`final_qor_available=no` / `final_timing_available=no`，full compile 也只有
precompile QoR/timing，尚无 final postcompile report。该脚本不调用 Synopsys 工具，
只读已有文件，可作为后续 report 生成后的第一步判读入口。

2026-05-11 06:31 CST 增强 `rtl/dc/summarize_dc_reports.sh`：新增 `SETUP_GATE`
段，只在 final quick-map 或 postcompile QoR 存在时解析 `Critical Path Slack`、
`Total Negative Slack` 和 `No. of Violating Paths`，并给出 `PASS` / `FAIL`；
如果只有 precompile QoR，则保持 `WAIT reason=missing_final_qor`。当前三条 run 的
`SETUP_GATE` 均为 `WAIT`，因此 precompile `+0.33ns` 不会被误判为 setup 收敛。

2026-05-11 06:32 CST 将同一 `SETUP_GATE` 判据并入
`rtl/dc/monitor_dc_status.sh`，后台自动生成的 `dc_status_latest.txt` 现在每个 active
run 都直接包含 `SETUP_GATE` 与 `status=WAIT|PASS|FAIL`。已用一次性输出验证三条
current run 均为 `WAIT reason=missing_final_qor`，并重新用 `setsid` 启动后台 monitor；
当前 `rtl/dc/dc_status_monitor.pid` 为 `2567591`，`PPID=1`，不会随当前 shell 退出。

2026-05-11 07:01 CST 更新总目标 gate 脚本：`rtl/dc/check_goal_gate.sh`。该脚本只读检查
四项：LLC read hit 是否由当前 perf 输入之后的日志证明 `ready=0 resp=7 external=-1`、
LLC write hit 是否证明 `ready=1 resp=9 external=-1`，bounded
non-hit 是否通过 `max_extra_observed=5` 上限，53 个 RTL contract run log 是否无
FAIL/ERROR/MISMATCH，以及三条 current DC 的 `SETUP_GATE` 是否全部 PASS。当前运行结果：
`LLC_HIT PASS`、`BOUNDED_NON_HIT PASS`、`RTL_CONTRACTS PASS`、`DC_SETUP WAIT`、
`GOAL status=WAIT`。因此后续是否能标记 goal complete 可以直接以该脚本输出为第一层
审计入口，但 final DC report 仍需人工看 endpoint/报告确认。

2026-05-11 06:35 CST 复跑 `rtl/dc/check_goal_gate.sh`：`LLC_HIT status=PASS`、
`BOUNDED_NON_HIT status=PASS`、`RTL_CONTRACTS status=PASS`。三条 current DC 的
`SETUP_GATE` 仍均为 `WAIT reason=missing_final_qor`，因此 `DC_SETUP status=WAIT`、
`GOAL status=WAIT`。同一时间三条 DC 进程仍在运行：`compat_quick_map_low` 约
`4h25m` 且 CPU `99.7%`，`full_quick_map_low` 约 `4h25m` 且 CPU `99.7%`，
`full_compile_1g` 约 `4h25m` 且 CPU 约 `41.7%`。当前没有可据此修改 RTL 的 final
endpoint。

2026-05-11 06:37 CST 增强 `rtl/dc/summarize_dc_reports.sh`：新增
`ENDPOINT_HOTSPOTS` 段，在 final quick-map/postcompile timing report 出现后统计
`Endpoint:` 的一级层级热点，用于快速判断违例主要落在 `compat`、`bridge`、
`core/SRAM` 或其它层级。当前三条 run 因没有 final timing，均显示
`no_final_timing_reports`；该逻辑不会把 precompile timing endpoint 当作最终热点。

2026-05-11 06:39 CST 增强 `rtl/dc/check_goal_gate.sh`：新增 `BLOCKERS` 汇总行。
当前输出为 `BLOCKERS DC_SETUP:WAIT:missing_final_qor_or_timing` 和
`GOAL status=WAIT`，说明 LLC hit、bounded non-hit、RTL contracts 三项都已通过，
唯一阻塞仍是 current RTL DC setup final report。

06:39 CST 同步增强 `rtl/dc/monitor_dc_status.sh`：`dc_status_latest.txt` 顶部现在包含
`GOAL_GATE` 段，直接打印 `LLC_HIT`、`BOUNDED_NON_HIT`、`RTL_CONTRACTS`、
`DC_SETUP`、`BLOCKERS` 和 `GOAL status`。当前自动刷新结果为
`BLOCKERS DC_SETUP:WAIT:missing_final_qor_or_timing`、`GOAL status=WAIT`。后台 monitor
已重新以 `setsid` 启动，当前 PID 为 `2595542`，`PPID=1`。

2026-05-11 06:29 CST 复查并修复后台 monitor：前一次直接后台启动的
`monitor_dc_status.sh` PID 已退出，`dc_status_latest.txt` 不会继续自动刷新。已改用
`setsid bash -c ...` 重新启动，当前 `rtl/dc/dc_status_monitor.pid` 为 `2552511`，
进程 `PPID=1`、独立 session，子进程为 `sleep 1800`；这不会影响三条正在运行的 DC。
最新 `dc_status_latest.txt` 已更新到 06:29，并包含增强后的 `RUN_METADATA` /
`PROCESS` 段。

2026-05-11 06:18 CST 复查：三条 current RTL DC 进程仍在运行，未见 fatal/OOM。
`compat_quick_map_low` 已运行约 `4h08m`，child CPU 约 `99.7%`、RSS 约 `14.0GB`；
`full_quick_map_low` 已运行约 `4h08m`，child CPU 约 `99.7%`、RSS 约 `14.6GB`；
`full_compile_1g` 已运行约 `4h08m`，child CPU 约 `37.8%`、RSS 约 `9.6GB`。
当前没有新的 QoR/timing report；`compat` / `full_quick_map` 仍只有 mapping phase
记录，`full_compile_1g` 仍只有 precompile timing。三条 log 的 mtime 分别停在
05:29 / 05:59 / 05:49，但 DC child 仍在消耗 CPU，应视为内部优化阶段尚未刷新日志，
不是 run 结束。下一次有价值检查点仍是 quick-map report、postcompile report 或真实
violating endpoint。

2026-05-11 06:08 CST 复查：full top 并没有停止，当前仍有两条
`axi_llc_subsystem_dual` top 相关 DC 在 `eda-05` 上运行，另有一条 `compat`
quick-map 同步运行；三条均未见 fatal/OOM，整机 available memory 约 `332GiB`。
`full_quick_map_low_slot_payload_9t20_20260511_020948_eda-05` 已运行约 `3h58m`，
02:53:12 `elaborate_done`，02:56:23 `quick_map_low_start`，当前在
`Mapping Optimization (Phase 6)`，尚无 quick-map final QoR/timing report。
该 run 的中间表显示 area 约 `9851603.9`、`WORST NEG SLACK 6376295.50`、
setup cost `375546314752.0`、rule cost `464974688.0`，但 endpoint 为空；这仍是
early mapping cost table，不是 ns 级 final setup slack。

`full_compile_1g_slot_payload_9t20_20260511_020948_eda-05` 已运行约 `3h58m`，
03:01:03 `compile_start` 后处于 `Beginning Mapping Optimizations (Ultra High effort)`。
当前可提供的 top setup 时序是 precompile 报告：
`axi_llc_subsystem_dual_qor_precompile.rpt` 显示 Critical Path Slack `+0.33ns`、
TNS `0.00`、violating paths `0`、Cell Area `8622370.25`；
`axi_llc_subsystem_dual_timing_precompile.rpt` 的最坏路径为 data SRAM macro 到
`compat/core/data_store/.../rd_row_capture_r_reg[*]`，slack `+0.33ns`。这个数字可以
说明当前 top link、约束、SRAM DB 和 9T20 stdcell 配置没有早期明显异常，但不能替代
post-map/postcompile setup 结论。下一步继续低频等待 quick-map final report 或
full compile 的 postcompile timing；一旦出现真实 endpoint，再决定是否继续改 RTL。

2026-05-11 05:05 CST 复查：三条 `slot_payload` DC 仍在运行，未见 fatal/OOM，
整机 available memory 约 `330GiB`。`compat_quick_map_low` 已运行约 `2h55m`，
进入 `Beginning Mapping Optimizations (Medium effort)`，当前到
`Mapping Optimization (Phase 2)`；中间表显示 `WORST NEG SLACK 6372694.50`、
setup cost `376956551168.0`、rule cost `402943968.0`，endpoint 为空。
`full_quick_map_low` 已运行约 `2h55m`，进入 `Mapping Optimization (Phase 1)`；
中间表显示 `WORST NEG SLACK 6376295.50`、setup cost `375546314752.0`、rule cost
`464974688.0`，endpoint 为空。以上大数仍是 early mapping cost table，不能解释成
真实 ns 级 setup slack，也不能作为 final timing endpoint。`full_compile_1g` 仍在
Pass 1 Mapping，当前仍只有 precompile `+0.33ns`。后续继续等 Delay Optimization 或
final report；若 endpoint 继续为空，则只记录进度，不据此改 RTL。

2026-05-11 04:02 CST 复查：三条 `slot_payload` DC 仍在运行，未见 fatal/OOM，
整机 available memory 约 `333GiB`。`compat_quick_map_low` 已运行约 `1h52m`，
仍在 Pass 1 Mapping，tail 显示正在处理 `axi_llc_subsystem_compat_DW01_cmp6_2285`
到 `DW01_cmp6_2314` 附近；尚无 QoR/timing。`full_quick_map_low` 已运行约
`1h52m`，仍在 full top 内处理 `axi_llc_subsystem_compat...DW01_cmp6_802` 到
`DW01_cmp6_831` 附近；尚无 quick-map final QoR/timing，也没有 `WORST NEG SLACK`
endpoint。`full_compile_1g` 已运行约 `1h52m`，仍在 Pass 1 Mapping；当前仅有
precompile setup `+0.33ns`，没有 postcompile setup。当前观察到的是 compat 内大量
compare 网络展开仍然是主要耗时点，但还没有 timing endpoint，暂不应基于这个中间状态
改 RTL；继续等待 quick-map 进入后续 mapping/Delay Optimization 或 report 阶段。

04:04 CST 同步看 post-link report：`compat` 的 `report_reference_post_link.rpt`
显示它仍是当前规模主导模块，包含 `EQ_UNS_OP_26_26_1` 约 `2812` 个、32-bit range
compare 相关 `GEQ/LEQ` 各约 `640` 个，以及若干宽 mux/select；full top post-link
只包含 `axi_llc_axi_bridge_dual` 与 `axi_llc_subsystem_compat` 两个主层级，其中
`compat/core` macro area 为 `8622370.25`。这些数据说明当前长时间 Pass 1 Mapping
主要不是 generic memory / SRAM DB 错配，而是 `compat` 中 line hazard / 地址范围判断
被多个 master、ready、dispatch、direct-bypass 路径重复展开。若后续 timing endpoint
仍指向 compat，应优先审视 `read_req_path_clear_w`、`dispatch_path_line_hazard`、
`local_write_line_pending`、`queued_core_read_line_pending` 等重复扫描；但当前仍无
endpoint，不应仅凭 operator count 改 RTL。

2026-05-11 03:16 CST 复查：三条 `slot_payload` DC 均已通过 elaborate/link sanity，
未见 fatal/OOM，整机 available memory 约 `337GiB`。`compat_quick_map_low` 在
02:52:52 `elaborate_done`，02:55:30 `quick_map_low_start`，当前正在 Pass 1
Mapping，尚无 final QoR/timing。`full_quick_map_low` 在 02:53:12
`elaborate_done`，02:56:23 `quick_map_low_start`，当前正在 full top 内处理
`axi_llc_subsystem_compat...`，尚无 quick-map final QoR/timing。`full_compile_1g`
在 02:53:14 `elaborate_done`，03:01:03 `compile_start`，当前在 Pass 1 Mapping。
这一轮已经能提供 top 的 precompile setup 趋势：`axi_llc_subsystem_dual_qor_precompile.rpt`
显示 Critical Path Slack `+0.33ns`、TNS `0.00`、violating paths `0`、Cell Area
`8622370.25`；`axi_llc_subsystem_dual_timing_precompile.rpt` 最坏路径仍为
data SRAM macro 到 `compat/core/data_store/.../rd_row_capture_r_reg[*]`，slack
`+0.33ns`。该 precompile 数字说明当前 top 约束、宏库和 link 配置基本可信，但不能
替代 post-map/postcompile setup 收敛结论；下一步继续等 `full_quick_map_low` 或
`compat_quick_map_low` 的 mapping/Delay Optimization endpoint。

2026-05-11 02:46 CST 复查：三条 `slot_payload` DC 仍在运行，未见 fatal/OOM，
整机 available memory 约 `344GiB`。`compat_quick_map_low` 已运行约 `36m`，RSS
约 `8.1GB`；`full_quick_map_low` 已运行约 `36m`，RSS 约 `8.2GB`；
`full_compile_1g` 已运行约 `36m`，RSS 约 `8.2GB`。三条日志均更新到 02:44-02:45，
仍在 elaborate / hierarchy build，正在构建 `llc_data_store`、`llc_meta_store`、
`llc_cache_ctrl` 等层级；尚未 `elaborate_done` / `LINK_SANITY_PASS`，也尚未进入
quick-map/compile 的 mapping 阶段，因此没有 QoR/timing report 或 top WNS。当前
结论是 run 健康、full top 已在跑，但还不能提供 setup 时序情况；下一次有价值检查点
应等待 `elaborate_done`、`quick_map_low_start` / `compile_start` 或 report 生成。

2026-05-11 02:13 CST 复查：旧 `head_payload` DC 已因 RTL 被
per-slot write payload storage 修正替代而停止并标记 stale。当前有效 run 是三条
`slot_payload` RTL DC：
`compat_quick_map_low_slot_payload_9t20_20260511_020948_eda-05`、
`full_quick_map_low_slot_payload_9t20_20260511_020948_eda-05` 和
`full_compile_1g_slot_payload_9t20_20260511_020948_eda-05`。三条均在 `eda-05`
运行，使用 SMIC12 9T20 RVT/LVT stdcell 和当前 SMIC12 data/meta SRAM DB；早期
read DB、analyze 已完成，正在 elaborate / hierarchy build，未见 fatal、OOM、
missing DB 或语法错误。当前两条 full top 都已经启动：`full_quick_map_low` 用于尽早
给出 top setup 趋势，`full_compile_1g` 用于正式 1GHz full compile。现阶段还没有
QoR/timing report，因此不能给出 top WNS；下一步应等待 quick-map 先进入 mapping /
Delay Optimization 或生成 `quick_reports`。

2026-05-11 02:04 CST RTL 更新：上一轮 `head_payload` DC 在 Delay Optimization
阶段把 `compat` 最坏 endpoint 推到 `wr_q_head_wdata_r_reg[*]/D` /
`wr_q_head_wstrb_r_reg[*]/D`，中间 violation 约 `0.79-0.80ns`，说明新增 head payload
寄存器后，瓶颈仍来自从 shared payload pool 读取当前 write head payload 的选择锥。
因此进一步修改 `axi_llc_subsystem_compat.v`：删除 shared write payload pool 和
`wr_q_payload_idx`，改为每个 write FIFO slot 直接保存 `wdata/wstrb`。该修改会增加
slot payload flop 面积，但移除 `slot -> payload_idx -> 32-entry 512-bit payload pool`
两级选择路径；它只影响写侧 queue 实现，不给 LLC hit read 快路径增加 stage。

验证证据：`rtl/local_debug/vcs_cpp_llc_hit_perf_contract_slot_payload_20260511_020350_eda-05/run.log`
显示 `PERF LLC_HIT_READ64 CHECKED ready=0 resp=7 external=-1` 并通过
`PASS LLC_HIT_ONLY`；`rtl/local_debug/vcs_cpp_perf_contract_slot_payload_20260511_020403_eda-05/run.log`
通过 bounded non-hit，`max_extra_observed=5`；全量 RTL contracts
`rtl/local_debug/vcs_all_contracts_slot_payload_20260511_020415_eda-05` 为
`SUMMARY total=53 passed=53 failed=0`。因此当前 RTL 修改后，LLC hit cycle 对齐仍成立；
DC setup 结论仍需等待当前 `slot_payload` run 的 final report。

2026-05-11 01:13 CST 复查：三条 head-payload DC 仍在运行，未见 fatal/OOM，整机
available memory 约 `333GiB`。`compat_quick_map_low_head_payload...` 已运行约
`3h58m`，RSS 约 `13.6GB`，log 已更新到 01:13；3h22m 附近出现新的 mapping cost
表，显示 `WORST NEG SLACK 11306353.00`、setup cost `133782528000.0`、rule cost
约 `215129088.0`，endpoint 仍为空。该数值仍是早期/中期 mapping cost，不是 final
`report_timing`，不能作为真实 setup path。`full_quick_map_low_head_payload...`
已运行约 `3h58m`，RSS 约 `14.8GB`，仍停在 Phase 5 附近且没有 QoR/timing。
`full_compile_1g_head_payload...` 已运行约 `3h58m`，RSS 约 `9.25GB`，日志更新到
01:12，进入 `Mapping Optimization (Phase 1)`，并开始 ungroup
`bridge/ddr_bridge`，SVF 更新到 01:12；仍只有 precompile `+0.33ns`，没有
postcompile setup 结论。当前继续等待 final report；若下一轮仍无 endpoint，可考虑
把检查间隔放宽到 45-60 分钟。

2026-05-11 00:42 CST 复查：三条 head-payload DC 仍在运行，未见 fatal/OOM，整机
available memory 约 `334GiB`。`compat_quick_map_low_head_payload...` 已运行约
`3h27m`，DC child RSS 约 `13.6GB`、CPU 约 `99%`；launcher log mtime 仍停在
23:47，仍无 QoR/timing，因此不能判断 final setup。`full_quick_map_low_head_payload...`
已运行约 `3h27m`，RSS 约 `13.3GB`，日志 mtime 到 00:16，已推进到
`Mapping Optimization (Phase 5)`，但仍没有 final quick-map QoR/timing；早期
`WORST NEG SLACK 6376845.50` 仍无 endpoint，不能作为真实 setup path。
`full_compile_1g_head_payload...` 已运行约 `3h27m`，RSS 约 `9.2GB`，日志 mtime 到
00:32，已进入 `Beginning Mapping Optimizations (Ultra High effort)`，SVF 在
00:31 更新；当前仍只有 precompile `+0.33ns`，没有 postcompile setup 结论。现阶段
不应基于无 endpoint 的 mapping cost 改 RTL，应继续等 full-top quick-map 或
compat quick-map 的 final report。

2026-05-11 00:09 CST 复查：full top 并没有停，当前有两条 full-top DC 正在跑：
`full_quick_map_low_head_payload_9t20_20260510_211457_eda-05` 和
`full_compile_1g_head_payload_9t20_20260510_211457_eda-05`；同时还有一条
`compat_quick_map_low_head_payload_9t20_20260510_211457_eda-05`。三条 run 均仍在
运行，未见 fatal/OOM，整机 available memory 约 `322GiB`。`full_quick_map_low`
已运行约 `2h54m`，RSS 约 `12.9GB`，在 `Beginning Mapping Optimizations` 的
Phase 1-3，尚未生成 quick-map final QoR/timing；日志中的
`WORST NEG SLACK 6376845.50` 仍是早期 mapping cost 表，endpoint 为空，不能作为
真实 setup path。`full_compile_1g` 已运行约 `2h54m`，仍在 Pass 1 Mapping；当前唯一
可用的 top setup 报告是 precompile：Critical Path Slack `+0.33ns`、TNS `0.00`、
violating paths `0`，最坏路径为 data SRAM macro 到 `rd_row_capture_r_reg[*]`。
该 precompile 只能说明当前 top 在 compile 前约束/宏库/link 基本可信，不能替代
post-map/post-compile setup 结论。后续应继续等待 full-top quick-map 或 full compile
产出真实 timing report，而不是再开重复 full-top。

2026-05-10 23:37 CST 复查：三条 head-payload DC 仍在运行，未见 fatal/OOM，整机
available memory 约 `321GiB`。`compat_quick_map_low_head_payload...` 已运行约
2h22m，RSS 约 `10.9GB`，进入 `Beginning Mapping Optimizations (Medium effort)`；
中间表显示 `WORST NEG SLACK 6373301.00`、setup cost `230326190080.0`、rule cost
`398158144.0`，endpoint 为空。`full_quick_map_low_head_payload...` 已运行约
2h22m，RSS 约 `11.8GB`，也进入 `Beginning Mapping Optimizations (Medium effort)`；
中间表显示 `WORST NEG SLACK 6376845.50`、setup cost `214635347968.0`、rule cost
`456278944.0`，endpoint 为空。该阶段数值是初始 mapping 成本，量级异常大且没有
endpoint，不能据此判断真实 final setup path；仍需等待后续 Delay Optimization /
final `report_timing`。`full_compile_1g_head_payload...` 仍只有 precompile `+0.33ns`，
没有 postcompile setup 结论。

2026-05-10 23:06 CST 复查：三条 head-payload DC 仍在运行，未见 fatal/OOM，整机
available memory 约 `334GiB`。`compat_quick_map_low_head_payload...` 已运行约
1h51m，RSS 约 `10.1GB`，log mtime 已更新到 23:01，当前仍在 Pass 1 Mapping；
tail 显示正在处理 `llc_mshr_pending_scan...DW01_cmp6_108` 到
`DW01_cmp6_127` 以及 `axi_llc_subsystem_compat_DW01_add/sub` 等 DesignWare
比较/加减网络，尚无 QoR/timing。`full_quick_map_low_head_payload...` 已运行约
1h51m，RSS 约 `10.9GB`，log mtime 更新到 23:06，正在处理 full top 内
`axi_llc_subsystem_compat...DW01_cmp6_2344` 到 `DW01_cmp6_2373`，仍无 QoR/timing。
`full_compile_1g_head_payload...` 已运行约 1h51m，仍只有 precompile `+0.33ns`，没有
postcompile setup 结论。当前能观察到的是 mapping 仍卡在大量 compare 网络展开阶段，
但没有 endpoint，暂不应据此改 RTL。

2026-05-10 22:33 CST 复查：三条 head-payload DC 仍在运行，未见 fatal/OOM，整机
available memory 约 `336GiB`。`compat_quick_map_low_head_payload...` 已运行约
1h18m，RSS 约 `9.1GB`，log mtime 仍停在 22:03，尚无 QoR/timing 或 WNS 表；
`full_quick_map_low_head_payload...` 已运行约 1h18m，RSS 约 `10.0GB`，22:11 后
已推进到 full top 内的 `axi_llc_subsystem_compat...`，仍无 QoR/timing；
`full_compile_1g_head_payload...` 已运行约 1h18m，RSS 约 `9.1GB`，22:20 后继续
在 Pass 1 Mapping 中清理 `wr_q_payload_idx` / `core_req_stage_slot` /
`rd_capture_rr_r` 常量位，仍只有 precompile `+0.33ns`，没有 postcompile setup
结论。当前继续等待比改 RTL 更合理。

2026-05-10 22:04 CST 复查：full top 并没有停止，当前有两条 top 相关 DC
仍在跑：`full_quick_map_low_head_payload_9t20_20260510_211457_eda-05` 和
`full_compile_1g_head_payload_9t20_20260510_211457_eda-05`；另外还有一条
`compat_quick_map_low_head_payload_9t20_20260510_211457_eda-05`。三条 run 均已
`LINK_SANITY_PASS`，正在 Pass 1 Mapping / compile 阶段，尚未生成 post-map 或
post-compile setup/QoR 报告。当前唯一 top setup 数字仍是 full compile 的 precompile
report：Critical Path Slack `+0.33ns`、TNS `0.00`、violating paths `0`，最坏路径为
data SRAM macro 到 `rd_row_capture_r_reg[*]`；该数字只能作为趋势，不能作为最终
full-top setup pass 证据。后台 monitor 仍在运行，间隔 1800 秒写入
`rtl/dc/dc_status_latest.txt`，但它不会主动唤醒 Codex 对话，需要在检查点手动读取。

2026-05-10 22:10 CST 配置可信度复查：三条当前 run 的 `link.rpt` 均显示使用
SMIC12 9T20 RVT/LVT 标准单元库：
`scc12nsfe_90sdb_9tc20_rvt_ssg_v0p72_-40c_ccs.db` 和
`scc12nsfe_90sdb_9tc20_lvt_ssg_v0p72_-40c_ccs.db`；同时使用 SMIC12 SRAM DB：
meta `sassls0c4l1p4096x16.../ssgs_ccw0p72v125c/...db`，data
`sassls0c4l1p4096x256.../ssgs_ccw0p72v125c/...db`。`check_design_post_link.rpt`
存在大量 LINT warning，例如 full top `19825` 个 warning，其中 `LINT-1` 约 `3009`
个，但未检出 unresolved / missing macro / blackbox 关键字；因此当前问题不是
generic memory 或错误 stdcell 配置导致的假 run。22:09 CST raw log 搜索仍未发现
`WORST NEG SLACK` / endpoint / final report，说明三条 run 尚未到可用 setup 趋势表。

2026-05-10 22:34 CST 更新 monitor：`rtl/dc/monitor_dc_status.sh` 已改为把当前有效
run 放在 `ACTIVE_RUNS`，把历史参考 run 放在 `REFERENCE_RUNS_NOT_CURRENT`，避免旧
`id_busy` precompile QoR 被误读成当前 full-top 结果。已停止旧 monitor PID `400183`，
最初用 `nohup` 启动的新 monitor 没有保活，随后改用 `setsid` 启动，当前 monitor
PID 为 `1026276`，`rtl/dc/dc_status_latest.txt` 已刷新到 22:34:50。这只改监控脚本，
不影响正在运行的三条 DC。

2026-05-10 22:01 CST 复查：三条 head-payload RTL DC 均已通过
`LINK_SANITY_PASS`。`compat_quick_map_low_head_payload_9t20_20260510_211457_eda-05`
在 21:47:50 `elaborate_done`，21:50:33 进入 `quick_map_low_start`；
`full_quick_map_low_head_payload_9t20_20260510_211457_eda-05` 在 21:48:07
`elaborate_done`，21:51:17 进入 `quick_map_low_start`；
`full_compile_1g_head_payload_9t20_20260510_211457_eda-05` 在 21:48:00
`elaborate_done`，21:55:53 进入 `compile_start`。full compile precompile
QoR/timing 与上一轮一致，Critical Path Slack `+0.33ns`、TNS `0.00`、violating
paths `0`，仍只作为趋势，不是 final postcompile 结论。

2026-05-10 21:45 CST 复查：三条 head-payload RTL DC 均仍在 elaborate，尚未
`elaborate_done` / `LINK_SANITY_PASS`，也还没有 QoR/timing report。三条 run 的
Presto compilation 均已完成，正在构建 `llc_cache_ctrl` 等层级；CPU/RSS 正常，
整机内存约 346GiB available，未见 early fatal/OOM。继续等待 link/quick-map
阶段，不再改 RTL。

2026-05-10 21:15 CST 更新：基于 20:40-21:07 的中间 DC 趋势，旧
`write_count` 三条 DC 已停止并标记为 stale，不再等待其 final report。停止原因：
`compat` quick-map 在 Delay Optimization 运行到约 4h20m 后仍显示约
`0.81ns` WORST NEG SLACK，endpoint 主要为 `core_req_stage_wdata_r_reg[*]/D` /
`core_req_stage_wstrb_r_reg[*]/D`；full-top quick-map 也进入 delay opt，约
`1.64ns` WORST NEG SLACK。随后修改 `axi_llc_subsystem_compat.v`：为每个 write
master 增加 head payload/head strobe 寄存器，使 core/direct dispatch 只从当前
write-master head payload 取数，避免 `rr_ptr_r -> dispatch_fifo_slot_w ->
wr_q_payload_idx[...] -> 32-entry 512-bit wr_payload_wdata[...] ->
core_req_stage_wdata_r` 出现在同拍关键路径上。该修改只针对写侧 payload 选择，不给
LLC hit read 快路径增加 stage。

验证证据：`rtl/local_debug/vcs_cpp_llc_hit_perf_contract_head_payload_20260510_211050_eda-05`
通过 `PASS LLC_HIT_ONLY`；`rtl/local_debug/vcs_cpp_perf_contract_head_payload_20260510_211101_eda-05`
通过 bounded non-hit；`rtl/local_debug/vcs_all_contracts_head_payload_20260510_211121_eda-05`
为 `SUMMARY total=53 passed=53 failed=0`。21:14-21:15 CST 已启动三条新
head-payload RTL DC：`compat_quick_map_low_head_payload_9t20_20260510_211457_eda-05`、
`full_quick_map_low_head_payload_9t20_20260510_211457_eda-05`、
`full_compile_1g_head_payload_9t20_20260510_211457_eda-05`。三条均在 `eda-05`
运行，已开始 read_db/analyze，Presto compilation completed successfully，未见早期
missing DB/syntax/fatal/OOM。

2026-05-10 20:51 CST 复查：`compat` quick-map 仍未 final，但 Delay Optimization
仍在推进。中间 `WORST NEG SLACK` 从 20:40 CST 附近约 `1.05ns` 改善到约
`0.89ns`，当前反复显示的 endpoint 是 `core_req_stage_wdata_r_reg[*]/D`、
`core_req_stage_wstrb_r_reg[*]/D`，偶尔出现 `bypass_req_mode2_ddr_aligned` 和
`rd_q_id_reg[*]`。这进一步说明原 `wr_q_count -> write_req_ready` 已不是当前
主导路径；如果 final 仍 fail，候选 RTL 修复应集中在写请求 dispatch 同拍从
`rr_ptr_r` 扫描队列后经 `wr_q_payload_idx[...]` 选择 32-entry 512-bit
`wr_payload_wdata[...]` 写入 `core_req_stage_wdata_r` 的路径。优先考虑只优化写侧
head payload 选择/寄存，避免给 LLC hit read 快路径增加周期。

2026-05-10 20:40 CST 复查并更正解释：`compat` quick-map 已进入
`Beginning Delay Optimization Phase`，中间表当前约为 `WORST NEG SLACK 1.05`、
setup cost 约 `238279.1`、rule cost `0.0`，endpoint 显示为
`core_req_stage_wdata_r_reg[*]/D`。这里的 `WORST NEG SLACK 1.05` 不能解释成
正 slack，而应视为仍有约 `-1.05ns` 级 setup violation 的中间优化状态。相比上一轮
read-count 版 compat final `-4.42ns` 已明显改善，且原
`wr_q_count -> write_req_ready` 路径没有继续作为当前显示 endpoint 主导，但
compat 仍未 final pass；必须等 final `report_qor/report_timing`。
`full_quick_map_low` 仍在运行但 log 暂无新 final report；`full_compile_1g` 仍在
`Mapping Optimization (Phase 1)`，无 final postcompile report。

2026-05-10 20:29 CST 复查：三条 current write-count DC 仍在运行，仍未生成
final QoR/timing。`compat` quick-map 的 log 已有新的中间优化表，3h37m 附近从
巨大 setup cost 下降到中间 `SLACK 1.52`、setup cost 约 `252514.6`、rule cost
继续下降到 `35.2`。这里的 `SLACK 1.52` 是中间 `WORST NEG SLACK` 数值，不是正
slack；它表示仍有约 `-1.52ns` 级中间 setup violation。这不是 final timing 结论，
但比上一轮 read-count 版 final `-4.42ns` 失败趋势明显更好，说明
`write_outstanding_count_r` cleanup 至少没有让原 `wr_q_count -> write_req_ready`
最坏路径继续主导。`full_compile_1g` 已推进到
`Mapping Optimization (Phase 1)`，并开始 ungroup `bridge/ddr_bridge`，log 在
20:08 CST 更新；`full_quick_map_low` 仍在 Phase 7，无 final report。继续等待
`compat` 或 full-top quick-map 的 final report。

2026-05-10 19:59 CST 复查：三条 current write-count DC 仍在运行，尚无新的
final QoR/timing。`full_quick_map_low_write_count_9t20_20260510_160800_eda-05`
已运行约 3h51m，DC child RSS 约 15.5GB；`compat_quick_map_low_write_count_9t20_20260510_161207_eda-05`
已运行约 3h47m，RSS 约 14.2GB；`full_compile_1g_write_count_9t20_20260510_161207_eda-05`
已运行约 3h47m，RSS 约 9.3GB。整机内存仍充足，约 332GiB available，未见
fatal/OOM。当前仍只能使用 full compile precompile `+0.33ns` 作为趋势；final
setup 结论仍缺失。

2026-05-10 19:31 CST 复查：full top 没有停，也不是只跑小模块。当前同时有两条
full-top 任务在跑：`full_quick_map_low_write_count_9t20_20260510_160800_eda-05`
作为较快的 top setup 趋势探针，`full_compile_1g_write_count_9t20_20260510_161207_eda-05`
作为正式 1GHz full compile。另有一条 `compat` quick-map 用来快速定位若 top
失败时是否仍由 compat 主导。三条 run 均仍在运行且未见 fatal/OOM；机器内存约
376GiB 总量、333GiB available。当前只有 full compile 的 precompile QoR/timing：
Critical Path Slack `+0.33ns`、TNS `0.00`、setup violating paths `0`，不能替代
final postcompile/full-top 结论。下一步应等待 full-top quick-map 或 compat
quick-map 先产出 final report，再按实际 endpoint 决定是否改 RTL；不应再额外开
重复 full-top，以免浪费 license/内存并干扰已有长跑。

2026-05-10 19:22 CST 更新：三条 current write-count DC 均已越过 elaborate/link。
`full_quick_map_low_write_count_9t20_20260510_160800_eda-05` 在 16:40 CST
`elaborate_done`，16:43 CST `quick_map_low_start`，当前在
`Mapping Optimization (Phase 7)`；尚无 final QoR/timing。`compat_quick_map_low_write_count_9t20_20260510_161207_eda-05`
在 16:44 CST `elaborate_done`，16:46 CST `quick_map_low_start`，当前在
`Mapping Optimization (Phase 6)`；尚无 final QoR/timing。`full_compile_1g_write_count_9t20_20260510_161207_eda-05`
在 16:44 CST `elaborate_done`，16:52 CST `compile_start`，当前仍在 Pass 1 Mapping。
三条 run 均 `LINK_SANITY_PASS`，未见 fatal/OOM。

full compile 的 precompile report 已生成，但只作为趋势，不作为完成证据：
`axi_llc_subsystem_dual_qor_precompile.rpt` 显示 Critical Path Slack `+0.33ns`、
TNS `0.00`、setup violating paths `0`、Cell Area `8622370.25`；precompile 最坏路径仍是
data SRAM macro 到 `rd_row_capture_r_reg[*]`，slack `+0.33ns`。当前 quick-map
中间表仍显示很大的 WORST NEG SLACK / SETUP COST，这是 mapping 过程中的优化前/中间
成本，不等价于 final report。按上一轮 compat quick-map 耗时估算，current `compat`
final quick-map report 更可能在 20:20 CST 左右或之后出现。

19:28 CST 轻量复查：`compat` quick-map 仍在 Mapping Optimization Phase 6，
`full_quick_map_low` 仍在 Phase 7，二者尚无 final QoR/timing。`full_compile_1g`
已从 Pass 1 Mapping 推进到 `Beginning Mapping Optimizations (Ultra High effort)`，
仍只有 precompile QoR/timing。三条 DC 进程仍在运行，未见 fatal/OOM。

2026-05-10 16:15 CST 更新：full top 现在已经重新跑起来，不再等待 `compat` 先完成。
上一轮 `full_quick_map_low_read_count_9t20_20260510_111925_eda-05` 和
`full_compile_1g_read_count_9t20_20260510_111925_eda-05` 是基于 read-count RTL；
随后 `compat_quick_map_low_read_count_9t20_20260510_111925_eda-05` 已给出明确
quick-map setup failure：Critical Path Slack `-4.42ns`、TNS `-409896.47ns`、
setup violating paths `353872`，最坏路径为
`wr_q_count_reg_0__1_` 到 `write_req_ready_r_reg_1_`。因此继续等待 read-count
版 full top 会浪费长跑资源，已停止 stale full-top run，并把 `compat` 写侧
outstanding room 从宽组合统计改成 `write_outstanding_count_r` 小计数器。

16:09 CST，write-count RTL 的 LLC hit-only gate 和 bounded non-hit gate 均通过：
`rtl/local_debug/vcs_cpp_llc_hit_perf_contract_write_count_20260510_160902` 为
`PASS LLC_HIT_ONLY`；
`rtl/local_debug/vcs_cpp_perf_contract_write_count_20260510_160902` 为 bounded perf
`PASS`。16:11 CST，全量 RTL contracts 通过：
`rtl/local_debug/vcs_all_contracts_write_count_20260510_160902` 为
`SUMMARY total=53 passed=53 failed=0`。

16:08 CST 已先启动 current RTL 的 full-top quick-map：
`full_quick_map_low_write_count_9t20_20260510_160800_eda-05`。16:12 CST 在 VCS
contracts 通过后又启动：
`compat_quick_map_low_write_count_9t20_20260510_161207_eda-05` 和
`full_compile_1g_write_count_9t20_20260510_161207_eda-05`。三条 run 均在 `eda-05`
上运行，使用 SMIC12 9T20 标准单元、SMIC12 data `4096x256` SRAM db、SMIC12 meta
`4096x16` SRAM db，`USE_SMIC12_STORES=1`，1GHz 约束。16:14 CST 抽查显示三条
DC 均已完成 analyze 并进入 elaborate，未见 missing DB、syntax、link、fatal 或 OOM；
当前还没有 final timing/QoR。实际后台 DC child PIDs：
full quick-map `4003634`，compat quick-map `4042855`，full compile `4043077`。

16:18 CST 复查：三条 current RTL DC 仍在 elaborate，未生成 reports；三个 DC child
CPU 约 `99%`，RSS 约 `4.3-5.0GB`，说明仍在计算而不是 license/OOM 失败。参考上一轮
`compat_quick_map_low_read_count...`：11:20 elaborate start、11:48 elaborate done、
11:50 quick-map start、15:33 reports start、15:37 reports done；因此 current
`compat` quick-map 若进度类似，final quick-map timing/QoR 可能要到约 20:00 CST
后才出现。

上一轮 read-count `compat` quick-map 的 top-20 path 已作为后续决策基线：
最坏三条 `wr_q_count_reg_0__1_ -> write_req_ready_r_reg_[1/0]` slack `-4.42/-4.41ns`，
主要是写侧 outstanding/queue count 宽组合统计；这已由 `write_outstanding_count_r`
cleanup 针对处理。若 current write-count report 仍失败，下一批优先关注：
`direct_rr_ptr_r_reg_0_ -> bypass_req_mode2_ddr_aligned` slack `-2.48ns`，以及大量
`rr_ptr_r_reg_0_ -> core_req_stage_wdata_r_reg[*]` slack 约 `-2.12ns`。前者对应
direct bypass dispatch 对输出 `bypass_req_mode2_ddr_aligned` 的组合生成，后者对应
core dispatch round-robin 选择后读取 `wr_payload_wdata[...]` 写入 `core_req_stage_wdata_r`。
在 current report 出来前暂不改 RTL，避免让正在跑的 full-top DC 再次 stale。

2026-05-10 11:25 CST 更新：full top 需要继续跑，这一点是正确的。上一轮
current RTL 的 full-top quick-map-low 已在
`full_quick_map_low_hazard_summary_9t20_20260510_021209_eda-05` 产出 top setup
趋势：1GHz 下 Critical Path Slack `-5.25ns`、TNS `-632348.00ns`、setup violating
paths `484012`，最坏路径为 `compat/rd_resp_q_count_reg_0__1_` 到
`compat/rd_q_id_reg_68__0_`。这说明 top-level setup 瓶颈已经明确落在
`axi_llc_subsystem_compat` 的 read-response-count / read-accept / read-queue 写入路径，
不能只等待旧 full compile。

11:10 CST 尝试把 read-accept room 与 per-master response-busy 注册化后，LLC hit-only
和 bounded non-hit 性能 gate 通过，但全量 RTL contract 在
`tb_axi_llc_subsystem_dual_cpp_trace_contract` 的 read-budget after-release 场景失败：
释放一个 read response 后新 read 请求无法恢复 accepted。原因是上一版
`read_outstanding_accept_room_r` 用上一拍总 outstanding 且阈值为 `< MAX_OUTSTANDING-1`，
在 32/32 满载释放 1 个 response 后会卡在 31/32 不再开放 room。

11:15 CST 已修正为显式 `read_outstanding_count_r` 小计数器：read request accepted
时加一，upstream read response 被消费时减一，read-ready/selection 只依赖该小计数器
的 `< MAX_OUTSTANDING` 比较，不再依赖 `rd_resp_q_count` 宽加法树。验证已通过：
`rtl/local_debug/vcs_cpp_llc_hit_perf_contract_read_count_20260510_111543` 为
LLC hit-only PASS；`rtl/local_debug/vcs_cpp_perf_contract_read_count_20260510_111543`
为 bounded non-hit PASS；`rtl/local_debug/vcs_all_contracts_read_count_20260510_111543`
为 `SUMMARY total=53 passed=53 failed=0`。

11:19 CST 已停止两条基于旧 RTL 的 stale full-top compile，并启动最新 RTL 的三条 DC：
`compat_quick_map_low_read_count_9t20_20260510_111925_eda-05`、
`full_quick_map_low_read_count_9t20_20260510_111925_eda-05`、
`full_compile_1g_read_count_9t20_20260510_111925_eda-05`。三者均确认读取 SMIC12
9T20 stdcell、SMIC12 data/meta SRAM `.db`，并进入 analyze；暂未看到 missing DB、
flist、link 或语法级早期错误。实际后台进程为：
compat quick-map `timeout PID 3291139 / dc PID 3291146`，full-top quick-map
`timeout PID 3291141 / dc PID 3291147`，full-top compile
`timeout PID 3291143 / dc PID 3291145`。

11:23 CST 修正 `rtl/dc/monitor_dc_status.sh`：新 run 使用 `launcher.log`，旧脚本只解析
`launcher.direct.log`，导致最新三条 run 没有阶段摘要；同时把临时文件改成按 PID
唯一命名，避免 one-shot 和后台 monitor 并发写 `dc_status_latest.txt` 时竞争。已重启
唯一后台 monitor，PID `3304945`。最新状态文件已能显示三条新 DC 的 analyze/elaborate
阶段和实际 PIDs。

11:42 CST 抽查：三条最新 DC 仍在 elaborate 阶段，log mtime 仍在推进，三个 DC child
CPU 约 `99%`、RSS 约 `7.6-7.7GB`，系统 available memory 约 `346GiB`，没有
fatal/error/OOM，也尚未生成 link sanity 或 timing/QoR report。清理了额外遗留的
orphan `sleep 1800`，仅保留后台 monitor 自身的 sleep。

11:44 CST 增强 monitor：在阶段 grep 之外追加每个 run 的 `LOG_TAIL`，用于 elaborate
阶段观察真实推进位置。当前 raw tail 显示三条 run 都在展开 core 内部模块，已到
`llc_cache_ctrl` 实例；出现的 `llc_cache_ctrl.v:439/462 DEFAULT branch ... cannot be
reached (ELAB-311)` 属于不可达 default 分支提示，不是 fatal，也不应在当前 DC 运行中
为清理 warning 再改 RTL。

11:47 CST 抽查：`compat_quick_map_low_read_count...` 的 raw tail 已从
`llc_cache_ctrl` 推进到 `llc_mapped_window_ctrl`，说明 elaborate 仍在前进；full-top
quick-map/full compile 两条 raw tail 仍停在 core 内部 `llc_cache_ctrl` 展开附近。三条
run 均无 reports、无 link sanity、无 timing/QoR，后台 CPU/RSS 正常。

2026-05-10 02:05 CST 更新：full top 并没有停止。旧 full-top run
`full_compile_1g_id_busy_9t20_20260509_234201_eda-05` 仍在后台 Pass 1 Mapping，
已给出 precompile setup 参考：1GHz 下 Critical Path Slack `+0.33ns`、TNS `0.00`、
setup violating paths `0`，最坏路径是 data SRAM macro Q 到 `rd_row_capture_r`。
该结果还不是 postcompile setup pass，只能说明 link/precompile 阶段没有立即失败。

01:55 CST 后又对 `axi_llc_subsystem_compat` 做了一次纯组合 hazard summary 复用：
把 read/write request 的 supported/direct/path-clear/id-clear predicate 预先计算一次，
同时复用于 round-robin selection 和 ready 输出，避免 DC 重复展开 line/address hazard
compare 网络；不新增寄存器、不改变可见周期。验证已通过：
`rtl/local_debug/vcs_cpp_llc_hit_perf_contract_hazard_summary_20260510_020108`
显示 LLC hit-only `ready=0 resp=7 external=-1`；
`rtl/local_debug/vcs_cpp_perf_contract_hazard_summary_20260510_020130` 显示 bounded non-hit
`max_extra_observed=5`，阈值仍为 direct `<=6`、LLC miss `<=8`；全量 RTL contracts
`rtl/local_debug/vcs_all_contracts_hazard_summary_20260510_020253` 为 `53/53` PASS。

由于 `compat_quick_map_low_id_busy_direct_9t20_20260509_231547_eda-05` 已经基于旧 RTL
且 raw log 显示 DesignWare compare 持续膨胀，02:02 CST 已停止该过期 compat run。
同时启动当前 RTL 的两条新 DC：
`compat_quick_map_low_hazard_summary_direct_9t20_20260510_020217_eda-05` 和
`full_compile_1g_hazard_summary_9t20_20260510_020217_eda-05`。两者均确认读取
SMIC12 9T20 stdcell、SMIC12 data/meta SRAM `.db`，02:02 CST 已完成 analyze 并进入
elaborate，早期没有 fatal/error/OOM。旧 full-top run 保留为参考，新 full-top run
用于当前 RTL 的最终 setup 判断。

02:08 CST 已修正并重启 `rtl/dc/monitor_dc_status.sh`，新 PID `1660529`。monitor
现在同时记录 `.latest_compat_low_probe`、`.latest_full_compile_1g` 和
`.reference_full_compile_1g_pre_hazard_summary`，并支持
`DC_MONITOR_ONCE=1 rtl/dc/monitor_dc_status.sh` 手动刷新 `dc_status_latest.txt`。
这只影响状态落盘，不影响任何 DC 进程。

02:10 CST 已把当前 submodule 的 `git status`、`git diff`、`git diff --stat` 以及
LLC hit / bounded non-hit 验证 log 快照写入两条新 DC run 目录，文件名为
`source_status.txt`、`source_diff.patch`、`source_diff.stat`、
`verify_llc_hit_contract.log`、`verify_bounded_perf_contract.log`。后续即使工作区继续
变化，也能追溯这两条 run 使用的 RTL/验证基线。

02:12 CST 新增一条 current RTL 的 full-top quick-map-low run：
`full_quick_map_low_hazard_summary_9t20_20260510_021209_eda-05`。目的不是替代
full compile signoff，而是在 full compile 长跑期间尽早提供 top-level quick timing/QoR
趋势。该 run 已确认读取 9T20 stdcell 与 SMIC12 data/meta SRAM `.db`，并写入同样的
source/verification snapshot。monitor 已纳入 `.latest_full_quick_map_low_probe`。

2026-05-09 17:19 CST 快照：已有 setup pass 证据覆盖 bridge/pack/scoreboard/
MSHR scan、`llc_cache_ctrl`、`llc_repl_ram`、`llc_valid_ram` 和
`axi_llc_subsystem_core`。`axi_llc_subsystem_core` 在 15:16 CST 的 direct-store
split cleanup 后已生成 final timing/QoR 并 setup pass。`axi_llc_subsystem_compat`
仍缺少 final timing 收敛证据；full top 仍在等待 final timing/QoR。
2026-05-09 01:29 CST 进一步把 `llc_cache_ctrl` 内部 MSHR 宽 payload
(`victim_data/refill_line/wdata/wstrb`) 从 flattened vector 改为 per-slot unpacked
array，目标是消除 post-link 中的 `16384/8192` 级 select/write-mask cone。该修改不改变
宏接口和可见周期，LLC hit-only、bounded non-hit、全量 RTL contracts `53/53` 均已通过。

本文档记录当前分模块 DC setup 收敛证据。判断口径是：只有生成 final
`report_timing` / `report_qor` 且 setup violating paths 为 0，才视为该模块或
probe 在当前约束下 setup 收敛。link sanity、precompile report、中间优化表和
仍在运行的 mapping 阶段都不能单独作为 setup pass 结论。

## 当前目标审计 Checklist

本轮目标拆成四个可验收 deliverable：

1. LLC hit 的 C++/RTL cycle/performance 必须对齐。
2. LLC miss / 非 hit 场景协议和约束语义必须对齐，性能差距可有但要有 bounded gate。
3. 时序 cleanup 不能破坏 RTL 功能回归。
4. DC setup 收敛必须有当前 RTL 的 final timing/QoR 证据；precompile timing、link
   sanity、仍在 running 的进程都只能作为趋势，不可作为完成证据。

| 目标项 | 证据 | 当前结论 |
| --- | --- | --- |
| C++/RTL LLC hit cycles/performance 必须对齐 | 最新 current RTL head-payload gate `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_head_payload_20260510_211050_eda-05/run.log` 显示 `PASS LLC_HIT_ONLY`，并打印 `ready=0 resp=7 external=-1`；该 gate 使用实际 C++/RTL perf vector，覆盖 LLC hit-only 可见周期 | 已收敛；后续 RTL 改动必须继续重跑该 gate |
| LLC miss/非 hit 允许协议/约束对齐，性能差距不能过大 | 最新 current RTL head-payload gate `rtl/local_debug/vcs_cpp_perf_contract_head_payload_20260510_211101_eda-05/run.log` 通过 bounded non-hit；`max_extra_observed=5`，direct path 上限 `6`，LLC miss 上限 `8` | 当前可接受；不是最终 full-system 性能结论 |
| RTL 功能回归不能被时序 cleanup 破坏 | 最新 current RTL head-payload gate `rtl/local_debug/vcs_all_contracts_head_payload_20260510_211121_eda-05` 的 per-test `run.log` 均显示 PASS；此前 wrapper 汇总为 `SUMMARY total=53 passed=53 failed=0` | 当前通过 |
| 小模块 setup 需要按 final DC timing/QoR 判定 | bridge/pack/MSHR/cache_ctrl/repl/valid/core 已有 final pass 证据；current head-payload `compat_quick_map_low_head_payload_9t20_20260510_211457_eda-05` 已进入 Pass 1 Mapping，尚无 final timing/QoR | 部分完成；`compat` 仍是主要缺口 |
| full top 1GHz setup 收敛 | current head-payload `full_quick_map_low_head_payload_9t20_20260510_211457_eda-05` 和 `full_compile_1g_head_payload_9t20_20260510_211457_eda-05` 正在运行；尚无 post-map/post-compile final timing/QoR，只有 precompile `+0.33ns` 趋势 | 未完成，必须等待 current RTL final quick-map/full compile timing/QoR |

当前不能标记目标完成，原因是 deliverable 4 还缺两类硬证据：当前 RTL 的
`axi_llc_subsystem_compat` final quick-map timing/QoR，以及当前 RTL 的
`axi_llc_subsystem_dual` full-top quick-map/full compile timing/QoR。旧 full-top 的
precompile `+0.33ns` 只能证明早期趋势，不覆盖 current RTL final mapped setup。

## 已有 Setup Pass 证据

除明确列出的完整模块外，probe 结果只证明对应局部 helper/probe 可在 1GHz 下映射，
不等价于 `compat` 或 full top 收敛。

| 对象 | run | 结论 |
| --- | --- | --- |
| `axi_llc_hazard_scoreboard_probe32` | `hazard_scoreboard_probe32_quick_map_9t20_20260507_202523_eda-05` | setup pass，Design WNS/TNS `0.00/0.00`，violating paths `0`，cell area 约 `7248` |
| `axi_llc_hazard_scoreboard_probe64` | `hazard_scoreboard_probe64_quick_map_9t20_20260507_202523_eda-05` | setup pass，Design WNS/TNS `0.00/0.00`，violating paths `0`，cell area 约 `14631` |
| DDR64 pack timing probe | `pack_timing_probe_ddr64_offset6_9t20_20260507_194703_eda-05` | setup pass，critical path slack 约 `+0.01ns`，setup violating paths `0` |
| MMIO4 single-beat pack probe | `pack_timing_probe_mmio4_singlebeat_9t20_20260507_195850_eda-05` | setup pass，critical path slack 约 `+0.24ns`，setup violating paths `0` |
| MMIO4 real mode2 pack probe | `pack_timing_probe_mmio4_singlebeat_real_mode2_9t20_20260507_200041_eda-05` | setup pass，critical path slack 约 `+0.24ns`，setup violating paths `0` |
| `axi_llc_axi_bridge_mmio4_probe` | `bridge_mmio4_probe_quick_map_low_single4_generate_direct_9t20_20260508_1012_101254_eda-05` | setup pass，Design WNS/TNS `0.00/0.00`，setup violating paths `0`，cell area 约 `21230` |
| `axi_llc_axi_bridge_ddr64_probe` | `bridge_ddr64_probe_quick_map_low_read_pack64_case_long_direct_9t20_20260508_154942_eda-05` | setup pass，Design WNS/TNS `0.00/0.00`，setup violating paths `0`，cell area 约 `134848`；最坏 setup path slack `0.00ns` |
| `axi_llc_axi_bridge_dual` | `bridge_dual_quick_map_low_read_pack64_case_long_direct_9t20_20260508_154942_eda-05` | setup pass，Design WNS/TNS `0.00/0.00`，setup violating paths `0`，cell area 约 `167681`；最坏 setup path slack `0.00ns` |
| `llc_mshr_pending_scan` registered timing wrapper | `mshr_pending_scan_timing_probe_quick_map_low_current_direct_9t20_20260508_140121_eda-05` | setup pass，critical path slack 约 `+0.07ns`，Design WNS/TNS `0.00/0.00`，violating paths `0`；helper local cell area 约 `2283`，wrapper 总 cell area 约 `4748` |
| `llc_cache_ctrl` | `cache_ctrl_only_quick_map_low_mshr_payload_banked_direct_9t20_20260509_012946_eda-05` | setup pass，Design WNS/TNS `0.00/0.00`，setup violating paths `0`，cell area 约 `110337.8`；最坏 setup path slack `0.00ns` |
| `llc_repl_ram` | `repl_ram_quick_map_low_direct_9t20_20260509_032054_eda-05` | setup pass，critical path slack 约 `+0.37ns`，setup violating paths `0`，cell area 约 `48129.2` |
| `llc_valid_ram` banked timing probe | `valid_ram_banked_probe_quick_map_low_direct_9t20_20260509_033318_eda-05` | setup pass，critical path slack 约 `+0.37ns`，setup violating paths `0`，cell area 约 `223518.9`；该 probe 证明 64-bank regfile 结构可在 1GHz 收敛 |
| `llc_valid_ram` production RTL | `valid_ram_quick_map_low_banked_prod_direct_9t20_20260509_035710_eda-05` | setup pass，critical path slack 约 `+0.37ns`，setup violating paths `0`，cell area 约 `223518.9`；post-link 已无原始 `MUX_OP_8192_13_16` |
| `axi_llc_subsystem_core` | `core_only_quick_map_low_direct_store_split_direct_9t20_20260509_152105_eda-05` | setup pass，Critical Path Slack `0.00`、Total Negative Slack `0.00`、setup violating paths `0`、Cell Area `9081545.332955`；最坏路径 `valid_ram/rd_bits_reg_0_ -> cache_ctrl/mshr_wdata_r_reg_24__13_` slack `0.00` |

## 尚未证明 Setup 收敛

这些是真正需要继续关闭的小模块级目标：

| 对象 | 当前状态 |
| --- | --- |
| `axi_llc_subsystem_compat` | 旧 compat quick-map run 均已因后续 RTL cleanup stale 或 timeout；当前最新 read-count RTL 的 `compat_quick_map_low_read_count_9t20_20260510_111925_eda-05` 正在 elaborate，尚无 final timing/QoR |
| `axi_llc_subsystem_dual` full top | 旧 full-top run 均已因 read-count RTL cleanup stale 或被停止；当前最新 read-count RTL 的 `full_quick_map_low_read_count_9t20_20260510_111925_eda-05` 和 `full_compile_1g_read_count_9t20_20260510_111925_eda-05` 正在 elaborate，尚无 final timing/QoR |

## 当前正在运行的 DC

当前 latest run 在 `eda-05` 上使用 SMIC12 9T20 标准单元与 SMIC12 data/meta SRAM
`.db`，时钟 `1.0ns`。11:15 CST 的 read-count RTL cleanup 已通过 LLC hit-only、
bounded non-hit、全量 RTL contracts `53/53`，11:19 CST 启动最新 `compat` quick-map、
full-top quick-map 和 full-top full compile。11:44 CST 定时检查显示三条 run 仍在
elaborate，尚未生成 final timing/QoR。所有 stale run 不得作为当前 RTL 的 setup pass
证据。

`compat` 当前 post-link reference 仍显示外围 wrapper 复杂度较高：`SEQGEN=133661`、
`MUX_OP_32_5_2048` count `4`、`MUX_OP_32_5_512` count `8`、
`SELECT_OP_2.16384` count `6`、`SELECT_OP_3.16384` count `4`、
`SELECT_OP_2.8192` / `SELECT_OP_3.8192` 各 count `2`，并有 149 条 high-fanout net。
这些不是 setup fail 结论，但如果当前 compat run 超时或 final timing 失败，应优先把
真实 endpoint 映射回这些 read-response/direct-slot/write-payload pool 相关结构。

17:52 CST 定时检查：`compat` 仍只有 post-link reports，未生成 final QoR/timing；
full-top 仍只有 precompile QoR/timing 和 post-link reports，未生成 postcompile
QoR/timing。两个 DC 进程仍在运行，未看到 fatal/error/OOM；系统 available memory
约 `337GiB`。

23:08 CST 复查：之前依赖 Codex session 的 `sleep 1800` 没有自动向对话触发通知。
已新增独立后台 monitor `rtl/dc/monitor_dc_status.sh`，PID 记录在
`rtl/dc/dc_status_monitor.pid`，每 30 分钟写最新状态到
`rtl/dc/dc_status_latest.txt` 并追加 `rtl/dc/dc_status_monitor.log`。第一次 `nohup`
启动只写了一轮后退出；23:18 CST 已改用 `setsid` 重启，PID `1109136`，PPID 已变为
`1`，可以独立于 Codex shell 驻留。该 monitor 不负责重跑 DC，只保证状态持续落盘。

23:08 CST 同步状态：`compat_quick_map_low_direct_store_split...152105...` 已在
19:21 CST 收到 Signal 15，只有 post-link reports，没有 final QoR/timing；
`full_compile_1g_direct_store_split...152105...` 仍在 Mapping Optimization Phase 10，
但 23:11 CST 后 RTL 又做了 ID-busy cleanup，因此该 full-top run 已 stale。23:15 CST
已停止 stale full-top，释放 license/CPU。

23:11 CST 对 `axi_llc_subsystem_compat` 做 ID conflict 结构 cleanup：新增 per-master
read/write ID busy bitmap，accepted upstream ID 在对应 upstream response 被消费前保持
busy，用它替代 ready 路径中对 FIFO/core/direct/response queue 的重复扫描。该修改保持
原有“同 master 同 ID 未完成前不可再次 accepted”的语义，但去掉 response queue
动态 head+offset+wrap 扫描和多处宽 fan-in 比较。验证已通过：
`rtl/local_debug/vcs_cpp_llc_hit_perf_contract_id_busy_20260509_231118`、
`rtl/local_debug/vcs_cpp_perf_contract_id_busy_20260509_231134`、
`rtl/local_debug/vcs_all_contracts_id_busy_20260509_231153`，全量 contracts `53/53`。
23:15 CST 已启动 current RTL 新 compat quick-map
`compat_quick_map_low_id_busy_direct_9t20_20260509_231547_eda-05`；23:16 CST 早期日志
显示已完成 SRAM/stdcell db 读取并进入 analyze，暂未看到 fatal/error。

23:42 CST 已并行启动 current RTL full-top 1GHz full compile
`full_compile_1g_id_busy_9t20_20260509_234201_eda-05`。启动 full-top 的原因是 full
top 本身很慢，但它能尽早暴露 top-level setup 趋势；不应只等 `compat` 完成后再开始。
23:44 CST 快照：`compat` 已运行约 29 分钟、`full_top` 已运行约 3 分钟，二者都在
early elaborate 阶段，尚未进入 mapping optimization，也没有中间 setup/area 表。
未看到 fatal/error/OOM，eda-05 available memory 约 `359GiB`。

23:49 CST monitor 已按 30 分钟周期正常更新。`compat` 已在 23:46 CST 完成
`elaborate_done` 并生成 post-link reports，23:49 CST 进入 `quick_map_low_start`；
full-top 仍在 `elaborate_start`。`compat` post-link reference 对比显示 ID-busy
cleanup 没有降低 `MUX_OP_32_5_2048`、`MUX_OP_32_5_512`、
`SELECT_OP_2/3.8192`、`SELECT_OP_2/3.16384` 计数；这些宽选择更可能来自
`direct_slot_wdata_r`、`wr_payload_wdata`、`rd_resp_pool_data_c*`、
`rd_resp_data_r/rd_resp_pop_data_r` 等变量索引写入/读取的宽 payload array。
在 final timing 出来前不应继续修改 RTL，以免再次 stale 当前 full-top。

23:53-00:12 CST 做了两组不触碰 production RTL 的 payload-pool 小综合：
`32x512` vs `8x64` chunk，以及 response queue pool-index 同拍间接读 vs pool-index
打一拍。四个 probe 都在 1GHz quick-map 下 setup pass，面积差异很小，且 chunk/stage
版本仍被 DC 重组出 `MUX_OP_32_5_512`。结论是：在没有 compat/full-top final
failing endpoint 前，不应盲目把 production payload pool 机械拆 chunk 或给 pool index
增加一拍；如果后续 timing 失败，需要按真实 endpoint 定向处理。

00:18 CST monitor 正常刷新。full-top 已在 00:14 CST `elaborate_done` 并通过
`LINK_SANITY_PASS`，post-link DDC 约 `93MB`；随后进入 precompile `report_qor`，
00:20 CST `axi_llc_subsystem_dual_qor_precompile.rpt` 仍为 `0` 字节，`compile_start`
尚未出现。参考旧 full-top run，elaborate 后生成 precompile QoR/timing 可能需要约
10 分钟，因此当前不判定卡死。`compat` quick-map 仍在 Pass 1 Mapping，尚无 final
quick-map timing/QoR。

00:31 CST 复查：full-top 已在 00:23 CST 正常进入 `compile_start` / Pass 1 Mapping。
precompile QoR/timing 已生成，早期 setup 指标为 Critical Path Slack `+0.33ns`、
TNS `0.00`、setup violating paths `0`。precompile 最坏路径是
`compat/core/data_store/.../u_macro` 到
`compat/core/data_store/.../rd_row_capture_r_reg[*]`，即 data SRAM macro Q 到 capture
register，slack 约 `+0.33ns`。这不是 final mapped setup pass 结论，但说明 current
RTL full-top 在 link/precompile 阶段没有立即暴露 setup failure。full-top 当前仍在
compile；`compat` quick-map 仍在 Pass 1 Mapping。

01:22 CST 复查：`compat` quick-map 仍在 Pass 1 Mapping，但 raw log 正在推进；
已观察到 `axi_llc_subsystem_compat_DW01_cmp6` 处理计数约 `775`、
`DW01_cmp2` 约 `426`、`DW01_add` 约 `150`。这比 payload-pool probe 更明确地指向
line/address hazard 比较网络的展开成本。若 `compat` 后续 timeout 或 final timing fail，
优先考虑组合 summary 复用 `local_write_line_pending()` / `read_capture_line_hazard()` /
`dispatch_path_line_hazard()` / `core_path_line_hazard()`，而不是盲目拆 payload pool 或
新增 pipeline。full-top 仍在 Pass 1 Mapping；RSS/CPU 正常，无 fatal/OOM。

01:24 CST 已重启 `rtl/dc/monitor_dc_status.sh`，新 PID `1506136`。新 monitor 会把
`Processing '...'` 行纳入 `dc_status_latest.txt`，便于观察 Pass 1 Mapping 是否仍在
推进。重启只影响监控脚本，不影响两个 DC 进程。重启后即时状态显示 compat 已推进到
`DW01_cmp6_967` / `DW01_cmp2_465` 左右；full-top 正在处理 uniquified compat 实例。

| marker | run | top |
| --- | --- | --- |
| `.latest_cache_ctrl_low_probe` | `cache_ctrl_only_quick_map_low_mshr_payload_banked_direct_9t20_20260509_012946_eda-05` | `llc_cache_ctrl` |
| `.latest_valid_ram_low_probe` | `valid_ram_quick_map_low_banked_prod_direct_9t20_20260509_035710_eda-05` | `llc_valid_ram` |
| `.latest_core_only_low_probe` | `core_only_quick_map_low_direct_store_split_direct_9t20_20260509_152105_eda-05` | `axi_llc_subsystem_core`，final setup pass |
| `.latest_compat_low_probe` | `compat_quick_map_low_read_count_9t20_20260510_111925_eda-05` | `axi_llc_subsystem_compat`，latest read-count RTL 正在 elaborate |
| `.latest_full_quick_map_low_probe` | `full_quick_map_low_read_count_9t20_20260510_111925_eda-05` | `axi_llc_subsystem_dual` quick-map，latest read-count RTL 正在 elaborate |
| `.latest_full_compile_1g` | `full_compile_1g_read_count_9t20_20260510_111925_eda-05` | `axi_llc_subsystem_dual` full compile，latest read-count RTL 正在 elaborate |

2026-05-09 03:58 CST 快照：

- `llc_valid_ram` production RTL 已从 flat 8192-entry regfile 改成仅生产配置启用的
  64-bank regfile。其它小参数配置仍走原 flat 分支；两个依赖 XMR 的小配置 testbench
  已改为访问 `valid_ram.gen_flat.valid_mem`。
- 变更前的 original `valid_ram` quick-map 卡在 mapping/area-recovery，且 post-link
  reference 显示 `SEQGEN=131111`、`MUX_OP_8192_13_16`、`SELECT_OP_2.8192`；banked
  probe 则已 final setup pass，slack `+0.37ns`。因此已将 banked 结构迁移到生产
  `llc_valid_ram`。
- 迁移后验证已通过：LLC hit-only performance
  `local_debug/vcs_cpp_llc_hit_perf_contract_20260509_035047`，bounded non-hit
  `local_debug/vcs_cpp_perf_contract_20260509_035050`，全量 RTL contracts
  `rtl/local_debug/vcs_all_contracts_20260509_035411`，结果 `53/53`。
- 03:57 CST 已用当前 RTL 重新启动 `llc_valid_ram`、`axi_llc_subsystem_core`、
  `axi_llc_subsystem_compat` 三条 1GHz quick-map low run；三条均确认使用 9T20 stdcell
  和 SMIC12 data/meta SRAM db，早期已进入 analyze，暂未看到 fatal/error。
- 04:11 CST `llc_valid_ram` production RTL run 已完成 final report：Critical Path Slack
  `0.37ns`、Total Negative Slack `0.00`、setup violating paths `0`、Cell Area
  `223518.891971`，因此当前生产 `llc_valid_ram` 可判为 1GHz setup pass。
- `axi_llc_subsystem_core` 已完成 elaborate/link sanity 并在 04:07:26 进入 mapping；
  `axi_llc_subsystem_compat` 仍在 elaborate。两条尚无 final QoR/timing。
- 04:15 CST 修正 `axi_llc_write_mapped_outputs`：DC O-2018.06 已不支持
  `write -format db`，后续 run 不再尝试写 mapped `.db`，改为保留 DDC、Verilog
  netlist、SDC/SDF/SPF，并在 `outputs/db` 写 README 说明。当前已经启动的 core/compat
  run 在启动时已加载旧 proc，如跑完时仍出现 `UID-530`，不影响 timing/QoR 结论；
  后续新 run 会使用修正后的脚本。
- 04:28 CST 复查：`core_only` 仍在 Mapping Optimization，log 已有 QoR 表头但尚无
  有效 slack/area 行或 final report；`compat` 仍在 elaborate。两个进程 CPU/RSS
  正常，未看到 fatal/OOM。
- 04:58 CST 复查：`core_only` 已推进到 Mapping Optimization Phase 2，但仍没有
  slack/area 数值或 final report；`compat` 仍在 elaborate。两个进程约运行 `1h01m`，
  RSS 分别约 `12.6GB` / `6.5GB`，系统可用内存约 `351GiB`，未看到 OOM/fatal。
- 05:31 CST 复查：`core_only` 已推进到 Mapping Optimization Phase 3，但仍没有
  slack/area 数值或 final report；`compat` 已在 05:15:11 完成 elaborate/link sanity，
  05:22:03 进入 mapping。两个进程约运行 `1h34m`，RSS 分别约 `12.6GB` / `8.7GB`，
  系统可用内存约 `349GiB`，未看到 OOM/fatal。
- 当前 compat post-link reference 显示 `SEQGEN=133661`，相比旧
  `compat_quick_map_low_mshr_payload_resp_chunk_direct...` 的 `SEQGEN=151549` 有下降，
  说明 write payload pool 和 banked valid 对综合规模有正向作用。但仍残留
  `SELECT_OP_2.65536_2.1_65536`、`SELECT_OP_2.16384`、`SELECT_OP_2.8192` 等宽选择；
  如果 compat final timing 失败，应优先定位这些剩余宽 cone。

2026-05-09 03:21 CST 快照：

- `axi_llc_subsystem_compat` 又做了一次结构性 RTL 优化：把写请求 FIFO 中
  `NUM_WRITE_MASTERS * 32` 个物理 `512b` payload 槽改成全局 `32` entry
  write payload pool，per-master FIFO 只保存 pool index。该修改保持“全局 write
  outstanding 最大 32，单个 master 仍可占满 32”的语义，但避免 4-master 配置下
  生成 `128x512b` 的宽数据队列。
- 因该 RTL 修改，旧
  `compat_quick_map_low_mshr_payload_resp_chunk_direct_9t20_20260509_012946_eda-05`
  已标记 stale 并停止；它的 post-link reference 显示 `SEQGEN=151549`，并存在
  `SELECT_OP_2.65536_2.1_65536`，这是触发本轮 write payload pool 优化的主要证据。
- 写 payload pool 修改后已通过 `git diff --check`、LLC hit-only performance、
  bounded non-hit performance 和全量 RTL contracts `53/53`。其中 LLC hit-only run 为
  `local_debug/vcs_cpp_llc_hit_perf_contract_20260509_031453`，bounded non-hit run 为
  `local_debug/vcs_cpp_perf_contract_20260509_031510`，全量 contracts run 为
  `local_debug/vcs_all_contracts_20260509_031513`。
- 新 compat run
  `compat_quick_map_low_wr_payload_pool_direct_9t20_20260509_031853_eda-05`
  已启动，确认使用 9T20 stdcell 和 SMIC12 data/meta SRAM db；03:19:19 进入
  elaborate，早期暂未看到 fatal/error。该 run 使用已补充 mapped output 的脚本。
- `core_only_quick_map_low_mshr_payload_banked_direct_9t20_20260509_012946_eda-05`
  仍在运行，已从 `Mapping Optimization (Phase 1)` 推进到 `Phase 2`，尚无 final
  QoR/timing。

2026-05-09 03:05 CST 快照：

- 当前仍在运行的我方 DC 进程为 `axi_llc_subsystem_core` 和
  `axi_llc_subsystem_compat` 两条；`llc_cache_ctrl` 已完成并生成 final report。
- `core_only_quick_map_low_mshr_payload_banked_direct_9t20_20260509_012946_eda-05`
  已完成 elaborate/link sanity 并进入 `Mapping Optimization (Phase 1)`；raw log
  第一张 QoR 表显示面积约 `9.16M`，setup cost 仍很大，尚不能判断最终是否收敛，
  也尚未生成 final QoR/timing。
- `compat_quick_map_low_mshr_payload_resp_chunk_direct_9t20_20260509_012946_eda-05`
  仍在 elaborate/build 子模块阶段；log 持续更新，暂未看到 fatal/error，也尚未生成
  final QoR/timing。
- 上述 core/compat run 启动早于 02:30 CST 对 quick-map 脚本新增 mapped netlist
  输出的补丁；如果后续需要保留 mapped netlist，应使用已补丁后的脚本重新启动对应
  run。

2026-05-09 01:31 CST 早期状态：

- `cache_ctrl_only_quick_map_low_mshr_stage_split_direct_9t20_20260509_001204_eda-05`、
  `core_only_quick_map_low_mshr_stage_compat_pop_current_direct_9t20_20260509_010952_eda-05`
  和 `compat_quick_map_low_resp_chunk_direct_9t20_20260509_012043_eda-05`
  因后续 `llc_cache_ctrl` MSHR payload banking RTL 修改已手动停止并标记 stale。
- 三条新 run 均已确认读取 9T20 stdcell 和 SMIC12 data/meta SRAM db。
  `llc_cache_ctrl` 已在 02:18:56 完成 quick-map，02:19:13 生成报告；
  `llc_cache_ctrl_quick_map_low_qor.rpt` 显示 Critical Path Slack `0.00`、
  Total Negative Slack `0.00`、No. of Violating Paths `0`、Cell Area
  `110337.810553`，因此 `llc_cache_ctrl` 当前 RTL 可判为 1GHz setup pass。
  注意：该 `llc_cache_ctrl` run 启动时 quick-map 脚本尚未写 mapped netlist；
  02:30 CST 已补充 `run_dual_quick_map_low_1g.tcl` 的
  `axi_llc_write_mapped_outputs ${top_name}_quick_map_low` 调用，后续新启动的 run
  会保留 ddc/verilog/db/sdc/sdf/spf。
  `core` 已在 01:40:38 完成 elaborate，已通过 link sanity，01:41:42 进入
  `quick_map_low_start` / Beginning Pass 1 Mapping，02:30 CST 仍在 Mapping Phase 1。
  `compat` 仍在 elaborate。暂未看到 fatal/error。
- `llc_cache_ctrl` MSHR payload banking 对 post-link reference 有正向效果：
  旧 run 中 `SELECT_OP_2.4096` / `8192` / `2048` 有多项，新 run 中
  `4096` 级 select 已消失，`8192` 和 `2048` 各剩 1 项。但仍有
  `SEQGEN=60190` 和 1 个 `SELECT_OP_2.16384_2.1_16384`，因此只能说明综合复杂度
  有改善，不能据此判 setup 收敛。静态扫当前 RTL 后，原先 flattened MSHR payload
  已清掉；剩余大宽度主要来自合法的 data/meta row 总线、`victim_line_addr` 导出和
  cacheline row placement/extract 逻辑，下一步应等 mapping/timing 给出真实 endpoint
  后再决定是否继续 RTL 拆分。
- `axi_llc_subsystem_compat` 的
  `compat_quick_map_low_compat_pop_stage_direct_9t20_20260509_010726_eda-05`
  在 01:16 CST 被手动停止并标记 stale，原因是后续又做了 response payload
  chunk banking：外部 `READ_RESP_BITS=2048` 契约不变，内部
  `rd_resp_data/pop/pool` 改按 `min(READ_RESP_BITS, LINE_BITS)` 分块存储；
  生产配置等价于把 `32x2048` pool mux 拆成 4 个 `32x512` chunk cone。
  新 run `compat_quick_map_low_resp_chunk_direct_9t20_20260509_012043_eda-05`
  已确认读取 9T20 stdcell 和 SMIC12 data/meta SRAM db，01:21:10 进入 elaborate；
  暂未看到 fatal/error。
- 当前只看到上述三条我方 DC 进程；没有看到 OOM 或早期 fatal。
- 最新 LLC hit 性能对齐证据：
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_mshr_payload_banked_20260509_012630_eda-05/run.log`
  显示 `PERF LLC_HIT_READ64 CHECKED ready=0 resp=7 external=-1` 和
  `PASS LLC_HIT_ONLY`。最新 bounded non-hit 证据：
  `rtl/local_debug/vcs_cpp_perf_contract_mshr_payload_banked_20260509_012648_eda-05/run.log`
  显示 `PASS bounded_non_hit max_extra_observed=5 direct_max_extra_allowed=6
  llc_miss_max_extra_allowed=8`。最新全量 RTL contracts：
  `rtl/local_debug/vcs_all_contracts_mshr_payload_banked_20260509_012703_eda-05`
  显示 `SUMMARY total=53 passed=53 failed=0`。

2026-05-08 18:57 CST 快照：

- 10:54 CST 的 `write_pack_partselect` bridge run 已判定为 stale：`bridge_ddr64`
  在 3600s timeout 后退出码 `124`，旧 log 仍含 `axi_llc_axi_write_pack...DW_rash`
  / `DW01_ash` / `DW01_sub` / `DW01_add`；旧 `bridge_dual` 已手动停止。
- 12:02 CST 的 `write_pack64_case` 版 `bridge_dual` 和 `bridge_ddr64_probe`
  因后续 `mode2_shape/beat_shape` production 常量路径 cleanup 已停止为 stale。
- 12:49 CST 已重启 `shape_fast` 版 `bridge_dual` 和 `bridge_ddr64_probe`。
  后续 `bridge_ddr64_probe` log 暴露 `axi_llc_axi_read_pack` 仍有 `DW_rash`、
  `DW01_add`、`DW01_cmp`、`DW01_sub` 结构，因此这两条 run 已停止为 stale。
- 13:43 CST 已重启 `read_pack64_case` 版 `bridge_dual` 和 `bridge_ddr64_probe`。
  两条 run 均在 7200s timeout 后退出码 `124`，没有 final timing/QoR：`bridge_dual`
  停在 Delay Optimization，`bridge_ddr64_probe` 停在 Area-Recovery cleanup。
  因没有 RTL 变更，15:49 CST 已用同一当前 RTL、同一 9T20/SMIC12 SRAM db 约束、
  14400s timeout 重启两条 bridge quick-map。`bridge_ddr64_probe` 已于 17:28 CST
  正常结束并 setup pass；`bridge_dual` 已于 18:05 CST 正常结束并 setup pass。
- 10:22 CST 的旧 `cache_ctrl_only` 在 7200s timeout 后退出码 `124`，中间表曾显示
  setup 仍严重违例（WNS 数字约 `3283.89`，DC 以正数打印 violation magnitude）；
  该 run 早于最新 `extract_read_response` cleanup，已不作为当前 RTL 结论。
- 10:40 CST 的旧 `compat` 因 `llc_cache_ctrl.v` 修改过时，已停止并标记 stale。
- 12:34 CST 已重启 `cache_ctrl_only` 和 `compat`。`cache_ctrl_only` 已在
  Mapping Optimization Phase 46 后 7200s timeout，退出码 `124`，没有 final
  timing/QoR，因此不能判 setup pass/fail；`compat` 已在 14:07:57 CST 完成 elaborate，
  并于 14:30:39 CST 进入 Pass 1 Mapping，尚未给出 final timing/QoR。
- 14:37 CST 已利用 `cache_ctrl_only` 释放出的 DC slot 启动
  `axi_llc_subsystem_core` quick-map，使用同一 9T20/SMIC12 SRAM db 约束。该 run
  已于 16:37 CST timeout，尚无 final timing/QoR；末尾停在
  `llc_mapped_window_ctrl...DW01_cmp6_3667`，说明 mapped-window 写合并逻辑可能
  正在生成数千个比较器，是下一步应优先修复的结构性问题。
- 17:43-18:49 CST 修复 mapped-window/core direct path 后完成 VCS 验证：
  `tb_llc_mapped_window_ctrl`、`tb_axi_llc_subsystem_dual_mapped_window_prod_contract`、
  `tb_axi_llc_subsystem_core_startup_idle_contract`、LLC hit-only performance、
  bounded performance、全量 RTL contracts `53/53` 均通过。LLC hit 仍保持
  `ready=0 resp=7 external=-1`。
- 18:53 CST 已启动 current RTL 的 `core_only` 和 `compat` long probe，均使用
  `14400s` timeout、9T20 标准单元和 SMIC12 data/meta SRAM db；18:54 CST 早期
  快照显示两条均已进入 analyze，暂未看到 fatal/error。
- 19:10-19:14 CST 根据旧 full-top endpoint `compat_rd_q_count_reg_3__2_` 到
  `read_req_ready[0/2/3]` 的路径，进一步清理 `axi_llc_subsystem_compat`
  非 DCache read ready 输出：非 DCache master 不再在输出端重复使用
  `rd_q_count` / total outstanding / DCache same-cycle 选择锥，只使用已注册 grant
  并保留 maintenance、请求合法性、hazard 和 ID conflict 门控。DCache same-cycle
  LLC-hit 路径保持原逻辑。LLC hit-only performance、bounded performance 和全量
  RTL contracts `53/53` 均通过。
- 由于上述 RTL 修改，18:53 CST 的 `core_only` / `compat` run 已停止为 stale。
  19:14 CST 已使用当前 RTL 重新启动
  `core_only_quick_map_low_compat_ready_current_direct_9t20_20260508_191440_eda-05`
  和
  `compat_quick_map_low_compat_ready_current_direct_9t20_20260508_191440_eda-05`。
  19:15 CST 早期日志显示两条均完成 analyze 并进入 elaborate，暂未看到
  fatal/error。
- 19:17-19:21 CST 继续清理 `axi_llc_subsystem_compat` write ready 输出：
  `write_req_ready` 不再在输出端重复依赖 `wr_q_count` / total outstanding。
  该修改针对旧报告中 `compat_wr_q_count_reg_1__1_ -> write_req_ready[0/1]`
  的同类输出路径；LLC hit-only performance、bounded performance 和全量 RTL
  contracts `53/53` 均通过。
- 由于 write ready RTL 修改，19:14 CST 的 `core_only` / `compat` run 已停止为
  stale。19:21 CST 已使用当前 RTL 重新启动
  `core_only_quick_map_low_compat_rw_ready_current_direct_9t20_20260508_192155_eda-05`
  和
  `compat_quick_map_low_compat_rw_ready_current_direct_9t20_20260508_192155_eda-05`。
  19:23 CST 早期日志显示两条均完成 analyze 并进入 elaborate，暂未看到
  fatal/error。
  19:36 CST `core_only` 已通过 link sanity 并进入 `quick_map_low_start` /
  Pass 1 Mapping；20:20 CST `compat` 也已通过 link sanity 并进入
  `quick_map_low_start` / Pass 1 Mapping。两条 current RTL DC 目前都在映射阶段，
  尚未生成中间 WNS/TNS 或 final QoR/timing。21:37 CST 复查时，两条进程仍在
  `common_shell` 中运行：`core_only` 约运行 `2h15m`、RSS 约 `7.4GB`，log 停在
  `Mapping Optimization (Phase 1)`；`compat` 约运行 `2h15m`、RSS 约 `13GB`，
  log 停在 `Beginning Pass 1 Mapping`。没有看到 fatal/error，也没有生成 final
  report。23:24 CST 两条均被 `14400s` timeout SIGTERM 终止：`core_only` 停在
  Mapping Optimization Phase 1，`compat` 停在 Beginning Pass 1 Mapping；两条均无
  final QoR/timing，因此当前 RTL 的 `core` / `compat` setup 仍未证明收敛。
  `core_only` timeout 前原始 log 正在处理 `llc_mshr_write_hit_scan` /
  `llc_mshr_pending_scan` 的大量 `DW01_cmp6`，初始优化表面积约 `9.17M`，WNS/SETUP
  cost 数字极大；`compat` post-link reference 显示约 `143337` 个 `SEQGEN`，
  并含 `65536` 位 select operator，说明 compat 内部超宽寄存器/队列选择结构仍是
  明确的综合复杂度风险。
- 13:58 CST 启动过纯组合 `llc_mshr_pending_scan` probe，但通用 1GHz 约束脚本找不到
  clock，不能作为 timing 结论；14:01 CST 改用寄存器 wrapper 后得到可信
  reg-to-reg timing，1GHz setup pass。该 helper 在 cache_ctrl log 中会展开约
  `128` 个 `DW01_cmp6`，会拖慢 mapping，但单独看不是明显无法 1GHz 的 cone。
- 21:40 CST 在 eda-05 当前可用内存约 `332GiB` 的前提下，补充启动
  `llc_cache_ctrl` current RTL 1GHz/9T20/SMIC12-SRAM 长 probe：
  `cache_ctrl_only_quick_map_low_current_direct_9t20_20260508_214010_eda-05`。
  早期 log 已确认读取 9T20 stdcell db 和 SMIC12 data/meta SRAM db；21:40 CST
  已完成 analyze 并进入 elaborate；21:52 CST 已通过 link sanity 并进入
  `quick_map_low_start` / Pass 1 Mapping；22:24 CST 已进入 Mapping Optimizations
  并打印 QoR 表头；22:52 CST 已推进到 Mapping Optimization Phase 16，但还没有第一行
  slack/area 或 final timing，未看到 fatal/error。
- 21:42 CST 复查旧 `cache_ctrl_only_quick_map_low_extract64_fix...` post-link
  report：`llc_cache_ctrl` 有约 `59125` 个 `SEQGEN`，且存在多个
  `8192/4096/2048` 位 `SELECT_OP`。主要来源是 `mshr_victim_data_r`、
  `mshr_refill_line_r`、`mshr_wdata_r` 三组 `MSHR_COUNT*LINE_BITS` payload
  寄存器，以及按动态 MSHR slot 读取这些 payload 的路径。旧 timeout log 的末尾
  虽停在 `llc_mshr_pending_scan` 的 128 个比较器映射上，但这只是可见的 mapping
  慢点；如果 current DC endpoint 指向 `mshr_issue_slot` / `mshr_commit_slot` 到
  `mem_req_wdata` / `install_line` 等宽数据选择，则需要专门拆宽 payload/slot mux
  路径，而不能只继续优化 pending-scan helper。
- 21:46 CST 新增并启动 `llc_mshr_payload_mux_timing_probe`，用于隔离
  `cache_ctrl` 中 `32x512b` MSHR payload 动态 slot mux 与 refill/write merge
  reg-to-reg timing。该 probe 不进入生产 RTL。21:49 CST 已通过 link sanity 并进入
  `quick_map_low_start` / Pass 1 Mapping；21:56 CST 仍停在
  `Mapping Optimization (Phase 1)`；21:57 CST 进入 `Phase 2`；22:02 CST 进入
  `Phase 3`；22:17 CST 该 probe 在 `Phase 4` 被 `1800s` timeout 终止，没有生成
  中间 QoR 或 final timing。该结果只能作为宽 payload mux/merge 结构综合复杂度
  风险证据，不能单独视为 setup fail；后续需要结合 `cache_ctrl` current run 的
  真实 endpoint 决定是否拆宽 payload/slot mux 路径。
- 22:20 CST 新增并启动 `llc_mshr_payload_mux_split_timing_probe`，作为
  payload mux 对照实验：第一拍只做动态 slot 选择并打入寄存器，第二拍再做
  refill/write merge。该 probe 也不进入生产 RTL，用于判断两级拆分是否明显降低
  综合复杂度。22:24 CST 已完成 analyze 并进入 elaborate；22:29 CST 已通过 link
  sanity 并进入 quick-map；22:51 CST 在 Area-Recovery cleanup 被 `1800s`
  timeout 终止，没有生成 final QoR/timing。对比未拆版只到 Mapping Phase 4，
  split 版推进到 Delay Optimization/Area-Recovery，说明两级拆分方向有综合复杂度
  收益，但仍不足以作为最终 setup 证据。
- 当前只看到 `cache_ctrl` 一条我方 DC 仍在运行；没有看到我方 run 引起 OOM 或僵死
  的迹象。

## 已完成的 RTL/验证工作

- LLC hit performance contract 已按实际 C++ `AXI_Interconnect` 与实际 RTL
  `axi_llc_subsystem_dual` 对齐：`LLC_HIT_READ64 ready=0 resp=7 external=-1`。
- non-hit bounded performance gate 已通过：direct DDR/MMIO 最大额外延迟在
  `<=6 cycle` 阈值内，clean read miss/refill 最大额外延迟在 `<=8 cycle` 阈值内。
- `axi_llc_axi_read_pack` / `axi_llc_axi_write_pack` 已从超宽 dynamic shift 清理为
  indexed part-select；4B single-beat 路径已拆成 generate-isolated fast path。
- 2026-05-08 继续清理 `axi_llc_axi_write_pack` generic 分支：去掉 byte get/set helper
  中的动态移位，改用 indexed part-select。验证证据：`axi_write_pack`、
  `axi_write_pack_prod_width`、`axi_write_pack_single4` 三个 hw-cbmc 均
  `VERIFICATION SUCCESSFUL`；LLC hit-only perf、bounded perf 和全量 RTL contracts
  `53/53` 均通过。10:12 CST 启动的 bridge/DDR64 DC 因该 RTL 修改已停止为 stale，
  当前 bridge/DDR64 run 已于 10:54 CST 重启。
- 2026-05-08 11:11 CST 对最新 performance gate 做证据复核：
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_write_pack_partselect_20260508_104611_eda-05/run.log`
  显示 `PERF LLC_HIT_READ64 CHECKED ready=0 resp=7 external=-1` 和
  `PASS LLC_HIT_ONLY`；
  `rtl/local_debug/vcs_cpp_perf_contract_write_pack_partselect_20260508_104619_eda-05/run.log`
  显示 `PASS bounded_non_hit max_extra_observed=5 direct_max_extra_allowed=6
  llc_miss_max_extra_allowed=8`。
- 2026-05-08 12:02 CST 进一步清理 `axi_llc_axi_write_pack` production
  `LINE_BYTES=64` / `AXI_DATA_BYTES=32` 路径：新增常量 slice/case generate 分支，
  避免 DC 将 variable indexed part-select 继续综合成 `DW_rash` / `DW01_ash`
  barrel-shift 结构。验证证据：`axi_write_pack`、`axi_write_pack_single4`、
  `axi_write_pack_prod_width`、`bridge_prod_width_cacheline_write_shape`、
  `dual_bridge_prod_width_cacheline_write_shape`、`dual_bridge_prod_width_mode2_write`
  六个 hw-cbmc 均 `VERIFICATION SUCCESSFUL`；LLC hit-only perf log
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_write_pack64_case_20260508_114902_eda-05/run.log`
  显示 `PERF LLC_HIT_READ64 CHECKED ready=0 resp=7 external=-1`；bounded perf log
  `rtl/local_debug/vcs_cpp_perf_contract_write_pack64_case_20260508_114929_eda-05/run.log`
  显示 `PASS bounded_non_hit max_extra_observed=5 direct_max_extra_allowed=6
  llc_miss_max_extra_allowed=8`；全量 RTL contract
  `rtl/local_debug/vcs_all_contracts_write_pack64_case_20260508_114955_eda-05`
  为 `SUMMARY total=53 passed=53 failed=0`。
- 2026-05-08 12:24 CST 修复 `llc_cache_ctrl.extract_read_response` 64B
  production 路径：把 512-bit 常量 case 用 generate 隔离，窄参数 testbench 继续走
  generic function，避免 VCS 在非生产宽度下看到非法 part-select/负 repeat count。
  验证证据：LLC hit-only perf
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_cache_extract64_case_20260508_121006_eda-05`
  通过；bounded perf
  `rtl/local_debug/vcs_cpp_perf_contract_cache_extract64_case_20260508_121311_eda-05`
  通过；单点 `tb_axi_llc_subsystem_core_startup_idle_contract`
  `rtl/local_debug/vcs_single_core_startup_idle_cache_extract64_fix_20260508_122402_eda-05`
  通过；全量 RTL contracts
  `rtl/local_debug/vcs_all_contracts_cache_extract64_fix_20260508_122430_eda-05`
  为 `SUMMARY total=53 passed=53 failed=0`。
- 2026-05-08 12:49 CST 清理 bridge helper 的 production 常量路径：
  `axi_llc_axi_mode2_shape` 对 `64B line / 32B AXI beat` 使用 power-of-two
  对齐与 9-bit end-size 判断，避免除法/乘法和宽 subtract；`axi_llc_axi_beat_shape`
  对 `AXI_DATA_BYTES=32` 使用阈值 case，避免除法和 decrement 结构。
  验证证据：`formal/axi_beat_shape`、`formal/axi_mode2_shape`、
  `formal/axi_mode2_shape_single4`、`formal/axi_issue_select` 均
  `VERIFICATION SUCCESSFUL`；LLC hit-only perf
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_shape_fast_20260508_124055_eda-05`
  通过；bounded perf
  `rtl/local_debug/vcs_cpp_perf_contract_shape_fast_20260508_124116_eda-05`
  通过；全量 RTL contracts
  `rtl/local_debug/vcs_all_contracts_shape_fast_20260508_124146_eda-05`
  为 `SUMMARY total=53 passed=53 failed=0`。
- 2026-05-08 13:36 CST 清理 `axi_llc_axi_read_pack` production
  `READ_RESP_BYTES=64` / `AXI_DATA_BYTES=32` / `MODE2_EXTRACT_BYTES=64` 路径：
  两拍 256-bit DDR read response 用常量 slice 合并，mode2 extract 用 64 项
  constant-case，避免 DC 继续生成 512-bit variable shift 以及 63 组 add/cmp
  结构。验证证据：`formal/axi_read_pack`、`formal/axi_read_pack_single4`、
  `formal/axi_read_pack_prod_width` 均 `VERIFICATION SUCCESSFUL`；LLC hit-only perf
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_read_pack64_case_20260508_133616_eda-05`
  通过；bounded perf
  `rtl/local_debug/vcs_cpp_perf_contract_read_pack64_case_20260508_133632_eda-05`
  通过；全量 RTL contracts
  `rtl/local_debug/vcs_all_contracts_read_pack64_case_20260508_133650_eda-05`
  为 `SUMMARY total=53 passed=53 failed=0`。
- single4 的 mode2/read_pack/write_pack targeted formal/VCS 已通过，并已纳入
  stable formal/回归入口。
- 已增加当前 RTL 的 `core_only.f` 和 `compat_only.f` probe 入口，避免下一步只等待
  full top 黑盒长跑。
- 已增加 `llc_mshr_pending_scan` 的独立 DC timing wrapper probe，用于区分
  cache_ctrl 内部 mapping 慢点和真正 setup fail cone；该 probe 不进入生产 RTL。
- 2026-05-08 17:43-18:49 CST 清理 `llc_mapped_window_ctrl` 和
  `axi_llc_subsystem_core` mode2 direct path：生产 64B window 写 merge 改为
  constant-case，生产 `16-way/8-window-way` read line select 改为 direct case，
  core 内 mode2 direct read response、way onehot、write-row placement 改为生产参数
  constant-case。验证证据：`rtl/local_debug/vcs_mapped_window_core_direct_case_20260508_184914_eda-05`、
  `rtl/local_debug/vcs_mapped_window_prod_core_direct_case_20260508_184917_eda-05`、
  `rtl/local_debug/vcs_core_startup_core_direct_case_20260508_184920_eda-05` 通过；
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_core_direct_case_20260508_184945_eda-05`
  和 `rtl/local_debug/vcs_cpp_perf_contract_core_direct_case_20260508_184949_eda-05`
  通过；全量 RTL contracts
  `rtl/local_debug/vcs_all_contracts_core_direct_case_20260508_184952_eda-05`
  为 `SUMMARY total=53 passed=53 failed=0`。
- 2026-05-08 19:10-19:14 CST 清理 `axi_llc_subsystem_compat` 非 DCache
  `read_req_ready` 输出路径，避免旧 full-top 暴露的
  `compat_rd_q_count_reg_3__2_ -> read_req_ready[0/2/3]` 输出路径继续穿过
  FIFO count / total outstanding / DCache same-cycle 选择锥。验证证据：
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_compat_ready_current_20260508_191008_eda-05`
  通过；`rtl/local_debug/vcs_cpp_perf_contract_compat_ready_current_20260508_191012_eda-05`
  通过；全量 RTL contracts
  `rtl/local_debug/vcs_all_contracts_compat_ready_current_20260508_191016_eda-05`
  为 `SUMMARY total=53 passed=53 failed=0`。
- 2026-05-08 19:17-19:21 CST 同步清理 `axi_llc_subsystem_compat`
  `write_req_ready` 输出路径，避免旧 full-top 暴露的
  `compat_wr_q_count_reg_1__1_ -> write_req_ready[0/1]` 输出路径继续穿过
  FIFO count / total outstanding。验证证据：
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_compat_rw_ready_current_20260508_191800_eda-05`
  通过；`rtl/local_debug/vcs_cpp_perf_contract_compat_rw_ready_current_20260508_191804_eda-05`
  通过；全量 RTL contracts
  `rtl/local_debug/vcs_all_contracts_compat_rw_ready_current_20260508_191807_eda-05`
  为 `SUMMARY total=53 passed=53 failed=0`。
- 2026-05-09 03:50-03:54 CST 对最新 RTL 做目标审计：LLC hit 性能 gate
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_20260509_035047/run.log`
  显示 `PERF LLC_HIT_READ64 CHECKED ready=0 resp=7 external=-1`，并以
  `PASS LLC_HIT_ONLY` 结束；bounded non-hit gate
  `rtl/local_debug/vcs_cpp_perf_contract_20260509_035050/run.log` 显示
  `PASS bounded_non_hit max_extra_observed=5 direct_max_extra_allowed=6
  llc_miss_max_extra_allowed=8`；全量 RTL contracts
  `rtl/local_debug/vcs_all_contracts_20260509_035411` 为
  `SUMMARY total=53 passed=53 failed=0`。因此当前目标中的 LLC hit
  cycles/performance 已有最新证据，后续优先等待/解析 DC setup。
- 2026-05-09 05:34 CST 复核当前两条正在运行的 9T20 小模块 DC：
  `core_only_quick_map_low_banked_valid_wr_payload_direct_9t20_20260509_035710_eda-05`
  已从 04:07:26 进入 quick map，当前 log 停在 `Mapping Optimization
  (Phase 3)`，尚无 final QoR/timing；post-link 剩余主要大选择器为
  `SELECT_OP_2.2048` x1、`SELECT_OP_2.8192` x1。`compat` 同批 run
  已在 05:22:03 进入 quick map，尚无 final QoR/timing；post-link 仍有
  `SELECT_OP_2.8192` x2、`SELECT_OP_2.16384` x2、`SELECT_OP_2.65536` x1。
  这些只能作为若 final fail 后的排查方向，不能替代 final timing endpoint。
- 2026-05-09 05:37-05:43 CST 清理 `axi_llc_subsystem_compat`
  queued read response pool：把 32-slot/4-chunk response payload pool 从
  `[pool_slot * chunk + chunk]` 扁平数组拆成 4 个 32-entry chunk bank，避免
  DC 对生产配置推断 128-entry x 512-bit 的 `SELECT_OP_2.65536`。该改动不改变
  外部 2048-bit read response 合约，也不触碰 LLC hit 的直接 response 路径。
  验证证据：`rtl/local_debug/vcs_cpp_llc_hit_perf_contract_20260509_053743`
  显示 `PASS LLC_HIT_ONLY`；`rtl/local_debug/vcs_cpp_perf_contract_20260509_053753`
  通过 bounded non-hit；全量 RTL contracts
  `rtl/local_debug/vcs_all_contracts_20260509_053805` 为
  `SUMMARY total=53 passed=53 failed=0`。旧 `compat` run
  `compat_quick_map_low_banked_valid_wr_payload_direct_9t20_20260509_035710_eda-05`
  因该 RTL 修改已停止并标记 stale；新 `compat` quick-map run
  `compat_quick_map_low_resp_pool_banked_direct_9t20_20260509_054302_eda-05`
  已于 05:43 CST 启动，早期 DB/RTL analyze 正常，正在 elaborate。
- 2026-05-09 15:14 CST 复查 DC：`core_only_quick_map_low_banked_valid_wr_payload_direct_9t20_20260509_035710_eda-05`
  已完成 final report，但未收敛，QoR 为 Critical Path Slack `-0.14ns`、
  TNS `-21357.68`、violating paths `205708`、Cell Area `9105536.37`。最坏路径是
  `direct_wait_rd_r_reg -> valid_ram/gen_banked.../valid_mem_reg_*`，路径穿过
  `mapped_window_ctrl` 的 window/sub/add 逻辑到 `valid_ram.wr_set`。同一时间，
  `compat_quick_map_low_resp_pool_banked_direct_9t20_20260509_054302_eda-05`
  没有 final timing/QoR，3h24m 后被 timeout Signal 15 停在 Mapping Optimizations
  早期；post-link 已确认 `SELECT_OP_2.65536` 消失，但仍残留 `SELECT_OP_2.16384`
  x6、`SELECT_OP_2.8192` x2、`MUX_OP_32_5_2048` x4 等结构。因此 `compat`
  之前不能判为 setup 收敛。
- 2026-05-09 15:16-15:19 CST 针对 core 最坏路径修正
  `axi_llc_subsystem_core`：把 mode2 direct 的 read-store 选择
  (`direct_wait || direct_accept`) 与 write-store 选择 (`direct_wait`) 拆开，
  避免 `direct_wait_rd_r` 通过 `mapped_window_ctrl` 组合路径影响 valid/data write
  端 mux。该修改不触碰 LLC hit 路径。验证证据：
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_20260509_151706` 通过
  `PASS LLC_HIT_ONLY`；`rtl/local_debug/vcs_cpp_perf_contract_20260509_151709`
  通过 bounded non-hit；`rtl/local_debug/vcs_all_contracts_20260509_151728`
  为 `SUMMARY total=53 passed=53 failed=0`。
- 2026-05-09 15:21 CST 基于最新 RTL 同步启动三条 DC：`core_only`
  quick-map `core_only_quick_map_low_direct_store_split_direct_9t20_20260509_152105_eda-05`、
  `compat` quick-map `compat_quick_map_low_direct_store_split_direct_9t20_20260509_152105_eda-05`、
  full-top full compile `full_compile_1g_direct_store_split_9t20_20260509_152105_eda-05`。
  三条均确认使用 SMIC12 9T20 stdcell 与当前 SMIC12 data/meta SRAM `.db`，早期
  read_db/analyze 已正常开始，暂未看到 fatal/error。
- 2026-05-09 16:37 CST 复查三条新 DC：`core_only` 已完成 elaborate/link sanity，
  15:30:28 进入 quick-map，目前在 Area-Recovery，尚无 final QoR/timing；post-link
  仍有 `SELECT_OP_2.2048` x1、`SELECT_OP_2.8192` x1，但需要 final timing endpoint
  才能判断是否有害。`compat` 已完成 elaborate/link sanity，15:55:34 进入 quick-map；
  post-link 仍有 `MUX_OP_32_5_2048` x4、`SELECT_OP_2.16384` x6、
  `SELECT_OP_2.8192` x2，说明 compat 仍有明显综合规模风险，尚不能判定 setup。
  Full-top 已完成 elaborate/link sanity，16:03:24 进入 `compile_ultra -retime`；
  precompile QoR 显示 Critical Path Slack `+0.33ns`、TNS `0.00`、violating paths
  `0`、Cell Area `8622370.25`，最坏 precompile path 为 data SRAM macro 到
  `rd_row_capture_r`，但这不是 postcompile/final timing 结论。

## 历史关键路径证据

旧 full-top 9T20 run
`full_compile_1g_strict_template_9t20_5274f9d_20260506_2154_eda09` 的 postcompile
QoR 显示 setup 未收敛：

- Critical Path Slack `-2.25ns`。
- Design WNS/TNS 为 `2.25 / 1019853.06`，violating paths `715671`。
- 最坏路径从 `compat_rd_q_count_reg_3__2_` 到 compat read queue 相关寄存器。

该 run 早于当前部分 RTL cleanup，只能作为瓶颈方向证据，不能作为当前 RTL 的最终
结论。19:10-19:14 CST 已清理非 DCache `read_req_ready` 输出端的
`rd_q_count` / total outstanding 依赖；DCache same-cycle LLC-hit 路径仍保留原逻辑。
19:17-19:21 CST 已同步清理 `write_req_ready` 输出端的 `wr_q_count` /
total outstanding 依赖。该修复还需要 current-RTL `compat` DC probe 的 final
timing 来证明。

## 下一步 Gate

1. 当前已经在跑 full top；不要再等待小模块全部 pass 后才启动 top。`.latest_full_compile_1g` 对应的 `axi_llc_subsystem_dual` postcompile QoR/timing 是最终 1GHz setup signoff。
2. `compat` quick-map 和 `full_top` quick-map 只作为早期诊断：如果它们先给出 final timing endpoint，可以用来提前修 RTL；但它们不是最终 signoff blocker。
3. 若 `.latest_full_compile_1g` 的 postcompile QoR/timing setup pass，并且 final netlist 保留真实 data/meta SRAM macro 引用，则 DC gate 可以通过。
4. 若 `.latest_full_compile_1g` 仍有 setup violation，再按 postcompile final endpoint 决定是修 `compat`、`core/data_store` 还是其它 top-level 组合路径，并重跑对应 probe + full top。

## 2026-05-11 17:57 CST 复查

- Full top 没有停跑，也不是只等小模块：当前 `.latest_full_compile_1g`
  指向 `full_compile_1g_payload_shift_9t20_20260511_073614_eda-05`，
  `dc_shell` 仍存活，TOP 为 `axi_llc_subsystem_dual`，脚本为
  `rtl/dc/run_dual_full_compile_1g.tcl`。该 run 目前只有 precompile QoR：
  Critical Path Slack `+0.33ns`、TNS `0.00`、violating paths `0`、Cell Area
  `8622370.25`；postcompile QoR/timing 尚未生成，所以还不能 signoff。
- 同步存在 full-top quick-map 早期诊断 run：
  `.latest_full_quick_map_low_probe` 指向
  `full_quick_map_low_payload_shift_9t20_20260511_073614_eda-05`，TOP 同为
  `axi_llc_subsystem_dual`。该 run 正在 Mapping Optimizations，launcher log
  持续更新，当前中间表已到约 `9:38:03`，Area 约 `10067094.9`，Slack 列约
  `+0.86`，Cost 约 `330605.9`。这是有价值的 top 级 setup trend，但还不是
  final QoR/timing。
- `compat` quick-map 已先完成并 setup fail：WNS `-0.66ns`、TNS
  `-155090.55`、violating paths `355529`。该结果不是 full-top signoff，
  但说明如果 full-top final endpoint 也落在 compat 相关路径，需要优先修
  `axi_llc_subsystem_compat` 的 direct arbitration / bypass 输出组合路径。
- 后续检查策略调整为：继续保留 full compile 作为最终 signoff，同时把
  full-top quick-map final QoR/timing 作为优先观察项；一旦 full-top quick-map
  产出 final endpoint，就先按 top endpoint 判断是否需要提前修改 RTL，而不是
  被动只等 full compile postcompile。

## 2026-05-11 18:12 CST route-predecode 修正与重跑

- 根据旧 `compat` quick-map final timing，最坏路径为
  `direct_rr_ptr_r_reg_2_ -> bypass_req_mode2_ddr_aligned`，slack `-0.66ns`；
  max20 后续大量路径为 `rr_ptr_r_reg_0_ -> core_req_stage_addr/size/bypass`，
  slack 同为约 `-0.66ns`。根因是 FIFO head arbitration 之后仍在输出/dispatch
  端重复计算 `request_uses_direct_bypass()` / mapped-window 地址范围 add/cmp。
- 已修改 `rtl/src/axi_llc_subsystem_compat.v`：读写请求入队时预解码并保存
  `*_q_direct` 与 `*_q_mode2_ddr_aligned`；direct slot 保存
  `direct_slot_mode2_ddr_aligned_r`。后续 core/direct dispatch 使用这些已注册
  route flags，不再让 `rr_ptr/direct_rr_ptr` 组合穿过 mode/window 判定。该改动
  不增加 core request stage，不改变 LLC-hit 关键 cycle。
- 新 RTL 验证：
  `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_route_predecode_refresh_20260511_181545_eda-05/run.log`
  显示 `PERF LLC_HIT_READ64 CHECKED ready=0 resp=7 external=-1`、
  `PERF LLC_HIT_WRITE64 CHECKED ready=1 resp=9 external=-1` 和
  `PASS LLC_HIT_ONLY`；`rtl/local_debug/vcs_cpp_perf_contract_route_predecode_refresh_20260511_181558_eda-05/run.log`
  显示 bounded non-hit 通过，LLC miss read64 仍为 `ready=0 ar=8 r0=10 r1=11 resp=18`，
  `max_extra_observed=5`；全量 RTL contracts
  `rtl/local_debug/vcs_all_contracts_route_predecode_refresh_20260511_181606_eda-05`
  通过 `53/53`。
- 由于 RTL 已变化，07:36 CST 启动的 `payload_shift` full-top quick/full compile
  已标记 stale 并停止，不能作为当前 RTL signoff。基于 route-predecode 新 RTL
  已于 18:11 CST 重启三条 DC：
  `compat_quick_map_low_route_predecode_9t20_20260511_181142_eda-05`、
  `full_quick_map_low_route_predecode_9t20_20260511_181142_eda-05`、
  `full_compile_1g_route_predecode_9t20_20260511_181142_eda-05`。
- 18:12 CST 早期健康检查：三条 run 均完成 read data/meta DB 和 analyze，正在
  elaborate 或后续阶段；`DC_SOURCE_FRESHNESS` 和 `DC_RUN_LIVENESS` 为 PASS。
  此时 link report 尚未生成，因此 `DC_MACRO_BINDING` / `DC_LIBRARY_BINDING`
  正确状态是 `WAIT link_report_pending`，不是库绑定失败。
- 18:21 CST 复查：三条新 run 仍存活，`check_goal_gate.sh` 显示
  LLC-hit、bounded non-hit、53/53 contracts、Linux sanity、DC source freshness 和
  liveness 均为 PASS；`DC_SETUP` 仍为 `WAIT missing_signoff_postcompile_qor`。
  link report 仍未落盘，库/macro 绑定继续为 `WAIT link_report_pending`。
- 18:22 CST 复跑 `rtl/dc/selftest_goal_gate_signoff.sh`，输出
  `PASS goal gate signoff selftest`。这覆盖刚才把 link 前
  `DC_MACRO_BINDING` / `DC_LIBRARY_BINDING` 从误报 FAIL 改为 WAIT 后，最终
  setup/netlist/macro/library signoff gate 仍按预期工作。
- 18:25 CST 为避免 18:11 run 的 `source_status.txt` 在 no-op mtime 修复后被
  手工刷新造成 signoff 证据歧义，停止 18:11 三条 run，并重启 clean source
  status 版本。当前有效 marker：
  `compat_quick_map_low_route_predecode_clean_9t20_20260511_182517_eda-05`、
  `full_quick_map_low_route_predecode_clean_9t20_20260511_182517_eda-05`、
  `full_compile_1g_route_predecode_clean_9t20_20260511_182517_eda-05`。
  新 `source_status.txt` 记录了当前 `axi_llc_subsystem_compat.v`、
  `axi_llc_dc_common.tcl` 和入口 Tcl 的 SHA256，capture time 均晚于当前 RTL
  mtime。18:25 CST 早期健康检查显示三条 run 均存活，已完成 read data/meta DB
  与 analyze，正在 elaborate / link 前阶段；`DC_SOURCE_FRESHNESS` 和
  `DC_RUN_LIVENESS` 为 PASS，`DC_SETUP` 等待 final QoR/timing。
- 18:27 CST 补强 `rtl/dc/check_goal_gate.sh`：若 clean `source_status.txt`
  记录了 `RTL_COMPAT_SHA256`、`DC_COMMON_SHA256` 或 `SCRIPT_SHA256`，gate 会
  直接与当前文件 hash 比较，避免只依赖 mtime。复查输出
  `DC_SOURCE_FRESHNESS PASS`；`rtl/dc/selftest_goal_gate_signoff.sh` 仍输出
  `PASS goal gate signoff selftest`。
- 18:41 CST 复查 clean DC：三条 run 仍在 `elaborate_start` 之后，进程存活且
  CPU 正常；`compat` DC RSS 约 `6.5GB`，两个 full-top run RSS 约 `5.2GB`。
  当前尚无 link report、QoR 或 timing report，因此 `DC_MACRO_BINDING` /
  `DC_LIBRARY_BINDING` 仍为 `WAIT link_report_pending`，`DC_SETUP` 仍为
  `WAIT missing_signoff_postcompile_qor`。没有新 endpoint，不做 RTL 改动。
- 19:07 CST 复查 clean DC：三条 run 仍存活并接近满 CPU。`compat_quick_map_low`
  运行约 `41m48s`，RSS 约 `9.6GB`；`full_quick_map_low` 运行约 `41m46s`，
  RSS 约 `9.7GB`；`full_compile_1g` 运行约 `41m44s`，RSS 约 `9.7GB`。
  `.latest_full_quick_map_low_probe` 和 `.latest_full_compile_1g` 都是
  `TOP=axi_llc_subsystem_dual`，因此 full top 已经在跑。launcher log 显示
  full-top 正在 elaborate/build `llc_data_store`、`llc_meta_store` 和
  `llc_cache_ctrl`，并确认 `USE_SMIC12=1`、`READ_LATENCY_CYCLES=3`。当前仍无
  link report、final QoR/timing 或 postcompile netlist，因此还没有新的 setup endpoint；
  `DC_SETUP` 仍为 `WAIT missing_signoff_postcompile_qor`，`DC_MACRO_BINDING` /
  `DC_LIBRARY_BINDING` 仍为 `WAIT link_report_pending`。
- 19:43 CST 复查 clean DC：三条 run 均已完成 elaborate/link。`compat_quick_map_low`
  于 19:21:23 进入 `quick_map_low_start`，`full_quick_map_low` 于 19:22:05 进入
  `quick_map_low_start`，`.latest_full_compile_1g` 于 19:27:39 进入 `compile_start`。
  三条 run 的 `link.rpt` 已确认 data/meta SRAM DB 与 9T20 RVT/LVT 标准单元库，
  且没有 7p5t 标准单元库，因此 `DC_MACRO_BINDING` / `DC_LIBRARY_BINDING` 已从
  link 前 WAIT 转为 PASS。`.latest_full_compile_1g` 已生成 current route-predecode
  top precompile QoR/timing：Critical Path Slack `+0.33ns`、TNS `0.00`、violating
  paths `0`、Cell Area `8622370.25`；最紧路径为 data SRAM macro Q 到
  `compat/core/data_store/.../rd_row_capture_r_reg[*]`，slack `+0.33ns`。这说明
  current top 早期 setup 趋势为正，但仍不是最终 signoff；当前仍缺
  `*postcompile_1g_qor.rpt` / `*postcompile_1g_timing.rpt` 和 final netlist，因此
  `DC_SETUP` 仍为 `WAIT missing_signoff_postcompile_qor`。
- 2026-05-13 00:08 CST 复查 current payload-circular marker：`.latest_compat_low_probe`
  指向 `compat_quick_map_low_payload_circular_9t20_20260512_235452_eda-05`，
  `.latest_full_compile_1g` 指向
  `full_compile_1g_payload_circular_long72h_9t20_20260512_235452_eda-05`。两条
  run 均在 `eda-05` 存活并处于 `elaborate_start` 后阶段，尚无 link report、
  QoR/timing report 或 final netlist；log health 未发现 fatal/error/warning。
  `rtl/dc/check_goal_gate.sh` 显示 `LLC_HIT PASS`
  (`ready=0 resp=7` / `ready=1 resp=9` exact)、`BOUNDED_NON_HIT PASS`
  (`max_extra_observed=5`)、`RTL_CONTRACTS PASS` (`53/53`)、
  `LINUX_SANITY PASS`、`DC_SOURCE_FRESHNESS PASS` 和 `DC_RUN_LIVENESS PASS`。
  当前未完成项仍是 `DC_SETUP:WAIT:missing_signoff_postcompile_qor`，以及 link 前
  `DC_MACRO_BINDING` / `DC_LIBRARY_BINDING` 的 `WAIT link_report_pending`；不能用
  旧 `-0.10ns` full_top report 或任何 precompile/quick-map proxy 替代当前
  payload-circular full_top postcompile signoff。
- 00:26 CST 等待 00:25 低频自动检查后再次复查：`dc_1h_20260512_232526`
  已写入 `SCHEDULED_CHECK_DONE`。`check_goal_gate.sh` 状态未变化，current
  payload-circular compat/fulltop run 均 alive；launcher log mtime 分别更新到
  `00:25:20` / `00:25:53`，但 latest stage 仍为 `elaborate_start`，没有 link/QoR/timing。
  因此当前没有新的 timing endpoint 可以指导 RTL 修改，正确动作仍是等待当前
  source-fresh fulltop postcompile 或 compat quick final report。已用
  `rtl/dc/schedule_dc_check_once.sh 3600 dc_1h_20260513_002640` 重新安排下一次一小时
  低频检查，PID `1953955`。
- 00:28 CST 只读检查 launcher tail：compat/fulltop 两条 payload-circular run 均已展开
  `llc_data_store`、`llc_meta_store`，并进入 `llc_cache_ctrl` elaborate；当前参数仍为
  `READ_LATENCY_CYCLES=3`、`USE_SMIC12=1`、`READ_RESP_BITS=2048`。日志出现
  `llc_cache_ctrl.v:439` / `:462` 的 `ELAB-311 DEFAULT branch ... cannot be reached`
  warning，属于 case default 不可达提示；没有 fatal/error，也没有 setup endpoint。
  因此这次检查不触发 RTL 修改，继续等待 01:26 低频检查或更早的 QoR/timing 落盘。
- 01:27 CST 等待 `dc_1h_20260513_002640` 后复查：payload-circular compat 和 fulltop
  均已完成 elaborate/link，`LINK_SANITY_PASS` 和 `SRAM_HIERARCHY_PROTECTED 96`
  已出现。`DC_MACRO_BINDING` 转为 `PASS reason=db_linked_signoff_netlist_pending`，
  `DC_LIBRARY_BINDING` 转为 `PASS reason=all_active_runs_link_9t20_rvt_lvt_and_no_7p5t`。
  `.latest_full_compile_1g` 已进入 `compile_start` / `Beginning Pass 1 Mapping`，
  并生成 precompile QoR：WNS `+0.33ns`、TNS `0.00`、violating paths `0`、
  cell area `8622370.250000`；该结果只能作为 trend，不能替代 postcompile signoff。
  `compat_quick_map_low` 已进入 `Beginning Implementation Selection`，仍缺 quick
  QoR/timing。log health 没有 fatal/error；当前 warnings 为 `VER-318`、`ELAB-311`、
  `UISN-40` / `OPT-1303`，并有若干 constant-register removal 汇总。当前唯一 blocker
  是 `DC_SETUP:WAIT:missing_signoff_postcompile_qor`，正确动作仍是等待 compat quick
  final 或 fulltop postcompile endpoint。
- 01:58 CST 等待 `dc_30min_20260513_012749` 后复查：`compat_quick_map_low`
  已推进到 `Mapping Optimization (Phase 1)`，仍未生成 quick QoR/timing；
  `.latest_full_compile_1g` 仍在 `Beginning Pass 1 Mapping` 后，尚无 postcompile
  QoR/timing。fulltop precompile trend 仍为 WNS `+0.33ns`、TNS `0.00`、violating
  paths `0`、cell area `8622370.250000`，最紧路径仍是 data SRAM macro Q 到
  `rd_row_capture_r_reg[*]`，slack `+0.33ns`。macro/library binding 继续 PASS：
  data macro `sassls0c4l1p4096x256...`、meta macro `sassls0c4l1p4096x16...` 已 link，
  标准单元为 9T20 RVT/LVT 且无 7p5t。compat post-link structural summary 显示
  `SEQGEN count=153249` 及若干大宽度 mux/select，但这不是 final timing endpoint；
  当前仍不应据此修改 RTL。唯一 blocker 仍是
  `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。
- 02:30 CST 等待 `dc_30min_20260513_015923` 后复查：状态仍未到可修复节点。
  `compat_quick_map_low` 仍在 `Mapping Optimization (Phase 1)`，没有 quick QoR/timing；
  `.latest_full_compile_1g` 仍缺 postcompile QoR/timing 和 final netlist。fulltop
  precompile trend 保持 WNS `+0.33ns`、TNS `0.00`、violating paths `0`、
  cell area `8622370.250000`，但仍只能作为 trend。两条 run 均 alive，source
  freshness、LLC-hit exact、bounded non-hit、RTL contracts、Linux sanity、macro
  binding 和 9T20 library binding 均 PASS；唯一 blocker 仍是
  `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。
- 03:01 CST 等待 `dc_30min_20260513_023041` 后复查：`compat_quick_map_low`
  从 `Mapping Optimization (Phase 1)` 推进到 `Mapping Optimization (Phase 2)`，
  仍未生成 quick QoR/timing；`.latest_full_compile_1g` launcher log 有更新，仍在
  `Beginning Pass 1 Mapping` 后，未生成 postcompile QoR/timing。fulltop precompile
  trend 仍为 WNS `+0.33ns`、TNS `0.00`、violating paths `0`、cell area
  `8622370.250000`；macro/library binding 继续 PASS。当前仍没有可用于 RTL 修复的
  final endpoint，唯一 blocker 仍是 `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。
- 03:32 CST 等待 `dc_30min_20260513_030141` 后复查：`compat_quick_map_low`
  已推进到 `Mapping Optimization (Phase 3)`，仍没有 quick QoR/timing；
  `.latest_full_compile_1g` 已推进到 `Beginning Mapping Optimizations (Ultra High effort)`，
  但仍缺 postcompile QoR/timing。fulltop precompile trend 保持 WNS `+0.33ns`、TNS
  `0.00`、violating paths `0`、cell area `8622370.250000`。两条 run 均 alive，
  source freshness、LLC-hit exact、bounded non-hit、RTL contracts、Linux sanity、
  macro binding 和 9T20 library binding 均 PASS；唯一 blocker 仍是
  `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。没有 final endpoint，不触发 RTL 修改。
- 04:04 CST 等待 `dc_30min_20260513_033308` 后复查：`compat_quick_map_low`
  仍停在 `Mapping Optimization (Phase 3)`，未生成 quick QoR/timing；fulltop 已推进到
  `Mapping Optimization (Phase 2)`，仍缺 postcompile QoR/timing。两条 run 均 alive，
  compat RSS 约 `15.3GB`，fulltop RSS 约 `9.3GB`。fulltop precompile trend 仍为
  WNS `+0.33ns`、TNS `0.00`、violating paths `0`、cell area `8622370.250000`，
  但不能作为 signoff。当前没有 final endpoint，继续等待；后续检查频率从 30 分钟
  放宽到 1 小时，避免无效轮询。
- 05:06 CST 等待 `dc_1h_20260513_040431` 后复查：`compat_quick_map_low`
  仍未生成 quick QoR/timing，latest stage 仍为 `Mapping Optimization (Phase 3)`；
  进程 alive、CPU 约满载、RSS 约 `15.3GB`。fulltop 推进到
  `Mapping Optimization (Phase 4)`，仍没有 postcompile QoR/timing 和 final netlist；
  fulltop RSS 约 `9.3GB`，precompile trend 仍为 WNS `+0.33ns`、TNS `0.00`、
  violating paths `0`、cell area `8622370.250000`。LLC-hit exact、bounded non-hit、
  RTL contracts、Linux sanity、source freshness、macro binding、9T20 library binding
  均 PASS；唯一 blocker 仍是 `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。
  当前没有 final endpoint，不触发 RTL 修改。
- 06:08 CST 等待 `dc_1h_20260513_050630` 后复查：`compat_quick_map_low`
  已推进到 `Mapping Optimization (Phase 4)`，仍没有 quick QoR/timing；fulltop
  已推进到 `Mapping Optimization (Phase 5)`，仍没有 postcompile QoR/timing 和 final
  netlist。两条 run 均 alive，compat RSS 约 `15.3GB`，fulltop RSS 约 `9.3GB`。
  fulltop precompile trend 仍为 WNS `+0.33ns`、TNS `0.00`、violating paths `0`、
  cell area `8622370.250000`，但不能作为 signoff。LLC-hit exact、bounded non-hit、
  RTL contracts、Linux sanity、source freshness、macro binding、9T20 library binding
  均 PASS；唯一 blocker 仍是 `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。
- 07:10 CST 等待 `dc_1h_20260513_060822` 后复查：`compat_quick_map_low`
  已推进到 `Beginning Delay Optimization Phase`，仍没有 quick QoR/timing；fulltop
  已推进到 `Mapping Optimization (Phase 6)`，仍没有 postcompile QoR/timing 和 final
  netlist。两条 run 均 alive，compat RSS 约 `15.3GB`，fulltop RSS 约 `9.3GB`。
  fulltop precompile trend 仍为 WNS `+0.33ns`、TNS `0.00`、violating paths `0`、
  cell area `8622370.250000`。当前没有 final endpoint；继续等待，不修改 RTL。
- 08:12 CST 等待 `dc_1h_20260513_071029` 后复查：`compat_quick_map_low`
  仍在 `Beginning Delay Optimization Phase`，未生成 quick QoR/timing；fulltop
  latest stage 仍为 `Mapping Optimization (Phase 6)`，未生成 postcompile QoR/timing
  或 final netlist。两条 run 均 alive；compat RSS 约 `15.3GB`，fulltop RSS 约
  `9.5GB`。fulltop precompile trend 仍为 WNS `+0.33ns`、TNS `0.00`、violating
  paths `0`、cell area `8622370.250000`。当前仍没有 final endpoint，不触发 RTL 修改。
- 09:18 CST 手动复查：LLC-hit exact、bounded non-hit、RTL contracts、Linux sanity、
  source freshness、macro binding、9T20 library binding 均保持 PASS；唯一 blocker
  仍为 `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。`compat_quick_map_low`
  已进入 `Beginning Area-Recovery Phase (cleanup)`，log 中可见优化表继续更新，
  但仍未写出 quick QoR/timing；fulltop 仍在 `Mapping Optimization (Phase 7)`，
  只具备 precompile trend：WNS `+0.33ns`、TNS `0.00`、violating paths `0`、
  cell area `8622370.250000`，不能作为 signoff。已重新挂起 1 小时后检查：
  `dc_1h_20260513_091824`，PID `146371`，预计 10:18 CST 触发。
- 09:23 CST 补充观察：`compat_quick_map_low` cleanup 阶段的优化表已经出现过
  SLACK `0.00` / COST `0.0`，随后 area recovery 一度反弹到 SLACK `0.47` /
  COST `45506.8`，并继续优化到 SLACK `0.09` / COST `9560.9`。当前末尾 endpoint
  在 `rd_q_addr_reg[*]` 与 `core/valid_ram/.../valid_mem_reg[*]` 间切换；这只是
  compile log 的非 final 趋势，不能替代 quick QoR/timing，也暂不据此改 RTL。
- 10:21 CST 等待 `dc_1h_20260513_091824` 后复查：`compat_quick_map_low`
  已正常结束并写出 quick QoR/timing/netlist。setup PASS：Critical Path Slack
  `0.00`、TNS `0.00`、violating paths `0.00`，quick timing 中无 violated paths；
  最紧路径为 `rd_q_head_reg_0__3_ -> rr_ptr_r_reg_5_`，slack `0.00`。quick netlist
  保留 data macro refs `64`、meta macro refs `32`，9T20 RVT/LVT link PASS 且无
  7p5t。`.latest_full_compile_1g` 仍在运行，elapsed 约 `10:26:38`，仍缺
  postcompile QoR/timing 和 final netlist；fulltop 当前只有 precompile trend
  WNS `+0.33ns`、TNS `0.00`、violating paths `0`，不能作为 signoff。已重新挂起
  1 小时后检查：`dc_1h_20260513_102145`，PID `439012`。
- 11:23 CST 等待 `dc_1h_20260513_102145` 后复查：状态未到 final signoff。
  LLC-hit、bounded non-hit、RTL contracts、Linux sanity、source freshness、macro
  binding、9T20 library binding 均保持 PASS；`compat_quick_map_low` 继续作为
  quick trend PASS。`.latest_full_compile_1g` 仍在运行，elapsed 约 `11:28:47`，
  RSS 约 `9.9GB`，仍缺 postcompile QoR/timing 和 final netlist；当前只可引用
  precompile trend WNS `+0.33ns`、TNS `0.00`、violating paths `0`。唯一 blocker
  仍为 `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。已重新挂起 1 小时后检查：
  `dc_1h_20260513_112352`，PID `707540`。
- 12:26 CST 等待 `dc_1h_20260513_112352` 后复查：状态仍未到 final signoff。
  `.latest_full_compile_1g` 继续运行，elapsed 约 `12:31:16`，RSS 约 `10.0GB`，
  仍缺 postcompile QoR/timing 和 final netlist。precompile trend 仍为 WNS
  `+0.33ns`、TNS `0.00`、violating paths `0`，但不作为 signoff。`compat_quick`
  继续 PASS，所有 functional/perf/source/library/macro gate 继续 PASS；唯一 blocker
  仍为 `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。已重新挂起 1 小时后检查：
  `dc_1h_20260513_122626`，PID `979611`。
- 13:29 CST 等待 `dc_1h_20260513_122626` 后复查：状态仍未到 final signoff。
  `.latest_full_compile_1g` 继续运行，elapsed 约 `13:34:44`，RSS 约 `10.0GB`，
  postcompile QoR/timing 和 final netlist 仍未生成。log health 显示 launcher log
  mtime 停在 `2026-05-13 11:59:59 CST`，latest stage 为
  `Mapping Optimization (Phase 8)`；进程仍为 `R` 且 CPU 约 `82.9%`，因此暂按
  长优化阶段处理。无 fatal/error；唯一 blocker 仍为
  `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。已重新挂起 1 小时后检查：
  `dc_1h_20260513_133024`，PID `1254517`。
- 14:32 CST 等待 `dc_1h_20260513_133024` 后复查：状态仍未到 final signoff。
  `.latest_full_compile_1g` 继续运行，elapsed 约 `14:37:30`，RSS 约 `10.0GB`，
  CPU 约 `84.1%`；postcompile QoR/timing 和 final netlist 仍未生成。launcher log
  mtime 仍停在 `2026-05-13 11:59:59 CST`，latest stage 仍为
  `Mapping Optimization (Phase 8)`，无 fatal/error。由于进程仍持续 CPU active，
  暂不判定失败或中断；若后续多轮仍无 log/report 更新，再考虑补充更小粒度
  fast probe。已重新挂起 1 小时后检查：`dc_1h_20260513_143245`，PID `1508503`。
- 15:40 CST 等待 `dc_1h_20260513_143245` 后复查：状态仍未到 final signoff。
  `.latest_full_compile_1g` 继续运行，elapsed 约 `15:45:09`，RSS 约 `10.6GB`，
  CPU 约 `85.2%`；postcompile QoR/timing 和 final netlist 仍未生成。launcher log
  mtime 已更新到 `2026-05-13 15:13:45 CST`，latest stage 推进到
  `Mapping Optimization (Phase 9)`，说明上一轮 mtime 停滞不是静态卡死。当前
  fulltop 仍只能引用 precompile trend：WNS `+0.33ns`、TNS `0.00`、violating
  paths `0`、cell area `8622370.250000`。`compat_quick_map_low` 已保持 final
  quick setup PASS：WNS `0.00`、TNS `0.00`、violating paths `0.00`。所有
  functional/perf/source/library/macro gate 继续 PASS；唯一 blocker 仍为
  `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。当前没有 final endpoint，不触发
  RTL 修改。已重新挂起 1 小时后检查：`dc_1h_20260513_154109`，PID `1732314`。
- 16:42 CST 等待 `dc_1h_20260513_154109` 后复查：状态仍未到 final signoff。
  `.latest_full_compile_1g` 继续运行，elapsed 约 `16:47:16`，RSS 约 `10.6GB`，
  CPU 约 `86.1%`；postcompile QoR/timing 和 final netlist 仍未生成。launcher log
  mtime 仍为 `2026-05-13 15:13:45 CST`，latest stage 仍为
  `Mapping Optimization (Phase 9)`，无 fatal/error。precompile trend 仍为 WNS
  `+0.33ns`、TNS `0.00`、violating paths `0`。`compat_quick_map_low` 继续作为
  final quick setup PASS supporting evidence；所有 functional/perf/source/library/macro
  gate 继续 PASS；唯一 blocker 仍为 `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。
  由于 fulltop 进程仍 CPU active，当前不判定失败，也不据此改 RTL。已重新挂起
  1 小时后检查：`dc_1h_20260513_164506`，PID `1984016`。
- 17:45 CST 等待 `dc_1h_20260513_164506` 后复查：状态仍未到 final signoff。
  `.latest_full_compile_1g` 继续运行，elapsed 约 `17:50:31`，RSS 约 `10.6GB`，
  CPU 约 `86.9%`；postcompile QoR/timing 和 final netlist 仍未生成。launcher log
  mtime 已更新到 `2026-05-13 17:44:47 CST`，latest stage 从
  `Mapping Optimization (Phase 9)` 推进到 `Beginning Constant Register Removal`、
  `Beginning Global Optimizations`、`Beginning Isolate Ports`、`Beginning Delay
  Optimization`，说明 fulltop 仍在继续推进。precompile trend 仍为 WNS `+0.33ns`、
  TNS `0.00`、violating paths `0`。`compat_quick_map_low` 继续作为 final quick setup
  PASS supporting evidence；所有 functional/perf/source/library/macro gate 继续
  PASS；唯一 blocker 仍为 `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。已重新挂起
  1 小时后检查：`dc_1h_20260513_174806`，PID `2259230`。
- 18:48 CST 等待 `dc_1h_20260513_174806` 后复查：状态仍未到 final signoff。
  `.latest_full_compile_1g` 继续运行，elapsed 约 `18:53:22`，RSS 约 `10.6GB`，
  CPU 约 `87.6%`；postcompile QoR/timing 和 final netlist 仍未生成。launcher log
  mtime 已更新到 `2026-05-13 18:45:33 CST`，latest stage 从
  `Beginning Delay Optimization` 推进到 `Beginning WLM Backend Optimization`，说明
  fulltop 仍在继续推进。precompile trend 仍为 WNS `+0.33ns`、TNS `0.00`、
  violating paths `0`。所有 functional/perf/source/library/macro gate 继续 PASS；
  唯一 blocker 仍为 `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。已重新挂起
  1 小时后检查：`dc_1h_20260513_184958`，PID `2543028`。
- 20:02 CST 复查 `dc_1h_20260513_184958` 后发现 eda-05 fulltop 已退出：
  `exit_code=137`，无 postcompile QoR/timing 或 final netlist，`DC_RUN_LIVENESS`
  变为 FAIL。`launcher.direct.log` 显示 `timeout ... Killed`，不是 72h timeout
  到期。`launcher.log` 最后阶段在 `Beginning Leakage Power Optimization` 后，
  表格已出现 WNS `0.00`、setup cost `0.0`、design rule cost `0.0`，但由于没有
  final reports/netlist，不能作为 signoff。eda-05 dmesg 在 19:29-19:30 记录全局
  OOM，且当时有大量其它用户 simulator 进程每个约 8GB RSS；因此该次失败按资源/
  外部 kill 处理，不按 RTL setup 失败处理。
- 20:06 CST 已在 eda-10 重启 current source-fresh fulltop：
  `full_compile_1g_payload_circular_oom_retry72h_9t20_20260513_200542_eda-10`，
  `.latest_full_compile_1g` 已切到该 run。eda-10 探测结果为 DC 可用，内存
  available 约 `943GiB`，比 eda-05 当前 OOM 环境更安全。新 run metadata：
  launcher `2471764`、timeout `2471819`、DC PID `2471827`；20:07 CST DC 仍在
  analyze/elab 早期，RSS 约 `1.68GB`，`DC_SOURCE_FRESHNESS` 和 `DC_RUN_LIVENESS`
  已恢复 PASS，`DC_MACRO_BINDING` / `DC_LIBRARY_BINDING` 暂为 `link_report_pending`。
  已重新挂起 1 小时后检查：`dc_1h_20260513_200928`，PID `2947885`。
- 21:13 CST 等待 `dc_1h_20260513_200928` 后复查：eda-10 retry 已完成
  elaborate/link/precompile，并进入 `compile_ultra`。21:14 CST active process 为
  launcher `2471764`、timeout `2471819`、DC parent `2471827` 和 child `2735481`；
  child RSS 约 `10.4GB`、CPU 约 `99.6%`。20:30 CST `LINK_SANITY_PASS`，20:32 CST
  写出 post-link DDC，20:36 CST `compile_start`。precompile QoR/timing 仍为 WNS
  `+0.33ns`、TNS `0.00`、violating paths `0`、cell area `8622370.250000`；
  `DC_MACRO_BINDING` 和 `DC_LIBRARY_BINDING` 已恢复 PASS。当前仍无 postcompile
  QoR/timing 或 final netlist；唯一 blocker 仍为
  `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。已重新挂起 1 小时后检查：
  `dc_1h_20260513_211618`，PID `3281526`。
