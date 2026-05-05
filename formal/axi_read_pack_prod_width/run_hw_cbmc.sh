#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
hw_cbmc="${HW_CBMC:-${repo_root}/../../hw-cbmc/src/hw-cbmc/hw-cbmc}"
timeout_sec="${HW_CBMC_TIMEOUT_SEC:-120}"

exec timeout "${timeout_sec}" "${hw_cbmc}" \
  "${script_dir}/harness.c" \
  "${repo_root}/rtl/src/axi_llc_axi_read_pack.v" \
  "${script_dir}/axi_read_pack_prod_width_formal_top.v" \
  --module axi_read_pack_prod_width_formal_top \
  --bound 1
