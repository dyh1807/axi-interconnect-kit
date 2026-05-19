#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/../.." && pwd)
cd "$repo_root"

compat_rtl=rtl/src/axi_llc_subsystem_compat.v
contracts_dir=rtl/local_debug/vcs_all_contracts_payload_circular_20260512_234723_eda-05
preferred_hit_log=rtl/local_debug/vcs_cpp_llc_hit_perf_contract_payload_circular_20260512_234630_eda-05/run.log
preferred_bounded_log=rtl/local_debug/vcs_cpp_perf_contract_payload_circular_20260512_234659_eda-05/run.log
linux_300k_log=../local_logs/goal_llc_hit_dc_20260511/linux_large_bpu_mode1_300k_after_cpp_resp_boundary_20260511_071015.log
linux_5m_log=../local_logs/goal_llc_hit_dc_20260511/linux_large_bpu_mode1_5m_after_cpp_resp_boundary_20260511_071224.log
linux_sim_exe=../build_goal_llc_hit_large_bpu_20260511/simulator
linux_profile_inputs=(
  ../Makefile
  ../include/config.h.large
  ../include/config.h
  ../front-end/config/frontend_feature_config.h.large
  ../front-end/config/frontend_feature_config.h
)
perf_inputs=(
  "$compat_rtl"
  rtl/tb/tb_axi_llc_subsystem_dual_cpp_perf_contract.v
  rtl/include/axi_dual_cpp_perf_vectors.vh
  axi_interconnect/AXI_Interconnect.cpp
  axi_interconnect/include/AXI_Interconnect.h
  axi_interconnect/axi_interconnect_dual_port_perf_vectors_test.cpp
)
if [[ -n "${AXI_LLC_DC_ACTIVE_MARKERS:-}" ]]; then
  IFS=: read -r -a active_dc_markers <<< "$AXI_LLC_DC_ACTIVE_MARKERS"
else
  active_dc_markers=(
    rtl/dc/.latest_full_compile_1g
  )
fi
dc_signoff_marker=${AXI_LLC_DC_SIGNOFF_MARKER:-rtl/dc/.latest_full_compile_1g}
skip_non_dc_gates=${AXI_LLC_GATE_SKIP_NON_DC:-0}

status=PASS
blockers=()
stale_input=
dc_summary_cache=

mtime_epoch() {
  stat -c %Y "$1"
}

print_gate() {
  local name="$1"
  local gate_status="$2"
  local reason="$3"
  printf '%s status=%s reason=%s\n' "$name" "$gate_status" "$reason"
  if [[ "$gate_status" != PASS ]]; then
    if [[ "$gate_status" == FAIL ]]; then
      status=FAIL
    elif [[ "$status" != FAIL ]]; then
      status=WAIT
    fi
    blockers+=("${name}:${gate_status}:${reason}")
  fi
}

latest_log_with_marker() {
  local path_pattern="$1"
  local marker="$2"
  local log
  while IFS= read -r log; do
    if grep -Fq "$marker" "$log"; then
      printf '%s\n' "$log"
      return 0
    fi
  done < <(find rtl/local_debug -path "$path_pattern" -type f -name run.log -printf '%T@ %p\n' 2>/dev/null | sort -rn | cut -d' ' -f2-)
  return 1
}

select_log_with_marker() {
  local preferred_log="$1"
  local path_pattern="$2"
  local marker="$3"
  if [[ -f "$preferred_log" ]] && grep -Fq "$marker" "$preferred_log"; then
    printf '%s\n' "$preferred_log"
    return 0
  fi
  latest_log_with_marker "$path_pattern" "$marker"
}

fresh_against_inputs() {
  local log="$1"
  local input
  stale_input=
  for input in "${@:2}"; do
    if [[ ! -e "$input" ]]; then
      stale_input="missing_${input//\//_}"
      return 1
    fi
    if (( $(mtime_epoch "$log") < $(mtime_epoch "$input") )); then
      stale_input="${input//\//_}"
      return 1
    fi
  done
  return 0
}

fresh_contract_dir_against_rtl_tree() {
  local contract_dir="$1"
  local input
  local oldest_run_log
  local oldest_run_log_mtime
  stale_input=
  oldest_run_log=$(
    find "$contract_dir" -maxdepth 2 -type f -name run.log -printf '%T@ %p\n' 2>/dev/null |
      sort -n |
      awk 'NR == 1 {print $2}'
  )
  if [[ -z "$oldest_run_log" || ! -f "$oldest_run_log" ]]; then
    stale_input="missing_run_log"
    return 1
  fi
  oldest_run_log_mtime=$(mtime_epoch "$oldest_run_log")
  while IFS= read -r input; do
    if (( oldest_run_log_mtime < $(mtime_epoch "$input") )); then
      stale_input="${input//\//_}"
      return 1
    fi
  done < <(find rtl/src rtl/tb rtl/include rtl/flist \
             -type f \( -name '*.v' -o -name '*.vh' -o -name '*.f' \) \
             -print 2>/dev/null)
  return 0
}

get_dc_summary() {
  if [[ -z "${dc_summary_cache:-}" ]]; then
    dc_summary_cache=$(rtl/dc/summarize_dc_reports.sh "${active_dc_markers[@]}")
  fi
  printf '%s\n' "$dc_summary_cache"
}

sanitize_path() {
  local path="$1"
  printf '%s\n' "${path//\//_}"
}

extract_qor_number() {
  local label="$1"
  local rpt="$2"
  awk -v label="$label" '
    index($0, label) {
      value = $NF
      gsub(/,/, "", value)
      print value
      exit
    }
  ' "$rpt"
}

resolve_marker_run() {
  local marker="$1"
  local run="$marker"
  if [[ "$run" != /* ]]; then
    run="$repo_root/$run"
  fi
  if [[ -L "$run" ]]; then
    run=$(readlink -f "$run" || true)
    if [[ -z "$run" || ! -d "$run" ]]; then
      return 1
    fi
    printf '%s\n' "$run"
    return 0
  fi
  if [[ -d "$run" ]]; then
    printf '%s\n' "$run"
    return 0
  fi
  if [[ ! -f "$run" ]]; then
    return 1
  fi
  run=$(head -n 1 "$run" || true)
  if [[ -z "$run" || ! -d "$run" ]]; then
    return 1
  fi
  printf '%s\n' "$run"
}

signoff_run_dir() {
  resolve_marker_run "$dc_signoff_marker"
}

signoff_qor_report() {
  local run="$1"
  find "$run/reports" -maxdepth 1 -type f -name '*postcompile_1g_qor.rpt' 2>/dev/null | sort | head -n 1
}

signoff_timing_report() {
  local run="$1"
  find "$run/reports" -maxdepth 1 -type f -name '*postcompile_1g_timing.rpt' 2>/dev/null | sort | head -n 1
}

qor_has_non_negative_setup() {
  local rpt="$1"
  local wns tns viol
  wns=$(extract_qor_number 'Critical Path Slack' "$rpt")
  tns=$(extract_qor_number 'Total Negative Slack' "$rpt")
  viol=$(extract_qor_number 'No. of Violating Paths' "$rpt")
  [[ -n "${wns:-}" && -n "${tns:-}" && -n "${viol:-}" ]] || return 2
  awk -v wns="$wns" -v tns="$tns" -v viol="$viol" \
    'BEGIN { exit !((wns + 0) >= 0 && (tns + 0) == 0 && (viol + 0) == 0) }'
}

timing_report_has_setup_slack() {
  local rpt="$1"
  grep -Eq 'slack[[:space:]]+\(' "$rpt"
}

timing_report_has_no_violated_setup_slack() {
  local rpt="$1"
  ! grep -Eq 'slack[[:space:]]+\(VIOLATED\)' "$rpt"
}

check_llc_hit() {
  local hit_log
  hit_log=$(select_log_with_marker \
    "$preferred_hit_log" \
    'rtl/local_debug/vcs_cpp_llc_hit_perf_contract_*/run.log' \
    'tb_axi_llc_subsystem_dual_cpp_perf_contract PASS LLC_HIT_ONLY' || true)
  if [[ -z "$hit_log" || ! -f "$hit_log" ]]; then
    print_gate LLC_HIT WAIT missing_rtl_or_log
    return
  fi
  if ! fresh_against_inputs "$hit_log" "${perf_inputs[@]}"; then
    print_gate LLC_HIT WAIT hit_log_older_than_${stale_input}
    return
  fi
  if ! grep -Fq 'PERF LLC_HIT_READ64 CHECKED ready=0 resp=7 external=-1' "$hit_log"; then
    print_gate LLC_HIT FAIL missing_read_hit_exact_cycle_marker
    return
  fi
  if ! grep -Fq 'PERF LLC_HIT_WRITE64 CHECKED ready=1 resp=9 external=-1' "$hit_log"; then
    print_gate LLC_HIT FAIL missing_write_hit_exact_cycle_marker
    return
  fi
  if ! grep -Fq 'tb_axi_llc_subsystem_dual_cpp_perf_contract PASS LLC_HIT_ONLY' "$hit_log"; then
    print_gate LLC_HIT FAIL missing_pass_marker
    return
  fi
  print_gate LLC_HIT PASS exact_read_ready0_resp7_write_ready1_resp9_no_external
}

check_bounded_non_hit() {
  local bounded_log
  bounded_log=$(select_log_with_marker \
    "$preferred_bounded_log" \
    'rtl/local_debug/vcs_cpp_perf_contract_*/run.log' \
    'tb_axi_llc_subsystem_dual_cpp_perf_contract PASS bounded_non_hit' || true)
  if [[ -z "$bounded_log" || ! -f "$bounded_log" ]]; then
    print_gate BOUNDED_NON_HIT WAIT missing_rtl_or_log
    return
  fi
  if ! fresh_against_inputs "$bounded_log" "${perf_inputs[@]}"; then
    print_gate BOUNDED_NON_HIT WAIT bounded_log_older_than_${stale_input}
    return
  fi
  if ! grep -Fq 'PERF LLC_MISS_READ64 CHECKED ready=0 ar=8 r0=10 r1=11 resp=18' "$bounded_log"; then
    print_gate BOUNDED_NON_HIT FAIL missing_llc_miss_marker
    return
  fi
  if ! grep -Fq 'PASS bounded_non_hit max_extra_observed=5 direct_max_extra_allowed=6 llc_miss_max_extra_allowed=8' "$bounded_log"; then
    print_gate BOUNDED_NON_HIT FAIL missing_bounded_pass_marker
    return
  fi
  print_gate BOUNDED_NON_HIT PASS max_extra5_within_limits
}

check_contracts() {
  if [[ ! -d "$contracts_dir" ]]; then
    print_gate RTL_CONTRACTS WAIT missing_contracts_dir
    return
  fi
  if ! fresh_contract_dir_against_rtl_tree "$contracts_dir"; then
    print_gate RTL_CONTRACTS WAIT contracts_dir_older_than_${stale_input}
    return
  fi
  local run_count
  run_count=$(find "$contracts_dir" -maxdepth 2 -type f -name run.log | wc -l)
  if [[ "$run_count" -ne 53 ]]; then
    print_gate RTL_CONTRACTS WAIT expected_53_run_logs_got_${run_count}
    return
  fi
  if find "$contracts_dir" -maxdepth 2 -type f -name run.log -print0 | xargs -0 grep -E '(^| )FAIL|ERROR|MISMATCH|mismatch' >/dev/null; then
    print_gate RTL_CONTRACTS FAIL failure_marker_found
    return
  fi
  print_gate RTL_CONTRACTS PASS 53_run_logs_no_fail_error_mismatch
}

check_linux_sanity() {
  local log
  local input
  if [[ ! -x "$linux_sim_exe" ]]; then
    print_gate LINUX_SANITY WAIT missing_linux_simulator_binary
    return
  fi
  if ! cmp -s ../include/config.h ../include/config.h.large; then
    print_gate LINUX_SANITY WAIT active_include_config_not_large
    return
  fi
  if ! cmp -s ../front-end/config/frontend_feature_config.h ../front-end/config/frontend_feature_config.h.large; then
    print_gate LINUX_SANITY WAIT active_frontend_config_not_large
    return
  fi
  if ! grep -Fq 'constexpr int ROB_NUM = 512;' ../include/config.h.large; then
    print_gate LINUX_SANITY FAIL large_profile_rob_num_not_512
    return
  fi
  if ! grep -Fq 'constexpr int ROB_NUM = 512;' ../include/config.h; then
    print_gate LINUX_SANITY FAIL active_profile_rob_num_not_512
    return
  fi
  for input in "${linux_profile_inputs[@]}"; do
    if [[ ! -e "$input" ]]; then
      print_gate LINUX_SANITY WAIT missing_$(sanitize_path "$input")
      return
    fi
    if (( $(mtime_epoch "$linux_sim_exe") < $(mtime_epoch "$input") )); then
      print_gate LINUX_SANITY WAIT simulator_binary_older_than_$(sanitize_path "$input")
      return
    fi
  done
  for log in "$linux_300k_log" "$linux_5m_log"; do
    if [[ ! -f "$log" ]]; then
      print_gate LINUX_SANITY WAIT missing_$(sanitize_path "$log")
      return
    fi
    if (( $(mtime_epoch "$log") < $(mtime_epoch "$linux_sim_exe") )); then
      print_gate LINUX_SANITY WAIT linux_log_older_than_simulator_binary
      return
    fi
    if ! fresh_against_inputs "$log" axi_interconnect/AXI_Interconnect.cpp axi_interconnect/include/AXI_Interconnect.h; then
      print_gate LINUX_SANITY WAIT linux_log_older_than_${stale_input}
      return
    fi
    if grep -E 'Difftest: error|ABORT|abort|panic|deadlock|timeout|Segmentation fault' "$log" >/dev/null; then
      print_gate LINUX_SANITY FAIL failure_marker_found_in_$(basename "$log")
      return
    fi
    if ! grep -Fq 'bpu=1(real-bpu)' "$log"; then
      print_gate LINUX_SANITY FAIL missing_bpu_marker_in_$(basename "$log")
      return
    fi
    if ! grep -Fq 'Success!!!!' "$log"; then
      print_gate LINUX_SANITY FAIL missing_success_marker_in_$(basename "$log")
      return
    fi
  done

  if ! grep -Fq 'sim-time(cycle)= 121383, committed(total/load/store)= 300001 / 40586 / 51609' "$linux_300k_log"; then
    print_gate LINUX_SANITY FAIL unexpected_300k_cycle_or_commit_count
    return
  fi
  if ! grep -Fq 'ipc            : 2.471524' "$linux_300k_log"; then
    print_gate LINUX_SANITY FAIL unexpected_300k_ipc
    return
  fi
  if ! grep -Fq 'sim-time(cycle)= 2086921, committed(total/load/store)= 5000005 / 530423 / 921658' "$linux_5m_log"; then
    print_gate LINUX_SANITY FAIL unexpected_5m_cycle_or_commit_count
    return
  fi
  if ! grep -Fq 'ipc            : 2.395877' "$linux_5m_log"; then
    print_gate LINUX_SANITY FAIL unexpected_5m_ipc
    return
  fi

  print_gate LINUX_SANITY PASS large_bpu_300k_5m_success_perf_within_recorded_bounds
}

check_dc_source_freshness() {
  local marker run capture capture_mtime input script_input recorded_hash actual_hash
  stale_input=
  for marker in "${active_dc_markers[@]}"; do
    run=$(resolve_marker_run "$marker" || true)
    if [[ -z "$run" || ! -d "$run" ]]; then
      print_gate DC_SOURCE_FRESHNESS WAIT missing_run_for_$(sanitize_path "$marker")
      return
    fi
    capture="$run/source_status.txt"
    if [[ ! -f "$capture" ]]; then
      print_gate DC_SOURCE_FRESHNESS WAIT missing_source_status_for_$(basename "$run")
      return
    fi
    recorded_hash=$(awk -F= '$1 == "RTL_COMPAT_SHA256" {print $2; exit}' "$capture" 2>/dev/null || true)
    if [[ -n "$recorded_hash" ]]; then
      actual_hash=$(sha256sum "$compat_rtl" | awk '{print $1}')
      if [[ "$recorded_hash" != "$actual_hash" ]]; then
        print_gate DC_SOURCE_FRESHNESS WAIT source_hash_mismatch_$(sanitize_path "$compat_rtl")
        return
      fi
    fi
    recorded_hash=$(awk -F= '$1 == "DC_COMMON_SHA256" {print $2; exit}' "$capture" 2>/dev/null || true)
    if [[ -n "$recorded_hash" ]]; then
      actual_hash=$(sha256sum rtl/dc/axi_llc_dc_common.tcl | awk '{print $1}')
      if [[ "$recorded_hash" != "$actual_hash" ]]; then
        print_gate DC_SOURCE_FRESHNESS WAIT source_hash_mismatch_rtl_dc_axi_llc_dc_common_tcl
        return
      fi
    fi
    capture_mtime=$(mtime_epoch "$capture")
    while IFS= read -r input; do
      if (( $(mtime_epoch "$input") > capture_mtime )); then
        stale_input="$(basename "$run")_older_than_$(sanitize_path "$input")"
        print_gate DC_SOURCE_FRESHNESS WAIT "$stale_input"
        return
      fi
    done < <(find rtl/src rtl/include rtl/flist \
               -type f \( -name '*.v' -o -name '*.vh' -o -name '*.f' \) \
               -print 2>/dev/null)
    for input in rtl/dc/axi_llc_dc_common.tcl; do
      if [[ ! -e "$input" ]]; then
        print_gate DC_SOURCE_FRESHNESS WAIT missing_$(sanitize_path "$input")
        return
      fi
      if (( $(mtime_epoch "$input") > capture_mtime )); then
        stale_input="$(basename "$run")_older_than_$(sanitize_path "$input")"
        print_gate DC_SOURCE_FRESHNESS WAIT "$stale_input"
        return
      fi
    done
    script_input=$(awk -F= '$1 == "SCRIPT" {print $2; exit}' "$run/run_metadata.txt" 2>/dev/null || true)
    if [[ -n "$script_input" ]]; then
      if [[ ! -e "$script_input" ]]; then
        print_gate DC_SOURCE_FRESHNESS WAIT missing_$(sanitize_path "$script_input")
        return
      fi
      recorded_hash=$(awk -F= '$1 == "SCRIPT_SHA256" {print $2; exit}' "$capture" 2>/dev/null || true)
      if [[ -n "$recorded_hash" ]]; then
        actual_hash=$(sha256sum "$script_input" | awk '{print $1}')
        if [[ "$recorded_hash" != "$actual_hash" ]]; then
          print_gate DC_SOURCE_FRESHNESS WAIT source_hash_mismatch_$(sanitize_path "$script_input")
          return
        fi
      fi
      if (( $(mtime_epoch "$script_input") > capture_mtime )); then
        stale_input="$(basename "$run")_older_than_$(sanitize_path "$script_input")"
        print_gate DC_SOURCE_FRESHNESS WAIT "$stale_input"
        return
      fi
    fi
  done
  print_gate DC_SOURCE_FRESHNESS PASS all_active_dc_runs_match_current_synth_inputs_and_dc_scripts
}

run_has_final_qor_and_timing() {
  local run="$1"
  local rpt_dir="$run/reports"
  if compgen -G "$rpt_dir/*quick_map_low_qor.rpt" >/dev/null; then
    compgen -G "$rpt_dir/*quick_map_low_timing.rpt" >/dev/null && return 0
  fi
  if compgen -G "$rpt_dir/*postcompile_1g_qor.rpt" >/dev/null; then
    compgen -G "$rpt_dir/*postcompile_1g_timing.rpt" >/dev/null && return 0
  fi
  return 1
}

metadata_pid() {
  local run="$1"
  local key="$2"
  awk -F= -v key="$key" '$1 == key {gsub(/[^0-9]/, "", $2); print $2; exit}' "$run/run_metadata.txt" 2>/dev/null || true
}

metadata_host() {
  local run="$1"
  awk -F= '$1 == "HOST" {print $2; exit}' "$run/run_metadata.txt" 2>/dev/null || true
}

host_is_local() {
  local host="$1"
  local local_full local_short
  local_full=$(hostname 2>/dev/null || true)
  local_short=$(hostname -s 2>/dev/null || true)
  [[ -z "$host" || "$host" == "$local_full" || "$host" == "$local_short" || "$host" == localhost || "$host" == 127.0.0.1 ]]
}

pid_is_alive_on_host() {
  local host="$1"
  local pid="$2"
  [[ -n "$pid" ]] || return 1
  if host_is_local "$host"; then
    ps -p "$pid" >/dev/null 2>&1
  else
    ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" "ps -p '$pid' >/dev/null 2>&1" >/dev/null 2>&1
  fi
}

check_dc_run_liveness() {
  local marker run run_host dc_pid timeout_pid launcher_pid exit_code
  for marker in "${active_dc_markers[@]}"; do
    run=$(resolve_marker_run "$marker" || true)
    if [[ -z "$run" || ! -d "$run" ]]; then
      print_gate DC_RUN_LIVENESS WAIT missing_run_for_$(sanitize_path "$marker")
      return
    fi
    if run_has_final_qor_and_timing "$run"; then
      continue
    fi
    if [[ -f "$run/exit_code.txt" ]]; then
      exit_code=$(tr -dc '0-9' < "$run/exit_code.txt" || true)
      print_gate DC_RUN_LIVENESS FAIL "$(basename "$run")_exited_${exit_code:-unknown}_without_final_qor_or_timing"
      return
    fi
    run_host=$(metadata_host "$run")
    dc_pid=$(metadata_pid "$run" DC_PID)
    timeout_pid=$(metadata_pid "$run" TIMEOUT_PID)
    launcher_pid=$(metadata_pid "$run" LAUNCHER_PID)
    if pid_is_alive_on_host "$run_host" "$dc_pid" || \
       pid_is_alive_on_host "$run_host" "$timeout_pid" || \
       pid_is_alive_on_host "$run_host" "$launcher_pid"; then
      continue
    fi
    print_gate DC_RUN_LIVENESS FAIL "$(basename "$run")_not_live_and_missing_final_qor_or_timing"
    return
  done
  print_gate DC_RUN_LIVENESS PASS active_runs_alive_or_have_final_qor_and_timing
}

check_dc_setup() {
  local summary
  summary=$(get_dc_summary)
  printf '%s\n' "$summary" | awk '/^===== RUN / || /^  RUN_KIND=/ || /^  TOP=/ || /^SETUP_GATE$/ || /^SETUP_TREND$/ || /^  status=/ || /^status=/ || /^  qor=/' | sed 's/^/DC_SUMMARY /'

  local run rpt timing_rpt wns tns viol
  run=$(signoff_run_dir || true)
  if [[ -z "${run:-}" ]]; then
    print_gate DC_SETUP WAIT missing_signoff_full_compile_run
    return
  fi
  rpt=$(signoff_qor_report "$run")
  if [[ -z "${rpt:-}" || ! -f "$rpt" ]]; then
    print_gate DC_SETUP WAIT missing_signoff_postcompile_qor
    return
  fi
  timing_rpt=$(signoff_timing_report "$run")
  if [[ -z "${timing_rpt:-}" || ! -f "$timing_rpt" ]]; then
    print_gate DC_SETUP WAIT missing_signoff_postcompile_timing
    return
  fi
  if ! timing_report_has_setup_slack "$timing_rpt"; then
    print_gate DC_SETUP FAIL signoff_timing_parse_gap
    return
  fi
  if ! timing_report_has_no_violated_setup_slack "$timing_rpt"; then
    print_gate DC_SETUP FAIL signoff_timing_report_has_violated_setup_path
    return
  fi

  wns=$(extract_qor_number 'Critical Path Slack' "$rpt")
  tns=$(extract_qor_number 'Total Negative Slack' "$rpt")
  viol=$(extract_qor_number 'No. of Violating Paths' "$rpt")
  if [[ -z "${wns:-}" || -z "${tns:-}" || -z "${viol:-}" ]]; then
    print_gate DC_SETUP FAIL signoff_qor_parse_gap
    return
  fi
  if qor_has_non_negative_setup "$rpt"; then
    print_gate DC_SETUP PASS signoff_full_compile_setup_pass
  else
    print_gate DC_SETUP FAIL signoff_full_compile_setup_violation_wns_${wns}_tns_${tns}_viol_${viol}
  fi
}

check_dc_macro_binding() {
  local summary
  summary=$(get_dc_summary)

  local active_count data_link_count meta_link_count
  active_count=$(printf '%s\n' "$summary" | grep -c '^===== RUN ' || true)
  data_link_count=$(printf '%s\n' "$summary" | grep -c 'data_macro_db_linked=yes' || true)
  meta_link_count=$(printf '%s\n' "$summary" | grep -c 'meta_macro_db_linked=yes' || true)

  if [[ "$active_count" -eq 0 ]]; then
    print_gate DC_MACRO_BINDING WAIT no_active_dc_runs
    return
  fi
  if [[ "$data_link_count" -ne "$active_count" || "$meta_link_count" -ne "$active_count" ]]; then
    if printf '%s\n' "$summary" | grep -q 'link_report_missing'; then
      print_gate DC_MACRO_BINDING WAIT link_report_pending
      return
    fi
    print_gate DC_MACRO_BINDING FAIL missing_data_or_meta_sram_db_link
    return
  fi

  local run rpt timing_rpt netlist data_count meta_count
  run=$(signoff_run_dir || true)
  if [[ -z "${run:-}" ]]; then
    print_gate DC_MACRO_BINDING WAIT missing_signoff_full_compile_run
    return
  fi
  rpt=$(signoff_qor_report "$run")
  if [[ -z "${rpt:-}" || ! -f "$rpt" ]]; then
    print_gate DC_MACRO_BINDING PASS db_linked_signoff_netlist_pending
    return
  fi
  timing_rpt=$(signoff_timing_report "$run")
  if [[ -z "${timing_rpt:-}" || ! -f "$timing_rpt" ]]; then
    print_gate DC_MACRO_BINDING PASS db_linked_signoff_timing_pending
    return
  fi
  if ! qor_has_non_negative_setup "$rpt"; then
    print_gate DC_MACRO_BINDING PASS db_linked_signoff_setup_pending
    return
  fi

  netlist=$(find "$run/outputs/netlist" -maxdepth 1 -type f -name '*postcompile_1g.v' 2>/dev/null | sort | head -n 1)
  if [[ -z "${netlist:-}" || ! -f "$netlist" ]]; then
    print_gate DC_MACRO_BINDING WAIT signoff_final_netlist_missing_or_not_yet_written
    return
  fi
  data_count=$(grep -c 'sassls0c4l1p4096x256m4b4w1c1p0d0t0s2sdz1rw00' "$netlist" || true)
  meta_count=$(grep -c 'sassls0c4l1p4096x16m16b1w1c1p0d0t0s2sdz1rw00' "$netlist" || true)
  if [[ "$data_count" -eq 0 || "$meta_count" -eq 0 ]]; then
    print_gate DC_MACRO_BINDING FAIL signoff_final_netlist_missing_sram_macro_refs
    return
  fi

  print_gate DC_MACRO_BINDING PASS db_linked_and_signoff_netlist_keeps_macros
}

check_dc_library_binding() {
  local summary
  summary=$(get_dc_summary)

  local active_count rvt_count lvt_count bad_7p5t_count
  active_count=$(printf '%s\n' "$summary" | grep -c '^===== RUN ' || true)
  rvt_count=$(printf '%s\n' "$summary" | grep -c 'stdcell_9t20_rvt_db_linked=yes' || true)
  lvt_count=$(printf '%s\n' "$summary" | grep -c 'stdcell_9t20_lvt_db_linked=yes' || true)
  bad_7p5t_count=$(printf '%s\n' "$summary" | grep -c 'stdcell_7p5t_db_linked=yes' || true)

  if [[ "$active_count" -eq 0 ]]; then
    print_gate DC_LIBRARY_BINDING WAIT no_active_dc_runs
    return
  fi
  if [[ "$rvt_count" -ne "$active_count" || "$lvt_count" -ne "$active_count" ]]; then
    if printf '%s\n' "$summary" | grep -q 'link_report_missing'; then
      print_gate DC_LIBRARY_BINDING WAIT link_report_pending
      return
    fi
    print_gate DC_LIBRARY_BINDING FAIL missing_9t20_rvt_or_lvt_stdcell_db_link
    return
  fi
  if [[ "$bad_7p5t_count" -ne 0 ]]; then
    print_gate DC_LIBRARY_BINDING FAIL unexpected_7p5t_stdcell_db_link
    return
  fi

  print_gate DC_LIBRARY_BINDING PASS all_active_runs_link_9t20_rvt_lvt_and_no_7p5t
}

printf 'GOAL_GATE_SUMMARY %s\n' "$(date '+%F %T %Z')"
if [[ "$skip_non_dc_gates" == "1" ]]; then
  print_gate LLC_HIT PASS skipped_non_dc_gate_for_dc_signoff_selftest
  print_gate BOUNDED_NON_HIT PASS skipped_non_dc_gate_for_dc_signoff_selftest
  print_gate RTL_CONTRACTS PASS skipped_non_dc_gate_for_dc_signoff_selftest
  print_gate LINUX_SANITY PASS skipped_non_dc_gate_for_dc_signoff_selftest
else
  check_llc_hit
  check_bounded_non_hit
  check_contracts
  check_linux_sanity
fi
check_dc_source_freshness
check_dc_run_liveness
check_dc_setup
check_dc_macro_binding
check_dc_library_binding
if [[ ${#blockers[@]} -eq 0 ]]; then
  printf 'BLOCKERS none\n'
else
  printf 'BLOCKERS %s\n' "${blockers[*]}"
fi
printf 'GOAL status=%s\n' "$status"
