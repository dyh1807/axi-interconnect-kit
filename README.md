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
- AXI4 interconnect read front-end supports multiple outstanding contexts:
  - global limit `8`
  - per-read-master limit `4`
- LLC cacheable demand-miss execution is still more restrictive:
  - one read master can have at most one cacheable demand miss actively owned by
    the LLC at a time
  - other masters can still consume remaining global read resources
  - bypass reads are not subject to that same-master cacheable-miss restriction
- Cacheable writes are owned by the LLC path.
- Cacheable partial write miss performs `refill old line -> merge bytes ->
  install dirty line`; it does not merge onto an all-zero line.
- Bypass reads probe LLC first:
  - hit returns latest resident line
  - miss goes downstream without allocation
- Bypass writes are write-through maintenance operations:
  - hit updates resident line without setting `DIRTY`
  - miss goes downstream without allocation
- Sub-line writes merge by `addr % line_bytes`.
- `invalidate_all` is conservative:
  - it is accepted only when there is no dirty resident line, dirty victim
    writeback, or write-side hazard pending
  - callers should hold the request until `invalidate_all_accepted` is observed
  - already captured clean LLC-path work may drain while `invalidate_all` is
    pending
  - it drops stale clean refill installs by epoch once accepted
  - it does not silently discard dirty resident data

### AXI4 Write Concurrency

The current AXI4 write design is:

- Interconnect-front accepts up to `MAX_WRITE_OUTSTANDING` pending writes.
- Non-LLC path drains pending writes downstream and routes B responses by AXI ID.
- LLC path keeps:
  - per-master pending write queues
  - one active write context per write master
  - shared lookup engine
  - shared victim-writeback resource
  - shared downstream memory write port
- Same-master promotion waits until the previous write response slot is consumed.

`MAX_WRITE_OUTSTANDING` is therefore a front-end queueing bound, not a total
global bound on every LLC-internal write state bit combined with interconnect
state.

This is the current write-side correctness target for this stage. Future
performance work, if needed, would deepen internal write-resource parallelism
rather than reopen basic ordering/coherence rules.

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

This repository is currently stabilized around the AXI4-only LLC/interconnect
correctness scope implemented here, with conservative maintenance semantics.
Final closure wording is intentionally deferred pending external review of the
maintenance barrier and front-end race regressions. Parent-simulator
integration bugs should be debugged outside this submodule unless the root
cause is clearly inside the kit itself.
