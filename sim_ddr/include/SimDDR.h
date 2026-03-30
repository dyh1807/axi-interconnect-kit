#pragma once
/**
 * @file SimDDR.h
 * @brief SimDDR - DDR Memory Simulator with AXI4 Interface
 *
 * This module simulates DDR memory with standard AXI4 interface.
 * It follows the simulator's comb/seq pattern for cycle-accurate behavior.
 *
 * Features:
 * - 5 AXI4 channels (AW, W, B, AR, R)
 * - Configurable memory latency
 * - Outstanding transaction support (multiple in-flight transactions)
 * - Burst-drain read service with burst-to-burst round-robin fairness
 * - INCR burst mode support
 * - Uses external p_memory for storage (shared with main simulator)
 */

#include "SimDDR_IO.h"
#include "axi_interconnect_compat.h"
#include <cstddef>
#include <cstdint>
#include <queue>
#include <vector>

namespace sim_ddr {

// ============================================================================
// SimDDR Configuration
// ============================================================================
constexpr uint32_t SIM_DDR_LATENCY = CONFIG_SIM_DDR_LATENCY;
// Write response latency is modeled separately from read latency. Older
// simulator glue reused a frontend-side latency knob for the whole DDR path,
// but the current shared-AXI design benefits from controlling write completion
// independently when analyzing dirty-victim critical paths.
#ifndef AXI_KIT_SIM_DDR_WRITE_RESP_LATENCY
#ifdef CONFIG_AXI_KIT_SIM_DDR_WRITE_RESP_LATENCY
#define AXI_KIT_SIM_DDR_WRITE_RESP_LATENCY \
  CONFIG_AXI_KIT_SIM_DDR_WRITE_RESP_LATENCY
#else
#define AXI_KIT_SIM_DDR_WRITE_RESP_LATENCY 2
#endif
#endif
constexpr uint32_t SIM_DDR_WRITE_RESP_LATENCY =
    AXI_KIT_SIM_DDR_WRITE_RESP_LATENCY;
constexpr uint32_t SIM_DDR_MAX_BURST = 256;     // Max burst length (AXI4 limit)
#ifndef AXI_KIT_SIM_DDR_MAX_OUTSTANDING
#ifdef CONFIG_AXI_KIT_SIM_DDR_MAX_OUTSTANDING
#define AXI_KIT_SIM_DDR_MAX_OUTSTANDING CONFIG_AXI_KIT_SIM_DDR_MAX_OUTSTANDING
#else
#define AXI_KIT_SIM_DDR_MAX_OUTSTANDING 8
#endif
#endif
constexpr uint32_t SIM_DDR_MAX_OUTSTANDING =
    AXI_KIT_SIM_DDR_MAX_OUTSTANDING; // Max outstanding transactions

// ============================================================================
// Transaction Structures for Outstanding Support
// ============================================================================

// Write transaction (after AW handshake, waiting for W data or in latency)
struct WriteTransaction {
  uint32_t addr;
  uint8_t id;
  uint8_t len; // Burst length - 1
  uint8_t size;
  uint8_t burst;
  uint8_t beat_cnt; // Current beat received
  bool data_done;   // All W beats received
};

// Write response pending (in latency phase after W complete)
struct WriteRespPending {
  uint8_t id;
  uint32_t latency_cnt;
};

// Read transaction (after AR handshake, in latency or sending data)
struct ReadTransaction {
  uint32_t addr;
  uint8_t id;
  uint8_t len; // Burst length - 1
  uint8_t size;
  uint8_t burst;
  uint8_t beat_cnt; // Current beat sent
  uint32_t latency_cnt;
  bool in_data_phase; // True if latency done, sending data
  bool complete;      // True when all beats sent and rlast accepted
};

// ============================================================================
// SimDDR Class with Outstanding + Burst-Drain Read Service
// ============================================================================
class SimDDR {
public:
  // ========== Simulator Interface ==========
  void init();

  // Two-phase combinational logic for proper signal timing
  void comb_outputs(); // Phase 1: arready, rvalid, rdata, bvalid, bresp
  void comb_inputs();  // Phase 2: Process arvalid, awvalid, wvalid
  void comb() {
    comb_outputs();
    comb_inputs();
  } // Convenience wrapper

  void seq();

  // ========== IO Ports ==========
  SimDDR_IO_t io;

  // ========== Debug ==========
  void print_state();

private:
  // ========== Write Channel ==========
  // Active write transaction (receiving W data)
  bool w_active;
  WriteTransaction w_current;

  // Pending write responses (in latency)
  std::queue<WriteRespPending> w_resp_queue;

  // ========== Read Channel with Burst-Drain Service ==========
  // Vector allows access to any transaction while preserving issue order.
  std::vector<ReadTransaction> r_transactions;

  // Round-robin index for fair burst-to-burst scheduling
  size_t r_rr_index;

  // Currently selected transaction index for this cycle (-1 if none)
  int r_selected_idx;

  // Active transaction whose burst is being drained.
  int r_active_idx;

  // ========== Combinational Logic Functions ==========
  void comb_write_channel();
  void comb_read_channel();

  // ========== Helper Functions ==========
  void do_memory_write(uint32_t addr, axi_data_t data, axi_strb_t wstrb);
  axi_data_t do_memory_read(uint32_t addr);

  // Find next ready transaction using round-robin once the current burst finishes
  int find_next_ready_transaction();
};

} // namespace sim_ddr
