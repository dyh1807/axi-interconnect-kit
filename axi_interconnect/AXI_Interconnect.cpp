/**
 * @file AXI_Interconnect.cpp
 * @brief AXI-Interconnect Layer Implementation
 *
 * AXI Protocol Compliance:
 * - AR/AW valid signals are latched until ready handshake
 * - Upstream req_valid can be deasserted without affecting AXI valid
 */

#include "AXI_Interconnect.h"
#include <algorithm>

extern long long sim_time;

namespace axi_interconnect {

namespace {
constexpr uint8_t kInvalidAxiReadId = 0xFF;
}

// ============================================================================
// Initialization
// ============================================================================
void AXI_Interconnect::init() {
  llc.set_config(llc_config);
  llc.reset();
  r_arb_rr_idx = 0;
  r_current_master = -1;
  r_pending.clear();
  for (int i = 0; i < NUM_READ_MASTERS; ++i) {
    llc_upstream_req[i] = {};
    llc_upstream_capture_c[i] = {};
    llc_upstream_accept_c[i] = false;
  }
  llc_mem_write_resp_valid_ = false;
  llc_mem_write_resp_ = 0;

  // Clear AR latch
  ar_latched.valid = false;
  ar_latched.to_llc = false;
  ar_latched.addr = 0;
  ar_latched.len = 0;
  ar_latched.size = 2;
  ar_latched.burst = sim_ddr::AXI_BURST_INCR;
  ar_latched.id = 0;
  ar_latched.master_id = 0;
  ar_latched.orig_id = 0;

  w_active = false;
  w_current = {};
  w_arb_rr_idx = 0;
  w_current_master = -1;

  // Clear AW latch
  aw_latched.valid = false;
  aw_latched.addr = 0;
  aw_latched.len = 0;
  aw_latched.size = 2;
  aw_latched.burst = sim_ddr::AXI_BURST_INCR;
  aw_latched.id = 0;

  // Clear registered req.ready signals
  for (int i = 0; i < NUM_READ_MASTERS; i++) {
    req_ready_r[i] = false;
    r_pending_age[i] = 0;
    r_pending_warned[i] = false;
    req_drop_warned[i] = false;
  }

  for (int i = 0; i < NUM_READ_MASTERS; i++) {
    read_ports[i].req.ready = false;
    read_ports[i].resp.valid = false;
    read_ports[i].resp.data.clear();
    read_ports[i].resp.id = 0;
    read_req_accepted[i] = false;
  }
  for (int i = 0; i < NUM_WRITE_MASTERS; i++) {
    write_ports[i].req.ready = false;
    write_ports[i].resp.valid = false;
    write_ports[i].resp.id = 0;
    write_ports[i].resp.resp = 0;
    w_req_ready_r[i] = false;
    w_resp_valid[i] = false;
    w_resp_id[i] = 0;
    w_resp_resp[i] = 0;
    write_req_accepted[i] = false;
  }

  axi_io.ar.arvalid = false;
  axi_io.ar.arid = 0;
  axi_io.ar.araddr = 0;
  axi_io.ar.arlen = 0;
  axi_io.ar.arsize = 2;
  axi_io.ar.arburst = sim_ddr::AXI_BURST_INCR;
  axi_io.r.rready = true;

  axi_io.aw.awvalid = false;
  axi_io.aw.awid = 0;
  axi_io.aw.awaddr = 0;
  axi_io.aw.awlen = 0;
  axi_io.aw.awsize = 2;
  axi_io.aw.awburst = sim_ddr::AXI_BURST_INCR;
  axi_io.w.wvalid = false;
  axi_io.w.wdata = 0;
  axi_io.w.wstrb = 0xF;
  axi_io.w.wlast = false;
  axi_io.b.bready = true;
}

uint8_t AXI_Interconnect::alloc_read_axi_id() const {
  bool used[1u << sim_ddr::AXI_ID_WIDTH] = {false};
  for (const auto &txn : r_pending) {
    used[txn.axi_id & ((1u << sim_ddr::AXI_ID_WIDTH) - 1u)] = true;
  }
  if (ar_latched.valid) {
    used[ar_latched.id & ((1u << sim_ddr::AXI_ID_WIDTH) - 1u)] = true;
  }
  for (uint8_t id = 0; id < (1u << sim_ddr::AXI_ID_WIDTH); ++id) {
    if (!used[id]) {
      return id;
    }
  }
  return kInvalidAxiReadId;
}

uint8_t AXI_Interconnect::count_master_read_pending(uint8_t master_id) const {
  uint8_t count = 0;
  for (const auto &txn : r_pending) {
    if (txn.master_id == master_id) {
      ++count;
    }
  }
  if (ar_latched.valid && ar_latched.master_id == master_id) {
    ++count;
  }
  return count;
}

uint8_t AXI_Interconnect::count_total_read_inflight() const {
  return static_cast<uint8_t>(r_pending.size() + (ar_latched.valid ? 1 : 0));
}

bool AXI_Interconnect::can_accept_read_master(uint8_t master_id) const {
  if (master_id >= NUM_READ_MASTERS) {
    return false;
  }
  if (count_total_read_inflight() >= MAX_OUTSTANDING) {
    return false;
  }
  if (count_master_read_pending(master_id) >= MAX_READ_OUTSTANDING_PER_MASTER) {
    return false;
  }
  return alloc_read_axi_id() != kInvalidAxiReadId;
}

bool AXI_Interconnect::can_issue_llc_read_req() const {
  return !ar_latched.valid && count_total_read_inflight() < MAX_OUTSTANDING &&
         alloc_read_axi_id() != kInvalidAxiReadId;
}

void AXI_Interconnect::prepare_llc_inputs() {
  llc.io.ext_in = {};

  if (!llc_enabled()) {
    return;
  }

  llc.io.ext_in.mem.invalidate_all = llc_invalidate_req_;
  bool any_upstream_capture_pending = false;
  bool any_upstream_req_visible = false;
  for (int master = 0; master < NUM_READ_MASTERS; ++master) {
    const bool capture_pending =
        !llc_upstream_req[master].valid && req_ready_r[master] &&
        read_ports[master].req.valid;
    any_upstream_capture_pending =
        any_upstream_capture_pending || capture_pending;
    any_upstream_req_visible = any_upstream_req_visible ||
                               llc_upstream_req[master].valid ||
                               read_ports[master].req.valid;

    llc.io.ext_in.upstream.read_req[master].valid = llc_upstream_req[master].valid;
    llc.io.ext_in.upstream.read_req[master].addr = llc_upstream_req[master].addr;
    llc.io.ext_in.upstream.read_req[master].total_size =
        llc_upstream_req[master].total_size;
    llc.io.ext_in.upstream.read_req[master].id = llc_upstream_req[master].id;
    llc.io.ext_in.upstream.read_req[master].bypass =
        llc_upstream_req[master].bypass;
    llc.io.ext_in.upstream.read_resp[master].ready = read_ports[master].resp.ready;
  }

  for (int master = 0; master < NUM_WRITE_MASTERS; ++master) {
    llc.io.ext_in.upstream.write_req[master].valid = write_ports[master].req.valid;
    llc.io.ext_in.upstream.write_req[master].addr = write_ports[master].req.addr;
    llc.io.ext_in.upstream.write_req[master].total_size =
        write_ports[master].req.total_size;
    llc.io.ext_in.upstream.write_req[master].id = write_ports[master].req.id;
    llc.io.ext_in.upstream.write_req[master].wdata = write_ports[master].req.wdata;
    llc.io.ext_in.upstream.write_req[master].wstrb = write_ports[master].req.wstrb;
    llc.io.ext_in.upstream.write_req[master].bypass =
        write_ports[master].req.bypass;
    llc.io.ext_in.upstream.write_resp[master].ready = write_ports[master].resp.ready;
  }

  llc.io.ext_in.mem.prefetch_allow =
      !any_upstream_capture_pending && !any_upstream_req_visible;
  llc.io.ext_in.mem.read_req_ready = can_issue_llc_read_req();
  llc.io.ext_in.mem.write_req_ready =
      !w_active && !aw_latched.valid && !llc_mem_write_resp_valid_;
  llc.io.ext_in.mem.write_resp_valid = llc_mem_write_resp_valid_;
  llc.io.ext_in.mem.write_resp = llc_mem_write_resp_;

  for (const auto &txn : r_pending) {
    if (!txn.to_llc || txn.beats_done != txn.total_beats) {
      continue;
    }
    llc.io.ext_in.mem.read_resp_valid = true;
    llc.io.ext_in.mem.read_resp_data = txn.data;
    llc.io.ext_in.mem.read_resp_id = txn.orig_id;
    break;
  }
}

// ============================================================================
// Two-Phase Combinational Logic
// ============================================================================

// Phase 1: Output signals for masters (run BEFORE cpu.cycle())
// Sets: port.resp.valid/data, port.req.ready (from register), DDR rready
void AXI_Interconnect::comb_outputs() {
  prepare_llc_inputs();
  llc.comb();

  // Response path: DDR → masters
  comb_read_response();
  comb_write_response();

  // Use registered req.ready values (set by previous cycle's comb_inputs)
  // This ensures ICache sees req.ready in the same cycle as it transitions
  for (int i = 0; i < NUM_READ_MASTERS; i++) {
    read_ports[i].req.ready = req_ready_r[i];
  }

  // If AR is latched (waiting for arready), also keep req.ready true
  if (ar_latched.valid) {
    if (ar_latched.master_id < NUM_READ_MASTERS) {
      read_ports[ar_latched.master_id].req.ready = true;
    }
  }

  // Registered write req.ready (two-phase timing)
  for (int i = 0; i < NUM_WRITE_MASTERS; i++) {
    if (llc_enabled()) {
      write_ports[i].req.ready =
          w_req_ready_r[i] || llc.io.ext_out.upstream.write_req[i].ready;
    } else {
      write_ports[i].req.ready = w_req_ready_r[i];
    }
  }
  if (aw_latched.valid && w_current_master >= 0 &&
      w_current_master < NUM_WRITE_MASTERS) {
    if (!llc_enabled()) {
      write_ports[w_current_master].req.ready = true;
    }
  }

  if (llc_enabled()) {
    for (int i = 0; i < NUM_READ_MASTERS; ++i) {
      read_ports[i].resp.valid = llc.io.ext_out.upstream.read_resp[i].valid;
      read_ports[i].resp.data = llc.io.ext_out.upstream.read_resp[i].data;
      read_ports[i].resp.id = llc.io.ext_out.upstream.read_resp[i].id;
    }
    for (int i = 0; i < NUM_WRITE_MASTERS; ++i) {
      if (w_resp_valid[i]) {
        write_ports[i].resp.valid = true;
        write_ports[i].resp.id = w_resp_id[i];
        write_ports[i].resp.resp = w_resp_resp[i];
      } else {
        write_ports[i].resp.valid = llc.io.ext_out.upstream.write_resp[i].valid;
        write_ports[i].resp.id = llc.io.ext_out.upstream.write_resp[i].id;
        write_ports[i].resp.resp = llc.io.ext_out.upstream.write_resp[i].resp;
      }
    }
  }
}

// Phase 2: Input signals from masters (run AFTER cpu.cycle())
// Processes: port.req.valid/addr, drives DDR AR/AW/W
void AXI_Interconnect::comb_inputs() {
  comb_read_arbiter();
  comb_write_request();
}

// ============================================================================
// Read Arbiter with Latched AR (AXI Compliant)
// ============================================================================
void AXI_Interconnect::comb_read_arbiter() {
  ar_from_llc_c = false;
  ar_llc_mem_id_c = 0;
  for (int i = 0; i < NUM_READ_MASTERS; ++i) {
    llc_upstream_accept_c[i] = false;
    llc_upstream_capture_c[i] = {};
  }
  bool req_ready_curr[NUM_READ_MASTERS];
  for (int i = 0; i < NUM_READ_MASTERS; i++) {
    req_ready_curr[i] = req_ready_r[i];
    req_ready_r[i] = false;
  }

  // Detect ready pulses without a corresponding valid (possible dropped req).
  for (int i = 0; i < NUM_READ_MASTERS; i++) {
    if (req_ready_curr[i] && !read_ports[i].req.valid && !req_drop_warned[i] &&
        DEBUG) {
      printf("[axi] ready without valid (drop) master=%d\n", i);
      req_drop_warned[i] = true;
    }
  }

  // Default: don't accept new requests
  for (int i = 0; i < NUM_READ_MASTERS; i++) {
    read_ports[i].req.ready = false;
  }

  // If AR is latched (waiting for arready), output latched values
  if (ar_latched.valid) {
    axi_io.ar.arvalid = true; // MUST stay valid until handshake!
    axi_io.ar.araddr = ar_latched.addr;
    axi_io.ar.arlen = ar_latched.len;
    axi_io.ar.arsize = ar_latched.size;
    axi_io.ar.arburst = ar_latched.burst;
    axi_io.ar.arid = ar_latched.id;
    // Keep req.ready=true for the master whose request is latched so the
    // upstream handshake remains visible until the downstream AR handshake wins.
    if (ar_latched.master_id < NUM_READ_MASTERS) {
      read_ports[ar_latched.master_id].req.ready = true;
      req_ready_r[ar_latched.master_id] = true;
    }
    return; // Cannot accept new requests while AR pending
  }

  // No latched AR, can accept new request
  axi_io.ar.arvalid = false;

  if (llc_enabled()) {
    if (llc.io.ext_out.mem.read_req_valid && can_issue_llc_read_req()) {
      ar_from_llc_c = true;
      ar_llc_mem_id_c = llc.io.ext_out.mem.read_req_id;
      axi_io.ar.arvalid = true;
      axi_io.ar.araddr = llc.io.ext_out.mem.read_req_addr;
      axi_io.ar.arlen = calc_burst_len(llc.io.ext_out.mem.read_req_size);
      axi_io.ar.arsize = 2;
      axi_io.ar.arburst = sim_ddr::AXI_BURST_INCR;
      axi_io.ar.arid = alloc_read_axi_id();
      return;
    }
    for (int master = 0; master < NUM_READ_MASTERS; ++master) {
      if (llc_upstream_req[master].valid || !read_ports[master].req.valid) {
        continue;
      }
      if (req_ready_curr[master]) {
        read_ports[master].req.ready = true;
        llc_upstream_accept_c[master] = true;
        llc_upstream_capture_c[master].valid = true;
        llc_upstream_capture_c[master].addr = read_ports[master].req.addr;
        llc_upstream_capture_c[master].total_size =
            read_ports[master].req.total_size;
        llc_upstream_capture_c[master].id = read_ports[master].req.id;
        llc_upstream_capture_c[master].bypass = read_ports[master].req.bypass;
        continue;
      }
      req_ready_r[master] = true;
      read_ports[master].req.ready = true;
    }
    return;
  }

  // If a master saw ready last cycle, complete that handshake first.
  for (int i = 0; i < NUM_READ_MASTERS; i++) {
    if (!req_ready_curr[i] || !read_ports[i].req.valid) {
      continue;
    }

    r_current_master = i;
    uint8_t axi_id = alloc_read_axi_id();
    if (axi_id == kInvalidAxiReadId) {
      continue;
    }
    axi_io.ar.arvalid = true;
    axi_io.ar.araddr = read_ports[i].req.addr;
    axi_io.ar.arlen = calc_burst_len(read_ports[i].req.total_size);
    axi_io.ar.arsize = 2;
    axi_io.ar.arburst = sim_ddr::AXI_BURST_INCR;
    axi_io.ar.arid = axi_id;
    read_ports[i].req.ready = true;
    return;
  }

  // Round-robin search for valid request
  for (int i = 0; i < NUM_READ_MASTERS; i++) {
    int idx = (r_arb_rr_idx + i) % NUM_READ_MASTERS;

    if (read_ports[idx].req.valid) {
      if (!can_accept_read_master(static_cast<uint8_t>(idx))) {
        continue;
      }

      r_current_master = idx;
      uint8_t axi_id = alloc_read_axi_id();
      if (axi_id == kInvalidAxiReadId) {
        continue;
      }

      // Raise ready first, then issue AR on following cycle when ready is seen.
      if (!req_ready_curr[idx]) {
        req_ready_r[idx] = true;
        read_ports[idx].req.ready = true;
        break;
      }

      // Output AR (will be latched in seq if not immediately ready)
      axi_io.ar.arvalid = true;
      axi_io.ar.araddr = read_ports[idx].req.addr;
      axi_io.ar.arlen = calc_burst_len(read_ports[idx].req.total_size);
      axi_io.ar.arsize = 2;
      axi_io.ar.arburst = sim_ddr::AXI_BURST_INCR;
      axi_io.ar.arid = axi_id;

      read_ports[idx].req.ready = true; // Also set for immediate use
      break;
    }
  }
}

void AXI_Interconnect::comb_read_response() {
  for (int i = 0; i < NUM_READ_MASTERS; i++) {
    read_ports[i].resp.valid = false;
  }
  axi_io.r.rready = true;

  // Present at most one completed response per master per cycle.
  bool master_has_resp[NUM_READ_MASTERS] = {false};
  for (auto &txn : r_pending) {
    if (txn.beats_done == txn.total_beats) {
      if (txn.to_llc) {
        continue;
      }
      uint8_t master = txn.master_id;
      if (!master_has_resp[master]) { // Only first complete per master
        read_ports[master].resp.valid = true;
        read_ports[master].resp.data = txn.data;
        read_ports[master].resp.id = txn.orig_id;
        master_has_resp[master] = true;
        // No break - continue to find responses for other masters
      }
    }
  }
}

// ============================================================================
// Write Request with Latched AW (AXI Compliant)
// ============================================================================
void AXI_Interconnect::comb_write_request() {
  bool w_req_ready_curr[NUM_WRITE_MASTERS];
  bool any_w_resp_valid = false;
  for (int i = 0; i < NUM_WRITE_MASTERS; i++) {
    w_req_ready_curr[i] = w_req_ready_r[i];
    w_req_ready_r[i] = false;
    any_w_resp_valid = any_w_resp_valid || w_resp_valid[i];
    if (w_req_ready_curr[i] && !write_ports[i].req.valid && DEBUG) {
      printf("[axi] write ready without valid (drop) master=%d\n", i);
    }
  }

  axi_io.w.wvalid = false;

  if (llc_enabled()) {
    bool any_direct_w_resp_valid = false;
    for (int i = 0; i < NUM_WRITE_MASTERS; ++i) {
      any_direct_w_resp_valid = any_direct_w_resp_valid || w_resp_valid[i];
    }
    if (aw_latched.valid) {
      axi_io.aw.awvalid = true;
      axi_io.aw.awaddr = aw_latched.addr;
      axi_io.aw.awlen = aw_latched.len;
      axi_io.aw.awsize = aw_latched.size;
      axi_io.aw.awburst = aw_latched.burst;
      axi_io.aw.awid = aw_latched.id;
    } else {
      axi_io.aw.awvalid = false;
      if (!w_active && !llc_mem_write_resp_valid_ && !any_direct_w_resp_valid) {
        for (int k = 0; k < NUM_WRITE_MASTERS; ++k) {
          const int idx = (w_arb_rr_idx + k) % NUM_WRITE_MASTERS;
          if (!w_req_ready_curr[idx] || !write_ports[idx].req.valid ||
              !write_ports[idx].req.bypass) {
            continue;
          }
          w_current_master = idx;
          axi_io.aw.awvalid = true;
          axi_io.aw.awaddr = write_ports[idx].req.addr;
          axi_io.aw.awlen = calc_burst_len(write_ports[idx].req.total_size);
          axi_io.aw.awsize = 2;
          axi_io.aw.awburst = sim_ddr::AXI_BURST_INCR;
          axi_io.aw.awid = ((idx & 0x1) << 3) | (write_ports[idx].req.id & 0x7);
          write_ports[idx].req.ready = true;
          break;
        }
      }
      if (!axi_io.aw.awvalid && !w_active && !llc_mem_write_resp_valid_ &&
          !any_direct_w_resp_valid && llc.io.ext_out.mem.write_req_valid) {
        axi_io.aw.awvalid = true;
        axi_io.aw.awaddr = llc.io.ext_out.mem.write_req_addr;
        axi_io.aw.awlen = calc_burst_len(llc.io.ext_out.mem.write_req_size);
        axi_io.aw.awsize = 2;
        axi_io.aw.awburst = sim_ddr::AXI_BURST_INCR;
        axi_io.aw.awid = llc.io.ext_out.mem.write_req_id & 0x7;
      }
      if (!w_active && !llc_mem_write_resp_valid_ && !any_direct_w_resp_valid &&
          !axi_io.aw.awvalid) {
        for (int k = 0; k < NUM_WRITE_MASTERS; ++k) {
          const int idx = (w_arb_rr_idx + k) % NUM_WRITE_MASTERS;
          if (!write_ports[idx].req.valid || !write_ports[idx].req.bypass) {
            continue;
          }
          if (!w_req_ready_curr[idx]) {
            w_req_ready_r[idx] = true;
            write_ports[idx].req.ready = true;
            break;
          }
        }
      }
    }

    if (w_active && w_current.aw_done && !w_current.w_done) {
      axi_io.w.wvalid = true;
      axi_io.w.wdata = w_current.wdata[w_current.beats_sent];
      axi_io.w.wstrb = static_cast<uint8_t>(
          w_current.wstrb.slice_u32(
              static_cast<uint32_t>(w_current.beats_sent) * 4) &
          0xFu);
      axi_io.w.wlast = (w_current.beats_sent == w_current.total_beats - 1);
    }
    return;
  }

  // If AW is latched (waiting for awready), output latched values
  if (aw_latched.valid) {
    axi_io.aw.awvalid = true; // MUST stay valid until handshake!
    axi_io.aw.awaddr = aw_latched.addr;
    axi_io.aw.awlen = aw_latched.len;
    axi_io.aw.awsize = aw_latched.size;
    axi_io.aw.awburst = aw_latched.burst;
    axi_io.aw.awid = aw_latched.id;
  } else {
    axi_io.aw.awvalid = false;

    // If a write master saw ready in previous cycle and keeps valid,
    // prioritize issuing its AW now.
    if (!w_active && !any_w_resp_valid) {
      for (int k = 0; k < NUM_WRITE_MASTERS; k++) {
        int idx = (w_arb_rr_idx + k) % NUM_WRITE_MASTERS;
        if (!w_req_ready_curr[idx] || !write_ports[idx].req.valid) {
          continue;
        }
        w_current_master = idx;
        axi_io.aw.awvalid = true;
        axi_io.aw.awaddr = write_ports[idx].req.addr;
        axi_io.aw.awlen = calc_burst_len(write_ports[idx].req.total_size);
        axi_io.aw.awsize = 2;
        axi_io.aw.awburst = sim_ddr::AXI_BURST_INCR;
        axi_io.aw.awid = ((idx & 0x1) << 3) | (write_ports[idx].req.id & 0x7);
        write_ports[idx].req.ready = true;
        return;
      }
    }

    // Ready-first handshake: raise req.ready one cycle before accepting.
    if (!w_active && !any_w_resp_valid) {
      for (int k = 0; k < NUM_WRITE_MASTERS; k++) {
        int idx = (w_arb_rr_idx + k) % NUM_WRITE_MASTERS;
        if (!write_ports[idx].req.valid) {
          continue;
        }
        if (!w_req_ready_curr[idx]) {
          w_req_ready_r[idx] = true;
          write_ports[idx].req.ready = true;
          break;
        }
      }
    }
  }

  // W channel: send data after AW done
  if (w_active && w_current.aw_done && !w_current.w_done) {
    axi_io.w.wvalid = true;
    axi_io.w.wdata = w_current.wdata[w_current.beats_sent];
    axi_io.w.wstrb = static_cast<uint8_t>(
        w_current.wstrb.slice_u32(static_cast<uint32_t>(w_current.beats_sent) * 4) &
        0xFu);
    axi_io.w.wlast = (w_current.beats_sent == w_current.total_beats - 1);
  }
}

void AXI_Interconnect::comb_write_response() {
  if (llc_enabled()) {
    bool any_direct_w_resp_valid = false;
    for (int i = 0; i < NUM_WRITE_MASTERS; ++i) {
      any_direct_w_resp_valid = any_direct_w_resp_valid || w_resp_valid[i];
    }
    axi_io.b.bready = !llc_mem_write_resp_valid_ && !any_direct_w_resp_valid;
    return;
  }

  bool any_w_resp_valid = false;
  for (int i = 0; i < NUM_WRITE_MASTERS; i++) {
    write_ports[i].resp.valid = w_resp_valid[i];
    write_ports[i].resp.id = w_resp_id[i];
    write_ports[i].resp.resp = w_resp_resp[i];
    any_w_resp_valid = any_w_resp_valid || w_resp_valid[i];
  }

  // Backpressure DDR if upstream hasn't consumed the response yet.
  axi_io.b.bready = !any_w_resp_valid;
}

// ============================================================================
// Sequential Logic
// ============================================================================
void AXI_Interconnect::seq() {
  constexpr uint32_t kPendingTimeout = 100000;
  bool llc_upstream_req_valid_prev[NUM_READ_MASTERS];
  for (int i = 0; i < NUM_READ_MASTERS; ++i) {
    llc_upstream_req_valid_prev[i] = llc_upstream_req[i].valid;
  }
  bool w_resp_valid_prev[NUM_WRITE_MASTERS];
  for (int i = 0; i < NUM_WRITE_MASTERS; ++i) {
    w_resp_valid_prev[i] = w_resp_valid[i];
  }
  const bool llc_mem_write_resp_valid_prev = llc_mem_write_resp_valid_;
  auto assert_llc_consumed_reads = [&]() {
    if (!llc_enabled()) {
      return;
    }
    for (int master = 0; master < NUM_READ_MASTERS; ++master) {
      if (!(llc_upstream_req_valid_prev[master] &&
            llc.io.ext_out.upstream.read_req[master].ready)) {
        continue;
      }
      bool retained = llc.io.regs.lookup_valid_r &&
                      llc.io.regs.lookup_master_r ==
                          static_cast<uint8_t>(master);
      for (uint32_t slot = 0; !retained && slot < llc_config.mshr_num &&
                                  slot < MAX_OUTSTANDING;
           ++slot) {
        const auto &entry = llc.io.regs.mshr[slot];
        retained = entry.valid && !entry.is_prefetch &&
                   entry.master == static_cast<uint8_t>(master);
      }
      retained = retained || llc.io.regs.read_resp_valid_r[master];
      if (!retained) {
        std::printf(
            "[axi][llc] consumed request without retained llc state "
            "master=%d sim_time=%lld addr=0x%08x id=%u bypass=%d\n",
            master, sim_time, llc_upstream_req[master].addr,
            static_cast<unsigned>(llc_upstream_req[master].id),
            static_cast<int>(llc_upstream_req[master].bypass));
        std::exit(1);
      }
    }
  };
  for (int i = 0; i < NUM_READ_MASTERS; i++) {
    read_req_accepted[i] = false;
  }
  for (int i = 0; i < NUM_WRITE_MASTERS; i++) {
    write_req_accepted[i] = false;
  }

  // ========== AR Channel with Latch ==========

  // If new AR request and NOT immediately ready, latch it
  if (axi_io.ar.arvalid && !ar_latched.valid && !axi_io.ar.arready) {
    int master_idx = -1;
    uint8_t orig_id = 0;
    if (ar_from_llc_c) {
      master_idx = 0;
      orig_id = ar_llc_mem_id_c;
    } else {
      for (int i = 0; i < NUM_READ_MASTERS; ++i) {
        if (read_ports[i].req.valid && read_ports[i].req.ready) {
          master_idx = i;
          orig_id = read_ports[i].req.id;
          break;
        }
      }
    }
    if (master_idx >= 0) {
      // Latch the request
      ar_latched.valid = true;
      ar_latched.addr = axi_io.ar.araddr;
      ar_latched.len = axi_io.ar.arlen;
      ar_latched.size = axi_io.ar.arsize;
      ar_latched.burst = axi_io.ar.arburst;
      ar_latched.id = axi_io.ar.arid;
      ar_latched.master_id = static_cast<uint8_t>(master_idx);
      ar_latched.orig_id = orig_id;
      ar_latched.to_llc = ar_from_llc_c;
    }
  }

  // AR handshake complete
  if (axi_io.ar.arvalid && axi_io.ar.arready) {
    ReadPendingTxn txn;
    if (ar_latched.valid) {
      // Use latched values
      txn.axi_id = ar_latched.id;
      txn.master_id = ar_latched.master_id;
      txn.orig_id = ar_latched.orig_id;
      txn.total_beats = ar_latched.len + 1;
      txn.to_llc = ar_latched.to_llc;
      ar_latched.valid = false; // Clear latch
      ar_latched.to_llc = false;
    } else {
      // Direct handshake (same cycle)
      int master_idx = -1;
      uint8_t orig_id = 0;
      if (ar_from_llc_c) {
        master_idx = 0;
        orig_id = ar_llc_mem_id_c;
      } else {
        for (int i = 0; i < NUM_READ_MASTERS; ++i) {
          if (read_ports[i].req.valid && read_ports[i].req.ready) {
            master_idx = i;
            orig_id = read_ports[i].req.id;
            break;
          }
        }
      }
      if (master_idx < 0) {
        goto read_handshake_done;
      }
      txn.axi_id = axi_io.ar.arid;
      txn.master_id = static_cast<uint8_t>(master_idx);
      txn.orig_id = orig_id;
      txn.total_beats = axi_io.ar.arlen + 1;
      txn.to_llc = ar_from_llc_c;
    }
    txn.beats_done = 0;
    txn.data.clear();
    r_pending.push_back(txn);
    r_arb_rr_idx = (txn.master_id + 1) % NUM_READ_MASTERS;
    if (txn.master_id < NUM_READ_MASTERS) {
      read_req_accepted[txn.master_id] = true;
    }

    // req_ready_r is recomputed in comb_read_arbiter.
  }
read_handshake_done:

  if (llc_enabled()) {
    for (int master = 0; master < NUM_READ_MASTERS; ++master) {
      if (llc_upstream_req_valid_prev[master] &&
          llc.io.ext_out.upstream.read_req[master].ready) {
        llc_upstream_req[master] = {};
        read_req_accepted[master] = true;
      }
      if (!llc_upstream_req_valid_prev[master] && llc_upstream_accept_c[master]) {
        llc_upstream_req[master] = llc_upstream_capture_c[master];
      }
    }
  }

  // R handshake
  if (axi_io.r.rvalid && axi_io.r.rready) {
    for (auto &txn : r_pending) {
      if (txn.axi_id == static_cast<uint8_t>(axi_io.r.rid & 0xF) &&
          txn.beats_done < txn.total_beats) {
        txn.data[txn.beats_done] = axi_io.r.rdata;
        txn.beats_done++;
        break;
      }
    }
  }

  // Response handshake
  for (int i = 0; i < NUM_READ_MASTERS; i++) {
    if (read_ports[i].resp.valid && read_ports[i].resp.ready) {
      auto it = std::find_if(r_pending.begin(), r_pending.end(),
                             [i](const ReadPendingTxn &t) {
                               return t.master_id == i &&
                                      !t.to_llc &&
                                      t.beats_done == t.total_beats;
                             });
      if (it != r_pending.end()) {
        r_pending.erase(it);
      }
    }
  }

  if (llc_enabled() && llc.io.ext_in.mem.read_resp_valid &&
      llc.io.ext_out.mem.read_resp_ready) {
    const uint8_t mem_id = llc.io.ext_in.mem.read_resp_id;
    auto it = std::find_if(r_pending.begin(), r_pending.end(),
                           [mem_id](const ReadPendingTxn &t) {
                             return t.to_llc && t.beats_done == t.total_beats;
                           });
    auto exact_it = std::find_if(r_pending.begin(), r_pending.end(),
                                 [mem_id](const ReadPendingTxn &t) {
                                   return t.to_llc &&
                                          t.beats_done == t.total_beats &&
                                          t.orig_id == mem_id;
                           });
    if (exact_it != r_pending.end()) {
      r_pending.erase(exact_it);
    } else if (it != r_pending.end()) {
      r_pending.erase(it);
    }
  }

  // Monitor long-lived pending reads per master.
  for (int i = 0; i < NUM_READ_MASTERS; i++) {
    bool has_pending = false;
    int beats_done = 0;
    int total_beats = 0;
    for (const auto &txn : r_pending) {
      if (txn.master_id == i) {
        has_pending = true;
        beats_done = txn.beats_done;
        total_beats = txn.total_beats;
        break;
      }
    }
    if (has_pending) {
      r_pending_age[i]++;
      if (r_pending_age[i] > kPendingTimeout && !r_pending_warned[i]) {
        printf("[axi] pending read timeout master=%d beats=%d/%d\n", i,
               beats_done, total_beats);
        r_pending_warned[i] = true;
      }
    } else {
      r_pending_age[i] = 0;
      r_pending_warned[i] = false;
    }
  }

  // ========== Write Channel ==========

  if (llc_enabled()) {
    for (int i = 0; i < NUM_READ_MASTERS; ++i) {
      if (llc.io.regs.read_resp_valid_r[i] && read_ports[i].resp.ready) {
        llc.io.reg_write.read_resp_valid_r[i] = false;
        llc.io.reg_write.read_resp_id_r[i] = 0;
        llc.io.reg_write.read_resp_data_r[i].clear();
      }
    }
    for (int i = 0; i < NUM_WRITE_MASTERS; ++i) {
      if (llc.io.regs.write_resp_valid_r[i] && write_ports[i].resp.ready) {
        llc.io.reg_write.write_resp_valid_r[i] = false;
        llc.io.reg_write.write_resp_id_r[i] = 0;
        llc.io.reg_write.write_resp_code_r[i] = 0;
      }
    }

    for (int i = 0; i < NUM_WRITE_MASTERS; ++i) {
      if (write_ports[i].req.valid && write_ports[i].req.bypass &&
          w_req_ready_r[i]) {
        write_ports[i].req.ready = true;
      }
      if (write_ports[i].req.valid && !write_ports[i].req.bypass &&
          llc.io.ext_out.upstream.write_req[i].ready) {
        write_req_accepted[i] = true;
      }
    }

    if (!w_active) {
      for (int k = 0; k < NUM_WRITE_MASTERS; ++k) {
        const int idx = (w_arb_rr_idx + k) % NUM_WRITE_MASTERS;
        if (!write_ports[idx].req.valid || !write_ports[idx].req.ready ||
            !write_ports[idx].req.bypass) {
          continue;
        }
        w_active = true;
        w_current.master_id = idx;
        w_current.orig_id = write_ports[idx].req.id;
        w_current.addr = write_ports[idx].req.addr;
        w_current.wdata = write_ports[idx].req.wdata;
        w_current.wstrb = write_ports[idx].req.wstrb;
        w_current.total_beats =
            calc_burst_len(write_ports[idx].req.total_size) + 1;
        w_current.beats_sent = 0;
        w_current.aw_done = false;
        w_current.w_done = false;
        w_current_master = idx;
        write_req_accepted[idx] = true;
        aw_latched.valid = true;
        aw_latched.addr = w_current.addr;
        aw_latched.len = w_current.total_beats - 1;
        aw_latched.size = 2;
        aw_latched.burst = sim_ddr::AXI_BURST_INCR;
        aw_latched.id = ((idx & 0x1) << 3) | (w_current.orig_id & 0x7);
        w_arb_rr_idx = (idx + 1) % NUM_WRITE_MASTERS;
        break;
      }
    }

    if (!w_active && llc.io.ext_out.mem.write_req_valid &&
        llc.io.ext_in.mem.write_req_ready) {
      w_active = true;
      w_current = {};
      w_current.addr = llc.io.ext_out.mem.write_req_addr;
      w_current.wdata = llc.io.ext_out.mem.write_req_data;
      w_current.wstrb = llc.io.ext_out.mem.write_req_strobe;
      w_current.orig_id = llc.io.ext_out.mem.write_req_id;
      w_current.total_beats =
          calc_burst_len(llc.io.ext_out.mem.write_req_size) + 1;
      w_current.beats_sent = 0;
      w_current.aw_done = false;
      w_current.w_done = false;
      w_current_master = -1;

      aw_latched.valid = true;
      aw_latched.addr = w_current.addr;
      aw_latched.len = w_current.total_beats - 1;
      aw_latched.size = 2;
      aw_latched.burst = sim_ddr::AXI_BURST_INCR;
      aw_latched.id = w_current.orig_id & 0x7;
    }

    if (axi_io.aw.awvalid && axi_io.aw.awready) {
      aw_latched.valid = false;
      w_current.aw_done = true;
    }

    if (axi_io.w.wvalid && axi_io.w.wready) {
      w_current.beats_sent++;
      if (axi_io.w.wlast) {
        w_current.w_done = true;
      }
    }

    if (axi_io.b.bvalid && axi_io.b.bready) {
      if (w_current_master >= 0 && w_current_master < NUM_WRITE_MASTERS) {
        w_resp_valid[w_current_master] = true;
        w_resp_id[w_current_master] = w_current.orig_id;
        w_resp_resp[w_current_master] = axi_io.b.bresp;
      } else {
        llc_mem_write_resp_valid_ = true;
        llc_mem_write_resp_ = axi_io.b.bresp;
      }
    }

    if (llc_mem_write_resp_valid_prev && llc.io.ext_out.mem.write_resp_ready) {
      llc_mem_write_resp_valid_ = false;
      llc_mem_write_resp_ = 0;
      w_active = false;
      w_current = {};
      w_current_master = -1;
    }

    if (w_current_master >= 0 && w_current_master < NUM_WRITE_MASTERS &&
        w_resp_valid_prev[w_current_master] &&
        write_ports[w_current_master].resp.ready) {
      w_resp_valid[w_current_master] = false;
      w_resp_id[w_current_master] = 0;
      w_resp_resp[w_current_master] = 0;
      w_active = false;
      w_current = {};
      w_current_master = -1;
    }

    llc.seq();
    assert_llc_consumed_reads();
    return;
  }

  // Accept new write request
  if (!w_active) {
    for (int k = 0; k < NUM_WRITE_MASTERS; k++) {
      int idx = (w_arb_rr_idx + k) % NUM_WRITE_MASTERS;
      if (!write_ports[idx].req.valid || !write_ports[idx].req.ready) {
        continue;
      }
      w_active = true;
      w_current.master_id = idx;
      w_current.orig_id = write_ports[idx].req.id;
      w_current.addr = write_ports[idx].req.addr;
      w_current.wdata = write_ports[idx].req.wdata;
      w_current.wstrb = write_ports[idx].req.wstrb;
      w_current.total_beats =
          calc_burst_len(write_ports[idx].req.total_size) + 1;
      w_current.beats_sent = 0;
      w_current.aw_done = false;
      w_current.w_done = false;
      w_current_master = idx;
      write_req_accepted[idx] = true;

      // Immediately latch AW (will stay valid until awready)
      aw_latched.valid = true;
      aw_latched.addr = w_current.addr;
      aw_latched.len = w_current.total_beats - 1;
      aw_latched.size = 2;
      aw_latched.burst = sim_ddr::AXI_BURST_INCR;
      aw_latched.id = ((idx & 0x1) << 3) | (w_current.orig_id & 0x7);
      w_arb_rr_idx = (idx + 1) % NUM_WRITE_MASTERS;
      break;
    }
  }

  // AW handshake
  if (axi_io.aw.awvalid && axi_io.aw.awready) {
    aw_latched.valid = false; // Clear latch
    w_current.aw_done = true;
  }

  // W handshake
  if (axi_io.w.wvalid && axi_io.w.wready) {
    w_current.beats_sent++;
    if (axi_io.w.wlast) {
      w_current.w_done = true;
    }
  }

  // B handshake
  if (axi_io.b.bvalid && axi_io.b.bready) {
    uint8_t master = (axi_io.b.bid >> 3) & 0x1;
    if (master < NUM_WRITE_MASTERS) {
      w_resp_valid[master] = true;
      w_resp_id[master] = axi_io.b.bid & 0x7;
      w_resp_resp[master] = axi_io.b.bresp;
    }
  }

  // Upstream response handshake (only one write outstanding is supported)
  if (w_current.master_id < NUM_WRITE_MASTERS &&
      write_ports[w_current.master_id].resp.valid &&
      write_ports[w_current.master_id].resp.ready) {
    w_resp_valid[w_current.master_id] = false;
    w_resp_id[w_current.master_id] = 0;
    w_resp_resp[w_current.master_id] = 0;
    w_active = false;
    w_current = {};
    w_current_master = -1;
  }

  llc.seq();
  assert_llc_consumed_reads();
}

void AXI_Interconnect::debug_print() {
  printf("  interconnect: ar_latched=%d r_pending=%zu w_active=%d\n",
         ar_latched.valid, r_pending.size(), w_active);
  if (ar_latched.valid) {
    printf("    ar_latched: master=%u addr=0x%08x len=%u id=0x%02x\n",
           ar_latched.master_id, ar_latched.addr, ar_latched.len,
           ar_latched.id);
  }
  if (!r_pending.empty()) {
    for (const auto &txn : r_pending) {
      printf("    r_pending: master=%u beats=%u/%u\n", txn.master_id,
             txn.beats_done, txn.total_beats);
    }
  }
  if (llc_enabled()) {
    printf("    llc: state=%u lookup_valid=%d lookup_issued=%d lookup_master=%u lookup_addr=0x%08x\n",
           static_cast<unsigned>(llc.io.regs.state),
           static_cast<int>(llc.io.regs.lookup_valid_r),
           static_cast<int>(llc.io.regs.lookup_issued_r),
           static_cast<unsigned>(llc.io.regs.lookup_master_r),
           llc.io.regs.lookup_addr_r);
    for (int i = 0; i < NUM_READ_MASTERS; ++i) {
      printf("    llc_upstream[%d]: valid=%d addr=0x%08x id=%u bypass=%d resp_valid=%d\n",
             i, static_cast<int>(llc_upstream_req[i].valid),
             llc_upstream_req[i].addr, static_cast<unsigned>(llc_upstream_req[i].id),
             static_cast<int>(llc_upstream_req[i].bypass),
             static_cast<int>(llc.io.regs.read_resp_valid_r[i]));
    }
    for (uint32_t i = 0; i < std::min<uint32_t>(llc_config.mshr_num, MAX_OUTSTANDING); ++i) {
      const auto &entry = llc.io.regs.mshr[i];
      printf("    llc_mshr[%u]: valid=%d bypass=%d prefetch=%d mem_issued=%d refill_valid=%d line=0x%08x master=%u id=%u\n",
             i, static_cast<int>(entry.valid), static_cast<int>(entry.bypass),
             static_cast<int>(entry.is_prefetch), static_cast<int>(entry.mem_req_issued),
             static_cast<int>(entry.refill_valid), entry.line_addr,
             static_cast<unsigned>(entry.master), static_cast<unsigned>(entry.id));
    }
    for (int i = 0; i < NUM_WRITE_MASTERS; ++i) {
      printf("    write_port[%d]: valid=%d ready=%d bypass=%d resp_valid=%d w_req_ready_r=%d\n",
             i, static_cast<int>(write_ports[i].req.valid),
             static_cast<int>(write_ports[i].req.ready),
             static_cast<int>(write_ports[i].req.bypass),
             static_cast<int>(w_resp_valid[i]),
             static_cast<int>(w_req_ready_r[i]));
    }
  }
}

// ============================================================================
// Helpers
// ============================================================================
uint8_t AXI_Interconnect::calc_burst_len(uint8_t total_size) {
  uint16_t bytes = static_cast<uint16_t>(total_size) + 1u;
  uint16_t beats = (bytes + 3u) / 4u;
  return beats > 0 ? static_cast<uint8_t>(beats - 1u) : 0;
}

} // namespace axi_interconnect
