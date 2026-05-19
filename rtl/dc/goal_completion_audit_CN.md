# Goal 完成审计

更新时间：2026-05-14 14:35 CST。

## 当前有效审计（payload-circular RTL）

当前 thread goal 的完成判定只能基于最新 `payload_circular` RTL 和当前
`.latest_full_compile_1g`。下面是当前有效证据；后面的旧版本记录仅保留为历史诊断。

| Objective 要求 | 当前有效 artifact | 当前判定 |
| --- | --- | --- |
| C++ / RTL 在 LLC hit read/write cycles/performance 必须精确对齐 | `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_payload_circular_20260512_234630_eda-05/run.log` 包含 `PERF LLC_HIT_READ64 CHECKED ready=0 resp=7 external=-1`、`PERF LLC_HIT_WRITE64 CHECKED ready=1 resp=9 external=-1` 和 `PASS LLC_HIT_ONLY` | PASS |
| LLC miss / 非 hit 允许协议和约束对齐，但性能差距必须有明确上界且不能显著退化 | `rtl/local_debug/vcs_cpp_perf_contract_payload_circular_20260512_234659_eda-05/run.log` 包含 `PASS bounded_non_hit max_extra_observed=5 direct_max_extra_allowed=6 llc_miss_max_extra_allowed=8` | PASS |
| 相关 RTL 功能 contract 必须保持通过 | `rtl/local_debug/vcs_all_contracts_payload_circular_20260512_234723_eda-05.wrapper.log` 包含 `SUMMARY total=53 passed=53 failed=0` | PASS |
| parent simulator large + CONFIG_BPU Linux sanity 不应出错且性能无显著退化 | `rtl/dc/check_goal_gate.sh` 21:13 CST 输出 `LINUX_SANITY status=PASS reason=large_bpu_300k_5m_success_perf_within_recorded_bounds`；该项复用 `../local_logs/goal_llc_hit_dc_20260511/` 下已记录的 300k/5M large+BPU smoke | PASS |
| DC 必须使用当前可综合 RTL 和当前 DC 脚本 | `rtl/dc/check_goal_gate.sh` 14:32 CST 输出 `DC_SOURCE_FRESHNESS status=PASS reason=all_active_dc_runs_match_current_synth_inputs_and_dc_scripts`；当前 signoff run 为 `full_compile_1g_payload_circular_oom_retry72h_9t20_20260513_200542_eda-10`，`source_status.txt` 记录当前 compat RTL、DC common Tcl、full compile Tcl SHA256 | PASS |
| DC 必须使用真实 SMIC12 SRAM macro DB 和 9T20 标准单元库 | eda-10 retry 的 `link.rpt` 确认 9T20 RVT/LVT 标准单元库、data `4096x256` SRAM DB、meta `4096x16` SRAM DB；14:32 CST gate 输出 `DC_MACRO_BINDING status=PASS reason=db_linked_and_signoff_netlist_keeps_macros`、`DC_LIBRARY_BINDING status=PASS reason=all_active_runs_link_9t20_rvt_lvt_and_no_7p5t` | PASS |
| compat quick-map setup 趋势 | `rtl/dc/runs/compat_quick_map_low_payload_circular_9t20_20260512_235452_eda-05/reports/axi_llc_subsystem_compat_quick_map_low_qor.rpt` 10:21 CST 已生成，Critical Path Slack `0.00`、TNS `0.00`、violating paths `0.00`；quick timing 无 violated paths；quick netlist 保留 data macro refs `64`、meta macro refs `32` | PASS，作为趋势/子模块证据，不替代 full_top signoff |
| 最终 DC setup signoff 必须来自 current RTL full top postcompile QoR/timing，不能用 precompile、quick-map 或旧 run 代替 | eda-10 retry 已生成 `axi_llc_subsystem_dual_postcompile_1g_qor.rpt` 和 `axi_llc_subsystem_dual_postcompile_1g_timing.rpt`；QoR 为 WNS `0.00`、TNS `0.00`、violating paths `0.00`、Cell Area `9446885.041434`；timing report 含 `slack (MET) 0.00` 且无 `slack (VIOLATED)`；14:32 CST gate 输出 `DC_SETUP status=PASS reason=signoff_full_compile_setup_pass` | PASS |
| final netlist 必须保留真实 data/meta SRAM macro 引用 | `outputs/netlist/axi_llc_subsystem_dual_postcompile_1g.v` 已生成；直接计数 data macro refs `64`、meta macro refs `32`，未见 generic/DW/stub memory refs | PASS |

当前结论：goal 已具备完成条件。LLC-hit 精确 cycles、bounded non-hit、RTL contracts、
Linux sanity、source freshness、SRAM DB link、9T20 library binding、compat quick-map
setup 趋势、current full_top postcompile setup signoff、final netlist SRAM macro refs
均已通过。14:32 CST `rtl/dc/check_goal_gate.sh` 输出 `GOAL status=PASS`、
`BLOCKERS none`。current full_top run `exit_code=0`，log 记录 `compile_done
2026-05-14 13:38:43`、`reports_done 13:44:24`、`write_done 13:46:39`。hold 仍有
violation（Worst Hold Violation `-0.13`、hold violating paths `16834`），但当前目标是
1GHz setup 收敛，hold 不是本轮 completion blocker。

07:05 CST 补充抽查：当前 signoff run 的 `reports/link.rpt` 绑定标准单元库
`scc12nsfe_90sdb_9tc20_rvt_ssg_v0p72_-40c_ccs.db` 和
`scc12nsfe_90sdb_9tc20_lvt_ssg_v0p72_-40c_ccs.db`，并绑定 data/meta SRAM 的
`4096x256` / `4096x16` `ssgs_ccw0p72v125c` DB；未见 7p5t。该项确认库配置可信，
但仍不替代 postcompile setup signoff 和 final netlist macro refs。

## Objective 拆解

当前 thread goal 的验收标准拆成以下可检查交付物：

1. C++ / RTL 在 LLC hit 场景下 cycles/performance 必须精确对齐。
2. LLC miss / 非 hit 场景允许按协议和约束对齐，但性能差距必须有明确上界且当前证据不应显著退化。
3. 相关 RTL 功能 contract 必须保持通过，不能为了性能/时序破坏功能语义。
4. parent simulator 的 large + CONFIG_BPU Linux smoke 必须无错误，且 IPC/cycle 没有显著退化。
5. DC 必须使用当前可综合 RTL、真实 SMIC12 SRAM macro DB，并且运行状态可追踪。
6. 最终 DC setup signoff 必须来自 current RTL 的 full top `.latest_full_compile_1g` postcompile QoR/timing，不能用 precompile、quick-map 或旧 run 代替。
7. 若 final DC setup 通过，最终 netlist 必须保留真实 data/meta SRAM macro 引用。

## Prompt-to-Artifact Checklist

| Objective 要求 | 证据 / artifact | 当前判定 |
| --- | --- | --- |
| LLC hit read/write cycles 必须精确对齐 | `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_direct_pop_predecode_clean_20260512_1050_eda-05/run.log` 包含 `PERF LLC_HIT_READ64 CHECKED ready=0 resp=7 external=-1`、`PERF LLC_HIT_WRITE64 CHECKED ready=1 resp=9 external=-1` 和 `PASS LLC_HIT_ONLY` | PASS |
| LLC hit 证据必须覆盖当前输入 | `rtl/dc/check_goal_gate.sh` 14:47 CST 输出 `LLC_HIT status=PASS reason=exact_read_ready0_resp7_write_ready1_resp9_no_external`；该证据对应当前 direct-pop RTL | PASS |
| LLC miss / 非 hit bounded performance | `rtl/local_debug/vcs_cpp_perf_contract_direct_pop_predecode_clean_20260512_1050_eda-05/run.log` 包含 `PERF LLC_MISS_READ64 CHECKED ready=0 ar=8 r0=10 r1=11 resp=18` 和 `PASS bounded_non_hit max_extra_observed=5 direct_max_extra_allowed=6 llc_miss_max_extra_allowed=8` | PASS |
| RTL contracts 功能回归 | `rtl/local_debug/vcs_all_contracts_direct_pop_predecode_clean_20260512_1050_eda-05` 全量 contract 通过；汇总为 `SUMMARY total=53 passed=53 failed=0` | PASS |
| parent simulator Linux sanity 和性能 | `../local_logs/goal_llc_hit_dc_20260511/linux_large_bpu_mode1_300k_after_cpp_resp_boundary_20260511_071015.log` 包含 `bpu=1(real-bpu)`、`Success!!!!`、`sim-time(cycle)= 121383`；`../local_logs/goal_llc_hit_dc_20260511/linux_large_bpu_mode1_5m_after_cpp_resp_boundary_20260511_071224.log` 包含 `bpu=1(real-bpu)`、`Success!!!!`、`sim-time(cycle)= 2086921`；14:47 CST gate 输出 `LINUX_SANITY PASS` | PASS |
| DC run 对应当前可综合 RTL 和 DC 脚本 | `.latest_full_compile_1g` 当前指向 72h timeout 的 `full_compile_1g_direct_pop_predecode_clean_long72h_9t20_20260512_125943_eda-05`；`source_status.txt` 记录当前 compat RTL、DC common Tcl 和 full compile Tcl 的 SHA256；`rtl/dc/check_goal_gate.sh` 默认以该 signoff marker 做 completion gate，14:47 CST 输出 `DC_SOURCE_FRESHNESS PASS reason=all_active_dc_runs_match_current_synth_inputs_and_dc_scripts`；compat quick/reference 由 summary/decision 脚本单独诊断 | PASS |
| DC run 没有早退或假等待 | `rtl/dc/check_goal_gate.sh` 默认检查 signoff marker `.latest_full_compile_1g`，14:47 CST 输出 `DC_RUN_LIVENESS PASS reason=active_runs_alive_or_have_final_qor_and_timing`；compat quick 和旧 12h full_top reference 均跑在 `eda-05`，但只作为辅助趋势，不阻塞最终 signoff gate | PASS |
| DC 使用真实 SRAM macro DB | 72h signoff full_top `reports/link.rpt` 已确认 data SRAM `sassls0c4l1p4096x256.../ssgs_ccw0p72v125c/*.db` 和 meta SRAM `sassls0c4l1p4096x16.../ssgs_ccw0p72v125c/*.db`；`DC_MACRO_BINDING PASS reason=db_linked_signoff_netlist_pending` | PASS for DB link；final netlist macro refs 仍 WAIT |
| DC 使用 SMIC12 9T20 标准单元库 | 72h signoff full_top `reports/link.rpt` 已确认 `scc12nsfe_90sdb_9tc20_rvt_ssg_v0p72_-40c_ccs.db` 和 `scc12nsfe_90sdb_9tc20_lvt_ssg_v0p72_-40c_ccs.db`，未见 7p5t；`DC_LIBRARY_BINDING PASS reason=all_active_runs_link_9t20_rvt_lvt_and_no_7p5t` | PASS |
| final signoff gate 自测 | `rtl/dc/selftest_goal_gate_signoff.sh` 使用 `AXI_LLC_DC_ACTIVE_MARKERS` 和 `AXI_LLC_DC_SIGNOFF_MARKER` 指向临时 fake run，覆盖 `check_goal_gate.sh`、`summarize_dc_reports.sh`、`monitor_dc_status.sh` 三套入口：正 slack + 正确 QoR/timing/netlist PASS；fake `SCRIPT=` 变新触发 `DC_SOURCE_FRESHNESS WAIT`；9T20 RVT/LVT 标准单元库 PASS；意外 7p5t 标准单元库 FAIL；正 slack + 缺 timing WAIT；已退出且缺 timing FAIL liveness；正 slack + 缺 netlist WAIT；正 slack + 缺 macro refs FAIL；负 slack FAIL；正 QoR 但 timing `slack (VIOLATED)` FAIL；正 QoR 但 timing 无 slack 行 FAIL。14:47 CST 修复 marker/symlink 和 selftest 轻量 monitor 后，`timeout 300s bash rtl/dc/selftest_goal_gate_signoff.sh` 输出 `PASS goal gate signoff selftest` | PASS |
| DC 输出命名与 gate 匹配 | `rtl/dc/run_dual_full_compile_1g.tcl` 使用 `${top_name}_postcompile_1g` stem 写 final reports 和 mapped outputs；`rtl/dc/axi_llc_dc_common.tcl` 会生成 `*_postcompile_1g_qor.rpt`、`*_postcompile_1g_timing.rpt`、`outputs/netlist/*_postcompile_1g.v`；`rtl/dc/check_goal_gate.sh` 查找的 pattern 与这些输出一致 | PASS |
| full top 1GHz setup signoff | 13:00 CST 因 12h timeout 风险，`.latest_full_compile_1g` 已切到 72h timeout 的 `full_compile_1g_direct_pop_predecode_clean_long72h_9t20_20260512_125943_eda-05`；13:59 CST 该 run 已完成 link、写出 post-link DDC、生成 precompile QoR/timing，precompile WNS `+0.33ns`、TNS `0.00`、violating paths `0`，并进入 `compile_ultra -retime` | WAIT，不能完成；72h run 仍缺 postcompile QoR/timing |
| 不能用 proxy 信号替代最终 setup | `rtl/dc/check_goal_gate.sh` 14:47 CST 明确输出 `DC_SETUP status=WAIT reason=missing_signoff_postcompile_qor`；precompile `+0.33ns` 只作为趋势，gate 还会检查 final timing report 有 slack 行且无 `slack (VIOLATED)` | 未完成，当前还没有 postcompile setup endpoint |
| 下一步自动判定脚本 | `rtl/dc/decide_dc_next_action.sh` 14:10 CST 输出 compat quick `WAIT missing_quick_map_qor_or_timing`、72h fulltop `WAIT missing_signoff_qor_or_timing`、旧 12h reference precompile PASS，整体 `overall=WAIT action=wait_for_current_fulltop_postcompile_or_compat_quick_final_report`；13:47 CST 已修正 final timing 分类逻辑，把 compat dispatch / write payload / response pool / bridge-hazard / refill-response 分开；13:50 CST `summarize_dc_reports.sh` 已同步同一套分类；14:10 CST 新增 `dc_timing_next_fix_playbook_CN.md` 作为 report 出来后的修复执行清单 | PASS，脚本/文档只读且作为后续 report 出来后的动作判定入口 |
| 低频自动检查可靠性 | `rtl/dc/schedule_dc_check_once.sh` 使用 `setsid` 安排一次性延迟检查；2 秒 smoke 和 30 分钟检查均已写入 `SCHEDULED_CHECK_DONE` 并刷新 `rtl/dc/dc_status_latest.txt`；当前一小时检查 `dc_1h_20260512_140736` PID `636457` 存活 | PASS，辅助追踪项，不替代 final DC evidence |
| DC log health 只读诊断 | `rtl/dc/summarize_dc_log_health.sh` 当前显示三条 active run 均 `ERROR_FATAL_SUMMARY count=0`；72h fulltop warning 主要是 `VER-318` / `ELAB-311`，暂无 constant-register removal；该脚本已接入 `monitor_dc_status.sh` 的 `LOG_HEALTH` 段 | PASS，辅助诊断项，不替代 final DC evidence |
| final netlist 保留真实 macro | 当前 full compile 仍未生成 `outputs/netlist/*postcompile_1g.v`，所以还不能检查 netlist 中 data/meta SRAM macro 引用数量 | WAIT |

## 当前结论

当前 goal 不能标记 complete。10:50 CST 最新 RTL 在 core-dispatch predecode 后又把
direct/core write-pop payload shift 改成 per-master 展开，已重新通过 LLC-hit exact
cycles、bounded non-hit 和 53/53 RTL contracts；`rtl/dc/check_goal_gate.sh` 10:58 CST
对 `LLC_HIT`、`BOUNDED_NON_HIT`、`RTL_CONTRACTS`、`DC_SOURCE_FRESHNESS` 和
`DC_RUN_LIVENESS` 均为 PASS。13:00 CST 发现上一轮完成 full_top 用时约 13h20m，
而 10:56 CST 启动的 current full_top 是 12h timeout，存在被提前杀掉的风险；已补开
72h timeout 的同源 `.latest_full_compile_1g`
`full_compile_1g_direct_pop_predecode_clean_long72h_9t20_20260512_125943_eda-05`，
并保留旧 12h full_top 继续跑作参考。旧 12h run 已完成 link，macro/library binding
PASS，precompile QoR 为 WNS `+0.33ns`、TNS `0.00`、violating paths `0`；13:55 CST
72h signoff run 已完成 elaborate/link，`link.rpt` 确认 9T20 RVT/LVT 标准单元和
data/meta SRAM `.db`，因此当前 signoff marker 的 macro/library gate 已 PASS。当前仍未生成
postcompile QoR/timing 或 final netlist。13:16 CST 新增并验证只读判定脚本
`rtl/dc/decide_dc_next_action.sh`，当前整体判定仍为 WAIT，
因此当前剩余阻塞项是：
用最新 RTL 得到新的 DC source-fresh signoff，并把 full_top postcompile setup 收敛到
WNS>=0、TNS=0、violating paths=0，同时保留 final netlist 中的真实 SRAM macro 引用。
14:47 CST 复查时，compat quick 已推进到 `Mapping Optimization (Phase 4)`，72h
fulltop 仍在 `Beginning Pass 1 Mapping`，二者仍无 final QoR/timing；completion
gate 的硬门槛仍只看 `.latest_full_compile_1g` 的 source-fresh postcompile signoff，
compat quick/reference 只作为辅助趋势。14:47 CST 还修复了工具层 marker 解析：
`check_goal_gate.sh` 现在同时接受文本 marker、目录路径和 symlink-to-directory，
`summarize_dc_reports.sh` 会把 symlink marker 解析成真实 run 目录；同时
`monitor_dc_status.sh` 增加 `DC_MONITOR_LIGHTWEIGHT=1` 供 signoff selftest 使用，避免
selftest 扫真实长跑 reference。post-link 大 mux/select 和
`rd_resp_q_pool_idx` 高位常量删除已记录在
`current_setup_status_CN.md` / `dc_warning_hygiene_candidates_CN.md`，仅作为后续
失败后的定位线索，不作为当前完成证据。

以下旧时间段记录保留为历史诊断，不能替代当前 72h signoff marker。

18:25 CST 更新：旧 `payload_shift` DC run 已因 route-predecode RTL 修改而标记 stale
并停止；18:11 route-predecode run 又因 `source_status.txt` 曾被手工刷新而降级为
stale。上表中 16:53 以前和 18:11 的 DC run 证据只保留为历史诊断，不再作为
current RTL signoff。当前有效证据如下：

| Objective 要求 | 当前 route-predecode 证据 / artifact | 当前判定 |
| --- | --- | --- |
| LLC hit read/write cycles 必须精确对齐 | `rtl/local_debug/vcs_cpp_llc_hit_perf_contract_route_predecode_refresh_20260511_181545_eda-05/run.log` 包含 `PERF LLC_HIT_READ64 CHECKED ready=0 resp=7 external=-1`、`PERF LLC_HIT_WRITE64 CHECKED ready=1 resp=9 external=-1` 和 `PASS LLC_HIT_ONLY` | PASS |
| LLC miss / 非 hit bounded performance | `rtl/local_debug/vcs_cpp_perf_contract_route_predecode_refresh_20260511_181558_eda-05/run.log` 包含 `PERF LLC_MISS_READ64 CHECKED ready=0 ar=8 r0=10 r1=11 resp=18` 和 `PASS bounded_non_hit max_extra_observed=5 direct_max_extra_allowed=6 llc_miss_max_extra_allowed=8` | PASS |
| RTL contracts 功能回归 | `rtl/local_debug/vcs_all_contracts_route_predecode_refresh_20260511_181606_eda-05` 全量 53 个 contract 通过；终端输出 `SUMMARY total=53 passed=53 failed=0` | PASS |
| final signoff gate 自测 | 18:22 CST 复跑 `rtl/dc/selftest_goal_gate_signoff.sh`，输出 `PASS goal gate signoff selftest`；覆盖 link 前 WAIT、最终 setup、timing、netlist macro refs 和 9T20/7p5t 库判定 | PASS |
| DC run 对应当前可综合 RTL 和 DC 脚本 | 18:25 CST 为避免 18:11 run 的 `source_status.txt` 手工刷新疑点，已停止 18:11 三条 run 并重启 clean source status 版本；`.latest_compat_low_probe`、`.latest_full_quick_map_low_probe`、`.latest_full_compile_1g` 当前分别指向 `compat_quick_map_low_route_predecode_clean_9t20_20260511_182517_eda-05`、`full_quick_map_low_route_predecode_clean_9t20_20260511_182517_eda-05`、`full_compile_1g_route_predecode_clean_9t20_20260511_182517_eda-05`；18:25 CST gate 输出 `DC_SOURCE_FRESHNESS PASS` 和 `DC_RUN_LIVENESS PASS` | PASS |
| DC source hash 绑定 | clean `source_status.txt` 记录 `RTL_COMPAT_SHA256`、`DC_COMMON_SHA256` 和入口 `SCRIPT_SHA256`；18:27 CST `rtl/dc/check_goal_gate.sh` 已补强为存在这些字段时直接核对当前文件 hash，复查 `DC_SOURCE_FRESHNESS PASS`；同轮 `selftest_goal_gate_signoff.sh` 仍 PASS | PASS |
| DC 使用真实 SRAM macro DB / 9T20 stdcell | 19:43 CST clean run 已生成 link report；gate 当前为 `DC_MACRO_BINDING PASS` / `DC_LIBRARY_BINDING PASS`，final netlist macro refs 仍等待 signoff netlist | PASS，final netlist 检查等待 mapped output |
| full top 1GHz setup signoff | clean `.latest_full_compile_1g` 指向 `rtl/dc/runs/full_compile_1g_route_predecode_clean_9t20_20260511_182517_eda-05`，已有 precompile QoR/timing：WNS `+0.33ns`、TNS `0.00`、violating paths `0`；目前尚无 postcompile QoR/timing | WAIT，不能完成 |
| final netlist 保留真实 macro | 新 full compile 尚未生成 `outputs/netlist/*postcompile_1g.v` | WAIT |

当前唯一有效完成路径：

1. 等 `.latest_full_compile_1g` 生成 `*postcompile_1g_qor.rpt` 和 `*postcompile_1g_timing.rpt`。
2. 若 setup pass：检查 WNS 非负、TNS=0、violating paths=0，timing report 有 slack 行且无 `slack (VIOLATED)`，并检查 final netlist 中真实 data/meta SRAM macro 引用。
3. 若 setup fail：按 postcompile final endpoint 修改 RTL，重跑相关 RTL contracts/performance gate，再启动新的 current RTL DC。

2026-05-11 20:50 CST 复查：新的 `.latest_full_compile_1g`
`full_compile_1g_route_predecode_sram_protect_9t20_20260511_203051_eda-09`
仍在运行且无 `exit_code.txt`；当前只有 `outputs/axi_llc_subsystem_dual.svf`，尚无
`reports/link.rpt`、precompile QoR/timing、postcompile QoR/timing 或 final netlist。
因此本审计仍不能 complete；当前阻塞项仍是新 full_top 的 link/macro/library 确认、
postcompile setup signoff 和 final netlist macro refs。

2026-05-11 21:23 CST 复查：新的 `.latest_full_compile_1g` 已完成 link 和 precompile
report。已收敛/确认项更新为：`DC_MACRO_BINDING PASS`、`DC_LIBRARY_BINDING PASS`，
precompile top setup WNS `+0.33ns`、TNS `0.00`、violating paths `0`。仍未完成项为：
`*postcompile_1g_qor.rpt` / `*postcompile_1g_timing.rpt` 尚未生成，final mapped netlist
尚未生成，因此 final setup signoff 和 final netlist macro refs 仍是 WAIT。

2026-05-11 22:02 CST 复查：full_top 仍在 mapping，未退出且无 fatal/OOM。`DC_SETUP`
仍等待 postcompile QoR/timing；`DC_MACRO_BINDING` 和 `DC_LIBRARY_BINDING` 继续 PASS。
本审计仍不能 complete。

2026-05-11 22:38 CST 复查：full_top 仍在 Pass 1 mapping 长优化阶段，未退出、无
postcompile report；所有非 setup gate 继续 PASS，唯一 blocker 仍是
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。本审计仍不能 complete。

2026-05-11 23:12 CST 复查：full_top 仍在 Pass 1 mapping 长优化阶段，未退出、无
postcompile report；所有非 setup gate 继续 PASS，唯一 blocker 仍是
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。本审计仍不能 complete。

2026-05-11 23:47 CST 复查：full_top 仍在 Pass 1 mapping 长优化阶段，未退出、无
postcompile report；所有非 setup gate 继续 PASS，唯一 blocker 仍是
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。本审计仍不能 complete。后续人工
复查间隔降为约 1 小时，后台 monitor 继续按 30 分钟刷新。

2026-05-12 00:50 CST 复查：full_top 已推进到 `Mapping Optimization (Phase 1)`，
未退出、无 postcompile report；所有非 setup gate 继续 PASS，唯一 blocker 仍是
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。本审计仍不能 complete。

2026-05-12 01:52 CST 复查：full_top 已推进到 `Mapping Optimization (Phase 2)`，
未退出、无 postcompile report；所有非 setup gate 继续 PASS，唯一 blocker 仍是
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。本审计仍不能 complete。

2026-05-12 02:54 CST 复查：full_top 已推进到 `Mapping Optimization (Phase 3/4)`，
未退出、无 postcompile report；所有非 setup gate 继续 PASS，唯一 blocker 仍是
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。本审计仍不能 complete。

2026-05-12 03:58 CST 复查：full_top 已推进到 `Mapping Optimization (Phase 5/6/7)`，
未退出、无 postcompile report；所有非 setup gate 继续 PASS，唯一 blocker 仍是
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。本审计仍不能 complete。

2026-05-12 06:03 CST 复查：full_top 已从 mapping phase 推进到
`Beginning Delay Optimization`，未退出、无 postcompile report；所有非 setup gate
继续 PASS，唯一 blocker 仍是 `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。本审计
仍不能 complete。

2026-05-12 06:39 CST 复查：full_top 继续在 `eda-09` 运行，launcher `2660421`
已运行约 `10h08m`，DC parent `2661056` 存活且 CPU 约 `71.7%`。log 已推进到
`Beginning WLM Backend Optimization`，但仍未生成 `*postcompile_1g_qor.rpt` /
`*postcompile_1g_timing.rpt` 或 final netlist。当前能报告的 top setup 仍是
precompile 趋势 WNS `+0.33ns`、TNS `0.00`、violating paths `0`；它说明早期 top
setup 不是负 slack，但不能替代最终 postcompile signoff。本审计仍不能 complete。

2026-05-12 07:48 CST 复查：full_top 继续在 `eda-09` 运行，已从
`Beginning WLM Backend Optimization` 推进到 `Beginning Design Rule Fixing
(max_transition) (max_capacitance)` 和 `Global Optimization (Phase 35/36/37)`。
这证明当前 run 仍在推进，没有早退或静止卡死；但仍未生成
`*postcompile_1g_qor.rpt` / `*postcompile_1g_timing.rpt` 或 final netlist。本审计
仍不能 complete。

2026-05-12 08:49 CST 复查：full_top 继续在 `eda-09` 运行，已从 design-rule fixing
推进到 `Beginning Leakage Power Optimization (max_leakage_power 0)` 和
`Global Optimization (Phase 38)` 至 `Global Optimization (Phase 53)`。当前 run
仍在推进，且 `DC_SOURCE_FRESHNESS`、`DC_RUN_LIVENESS`、`DC_MACRO_BINDING`、
`DC_LIBRARY_BINDING` 继续 PASS；但仍未生成 postcompile QoR/timing 或 final netlist。
本审计仍不能 complete。

2026-05-12 09:52 CST 复查：full_top `.latest_full_compile_1g`
`full_compile_1g_route_predecode_sram_protect_9t20_20260511_203051_eda-09`
正常退出，`exit_code=0`，并写出 postcompile QoR/timing、DDC、Verilog netlist、
SDC、SDF、SPF。该 run 使用真实 SRAM DB 和 9T20 RVT/LVT 标准单元库，macro/library
绑定仍为 PASS；但 setup signoff FAIL：postcompile WNS `-0.10ns`、TNS `-8173.00`、
violating paths `246460`，timing report 含 `slack (VIOLATED)`。最坏路径为
`compat_rr_ptr_r_reg_1_ -> compat_core_req_stage_addr_r_reg_8_`，后续 max80
路径集中在 compat `rr_ptr` / `direct_rr_ptr` 到 `core_req_stage_*` 和 write payload
queue registers。本审计仍不能 complete。

2026-05-12 10:30 CST 复查：已基于上述 final timing 继续修改
`rtl/src/axi_llc_subsystem_compat.v`，预计算每个 read/write master head entry 的
core-path dispatch payload 与 hazard eligibility，并将 `dispatch_fifo_slot_w` 从
`integer` 清理为 8-bit reg。最新 RTL 已重新通过：
`rtl/local_debug/vcs_cpp_llc_hit_perf_contract_core_dispatch_predecode_clean_20260512_101430_eda-05/run.log`、
`rtl/local_debug/vcs_cpp_perf_contract_core_dispatch_predecode_clean_20260512_101433_eda-05/run.log`、
`rtl/local_debug/vcs_all_contracts_core_dispatch_predecode_clean_20260512_101447_eda-05`
（53/53）。`rtl/dc/check_goal_gate.sh` 当前显示功能/性能 gate PASS，但
`DC_SOURCE_FRESHNESS WAIT`，因为 full_top DC 尚未覆盖这次最新 RTL。10:17 CST 启动
`compat_quick_map_low_core_dispatch_predecode_clean_9t20_20260512_101738_eda-05`
作为快速趋势实验，当前仍在 elaborate，尚无 quick QoR/timing。本审计仍不能 complete。

2026-05-13 15:40 CST 复查：当前 source-fresh `.latest_full_compile_1g`
为 `full_compile_1g_payload_circular_long72h_9t20_20260512_235452_eda-05`，
`TOP=axi_llc_subsystem_dual`，仍在运行，elapsed 约 `15:45:09`。该 run 使用真实
data/meta SRAM DB 和 9T20 RVT/LVT 标准单元库，`DC_SOURCE_FRESHNESS`、
`DC_RUN_LIVENESS`、`DC_MACRO_BINDING`、`DC_LIBRARY_BINDING` 均 PASS；但仍未生成
`*postcompile_1g_qor.rpt` / `*postcompile_1g_timing.rpt` 或 final netlist。
当前 fulltop 只有 precompile trend：WNS `+0.33ns`、TNS `0.00`、violating paths
`0`，不能替代 final setup signoff。`compat_quick_map_low` 已完成并 setup PASS：
WNS `0.00`、TNS `0.00`、violating paths `0.00`，但它只是 supporting evidence，
不能替代 full_top。LLC-hit exact、bounded non-hit、RTL contracts、Linux sanity
均继续 PASS；唯一 blocker 仍为 `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。
本审计仍不能 complete。

2026-05-13 16:42 CST 复查：当前 source-fresh `.latest_full_compile_1g`
仍为 `full_compile_1g_payload_circular_long72h_9t20_20260512_235452_eda-05`，
`TOP=axi_llc_subsystem_dual`，继续运行，elapsed 约 `16:47:16`。postcompile
QoR/timing 和 final netlist 仍未生成；launcher log mtime 仍为
`2026-05-13 15:13:45 CST`，latest stage 仍为 `Mapping Optimization (Phase 9)`，
但 DC PID 仍为 running 且 CPU 约 `86.1%`，因此当前只判定为继续等待，不判定失败。
LLC-hit exact、bounded non-hit、RTL contracts、Linux sanity、source freshness、
macro/library binding 均继续 PASS；唯一 blocker 仍为
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。本审计仍不能 complete。

2026-05-13 17:45 CST 复查：当前 source-fresh `.latest_full_compile_1g`
仍为 `full_compile_1g_payload_circular_long72h_9t20_20260512_235452_eda-05`，
`TOP=axi_llc_subsystem_dual`，继续运行，elapsed 约 `17:50:31`。postcompile
QoR/timing 和 final netlist 仍未生成；launcher log mtime 已更新到
`2026-05-13 17:44:47 CST`，latest stage 已推进到 `Beginning Delay Optimization`，
说明 run 仍在继续推进。LLC-hit exact、bounded non-hit、RTL contracts、Linux sanity、
source freshness、macro/library binding 均继续 PASS；唯一 blocker 仍为
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。本审计仍不能 complete。

2026-05-13 18:48 CST 复查：当前 source-fresh `.latest_full_compile_1g`
仍为 `full_compile_1g_payload_circular_long72h_9t20_20260512_235452_eda-05`，
`TOP=axi_llc_subsystem_dual`，继续运行，elapsed 约 `18:53:22`。postcompile
QoR/timing 和 final netlist 仍未生成；launcher log mtime 已更新到
`2026-05-13 18:45:33 CST`，latest stage 已推进到
`Beginning WLM Backend Optimization`，说明 run 仍在继续推进。LLC-hit exact、
bounded non-hit、RTL contracts、Linux sanity、source freshness、macro/library binding
均继续 PASS；唯一 blocker 仍为 `DC_SETUP:WAIT:missing_signoff_postcompile_qor`。
本审计仍不能 complete。

2026-05-13 20:02 CST 复查：上一条 source-fresh eda-05 fulltop
`full_compile_1g_payload_circular_long72h_9t20_20260512_235452_eda-05` 已退出，
`exit_code=137`，无 postcompile QoR/timing 或 final netlist。`launcher.direct.log`
显示 `timeout ... Killed`，不是 72h timeout 到期。该 run 被 kill 前在 compile log
中已经出现 WNS `0.00`、setup cost `0.0`、design rule cost `0.0`，随后进入
leakage optimization；但没有 final report/netlist，所以不能作为 signoff。eda-05
dmesg 在 19:29-19:30 记录全局 OOM，且有大量其它用户 simulator 进程占用内存；
该次失败按资源/外部 kill 处理，不按 RTL setup fail 处理。本审计仍不能 complete。

2026-05-13 20:06 CST 处理：已探测 eda-04/08/10，eda-10 的 Synopsys DC 可用且
available memory 约 `943GiB`，因此已在 eda-10 启动新的 source-fresh fulltop retry：
`full_compile_1g_payload_circular_oom_retry72h_9t20_20260513_200542_eda-10`，
并将 `.latest_full_compile_1g` 切到该 run。20:06 CST gate 显示 LLC-hit exact、
bounded non-hit、RTL contracts、Linux sanity、DC source freshness 和 liveness 均 PASS；
由于新 run 仍在 analyze/elab 早期，macro/library binding 暂为 link-pending，setup
仍等待 postcompile QoR/timing。本审计仍不能 complete。

2026-05-13 21:13 CST 复查：eda-10 retry 已完成 elaborate/link/precompile 并进入
`compile_ultra`。20:30 CST `LINK_SANITY_PASS`，20:32 CST 写出 post-link DDC，
20:36 CST `compile_start`；precompile QoR/timing 为 WNS `+0.33ns`、TNS `0.00`、
violating paths `0`、cell area `8622370.250000`。`DC_MACRO_BINDING` 和
`DC_LIBRARY_BINDING` 已恢复 PASS，source freshness/liveness 继续 PASS；当前仍无
postcompile QoR/timing 或 final netlist，唯一 blocker 仍为
`DC_SETUP:WAIT:missing_signoff_postcompile_qor`。本审计仍不能 complete。
