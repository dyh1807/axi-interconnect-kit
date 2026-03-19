# AXI Interconnect Kit Interface Specification

This document lists:

1. Interconnect upstream interfaces
2. AXI4 channel signals

## 1) Interconnect Upstream Interfaces

Defined in `axi_interconnect/include/AXI_Interconnect_IO.h`.

### 1.1 Read Master Request (`ReadMasterReq_t`)

| Signal | Width | Direction (vs interconnect) | Meaning |
|---|---:|---|---|
| `valid` | 1 | input | Request is valid |
| `ready` | 1 | output | Interconnect accepts request |
| `addr` | 32 | input | Byte address |
| `total_size` | 8 | input | Transfer bytes minus 1 |
| `id` | 4 | input | Upstream transaction ID |
| `bypass` | 1 | input | Bypass LLC allocation/ownership rules |

### 1.2 Read Master Response (`ReadMasterResp_t`)

| Signal | Width | Direction | Meaning |
|---|---:|---|---|
| `valid` | 1 | output | Response valid |
| `ready` | 1 | input | Master accepts response |
| `data` | up to 256B | output | Wide read response payload |
| `id` | 4 | output | Upstream ID echoed back |

### 1.3 Write Master Request (`WriteMasterReq_t`)

| Signal | Width | Direction | Meaning |
|---|---:|---|---|
| `valid` | 1 | input | Request valid |
| `ready` | 1 | output | Interconnect accepts request |
| `addr` | 32 | input | Byte address |
| `wdata` | up to 64B | input | Bounded write payload |
| `wstrb` | up to 64b | input | Byte strobes |
| `total_size` | 8 | input | Transfer bytes minus 1 |
| `id` | 4 | input | Upstream transaction ID |
| `bypass` | 1 | input | Write-through maintenance / bypass semantics |

### 1.4 Write Master Response (`WriteMasterResp_t`)

| Signal | Width | Direction | Meaning |
|---|---:|---|---|
| `valid` | 1 | output | Response valid |
| `ready` | 1 | input | Master accepts response |
| `id` | 4 | output | Upstream ID echoed back |
| `resp` | 2 | output | AXI response code |

## 2) AXI4 Channel Signals

Defined in `sim_ddr/include/SimDDR_IO.h`.

AXI4 in this project uses:

- `ID`: 4 bits
- Data: `32-bit` bus at the downstream AXI4 channel

### 2.1 Write Address Channel (`AW`)

| Signal | Width | Direction (master->slave) | Meaning |
|---|---:|---|---|
| `awvalid` | 1 | M->S | Address valid |
| `awready` | 1 | S->M | Address ready |
| `awid` | 4 | M->S | Write transaction ID |
| `awaddr` | 32 | M->S | Byte address |
| `awlen` | 8 | M->S | Burst length minus 1 |
| `awsize` | 3 | M->S | `log2(bytes_per_beat)` |
| `awburst` | 2 | M->S | Burst type |

### 2.2 Write Data Channel (`W`)

| Signal | Width | Direction | Meaning |
|---|---:|---|---|
| `wvalid` | 1 | M->S | Data valid |
| `wready` | 1 | S->M | Data ready |
| `wdata` | 32 | M->S | Write payload |
| `wstrb` | 4 | M->S | Byte enable bits |
| `wlast` | 1 | M->S | Last beat |

### 2.3 Write Response Channel (`B`)

| Signal | Width | Direction | Meaning |
|---|---:|---|---|
| `bvalid` | 1 | S->M | Response valid |
| `bready` | 1 | M->S | Response ready |
| `bid` | 4 | S->M | Response ID |
| `bresp` | 2 | S->M | Response code |

### 2.4 Read Address Channel (`AR`)

| Signal | Width | Direction | Meaning |
|---|---:|---|---|
| `arvalid` | 1 | M->S | Address valid |
| `arready` | 1 | S->M | Address ready |
| `arid` | 4 | M->S | Read transaction ID |
| `araddr` | 32 | M->S | Byte address |
| `arlen` | 8 | M->S | Burst length minus 1 |
| `arsize` | 3 | M->S | `log2(bytes_per_beat)` |
| `arburst` | 2 | M->S | Burst type |

### 2.5 Read Data Channel (`R`)

| Signal | Width | Direction | Meaning |
|---|---:|---|---|
| `rvalid` | 1 | S->M | Data valid |
| `rready` | 1 | M->S | Data ready |
| `rid` | 4 | S->M | Response ID |
| `rdata` | 32 | S->M | Read payload |
| `rresp` | 2 | S->M | Response code |
| `rlast` | 1 | S->M | Last beat |
