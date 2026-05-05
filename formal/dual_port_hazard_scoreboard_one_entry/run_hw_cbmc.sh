#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
hw_cbmc="${HW_CBMC:-${repo_root}/../../hw-cbmc/src/hw-cbmc/hw-cbmc}"
timeout_sec="${HW_CBMC_TIMEOUT_SEC:-60}"

exec timeout "${timeout_sec}" "${hw_cbmc}" \
  "${script_dir}/harness.c" \
  "${repo_root}/rtl/src/axi_llc_dual_port_slot_hazard.v" \
  "${repo_root}/rtl/src/axi_llc_dual_port_hazard_match.v" \
  "${repo_root}/rtl/src/axi_llc_dual_port_hazard_scoreboard.v" \
  "${script_dir}/axi_dual_port_hazard_scoreboard_one_entry_formal_top.v" \
  --module axi_dual_port_hazard_scoreboard_one_entry_formal_top \
  --bound 8
