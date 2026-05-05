#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${script_dir}"

if ! command -v vcs >/dev/null 2>&1; then
  echo "ERROR: vcs not found. Source the Synopsys toolchain before running." >&2
  exit 1
fi

out_dir="${OUT_DIR:-local_debug/vcs_all_contracts_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "${out_dir}"

mapfile -t flists < <(find flist -maxdepth 1 -type f -name 'tb_*.f' | sort)

if [ "${#flists[@]}" -eq 0 ]; then
  echo "ERROR: no flist/tb_*.f files found" >&2
  exit 1
fi

passed=0
for flist in "${flists[@]}"; do
  test_name="$(basename "${flist}" .f)"
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
  if ! grep -Eq "(^|[[:space:]])${test_name}[[:space:]]+PASS|^PASS[[:space:]]*$" \
      "${test_dir}/run.log"; then
    echo "FAIL ${test_name}: PASS marker not found"
    tail -n 80 "${test_dir}/run.log"
    exit 1
  fi
  echo "PASS ${test_name}"
  passed=$((passed + 1))
done

echo "SUMMARY total=${#flists[@]} passed=${passed} failed=0 out_dir=${out_dir}"
