#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
hw_cbmc="${HW_CBMC:-${repo_root}/../../hw-cbmc/src/hw-cbmc/hw-cbmc}"
build_dir="${repo_root}/local_debug/hw_cbmc_dual_bridge_mode2_aligned_read"
timeout_sec="${HW_CBMC_TIMEOUT_SEC:-180}"

mkdir -p "${build_dir}"

{
  printf '`define AXI_LLC_BRIDGE_READ_PENDING_COUNT 1\n'
  printf '`define AXI_LLC_BRIDGE_WRITE_PENDING_COUNT 1\n'
  cat "${repo_root}/rtl/include/axi_llc_params.vh"
  printf '`undef AXI_LLC_LINE_BYTES\n'
  printf '`define AXI_LLC_LINE_BYTES 8\n'
  printf '`undef AXI_LLC_LINE_BITS\n'
  printf '`define AXI_LLC_LINE_BITS 64\n'
  printf '`undef AXI_LLC_LINE_OFFSET_BITS\n'
  printf '`define AXI_LLC_LINE_OFFSET_BITS 3\n'
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
  sed '/^`include "axi_llc_params.vh"/d' \
    "${repo_root}/rtl/src/axi_llc_axi_bridge.v"
} > "${build_dir}/axi_llc_axi_bridge.pre.v"

{
  printf '`define AXI_LLC_BRIDGE_READ_PENDING_COUNT 1\n'
  printf '`define AXI_LLC_BRIDGE_WRITE_PENDING_COUNT 1\n'
  cat "${repo_root}/rtl/include/axi_llc_params.vh"
  printf '`undef AXI_LLC_LINE_BYTES\n'
  printf '`define AXI_LLC_LINE_BYTES 8\n'
  printf '`undef AXI_LLC_LINE_BITS\n'
  printf '`define AXI_LLC_LINE_BITS 64\n'
  printf '`undef AXI_LLC_LINE_OFFSET_BITS\n'
  printf '`define AXI_LLC_LINE_OFFSET_BITS 3\n'
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
  sed '/^`include "axi_llc_params.vh"/d' \
    "${repo_root}/rtl/src/axi_llc_axi_bridge_dual.v"
} > "${build_dir}/axi_llc_axi_bridge_dual.pre.v"

exec timeout "${timeout_sec}" "${hw_cbmc}" \
  "${script_dir}/harness.c" \
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
  "${script_dir}/axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.v" \
  --module axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top \
  --bound 12
