#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/../.." && pwd)
cd "$repo_root"

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/axi_llc_goal_gate_signoff.XXXXXX")
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

run_dir="$tmp_dir/full_compile_1g_signoff_selftest"
marker="$tmp_dir/latest_full_compile_1g"
fake_script="$tmp_dir/selftest_dc.tcl"
mkdir -p "$run_dir/reports" "$run_dir/outputs/netlist"
printf '%s\n' "$run_dir" > "$marker"
touch -d '2030-01-01 00:00:00' "$fake_script" "$run_dir/source_status.txt"
cat > "$run_dir/run_metadata.txt" <<EOF_META
SCRIPT=$fake_script
LAUNCHER_PID=$$
TIMEOUT_PID=$$
DC_PID=$$
EOF_META

cat > "$run_dir/reports/link.rpt" <<'EOF_LINK'
scc12nsfe_90sdb_9tc20_rvt_ssg_v0p72_-40c_ccs (library) /tmp/SCC12NSFE_90SDB_9TC20_RVT_V1P0F/scc12nsfe_90sdb_9tc20_rvt_ssg_v0p72_-40c_ccs.db
scc12nsfe_90sdb_9tc20_lvt_ssg_v0p72_-40c_ccs (library) /tmp/SCC12NSFE_90SDB_9TC20_LVT_V1P0F/scc12nsfe_90sdb_9tc20_lvt_ssg_v0p72_-40c_ccs.db
sassls0c4l1p4096x256m4b4w1c1p0d0t0s2sdz1rw00.db
sassls0c4l1p4096x16m16b1w1c1p0d0t0s2sdz1rw00.db
EOF_LINK

write_qor() {
  local slack="$1"
  cat > "$run_dir/reports/selftest_postcompile_1g_qor.rpt" <<EOF_QOR
Report : qor
Design : axi_llc_subsystem_dual

  Timing Path Group 'clk_1g'
  -----------------------------------
  Critical Path Slack:           ${slack}
  Total Negative Slack:          0.00
  No. of Violating Paths:        0.00
  Cell Area:           8622370.250000
  -----------------------------------
EOF_QOR
}

write_timing() {
  cat > "$run_dir/reports/selftest_postcompile_1g_timing.rpt" <<'EOF_TIMING'
Report : timing
Design : axi_llc_subsystem_dual

  Startpoint: selftest_start_reg
  Endpoint: selftest_end_reg
  Path Group: clk_1g
  slack (MET)                                                        0.01
EOF_TIMING
}

write_violated_timing() {
  cat > "$run_dir/reports/selftest_postcompile_1g_timing.rpt" <<'EOF_TIMING'
Report : timing
Design : axi_llc_subsystem_dual

  Startpoint: selftest_start_reg
  Endpoint: selftest_end_reg
  Path Group: clk_1g
  slack (VIOLATED)                                                   -0.01
EOF_TIMING
}

write_no_slack_timing() {
  cat > "$run_dir/reports/selftest_postcompile_1g_timing.rpt" <<'EOF_TIMING'
Report : timing
Design : axi_llc_subsystem_dual

  No constrained paths.
EOF_TIMING
}

write_good_netlist() {
  cat > "$run_dir/outputs/netlist/selftest_postcompile_1g.v" <<'EOF_NETLIST'
module selftest_netlist;
  sassls0c4l1p4096x256m4b4w1c1p0d0t0s2sdz1rw00 u_data ();
  sassls0c4l1p4096x16m16b1w1c1p0d0t0s2sdz1rw00 u_meta ();
endmodule
EOF_NETLIST
}

write_bad_netlist_missing_meta() {
  cat > "$run_dir/outputs/netlist/selftest_postcompile_1g.v" <<'EOF_NETLIST'
module selftest_netlist;
  sassls0c4l1p4096x256m4b4w1c1p0d0t0s2sdz1rw00 u_data ();
endmodule
EOF_NETLIST
}

run_gate() {
  AXI_LLC_DC_ACTIVE_MARKERS="$marker" AXI_LLC_DC_SIGNOFF_MARKER="$marker" \
    AXI_LLC_GATE_SKIP_NON_DC=1 \
    bash rtl/dc/check_goal_gate.sh
}

run_summary() {
  bash rtl/dc/summarize_dc_reports.sh "$marker"
}

run_monitor_once() {
    AXI_LLC_DC_ACTIVE_MARKERS="$marker" AXI_LLC_DC_SIGNOFF_MARKER="$marker" \
    AXI_LLC_GATE_SKIP_NON_DC=1 \
    DC_MONITOR_ONCE=1 \
    DC_MONITOR_LIGHTWEIGHT=1 \
    DC_MONITOR_LATEST="$tmp_dir/monitor_latest.txt" \
    DC_MONITOR_LOG="$tmp_dir/monitor.log" \
    bash rtl/dc/monitor_dc_status.sh >/dev/null
  cat "$tmp_dir/monitor_latest.txt"
}

write_qor "0.01"
write_timing
write_good_netlist
pass_output=$(run_gate)
if ! grep -Fq 'DC_SETUP status=PASS reason=signoff_full_compile_setup_pass' <<<"$pass_output"; then
  printf 'expected positive signoff QoR to pass DC_SETUP\n' >&2
  printf '%s\n' "$pass_output" >&2
  exit 1
fi
if ! grep -Fq 'DC_MACRO_BINDING status=PASS reason=db_linked_and_signoff_netlist_keeps_macros' <<<"$pass_output"; then
  printf 'expected signoff netlist macro refs to pass DC_MACRO_BINDING\n' >&2
  printf '%s\n' "$pass_output" >&2
  exit 1
fi
if ! grep -Fq 'DC_LIBRARY_BINDING status=PASS reason=all_active_runs_link_9t20_rvt_lvt_and_no_7p5t' <<<"$pass_output"; then
  printf 'expected 9T20 RVT/LVT link report to pass DC_LIBRARY_BINDING\n' >&2
  printf '%s\n' "$pass_output" >&2
  exit 1
fi
pass_summary=$(run_summary)
if ! grep -Fq '  status=PASS reason=all_final_qor_non_negative_setup' <<<"$pass_summary"; then
  printf 'expected positive signoff QoR/timing to pass summarize SETUP_GATE\n' >&2
  printf '%s\n' "$pass_summary" >&2
  exit 1
fi
pass_monitor=$(run_monitor_once)
if ! grep -Fq 'DC_SETUP status=PASS reason=signoff_full_compile_setup_pass' <<<"$pass_monitor"; then
  printf 'expected monitor GOAL_GATE to see positive signoff DC_SETUP PASS\n' >&2
  printf '%s\n' "$pass_monitor" >&2
  exit 1
fi
if ! grep -Fq 'status=PASS reason=all_final_qor_non_negative_setup' <<<"$pass_monitor"; then
  printf 'expected monitor ACTIVE_RUNS SETUP_GATE to pass with positive QoR/timing\n' >&2
  printf '%s\n' "$pass_monitor" >&2
  exit 1
fi

printf 'scc12nsfe_96sdb_7p5tc_rvt_ssg_v0p72_ccs (library) /tmp/7p5.db\n' >> "$run_dir/reports/link.rpt"
bad_stdcell_output=$(run_gate || true)
if ! grep -Fq 'DC_LIBRARY_BINDING status=FAIL reason=unexpected_7p5t_stdcell_db_link' <<<"$bad_stdcell_output"; then
  printf 'expected unexpected 7p5t stdcell link to fail DC_LIBRARY_BINDING\n' >&2
  printf '%s\n' "$bad_stdcell_output" >&2
  exit 1
fi
sed -i '/7p5/d;/7P5/d;/96SDB_7P5TC/d' "$run_dir/reports/link.rpt"

touch -d '2030-01-01 00:00:01' "$fake_script"
stale_script_output=$(run_gate)
if ! grep -Fq 'DC_SOURCE_FRESHNESS status=WAIT reason=full_compile_1g_signoff_selftest_older_than_' <<<"$stale_script_output"; then
  printf 'expected newer DC SCRIPT metadata input to make DC_SOURCE_FRESHNESS wait\n' >&2
  printf '%s\n' "$stale_script_output" >&2
  exit 1
fi
touch -d '2030-01-01 00:00:02' "$run_dir/source_status.txt"

rm -f "$run_dir/reports/selftest_postcompile_1g_timing.rpt"
missing_timing_output=$(run_gate)
if ! grep -Fq 'DC_RUN_LIVENESS status=PASS reason=active_runs_alive_or_have_final_qor_and_timing' <<<"$missing_timing_output"; then
  printf 'expected live run with missing timing report to keep DC_RUN_LIVENESS passing\n' >&2
  printf '%s\n' "$missing_timing_output" >&2
  exit 1
fi
if ! grep -Fq 'DC_SETUP status=WAIT reason=missing_signoff_postcompile_timing' <<<"$missing_timing_output"; then
  printf 'expected missing signoff timing report to keep DC_SETUP waiting\n' >&2
  printf '%s\n' "$missing_timing_output" >&2
  exit 1
fi
if ! grep -Fq 'DC_MACRO_BINDING status=PASS reason=db_linked_signoff_timing_pending' <<<"$missing_timing_output"; then
  printf 'expected missing signoff timing report to keep DC_MACRO_BINDING in non-blocking timing-pending state\n' >&2
  printf '%s\n' "$missing_timing_output" >&2
  exit 1
fi
missing_timing_summary=$(run_summary)
if ! grep -Fq '  status=WAIT reason=missing_final_timing_for_selftest_postcompile_1g_qor.rpt' <<<"$missing_timing_summary"; then
  printf 'expected summarize SETUP_GATE to wait when signoff timing report is missing\n' >&2
  printf '%s\n' "$missing_timing_summary" >&2
  exit 1
fi
missing_timing_monitor=$(run_monitor_once)
if ! grep -Fq 'DC_SETUP status=WAIT reason=missing_signoff_postcompile_timing' <<<"$missing_timing_monitor"; then
  printf 'expected monitor GOAL_GATE to wait when signoff timing report is missing\n' >&2
  printf '%s\n' "$missing_timing_monitor" >&2
  exit 1
fi
if ! grep -Fq 'status=WAIT reason=missing_final_timing_for_selftest_postcompile_1g_qor.rpt' <<<"$missing_timing_monitor"; then
  printf 'expected monitor ACTIVE_RUNS SETUP_GATE to wait when signoff timing report is missing\n' >&2
  printf '%s\n' "$missing_timing_monitor" >&2
  exit 1
fi

printf '15\n' > "$run_dir/exit_code.txt"
exited_missing_timing_output=$(run_gate || true)
if ! grep -Fq 'DC_RUN_LIVENESS status=FAIL reason=full_compile_1g_signoff_selftest_exited_15_without_final_qor_or_timing' <<<"$exited_missing_timing_output"; then
  printf 'expected exited run with missing timing report to fail DC_RUN_LIVENESS\n' >&2
  printf '%s\n' "$exited_missing_timing_output" >&2
  exit 1
fi
rm -f "$run_dir/exit_code.txt"

write_violated_timing
violated_timing_output=$(run_gate || true)
if ! grep -Fq 'DC_SETUP status=FAIL reason=signoff_timing_report_has_violated_setup_path' <<<"$violated_timing_output"; then
  printf 'expected violated signoff timing report to fail DC_SETUP\n' >&2
  printf '%s\n' "$violated_timing_output" >&2
  exit 1
fi
violated_timing_summary=$(run_summary)
if ! grep -Fq '  status=FAIL reason=final_timing_has_violated_setup_path_for_selftest_postcompile_1g_timing.rpt' <<<"$violated_timing_summary"; then
  printf 'expected summarize SETUP_GATE to fail on violated signoff timing report\n' >&2
  printf '%s\n' "$violated_timing_summary" >&2
  exit 1
fi
violated_timing_monitor=$(run_monitor_once)
if ! grep -Fq 'DC_SETUP status=FAIL reason=signoff_timing_report_has_violated_setup_path' <<<"$violated_timing_monitor"; then
  printf 'expected monitor GOAL_GATE to fail on violated signoff timing report\n' >&2
  printf '%s\n' "$violated_timing_monitor" >&2
  exit 1
fi
if ! grep -Fq 'status=FAIL reason=final_timing_has_violated_setup_path_for_selftest_postcompile_1g_timing.rpt' <<<"$violated_timing_monitor"; then
  printf 'expected monitor ACTIVE_RUNS SETUP_GATE to fail on violated signoff timing report\n' >&2
  printf '%s\n' "$violated_timing_monitor" >&2
  exit 1
fi

write_no_slack_timing
no_slack_output=$(run_gate || true)
if ! grep -Fq 'DC_SETUP status=FAIL reason=signoff_timing_parse_gap' <<<"$no_slack_output"; then
  printf 'expected signoff timing report without slack lines to fail DC_SETUP\n' >&2
  printf '%s\n' "$no_slack_output" >&2
  exit 1
fi
no_slack_summary=$(run_summary)
if ! grep -Fq '  status=FAIL reason=final_timing_parse_gap_for_selftest_postcompile_1g_timing.rpt' <<<"$no_slack_summary"; then
  printf 'expected summarize SETUP_GATE to fail on signoff timing report without slack lines\n' >&2
  printf '%s\n' "$no_slack_summary" >&2
  exit 1
fi
no_slack_monitor=$(run_monitor_once)
if ! grep -Fq 'DC_SETUP status=FAIL reason=signoff_timing_parse_gap' <<<"$no_slack_monitor"; then
  printf 'expected monitor GOAL_GATE to fail on signoff timing report without slack lines\n' >&2
  printf '%s\n' "$no_slack_monitor" >&2
  exit 1
fi
if ! grep -Fq 'status=FAIL reason=final_timing_parse_gap_for_selftest_postcompile_1g_timing.rpt' <<<"$no_slack_monitor"; then
  printf 'expected monitor ACTIVE_RUNS SETUP_GATE to fail on signoff timing report without slack lines\n' >&2
  printf '%s\n' "$no_slack_monitor" >&2
  exit 1
fi

write_timing
rm -f "$run_dir/outputs/netlist/selftest_postcompile_1g.v"
missing_netlist_output=$(run_gate)
if ! grep -Fq 'DC_SETUP status=PASS reason=signoff_full_compile_setup_pass' <<<"$missing_netlist_output"; then
  printf 'expected positive signoff QoR to keep DC_SETUP passing when netlist is missing\n' >&2
  printf '%s\n' "$missing_netlist_output" >&2
  exit 1
fi
if ! grep -Fq 'DC_MACRO_BINDING status=WAIT reason=signoff_final_netlist_missing_or_not_yet_written' <<<"$missing_netlist_output"; then
  printf 'expected missing signoff netlist to keep DC_MACRO_BINDING waiting\n' >&2
  printf '%s\n' "$missing_netlist_output" >&2
  exit 1
fi

write_bad_netlist_missing_meta
missing_macro_output=$(run_gate || true)
if ! grep -Fq 'DC_MACRO_BINDING status=FAIL reason=signoff_final_netlist_missing_sram_macro_refs' <<<"$missing_macro_output"; then
  printf 'expected missing meta/data macro refs to fail DC_MACRO_BINDING\n' >&2
  printf '%s\n' "$missing_macro_output" >&2
  exit 1
fi

write_qor "-0.01"
write_good_netlist
fail_output=$(run_gate || true)
if ! grep -Fq 'DC_SETUP status=FAIL reason=signoff_full_compile_setup_violation_wns_-0.01_tns_0.00_viol_0.00' <<<"$fail_output"; then
  printf 'expected negative signoff QoR to fail DC_SETUP\n' >&2
  printf '%s\n' "$fail_output" >&2
  exit 1
fi
fail_summary=$(run_summary)
if ! grep -Fq '  status=FAIL reason=one_or_more_final_qor_has_setup_violation_or_parse_gap' <<<"$fail_summary"; then
  printf 'expected summarize SETUP_GATE to fail on negative signoff QoR\n' >&2
  printf '%s\n' "$fail_summary" >&2
  exit 1
fi
fail_monitor=$(run_monitor_once)
if ! grep -Fq 'DC_SETUP status=FAIL reason=signoff_full_compile_setup_violation_wns_-0.01_tns_0.00_viol_0.00' <<<"$fail_monitor"; then
  printf 'expected monitor GOAL_GATE to fail on negative signoff QoR\n' >&2
  printf '%s\n' "$fail_monitor" >&2
  exit 1
fi
if ! grep -Fq 'status=FAIL reason=one_or_more_final_qor_has_setup_violation_or_parse_gap' <<<"$fail_monitor"; then
  printf 'expected monitor ACTIVE_RUNS SETUP_GATE to fail on negative signoff QoR\n' >&2
  printf '%s\n' "$fail_monitor" >&2
  exit 1
fi

printf 'PASS goal gate signoff selftest\n'
