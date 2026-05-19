#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
hw_cbmc="${HW_CBMC:-${repo_root}/../../hw-cbmc/src/hw-cbmc/hw-cbmc}"
build_dir="${repo_root}/local_debug/hw_cbmc_cache_ctrl_invalidate_line_hit"
timeout_sec="${HW_CBMC_TIMEOUT_SEC:-120}"

mkdir -p "${build_dir}"

write_formal_params() {
  cat "${repo_root}/rtl/include/axi_llc_params.vh"
  printf '`undef AXI_LLC_LINE_BYTES\n'
  printf '`define AXI_LLC_LINE_BYTES 8\n'
  printf '`undef AXI_LLC_LINE_BITS\n'
  printf '`define AXI_LLC_LINE_BITS 64\n'
  printf '`undef AXI_LLC_LINE_OFFSET_BITS\n'
  printf '`define AXI_LLC_LINE_OFFSET_BITS 3\n'
  printf '`undef AXI_LLC_SET_COUNT\n'
  printf '`define AXI_LLC_SET_COUNT 2\n'
  printf '`undef AXI_LLC_SET_BITS\n'
  printf '`define AXI_LLC_SET_BITS 1\n'
  printf '`undef AXI_LLC_WAY_COUNT\n'
  printf '`define AXI_LLC_WAY_COUNT 2\n'
  printf '`undef AXI_LLC_WAY_BITS\n'
  printf '`define AXI_LLC_WAY_BITS 1\n'
  printf '`undef AXI_LLC_META_BITS\n'
  printf '`define AXI_LLC_META_BITS 29\n'
  printf '`undef AXI_LLC_READ_RESP_BYTES\n'
  printf '`define AXI_LLC_READ_RESP_BYTES 8\n'
  printf '`undef AXI_LLC_READ_RESP_BITS\n'
  printf '`define AXI_LLC_READ_RESP_BITS 64\n'
  printf '`undef AXI_LLC_MAX_OUTSTANDING\n'
  printf '`define AXI_LLC_MAX_OUTSTANDING 2\n'
}

{
  write_formal_params
  sed '/^`include "axi_llc_params.vh"/d' "${repo_root}/rtl/src/llc_cache_ctrl.v"
} > "${build_dir}/llc_cache_ctrl.pre.v"

exec timeout "${timeout_sec}" "${hw_cbmc}" \
  "${script_dir}/harness.c" \
  "${repo_root}/rtl/src/llc_mshr_pending_scan.v" \
  "${repo_root}/rtl/src/llc_mshr_select_scan.v" \
  "${repo_root}/rtl/src/llc_mshr_write_hit_scan.v" \
  "${build_dir}/llc_cache_ctrl.pre.v" \
  "${script_dir}/cache_ctrl_invalidate_line_hit_formal_top.v" \
  --module cache_ctrl_invalidate_line_hit_formal_top \
  --bound 16
