#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: rtl/dc/summarize_dc_log_health.sh [RUN_DIR_OR_MARKER ...]

Read-only DC launcher-log health summary. With no arguments, summarizes:
  rtl/dc/.latest_full_compile_1g
  rtl/dc/.latest_compat_low_probe
  rtl/dc/.reference_full_compile_1g_12h_direct_pop_predecode_clean

The script does not invoke Synopsys tools and does not modify run artifacts.
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

print_stage_tail() {
  local log="$1"
  printf 'STAGE_TAIL\n'
  grep -E \
    'DC_STAGE|LINK_SANITY|SRAM_HIERARCHY|compile_start|compile_done|reports_start|reports_done|quick_map_low_start|quick_map_low_done|quick_reports_start|quick_reports_done|Beginning |Mapping Optimization|Delay Optimization|Area-Recovery|Leakage Power|Design Rule Fixing|WLM Backend Optimization' \
    "$log" 2>/dev/null | tail -40 | sed 's/^/  /' || printf '  no_stage_markers\n'
}

print_error_summary() {
  local log="$1"
  printf 'ERROR_FATAL_SUMMARY\n'
  awk '
    /(^|[[:space:]])(Error|Fatal):/ {count++}
    /Out of memory|Received Signal|segmentation violation|Internal system error/ {count++}
    END {printf "  count=%d\n", count + 0}
  ' "$log"
  grep -Ei '(^|[[:space:]])(Error|Fatal):|Out of memory|Received Signal|segmentation violation|Internal system error' \
    "$log" 2>/dev/null | tail -20 | sed 's/^/  /' || true
}

print_warning_summary() {
  local log="$1"
  local lines
  printf 'WARNING_CODE_SUMMARY\n'
  lines=$(awk '
    /Warning:/ {
      code = "NO_CODE"
      if (match($0, /\([A-Z0-9]+-[0-9]+\)/)) {
        code = substr($0, RSTART + 1, RLENGTH - 2)
      }
      count[code]++
      if (!(code in sample)) {
        sample[code] = $0
      }
    }
    END {
      for (code in count) {
        printf "%09d %s %s\n", count[code], code, sample[code]
      }
    }
  ' "$log" | sort -nr | head -40 | \
    awk '{$1=$1+0; printf "  count=%s code=%s sample=", $1, $2; $1=""; $2=""; sub(/^[[:space:]]+/, ""); print}')
  if [[ -n "$lines" ]]; then
    printf '%s\n' "$lines"
  else
    printf '  none\n'
  fi
}

print_constant_removal_summary() {
  local log="$1"
  local lines
  printf 'CONSTANT_REGISTER_REMOVAL_SUMMARY\n'
  lines=$(awk '
    /is a constant and will be removed/ {
      split($0, parts, "'\''")
      name = parts[2]
      if (name == "") {
        name = "UNKNOWN"
      }
      gsub(/\[[^]]*\]/, "", name)
      count[name]++
      if (!(name in sample)) {
        sample[name] = parts[2]
      }
    }
    END {
      for (name in count) {
        printf "%09d %s %s\n", count[name], name, sample[name]
      }
    }
  ' "$log" | sort -nr | head -40 | \
    awk '{$1=$1+0; printf "  count=%s reg=%s sample=", $1, $2; $1=""; $2=""; sub(/^[[:space:]]+/, ""); print}')
  if [[ -n "$lines" ]]; then
    printf '%s\n' "$lines"
  else
    printf '  none\n'
  fi
}

print_run() {
  local run="$1"
  local log="$run/launcher.log"
  printf '\n===== RUN %s =====\n' "$run"
  if [[ ! -d "$run" ]]; then
    printf 'missing_run_dir\n'
    return
  fi
  if [[ ! -f "$log" ]]; then
    printf 'missing_launcher_log\n'
    return
  fi
  printf 'LOG_INFO\n'
  stat -c '  mtime=%y size=%s path=%n' "$log"
  if [[ -f "$run/exit_code.txt" ]]; then
    printf '  exit_code=%s\n' "$(tr -dc '0-9' < "$run/exit_code.txt")"
  else
    printf '  exit_code=running_or_not_written\n'
  fi
  print_stage_tail "$log"
  print_error_summary "$log"
  print_warning_summary "$log"
  print_constant_removal_summary "$log"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

args=("$@")
if [[ ${#args[@]} -eq 0 ]]; then
  args=("${default_markers[@]}")
fi

printf 'DC_LOG_HEALTH_SUMMARY %s\n' "$(date '+%F %T %Z')"
for arg in "${args[@]}"; do
  run=$(resolve_run "$arg") || {
    printf '\n===== RUN %s =====\nmissing_or_empty_marker\n' "$arg"
    continue
  }
  print_run "$run"
done
