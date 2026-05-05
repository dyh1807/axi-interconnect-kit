#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
hw_cbmc="${HW_CBMC:-${repo_root}/../../hw-cbmc/src/hw-cbmc/hw-cbmc}"
build_dir="${repo_root}/local_debug/hw_cbmc_subsystem_core_dirty_evict_writeback"
timeout_sec="${HW_CBMC_TIMEOUT_SEC:-300}"

mkdir -p "${build_dir}"

write_formal_params() {
  cat "${repo_root}/rtl/include/axi_llc_params.vh"
  printf '`undef AXI_LLC_MODE_BITS\n'
  printf '`define AXI_LLC_MODE_BITS 3\n'
  printf '`undef AXI_LLC_SLOT_ID_BITS\n'
  printf '`define AXI_LLC_SLOT_ID_BITS 4\n'
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
  printf '`define AXI_LLC_META_BITS 8\n'
  printf '`undef AXI_LLC_LLC_SIZE_BYTES\n'
  printf '`define AXI_LLC_LLC_SIZE_BYTES 16\n'
  printf '`undef AXI_LLC_WINDOW_BYTES\n'
  printf '`define AXI_LLC_WINDOW_BYTES 8\n'
  printf '`undef AXI_LLC_WINDOW_WAYS\n'
  printf '`define AXI_LLC_WINDOW_WAYS 1\n'
  printf '`undef AXI_LLC_READ_RESP_BYTES\n'
  printf '`define AXI_LLC_READ_RESP_BYTES 8\n'
  printf '`undef AXI_LLC_READ_RESP_BITS\n'
  printf '`define AXI_LLC_READ_RESP_BITS 64\n'
  printf '`undef AXI_LLC_MAX_OUTSTANDING\n'
  printf '`define AXI_LLC_MAX_OUTSTANDING 2\n'
}

preprocess_with_params() {
  local src="$1"
  local dst="$2"
  {
    write_formal_params
    sed '/^`include "axi_llc_params.vh"/d' "${src}"
  } > "${dst}"
}

preprocess_with_params "${repo_root}/rtl/src/axi_reconfig_ctrl.v" \
  "${build_dir}/axi_reconfig_ctrl.pre.v"
preprocess_with_params "${repo_root}/rtl/src/llc_valid_ram.v" \
  "${build_dir}/llc_valid_ram.pre.v"
preprocess_with_params "${repo_root}/rtl/src/llc_repl_ram.v" \
  "${build_dir}/llc_repl_ram.pre.v"
preprocess_with_params "${repo_root}/rtl/src/llc_data_store_generic.v" \
  "${build_dir}/llc_data_store_generic.pre.v"
preprocess_with_params "${repo_root}/rtl/src/llc_meta_store_generic.v" \
  "${build_dir}/llc_meta_store_generic.pre.v"
preprocess_with_params "${repo_root}/rtl/src/llc_smic12_meta_4096x16_bw.v" \
  "${build_dir}/llc_smic12_meta_4096x16_bw.pre.v"
preprocess_with_params "${repo_root}/rtl/src/llc_data_store_smic12.v" \
  "${build_dir}/llc_data_store_smic12.pre.v"
preprocess_with_params "${repo_root}/rtl/src/llc_meta_store_smic12.v" \
  "${build_dir}/llc_meta_store_smic12.pre.v"
preprocess_with_params "${repo_root}/rtl/src/llc_data_store.v" \
  "${build_dir}/llc_data_store.pre.v"
preprocess_with_params "${repo_root}/rtl/src/llc_meta_store.v" \
  "${build_dir}/llc_meta_store.pre.v"
preprocess_with_params "${repo_root}/rtl/src/llc_invalidate_sweep.v" \
  "${build_dir}/llc_invalidate_sweep.pre.v"
preprocess_with_params "${repo_root}/rtl/src/llc_mapped_window_ctrl.v" \
  "${build_dir}/llc_mapped_window_ctrl.pre.v"
preprocess_with_params "${repo_root}/rtl/src/llc_cache_ctrl.v" \
  "${build_dir}/llc_cache_ctrl.pre.v"
preprocess_with_params "${repo_root}/rtl/src/axi_llc_subsystem_core.v" \
  "${build_dir}/axi_llc_subsystem_core.pre.v"

exec timeout "${timeout_sec}" "${hw_cbmc}" \
  "${script_dir}/harness.c" \
  "${build_dir}/axi_reconfig_ctrl.pre.v" \
  "${build_dir}/llc_valid_ram.pre.v" \
  "${build_dir}/llc_repl_ram.pre.v" \
  "${build_dir}/llc_data_store_generic.pre.v" \
  "${build_dir}/llc_meta_store_generic.pre.v" \
  "${repo_root}/rtl/src/llc_smic12_data_4096x256_sass_bw.v" \
  "${build_dir}/llc_smic12_meta_4096x16_bw.pre.v" \
  "${build_dir}/llc_data_store_smic12.pre.v" \
  "${build_dir}/llc_meta_store_smic12.pre.v" \
  "${build_dir}/llc_data_store.pre.v" \
  "${build_dir}/llc_meta_store.pre.v" \
  "${build_dir}/llc_invalidate_sweep.pre.v" \
  "${build_dir}/llc_mapped_window_ctrl.pre.v" \
  "${build_dir}/llc_cache_ctrl.pre.v" \
  "${build_dir}/axi_llc_subsystem_core.pre.v" \
  "${script_dir}/axi_llc_subsystem_core_dirty_evict_writeback_formal_top.v" \
  --module axi_llc_subsystem_core_dirty_evict_writeback_formal_top \
  --bound 112
