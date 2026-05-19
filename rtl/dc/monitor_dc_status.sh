#!/usr/bin/env bash
set -uo pipefail

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$repo_root" || exit 1

interval_sec=${DC_MONITOR_INTERVAL_SEC:-1800}
log_file=${DC_MONITOR_LOG:-rtl/dc/dc_status_monitor.log}
latest_file=${DC_MONITOR_LATEST:-rtl/dc/dc_status_latest.txt}
lightweight=${DC_MONITOR_LIGHTWEIGHT:-0}

if [[ -n "${AXI_LLC_DC_ACTIVE_MARKERS:-}" ]]; then
  IFS=: read -r -a active_markers <<< "$AXI_LLC_DC_ACTIVE_MARKERS"
else
  active_markers=(
    rtl/dc/.latest_full_compile_1g
    rtl/dc/.latest_compat_low_probe
  )
fi

reference_markers=(
  rtl/dc/.reference_full_compile_1g_12h_direct_pop_predecode_clean
  rtl/dc/.reference_full_compile_1g_pre_hazard_summary
)

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

pgrep_children_on_host() {
  local host="$1"
  local pid="$2"
  if host_is_local "$host"; then
    pgrep -P "$pid" 2>/dev/null || true
  else
    ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" "pgrep -P '$pid' 2>/dev/null || true" 2>/dev/null || true
  fi
}

ps_pids_on_host() {
  local host="$1"
  local csv="$2"
  if host_is_local "$host"; then
    ps -p "$csv" -o pid,ppid,stat,etime,%cpu,%mem,rss,args 2>/dev/null
  else
    ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" \
      "ps -p '$csv' -o pid,ppid,stat,etime,%cpu,%mem,rss,args 2>/dev/null" 2>/dev/null
  fi
}

dump_run_processes() {
  local run="$1"
  local host
  local pids=()
  local launcher_pid=""

  host=$(metadata_host "$run")

  if [[ -f "$run/launcher.pid" ]]; then
    launcher_pid=$(tr -dc "0-9" < "$run/launcher.pid" || true)
    [[ -n "$launcher_pid" ]] && pids+=("$launcher_pid")
  fi

  if [[ -f "$run/run_metadata.txt" ]]; then
    while IFS= read -r meta_pid; do
      [[ -n "$meta_pid" ]] && pids+=("$meta_pid")
    done < <(awk -F= '/^(LAUNCHER_PID|TIMEOUT_PID|DC_PID)=/ {print $2}' "$run/run_metadata.txt" | tr -dc "0-9\n" || true)
  fi

  if [[ -n "$launcher_pid" ]]; then
    while IFS= read -r child_pid; do
      [[ -n "$child_pid" ]] && pids+=("$child_pid")
    done < <(pgrep_children_on_host "$host" "$launcher_pid")
  fi

  append_descendants() {
    local parent="$1"
    local child
    while IFS= read -r child; do
      [[ -n "$child" ]] || continue
      pids+=("$child")
      append_descendants "$child"
    done < <(pgrep_children_on_host "$host" "$parent")
  }

  local seed_pid
  local seed_pids=("${pids[@]}")
  for seed_pid in "${seed_pids[@]}"; do
    append_descendants "$seed_pid"
  done

  printf 'PROCESS\n'
  if [[ ${#pids[@]} -eq 0 ]]; then
    printf 'no_known_pid\n'
    return
  fi

  mapfile -t unique_pids < <(printf "%s\n" "${pids[@]}" | awk 'NF && !seen[$1]++')
  ps_pids_on_host "$host" "$(IFS=,; echo "${unique_pids[*]}")" || printf 'no_live_process_for_known_pids %s\n' "${unique_pids[*]}"
}

dump_run_artifacts() {
  local run="$1"

  if [[ -d "$run/reports" ]]; then
    printf 'REPORTS\n'
    find "$run/reports" -maxdepth 1 -type f -printf '%TY-%Tm-%Td %TH:%TM:%TS %s %f\n' 2>/dev/null | sort | tail -120
  fi

  if [[ -d "$run/outputs" ]]; then
    printf 'OUTPUTS\n'
    find "$run/outputs" -maxdepth 2 -type f -printf '%TY-%Tm-%Td %TH:%TM:%TS %s %P\n' 2>/dev/null | sort | tail -120
  fi
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

matching_timing_report() {
  local rpt="$1"
  local timing="${rpt/_qor.rpt/_timing.rpt}"
  if [[ "$timing" != "$rpt" && -f "$timing" ]]; then
    printf '%s\n' "$timing"
    return 0
  fi
  return 1
}

timing_report_has_setup_slack() {
  local rpt="$1"
  grep -Eq 'slack[[:space:]]+\(' "$rpt"
}

timing_report_has_no_violated_setup_slack() {
  local rpt="$1"
  ! grep -Eq 'slack[[:space:]]+\(VIOLATED\)' "$rpt"
}

dump_setup_gate() {
  local run="$1"
  local rpt_dir="$run/reports"
  local final_reports=()

  printf 'SETUP_GATE\n'
  if [[ ! -d "$rpt_dir" ]]; then
    printf 'status=WAIT reason=reports_dir_missing\n'
    return
  fi

  while IFS= read -r rpt; do
    [[ -n "$rpt" ]] && final_reports+=("$rpt")
  done < <(find "$rpt_dir" -maxdepth 1 -type f \( -name '*quick_map_low_qor.rpt' -o -name '*postcompile_1g_qor.rpt' \) | sort)

  if [[ ${#final_reports[@]} -eq 0 ]]; then
    printf 'status=WAIT reason=missing_final_qor\n'
    return
  fi

  local fail=0
  local rpt timing_rpt wns tns viol
  for rpt in "${final_reports[@]}"; do
    wns=$(extract_qor_number 'Critical Path Slack' "$rpt")
    tns=$(extract_qor_number 'Total Negative Slack' "$rpt")
    viol=$(extract_qor_number 'No. of Violating Paths' "$rpt")
    printf 'final_qor=%s wns=%s tns=%s violating_paths=%s\n' "$(basename "$rpt")" "${wns:-NA}" "${tns:-NA}" "${viol:-NA}"
    timing_rpt=$(matching_timing_report "$rpt" || true)
    if [[ -z "${timing_rpt:-}" ]]; then
      printf 'status=WAIT reason=missing_final_timing_for_%s\n' "$(basename "$rpt")"
      return
    fi
    if ! timing_report_has_setup_slack "$timing_rpt"; then
      printf 'status=FAIL reason=final_timing_parse_gap_for_%s\n' "$(basename "$timing_rpt")"
      return
    fi
    if ! timing_report_has_no_violated_setup_slack "$timing_rpt"; then
      printf 'status=FAIL reason=final_timing_has_violated_setup_path_for_%s\n' "$(basename "$timing_rpt")"
      return
    fi
    if [[ -z "${wns:-}" || -z "${tns:-}" || -z "${viol:-}" ]]; then
      fail=1
      continue
    fi
    if ! awk -v wns="$wns" -v tns="$tns" -v viol="$viol" 'BEGIN { exit !((wns + 0) >= 0 && (tns + 0) == 0 && (viol + 0) == 0) }'; then
      fail=1
    fi
  done

  if [[ "$fail" -eq 0 ]]; then
    printf 'status=PASS reason=all_final_qor_non_negative_setup\n'
  else
    printf 'status=FAIL reason=one_or_more_final_qor_has_setup_violation_or_parse_gap\n'
  fi
}

dump_macro_binding_summary() {
  local run="$1"
  local rpt_dir="$run/reports"
  local out_dir="$run/outputs"
  local data_macro="sassls0c4l1p4096x256m4b4w1c1p0d0t0s2sdz1rw00"
  local meta_macro="sassls0c4l1p4096x16m16b1w1c1p0d0t0s2sdz1rw00"

  printf 'MACRO_BINDING_SUMMARY\n'
  if [[ -f "$rpt_dir/link.rpt" ]]; then
    if grep -q "$data_macro.*\\.db" "$rpt_dir/link.rpt"; then
      printf 'data_macro_db_linked=yes macro=%s\n' "$data_macro"
    else
      printf 'data_macro_db_linked=no macro=%s\n' "$data_macro"
    fi
    if grep -q "$meta_macro.*\\.db" "$rpt_dir/link.rpt"; then
      printf 'meta_macro_db_linked=yes macro=%s\n' "$meta_macro"
    else
      printf 'meta_macro_db_linked=no macro=%s\n' "$meta_macro"
    fi
  else
    printf 'link_report_missing\n'
  fi

  if ! compgen -G "$out_dir/netlist/*.v" >/dev/null; then
    printf 'final_netlist_missing_or_not_yet_written\n'
    return
  fi

  local netlist data_count meta_count
  for netlist in "$out_dir"/netlist/*.v; do
    data_count=$(grep -c "$data_macro" "$netlist" || true)
    meta_count=$(grep -c "$meta_macro" "$netlist" || true)
    printf 'netlist=%s data_macro_refs=%s meta_macro_refs=%s\n' \
      "$(basename "$netlist")" "$data_count" "$meta_count"
  done
}

dump_library_binding_summary() {
  local run="$1"
  local rpt_dir="$run/reports"

  printf 'LIBRARY_BINDING_SUMMARY\n'
  if [[ ! -f "$rpt_dir/link.rpt" ]]; then
    printf 'link_report_missing\n'
    return
  fi

  if grep -Eiq 'scc12nsfe_90sdb_9tc20_rvt.*\.db' "$rpt_dir/link.rpt"; then
    printf 'stdcell_9t20_rvt_db_linked=yes\n'
  else
    printf 'stdcell_9t20_rvt_db_linked=no\n'
  fi
  if grep -Eiq 'scc12nsfe_90sdb_9tc20_lvt.*\.db' "$rpt_dir/link.rpt"; then
    printf 'stdcell_9t20_lvt_db_linked=yes\n'
  else
    printf 'stdcell_9t20_lvt_db_linked=no\n'
  fi
  if grep -Eiq '7p5|7p5tc|96sdb_7p5tc' "$rpt_dir/link.rpt"; then
    printf 'stdcell_7p5t_db_linked=yes\n'
  else
    printf 'stdcell_7p5t_db_linked=no\n'
  fi
}

dump_post_link_structural_hotspots() {
  local run="$1"
  local rpt="$run/reports/report_reference_post_link.rpt"

  printf 'POST_LINK_STRUCTURAL_HOTSPOTS\n'
  if [[ ! -f "$rpt" ]]; then
    printf 'report_reference_post_link_missing\n'
    return
  fi

  awk '/\*\*SEQGEN\*\*/ { printf "kind=SEQGEN count=%s op=%s\n", $3, $1 }' "$rpt"

  local hotspot_lines
  hotspot_lines=$(awk '
    function max_numeric_width(name, tmp, n, parts, i, value, max) {
      tmp = name
      gsub(/[^0-9]+/, " ", tmp)
      n = split(tmp, parts, /[[:space:]]+/)
      max = 0
      for (i = 1; i <= n; i++) {
        if (parts[i] == "") {
          continue
        }
        value = parts[i] + 0
        if (value > max) {
          max = value
        }
      }
      return max
    }
    /\*(MUX_OP|SELECT_OP)/ {
      name = $1
      count = $3 + 0
      width = max_numeric_width(name)
      if (width >= 512 || count >= 128) {
        printf "%09d %09d kind=generic_mux_select width=%d count=%d op=%s\n", width, count, width, count, name
      }
    }
  ' "$rpt" | sort -k1,1nr -k2,2nr | head -25 | \
    awk '{$1=""; $2=""; sub(/^[[:space:]]+/, ""); print $0}')
  if [[ -n "$hotspot_lines" ]]; then
    printf '%s\n' "$hotspot_lines"
  elif ! grep -q '\*\*SEQGEN\*\*' "$rpt"; then
    printf 'no_seqgen_or_large_mux_select_found\n'
  fi
}

dump_marker() {
  local marker="$1"
  local run
  local log_path
  if [[ -L "$marker" ]]; then
    run=$(readlink -f "$marker" 2>/dev/null || true)
  elif [[ -d "$marker" ]]; then
    run="$marker"
  else
    run=$(cat "$marker" 2>/dev/null || true)
  fi
  printf '\n%s -> %s\n' "$marker" "$run"
  if [[ -n "$run" && -f "$run/run_metadata.txt" ]]; then
    printf 'RUN_METADATA\n'
    cat "$run/run_metadata.txt"
  fi
  if [[ -n "$run" && -d "$run" ]]; then
    dump_run_processes "$run"
  fi
  log_path=""
  if [[ -n "$run" && -f "$run/launcher.log" ]]; then
    log_path="$run/launcher.log"
  elif [[ -n "$run" && -f "$run/launcher.direct.log" ]]; then
    log_path="$run/launcher.direct.log"
  fi
  if [[ -n "$log_path" ]]; then
    date -r "$log_path" '+LOG_MTIME %F %T %Z'
    dump_setup_gate "$run"
    dump_macro_binding_summary "$run"
    dump_library_binding_summary "$run"
    dump_post_link_structural_hotspots "$run"
    grep -E "DC_STAGE|LINK_SANITY|compile_start|compile_done|reports_done|quick_map_low_start|quick_map_low_done|quick_reports_done|Beginning Pass|Mapping Optimization|Delay Optimization|Area-Recovery|ELAPSED TIME|AREA +SLACK|Critical Path Slack|Total Negative Slack|No\\. of Violating Paths|Cell Area|Processing '|Error:|Fatal:|Received Signal" "$log_path" | tail -180 || true
    printf 'LOG_TAIL\n'
    tail -40 "$log_path" || true
    dump_run_artifacts "$run"
    if ls "$run"/reports/*_qor*.rpt >/dev/null 2>&1; then
      for rpt in "$run"/reports/*_qor*.rpt; do
        printf 'QOR %s\n' "$rpt"
        grep -E 'Critical Path Slack|Total Negative Slack|No\. of Violating Paths|Cell Area' "$rpt" || true
      done
    fi
    if ls "$run"/reports/*_timing*.rpt >/dev/null 2>&1; then
      for rpt in "$run"/reports/*_timing*.rpt; do
        printf 'TIMING %s\n' "$rpt"
        grep -E 'Startpoint:|Endpoint:|Path Group:|slack \(' "$rpt" | head -20 || true
      done
    fi
  fi
}

write_status() {
  local tmp_file="${latest_file}.$$"
  {
    printf '===== DC_STATUS %s =====\n' "$(date '+%F %T %Z')"
    printf '\nGOAL_GATE\n'
    if [[ -x rtl/dc/check_goal_gate.sh ]]; then
      rtl/dc/check_goal_gate.sh | grep -E '^(LLC_HIT|BOUNDED_NON_HIT|RTL_CONTRACTS|LINUX_SANITY|DC_SOURCE_FRESHNESS|DC_RUN_LIVENESS|DC_SETUP|DC_MACRO_BINDING|DC_LIBRARY_BINDING|BLOCKERS|GOAL) |^DC_SUMMARY (===== RUN|  RUN_KIND=|  TOP=|SETUP_GATE|SETUP_TREND|  status=|  qor=)'
    else
      printf 'GOAL status=WAIT reason=missing_check_goal_gate_script\n'
    fi
    if [[ "$lightweight" != "1" ]]; then
      printf '\nNEXT_ACTION\n'
      if [[ -x rtl/dc/decide_dc_next_action.sh ]]; then
        rtl/dc/decide_dc_next_action.sh | sed -n '1,220p'
      else
        printf 'overall=WAIT reason=missing_decide_dc_next_action_script\n'
      fi
      printf '\nLOG_HEALTH\n'
      if [[ -x rtl/dc/summarize_dc_log_health.sh ]]; then
        rtl/dc/summarize_dc_log_health.sh | sed -n '1,260p'
      else
        printf 'log_health=WAIT reason=missing_summarize_dc_log_health_script\n'
      fi
    fi
    printf '\nACTIVE_RUNS\n'
    for marker in "${active_markers[@]}"; do
      dump_marker "$marker"
    done
    if [[ "$lightweight" != "1" ]]; then
      printf '\nREFERENCE_RUNS_NOT_CURRENT\n'
      for marker in "${reference_markers[@]}"; do
        dump_marker "$marker"
      done
    fi
    if [[ "$lightweight" != "1" ]]; then
      printf '\nPIDS\n'
      ps -u "$USER" -o pid,ppid,stat,etime,%cpu,%mem,rss,args | \
        awk '/dc_shell|common_shell|timeout 14400|timeout 259200/ && !/awk/ {print}'
      printf '\nMEM\n'
      free -h
    fi
    printf '\n'
  } > "$tmp_file"
  mv "$tmp_file" "$latest_file"
  cat "$latest_file" >> "$log_file"
}

if [[ "${DC_MONITOR_ONCE:-0}" == "1" ]]; then
  write_status
  exit 0
fi

while :; do
  write_status
  sleep "$interval_sec"
done
