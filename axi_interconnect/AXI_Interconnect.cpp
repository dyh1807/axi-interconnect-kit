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
#include <cstdio>

extern long long sim_time;

namespace axi_interconnect {

namespace {
constexpr uint8_t kInvalidAxiReadId = 0xFF;
constexpr uint8_t kAxiIdMask =
    static_cast<uint8_t>((1u << sim_ddr::AXI_ID_WIDTH) - 1u);
constexpr uint8_t kDownstreamBeatBytes = sim_ddr::AXI_DATA_BYTES;
constexpr uint8_t kDownstreamBeatWords =
    kDownstreamBeatBytes / static_cast<uint8_t>(sizeof(uint32_t));
constexpr uint8_t kDownstreamAxiSize = sim_ddr::AXI_SIZE_CODE;

#ifndef CONFIG_AXI_LLC_FOCUS_LINE0
#define CONFIG_AXI_LLC_FOCUS_LINE0 0u
#endif

#ifndef CONFIG_AXI_LLC_FOCUS_LINE1
#define CONFIG_AXI_LLC_FOCUS_LINE1 0u
#endif

#ifndef CONFIG_AXI_LLC_DEBUG_LOG
#define CONFIG_AXI_LLC_DEBUG_LOG 0
#endif

#ifndef SIM_DEBUG_PRINT
#define SIM_DEBUG_PRINT 0
#endif

#ifndef SIM_DEBUG_PRINT_CYCLE_BEGIN
#define SIM_DEBUG_PRINT_CYCLE_BEGIN 0LL
#endif

#ifndef SIM_DEBUG_PRINT_CYCLE_END
#define SIM_DEBUG_PRINT_CYCLE_END 0LL
#endif

bool interconnect_debug_active(long long cycle) {
  return SIM_DEBUG_PRINT &&
         cycle >= static_cast<long long>(SIM_DEBUG_PRINT_CYCLE_BEGIN) &&
         cycle <= static_cast<long long>(SIM_DEBUG_PRINT_CYCLE_END);
}

bool llc_focus_line(uint32_t line_addr) {
  if (CONFIG_AXI_LLC_DEBUG_LOG == 0) {
    return false;
  }
  return (CONFIG_AXI_LLC_FOCUS_LINE0 != 0u &&
          line_addr == static_cast<uint32_t>(CONFIG_AXI_LLC_FOCUS_LINE0)) ||
         (CONFIG_AXI_LLC_FOCUS_LINE1 != 0u &&
          line_addr == static_cast<uint32_t>(CONFIG_AXI_LLC_FOCUS_LINE1));
}

bool focus_read_line(uint32_t line_addr) { return llc_focus_line(line_addr); }

bool focus_write_line(uint32_t addr) {
  const uint32_t line_addr =
      addr & ~static_cast<uint32_t>(MAX_WRITE_TRANSACTION_BYTES - 1u);
  return llc_focus_line(line_addr);
}

bool focus_read_txn(const ReadPendingTxn &txn) {
  return focus_read_line(txn.addr);
}

bool trace_icache_read_txn(const ReadPendingTxn &txn, long long cycle) {
  return txn.master_id == MASTER_ICACHE && interconnect_debug_active(cycle);
}

bool trace_icache_llc_master(int master, long long cycle) {
  return master == MASTER_ICACHE && interconnect_debug_active(cycle);
}

uint32_t txn_word_count(const ReadPendingTxn &txn) {
  return std::min<uint32_t>(MAX_READ_TRANSACTION_WORDS,
                            static_cast<uint32_t>(txn.total_beats) *
                                kDownstreamBeatWords);
}

sim_ddr::axi_data_t pack_downstream_write_beat(const WideWriteData_t &wdata,
                                               uint8_t beat_idx) {
  sim_ddr::axi_data_t value = 0;
  const uint32_t base = static_cast<uint32_t>(beat_idx) * kDownstreamBeatWords;
  for (uint8_t word = 0; word < kDownstreamBeatWords; ++word) {
    const uint32_t idx = base + word;
    if (idx >= MAX_WRITE_TRANSACTION_WORDS) {
      break;
    }
    value |= static_cast<sim_ddr::axi_data_t>(
        static_cast<unsigned __int128>(wdata.words[idx]) << (word * 32u));
  }
  return value;
}

sim_ddr::axi_strb_t pack_downstream_write_strobe(const WideWriteStrb_t &wstrb,
                                                 uint8_t beat_idx) {
  sim_ddr::axi_strb_t mask = 0;
  const uint32_t first_byte =
      static_cast<uint32_t>(beat_idx) * kDownstreamBeatBytes;
  for (uint8_t byte = 0; byte < kDownstreamBeatBytes; ++byte) {
    if (wstrb.test(first_byte + byte)) {
      mask |= static_cast<sim_ddr::axi_strb_t>(1u << byte);
    }
  }
  return mask;
}

void unpack_downstream_read_beat(ReadPendingTxn &txn, sim_ddr::axi_data_t beat) {
  const uint32_t base =
      static_cast<uint32_t>(txn.beats_done) * kDownstreamBeatWords;
  for (uint8_t word = 0; word < kDownstreamBeatWords; ++word) {
    const uint32_t idx = base + word;
    if (idx >= MAX_READ_TRANSACTION_WORDS) {
      break;
    }
    txn.data[idx] = static_cast<uint32_t>(
        (static_cast<unsigned __int128>(beat) >> (word * 32u)) & 0xFFFFFFFFu);
  }
}

void dump_focus_read_txn(const char *tag, long long cyc,
                         const ReadPendingTxn &txn) {
  if (!focus_read_txn(txn) && !trace_icache_read_txn(txn, cyc)) {
    return;
  }
  std::printf(
      "[AXI-R][%s] cyc=%lld addr=0x%08x master=%u orig_id=%u axi_id=%u "
      "beats=%u/%u to_llc=%d data=[",
      tag, cyc, txn.addr, static_cast<unsigned>(txn.master_id),
      static_cast<unsigned>(txn.orig_id), static_cast<unsigned>(txn.axi_id),
      static_cast<unsigned>(txn.beats_done), static_cast<unsigned>(txn.total_beats),
      static_cast<int>(txn.to_llc));
  for (uint32_t word = 0; word < txn_word_count(txn); ++word) {
    std::printf("%s%08x", (word == 0) ? "" : " ",
                static_cast<unsigned>(txn.data[word]));
  }
  std::printf("]\n");
}

void dump_focus_read_words(const char *tag, long long cyc, const ReadPendingTxn &txn) {
  if (!txn.to_llc ||
      (!llc_focus_line(txn.addr) && !trace_icache_read_txn(txn, cyc))) {
    return;
  }
  std::printf(
      "[AXI-LLC][%s] cyc=%lld addr=0x%08x slot=%u axi_id=%u beats=%u/%u "
      "data=[%08x %08x %08x %08x]\n",
      tag, cyc, txn.addr, static_cast<unsigned>(txn.orig_id),
      static_cast<unsigned>(txn.axi_id), static_cast<unsigned>(txn.beats_done),
      static_cast<unsigned>(txn.total_beats), txn.data.words[0], txn.data.words[1],
      txn.data.words[2], txn.data.words[3]);
}

inline bool write_size_supported(uint8_t total_size) {
  return (static_cast<uint16_t>(total_size) + 1u) <=
         MAX_WRITE_TRANSACTION_BYTES;
}
constexpr uint8_t kInvalidAxiWriteId = 0xFF;
} // namespace

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
    read_req_hold[i] = {};
    llc_upstream_req[i] = {};
    llc_upstream_capture_c[i] = {};
    llc_upstream_accept_c[i] = false;
  }
  for (int i = 0; i < NUM_WRITE_MASTERS; ++i) {
    llc_upstream_write_req[i] = {};
    llc_upstream_write_capture_c[i] = {};
    llc_upstream_write_accept_c[i] = false;
    llc_upstream_write_q[i].clear();
  }
  llc_mem_write_resp_valid_ = false;
  llc_mem_write_resp_ = 0;
  llc_mem_ignored_b_count_ = 0;

  // Clear AR latch
  ar_latched.valid = false;
  ar_latched.accepted_upstream = false;
  ar_latched.to_llc = false;
  ar_latched.addr = 0;
  ar_latched.len = 0;
  ar_latched.size = kDownstreamAxiSize;
  ar_latched.burst = sim_ddr::AXI_BURST_INCR;
  ar_latched.id = 0;
  ar_latched.master_id = 0;
  ar_latched.orig_id = 0;

  w_active = false;
  w_current = {};
  w_pending.clear();
  w_arb_rr_idx = 0;
  w_current_master = -1;

  // Clear AW latch
  aw_latched.valid = false;
  aw_latched.addr = 0;
  aw_latched.len = 0;
  aw_latched.size = kDownstreamAxiSize;
  aw_latched.burst = sim_ddr::AXI_BURST_INCR;
  aw_latched.id = 0;

  // Clear registered req.ready signals
  for (int i = 0; i < NUM_READ_MASTERS; i++) {
    req_ready_r[i] = false;
    req_drop_warned[i] = false;
  }

  for (int i = 0; i < NUM_READ_MASTERS; i++) {
    read_ports[i].req.ready = false;
    read_ports[i].req.accepted = false;
    read_ports[i].req.accepted_id = 0;
    read_ports[i].resp.valid = false;
    read_ports[i].resp.data.clear();
    read_ports[i].resp.id = 0;
    read_req_accepted[i] = false;
    read_req_accepted_id[i] = 0;
  }
  for (int i = 0; i < NUM_WRITE_MASTERS; i++) {
    write_ports[i].req.ready = false;
    write_ports[i].req.accepted = false;
    write_ports[i].resp.valid = false;
    write_ports[i].resp.id = 0;
    write_ports[i].resp.resp = 0;
    w_req_ready_r[i] = false;
    write_req_fire_c[i] = false;
    w_resp_valid[i] = false;
    w_resp_id[i] = 0;
    w_resp_resp[i] = 0;
    write_req_accepted[i] = false;
  }

  axi_io.ar.arvalid = false;
  axi_io.ar.arid = 0;
  axi_io.ar.araddr = 0;
  axi_io.ar.arlen = 0;
  axi_io.ar.arsize = kDownstreamAxiSize;
  axi_io.ar.arburst = sim_ddr::AXI_BURST_INCR;
  axi_io.r.rready = true;

  axi_io.aw.awvalid = false;
  axi_io.aw.awid = 0;
  axi_io.aw.awaddr = 0;
  axi_io.aw.awlen = 0;
  axi_io.aw.awsize = kDownstreamAxiSize;
  axi_io.aw.awburst = sim_ddr::AXI_BURST_INCR;
  axi_io.w.wvalid = false;
  axi_io.w.wdata = 0;
  axi_io.w.wstrb =
      static_cast<sim_ddr::axi_strb_t>((1ull << kDownstreamBeatBytes) - 1ull);
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

uint8_t AXI_Interconnect::alloc_write_axi_id() const {
  bool used[1u << sim_ddr::AXI_ID_WIDTH] = {false};
  for (const auto &txn : w_pending) {
    used[txn.axi_id & ((1u << sim_ddr::AXI_ID_WIDTH) - 1u)] = true;
  }
  if (aw_latched.valid) {
    used[aw_latched.id & ((1u << sim_ddr::AXI_ID_WIDTH) - 1u)] = true;
  }
  for (uint8_t id = 0; id < (1u << sim_ddr::AXI_ID_WIDTH); ++id) {
    if (!used[id]) {
      return id;
    }
  }
  return kInvalidAxiWriteId;
}

bool AXI_Interconnect::can_accept_write_now() const {
  return !llc_enabled() &&
         w_pending.size() < MAX_WRITE_OUTSTANDING &&
         alloc_write_axi_id() != kInvalidAxiWriteId;
}

uint32_t AXI_Interconnect::count_llc_write_pending() const {
  uint32_t count = 0;
  for (int i = 0; i < NUM_WRITE_MASTERS; ++i) {
    count += llc_upstream_write_req[i].valid ? 1u : 0u;
    count += static_cast<uint32_t>(llc_upstream_write_q[i].size());
  }
  return count;
}

bool AXI_Interconnect::has_same_line_write_hazard(uint32_t line_addr) const {
  if (!llc_enabled()) {
    return false;
  }
  for (int master = 0; master < NUM_WRITE_MASTERS; ++master) {
    if (llc_upstream_write_req[master].valid &&
        AXI_LLC::line_addr(llc_config, llc_upstream_write_req[master].addr) ==
            line_addr) {
      return true;
    }
    for (const auto &entry : llc_upstream_write_q[master]) {
      if (entry.valid && AXI_LLC::line_addr(llc_config, entry.addr) == line_addr) {
        return true;
      }
    }
    if (write_ports[master].req.valid &&
        AXI_LLC::line_addr(llc_config, write_ports[master].req.addr) == line_addr) {
      return true;
    }
  }
  for (int master = 0; master < NUM_WRITE_MASTERS; ++master) {
    const auto &ctx = llc.io.regs.write_ctx[master];
    if (ctx.valid && ctx.line_addr == line_addr) {
      return true;
    }
    if (llc.io.regs.write_resp_valid_r[master] &&
        llc.io.regs.write_resp_line_addr_r[master] == line_addr) {
      return true;
    }
  }
  for (uint8_t master = 0; master < NUM_WRITE_MASTERS; ++master) {
    for (uint32_t i = 0;
         i < llc.io.regs.write_q_count_r[master] && i < MAX_WRITE_OUTSTANDING; ++i) {
      const uint32_t slot =
          (llc.io.regs.write_q_head_r[master] + i) % MAX_WRITE_OUTSTANDING;
      const auto &entry = llc.io.regs.write_q[master][slot];
      if (!entry.valid) {
        continue;
      }
      if (AXI_LLC::line_addr(llc_config, entry.addr) == line_addr) {
        return true;
      }
    }
  }
  if (w_active && AXI_LLC::line_addr(llc_config, w_current.addr) == line_addr) {
    return true;
  }
  if (aw_latched.valid &&
      AXI_LLC::line_addr(llc_config, aw_latched.addr) == line_addr) {
    return true;
  }
  return false;
}

int AXI_Interconnect::find_write_pending_by_axi_id(uint8_t axi_id) const {
  for (size_t i = 0; i < w_pending.size(); ++i) {
    if (w_pending[i].axi_id == axi_id) {
      return static_cast<int>(i);
    }
  }
  return -1;
}

int AXI_Interconnect::find_next_aw_pending() const {
  for (size_t i = 0; i < w_pending.size(); ++i) {
    if (!w_pending[i].aw_done) {
      return static_cast<int>(i);
    }
  }
  return -1;
}

int AXI_Interconnect::find_next_w_pending() const {
  for (size_t i = 0; i < w_pending.size(); ++i) {
    if (w_pending[i].aw_done && !w_pending[i].w_done) {
      return static_cast<int>(i);
    }
  }
  return -1;
}

void AXI_Interconnect::refresh_non_llc_w_active() {
  if (llc_enabled()) {
    return;
  }
  if (w_active) {
    return;
  }
  const int idx = find_next_w_pending();
  if (idx < 0) {
    w_current = {};
    w_current_master = -1;
    return;
  }
  w_current = w_pending[static_cast<size_t>(idx)];
  w_active = true;
  w_current_master = w_current.master_id;
  if (focus_write_line(w_current.addr)) {
    std::printf(
        "[AXI-W][SELECT] cyc=%lld axi_id=%u master=%u addr=0x%08x beats=%u "
        "beats_sent=%u aw_done=%d w_done=%d\n",
        sim_time, static_cast<unsigned>(w_current.axi_id),
        static_cast<unsigned>(w_current.master_id), w_current.addr,
        static_cast<unsigned>(w_current.total_beats),
        static_cast<unsigned>(w_current.beats_sent),
        static_cast<int>(w_current.aw_done), static_cast<int>(w_current.w_done));
  }
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

bool AXI_Interconnect::has_read_id_conflict(uint8_t master_id,
                                            uint8_t orig_id) const {
  if (ar_latched.valid && !ar_latched.to_llc &&
      ar_latched.master_id == master_id && ar_latched.orig_id == orig_id) {
    return true;
  }
  for (const auto &txn : r_pending) {
    if (txn.master_id == master_id && txn.orig_id == orig_id) {
      return true;
    }
  }
  if (llc_enabled()) {
    if (llc_upstream_req[master_id].valid && llc_upstream_req[master_id].id == orig_id) {
      return true;
    }
    if (llc.io.regs.read_resp_valid_r[master_id] &&
        llc.io.regs.read_resp_id_r[master_id] == orig_id) {
      return true;
    }
    if (llc.io.regs.lookup_valid_r &&
        llc.io.regs.lookup_master_r == master_id &&
        llc.io.regs.lookup_id_r == orig_id) {
      return true;
    }
    for (uint32_t slot = 0; slot < llc_config.mshr_num && slot < MAX_OUTSTANDING;
         ++slot) {
      const auto &entry = llc.io.regs.mshr[slot];
      if (entry.valid && !entry.is_prefetch && entry.master == master_id &&
          entry.id == orig_id) {
        return true;
      }
    }
  }
  return false;
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

  llc.io.ext_in.mem.invalidate_all = llc_invalidate_all_req_;
  const uint32_t invalidate_line_addr =
      AXI_LLC::line_addr(llc_config, llc_invalidate_line_addr_);
  const bool line_hazard =
      llc_invalidate_line_valid_ &&
      has_same_line_write_hazard(invalidate_line_addr);
  llc.io.ext_in.mem.invalidate_line_valid =
      llc_invalidate_line_valid_ && !line_hazard;
  llc.io.ext_in.mem.invalidate_line_addr = llc_invalidate_line_addr_;
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
    llc.io.ext_in.upstream.write_req[master].valid =
        llc_upstream_write_req[master].valid;
    llc.io.ext_in.upstream.write_req[master].addr = llc_upstream_write_req[master].addr;
    llc.io.ext_in.upstream.write_req[master].total_size =
        llc_upstream_write_req[master].total_size;
    llc.io.ext_in.upstream.write_req[master].id = llc_upstream_write_req[master].id;
    llc.io.ext_in.upstream.write_req[master].wdata = llc_upstream_write_req[master].wdata;
    llc.io.ext_in.upstream.write_req[master].wstrb = llc_upstream_write_req[master].wstrb;
    llc.io.ext_in.upstream.write_req[master].bypass =
        llc_upstream_write_req[master].bypass;
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
    dump_focus_read_words("MEM-RSP-FWD", sim_time, txn);
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
    const bool llc_slot_busy =
        llc_enabled() && llc_upstream_req[i].valid && !ar_latched.valid;
    read_ports[i].req.ready =
        req_ready_r[i] && !llc_slot_busy && !(llc_enabled() && llc_invalidate_all_req_);
    read_ports[i].req.accepted = read_req_accepted[i];
    read_ports[i].req.accepted_id = read_req_accepted_id[i];
  }

  // If AR is latched (waiting for arready), also keep req.ready true
  if (ar_latched.valid) {
    if (!ar_latched.to_llc && ar_latched.master_id < NUM_READ_MASTERS) {
      read_ports[ar_latched.master_id].req.ready = true;
    }
  }

  // Registered write req.ready (two-phase timing)
  for (int i = 0; i < NUM_WRITE_MASTERS; i++) {
    write_ports[i].req.accepted = write_req_accepted[i];
    if (llc_enabled()) {
      const bool llc_slot_busy = llc_upstream_write_req[i].valid;
      const bool blocked_by_line_invalidate =
          llc_invalidate_line_valid_ && write_ports[i].req.valid &&
          AXI_LLC::line_addr(llc_config, write_ports[i].req.addr) ==
              AXI_LLC::line_addr(llc_config, llc_invalidate_line_addr_);
      write_ports[i].req.ready =
          !llc_invalidate_all_req_ &&
          !blocked_by_line_invalidate &&
          (w_req_ready_r[i] ||
           (!llc_slot_busy && llc.io.ext_out.upstream.write_req[i].ready));
    } else {
      write_ports[i].req.ready = w_req_ready_r[i];
    }
  }
  if (llc_enabled()) {
    for (int i = 0; i < NUM_READ_MASTERS; ++i) {
      read_ports[i].resp.valid = llc.io.ext_out.upstream.read_resp[i].valid;
      read_ports[i].resp.data = llc.io.ext_out.upstream.read_resp[i].data;
      read_ports[i].resp.id = llc.io.ext_out.upstream.read_resp[i].id;
    }
    for (int i = 0; i < NUM_WRITE_MASTERS; ++i) {
      write_ports[i].resp.valid = llc.io.ext_out.upstream.write_resp[i].valid;
      write_ports[i].resp.id = llc.io.ext_out.upstream.write_resp[i].id;
      write_ports[i].resp.resp = llc.io.ext_out.upstream.write_resp[i].resp;
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
  ar_master_c = -1;
  ar_orig_id_c = 0;
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
    if (req_ready_curr[i] && !read_ports[i].req.valid) {
      read_req_hold[i] = {};
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
    if (!ar_latched.to_llc && !ar_latched.accepted_upstream &&
        ar_latched.master_id < NUM_READ_MASTERS) {
      read_ports[ar_latched.master_id].req.ready = true;
      req_ready_r[ar_latched.master_id] = true;
    }
    return; // Cannot accept new requests while AR pending
  }

  // No latched AR, can accept new request
  axi_io.ar.arvalid = false;

  if (llc_enabled()) {
    if (llc.io.ext_out.mem.read_req_valid && can_issue_llc_read_req()) {
      if (llc_focus_line(llc.io.ext_out.mem.read_req_addr)) {
        std::printf(
            "[AXI-LLC][AR-ISSUE] cyc=%lld addr=0x%08x slot=%u size=%u\n",
            sim_time, llc.io.ext_out.mem.read_req_addr,
            static_cast<unsigned>(llc.io.ext_out.mem.read_req_id),
            static_cast<unsigned>(llc.io.ext_out.mem.read_req_size));
      }
      ar_from_llc_c = true;
      ar_llc_mem_id_c = llc.io.ext_out.mem.read_req_id;
      axi_io.ar.arvalid = true;
      axi_io.ar.araddr = llc.io.ext_out.mem.read_req_addr;
      axi_io.ar.arlen = calc_burst_len(llc.io.ext_out.mem.read_req_size);
      axi_io.ar.arsize = kDownstreamAxiSize;
      axi_io.ar.arburst = sim_ddr::AXI_BURST_INCR;
      axi_io.ar.arid = alloc_read_axi_id();
    }
    for (int master = 0; master < NUM_READ_MASTERS; ++master) {
      if (llc_upstream_req[master].valid || !read_ports[master].req.valid ||
          llc_invalidate_all_req_) {
        continue;
      }
      if (has_read_id_conflict(static_cast<uint8_t>(master),
                               static_cast<uint8_t>(read_ports[master].req.id))) {
        continue;
      }
      const bool allow_same_cycle_accept = (master == MASTER_DCACHE_R);
      if (req_ready_curr[master] || allow_same_cycle_accept) {
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
    ReadReqHoldLatch cap =
        read_req_hold[i].valid
            ? read_req_hold[i]
            : ReadReqHoldLatch{true,
                               static_cast<uint32_t>(read_ports[i].req.addr),
                               static_cast<uint8_t>(read_ports[i].req.total_size),
                               static_cast<uint8_t>(read_ports[i].req.id),
                               static_cast<bool>(read_ports[i].req.bypass)};
    const bool hold_matches_current =
        read_req_hold[i].valid &&
        cap.addr == static_cast<uint32_t>(read_ports[i].req.addr) &&
        cap.total_size ==
            static_cast<uint8_t>(read_ports[i].req.total_size) &&
        cap.id == static_cast<uint8_t>(read_ports[i].req.id) &&
        cap.bypass == static_cast<bool>(read_ports[i].req.bypass);
    if (read_req_hold[i].valid && !hold_matches_current) {
      const uint32_t old_addr = cap.addr;
      cap = ReadReqHoldLatch{true,
                             static_cast<uint32_t>(read_ports[i].req.addr),
                             static_cast<uint8_t>(read_ports[i].req.total_size),
                             static_cast<uint8_t>(read_ports[i].req.id),
                             static_cast<bool>(read_ports[i].req.bypass)};
      read_req_hold[i] = cap;
      if (i == MASTER_ICACHE && interconnect_debug_active(sim_time)) {
        std::printf(
            "[AXI-R][HOLD-REFRESH] cyc=%lld master=%d old_addr=0x%08x "
            "new_addr=0x%08x id=%u\n",
            sim_time, i, old_addr, cap.addr,
            static_cast<unsigned>(cap.id));
      }
    }
    if (has_read_id_conflict(static_cast<uint8_t>(i), cap.id)) {
      continue;
    }

    r_current_master = i;
    ar_master_c = i;
    ar_orig_id_c = cap.id;
    uint8_t axi_id = alloc_read_axi_id();
    if (axi_id == kInvalidAxiReadId) {
      continue;
    }
    axi_io.ar.arvalid = true;
    axi_io.ar.araddr = cap.addr;
    axi_io.ar.arlen = calc_burst_len(cap.total_size);
    axi_io.ar.arsize = kDownstreamAxiSize;
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
      if (has_read_id_conflict(static_cast<uint8_t>(idx),
                               static_cast<uint8_t>(read_ports[idx].req.id))) {
        continue;
      }

      r_current_master = idx;
      uint8_t axi_id = alloc_read_axi_id();
      if (axi_id == kInvalidAxiReadId) {
        continue;
      }

      const bool allow_same_cycle_accept = (idx == MASTER_DCACHE_R);
      const bool require_ready_first = !allow_same_cycle_accept;
      if (require_ready_first && !req_ready_curr[idx]) {
        req_ready_r[idx] = true;
        read_ports[idx].req.ready = true;
        read_req_hold[idx].valid = true;
        read_req_hold[idx].addr = read_ports[idx].req.addr;
        read_req_hold[idx].total_size =
            static_cast<uint8_t>(read_ports[idx].req.total_size);
        read_req_hold[idx].id = static_cast<uint8_t>(read_ports[idx].req.id);
        read_req_hold[idx].bypass = read_ports[idx].req.bypass;
        break;
      }

      // Data-side masters can use same-cycle accept to keep the AR issue rate
      // from being artificially halved. ICache still relies on ready-first
      // semantics internally, so preserve the existing two-cycle contract
      // there until the front-end request state machine is updated.
      axi_io.ar.arvalid = true;
      axi_io.ar.araddr = read_ports[idx].req.addr;
      axi_io.ar.arlen = calc_burst_len(read_ports[idx].req.total_size);
      axi_io.ar.arsize = kDownstreamAxiSize;
      axi_io.ar.arburst = sim_ddr::AXI_BURST_INCR;
      axi_io.ar.arid = axi_id;
      read_ports[idx].req.ready = true;
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
        if (!txn.to_llc &&
            (focus_read_txn(txn) || trace_icache_read_txn(txn, sim_time))) {
          dump_focus_read_txn("RESP-DRIVE", sim_time, txn);
        }
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
    write_req_fire_c[i] = false;
    llc_upstream_write_accept_c[i] = false;
    llc_upstream_write_capture_c[i] = {};
    any_w_resp_valid = any_w_resp_valid || w_resp_valid[i];
    if (w_req_ready_curr[i] && !write_ports[i].req.valid && DEBUG) {
      printf("[axi] write ready without valid (drop) master=%d\n", i);
    }
  }

  axi_io.w.wvalid = false;

  if (llc_enabled()) {
    if (aw_latched.valid) {
      axi_io.aw.awvalid = true;
      axi_io.aw.awaddr = aw_latched.addr;
      axi_io.aw.awlen = aw_latched.len;
      axi_io.aw.awsize = aw_latched.size;
      axi_io.aw.awburst = aw_latched.burst;
      axi_io.aw.awid = aw_latched.id;
    } else {
      axi_io.aw.awvalid = false;
      if (!w_active && !llc_mem_write_resp_valid_ &&
          llc.io.ext_out.mem.write_req_valid) {
        axi_io.aw.awvalid = true;
        axi_io.aw.awaddr = llc.io.ext_out.mem.write_req_addr;
        axi_io.aw.awlen = calc_burst_len(llc.io.ext_out.mem.write_req_size);
        axi_io.aw.awsize = kDownstreamAxiSize;
        axi_io.aw.awburst = sim_ddr::AXI_BURST_INCR;
        axi_io.aw.awid = llc.io.ext_out.mem.write_req_id & 0x7;
      }
    }

    const bool llc_write_queue_has_space =
        count_llc_write_pending() < MAX_WRITE_OUTSTANDING;
    if (llc_write_queue_has_space && !llc_invalidate_all_req_) {
      for (int k = 0; k < NUM_WRITE_MASTERS; ++k) {
        const int idx = (w_arb_rr_idx + k) % NUM_WRITE_MASTERS;
        if (!write_ports[idx].req.valid) {
          continue;
        }
        const bool blocked_by_line_invalidate =
            llc_invalidate_line_valid_ &&
            AXI_LLC::line_addr(llc_config, write_ports[idx].req.addr) ==
                AXI_LLC::line_addr(llc_config, llc_invalidate_line_addr_);
        if (blocked_by_line_invalidate) {
          continue;
        }
        if (w_req_ready_curr[idx]) {
          write_ports[idx].req.ready = true;
          llc_upstream_write_accept_c[idx] = true;
          llc_upstream_write_capture_c[idx].valid = true;
          llc_upstream_write_capture_c[idx].addr = write_ports[idx].req.addr;
          llc_upstream_write_capture_c[idx].total_size =
              write_ports[idx].req.total_size;
          llc_upstream_write_capture_c[idx].id = write_ports[idx].req.id;
          llc_upstream_write_capture_c[idx].wdata = write_ports[idx].req.wdata;
          llc_upstream_write_capture_c[idx].wstrb = write_ports[idx].req.wstrb;
          llc_upstream_write_capture_c[idx].bypass = write_ports[idx].req.bypass;
          break;
        }
        w_req_ready_r[idx] = true;
        write_ports[idx].req.ready = true;
        break;
      }
    }

    if (w_active && w_current.aw_done && !w_current.w_done) {
      axi_io.w.wvalid = true;
      axi_io.w.wdata =
          pack_downstream_write_beat(w_current.wdata, w_current.beats_sent);
      axi_io.w.wstrb =
          pack_downstream_write_strobe(w_current.wstrb, w_current.beats_sent);
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
    if (!any_w_resp_valid) {
      const int aw_idx = find_next_aw_pending();
      if (aw_idx >= 0) {
        const auto &txn = w_pending[static_cast<size_t>(aw_idx)];
        axi_io.aw.awvalid = true;
        axi_io.aw.awaddr = txn.addr;
        axi_io.aw.awlen = txn.total_beats - 1;
        axi_io.aw.awsize = kDownstreamAxiSize;
        axi_io.aw.awburst = sim_ddr::AXI_BURST_INCR;
        axi_io.aw.awid = txn.axi_id;
      }
    }

    // Ready-first handshake: raise req.ready one cycle before accepting.
    if (can_accept_write_now() && !any_w_resp_valid) {
      for (int k = 0; k < NUM_WRITE_MASTERS; k++) {
        int idx = (w_arb_rr_idx + k) % NUM_WRITE_MASTERS;
        if (!write_ports[idx].req.valid) {
          continue;
        }
        if (!write_size_supported(write_ports[idx].req.total_size)) {
          printf("[axi] write size too large total_size=%u master=%d\n",
                 static_cast<unsigned>(write_ports[idx].req.total_size), idx);
          continue;
        }
        if (w_req_ready_curr[idx]) {
          write_ports[idx].req.ready = true;
          write_req_fire_c[idx] = true;
          break;
        } else {
          w_req_ready_r[idx] = true;
          write_ports[idx].req.ready = true;
        }
        break;
      }
    }
  }

  // W channel: send data after AW done
  if (w_active && w_current.aw_done && !w_current.w_done) {
    axi_io.w.wvalid = true;
    axi_io.w.wdata =
        pack_downstream_write_beat(w_current.wdata, w_current.beats_sent);
    axi_io.w.wstrb =
        pack_downstream_write_strobe(w_current.wstrb, w_current.beats_sent);
    axi_io.w.wlast = (w_current.beats_sent == w_current.total_beats - 1);
  }
}

void AXI_Interconnect::comb_write_response() {
  if (llc_enabled()) {
    axi_io.b.bready =
        (llc_mem_ignored_b_count_ > 0) || !llc_mem_write_resp_valid_;
    return;
  }

  bool any_w_resp_valid = false;
  for (int i = 0; i < NUM_WRITE_MASTERS; i++) {
    write_ports[i].req.accepted = write_req_accepted[i];
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
  decltype(llc_upstream_req) llc_upstream_req_prev{};
  for (int i = 0; i < NUM_READ_MASTERS; ++i) {
    llc_upstream_req_prev[i] = llc_upstream_req[i];
  }
  for (int i = 0; i < NUM_READ_MASTERS; ++i) {
    llc_upstream_req_valid_prev[i] = llc_upstream_req[i].valid;
  }
  bool llc_upstream_write_req_valid_prev[NUM_WRITE_MASTERS];
  for (int i = 0; i < NUM_WRITE_MASTERS; ++i) {
    llc_upstream_write_req_valid_prev[i] = llc_upstream_write_req[i].valid;
  }
  const bool llc_mem_write_resp_valid_prev = llc_mem_write_resp_valid_;
  auto assert_llc_consumed_reads = [&]() {
    if (!llc_enabled()) {
      return;
    }
    auto read_resp_queue_has_id = [&](int master, uint8_t id) {
      const uint8_t count = llc.io.regs.read_resp_q_count_r[master];
      const uint8_t head = llc.io.regs.read_resp_q_head_r[master];
      for (uint8_t off = 0; off < count; ++off) {
        const uint8_t slot =
            static_cast<uint8_t>((head + off) % AXI_LLC_READ_RESP_QUEUE_DEPTH);
        if (llc.io.regs.read_resp_q_id_r[master][slot] == id) {
          return true;
        }
      }
      return false;
    };
    for (int master = 0; master < NUM_READ_MASTERS; ++master) {
      if (!(llc_upstream_req_valid_prev[master] &&
            llc.io.ext_out.upstream.read_req[master].ready)) {
        continue;
      }
      const auto &consumed_req = llc_upstream_req_prev[master];
      bool retained = llc.io.regs.lookup_valid_r &&
                      llc.io.regs.lookup_master_r ==
                          static_cast<uint8_t>(master) &&
                      llc.io.regs.lookup_id_r ==
                          consumed_req.id;
      for (uint32_t slot = 0; !retained && slot < llc_config.mshr_num &&
                              slot < MAX_OUTSTANDING;
           ++slot) {
        const auto &entry = llc.io.regs.mshr[slot];
        retained = entry.valid && !entry.is_prefetch &&
                   entry.master == static_cast<uint8_t>(master) &&
                   entry.id == consumed_req.id;
      }
      retained = retained || (llc.io.regs.read_resp_valid_r[master] &&
                              llc.io.regs.read_resp_id_r[master] ==
                                  consumed_req.id);
      retained = retained || read_resp_queue_has_id(master, consumed_req.id);
      if (!retained) {
        std::printf(
            "[axi][llc] consumed request without retained llc state "
            "master=%d sim_time=%lld addr=0x%08x id=%u bypass=%d "
            "lookup{valid=%d master=%u id=%u addr=0x%08x} "
            "resp{valid=%d id=%u q_count=%u q_head=%u q_tail=%u} "
            "mshr0{valid=%d master=%u id=%u line=0x%08x} "
            "mshr1{valid=%d master=%u id=%u line=0x%08x}\n",
            master, sim_time, consumed_req.addr,
            static_cast<unsigned>(consumed_req.id),
            static_cast<int>(consumed_req.bypass),
            static_cast<int>(llc.io.regs.lookup_valid_r),
            static_cast<unsigned>(llc.io.regs.lookup_master_r),
            static_cast<unsigned>(llc.io.regs.lookup_id_r),
            llc.io.regs.lookup_addr_r,
            static_cast<int>(llc.io.regs.read_resp_valid_r[master]),
            static_cast<unsigned>(llc.io.regs.read_resp_id_r[master]),
            static_cast<unsigned>(llc.io.regs.read_resp_q_count_r[master]),
            static_cast<unsigned>(llc.io.regs.read_resp_q_head_r[master]),
            static_cast<unsigned>(llc.io.regs.read_resp_q_tail_r[master]),
            static_cast<int>(llc.io.regs.mshr[0].valid),
            static_cast<unsigned>(llc.io.regs.mshr[0].master),
            static_cast<unsigned>(llc.io.regs.mshr[0].id),
            llc.io.regs.mshr[0].line_addr,
            static_cast<int>(llc.io.regs.mshr[1].valid),
            static_cast<unsigned>(llc.io.regs.mshr[1].master),
            static_cast<unsigned>(llc.io.regs.mshr[1].id),
            llc.io.regs.mshr[1].line_addr);
        std::exit(1);
      }
    }
  };
  for (int i = 0; i < NUM_READ_MASTERS; i++) {
    read_req_accepted[i] = false;
    read_req_accepted_id[i] = 0;
  }
  for (int i = 0; i < NUM_WRITE_MASTERS; i++) {
    write_req_accepted[i] = false;
  }

  auto resolve_ar_master = [this](uint8_t &orig_id) -> int {
    if (ar_master_c >= 0 && ar_master_c < NUM_READ_MASTERS) {
      orig_id = ar_orig_id_c;
      return ar_master_c;
    }
    if (r_current_master >= 0 && r_current_master < NUM_READ_MASTERS &&
        read_ports[r_current_master].req.valid &&
        read_ports[r_current_master].req.ready) {
      orig_id = static_cast<uint8_t>(read_ports[r_current_master].req.id);
      return r_current_master;
    }
    for (int i = 0; i < NUM_READ_MASTERS; ++i) {
      if (read_ports[i].req.valid && read_ports[i].req.ready) {
        orig_id = static_cast<uint8_t>(read_ports[i].req.id);
        return i;
      }
    }
    return -1;
  };

  // ========== AR Channel with Latch ==========

  // If new AR request and NOT immediately ready, latch it
  if (axi_io.ar.arvalid && !ar_latched.valid && !axi_io.ar.arready) {
    uint8_t orig_id = 0;
    int master_idx = -1;
    if (ar_from_llc_c) {
      master_idx = 0;
      orig_id = ar_llc_mem_id_c;
    } else {
      master_idx = resolve_ar_master(orig_id);
      if (master_idx < 0) {
        return;
      }
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
      ar_latched.accepted_upstream = false;
      ar_latched.addr = axi_io.ar.araddr;
      ar_latched.len = axi_io.ar.arlen;
      ar_latched.size = axi_io.ar.arsize;
      ar_latched.burst = axi_io.ar.arburst;
      ar_latched.id = axi_io.ar.arid;
      ar_latched.master_id = static_cast<uint8_t>(master_idx);
      ar_latched.orig_id = orig_id;
      ar_latched.to_llc = ar_from_llc_c;
      if (!ar_from_llc_c) {
        // A latched AR only means the interconnect has locally buffered the
        // request under downstream backpressure. Upstream acceptance must wait
        // until the real downstream AR handshake commits and an r_pending txn
        // is created, otherwise MSHR/icache can believe the miss is issued
        // while the request is still absent from the fabric.
        ar_latched.accepted_upstream = false;
      }
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
      txn.addr = ar_latched.addr;
      txn.to_llc = ar_latched.to_llc;
      const bool upstream_accepted = ar_latched.accepted_upstream;
      ar_latched.valid = false; // Clear latch
      ar_latched.accepted_upstream = false;
      ar_latched.to_llc = false;
      if (!txn.to_llc && !upstream_accepted &&
          txn.master_id < NUM_READ_MASTERS) {
        read_req_accepted[txn.master_id] = true;
        read_req_accepted_id[txn.master_id] = txn.orig_id;
        read_req_hold[txn.master_id] = {};
      }
    } else {
      // Direct handshake (same cycle)
      uint8_t orig_id = 0;
      int master_idx = -1;
      if (ar_from_llc_c) {
        master_idx = 0;
        orig_id = ar_llc_mem_id_c;
      } else {
        master_idx = resolve_ar_master(orig_id);
        if (master_idx < 0) {
          goto read_handshake_done;
        }
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
      txn.addr = axi_io.ar.araddr;
      txn.to_llc = ar_from_llc_c;
      if (!ar_from_llc_c) {
        read_req_hold[master_idx] = {};
      }
    }
    txn.beats_done = 0;
    txn.data.clear();
    txn.stall_cycles = 0;
    txn.last_beats_done = 0;
    txn.timeout_warned = false;
    r_pending.push_back(txn);
    if ((sim_time < 400 ||
         focus_read_txn(txn) ||
         trace_icache_read_txn(txn, sim_time)) &&
        !txn.to_llc) {
      dump_focus_read_txn("AR-HS", sim_time, txn);
    }
    if (txn.to_llc && llc_focus_line(txn.addr)) {
      std::printf(
          "[AXI-LLC][AR-HS] cyc=%lld addr=0x%08x slot=%u axi_id=%u beats=%u\n",
          sim_time, txn.addr, static_cast<unsigned>(txn.orig_id),
          static_cast<unsigned>(txn.axi_id), static_cast<unsigned>(txn.total_beats));
    }
    r_arb_rr_idx = (txn.master_id + 1) % NUM_READ_MASTERS;
    if (!txn.to_llc && txn.master_id < NUM_READ_MASTERS) {
      read_req_accepted[txn.master_id] = true;
      read_req_accepted_id[txn.master_id] = txn.orig_id;
      read_req_hold[txn.master_id] = {};
    }

    // req_ready_r is recomputed in comb_read_arbiter.
  }
read_handshake_done:

  if (llc_enabled()) {
    for (int master = 0; master < NUM_READ_MASTERS; ++master) {
      if (llc_upstream_req_valid_prev[master] &&
          llc.io.ext_out.upstream.read_req[master].ready) {
        if (llc_focus_line(llc_upstream_req[master].addr) ||
            trace_icache_llc_master(master, sim_time)) {
          std::printf(
              "[AXI-LLC][UPSTREAM-CONSUME] cyc=%lld master=%d addr=0x%08x "
              "id=%u bypass=%d\n",
              sim_time, master, llc_upstream_req[master].addr,
              static_cast<unsigned>(llc_upstream_req[master].id),
              static_cast<int>(llc_upstream_req[master].bypass));
        }
        llc_upstream_req[master] = {};
      }
      if (!llc_upstream_req_valid_prev[master] && llc_upstream_accept_c[master]) {
        llc_upstream_req[master] = llc_upstream_capture_c[master];
        if (llc_focus_line(llc_upstream_capture_c[master].addr) ||
            trace_icache_llc_master(master, sim_time)) {
          std::printf(
              "[AXI-LLC][UPSTREAM-CAPTURE] cyc=%lld master=%d addr=0x%08x "
              "id=%u bypass=%d\n",
              sim_time, master, llc_upstream_capture_c[master].addr,
              static_cast<unsigned>(llc_upstream_capture_c[master].id),
              static_cast<int>(llc_upstream_capture_c[master].bypass));
        }
        read_req_accepted[master] = true;
        read_req_accepted_id[master] =
            static_cast<uint8_t>(llc_upstream_capture_c[master].id);
      }
    }
    for (int master = 0; master < NUM_WRITE_MASTERS; ++master) {
      if (llc_upstream_write_req_valid_prev[master] &&
          llc.io.ext_out.upstream.write_req[master].ready) {
        if (focus_write_line(llc_upstream_write_req[master].addr) ||
            llc_focus_line(llc_upstream_write_req[master].addr)) {
          std::printf(
              "[AXI-LLC][UPSTREAM-WRITE-CONSUME] cyc=%lld master=%d addr=0x%08x "
              "id=%u bypass=%d\n",
              sim_time, master, llc_upstream_write_req[master].addr,
              static_cast<unsigned>(llc_upstream_write_req[master].id),
              static_cast<int>(llc_upstream_write_req[master].bypass));
        }
        llc_upstream_write_req[master] = {};
      }
      if (llc_upstream_write_accept_c[master]) {
        if (!llc_upstream_write_req[master].valid) {
          llc_upstream_write_req[master] = llc_upstream_write_capture_c[master];
        } else {
          llc_upstream_write_q[master].push_back(
              llc_upstream_write_capture_c[master]);
        }
        if (focus_write_line(llc_upstream_write_capture_c[master].addr) ||
            llc_focus_line(llc_upstream_write_capture_c[master].addr)) {
          std::printf(
              "[AXI-LLC][UPSTREAM-WRITE-CAPTURE] cyc=%lld master=%d addr=0x%08x "
              "id=%u bypass=%d q_depth=%zu\n",
              sim_time, master, llc_upstream_write_capture_c[master].addr,
              static_cast<unsigned>(llc_upstream_write_capture_c[master].id),
              static_cast<int>(llc_upstream_write_capture_c[master].bypass),
              llc_upstream_write_q[master].size());
        }
        write_req_accepted[master] = true;
      }
      if (!llc_upstream_write_req[master].valid &&
          !llc_upstream_write_q[master].empty()) {
        llc_upstream_write_req[master] = llc_upstream_write_q[master].front();
        llc_upstream_write_q[master].pop_front();
        if (focus_write_line(llc_upstream_write_req[master].addr) ||
            llc_focus_line(llc_upstream_write_req[master].addr)) {
          std::printf(
              "[AXI-LLC][UPSTREAM-WRITE-DEQ] cyc=%lld master=%d addr=0x%08x "
              "id=%u bypass=%d q_depth=%zu\n",
              sim_time, master, llc_upstream_write_req[master].addr,
              static_cast<unsigned>(llc_upstream_write_req[master].id),
              static_cast<int>(llc_upstream_write_req[master].bypass),
              llc_upstream_write_q[master].size());
        }
      }
    }
  }

  // R handshake
  if (axi_io.r.rvalid && axi_io.r.rready) {
    for (auto &txn : r_pending) {
      if (txn.axi_id == static_cast<uint8_t>(axi_io.r.rid & kAxiIdMask) &&
          txn.beats_done < txn.total_beats) {
        unpack_downstream_read_beat(txn, axi_io.r.rdata);
        txn.beats_done++;
        if (focus_read_txn(txn) || trace_icache_read_txn(txn, sim_time)) {
          std::printf(
              "[AXI-R][R-BEAT] cyc=%lld addr=0x%08x master=%u orig_id=%u axi_id=%u "
              "rid=%u beat=%u/%u data=0x%016llx rlast=%u\n",
              sim_time, txn.addr, static_cast<unsigned>(txn.master_id),
              static_cast<unsigned>(txn.orig_id), static_cast<unsigned>(txn.axi_id),
              static_cast<unsigned>(axi_io.r.rid & kAxiIdMask),
              static_cast<unsigned>(txn.beats_done),
              static_cast<unsigned>(txn.total_beats),
              static_cast<unsigned long long>(axi_io.r.rdata),
              static_cast<unsigned>(axi_io.r.rlast));
          if (txn.beats_done == txn.total_beats) {
            dump_focus_read_txn("R-COMPLETE", sim_time, txn);
          }
        }
        if (txn.to_llc && llc_focus_line(txn.addr)) {
          dump_focus_read_words("R-BEAT", sim_time, txn);
        }
        break;
      }
    }
  }

  // Response handshake
  for (int i = 0; i < NUM_READ_MASTERS; i++) {
    if (read_ports[i].resp.valid && read_ports[i].resp.ready) {
      const uint8_t driven_orig_id =
          static_cast<uint8_t>(read_ports[i].resp.id & 0xFFu);
      auto it = std::find_if(r_pending.begin(), r_pending.end(),
                             [i, driven_orig_id](const ReadPendingTxn &t) {
                               return t.master_id == i &&
                                      !t.to_llc &&
                                      t.beats_done == t.total_beats &&
                                      t.orig_id == driven_orig_id;
                             });
      if (it != r_pending.end()) {
        if (focus_read_txn(*it) || trace_icache_read_txn(*it, sim_time)) {
          dump_focus_read_txn("RESP-RETIRE", sim_time, *it);
        }
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
      if (llc_focus_line(exact_it->addr) ||
          trace_icache_read_txn(*exact_it, sim_time)) {
        std::printf(
            "[AXI-LLC][MEM-RSP-RETIRE] cyc=%lld addr=0x%08x slot=%u axi_id=%u\n",
            sim_time, exact_it->addr, static_cast<unsigned>(exact_it->orig_id),
            static_cast<unsigned>(exact_it->axi_id));
      }
      r_pending.erase(exact_it);
    } else if (it != r_pending.end()) {
      if (llc_focus_line(it->addr) || trace_icache_read_txn(*it, sim_time)) {
        std::printf(
            "[AXI-LLC][MEM-RSP-RETIRE-FALLBACK] cyc=%lld addr=0x%08x "
            "slot=%u expected_slot=%u axi_id=%u\n",
            sim_time, it->addr, static_cast<unsigned>(it->orig_id),
            static_cast<unsigned>(mem_id), static_cast<unsigned>(it->axi_id));
      }
      r_pending.erase(it);
    }
  }

  // Monitor reads that have stopped making forward progress on the memory side.
  // Completed responses may legitimately wait for the upstream client, so only
  // track incomplete transactions and reset the timer whenever a new beat lands.
  for (auto &txn : r_pending) {
    if (txn.beats_done >= txn.total_beats) {
      txn.stall_cycles = 0;
      txn.last_beats_done = txn.beats_done;
      txn.timeout_warned = false;
      continue;
    }
    if (txn.beats_done != txn.last_beats_done) {
      txn.stall_cycles = 0;
      txn.last_beats_done = txn.beats_done;
      txn.timeout_warned = false;
      continue;
    }
    txn.stall_cycles++;
    if (txn.stall_cycles > kPendingTimeout && !txn.timeout_warned && DEBUG) {
      printf("[axi] pending read stalled master=%u beats=%u/%u axi_id=%u addr=0x%08x\n",
             static_cast<unsigned>(txn.master_id),
             static_cast<unsigned>(txn.beats_done),
             static_cast<unsigned>(txn.total_beats),
             static_cast<unsigned>(txn.axi_id), txn.addr);
      txn.timeout_warned = true;
    }
  }

  // ========== Write Channel ==========

  if (llc_enabled()) {
    // LLC read-response ownership lives entirely inside AXI_LLC::comb().
    // Duplicating retirement here races with same-cycle slot reuse once a
    // master can keep multiple misses in flight, and can erase a fresh
    // response before llc.seq() commits it.
    for (int i = 0; i < NUM_WRITE_MASTERS; ++i) {
      if (llc.io.regs.write_resp_valid_r[i] && write_ports[i].resp.ready) {
        llc.io.reg_write.write_resp_valid_r[i] = false;
        llc.io.reg_write.write_resp_id_r[i] = 0;
        llc.io.reg_write.write_resp_code_r[i] = 0;
      }
      if (!write_size_supported(write_ports[i].req.total_size)) {
        continue;
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
      w_current.llc_victim_write =
          llc.io.regs.victim_wb_valid_r || llc.io.reg_write.victim_wb_valid_r;
      w_current_master = -1;

      aw_latched.valid = true;
      aw_latched.addr = w_current.addr;
      aw_latched.len = w_current.total_beats - 1;
      aw_latched.size = kDownstreamAxiSize;
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
        if (w_current.llc_victim_write) {
          llc_mem_write_resp_valid_ = true;
          llc_mem_write_resp_ = sim_ddr::AXI_RESP_OKAY;
          llc_mem_ignored_b_count_++;
          w_active = false;
          w_current = {};
          w_current_master = -1;
        }
      }
    }

    if (axi_io.b.bvalid && axi_io.b.bready) {
      if (llc_mem_ignored_b_count_ > 0) {
        llc_mem_ignored_b_count_--;
      } else {
        llc_mem_write_resp_valid_ = true;
        llc_mem_write_resp_ = axi_io.b.bresp;
      }
    }

    if (llc_mem_write_resp_valid_prev && llc.io.ext_out.mem.write_resp_ready) {
      llc_mem_write_resp_valid_ = false;
      llc_mem_write_resp_ = 0;
      if (w_active) {
        w_active = false;
        w_current = {};
        w_current_master = -1;
      }
    }

    llc.seq();
    assert_llc_consumed_reads();
    return;
  }

  // Accept new write request into pending queue.
  for (int k = 0; k < NUM_WRITE_MASTERS; k++) {
    int idx = (w_arb_rr_idx + k) % NUM_WRITE_MASTERS;
    if (!write_ports[idx].req.valid || !write_req_fire_c[idx] ||
        !can_accept_write_now()) {
      continue;
    }
    WritePendingTxn txn{};
    txn.axi_id = alloc_write_axi_id();
    if (txn.axi_id == kInvalidAxiWriteId) {
      break;
    }
    txn.master_id = idx;
    txn.orig_id = write_ports[idx].req.id;
    txn.addr = write_ports[idx].req.addr;
    txn.wdata = write_ports[idx].req.wdata;
    txn.wstrb = write_ports[idx].req.wstrb;
    txn.total_beats = calc_burst_len(write_ports[idx].req.total_size) + 1;
    txn.beats_sent = 0;
    txn.aw_done = false;
    txn.w_done = false;
    w_pending.push_back(txn);
    if (focus_write_line(txn.addr)) {
      std::printf(
          "[AXI-W][ENQ] cyc=%lld master=%d axi_id=%u orig_id=%u addr=0x%08x "
          "total_size=%u beats=%u wstrb=0x%016llx\n",
          sim_time, idx, static_cast<unsigned>(txn.axi_id),
          static_cast<unsigned>(txn.orig_id), txn.addr,
          static_cast<unsigned>(write_ports[idx].req.total_size),
          static_cast<unsigned>(txn.total_beats),
          static_cast<unsigned long long>(static_cast<uint64_t>(txn.wstrb)));
      std::printf(
          "[AXI-W][ENQ_DATA] [%08x %08x %08x %08x %08x %08x %08x %08x "
          "%08x %08x %08x %08x %08x %08x %08x %08x]\n",
          txn.wdata.words[0], txn.wdata.words[1], txn.wdata.words[2],
          txn.wdata.words[3], txn.wdata.words[4], txn.wdata.words[5],
          txn.wdata.words[6], txn.wdata.words[7], txn.wdata.words[8],
          txn.wdata.words[9], txn.wdata.words[10], txn.wdata.words[11],
          txn.wdata.words[12], txn.wdata.words[13], txn.wdata.words[14],
          txn.wdata.words[15]);
    }
    write_req_accepted[idx] = true;
    w_arb_rr_idx = (idx + 1) % NUM_WRITE_MASTERS;
    break;
  }

  // AW handshake
  if (axi_io.aw.awvalid && axi_io.aw.awready) {
    const uint8_t axi_id = aw_latched.valid ? aw_latched.id : axi_io.aw.awid;
    const int pending_idx = find_write_pending_by_axi_id(axi_id);
    if (pending_idx >= 0) {
      w_pending[static_cast<size_t>(pending_idx)].aw_done = true;
      const auto &txn = w_pending[static_cast<size_t>(pending_idx)];
      if (focus_write_line(txn.addr)) {
        std::printf(
            "[AXI-W][AW-HS] cyc=%lld axi_id=%u addr=0x%08x len=%u beats=%u\n",
            sim_time, static_cast<unsigned>(axi_id), txn.addr,
            static_cast<unsigned>(axi_io.aw.awlen),
            static_cast<unsigned>(txn.total_beats));
      }
    }
    aw_latched.valid = false; // Clear latch
  }

  // W handshake
  if (axi_io.w.wvalid && axi_io.w.wready) {
    const int pending_idx = find_write_pending_by_axi_id(w_current.axi_id);
    if (pending_idx >= 0) {
      auto &txn = w_pending[static_cast<size_t>(pending_idx)];
      if (focus_write_line(txn.addr)) {
        const uint32_t beat_addr =
            txn.addr + static_cast<uint32_t>(txn.beats_sent) * kDownstreamBeatBytes;
        std::printf(
            "[AXI-W][W-HS] cyc=%lld axi_id=%u beat=%u/%u beat_addr=0x%08x "
            "data=0x%016llx wstrb=0x%llx wlast=%d\n",
            sim_time, static_cast<unsigned>(txn.axi_id),
            static_cast<unsigned>(txn.beats_sent),
            static_cast<unsigned>(txn.total_beats), beat_addr,
            static_cast<unsigned long long>(axi_io.w.wdata),
            static_cast<unsigned long long>(axi_io.w.wstrb),
            static_cast<int>(axi_io.w.wlast));
      }
      txn.beats_sent++;
      w_current.beats_sent = txn.beats_sent;
    }
    if (axi_io.w.wlast) {
      if (const int idx = find_write_pending_by_axi_id(w_current.axi_id); idx >= 0) {
        w_pending[static_cast<size_t>(idx)].w_done = true;
        const auto &txn = w_pending[static_cast<size_t>(idx)];
        if (focus_write_line(txn.addr)) {
          std::printf(
              "[AXI-W][W-DONE] cyc=%lld axi_id=%u addr=0x%08x beats_sent=%u\n",
              sim_time, static_cast<unsigned>(txn.axi_id), txn.addr,
              static_cast<unsigned>(txn.beats_sent));
        }
      }
      w_current.w_done = true;
      w_active = false;
      w_current = {};
      w_current_master = -1;
    }
  }

  // B handshake
  if (axi_io.b.bvalid && axi_io.b.bready) {
    const int pending_idx = find_write_pending_by_axi_id(axi_io.b.bid);
    if (pending_idx >= 0) {
      const auto txn = w_pending[static_cast<size_t>(pending_idx)];
      if (focus_write_line(txn.addr)) {
        std::printf(
            "[AXI-W][B-HS] cyc=%lld axi_id=%u master=%u addr=0x%08x "
            "beats_sent=%u w_done=%d\n",
            sim_time, static_cast<unsigned>(txn.axi_id),
            static_cast<unsigned>(txn.master_id), txn.addr,
            static_cast<unsigned>(txn.beats_sent), static_cast<int>(txn.w_done));
      }
      if (txn.master_id < NUM_WRITE_MASTERS) {
        w_resp_valid[txn.master_id] = true;
        w_resp_id[txn.master_id] = txn.orig_id;
        w_resp_resp[txn.master_id] = axi_io.b.bresp;
      }
      w_pending.erase(w_pending.begin() + pending_idx);
    }
  }

  // Upstream response handshake.
  for (int master = 0; master < NUM_WRITE_MASTERS; ++master) {
    if (write_ports[master].resp.valid && write_ports[master].resp.ready) {
      w_resp_valid[master] = false;
      w_resp_id[master] = 0;
      w_resp_resp[master] = 0;
    }
  }

  if (!aw_latched.valid) {
    const int next_aw_idx = find_next_aw_pending();
    if (next_aw_idx >= 0) {
      const auto &txn = w_pending[static_cast<size_t>(next_aw_idx)];
      aw_latched.valid = true;
      aw_latched.addr = txn.addr;
      aw_latched.len = txn.total_beats - 1;
      aw_latched.size = kDownstreamAxiSize;
      aw_latched.burst = sim_ddr::AXI_BURST_INCR;
      aw_latched.id = txn.axi_id;
    }
  }

  refresh_non_llc_w_active();

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
    printf("    llc: state=%u lookup_valid=%d lookup_issued=%d lookup_master=%u lookup_addr=0x%08x write=%d bypass=%d prefetch=%d invalidate=%d\n",
           static_cast<unsigned>(llc.io.regs.state),
           static_cast<int>(llc.io.regs.lookup_valid_r),
           static_cast<int>(llc.io.regs.lookup_issued_r),
           static_cast<unsigned>(llc.io.regs.lookup_master_r),
           llc.io.regs.lookup_addr_r,
           static_cast<int>(llc.io.regs.lookup_is_write_r),
           static_cast<int>(llc.io.regs.lookup_is_bypass_r),
           static_cast<int>(llc.io.regs.lookup_is_prefetch_r),
           static_cast<int>(llc.io.regs.lookup_is_invalidate_r));
    for (int i = 0; i < NUM_READ_MASTERS; ++i) {
      printf("    llc_upstream[%d]: valid=%d addr=0x%08x id=%u bypass=%d resp_valid=%d resp_ready=%d resp_id=%u\n",
             i, static_cast<int>(llc_upstream_req[i].valid),
             llc_upstream_req[i].addr, static_cast<unsigned>(llc_upstream_req[i].id),
             static_cast<int>(llc_upstream_req[i].bypass),
             static_cast<int>(llc.io.regs.read_resp_valid_r[i]),
             static_cast<int>(read_ports[i].resp.ready),
             static_cast<unsigned>(llc.io.regs.read_resp_id_r[i]));
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
      printf("    llc_upstream_write[%d]: valid=%d addr=0x%08x size=%u id=%u bypass=%d accept_c=%d\n",
             i, static_cast<int>(llc_upstream_write_req[i].valid),
             llc_upstream_write_req[i].addr,
             static_cast<unsigned>(llc_upstream_write_req[i].total_size),
             static_cast<unsigned>(llc_upstream_write_req[i].id),
             static_cast<int>(llc_upstream_write_req[i].bypass),
             static_cast<int>(llc_upstream_write_accept_c[i]));
      printf("    llc_upstream_write_q[%d]: depth=%zu\n", i,
             llc_upstream_write_q[i].size());
    }
    printf("    llc_mem_write_resp: valid=%d code=%u w_active=%d w_current_master=%d aw_latched=%d\n",
           static_cast<int>(llc_mem_write_resp_valid_),
           static_cast<unsigned>(llc_mem_write_resp_),
           static_cast<int>(w_active), w_current_master,
           static_cast<int>(aw_latched.valid));
    llc.debug_print();
  }
}

// ============================================================================
// Helpers
// ============================================================================
uint8_t AXI_Interconnect::calc_burst_len(uint8_t total_size) {
  uint16_t bytes = static_cast<uint16_t>(total_size) + 1u;
  uint16_t beats = (bytes + kDownstreamBeatBytes - 1u) / kDownstreamBeatBytes;
  return beats > 0 ? static_cast<uint8_t>(beats - 1u) : 0;
}

} // namespace axi_interconnect
