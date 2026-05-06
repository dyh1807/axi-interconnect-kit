# RTL Subtree

This directory hosts the current synthesizable Verilog (not SystemVerilog)
implementation of the AXI/LLC submodule.

Start here for the current external top:

- `src/axi_llc_subsystem_dual.v`
- `src/axi_llc_subsystem.v` (legacy single-AXI compatible top)
- `src/axi_llc_subsystem_core.v`

Detailed hierarchy / IO index is documented in:

- `README_CN.md`
- `../docs/submodule_architecture_CN.md`
- `docs/rtl_hierarchy_CN.md`

Current implemented scope:

- unified reconfiguration FSM
- valid-sweep invalidate flow
- mode-2 direct-mapped local window
- mode-1 cache control
- native dual external AXI boundary:
  - DDR/SDRAM AXI: 256-bit beat
  - MMIO AXI: 32-bit beat, 4B single-beat only
- compatibility wrappers that expose the older single AXI4 boundary for legacy
  tests only

The subtree is self-contained and is not wired into the top-level CMake build
yet.
