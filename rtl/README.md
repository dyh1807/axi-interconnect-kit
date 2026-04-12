# RTL Subtree

This directory hosts the first-stage Verilog (not SystemVerilog) implementation
for the AXI/LLC submodule.

The current bring-up scope is intentionally narrow:

- unified reconfiguration FSM
- valid-sweep invalidate flow
- mode-2 direct-mapped local window
- abstract cache/bypass subpath split for future integration

The subtree is self-contained and is not wired into the top-level CMake build
yet.
