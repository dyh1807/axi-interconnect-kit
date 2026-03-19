# AXI Interconnect Kit

Standalone AXI4 memory subsystem extracted from the simulator.

## Scope

- One AXI4 interconnect with simplified upstream ports:
  - `read_ports[4]`: `icache`, `dcache_r`, `uncore_lsu_r`, `extra_r`
  - `write_ports[2]`: `dcache_w`, `uncore_lsu_w`
- AXI4 router, SimDDR backend, MMIO bus, UART16550 device
- Optional shared unified LLC on the AXI4 path

AXI3 support has been removed from this repository. The kit is now AXI4-only.

## Topology

```text
Read/Write masters
        |
        v
+----------------------+
| AXI_Interconnect     |
+----------------------+
        |
        v
+----------------------+
| AXI_LLC (optional)   |
+----------------------+
        |
        v
+----------------------+
| AXI_Router_AXI4      |
+----------------------+
     |            |
     | DDR range  | MMIO range
     v            v
+----------+   +---------------------+
| SimDDR   |   | MMIO_Bus + UART16550|
+----------+   +---------------------+
```

`AXI_Router_AXI4` is an explicit layer. The interconnect does arbitration and
upstream response routing; the router does AXI-side address decode.

## LLC Summary

`AXI_LLC` sits behind the AXI4 interconnect and models a shared unified cache.

Default configuration:

- `8MB`
- `64B` line
- `16-way`
- `4` MSHRs
- lookup latency `8`
- `PIPT`, `unified`, `NINE`
- prefetch disabled by default

Current behavior:

- Cacheable reads allocate and refill through external SRAM-style `data/meta/repl`
  tables supplied by the parent simulator.
- AXI4 read path supports multiple outstanding contexts:
  - global limit `8`
  - per-read-master limit `4`
- Cacheable writes are owned by the LLC path.
- Bypass reads probe LLC first:
  - hit returns latest resident line
  - miss goes downstream without allocation
- Bypass writes are write-through maintenance operations:
  - hit updates resident line without setting `DIRTY`
  - miss goes downstream without allocation
- Sub-line writes merge by `addr % line_bytes`.
- `invalidate_all` drops stale refill installs by epoch, but original demand
  misses still return responses correctly.

### AXI4 Write Concurrency

The current AXI4 write design is:

- Interconnect accepts up to `MAX_WRITE_OUTSTANDING` pending writes.
- Non-LLC path drains pending writes downstream and routes B responses by AXI ID.
- LLC path keeps:
  - per-master pending write queues
  - one active write context per write master
  - shared lookup engine
  - shared victim-writeback resource
  - shared downstream memory write port
- Same-master promotion waits until the previous write response slot is consumed.

This is the current correctness closure point. Future performance work, if
needed, would deepen internal write-resource parallelism rather than reopen
basic ordering/coherence rules.

## Test Tiers

- `P0`: deterministic component tests
  - LLC read/write hit/miss
  - bypass read/write semantics
  - victim writeback
  - maintenance
  - stale refill protection
  - write-queue edge cases
- `P1`: deterministic AXI4 + LLC + SimDDR integration tests
  - cacheable+bypass coexistence
  - queued writes
  - maintenance interlocks
  - invalidate-all epoch behavior
- `P2`: fixed-seed mixed stress
  - mixed coherence stress
  - refill/maintenance/writeback races

Validated toolchains:

- `qm` environment default toolchain
- `/usr/bin/g++`
- `/workspace/S/daiyihao/miniconda3/envs/qm/bin/x86_64-conda-linux-gnu-c++`

## Interface Documentation

- [docs/interfaces.md](docs/interfaces.md)
- [docs/interfaces_CN.md](docs/interfaces_CN.md)

## Main Files

```text
.
├── CMakeLists.txt
├── README.md / README_CN.md
├── axi_interconnect/
│   ├── include/
│   ├── AXI_Interconnect.cpp
│   ├── AXI_LLC.cpp
│   ├── AXI_Router_AXI4.cpp
│   ├── axi_interconnect_test.cpp
│   ├── axi_interconnect_llc_axi4_test.cpp
│   └── axi_llc_test.cpp
├── sim_ddr/
│   ├── include/
│   ├── SimDDR.cpp
│   └── sim_ddr_test.cpp
├── mmio/
│   ├── include/
│   ├── MMIO_Bus_AXI4.cpp
│   ├── UART16550_Device.cpp
│   └── mmio_router_axi4_test.cpp
└── demos/
    └── axi4_smoke.cpp
```

## Current Closure

This repository is now closed around AXI4-only correctness and regression
coverage. Parent-simulator integration bugs should be debugged outside this
submodule unless the root cause is clearly inside the kit itself.
