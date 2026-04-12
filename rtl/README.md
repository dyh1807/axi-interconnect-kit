# RTL Subtree

This directory hosts the current synthesizable Verilog (not SystemVerilog)
implementation of the AXI/LLC submodule.

Start here for the current external top:

- `src/axi_llc_subsystem.v`
- `src/axi_llc_subsystem_core.v`

Detailed hierarchy / IO index is documented in:

- `README_CN.md`
- `docs/rtl_hierarchy_CN.md`

Current implemented scope:

- unified reconfiguration FSM
- valid-sweep invalidate flow
- mode-2 direct-mapped local window
- mode-1 cache control
- single AXI4 external boundary

The subtree is self-contained and is not wired into the top-level CMake build
yet.
