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
