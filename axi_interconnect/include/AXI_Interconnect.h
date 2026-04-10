#pragma once
/**
 * @file AXI_Interconnect.h
 * @brief AXI-Interconnect Layer
 *
 * Converts simplified master interfaces (single-beat, wide data) to
 * AXI4 protocol (multi-beat bursts) for connection to SimDDR.
 *
 * AXI Protocol Compliance:
 * - AR/AW valid signals are latched until ready handshake
 * - Upstream req_valid can be deasserted without affecting AXI valid
 */

#include "AXI_Interconnect_IO.h"
#include "AXI_LLC.h"
#include "SimDDR_IO.h"
#include "axi_interconnect_compat.h"
#include <deque>
#include <queue>
#include <vector>

namespace axi_interconnect {

// ============================================================================
// Latched AR/AW Requests (for AXI compliance)
// ============================================================================

// Latched AR request - holds values until arready
struct ARLatch_t {
  bool valid;
  bool accepted_upstream;
  bool to_llc;
  uint32_t addr;
  uint8_t len;
  uint8_t size;
  uint8_t burst;
  uint8_t id;
  uint8_t master_id;
  uint8_t orig_id;
};

// Latched AW request - holds values until awready
struct AWLatch_t {
  bool valid;
  uint32_t addr;
  uint8_t len;
  uint8_t size;
  uint8_t burst;
  uint8_t id;
};

// ============================================================================
// Pending Transaction Tracking
// ============================================================================

struct ReadPendingTxn {
  uint8_t axi_id;
  uint8_t master_id;
  uint8_t orig_id;
  uint8_t total_beats;
  uint8_t beats_done;
  uint32_t addr;
  bool to_llc;
  WideReadData_t data;
  uint32_t stall_cycles;
  uint8_t last_beats_done;
  bool timeout_warned;
};

struct LlcUpstreamReqLatch {
  bool valid = false;
  uint32_t addr = 0;
  uint8_t total_size = 0;
  uint8_t id = 0;
  bool bypass = false;
};

struct ReadReqHoldLatch {
  bool valid = false;
  uint32_t addr = 0;
  uint8_t total_size = 0;
  uint8_t id = 0;
  bool bypass = false;
};

struct LlcUpstreamWriteReqLatch {
  bool valid = false;
  uint32_t addr = 0;
  uint8_t total_size = 0;
  uint8_t id = 0;
  WideWriteData_t wdata{};
  WideWriteStrb_t wstrb{};
  bool bypass = false;
};

struct WritePendingTxn {
  uint8_t axi_id;
  uint8_t master_id;
  uint8_t orig_id;
  uint32_t addr;
  WideWriteData_t wdata;
  WideWriteStrb_t wstrb{};
  uint8_t total_beats;
  uint8_t beats_sent;
  bool aw_done;
  bool w_done;
  bool llc_victim_write;
};

// ============================================================================
// AXI_Interconnect Class
// ============================================================================

class AXI_Interconnect {
public:
  AXI_Interconnect() : write_port(write_ports[MASTER_DCACHE_W]) {}

  // Runtime control inputs for the shared AXI submodule.
  // For simulator-only bring-up, init() may seed these inputs from env vars,
  // but the active mode/offset seen by the datapath remains hardware-like:
  // the module observes these inputs at runtime and performs a flush when a
  // mode transition involving mode=2 is requested.
  wire<2> mode = 1;
  wire<32> llc_mapped_offset = 0;

  void init();
  void set_llc_config(const AXI_LLCConfig &config) {
    llc_config = config;
    llc.set_config(llc_config);
  }
  const AXI_LLCConfig &get_llc_config() const { return llc_config; }
  bool llc_enabled() const;
  void set_llc_lookup_in(const AXI_LLC_LookupIn_t &lookup_in) {
    llc.io.lookup_in = lookup_in;
  }
  void set_llc_invalidate_all(bool invalidate) { llc_invalidate_all_req_ = invalidate; }
  void set_llc_invalidate_line(bool valid, uint32_t addr) {
    llc_invalidate_line_valid_ = valid;
    llc_invalidate_line_addr_ = addr;
  }
  bool llc_invalidate_all_accepted() const {
    return llc.io.ext_out.mem.invalidate_all_accepted;
  }
  bool llc_invalidate_line_accepted() const {
    return llc.io.ext_out.mem.invalidate_line_accepted;
  }
  const AXI_LLC_TableOut_t &get_llc_table_out() const { return llc.io.table_out; }
  const AXI_LLCPerfCounters_t &get_llc_perf_counters() const {
    return llc.perf_counters();
  }

  // Two-phase combinational logic for proper signal timing
  void comb_outputs(); // Phase 1: Update resp signals for masters, req.ready
  void comb_inputs();  // Phase 2: Process req from masters, drive DDR AR/AW/W
  void comb() {
    comb_outputs();
    comb_inputs();
  } // Convenience wrapper

  void seq();

  void debug_print();

  // Upstream IO (Masters)
  ReadMasterPort_t read_ports[NUM_READ_MASTERS];
  WriteMasterPort_t write_ports[NUM_WRITE_MASTERS];
  // Backward-compatible alias to the primary write master.
  WriteMasterPort_t &write_port;

  // Downstream IO (to SimDDR)
  sim_ddr::SimDDR_IO_t axi_io;
  bool read_req_accepted[NUM_READ_MASTERS] = {};
  uint8_t read_req_accepted_id[NUM_READ_MASTERS] = {};
  bool write_req_accepted[NUM_WRITE_MASTERS] = {};

private:
  uint8_t count_master_read_pending(uint8_t master_id) const;
  uint8_t count_total_read_inflight() const;
  bool can_accept_read_master(uint8_t master_id) const;
  bool has_read_id_conflict(uint8_t master_id, uint8_t orig_id) const;
  uint8_t alloc_write_axi_id() const;
  bool can_accept_write_now() const;
  uint32_t count_llc_write_pending() const;
  int find_write_pending_by_axi_id(uint8_t axi_id) const;
  int find_next_aw_pending() const;
  int find_next_w_pending() const;
  void refresh_non_llc_w_active();

  // Read arbiter state
  uint8_t r_arb_rr_idx;
  int r_current_master;

  // Registered req.ready for each master (persists until handshake)
  bool req_ready_r[NUM_READ_MASTERS];
  bool req_drop_warned[NUM_READ_MASTERS];
  uint8_t w_arb_rr_idx;
  int w_current_master;
  bool w_req_ready_r[NUM_WRITE_MASTERS];
  bool write_req_fire_c[NUM_WRITE_MASTERS];

  // AR latch for AXI compliance
  ARLatch_t ar_latched;

  // Pending read transactions
  std::vector<ReadPendingTxn> r_pending;

  // Write state
  bool w_active;
  WritePendingTxn w_current;
  std::deque<WritePendingTxn> w_pending;
  bool w_resp_valid[NUM_WRITE_MASTERS];
  uint8_t w_resp_id[NUM_WRITE_MASTERS];
  uint8_t w_resp_resp[NUM_WRITE_MASTERS];

  // AW latch for AXI compliance
  AWLatch_t aw_latched;

  void comb_read_arbiter();
  void comb_read_response();
  void comb_write_request();
  void comb_write_response();
  void prepare_llc_inputs();
  bool can_issue_llc_read_req() const;
  bool has_same_line_write_hazard(uint32_t line_addr) const;

  uint8_t calc_burst_len(uint8_t total_size);
  uint8_t alloc_read_axi_id() const;
  void sample_runtime_controls();
  uint8_t requested_mode() const;
  uint32_t requested_llc_mapped_offset() const;
  bool mode_transition_needs_flush() const;
  bool invalidate_all_requested() const;
  bool request_in_mapped_window(uint32_t addr, uint8_t total_size) const;
  bool effective_llc_bypass(uint32_t addr, uint8_t total_size,
                            bool upstream_bypass) const;

  AXI_LLCConfig llc_config{};
  AXI_LLC llc{};
  bool llc_invalidate_all_req_ = false;
  bool llc_invalidate_line_valid_ = false;
  uint32_t llc_invalidate_line_addr_ = 0;
  ReadReqHoldLatch read_req_hold[NUM_READ_MASTERS] = {};
  LlcUpstreamReqLatch llc_upstream_req[NUM_READ_MASTERS] = {};
  LlcUpstreamReqLatch llc_upstream_capture_c[NUM_READ_MASTERS] = {};
  bool llc_upstream_accept_c[NUM_READ_MASTERS] = {};
  LlcUpstreamWriteReqLatch llc_upstream_write_req[NUM_WRITE_MASTERS] = {};
  LlcUpstreamWriteReqLatch llc_upstream_write_capture_c[NUM_WRITE_MASTERS] = {};
  bool llc_upstream_write_accept_c[NUM_WRITE_MASTERS] = {};
  std::deque<LlcUpstreamWriteReqLatch> llc_upstream_write_q[NUM_WRITE_MASTERS];
  bool llc_mem_write_resp_valid_ = false;
  uint8_t llc_mem_write_resp_ = 0;
  uint32_t llc_mem_ignored_b_count_ = 0;
  bool ar_from_llc_c = false;
  uint8_t ar_llc_mem_id_c = 0;
  int ar_master_c = -1;
  uint8_t ar_orig_id_c = 0;
  uint8_t runtime_mode_ = 1;
  uint32_t llc_mapped_offset_ = 0;
  static constexpr uint32_t kMappedLlcWindowBytes = 4u << 20;
};

} // namespace axi_interconnect
