#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
hw_cbmc="${HW_CBMC:-${repo_root}/../../hw-cbmc/src/hw-cbmc/hw-cbmc}"
timeout_sec="${HW_CBMC_TIMEOUT_SEC:-60}"

exec timeout "${timeout_sec}" "${hw_cbmc}" \
  "${script_dir}/harness.c" \
  "${repo_root}/rtl/src/axi_llc_axi_mode2_shape.v" \
  "${repo_root}/rtl/src/axi_llc_axi_issue_select.v" \
  "${script_dir}/axi_issue_select_formal_top.v" \
  --module axi_issue_select_formal_top \
  --bound 1
