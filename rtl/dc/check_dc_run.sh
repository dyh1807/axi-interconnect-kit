#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: rtl/dc/check_dc_run.sh [--host HOST] [--pid PID] RUN_DIR

Print a read-only status summary for a DC run directory:
  - host time, memory pressure, launcher/DC process status
  - console log mtime and latest DC_STAGE markers
  - exit_code.txt if present
  - latest reports/outputs/checkpoints

RUN_DIR may be absolute or relative to the repository root.
USAGE
}

host=""
pid=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      host="$2"
      shift 2
      ;;
    --pid)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      pid="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

[[ $# -eq 1 ]] || { usage >&2; exit 2; }

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/../.." && pwd)
run_arg="$1"
if [[ "$run_arg" = /* ]]; then
  run_abs="$run_arg"
else
  run_abs="$repo_root/$run_arg"
fi

check_script='
set -euo pipefail
run="$1"
pid_arg="${2:-}"

echo "=== host ==="
hostname
date "+%F %T %Z"

echo "=== run ==="
echo "$run"
if [[ ! -d "$run" ]]; then
  echo "missing run directory"
  exit 1
fi

echo "=== metadata ==="
if [[ -f "$run/run_metadata.txt" ]]; then
  cat "$run/run_metadata.txt"
else
  echo "missing run_metadata.txt"
fi

echo "=== process ==="
pids=()
if [[ -n "$pid_arg" ]]; then
  pids+=("$pid_arg")
fi
if [[ -f "$run/launcher.pid" ]]; then
  launcher_pid=$(tr -dc "0-9" < "$run/launcher.pid" || true)
  if [[ -n "$launcher_pid" ]]; then
    pids+=("$launcher_pid")
    while IFS= read -r child; do
      [[ -n "$child" ]] && pids+=("$child")
    done < <(pgrep -P "$launcher_pid" 2>/dev/null || true)
  fi
fi
if [[ -f "$run/run_metadata.txt" ]]; then
  while IFS= read -r meta_pid; do
    [[ -n "$meta_pid" ]] && pids+=("$meta_pid")
  done < <(awk -F= "/^(DC_PID|LAUNCHER_PID)=/ {print \$2}" "$run/run_metadata.txt" | tr -dc "0-9\n" || true)
fi

if [[ ${#pids[@]} -eq 0 ]]; then
  echo "no pid known"
else
  mapfile -t uniq_pids < <(printf "%s\n" "${pids[@]}" | awk "NF && !seen[\$1]++")
  ps -p "$(IFS=,; echo "${uniq_pids[*]}")" -o user,pid,ppid,stat,etime,pcpu,rss,pmem,cmd || true
fi

echo "=== memory ==="
free -h || true

log="$run/full_compile_1g.console.log"
echo "=== log ==="
log=""
for candidate in \
  "$run/launcher.log" \
  "$run/launcher.direct.log" \
  "$run/full_compile_1g.console.log"; do
  if [[ -f "$candidate" ]]; then
    log="$candidate"
    break
  fi
done
if [[ -n "$log" ]]; then
  stat -c "%y %s %n" "$log"
  echo "--- latest stages/warnings/errors ---"
  grep -E "DC_STAGE|LINK_SANITY|compile_start|compile_done|quick_map_low_start|quick_map_low_done|reports_start|reports_done|quick_reports_start|quick_reports_done|write_start|write_done|Beginning Pass|Mapping Optimization|Delay Optimization|AREA +SLACK|Critical Path Slack|Total Negative Slack|No\\. of Violating Paths|Cell Area|Out of memory|Error:|Fatal:|Warning:|Received Signal" "$log" | tail -n 120 || true
  echo "--- tail ---"
  tail -n 30 "$log" || true
else
  echo "missing launcher.log / launcher.direct.log / full_compile_1g.console.log"
fi

echo "=== exit ==="
if [[ -f "$run/exit_code.txt" ]]; then
  cat "$run/exit_code.txt"
else
  echo "running_or_no_exit_code"
fi

echo "=== latest reports/outputs ==="
find "$run" -maxdepth 3 -type f \
  \( -path "*/reports/*" -o -path "*/outputs/*" -o -name "exit_code.txt" \) \
  -printf "%TY-%Tm-%Td %TH:%TM %s %p\n" 2>/dev/null | sort | tail -n 80 || true

echo "=== qor summary ==="
if compgen -G "$run/reports/*_qor*.rpt" >/dev/null; then
  for rpt in "$run"/reports/*_qor*.rpt; do
    echo "--- $rpt ---"
    grep -E "Critical Path Slack|Total Negative Slack|No\\. of Violating Paths|Cell Area" "$rpt" || true
  done
else
  echo "no qor reports"
fi

echo "=== worst timing summary ==="
if compgen -G "$run/reports/*_timing*.rpt" >/dev/null; then
  for rpt in "$run"/reports/*_timing*.rpt; do
    echo "--- $rpt ---"
    grep -E "Startpoint:|Endpoint:|Path Group:|slack \\(" "$rpt" | head -20 || true
  done
else
  echo "no timing reports"
fi
'

if [[ -n "$host" ]]; then
  ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" 'bash -s' -- "$run_abs" "$pid" <<<"$check_script"
else
  bash -s -- "$run_abs" "$pid" <<<"$check_script"
fi
