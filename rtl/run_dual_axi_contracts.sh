#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${script_dir}"

if ! command -v vcs >/dev/null 2>&1; then
  echo "ERROR: vcs not found. Source the Synopsys toolchain before running." >&2
  exit 1
fi

out_dir="${OUT_DIR:-local_debug/vcs_dual_axi_contracts_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "${out_dir}"

tests=(
  "tb_axi_llc_axi_bridge_dual_contract:flist/tb_axi_llc_axi_bridge_dual_contract.f"
  "tb_axi_llc_subsystem_dual_mmio_contract:flist/tb_axi_llc_subsystem_dual_mmio_contract.f"
  "tb_axi_llc_subsystem_dual_outstanding_contract:flist/tb_axi_llc_subsystem_dual_outstanding_contract.f"
  "tb_axi_llc_dual_port_hazard_scoreboard_contract:flist/tb_axi_llc_dual_port_hazard_scoreboard_contract.f"
)

passed=0
for item in "${tests[@]}"; do
  test_name="${item%%:*}"
  flist="${item#*:}"
  test_dir="${out_dir}/${test_name}"
  mkdir -p "${test_dir}"

  echo "RUN ${test_name}"
  vcs -full64 -sverilog +v2k +incdir+include \
    -f "${flist}" \
    -o "${test_dir}/simv" \
    > "${test_dir}/compile.log" 2>&1
  "${test_dir}/simv" > "${test_dir}/run.log" 2>&1 || true

  if grep -q "FAIL" "${test_dir}/run.log"; then
    echo "FAIL ${test_name}"
    tail -n 80 "${test_dir}/run.log"
    exit 1
  fi
  if ! grep -q "${test_name} PASS" "${test_dir}/run.log"; then
    echo "FAIL ${test_name}: PASS marker not found"
    tail -n 80 "${test_dir}/run.log"
    exit 1
  fi
  echo "PASS ${test_name}"
  passed=$((passed + 1))
done

echo "SUMMARY total=${#tests[@]} passed=${passed} failed=0 out_dir=${out_dir}"
