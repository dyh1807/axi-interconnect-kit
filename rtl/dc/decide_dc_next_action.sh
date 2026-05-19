#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$repo_root"

resolve_run() {
  local marker_or_run="$1"
  local path="$marker_or_run"
  if [[ "$path" != /* ]]; then
    path="$repo_root/$path"
  fi
  if [[ -L "$path" ]]; then
    readlink -f "$path"
  elif [[ -f "$path" ]]; then
    local target
    target=$(head -n 1 "$path" || true)
    if [[ -z "$target" ]]; then
      return 1
    fi
    if [[ "$target" != /* ]]; then
      target="$repo_root/$target"
    fi
    printf '%s\n' "$target"
  else
    printf '%s\n' "$path"
  fi
}

latest_report() {
  local run="$1"
  local pattern="$2"
  find "$run/reports" -maxdepth 1 -type f -name "$pattern" \
    -printf '%T@ %p\n' 2>/dev/null | sort -n | awk 'END {print $2}'
}

log_mtime() {
  local run="$1"
  if [[ -f "$run/launcher.log" ]]; then
    stat -c '%y' "$run/launcher.log" 2>/dev/null || true
  else
    printf 'missing_launcher_log\n'
  fi
}

latest_stage() {
  local run="$1"
  local log="$run/launcher.log"
  if [[ ! -f "$log" ]]; then
    printf 'missing_launcher_log\n'
    return
  fi
  awk '
    /=== DC_STAGE/ ||
    /=== LINK_SANITY/ ||
    /=== SRAM_HIERARCHY/ ||
    /Beginning / ||
    /Mapping Optimization/ ||
    /Implementation Selection/ ||
    /Fatal/ ||
    /Error/ {
      line=$0
    }
    END {
      if (line != "") {
        print line
      } else {
        print "no_stage_marker"
      }
    }
  ' "$log"
}

metadata_value() {
  local run="$1"
  local key="$2"
  awk -F= -v key="$key" '$1 == key {print $2; exit}' "$run/run_metadata.txt" 2>/dev/null || true
}

host_is_local() {
  local host="$1"
  local local_full local_short
  local_full=$(hostname 2>/dev/null || true)
  local_short=$(hostname -s 2>/dev/null || true)
  [[ -z "$host" || "$host" == "$local_full" || "$host" == "$local_short" || "$host" == localhost || "$host" == 127.0.0.1 ]]
}

pid_alive() {
  local host="$1"
  local pid="$2"
  if [[ -z "$pid" ]]; then
    return 1
  fi
  if host_is_local "$host"; then
    ps -p "$pid" >/dev/null 2>&1
  else
    ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" "ps -p '$pid' >/dev/null 2>&1" >/dev/null 2>&1
  fi
}

run_liveness_summary() {
  local run="$1"
  local host launcher_pid timeout_pid dc_pid alive=0
  host=$(metadata_value "$run" HOST)
  launcher_pid=$(metadata_value "$run" LAUNCHER_PID)
  timeout_pid=$(metadata_value "$run" TIMEOUT_PID)
  dc_pid=$(metadata_value "$run" DC_PID)
  printf 'process_host=%s launcher_pid=%s timeout_pid=%s dc_pid=%s ' \
    "${host:-unknown}" "${launcher_pid:-none}" "${timeout_pid:-none}" "${dc_pid:-none}"
  if pid_alive "$host" "$launcher_pid"; then
    alive=1
  fi
  if pid_alive "$host" "$timeout_pid"; then
    alive=1
  fi
  if pid_alive "$host" "$dc_pid"; then
    alive=1
  fi
  if (( alive )); then
    printf 'liveness=alive\n'
  else
    printf 'liveness=not_alive_by_recorded_pids\n'
  fi
}

qor_value() {
  local key="$1"
  local rpt="$2"
  awk -v key="$key" 'index($0, key) {print $NF; exit}' "$rpt"
}

num_ge_zero() {
  awk -v v="$1" 'BEGIN {exit !(v >= 0)}'
}

num_eq_zero() {
  awk -v v="$1" 'BEGIN {exit !(v == 0)}'
}

classify_timing_paths() {
  local timing="$1"
  awk '
    /^  Startpoint:/ {
      sp=$0
      sub(/^  Startpoint: /, "", sp)
    }
    /^  Endpoint:/ {
      ep=$0
      sub(/^  Endpoint: /, "", ep)
    }
    /slack \(VIOLATED\)/ {
      key="other"
      if (sp ~ /data_store|meta_store|valid_ram/ ||
          ep ~ /data_store|meta_store|valid_ram/) {
        key="store_or_sram"
      } else if (sp ~ /bridge_.*wr_aw_head|wr_aw_q|wr_addr_r/ ||
                 ep ~ /hazard_scoreboard|wr_hazard_line/) {
        key="bridge_or_hazard"
      } else if (sp ~ /cache_rd_rsp_head|cache_rd_rsp_data|cache_rd_rsp/ ||
                 ep ~ /mshr_refill_line|mshr_resp_match/) {
        key="refill_response"
      } else if (sp ~ /rd_resp_|read_resp|resp_pool/ ||
                 ep ~ /rd_resp_|read_resp|resp_pool/) {
        key="compat_response_pool"
      } else if (sp ~ /wr_q_w(data|strb)|direct_slot_w(data|strb)|core_req_stage_w(data|strb)/ ||
                 ep ~ /wr_q_w(data|strb)|direct_slot_w(data|strb)|core_req_stage_w(data|strb)/) {
        key="compat_write_payload"
      } else if (sp ~ /compat_(core_)?rr_ptr|compat_direct_rr_ptr|rr_ptr_r|direct_rr_ptr_r/ ||
                 ep ~ /compat_core_req_stage|core_req_stage|dispatch/) {
        key="compat_dispatch"
      }
      count[key]++
      if (!(key in sample)) {
        sample[key]="sp=" sp " ep=" ep
      }
    }
    END {
      if (length(count) == 0) {
        print "  no_violated_paths_found"
        exit
      }
      for (key in count) {
        printf "  category=%s count=%d sample=%s\n", key, count[key], sample[key]
      }
    }
  ' "$timing"
}

report_run_qor() {
  local label="$1"
  local run="$2"
  local qor_pattern="$3"
  local timing_pattern="$4"
  local setup_kind="$5"
  local qor timing wns tns violating

  printf '\n[%s]\n' "$label"
  printf 'run=%s\n' "$run"
  if [[ ! -d "$run" ]]; then
    printf 'status=WAIT reason=missing_run\n'
    return
  fi
  printf 'log_mtime=%s\n' "$(log_mtime "$run")"
  printf 'latest_stage=%s\n' "$(latest_stage "$run")"
  run_liveness_summary "$run"
  if [[ -f "$run/exit_code.txt" ]]; then
    printf 'exit_code=%s\n' "$(tr -dc '0-9' < "$run/exit_code.txt")"
  else
    printf 'exit_code=running_or_not_written\n'
  fi
  qor=$(latest_report "$run" "$qor_pattern" || true)
  timing=$(latest_report "$run" "$timing_pattern" || true)
  if [[ -z "$qor" || -z "$timing" ]]; then
    printf 'status=WAIT reason=missing_%s_qor_or_timing\n' "$setup_kind"
    printf 'action=wait_for_report\n'
    return
  fi

  wns=$(qor_value 'Critical Path Slack' "$qor")
  tns=$(qor_value 'Total Negative Slack' "$qor")
  violating=$(qor_value 'No. of Violating Paths' "$qor")
  printf 'qor=%s\n' "$qor"
  printf 'timing=%s\n' "$timing"
  printf 'wns=%s tns=%s violating_paths=%s\n' "$wns" "$tns" "$violating"

  if num_ge_zero "$wns" && num_eq_zero "$tns" && num_eq_zero "$violating" &&
     ! grep -q 'slack (VIOLATED)' "$timing"; then
    printf 'status=PASS\n'
    if [[ "$setup_kind" == "signoff" ]]; then
      printf 'action=check_final_netlist_macro_refs_then_run_completion_audit\n'
    else
      printf 'action=record_supporting_evidence_and_wait_for_fulltop_signoff\n'
    fi
    return
  fi

  printf 'status=FAIL\n'
  printf 'action=classify_final_timing_and_fix_highest_count_path_before_rerun\n'
  printf 'violated_path_categories:\n'
  classify_timing_paths "$timing"
}

echo "DC_NEXT_ACTION $(date '+%F %T %Z')"

echo
echo "[goal_gate]"
gate_tmp=$(mktemp)
trap 'rm -f "$gate_tmp"' EXIT
bash rtl/dc/check_goal_gate.sh > "$gate_tmp"
sed -n '1,120p' "$gate_tmp"

full_run=$(resolve_run rtl/dc/.latest_full_compile_1g || true)
compat_run=$(resolve_run rtl/dc/.latest_compat_low_probe || true)
old12_run=$(resolve_run rtl/dc/.reference_full_compile_1g_12h_direct_pop_predecode_clean || true)

report_run_qor "compat_quick_map_low" "$compat_run" '*quick_map_low*qor*.rpt' '*quick_map_low*timing*.rpt' "quick_map"
report_run_qor "fulltop_signoff_72h" "$full_run" '*postcompile_1g_qor.rpt' '*postcompile_1g_timing.rpt' "signoff"
report_run_qor "old12_reference_trend" "$old12_run" '*qor_precompile.rpt' '*timing_precompile.rpt' "precompile_reference"

echo
echo "[decision]"
if grep -q '^GOAL status=PASS' "$gate_tmp"; then
  echo 'overall=PASS action=perform_completion_audit_and_update_goal'
elif grep -q '^DC_SETUP status=FAIL' "$gate_tmp"; then
  echo 'overall=FAIL action=inspect_fulltop_final_timing_and_fix_rtl'
elif grep -q '^DC_SETUP status=WAIT' "$gate_tmp"; then
  compat_qor=$(latest_report "$compat_run" '*quick_map_low*qor*.rpt' || true)
  compat_timing=$(latest_report "$compat_run" '*quick_map_low*timing*.rpt' || true)
  if [[ -n "$compat_qor" && -n "$compat_timing" ]] &&
     grep -q 'slack (VIOLATED)' "$compat_timing"; then
    echo 'overall=WAIT action=wait_for_current_fulltop_postcompile_compat_quick_failed_prepare_compat_payload_dispatch_fix'
  else
    echo 'overall=WAIT action=wait_for_current_fulltop_postcompile_or_compat_quick_final_report'
  fi
else
  echo 'overall=UNKNOWN action=inspect_goal_gate_output'
fi
