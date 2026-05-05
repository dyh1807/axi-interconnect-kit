#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
hw_cbmc="${HW_CBMC:-${repo_root}/../../hw-cbmc/src/hw-cbmc/hw-cbmc}"
build_dir="${repo_root}/local_debug/hw_cbmc_subsystem_dual_ddr_write_mmio_read_independent"
timeout_sec="${HW_CBMC_TIMEOUT_SEC:-180}"

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
  printf '`undef AXI_LLC_AXI_DATA_BYTES\n'
  printf '`define AXI_LLC_AXI_DATA_BYTES 8\n'
  printf '`undef AXI_LLC_AXI_DATA_BITS\n'
  printf '`define AXI_LLC_AXI_DATA_BITS 64\n'
  printf '`undef AXI_LLC_AXI_STRB_BITS\n'
  printf '`define AXI_LLC_AXI_STRB_BITS 8\n'
  printf '`undef AXI_LLC_AXI_ID_BITS\n'
  printf '`define AXI_LLC_AXI_ID_BITS 1\n'
  printf '`undef AXI_LLC_READ_RESP_BYTES\n'
  printf '`define AXI_LLC_READ_RESP_BYTES 8\n'
  printf '`undef AXI_LLC_READ_RESP_BITS\n'
  printf '`define AXI_LLC_READ_RESP_BITS 64\n'
  printf '`undef AXI_LLC_MAX_OUTSTANDING\n'
  printf '`define AXI_LLC_MAX_OUTSTANDING 2\n'
  printf '`undef AXI_LLC_MAX_READ_OUTSTANDING_PER_MASTER\n'
  printf '`define AXI_LLC_MAX_READ_OUTSTANDING_PER_MASTER 2\n'
  printf '`undef AXI_LLC_MAX_WRITE_OUTSTANDING\n'
  printf '`define AXI_LLC_MAX_WRITE_OUTSTANDING 2\n'
  printf '`undef AXI_LLC_BRIDGE_READ_PENDING_COUNT\n'
  printf '`define AXI_LLC_BRIDGE_READ_PENDING_COUNT 1\n'
  printf '`undef AXI_LLC_BRIDGE_WRITE_PENDING_COUNT\n'
  printf '`define AXI_LLC_BRIDGE_WRITE_PENDING_COUNT 1\n'
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
preprocess_with_params "${repo_root}/rtl/src/axi_llc_subsystem_compat.v" \
  "${build_dir}/axi_llc_subsystem_compat.pre.v"
preprocess_with_params "${repo_root}/rtl/src/axi_llc_axi_bridge.v" \
  "${build_dir}/axi_llc_axi_bridge.pre.v"
preprocess_with_params "${repo_root}/rtl/src/axi_llc_axi_bridge_dual.v" \
  "${build_dir}/axi_llc_axi_bridge_dual.pre.v"
preprocess_with_params "${repo_root}/rtl/src/axi_llc_subsystem_dual.v" \
  "${build_dir}/axi_llc_subsystem_dual.pre.v"

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
  "${build_dir}/axi_llc_subsystem_compat.pre.v" \
  "${repo_root}/rtl/src/axi_llc_axi_beat_shape.v" \
  "${repo_root}/rtl/src/axi_llc_axi_mode2_shape.v" \
  "${repo_root}/rtl/src/axi_llc_axi_fifo_ptr.v" \
  "${repo_root}/rtl/src/axi_llc_axi_queue_ctrl.v" \
  "${repo_root}/rtl/src/axi_llc_axi_write_pack.v" \
  "${repo_root}/rtl/src/axi_llc_axi_read_pack.v" \
  "${repo_root}/rtl/src/axi_llc_axi_read_resp_ctrl.v" \
  "${repo_root}/rtl/src/axi_llc_axi_id_shape.v" \
  "${repo_root}/rtl/src/axi_llc_axi_pending_scan.v" \
  "${repo_root}/rtl/src/axi_llc_axi_issue_select.v" \
  "${repo_root}/rtl/src/axi_llc_axi_req_accept.v" \
  "${repo_root}/rtl/src/axi_llc_axi_resp_accept.v" \
  "${repo_root}/rtl/src/axi_llc_axi_resp_route.v" \
  "${repo_root}/rtl/src/axi_llc_axi_source_resp_mux.v" \
  "${build_dir}/axi_llc_axi_bridge.pre.v" \
  "${repo_root}/rtl/src/axi_llc_dual_port_route_shape.v" \
  "${repo_root}/rtl/src/axi_llc_dual_port_req_steer.v" \
  "${repo_root}/rtl/src/axi_llc_dual_port_issue_gate.v" \
  "${repo_root}/rtl/src/axi_llc_dual_port_hazard_match.v" \
  "${repo_root}/rtl/src/axi_llc_dual_port_slot_hazard.v" \
  "${repo_root}/rtl/src/axi_llc_dual_port_hazard_scoreboard.v" \
  "${repo_root}/rtl/src/axi_llc_dual_port_resp_mux.v" \
  "${build_dir}/axi_llc_axi_bridge_dual.pre.v" \
  "${build_dir}/axi_llc_subsystem_dual.pre.v" \
  "${script_dir}/axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top.v" \
  --module axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top \
  --bound 48
