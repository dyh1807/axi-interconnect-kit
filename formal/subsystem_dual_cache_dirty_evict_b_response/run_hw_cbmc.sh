#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"

export HW_CBMC_HARNESS="${script_dir}/harness.c"
export HW_CBMC_TIMEOUT_SEC="${HW_CBMC_TIMEOUT_SEC:-480}"

exec "${repo_root}/formal/subsystem_dual_cache_dirty_evict_writeback/run_hw_cbmc.sh"
