#include "AXI_LLC.h"
#include <algorithm>
#include <cstring>

namespace axi_interconnect {

namespace {

uint32_t read_u32_le(const uint8_t *ptr) {
  return static_cast<uint32_t>(ptr[0]) |
         (static_cast<uint32_t>(ptr[1]) << 8) |
         (static_cast<uint32_t>(ptr[2]) << 16) |
         (static_cast<uint32_t>(ptr[3]) << 24);
}

void write_u32_le(uint8_t *ptr, uint32_t value) {
  ptr[0] = static_cast<uint8_t>(value & 0xFFu);
  ptr[1] = static_cast<uint8_t>((value >> 8) & 0xFFu);
  ptr[2] = static_cast<uint8_t>((value >> 16) & 0xFFu);
  ptr[3] = static_cast<uint8_t>((value >> 24) & 0xFFu);
}

WideReadData_t extract_line_response(const AXI_LLCConfig &config, uint32_t addr,
                                     const AXI_LLC_Bytes_t &line) {
  WideReadData_t out;
  out.clear();
  const uint32_t line_bytes = config.line_bytes;
  const uint32_t byte_off = line_bytes == 0 ? 0 : (addr % line_bytes);
  const uint32_t start_word = byte_off / sizeof(uint32_t);
  const uint32_t max_words =
      std::min<uint32_t>(AXI_LLC::line_words(config),
                         MAX_READ_TRANSACTION_WORDS - start_word);
  for (uint32_t i = 0; i < max_words; ++i) {
    const uint32_t src_word = start_word + i;
    const size_t byte_idx = static_cast<size_t>(src_word) * sizeof(uint32_t);
    if (byte_idx + sizeof(uint32_t) <= line.size()) {
      out[i] = read_u32_le(line.data() + byte_idx);
    }
  }
  return out;
}

AXI_LLC_Bytes_t wide_to_line_bytes(const AXI_LLCConfig &config,
                                   const WideReadData_t &data) {
  AXI_LLC_Bytes_t bytes;
  bytes.resize(config.line_bytes);
  const uint32_t words = AXI_LLC::line_words(config);
  for (uint32_t i = 0; i < words; ++i) {
    write_u32_le(bytes.data() + static_cast<size_t>(i) * sizeof(uint32_t),
                 data.words[i]);
  }
  return bytes;
}

AXI_LLC_Bytes_t build_repl_payload(uint32_t next_way) {
  AXI_LLC_Bytes_t bytes;
  bytes.resize(AXI_LLC_REPL_BYTES);
  write_u32_le(bytes.data(), next_way);
  return bytes;
}

uint32_t decode_repl_way(const AXI_LLC_Bytes_t &payload) {
  if (payload.size() < AXI_LLC_REPL_BYTES) {
    return 0;
  }
  return read_u32_le(payload.data());
}
} // namespace

AXI_LLC::AXI_LLC() { reset(); }

bool AXI_LLC::can_accept_read_now(uint8_t master, bool bypass) const {
  if (master >= NUM_READ_MASTERS || config_.mshr_num == 0) {
    return false;
  }
  if (io.regs.read_resp_valid_r[master]) {
    return false;
  }
  if (bypass) {
    return find_free_mshr(io.regs) >= 0;
  }
  if (io.regs.lookup_valid_r) {
    return false;
  }
  if (has_mshr_for_master(io.regs, master)) {
    return false;
  }
  return true;
}

uint32_t AXI_LLC::line_words(const AXI_LLCConfig &config) {
  return config.line_bytes / sizeof(uint32_t);
}

uint32_t AXI_LLC::line_addr(const AXI_LLCConfig &config, uint32_t addr) {
  return config.line_bytes == 0 ? addr : (addr / config.line_bytes) * config.line_bytes;
}

uint32_t AXI_LLC::set_index(const AXI_LLCConfig &config, uint32_t addr) {
  if (!config.valid() || config.line_bytes == 0) {
    return 0;
  }
  return (addr / config.line_bytes) % config.set_count();
}

uint32_t AXI_LLC::tag_of(const AXI_LLCConfig &config, uint32_t addr) {
  if (!config.valid() || config.line_bytes == 0 || config.set_count() == 0) {
    return 0;
  }
  return (addr / config.line_bytes) / config.set_count();
}

AXI_LLCMetaEntry_t AXI_LLC::decode_meta(const AXI_LLC_Bytes_t &payload,
                                        uint32_t way) {
  AXI_LLCMetaEntry_t entry{};
  const size_t offset = static_cast<size_t>(way) * AXI_LLC_META_ENTRY_BYTES;
  if (offset + AXI_LLC_META_ENTRY_BYTES > payload.size()) {
    return entry;
  }
  entry.tag = read_u32_le(payload.data() + offset);
  entry.flags = payload.data()[offset + 4];
  return entry;
}

void AXI_LLC::encode_meta(const AXI_LLCMetaEntry_t &entry,
                          AXI_LLC_Bytes_t &payload) {
  payload.resize(AXI_LLC_META_ENTRY_BYTES);
  write_u32_le(payload.data(), entry.tag);
  payload.data()[4] = entry.flags;
}

void AXI_LLC::set_config(const AXI_LLCConfig &config) {
  config_ = config;
  io.regs.enable_r = config_.enable;
  io.regs.state =
      config_.enable ? AXI_LLCState::kIdle : AXI_LLCState::kDisabled;
}

void AXI_LLC::reset() {
  io = {};
  io.regs.enable_r = config_.enable;
  io.regs.state =
      config_.enable ? AXI_LLCState::kIdle : AXI_LLCState::kDisabled;
}

int AXI_LLC::find_free_mshr(const AXI_LLC_Regs_t &regs) const {
  const uint32_t limit = std::min<uint32_t>(config_.mshr_num, MAX_OUTSTANDING);
  for (uint32_t i = 0; i < limit; ++i) {
    if (!regs.mshr[i].valid) {
      return static_cast<int>(i);
    }
  }
  return -1;
}

int AXI_LLC::find_mshr_by_line_addr(const AXI_LLC_Regs_t &regs,
                                    uint32_t line_addr_value) const {
  const uint32_t limit = std::min<uint32_t>(config_.mshr_num, MAX_OUTSTANDING);
  for (uint32_t i = 0; i < limit; ++i) {
    if (regs.mshr[i].valid && !regs.mshr[i].bypass &&
        regs.mshr[i].line_addr == line_addr_value) {
      return static_cast<int>(i);
    }
  }
  return -1;
}

bool AXI_LLC::has_mshr_for_master(const AXI_LLC_Regs_t &regs, uint8_t master) const {
  const uint32_t limit = std::min<uint32_t>(config_.mshr_num, MAX_OUTSTANDING);
  for (uint32_t i = 0; i < limit; ++i) {
    if (regs.mshr[i].valid && regs.mshr[i].master == master) {
      return true;
    }
  }
  return false;
}

int AXI_LLC::pick_mem_issue_slot(const AXI_LLC_Regs_t &regs) const {
  const uint32_t limit = std::min<uint32_t>(config_.mshr_num, MAX_OUTSTANDING);
  for (uint32_t i = 0; i < limit; ++i) {
    if (regs.mshr[i].valid && !regs.mshr[i].mem_req_issued) {
      return static_cast<int>(i);
    }
  }
  return -1;
}

int AXI_LLC::find_mshr_by_mem_id(const AXI_LLC_Regs_t &regs, uint8_t mem_id) const {
  const uint32_t limit = std::min<uint32_t>(config_.mshr_num, MAX_OUTSTANDING);
  for (uint32_t i = 0; i < limit; ++i) {
    if (regs.mshr[i].valid && static_cast<uint8_t>(i) == mem_id) {
      return static_cast<int>(i);
    }
  }
  return -1;
}

int AXI_LLC::pick_refill_commit_slot(const AXI_LLC_Regs_t &regs) const {
  const uint32_t limit = std::min<uint32_t>(config_.mshr_num, MAX_OUTSTANDING);
  for (uint32_t i = 0; i < limit; ++i) {
    if (regs.mshr[i].valid && regs.mshr[i].refill_valid) {
      return static_cast<int>(i);
    }
  }
  return -1;
}

int AXI_LLC::pick_new_read_master(const AXI_LLC_Regs_t &regs) const {
  for (uint32_t off = 0; off < NUM_READ_MASTERS; ++off) {
    const uint32_t idx = (regs.rr_read_master_r + off) % NUM_READ_MASTERS;
    const auto &req = io.ext_in.upstream.read_req[idx];
    if (!req.valid || regs.read_resp_valid_r[idx]) {
      continue;
    }
    if (!req.bypass && has_mshr_for_master(regs, static_cast<uint8_t>(idx))) {
      continue;
    }
    if (!req.bypass && regs.lookup_valid_r) {
      continue;
    }
    if (req.bypass && find_free_mshr(regs) < 0) {
      continue;
    }
    return static_cast<int>(idx);
  }
  return -1;
}

int AXI_LLC::pick_new_write_master(const AXI_LLC_Regs_t &regs) const {
  if (regs.write_active_r) {
    return -1;
  }
  for (uint32_t off = 0; off < NUM_WRITE_MASTERS; ++off) {
    const uint32_t idx = (regs.rr_write_master_r + off) % NUM_WRITE_MASTERS;
    const auto &req = io.ext_in.upstream.write_req[idx];
    if (req.valid && !regs.write_resp_valid_r[idx]) {
      return static_cast<int>(idx);
    }
  }
  return -1;
}

void AXI_LLC::drive_read_responses() {
  for (uint8_t i = 0; i < NUM_READ_MASTERS; ++i) {
    io.ext_out.upstream.read_resp[i].valid = io.regs.read_resp_valid_r[i];
    io.ext_out.upstream.read_resp[i].data = io.regs.read_resp_data_r[i];
    io.ext_out.upstream.read_resp[i].id = io.regs.read_resp_id_r[i];
    if (io.regs.read_resp_valid_r[i] && io.ext_in.upstream.read_resp[i].ready) {
      io.reg_write.read_resp_valid_r[i] = false;
      io.reg_write.read_resp_id_r[i] = 0;
      io.reg_write.read_resp_data_r[i].clear();
    }
  }
}

void AXI_LLC::drive_write_path() {
  for (uint8_t i = 0; i < NUM_WRITE_MASTERS; ++i) {
    io.ext_out.upstream.write_resp[i].valid = io.regs.write_resp_valid_r[i];
    io.ext_out.upstream.write_resp[i].id = io.regs.write_resp_id_r[i];
    io.ext_out.upstream.write_resp[i].resp = io.regs.write_resp_code_r[i];
    if (io.regs.write_resp_valid_r[i] && io.ext_in.upstream.write_resp[i].ready) {
      io.reg_write.write_resp_valid_r[i] = false;
      io.reg_write.write_resp_id_r[i] = 0;
      io.reg_write.write_resp_code_r[i] = 0;
    }
  }

  io.ext_out.mem.write_resp_ready = true;
  if (io.ext_in.mem.write_resp_valid && io.regs.write_active_r) {
    const uint8_t master = io.regs.write_active_master_r;
    io.reg_write.write_resp_valid_r[master] = true;
    io.reg_write.write_resp_id_r[master] = io.regs.write_active_id_r;
    io.reg_write.write_resp_code_r[master] = io.ext_in.mem.write_resp;
    io.reg_write.write_active_r = false;
  }

  const int write_master = pick_new_write_master(io.regs);
  if (write_master >= 0) {
    const auto &req = io.ext_in.upstream.write_req[write_master];
    io.ext_out.upstream.write_req[write_master].ready = io.ext_in.mem.write_req_ready;
    io.ext_out.mem.write_req_valid = req.valid;
    io.ext_out.mem.write_req_addr = req.addr;
    io.ext_out.mem.write_req_data = req.wdata;
    io.ext_out.mem.write_req_strobe = req.wstrb;
    io.ext_out.mem.write_req_size = req.total_size;
    io.ext_out.mem.write_req_id = req.id;
    if (req.valid && io.ext_in.mem.write_req_ready) {
      io.reg_write.write_active_r = true;
      io.reg_write.write_active_master_r = static_cast<uint8_t>(write_master);
      io.reg_write.write_active_id_r = req.id;
      io.reg_write.rr_write_master_r =
          static_cast<uint8_t>((write_master + 1) % NUM_WRITE_MASTERS);
    }
  }
}

void AXI_LLC::drive_lookup_request() {
  if (!io.regs.lookup_valid_r) {
    return;
  }
  const uint32_t index = set_index(config_, io.regs.lookup_addr_r);
  io.table_out.data.enable = true;
  io.table_out.meta.enable = true;
  io.table_out.repl.enable = true;
  io.table_out.data.index = index;
  io.table_out.meta.index = index;
  io.table_out.repl.index = index;
  io.reg_write.state = AXI_LLCState::kLookup;
}

bool AXI_LLC::try_complete_lookup() {
  if (!io.regs.lookup_valid_r || !io.lookup_in.data_valid || !io.lookup_in.meta_valid ||
      !io.lookup_in.repl_valid) {
    return false;
  }

  const uint32_t set = set_index(config_, io.regs.lookup_addr_r);
  const uint32_t tag = tag_of(config_, io.regs.lookup_addr_r);
  const uint32_t way_count = config_.ways;
  int hit_way = -1;
  int first_invalid_way = -1;
  for (uint32_t way = 0; way < way_count; ++way) {
    const auto meta = decode_meta(io.lookup_in.meta, way);
    const bool valid = (meta.flags & AXI_LLC_META_VALID) != 0;
    if (!valid && first_invalid_way < 0) {
      first_invalid_way = static_cast<int>(way);
    }
    if (valid && meta.tag == tag) {
      hit_way = static_cast<int>(way);
      break;
    }
  }

  if (hit_way >= 0) {
    AXI_LLC_Bytes_t line;
    line.resize(config_.line_bytes);
    const size_t offset = static_cast<size_t>(hit_way) * config_.line_bytes;
    if (offset + config_.line_bytes <= io.lookup_in.data.size()) {
      std::memcpy(line.data(), io.lookup_in.data.data() + offset,
                  config_.line_bytes);
    }
    const uint8_t master = io.regs.lookup_master_r;
    io.reg_write.read_resp_valid_r[master] = true;
    io.reg_write.read_resp_id_r[master] = io.regs.lookup_id_r;
    io.reg_write.read_resp_data_r[master] =
        extract_line_response(config_, io.regs.lookup_addr_r, line);
    io.table_out.repl.enable = true;
    io.table_out.repl.write = true;
    io.table_out.repl.index = set;
    io.table_out.repl.payload = build_repl_payload(
        static_cast<uint32_t>((hit_way + 1) % config_.ways));
    io.table_out.repl.byte_enable.assign(AXI_LLC_REPL_BYTES, 1);
    io.reg_write.lookup_valid_r = false;
    io.reg_write.state = AXI_LLCState::kIdle;
    return true;
  }

  const uint32_t req_line_addr = line_addr(config_, io.regs.lookup_addr_r);
  const int merge_slot = find_mshr_by_line_addr(io.regs, req_line_addr);
  if (merge_slot >= 0) {
    io.reg_write.lookup_valid_r = false;
    io.reg_write.state = AXI_LLCState::kMiss;
    return true;
  }

  const int free_slot = find_free_mshr(io.regs);
  if (free_slot < 0) {
    io.reg_write.state = AXI_LLCState::kMiss;
    return false;
  }

  const uint32_t repl_way_raw = decode_repl_way(io.lookup_in.repl);
  const uint8_t victim_way = static_cast<uint8_t>(
      first_invalid_way >= 0 ? first_invalid_way : (repl_way_raw % config_.ways));
  auto &entry = io.reg_write.mshr[free_slot];
  entry = {};
  entry.valid = true;
  entry.addr = io.regs.lookup_addr_r;
  entry.line_addr = line_addr(config_, io.regs.lookup_addr_r);
  entry.set = set;
  entry.tag = tag;
  entry.way = victim_way;
  entry.total_size = io.regs.lookup_size_r;
  entry.master = io.regs.lookup_master_r;
  entry.id = io.regs.lookup_id_r;

  io.reg_write.lookup_valid_r = false;
  io.reg_write.state = AXI_LLCState::kMiss;
  return true;
}

void AXI_LLC::drive_mem_read_path() {
  io.ext_out.mem.read_resp_ready = true;

  if (io.ext_in.mem.read_resp_valid) {
    const int slot = find_mshr_by_mem_id(io.regs, io.ext_in.mem.read_resp_id);
    if (slot >= 0) {
      auto &entry = io.reg_write.mshr[slot];
      entry.refill_valid = true;
      entry.refill_data = io.ext_in.mem.read_resp_data;
      entry.refill_committed = entry.bypass;
      io.reg_write.state = AXI_LLCState::kRefill;
    }
  }

  const int slot = pick_mem_issue_slot(io.regs);
  if (slot >= 0) {
    const auto &entry = io.regs.mshr[slot];
    io.ext_out.mem.read_req_valid = true;
    io.ext_out.mem.read_req_addr = entry.line_addr;
    io.ext_out.mem.read_req_size = entry.bypass
                                       ? entry.total_size
                                       : static_cast<uint8_t>(config_.line_bytes - 1);
    io.ext_out.mem.read_req_id = static_cast<uint8_t>(slot);
    if (io.ext_in.mem.read_req_ready) {
      io.reg_write.mshr[slot].mem_req_issued = true;
    }
  }

  const int commit_slot = pick_refill_commit_slot(io.regs);
  if (commit_slot < 0) {
    return;
  }

  const auto &entry = io.regs.mshr[commit_slot];
  if (!entry.refill_committed && !entry.bypass) {
    const auto line_bytes = wide_to_line_bytes(config_, entry.refill_data);
    AXI_LLCMetaEntry_t meta{};
    meta.tag = entry.tag;
    meta.flags = AXI_LLC_META_VALID;

    io.table_out.data.enable = true;
    io.table_out.data.write = true;
    io.table_out.data.index = entry.set;
    io.table_out.data.way = entry.way;
    io.table_out.data.payload = line_bytes;
    io.table_out.data.byte_enable.assign(config_.line_bytes, 1);

    io.table_out.meta.enable = true;
    io.table_out.meta.write = true;
    io.table_out.meta.index = entry.set;
    io.table_out.meta.way = entry.way;
    encode_meta(meta, io.table_out.meta.payload);
    io.table_out.meta.byte_enable.assign(AXI_LLC_META_ENTRY_BYTES, 1);

    io.table_out.repl.enable = true;
    io.table_out.repl.write = true;
    io.table_out.repl.index = entry.set;
    io.table_out.repl.payload =
        build_repl_payload(static_cast<uint32_t>((entry.way + 1) % config_.ways));
    io.table_out.repl.byte_enable.assign(AXI_LLC_REPL_BYTES, 1);

    io.reg_write.mshr[commit_slot].refill_committed = true;
    return;
  }

  if (io.regs.read_resp_valid_r[entry.master]) {
    return;
  }

  WideReadData_t resp_data = entry.refill_data;
  if (!entry.bypass) {
    const auto line_bytes = wide_to_line_bytes(config_, entry.refill_data);
    resp_data = extract_line_response(config_, entry.addr, line_bytes);
  }
  io.reg_write.read_resp_valid_r[entry.master] = true;
  io.reg_write.read_resp_id_r[entry.master] = entry.id;
  io.reg_write.read_resp_data_r[entry.master] = resp_data;
  io.reg_write.mshr[commit_slot] = {};
  io.reg_write.state = io.regs.lookup_valid_r ? AXI_LLCState::kLookup
                                              : AXI_LLCState::kIdle;
}

void AXI_LLC::accept_new_requests() {
  const int master = pick_new_read_master(io.regs);
  if (master < 0) {
    return;
  }

  const auto &req = io.ext_in.upstream.read_req[master];
  io.ext_out.upstream.read_req[master].ready = true;
  if (!req.valid) {
    return;
  }

  io.reg_write.rr_read_master_r =
      static_cast<uint8_t>((master + 1) % NUM_READ_MASTERS);

  if (req.bypass) {
    const int free_slot = find_free_mshr(io.regs);
    if (free_slot < 0) {
      return;
    }
    auto &entry = io.reg_write.mshr[free_slot];
    entry = {};
    entry.valid = true;
    entry.bypass = true;
    entry.addr = req.addr;
    entry.line_addr = req.addr;
    entry.total_size = req.total_size;
    entry.master = static_cast<uint8_t>(master);
    entry.id = req.id;
    entry.set = set_index(config_, req.addr);
    entry.tag = tag_of(config_, req.addr);
    io.reg_write.state = AXI_LLCState::kMiss;
    return;
  }

  const int merge_slot =
      find_mshr_by_line_addr(io.regs, line_addr(config_, req.addr));
  if (merge_slot >= 0) {
    return;
  }

  io.reg_write.lookup_valid_r = true;
  io.reg_write.lookup_addr_r = req.addr;
  io.reg_write.lookup_size_r = req.total_size;
  io.reg_write.lookup_master_r = static_cast<uint8_t>(master);
  io.reg_write.lookup_id_r = req.id;
  io.reg_write.state = AXI_LLCState::kLookup;
}

void AXI_LLC::comb_disabled() {
  for (uint8_t i = 0; i < NUM_READ_MASTERS; ++i) {
    io.ext_out.upstream.read_req[i].ready = false;
    io.ext_out.upstream.read_resp[i].valid = false;
    io.ext_out.upstream.read_resp[i].id = 0;
    io.ext_out.upstream.read_resp[i].data.clear();
  }
  for (uint8_t i = 0; i < NUM_WRITE_MASTERS; ++i) {
    io.ext_out.upstream.write_req[i].ready = false;
    io.ext_out.upstream.write_resp[i].valid = false;
    io.ext_out.upstream.write_resp[i].id = 0;
    io.ext_out.upstream.write_resp[i].resp = 0;
  }
  io.ext_out.mem = {};
}

void AXI_LLC::comb() {
  io.ext_out = {};
  io.table_out = {};
  io.reg_write = io.regs;

  if (!config_.enable || !config_.valid()) {
    comb_disabled();
    io.reg_write.enable_r = false;
    io.reg_write.state = AXI_LLCState::kDisabled;
    return;
  }

  io.reg_write.enable_r = true;
  if (io.regs.state == AXI_LLCState::kDisabled) {
    io.reg_write.state = AXI_LLCState::kIdle;
  }

  drive_read_responses();
  drive_write_path();
  drive_lookup_request();
  (void)try_complete_lookup();
  drive_mem_read_path();
  accept_new_requests();
}

void AXI_LLC::seq() { io.regs = io.reg_write; }

} // namespace axi_interconnect
