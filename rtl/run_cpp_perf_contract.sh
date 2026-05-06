#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${script_dir}"

if ! command -v vcs >/dev/null 2>&1; then
  echo "ERROR: vcs not found. Source the Synopsys toolchain before running." >&2
  exit 1
fi

out_dir="${OUT_DIR:-local_debug/vcs_cpp_perf_contract_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "${out_dir}"

vcs -full64 -sverilog +v2k +incdir+include \
  -f flist/perf_axi_llc_subsystem_dual_cpp_perf_contract.f \
  -o "${out_dir}/simv" \
  > "${out_dir}/compile.log" 2>&1

"${out_dir}/simv" > "${out_dir}/run.log" 2>&1 || true

if grep -q "FAIL" "${out_dir}/run.log"; then
  echo "FAIL tb_axi_llc_subsystem_dual_cpp_perf_contract"
  tail -n 120 "${out_dir}/run.log"
  exit 1
fi

if ! grep -q "tb_axi_llc_subsystem_dual_cpp_perf_contract PASS" "${out_dir}/run.log"; then
  echo "FAIL tb_axi_llc_subsystem_dual_cpp_perf_contract: PASS marker not found"
  tail -n 120 "${out_dir}/run.log"
  exit 1
fi

echo "PASS tb_axi_llc_subsystem_dual_cpp_perf_contract out_dir=${out_dir}"
