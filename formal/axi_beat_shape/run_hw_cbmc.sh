#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
hw_cbmc="${HW_CBMC:-${repo_root}/../../hw-cbmc/src/hw-cbmc/hw-cbmc}"

exec "${hw_cbmc}" \
  "${script_dir}/harness.c" \
  "${repo_root}/rtl/src/axi_llc_axi_beat_shape.v" \
  "${script_dir}/axi_beat_shape_formal_top.v" \
  --module axi_beat_shape_formal_top \
  --bound 1
