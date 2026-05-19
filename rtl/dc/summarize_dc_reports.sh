#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: rtl/dc/summarize_dc_reports.sh [RUN_DIR_OR_MARKER ...]

Summarize DC evidence from run directories or marker files. With no arguments,
summarizes the current active markers:
  rtl/dc/.latest_full_compile_1g
  rtl/dc/.latest_compat_low_probe
  rtl/dc/.reference_full_compile_1g_12h_direct_pop_predecode_clean

This script is read-only. It does not invoke Synopsys tools.
USAGE
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/../.." && pwd)

default_markers=(
  rtl/dc/.latest_full_compile_1g
  rtl/dc/.latest_compat_low_probe
  rtl/dc/.reference_full_compile_1g_12h_direct_pop_predecode_clean
)

resolve_run() {
  local arg="$1"
  local path="$arg"
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

print_processes() {
  local run="$1"
  local host
  local pids=()

  host=$(metadata_host "$run")

  if [[ -f "$run/run_metadata.txt" ]]; then
    while IFS= read -r pid; do
      [[ -n "$pid" ]] && pids+=("$pid")
    done < <(awk -F= '/^(LAUNCHER_PID|TIMEOUT_PID|DC_PID)=/ {print $2}' "$run/run_metadata.txt" | tr -dc '0-9\n' || true)
  fi
  if [[ -f "$run/launcher.pid" ]]; then
    local launcher_pid
    launcher_pid=$(tr -dc '0-9' < "$run/launcher.pid" || true)
    [[ -n "$launcher_pid" ]] && pids+=("$launcher_pid")
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
    printf '  no_known_pid\n'
    return
  fi

  mapfile -t unique_pids < <(printf '%s\n' "${pids[@]}" | awk 'NF && !seen[$1]++')
  ps_pids_on_host "$host" "$(IFS=,; echo "${unique_pids[*]}")" || \
    printf '  no_live_process_for_known_pids %s\n' "${unique_pids[*]}"
}

print_report_presence() {
  local run="$1"
  local rpt_dir="$run/reports"

  printf 'REPORT_PRESENCE\n'
  if [[ ! -d "$rpt_dir" ]]; then
    printf '  reports_dir_missing\n'
    return
  fi

  local quick_qor_count quick_timing_count post_qor_count post_timing_count pre_qor_count pre_timing_count
  quick_qor_count=$(find "$rpt_dir" -maxdepth 1 -type f -name '*quick_map_low_qor.rpt' | wc -l)
  quick_timing_count=$(find "$rpt_dir" -maxdepth 1 -type f -name '*quick_map_low_timing.rpt' | wc -l)
  post_qor_count=$(find "$rpt_dir" -maxdepth 1 -type f -name '*postcompile_1g_qor.rpt' | wc -l)
  post_timing_count=$(find "$rpt_dir" -maxdepth 1 -type f -name '*postcompile_1g_timing.rpt' | wc -l)
  pre_qor_count=$(find "$rpt_dir" -maxdepth 1 -type f -name '*qor_precompile.rpt' | wc -l)
  pre_timing_count=$(find "$rpt_dir" -maxdepth 1 -type f -name '*timing_precompile.rpt' | wc -l)

  printf '  quick_map_low_qor=%s quick_map_low_timing=%s\n' "$quick_qor_count" "$quick_timing_count"
  printf '  postcompile_1g_qor=%s postcompile_1g_timing=%s\n' "$post_qor_count" "$post_timing_count"
  printf '  precompile_qor=%s precompile_timing=%s\n' "$pre_qor_count" "$pre_timing_count"
  if [[ "$quick_qor_count" -gt 0 || "$post_qor_count" -gt 0 ]]; then
    printf '  final_qor_available=yes\n'
  else
    printf '  final_qor_available=no\n'
  fi
  if [[ "$quick_timing_count" -gt 0 || "$post_timing_count" -gt 0 ]]; then
    printf '  final_timing_available=yes\n'
  else
    printf '  final_timing_available=no\n'
  fi
}

print_qor_summary() {
  local run="$1"
  local rpt_dir="$run/reports"

  printf 'QOR_SUMMARY\n'
  if ! compgen -G "$rpt_dir/*_qor*.rpt" >/dev/null; then
    printf '  no_qor_reports\n'
    return
  fi

  local rpt
  for rpt in "$rpt_dir"/*_qor*.rpt; do
    printf '  %s\n' "$(basename "$rpt")"
    grep -E 'Critical Path Slack|Total Negative Slack|No\. of Violating Paths|Cell Area' "$rpt" | sed 's/^/    /' || true
  done
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

print_setup_gate() {
  local run="$1"
  local rpt_dir="$run/reports"
  local final_reports=()

  printf 'SETUP_GATE\n'
  if [[ ! -d "$rpt_dir" ]]; then
    printf '  status=WAIT reason=reports_dir_missing\n'
    return
  fi

  while IFS= read -r rpt; do
    [[ -n "$rpt" ]] && final_reports+=("$rpt")
  done < <(find "$rpt_dir" -maxdepth 1 -type f \( -name '*quick_map_low_qor.rpt' -o -name '*postcompile_1g_qor.rpt' \) | sort)

  if [[ ${#final_reports[@]} -eq 0 ]]; then
    printf '  status=WAIT reason=missing_final_qor\n'
    return
  fi

  local fail=0
  local rpt timing_rpt wns tns viol
  for rpt in "${final_reports[@]}"; do
    wns=$(extract_qor_number 'Critical Path Slack' "$rpt")
    tns=$(extract_qor_number 'Total Negative Slack' "$rpt")
    viol=$(extract_qor_number 'No. of Violating Paths' "$rpt")
    printf '  final_qor=%s wns=%s tns=%s violating_paths=%s\n' "$(basename "$rpt")" "${wns:-NA}" "${tns:-NA}" "${viol:-NA}"
    timing_rpt=$(matching_timing_report "$rpt" || true)
    if [[ -z "${timing_rpt:-}" ]]; then
      printf '  status=WAIT reason=missing_final_timing_for_%s\n' "$(basename "$rpt")"
      return
    fi
    if ! timing_report_has_setup_slack "$timing_rpt"; then
      printf '  status=FAIL reason=final_timing_parse_gap_for_%s\n' "$(basename "$timing_rpt")"
      return
    fi
    if ! timing_report_has_no_violated_setup_slack "$timing_rpt"; then
      printf '  status=FAIL reason=final_timing_has_violated_setup_path_for_%s\n' "$(basename "$timing_rpt")"
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
    printf '  status=PASS reason=all_final_qor_non_negative_setup\n'
  else
    printf '  status=FAIL reason=one_or_more_final_qor_has_setup_violation_or_parse_gap\n'
  fi
}

print_setup_trend() {
  local run="$1"
  local rpt_dir="$run/reports"
  local reports=()

  printf 'SETUP_TREND\n'
  if [[ ! -d "$rpt_dir" ]]; then
    printf '  no_reports_dir\n'
    return
  fi

  while IFS= read -r rpt; do
    [[ -n "$rpt" ]] && reports+=("$rpt")
  done < <(find "$rpt_dir" -maxdepth 1 -type f \( -name '*quick_map_low_qor.rpt' -o -name '*postcompile_1g_qor.rpt' -o -name '*qor_precompile.rpt' \) | sort)

  if [[ ${#reports[@]} -eq 0 ]]; then
    printf '  no_qor_reports\n'
    return
  fi

  local rpt kind wns tns viol area note
  for rpt in "${reports[@]}"; do
    case "$(basename "$rpt")" in
      *quick_map_low_qor.rpt|*postcompile_1g_qor.rpt)
        kind=final
        note=counts_for_setup_gate
        ;;
      *qor_precompile.rpt)
        kind=precompile
        note=trend_only_not_final
        ;;
      *)
        kind=unknown
        note=not_used_for_gate
        ;;
    esac
    wns=$(extract_qor_number 'Critical Path Slack' "$rpt")
    tns=$(extract_qor_number 'Total Negative Slack' "$rpt")
    viol=$(extract_qor_number 'No. of Violating Paths' "$rpt")
    area=$(extract_qor_number 'Cell Area' "$rpt")
    if [[ -z "${wns:-}" || -z "${tns:-}" || -z "${viol:-}" || -z "${area:-}" ]]; then
      if [[ "$kind" == "precompile" ]]; then
        note=incomplete_or_in_progress_precompile_not_final
      else
        note=incomplete_or_parse_gap
      fi
    fi
    printf '  qor=%s kind=%s wns=%s tns=%s violating_paths=%s cell_area=%s note=%s\n' \
      "$(basename "$rpt")" "$kind" "${wns:-NA}" "${tns:-NA}" "${viol:-NA}" "${area:-NA}" "$note"
  done
}

print_timing_summary() {
  local run="$1"
  local rpt_dir="$run/reports"

  printf 'TIMING_SUMMARY\n'
  if ! compgen -G "$rpt_dir/*_timing*.rpt" >/dev/null; then
    printf '  no_timing_reports\n'
    return
  fi

  local rpt
  for rpt in "$rpt_dir"/*_timing*.rpt; do
    printf '  %s\n' "$(basename "$rpt")"
    grep -E 'Startpoint:|Endpoint:|Path Group:|slack \(' "$rpt" | head -20 | sed 's/^/    /' || true
  done
}

print_endpoint_hotspots() {
  local run="$1"
  local rpt_dir="$run/reports"
  local timing_reports=()

  printf 'ENDPOINT_HOTSPOTS\n'
  if [[ ! -d "$rpt_dir" ]]; then
    printf '  reports_dir_missing\n'
    return
  fi

  while IFS= read -r rpt; do
    [[ -n "$rpt" ]] && timing_reports+=("$rpt")
  done < <(find "$rpt_dir" -maxdepth 1 -type f \( -name '*quick_map_low_timing*.rpt' -o -name '*postcompile_1g_timing*.rpt' \) | sort)

  if [[ ${#timing_reports[@]} -eq 0 ]]; then
    printf '  no_final_timing_reports\n'
    return
  fi

  local rpt
  for rpt in "${timing_reports[@]}"; do
    printf '  %s\n' "$(basename "$rpt")"
    awk '
      /Endpoint:/ {
        ep = $0
        sub(/^.*Endpoint:[[:space:]]*/, "", ep)
        sub(/[[:space:]].*$/, "", ep)
        bucket = ep
        sub(/\/.*/, "", bucket)
        if (bucket == "") {
          bucket = "unknown"
        }
        count[bucket]++
      }
      END {
        for (bucket in count) {
          printf "%d %s\n", count[bucket], bucket
        }
      }
    ' "$rpt" | sort -nr | head -10 | sed 's/^/    /'
  done
}

print_timing_path_categories() {
  local run="$1"
  local rpt_dir="$run/reports"
  local timing_reports=()

  printf 'TIMING_PATH_CATEGORIES\n'
  if [[ ! -d "$rpt_dir" ]]; then
    printf '  reports_dir_missing\n'
    return
  fi

  while IFS= read -r rpt; do
    [[ -n "$rpt" ]] && timing_reports+=("$rpt")
  done < <(find "$rpt_dir" -maxdepth 1 -type f \( -name '*quick_map_low_timing*.rpt' -o -name '*postcompile_1g_timing*.rpt' \) | sort)

  if [[ ${#timing_reports[@]} -eq 0 ]]; then
    printf '  no_final_timing_reports\n'
    return
  fi

  local rpt
  for rpt in "${timing_reports[@]}"; do
    printf '  %s\n' "$(basename "$rpt")"
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
          print "    no_violated_paths_found"
          exit
        }
        for (key in count) {
          printf "    category=%s count=%d sample=%s\n", key, count[key], sample[key]
        }
      }
    ' "$rpt" | sort
  done
}

print_post_link_structural_hotspots() {
  local run="$1"
  local rpt="$run/reports/report_reference_post_link.rpt"

  printf 'POST_LINK_STRUCTURAL_HOTSPOTS\n'
  if [[ ! -f "$rpt" ]]; then
    printf '  report_reference_post_link_missing\n'
    return
  fi

  awk '/\*\*SEQGEN\*\*/ { printf "  kind=SEQGEN count=%s op=%s\n", $3, $1 }' "$rpt"

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
    awk '{$1=""; $2=""; sub(/^[[:space:]]+/, ""); print "  " $0}')
  if [[ -n "$hotspot_lines" ]]; then
    printf '%s\n' "$hotspot_lines"
  elif ! grep -q '\*\*SEQGEN\*\*' "$rpt"; then
    printf '  no_seqgen_or_large_mux_select_found\n'
  fi
}

print_output_summary() {
  local run="$1"
  local out_dir="$run/outputs"

  printf 'OUTPUT_SUMMARY\n'
  if [[ ! -d "$out_dir" ]]; then
    printf '  outputs_dir_missing\n'
    return
  fi
  for sub in ddc netlist sdc sdf spf db; do
    if [[ -d "$out_dir/$sub" ]]; then
      local count
      count=$(find "$out_dir/$sub" -maxdepth 1 -type f | wc -l)
      printf '  %s_files=%s\n' "$sub" "$count"
      find "$out_dir/$sub" -maxdepth 1 -type f -printf '    %TY-%Tm-%Td %TH:%TM:%TS %s %f\n' 2>/dev/null | sort | tail -5
    else
      printf '  %s_files=0\n' "$sub"
    fi
  done
}

print_macro_binding_summary() {
  local run="$1"
  local rpt_dir="$run/reports"
  local out_dir="$run/outputs"
  local data_macro="sassls0c4l1p4096x256m4b4w1c1p0d0t0s2sdz1rw00"
  local meta_macro="sassls0c4l1p4096x16m16b1w1c1p0d0t0s2sdz1rw00"

  printf 'MACRO_BINDING_SUMMARY\n'
  if [[ -f "$rpt_dir/link.rpt" ]]; then
    if grep -q "$data_macro.*\\.db" "$rpt_dir/link.rpt"; then
      printf '  data_macro_db_linked=yes macro=%s\n' "$data_macro"
    else
      printf '  data_macro_db_linked=no macro=%s\n' "$data_macro"
    fi
    if grep -q "$meta_macro.*\\.db" "$rpt_dir/link.rpt"; then
      printf '  meta_macro_db_linked=yes macro=%s\n' "$meta_macro"
    else
      printf '  meta_macro_db_linked=no macro=%s\n' "$meta_macro"
    fi
  else
    printf '  link_report_missing\n'
  fi

  if ! compgen -G "$out_dir/netlist/*.v" >/dev/null; then
    printf '  final_netlist_missing_or_not_yet_written\n'
    return
  fi

  local netlist data_count meta_count
  for netlist in "$out_dir"/netlist/*.v; do
    data_count=$(grep -c "$data_macro" "$netlist" || true)
    meta_count=$(grep -c "$meta_macro" "$netlist" || true)
    printf '  netlist=%s data_macro_refs=%s meta_macro_refs=%s\n' \
      "$(basename "$netlist")" "$data_count" "$meta_count"
  done
}

print_library_binding_summary() {
  local run="$1"
  local rpt_dir="$run/reports"

  printf 'LIBRARY_BINDING_SUMMARY\n'
  if [[ ! -f "$rpt_dir/link.rpt" ]]; then
    printf '  link_report_missing\n'
    return
  fi

  if grep -Eiq 'scc12nsfe_90sdb_9tc20_rvt.*\.db' "$rpt_dir/link.rpt"; then
    printf '  stdcell_9t20_rvt_db_linked=yes\n'
  else
    printf '  stdcell_9t20_rvt_db_linked=no\n'
  fi
  if grep -Eiq 'scc12nsfe_90sdb_9tc20_lvt.*\.db' "$rpt_dir/link.rpt"; then
    printf '  stdcell_9t20_lvt_db_linked=yes\n'
  else
    printf '  stdcell_9t20_lvt_db_linked=no\n'
  fi
  if grep -Eiq '7p5|7p5tc|96sdb_7p5tc' "$rpt_dir/link.rpt"; then
    printf '  stdcell_7p5t_db_linked=yes\n'
  else
    printf '  stdcell_7p5t_db_linked=no\n'
  fi
}

summarize_run() {
  local run="$1"
  printf '\n===== RUN %s =====\n' "$run"
  if [[ ! -d "$run" ]]; then
    printf 'missing_run_dir\n'
    return
  fi

  if [[ -f "$run/run_metadata.txt" ]]; then
    printf 'RUN_METADATA\n'
    sed 's/^/  /' "$run/run_metadata.txt"
  else
    printf 'RUN_METADATA missing\n'
  fi

  print_processes "$run"
  print_report_presence "$run"
  print_qor_summary "$run"
  print_setup_gate "$run"
  print_setup_trend "$run"
  print_timing_summary "$run"
  print_endpoint_hotspots "$run"
  print_timing_path_categories "$run"
  print_post_link_structural_hotspots "$run"
  print_macro_binding_summary "$run"
  print_library_binding_summary "$run"
  print_output_summary "$run"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

args=("$@")
if [[ ${#args[@]} -eq 0 ]]; then
  args=("${default_markers[@]}")
fi

printf 'DC_REPORT_SUMMARY %s\n' "$(date '+%F %T %Z')"
for arg in "${args[@]}"; do
  run=$(resolve_run "$arg") || {
    printf '\n===== RUN %s =====\nmissing_or_empty_marker\n' "$arg"
    continue
  }
  summarize_run "$run"
done
