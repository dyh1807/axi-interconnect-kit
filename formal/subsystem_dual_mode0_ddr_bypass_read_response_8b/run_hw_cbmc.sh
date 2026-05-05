#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
base_dir="${script_dir}/../subsystem_dual_mode0_ddr_bypass_read_response"

exec env \
  HW_CBMC_TEST_NAME="subsystem_dual_mode0_ddr_bypass_read_response_8b" \
  HARNESS_C="${base_dir}/harness_8b.c" \
  "${base_dir}/run_hw_cbmc.sh"
