# cache_ctrl_invalidate_line_hit

状态：已通过，并已纳入稳定 manifest。最新 targeted log：
`local_debug/hw_cbmc_cache_ctrl_invalidate_line_hit_20260506_132948.log`。

该 bounded formal smoke 直接实例化实际 `rtl/src/llc_cache_ctrl.v`，小参数与
`axi_llc_cache_trace_vectors_test.cpp` 生成的 invalidate case 对齐：8B line / 2 set /
2 way / 29-bit meta。验证目标是 MODE_CACHE 下 `invalidate_line` 命中一条 dirty line
时的 cache-control 局部语义：

- `invalidate_line` 在 idle 且无 pending MSHR/victim 时可以被 accepted。
- 命中后在 bounded window 内出现与 C++ trace 对齐的 valid clear payload：
  `valid_wr_mask=2'b10` 且 `valid_wr_bits=2'b00`。

边界：

- 不覆盖 same-cycle side-effect safety；`data/meta/repl` 不写、lower memory/bypass/upstream
  response 不产生，仍由 `tb_llc_cache_ctrl_cpp_trace_contract` 的 VCS trace contract 直接覆盖。
  最近一次 targeted VCS 目录：
  `rtl/local_debug/vcs_llc_cache_ctrl_cpp_trace_invline_formal_boundary_20260506_133152_eda10`。
- 不覆盖 pending MSHR/victim hazard；这些由 subsystem trace/VCS contract 覆盖。
- 不覆盖 `invalidate_all` dirty-line blocked 语义；该语义依赖 subsystem/core 级 drain
  与 dirty resident state。
