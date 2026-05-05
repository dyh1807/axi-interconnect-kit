#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"

export HW_CBMC_HARNESS="${script_dir}/harness.c"
export HW_CBMC_TOP_V="${script_dir}/axi_llc_subsystem_dual_cache_dirty_evict_post_b_hit_formal_top.v"
export HW_CBMC_TOP_MODULE="axi_llc_subsystem_dual_cache_dirty_evict_post_b_hit_formal_top"
export HW_CBMC_BOUND="${HW_CBMC_BOUND:-72}"
export HW_CBMC_TIMEOUT_SEC="${HW_CBMC_TIMEOUT_SEC:-480}"

exec "${repo_root}/formal/subsystem_dual_cache_dirty_evict_writeback/run_hw_cbmc.sh"
