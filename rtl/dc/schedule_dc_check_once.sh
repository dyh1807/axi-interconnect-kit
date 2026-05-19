#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$repo_root"

delay_sec=${1:-${DC_MONITOR_DELAY_SEC:-1800}}
tag=${2:-$(date '+%Y%m%d_%H%M%S')}
log_file=${DC_MONITOR_SCHEDULE_LOG:-rtl/dc/dc_status_schedule.log}
pid_file=${DC_MONITOR_SCHEDULE_PID:-rtl/dc/dc_status_schedule.pid}

case "$delay_sec" in
  ''|*[!0-9]*)
    printf 'usage: %s [delay_seconds] [tag]\n' "$0" >&2
    exit 2
    ;;
esac

mkdir -p "$(dirname "$log_file")"

launcher=setsid
if ! command -v setsid >/dev/null 2>&1; then
  launcher=nohup
fi

"$launcher" bash -c '
  set -euo pipefail
  repo_root=$1
  delay_sec=$2
  tag=$3
  pid_file=$4
  printf "%s\n" "$$" > "$pid_file"
  cd "$repo_root"
  printf "SCHEDULED_CHECK_START tag=%s delay_sec=%s start=%s\n" \
    "$tag" "$delay_sec" "$(date "+%F %T %Z")"
  sleep "$delay_sec"
  printf "SCHEDULED_CHECK_RUN tag=%s run=%s\n" "$tag" "$(date "+%F %T %Z")"
  DC_MONITOR_ONCE=1 bash rtl/dc/monitor_dc_status.sh
  printf "SCHEDULED_CHECK_DONE tag=%s done=%s\n" "$tag" "$(date "+%F %T %Z")"
' _ "$repo_root" "$delay_sec" "$tag" "$pid_file" >> "$log_file" 2>&1 < /dev/null &

launcher_pid=$!
sleep 0.1
scheduled_pid=$(cat "$pid_file" 2>/dev/null || printf '%s' "$launcher_pid")
printf 'scheduled_pid=%s launcher_pid=%s delay_sec=%s log=%s\n' \
  "$scheduled_pid" "$launcher_pid" "$delay_sec" "$log_file"
