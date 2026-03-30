/**
 * @file SimDDR.cpp
 * @brief SimDDR Implementation - DDR Memory Simulator with AXI4 Interface
 *
 * Implementation with outstanding transaction support and burst-drain read
 * service. Reads still use round-robin arbitration, but only between bursts,
 * so a selected burst drains contiguously instead of ping-ponging every beat.
 */

#include "SimDDR.h"
#include <algorithm>
#include <cstdio>
#include <cstring>

// Use the global p_memory from the simulator
extern uint32_t *p_memory;
extern long long sim_time;

namespace sim_ddr {

namespace {
#ifndef CONFIG_AXI_LLC_FOCUS_LINE0
#define CONFIG_AXI_LLC_FOCUS_LINE0 0u
#endif

#ifndef CONFIG_AXI_LLC_FOCUS_LINE1
#define CONFIG_AXI_LLC_FOCUS_LINE1 0u
#endif

#ifndef CONFIG_AXI_LLC_DEBUG_LOG
#define CONFIG_AXI_LLC_DEBUG_LOG 0
#endif

constexpr uint32_t kFocusWriteLineBytes = 64u;

bool focus_write_line(uint32_t addr) {
  if (CONFIG_AXI_LLC_DEBUG_LOG == 0) {
    return false;
  }
  const uint32_t line_addr = addr & ~(kFocusWriteLineBytes - 1u);
  return (CONFIG_AXI_LLC_FOCUS_LINE0 != 0u &&
          line_addr == static_cast<uint32_t>(CONFIG_AXI_LLC_FOCUS_LINE0)) ||
         (CONFIG_AXI_LLC_FOCUS_LINE1 != 0u &&
          line_addr == static_cast<uint32_t>(CONFIG_AXI_LLC_FOCUS_LINE1));
}

inline uint8_t extract_data_byte(axi_data_t data, uint8_t byte_idx) {
  return static_cast<uint8_t>(
      (static_cast<unsigned __int128>(data) >> (byte_idx * 8u)) & 0xFFu);
}
} // namespace

// ============================================================================
// Initialization
// ============================================================================
void SimDDR::init() {
  // Clear write channel state
  w_active = false;
  w_current = {};

  // Clear queues
  while (!w_resp_queue.empty())
    w_resp_queue.pop();

  // Clear read transactions
  r_transactions.clear();
  r_rr_index = 0;
  r_selected_idx = -1;
  r_active_idx = -1;

  // Initialize IO outputs
  io.aw.awready = false;
  io.w.wready = false;
  io.b.bvalid = false;
  io.b.bid = 0;
  io.b.bresp = AXI_RESP_OKAY;
  io.ar.arready = false;
  io.r.rvalid = false;
  io.r.rid = 0;
  io.r.rdata = 0;
  io.r.rresp = AXI_RESP_OKAY;
  io.r.rlast = false;
}

// ============================================================================
// Two-Phase Combinational Logic
// ============================================================================

// Phase 1: Output signals (run BEFORE cpu.cycle())
// Sets: arready, rvalid, rdata, bvalid, bresp
void SimDDR::comb_outputs() {
  // Read channel outputs (rvalid, rdata, arready)
  comb_read_channel();
  // Write channel outputs (awready, wready, bvalid, bresp)
  comb_write_channel();
}

// Phase 2: Input processing (run AFTER cpu.cycle())
// Note: For SimDDR, both channels compute based on current io inputs,
// which are already set. The wiring order in MemorySubsystem handles
// the dependency. This function is a no-op for now but kept for symmetry.
void SimDDR::comb_inputs() {
  // Input processing is already handled in comb_outputs for SimDDR
  // because the ready/valid signals are computed in the same pass.
  // The two-phase split is primarily for AXI_Interconnect's complex logic.
}

// ============================================================================
// Combinational Logic - Write Channel
// ============================================================================
void SimDDR::comb_write_channel() {
  // Default outputs
  io.aw.awready = false;
  io.w.wready = false;
  io.b.bvalid = false;
  io.b.bid = 0;
  io.b.bresp = AXI_RESP_OKAY;

  // --- AW Channel: Accept new write address if no active transaction ---
  if (!w_active) {
    io.aw.awready = true;
  }

  // --- W Channel: Accept write data if active transaction ---
  if (w_active && !w_current.data_done) {
    io.w.wready = true;
  }

  // --- B Channel: Send response if latency complete ---
  if (!w_resp_queue.empty()) {
    WriteRespPending &front =
        const_cast<WriteRespPending &>(w_resp_queue.front());
    if (SIM_DDR_WRITE_RESP_LATENCY == 0 ||
        front.latency_cnt >= SIM_DDR_WRITE_RESP_LATENCY) {
      io.b.bvalid = true;
      io.b.bid = front.id;
      io.b.bresp = AXI_RESP_OKAY;
    }
  }
}

// ============================================================================
// Find next ready transaction using round-robin once the current burst finishes
// ============================================================================
int SimDDR::find_next_ready_transaction() {
  if (r_transactions.empty())
    return -1;

  size_t count = r_transactions.size();

  // Start from current rr_index and search for a ready transaction
  for (size_t i = 0; i < count; i++) {
    size_t idx = (r_rr_index + i) % count;
    if (r_transactions[idx].in_data_phase && !r_transactions[idx].complete) {
      return static_cast<int>(idx);
    }
  }

  return -1; // No ready transactions
}

// ============================================================================
// Combinational Logic - Read Channel with Burst-Drain Service
// ============================================================================
void SimDDR::comb_read_channel() {
  // Default outputs
  io.ar.arready = false;
  io.r.rvalid = false;
  io.r.rid = 0;
  io.r.rdata = 0;
  io.r.rresp = AXI_RESP_OKAY;
  io.r.rlast = false;

  // Reset selection unless an active burst is still eligible to drive.
  r_selected_idx = -1;

  // --- AR Channel: Accept new read address if not full ---
  if (r_transactions.size() < SIM_DDR_MAX_OUTSTANDING) {
    io.ar.arready = true;
  }

  // --- R Channel: Drain the active burst before rotating to the next ready one ---
  if (r_active_idx >= 0 &&
      r_active_idx < static_cast<int>(r_transactions.size())) {
    const ReadTransaction &active = r_transactions[static_cast<size_t>(r_active_idx)];
    if (active.in_data_phase && !active.complete) {
      r_selected_idx = r_active_idx;
    }
  }

  if (r_selected_idx < 0) {
    r_selected_idx = find_next_ready_transaction();
  }

  if (r_selected_idx >= 0) {
    ReadTransaction &txn = r_transactions[r_selected_idx];
    uint32_t current_addr = txn.addr + (txn.beat_cnt << txn.size);

    io.r.rvalid = true;
    io.r.rid = txn.id;
    io.r.rdata = do_memory_read(current_addr);
    io.r.rresp = AXI_RESP_OKAY;
    io.r.rlast = (txn.beat_cnt == txn.len);
  }
}

// ============================================================================
// Sequential Logic
// ============================================================================
void SimDDR::seq() {
  // ========== Write Channel Sequential Logic ==========

  // AW handshake: Start new write transaction
  if (io.aw.awvalid && io.aw.awready) {
    w_active = true;
    w_current.addr = io.aw.awaddr;
    w_current.id = io.aw.awid;
    w_current.len = io.aw.awlen;
    w_current.size = io.aw.awsize;
    w_current.burst = io.aw.awburst;
    w_current.beat_cnt = 0;
    w_current.data_done = false;
    if (focus_write_line(w_current.addr)) {
      std::printf(
          "[DDR-W][AW-HS] cyc=%lld id=%u addr=0x%08x len=%u size=%u\n",
          sim_time, static_cast<unsigned>(w_current.id), w_current.addr,
          static_cast<unsigned>(w_current.len), static_cast<unsigned>(w_current.size));
    }
  }

  // W handshake: Process write data
  if (io.w.wvalid && io.w.wready && w_active) {
    uint32_t current_addr =
        w_current.addr + (w_current.beat_cnt << w_current.size);
    if (focus_write_line(w_current.addr)) {
      std::printf(
          "[DDR-W][W-HS] cyc=%lld id=%u beat=%u/%u beat_addr=0x%08x "
          "data=0x%016llx wstrb=0x%llx wlast=%d\n",
          sim_time, static_cast<unsigned>(w_current.id),
          static_cast<unsigned>(w_current.beat_cnt),
          static_cast<unsigned>(w_current.len + 1), current_addr,
          static_cast<unsigned long long>(io.w.wdata),
          static_cast<unsigned long long>(io.w.wstrb),
          static_cast<int>(io.w.wlast));
    }
    do_memory_write(current_addr, io.w.wdata, io.w.wstrb);
    w_current.beat_cnt++;

    if (io.w.wlast) {
      w_current.data_done = true;
      WriteRespPending resp;
      resp.id = w_current.id;
      resp.latency_cnt = 0;
      w_resp_queue.push(resp);
      if (focus_write_line(w_current.addr)) {
        std::printf("[DDR-W][RESP-ENQ] cyc=%lld id=%u addr=0x%08x beats=%u\n",
                    sim_time, static_cast<unsigned>(w_current.id), w_current.addr,
                    static_cast<unsigned>(w_current.beat_cnt));
      }
      w_active = false;
    }
  }

  // B handshake: Complete response
  if (io.b.bvalid && io.b.bready) {
    if (!w_resp_queue.empty()) {
      const auto &resp = w_resp_queue.front();
      if (focus_write_line(w_current.addr)) {
        std::printf("[DDR-W][B-HS] cyc=%lld id=%u active_addr=0x%08x\n",
                    sim_time, static_cast<unsigned>(resp.id), w_current.addr);
      }
    }
    w_resp_queue.pop();
  }

  // Increment latency counters for pending responses
  std::queue<WriteRespPending> temp_queue;
  while (!w_resp_queue.empty()) {
    WriteRespPending resp = w_resp_queue.front();
    w_resp_queue.pop();
    resp.latency_cnt++;
    temp_queue.push(resp);
  }
  w_resp_queue = temp_queue;

  // ========== Read Channel Sequential Logic ==========

  // AR handshake: Start new read transaction
  if (io.ar.arvalid && io.ar.arready) {
    ReadTransaction txn;
    txn.addr = io.ar.araddr;
    txn.id = io.ar.arid;
    txn.len = io.ar.arlen;
    txn.size = io.ar.arsize;
    txn.burst = io.ar.arburst;
    txn.beat_cnt = 0;
    txn.latency_cnt = 0;
    txn.in_data_phase = false;
    txn.complete = false;
    r_transactions.push_back(txn);
  }

  // R handshake: Advance data beat on selected transaction
  if (io.r.rvalid && io.r.rready && r_selected_idx >= 0) {
    ReadTransaction &txn = r_transactions[r_selected_idx];
    txn.beat_cnt++;

    if (io.r.rlast) {
      txn.complete = true;
      r_active_idx = -1;
      r_rr_index =
          (static_cast<size_t>(r_selected_idx) + 1) %
          std::max(static_cast<size_t>(1), r_transactions.size());
    } else {
      r_active_idx = r_selected_idx;
    }
  }

  // Update all read transactions: increment latency, mark data phase
  for (auto &txn : r_transactions) {
    if (!txn.in_data_phase && !txn.complete) {
      txn.latency_cnt++;
      if (txn.latency_cnt >= SIM_DDR_LATENCY) {
        txn.in_data_phase = true;
      }
    }
  }

  // Remove completed transactions while keeping the active index stable.
  size_t dst = 0;
  for (size_t src = 0; src < r_transactions.size(); ++src) {
    if (r_transactions[src].complete) {
      if (r_active_idx >= 0 && static_cast<int>(src) < r_active_idx) {
        r_active_idx--;
      }
      continue;
    }
    if (dst != src) {
      r_transactions[dst] = r_transactions[src];
    }
    dst++;
  }
  r_transactions.resize(dst);

  // Adjust rr_index if vector size changed
  if (!r_transactions.empty() && r_rr_index >= r_transactions.size()) {
    r_rr_index = 0;
  }
  if (r_active_idx >= static_cast<int>(r_transactions.size())) {
    r_active_idx = -1;
  }
}

// ============================================================================
// Helper Functions
// ============================================================================

void SimDDR::do_memory_write(uint32_t addr, axi_data_t data, axi_strb_t wstrb) {
  if (focus_write_line(addr)) {
    std::printf(
        "[DDR-W][COMMIT] cyc=%lld addr=0x%08x data=0x%016llx wstrb=0x%llx\n",
        sim_time, addr, static_cast<unsigned long long>(data),
        static_cast<unsigned long long>(wstrb));
  }

  if (p_memory == nullptr) {
    return;
  }

  auto *byte_mem = reinterpret_cast<uint8_t *>(p_memory);
  for (uint8_t byte = 0; byte < AXI_DATA_BYTES; ++byte) {
    if (((static_cast<uint64_t>(wstrb) >> byte) & 0x1u) == 0u) {
      continue;
    }
    byte_mem[addr + byte] = extract_data_byte(data, byte);
  }

  if (DCACHE_LOG) {
    printf("[SimDDR] Write: addr=0x%08x data=0x%016llx wstrb=0x%llx\n", addr,
           static_cast<unsigned long long>(data),
           static_cast<unsigned long long>(wstrb));
  }
}

axi_data_t SimDDR::do_memory_read(uint32_t addr) {
  if (p_memory == nullptr) {
    return static_cast<axi_data_t>(0xDEADBEEF);
  }

  auto *byte_mem = reinterpret_cast<uint8_t *>(p_memory);
  axi_data_t data = 0;
  for (uint8_t byte = 0; byte < AXI_DATA_BYTES; ++byte) {
    data |= static_cast<axi_data_t>(
        static_cast<unsigned __int128>(byte_mem[addr + byte]) << (byte * 8u));
  }

  if (DCACHE_LOG) {
    printf("[SimDDR] Read: addr=0x%08x -> 0x%016llx\n", addr,
           static_cast<unsigned long long>(data));
  }

  return data;
}

// ============================================================================
// Debug
// ============================================================================
void SimDDR::print_state() {
  printf("[SimDDR] Write: active=%d resp_pending=%zu\n", w_active,
         w_resp_queue.size());
  printf("[SimDDR] Read: txn_count=%zu rr_index=%zu active_idx=%d\n",
         r_transactions.size(), r_rr_index, r_active_idx);
  for (size_t i = 0; i < r_transactions.size(); ++i) {
    const auto &txn = r_transactions[i];
    printf("[SimDDR] ReadTxn[%zu]: addr=0x%08x id=%u len=%u size=%u beat=%u lat=%u in_data=%d complete=%d\n",
           i, txn.addr, static_cast<unsigned>(txn.id),
           static_cast<unsigned>(txn.len), static_cast<unsigned>(txn.size),
           static_cast<unsigned>(txn.beat_cnt),
           static_cast<unsigned>(txn.latency_cnt),
           static_cast<int>(txn.in_data_phase), static_cast<int>(txn.complete));
  }
}

} // namespace sim_ddr
