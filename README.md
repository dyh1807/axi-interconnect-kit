# AXI Interconnect Kit

Standalone AXI subsystem extracted from the simulator and buildable on its own.

## Components

- AXI4 path: interconnect + AXI4 router + SimDDR + MMIO bus + UART16550 device
- AXI3 path: interconnect + AXI3 router + SimDDR + MMIO bus + UART16550 device
- Upstream simplified CPU-side master ports:
  - `4` read masters (`icache`, `dcache_r`, `mmu`, `extra_r`)
  - `2` write masters (`dcache_w`, `extra_w`)

## Naming Choice: `interconnect` vs `bridge`

`bridge` is usually point-to-point protocol conversion.  
This project does multi-master arbitration, address routing, and response demux, so
`interconnect` is the accurate name.

## Topology (READ path)

```
Read Masters (4 ports)
  M0 icache, M1 dcache_r, M2 mmu, M3 extra_r
            |
            v
   +----------------------+
   | AXI_Interconnect     |  (upstream simplified req/resp -> AXI4/AXI3)
   +----------------------+
            |
            v
   +----------------------+
   | AXI_Router_AXI4/AXI3 |  (address decode)
   +----------------------+
        |            |
        | DDR range  | MMIO range
        v            v
 +-------------+  +---------------------+
 | SimDDR      |  | MMIO_Bus + UART16550|
 | (slave #0)  |  | (slave #1)          |
 +-------------+  +---------------------+
```

`AXI_Router_AXI4/AXI3` is a first-class layer (not implied inside interconnect):
- `AXI_Interconnect`: multi-master arbitration, upstream request/response scheduling.
- `AXI_Router_AXI4/AXI3`: AXI-side address decode and slave-path selection.

## Topology (WRITE path)

```
Write Masters (2 ports)
  M0 dcache_w, M1 extra_w
            |
            v
   +----------------------+
   | AXI_Interconnect     |  (AW/W/B scheduling + response routing)
   +----------------------+
            |
            v
   +----------------------+
   | AXI_Router_AXI4/AXI3 |  (AW/W/B path selection)
   +----------------------+
        |            |
        | DDR range  | MMIO range
        v            v
 +-------------+  +---------------------+
 | SimDDR      |  | MMIO_Bus + UART16550|
 | (slave #0)  |  | (slave #1)          |
 +-------------+  +---------------------+
```

The same layering applies to write path (`AW/W/B`):
- `AXI_Interconnect` handles upstream write-port arbitration and response demux.
- `AXI_Router_AXI4/AXI3` decides DDR vs MMIO destination by address map.

## Interface Signals

Detailed signal lists are in:

- `docs/interfaces.md`
  - Interconnect upstream ports (`read_ports[4]`, `write_ports[2]`)
  - AXI3 channels (`AW/W/B/AR/R`, 256-bit data bus flavor)
  - AXI4 channels (`AW/W/B/AR/R`, 32-bit data bus flavor)

Chinese version:

- `docs/interfaces_CN.md`

## Repository Tree and File Roles

```text
.
├── CMakeLists.txt
├── Makefile
├── README.md / README_CN.md
├── include/
├── axi_interconnect/
│   ├── include/
│   ├── AXI_Interconnect.cpp
│   ├── AXI_Interconnect_AXI3.cpp
│   ├── AXI_Router_AXI4.cpp
│   ├── AXI_Router_AXI3.cpp
│   ├── axi_interconnect_test.cpp
│   └── axi_interconnect_axi3_test.cpp
├── sim_ddr/
│   ├── include/
│   ├── SimDDR.cpp
│   ├── SimDDR_AXI3.cpp
│   ├── sim_ddr_test.cpp
│   └── sim_ddr_axi3_test.cpp
├── mmio/
│   ├── include/
│   ├── MMIO_Bus_AXI4.cpp
│   ├── MMIO_Bus_AXI3.cpp
│   ├── UART16550_Device.cpp
│   ├── mmio_router_axi4_test.cpp
│   └── mmio_router_axi3_test.cpp
├── demos/
│   ├── axi4_smoke.cpp
│   ├── axi3_smoke.cpp
│   └── single_cycle/
│       ├── include/
│       ├── src/
│       └── third_party/softfloat/softfloat.a
├── docs/
└── .codex/skills/
```

Top-level files:
- `CMakeLists.txt`: target graph for libraries/tests/demos and feature switches.
- `Makefile`: CMake wrapper entry for quick local build.
- `README.md` / `README_CN.md`: English/Chinese user-facing documentation.
- `.gitignore`: ignores build artifacts and generated files.

`include/`:
- `include/axi_interconnect_compat.h`: integration compatibility helpers/macros for parent project.
- `include/axi_mmio_map.h`: shared DDR/MMIO address map constants.

`axi_interconnect/`:
- `axi_interconnect/include/AXI_Interconnect.h`: AXI4 interconnect class/types.
- `axi_interconnect/include/AXI_Interconnect_AXI3.h`: AXI3 interconnect class/types.
- `axi_interconnect/include/AXI_Interconnect_IO.h`: common upstream simplified read/write port structures.
- `axi_interconnect/include/AXI_Router_AXI4.h`: AXI4 router API.
- `axi_interconnect/include/AXI_Router_AXI3.h`: AXI3 router API.
- `axi_interconnect/AXI_Interconnect.cpp`: AXI4 arbitration/request scheduling/response demux.
- `axi_interconnect/AXI_Interconnect_AXI3.cpp`: AXI3 arbitration/request scheduling/response demux.
- `axi_interconnect/AXI_Router_AXI4.cpp`: AXI4 DDR/MMIO decode + forwarding.
- `axi_interconnect/AXI_Router_AXI3.cpp`: AXI3 DDR/MMIO decode + forwarding.
- `axi_interconnect/axi_interconnect_test.cpp`: AXI4 interconnect unit/randomized tests.
- `axi_interconnect/axi_interconnect_axi3_test.cpp`: AXI3 interconnect unit/randomized tests.

`sim_ddr/`:
- `sim_ddr/include/SimDDR.h`: AXI4 SimDDR API.
- `sim_ddr/include/SimDDR_AXI3.h`: AXI3 SimDDR API.
- `sim_ddr/include/SimDDR_IO.h`: AXI4 IO bundle definitions.
- `sim_ddr/include/SimDDR_AXI3_IO.h`: AXI3 IO bundle definitions.
- `sim_ddr/SimDDR.cpp`: AXI4 memory backend behavior.
- `sim_ddr/SimDDR_AXI3.cpp`: AXI3 memory backend behavior.
- `sim_ddr/sim_ddr_test.cpp`: AXI4 SimDDR test.
- `sim_ddr/sim_ddr_axi3_test.cpp`: AXI3 SimDDR test.

`mmio/`:
- `mmio/include/MMIO_Device.h`: abstract base class for MMIO devices.
- `mmio/include/MMIO_Bus_AXI4.h`: AXI4 MMIO bus API.
- `mmio/include/MMIO_Bus_AXI3.h`: AXI3 MMIO bus API.
- `mmio/include/UART16550_Device.h`: UART16550 device API.
- `mmio/MMIO_Bus_AXI4.cpp`: AXI4 MMIO bus implementation.
- `mmio/MMIO_Bus_AXI3.cpp`: AXI3 MMIO bus implementation.
- `mmio/UART16550_Device.cpp`: UART16550 model implementation.
- `mmio/mmio_router_axi4_test.cpp`: AXI4 router+MMIO integration tests.
- `mmio/mmio_router_axi3_test.cpp`: AXI3 router+MMIO integration tests.

`demos/`:
- `demos/axi4_smoke.cpp`: minimal AXI4 smoke demo.
- `demos/axi3_smoke.cpp`: minimal AXI3 smoke demo.
- `demos/single_cycle/include/config.h`: single-cycle local config and constants.
- `demos/single_cycle/include/RISCV.h`: RV32 ISA constants/helpers/types.
- `demos/single_cycle/include/CSR.h`: CSR constants/definitions.
- `demos/single_cycle/include/single_cycle_cpu.h`: single-cycle CPU class declaration.
- `demos/single_cycle/include/sc_axi4_sim_api.h`: AXI simulation API for single-cycle runner.
- `demos/single_cycle/include/softfloat.h`: softfloat function declarations.
- `demos/single_cycle/include/softfloat_types.h`: softfloat data types.
- `demos/single_cycle/src/main.cpp`: single-cycle demo entry.
- `demos/single_cycle/src/single_cycle_cpu.cpp`: single-cycle CPU implementation.
- `demos/single_cycle/src/sc_axi4_sim_api.cpp`: AXI memory/MMIO glue and runtime driver.
- `demos/single_cycle/third_party/softfloat/softfloat.a`: prebuilt softfloat static library.

`docs/`:
- `docs/interfaces.md`: full EN signal list (upstream ports + AXI3/AXI4 channels).
- `docs/interfaces_CN.md`: full CN signal list.

`.codex/skills/`:
- `.codex/skills/axi-kit-dev/SKILL.md`: development workflow notes.
- `.codex/skills/axi-kit-verify/SKILL.md`: verification/regression workflow notes.

Note:
- `build/` is generated output, not part of source roles.

## Suggested Reading Path

If you are new to this repository, this order gives the fastest understanding:

1. Read architecture + topology in this README (READ/WRITE ASCII diagrams).
2. Read signal dictionary in `docs/interfaces.md`.
3. Read one full datapath in order:
   - `axi_interconnect/include/AXI_Interconnect_IO.h`
   - `axi_interconnect/AXI_Interconnect.cpp` (or `AXI_Interconnect_AXI3.cpp`)
   - `axi_interconnect/AXI_Router_AXI4.cpp` (or `AXI_Router_AXI3.cpp`)
   - `sim_ddr/SimDDR.cpp` + `mmio/MMIO_Bus_AXI4.cpp`
4. Read tests to understand expected behavior:
   - `axi_interconnect/axi_interconnect_test.cpp`
   - `mmio/mmio_router_axi4_test.cpp`
5. Read demos for runnable examples:
   - `demos/axi4_smoke.cpp`, `demos/axi3_smoke.cpp`
   - `demos/single_cycle/src/main.cpp`

Quick rule of thumb:
- Start from AXI4 path first, then map differences to AXI3 equivalents.


## Build

```bash
cmake -S . -B build
cmake --build build -j
```

or:

```bash
make -j
```

## Tests

```bash
cd build
ctest --output-on-failure
```

Current test binaries:

- `sim_ddr_test`
- `axi_interconnect_test`
- `mmio_router_axi4_test`
- `sim_ddr_axi3_test`
- `axi_interconnect_axi3_test`
- `mmio_router_axi3_test`

## Demos

```bash
./build/axi4_smoke_demo
./build/axi3_smoke_demo
```

Demo intent:
- `axi4_smoke_demo`: single read-master smoke flow over AXI4 path; checks request acceptance, AR handshake issuance, and read response return.
- `axi3_smoke_demo`: same smoke intent over AXI3 path, including ID-carrying read path handshake.

## Single-Cycle RV32 Case

Source layout:

```text
demos/single_cycle/
  include/                # single-cycle local headers/API/config
  src/                    # simulator runtime + CPU model
  third_party/softfloat/  # prebuilt softfloat archive
```

Build target:

```bash
cmake -S . -B build
cmake --build build -j --target single_cycle_axi4_demo
```

Latency note:
- `single_cycle_axi4_demo` uses a dedicated AXI4+SimDDR library variant with
  default `AXI_KIT_SINGLE_CYCLE_DDR_LATENCY=8` (to keep demo runtime practical).
- You can override it by configuring CMake, for example:
  `cmake -S . -B build -DAXI_KIT_SINGLE_CYCLE_DDR_LATENCY=16`

Run examples (using images from parent simulator repo):

```bash
./build/single_cycle_axi4_demo ../baremetal/new_dhrystone/dhrystone.bin
./build/single_cycle_axi4_demo ../baremetal/new_coremark/coremark.bin
./build/single_cycle_axi4_demo ../baremetal/linux.bin --max-inst 20000000
```

This case keeps the simulator and interconnect separated, and all memory-like
operations are issued through AXI upstream master ports (not direct memory
peek/poke):
- `fetch` -> read master `M0 (icache)`
- `load` + `amo read` -> read master `M1 (dcache_r)`
- `ptw/va2pa` reads -> read master `M2 (mmu)`
- `store` + `amo writeback` (+ UART MMIO write) -> write master `M0 (dcache_w)`

Reserved-but-unused in this single-cycle case:
- read master `M3 (extra_r)`
- write master `M1 (extra_w)`

## Integration Back to Parent Simulator

Parent project can consume this repository as an external dependency and include:

- `include/`
- `axi_interconnect/include/`
- `sim_ddr/include/`
- `mmio/include/`

and link either:

- `axi_kit_axi4`
- `axi_kit_axi3`

## Git Submodule Workflow

If another repository wants to consume this kit as a submodule:

```bash
# run in parent repo root
git submodule add git@github.com:dyh1807/axi-interconnect-kit.git axi-interconnect-kit
git commit -m "chore(submodule): add axi-interconnect-kit"
```

What this does:
- creates `.gitmodules` entry (submodule URL/path metadata)
- records a fixed commit pointer for `axi-interconnect-kit` in parent repo

Clone parent repo + initialize submodules:

```bash
git clone --recurse-submodules <parent-repo-url>
# or if already cloned:
git submodule update --init --recursive
```

What this does:
- checks out submodule content at the exact commit pinned by parent repo

Update submodule to latest remote branch (example: `main`):

```bash
cd axi-interconnect-kit
git fetch origin
git checkout main
git pull --ff-only origin main
cd ..
git add axi-interconnect-kit
git commit -m "chore(submodule): bump axi-interconnect-kit"
```

What this does:
- updates submodule working tree to newer commit
- updates parent repo pointer to that new commit

Pin submodule to a specific commit:

```bash
cd axi-interconnect-kit
git checkout <commit-sha>
cd ..
git add axi-interconnect-kit
git commit -m "chore(submodule): pin axi-interconnect-kit to <sha>"
```

Useful maintenance commands:

```bash
git submodule status
git submodule sync --recursive
git submodule foreach --recursive 'git status --short --branch'
```

What they do:
- `git submodule status`: show current checked-out SHA for each submodule
- `git submodule sync --recursive`: refresh URL/path config from `.gitmodules`
- `git submodule foreach ...`: run command in each submodule for quick inspection
