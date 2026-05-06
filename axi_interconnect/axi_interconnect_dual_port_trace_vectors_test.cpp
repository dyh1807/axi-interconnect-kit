/**
 * @file axi_interconnect_dual_port_trace_vectors_test.cpp
 * @brief Emit RTL vectors from the actual AXI_Interconnect comb/seq path.
 *
 * This is intentionally a thin trace generator around the production C++
 * model. The generated Verilog include is consumed by RTL contract tests so
 * the expected values are not hand-written in the RTL bench.
 */

#include <array>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#include "AXI_Interconnect.h"

uint32_t *p_memory = nullptr;
long long sim_time = 0;

namespace {

uint32_t g_legacy_backing_words[32] = {};

uint32_t legacy_backing_index(uint32_t paddr) {
  return (paddr - 0x10000000u) >> 2;
}

void reset_legacy_backing() {
  for (auto &word : g_legacy_backing_words) {
    word = 0;
  }
}

void require(bool condition, const char *message) {
  if (!condition) {
    throw std::runtime_error(message);
  }
}

void clear_downstream_responses(axi_interconnect::AXI_Interconnect &dut) {
  dut.axi_ddr_io.r.rvalid = false;
  dut.axi_ddr_io.r.rid = 0;
  dut.axi_ddr_io.r.rdata = {};
  dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_ddr_io.r.rlast = false;
  dut.axi_ddr_io.b.bvalid = false;
  dut.axi_ddr_io.b.bid = 0;
  dut.axi_ddr_io.b.bresp = sim_ddr::AXI_RESP_OKAY;

  dut.axi_mmio_io.r.rvalid = false;
  dut.axi_mmio_io.r.rid = 0;
  dut.axi_mmio_io.r.rdata = {};
  dut.axi_mmio_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_mmio_io.r.rlast = false;
  dut.axi_mmio_io.b.bvalid = false;
  dut.axi_mmio_io.b.bid = 0;
  dut.axi_mmio_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
}

void clear_inputs(axi_interconnect::AXI_Interconnect &dut) {
  for (int i = 0; i < axi_interconnect::NUM_READ_MASTERS; ++i) {
    auto &port = dut.read_ports[i];
    port.req.valid = false;
    port.req.addr = 0;
    port.req.total_size = 0;
    port.req.id = 0;
    port.req.bypass = false;
    port.resp.ready = false;
  }
  for (int i = 0; i < axi_interconnect::NUM_WRITE_MASTERS; ++i) {
    auto &port = dut.write_ports[i];
    port.req.valid = false;
    port.req.addr = 0;
    port.req.wdata.clear();
    port.req.wstrb.clear();
    port.req.total_size = 0;
    port.req.id = 0;
    port.req.bypass = false;
    port.resp.ready = false;
  }
  clear_downstream_responses(dut);
}

void set_downstream_ready(axi_interconnect::AXI_Interconnect &dut) {
  dut.axi_ddr_io.ar.arready = true;
  dut.axi_ddr_io.aw.awready = true;
  dut.axi_ddr_io.w.wready = true;
  dut.axi_mmio_io.ar.arready = true;
  dut.axi_mmio_io.aw.awready = true;
  dut.axi_mmio_io.w.wready = true;
}

axi_interconnect::AXI_LLC_Bytes_t zero_llc_bytes(size_t size) {
  axi_interconnect::AXI_LLC_Bytes_t bytes{};
  bytes.resize(size);
  return bytes;
}

axi_interconnect::AXI_LLC_Bytes_t repl_payload(uint32_t way) {
  auto bytes = zero_llc_bytes(axi_interconnect::AXI_LLC_REPL_BYTES);
  for (uint32_t i = 0; i < axi_interconnect::AXI_LLC_REPL_BYTES; ++i) {
    bytes.data()[i] = static_cast<uint8_t>((way >> (i * 8)) & 0xffu);
  }
  return bytes;
}

axi_interconnect::AXI_LLC_LookupIn_t invalid_lookup_row(
    const axi_interconnect::AXI_LLCConfig &cfg) {
  axi_interconnect::AXI_LLC_LookupIn_t in{};
  in.data_valid = true;
  in.meta_valid = true;
  in.valid_valid = true;
  in.repl_valid = true;
  in.data = zero_llc_bytes(static_cast<size_t>(cfg.ways) * cfg.line_bytes);
  in.meta = zero_llc_bytes(static_cast<size_t>(cfg.ways) *
                           axi_interconnect::AXI_LLC_META_ENTRY_BYTES);
  in.valid = zero_llc_bytes(axi_interconnect::AXI_LLC::valid_row_bytes(cfg));
  in.repl = repl_payload(0);
  return in;
}

class InvalidLlcTableDriver {
public:
  explicit InvalidLlcTableDriver(const axi_interconnect::AXI_LLCConfig &cfg)
      : cfg_(cfg) {}

  void drive(axi_interconnect::AXI_Interconnect &dut) {
    dut.set_llc_lookup_in(pending_valid_ ? pending_ :
                                           axi_interconnect::AXI_LLC_LookupIn_t{});
    pending_valid_ = false;
  }

  void observe(const axi_interconnect::AXI_Interconnect &dut) {
    const auto &out = dut.get_llc_table_out();
    if (!out.data.enable || out.data.write || !out.meta.enable ||
        out.meta.write || !out.valid.enable || out.valid.write ||
        !out.repl.enable || out.repl.write) {
      return;
    }
    pending_ = invalid_lookup_row(cfg_);
    pending_valid_ = true;
  }

private:
  axi_interconnect::AXI_LLCConfig cfg_{};
  axi_interconnect::AXI_LLC_LookupIn_t pending_{};
  bool pending_valid_ = false;
};

class StatefulLlcTableDriver {
public:
  explicit StatefulLlcTableDriver(const axi_interconnect::AXI_LLCConfig &cfg)
      : cfg_(cfg) {
    reset();
  }

  void drive(axi_interconnect::AXI_Interconnect &dut) {
    dut.set_llc_lookup_in(pending_valid_ ? pending_ :
                                           axi_interconnect::AXI_LLC_LookupIn_t{});
    pending_valid_ = false;
  }

  void observe(const axi_interconnect::AXI_Interconnect &dut) {
    const auto &out = dut.get_llc_table_out();
    if (out.invalidate_all) {
      reset();
      return;
    }

    if (out.data.enable && out.data.write) {
      apply_way_write(row(out.data.index).data, out.data.way, cfg_.line_bytes,
                      out.data.payload, out.data.byte_enable);
    }
    if (out.meta.enable && out.meta.write) {
      apply_way_write(row(out.meta.index).meta, out.meta.way,
                      axi_interconnect::AXI_LLC_META_ENTRY_BYTES,
                      out.meta.payload, out.meta.byte_enable);
    }
    if (out.valid.enable && out.valid.write) {
      apply_valid_write(row(out.valid.index).valid, out.valid.way,
                        out.valid.payload);
    }
    if (out.repl.enable && out.repl.write) {
      apply_payload(row(out.repl.index).repl, 0, out.repl.payload,
                    out.repl.byte_enable);
    }

    if (!out.data.enable || out.data.write || !out.meta.enable ||
        out.meta.write || !out.valid.enable || out.valid.write ||
        !out.repl.enable || out.repl.write) {
      return;
    }
    pending_ = lookup_row(out.data.index);
    pending_valid_ = true;
  }

private:
  struct Row {
    axi_interconnect::AXI_LLC_Bytes_t data{};
    axi_interconnect::AXI_LLC_Bytes_t meta{};
    axi_interconnect::AXI_LLC_Bytes_t valid{};
    axi_interconnect::AXI_LLC_Bytes_t repl{};
  };

  void reset() {
    const uint32_t set_count = cfg_.set_count();
    rows_.assign(set_count, Row{});
    for (auto &entry : rows_) {
      entry.data =
          zero_llc_bytes(static_cast<size_t>(cfg_.ways) * cfg_.line_bytes);
      entry.meta = zero_llc_bytes(static_cast<size_t>(cfg_.ways) *
                                  axi_interconnect::AXI_LLC_META_ENTRY_BYTES);
      entry.valid =
          zero_llc_bytes(axi_interconnect::AXI_LLC::valid_row_bytes(cfg_));
      entry.repl = repl_payload(0);
    }
    pending_ = {};
    pending_valid_ = false;
  }

  Row &row(uint32_t index) {
    require(!rows_.empty(), "C++ stateful LLC table has no rows");
    return rows_[index % rows_.size()];
  }

  const Row &row(uint32_t index) const {
    require(!rows_.empty(), "C++ stateful LLC table has no rows");
    return rows_[index % rows_.size()];
  }

  static void apply_payload(axi_interconnect::AXI_LLC_Bytes_t &target,
                            size_t offset,
                            const axi_interconnect::AXI_LLC_Bytes_t &payload,
                            const std::vector<uint8_t> &byte_enable) {
    for (size_t i = 0; i < payload.size(); ++i) {
      if (offset + i >= target.size()) {
        break;
      }
      const bool enabled =
          byte_enable.empty() || (i < byte_enable.size() && byte_enable[i] != 0);
      if (enabled) {
        target.data()[offset + i] = payload.data()[i];
      }
    }
  }

  static void apply_way_write(axi_interconnect::AXI_LLC_Bytes_t &target,
                              uint32_t way, uint32_t way_bytes,
                              const axi_interconnect::AXI_LLC_Bytes_t &payload,
                              const std::vector<uint8_t> &byte_enable) {
    apply_payload(target, static_cast<size_t>(way) * way_bytes, payload,
                  byte_enable);
  }

  static void apply_valid_write(axi_interconnect::AXI_LLC_Bytes_t &target,
                                uint32_t way,
                                const axi_interconnect::AXI_LLC_Bytes_t &payload) {
    const size_t byte_idx = static_cast<size_t>(way >> 3);
    const uint8_t bit_mask = static_cast<uint8_t>(1u << (way & 0x7u));
    if (byte_idx >= target.size()) {
      return;
    }
    const bool new_value =
        byte_idx < payload.size() && ((payload.data()[byte_idx] & bit_mask) != 0);
    if (new_value) {
      target.data()[byte_idx] = static_cast<uint8_t>(target.data()[byte_idx] |
                                                     bit_mask);
    } else {
      target.data()[byte_idx] = static_cast<uint8_t>(target.data()[byte_idx] &
                                                     ~bit_mask);
    }
  }

  axi_interconnect::AXI_LLC_LookupIn_t lookup_row(uint32_t index) const {
    const auto &entry = row(index);
    axi_interconnect::AXI_LLC_LookupIn_t in{};
    in.data_valid = true;
    in.meta_valid = true;
    in.valid_valid = true;
    in.repl_valid = true;
    in.data = entry.data;
    in.meta = entry.meta;
    in.valid = entry.valid;
    in.repl = entry.repl;
    return in;
  }

  axi_interconnect::AXI_LLCConfig cfg_{};
  std::vector<Row> rows_{};
  axi_interconnect::AXI_LLC_LookupIn_t pending_{};
  bool pending_valid_ = false;
};

void init_dut(axi_interconnect::AXI_Interconnect &dut) {
  unsetenv("AXI_SUBMODULE_MODE");
  unsetenv("AXI_SUBMODULE_OFFSET");
  reset_legacy_backing();
  axi_interconnect::AXI_LLCConfig cfg{};
  cfg.enable = false;
  dut.set_llc_config(cfg);
  dut.mode = 0;
  dut.init();
  clear_downstream_responses(dut);
  set_downstream_ready(dut);
}

void init_cache_trace_dut(axi_interconnect::AXI_Interconnect &dut) {
  unsetenv("AXI_SUBMODULE_MODE");
  unsetenv("AXI_SUBMODULE_OFFSET");
  reset_legacy_backing();
  axi_interconnect::AXI_LLCConfig cfg{};
  cfg.enable = true;
  // Keep the RTL trace contract small but preserve enough set bits for
  // 32-bit DDR addresses to round-trip through the 16-bit metadata store.
  cfg.size_bytes = 64u * 2048u * 2u;
  cfg.line_bytes = 64;
  cfg.ways = 2;
  cfg.mshr_num = 8;
  cfg.lookup_latency = 3;
  dut.set_llc_config(cfg);
  dut.mode = 1;
  dut.init();
  clear_downstream_responses(dut);
  set_downstream_ready(dut);
}

void init_mapped_trace_dut(axi_interconnect::AXI_Interconnect &dut) {
  unsetenv("AXI_SUBMODULE_MODE");
  unsetenv("AXI_SUBMODULE_OFFSET");
  reset_legacy_backing();
  axi_interconnect::AXI_LLCConfig cfg{};
  cfg.enable = true;
  cfg.size_bytes = 64u * 2048u * 2u;
  cfg.line_bytes = 64;
  cfg.ways = 2;
  cfg.mshr_num = 8;
  cfg.lookup_latency = 3;
  dut.set_llc_config(cfg);
  dut.mode = 2;
  dut.llc_mapped_offset = 0x30000000u;
  dut.init();
  clear_downstream_responses(dut);
  set_downstream_ready(dut);
}

void cycle_outputs(axi_interconnect::AXI_Interconnect &dut) {
  set_downstream_ready(dut);
  dut.comb_outputs();
}

void cycle_inputs(axi_interconnect::AXI_Interconnect &dut) {
  set_downstream_ready(dut);
  dut.comb_inputs();
  dut.seq();
  ++sim_time;
}

void idle_request_outputs(axi_interconnect::AXI_Interconnect &dut) {
  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.comb_inputs();
}

sim_ddr::axi_data_t ddr_read_beat(uint32_t base) {
  sim_ddr::axi_data_t data{};
  for (uint8_t word = 0; word < sim_ddr::AXI_DATA_WORDS; ++word) {
    axi_compat::set_u32(data, word, base + word);
  }
  return data;
}

axi_interconnect::WideWriteData_t line_write_data(uint32_t base) {
  axi_interconnect::WideWriteData_t data{};
  data.clear();
  for (uint32_t word = 0; word < axi_interconnect::MAX_WRITE_TRANSACTION_WORDS;
       ++word) {
    data[word] = base + word;
  }
  return data;
}

axi_interconnect::WideWriteStrb_t full_line_strobe() {
  axi_interconnect::WideWriteStrb_t strobe{};
  strobe.clear();
  for (uint32_t byte = 0; byte < axi_interconnect::MAX_WRITE_TRANSACTION_BYTES;
       ++byte) {
    strobe.set(byte, true);
  }
  return strobe;
}

axi_interconnect::WideWriteData_t single_word_data(uint32_t value) {
  axi_interconnect::WideWriteData_t data{};
  data.clear();
  data[0] = value;
  return data;
}

axi_interconnect::WideWriteStrb_t byte_strobe(uint32_t mask) {
  axi_interconnect::WideWriteStrb_t strobe{};
  strobe.clear();
  for (uint32_t byte = 0; byte < axi_interconnect::MAX_WRITE_TRANSACTION_BYTES;
       ++byte) {
    if (byte < 32 && ((mask & (uint32_t{1} << byte)) != 0)) {
      strobe.set(byte, true);
    }
  }
  return strobe;
}

std::vector<uint32_t> axi_words(const sim_ddr::axi_data_t &data) {
  std::vector<uint32_t> words(sim_ddr::AXI_DATA_WORDS);
  for (uint32_t word = 0; word < sim_ddr::AXI_DATA_WORDS; ++word) {
    words[word] = axi_compat::get_u32(data, word);
  }
  return words;
}

std::vector<uint32_t> wide_write_words(
    const axi_interconnect::WideWriteData_t &data) {
  std::vector<uint32_t> words(axi_interconnect::MAX_WRITE_TRANSACTION_WORDS);
  for (uint32_t word = 0; word < words.size(); ++word) {
    words[word] = data[word];
  }
  return words;
}

std::vector<uint32_t> wide_read_words(
    const axi_interconnect::WideReadData_t &data) {
  std::vector<uint32_t> words(axi_interconnect::MAX_READ_TRANSACTION_WORDS);
  for (uint32_t word = 0; word < words.size(); ++word) {
    words[word] = data[word];
  }
  return words;
}

uint64_t write_strobe_mask(const axi_interconnect::WideWriteStrb_t &strobe) {
  uint64_t mask = 0;
  for (uint32_t byte = 0; byte < 64 &&
                          byte < axi_interconnect::MAX_WRITE_TRANSACTION_BYTES;
       ++byte) {
    if (strobe.test(byte)) {
      mask |= (uint64_t{1} << byte);
    }
  }
  return mask;
}

uint32_t axi_strobe_mask(const sim_ddr::axi_strb_t &strobe) {
  uint32_t mask = 0;
  for (uint32_t byte = 0; byte < sim_ddr::AXI_DATA_BYTES; ++byte) {
    if (axi_compat::test_bit(strobe, byte)) {
      mask |= (uint32_t{1} << byte);
    }
  }
  return mask;
}

std::string hex_words(const std::vector<uint32_t> &words, uint32_t count) {
  std::ostringstream os;
  os << (count * 32u) << "'h";
  os << std::hex << std::setfill('0');
  for (uint32_t i = 0; i < count; ++i) {
    const uint32_t idx = count - 1u - i;
    os << std::setw(8) << words[idx];
  }
  return os.str();
}

std::string hex_u32(uint32_t value) {
  std::ostringstream os;
  os << "32'h" << std::hex << std::setfill('0') << std::setw(8) << value;
  return os.str();
}

std::string hex_u64(uint64_t value) {
  std::ostringstream os;
  os << "64'h" << std::hex << std::setfill('0') << std::setw(16) << value;
  return os.str();
}

struct ReadTrace {
  std::string prefix;
  uint32_t req_addr = 0;
  uint8_t req_size = 0;
  uint8_t req_id = 0;
  uint32_t araddr = 0;
  uint8_t arlen = 0;
  uint8_t arsize = 0;
  uint8_t arburst = 0;
  uint8_t arid = 0;
  std::array<std::vector<uint32_t>, 2> rbeats{};
  uint32_t beat_count = 0;
  uint8_t resp_id = 0;
  std::vector<uint32_t> resp_data;
};

struct WriteTrace {
  std::string prefix;
  uint32_t req_addr = 0;
  uint8_t req_size = 0;
  uint8_t req_id = 0;
  std::vector<uint32_t> req_wdata;
  uint64_t req_wstrb = 0;
  uint32_t awaddr = 0;
  uint8_t awlen = 0;
  uint8_t awsize = 0;
  uint8_t awburst = 0;
  uint8_t awid = 0;
  std::array<std::vector<uint32_t>, 2> wbeats{};
  std::array<uint32_t, 2> wstrb{};
  std::array<uint8_t, 2> wlast{};
  uint32_t beat_count = 0;
  uint8_t resp_id = 0;
  uint8_t resp_code = 0;
};

struct BlockedTrace {
  std::string prefix;
  uint32_t req_addr = 0;
  uint8_t req_size = 0;
  uint8_t req_id = 0;
  std::vector<uint32_t> req_wdata;
  uint64_t req_wstrb = 0;
  bool req_ready = true;
};

struct OverlapReadTrace {
  ReadTrace ddr;
  ReadTrace mmio;
  uint8_t ddr_master = 0;
  uint8_t mmio_master = 0;
  bool mmio_rready_while_resp_stalled = false;
  bool ddr_rready_while_resp_stalled = false;
};

struct OverlapWriteTrace {
  WriteTrace ddr;
  WriteTrace mmio;
  uint8_t ddr_master = 0;
  uint8_t mmio_master = 0;
  bool mmio_bready_while_resp_stalled = false;
  bool ddr_bready_while_resp_stalled = false;
};

struct SameMasterReadTrace {
  ReadTrace older;
  ReadTrace newer;
  uint8_t master = 0;
  bool newer_rready_while_resp_stalled = false;
  bool older_rready_while_resp_stalled = false;
};

struct SameMasterWriteTrace {
  WriteTrace older;
  WriteTrace newer;
  uint8_t master = 0;
  bool newer_bready_while_resp_stalled = false;
  bool older_bready_while_resp_stalled = false;
};

struct ReadReuseTrace {
  ReadTrace first;
  ReadTrace second;
  uint8_t master = 0;
  bool first_rready = false;
  bool second_rready = false;
};

struct ReadBudgetReleaseTrace {
  uint32_t fill_base_addr = 0;
  uint32_t fill_stride = 0;
  uint32_t fill_limit = 0;
  uint8_t fill_req_size = 0;
  uint32_t blocked_addr = 0;
  uint8_t blocked_master = 0;
  uint8_t blocked_id = 0;
  bool blocked_ready = true;
  ReadTrace release;
  bool release_rready = false;
  ReadTrace after_release;
};

struct WriteReuseTrace {
  WriteTrace first;
  WriteTrace second;
  uint8_t master = 0;
  bool first_bready = false;
  bool second_bready = false;
};

struct WriteBudgetReleaseTrace {
  uint32_t fill_base_addr = 0;
  uint32_t fill_stride = 0;
  uint32_t fill_limit = 0;
  uint8_t fill_req_size = 0;
  uint32_t blocked_addr = 0;
  uint8_t blocked_master = 0;
  uint8_t blocked_id = 0;
  std::vector<uint32_t> blocked_wdata;
  uint64_t blocked_wstrb = 0;
  bool blocked_ready = true;
  WriteTrace release;
  bool release_bready = false;
  WriteTrace after_release;
};

struct CacheWriteMissMmioWriteTrace {
  WriteTrace cache;
  ReadTrace refill;
  WriteTrace mmio;
  uint8_t cache_master = 0;
  uint8_t mmio_master = 0;
  bool mmio_bready_while_resp_stalled = false;
  bool ddr_rready_while_resp_stalled = false;
};

struct DirtyVictimMmioWriteTrace {
  WriteTrace setup0;
  WriteTrace setup1;
  WriteTrace cache;
  WriteTrace writeback;
  WriteTrace mmio;
  uint8_t cache_master = 0;
  uint8_t mmio_master = 0;
  bool mmio_bready_while_resp_stalled = false;
  bool ddr_bready_while_resp_stalled = false;
  bool blocked_while_mmio_resp_held = false;
  bool blocked_while_cache_resp_held = false;
  bool accepted_after_resp_retire = false;
  uint32_t invalidate_line_addr = 0;
  bool invalidate_line_accepted_after_resp_retire = false;
};

struct DirtyVictimMmioReadTrace {
  WriteTrace setup0;
  WriteTrace setup1;
  WriteTrace cache;
  WriteTrace writeback;
  ReadTrace mmio;
  uint8_t cache_master = 0;
  uint8_t mmio_master = 0;
  bool mmio_rready_while_resp_stalled = false;
  bool ddr_bready_while_resp_stalled = false;
  bool blocked_while_mmio_resp_held = false;
  bool blocked_while_cache_resp_held = false;
  bool accepted_after_resp_retire = false;
  uint32_t invalidate_line_addr = 0;
  bool invalidate_line_accepted_after_resp_retire = false;
};

struct DirtyVictimMmioReadWriteTrace {
  WriteTrace setup0;
  WriteTrace setup1;
  WriteTrace cache;
  WriteTrace writeback;
  ReadTrace mmio_read;
  WriteTrace mmio_write;
  uint8_t cache_master = 0;
  uint8_t mmio_read_master = 0;
  uint8_t mmio_write_master = 0;
  bool mmio_rready_while_resp_stalled = false;
  bool mmio_bready_while_resp_stalled = false;
  bool ddr_bready_while_resp_stalled = false;
  bool blocked_while_mmio_resp_held = false;
  bool blocked_while_cache_resp_held = false;
  bool accepted_after_resp_retire = false;
  uint32_t invalidate_line_addr = 0;
  bool invalidate_line_accepted_after_resp_retire = false;
};

struct SameLineReadPendingWriteTrace {
  ReadTrace read;
  BlockedTrace write;
  uint8_t read_master = 0;
  uint8_t write_master = 0;
  bool write_accepted_while_read_pending = false;
  bool no_external_issue_while_read_pending = false;
};

struct SameLineWritePendingReadTrace {
  WriteTrace write;
  BlockedTrace read;
  uint8_t write_master = 0;
  uint8_t read_master = 0;
  bool read_accepted_while_write_pending = false;
  bool no_external_issue_while_write_pending = false;
};

struct Mode2MappedLocalTrace {
  std::string prefix;
  WriteTrace write;
  ReadTrace read;
  uint8_t write_master = 0;
  uint8_t read_master = 0;
};

struct InvalidateLinePendingReadTrace {
  ReadTrace read;
  uint8_t read_master = 0;
  uint32_t invalidate_addr = 0;
  bool blocked_before_r = false;
  bool rready_while_invalidate_pending = false;
  bool blocked_while_resp_held = false;
  bool accepted_after_resp_retire = false;
};

struct InvalidateLineRecoveryReadTrace {
  ReadTrace first;
  ReadTrace second;
  std::string prefix;
  uint8_t read_master = 0;
  uint32_t invalidate_addr = 0;
  bool invalidate_accepted = false;
};

struct InvalidateLineScopeReadTrace {
  ReadTrace victim_fill;
  ReadTrace survivor_fill;
  ReadTrace victim_after;
  ReadTrace survivor_after;
  std::string prefix;
  uint8_t read_master = 0;
  uint32_t invalidate_addr = 0;
  bool invalidate_accepted = false;
  bool survivor_hit_no_external = false;
};

struct InvalidateAllRecoveryReadTrace {
  ReadTrace first_fill;
  ReadTrace second_fill;
  ReadTrace first_after;
  ReadTrace second_after;
  std::string prefix;
  uint8_t read_master = 0;
  bool invalidate_accepted = false;
};

struct InvalidateAllMultiMasterRecoveryReadTrace {
  ReadTrace first_fill;
  ReadTrace second_fill;
  ReadTrace first_after;
  ReadTrace second_after;
  std::string prefix;
  uint8_t first_master = 0;
  uint8_t second_master = 0;
  bool invalidate_accepted = false;
};

struct InvalidateAllRecoveryWriteTrace {
  ReadTrace fill;
  WriteTrace write_after;
  ReadTrace refill_after;
  ReadTrace read_hit_after;
  std::string prefix;
  uint8_t read_master = 0;
  uint8_t write_master = 0;
  bool invalidate_accepted = false;
  bool read_hit_no_external = false;
};

struct InvalidateAllMultiReadTrace {
  ReadTrace first;
  ReadTrace second;
  std::string prefix;
  uint8_t read_master = 0;
  bool first_rready_while_invalidate_pending = false;
  bool second_rready_while_first_resp_held = false;
  bool blocked_while_first_resp_held = false;
  bool blocked_while_second_resp_held = false;
  bool accepted_after_resp_retire = false;
};

struct InvalidateAllMultiMasterReadTrace {
  ReadTrace first;
  ReadTrace second;
  std::string prefix;
  uint8_t first_master = 0;
  uint8_t second_master = 0;
  bool first_rready_while_invalidate_pending = false;
  bool second_rready_while_first_resp_held = false;
  bool blocked_while_first_resp_held = false;
  bool blocked_while_second_resp_held = false;
  bool accepted_after_resp_retire = false;
};

struct InvalidateLineMultiMasterReadTrace {
  ReadTrace first;
  ReadTrace second;
  std::string prefix;
  uint8_t first_master = 0;
  uint8_t second_master = 0;
  uint32_t invalidate_addr = 0;
  bool first_rready_while_invalidate_pending = false;
  bool second_rready_while_first_resp_held = false;
  bool blocked_while_first_resp_held = false;
  bool blocked_while_second_resp_held = false;
  bool accepted_after_resp_retire = false;
};

struct InvalidateLineMultiReadTrace {
  ReadTrace first;
  ReadTrace second;
  std::string prefix;
  uint8_t read_master = 0;
  uint32_t invalidate_addr = 0;
  bool first_rready_while_invalidate_pending = false;
  bool second_rready_while_first_resp_held = false;
  bool blocked_while_first_resp_held = false;
  bool blocked_while_second_resp_held = false;
  bool accepted_after_resp_retire = false;
};

struct InvalidateLineCacheReadWriteTrace {
  ReadTrace read;
  WriteTrace write;
  ReadTrace write_refill;
  std::string prefix;
  uint8_t read_master = 0;
  uint8_t write_master = 0;
  uint32_t invalidate_addr = 0;
  bool read_rready_while_invalidate_pending = false;
  bool write_rready_while_read_resp_held = false;
  bool blocked_while_read_resp_held = false;
  bool blocked_while_write_resp_held = false;
  bool accepted_after_resp_retire = false;
};

struct InvalidateAllCacheReadWriteTrace {
  ReadTrace read;
  WriteTrace write;
  ReadTrace write_refill;
  std::string prefix;
  uint8_t read_master = 0;
  uint8_t write_master = 0;
  bool read_rready_while_invalidate_pending = false;
  bool write_rready_while_read_resp_held = false;
  bool blocked_while_read_resp_held = false;
  bool blocked_while_write_resp_held = false;
  bool accepted_after_resp_retire = false;
};

struct ReconfigCacheReadTrace {
  ReadTrace read;
  uint8_t read_master = 0;
  bool rready_while_reconfig_pending = false;
};

struct ReconfigCacheWriteTrace {
  WriteTrace write;
  ReadTrace refill;
  uint8_t write_master = 0;
  bool rready_while_reconfig_pending = false;
  bool blocked_after_resp_retire = false;
};

struct InvalidateLineCacheMmioReadTrace {
  OverlapReadTrace overlap;
  std::string prefix;
  uint32_t invalidate_addr = 0;
  bool mmio_rready_while_invalidate_pending = false;
  bool ddr_rready_while_mmio_resp_held = false;
  bool blocked_while_mmio_resp_held = false;
  bool blocked_while_cache_resp_held = false;
  bool accepted_after_resp_retire = false;
};

struct InvalidateLineCacheMmioWriteTrace {
  CacheWriteMissMmioWriteTrace flow;
  std::string prefix;
  uint32_t invalidate_addr = 0;
  bool mmio_bready_while_invalidate_pending = false;
  bool ddr_rready_while_mmio_resp_held = false;
  bool blocked_while_mmio_resp_held = false;
  bool blocked_while_cache_resp_held = false;
  bool accepted_after_resp_retire = false;
};

struct InvalidateAllCacheMmioReadTrace {
  OverlapReadTrace overlap;
  std::string prefix;
  bool mmio_rready_while_invalidate_pending = false;
  bool ddr_rready_while_mmio_resp_held = false;
  bool blocked_while_mmio_resp_held = false;
  bool blocked_while_cache_resp_held = false;
  bool accepted_after_resp_retire = false;
};

struct InvalidateAllCacheMmioWriteTrace {
  CacheWriteMissMmioWriteTrace flow;
  std::string prefix;
  bool mmio_bready_while_invalidate_pending = false;
  bool ddr_rready_while_mmio_resp_held = false;
  bool blocked_while_mmio_resp_held = false;
  bool blocked_while_cache_resp_held = false;
  bool accepted_after_resp_retire = false;
};

struct InvalidateAllCacheMmioReadWriteTrace {
  OverlapReadTrace overlap;
  WriteTrace mmio_write;
  std::string prefix;
  uint8_t mmio_write_master = 0;
  bool mmio_rready_while_invalidate_pending = false;
  bool mmio_bready_while_invalidate_pending = false;
  bool ddr_rready_while_mmio_resp_held = false;
  bool blocked_while_mmio_resp_held = false;
  bool blocked_while_cache_resp_held = false;
  bool accepted_after_resp_retire = false;
};

struct InvalidateLineCacheMmioReadWriteTrace {
  OverlapReadTrace overlap;
  WriteTrace mmio_write;
  std::string prefix;
  uint8_t mmio_write_master = 0;
  uint32_t invalidate_addr = 0;
  bool mmio_rready_while_invalidate_pending = false;
  bool mmio_bready_while_invalidate_pending = false;
  bool ddr_rready_while_mmio_resp_held = false;
  bool blocked_while_mmio_resp_held = false;
  bool blocked_while_cache_resp_held = false;
  bool accepted_after_resp_retire = false;
};

struct InvalidateLineCacheWriteMmioReadWriteTrace {
  CacheWriteMissMmioWriteTrace flow;
  ReadTrace mmio_read;
  std::string prefix;
  uint8_t mmio_read_master = 0;
  uint32_t invalidate_addr = 0;
  bool mmio_rready_while_invalidate_pending = false;
  bool mmio_bready_while_invalidate_pending = false;
  bool ddr_rready_while_mmio_resp_held = false;
  bool blocked_while_mmio_resp_held = false;
  bool blocked_while_cache_resp_held = false;
  bool accepted_after_resp_retire = false;
};

struct InvalidateAllCacheWriteMmioReadWriteTrace {
  CacheWriteMissMmioWriteTrace flow;
  ReadTrace mmio_read;
  std::string prefix;
  uint8_t mmio_read_master = 0;
  bool mmio_rready_while_invalidate_pending = false;
  bool mmio_bready_while_invalidate_pending = false;
  bool ddr_rready_while_mmio_resp_held = false;
  bool blocked_while_mmio_resp_held = false;
  bool blocked_while_cache_resp_held = false;
  bool accepted_after_resp_retire = false;
};

struct InvalidateAllMmioReadWriteTrace {
  ReadTrace read;
  WriteTrace write;
  std::string prefix;
  bool blocked_before_resp = false;
  bool rready_while_pending = false;
  bool bready_while_pending = false;
  bool blocked_while_both_held = false;
  bool blocked_after_read_retire = false;
  bool accepted_after_both_retire = false;
};

void issue_write_and_capture_axi(
    axi_interconnect::AXI_Interconnect &dut, WriteTrace &trace,
    uint8_t master, axi_interconnect::DownstreamPort port,
    const axi_interconnect::WideWriteData_t &data,
    const axi_interconnect::WideWriteStrb_t &strobe);

bool enqueue_write(axi_interconnect::AXI_Interconnect &dut, uint32_t addr,
                   uint8_t total_size,
                   const axi_interconnect::WideWriteData_t &data,
                   const axi_interconnect::WideWriteStrb_t &strobe,
                   uint8_t req_id,
                   uint8_t master = axi_interconnect::MASTER_DCACHE_W);

void capture_write_response(axi_interconnect::AXI_Interconnect &dut,
                            WriteTrace &trace, uint8_t master);

void issue_cache_write_and_wait_response(
    axi_interconnect::AXI_Interconnect &dut, StatefulLlcTableDriver &table_driver,
    WriteTrace &trace, uint8_t master,
    const axi_interconnect::WideWriteData_t &data,
    const axi_interconnect::WideWriteStrb_t &strobe);

void capture_write_response_with_table(
    axi_interconnect::AXI_Interconnect &dut, StatefulLlcTableDriver &table_driver,
    WriteTrace &trace, uint8_t master);

void issue_mapped_read_and_wait_response(
    axi_interconnect::AXI_Interconnect &dut, StatefulLlcTableDriver &table_driver,
    ReadTrace &trace, uint8_t master);

void issue_cache_read_miss_and_wait_response(
    axi_interconnect::AXI_Interconnect &dut, StatefulLlcTableDriver &table_driver,
    ReadTrace &trace, uint8_t master, uint32_t beat_seed);

void issue_cache_read_hit_and_wait_response(
    axi_interconnect::AXI_Interconnect &dut, StatefulLlcTableDriver &table_driver,
    ReadTrace &trace, uint8_t master, bool &no_external_issue);

void issue_read_and_capture_ar(axi_interconnect::AXI_Interconnect &dut,
                               ReadTrace &trace, uint8_t master,
                               axi_interconnect::DownstreamPort port) {
  bool accepted = false;
  bool ar_seen = false;
  for (int cycle = 0; cycle < 8 && !ar_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    auto &req = dut.read_ports[master].req;
    req.valid = true;
    req.addr = trace.req_addr;
    req.total_size = trace.req_size;
    req.id = trace.req_id;
    req.bypass = false;
    dut.comb_inputs();
    if (dut.read_ports[master].req.ready) {
      accepted = true;
    }
    if (port == axi_interconnect::DownstreamPort::DDR &&
        dut.axi_ddr_io.ar.arvalid) {
      require(!dut.axi_mmio_io.ar.arvalid,
              "C++ overlapped DDR read escaped to MMIO AR");
      trace.araddr = static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
      trace.arlen = static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
      trace.arsize = static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
      trace.arburst = static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
      trace.arid = static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
      ar_seen = true;
    } else if (port == axi_interconnect::DownstreamPort::MMIO &&
               dut.axi_mmio_io.ar.arvalid) {
      require(!dut.axi_ddr_io.ar.arvalid,
              "C++ overlapped MMIO read escaped to DDR AR");
      trace.araddr = static_cast<uint32_t>(dut.axi_mmio_io.ar.araddr);
      trace.arlen = static_cast<uint8_t>(dut.axi_mmio_io.ar.arlen);
      trace.arsize = static_cast<uint8_t>(dut.axi_mmio_io.ar.arsize);
      trace.arburst = static_cast<uint8_t>(dut.axi_mmio_io.ar.arburst);
      trace.arid = static_cast<uint8_t>(dut.axi_mmio_io.ar.arid);
      ar_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ overlapped read request was not accepted");
  require(ar_seen, "C++ overlapped read did not issue expected AR");
}

void capture_read_response(axi_interconnect::AXI_Interconnect &dut,
                           ReadTrace &trace, uint8_t master) {
  clear_inputs(dut);
  dut.comb_outputs();
  auto &resp = dut.read_ports[master].resp;
  require(resp.valid, "C++ overlapped read response did not become valid");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_data = wide_read_words(resp.data);
  resp.ready = true;
  dut.comb_outputs();
  require(resp.valid, "C++ overlapped read response dropped before ready");
  dut.seq();
  ++sim_time;
}

ReadTrace run_read_trace(const std::string &prefix, uint32_t addr,
                         uint8_t total_size, uint8_t req_id,
                         const std::vector<uint32_t> &rbeat_bases) {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);

  ReadTrace trace{};
  trace.prefix = prefix;
  trace.req_addr = addr;
  trace.req_size = total_size;
  trace.req_id = req_id;
  trace.beat_count = static_cast<uint32_t>(rbeat_bases.size());

  auto &req = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].req;
  req.valid = true;
  req.addr = addr;
  req.total_size = total_size;
  req.id = req_id;
  req.bypass = false;
  dut.comb_inputs();
  require(req.ready, "C++ read request was not ready");
  require(dut.axi_ddr_io.ar.arvalid, "C++ read did not issue DDR AR");
  require(!dut.axi_mmio_io.ar.arvalid, "C++ read escaped to MMIO AR");

  trace.araddr = static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
  trace.arlen = static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
  trace.arsize = static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
  trace.arburst = static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
  trace.arid = static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);

  dut.seq();
  ++sim_time;
  idle_request_outputs(dut);

  for (uint32_t beat = 0; beat < trace.beat_count; ++beat) {
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = trace.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == trace.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(rbeat_bases[beat]);
    trace.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    require(dut.axi_ddr_io.r.rready, "C++ read R was backpressured");
    dut.seq();
    ++sim_time;
    dut.axi_ddr_io.r.rvalid = false;
    dut.axi_ddr_io.r.rlast = false;
    dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp.ready = true;
    dut.comb_outputs();
  }

  const auto &resp = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp;
  require(resp.valid, "C++ read response did not become valid");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_data = wide_read_words(resp.data);
  dut.seq();
  ++sim_time;
  return trace;
}

ReadTrace run_mmio_read_trace(const std::string &prefix, uint32_t addr,
                              uint8_t total_size, uint8_t req_id,
                              uint32_t rdata_word) {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);

  ReadTrace trace{};
  trace.prefix = prefix;
  trace.req_addr = addr;
  trace.req_size = total_size;
  trace.req_id = req_id;
  trace.beat_count = 1;

  auto &req = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].req;
  req.valid = true;
  req.addr = addr;
  req.total_size = total_size;
  req.id = req_id;
  req.bypass = false;
  dut.comb_inputs();
  require(req.ready, "C++ MMIO read request was not ready");
  require(dut.axi_mmio_io.ar.arvalid, "C++ MMIO read did not issue MMIO AR");
  require(!dut.axi_ddr_io.ar.arvalid, "C++ MMIO read escaped to DDR AR");
  require(!dut.axi_ddr_io.aw.awvalid && !dut.axi_ddr_io.w.wvalid,
          "C++ MMIO read leaked write-side DDR activity");

  trace.araddr = static_cast<uint32_t>(dut.axi_mmio_io.ar.araddr);
  trace.arlen = static_cast<uint8_t>(dut.axi_mmio_io.ar.arlen);
  trace.arsize = static_cast<uint8_t>(dut.axi_mmio_io.ar.arsize);
  trace.arburst = static_cast<uint8_t>(dut.axi_mmio_io.ar.arburst);
  trace.arid = static_cast<uint8_t>(dut.axi_mmio_io.ar.arid);

  dut.seq();
  ++sim_time;
  idle_request_outputs(dut);

  dut.axi_mmio_io.r.rvalid = true;
  dut.axi_mmio_io.r.rid = trace.arid;
  dut.axi_mmio_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_mmio_io.r.rlast = true;
  dut.axi_mmio_io.r.rdata = {};
  axi_compat::set_u32(dut.axi_mmio_io.r.rdata, 0, rdata_word);
  trace.rbeats[0] = axi_words(dut.axi_mmio_io.r.rdata);
  dut.comb_outputs();
  require(dut.axi_mmio_io.r.rready, "C++ MMIO read R was backpressured");
  dut.seq();
  ++sim_time;

  dut.axi_mmio_io.r.rvalid = false;
  dut.axi_mmio_io.r.rlast = false;
  dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp.ready = true;
  dut.comb_outputs();

  const auto &resp = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp;
  require(resp.valid, "C++ MMIO read response did not become valid");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_data = wide_read_words(resp.data);
  dut.seq();
  ++sim_time;
  return trace;
}

ReadTrace run_mode1_mmio_read_trace(const std::string &prefix, uint32_t addr,
                                    uint8_t total_size, uint8_t req_id,
                                    uint32_t rdata_word) {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);

  ReadTrace trace{};
  trace.prefix = prefix;
  trace.req_addr = addr;
  trace.req_size = total_size;
  trace.req_id = req_id;
  trace.beat_count = 1;

  auto &req = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].req;
  req.valid = true;
  req.addr = addr;
  req.total_size = total_size;
  req.id = req_id;
  req.bypass = false;
  dut.comb_inputs();
  require(req.ready, "C++ mode1 MMIO read request was not ready");
  require(dut.axi_mmio_io.ar.arvalid,
          "C++ mode1 MMIO read did not issue MMIO AR");
  require(!dut.axi_ddr_io.ar.arvalid,
          "C++ mode1 MMIO read escaped to DDR AR");

  trace.araddr = static_cast<uint32_t>(dut.axi_mmio_io.ar.araddr);
  trace.arlen = static_cast<uint8_t>(dut.axi_mmio_io.ar.arlen);
  trace.arsize = static_cast<uint8_t>(dut.axi_mmio_io.ar.arsize);
  trace.arburst = static_cast<uint8_t>(dut.axi_mmio_io.ar.arburst);
  trace.arid = static_cast<uint8_t>(dut.axi_mmio_io.ar.arid);

  dut.seq();
  ++sim_time;
  idle_request_outputs(dut);

  dut.axi_mmio_io.r.rvalid = true;
  dut.axi_mmio_io.r.rid = trace.arid;
  dut.axi_mmio_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_mmio_io.r.rlast = true;
  dut.axi_mmio_io.r.rdata = {};
  axi_compat::set_u32(dut.axi_mmio_io.r.rdata, 0, rdata_word);
  trace.rbeats[0] = axi_words(dut.axi_mmio_io.r.rdata);
  dut.comb_outputs();
  require(dut.axi_mmio_io.r.rready,
          "C++ mode1 MMIO read R was backpressured");
  dut.seq();
  ++sim_time;

  dut.axi_mmio_io.r.rvalid = false;
  dut.axi_mmio_io.r.rlast = false;
  dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp.ready = true;
  dut.comb_outputs();
  const auto &resp = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp;
  require(resp.valid, "C++ mode1 MMIO read response did not become valid");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_data = wide_read_words(resp.data);
  dut.seq();
  ++sim_time;
  return trace;
}

void accept_mode1_invalidate_all(axi_interconnect::AXI_Interconnect &dut) {
  for (int retry = 0; retry < 32; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    const bool accepted = dut.llc_invalidate_all_accepted();
    dut.seq();
    ++sim_time;
    if (accepted) {
      dut.set_llc_invalidate_all(false);
      clear_inputs(dut);
      set_downstream_ready(dut);
      dut.comb_outputs();
      dut.comb_inputs();
      dut.seq();
      ++sim_time;
      return;
    }
  }
  require(false, "C++ mode1 invalidate-all was not accepted");
}

ReadTrace run_mode1_invalidate_all_recovery_mmio_read_trace(
    const std::string &prefix, uint32_t addr, uint8_t total_size,
    uint8_t req_id, uint32_t rdata_word) {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  accept_mode1_invalidate_all(dut);

  ReadTrace trace{};
  trace.prefix = prefix;
  trace.req_addr = addr;
  trace.req_size = total_size;
  trace.req_id = req_id;
  trace.beat_count = 1;

  auto &req = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].req;
  req.valid = true;
  req.addr = addr;
  req.total_size = total_size;
  req.id = req_id;
  req.bypass = false;
  dut.comb_inputs();
  require(req.ready,
          "C++ mode1 invalidate-all recovery MMIO read request was not ready");
  require(dut.axi_mmio_io.ar.arvalid,
          "C++ mode1 invalidate-all recovery MMIO read did not issue MMIO AR");
  require(!dut.axi_ddr_io.ar.arvalid,
          "C++ mode1 invalidate-all recovery MMIO read escaped to DDR AR");

  trace.araddr = static_cast<uint32_t>(dut.axi_mmio_io.ar.araddr);
  trace.arlen = static_cast<uint8_t>(dut.axi_mmio_io.ar.arlen);
  trace.arsize = static_cast<uint8_t>(dut.axi_mmio_io.ar.arsize);
  trace.arburst = static_cast<uint8_t>(dut.axi_mmio_io.ar.arburst);
  trace.arid = static_cast<uint8_t>(dut.axi_mmio_io.ar.arid);

  dut.seq();
  ++sim_time;
  idle_request_outputs(dut);

  dut.axi_mmio_io.r.rvalid = true;
  dut.axi_mmio_io.r.rid = trace.arid;
  dut.axi_mmio_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_mmio_io.r.rlast = true;
  dut.axi_mmio_io.r.rdata = {};
  axi_compat::set_u32(dut.axi_mmio_io.r.rdata, 0, rdata_word);
  trace.rbeats[0] = axi_words(dut.axi_mmio_io.r.rdata);
  dut.comb_outputs();
  require(dut.axi_mmio_io.r.rready,
          "C++ mode1 invalidate-all recovery MMIO read R was backpressured");
  dut.seq();
  ++sim_time;

  dut.axi_mmio_io.r.rvalid = false;
  dut.axi_mmio_io.r.rlast = false;
  dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp.ready = true;
  dut.comb_outputs();
  const auto &resp = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp;
  require(resp.valid,
          "C++ mode1 invalidate-all recovery MMIO read response did not become valid");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_data = wide_read_words(resp.data);
  dut.seq();
  ++sim_time;
  return trace;
}

ReadTrace run_mode1_invalidate_all_pending_mmio_read_trace(
    const std::string &prefix, uint32_t addr, uint8_t total_size,
    uint8_t req_id, uint32_t rdata_word) {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);

  ReadTrace trace{};
  trace.prefix = prefix;
  trace.req_addr = addr;
  trace.req_size = total_size;
  trace.req_id = req_id;
  trace.beat_count = 1;

  auto &req = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].req;
  req.valid = true;
  req.addr = addr;
  req.total_size = total_size;
  req.id = req_id;
  req.bypass = false;
  dut.comb_inputs();
  require(req.ready,
          "C++ mode1 pending-invalidate MMIO read request was not ready");
  require(dut.axi_mmio_io.ar.arvalid,
          "C++ mode1 pending-invalidate MMIO read did not issue MMIO AR");
  require(!dut.axi_ddr_io.ar.arvalid,
          "C++ mode1 pending-invalidate MMIO read escaped to DDR AR");

  trace.araddr = static_cast<uint32_t>(dut.axi_mmio_io.ar.araddr);
  trace.arlen = static_cast<uint8_t>(dut.axi_mmio_io.ar.arlen);
  trace.arsize = static_cast<uint8_t>(dut.axi_mmio_io.ar.arsize);
  trace.arburst = static_cast<uint8_t>(dut.axi_mmio_io.ar.arburst);
  trace.arid = static_cast<uint8_t>(dut.axi_mmio_io.ar.arid);

  dut.seq();
  ++sim_time;
  idle_request_outputs(dut);

  dut.set_llc_invalidate_all(true);
  for (int cycle = 0; cycle < 4; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    require(!dut.llc_invalidate_all_accepted(),
            "C++ mode1 invalidate-all accepted with MMIO read pending");
    dut.seq();
    ++sim_time;
  }

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.set_llc_invalidate_all(true);
  dut.axi_mmio_io.r.rvalid = true;
  dut.axi_mmio_io.r.rid = trace.arid;
  dut.axi_mmio_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_mmio_io.r.rlast = true;
  dut.axi_mmio_io.r.rdata = {};
  axi_compat::set_u32(dut.axi_mmio_io.r.rdata, 0, rdata_word);
  trace.rbeats[0] = axi_words(dut.axi_mmio_io.r.rdata);
  dut.comb_outputs();
  require(dut.axi_mmio_io.r.rready,
          "C++ mode1 pending-invalidate MMIO R was backpressured");
  dut.comb_inputs();
  require(!dut.llc_invalidate_all_accepted(),
          "C++ mode1 invalidate-all accepted in MMIO R handshake cycle");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.set_llc_invalidate_all(true);
  dut.comb_outputs();
  const auto &held_resp =
      dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp;
  require(held_resp.valid,
          "C++ mode1 pending-invalidate MMIO response was not held");
  dut.comb_inputs();
  require(!dut.llc_invalidate_all_accepted(),
          "C++ mode1 invalidate-all accepted while MMIO response held");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.set_llc_invalidate_all(true);
  dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp.ready = true;
  dut.comb_outputs();
  const auto &resp = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp;
  require(resp.valid,
          "C++ mode1 pending-invalidate MMIO response did not become valid");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_data = wide_read_words(resp.data);
  dut.comb_inputs();
  require(!dut.llc_invalidate_all_accepted(),
          "C++ mode1 invalidate-all accepted before MMIO response retired");
  dut.seq();
  ++sim_time;

  for (int retry = 0; retry < 64; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    const bool accepted = dut.llc_invalidate_all_accepted();
    dut.seq();
    ++sim_time;
    if (accepted) {
      dut.set_llc_invalidate_all(false);
      return trace;
    }
  }
  require(false,
          "C++ mode1 invalidate-all did not accept after MMIO read retired");
  return trace;
}

ReadTrace run_mode1_invalidate_all_pre_ar_mmio_read_trace(
    const std::string &prefix, uint32_t addr, uint8_t total_size,
    uint8_t req_id, uint32_t rdata_word) {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);

  ReadTrace trace{};
  trace.prefix = prefix;
  trace.req_addr = addr;
  trace.req_size = total_size;
  trace.req_id = req_id;
  trace.beat_count = 1;

  set_downstream_ready(dut);
  dut.axi_mmio_io.ar.arready = false;
  auto &req = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].req;
  req.valid = true;
  req.addr = addr;
  req.total_size = total_size;
  req.id = req_id;
  req.bypass = false;
  dut.comb_inputs();
  require(dut.axi_mmio_io.ar.arvalid,
          "C++ mode1 pre-AR invalidate MMIO read did not issue MMIO AR");
  require(!dut.axi_ddr_io.ar.arvalid,
          "C++ mode1 pre-AR invalidate MMIO read escaped to DDR AR");

  trace.araddr = static_cast<uint32_t>(dut.axi_mmio_io.ar.araddr);
  trace.arlen = static_cast<uint8_t>(dut.axi_mmio_io.ar.arlen);
  trace.arsize = static_cast<uint8_t>(dut.axi_mmio_io.ar.arsize);
  trace.arburst = static_cast<uint8_t>(dut.axi_mmio_io.ar.arburst);
  trace.arid = static_cast<uint8_t>(dut.axi_mmio_io.ar.arid);
  dut.seq();
  ++sim_time;

  for (int cycle = 0; cycle < 4; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    dut.axi_mmio_io.ar.arready = false;
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    require(dut.axi_mmio_io.ar.arvalid,
            "C++ mode1 pre-AR invalidate lost pending MMIO AR");
    require(!dut.llc_invalidate_all_accepted(),
            "C++ mode1 invalidate-all accepted with MMIO AR pending");
    dut.seq();
    ++sim_time;
  }

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.set_llc_invalidate_all(true);
  dut.comb_outputs();
  dut.comb_inputs();
  require(dut.axi_mmio_io.ar.arvalid,
          "C++ mode1 pre-AR invalidate did not retain MMIO AR");
  require(!dut.llc_invalidate_all_accepted(),
          "C++ mode1 invalidate-all accepted in MMIO AR handshake cycle");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.set_llc_invalidate_all(true);
  dut.axi_mmio_io.r.rvalid = true;
  dut.axi_mmio_io.r.rid = trace.arid;
  dut.axi_mmio_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_mmio_io.r.rlast = true;
  dut.axi_mmio_io.r.rdata = {};
  axi_compat::set_u32(dut.axi_mmio_io.r.rdata, 0, rdata_word);
  trace.rbeats[0] = axi_words(dut.axi_mmio_io.r.rdata);
  dut.comb_outputs();
  require(dut.axi_mmio_io.r.rready,
          "C++ mode1 pre-AR invalidate MMIO R was backpressured");
  dut.comb_inputs();
  require(!dut.llc_invalidate_all_accepted(),
          "C++ mode1 invalidate-all accepted in pre-AR R handshake cycle");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.set_llc_invalidate_all(true);
  dut.comb_outputs();
  const auto &held_resp =
      dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp;
  require(held_resp.valid,
          "C++ mode1 pre-AR invalidate MMIO response was not held");
  dut.comb_inputs();
  require(!dut.llc_invalidate_all_accepted(),
          "C++ mode1 invalidate-all accepted while pre-AR response held");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.set_llc_invalidate_all(true);
  dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp.ready = true;
  dut.comb_outputs();
  const auto &resp = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp;
  require(resp.valid,
          "C++ mode1 pre-AR invalidate MMIO response did not become valid");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_data = wide_read_words(resp.data);
  dut.comb_inputs();
  require(!dut.llc_invalidate_all_accepted(),
          "C++ mode1 invalidate-all accepted before pre-AR response retired");
  dut.seq();
  ++sim_time;

  for (int retry = 0; retry < 64; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    const bool accepted = dut.llc_invalidate_all_accepted();
    dut.seq();
    ++sim_time;
    if (accepted) {
      dut.set_llc_invalidate_all(false);
      return trace;
    }
  }
  require(false,
          "C++ mode1 invalidate-all did not accept after pre-AR read retired");
  return trace;
}

WriteTrace run_mode1_invalidate_all_pending_mmio_write_trace(
    const std::string &prefix, uint32_t addr, uint8_t total_size,
    uint8_t req_id, const axi_interconnect::WideWriteData_t &data,
    const axi_interconnect::WideWriteStrb_t &strobe) {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);

  WriteTrace trace{};
  trace.prefix = prefix;
  trace.req_addr = addr;
  trace.req_size = total_size;
  trace.req_id = req_id;
  trace.req_wdata = wide_write_words(data);
  trace.req_wstrb = write_strobe_mask(strobe);

  require(enqueue_write(dut, addr, total_size, data, strobe, req_id),
          "C++ mode1 pending-invalidate MMIO write request was not accepted");

  clear_inputs(dut);
  dut.comb_inputs();
  require(dut.axi_mmio_io.aw.awvalid,
          "C++ mode1 pending-invalidate MMIO write did not issue MMIO AW");
  require(!dut.axi_ddr_io.aw.awvalid,
          "C++ mode1 pending-invalidate MMIO write escaped to DDR AW");
  require(!dut.axi_ddr_io.w.wvalid,
          "C++ mode1 pending-invalidate MMIO write escaped to DDR W");
  trace.awaddr = static_cast<uint32_t>(dut.axi_mmio_io.aw.awaddr);
  trace.awlen = static_cast<uint8_t>(dut.axi_mmio_io.aw.awlen);
  trace.awsize = static_cast<uint8_t>(dut.axi_mmio_io.aw.awsize);
  trace.awburst = static_cast<uint8_t>(dut.axi_mmio_io.aw.awburst);
  trace.awid = static_cast<uint8_t>(dut.axi_mmio_io.aw.awid);
  trace.beat_count = static_cast<uint32_t>(trace.awlen) + 1u;
  dut.seq();
  ++sim_time;

  for (uint32_t beat = 0; beat < trace.beat_count; ++beat) {
    clear_inputs(dut);
    dut.comb_inputs();
    require(dut.axi_mmio_io.w.wvalid,
            "C++ mode1 pending-invalidate MMIO write W did not become valid");
    require(!dut.axi_ddr_io.w.wvalid,
            "C++ mode1 pending-invalidate MMIO write W escaped to DDR");
    trace.wbeats[beat] = axi_words(dut.axi_mmio_io.w.wdata);
    trace.wstrb[beat] = axi_strobe_mask(dut.axi_mmio_io.w.wstrb);
    trace.wlast[beat] = dut.axi_mmio_io.w.wlast ? 1 : 0;
    dut.seq();
    ++sim_time;
  }

  dut.set_llc_invalidate_all(true);
  for (int cycle = 0; cycle < 4; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    require(!dut.llc_invalidate_all_accepted(),
            "C++ mode1 invalidate-all accepted with MMIO write pending");
    dut.seq();
    ++sim_time;
  }

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.set_llc_invalidate_all(true);
  dut.axi_mmio_io.b.bvalid = true;
  dut.axi_mmio_io.b.bid = trace.awid;
  dut.axi_mmio_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  require(dut.axi_mmio_io.b.bready,
          "C++ mode1 pending-invalidate MMIO B was backpressured");
  dut.comb_inputs();
  require(!dut.llc_invalidate_all_accepted(),
          "C++ mode1 invalidate-all accepted in MMIO B handshake cycle");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.set_llc_invalidate_all(true);
  dut.comb_outputs();
  const auto &held_resp =
      dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp;
  require(held_resp.valid,
          "C++ mode1 pending-invalidate MMIO write response was not held");
  dut.comb_inputs();
  require(!dut.llc_invalidate_all_accepted(),
          "C++ mode1 invalidate-all accepted while MMIO write response held");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.set_llc_invalidate_all(true);
  dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp.ready = true;
  dut.comb_outputs();
  const auto &resp = dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp;
  require(resp.valid,
          "C++ mode1 pending-invalidate MMIO write response was not valid");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_code = static_cast<uint8_t>(resp.resp);
  dut.comb_inputs();
  require(!dut.llc_invalidate_all_accepted(),
          "C++ mode1 invalidate-all accepted before MMIO write response retired");
  dut.seq();
  ++sim_time;

  for (int retry = 0; retry < 64; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    const bool accepted = dut.llc_invalidate_all_accepted();
    dut.seq();
    ++sim_time;
    if (accepted) {
      dut.set_llc_invalidate_all(false);
      return trace;
    }
  }
  require(false,
          "C++ mode1 invalidate-all did not accept after MMIO write retired");
  return trace;
}

InvalidateAllMmioReadWriteTrace
run_mode1_invalidate_all_pending_mmio_read_write_trace(
    const std::string &prefix, uint32_t read_addr, uint8_t read_size,
    uint8_t read_id, uint32_t read_data_word, uint32_t write_addr,
    uint8_t write_size, uint8_t write_id,
    const axi_interconnect::WideWriteData_t &write_data,
    const axi_interconnect::WideWriteStrb_t &write_strobe) {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);

  InvalidateAllMmioReadWriteTrace trace{};
  trace.prefix = prefix;
  trace.read.prefix = prefix + "_READ";
  trace.read.req_addr = read_addr;
  trace.read.req_size = read_size;
  trace.read.req_id = read_id;
  trace.read.beat_count = 1;
  trace.write.prefix = prefix + "_WRITE";
  trace.write.req_addr = write_addr;
  trace.write.req_size = write_size;
  trace.write.req_id = write_id;
  trace.write.req_wdata = wide_write_words(write_data);
  trace.write.req_wstrb = write_strobe_mask(write_strobe);

  auto &read_req = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].req;
  read_req.valid = true;
  read_req.addr = read_addr;
  read_req.total_size = read_size;
  read_req.id = read_id;
  read_req.bypass = false;
  dut.comb_inputs();
  require(read_req.ready,
          "C++ mode1 pending-invalidate RW MMIO read was not ready");
  require(dut.axi_mmio_io.ar.arvalid,
          "C++ mode1 pending-invalidate RW MMIO read did not issue AR");
  require(!dut.axi_ddr_io.ar.arvalid,
          "C++ mode1 pending-invalidate RW MMIO read escaped to DDR AR");
  trace.read.araddr = static_cast<uint32_t>(dut.axi_mmio_io.ar.araddr);
  trace.read.arlen = static_cast<uint8_t>(dut.axi_mmio_io.ar.arlen);
  trace.read.arsize = static_cast<uint8_t>(dut.axi_mmio_io.ar.arsize);
  trace.read.arburst = static_cast<uint8_t>(dut.axi_mmio_io.ar.arburst);
  trace.read.arid = static_cast<uint8_t>(dut.axi_mmio_io.ar.arid);
  dut.seq();
  ++sim_time;
  idle_request_outputs(dut);

  require(enqueue_write(dut, write_addr, write_size, write_data, write_strobe,
                        write_id),
          "C++ mode1 pending-invalidate RW MMIO write was not accepted");
  clear_inputs(dut);
  dut.comb_inputs();
  require(dut.axi_mmio_io.aw.awvalid,
          "C++ mode1 pending-invalidate RW MMIO write did not issue AW");
  require(!dut.axi_ddr_io.aw.awvalid && !dut.axi_ddr_io.w.wvalid,
          "C++ mode1 pending-invalidate RW MMIO write escaped to DDR");
  trace.write.awaddr = static_cast<uint32_t>(dut.axi_mmio_io.aw.awaddr);
  trace.write.awlen = static_cast<uint8_t>(dut.axi_mmio_io.aw.awlen);
  trace.write.awsize = static_cast<uint8_t>(dut.axi_mmio_io.aw.awsize);
  trace.write.awburst = static_cast<uint8_t>(dut.axi_mmio_io.aw.awburst);
  trace.write.awid = static_cast<uint8_t>(dut.axi_mmio_io.aw.awid);
  trace.write.beat_count = static_cast<uint32_t>(trace.write.awlen) + 1u;
  dut.seq();
  ++sim_time;

  for (uint32_t beat = 0; beat < trace.write.beat_count; ++beat) {
    clear_inputs(dut);
    dut.comb_inputs();
    require(dut.axi_mmio_io.w.wvalid,
            "C++ mode1 pending-invalidate RW MMIO write W missing");
    require(!dut.axi_ddr_io.w.wvalid,
            "C++ mode1 pending-invalidate RW MMIO write W escaped to DDR");
    trace.write.wbeats[beat] = axi_words(dut.axi_mmio_io.w.wdata);
    trace.write.wstrb[beat] = axi_strobe_mask(dut.axi_mmio_io.w.wstrb);
    trace.write.wlast[beat] = dut.axi_mmio_io.w.wlast ? 1 : 0;
    dut.seq();
    ++sim_time;
  }

  dut.set_llc_invalidate_all(true);
  trace.blocked_before_resp = true;
  for (int cycle = 0; cycle < 4; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    const bool accepted = dut.llc_invalidate_all_accepted();
    trace.blocked_before_resp = trace.blocked_before_resp && !accepted;
    require(!accepted,
            "C++ mode1 invalidate-all accepted with MMIO read/write pending");
    dut.seq();
    ++sim_time;
  }

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.set_llc_invalidate_all(true);
  dut.axi_mmio_io.r.rvalid = true;
  dut.axi_mmio_io.r.rid = trace.read.arid;
  dut.axi_mmio_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_mmio_io.r.rlast = true;
  dut.axi_mmio_io.r.rdata = {};
  axi_compat::set_u32(dut.axi_mmio_io.r.rdata, 0, read_data_word);
  trace.read.rbeats[0] = axi_words(dut.axi_mmio_io.r.rdata);
  dut.axi_mmio_io.b.bvalid = true;
  dut.axi_mmio_io.b.bid = trace.write.awid;
  dut.axi_mmio_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  trace.rready_while_pending = dut.axi_mmio_io.r.rready;
  trace.bready_while_pending = dut.axi_mmio_io.b.bready;
  require(trace.rready_while_pending,
          "C++ mode1 pending-invalidate RW MMIO R was backpressured");
  require(trace.bready_while_pending,
          "C++ mode1 pending-invalidate RW MMIO B was backpressured");
  dut.comb_inputs();
  require(!dut.llc_invalidate_all_accepted(),
          "C++ mode1 invalidate-all accepted in MMIO R/B handshake cycle");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.set_llc_invalidate_all(true);
  dut.comb_outputs();
  const auto &held_read =
      dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp;
  const auto &held_write =
      dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp;
  require(held_read.valid && held_write.valid,
          "C++ mode1 pending-invalidate RW responses were not both held");
  dut.comb_inputs();
  trace.blocked_while_both_held = !dut.llc_invalidate_all_accepted();
  require(trace.blocked_while_both_held,
          "C++ mode1 invalidate-all accepted while both responses held");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.set_llc_invalidate_all(true);
  dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp.ready = true;
  dut.comb_outputs();
  const auto &read_resp =
      dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp;
  require(read_resp.valid,
          "C++ mode1 pending-invalidate RW read response was not valid");
  trace.read.resp_id = static_cast<uint8_t>(read_resp.id);
  trace.read.resp_data = wide_read_words(read_resp.data);
  dut.comb_inputs();
  require(!dut.llc_invalidate_all_accepted(),
          "C++ mode1 invalidate-all accepted before read response retired");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.set_llc_invalidate_all(true);
  dut.comb_outputs();
  require(dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp.valid,
          "C++ mode1 pending-invalidate RW write response dropped after read retire");
  dut.comb_inputs();
  trace.blocked_after_read_retire = !dut.llc_invalidate_all_accepted();
  require(trace.blocked_after_read_retire,
          "C++ mode1 invalidate-all accepted while write response still held");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.set_llc_invalidate_all(true);
  dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp.ready = true;
  dut.comb_outputs();
  const auto &write_resp =
      dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp;
  require(write_resp.valid,
          "C++ mode1 pending-invalidate RW write response was not valid");
  trace.write.resp_id = static_cast<uint8_t>(write_resp.id);
  trace.write.resp_code = static_cast<uint8_t>(write_resp.resp);
  dut.comb_inputs();
  require(!dut.llc_invalidate_all_accepted(),
          "C++ mode1 invalidate-all accepted before write response retired");
  dut.seq();
  ++sim_time;

  for (int retry = 0; retry < 64; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    const bool accepted = dut.llc_invalidate_all_accepted();
    dut.seq();
    ++sim_time;
    if (accepted) {
      trace.accepted_after_both_retire = true;
      dut.set_llc_invalidate_all(false);
      return trace;
    }
  }
  require(false,
          "C++ mode1 invalidate-all did not accept after read/write retired");
  return trace;
}

WriteTrace run_mode1_invalidate_all_pre_aw_w_mmio_write_trace(
    const std::string &prefix, uint32_t addr, uint8_t total_size,
    uint8_t req_id, const axi_interconnect::WideWriteData_t &data,
    const axi_interconnect::WideWriteStrb_t &strobe) {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);

  WriteTrace trace{};
  trace.prefix = prefix;
  trace.req_addr = addr;
  trace.req_size = total_size;
  trace.req_id = req_id;
  trace.req_wdata = wide_write_words(data);
  trace.req_wstrb = write_strobe_mask(strobe);

  require(enqueue_write(dut, addr, total_size, data, strobe, req_id),
          "C++ mode1 pre-AW invalidate MMIO write request was not accepted");

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.axi_mmio_io.aw.awready = false;
  dut.axi_mmio_io.w.wready = false;
  dut.comb_inputs();
  require(dut.axi_mmio_io.aw.awvalid,
          "C++ mode1 pre-AW invalidate MMIO write did not issue MMIO AW");
  require(!dut.axi_ddr_io.aw.awvalid,
          "C++ mode1 pre-AW invalidate MMIO write escaped to DDR AW");
  require(!dut.axi_ddr_io.w.wvalid,
          "C++ mode1 pre-AW invalidate MMIO write escaped to DDR W");
  trace.awaddr = static_cast<uint32_t>(dut.axi_mmio_io.aw.awaddr);
  trace.awlen = static_cast<uint8_t>(dut.axi_mmio_io.aw.awlen);
  trace.awsize = static_cast<uint8_t>(dut.axi_mmio_io.aw.awsize);
  trace.awburst = static_cast<uint8_t>(dut.axi_mmio_io.aw.awburst);
  trace.awid = static_cast<uint8_t>(dut.axi_mmio_io.aw.awid);
  trace.beat_count = static_cast<uint32_t>(trace.awlen) + 1u;
  dut.seq();
  ++sim_time;

  for (int cycle = 0; cycle < 4; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    dut.axi_mmio_io.aw.awready = false;
    dut.axi_mmio_io.w.wready = false;
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    require(dut.axi_mmio_io.aw.awvalid,
            "C++ mode1 pre-AW invalidate lost pending MMIO AW");
    require(!dut.llc_invalidate_all_accepted(),
            "C++ mode1 invalidate-all accepted with MMIO AW pending");
    dut.seq();
    ++sim_time;
  }

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.axi_mmio_io.w.wready = false;
  dut.set_llc_invalidate_all(true);
  dut.comb_outputs();
  dut.comb_inputs();
  require(dut.axi_mmio_io.aw.awvalid,
          "C++ mode1 pre-AW invalidate did not retain MMIO AW");
  require(!dut.llc_invalidate_all_accepted(),
          "C++ mode1 invalidate-all accepted in MMIO AW handshake cycle");
  dut.seq();
  ++sim_time;

  for (uint32_t beat = 0; beat < trace.beat_count; ++beat) {
    for (int cycle = 0; cycle < 4; ++cycle) {
      clear_inputs(dut);
      set_downstream_ready(dut);
      dut.axi_mmio_io.w.wready = false;
      dut.set_llc_invalidate_all(true);
      dut.comb_outputs();
      dut.comb_inputs();
      require(dut.axi_mmio_io.w.wvalid,
              "C++ mode1 pre-W invalidate MMIO write W did not become valid");
      require(!dut.axi_ddr_io.w.wvalid,
              "C++ mode1 pre-W invalidate MMIO write W escaped to DDR");
      trace.wbeats[beat] = axi_words(dut.axi_mmio_io.w.wdata);
      trace.wstrb[beat] = axi_strobe_mask(dut.axi_mmio_io.w.wstrb);
      trace.wlast[beat] = dut.axi_mmio_io.w.wlast ? 1 : 0;
      require(!dut.llc_invalidate_all_accepted(),
              "C++ mode1 invalidate-all accepted with MMIO W pending");
      dut.seq();
      ++sim_time;
    }

    clear_inputs(dut);
    set_downstream_ready(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    require(dut.axi_mmio_io.w.wvalid,
            "C++ mode1 pre-W invalidate lost MMIO W before handshake");
    trace.wbeats[beat] = axi_words(dut.axi_mmio_io.w.wdata);
    trace.wstrb[beat] = axi_strobe_mask(dut.axi_mmio_io.w.wstrb);
    trace.wlast[beat] = dut.axi_mmio_io.w.wlast ? 1 : 0;
    require(!dut.llc_invalidate_all_accepted(),
            "C++ mode1 invalidate-all accepted in MMIO W handshake cycle");
    dut.seq();
    ++sim_time;
  }

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.set_llc_invalidate_all(true);
  dut.axi_mmio_io.b.bvalid = true;
  dut.axi_mmio_io.b.bid = trace.awid;
  dut.axi_mmio_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  require(dut.axi_mmio_io.b.bready,
          "C++ mode1 pre-AW invalidate MMIO B was backpressured");
  dut.comb_inputs();
  require(!dut.llc_invalidate_all_accepted(),
          "C++ mode1 invalidate-all accepted in pre-AW B handshake cycle");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.set_llc_invalidate_all(true);
  dut.comb_outputs();
  const auto &held_resp =
      dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp;
  require(held_resp.valid,
          "C++ mode1 pre-AW invalidate MMIO write response was not held");
  dut.comb_inputs();
  require(!dut.llc_invalidate_all_accepted(),
          "C++ mode1 invalidate-all accepted while pre-AW write response held");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.set_llc_invalidate_all(true);
  dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp.ready = true;
  dut.comb_outputs();
  const auto &resp = dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp;
  require(resp.valid,
          "C++ mode1 pre-AW invalidate MMIO write response was not valid");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_code = static_cast<uint8_t>(resp.resp);
  dut.comb_inputs();
  require(!dut.llc_invalidate_all_accepted(),
          "C++ mode1 invalidate-all accepted before pre-AW write response retired");
  dut.seq();
  ++sim_time;

  for (int retry = 0; retry < 64; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    const bool accepted = dut.llc_invalidate_all_accepted();
    dut.seq();
    ++sim_time;
    if (accepted) {
      dut.set_llc_invalidate_all(false);
      return trace;
    }
  }
  require(false,
          "C++ mode1 invalidate-all did not accept after pre-AW write retired");
  return trace;
}

void transition_mode(axi_interconnect::AXI_Interconnect &dut,
                     uint8_t target_mode, uint32_t target_offset) {
  dut.mode = target_mode;
  dut.llc_mapped_offset = target_offset;
  for (int retry = 0; retry < 64; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    dut.comb_outputs();
    dut.comb_inputs();
    dut.seq();
    ++sim_time;
    const bool mode_match = dut.active_mode() == target_mode;
    const bool offset_match =
        target_mode != 2u || dut.active_llc_mapped_offset() == target_offset;
    if (mode_match && offset_match) {
      clear_inputs(dut);
      set_downstream_ready(dut);
      dut.comb_outputs();
      dut.comb_inputs();
      dut.seq();
      ++sim_time;
      return;
    }
  }
  require(false, "C++ mode transition did not settle");
}

ReadTrace run_mode1_to_mode2_mmio_read_trace(const std::string &prefix,
                                             uint32_t addr,
                                             uint8_t total_size,
                                             uint8_t req_id,
                                             uint32_t rdata_word) {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  transition_mode(dut, 2u, 0x30000000u);

  ReadTrace trace{};
  trace.prefix = prefix;
  trace.req_addr = addr;
  trace.req_size = total_size;
  trace.req_id = req_id;
  trace.beat_count = 1;

  auto &req = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].req;
  req.valid = true;
  req.addr = addr;
  req.total_size = total_size;
  req.id = req_id;
  req.bypass = false;
  dut.comb_inputs();
  require(req.ready, "C++ mode1-to-mode2 MMIO read request was not ready");
  require(dut.axi_mmio_io.ar.arvalid,
          "C++ mode1-to-mode2 MMIO read did not issue MMIO AR");
  require(!dut.axi_ddr_io.ar.arvalid,
          "C++ mode1-to-mode2 MMIO read escaped to DDR AR");

  trace.araddr = static_cast<uint32_t>(dut.axi_mmio_io.ar.araddr);
  trace.arlen = static_cast<uint8_t>(dut.axi_mmio_io.ar.arlen);
  trace.arsize = static_cast<uint8_t>(dut.axi_mmio_io.ar.arsize);
  trace.arburst = static_cast<uint8_t>(dut.axi_mmio_io.ar.arburst);
  trace.arid = static_cast<uint8_t>(dut.axi_mmio_io.ar.arid);

  dut.seq();
  ++sim_time;
  idle_request_outputs(dut);

  dut.axi_mmio_io.r.rvalid = true;
  dut.axi_mmio_io.r.rid = trace.arid;
  dut.axi_mmio_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_mmio_io.r.rlast = true;
  dut.axi_mmio_io.r.rdata = {};
  axi_compat::set_u32(dut.axi_mmio_io.r.rdata, 0, rdata_word);
  trace.rbeats[0] = axi_words(dut.axi_mmio_io.r.rdata);
  dut.comb_outputs();
  require(dut.axi_mmio_io.r.rready,
          "C++ mode1-to-mode2 MMIO read R was backpressured");
  dut.seq();
  ++sim_time;

  dut.axi_mmio_io.r.rvalid = false;
  dut.axi_mmio_io.r.rlast = false;
  dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp.ready = true;
  dut.comb_outputs();
  const auto &resp = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp;
  require(resp.valid, "C++ mode1-to-mode2 MMIO read response did not become valid");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_data = wide_read_words(resp.data);
  dut.seq();
  ++sim_time;
  return trace;
}

ReadTrace run_mode1_to_mode2_pending_mmio_read_trace(
    const std::string &prefix, uint32_t addr, uint8_t total_size,
    uint8_t req_id, uint32_t rdata_word) {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);

  ReadTrace trace{};
  trace.prefix = prefix;
  trace.req_addr = addr;
  trace.req_size = total_size;
  trace.req_id = req_id;
  trace.beat_count = 1;

  auto &req = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].req;
  req.valid = true;
  req.addr = addr;
  req.total_size = total_size;
  req.id = req_id;
  req.bypass = false;
  dut.comb_inputs();
  require(req.ready,
          "C++ mode1-to-mode2 pending MMIO read request was not ready");
  require(dut.axi_mmio_io.ar.arvalid,
          "C++ mode1-to-mode2 pending MMIO read did not issue AR");
  require(!dut.axi_ddr_io.ar.arvalid,
          "C++ mode1-to-mode2 pending MMIO read escaped to DDR AR");

  trace.araddr = static_cast<uint32_t>(dut.axi_mmio_io.ar.araddr);
  trace.arlen = static_cast<uint8_t>(dut.axi_mmio_io.ar.arlen);
  trace.arsize = static_cast<uint8_t>(dut.axi_mmio_io.ar.arsize);
  trace.arburst = static_cast<uint8_t>(dut.axi_mmio_io.ar.arburst);
  trace.arid = static_cast<uint8_t>(dut.axi_mmio_io.ar.arid);

  dut.seq();
  ++sim_time;
  idle_request_outputs(dut);

  dut.mode = 2u;
  dut.llc_mapped_offset = 0x30000000u;
  for (int cycle = 0; cycle < 4; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    dut.comb_outputs();
    dut.comb_inputs();
    require(dut.active_mode() != 2u,
            "C++ mode transition completed while MMIO read was pending");
    dut.seq();
    ++sim_time;
  }

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.axi_mmio_io.r.rvalid = true;
  dut.axi_mmio_io.r.rid = trace.arid;
  dut.axi_mmio_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_mmio_io.r.rlast = true;
  dut.axi_mmio_io.r.rdata = {};
  axi_compat::set_u32(dut.axi_mmio_io.r.rdata, 0, rdata_word);
  trace.rbeats[0] = axi_words(dut.axi_mmio_io.r.rdata);
  dut.comb_outputs();
  require(dut.axi_mmio_io.r.rready,
          "C++ mode1-to-mode2 pending MMIO R was backpressured");
  dut.comb_inputs();
  require(dut.active_mode() != 2u,
          "C++ mode transition completed in MMIO R handshake cycle");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.comb_outputs();
  const auto &held_resp =
      dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp;
  require(held_resp.valid,
          "C++ mode1-to-mode2 pending MMIO response was not held");
  dut.comb_inputs();
  require(dut.active_mode() != 2u,
          "C++ mode transition completed while MMIO response held");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp.ready = true;
  dut.comb_outputs();
  const auto &resp = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp;
  require(resp.valid,
          "C++ mode1-to-mode2 pending MMIO response did not become valid");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_data = wide_read_words(resp.data);
  dut.comb_inputs();
  require(dut.active_mode() != 2u,
          "C++ mode transition completed before MMIO response retired");
  dut.seq();
  ++sim_time;

  for (int retry = 0; retry < 64; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    dut.comb_outputs();
    dut.comb_inputs();
    dut.seq();
    ++sim_time;
    if (dut.active_mode() == 2u &&
        dut.active_llc_mapped_offset() == 0x30000000u) {
      return trace;
    }
  }
  require(false,
          "C++ mode transition did not complete after MMIO response retired");
  return trace;
}

WriteTrace run_mode1_to_mode2_pending_mmio_write_trace(
    const std::string &prefix, uint32_t addr, uint8_t total_size,
    uint8_t req_id, const axi_interconnect::WideWriteData_t &data,
    const axi_interconnect::WideWriteStrb_t &strobe) {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);

  WriteTrace trace{};
  trace.prefix = prefix;
  trace.req_addr = addr;
  trace.req_size = total_size;
  trace.req_id = req_id;
  trace.req_wdata = wide_write_words(data);
  trace.req_wstrb = write_strobe_mask(strobe);

  require(enqueue_write(dut, addr, total_size, data, strobe, req_id),
          "C++ mode1-to-mode2 pending MMIO write request was not accepted");

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.comb_inputs();
  require(dut.axi_mmio_io.aw.awvalid,
          "C++ mode1-to-mode2 pending MMIO write did not issue AW");
  require(!dut.axi_ddr_io.aw.awvalid,
          "C++ mode1-to-mode2 pending MMIO write escaped to DDR AW");
  require(!dut.axi_ddr_io.w.wvalid,
          "C++ mode1-to-mode2 pending MMIO write escaped to DDR W");
  trace.awaddr = static_cast<uint32_t>(dut.axi_mmio_io.aw.awaddr);
  trace.awlen = static_cast<uint8_t>(dut.axi_mmio_io.aw.awlen);
  trace.awsize = static_cast<uint8_t>(dut.axi_mmio_io.aw.awsize);
  trace.awburst = static_cast<uint8_t>(dut.axi_mmio_io.aw.awburst);
  trace.awid = static_cast<uint8_t>(dut.axi_mmio_io.aw.awid);
  trace.beat_count = static_cast<uint32_t>(trace.awlen) + 1u;
  dut.seq();
  ++sim_time;

  for (uint32_t beat = 0; beat < trace.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    dut.comb_inputs();
    require(dut.axi_mmio_io.w.wvalid,
            "C++ mode1-to-mode2 pending MMIO write W did not become valid");
    require(!dut.axi_ddr_io.w.wvalid,
            "C++ mode1-to-mode2 pending MMIO write W escaped to DDR");
    trace.wbeats[beat] = axi_words(dut.axi_mmio_io.w.wdata);
    trace.wstrb[beat] = axi_strobe_mask(dut.axi_mmio_io.w.wstrb);
    trace.wlast[beat] = dut.axi_mmio_io.w.wlast ? 1 : 0;
    dut.seq();
    ++sim_time;
  }

  dut.mode = 2u;
  dut.llc_mapped_offset = 0x30000000u;
  for (int cycle = 0; cycle < 4; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    dut.comb_outputs();
    dut.comb_inputs();
    require(dut.active_mode() != 2u,
            "C++ mode transition completed while MMIO write was pending");
    dut.seq();
    ++sim_time;
  }

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.axi_mmio_io.b.bvalid = true;
  dut.axi_mmio_io.b.bid = trace.awid;
  dut.axi_mmio_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  require(dut.axi_mmio_io.b.bready,
          "C++ mode1-to-mode2 pending MMIO B was backpressured");
  dut.comb_inputs();
  require(dut.active_mode() != 2u,
          "C++ mode transition completed in MMIO B handshake cycle");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.comb_outputs();
  const auto &held_resp =
      dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp;
  require(held_resp.valid,
          "C++ mode1-to-mode2 pending MMIO write response was not held");
  dut.comb_inputs();
  require(dut.active_mode() != 2u,
          "C++ mode transition completed while MMIO write response held");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp.ready = true;
  dut.comb_outputs();
  const auto &resp = dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp;
  require(resp.valid,
          "C++ mode1-to-mode2 pending MMIO write response did not become valid");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_code = static_cast<uint8_t>(resp.resp);
  dut.comb_inputs();
  require(dut.active_mode() != 2u,
          "C++ mode transition completed before MMIO write response retired");
  dut.seq();
  ++sim_time;

  for (int retry = 0; retry < 64; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    dut.comb_outputs();
    dut.comb_inputs();
    dut.seq();
    ++sim_time;
    if (dut.active_mode() == 2u &&
        dut.active_llc_mapped_offset() == 0x30000000u) {
      return trace;
    }
  }
  require(false,
          "C++ mode transition did not complete after MMIO write response retired");
  return trace;
}

InvalidateAllMmioReadWriteTrace
run_mode1_to_mode2_pending_mmio_read_write_trace(
    const std::string &prefix, uint32_t read_addr, uint8_t read_size,
    uint8_t read_id, uint32_t read_data_word, uint32_t write_addr,
    uint8_t write_size, uint8_t write_id,
    const axi_interconnect::WideWriteData_t &write_data,
    const axi_interconnect::WideWriteStrb_t &write_strobe) {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);

  InvalidateAllMmioReadWriteTrace trace{};
  trace.prefix = prefix;
  trace.read.prefix = prefix + "_READ";
  trace.read.req_addr = read_addr;
  trace.read.req_size = read_size;
  trace.read.req_id = read_id;
  trace.read.beat_count = 1;
  trace.write.prefix = prefix + "_WRITE";
  trace.write.req_addr = write_addr;
  trace.write.req_size = write_size;
  trace.write.req_id = write_id;
  trace.write.req_wdata = wide_write_words(write_data);
  trace.write.req_wstrb = write_strobe_mask(write_strobe);

  auto &read_req = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].req;
  read_req.valid = true;
  read_req.addr = read_addr;
  read_req.total_size = read_size;
  read_req.id = read_id;
  read_req.bypass = false;
  dut.comb_inputs();
  require(read_req.ready,
          "C++ mode1-to-mode2 pending RW MMIO read was not ready");
  require(dut.axi_mmio_io.ar.arvalid,
          "C++ mode1-to-mode2 pending RW MMIO read did not issue AR");
  require(!dut.axi_ddr_io.ar.arvalid,
          "C++ mode1-to-mode2 pending RW MMIO read escaped to DDR AR");
  trace.read.araddr = static_cast<uint32_t>(dut.axi_mmio_io.ar.araddr);
  trace.read.arlen = static_cast<uint8_t>(dut.axi_mmio_io.ar.arlen);
  trace.read.arsize = static_cast<uint8_t>(dut.axi_mmio_io.ar.arsize);
  trace.read.arburst = static_cast<uint8_t>(dut.axi_mmio_io.ar.arburst);
  trace.read.arid = static_cast<uint8_t>(dut.axi_mmio_io.ar.arid);
  dut.seq();
  ++sim_time;
  idle_request_outputs(dut);

  require(enqueue_write(dut, write_addr, write_size, write_data, write_strobe,
                        write_id),
          "C++ mode1-to-mode2 pending RW MMIO write was not accepted");
  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.comb_inputs();
  require(dut.axi_mmio_io.aw.awvalid,
          "C++ mode1-to-mode2 pending RW MMIO write did not issue AW");
  require(!dut.axi_ddr_io.aw.awvalid && !dut.axi_ddr_io.w.wvalid,
          "C++ mode1-to-mode2 pending RW MMIO write escaped to DDR");
  trace.write.awaddr = static_cast<uint32_t>(dut.axi_mmio_io.aw.awaddr);
  trace.write.awlen = static_cast<uint8_t>(dut.axi_mmio_io.aw.awlen);
  trace.write.awsize = static_cast<uint8_t>(dut.axi_mmio_io.aw.awsize);
  trace.write.awburst = static_cast<uint8_t>(dut.axi_mmio_io.aw.awburst);
  trace.write.awid = static_cast<uint8_t>(dut.axi_mmio_io.aw.awid);
  trace.write.beat_count = static_cast<uint32_t>(trace.write.awlen) + 1u;
  dut.seq();
  ++sim_time;

  for (uint32_t beat = 0; beat < trace.write.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    dut.comb_inputs();
    require(dut.axi_mmio_io.w.wvalid,
            "C++ mode1-to-mode2 pending RW MMIO write W missing");
    require(!dut.axi_ddr_io.w.wvalid,
            "C++ mode1-to-mode2 pending RW MMIO write W escaped to DDR");
    trace.write.wbeats[beat] = axi_words(dut.axi_mmio_io.w.wdata);
    trace.write.wstrb[beat] = axi_strobe_mask(dut.axi_mmio_io.w.wstrb);
    trace.write.wlast[beat] = dut.axi_mmio_io.w.wlast ? 1 : 0;
    dut.seq();
    ++sim_time;
  }

  dut.mode = 2u;
  dut.llc_mapped_offset = 0x30000000u;
  trace.blocked_before_resp = true;
  for (int cycle = 0; cycle < 4; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    dut.comb_outputs();
    dut.comb_inputs();
    const bool blocked = dut.active_mode() != 2u;
    trace.blocked_before_resp = trace.blocked_before_resp && blocked;
    require(blocked,
            "C++ mode transition completed with MMIO read/write pending");
    dut.seq();
    ++sim_time;
  }

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.axi_mmio_io.b.bvalid = true;
  dut.axi_mmio_io.b.bid = trace.write.awid;
  dut.axi_mmio_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  trace.bready_while_pending = dut.axi_mmio_io.b.bready;
  require(trace.bready_while_pending,
          "C++ mode1-to-mode2 pending RW MMIO B was backpressured");
  dut.comb_inputs();
  require(dut.active_mode() != 2u,
          "C++ mode transition completed in MMIO B handshake cycle");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.comb_outputs();
  const auto &held_write =
      dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp;
  require(held_write.valid,
          "C++ mode1-to-mode2 pending RW write response was not held");
  dut.comb_inputs();
  require(dut.active_mode() != 2u,
          "C++ mode transition completed while write response held");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp.ready = true;
  dut.comb_outputs();
  const auto &write_resp =
      dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp;
  require(write_resp.valid,
          "C++ mode1-to-mode2 pending RW write response was not valid");
  trace.write.resp_id = static_cast<uint8_t>(write_resp.id);
  trace.write.resp_code = static_cast<uint8_t>(write_resp.resp);
  dut.comb_inputs();
  require(dut.active_mode() != 2u,
          "C++ mode transition completed before MMIO R returned");
  dut.seq();
  ++sim_time;

  trace.blocked_after_read_retire = true;
  for (int cycle = 0; cycle < 4; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    dut.comb_outputs();
    dut.comb_inputs();
    const bool blocked = dut.active_mode() != 2u;
    trace.blocked_after_read_retire = trace.blocked_after_read_retire && blocked;
    require(blocked,
            "C++ mode transition completed after B before pending R");
    dut.seq();
    ++sim_time;
  }

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.axi_mmio_io.r.rvalid = true;
  dut.axi_mmio_io.r.rid = trace.read.arid;
  dut.axi_mmio_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_mmio_io.r.rlast = true;
  dut.axi_mmio_io.r.rdata = {};
  axi_compat::set_u32(dut.axi_mmio_io.r.rdata, 0, read_data_word);
  trace.read.rbeats[0] = axi_words(dut.axi_mmio_io.r.rdata);
  dut.comb_outputs();
  trace.rready_while_pending = dut.axi_mmio_io.r.rready;
  require(trace.rready_while_pending,
          "C++ mode1-to-mode2 pending RW MMIO R was backpressured");
  dut.comb_inputs();
  require(dut.active_mode() != 2u,
          "C++ mode transition completed in MMIO R handshake cycle");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.comb_outputs();
  const auto &held_read =
      dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp;
  require(held_read.valid,
          "C++ mode1-to-mode2 pending RW read response was not held");
  dut.comb_inputs();
  trace.blocked_while_both_held = dut.active_mode() != 2u;
  require(trace.blocked_while_both_held,
          "C++ mode transition completed while read response held");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp.ready = true;
  dut.comb_outputs();
  const auto &read_resp =
      dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp;
  require(read_resp.valid,
          "C++ mode1-to-mode2 pending RW read response was not valid");
  trace.read.resp_id = static_cast<uint8_t>(read_resp.id);
  trace.read.resp_data = wide_read_words(read_resp.data);
  dut.comb_inputs();
  require(dut.active_mode() != 2u,
          "C++ mode transition completed before read response retired");
  dut.seq();
  ++sim_time;

  for (int retry = 0; retry < 64; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    dut.comb_outputs();
    dut.comb_inputs();
    dut.seq();
    ++sim_time;
    if (dut.active_mode() == 2u &&
        dut.active_llc_mapped_offset() == 0x30000000u) {
      trace.accepted_after_both_retire = true;
      return trace;
    }
  }
  require(false,
          "C++ mode transition did not complete after MMIO read/write retired");
  return trace;
}

ReconfigCacheReadTrace run_mode1_to_mode2_pending_cache_read_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  InvalidLlcTableDriver table_driver(dut.get_llc_config());

  ReconfigCacheReadTrace trace{};
  trace.read.prefix = "CPP_MODE1_TO_MODE2_PENDING_CACHE_READ";
  trace.read.req_addr = 0x40000c04u;
  trace.read.req_size = 3;
  trace.read.req_id = 0x9u;
  trace.read.beat_count = 2;
  trace.read_master = axi_interconnect::MASTER_DCACHE_R;

  bool accepted = false;
  bool ar_seen = false;
  bool request_active = true;
  for (int cycle = 0; cycle < 80 && !ar_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    if (request_active) {
      auto &req = dut.read_ports[trace.read_master].req;
      req.valid = true;
      req.addr = trace.read.req_addr;
      req.total_size = trace.read.req_size;
      req.id = trace.read.req_id;
      req.bypass = false;
    }
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    if (request_active && dut.read_ports[trace.read_master].req.ready) {
      accepted = true;
      request_active = false;
    }
    if (dut.axi_ddr_io.ar.arvalid) {
      require(!dut.axi_mmio_io.ar.arvalid,
              "C++ mode1-to-mode2 cache read escaped to MMIO AR");
      trace.read.araddr = static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
      trace.read.arlen = static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
      trace.read.arsize = static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
      trace.read.arburst = static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
      trace.read.arid = static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
      ar_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ mode1-to-mode2 cache read was not accepted");
  require(ar_seen, "C++ mode1-to-mode2 cache read did not issue DDR AR");
  require(trace.read.beat_count ==
              static_cast<uint32_t>(trace.read.arlen) + 1u,
          "C++ mode1-to-mode2 cache read refill beat count mismatch");

  dut.mode = 2u;
  dut.llc_mapped_offset = 0x30000000u;
  for (int cycle = 0; cycle < 4; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    require(dut.active_mode() != 2u,
            "C++ mode transition completed while cache read was pending");
    dut.seq();
    ++sim_time;
  }

  trace.rready_while_reconfig_pending = true;
  for (uint32_t beat = 0; beat < trace.read.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = trace.read.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == trace.read.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(0xd00d0e00u + beat * 0x100u);
    trace.read.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    trace.rready_while_reconfig_pending =
        trace.rready_while_reconfig_pending && dut.axi_ddr_io.r.rready;
    require(dut.axi_ddr_io.r.rready,
            "C++ mode1-to-mode2 cache read DDR R was backpressured");
    dut.comb_inputs();
    table_driver.observe(dut);
    require(dut.active_mode() != 2u,
            "C++ mode transition completed in cache DDR R handshake");
    dut.seq();
    ++sim_time;
  }

  bool cache_resp_seen = false;
  for (int cycle = 0; cycle < 180 && !cache_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    auto &resp = dut.read_ports[trace.read_master].resp;
    if (resp.valid) {
      cache_resp_seen = true;
      trace.read.resp_id = static_cast<uint8_t>(resp.id);
      trace.read.resp_data = wide_read_words(resp.data);
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(dut.active_mode() != 2u,
            "C++ mode transition completed before cache response retired");
    dut.seq();
    ++sim_time;
  }
  require(cache_resp_seen,
          "C++ mode1-to-mode2 cache read response timeout");

  for (int cycle = 0; cycle < 4; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    require(dut.read_ports[trace.read_master].resp.valid,
            "C++ mode1-to-mode2 cache response was not held");
    dut.comb_inputs();
    table_driver.observe(dut);
    require(dut.active_mode() != 2u,
            "C++ mode transition completed while cache response held");
    dut.seq();
    ++sim_time;
  }

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.read_ports[trace.read_master].resp.ready = true;
  dut.comb_outputs();
  require(dut.read_ports[trace.read_master].resp.valid,
          "C++ mode1-to-mode2 cache response not valid at retire");
  dut.comb_inputs();
  table_driver.observe(dut);
  require(dut.active_mode() != 2u,
          "C++ mode transition completed before cache response retire edge");
  dut.seq();
  ++sim_time;

  for (int retry = 0; retry < 64; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    dut.seq();
    ++sim_time;
    if (dut.active_mode() == 2u &&
        dut.active_llc_mapped_offset() == 0x30000000u) {
      return trace;
    }
  }
  require(false,
          "C++ mode transition did not complete after cache response retired");
  return trace;
}

ReconfigCacheWriteTrace run_mode1_to_mode2_pending_cache_write_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  InvalidLlcTableDriver table_driver(dut.get_llc_config());

  ReconfigCacheWriteTrace trace{};
  trace.write.prefix = "CPP_MODE1_TO_MODE2_PENDING_CACHE_WRITE";
  trace.write.req_addr = 0x40000d04u;
  trace.write.req_size = 3;
  trace.write.req_id = 0xAu;
  const auto write_data = single_word_data(0x24681357u);
  const auto write_strobe = byte_strobe(0xfu);
  trace.write.req_wdata = wide_write_words(write_data);
  trace.write.req_wstrb = write_strobe_mask(write_strobe);
  trace.refill.prefix = "CPP_MODE1_TO_MODE2_PENDING_CACHE_WRITE_REFILL";
  trace.refill.req_addr = trace.write.req_addr;
  trace.refill.req_size = 63;
  trace.refill.req_id = 0;
  trace.refill.beat_count = 2;
  trace.refill.resp_data.assign(axi_interconnect::MAX_READ_TRANSACTION_WORDS, 0);
  trace.write_master = axi_interconnect::MASTER_DCACHE_W;

  bool accepted = false;
  bool ar_seen = false;
  bool request_active = true;
  for (int cycle = 0; cycle < 120 && !ar_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    const bool ready_snapshot = dut.write_ports[trace.write_master].req.ready;
    if (request_active) {
      auto &req = dut.write_ports[trace.write_master].req;
      req.valid = true;
      req.addr = trace.write.req_addr;
      req.total_size = trace.write.req_size;
      req.id = trace.write.req_id;
      req.wdata = write_data;
      req.wstrb = write_strobe;
      req.bypass = false;
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    if (request_active && ready_snapshot) {
      accepted = true;
      request_active = false;
    }
    if (dut.axi_ddr_io.ar.arvalid) {
      require(!dut.axi_mmio_io.ar.arvalid,
              "C++ mode1-to-mode2 cache write refill escaped to MMIO AR");
      trace.refill.araddr = static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
      trace.refill.arlen = static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
      trace.refill.arsize = static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
      trace.refill.arburst = static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
      trace.refill.arid = static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
      ar_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ mode1-to-mode2 cache write was not accepted");
  require(ar_seen, "C++ mode1-to-mode2 cache write did not issue DDR AR");
  require(trace.refill.beat_count ==
              static_cast<uint32_t>(trace.refill.arlen) + 1u,
          "C++ mode1-to-mode2 cache write refill beat count mismatch");

  dut.mode = 2u;
  dut.llc_mapped_offset = 0x30000000u;
  for (int cycle = 0; cycle < 4; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    require(dut.active_mode() != 2u,
            "C++ mode transition completed while cache write was pending");
    dut.seq();
    ++sim_time;
  }

  trace.rready_while_reconfig_pending = true;
  for (uint32_t beat = 0; beat < trace.refill.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = trace.refill.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == trace.refill.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(0xd00d1000u + beat * 0x100u);
    trace.refill.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    trace.rready_while_reconfig_pending =
        trace.rready_while_reconfig_pending && dut.axi_ddr_io.r.rready;
    require(dut.axi_ddr_io.r.rready,
            "C++ mode1-to-mode2 cache write DDR R was backpressured");
    dut.comb_inputs();
    table_driver.observe(dut);
    require(dut.active_mode() != 2u,
            "C++ mode transition completed in cache write DDR R handshake");
    dut.seq();
    ++sim_time;
  }

  bool cache_resp_seen = false;
  for (int cycle = 0; cycle < 180 && !cache_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    auto &resp = dut.write_ports[trace.write_master].resp;
    if (resp.valid) {
      cache_resp_seen = true;
      trace.write.resp_id = static_cast<uint8_t>(resp.id);
      trace.write.resp_code = static_cast<uint8_t>(resp.resp);
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(dut.active_mode() != 2u,
            "C++ mode transition completed before cache write response retired");
    dut.seq();
    ++sim_time;
  }
  require(cache_resp_seen,
          "C++ mode1-to-mode2 cache write response timeout");

  for (int cycle = 0; cycle < 4; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    require(dut.write_ports[trace.write_master].resp.valid,
            "C++ mode1-to-mode2 cache write response was not held");
    dut.comb_inputs();
    table_driver.observe(dut);
    require(dut.active_mode() != 2u,
            "C++ mode transition completed while cache write response held");
    dut.seq();
    ++sim_time;
  }

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.write_ports[trace.write_master].resp.ready = true;
  dut.comb_outputs();
  require(dut.write_ports[trace.write_master].resp.valid,
          "C++ mode1-to-mode2 cache write response not valid at retire");
  dut.comb_inputs();
  table_driver.observe(dut);
  require(dut.active_mode() != 2u,
          "C++ mode transition completed before cache write response retire edge");
  dut.seq();
  ++sim_time;

  trace.blocked_after_resp_retire = true;
  for (int retry = 0; retry < 16; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    trace.blocked_after_resp_retire =
        trace.blocked_after_resp_retire && dut.active_mode() != 2u;
    require(dut.active_mode() != 2u,
            "C++ mode transition completed with dirty cache write resident");
    dut.seq();
    ++sim_time;
  }
  return trace;
}

OverlapReadTrace run_overlapped_read_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);

  OverlapReadTrace trace{};
  trace.ddr.prefix = "CPP_MODE0_OVERLAP_READ_DDR";
  trace.ddr.req_addr = 0x40000100u;
  trace.ddr.req_size = 3;
  trace.ddr.req_id = 0xAu;
  trace.ddr.beat_count = 1;
  trace.mmio.prefix = "CPP_MODE0_OVERLAP_READ_MMIO";
  trace.mmio.req_addr = 0x10000080u;
  trace.mmio.req_size = 3;
  trace.mmio.req_id = 0xBu;
  trace.mmio.beat_count = 1;
  trace.ddr_master = axi_interconnect::MASTER_DCACHE_R;
  trace.mmio_master = axi_interconnect::MASTER_UNCORE_LSU_R;

  issue_read_and_capture_ar(dut, trace.ddr, trace.ddr_master,
                            axi_interconnect::DownstreamPort::DDR);
  issue_read_and_capture_ar(dut, trace.mmio, trace.mmio_master,
                            axi_interconnect::DownstreamPort::MMIO);

  idle_request_outputs(dut);
  dut.axi_mmio_io.r.rvalid = true;
  dut.axi_mmio_io.r.rid = trace.mmio.arid;
  dut.axi_mmio_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_mmio_io.r.rlast = true;
  dut.axi_mmio_io.r.rdata = {};
  axi_compat::set_u32(dut.axi_mmio_io.r.rdata, 0, 0xcafe0080u);
  trace.mmio.rbeats[0] = axi_words(dut.axi_mmio_io.r.rdata);
  dut.comb_outputs();
  trace.mmio_rready_while_resp_stalled = dut.axi_mmio_io.r.rready;
  require(trace.mmio_rready_while_resp_stalled,
          "C++ overlapped MMIO R was backpressured by upstream stall");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  dut.comb_outputs();
  require(dut.read_ports[trace.mmio_master].resp.valid,
          "C++ overlapped MMIO response was not held while stalled");
  require(!dut.read_ports[trace.ddr_master].resp.valid,
          "C++ overlapped DDR response appeared before DDR R");

  idle_request_outputs(dut);
  dut.axi_ddr_io.r.rvalid = true;
  dut.axi_ddr_io.r.rid = trace.ddr.arid;
  dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_ddr_io.r.rlast = true;
  dut.axi_ddr_io.r.rdata = ddr_read_beat(0xd00d0100u);
  trace.ddr.rbeats[0] = axi_words(dut.axi_ddr_io.r.rdata);
  dut.comb_outputs();
  trace.ddr_rready_while_resp_stalled = dut.axi_ddr_io.r.rready;
  require(trace.ddr_rready_while_resp_stalled,
          "C++ overlapped DDR R was backpressured by upstream stall");
  dut.seq();
  ++sim_time;

  capture_read_response(dut, trace.mmio, trace.mmio_master);
  capture_read_response(dut, trace.ddr, trace.ddr_master);
  return trace;
}

OverlapReadTrace run_overlapped_read64_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);

  OverlapReadTrace trace{};
  trace.ddr.prefix = "CPP_MODE0_OVERLAP_READ64_DDR";
  trace.ddr.req_addr = 0x40000300u;
  trace.ddr.req_size = 63;
  trace.ddr.req_id = 0xCu;
  trace.ddr.beat_count = 2;
  trace.mmio.prefix = "CPP_MODE0_OVERLAP_READ64_MMIO";
  trace.mmio.req_addr = 0x10000090u;
  trace.mmio.req_size = 3;
  trace.mmio.req_id = 0xDu;
  trace.mmio.beat_count = 1;
  trace.ddr_master = axi_interconnect::MASTER_DCACHE_R;
  trace.mmio_master = axi_interconnect::MASTER_UNCORE_LSU_R;

  issue_read_and_capture_ar(dut, trace.ddr, trace.ddr_master,
                            axi_interconnect::DownstreamPort::DDR);
  issue_read_and_capture_ar(dut, trace.mmio, trace.mmio_master,
                            axi_interconnect::DownstreamPort::MMIO);

  idle_request_outputs(dut);
  dut.axi_mmio_io.r.rvalid = true;
  dut.axi_mmio_io.r.rid = trace.mmio.arid;
  dut.axi_mmio_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_mmio_io.r.rlast = true;
  dut.axi_mmio_io.r.rdata = {};
  axi_compat::set_u32(dut.axi_mmio_io.r.rdata, 0, 0xcafe0090u);
  trace.mmio.rbeats[0] = axi_words(dut.axi_mmio_io.r.rdata);
  dut.comb_outputs();
  trace.mmio_rready_while_resp_stalled = dut.axi_mmio_io.r.rready;
  require(trace.mmio_rready_while_resp_stalled,
          "C++ overlapped read64 MMIO R was backpressured by upstream stall");
  dut.seq();
  ++sim_time;

  dut.axi_mmio_io.r.rvalid = false;
  dut.axi_mmio_io.r.rlast = false;
  clear_inputs(dut);
  dut.comb_outputs();
  require(dut.read_ports[trace.mmio_master].resp.valid,
          "C++ overlapped read64 MMIO response was not held while stalled");
  require(!dut.read_ports[trace.ddr_master].resp.valid,
          "C++ overlapped read64 DDR response appeared before DDR R");

  trace.ddr_rready_while_resp_stalled = true;
  for (uint32_t beat = 0; beat < trace.ddr.beat_count; ++beat) {
    idle_request_outputs(dut);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = trace.ddr.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == trace.ddr.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(0xd00d0300u + beat * 0x100u);
    trace.ddr.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    trace.ddr_rready_while_resp_stalled =
        trace.ddr_rready_while_resp_stalled && dut.axi_ddr_io.r.rready;
    require(dut.axi_ddr_io.r.rready,
            "C++ overlapped read64 DDR R was backpressured by upstream stall");
    dut.seq();
    ++sim_time;

    dut.axi_ddr_io.r.rvalid = false;
    dut.axi_ddr_io.r.rlast = false;
    if (beat + 1u < trace.ddr.beat_count) {
      clear_inputs(dut);
      dut.comb_outputs();
      require(!dut.read_ports[trace.ddr_master].resp.valid,
              "C++ overlapped read64 DDR response appeared before last beat");
    }
  }

  capture_read_response(dut, trace.mmio, trace.mmio_master);
  capture_read_response(dut, trace.ddr, trace.ddr_master);
  return trace;
}

OverlapReadTrace run_mode1_cache_mmio_overlap_read_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  InvalidLlcTableDriver table_driver(dut.get_llc_config());

  OverlapReadTrace trace{};
  trace.ddr.prefix = "CPP_MODE1_CACHE_OVERLAP_READ_DDR";
  trace.ddr.req_addr = 0x40000704u;
  trace.ddr.req_size = 3;
  trace.ddr.req_id = 0x1u;
  trace.ddr.beat_count = 2;
  trace.mmio.prefix = "CPP_MODE1_CACHE_OVERLAP_READ_MMIO";
  trace.mmio.req_addr = 0x10000098u;
  trace.mmio.req_size = 3;
  trace.mmio.req_id = 0x2u;
  trace.mmio.beat_count = 1;
  trace.ddr_master = axi_interconnect::MASTER_DCACHE_R;
  trace.mmio_master = axi_interconnect::MASTER_UNCORE_LSU_R;

  bool accepted = false;
  bool ar_seen = false;
  bool request_active = true;
  for (int cycle = 0; cycle < 80 && !ar_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    if (request_active) {
      auto &req = dut.read_ports[trace.ddr_master].req;
      req.valid = true;
      req.addr = trace.ddr.req_addr;
      req.total_size = trace.ddr.req_size;
      req.id = trace.ddr.req_id;
      req.bypass = false;
    }
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    if (request_active && dut.read_ports[trace.ddr_master].req.ready) {
      accepted = true;
      request_active = false;
    }
    if (dut.axi_ddr_io.ar.arvalid) {
      require(!dut.axi_mmio_io.ar.arvalid,
              "C++ mode1 cache refill DDR AR overlapped with MMIO AR");
      trace.ddr.araddr = static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
      trace.ddr.arlen = static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
      trace.ddr.arsize = static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
      trace.ddr.arburst = static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
      trace.ddr.arid = static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
      ar_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ mode1 cache read was not accepted");
  require(ar_seen, "C++ mode1 cache read did not issue DDR refill AR");
  require(trace.ddr.beat_count == static_cast<uint32_t>(trace.ddr.arlen) + 1u,
          "C++ mode1 cache read refill beat count mismatch");

  issue_read_and_capture_ar(dut, trace.mmio, trace.mmio_master,
                            axi_interconnect::DownstreamPort::MMIO);

  idle_request_outputs(dut);
  dut.axi_mmio_io.r.rvalid = true;
  dut.axi_mmio_io.r.rid = trace.mmio.arid;
  dut.axi_mmio_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_mmio_io.r.rlast = true;
  dut.axi_mmio_io.r.rdata = {};
  axi_compat::set_u32(dut.axi_mmio_io.r.rdata, 0, 0xcafe0098u);
  trace.mmio.rbeats[0] = axi_words(dut.axi_mmio_io.r.rdata);
  dut.comb_outputs();
  trace.mmio_rready_while_resp_stalled = dut.axi_mmio_io.r.rready;
  require(trace.mmio_rready_while_resp_stalled,
          "C++ mode1 cache/MMIO overlap MMIO R was backpressured");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  table_driver.drive(dut);
  dut.comb_outputs();
  dut.comb_inputs();
  table_driver.observe(dut);
  require(dut.read_ports[trace.mmio_master].resp.valid,
          "C++ mode1 cache/MMIO overlap MMIO response was not held");
  require(!dut.read_ports[trace.ddr_master].resp.valid,
          "C++ mode1 cache/MMIO overlap cache response appeared before refill");
  dut.seq();
  ++sim_time;

  trace.ddr_rready_while_resp_stalled = true;
  for (uint32_t beat = 0; beat < trace.ddr.beat_count; ++beat) {
    idle_request_outputs(dut);
    table_driver.drive(dut);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = trace.ddr.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == trace.ddr.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(0xd00d0700u + beat * 0x100u);
    trace.ddr.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    trace.ddr_rready_while_resp_stalled =
        trace.ddr_rready_while_resp_stalled && dut.axi_ddr_io.r.rready;
    require(dut.axi_ddr_io.r.rready,
            "C++ mode1 cache/MMIO overlap DDR R was backpressured");
    dut.seq();
    ++sim_time;
  }

  capture_read_response(dut, trace.mmio, trace.mmio_master);

  bool cache_resp_seen = false;
  for (int cycle = 0; cycle < 160 && !cache_resp_seen; ++cycle) {
    clear_inputs(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    auto &resp = dut.read_ports[trace.ddr_master].resp;
    if (resp.valid) {
      cache_resp_seen = true;
      trace.ddr.resp_id = static_cast<uint8_t>(resp.id);
      trace.ddr.resp_data = wide_read_words(resp.data);
      resp.ready = true;
      dut.comb_outputs();
      require(resp.valid,
              "C++ mode1 cache response dropped before ready handshake");
    }
    dut.seq();
    ++sim_time;
  }
  require(cache_resp_seen,
          "C++ mode1 cache/MMIO overlap cache response timeout");
  return trace;
}

InvalidateLinePendingReadTrace
run_mode1_invalidate_line_pending_read_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  InvalidLlcTableDriver table_driver(dut.get_llc_config());

  InvalidateLinePendingReadTrace trace{};
  trace.read.prefix = "CPP_MODE1_INVALIDATE_LINE_PENDING_READ";
  trace.read.req_addr = 0x40000904u;
  trace.read.req_size = 3;
  trace.read.req_id = 0x5u;
  trace.read.beat_count = 2;
  trace.read_master = axi_interconnect::MASTER_DCACHE_R;
  trace.invalidate_addr = trace.read.req_addr;

  bool accepted = false;
  bool ar_seen = false;
  bool request_active = true;
  for (int cycle = 0; cycle < 80 && !ar_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    if (request_active) {
      auto &req = dut.read_ports[trace.read_master].req;
      req.valid = true;
      req.addr = trace.read.req_addr;
      req.total_size = trace.read.req_size;
      req.id = trace.read.req_id;
      req.bypass = false;
    }
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    if (request_active && dut.read_ports[trace.read_master].req.ready) {
      accepted = true;
      request_active = false;
    }
    if (dut.axi_ddr_io.ar.arvalid) {
      trace.read.araddr = static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
      trace.read.arlen = static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
      trace.read.arsize = static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
      trace.read.arburst = static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
      trace.read.arid = static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
      ar_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ invalidate-line pending read was not accepted");
  require(ar_seen, "C++ invalidate-line pending read did not issue DDR AR");
  require(trace.read.beat_count == static_cast<uint32_t>(trace.read.arlen) + 1u,
          "C++ invalidate-line pending read beat count mismatch");

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_line(true, trace.invalidate_addr);
  dut.comb_outputs();
  dut.comb_inputs();
  table_driver.observe(dut);
  trace.blocked_before_r = !dut.llc_invalidate_line_accepted();
  require(trace.blocked_before_r,
          "C++ invalidate_line accepted while DDR read was pending");
  dut.seq();
  ++sim_time;

  trace.rready_while_invalidate_pending = true;
  for (uint32_t beat = 0; beat < trace.read.beat_count; ++beat) {
    clear_inputs(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = trace.read.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == trace.read.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(0xd00d0900u + beat * 0x100u);
    trace.read.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    trace.rready_while_invalidate_pending =
        trace.rready_while_invalidate_pending && dut.axi_ddr_io.r.rready;
    require(dut.axi_ddr_io.r.rready,
            "C++ invalidate-line pending read R was backpressured");
    require(!dut.llc_invalidate_line_accepted(),
            "C++ invalidate_line accepted in DDR R handshake cycle");
    dut.seq();
    ++sim_time;
  }

  bool resp_seen = false;
  for (int cycle = 0; cycle < 160 && !resp_seen; ++cycle) {
    clear_inputs(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    auto &resp = dut.read_ports[trace.read_master].resp;
    if (resp.valid) {
      resp_seen = true;
      trace.read.resp_id = static_cast<uint8_t>(resp.id);
      trace.read.resp_data = wide_read_words(resp.data);
      trace.blocked_while_resp_held = !dut.llc_invalidate_line_accepted();
      require(resp.valid,
              "C++ invalidate-line pending read response dropped while held");
    }
    dut.seq();
    ++sim_time;
  }
  require(resp_seen, "C++ invalidate-line pending read response timeout");

  if (trace.blocked_while_resp_held) {
    clear_inputs(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.read_ports[trace.read_master].resp.ready = true;
    dut.comb_outputs();
    require(dut.read_ports[trace.read_master].resp.valid,
            "C++ invalidate-line pending read response dropped before ready");
    dut.comb_inputs();
    table_driver.observe(dut);
    dut.seq();
    ++sim_time;

    for (int cycle = 0; cycle < 160; ++cycle) {
      clear_inputs(dut);
      table_driver.drive(dut);
      dut.set_llc_invalidate_line(true, trace.invalidate_addr);
      dut.comb_outputs();
      dut.comb_inputs();
      table_driver.observe(dut);
      if (dut.llc_invalidate_line_accepted()) {
        trace.accepted_after_resp_retire = true;
        dut.seq();
        ++sim_time;
        break;
      }
      dut.seq();
      ++sim_time;
    }
    require(trace.accepted_after_resp_retire,
            "C++ invalidate_line did not accept after read response retired");
  }
  dut.set_llc_invalidate_line(false, 0);
  return trace;
}

InvalidateLineRecoveryReadTrace
run_mode1_invalidate_line_recovery_read_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  StatefulLlcTableDriver table_driver(dut.get_llc_config());

  InvalidateLineRecoveryReadTrace trace{};
  trace.prefix = "CPP_MODE1_INVLINE_RECOVERY";
  trace.first.prefix = "CPP_MODE1_INVLINE_RECOVERY_FIRST";
  trace.first.req_addr = 0x40000e04u;
  trace.first.req_size = 3;
  trace.first.req_id = 0x6u;
  trace.first.beat_count = 2;
  trace.second.prefix = "CPP_MODE1_INVLINE_RECOVERY_SECOND";
  trace.second.req_addr = trace.first.req_addr;
  trace.second.req_size = trace.first.req_size;
  trace.second.req_id = 0x7u;
  trace.second.beat_count = 2;
  trace.read_master = axi_interconnect::MASTER_DCACHE_R;
  trace.invalidate_addr = trace.first.req_addr;

  issue_cache_read_miss_and_wait_response(dut, table_driver, trace.first,
                                          trace.read_master, 0xd00d1200u);

  for (int cycle = 0; cycle < 240 && !trace.invalidate_accepted; ++cycle) {
    clear_inputs(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    if (dut.llc_invalidate_line_accepted()) {
      trace.invalidate_accepted = true;
    }
    dut.seq();
    ++sim_time;
  }
  if (!trace.invalidate_accepted) {
    dut.debug_print();
  }
  require(trace.invalidate_accepted,
          "C++ invalidate_line recovery trace did not accept");
  dut.set_llc_invalidate_line(false, 0);

  issue_cache_read_miss_and_wait_response(dut, table_driver, trace.second,
                                          trace.read_master, 0xd00d1400u);
  return trace;
}

InvalidateLineScopeReadTrace
run_mode1_invalidate_line_scope_read_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  StatefulLlcTableDriver table_driver(dut.get_llc_config());

  const auto &cfg = dut.get_llc_config();
  const uint32_t same_set_stride = cfg.set_count() * cfg.line_bytes;

  InvalidateLineScopeReadTrace trace{};
  trace.prefix = "CPP_MODE1_INVLINE_SCOPE";
  trace.read_master = axi_interconnect::MASTER_DCACHE_R;
  trace.victim_fill.prefix = "CPP_MODE1_INVLINE_SCOPE_VICTIM_FILL";
  trace.victim_fill.req_addr = 0x40001204u;
  trace.victim_fill.req_size = 3;
  trace.victim_fill.req_id = 0x8u;
  trace.victim_fill.beat_count = 2;
  trace.survivor_fill.prefix = "CPP_MODE1_INVLINE_SCOPE_SURVIVOR_FILL";
  trace.survivor_fill.req_addr = trace.victim_fill.req_addr + same_set_stride;
  trace.survivor_fill.req_size = trace.victim_fill.req_size;
  trace.survivor_fill.req_id = 0x9u;
  trace.survivor_fill.beat_count = 2;
  trace.victim_after.prefix = "CPP_MODE1_INVLINE_SCOPE_VICTIM_AFTER";
  trace.victim_after.req_addr = trace.victim_fill.req_addr;
  trace.victim_after.req_size = trace.victim_fill.req_size;
  trace.victim_after.req_id = 0xAu;
  trace.victim_after.beat_count = 2;
  trace.survivor_after.prefix = "CPP_MODE1_INVLINE_SCOPE_SURVIVOR_AFTER";
  trace.survivor_after.req_addr = trace.survivor_fill.req_addr;
  trace.survivor_after.req_size = trace.survivor_fill.req_size;
  trace.survivor_after.req_id = 0xBu;
  trace.invalidate_addr = trace.victim_fill.req_addr;

  issue_cache_read_miss_and_wait_response(dut, table_driver, trace.victim_fill,
                                          trace.read_master, 0xd00d1600u);
  issue_cache_read_miss_and_wait_response(dut, table_driver, trace.survivor_fill,
                                          trace.read_master, 0xd00d1800u);

  for (int cycle = 0; cycle < 240 && !trace.invalidate_accepted; ++cycle) {
    clear_inputs(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    if (dut.llc_invalidate_line_accepted()) {
      trace.invalidate_accepted = true;
    }
    dut.seq();
    ++sim_time;
  }
  if (!trace.invalidate_accepted) {
    dut.debug_print();
  }
  require(trace.invalidate_accepted,
          "C++ invalidate_line scope trace did not accept");
  dut.set_llc_invalidate_line(false, 0);

  issue_cache_read_miss_and_wait_response(dut, table_driver, trace.victim_after,
                                          trace.read_master, 0xd00d1a00u);
  issue_cache_read_hit_and_wait_response(dut, table_driver, trace.survivor_after,
                                         trace.read_master,
                                         trace.survivor_hit_no_external);
  require(trace.survivor_hit_no_external,
          "C++ invalidate_line scope survivor hit escaped to external AXI");
  return trace;
}

InvalidateAllRecoveryReadTrace
run_mode1_invalidate_all_recovery_cache_read_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  StatefulLlcTableDriver table_driver(dut.get_llc_config());

  InvalidateAllRecoveryReadTrace trace{};
  trace.prefix = "CPP_MODE1_INVALL_RECOVERY_CACHE";
  trace.read_master = axi_interconnect::MASTER_DCACHE_R;
  trace.first_fill.prefix = "CPP_MODE1_INVALL_RECOVERY_FIRST_FILL";
  trace.first_fill.req_addr = 0x40001804u;
  trace.first_fill.req_size = 3;
  trace.first_fill.req_id = 0x1u;
  trace.first_fill.beat_count = 2;
  trace.second_fill.prefix = "CPP_MODE1_INVALL_RECOVERY_SECOND_FILL";
  trace.second_fill.req_addr = 0x40001844u;
  trace.second_fill.req_size = trace.first_fill.req_size;
  trace.second_fill.req_id = 0x2u;
  trace.second_fill.beat_count = 2;
  trace.first_after.prefix = "CPP_MODE1_INVALL_RECOVERY_FIRST_AFTER";
  trace.first_after.req_addr = trace.first_fill.req_addr;
  trace.first_after.req_size = trace.first_fill.req_size;
  trace.first_after.req_id = 0x3u;
  trace.first_after.beat_count = 2;
  trace.second_after.prefix = "CPP_MODE1_INVALL_RECOVERY_SECOND_AFTER";
  trace.second_after.req_addr = trace.second_fill.req_addr;
  trace.second_after.req_size = trace.second_fill.req_size;
  trace.second_after.req_id = 0x4u;
  trace.second_after.beat_count = 2;

  issue_cache_read_miss_and_wait_response(dut, table_driver, trace.first_fill,
                                          trace.read_master, 0xd00d1c00u);
  issue_cache_read_miss_and_wait_response(dut, table_driver, trace.second_fill,
                                          trace.read_master, 0xd00d1e00u);

  for (int cycle = 0; cycle < 240 && !trace.invalidate_accepted; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    if (dut.llc_invalidate_all_accepted()) {
      trace.invalidate_accepted = true;
    }
    dut.seq();
    ++sim_time;
  }
  if (!trace.invalidate_accepted) {
    dut.debug_print();
  }
  require(trace.invalidate_accepted,
          "C++ invalidate_all cache recovery trace did not accept");
  dut.set_llc_invalidate_all(false);

  issue_cache_read_miss_and_wait_response(dut, table_driver, trace.first_after,
                                          trace.read_master, 0xd00d2000u);
  issue_cache_read_miss_and_wait_response(dut, table_driver, trace.second_after,
                                          trace.read_master, 0xd00d2200u);
  return trace;
}

InvalidateAllMultiMasterRecoveryReadTrace
run_mode1_invalidate_all_multi_master_recovery_read_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  StatefulLlcTableDriver table_driver(dut.get_llc_config());

  InvalidateAllMultiMasterRecoveryReadTrace trace{};
  trace.prefix = "CPP_MODE1_INVALL_MULTI_MASTER_RECOVERY";
  trace.first_master = axi_interconnect::MASTER_ICACHE;
  trace.second_master = axi_interconnect::MASTER_DCACHE_R;
  trace.first_fill.prefix =
      "CPP_MODE1_INVALL_MULTI_MASTER_RECOVERY_FIRST_FILL";
  trace.first_fill.req_addr = 0x40002404u;
  trace.first_fill.req_size = 3;
  trace.first_fill.req_id = 0xCu;
  trace.first_fill.beat_count = 2;
  trace.second_fill.prefix =
      "CPP_MODE1_INVALL_MULTI_MASTER_RECOVERY_SECOND_FILL";
  trace.second_fill.req_addr = 0x40002444u;
  trace.second_fill.req_size = trace.first_fill.req_size;
  trace.second_fill.req_id = 0xDu;
  trace.second_fill.beat_count = 2;
  trace.first_after.prefix =
      "CPP_MODE1_INVALL_MULTI_MASTER_RECOVERY_FIRST_AFTER";
  trace.first_after.req_addr = trace.first_fill.req_addr;
  trace.first_after.req_size = trace.first_fill.req_size;
  trace.first_after.req_id = 0xEu;
  trace.first_after.beat_count = 2;
  trace.second_after.prefix =
      "CPP_MODE1_INVALL_MULTI_MASTER_RECOVERY_SECOND_AFTER";
  trace.second_after.req_addr = trace.second_fill.req_addr;
  trace.second_after.req_size = trace.second_fill.req_size;
  trace.second_after.req_id = 0xFu;
  trace.second_after.beat_count = 2;

  issue_cache_read_miss_and_wait_response(dut, table_driver, trace.first_fill,
                                          trace.first_master, 0xd00d3800u);
  issue_cache_read_miss_and_wait_response(dut, table_driver, trace.second_fill,
                                          trace.second_master, 0xd00d3a00u);

  for (int cycle = 0; cycle < 10000 && !trace.invalidate_accepted; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    if (dut.llc_invalidate_all_accepted()) {
      trace.invalidate_accepted = true;
    }
    dut.seq();
    ++sim_time;
  }
  if (!trace.invalidate_accepted) {
    dut.debug_print();
  }
  require(trace.invalidate_accepted,
          "C++ invalidate_all multi-master recovery trace did not accept");
  dut.set_llc_invalidate_all(false);

  issue_cache_read_miss_and_wait_response(dut, table_driver, trace.first_after,
                                          trace.first_master, 0xd00d3c00u);
  issue_cache_read_miss_and_wait_response(dut, table_driver, trace.second_after,
                                          trace.second_master, 0xd00d3e00u);
  return trace;
}

InvalidateAllRecoveryWriteTrace
run_mode1_invalidate_all_recovery_cache_write_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  StatefulLlcTableDriver table_driver(dut.get_llc_config());

  InvalidateAllRecoveryWriteTrace trace{};
  trace.prefix = "CPP_MODE1_INVALL_WRITE_RECOVERY_CACHE";
  trace.read_master = axi_interconnect::MASTER_DCACHE_R;
  trace.write_master = axi_interconnect::MASTER_DCACHE_W;
  trace.fill.prefix = "CPP_MODE1_INVALL_WRITE_RECOVERY_FILL";
  trace.fill.req_addr = 0x40001a04u;
  trace.fill.req_size = 3;
  trace.fill.req_id = 0x1u;
  trace.fill.beat_count = 2;
  trace.write_after.prefix = "CPP_MODE1_INVALL_WRITE_RECOVERY_WRITE";
  trace.write_after.req_addr = trace.fill.req_addr;
  trace.write_after.req_size = trace.fill.req_size;
  trace.write_after.req_id = 0x2u;
  const auto write_data = single_word_data(0xabcdef12u);
  const auto write_strobe = byte_strobe(0xfu);
  trace.write_after.req_wdata = wide_write_words(write_data);
  trace.write_after.req_wstrb = write_strobe_mask(write_strobe);
  trace.refill_after.prefix = "CPP_MODE1_INVALL_WRITE_RECOVERY_REFILL";
  trace.refill_after.req_addr = trace.fill.req_addr;
  trace.refill_after.req_size = 63;
  trace.refill_after.req_id = 0;
  trace.refill_after.beat_count = 2;
  trace.refill_after.resp_data.assign(
      axi_interconnect::MAX_READ_TRANSACTION_WORDS, 0);
  trace.read_hit_after.prefix = "CPP_MODE1_INVALL_WRITE_RECOVERY_HIT";
  trace.read_hit_after.req_addr = trace.fill.req_addr;
  trace.read_hit_after.req_size = trace.fill.req_size;
  trace.read_hit_after.req_id = 0x3u;

  issue_cache_read_miss_and_wait_response(dut, table_driver, trace.fill,
                                          trace.read_master, 0xd00d2400u);

  for (int cycle = 0; cycle < 10000 && !trace.invalidate_accepted; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    if (dut.llc_invalidate_all_accepted()) {
      trace.invalidate_accepted = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(trace.invalidate_accepted,
          "C++ invalidate_all write recovery trace did not accept");
  dut.set_llc_invalidate_all(false);

  bool accepted = false;
  bool ar_seen = false;
  bool request_active = true;
  for (int cycle = 0; cycle < 240 && !ar_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    const bool ready_snapshot =
        dut.write_ports[trace.write_master].req.ready;
    if (request_active) {
      auto &req = dut.write_ports[trace.write_master].req;
      req.valid = true;
      req.addr = trace.write_after.req_addr;
      req.total_size = trace.write_after.req_size;
      req.id = trace.write_after.req_id;
      req.wdata = write_data;
      req.wstrb = write_strobe;
      req.bypass = false;
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    if (request_active && ready_snapshot) {
      accepted = true;
      request_active = false;
    }
    if (dut.axi_ddr_io.ar.arvalid) {
      require(!dut.axi_mmio_io.ar.arvalid,
              "C++ invall write recovery refill escaped to MMIO AR");
      trace.refill_after.araddr =
          static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
      trace.refill_after.arlen =
          static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
      trace.refill_after.arsize =
          static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
      trace.refill_after.arburst =
          static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
      trace.refill_after.arid =
          static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
      ar_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ invall write recovery write was not accepted");
  require(ar_seen, "C++ invall write recovery did not issue DDR refill AR");
  require(trace.refill_after.beat_count ==
              static_cast<uint32_t>(trace.refill_after.arlen) + 1u,
          "C++ invall write recovery refill beat count mismatch");

  for (uint32_t beat = 0; beat < trace.refill_after.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = trace.refill_after.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == trace.refill_after.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(0xd00d2600u + beat * 0x100u);
    trace.refill_after.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    require(dut.axi_ddr_io.r.rready,
            "C++ invall write recovery DDR R was backpressured");
    dut.comb_inputs();
    table_driver.observe(dut);
    dut.seq();
    ++sim_time;
  }

  bool write_resp_seen = false;
  for (int cycle = 0; cycle < 240 && !write_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    auto &resp = dut.write_ports[trace.write_master].resp;
    if (resp.valid) {
      write_resp_seen = true;
      trace.write_after.resp_id = static_cast<uint8_t>(resp.id);
      trace.write_after.resp_code = static_cast<uint8_t>(resp.resp);
      resp.ready = true;
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    dut.seq();
    ++sim_time;
  }
  require(write_resp_seen,
          "C++ invall write recovery write response timeout");

  issue_cache_read_hit_and_wait_response(
      dut, table_driver, trace.read_hit_after, trace.read_master,
      trace.read_hit_no_external);
  return trace;
}

InvalidateAllMultiReadTrace run_mode1_invalidate_all_multi_read_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  StatefulLlcTableDriver table_driver(dut.get_llc_config());

  InvalidateAllMultiReadTrace trace{};
  trace.prefix = "CPP_MODE1_INVALL_MULTI_READ";
  trace.read_master = axi_interconnect::MASTER_DCACHE_R;
  trace.first.prefix = "CPP_MODE1_INVALL_MULTI_READ_FIRST";
  trace.first.req_addr = 0x40001c04u;
  trace.first.req_size = 3;
  trace.first.req_id = 0x4u;
  trace.first.beat_count = 2;
  trace.second.prefix = "CPP_MODE1_INVALL_MULTI_READ_SECOND";
  trace.second.req_addr = 0x40001c44u;
  trace.second.req_size = 3;
  trace.second.req_id = 0x5u;
  trace.second.beat_count = 2;

  auto issue_read_ar_only = [&](ReadTrace &read_trace) {
    bool accepted = false;
    bool ar_seen = false;
    bool request_active = true;
    for (int cycle = 0; cycle < 240 && !ar_seen; ++cycle) {
      clear_inputs(dut);
      set_downstream_ready(dut);
      table_driver.drive(dut);
      if (request_active) {
        auto &req = dut.read_ports[trace.read_master].req;
        req.valid = true;
        req.addr = read_trace.req_addr;
        req.total_size = read_trace.req_size;
        req.id = read_trace.req_id;
        req.bypass = false;
      }
      dut.comb_outputs();
      dut.comb_inputs();
      table_driver.observe(dut);
      if (request_active && dut.read_ports[trace.read_master].req.ready) {
        accepted = true;
        request_active = false;
      }
      if (dut.axi_ddr_io.ar.arvalid) {
        require(!dut.axi_mmio_io.ar.arvalid,
                "C++ invall multi-read DDR AR overlapped with MMIO AR");
        read_trace.araddr =
            static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
        read_trace.arlen = static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
        read_trace.arsize = static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
        read_trace.arburst =
            static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
        read_trace.arid = static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
        ar_seen = true;
      }
      dut.seq();
      ++sim_time;
    }
    require(accepted, "C++ invall multi-read request was not accepted");
    require(ar_seen, "C++ invall multi-read did not issue DDR AR");
    require(read_trace.beat_count ==
                static_cast<uint32_t>(read_trace.arlen) + 1u,
            "C++ invall multi-read beat count mismatch");
  };

  issue_read_ar_only(trace.first);
  issue_read_ar_only(trace.second);

  trace.first_rready_while_invalidate_pending = true;
  for (uint32_t beat = 0; beat < trace.first.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = trace.first.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == trace.first.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(0xd00d2800u + beat * 0x100u);
    trace.first.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    trace.first_rready_while_invalidate_pending =
        trace.first_rready_while_invalidate_pending &&
        dut.axi_ddr_io.r.rready;
    require(dut.axi_ddr_io.r.rready,
            "C++ invall multi-read first DDR R was backpressured");
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall multi-read accepted during first R");
    dut.seq();
    ++sim_time;
  }

  bool first_resp_seen = false;
  for (int cycle = 0; cycle < 240 && !first_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    auto &resp = dut.read_ports[trace.read_master].resp;
    if (resp.valid) {
      first_resp_seen = true;
      trace.first.resp_id = static_cast<uint8_t>(resp.id);
      trace.first.resp_data = wide_read_words(resp.data);
      trace.blocked_while_first_resp_held =
          !dut.llc_invalidate_all_accepted();
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall multi-read accepted while first response pending");
    dut.seq();
    ++sim_time;
  }
  require(first_resp_seen, "C++ invall multi-read first response timeout");

  trace.second_rready_while_first_resp_held = true;
  for (uint32_t beat = 0; beat < trace.second.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = trace.second.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == trace.second.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(0xd00d2a00u + beat * 0x100u);
    trace.second.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    require(dut.read_ports[trace.read_master].resp.valid,
            "C++ invall multi-read first response dropped while held");
    trace.second_rready_while_first_resp_held =
        trace.second_rready_while_first_resp_held &&
        dut.axi_ddr_io.r.rready;
    require(dut.axi_ddr_io.r.rready,
            "C++ invall multi-read second DDR R was backpressured");
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall multi-read accepted during second R");
    dut.seq();
    ++sim_time;
  }

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.read_ports[trace.read_master].resp.ready = true;
  dut.comb_outputs();
  require(dut.read_ports[trace.read_master].resp.valid,
          "C++ invall multi-read first response not valid at retire");
  require(!dut.llc_invalidate_all_accepted(),
          "C++ invall multi-read accepted before first response retire");
  dut.comb_inputs();
  table_driver.observe(dut);
  dut.seq();
  ++sim_time;

  bool second_resp_seen = false;
  for (int cycle = 0; cycle < 240 && !second_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    auto &resp = dut.read_ports[trace.read_master].resp;
    if (resp.valid) {
      second_resp_seen = true;
      trace.second.resp_id = static_cast<uint8_t>(resp.id);
      trace.second.resp_data = wide_read_words(resp.data);
      trace.blocked_while_second_resp_held =
          !dut.llc_invalidate_all_accepted();
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall multi-read accepted while second response pending");
    dut.seq();
    ++sim_time;
  }
  require(second_resp_seen, "C++ invall multi-read second response timeout");

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.read_ports[trace.read_master].resp.ready = true;
  dut.comb_outputs();
  require(dut.read_ports[trace.read_master].resp.valid,
          "C++ invall multi-read second response not valid at retire");
  require(!dut.llc_invalidate_all_accepted(),
          "C++ invall multi-read accepted before second response retire");
  dut.comb_inputs();
  table_driver.observe(dut);
  dut.seq();
  ++sim_time;

  for (int retry = 0; retry < 10000; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    const bool accepted_now = dut.llc_invalidate_all_accepted();
    dut.seq();
    ++sim_time;
    if (accepted_now) {
      trace.accepted_after_resp_retire = true;
      dut.set_llc_invalidate_all(false);
      return trace;
    }
  }
  require(false, "C++ invall multi-read did not accept after responses retired");
  return trace;
}

InvalidateAllMultiMasterReadTrace
run_mode1_invalidate_all_multi_master_read_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  StatefulLlcTableDriver table_driver(dut.get_llc_config());

  InvalidateAllMultiMasterReadTrace trace{};
  trace.prefix = "CPP_MODE1_INVALL_MULTI_MASTER_READ";
  trace.first_master = axi_interconnect::MASTER_ICACHE;
  trace.second_master = axi_interconnect::MASTER_DCACHE_R;
  trace.first.prefix = "CPP_MODE1_INVALL_MULTI_MASTER_READ_FIRST";
  trace.first.req_addr = 0x40002004u;
  trace.first.req_size = 3;
  trace.first.req_id = 0x8u;
  trace.first.beat_count = 2;
  trace.second.prefix = "CPP_MODE1_INVALL_MULTI_MASTER_READ_SECOND";
  trace.second.req_addr = 0x40002044u;
  trace.second.req_size = 3;
  trace.second.req_id = 0x9u;
  trace.second.beat_count = 2;

  auto issue_read_ar_only = [&](ReadTrace &read_trace, uint8_t master,
                                const char *label) {
    bool accepted = false;
    bool ar_seen = false;
    bool request_active = true;
    bool ready_seen = false;
    for (int cycle = 0; cycle < 240 && !ar_seen; ++cycle) {
      clear_inputs(dut);
      set_downstream_ready(dut);
      table_driver.drive(dut);
      if (request_active) {
        auto &req = dut.read_ports[master].req;
        req.valid = true;
        req.addr = read_trace.req_addr;
        req.total_size = read_trace.req_size;
        req.id = read_trace.req_id;
        req.bypass = false;
      }
      dut.comb_outputs();
      dut.comb_inputs();
      table_driver.observe(dut);
      if (request_active && dut.read_ports[master].req.ready) {
        if (master == axi_interconnect::MASTER_DCACHE_R || ready_seen) {
          accepted = true;
          request_active = false;
        } else {
          ready_seen = true;
        }
      }
      if (dut.axi_ddr_io.ar.arvalid) {
        require(!dut.axi_mmio_io.ar.arvalid,
                "C++ invall multi-master read DDR AR overlapped with MMIO AR");
        read_trace.araddr =
            static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
        read_trace.arlen = static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
        read_trace.arsize = static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
        read_trace.arburst =
            static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
        read_trace.arid = static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
        ar_seen = true;
      }
      dut.seq();
      ++sim_time;
    }
    require(accepted, label);
    require(ar_seen, "C++ invall multi-master read did not issue DDR AR");
    require(read_trace.beat_count ==
                static_cast<uint32_t>(read_trace.arlen) + 1u,
            "C++ invall multi-master read beat count mismatch");
  };

  issue_read_ar_only(trace.first, trace.first_master,
                     "C++ invall multi-master first request not accepted");
  issue_read_ar_only(trace.second, trace.second_master,
                     "C++ invall multi-master second request not accepted");

  trace.first_rready_while_invalidate_pending = true;
  for (uint32_t beat = 0; beat < trace.first.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = trace.first.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == trace.first.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(0xd00d3000u + beat * 0x100u);
    trace.first.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    trace.first_rready_while_invalidate_pending =
        trace.first_rready_while_invalidate_pending &&
        dut.axi_ddr_io.r.rready;
    require(dut.axi_ddr_io.r.rready,
            "C++ invall multi-master first DDR R was backpressured");
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall multi-master accepted during first R");
    dut.seq();
    ++sim_time;
  }

  bool first_resp_seen = false;
  for (int cycle = 0; cycle < 240 && !first_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    auto &resp = dut.read_ports[trace.first_master].resp;
    if (resp.valid) {
      first_resp_seen = true;
      trace.first.resp_id = static_cast<uint8_t>(resp.id);
      trace.first.resp_data = wide_read_words(resp.data);
      trace.blocked_while_first_resp_held =
          !dut.llc_invalidate_all_accepted();
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall multi-master accepted while first response pending");
    dut.seq();
    ++sim_time;
  }
  require(first_resp_seen,
          "C++ invall multi-master first response timeout");

  trace.second_rready_while_first_resp_held = true;
  for (uint32_t beat = 0; beat < trace.second.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = trace.second.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == trace.second.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(0xd00d3200u + beat * 0x100u);
    trace.second.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    require(dut.read_ports[trace.first_master].resp.valid,
            "C++ invall multi-master first response dropped while held");
    trace.second_rready_while_first_resp_held =
        trace.second_rready_while_first_resp_held &&
        dut.axi_ddr_io.r.rready;
    require(dut.axi_ddr_io.r.rready,
            "C++ invall multi-master second DDR R was backpressured");
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall multi-master accepted during second R");
    dut.seq();
    ++sim_time;
  }

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.read_ports[trace.first_master].resp.ready = true;
  dut.comb_outputs();
  require(dut.read_ports[trace.first_master].resp.valid,
          "C++ invall multi-master first response not valid at retire");
  require(!dut.llc_invalidate_all_accepted(),
          "C++ invall multi-master accepted before first response retire");
  dut.comb_inputs();
  table_driver.observe(dut);
  dut.seq();
  ++sim_time;

  bool second_resp_seen = false;
  for (int cycle = 0; cycle < 240 && !second_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    auto &resp = dut.read_ports[trace.second_master].resp;
    if (resp.valid) {
      second_resp_seen = true;
      trace.second.resp_id = static_cast<uint8_t>(resp.id);
      trace.second.resp_data = wide_read_words(resp.data);
      trace.blocked_while_second_resp_held =
          !dut.llc_invalidate_all_accepted();
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall multi-master accepted while second response pending");
    dut.seq();
    ++sim_time;
  }
  require(second_resp_seen,
          "C++ invall multi-master second response timeout");

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.read_ports[trace.second_master].resp.ready = true;
  dut.comb_outputs();
  require(dut.read_ports[trace.second_master].resp.valid,
          "C++ invall multi-master second response not valid at retire");
  require(!dut.llc_invalidate_all_accepted(),
          "C++ invall multi-master accepted before second response retire");
  dut.comb_inputs();
  table_driver.observe(dut);
  dut.seq();
  ++sim_time;

  for (int retry = 0; retry < 10000; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    const bool accepted_now = dut.llc_invalidate_all_accepted();
    dut.seq();
    ++sim_time;
    if (accepted_now) {
      trace.accepted_after_resp_retire = true;
      dut.set_llc_invalidate_all(false);
      return trace;
    }
  }
  require(false,
          "C++ invall multi-master did not accept after responses retired");
  return trace;
}

InvalidateLineMultiMasterReadTrace
run_mode1_invalidate_line_multi_master_read_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  StatefulLlcTableDriver table_driver(dut.get_llc_config());

  InvalidateLineMultiMasterReadTrace trace{};
  trace.prefix = "CPP_MODE1_INVLINE_MULTI_MASTER_READ";
  trace.first_master = axi_interconnect::MASTER_ICACHE;
  trace.second_master = axi_interconnect::MASTER_DCACHE_R;
  trace.first.prefix = "CPP_MODE1_INVLINE_MULTI_MASTER_READ_FIRST";
  trace.first.req_addr = 0x40002204u;
  trace.first.req_size = 3;
  trace.first.req_id = 0xAu;
  trace.first.beat_count = 2;
  trace.second.prefix = "CPP_MODE1_INVLINE_MULTI_MASTER_READ_SECOND";
  trace.second.req_addr = 0x40002244u;
  trace.second.req_size = 3;
  trace.second.req_id = 0xBu;
  trace.second.beat_count = 2;
  trace.invalidate_addr = trace.second.req_addr;

  auto issue_read_ar_only = [&](ReadTrace &read_trace, uint8_t master,
                                const char *label) {
    bool accepted = false;
    bool ar_seen = false;
    bool request_active = true;
    bool ready_seen = false;
    for (int cycle = 0; cycle < 240 && !ar_seen; ++cycle) {
      clear_inputs(dut);
      set_downstream_ready(dut);
      table_driver.drive(dut);
      if (request_active) {
        auto &req = dut.read_ports[master].req;
        req.valid = true;
        req.addr = read_trace.req_addr;
        req.total_size = read_trace.req_size;
        req.id = read_trace.req_id;
        req.bypass = false;
      }
      dut.comb_outputs();
      dut.comb_inputs();
      table_driver.observe(dut);
      if (request_active && dut.read_ports[master].req.ready) {
        if (master == axi_interconnect::MASTER_DCACHE_R || ready_seen) {
          accepted = true;
          request_active = false;
        } else {
          ready_seen = true;
        }
      }
      if (dut.axi_ddr_io.ar.arvalid) {
        require(!dut.axi_mmio_io.ar.arvalid,
                "C++ invline multi-master read DDR AR overlapped with MMIO AR");
        read_trace.araddr =
            static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
        read_trace.arlen = static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
        read_trace.arsize = static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
        read_trace.arburst =
            static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
        read_trace.arid = static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
        ar_seen = true;
      }
      dut.seq();
      ++sim_time;
    }
    require(accepted, label);
    require(ar_seen, "C++ invline multi-master read did not issue DDR AR");
    require(read_trace.beat_count ==
                static_cast<uint32_t>(read_trace.arlen) + 1u,
            "C++ invline multi-master read beat count mismatch");
  };

  issue_read_ar_only(trace.first, trace.first_master,
                     "C++ invline multi-master first request not accepted");
  issue_read_ar_only(trace.second, trace.second_master,
                     "C++ invline multi-master second request not accepted");

  trace.first_rready_while_invalidate_pending = true;
  for (uint32_t beat = 0; beat < trace.first.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = trace.first.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == trace.first.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(0xd00d3400u + beat * 0x100u);
    trace.first.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    trace.first_rready_while_invalidate_pending =
        trace.first_rready_while_invalidate_pending &&
        dut.axi_ddr_io.r.rready;
    require(dut.axi_ddr_io.r.rready,
            "C++ invline multi-master first DDR R was backpressured");
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_line_accepted(),
            "C++ invline multi-master accepted during first R");
    dut.seq();
    ++sim_time;
  }

  bool first_resp_seen = false;
  for (int cycle = 0; cycle < 240 && !first_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.comb_outputs();
    auto &resp = dut.read_ports[trace.first_master].resp;
    if (resp.valid) {
      first_resp_seen = true;
      trace.first.resp_id = static_cast<uint8_t>(resp.id);
      trace.first.resp_data = wide_read_words(resp.data);
      trace.blocked_while_first_resp_held =
          !dut.llc_invalidate_line_accepted();
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_line_accepted(),
            "C++ invline multi-master accepted while first response pending");
    dut.seq();
    ++sim_time;
  }
  require(first_resp_seen,
          "C++ invline multi-master first response timeout");

  trace.second_rready_while_first_resp_held = true;
  for (uint32_t beat = 0; beat < trace.second.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = trace.second.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == trace.second.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(0xd00d3600u + beat * 0x100u);
    trace.second.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    require(dut.read_ports[trace.first_master].resp.valid,
            "C++ invline multi-master first response dropped while held");
    trace.second_rready_while_first_resp_held =
        trace.second_rready_while_first_resp_held &&
        dut.axi_ddr_io.r.rready;
    require(dut.axi_ddr_io.r.rready,
            "C++ invline multi-master second DDR R was backpressured");
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_line_accepted(),
            "C++ invline multi-master accepted during second R");
    dut.seq();
    ++sim_time;
  }

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_line(true, trace.invalidate_addr);
  dut.read_ports[trace.first_master].resp.ready = true;
  dut.comb_outputs();
  require(dut.read_ports[trace.first_master].resp.valid,
          "C++ invline multi-master first response not valid at retire");
  require(!dut.llc_invalidate_line_accepted(),
          "C++ invline multi-master accepted before first response retire");
  dut.comb_inputs();
  table_driver.observe(dut);
  dut.seq();
  ++sim_time;

  bool second_resp_seen = false;
  for (int cycle = 0; cycle < 240 && !second_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.comb_outputs();
    auto &resp = dut.read_ports[trace.second_master].resp;
    if (resp.valid) {
      second_resp_seen = true;
      trace.second.resp_id = static_cast<uint8_t>(resp.id);
      trace.second.resp_data = wide_read_words(resp.data);
      trace.blocked_while_second_resp_held =
          !dut.llc_invalidate_line_accepted();
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_line_accepted(),
            "C++ invline multi-master accepted while second response pending");
    dut.seq();
    ++sim_time;
  }
  require(second_resp_seen,
          "C++ invline multi-master second response timeout");

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_line(true, trace.invalidate_addr);
  dut.read_ports[trace.second_master].resp.ready = true;
  dut.comb_outputs();
  require(dut.read_ports[trace.second_master].resp.valid,
          "C++ invline multi-master second response not valid at retire");
  require(!dut.llc_invalidate_line_accepted(),
          "C++ invline multi-master accepted before second response retire");
  dut.comb_inputs();
  table_driver.observe(dut);
  dut.seq();
  ++sim_time;

  for (int retry = 0; retry < 10000; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    const bool accepted_now = dut.llc_invalidate_line_accepted();
    dut.seq();
    ++sim_time;
    if (accepted_now) {
      trace.accepted_after_resp_retire = true;
      dut.set_llc_invalidate_line(false, 0);
      return trace;
    }
  }
  require(false,
          "C++ invline multi-master did not accept after responses retired");
  return trace;
}

InvalidateLineMultiReadTrace run_mode1_invalidate_line_multi_read_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  StatefulLlcTableDriver table_driver(dut.get_llc_config());

  InvalidateLineMultiReadTrace trace{};
  trace.prefix = "CPP_MODE1_INVLINE_MULTI_READ";
  trace.read_master = axi_interconnect::MASTER_DCACHE_R;
  trace.first.prefix = "CPP_MODE1_INVLINE_MULTI_READ_FIRST";
  trace.first.req_addr = 0x40001e04u;
  trace.first.req_size = 3;
  trace.first.req_id = 0x6u;
  trace.first.beat_count = 2;
  trace.second.prefix = "CPP_MODE1_INVLINE_MULTI_READ_SECOND";
  trace.second.req_addr = 0x40001e44u;
  trace.second.req_size = 3;
  trace.second.req_id = 0x7u;
  trace.second.beat_count = 2;
  trace.invalidate_addr = trace.second.req_addr;

  auto issue_read_ar_only = [&](ReadTrace &read_trace) {
    bool accepted = false;
    bool ar_seen = false;
    bool request_active = true;
    for (int cycle = 0; cycle < 240 && !ar_seen; ++cycle) {
      clear_inputs(dut);
      set_downstream_ready(dut);
      table_driver.drive(dut);
      if (request_active) {
        auto &req = dut.read_ports[trace.read_master].req;
        req.valid = true;
        req.addr = read_trace.req_addr;
        req.total_size = read_trace.req_size;
        req.id = read_trace.req_id;
        req.bypass = false;
      }
      dut.comb_outputs();
      dut.comb_inputs();
      table_driver.observe(dut);
      if (request_active && dut.read_ports[trace.read_master].req.ready) {
        accepted = true;
        request_active = false;
      }
      if (dut.axi_ddr_io.ar.arvalid) {
        require(!dut.axi_mmio_io.ar.arvalid,
                "C++ invline multi-read DDR AR overlapped with MMIO AR");
        read_trace.araddr =
            static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
        read_trace.arlen = static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
        read_trace.arsize = static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
        read_trace.arburst =
            static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
        read_trace.arid = static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
        ar_seen = true;
      }
      dut.seq();
      ++sim_time;
    }
    require(accepted, "C++ invline multi-read request was not accepted");
    require(ar_seen, "C++ invline multi-read did not issue DDR AR");
    require(read_trace.beat_count ==
                static_cast<uint32_t>(read_trace.arlen) + 1u,
            "C++ invline multi-read beat count mismatch");
  };

  issue_read_ar_only(trace.first);
  issue_read_ar_only(trace.second);

  trace.first_rready_while_invalidate_pending = true;
  for (uint32_t beat = 0; beat < trace.first.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = trace.first.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == trace.first.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(0xd00d2c00u + beat * 0x100u);
    trace.first.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    trace.first_rready_while_invalidate_pending =
        trace.first_rready_while_invalidate_pending &&
        dut.axi_ddr_io.r.rready;
    require(dut.axi_ddr_io.r.rready,
            "C++ invline multi-read first DDR R was backpressured");
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_line_accepted(),
            "C++ invline multi-read accepted during first R");
    dut.seq();
    ++sim_time;
  }

  bool first_resp_seen = false;
  for (int cycle = 0; cycle < 240 && !first_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.comb_outputs();
    auto &resp = dut.read_ports[trace.read_master].resp;
    if (resp.valid) {
      first_resp_seen = true;
      trace.first.resp_id = static_cast<uint8_t>(resp.id);
      trace.first.resp_data = wide_read_words(resp.data);
      trace.blocked_while_first_resp_held =
          !dut.llc_invalidate_line_accepted();
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_line_accepted(),
            "C++ invline multi-read accepted while first response pending");
    dut.seq();
    ++sim_time;
  }
  require(first_resp_seen, "C++ invline multi-read first response timeout");

  trace.second_rready_while_first_resp_held = true;
  for (uint32_t beat = 0; beat < trace.second.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = trace.second.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == trace.second.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(0xd00d2e00u + beat * 0x100u);
    trace.second.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    require(dut.read_ports[trace.read_master].resp.valid,
            "C++ invline multi-read first response dropped while held");
    trace.second_rready_while_first_resp_held =
        trace.second_rready_while_first_resp_held &&
        dut.axi_ddr_io.r.rready;
    require(dut.axi_ddr_io.r.rready,
            "C++ invline multi-read second DDR R was backpressured");
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_line_accepted(),
            "C++ invline multi-read accepted during second R");
    dut.seq();
    ++sim_time;
  }

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_line(true, trace.invalidate_addr);
  dut.read_ports[trace.read_master].resp.ready = true;
  dut.comb_outputs();
  require(dut.read_ports[trace.read_master].resp.valid,
          "C++ invline multi-read first response not valid at retire");
  require(!dut.llc_invalidate_line_accepted(),
          "C++ invline multi-read accepted before first response retire");
  dut.comb_inputs();
  table_driver.observe(dut);
  dut.seq();
  ++sim_time;

  bool second_resp_seen = false;
  for (int cycle = 0; cycle < 240 && !second_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.comb_outputs();
    auto &resp = dut.read_ports[trace.read_master].resp;
    if (resp.valid) {
      second_resp_seen = true;
      trace.second.resp_id = static_cast<uint8_t>(resp.id);
      trace.second.resp_data = wide_read_words(resp.data);
      trace.blocked_while_second_resp_held =
          !dut.llc_invalidate_line_accepted();
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_line_accepted(),
            "C++ invline multi-read accepted while second response pending");
    dut.seq();
    ++sim_time;
  }
  require(second_resp_seen, "C++ invline multi-read second response timeout");

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_line(true, trace.invalidate_addr);
  dut.read_ports[trace.read_master].resp.ready = true;
  dut.comb_outputs();
  require(dut.read_ports[trace.read_master].resp.valid,
          "C++ invline multi-read second response not valid at retire");
  require(!dut.llc_invalidate_line_accepted(),
          "C++ invline multi-read accepted before second response retire");
  dut.comb_inputs();
  table_driver.observe(dut);
  dut.seq();
  ++sim_time;

  for (int retry = 0; retry < 10000; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    const bool accepted_now = dut.llc_invalidate_line_accepted();
    dut.seq();
    ++sim_time;
    if (accepted_now) {
      trace.accepted_after_resp_retire = true;
      dut.set_llc_invalidate_line(false, 0);
      return trace;
    }
  }
  require(false, "C++ invline multi-read did not accept after responses retired");
  return trace;
}

InvalidateLineCacheReadWriteTrace
run_mode1_invalidate_line_cache_read_write_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  InvalidLlcTableDriver table_driver(dut.get_llc_config());

  InvalidateLineCacheReadWriteTrace trace{};
  trace.prefix = "CPP_MODE1_INVLINE_CACHE_RW";
  trace.read_master = axi_interconnect::MASTER_DCACHE_R;
  trace.write_master = axi_interconnect::MASTER_DCACHE_W;
  trace.read.prefix = "CPP_MODE1_INVLINE_CACHE_RW_READ";
  trace.read.req_addr = 0x40001f04u;
  trace.read.req_size = 3;
  trace.read.req_id = 0x6u;
  trace.read.beat_count = 2;
  trace.write.prefix = "CPP_MODE1_INVLINE_CACHE_RW_WRITE";
  trace.write.req_addr = 0x40001f44u;
  trace.write.req_size = 3;
  trace.write.req_id = 0x7u;
  const auto write_data = single_word_data(0xacc01f44u);
  const auto write_strobe = byte_strobe(0xfu);
  trace.write.req_wdata = wide_write_words(write_data);
  trace.write.req_wstrb = write_strobe_mask(write_strobe);
  trace.write_refill.prefix = "CPP_MODE1_INVLINE_CACHE_RW_WRITE_REFILL";
  trace.write_refill.req_addr = trace.write.req_addr;
  trace.write_refill.req_size = 63;
  trace.write_refill.req_id = 0;
  trace.write_refill.beat_count = 2;
  trace.write_refill.resp_data.assign(
      axi_interconnect::MAX_READ_TRANSACTION_WORDS, 0);
  trace.invalidate_addr = trace.write.req_addr;

  bool read_accepted = false;
  bool read_ar_seen = false;
  bool read_request_active = true;
  for (int cycle = 0; cycle < 240 && !read_ar_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    if (read_request_active) {
      auto &req = dut.read_ports[trace.read_master].req;
      req.valid = true;
      req.addr = trace.read.req_addr;
      req.total_size = trace.read.req_size;
      req.id = trace.read.req_id;
      req.bypass = false;
    }
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    if (read_request_active && dut.read_ports[trace.read_master].req.ready) {
      read_accepted = true;
      read_request_active = false;
    }
    if (dut.axi_ddr_io.ar.arvalid) {
      require(!dut.axi_mmio_io.ar.arvalid,
              "C++ invline cache RW read DDR AR overlapped with MMIO AR");
      trace.read.araddr = static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
      trace.read.arlen = static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
      trace.read.arsize = static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
      trace.read.arburst = static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
      trace.read.arid = static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
      read_ar_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(read_accepted, "C++ invline cache RW read was not accepted");
  require(read_ar_seen, "C++ invline cache RW read did not issue DDR AR");
  require(trace.read.beat_count == static_cast<uint32_t>(trace.read.arlen) + 1u,
          "C++ invline cache RW read beat count mismatch");

  auto issue_write_ar_only =
      [&](WriteTrace &write_trace, ReadTrace &refill_trace) {
        bool accepted = false;
        bool ar_seen = false;
        bool request_active = true;
        for (int cycle = 0; cycle < 240 && !ar_seen; ++cycle) {
          clear_inputs(dut);
          set_downstream_ready(dut);
          table_driver.drive(dut);
          dut.comb_outputs();
          const bool ready_snapshot =
              dut.write_ports[trace.write_master].req.ready;
          if (request_active) {
            auto &req = dut.write_ports[trace.write_master].req;
            req.valid = true;
            req.addr = write_trace.req_addr;
            req.total_size = write_trace.req_size;
            req.id = write_trace.req_id;
            req.wdata = write_data;
            req.wstrb = write_strobe;
            req.bypass = false;
          }
          dut.comb_inputs();
          table_driver.observe(dut);
          if (request_active && ready_snapshot) {
            accepted = true;
            request_active = false;
          }
          if (dut.axi_ddr_io.ar.arvalid) {
            require(!dut.axi_mmio_io.ar.arvalid,
                    "C++ invline cache RW write DDR AR overlapped with MMIO AR");
            refill_trace.araddr =
                static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
            refill_trace.arlen =
                static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
            refill_trace.arsize =
                static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
            refill_trace.arburst =
                static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
            refill_trace.arid =
                static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
            ar_seen = true;
          }
          dut.seq();
          ++sim_time;
        }
        require(accepted, "C++ invline cache RW write was not accepted");
        require(ar_seen, "C++ invline cache RW write did not issue DDR AR");
        require(refill_trace.beat_count ==
                    static_cast<uint32_t>(refill_trace.arlen) + 1u,
                "C++ invline cache RW write beat count mismatch");
      };

  issue_write_ar_only(trace.write, trace.write_refill);
  require(trace.read.arid != trace.write_refill.arid,
          "C++ invline cache RW reused a downstream refill ARID");

  auto drive_refill = [&](ReadTrace &refill_trace, uint32_t seed,
                          bool write_while_read_held) {
    for (uint32_t beat = 0; beat < refill_trace.beat_count; ++beat) {
      clear_inputs(dut);
      set_downstream_ready(dut);
      table_driver.drive(dut);
      dut.set_llc_invalidate_line(true, trace.invalidate_addr);
      dut.axi_ddr_io.r.rvalid = true;
      dut.axi_ddr_io.r.rid = refill_trace.arid;
      dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
      dut.axi_ddr_io.r.rlast = beat == refill_trace.beat_count - 1u;
      dut.axi_ddr_io.r.rdata = ddr_read_beat(seed + beat * 0x100u);
      refill_trace.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
      dut.comb_outputs();
      if (write_while_read_held) {
        trace.write_rready_while_read_resp_held =
            trace.write_rready_while_read_resp_held &&
            dut.axi_ddr_io.r.rready;
        require(dut.read_ports[trace.read_master].resp.valid &&
                    dut.read_ports[trace.read_master].resp.id ==
                        trace.read.req_id,
                "C++ invline cache RW read response not held during write R");
      } else {
        trace.read_rready_while_invalidate_pending =
            trace.read_rready_while_invalidate_pending &&
            dut.axi_ddr_io.r.rready;
      }
      require(dut.axi_ddr_io.r.rready,
              "C++ invline cache RW DDR R was backpressured");
      require(!dut.llc_invalidate_line_accepted(),
              "C++ invline cache RW accepted during DDR R");
      dut.comb_inputs();
      table_driver.observe(dut);
      dut.seq();
      ++sim_time;
    }
  };

  trace.read_rready_while_invalidate_pending = true;
  trace.write_rready_while_read_resp_held = true;
  drive_refill(trace.read, 0xd00d3000u, false);

  bool read_resp_seen = false;
  for (int cycle = 0; cycle < 260 && !read_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.comb_outputs();
    auto &resp = dut.read_ports[trace.read_master].resp;
    if (resp.valid) {
      read_resp_seen = true;
      trace.read.resp_id = static_cast<uint8_t>(resp.id);
      trace.read.resp_data = wide_read_words(resp.data);
      trace.blocked_while_read_resp_held =
          !dut.llc_invalidate_line_accepted();
    }
    require(!dut.llc_invalidate_line_accepted(),
            "C++ invline cache RW accepted while read response pending");
    dut.comb_inputs();
    table_driver.observe(dut);
    dut.seq();
    ++sim_time;
  }
  require(read_resp_seen, "C++ invline cache RW read response timeout");

  drive_refill(trace.write_refill, 0xd00d3200u, true);

  bool write_resp_seen = false;
  for (int cycle = 0; cycle < 260 && !write_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.comb_outputs();
    auto &resp = dut.write_ports[trace.write_master].resp;
    if (resp.valid) {
      write_resp_seen = true;
      trace.write.resp_id = static_cast<uint8_t>(resp.id);
      trace.write.resp_code = static_cast<uint8_t>(resp.resp);
      trace.blocked_while_write_resp_held =
          !dut.llc_invalidate_line_accepted();
    }
    require(!dut.llc_invalidate_line_accepted(),
            "C++ invline cache RW accepted while write response pending");
    dut.comb_inputs();
    table_driver.observe(dut);
    dut.seq();
    ++sim_time;
  }
  require(write_resp_seen, "C++ invline cache RW write response timeout");

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_line(true, trace.invalidate_addr);
  dut.read_ports[trace.read_master].resp.ready = true;
  dut.comb_outputs();
  require(dut.read_ports[trace.read_master].resp.valid &&
              dut.read_ports[trace.read_master].resp.id == trace.read.req_id,
          "C++ invline cache RW read response not valid at retire");
  require(!dut.llc_invalidate_line_accepted(),
          "C++ invline cache RW accepted before read response retire");
  dut.comb_inputs();
  table_driver.observe(dut);
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_line(true, trace.invalidate_addr);
  dut.write_ports[trace.write_master].resp.ready = true;
  dut.comb_outputs();
  require(dut.write_ports[trace.write_master].resp.valid &&
              dut.write_ports[trace.write_master].resp.id == trace.write.req_id,
          "C++ invline cache RW write response not valid at retire");
  require(!dut.llc_invalidate_line_accepted(),
          "C++ invline cache RW accepted before write response retire");
  dut.comb_inputs();
  table_driver.observe(dut);
  dut.seq();
  ++sim_time;

  for (int retry = 0; retry < 10000; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    const bool accepted_now = dut.llc_invalidate_line_accepted();
    dut.seq();
    ++sim_time;
    if (accepted_now) {
      trace.accepted_after_resp_retire = true;
      dut.set_llc_invalidate_line(false, 0);
      return trace;
    }
  }
  require(false, "C++ invline cache RW did not accept after responses retired");
  return trace;
}

InvalidateAllCacheReadWriteTrace
run_mode1_invalidate_all_cache_read_write_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  InvalidLlcTableDriver table_driver(dut.get_llc_config());

  InvalidateAllCacheReadWriteTrace trace{};
  trace.prefix = "CPP_MODE1_INVALL_CACHE_RW";
  trace.read_master = axi_interconnect::MASTER_DCACHE_R;
  trace.write_master = axi_interconnect::MASTER_DCACHE_W;
  trace.read.prefix = "CPP_MODE1_INVALL_CACHE_RW_READ";
  trace.read.req_addr = 0x40002004u;
  trace.read.req_size = 3;
  trace.read.req_id = 0x6u;
  trace.read.beat_count = 2;
  trace.write.prefix = "CPP_MODE1_INVALL_CACHE_RW_WRITE";
  trace.write.req_addr = 0x40002044u;
  trace.write.req_size = 3;
  trace.write.req_id = 0x7u;
  const auto write_data = single_word_data(0xacc02044u);
  const auto write_strobe = byte_strobe(0xfu);
  trace.write.req_wdata = wide_write_words(write_data);
  trace.write.req_wstrb = write_strobe_mask(write_strobe);
  trace.write_refill.prefix = "CPP_MODE1_INVALL_CACHE_RW_WRITE_REFILL";
  trace.write_refill.req_addr = trace.write.req_addr;
  trace.write_refill.req_size = 63;
  trace.write_refill.req_id = 0;
  trace.write_refill.beat_count = 2;
  trace.write_refill.resp_data.assign(
      axi_interconnect::MAX_READ_TRANSACTION_WORDS, 0);

  bool read_accepted = false;
  bool read_ar_seen = false;
  bool read_request_active = true;
  for (int cycle = 0; cycle < 240 && !read_ar_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    if (read_request_active) {
      auto &req = dut.read_ports[trace.read_master].req;
      req.valid = true;
      req.addr = trace.read.req_addr;
      req.total_size = trace.read.req_size;
      req.id = trace.read.req_id;
      req.bypass = false;
    }
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    if (read_request_active && dut.read_ports[trace.read_master].req.ready) {
      read_accepted = true;
      read_request_active = false;
    }
    if (dut.axi_ddr_io.ar.arvalid) {
      require(!dut.axi_mmio_io.ar.arvalid,
              "C++ invall cache RW read DDR AR overlapped with MMIO AR");
      trace.read.araddr = static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
      trace.read.arlen = static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
      trace.read.arsize = static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
      trace.read.arburst = static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
      trace.read.arid = static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
      read_ar_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(read_accepted, "C++ invall cache RW read was not accepted");
  require(read_ar_seen, "C++ invall cache RW read did not issue DDR AR");
  require(trace.read.beat_count == static_cast<uint32_t>(trace.read.arlen) + 1u,
          "C++ invall cache RW read beat count mismatch");

  bool write_accepted = false;
  bool write_ar_seen = false;
  bool write_request_active = true;
  for (int cycle = 0; cycle < 240 && !write_ar_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    const bool ready_snapshot = dut.write_ports[trace.write_master].req.ready;
    if (write_request_active) {
      auto &req = dut.write_ports[trace.write_master].req;
      req.valid = true;
      req.addr = trace.write.req_addr;
      req.total_size = trace.write.req_size;
      req.id = trace.write.req_id;
      req.wdata = write_data;
      req.wstrb = write_strobe;
      req.bypass = false;
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    if (write_request_active && ready_snapshot) {
      write_accepted = true;
      write_request_active = false;
    }
    if (dut.axi_ddr_io.ar.arvalid) {
      require(!dut.axi_mmio_io.ar.arvalid,
              "C++ invall cache RW write DDR AR overlapped with MMIO AR");
      trace.write_refill.araddr =
          static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
      trace.write_refill.arlen =
          static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
      trace.write_refill.arsize =
          static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
      trace.write_refill.arburst =
          static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
      trace.write_refill.arid =
          static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
      write_ar_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(write_accepted, "C++ invall cache RW write was not accepted");
  require(write_ar_seen, "C++ invall cache RW write did not issue DDR AR");
  require(trace.write_refill.beat_count ==
              static_cast<uint32_t>(trace.write_refill.arlen) + 1u,
          "C++ invall cache RW write beat count mismatch");
  require(trace.read.arid != trace.write_refill.arid,
          "C++ invall cache RW reused a downstream refill ARID");

  auto drive_refill = [&](ReadTrace &refill_trace, uint32_t seed,
                          bool write_while_read_held) {
    for (uint32_t beat = 0; beat < refill_trace.beat_count; ++beat) {
      clear_inputs(dut);
      set_downstream_ready(dut);
      table_driver.drive(dut);
      dut.set_llc_invalidate_all(true);
      dut.axi_ddr_io.r.rvalid = true;
      dut.axi_ddr_io.r.rid = refill_trace.arid;
      dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
      dut.axi_ddr_io.r.rlast = beat == refill_trace.beat_count - 1u;
      dut.axi_ddr_io.r.rdata = ddr_read_beat(seed + beat * 0x100u);
      refill_trace.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
      dut.comb_outputs();
      if (write_while_read_held) {
        trace.write_rready_while_read_resp_held =
            trace.write_rready_while_read_resp_held &&
            dut.axi_ddr_io.r.rready;
        require(dut.read_ports[trace.read_master].resp.valid &&
                    dut.read_ports[trace.read_master].resp.id ==
                        trace.read.req_id,
                "C++ invall cache RW read response not held during write R");
      } else {
        trace.read_rready_while_invalidate_pending =
            trace.read_rready_while_invalidate_pending &&
            dut.axi_ddr_io.r.rready;
      }
      require(dut.axi_ddr_io.r.rready,
              "C++ invall cache RW DDR R was backpressured");
      require(!dut.llc_invalidate_all_accepted(),
              "C++ invall cache RW accepted during DDR R");
      dut.comb_inputs();
      table_driver.observe(dut);
      dut.seq();
      ++sim_time;
    }
  };

  trace.read_rready_while_invalidate_pending = true;
  trace.write_rready_while_read_resp_held = true;
  drive_refill(trace.read, 0xd00d3800u, false);

  bool read_resp_seen = false;
  for (int cycle = 0; cycle < 260 && !read_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    auto &resp = dut.read_ports[trace.read_master].resp;
    if (resp.valid) {
      read_resp_seen = true;
      trace.read.resp_id = static_cast<uint8_t>(resp.id);
      trace.read.resp_data = wide_read_words(resp.data);
      trace.blocked_while_read_resp_held =
          !dut.llc_invalidate_all_accepted();
    }
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall cache RW accepted while read response pending");
    dut.comb_inputs();
    table_driver.observe(dut);
    dut.seq();
    ++sim_time;
  }
  require(read_resp_seen, "C++ invall cache RW read response timeout");

  drive_refill(trace.write_refill, 0xd00d3a00u, true);

  bool write_resp_seen = false;
  for (int cycle = 0; cycle < 260 && !write_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    auto &resp = dut.write_ports[trace.write_master].resp;
    if (resp.valid) {
      write_resp_seen = true;
      trace.write.resp_id = static_cast<uint8_t>(resp.id);
      trace.write.resp_code = static_cast<uint8_t>(resp.resp);
      trace.blocked_while_write_resp_held =
          !dut.llc_invalidate_all_accepted();
    }
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall cache RW accepted while write response pending");
    dut.comb_inputs();
    table_driver.observe(dut);
    dut.seq();
    ++sim_time;
  }
  require(write_resp_seen, "C++ invall cache RW write response timeout");

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.read_ports[trace.read_master].resp.ready = true;
  dut.comb_outputs();
  require(dut.read_ports[trace.read_master].resp.valid &&
              dut.read_ports[trace.read_master].resp.id == trace.read.req_id,
          "C++ invall cache RW read response not valid at retire");
  require(!dut.llc_invalidate_all_accepted(),
          "C++ invall cache RW accepted before read response retire");
  dut.comb_inputs();
  table_driver.observe(dut);
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.write_ports[trace.write_master].resp.ready = true;
  dut.comb_outputs();
  require(dut.write_ports[trace.write_master].resp.valid &&
              dut.write_ports[trace.write_master].resp.id == trace.write.req_id,
          "C++ invall cache RW write response not valid at retire");
  require(!dut.llc_invalidate_all_accepted(),
          "C++ invall cache RW accepted before write response retire");
  dut.comb_inputs();
  table_driver.observe(dut);
  dut.seq();
  ++sim_time;

  for (int retry = 0; retry < 64; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall cache RW accepted with dirty resident line");
    dut.seq();
    ++sim_time;
  }
  trace.accepted_after_resp_retire = false;
  dut.set_llc_invalidate_all(false);
  return trace;
}

InvalidateLineCacheMmioReadTrace
run_mode1_invalidate_line_cache_mmio_read_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  InvalidLlcTableDriver table_driver(dut.get_llc_config());

  InvalidateLineCacheMmioReadTrace trace{};
  trace.prefix = "CPP_MODE1_INVLINE_CACHE_MMIO_READ";
  trace.overlap.ddr.prefix = "CPP_MODE1_INVLINE_CACHE_MMIO_DDR";
  trace.overlap.ddr.req_addr = 0x40000e04u;
  trace.overlap.ddr.req_size = 3;
  trace.overlap.ddr.req_id = 0xCu;
  trace.overlap.ddr.beat_count = 2;
  trace.overlap.mmio.prefix = "CPP_MODE1_INVLINE_CACHE_MMIO_MMIO";
  trace.overlap.mmio.req_addr = 0x100000e8u;
  trace.overlap.mmio.req_size = 3;
  trace.overlap.mmio.req_id = 0xDu;
  trace.overlap.mmio.beat_count = 1;
  trace.overlap.ddr_master = axi_interconnect::MASTER_DCACHE_R;
  trace.overlap.mmio_master = axi_interconnect::MASTER_UNCORE_LSU_R;
  trace.invalidate_addr = trace.overlap.ddr.req_addr;

  bool accepted = false;
  bool ar_seen = false;
  bool request_active = true;
  for (int cycle = 0; cycle < 80 && !ar_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    if (request_active) {
      auto &req = dut.read_ports[trace.overlap.ddr_master].req;
      req.valid = true;
      req.addr = trace.overlap.ddr.req_addr;
      req.total_size = trace.overlap.ddr.req_size;
      req.id = trace.overlap.ddr.req_id;
      req.bypass = false;
    }
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    if (request_active && dut.read_ports[trace.overlap.ddr_master].req.ready) {
      accepted = true;
      request_active = false;
    }
    if (dut.axi_ddr_io.ar.arvalid) {
      require(!dut.axi_mmio_io.ar.arvalid,
              "C++ invline cache/MMIO read DDR AR overlapped with MMIO AR");
      trace.overlap.ddr.araddr =
          static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
      trace.overlap.ddr.arlen = static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
      trace.overlap.ddr.arsize =
          static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
      trace.overlap.ddr.arburst =
          static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
      trace.overlap.ddr.arid = static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
      ar_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ invline cache/MMIO cache read was not accepted");
  require(ar_seen, "C++ invline cache/MMIO cache read did not issue DDR AR");
  require(trace.overlap.ddr.beat_count ==
              static_cast<uint32_t>(trace.overlap.ddr.arlen) + 1u,
          "C++ invline cache/MMIO cache read beat count mismatch");

  issue_read_and_capture_ar(dut, trace.overlap.mmio, trace.overlap.mmio_master,
                            axi_interconnect::DownstreamPort::MMIO);

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_line(true, trace.invalidate_addr);
  dut.axi_mmio_io.r.rvalid = true;
  dut.axi_mmio_io.r.rid = trace.overlap.mmio.arid;
  dut.axi_mmio_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_mmio_io.r.rlast = true;
  dut.axi_mmio_io.r.rdata = {};
  axi_compat::set_u32(dut.axi_mmio_io.r.rdata, 0, 0xcafe00e8u);
  trace.overlap.mmio.rbeats[0] = axi_words(dut.axi_mmio_io.r.rdata);
  dut.comb_outputs();
  trace.mmio_rready_while_invalidate_pending = dut.axi_mmio_io.r.rready;
  require(dut.axi_mmio_io.r.rready,
          "C++ invline cache/MMIO MMIO R was backpressured");
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_line_accepted(),
          "C++ invline cache/MMIO accepted in MMIO R handshake cycle");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_line(true, trace.invalidate_addr);
  dut.comb_outputs();
  require(dut.read_ports[trace.overlap.mmio_master].resp.valid,
          "C++ invline cache/MMIO MMIO response was not held");
  trace.blocked_while_mmio_resp_held = !dut.llc_invalidate_line_accepted();
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_line_accepted(),
          "C++ invline cache/MMIO accepted while target read pending");
  dut.seq();
  ++sim_time;

  trace.ddr_rready_while_mmio_resp_held = true;
  for (uint32_t beat = 0; beat < trace.overlap.ddr.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = trace.overlap.ddr.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == trace.overlap.ddr.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(0xd00d0e00u + beat * 0x100u);
    trace.overlap.ddr.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    trace.ddr_rready_while_mmio_resp_held =
        trace.ddr_rready_while_mmio_resp_held && dut.axi_ddr_io.r.rready;
    require(dut.axi_ddr_io.r.rready,
            "C++ invline cache/MMIO DDR R was backpressured");
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_line_accepted(),
            "C++ invline cache/MMIO accepted in DDR R handshake cycle");
    dut.seq();
    ++sim_time;
  }

  bool cache_resp_seen = false;
  for (int cycle = 0; cycle < 160 && !cache_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.comb_outputs();
    require(dut.read_ports[trace.overlap.mmio_master].resp.valid,
            "C++ invline cache/MMIO MMIO response dropped while held");
    auto &cache_resp = dut.read_ports[trace.overlap.ddr_master].resp;
    if (cache_resp.valid) {
      cache_resp_seen = true;
      trace.overlap.ddr.resp_id = static_cast<uint8_t>(cache_resp.id);
      trace.overlap.ddr.resp_data = wide_read_words(cache_resp.data);
      trace.blocked_while_cache_resp_held = !dut.llc_invalidate_line_accepted();
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_line_accepted(),
            "C++ invline cache/MMIO accepted while cache response pending");
    dut.seq();
    ++sim_time;
  }
  require(cache_resp_seen, "C++ invline cache/MMIO cache response timeout");

  bool mmio_retired = false;
  for (int cycle = 0; cycle < 8 && !mmio_retired; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.read_ports[trace.overlap.mmio_master].resp.ready = true;
    dut.comb_outputs();
    auto &mmio_resp = dut.read_ports[trace.overlap.mmio_master].resp;
    if (!mmio_resp.valid) {
      mmio_retired = true;
      break;
    }
    trace.overlap.mmio.resp_id = static_cast<uint8_t>(mmio_resp.id);
    trace.overlap.mmio.resp_data = wide_read_words(mmio_resp.data);
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_line_accepted(),
            "C++ invline cache/MMIO accepted before MMIO response retired");
    dut.seq();
    ++sim_time;
  }
  require(mmio_retired, "C++ invline cache/MMIO MMIO response did not retire");

  bool cache_retired = false;
  for (int cycle = 0; cycle < 8 && !cache_retired; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.read_ports[trace.overlap.ddr_master].resp.ready = true;
    dut.comb_outputs();
    if (!dut.read_ports[trace.overlap.ddr_master].resp.valid) {
      cache_retired = true;
      break;
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_line_accepted(),
            "C++ invline cache/MMIO accepted before cache response retired");
    dut.seq();
    ++sim_time;
  }
  require(cache_retired, "C++ invline cache/MMIO cache response did not retire");

  for (int retry = 0; retry < 160; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    const bool accepted_now = dut.llc_invalidate_line_accepted();
    dut.seq();
    ++sim_time;
    if (accepted_now) {
      trace.accepted_after_resp_retire = true;
      dut.set_llc_invalidate_line(false, 0);
      return trace;
    }
  }
  dut.debug_print();
  require(false,
          "C++ invline cache/MMIO did not accept after responses retired");
  return trace;
}

SameLineReadPendingWriteTrace
run_mode1_same_line_read_pending_write_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  InvalidLlcTableDriver table_driver(dut.get_llc_config());

  SameLineReadPendingWriteTrace trace{};
  trace.read.prefix = "CPP_MODE1_SAME_LINE_READ_PENDING_READ";
  trace.read.req_addr = 0x40000b04u;
  trace.read.req_size = 3;
  trace.read.req_id = 0x6u;
  trace.read.beat_count = 2;
  trace.write.prefix = "CPP_MODE1_SAME_LINE_READ_PENDING_WRITE";
  trace.write.req_addr = 0x40000b08u;
  trace.write.req_size = 3;
  trace.write.req_id = 0x7u;
  const auto write_data = single_word_data(0xface0b08u);
  const auto write_strobe = byte_strobe(0xfu);
  trace.write.req_wdata = wide_write_words(write_data);
  trace.write.req_wstrb = write_strobe_mask(write_strobe);
  trace.read_master = axi_interconnect::MASTER_DCACHE_R;
  trace.write_master = axi_interconnect::MASTER_DCACHE_W;

  bool accepted = false;
  bool ar_seen = false;
  bool request_active = true;
  for (int cycle = 0; cycle < 100 && !ar_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    if (request_active) {
      auto &req = dut.read_ports[trace.read_master].req;
      req.valid = true;
      req.addr = trace.read.req_addr;
      req.total_size = trace.read.req_size;
      req.id = trace.read.req_id;
      req.bypass = false;
    }
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    if (request_active && dut.read_ports[trace.read_master].req.ready) {
      accepted = true;
      request_active = false;
    }
    if (dut.axi_ddr_io.ar.arvalid) {
      require(!dut.axi_mmio_io.ar.arvalid,
              "C++ same-line read pending trace escaped read to MMIO");
      trace.read.araddr = static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
      trace.read.arlen = static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
      trace.read.arsize = static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
      trace.read.arburst = static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
      trace.read.arid = static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
      ar_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ same-line read pending read was not accepted");
  require(ar_seen, "C++ same-line read pending read did not issue DDR AR");
  require(trace.read.beat_count == static_cast<uint32_t>(trace.read.arlen) + 1u,
          "C++ same-line read pending read beat count mismatch");

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  auto &write_req = dut.write_ports[trace.write_master].req;
  write_req.valid = true;
  write_req.addr = trace.write.req_addr;
  write_req.total_size = trace.write.req_size;
  write_req.id = trace.write.req_id;
  write_req.wdata = write_data;
  write_req.wstrb = write_strobe;
  write_req.bypass = false;
  dut.comb_outputs();
  dut.comb_inputs();
  table_driver.observe(dut);
  trace.write.req_ready = dut.write_ports[trace.write_master].req.ready;
  trace.write_accepted_while_read_pending =
      dut.write_ports[trace.write_master].req.accepted;
  trace.no_external_issue_while_read_pending =
      !dut.axi_ddr_io.aw.awvalid && !dut.axi_ddr_io.w.wvalid &&
      !dut.axi_ddr_io.ar.arvalid && !dut.axi_mmio_io.aw.awvalid &&
      !dut.axi_mmio_io.w.wvalid && !dut.axi_mmio_io.ar.arvalid;
  require(trace.no_external_issue_while_read_pending,
          "C++ same-line write escaped externally while read pending");
  dut.seq();
  ++sim_time;

  return trace;
}

SameLineWritePendingReadTrace
run_mode0_same_line_write_pending_read_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);

  SameLineWritePendingReadTrace trace{};
  trace.write.prefix = "CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE";
  trace.write.req_addr = 0x40000c00u;
  trace.write.req_size = 3;
  trace.write.req_id = 0x8u;
  const auto write_data = single_word_data(0xface0c00u);
  const auto write_strobe = byte_strobe(0xfu);
  trace.write.req_wdata = wide_write_words(write_data);
  trace.write.req_wstrb = write_strobe_mask(write_strobe);
  trace.write_master = axi_interconnect::MASTER_DCACHE_W;
  trace.read.prefix = "CPP_MODE0_SAME_LINE_WRITE_PENDING_READ";
  trace.read.req_addr = 0x40000c08u;
  trace.read.req_size = 3;
  trace.read.req_id = 0x9u;
  trace.read_master = axi_interconnect::MASTER_DCACHE_R;

  issue_write_and_capture_axi(dut, trace.write, trace.write_master,
                              axi_interconnect::DownstreamPort::DDR,
                              write_data, write_strobe);

  clear_inputs(dut);
  set_downstream_ready(dut);
  auto &read_req = dut.read_ports[trace.read_master].req;
  read_req.valid = true;
  read_req.addr = trace.read.req_addr;
  read_req.total_size = trace.read.req_size;
  read_req.id = trace.read.req_id;
  read_req.bypass = false;
  dut.comb_outputs();
  dut.comb_inputs();
  trace.read.req_ready = dut.read_ports[trace.read_master].req.ready;
  trace.read_accepted_while_write_pending =
      dut.read_ports[trace.read_master].req.accepted;
  trace.no_external_issue_while_write_pending =
      !dut.axi_ddr_io.ar.arvalid && !dut.axi_ddr_io.aw.awvalid &&
      !dut.axi_ddr_io.w.wvalid && !dut.axi_mmio_io.ar.arvalid &&
      !dut.axi_mmio_io.aw.awvalid && !dut.axi_mmio_io.w.wvalid;
  require(!trace.read.req_ready,
          "C++ same-line read was ready while write B was pending");
  require(!trace.read_accepted_while_write_pending,
          "C++ same-line read was accepted while write B was pending");
  require(trace.no_external_issue_while_write_pending,
          "C++ same-line read escaped externally while write B was pending");
  dut.seq();
  ++sim_time;

  return trace;
}

SameLineReadPendingWriteTrace
run_mode1_same_line_mmio_read_pending_write_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);

  SameLineReadPendingWriteTrace trace{};
  trace.read.prefix = "CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_READ";
  trace.read.req_addr = 0x10000140u;
  trace.read.req_size = 3;
  trace.read.req_id = 0x5u;
  trace.read.beat_count = 1;
  trace.write.prefix = "CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_WRITE";
  trace.write.req_addr = 0x10000144u;
  trace.write.req_size = 3;
  trace.write.req_id = 0xAu;
  const auto write_data = single_word_data(0xface0144u);
  const auto write_strobe = byte_strobe(0xfu);
  trace.write.req_wdata = wide_write_words(write_data);
  trace.write.req_wstrb = write_strobe_mask(write_strobe);
  trace.read_master = axi_interconnect::MASTER_DCACHE_R;
  trace.write_master = axi_interconnect::MASTER_DCACHE_W;

  bool accepted = false;
  bool ar_seen = false;
  bool request_active = true;
  for (int cycle = 0; cycle < 32 && !ar_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    if (request_active) {
      auto &req = dut.read_ports[trace.read_master].req;
      req.valid = true;
      req.addr = trace.read.req_addr;
      req.total_size = trace.read.req_size;
      req.id = trace.read.req_id;
      req.bypass = false;
    }
    dut.comb_outputs();
    dut.comb_inputs();
    if (request_active && dut.read_ports[trace.read_master].req.ready) {
      accepted = true;
      request_active = false;
    }
    if (dut.axi_mmio_io.ar.arvalid) {
      require(!dut.axi_ddr_io.ar.arvalid,
              "C++ same-line MMIO read pending escaped read to DDR");
      trace.read.araddr = static_cast<uint32_t>(dut.axi_mmio_io.ar.araddr);
      trace.read.arlen = static_cast<uint8_t>(dut.axi_mmio_io.ar.arlen);
      trace.read.arsize = static_cast<uint8_t>(dut.axi_mmio_io.ar.arsize);
      trace.read.arburst = static_cast<uint8_t>(dut.axi_mmio_io.ar.arburst);
      trace.read.arid = static_cast<uint8_t>(dut.axi_mmio_io.ar.arid);
      ar_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ same-line MMIO pending read was not accepted");
  require(ar_seen, "C++ same-line MMIO pending read did not issue MMIO AR");
  require(trace.read.beat_count == static_cast<uint32_t>(trace.read.arlen) + 1u,
          "C++ same-line MMIO pending read beat count mismatch");

  clear_inputs(dut);
  set_downstream_ready(dut);
  auto &write_req = dut.write_ports[trace.write_master].req;
  write_req.valid = true;
  write_req.addr = trace.write.req_addr;
  write_req.total_size = trace.write.req_size;
  write_req.id = trace.write.req_id;
  write_req.wdata = write_data;
  write_req.wstrb = write_strobe;
  write_req.bypass = false;
  dut.comb_outputs();
  dut.comb_inputs();
  trace.write.req_ready = dut.write_ports[trace.write_master].req.ready;
  trace.write_accepted_while_read_pending =
      dut.write_ports[trace.write_master].req.accepted;
  trace.no_external_issue_while_read_pending =
      !dut.axi_ddr_io.aw.awvalid && !dut.axi_ddr_io.w.wvalid &&
      !dut.axi_ddr_io.ar.arvalid && !dut.axi_mmio_io.aw.awvalid &&
      !dut.axi_mmio_io.w.wvalid && !dut.axi_mmio_io.ar.arvalid;
  require(trace.no_external_issue_while_read_pending,
          "C++ same-line MMIO write escaped externally while read R was pending");
  dut.seq();
  ++sim_time;

  for (int cycle = 0; cycle < 4; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    if (!trace.write_accepted_while_read_pending) {
      auto &held_write_req = dut.write_ports[trace.write_master].req;
      held_write_req.valid = true;
      held_write_req.addr = trace.write.req_addr;
      held_write_req.total_size = trace.write.req_size;
      held_write_req.id = trace.write.req_id;
      held_write_req.wdata = write_data;
      held_write_req.wstrb = write_strobe;
      held_write_req.bypass = false;
    }
    dut.comb_outputs();
    dut.comb_inputs();
    trace.write_accepted_while_read_pending =
        trace.write_accepted_while_read_pending ||
        dut.write_ports[trace.write_master].req.accepted;
    const bool no_external_issue =
        !dut.axi_ddr_io.aw.awvalid && !dut.axi_ddr_io.w.wvalid &&
        !dut.axi_ddr_io.ar.arvalid && !dut.axi_mmio_io.aw.awvalid &&
        !dut.axi_mmio_io.w.wvalid && !dut.axi_mmio_io.ar.arvalid;
    trace.no_external_issue_while_read_pending =
        trace.no_external_issue_while_read_pending && no_external_issue;
    require(no_external_issue,
            "C++ same-line MMIO pending write issued externally before R");
    dut.seq();
    ++sim_time;
  }

  return trace;
}

SameLineWritePendingReadTrace
run_mode1_same_line_mmio_write_pending_read_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);

  SameLineWritePendingReadTrace trace{};
  trace.write.prefix = "CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE";
  trace.write.req_addr = 0x10000180u;
  trace.write.req_size = 3;
  trace.write.req_id = 0xBu;
  const auto write_data = single_word_data(0xface0180u);
  const auto write_strobe = byte_strobe(0xfu);
  trace.write.req_wdata = wide_write_words(write_data);
  trace.write.req_wstrb = write_strobe_mask(write_strobe);
  trace.write_master = axi_interconnect::MASTER_DCACHE_W;
  trace.read.prefix = "CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_READ";
  trace.read.req_addr = 0x10000184u;
  trace.read.req_size = 3;
  trace.read.req_id = 0xCu;
  trace.read_master = axi_interconnect::MASTER_DCACHE_R;

  issue_write_and_capture_axi(dut, trace.write, trace.write_master,
                              axi_interconnect::DownstreamPort::MMIO,
                              write_data, write_strobe);

  clear_inputs(dut);
  set_downstream_ready(dut);
  auto &read_req = dut.read_ports[trace.read_master].req;
  read_req.valid = true;
  read_req.addr = trace.read.req_addr;
  read_req.total_size = trace.read.req_size;
  read_req.id = trace.read.req_id;
  read_req.bypass = false;
  dut.comb_outputs();
  dut.comb_inputs();
  trace.read.req_ready = dut.read_ports[trace.read_master].req.ready;
  trace.read_accepted_while_write_pending =
      dut.read_ports[trace.read_master].req.accepted;
  trace.no_external_issue_while_write_pending =
      !dut.axi_ddr_io.ar.arvalid && !dut.axi_ddr_io.aw.awvalid &&
      !dut.axi_ddr_io.w.wvalid && !dut.axi_mmio_io.ar.arvalid &&
      !dut.axi_mmio_io.aw.awvalid && !dut.axi_mmio_io.w.wvalid;
  require(trace.no_external_issue_while_write_pending,
          "C++ same-line MMIO read escaped externally while write B was pending");
  dut.seq();
  ++sim_time;

  for (int cycle = 0; cycle < 4; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    if (!trace.read_accepted_while_write_pending) {
      auto &held_read_req = dut.read_ports[trace.read_master].req;
      held_read_req.valid = true;
      held_read_req.addr = trace.read.req_addr;
      held_read_req.total_size = trace.read.req_size;
      held_read_req.id = trace.read.req_id;
      held_read_req.bypass = false;
    }
    dut.comb_outputs();
    dut.comb_inputs();
    trace.read_accepted_while_write_pending =
        trace.read_accepted_while_write_pending ||
        dut.read_ports[trace.read_master].req.accepted;
    const bool no_external_issue =
        !dut.axi_ddr_io.ar.arvalid && !dut.axi_ddr_io.aw.awvalid &&
        !dut.axi_ddr_io.w.wvalid && !dut.axi_mmio_io.ar.arvalid &&
        !dut.axi_mmio_io.aw.awvalid && !dut.axi_mmio_io.w.wvalid;
    trace.no_external_issue_while_write_pending =
        trace.no_external_issue_while_write_pending && no_external_issue;
    require(no_external_issue,
            "C++ same-line MMIO pending read issued externally before B");
    dut.seq();
    ++sim_time;
  }

  return trace;
}

InvalidateAllCacheMmioReadTrace
run_mode1_invalidate_all_cache_mmio_read_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  InvalidLlcTableDriver table_driver(dut.get_llc_config());

  InvalidateAllCacheMmioReadTrace trace{};
  trace.prefix = "CPP_MODE1_INVALL_CACHE_MMIO_READ";
  trace.overlap.ddr.prefix = "CPP_MODE1_INVALL_CACHE_MMIO_DDR";
  trace.overlap.ddr.req_addr = 0x40000b04u;
  trace.overlap.ddr.req_size = 3;
  trace.overlap.ddr.req_id = 0x6u;
  trace.overlap.ddr.beat_count = 2;
  trace.overlap.mmio.prefix = "CPP_MODE1_INVALL_CACHE_MMIO_MMIO";
  trace.overlap.mmio.req_addr = 0x100000b8u;
  trace.overlap.mmio.req_size = 3;
  trace.overlap.mmio.req_id = 0x7u;
  trace.overlap.mmio.beat_count = 1;
  trace.overlap.ddr_master = axi_interconnect::MASTER_DCACHE_R;
  trace.overlap.mmio_master = axi_interconnect::MASTER_UNCORE_LSU_R;

  bool accepted = false;
  bool ar_seen = false;
  bool request_active = true;
  for (int cycle = 0; cycle < 80 && !ar_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    if (request_active) {
      auto &req = dut.read_ports[trace.overlap.ddr_master].req;
      req.valid = true;
      req.addr = trace.overlap.ddr.req_addr;
      req.total_size = trace.overlap.ddr.req_size;
      req.id = trace.overlap.ddr.req_id;
      req.bypass = false;
    }
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    if (request_active && dut.read_ports[trace.overlap.ddr_master].req.ready) {
      accepted = true;
      request_active = false;
    }
    if (dut.axi_ddr_io.ar.arvalid) {
      require(!dut.axi_mmio_io.ar.arvalid,
              "C++ invall cache/MMIO read DDR AR overlapped with MMIO AR");
      trace.overlap.ddr.araddr =
          static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
      trace.overlap.ddr.arlen = static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
      trace.overlap.ddr.arsize =
          static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
      trace.overlap.ddr.arburst =
          static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
      trace.overlap.ddr.arid = static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
      ar_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ invall cache/MMIO cache read was not accepted");
  require(ar_seen, "C++ invall cache/MMIO cache read did not issue DDR AR");
  require(trace.overlap.ddr.beat_count ==
              static_cast<uint32_t>(trace.overlap.ddr.arlen) + 1u,
          "C++ invall cache/MMIO cache read beat count mismatch");

  issue_read_and_capture_ar(dut, trace.overlap.mmio, trace.overlap.mmio_master,
                            axi_interconnect::DownstreamPort::MMIO);

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.axi_mmio_io.r.rvalid = true;
  dut.axi_mmio_io.r.rid = trace.overlap.mmio.arid;
  dut.axi_mmio_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_mmio_io.r.rlast = true;
  dut.axi_mmio_io.r.rdata = {};
  axi_compat::set_u32(dut.axi_mmio_io.r.rdata, 0, 0xcafe00b8u);
  trace.overlap.mmio.rbeats[0] = axi_words(dut.axi_mmio_io.r.rdata);
  dut.comb_outputs();
  trace.mmio_rready_while_invalidate_pending = dut.axi_mmio_io.r.rready;
  require(dut.axi_mmio_io.r.rready,
          "C++ invall cache/MMIO MMIO R was backpressured");
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ invall cache/MMIO accepted in MMIO R handshake cycle");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.comb_outputs();
  require(dut.read_ports[trace.overlap.mmio_master].resp.valid,
          "C++ invall cache/MMIO MMIO response was not held");
  trace.blocked_while_mmio_resp_held = !dut.llc_invalidate_all_accepted();
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ invall cache/MMIO accepted while MMIO response held");
  dut.seq();
  ++sim_time;

  trace.ddr_rready_while_mmio_resp_held = true;
  for (uint32_t beat = 0; beat < trace.overlap.ddr.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = trace.overlap.ddr.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == trace.overlap.ddr.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(0xd00d0b00u + beat * 0x100u);
    trace.overlap.ddr.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    trace.ddr_rready_while_mmio_resp_held =
        trace.ddr_rready_while_mmio_resp_held && dut.axi_ddr_io.r.rready;
    require(dut.axi_ddr_io.r.rready,
            "C++ invall cache/MMIO DDR R was backpressured");
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall cache/MMIO accepted in DDR R handshake cycle");
    dut.seq();
    ++sim_time;
  }

  bool cache_resp_seen = false;
  for (int cycle = 0; cycle < 160 && !cache_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    require(dut.read_ports[trace.overlap.mmio_master].resp.valid,
            "C++ invall cache/MMIO MMIO response dropped while held");
    auto &cache_resp = dut.read_ports[trace.overlap.ddr_master].resp;
    if (cache_resp.valid) {
      cache_resp_seen = true;
      trace.overlap.ddr.resp_id = static_cast<uint8_t>(cache_resp.id);
      trace.overlap.ddr.resp_data = wide_read_words(cache_resp.data);
      trace.blocked_while_cache_resp_held = !dut.llc_invalidate_all_accepted();
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall cache/MMIO accepted while cache response pending");
    dut.seq();
    ++sim_time;
  }
  require(cache_resp_seen,
          "C++ invall cache/MMIO cache response timeout");

  bool mmio_retired = false;
  for (int cycle = 0; cycle < 8 && !mmio_retired; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.read_ports[trace.overlap.mmio_master].resp.ready = true;
    dut.comb_outputs();
    auto &mmio_resp = dut.read_ports[trace.overlap.mmio_master].resp;
    if (!mmio_resp.valid) {
      mmio_retired = true;
      break;
    }
    trace.overlap.mmio.resp_id = static_cast<uint8_t>(mmio_resp.id);
    trace.overlap.mmio.resp_data = wide_read_words(mmio_resp.data);
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall cache/MMIO accepted before MMIO response retired");
    dut.seq();
    ++sim_time;
  }
  require(mmio_retired, "C++ invall cache/MMIO MMIO response did not retire");

  bool cache_retired = false;
  for (int cycle = 0; cycle < 8 && !cache_retired; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.read_ports[trace.overlap.ddr_master].resp.ready = true;
    dut.comb_outputs();
    if (!dut.read_ports[trace.overlap.ddr_master].resp.valid) {
      cache_retired = true;
      break;
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall cache/MMIO accepted before cache response retired");
    dut.seq();
    ++sim_time;
  }
  require(cache_retired, "C++ invall cache/MMIO cache response did not retire");

  for (int retry = 0; retry < 160; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    const bool accepted_now = dut.llc_invalidate_all_accepted();
    dut.seq();
    ++sim_time;
    if (accepted_now) {
      trace.accepted_after_resp_retire = true;
      dut.set_llc_invalidate_all(false);
      return trace;
    }
  }
  dut.debug_print();
  require(false,
          "C++ invall cache/MMIO did not accept after responses retired");
  return trace;
}

CacheWriteMissMmioWriteTrace run_mode1_cache_write_miss_mmio_write_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  InvalidLlcTableDriver table_driver(dut.get_llc_config());

  CacheWriteMissMmioWriteTrace trace{};
  trace.cache.prefix = "CPP_MODE1_CACHE_WRITE_MISS";
  trace.cache.req_addr = 0x40000804u;
  trace.cache.req_size = 3;
  trace.cache.req_id = 0x3u;
  const auto cache_data = single_word_data(0x13572468u);
  const auto cache_strobe = byte_strobe(0xfu);
  trace.cache.req_wdata = wide_write_words(cache_data);
  trace.cache.req_wstrb = write_strobe_mask(cache_strobe);
  trace.refill.prefix = "CPP_MODE1_CACHE_WRITE_MISS_REFILL";
  trace.refill.req_addr = trace.cache.req_addr;
  trace.refill.req_size = 63;
  trace.refill.req_id = 0;
  trace.refill.beat_count = 2;
  trace.refill.resp_data.assign(axi_interconnect::MAX_READ_TRANSACTION_WORDS, 0);
  trace.mmio.prefix = "CPP_MODE1_CACHE_WRITE_MISS_MMIO";
  trace.mmio.req_addr = 0x1000009cu;
  trace.mmio.req_size = 3;
  trace.mmio.req_id = 0x4u;
  const auto mmio_data = single_word_data(0xface009cu);
  const auto mmio_strobe = byte_strobe(0xfu);
  trace.mmio.req_wdata = wide_write_words(mmio_data);
  trace.mmio.req_wstrb = write_strobe_mask(mmio_strobe);
  trace.cache_master = axi_interconnect::MASTER_DCACHE_W;
  trace.mmio_master = axi_interconnect::MASTER_UNCORE_LSU_W;

  bool accepted = false;
  bool ar_seen = false;
  bool request_active = true;
  for (int cycle = 0; cycle < 120 && !ar_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    const bool ready_snapshot = dut.write_ports[trace.cache_master].req.ready;
    if (request_active) {
      auto &req = dut.write_ports[trace.cache_master].req;
      req.valid = true;
      req.addr = trace.cache.req_addr;
      req.total_size = trace.cache.req_size;
      req.id = trace.cache.req_id;
      req.wdata = cache_data;
      req.wstrb = cache_strobe;
      req.bypass = false;
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    if (request_active && ready_snapshot) {
      accepted = true;
      request_active = false;
    }
    if (dut.axi_ddr_io.ar.arvalid) {
      require(!dut.axi_mmio_io.ar.arvalid,
              "C++ mode1 cache write miss DDR AR overlapped with MMIO AR");
      trace.refill.araddr = static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
      trace.refill.arlen = static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
      trace.refill.arsize = static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
      trace.refill.arburst = static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
      trace.refill.arid = static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
      ar_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ mode1 cache write miss was not accepted");
  require(ar_seen, "C++ mode1 cache write miss did not issue DDR refill AR");
  require(trace.refill.beat_count ==
              static_cast<uint32_t>(trace.refill.arlen) + 1u,
          "C++ mode1 cache write miss refill beat count mismatch");

  issue_write_and_capture_axi(dut, trace.mmio, trace.mmio_master,
                              axi_interconnect::DownstreamPort::MMIO,
                              mmio_data, mmio_strobe);

  idle_request_outputs(dut);
  dut.axi_mmio_io.b.bvalid = true;
  dut.axi_mmio_io.b.bid = trace.mmio.awid;
  dut.axi_mmio_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  trace.mmio_bready_while_resp_stalled = dut.axi_mmio_io.b.bready;
  require(trace.mmio_bready_while_resp_stalled,
          "C++ mode1 cache write miss/MMIO B was backpressured");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  table_driver.drive(dut);
  dut.comb_outputs();
  dut.comb_inputs();
  table_driver.observe(dut);
  require(dut.write_ports[trace.mmio_master].resp.valid,
          "C++ mode1 cache write miss/MMIO response was not held");
  require(!dut.write_ports[trace.cache_master].resp.valid,
          "C++ mode1 cache write miss response appeared before refill");
  dut.seq();
  ++sim_time;

  trace.ddr_rready_while_resp_stalled = true;
  for (uint32_t beat = 0; beat < trace.refill.beat_count; ++beat) {
    idle_request_outputs(dut);
    table_driver.drive(dut);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = trace.refill.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == trace.refill.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(0xd00d0800u + beat * 0x100u);
    trace.refill.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    trace.ddr_rready_while_resp_stalled =
        trace.ddr_rready_while_resp_stalled && dut.axi_ddr_io.r.rready;
    require(dut.axi_ddr_io.r.rready,
            "C++ mode1 cache write miss DDR R was backpressured");
    dut.seq();
    ++sim_time;
  }

  capture_write_response(dut, trace.mmio, trace.mmio_master);

  bool cache_resp_seen = false;
  for (int cycle = 0; cycle < 180 && !cache_resp_seen; ++cycle) {
    clear_inputs(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    auto &resp = dut.write_ports[trace.cache_master].resp;
    if (resp.valid) {
      cache_resp_seen = true;
      trace.cache.resp_id = static_cast<uint8_t>(resp.id);
      trace.cache.resp_code = static_cast<uint8_t>(resp.resp);
      resp.ready = true;
      dut.comb_outputs();
      require(resp.valid,
              "C++ mode1 cache write miss response dropped before ready");
    }
    dut.seq();
    ++sim_time;
  }
  require(cache_resp_seen,
          "C++ mode1 cache write miss/MMIO cache response timeout");
  return trace;
}

InvalidateAllCacheMmioWriteTrace
run_mode1_invalidate_all_cache_mmio_write_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  InvalidLlcTableDriver table_driver(dut.get_llc_config());

  InvalidateAllCacheMmioWriteTrace trace{};
  trace.prefix = "CPP_MODE1_INVALL_CACHE_MMIO_WRITE";
  auto &flow = trace.flow;
  flow.cache.prefix = "CPP_MODE1_INVALL_CACHE_MMIO_WRITE_CACHE";
  flow.cache.req_addr = 0x40000c04u;
  flow.cache.req_size = 3;
  flow.cache.req_id = 0x8u;
  const auto cache_data = single_word_data(0x24681357u);
  const auto cache_strobe = byte_strobe(0xfu);
  flow.cache.req_wdata = wide_write_words(cache_data);
  flow.cache.req_wstrb = write_strobe_mask(cache_strobe);
  flow.refill.prefix = "CPP_MODE1_INVALL_CACHE_MMIO_WRITE_REFILL";
  flow.refill.req_addr = flow.cache.req_addr;
  flow.refill.req_size = 63;
  flow.refill.req_id = 0;
  flow.refill.beat_count = 2;
  flow.refill.resp_data.assign(axi_interconnect::MAX_READ_TRANSACTION_WORDS,
                               0);
  flow.mmio.prefix = "CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO";
  flow.mmio.req_addr = 0x100000bcu;
  flow.mmio.req_size = 3;
  flow.mmio.req_id = 0x9u;
  const auto mmio_data = single_word_data(0xface00bcu);
  const auto mmio_strobe = byte_strobe(0xfu);
  flow.mmio.req_wdata = wide_write_words(mmio_data);
  flow.mmio.req_wstrb = write_strobe_mask(mmio_strobe);
  flow.cache_master = axi_interconnect::MASTER_DCACHE_W;
  flow.mmio_master = axi_interconnect::MASTER_UNCORE_LSU_W;

  bool accepted = false;
  bool ar_seen = false;
  bool request_active = true;
  for (int cycle = 0; cycle < 120 && !ar_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    const bool ready_snapshot = dut.write_ports[flow.cache_master].req.ready;
    if (request_active) {
      auto &req = dut.write_ports[flow.cache_master].req;
      req.valid = true;
      req.addr = flow.cache.req_addr;
      req.total_size = flow.cache.req_size;
      req.id = flow.cache.req_id;
      req.wdata = cache_data;
      req.wstrb = cache_strobe;
      req.bypass = false;
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    if (request_active && ready_snapshot) {
      accepted = true;
      request_active = false;
    }
    if (dut.axi_ddr_io.ar.arvalid) {
      require(!dut.axi_mmio_io.ar.arvalid,
              "C++ invall cache/MMIO write DDR AR overlapped with MMIO AR");
      flow.refill.araddr = static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
      flow.refill.arlen = static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
      flow.refill.arsize = static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
      flow.refill.arburst = static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
      flow.refill.arid = static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
      ar_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ invall cache/MMIO write miss was not accepted");
  require(ar_seen, "C++ invall cache/MMIO write did not issue DDR refill AR");
  require(flow.refill.beat_count ==
              static_cast<uint32_t>(flow.refill.arlen) + 1u,
          "C++ invall cache/MMIO write refill beat count mismatch");

  issue_write_and_capture_axi(dut, flow.mmio, flow.mmio_master,
                              axi_interconnect::DownstreamPort::MMIO,
                              mmio_data, mmio_strobe);

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.axi_mmio_io.b.bvalid = true;
  dut.axi_mmio_io.b.bid = flow.mmio.awid;
  dut.axi_mmio_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  trace.mmio_bready_while_invalidate_pending = dut.axi_mmio_io.b.bready;
  flow.mmio_bready_while_resp_stalled =
      trace.mmio_bready_while_invalidate_pending;
  require(dut.axi_mmio_io.b.bready,
          "C++ invall cache/MMIO write MMIO B was backpressured");
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ invall cache/MMIO write accepted in MMIO B handshake cycle");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.comb_outputs();
  require(dut.write_ports[flow.mmio_master].resp.valid,
          "C++ invall cache/MMIO write MMIO response was not held");
  require(!dut.write_ports[flow.cache_master].resp.valid,
          "C++ invall cache/MMIO write cache response appeared before refill");
  trace.blocked_while_mmio_resp_held = !dut.llc_invalidate_all_accepted();
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ invall cache/MMIO write accepted while MMIO response held");
  dut.seq();
  ++sim_time;

  trace.ddr_rready_while_mmio_resp_held = true;
  for (uint32_t beat = 0; beat < flow.refill.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = flow.refill.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == flow.refill.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(0xd00d0c00u + beat * 0x100u);
    flow.refill.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    trace.ddr_rready_while_mmio_resp_held =
        trace.ddr_rready_while_mmio_resp_held && dut.axi_ddr_io.r.rready;
    flow.ddr_rready_while_resp_stalled =
        trace.ddr_rready_while_mmio_resp_held;
    require(dut.axi_ddr_io.r.rready,
            "C++ invall cache/MMIO write DDR R was backpressured");
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall cache/MMIO write accepted in DDR R handshake cycle");
    dut.seq();
    ++sim_time;
  }

  bool cache_resp_seen = false;
  for (int cycle = 0; cycle < 180 && !cache_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    require(dut.write_ports[flow.mmio_master].resp.valid,
            "C++ invall cache/MMIO write MMIO response dropped while held");
    auto &cache_resp = dut.write_ports[flow.cache_master].resp;
    if (cache_resp.valid) {
      cache_resp_seen = true;
      flow.cache.resp_id = static_cast<uint8_t>(cache_resp.id);
      flow.cache.resp_code = static_cast<uint8_t>(cache_resp.resp);
      trace.blocked_while_cache_resp_held =
          !dut.llc_invalidate_all_accepted();
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall cache/MMIO write accepted while cache response held");
    dut.seq();
    ++sim_time;
  }
  require(cache_resp_seen, "C++ invall cache/MMIO write cache response timeout");

  bool mmio_retired = false;
  for (int cycle = 0; cycle < 8 && !mmio_retired; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.write_ports[flow.mmio_master].resp.ready = true;
    dut.comb_outputs();
    auto &mmio_resp = dut.write_ports[flow.mmio_master].resp;
    if (!mmio_resp.valid) {
      mmio_retired = true;
      break;
    }
    flow.mmio.resp_id = static_cast<uint8_t>(mmio_resp.id);
    flow.mmio.resp_code = static_cast<uint8_t>(mmio_resp.resp);
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall cache/MMIO write accepted before MMIO response retired");
    dut.seq();
    ++sim_time;
  }
  require(mmio_retired,
          "C++ invall cache/MMIO write MMIO response did not retire");

  bool cache_retired = false;
  for (int cycle = 0; cycle < 8 && !cache_retired; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.write_ports[flow.cache_master].resp.ready = true;
    dut.comb_outputs();
    if (!dut.write_ports[flow.cache_master].resp.valid) {
      cache_retired = true;
      break;
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall cache/MMIO write accepted before cache response retired");
    dut.seq();
    ++sim_time;
  }
  require(cache_retired,
          "C++ invall cache/MMIO write cache response did not retire");

  for (int retry = 0; retry < 32; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall cache/MMIO write accepted with dirty resident line");
    dut.seq();
    ++sim_time;
  }
  trace.accepted_after_resp_retire = false;
  dut.set_llc_invalidate_all(false);
  return trace;
}

InvalidateLineCacheMmioWriteTrace
run_mode1_invalidate_line_cache_mmio_write_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  InvalidLlcTableDriver table_driver(dut.get_llc_config());

  InvalidateLineCacheMmioWriteTrace trace{};
  trace.prefix = "CPP_MODE1_INVLINE_CACHE_MMIO_WRITE";
  auto &flow = trace.flow;
  flow.cache.prefix = "CPP_MODE1_INVLINE_CACHE_MMIO_WRITE_CACHE";
  flow.cache.req_addr = 0x40000e04u;
  flow.cache.req_size = 3;
  flow.cache.req_id = 0xDu;
  const auto cache_data = single_word_data(0x35792468u);
  const auto cache_strobe = byte_strobe(0xfu);
  flow.cache.req_wdata = wide_write_words(cache_data);
  flow.cache.req_wstrb = write_strobe_mask(cache_strobe);
  flow.refill.prefix = "CPP_MODE1_INVLINE_CACHE_MMIO_WRITE_REFILL";
  flow.refill.req_addr = flow.cache.req_addr;
  flow.refill.req_size = 63;
  flow.refill.req_id = 0;
  flow.refill.beat_count = 2;
  flow.refill.resp_data.assign(axi_interconnect::MAX_READ_TRANSACTION_WORDS,
                               0);
  flow.mmio.prefix = "CPP_MODE1_INVLINE_CACHE_MMIO_WRITE_MMIO";
  flow.mmio.req_addr = 0x100001e0u;
  flow.mmio.req_size = 3;
  flow.mmio.req_id = 0xEu;
  const auto mmio_data = single_word_data(0xface01e0u);
  const auto mmio_strobe = byte_strobe(0xfu);
  flow.mmio.req_wdata = wide_write_words(mmio_data);
  flow.mmio.req_wstrb = write_strobe_mask(mmio_strobe);
  flow.cache_master = axi_interconnect::MASTER_DCACHE_W;
  flow.mmio_master = axi_interconnect::MASTER_UNCORE_LSU_W;
  trace.invalidate_addr = flow.cache.req_addr;

  bool accepted = false;
  bool ar_seen = false;
  bool request_active = true;
  for (int cycle = 0; cycle < 120 && !ar_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    const bool ready_snapshot = dut.write_ports[flow.cache_master].req.ready;
    if (request_active) {
      auto &req = dut.write_ports[flow.cache_master].req;
      req.valid = true;
      req.addr = flow.cache.req_addr;
      req.total_size = flow.cache.req_size;
      req.id = flow.cache.req_id;
      req.wdata = cache_data;
      req.wstrb = cache_strobe;
      req.bypass = false;
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    if (request_active && ready_snapshot) {
      accepted = true;
      request_active = false;
    }
    if (dut.axi_ddr_io.ar.arvalid) {
      require(!dut.axi_mmio_io.ar.arvalid,
              "C++ invline cache/MMIO write DDR AR overlapped with MMIO AR");
      flow.refill.araddr = static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
      flow.refill.arlen = static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
      flow.refill.arsize = static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
      flow.refill.arburst = static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
      flow.refill.arid = static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
      ar_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ invline cache/MMIO write miss was not accepted");
  require(ar_seen, "C++ invline cache/MMIO write did not issue DDR refill AR");
  require(flow.refill.beat_count ==
              static_cast<uint32_t>(flow.refill.arlen) + 1u,
          "C++ invline cache/MMIO write refill beat count mismatch");

  issue_write_and_capture_axi(dut, flow.mmio, flow.mmio_master,
                              axi_interconnect::DownstreamPort::MMIO,
                              mmio_data, mmio_strobe);

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_line(true, trace.invalidate_addr);
  dut.axi_mmio_io.b.bvalid = true;
  dut.axi_mmio_io.b.bid = flow.mmio.awid;
  dut.axi_mmio_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  trace.mmio_bready_while_invalidate_pending = dut.axi_mmio_io.b.bready;
  flow.mmio_bready_while_resp_stalled =
      trace.mmio_bready_while_invalidate_pending;
  require(dut.axi_mmio_io.b.bready,
          "C++ invline cache/MMIO write MMIO B was backpressured");
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_line_accepted(),
          "C++ invline cache/MMIO write accepted in MMIO B handshake cycle");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_line(true, trace.invalidate_addr);
  dut.comb_outputs();
  require(dut.write_ports[flow.mmio_master].resp.valid,
          "C++ invline cache/MMIO write MMIO response was not held");
  require(!dut.write_ports[flow.cache_master].resp.valid,
          "C++ invline cache/MMIO write cache response appeared before refill");
  trace.blocked_while_mmio_resp_held = !dut.llc_invalidate_line_accepted();
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_line_accepted(),
          "C++ invline cache/MMIO write accepted while MMIO response held");
  dut.seq();
  ++sim_time;

  trace.ddr_rready_while_mmio_resp_held = true;
  for (uint32_t beat = 0; beat < flow.refill.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = flow.refill.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == flow.refill.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(0xd00d0e00u + beat * 0x100u);
    flow.refill.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    trace.ddr_rready_while_mmio_resp_held =
        trace.ddr_rready_while_mmio_resp_held && dut.axi_ddr_io.r.rready;
    flow.ddr_rready_while_resp_stalled =
        trace.ddr_rready_while_mmio_resp_held;
    require(dut.axi_ddr_io.r.rready,
            "C++ invline cache/MMIO write DDR R was backpressured");
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_line_accepted(),
            "C++ invline cache/MMIO write accepted in DDR R handshake cycle");
    dut.seq();
    ++sim_time;
  }

  bool cache_resp_seen = false;
  for (int cycle = 0; cycle < 180 && !cache_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.comb_outputs();
    require(dut.write_ports[flow.mmio_master].resp.valid,
            "C++ invline cache/MMIO write MMIO response dropped while held");
    auto &cache_resp = dut.write_ports[flow.cache_master].resp;
    if (cache_resp.valid) {
      cache_resp_seen = true;
      flow.cache.resp_id = static_cast<uint8_t>(cache_resp.id);
      flow.cache.resp_code = static_cast<uint8_t>(cache_resp.resp);
      trace.blocked_while_cache_resp_held =
          !dut.llc_invalidate_line_accepted();
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_line_accepted(),
            "C++ invline cache/MMIO write accepted while cache response held");
    dut.seq();
    ++sim_time;
  }
  require(cache_resp_seen, "C++ invline cache/MMIO write cache response timeout");

  bool mmio_retired = false;
  for (int cycle = 0; cycle < 8 && !mmio_retired; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.write_ports[flow.mmio_master].resp.ready = true;
    dut.comb_outputs();
    auto &mmio_resp = dut.write_ports[flow.mmio_master].resp;
    if (!mmio_resp.valid) {
      mmio_retired = true;
      break;
    }
    flow.mmio.resp_id = static_cast<uint8_t>(mmio_resp.id);
    flow.mmio.resp_code = static_cast<uint8_t>(mmio_resp.resp);
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_line_accepted(),
            "C++ invline cache/MMIO write accepted before MMIO response retired");
    dut.seq();
    ++sim_time;
  }
  require(mmio_retired,
          "C++ invline cache/MMIO write MMIO response did not retire");

  bool cache_retired = false;
  for (int cycle = 0; cycle < 8 && !cache_retired; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.write_ports[flow.cache_master].resp.ready = true;
    dut.comb_outputs();
    if (!dut.write_ports[flow.cache_master].resp.valid) {
      cache_retired = true;
      break;
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_line_accepted(),
            "C++ invline cache/MMIO write accepted before cache response retired");
    dut.seq();
    ++sim_time;
  }
  require(cache_retired,
          "C++ invline cache/MMIO write cache response did not retire");

  bool accepted_after_retire = false;
  for (int retry = 0; retry < 10000 && !accepted_after_retire; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    if (dut.llc_invalidate_line_accepted()) {
      accepted_after_retire = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted_after_retire,
          "C++ invline cache/MMIO write did not accept after responses retired");
  trace.accepted_after_resp_retire = true;
  dut.set_llc_invalidate_line(false, 0);
  return trace;
}

InvalidateLineCacheWriteMmioReadWriteTrace
run_mode1_invalidate_line_cache_write_mmio_read_write_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  InvalidLlcTableDriver table_driver(dut.get_llc_config());

  InvalidateLineCacheWriteMmioReadWriteTrace trace{};
  trace.prefix = "CPP_MODE1_INVLINE_CACHE_WRITE_MMIO_RW";
  auto &flow = trace.flow;
  flow.cache.prefix = "CPP_MODE1_INVLINE_CACHE_WRITE_MMIO_RW_CACHE";
  flow.cache.req_addr = 0x40001104u;
  flow.cache.req_size = 3;
  flow.cache.req_id = 0x9u;
  const auto cache_data = single_word_data(0x468a1357u);
  const auto cache_strobe = byte_strobe(0xfu);
  flow.cache.req_wdata = wide_write_words(cache_data);
  flow.cache.req_wstrb = write_strobe_mask(cache_strobe);
  flow.refill.prefix = "CPP_MODE1_INVLINE_CACHE_WRITE_MMIO_RW_REFILL";
  flow.refill.req_addr = flow.cache.req_addr;
  flow.refill.req_size = 63;
  flow.refill.req_id = 0;
  flow.refill.beat_count = 2;
  flow.refill.resp_data.assign(axi_interconnect::MAX_READ_TRANSACTION_WORDS,
                               0);
  trace.mmio_read.prefix = "CPP_MODE1_INVLINE_CACHE_WRITE_MMIO_RW_MMIO_READ";
  trace.mmio_read.req_addr = 0x10000280u;
  trace.mmio_read.req_size = 3;
  trace.mmio_read.req_id = 0xAu;
  trace.mmio_read.beat_count = 1;
  flow.mmio.prefix = "CPP_MODE1_INVLINE_CACHE_WRITE_MMIO_RW_MMIO_WRITE";
  flow.mmio.req_addr = 0x100002c0u;
  flow.mmio.req_size = 3;
  flow.mmio.req_id = 0xBu;
  const auto mmio_write_data = single_word_data(0xface02c0u);
  const auto mmio_write_strobe = byte_strobe(0xfu);
  flow.mmio.req_wdata = wide_write_words(mmio_write_data);
  flow.mmio.req_wstrb = write_strobe_mask(mmio_write_strobe);
  flow.cache_master = axi_interconnect::MASTER_DCACHE_W;
  trace.mmio_read_master = axi_interconnect::MASTER_UNCORE_LSU_R;
  flow.mmio_master = axi_interconnect::MASTER_UNCORE_LSU_W;
  trace.invalidate_addr = flow.cache.req_addr;

  bool accepted = false;
  bool ar_seen = false;
  bool request_active = true;
  for (int cycle = 0; cycle < 120 && !ar_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    const bool ready_snapshot = dut.write_ports[flow.cache_master].req.ready;
    if (request_active) {
      auto &req = dut.write_ports[flow.cache_master].req;
      req.valid = true;
      req.addr = flow.cache.req_addr;
      req.total_size = flow.cache.req_size;
      req.id = flow.cache.req_id;
      req.wdata = cache_data;
      req.wstrb = cache_strobe;
      req.bypass = false;
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    if (request_active && ready_snapshot) {
      accepted = true;
      request_active = false;
    }
    if (dut.axi_ddr_io.ar.arvalid) {
      require(!dut.axi_mmio_io.ar.arvalid,
              "C++ invline cache-write/MMIO RW DDR AR overlapped with MMIO AR");
      flow.refill.araddr = static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
      flow.refill.arlen = static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
      flow.refill.arsize = static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
      flow.refill.arburst = static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
      flow.refill.arid = static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
      ar_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ invline cache-write/MMIO RW miss was not accepted");
  require(ar_seen,
          "C++ invline cache-write/MMIO RW did not issue DDR refill AR");
  require(flow.refill.beat_count ==
              static_cast<uint32_t>(flow.refill.arlen) + 1u,
          "C++ invline cache-write/MMIO RW refill beat count mismatch");

  issue_read_and_capture_ar(dut, trace.mmio_read, trace.mmio_read_master,
                            axi_interconnect::DownstreamPort::MMIO);
  issue_write_and_capture_axi(dut, flow.mmio, flow.mmio_master,
                              axi_interconnect::DownstreamPort::MMIO,
                              mmio_write_data, mmio_write_strobe);

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_line(true, trace.invalidate_addr);
  dut.axi_mmio_io.r.rvalid = true;
  dut.axi_mmio_io.r.rid = trace.mmio_read.arid;
  dut.axi_mmio_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_mmio_io.r.rlast = true;
  dut.axi_mmio_io.r.rdata = {};
  axi_compat::set_u32(dut.axi_mmio_io.r.rdata, 0, 0xcafe0280u);
  trace.mmio_read.rbeats[0] = axi_words(dut.axi_mmio_io.r.rdata);
  dut.axi_mmio_io.b.bvalid = true;
  dut.axi_mmio_io.b.bid = flow.mmio.awid;
  dut.axi_mmio_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  trace.mmio_rready_while_invalidate_pending = dut.axi_mmio_io.r.rready;
  trace.mmio_bready_while_invalidate_pending = dut.axi_mmio_io.b.bready;
  flow.mmio_bready_while_resp_stalled =
      trace.mmio_bready_while_invalidate_pending;
  require(dut.axi_mmio_io.r.rready,
          "C++ invline cache-write/MMIO RW MMIO R was backpressured");
  require(dut.axi_mmio_io.b.bready,
          "C++ invline cache-write/MMIO RW MMIO B was backpressured");
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_line_accepted(),
          "C++ invline cache-write/MMIO RW accepted in MMIO R/B cycle");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_line(true, trace.invalidate_addr);
  dut.comb_outputs();
  require(dut.read_ports[trace.mmio_read_master].resp.valid,
          "C++ invline cache-write/MMIO RW MMIO read response was not held");
  require(dut.write_ports[flow.mmio_master].resp.valid,
          "C++ invline cache-write/MMIO RW MMIO write response was not held");
  require(!dut.write_ports[flow.cache_master].resp.valid,
          "C++ invline cache-write/MMIO RW cache response appeared before refill");
  trace.blocked_while_mmio_resp_held = !dut.llc_invalidate_line_accepted();
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_line_accepted(),
          "C++ invline cache-write/MMIO RW accepted while MMIO responses held");
  dut.seq();
  ++sim_time;

  trace.ddr_rready_while_mmio_resp_held = true;
  for (uint32_t beat = 0; beat < flow.refill.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = flow.refill.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == flow.refill.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(0xd00d1100u + beat * 0x100u);
    flow.refill.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    trace.ddr_rready_while_mmio_resp_held =
        trace.ddr_rready_while_mmio_resp_held && dut.axi_ddr_io.r.rready;
    flow.ddr_rready_while_resp_stalled =
        trace.ddr_rready_while_mmio_resp_held;
    require(dut.axi_ddr_io.r.rready,
            "C++ invline cache-write/MMIO RW DDR R was backpressured");
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_line_accepted(),
            "C++ invline cache-write/MMIO RW accepted in DDR R cycle");
    dut.seq();
    ++sim_time;
  }

  bool cache_resp_seen = false;
  for (int cycle = 0; cycle < 180 && !cache_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.comb_outputs();
    require(dut.read_ports[trace.mmio_read_master].resp.valid,
            "C++ invline cache-write/MMIO RW MMIO read response dropped");
    require(dut.write_ports[flow.mmio_master].resp.valid,
            "C++ invline cache-write/MMIO RW MMIO write response dropped");
    auto &cache_resp = dut.write_ports[flow.cache_master].resp;
    if (cache_resp.valid) {
      cache_resp_seen = true;
      flow.cache.resp_id = static_cast<uint8_t>(cache_resp.id);
      flow.cache.resp_code = static_cast<uint8_t>(cache_resp.resp);
      trace.blocked_while_cache_resp_held =
          !dut.llc_invalidate_line_accepted();
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_line_accepted(),
            "C++ invline cache-write/MMIO RW accepted while cache response held");
    dut.seq();
    ++sim_time;
  }
  require(cache_resp_seen,
          "C++ invline cache-write/MMIO RW cache response timeout");

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_line(true, trace.invalidate_addr);
  dut.read_ports[trace.mmio_read_master].resp.ready = true;
  dut.comb_outputs();
  auto &mmio_read_resp = dut.read_ports[trace.mmio_read_master].resp;
  require(mmio_read_resp.valid,
          "C++ invline cache-write/MMIO RW MMIO read response not valid");
  trace.mmio_read.resp_id = static_cast<uint8_t>(mmio_read_resp.id);
  trace.mmio_read.resp_data = wide_read_words(mmio_read_resp.data);
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_line_accepted(),
          "C++ invline cache-write/MMIO RW accepted before MMIO read retire");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_line(true, trace.invalidate_addr);
  dut.write_ports[flow.mmio_master].resp.ready = true;
  dut.comb_outputs();
  auto &mmio_write_resp = dut.write_ports[flow.mmio_master].resp;
  require(mmio_write_resp.valid,
          "C++ invline cache-write/MMIO RW MMIO write response not valid");
  flow.mmio.resp_id = static_cast<uint8_t>(mmio_write_resp.id);
  flow.mmio.resp_code = static_cast<uint8_t>(mmio_write_resp.resp);
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_line_accepted(),
          "C++ invline cache-write/MMIO RW accepted before MMIO write retire");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_line(true, trace.invalidate_addr);
  dut.write_ports[flow.cache_master].resp.ready = true;
  dut.comb_outputs();
  require(dut.write_ports[flow.cache_master].resp.valid,
          "C++ invline cache-write/MMIO RW cache response not valid");
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_line_accepted(),
          "C++ invline cache-write/MMIO RW accepted before cache retire");
  dut.seq();
  ++sim_time;

  bool accepted_after_retire = false;
  for (int retry = 0; retry < 10000 && !accepted_after_retire; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    if (dut.llc_invalidate_line_accepted()) {
      accepted_after_retire = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted_after_retire,
          "C++ invline cache-write/MMIO RW did not accept after responses");
  trace.accepted_after_resp_retire = true;
  dut.set_llc_invalidate_line(false, 0);
  return trace;
}

InvalidateAllCacheWriteMmioReadWriteTrace
run_mode1_invalidate_all_cache_write_mmio_read_write_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  InvalidLlcTableDriver table_driver(dut.get_llc_config());

  InvalidateAllCacheWriteMmioReadWriteTrace trace{};
  trace.prefix = "CPP_MODE1_INVALL_CACHE_WRITE_MMIO_RW";
  auto &flow = trace.flow;
  flow.cache.prefix = "CPP_MODE1_INVALL_CACHE_WRITE_MMIO_RW_CACHE";
  flow.cache.req_addr = 0x40001204u;
  flow.cache.req_size = 3;
  flow.cache.req_id = 0xCu;
  const auto cache_data = single_word_data(0x579b2468u);
  const auto cache_strobe = byte_strobe(0xfu);
  flow.cache.req_wdata = wide_write_words(cache_data);
  flow.cache.req_wstrb = write_strobe_mask(cache_strobe);
  flow.refill.prefix = "CPP_MODE1_INVALL_CACHE_WRITE_MMIO_RW_REFILL";
  flow.refill.req_addr = flow.cache.req_addr;
  flow.refill.req_size = 63;
  flow.refill.req_id = 0;
  flow.refill.beat_count = 2;
  flow.refill.resp_data.assign(axi_interconnect::MAX_READ_TRANSACTION_WORDS,
                               0);
  trace.mmio_read.prefix = "CPP_MODE1_INVALL_CACHE_WRITE_MMIO_RW_MMIO_READ";
  trace.mmio_read.req_addr = 0x10000300u;
  trace.mmio_read.req_size = 3;
  trace.mmio_read.req_id = 0xDu;
  trace.mmio_read.beat_count = 1;
  flow.mmio.prefix = "CPP_MODE1_INVALL_CACHE_WRITE_MMIO_RW_MMIO_WRITE";
  flow.mmio.req_addr = 0x10000340u;
  flow.mmio.req_size = 3;
  flow.mmio.req_id = 0xEu;
  const auto mmio_write_data = single_word_data(0xface0340u);
  const auto mmio_write_strobe = byte_strobe(0xfu);
  flow.mmio.req_wdata = wide_write_words(mmio_write_data);
  flow.mmio.req_wstrb = write_strobe_mask(mmio_write_strobe);
  flow.cache_master = axi_interconnect::MASTER_DCACHE_W;
  trace.mmio_read_master = axi_interconnect::MASTER_UNCORE_LSU_R;
  flow.mmio_master = axi_interconnect::MASTER_UNCORE_LSU_W;

  bool accepted = false;
  bool ar_seen = false;
  bool request_active = true;
  for (int cycle = 0; cycle < 120 && !ar_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    const bool ready_snapshot = dut.write_ports[flow.cache_master].req.ready;
    if (request_active) {
      auto &req = dut.write_ports[flow.cache_master].req;
      req.valid = true;
      req.addr = flow.cache.req_addr;
      req.total_size = flow.cache.req_size;
      req.id = flow.cache.req_id;
      req.wdata = cache_data;
      req.wstrb = cache_strobe;
      req.bypass = false;
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    if (request_active && ready_snapshot) {
      accepted = true;
      request_active = false;
    }
    if (dut.axi_ddr_io.ar.arvalid) {
      require(!dut.axi_mmio_io.ar.arvalid,
              "C++ invall cache-write/MMIO RW DDR AR overlapped with MMIO AR");
      flow.refill.araddr = static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
      flow.refill.arlen = static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
      flow.refill.arsize = static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
      flow.refill.arburst = static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
      flow.refill.arid = static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
      ar_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ invall cache-write/MMIO RW miss was not accepted");
  require(ar_seen,
          "C++ invall cache-write/MMIO RW did not issue DDR refill AR");
  require(flow.refill.beat_count ==
              static_cast<uint32_t>(flow.refill.arlen) + 1u,
          "C++ invall cache-write/MMIO RW refill beat count mismatch");

  issue_read_and_capture_ar(dut, trace.mmio_read, trace.mmio_read_master,
                            axi_interconnect::DownstreamPort::MMIO);
  issue_write_and_capture_axi(dut, flow.mmio, flow.mmio_master,
                              axi_interconnect::DownstreamPort::MMIO,
                              mmio_write_data, mmio_write_strobe);

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.axi_mmio_io.r.rvalid = true;
  dut.axi_mmio_io.r.rid = trace.mmio_read.arid;
  dut.axi_mmio_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_mmio_io.r.rlast = true;
  dut.axi_mmio_io.r.rdata = {};
  axi_compat::set_u32(dut.axi_mmio_io.r.rdata, 0, 0xcafe0300u);
  trace.mmio_read.rbeats[0] = axi_words(dut.axi_mmio_io.r.rdata);
  dut.axi_mmio_io.b.bvalid = true;
  dut.axi_mmio_io.b.bid = flow.mmio.awid;
  dut.axi_mmio_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  trace.mmio_rready_while_invalidate_pending = dut.axi_mmio_io.r.rready;
  trace.mmio_bready_while_invalidate_pending = dut.axi_mmio_io.b.bready;
  flow.mmio_bready_while_resp_stalled =
      trace.mmio_bready_while_invalidate_pending;
  require(dut.axi_mmio_io.r.rready,
          "C++ invall cache-write/MMIO RW MMIO R was backpressured");
  require(dut.axi_mmio_io.b.bready,
          "C++ invall cache-write/MMIO RW MMIO B was backpressured");
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ invall cache-write/MMIO RW accepted in MMIO R/B cycle");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.comb_outputs();
  require(dut.read_ports[trace.mmio_read_master].resp.valid,
          "C++ invall cache-write/MMIO RW MMIO read response was not held");
  require(dut.write_ports[flow.mmio_master].resp.valid,
          "C++ invall cache-write/MMIO RW MMIO write response was not held");
  require(!dut.write_ports[flow.cache_master].resp.valid,
          "C++ invall cache-write/MMIO RW cache response appeared before refill");
  trace.blocked_while_mmio_resp_held = !dut.llc_invalidate_all_accepted();
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ invall cache-write/MMIO RW accepted while MMIO responses held");
  dut.seq();
  ++sim_time;

  trace.ddr_rready_while_mmio_resp_held = true;
  for (uint32_t beat = 0; beat < flow.refill.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = flow.refill.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == flow.refill.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(0xd00d1200u + beat * 0x100u);
    flow.refill.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    trace.ddr_rready_while_mmio_resp_held =
        trace.ddr_rready_while_mmio_resp_held && dut.axi_ddr_io.r.rready;
    flow.ddr_rready_while_resp_stalled =
        trace.ddr_rready_while_mmio_resp_held;
    require(dut.axi_ddr_io.r.rready,
            "C++ invall cache-write/MMIO RW DDR R was backpressured");
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall cache-write/MMIO RW accepted in DDR R cycle");
    dut.seq();
    ++sim_time;
  }

  bool cache_resp_seen = false;
  for (int cycle = 0; cycle < 180 && !cache_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    require(dut.read_ports[trace.mmio_read_master].resp.valid,
            "C++ invall cache-write/MMIO RW MMIO read response dropped");
    require(dut.write_ports[flow.mmio_master].resp.valid,
            "C++ invall cache-write/MMIO RW MMIO write response dropped");
    auto &cache_resp = dut.write_ports[flow.cache_master].resp;
    if (cache_resp.valid) {
      cache_resp_seen = true;
      flow.cache.resp_id = static_cast<uint8_t>(cache_resp.id);
      flow.cache.resp_code = static_cast<uint8_t>(cache_resp.resp);
      trace.blocked_while_cache_resp_held =
          !dut.llc_invalidate_all_accepted();
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall cache-write/MMIO RW accepted while cache response held");
    dut.seq();
    ++sim_time;
  }
  require(cache_resp_seen,
          "C++ invall cache-write/MMIO RW cache response timeout");

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.read_ports[trace.mmio_read_master].resp.ready = true;
  dut.comb_outputs();
  auto &mmio_read_resp = dut.read_ports[trace.mmio_read_master].resp;
  require(mmio_read_resp.valid,
          "C++ invall cache-write/MMIO RW MMIO read response not valid");
  trace.mmio_read.resp_id = static_cast<uint8_t>(mmio_read_resp.id);
  trace.mmio_read.resp_data = wide_read_words(mmio_read_resp.data);
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ invall cache-write/MMIO RW accepted before MMIO read retire");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.write_ports[flow.mmio_master].resp.ready = true;
  dut.comb_outputs();
  auto &mmio_write_resp = dut.write_ports[flow.mmio_master].resp;
  require(mmio_write_resp.valid,
          "C++ invall cache-write/MMIO RW MMIO write response not valid");
  flow.mmio.resp_id = static_cast<uint8_t>(mmio_write_resp.id);
  flow.mmio.resp_code = static_cast<uint8_t>(mmio_write_resp.resp);
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ invall cache-write/MMIO RW accepted before MMIO write retire");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.write_ports[flow.cache_master].resp.ready = true;
  dut.comb_outputs();
  require(dut.write_ports[flow.cache_master].resp.valid,
          "C++ invall cache-write/MMIO RW cache response not valid");
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ invall cache-write/MMIO RW accepted before cache retire");
  dut.seq();
  ++sim_time;

  for (int retry = 0; retry < 32; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall cache-write/MMIO RW accepted with dirty resident line");
    dut.seq();
    ++sim_time;
  }
  trace.accepted_after_resp_retire = false;
  dut.set_llc_invalidate_all(false);
  return trace;
}

InvalidateAllCacheMmioReadWriteTrace
run_mode1_invalidate_all_cache_mmio_read_write_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  InvalidLlcTableDriver table_driver(dut.get_llc_config());

  InvalidateAllCacheMmioReadWriteTrace trace{};
  trace.prefix = "CPP_MODE1_INVALL_CACHE_MMIO_RW";
  trace.overlap.ddr.prefix = "CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR";
  trace.overlap.ddr.req_addr = 0x40000d04u;
  trace.overlap.ddr.req_size = 3;
  trace.overlap.ddr.req_id = 0xAu;
  trace.overlap.ddr.beat_count = 2;
  trace.overlap.mmio.prefix = "CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ";
  trace.overlap.mmio.req_addr = 0x100000c0u;
  trace.overlap.mmio.req_size = 3;
  trace.overlap.mmio.req_id = 0xBu;
  trace.overlap.mmio.beat_count = 1;
  trace.overlap.ddr_master = axi_interconnect::MASTER_DCACHE_R;
  trace.overlap.mmio_master = axi_interconnect::MASTER_UNCORE_LSU_R;
  trace.mmio_write.prefix = "CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE";
  trace.mmio_write.req_addr = 0x100001c4u;
  trace.mmio_write.req_size = 3;
  trace.mmio_write.req_id = 0xAu;
  const auto write_data = single_word_data(0xface01c4u);
  const auto write_strobe = byte_strobe(0xfu);
  trace.mmio_write.req_wdata = wide_write_words(write_data);
  trace.mmio_write.req_wstrb = write_strobe_mask(write_strobe);
  trace.mmio_write_master = axi_interconnect::MASTER_UNCORE_LSU_W;

  bool accepted = false;
  bool ar_seen = false;
  bool request_active = true;
  for (int cycle = 0; cycle < 80 && !ar_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    if (request_active) {
      auto &req = dut.read_ports[trace.overlap.ddr_master].req;
      req.valid = true;
      req.addr = trace.overlap.ddr.req_addr;
      req.total_size = trace.overlap.ddr.req_size;
      req.id = trace.overlap.ddr.req_id;
      req.bypass = false;
    }
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    if (request_active && dut.read_ports[trace.overlap.ddr_master].req.ready) {
      accepted = true;
      request_active = false;
    }
    if (dut.axi_ddr_io.ar.arvalid) {
      require(!dut.axi_mmio_io.ar.arvalid,
              "C++ invall cache/MMIO RW DDR AR overlapped with MMIO AR");
      trace.overlap.ddr.araddr =
          static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
      trace.overlap.ddr.arlen =
          static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
      trace.overlap.ddr.arsize =
          static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
      trace.overlap.ddr.arburst =
          static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
      trace.overlap.ddr.arid = static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
      ar_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ invall cache/MMIO RW cache read was not accepted");
  require(ar_seen, "C++ invall cache/MMIO RW cache read did not issue DDR AR");
  require(trace.overlap.ddr.beat_count ==
              static_cast<uint32_t>(trace.overlap.ddr.arlen) + 1u,
          "C++ invall cache/MMIO RW cache read beat count mismatch");

  issue_read_and_capture_ar(dut, trace.overlap.mmio, trace.overlap.mmio_master,
                            axi_interconnect::DownstreamPort::MMIO);
  issue_write_and_capture_axi(dut, trace.mmio_write, trace.mmio_write_master,
                              axi_interconnect::DownstreamPort::MMIO,
                              write_data, write_strobe);

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.axi_mmio_io.r.rvalid = true;
  dut.axi_mmio_io.r.rid = trace.overlap.mmio.arid;
  dut.axi_mmio_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_mmio_io.r.rlast = true;
  dut.axi_mmio_io.r.rdata = {};
  axi_compat::set_u32(dut.axi_mmio_io.r.rdata, 0, 0xcafe00c0u);
  trace.overlap.mmio.rbeats[0] = axi_words(dut.axi_mmio_io.r.rdata);
  dut.axi_mmio_io.b.bvalid = true;
  dut.axi_mmio_io.b.bid = trace.mmio_write.awid;
  dut.axi_mmio_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  trace.mmio_rready_while_invalidate_pending = dut.axi_mmio_io.r.rready;
  trace.mmio_bready_while_invalidate_pending = dut.axi_mmio_io.b.bready;
  trace.overlap.mmio_rready_while_resp_stalled =
      trace.mmio_rready_while_invalidate_pending;
  require(dut.axi_mmio_io.r.rready,
          "C++ invall cache/MMIO RW MMIO R was backpressured");
  require(dut.axi_mmio_io.b.bready,
          "C++ invall cache/MMIO RW MMIO B was backpressured");
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ invall cache/MMIO RW accepted in MMIO R/B handshake cycle");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.comb_outputs();
  require(dut.read_ports[trace.overlap.mmio_master].resp.valid,
          "C++ invall cache/MMIO RW MMIO read response was not held");
  require(dut.write_ports[trace.mmio_write_master].resp.valid,
          "C++ invall cache/MMIO RW MMIO write response was not held");
  trace.blocked_while_mmio_resp_held = !dut.llc_invalidate_all_accepted();
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ invall cache/MMIO RW accepted while MMIO responses held");
  dut.seq();
  ++sim_time;

  trace.ddr_rready_while_mmio_resp_held = true;
  for (uint32_t beat = 0; beat < trace.overlap.ddr.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = trace.overlap.ddr.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == trace.overlap.ddr.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(0xd00d0d00u + beat * 0x100u);
    trace.overlap.ddr.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    trace.ddr_rready_while_mmio_resp_held =
        trace.ddr_rready_while_mmio_resp_held && dut.axi_ddr_io.r.rready;
    trace.overlap.ddr_rready_while_resp_stalled =
        trace.ddr_rready_while_mmio_resp_held;
    require(dut.axi_ddr_io.r.rready,
            "C++ invall cache/MMIO RW DDR R was backpressured");
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall cache/MMIO RW accepted in DDR R handshake cycle");
    dut.seq();
    ++sim_time;
  }

  bool cache_resp_seen = false;
  for (int cycle = 0; cycle < 180 && !cache_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    require(dut.read_ports[trace.overlap.mmio_master].resp.valid,
            "C++ invall cache/MMIO RW MMIO read response dropped while held");
    require(dut.write_ports[trace.mmio_write_master].resp.valid,
            "C++ invall cache/MMIO RW MMIO write response dropped while held");
    auto &cache_resp = dut.read_ports[trace.overlap.ddr_master].resp;
    if (cache_resp.valid) {
      cache_resp_seen = true;
      trace.overlap.ddr.resp_id = static_cast<uint8_t>(cache_resp.id);
      trace.overlap.ddr.resp_data = wide_read_words(cache_resp.data);
      trace.blocked_while_cache_resp_held = !dut.llc_invalidate_all_accepted();
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ invall cache/MMIO RW accepted while cache response held");
    dut.seq();
    ++sim_time;
  }
  require(cache_resp_seen, "C++ invall cache/MMIO RW cache response timeout");

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.read_ports[trace.overlap.mmio_master].resp.ready = true;
  dut.comb_outputs();
  auto &mmio_read_resp = dut.read_ports[trace.overlap.mmio_master].resp;
  require(mmio_read_resp.valid,
          "C++ invall cache/MMIO RW MMIO read response not valid at retire");
  trace.overlap.mmio.resp_id = static_cast<uint8_t>(mmio_read_resp.id);
  trace.overlap.mmio.resp_data = wide_read_words(mmio_read_resp.data);
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ invall cache/MMIO RW accepted before MMIO read retired");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.write_ports[trace.mmio_write_master].resp.ready = true;
  dut.comb_outputs();
  auto &mmio_write_resp = dut.write_ports[trace.mmio_write_master].resp;
  require(mmio_write_resp.valid,
          "C++ invall cache/MMIO RW MMIO write response not valid at retire");
  trace.mmio_write.resp_id = static_cast<uint8_t>(mmio_write_resp.id);
  trace.mmio_write.resp_code = static_cast<uint8_t>(mmio_write_resp.resp);
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ invall cache/MMIO RW accepted before MMIO write retired");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.read_ports[trace.overlap.ddr_master].resp.ready = true;
  dut.comb_outputs();
  require(dut.read_ports[trace.overlap.ddr_master].resp.valid,
          "C++ invall cache/MMIO RW cache response not valid at retire");
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ invall cache/MMIO RW accepted before cache response retired");
  dut.seq();
  ++sim_time;

  for (int retry = 0; retry < 160; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    const bool accepted_now = dut.llc_invalidate_all_accepted();
    dut.seq();
    ++sim_time;
    if (accepted_now) {
      trace.accepted_after_resp_retire = true;
      dut.set_llc_invalidate_all(false);
      return trace;
    }
  }
  dut.debug_print();
  require(false,
          "C++ invall cache/MMIO RW did not accept after responses retired");
  return trace;
}

InvalidateLineCacheMmioReadWriteTrace
run_mode1_invalidate_line_cache_mmio_read_write_trace(
    const std::string &prefix = "CPP_MODE1_INVLINE_CACHE_MMIO_RW",
    uint32_t ddr_req_addr = 0x40000f04u, uint8_t ddr_req_id = 0xBu,
    uint32_t mmio_read_addr = 0x100001f0u, uint8_t mmio_read_id = 0xCu,
    uint32_t mmio_read_word = 0xcafe01f0u,
    uint32_t mmio_write_addr = 0x10000240u, uint8_t mmio_write_id = 0xDu,
    uint32_t mmio_write_word = 0xface0240u,
    uint32_t invalidate_addr = 0u, uint32_t ddr_beat_seed = 0xd00d0f00u) {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  InvalidLlcTableDriver table_driver(dut.get_llc_config());

  InvalidateLineCacheMmioReadWriteTrace trace{};
  trace.prefix = prefix;
  trace.overlap.ddr.prefix = prefix + "_DDR";
  trace.overlap.ddr.req_addr = ddr_req_addr;
  trace.overlap.ddr.req_size = 3;
  trace.overlap.ddr.req_id = ddr_req_id;
  trace.overlap.ddr.beat_count = 2;
  trace.overlap.mmio.prefix = prefix + "_MMIO_READ";
  trace.overlap.mmio.req_addr = mmio_read_addr;
  trace.overlap.mmio.req_size = 3;
  trace.overlap.mmio.req_id = mmio_read_id;
  trace.overlap.mmio.beat_count = 1;
  trace.overlap.ddr_master = axi_interconnect::MASTER_DCACHE_R;
  trace.overlap.mmio_master = axi_interconnect::MASTER_UNCORE_LSU_R;
  trace.mmio_write.prefix = prefix + "_MMIO_WRITE";
  trace.mmio_write.req_addr = mmio_write_addr;
  trace.mmio_write.req_size = 3;
  trace.mmio_write.req_id = mmio_write_id;
  const auto write_data = single_word_data(mmio_write_word);
  const auto write_strobe = byte_strobe(0xfu);
  trace.mmio_write.req_wdata = wide_write_words(write_data);
  trace.mmio_write.req_wstrb = write_strobe_mask(write_strobe);
  trace.mmio_write_master = axi_interconnect::MASTER_UNCORE_LSU_W;
  trace.invalidate_addr =
      (invalidate_addr == 0u) ? trace.overlap.ddr.req_addr : invalidate_addr;

  bool accepted = false;
  bool ar_seen = false;
  bool request_active = true;
  for (int cycle = 0; cycle < 80 && !ar_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    if (request_active) {
      auto &req = dut.read_ports[trace.overlap.ddr_master].req;
      req.valid = true;
      req.addr = trace.overlap.ddr.req_addr;
      req.total_size = trace.overlap.ddr.req_size;
      req.id = trace.overlap.ddr.req_id;
      req.bypass = false;
    }
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    if (request_active && dut.read_ports[trace.overlap.ddr_master].req.ready) {
      accepted = true;
      request_active = false;
    }
    if (dut.axi_ddr_io.ar.arvalid) {
      require(!dut.axi_mmio_io.ar.arvalid,
              "C++ invline cache/MMIO RW DDR AR overlapped with MMIO AR");
      trace.overlap.ddr.araddr =
          static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
      trace.overlap.ddr.arlen =
          static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
      trace.overlap.ddr.arsize =
          static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
      trace.overlap.ddr.arburst =
          static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
      trace.overlap.ddr.arid = static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
      ar_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ invline cache/MMIO RW cache read was not accepted");
  require(ar_seen, "C++ invline cache/MMIO RW cache read did not issue DDR AR");
  require(trace.overlap.ddr.beat_count ==
              static_cast<uint32_t>(trace.overlap.ddr.arlen) + 1u,
          "C++ invline cache/MMIO RW cache read beat count mismatch");

  issue_read_and_capture_ar(dut, trace.overlap.mmio, trace.overlap.mmio_master,
                            axi_interconnect::DownstreamPort::MMIO);
  issue_write_and_capture_axi(dut, trace.mmio_write, trace.mmio_write_master,
                              axi_interconnect::DownstreamPort::MMIO,
                              write_data, write_strobe);

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_line(true, trace.invalidate_addr);
  dut.axi_mmio_io.r.rvalid = true;
  dut.axi_mmio_io.r.rid = trace.overlap.mmio.arid;
  dut.axi_mmio_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_mmio_io.r.rlast = true;
  dut.axi_mmio_io.r.rdata = {};
  axi_compat::set_u32(dut.axi_mmio_io.r.rdata, 0, mmio_read_word);
  trace.overlap.mmio.rbeats[0] = axi_words(dut.axi_mmio_io.r.rdata);
  dut.axi_mmio_io.b.bvalid = true;
  dut.axi_mmio_io.b.bid = trace.mmio_write.awid;
  dut.axi_mmio_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  trace.mmio_rready_while_invalidate_pending = dut.axi_mmio_io.r.rready;
  trace.mmio_bready_while_invalidate_pending = dut.axi_mmio_io.b.bready;
  trace.overlap.mmio_rready_while_resp_stalled =
      trace.mmio_rready_while_invalidate_pending;
  require(dut.axi_mmio_io.r.rready,
          "C++ invline cache/MMIO RW MMIO R was backpressured");
  require(dut.axi_mmio_io.b.bready,
          "C++ invline cache/MMIO RW MMIO B was backpressured");
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_line_accepted(),
          "C++ invline cache/MMIO RW accepted in MMIO R/B handshake cycle");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_line(true, trace.invalidate_addr);
  dut.comb_outputs();
  require(dut.read_ports[trace.overlap.mmio_master].resp.valid,
          "C++ invline cache/MMIO RW MMIO read response was not held");
  require(dut.write_ports[trace.mmio_write_master].resp.valid,
          "C++ invline cache/MMIO RW MMIO write response was not held");
  trace.blocked_while_mmio_resp_held = !dut.llc_invalidate_line_accepted();
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_line_accepted(),
          "C++ invline cache/MMIO RW accepted while MMIO responses held");
  dut.seq();
  ++sim_time;

  trace.ddr_rready_while_mmio_resp_held = true;
  for (uint32_t beat = 0; beat < trace.overlap.ddr.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = trace.overlap.ddr.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == trace.overlap.ddr.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(ddr_beat_seed + beat * 0x100u);
    trace.overlap.ddr.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    trace.ddr_rready_while_mmio_resp_held =
        trace.ddr_rready_while_mmio_resp_held && dut.axi_ddr_io.r.rready;
    trace.overlap.ddr_rready_while_resp_stalled =
        trace.ddr_rready_while_mmio_resp_held;
    require(dut.axi_ddr_io.r.rready,
            "C++ invline cache/MMIO RW DDR R was backpressured");
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_line_accepted(),
            "C++ invline cache/MMIO RW accepted in DDR R handshake cycle");
    dut.seq();
    ++sim_time;
  }

  bool cache_resp_seen = false;
  for (int cycle = 0; cycle < 180 && !cache_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.comb_outputs();
    require(dut.read_ports[trace.overlap.mmio_master].resp.valid,
            "C++ invline cache/MMIO RW MMIO read response dropped while held");
    require(dut.write_ports[trace.mmio_write_master].resp.valid,
            "C++ invline cache/MMIO RW MMIO write response dropped while held");
    auto &cache_resp = dut.read_ports[trace.overlap.ddr_master].resp;
    if (cache_resp.valid) {
      cache_resp_seen = true;
      trace.overlap.ddr.resp_id = static_cast<uint8_t>(cache_resp.id);
      trace.overlap.ddr.resp_data = wide_read_words(cache_resp.data);
      trace.blocked_while_cache_resp_held =
          !dut.llc_invalidate_line_accepted();
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_line_accepted(),
            "C++ invline cache/MMIO RW accepted while cache response held");
    dut.seq();
    ++sim_time;
  }
  require(cache_resp_seen, "C++ invline cache/MMIO RW cache response timeout");

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_line(true, trace.invalidate_addr);
  dut.read_ports[trace.overlap.mmio_master].resp.ready = true;
  dut.comb_outputs();
  auto &mmio_read_resp = dut.read_ports[trace.overlap.mmio_master].resp;
  require(mmio_read_resp.valid,
          "C++ invline cache/MMIO RW MMIO read response not valid at retire");
  trace.overlap.mmio.resp_id = static_cast<uint8_t>(mmio_read_resp.id);
  trace.overlap.mmio.resp_data = wide_read_words(mmio_read_resp.data);
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_line_accepted(),
          "C++ invline cache/MMIO RW accepted before MMIO read retired");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_line(true, trace.invalidate_addr);
  dut.write_ports[trace.mmio_write_master].resp.ready = true;
  dut.comb_outputs();
  auto &mmio_write_resp = dut.write_ports[trace.mmio_write_master].resp;
  require(mmio_write_resp.valid,
          "C++ invline cache/MMIO RW MMIO write response not valid at retire");
  trace.mmio_write.resp_id = static_cast<uint8_t>(mmio_write_resp.id);
  trace.mmio_write.resp_code = static_cast<uint8_t>(mmio_write_resp.resp);
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_line_accepted(),
          "C++ invline cache/MMIO RW accepted before MMIO write retired");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_line(true, trace.invalidate_addr);
  dut.read_ports[trace.overlap.ddr_master].resp.ready = true;
  dut.comb_outputs();
  require(dut.read_ports[trace.overlap.ddr_master].resp.valid,
          "C++ invline cache/MMIO RW cache response not valid at retire");
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_line_accepted(),
          "C++ invline cache/MMIO RW accepted before cache response retired");
  dut.seq();
  ++sim_time;

  for (int retry = 0; retry < 160; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_addr);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    const bool accepted_now = dut.llc_invalidate_line_accepted();
    dut.seq();
    ++sim_time;
    if (accepted_now) {
      trace.accepted_after_resp_retire = true;
      dut.set_llc_invalidate_line(false, 0);
      return trace;
    }
  }
  dut.debug_print();
  require(false,
          "C++ invline cache/MMIO RW did not accept after responses retired");
  return trace;
}

DirtyVictimMmioWriteTrace run_mode1_dirty_victim_mmio_write_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  StatefulLlcTableDriver table_driver(dut.get_llc_config());

  DirtyVictimMmioWriteTrace trace{};
  trace.cache_master = axi_interconnect::MASTER_DCACHE_W;
  trace.mmio_master = axi_interconnect::MASTER_UNCORE_LSU_W;

  trace.setup0.prefix = "CPP_MODE1_DIRTY_VICTIM_SETUP0";
  trace.setup0.req_addr = 0x40001000u;
  trace.setup0.req_size = 63;
  trace.setup0.req_id = 0x5u;
  const auto setup0_data = line_write_data(0x51000000u);
  const auto setup_strobe = full_line_strobe();
  trace.setup0.req_wdata = wide_write_words(setup0_data);
  trace.setup0.req_wstrb = write_strobe_mask(setup_strobe);

  trace.setup1.prefix = "CPP_MODE1_DIRTY_VICTIM_SETUP1";
  trace.setup1.req_addr = 0x40021000u;
  trace.setup1.req_size = 63;
  trace.setup1.req_id = 0x6u;
  const auto setup1_data = line_write_data(0x61000000u);
  trace.setup1.req_wdata = wide_write_words(setup1_data);
  trace.setup1.req_wstrb = write_strobe_mask(setup_strobe);

  trace.cache.prefix = "CPP_MODE1_DIRTY_VICTIM_CACHE_WRITE";
  trace.cache.req_addr = 0x40041000u;
  trace.cache.req_size = 63;
  trace.cache.req_id = 0x7u;
  const auto cache_data = line_write_data(0x71000000u);
  trace.cache.req_wdata = wide_write_words(cache_data);
  trace.cache.req_wstrb = write_strobe_mask(setup_strobe);
  trace.invalidate_line_addr = trace.cache.req_addr;

  trace.writeback.prefix = "CPP_MODE1_DIRTY_VICTIM_WB";
  trace.writeback.req_addr = trace.setup0.req_addr;
  trace.writeback.req_size = 63;
  trace.writeback.req_id = 0;
  trace.writeback.req_wdata = wide_write_words(setup0_data);
  trace.writeback.req_wstrb = write_strobe_mask(setup_strobe);

  trace.mmio.prefix = "CPP_MODE1_DIRTY_VICTIM_MMIO";
  trace.mmio.req_addr = 0x100000a0u;
  trace.mmio.req_size = 3;
  trace.mmio.req_id = 0x8u;
  const auto mmio_data = single_word_data(0xface00a0u);
  const auto mmio_strobe = byte_strobe(0xfu);
  trace.mmio.req_wdata = wide_write_words(mmio_data);
  trace.mmio.req_wstrb = write_strobe_mask(mmio_strobe);

  issue_cache_write_and_wait_response(dut, table_driver, trace.setup0,
                                      trace.cache_master, setup0_data,
                                      setup_strobe);
  issue_cache_write_and_wait_response(dut, table_driver, trace.setup1,
                                      trace.cache_master, setup1_data,
                                      setup_strobe);

  bool accepted = false;
  bool aw_seen = false;
  bool request_active = true;
  for (int cycle = 0; cycle < 240 && !aw_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    const bool ready_snapshot = dut.write_ports[trace.cache_master].req.ready;
    if (request_active) {
      auto &req = dut.write_ports[trace.cache_master].req;
      req.valid = true;
      req.addr = trace.cache.req_addr;
      req.total_size = trace.cache.req_size;
      req.id = trace.cache.req_id;
      req.wdata = cache_data;
      req.wstrb = setup_strobe;
      req.bypass = false;
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    if (request_active && ready_snapshot) {
      accepted = true;
      request_active = false;
    }
    if (dut.axi_ddr_io.aw.awvalid) {
      require(!dut.axi_mmio_io.aw.awvalid,
              "C++ dirty victim writeback DDR AW overlapped with MMIO AW");
      trace.writeback.awaddr =
          static_cast<uint32_t>(dut.axi_ddr_io.aw.awaddr);
      trace.writeback.awlen = static_cast<uint8_t>(dut.axi_ddr_io.aw.awlen);
      trace.writeback.awsize = static_cast<uint8_t>(dut.axi_ddr_io.aw.awsize);
      trace.writeback.awburst =
          static_cast<uint8_t>(dut.axi_ddr_io.aw.awburst);
      trace.writeback.awid = static_cast<uint8_t>(dut.axi_ddr_io.aw.awid);
      aw_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ dirty victim cache write was not accepted");
  require(aw_seen, "C++ dirty victim writeback did not issue DDR AW");
  trace.writeback.beat_count = static_cast<uint32_t>(trace.writeback.awlen) + 1u;

  for (uint32_t beat = 0; beat < trace.writeback.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    require(dut.axi_ddr_io.w.wvalid,
            "C++ dirty victim writeback DDR W did not become valid");
    trace.writeback.wbeats[beat] = axi_words(dut.axi_ddr_io.w.wdata);
    trace.writeback.wstrb[beat] = axi_strobe_mask(dut.axi_ddr_io.w.wstrb);
    trace.writeback.wlast[beat] = dut.axi_ddr_io.w.wlast ? 1 : 0;
    dut.seq();
    ++sim_time;
  }

  issue_write_and_capture_axi(dut, trace.mmio, trace.mmio_master,
                              axi_interconnect::DownstreamPort::MMIO,
                              mmio_data, mmio_strobe);

  clear_inputs(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.axi_mmio_io.b.bvalid = true;
  dut.axi_mmio_io.b.bid = trace.mmio.awid;
  dut.axi_mmio_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  trace.mmio_bready_while_resp_stalled = dut.axi_mmio_io.b.bready;
  require(trace.mmio_bready_while_resp_stalled,
          "C++ dirty victim/MMIO B was backpressured");
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ dirty victim accepted invalidate_all in MMIO B handshake");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.comb_outputs();
  dut.comb_inputs();
  table_driver.observe(dut);
  require(dut.write_ports[trace.mmio_master].resp.valid,
          "C++ dirty victim/MMIO response was not held");
  require(!dut.write_ports[trace.cache_master].resp.valid,
          "C++ dirty victim cache response appeared before victim B");
  trace.blocked_while_mmio_resp_held = !dut.llc_invalidate_all_accepted();
  require(trace.blocked_while_mmio_resp_held,
          "C++ dirty victim accepted invalidate_all while MMIO response held");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.axi_ddr_io.b.bvalid = true;
  dut.axi_ddr_io.b.bid = trace.writeback.awid;
  dut.axi_ddr_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  trace.ddr_bready_while_resp_stalled = dut.axi_ddr_io.b.bready;
  require(trace.ddr_bready_while_resp_stalled,
          "C++ dirty victim DDR B was backpressured");
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ dirty victim accepted invalidate_all in victim B handshake");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.write_ports[trace.mmio_master].resp.ready = true;
  dut.comb_outputs();
  auto &mmio_resp = dut.write_ports[trace.mmio_master].resp;
  require(mmio_resp.valid,
          "C++ dirty victim/MMIO response dropped before ready");
  trace.mmio.resp_id = static_cast<uint8_t>(mmio_resp.id);
  trace.mmio.resp_code = static_cast<uint8_t>(mmio_resp.resp);
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ dirty victim accepted invalidate_all before MMIO response retired");
  dut.seq();
  ++sim_time;

  bool cache_resp_seen = false;
  for (int cycle = 0; cycle < 240 && !cache_resp_seen; ++cycle) {
    clear_inputs(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    auto &resp = dut.write_ports[trace.cache_master].resp;
    if (resp.valid) {
      cache_resp_seen = true;
      trace.cache.resp_id = static_cast<uint8_t>(resp.id);
      trace.cache.resp_code = static_cast<uint8_t>(resp.resp);
      trace.blocked_while_cache_resp_held = !dut.llc_invalidate_all_accepted();
      require(trace.blocked_while_cache_resp_held,
              "C++ dirty victim accepted invalidate_all while cache response held");
      resp.ready = true;
      dut.comb_outputs();
      require(resp.valid,
              "C++ dirty victim cache response dropped before ready");
      require(!dut.llc_invalidate_all_accepted(),
              "C++ dirty victim accepted invalidate_all before cache response retired");
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    dut.seq();
    ++sim_time;
  }
  require(cache_resp_seen, "C++ dirty victim cache response timeout");

  for (int retry = 0; retry < 32; ++retry) {
    clear_inputs(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ dirty victim accepted invalidate_all with dirty resident line");
    dut.seq();
    ++sim_time;
  }
  trace.accepted_after_resp_retire = false;
  dut.set_llc_invalidate_all(false);

  bool invalidate_line_accepted = false;
  for (int retry = 0; retry < 96 && !invalidate_line_accepted; ++retry) {
    clear_inputs(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_line_addr);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    if (dut.llc_invalidate_line_accepted()) {
      invalidate_line_accepted = true;
    }
    dut.seq();
    ++sim_time;
  }
  trace.invalidate_line_accepted_after_resp_retire = invalidate_line_accepted;
  require(invalidate_line_accepted,
          "C++ dirty victim invalidate_line did not accept after drain");
  dut.set_llc_invalidate_line(false, 0);
  return trace;
}

DirtyVictimMmioReadTrace run_mode1_dirty_victim_mmio_read_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  StatefulLlcTableDriver table_driver(dut.get_llc_config());

  DirtyVictimMmioReadTrace trace{};
  trace.cache_master = axi_interconnect::MASTER_DCACHE_W;
  trace.mmio_master = axi_interconnect::MASTER_UNCORE_LSU_R;

  trace.setup0.prefix = "CPP_MODE1_DIRTY_VICTIM_READ_SETUP0";
  trace.setup0.req_addr = 0x40001000u;
  trace.setup0.req_size = 63;
  trace.setup0.req_id = 0x5u;
  const auto setup0_data = line_write_data(0x52000000u);
  const auto setup_strobe = full_line_strobe();
  trace.setup0.req_wdata = wide_write_words(setup0_data);
  trace.setup0.req_wstrb = write_strobe_mask(setup_strobe);

  trace.setup1.prefix = "CPP_MODE1_DIRTY_VICTIM_READ_SETUP1";
  trace.setup1.req_addr = 0x40021000u;
  trace.setup1.req_size = 63;
  trace.setup1.req_id = 0x6u;
  const auto setup1_data = line_write_data(0x62000000u);
  trace.setup1.req_wdata = wide_write_words(setup1_data);
  trace.setup1.req_wstrb = write_strobe_mask(setup_strobe);

  trace.cache.prefix = "CPP_MODE1_DIRTY_VICTIM_READ_CACHE_WRITE";
  trace.cache.req_addr = 0x40041000u;
  trace.cache.req_size = 63;
  trace.cache.req_id = 0x7u;
  const auto cache_data = line_write_data(0x72000000u);
  trace.cache.req_wdata = wide_write_words(cache_data);
  trace.cache.req_wstrb = write_strobe_mask(setup_strobe);
  trace.invalidate_line_addr = trace.cache.req_addr;

  trace.writeback.prefix = "CPP_MODE1_DIRTY_VICTIM_READ_WB";
  trace.writeback.req_addr = trace.setup0.req_addr;
  trace.writeback.req_size = 63;
  trace.writeback.req_id = 0;
  trace.writeback.req_wdata = wide_write_words(setup0_data);
  trace.writeback.req_wstrb = write_strobe_mask(setup_strobe);

  trace.mmio.prefix = "CPP_MODE1_DIRTY_VICTIM_MMIO_READ";
  trace.mmio.req_addr = 0x100000d0u;
  trace.mmio.req_size = 3;
  trace.mmio.req_id = 0x9u;
  trace.mmio.beat_count = 1;

  issue_cache_write_and_wait_response(dut, table_driver, trace.setup0,
                                      trace.cache_master, setup0_data,
                                      setup_strobe);
  issue_cache_write_and_wait_response(dut, table_driver, trace.setup1,
                                      trace.cache_master, setup1_data,
                                      setup_strobe);

  bool accepted = false;
  bool aw_seen = false;
  bool request_active = true;
  for (int cycle = 0; cycle < 240 && !aw_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    const bool ready_snapshot = dut.write_ports[trace.cache_master].req.ready;
    if (request_active) {
      auto &req = dut.write_ports[trace.cache_master].req;
      req.valid = true;
      req.addr = trace.cache.req_addr;
      req.total_size = trace.cache.req_size;
      req.id = trace.cache.req_id;
      req.wdata = cache_data;
      req.wstrb = setup_strobe;
      req.bypass = false;
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    if (request_active && ready_snapshot) {
      accepted = true;
      request_active = false;
    }
    if (dut.axi_ddr_io.aw.awvalid) {
      require(!dut.axi_mmio_io.aw.awvalid,
              "C++ dirty victim/read writeback DDR AW overlapped with MMIO AW");
      trace.writeback.awaddr =
          static_cast<uint32_t>(dut.axi_ddr_io.aw.awaddr);
      trace.writeback.awlen = static_cast<uint8_t>(dut.axi_ddr_io.aw.awlen);
      trace.writeback.awsize = static_cast<uint8_t>(dut.axi_ddr_io.aw.awsize);
      trace.writeback.awburst =
          static_cast<uint8_t>(dut.axi_ddr_io.aw.awburst);
      trace.writeback.awid = static_cast<uint8_t>(dut.axi_ddr_io.aw.awid);
      aw_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ dirty victim/read cache write was not accepted");
  require(aw_seen, "C++ dirty victim/read writeback did not issue DDR AW");
  trace.writeback.beat_count =
      static_cast<uint32_t>(trace.writeback.awlen) + 1u;

  for (uint32_t beat = 0; beat < trace.writeback.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    require(dut.axi_ddr_io.w.wvalid,
            "C++ dirty victim/read writeback DDR W did not become valid");
    trace.writeback.wbeats[beat] = axi_words(dut.axi_ddr_io.w.wdata);
    trace.writeback.wstrb[beat] = axi_strobe_mask(dut.axi_ddr_io.w.wstrb);
    trace.writeback.wlast[beat] = dut.axi_ddr_io.w.wlast ? 1 : 0;
    dut.seq();
    ++sim_time;
  }

  issue_read_and_capture_ar(dut, trace.mmio, trace.mmio_master,
                            axi_interconnect::DownstreamPort::MMIO);

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.axi_mmio_io.r.rvalid = true;
  dut.axi_mmio_io.r.rid = trace.mmio.arid;
  dut.axi_mmio_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_mmio_io.r.rlast = true;
  dut.axi_mmio_io.r.rdata = {};
  axi_compat::set_u32(dut.axi_mmio_io.r.rdata, 0, 0xcafe00d0u);
  trace.mmio.rbeats[0] = axi_words(dut.axi_mmio_io.r.rdata);
  dut.comb_outputs();
  trace.mmio_rready_while_resp_stalled = dut.axi_mmio_io.r.rready;
  require(trace.mmio_rready_while_resp_stalled,
          "C++ dirty victim/read MMIO R was backpressured");
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ dirty victim/read accepted invalidate_all in MMIO R handshake");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.comb_outputs();
  require(dut.read_ports[trace.mmio_master].resp.valid,
          "C++ dirty victim/read MMIO response was not held");
  require(!dut.write_ports[trace.cache_master].resp.valid,
          "C++ dirty victim/read cache response appeared before victim B");
  trace.blocked_while_mmio_resp_held = !dut.llc_invalidate_all_accepted();
  dut.comb_inputs();
  table_driver.observe(dut);
  require(trace.blocked_while_mmio_resp_held,
          "C++ dirty victim/read accepted invalidate_all while MMIO response held");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.axi_ddr_io.b.bvalid = true;
  dut.axi_ddr_io.b.bid = trace.writeback.awid;
  dut.axi_ddr_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  trace.ddr_bready_while_resp_stalled = dut.axi_ddr_io.b.bready;
  require(trace.ddr_bready_while_resp_stalled,
          "C++ dirty victim/read DDR B was backpressured");
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ dirty victim/read accepted invalidate_all in victim B handshake");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.read_ports[trace.mmio_master].resp.ready = true;
  dut.comb_outputs();
  auto &mmio_resp = dut.read_ports[trace.mmio_master].resp;
  require(mmio_resp.valid,
          "C++ dirty victim/read MMIO response dropped before ready");
  trace.mmio.resp_id = static_cast<uint8_t>(mmio_resp.id);
  trace.mmio.resp_data = wide_read_words(mmio_resp.data);
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ dirty victim/read accepted invalidate_all before MMIO retire");
  dut.seq();
  ++sim_time;

  bool cache_resp_seen = false;
  for (int cycle = 0; cycle < 240 && !cache_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    auto &resp = dut.write_ports[trace.cache_master].resp;
    if (resp.valid) {
      cache_resp_seen = true;
      trace.cache.resp_id = static_cast<uint8_t>(resp.id);
      trace.cache.resp_code = static_cast<uint8_t>(resp.resp);
      trace.blocked_while_cache_resp_held = !dut.llc_invalidate_all_accepted();
      require(trace.blocked_while_cache_resp_held,
              "C++ dirty victim/read accepted invalidate_all while cache response held");
      resp.ready = true;
      dut.comb_outputs();
      require(resp.valid,
              "C++ dirty victim/read cache response dropped before ready");
      require(!dut.llc_invalidate_all_accepted(),
              "C++ dirty victim/read accepted invalidate_all before cache retire");
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    dut.seq();
    ++sim_time;
  }
  require(cache_resp_seen, "C++ dirty victim/read cache response timeout");

  for (int retry = 0; retry < 32; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ dirty victim/read accepted invalidate_all with dirty resident line");
    dut.seq();
    ++sim_time;
  }
  trace.accepted_after_resp_retire = false;
  dut.set_llc_invalidate_all(false);

  bool invalidate_line_accepted = false;
  for (int retry = 0; retry < 96 && !invalidate_line_accepted; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_line_addr);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    if (dut.llc_invalidate_line_accepted()) {
      invalidate_line_accepted = true;
    }
    dut.seq();
    ++sim_time;
  }
  trace.invalidate_line_accepted_after_resp_retire = invalidate_line_accepted;
  require(invalidate_line_accepted,
          "C++ dirty victim/read invalidate_line did not accept after drain");
  dut.set_llc_invalidate_line(false, 0);
  return trace;
}

DirtyVictimMmioReadWriteTrace
run_mode1_dirty_victim_mmio_read_write_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);
  StatefulLlcTableDriver table_driver(dut.get_llc_config());

  DirtyVictimMmioReadWriteTrace trace{};
  trace.cache_master = axi_interconnect::MASTER_DCACHE_W;
  trace.mmio_read_master = axi_interconnect::MASTER_UNCORE_LSU_R;
  trace.mmio_write_master = axi_interconnect::MASTER_UNCORE_LSU_W;

  trace.setup0.prefix = "CPP_MODE1_DIRTY_VICTIM_RW_SETUP0";
  trace.setup0.req_addr = 0x40001800u;
  trace.setup0.req_size = 63;
  trace.setup0.req_id = 0x5u;
  const auto setup0_data = line_write_data(0x53000000u);
  const auto setup_strobe = full_line_strobe();
  trace.setup0.req_wdata = wide_write_words(setup0_data);
  trace.setup0.req_wstrb = write_strobe_mask(setup_strobe);

  trace.setup1.prefix = "CPP_MODE1_DIRTY_VICTIM_RW_SETUP1";
  trace.setup1.req_addr = 0x40021800u;
  trace.setup1.req_size = 63;
  trace.setup1.req_id = 0x6u;
  const auto setup1_data = line_write_data(0x63000000u);
  trace.setup1.req_wdata = wide_write_words(setup1_data);
  trace.setup1.req_wstrb = write_strobe_mask(setup_strobe);

  trace.cache.prefix = "CPP_MODE1_DIRTY_VICTIM_RW_CACHE_WRITE";
  trace.cache.req_addr = 0x40041800u;
  trace.cache.req_size = 63;
  trace.cache.req_id = 0x7u;
  const auto cache_data = line_write_data(0x73000000u);
  trace.cache.req_wdata = wide_write_words(cache_data);
  trace.cache.req_wstrb = write_strobe_mask(setup_strobe);
  trace.invalidate_line_addr = trace.cache.req_addr;

  trace.writeback.prefix = "CPP_MODE1_DIRTY_VICTIM_RW_WB";
  trace.writeback.req_addr = trace.setup0.req_addr;
  trace.writeback.req_size = 63;
  trace.writeback.req_id = 0;
  trace.writeback.req_wdata = wide_write_words(setup0_data);
  trace.writeback.req_wstrb = write_strobe_mask(setup_strobe);

  trace.mmio_read.prefix = "CPP_MODE1_DIRTY_VICTIM_RW_MMIO_READ";
  trace.mmio_read.req_addr = 0x10000380u;
  trace.mmio_read.req_size = 3;
  trace.mmio_read.req_id = 0xAu;
  trace.mmio_read.beat_count = 1;

  trace.mmio_write.prefix = "CPP_MODE1_DIRTY_VICTIM_RW_MMIO_WRITE";
  trace.mmio_write.req_addr = 0x100003c0u;
  trace.mmio_write.req_size = 3;
  trace.mmio_write.req_id = 0xBu;
  const auto mmio_write_data = single_word_data(0xface03c0u);
  const auto mmio_write_strobe = byte_strobe(0xfu);
  trace.mmio_write.req_wdata = wide_write_words(mmio_write_data);
  trace.mmio_write.req_wstrb = write_strobe_mask(mmio_write_strobe);

  issue_cache_write_and_wait_response(dut, table_driver, trace.setup0,
                                      trace.cache_master, setup0_data,
                                      setup_strobe);
  issue_cache_write_and_wait_response(dut, table_driver, trace.setup1,
                                      trace.cache_master, setup1_data,
                                      setup_strobe);

  bool accepted = false;
  bool aw_seen = false;
  bool request_active = true;
  for (int cycle = 0; cycle < 240 && !aw_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    const bool ready_snapshot = dut.write_ports[trace.cache_master].req.ready;
    if (request_active) {
      auto &req = dut.write_ports[trace.cache_master].req;
      req.valid = true;
      req.addr = trace.cache.req_addr;
      req.total_size = trace.cache.req_size;
      req.id = trace.cache.req_id;
      req.wdata = cache_data;
      req.wstrb = setup_strobe;
      req.bypass = false;
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    if (request_active && ready_snapshot) {
      accepted = true;
      request_active = false;
    }
    if (dut.axi_ddr_io.aw.awvalid) {
      require(!dut.axi_mmio_io.aw.awvalid,
              "C++ dirty victim RW writeback DDR AW overlapped with MMIO AW");
      trace.writeback.awaddr =
          static_cast<uint32_t>(dut.axi_ddr_io.aw.awaddr);
      trace.writeback.awlen = static_cast<uint8_t>(dut.axi_ddr_io.aw.awlen);
      trace.writeback.awsize = static_cast<uint8_t>(dut.axi_ddr_io.aw.awsize);
      trace.writeback.awburst =
          static_cast<uint8_t>(dut.axi_ddr_io.aw.awburst);
      trace.writeback.awid = static_cast<uint8_t>(dut.axi_ddr_io.aw.awid);
      aw_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ dirty victim RW cache write was not accepted");
  require(aw_seen, "C++ dirty victim RW writeback did not issue DDR AW");
  trace.writeback.beat_count =
      static_cast<uint32_t>(trace.writeback.awlen) + 1u;

  for (uint32_t beat = 0; beat < trace.writeback.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    require(dut.axi_ddr_io.w.wvalid,
            "C++ dirty victim RW writeback DDR W did not become valid");
    trace.writeback.wbeats[beat] = axi_words(dut.axi_ddr_io.w.wdata);
    trace.writeback.wstrb[beat] = axi_strobe_mask(dut.axi_ddr_io.w.wstrb);
    trace.writeback.wlast[beat] = dut.axi_ddr_io.w.wlast ? 1 : 0;
    dut.seq();
    ++sim_time;
  }

  issue_read_and_capture_ar(dut, trace.mmio_read, trace.mmio_read_master,
                            axi_interconnect::DownstreamPort::MMIO);
  issue_write_and_capture_axi(dut, trace.mmio_write, trace.mmio_write_master,
                              axi_interconnect::DownstreamPort::MMIO,
                              mmio_write_data, mmio_write_strobe);

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.axi_mmio_io.r.rvalid = true;
  dut.axi_mmio_io.r.rid = trace.mmio_read.arid;
  dut.axi_mmio_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_mmio_io.r.rlast = true;
  dut.axi_mmio_io.r.rdata = {};
  axi_compat::set_u32(dut.axi_mmio_io.r.rdata, 0, 0xcafe0380u);
  trace.mmio_read.rbeats[0] = axi_words(dut.axi_mmio_io.r.rdata);
  dut.axi_mmio_io.b.bvalid = true;
  dut.axi_mmio_io.b.bid = trace.mmio_write.awid;
  dut.axi_mmio_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  trace.mmio_rready_while_resp_stalled = dut.axi_mmio_io.r.rready;
  trace.mmio_bready_while_resp_stalled = dut.axi_mmio_io.b.bready;
  require(trace.mmio_rready_while_resp_stalled,
          "C++ dirty victim RW MMIO R was backpressured");
  require(trace.mmio_bready_while_resp_stalled,
          "C++ dirty victim RW MMIO B was backpressured");
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ dirty victim RW accepted invalidate_all in MMIO R/B handshake");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.comb_outputs();
  require(dut.read_ports[trace.mmio_read_master].resp.valid,
          "C++ dirty victim RW MMIO read response was not held");
  require(dut.write_ports[trace.mmio_write_master].resp.valid,
          "C++ dirty victim RW MMIO write response was not held");
  require(!dut.write_ports[trace.cache_master].resp.valid,
          "C++ dirty victim RW cache response appeared before victim B");
  trace.blocked_while_mmio_resp_held = !dut.llc_invalidate_all_accepted();
  require(trace.blocked_while_mmio_resp_held,
          "C++ dirty victim RW accepted invalidate_all while MMIO responses held");
  dut.comb_inputs();
  table_driver.observe(dut);
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.axi_ddr_io.b.bvalid = true;
  dut.axi_ddr_io.b.bid = trace.writeback.awid;
  dut.axi_ddr_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  trace.ddr_bready_while_resp_stalled = dut.axi_ddr_io.b.bready;
  require(trace.ddr_bready_while_resp_stalled,
          "C++ dirty victim RW DDR B was backpressured");
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ dirty victim RW accepted invalidate_all in victim B handshake");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.read_ports[trace.mmio_read_master].resp.ready = true;
  dut.comb_outputs();
  auto &mmio_read_resp = dut.read_ports[trace.mmio_read_master].resp;
  require(mmio_read_resp.valid,
          "C++ dirty victim RW MMIO read response dropped before ready");
  trace.mmio_read.resp_id = static_cast<uint8_t>(mmio_read_resp.id);
  trace.mmio_read.resp_data = wide_read_words(mmio_read_resp.data);
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ dirty victim RW accepted invalidate_all before MMIO read retire");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  set_downstream_ready(dut);
  table_driver.drive(dut);
  dut.set_llc_invalidate_all(true);
  dut.write_ports[trace.mmio_write_master].resp.ready = true;
  dut.comb_outputs();
  auto &mmio_write_resp = dut.write_ports[trace.mmio_write_master].resp;
  require(mmio_write_resp.valid,
          "C++ dirty victim RW MMIO write response dropped before ready");
  trace.mmio_write.resp_id = static_cast<uint8_t>(mmio_write_resp.id);
  trace.mmio_write.resp_code = static_cast<uint8_t>(mmio_write_resp.resp);
  dut.comb_inputs();
  table_driver.observe(dut);
  require(!dut.llc_invalidate_all_accepted(),
          "C++ dirty victim RW accepted invalidate_all before MMIO write retire");
  dut.seq();
  ++sim_time;

  bool cache_resp_seen = false;
  for (int cycle = 0; cycle < 240 && !cache_resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    auto &resp = dut.write_ports[trace.cache_master].resp;
    if (resp.valid) {
      cache_resp_seen = true;
      trace.cache.resp_id = static_cast<uint8_t>(resp.id);
      trace.cache.resp_code = static_cast<uint8_t>(resp.resp);
      trace.blocked_while_cache_resp_held = !dut.llc_invalidate_all_accepted();
      require(trace.blocked_while_cache_resp_held,
              "C++ dirty victim RW accepted invalidate_all while cache response held");
      resp.ready = true;
      dut.comb_outputs();
      require(resp.valid,
              "C++ dirty victim RW cache response dropped before ready");
      require(!dut.llc_invalidate_all_accepted(),
              "C++ dirty victim RW accepted invalidate_all before cache retire");
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    dut.seq();
    ++sim_time;
  }
  require(cache_resp_seen, "C++ dirty victim RW cache response timeout");

  for (int retry = 0; retry < 32; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_all(true);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.llc_invalidate_all_accepted(),
            "C++ dirty victim RW accepted invalidate_all with dirty resident line");
    dut.seq();
    ++sim_time;
  }
  trace.accepted_after_resp_retire = false;
  dut.set_llc_invalidate_all(false);

  bool invalidate_line_accepted = false;
  for (int retry = 0; retry < 96 && !invalidate_line_accepted; ++retry) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.set_llc_invalidate_line(true, trace.invalidate_line_addr);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    if (dut.llc_invalidate_line_accepted()) {
      invalidate_line_accepted = true;
    }
    dut.seq();
    ++sim_time;
  }
  trace.invalidate_line_accepted_after_resp_retire = invalidate_line_accepted;
  require(invalidate_line_accepted,
          "C++ dirty victim RW invalidate_line did not accept after drain");
  dut.set_llc_invalidate_line(false, 0);
  return trace;
}

Mode2MappedLocalTrace run_mode2_mapped_local_write_read_trace(
    const std::string &prefix = "CPP_MODE2_MAPPED_LOCAL",
    uint32_t write_addr = 0x30002000u, uint8_t write_size = 63,
    uint8_t write_id = 0x9u,
    const axi_interconnect::WideWriteData_t &write_data =
        line_write_data(0x82000000u),
    const axi_interconnect::WideWriteStrb_t &write_strobe =
        full_line_strobe(),
    uint32_t read_addr = 0x30002008u, uint8_t read_size = 15,
    uint8_t read_id = 0xAu) {
  axi_interconnect::AXI_Interconnect dut;
  init_mapped_trace_dut(dut);
  clear_inputs(dut);
  StatefulLlcTableDriver table_driver(dut.get_llc_config());

  Mode2MappedLocalTrace trace{};
  trace.prefix = prefix;
  trace.write_master = axi_interconnect::MASTER_DCACHE_W;
  trace.read_master = axi_interconnect::MASTER_DCACHE_R;

  trace.write.prefix = prefix + "_WRITE";
  trace.write.req_addr = write_addr;
  trace.write.req_size = write_size;
  trace.write.req_id = write_id;
  trace.write.req_wdata = wide_write_words(write_data);
  trace.write.req_wstrb = write_strobe_mask(write_strobe);

  trace.read.prefix = prefix + "_READ";
  trace.read.req_addr = read_addr;
  trace.read.req_size = read_size;
  trace.read.req_id = read_id;
  trace.read.beat_count = 0;

  issue_cache_write_and_wait_response(dut, table_driver, trace.write,
                                      trace.write_master, write_data,
                                      write_strobe);
  issue_mapped_read_and_wait_response(dut, table_driver, trace.read,
                                      trace.read_master);
  return trace;
}

SameMasterReadTrace run_same_master_read_order_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);

  SameMasterReadTrace trace{};
  trace.master = axi_interconnect::MASTER_DCACHE_R;
  trace.older.prefix = "CPP_MODE0_SAME_MASTER_READ0";
  trace.older.req_addr = 0x40002000u;
  trace.older.req_size = 3;
  trace.older.req_id = 0x6u;
  trace.older.beat_count = 1;
  trace.newer.prefix = "CPP_MODE0_SAME_MASTER_READ1";
  trace.newer.req_addr = 0x40002020u;
  trace.newer.req_size = 3;
  trace.newer.req_id = 0x7u;
  trace.newer.beat_count = 1;

  issue_read_and_capture_ar(dut, trace.older, trace.master,
                            axi_interconnect::DownstreamPort::DDR);
  issue_read_and_capture_ar(dut, trace.newer, trace.master,
                            axi_interconnect::DownstreamPort::DDR);
  require(trace.older.arid != trace.newer.arid,
          "C++ same-master read trace reused a downstream AXI ID");

  idle_request_outputs(dut);
  dut.axi_ddr_io.r.rvalid = true;
  dut.axi_ddr_io.r.rid = trace.newer.arid;
  dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_ddr_io.r.rlast = true;
  dut.axi_ddr_io.r.rdata = ddr_read_beat(0x2200u);
  trace.newer.rbeats[0] = axi_words(dut.axi_ddr_io.r.rdata);
  dut.comb_outputs();
  trace.newer_rready_while_resp_stalled = dut.axi_ddr_io.r.rready;
  require(trace.newer_rready_while_resp_stalled,
          "C++ same-master newer R was backpressured");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  dut.comb_outputs();
  require(dut.read_ports[trace.master].resp.valid,
          "C++ same-master newer response was not held");
  require(dut.read_ports[trace.master].resp.id == trace.newer.req_id,
          "C++ same-master newer response ID mismatch before older R");

  idle_request_outputs(dut);
  dut.axi_ddr_io.r.rvalid = true;
  dut.axi_ddr_io.r.rid = trace.older.arid;
  dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_ddr_io.r.rlast = true;
  dut.axi_ddr_io.r.rdata = ddr_read_beat(0x1100u);
  trace.older.rbeats[0] = axi_words(dut.axi_ddr_io.r.rdata);
  dut.comb_outputs();
  trace.older_rready_while_resp_stalled = dut.axi_ddr_io.r.rready;
  require(trace.older_rready_while_resp_stalled,
          "C++ same-master older R was backpressured");
  require(dut.read_ports[trace.master].resp.valid &&
              dut.read_ports[trace.master].resp.id == trace.newer.req_id,
          "C++ same-master held response changed before older R edge");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  dut.comb_outputs();
  require(dut.read_ports[trace.master].resp.valid &&
              dut.read_ports[trace.master].resp.id == trace.newer.req_id,
          "C++ same-master held response changed after older R completion");

  capture_read_response(dut, trace.newer, trace.master);
  capture_read_response(dut, trace.older, trace.master);
  return trace;
}

SameMasterWriteTrace run_same_master_write_order_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);

  SameMasterWriteTrace trace{};
  trace.master = axi_interconnect::MASTER_DCACHE_W;
  trace.older.prefix = "CPP_MODE0_SAME_MASTER_WRITE0";
  trace.older.req_addr = 0x40002400u;
  trace.older.req_size = 3;
  trace.older.req_id = 0x6u;
  const auto older_data = single_word_data(0x66002400u);
  const auto older_strobe = byte_strobe(0xfu);
  trace.older.req_wdata = wide_write_words(older_data);
  trace.older.req_wstrb = write_strobe_mask(older_strobe);
  trace.newer.prefix = "CPP_MODE0_SAME_MASTER_WRITE1";
  trace.newer.req_addr = 0x40002420u;
  trace.newer.req_size = 3;
  trace.newer.req_id = 0x7u;
  const auto newer_data = single_word_data(0x77002420u);
  const auto newer_strobe = byte_strobe(0xfu);
  trace.newer.req_wdata = wide_write_words(newer_data);
  trace.newer.req_wstrb = write_strobe_mask(newer_strobe);

  issue_write_and_capture_axi(dut, trace.older, trace.master,
                              axi_interconnect::DownstreamPort::DDR,
                              older_data, older_strobe);
  issue_write_and_capture_axi(dut, trace.newer, trace.master,
                              axi_interconnect::DownstreamPort::DDR,
                              newer_data, newer_strobe);
  require(trace.older.awid != trace.newer.awid,
          "C++ same-master write trace reused a downstream AXI ID");

  idle_request_outputs(dut);
  dut.axi_ddr_io.b.bvalid = true;
  dut.axi_ddr_io.b.bid = trace.newer.awid;
  dut.axi_ddr_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  trace.newer_bready_while_resp_stalled = dut.axi_ddr_io.b.bready;
  require(trace.newer_bready_while_resp_stalled,
          "C++ same-master newer B was backpressured");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  dut.comb_outputs();
  require(dut.write_ports[trace.master].resp.valid,
          "C++ same-master newer write response was not held");
  require(dut.write_ports[trace.master].resp.id == trace.newer.req_id,
          "C++ same-master newer write response ID mismatch before older B");

  idle_request_outputs(dut);
  dut.axi_ddr_io.b.bvalid = true;
  dut.axi_ddr_io.b.bid = trace.older.awid;
  dut.axi_ddr_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  trace.older_bready_while_resp_stalled = dut.axi_ddr_io.b.bready;
  require(trace.older_bready_while_resp_stalled,
          "C++ same-master older B was backpressured");
  require(dut.write_ports[trace.master].resp.valid &&
              dut.write_ports[trace.master].resp.id == trace.newer.req_id,
          "C++ same-master held write response changed before older B edge");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  dut.comb_outputs();
  require(dut.write_ports[trace.master].resp.valid &&
              dut.write_ports[trace.master].resp.id == trace.newer.req_id,
          "C++ same-master held write response changed after older B completion");

  capture_write_response(dut, trace.newer, trace.master);
  capture_write_response(dut, trace.older, trace.master);
  return trace;
}

ReadReuseTrace run_read_reuse_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);

  ReadReuseTrace trace{};
  trace.master = axi_interconnect::MASTER_DCACHE_R;
  trace.first.prefix = "CPP_MODE0_READ_REUSE0";
  trace.first.req_addr = 0x40003000u;
  trace.first.req_size = 3;
  trace.first.req_id = 0x8u;
  trace.first.beat_count = 1;
  trace.second.prefix = "CPP_MODE0_READ_REUSE1";
  trace.second.req_addr = 0x40003020u;
  trace.second.req_size = 3;
  trace.second.req_id = 0x9u;
  trace.second.beat_count = 1;

  issue_read_and_capture_ar(dut, trace.first, trace.master,
                            axi_interconnect::DownstreamPort::DDR);
  idle_request_outputs(dut);
  dut.axi_ddr_io.r.rvalid = true;
  dut.axi_ddr_io.r.rid = trace.first.arid;
  dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_ddr_io.r.rlast = true;
  dut.axi_ddr_io.r.rdata = ddr_read_beat(0x3300u);
  trace.first.rbeats[0] = axi_words(dut.axi_ddr_io.r.rdata);
  dut.comb_outputs();
  trace.first_rready = dut.axi_ddr_io.r.rready;
  require(trace.first_rready, "C++ read-reuse first R was backpressured");
  dut.seq();
  ++sim_time;
  capture_read_response(dut, trace.first, trace.master);

  issue_read_and_capture_ar(dut, trace.second, trace.master,
                            axi_interconnect::DownstreamPort::DDR);
  require(trace.second.arid == trace.first.arid,
          "C++ read-reuse second AR did not reuse retired AXI ID");
  idle_request_outputs(dut);
  dut.axi_ddr_io.r.rvalid = true;
  dut.axi_ddr_io.r.rid = trace.second.arid;
  dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_ddr_io.r.rlast = true;
  dut.axi_ddr_io.r.rdata = ddr_read_beat(0x4400u);
  trace.second.rbeats[0] = axi_words(dut.axi_ddr_io.r.rdata);
  dut.comb_outputs();
  trace.second_rready = dut.axi_ddr_io.r.rready;
  require(trace.second_rready, "C++ read-reuse second R was backpressured");
  dut.seq();
  ++sim_time;
  capture_read_response(dut, trace.second, trace.master);

  return trace;
}

bool enqueue_write(axi_interconnect::AXI_Interconnect &dut, uint32_t addr,
                   uint8_t total_size,
                   const axi_interconnect::WideWriteData_t &data,
                   const axi_interconnect::WideWriteStrb_t &strobe,
                   uint8_t req_id,
                   uint8_t master) {
  for (int retry = 0; retry < 8; ++retry) {
    cycle_outputs(dut);
    const bool ready_snapshot =
        dut.write_ports[master].req.ready;
    auto &req = dut.write_ports[master].req;
    req.valid = true;
    req.addr = addr;
    req.total_size = total_size;
    req.id = req_id;
    req.wdata = data;
    req.wstrb = strobe;
    req.bypass = false;
    cycle_inputs(dut);
    if (ready_snapshot) {
      return true;
    }
  }
  return false;
}

void issue_write_and_capture_axi(axi_interconnect::AXI_Interconnect &dut,
                                 WriteTrace &trace, uint8_t master,
                                 axi_interconnect::DownstreamPort port,
                                 const axi_interconnect::WideWriteData_t &data,
                                 const axi_interconnect::WideWriteStrb_t &strobe) {
  require(enqueue_write(dut, trace.req_addr, trace.req_size, data, strobe,
                        trace.req_id, master),
          "C++ overlapped write request was not accepted");

  clear_inputs(dut);
  set_downstream_ready(dut);
  dut.comb_inputs();
  if (port == axi_interconnect::DownstreamPort::DDR) {
    require(dut.axi_ddr_io.aw.awvalid,
            "C++ overlapped write did not issue DDR AW");
    require(!dut.axi_mmio_io.aw.awvalid,
            "C++ overlapped DDR write escaped to MMIO AW");
    trace.awaddr = static_cast<uint32_t>(dut.axi_ddr_io.aw.awaddr);
    trace.awlen = static_cast<uint8_t>(dut.axi_ddr_io.aw.awlen);
    trace.awsize = static_cast<uint8_t>(dut.axi_ddr_io.aw.awsize);
    trace.awburst = static_cast<uint8_t>(dut.axi_ddr_io.aw.awburst);
    trace.awid = static_cast<uint8_t>(dut.axi_ddr_io.aw.awid);
  } else {
    require(dut.axi_mmio_io.aw.awvalid,
            "C++ overlapped write did not issue MMIO AW");
    require(!dut.axi_ddr_io.aw.awvalid,
            "C++ overlapped MMIO write escaped to DDR AW");
    trace.awaddr = static_cast<uint32_t>(dut.axi_mmio_io.aw.awaddr);
    trace.awlen = static_cast<uint8_t>(dut.axi_mmio_io.aw.awlen);
    trace.awsize = static_cast<uint8_t>(dut.axi_mmio_io.aw.awsize);
    trace.awburst = static_cast<uint8_t>(dut.axi_mmio_io.aw.awburst);
    trace.awid = static_cast<uint8_t>(dut.axi_mmio_io.aw.awid);
  }
  trace.beat_count = static_cast<uint32_t>(trace.awlen) + 1u;
  dut.seq();
  ++sim_time;

  for (uint32_t beat = 0; beat < trace.beat_count; ++beat) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    dut.comb_inputs();
    if (port == axi_interconnect::DownstreamPort::DDR) {
      require(dut.axi_ddr_io.w.wvalid,
              "C++ overlapped DDR write W did not become valid");
      trace.wbeats[beat] = axi_words(dut.axi_ddr_io.w.wdata);
      trace.wstrb[beat] = axi_strobe_mask(dut.axi_ddr_io.w.wstrb);
      trace.wlast[beat] = dut.axi_ddr_io.w.wlast ? 1 : 0;
    } else {
      require(dut.axi_mmio_io.w.wvalid,
              "C++ overlapped MMIO write W did not become valid");
      trace.wbeats[beat] = axi_words(dut.axi_mmio_io.w.wdata);
      trace.wstrb[beat] = axi_strobe_mask(dut.axi_mmio_io.w.wstrb);
      trace.wlast[beat] = dut.axi_mmio_io.w.wlast ? 1 : 0;
    }
    dut.seq();
    ++sim_time;
  }
}

void capture_write_response(axi_interconnect::AXI_Interconnect &dut,
                            WriteTrace &trace, uint8_t master) {
  clear_inputs(dut);
  dut.comb_outputs();
  auto &resp = dut.write_ports[master].resp;
  require(resp.valid, "C++ overlapped write response did not become valid");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_code = static_cast<uint8_t>(resp.resp);
  resp.ready = true;
  dut.comb_outputs();
  require(resp.valid, "C++ overlapped write response dropped before ready");
  dut.seq();
  ++sim_time;
}

void issue_cache_write_and_wait_response(
    axi_interconnect::AXI_Interconnect &dut, StatefulLlcTableDriver &table_driver,
    WriteTrace &trace, uint8_t master,
    const axi_interconnect::WideWriteData_t &data,
    const axi_interconnect::WideWriteStrb_t &strobe) {
  bool accepted = false;
  bool response_seen = false;
  bool request_active = true;
  for (int cycle = 0; cycle < 240 && !response_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    const bool ready_snapshot = dut.write_ports[master].req.ready;
    if (request_active) {
      auto &req = dut.write_ports[master].req;
      req.valid = true;
      req.addr = trace.req_addr;
      req.total_size = trace.req_size;
      req.id = trace.req_id;
      req.wdata = data;
      req.wstrb = strobe;
      req.bypass = false;
    }
    auto &resp = dut.write_ports[master].resp;
    if (resp.valid) {
      response_seen = true;
      trace.resp_id = static_cast<uint8_t>(resp.id);
      trace.resp_code = static_cast<uint8_t>(resp.resp);
      resp.ready = true;
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.axi_ddr_io.ar.arvalid && !dut.axi_ddr_io.aw.awvalid &&
                !dut.axi_ddr_io.w.wvalid && !dut.axi_mmio_io.ar.arvalid &&
                !dut.axi_mmio_io.aw.awvalid && !dut.axi_mmio_io.w.wvalid,
            "C++ cache setup write unexpectedly escaped to external AXI");
    if (request_active && ready_snapshot) {
      accepted = true;
      request_active = false;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ cache setup write was not accepted");
  require(response_seen, "C++ cache setup write response timeout");
}

void capture_write_response_with_table(
    axi_interconnect::AXI_Interconnect &dut, StatefulLlcTableDriver &table_driver,
    WriteTrace &trace, uint8_t master) {
  clear_inputs(dut);
  table_driver.drive(dut);
  dut.comb_outputs();
  auto &resp = dut.write_ports[master].resp;
  require(resp.valid, "C++ table-backed write response did not become valid");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_code = static_cast<uint8_t>(resp.resp);
  resp.ready = true;
  dut.comb_inputs();
  table_driver.observe(dut);
  dut.seq();
  ++sim_time;
}

void issue_mapped_read_and_wait_response(
    axi_interconnect::AXI_Interconnect &dut,
    StatefulLlcTableDriver &table_driver, ReadTrace &trace, uint8_t master) {
  bool accepted = false;
  bool request_active = true;
  for (int cycle = 0; cycle < 220 && !accepted; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    if (request_active) {
      auto &req = dut.read_ports[master].req;
      req.valid = true;
      req.addr = trace.req_addr;
      req.total_size = trace.req_size;
      req.id = trace.req_id;
      req.bypass = false;
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.axi_ddr_io.ar.arvalid && !dut.axi_ddr_io.aw.awvalid &&
                !dut.axi_ddr_io.w.wvalid && !dut.axi_mmio_io.ar.arvalid &&
                !dut.axi_mmio_io.aw.awvalid && !dut.axi_mmio_io.w.wvalid,
            "C++ mode2 mapped local read escaped to external AXI");
    if (request_active && dut.read_ports[master].req.ready) {
      accepted = true;
      request_active = false;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ mode2 mapped local read was not accepted");

  bool resp_seen = false;
  for (int cycle = 0; cycle < 220 && !resp_seen; ++cycle) {
    clear_inputs(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    require(!dut.axi_ddr_io.ar.arvalid && !dut.axi_ddr_io.aw.awvalid &&
                !dut.axi_ddr_io.w.wvalid && !dut.axi_mmio_io.ar.arvalid &&
                !dut.axi_mmio_io.aw.awvalid && !dut.axi_mmio_io.w.wvalid,
            "C++ mode2 mapped local read response escaped to external AXI");
    auto &resp = dut.read_ports[master].resp;
    if (resp.valid) {
      resp_seen = true;
      trace.resp_id = static_cast<uint8_t>(resp.id);
      trace.resp_data = wide_read_words(resp.data);
      resp.ready = true;
      dut.comb_outputs();
      require(resp.valid,
              "C++ mode2 mapped local read response dropped before ready");
    }
    dut.seq();
    ++sim_time;
  }
  require(resp_seen, "C++ mode2 mapped local read response timeout");
}

void issue_cache_read_miss_and_wait_response(
    axi_interconnect::AXI_Interconnect &dut,
    StatefulLlcTableDriver &table_driver, ReadTrace &trace, uint8_t master,
    uint32_t beat_seed) {
  bool accepted = false;
  bool ar_seen = false;
  bool request_active = true;
  bool ready_seen = false;
  for (int cycle = 0; cycle < 240 && !ar_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    if (request_active) {
      auto &req = dut.read_ports[master].req;
      req.valid = true;
      req.addr = trace.req_addr;
      req.total_size = trace.req_size;
      req.id = trace.req_id;
      req.bypass = false;
    }
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    if (request_active && dut.read_ports[master].req.ready) {
      if (master == axi_interconnect::MASTER_DCACHE_R || ready_seen) {
        accepted = true;
        request_active = false;
      } else {
        ready_seen = true;
      }
    }
    if (dut.axi_ddr_io.ar.arvalid) {
      require(!dut.axi_mmio_io.ar.arvalid,
              "C++ cache read miss escaped to both AR ports");
      trace.araddr = static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr);
      trace.arlen = static_cast<uint8_t>(dut.axi_ddr_io.ar.arlen);
      trace.arsize = static_cast<uint8_t>(dut.axi_ddr_io.ar.arsize);
      trace.arburst = static_cast<uint8_t>(dut.axi_ddr_io.ar.arburst);
      trace.arid = static_cast<uint8_t>(dut.axi_ddr_io.ar.arid);
      ar_seen = true;
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ cache read miss request was not accepted");
  require(ar_seen, "C++ cache read miss did not issue DDR AR");
  require(trace.beat_count == static_cast<uint32_t>(trace.arlen) + 1u,
          "C++ cache read miss beat count mismatch");

  for (uint32_t beat = 0; beat < trace.beat_count; ++beat) {
    clear_inputs(dut);
    table_driver.drive(dut);
    dut.axi_ddr_io.r.rvalid = true;
    dut.axi_ddr_io.r.rid = trace.arid;
    dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
    dut.axi_ddr_io.r.rlast = beat == trace.beat_count - 1u;
    dut.axi_ddr_io.r.rdata = ddr_read_beat(beat_seed + beat * 0x100u);
    trace.rbeats[beat] = axi_words(dut.axi_ddr_io.r.rdata);
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    require(dut.axi_ddr_io.r.rready,
            "C++ cache read miss DDR R was backpressured");
    dut.seq();
    ++sim_time;
  }

  bool resp_seen = false;
  for (int cycle = 0; cycle < 240 && !resp_seen; ++cycle) {
    clear_inputs(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    auto &resp = dut.read_ports[master].resp;
    if (resp.valid) {
      resp_seen = true;
      trace.resp_id = static_cast<uint8_t>(resp.id);
      trace.resp_data = wide_read_words(resp.data);
    }
    dut.comb_inputs();
    table_driver.observe(dut);
    dut.seq();
    ++sim_time;
  }
  require(resp_seen, "C++ cache read miss response timeout");

  bool resp_retired = false;
  for (int cycle = 0; cycle < 8 && !resp_retired; ++cycle) {
    clear_inputs(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    auto &resp = dut.read_ports[master].resp;
    if (!resp.valid) {
      resp_retired = true;
      dut.comb_inputs();
      table_driver.observe(dut);
      dut.seq();
      ++sim_time;
      break;
    }
    require(static_cast<uint8_t>(resp.id) == trace.resp_id,
            "C++ cache read miss held response id changed before ready");
    resp.ready = true;
    dut.comb_inputs();
    table_driver.observe(dut);
    dut.seq();
    ++sim_time;
  }
  require(resp_retired, "C++ cache read miss response did not retire");
}

void issue_cache_read_hit_and_wait_response(
    axi_interconnect::AXI_Interconnect &dut,
    StatefulLlcTableDriver &table_driver, ReadTrace &trace, uint8_t master,
    bool &no_external_issue) {
  no_external_issue = true;
  bool accepted = false;
  bool request_active = true;
  bool resp_seen = false;
  for (int cycle = 0; cycle < 240 && !resp_seen; ++cycle) {
    clear_inputs(dut);
    set_downstream_ready(dut);
    table_driver.drive(dut);
    if (request_active) {
      auto &req = dut.read_ports[master].req;
      req.valid = true;
      req.addr = trace.req_addr;
      req.total_size = trace.req_size;
      req.id = trace.req_id;
      req.bypass = false;
    }
    dut.comb_outputs();
    dut.comb_inputs();
    table_driver.observe(dut);
    no_external_issue =
        no_external_issue && !dut.axi_ddr_io.ar.arvalid &&
        !dut.axi_ddr_io.aw.awvalid && !dut.axi_ddr_io.w.wvalid &&
        !dut.axi_mmio_io.ar.arvalid && !dut.axi_mmio_io.aw.awvalid &&
        !dut.axi_mmio_io.w.wvalid;
    if (request_active && dut.read_ports[master].req.ready) {
      accepted = true;
      request_active = false;
    }
    auto &resp = dut.read_ports[master].resp;
    if (resp.valid) {
      resp_seen = true;
      trace.resp_id = static_cast<uint8_t>(resp.id);
      trace.resp_data = wide_read_words(resp.data);
    }
    dut.seq();
    ++sim_time;
  }
  require(accepted, "C++ cache read hit request was not accepted");
  require(resp_seen, "C++ cache read hit response timeout");
  require(no_external_issue, "C++ cache read hit escaped to external AXI");

  bool resp_retired = false;
  for (int cycle = 0; cycle < 8 && !resp_retired; ++cycle) {
    clear_inputs(dut);
    table_driver.drive(dut);
    dut.comb_outputs();
    auto &resp = dut.read_ports[master].resp;
    if (!resp.valid) {
      resp_retired = true;
      dut.comb_inputs();
      table_driver.observe(dut);
      dut.seq();
      ++sim_time;
      break;
    }
    require(static_cast<uint8_t>(resp.id) == trace.resp_id,
            "C++ cache read hit held response id changed before ready");
    resp.ready = true;
    dut.comb_inputs();
    table_driver.observe(dut);
    dut.seq();
    ++sim_time;
  }
  require(resp_retired, "C++ cache read hit response did not retire");
}

WriteTrace run_write_trace(const std::string &prefix, uint32_t addr,
                           uint8_t total_size, uint8_t req_id,
                           const axi_interconnect::WideWriteData_t &data,
                           const axi_interconnect::WideWriteStrb_t &strobe) {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);

  WriteTrace trace{};
  trace.prefix = prefix;
  trace.req_addr = addr;
  trace.req_size = total_size;
  trace.req_id = req_id;
  trace.req_wdata = wide_write_words(data);
  trace.req_wstrb = write_strobe_mask(strobe);

  require(enqueue_write(dut, addr, total_size, data, strobe, req_id),
          "C++ write request was not accepted");

  clear_inputs(dut);
  dut.comb_inputs();
  require(dut.axi_ddr_io.aw.awvalid, "C++ write did not issue DDR AW");
  require(!dut.axi_mmio_io.aw.awvalid, "C++ write escaped to MMIO AW");
  require(!dut.axi_mmio_io.w.wvalid, "C++ write escaped to MMIO W");
  trace.awaddr = static_cast<uint32_t>(dut.axi_ddr_io.aw.awaddr);
  trace.awlen = static_cast<uint8_t>(dut.axi_ddr_io.aw.awlen);
  trace.awsize = static_cast<uint8_t>(dut.axi_ddr_io.aw.awsize);
  trace.awburst = static_cast<uint8_t>(dut.axi_ddr_io.aw.awburst);
  trace.awid = static_cast<uint8_t>(dut.axi_ddr_io.aw.awid);
  trace.beat_count = static_cast<uint32_t>(trace.awlen) + 1u;

  dut.seq();
  ++sim_time;
  for (uint32_t beat = 0; beat < trace.beat_count; ++beat) {
    clear_inputs(dut);
    dut.comb_inputs();
    require(dut.axi_ddr_io.w.wvalid, "C++ write W did not become valid");
    require(!dut.axi_mmio_io.w.wvalid, "C++ write W escaped to MMIO");
    trace.wbeats[beat] = axi_words(dut.axi_ddr_io.w.wdata);
    trace.wstrb[beat] = axi_strobe_mask(dut.axi_ddr_io.w.wstrb);
    trace.wlast[beat] = dut.axi_ddr_io.w.wlast ? 1 : 0;
    dut.seq();
    ++sim_time;
  }

  clear_inputs(dut);
  dut.comb_inputs();
  dut.axi_ddr_io.b.bvalid = true;
  dut.axi_ddr_io.b.bid = trace.awid;
  dut.axi_ddr_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  require(dut.axi_ddr_io.b.bready, "C++ write B was backpressured");
  dut.seq();
  ++sim_time;

  dut.axi_ddr_io.b.bvalid = false;
  dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp.ready = true;
  dut.comb_outputs();
  const auto &resp = dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp;
  require(resp.valid, "C++ write response did not become valid");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_code = static_cast<uint8_t>(resp.resp);
  dut.seq();
  ++sim_time;
  return trace;
}

WriteTrace run_mmio_write_trace(
    const std::string &prefix, uint32_t addr, uint8_t total_size,
    uint8_t req_id, const axi_interconnect::WideWriteData_t &data,
    const axi_interconnect::WideWriteStrb_t &strobe) {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);

  WriteTrace trace{};
  trace.prefix = prefix;
  trace.req_addr = addr;
  trace.req_size = total_size;
  trace.req_id = req_id;
  trace.req_wdata = wide_write_words(data);
  trace.req_wstrb = write_strobe_mask(strobe);

  require(enqueue_write(dut, addr, total_size, data, strobe, req_id),
          "C++ MMIO write request was not accepted");

  clear_inputs(dut);
  dut.comb_inputs();
  require(dut.axi_mmio_io.aw.awvalid,
          "C++ MMIO write did not issue MMIO AW");
  require(!dut.axi_ddr_io.aw.awvalid, "C++ MMIO write escaped to DDR AW");
  require(!dut.axi_ddr_io.w.wvalid, "C++ MMIO write escaped to DDR W");
  trace.awaddr = static_cast<uint32_t>(dut.axi_mmio_io.aw.awaddr);
  trace.awlen = static_cast<uint8_t>(dut.axi_mmio_io.aw.awlen);
  trace.awsize = static_cast<uint8_t>(dut.axi_mmio_io.aw.awsize);
  trace.awburst = static_cast<uint8_t>(dut.axi_mmio_io.aw.awburst);
  trace.awid = static_cast<uint8_t>(dut.axi_mmio_io.aw.awid);
  trace.beat_count = static_cast<uint32_t>(trace.awlen) + 1u;

  dut.seq();
  ++sim_time;
  for (uint32_t beat = 0; beat < trace.beat_count; ++beat) {
    clear_inputs(dut);
    dut.comb_inputs();
    require(dut.axi_mmio_io.w.wvalid,
            "C++ MMIO write W did not become valid");
    require(!dut.axi_ddr_io.w.wvalid, "C++ MMIO write W escaped to DDR");
    trace.wbeats[beat] = axi_words(dut.axi_mmio_io.w.wdata);
    trace.wstrb[beat] = axi_strobe_mask(dut.axi_mmio_io.w.wstrb);
    trace.wlast[beat] = dut.axi_mmio_io.w.wlast ? 1 : 0;
    dut.seq();
    ++sim_time;
  }

  clear_inputs(dut);
  dut.comb_inputs();
  dut.axi_mmio_io.b.bvalid = true;
  dut.axi_mmio_io.b.bid = trace.awid;
  dut.axi_mmio_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  require(dut.axi_mmio_io.b.bready, "C++ MMIO write B was backpressured");
  dut.seq();
  ++sim_time;

  dut.axi_mmio_io.b.bvalid = false;
  dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp.ready = true;
  dut.comb_outputs();
  const auto &resp = dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp;
  require(resp.valid, "C++ MMIO write response did not become valid");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_code = static_cast<uint8_t>(resp.resp);
  dut.seq();
  ++sim_time;
  return trace;
}

WriteTrace run_mode1_mmio_write_trace(
    const std::string &prefix, uint32_t addr, uint8_t total_size,
    uint8_t req_id, const axi_interconnect::WideWriteData_t &data,
    const axi_interconnect::WideWriteStrb_t &strobe) {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);

  WriteTrace trace{};
  trace.prefix = prefix;
  trace.req_addr = addr;
  trace.req_size = total_size;
  trace.req_id = req_id;
  trace.req_wdata = wide_write_words(data);
  trace.req_wstrb = write_strobe_mask(strobe);

  require(enqueue_write(dut, addr, total_size, data, strobe, req_id),
          "C++ mode1 MMIO write request was not accepted");

  clear_inputs(dut);
  dut.comb_inputs();
  require(dut.axi_mmio_io.aw.awvalid,
          "C++ mode1 MMIO write did not issue MMIO AW");
  require(!dut.axi_ddr_io.aw.awvalid,
          "C++ mode1 MMIO write escaped to DDR AW");
  require(!dut.axi_ddr_io.w.wvalid,
          "C++ mode1 MMIO write escaped to DDR W");
  trace.awaddr = static_cast<uint32_t>(dut.axi_mmio_io.aw.awaddr);
  trace.awlen = static_cast<uint8_t>(dut.axi_mmio_io.aw.awlen);
  trace.awsize = static_cast<uint8_t>(dut.axi_mmio_io.aw.awsize);
  trace.awburst = static_cast<uint8_t>(dut.axi_mmio_io.aw.awburst);
  trace.awid = static_cast<uint8_t>(dut.axi_mmio_io.aw.awid);
  trace.beat_count = static_cast<uint32_t>(trace.awlen) + 1u;

  dut.seq();
  ++sim_time;
  for (uint32_t beat = 0; beat < trace.beat_count; ++beat) {
    clear_inputs(dut);
    dut.comb_inputs();
    require(dut.axi_mmio_io.w.wvalid,
            "C++ mode1 MMIO write W did not become valid");
    require(!dut.axi_ddr_io.w.wvalid,
            "C++ mode1 MMIO write W escaped to DDR");
    trace.wbeats[beat] = axi_words(dut.axi_mmio_io.w.wdata);
    trace.wstrb[beat] = axi_strobe_mask(dut.axi_mmio_io.w.wstrb);
    trace.wlast[beat] = dut.axi_mmio_io.w.wlast ? 1 : 0;
    dut.seq();
    ++sim_time;
  }

  clear_inputs(dut);
  dut.comb_inputs();
  dut.axi_mmio_io.b.bvalid = true;
  dut.axi_mmio_io.b.bid = trace.awid;
  dut.axi_mmio_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  require(dut.axi_mmio_io.b.bready,
          "C++ mode1 MMIO write B was backpressured");
  dut.seq();
  ++sim_time;

  dut.axi_mmio_io.b.bvalid = false;
  dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp.ready = true;
  dut.comb_outputs();
  const auto &resp = dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp;
  require(resp.valid, "C++ mode1 MMIO write response did not become valid");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_code = static_cast<uint8_t>(resp.resp);
  dut.seq();
  ++sim_time;
  return trace;
}

ReadTrace run_mode2_mmio_read_trace(const std::string &prefix, uint32_t addr,
                                    uint8_t total_size, uint8_t req_id,
                                    uint32_t rdata_word) {
  axi_interconnect::AXI_Interconnect dut;
  init_mapped_trace_dut(dut);
  clear_inputs(dut);

  ReadTrace trace{};
  trace.prefix = prefix;
  trace.req_addr = addr;
  trace.req_size = total_size;
  trace.req_id = req_id;
  trace.beat_count = 1;

  auto &req = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].req;
  req.valid = true;
  req.addr = addr;
  req.total_size = total_size;
  req.id = req_id;
  req.bypass = false;
  dut.comb_inputs();
  require(req.ready, "C++ mode2 MMIO read request was not ready");
  require(dut.axi_mmio_io.ar.arvalid,
          "C++ mode2 MMIO read did not issue MMIO AR");
  require(!dut.axi_ddr_io.ar.arvalid,
          "C++ mode2 MMIO read escaped to DDR AR");
  require(!dut.axi_ddr_io.aw.awvalid && !dut.axi_ddr_io.w.wvalid,
          "C++ mode2 MMIO read leaked write-side DDR activity");

  trace.araddr = static_cast<uint32_t>(dut.axi_mmio_io.ar.araddr);
  trace.arlen = static_cast<uint8_t>(dut.axi_mmio_io.ar.arlen);
  trace.arsize = static_cast<uint8_t>(dut.axi_mmio_io.ar.arsize);
  trace.arburst = static_cast<uint8_t>(dut.axi_mmio_io.ar.arburst);
  trace.arid = static_cast<uint8_t>(dut.axi_mmio_io.ar.arid);

  dut.seq();
  ++sim_time;
  idle_request_outputs(dut);

  dut.axi_mmio_io.r.rvalid = true;
  dut.axi_mmio_io.r.rid = trace.arid;
  dut.axi_mmio_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_mmio_io.r.rlast = true;
  dut.axi_mmio_io.r.rdata = {};
  axi_compat::set_u32(dut.axi_mmio_io.r.rdata, 0, rdata_word);
  trace.rbeats[0] = axi_words(dut.axi_mmio_io.r.rdata);
  dut.comb_outputs();
  require(dut.axi_mmio_io.r.rready,
          "C++ mode2 MMIO read R was backpressured");
  dut.seq();
  ++sim_time;

  dut.axi_mmio_io.r.rvalid = false;
  dut.axi_mmio_io.r.rlast = false;
  dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp.ready = true;
  dut.comb_outputs();
  const auto &resp = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].resp;
  require(resp.valid, "C++ mode2 MMIO read response did not become valid");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_data = wide_read_words(resp.data);
  dut.seq();
  ++sim_time;
  return trace;
}

WriteTrace run_mode2_mmio_write_trace(
    const std::string &prefix, uint32_t addr, uint8_t total_size,
    uint8_t req_id, const axi_interconnect::WideWriteData_t &data,
    const axi_interconnect::WideWriteStrb_t &strobe) {
  axi_interconnect::AXI_Interconnect dut;
  init_mapped_trace_dut(dut);
  clear_inputs(dut);

  WriteTrace trace{};
  trace.prefix = prefix;
  trace.req_addr = addr;
  trace.req_size = total_size;
  trace.req_id = req_id;
  trace.req_wdata = wide_write_words(data);
  trace.req_wstrb = write_strobe_mask(strobe);

  require(enqueue_write(dut, addr, total_size, data, strobe, req_id),
          "C++ mode2 MMIO write request was not accepted");

  clear_inputs(dut);
  dut.comb_inputs();
  require(dut.axi_mmio_io.aw.awvalid,
          "C++ mode2 MMIO write did not issue MMIO AW");
  require(!dut.axi_ddr_io.aw.awvalid,
          "C++ mode2 MMIO write escaped to DDR AW");
  require(!dut.axi_ddr_io.w.wvalid,
          "C++ mode2 MMIO write escaped to DDR W");
  trace.awaddr = static_cast<uint32_t>(dut.axi_mmio_io.aw.awaddr);
  trace.awlen = static_cast<uint8_t>(dut.axi_mmio_io.aw.awlen);
  trace.awsize = static_cast<uint8_t>(dut.axi_mmio_io.aw.awsize);
  trace.awburst = static_cast<uint8_t>(dut.axi_mmio_io.aw.awburst);
  trace.awid = static_cast<uint8_t>(dut.axi_mmio_io.aw.awid);
  trace.beat_count = static_cast<uint32_t>(trace.awlen) + 1u;

  dut.seq();
  ++sim_time;
  for (uint32_t beat = 0; beat < trace.beat_count; ++beat) {
    clear_inputs(dut);
    dut.comb_inputs();
    require(dut.axi_mmio_io.w.wvalid,
            "C++ mode2 MMIO write W did not become valid");
    require(!dut.axi_ddr_io.w.wvalid,
            "C++ mode2 MMIO write W escaped to DDR");
    trace.wbeats[beat] = axi_words(dut.axi_mmio_io.w.wdata);
    trace.wstrb[beat] = axi_strobe_mask(dut.axi_mmio_io.w.wstrb);
    trace.wlast[beat] = dut.axi_mmio_io.w.wlast ? 1 : 0;
    dut.seq();
    ++sim_time;
  }

  clear_inputs(dut);
  dut.comb_inputs();
  dut.axi_mmio_io.b.bvalid = true;
  dut.axi_mmio_io.b.bid = trace.awid;
  dut.axi_mmio_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  require(dut.axi_mmio_io.b.bready,
          "C++ mode2 MMIO write B was backpressured");
  dut.seq();
  ++sim_time;

  dut.axi_mmio_io.b.bvalid = false;
  dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp.ready = true;
  dut.comb_outputs();
  const auto &resp = dut.write_ports[axi_interconnect::MASTER_DCACHE_W].resp;
  require(resp.valid, "C++ mode2 MMIO write response did not become valid");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_code = static_cast<uint8_t>(resp.resp);
  dut.seq();
  ++sim_time;
  return trace;
}

OverlapWriteTrace run_overlapped_write_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);

  OverlapWriteTrace trace{};
  trace.ddr.prefix = "CPP_MODE0_OVERLAP_WRITE_DDR";
  trace.ddr.req_addr = 0x40000200u;
  trace.ddr.req_size = 3;
  trace.ddr.req_id = 0xCu;
  trace.ddr.req_wdata = wide_write_words(single_word_data(0xdd440200u));
  trace.ddr.req_wstrb = write_strobe_mask(byte_strobe(0xfu));
  trace.mmio.prefix = "CPP_MODE0_OVERLAP_WRITE_MMIO";
  trace.mmio.req_addr = 0x10000084u;
  trace.mmio.req_size = 3;
  trace.mmio.req_id = 0xDu;
  trace.mmio.req_wdata = wide_write_words(single_word_data(0xee550084u));
  trace.mmio.req_wstrb = write_strobe_mask(byte_strobe(0xfu));
  trace.ddr_master = axi_interconnect::MASTER_DCACHE_W;
  trace.mmio_master = axi_interconnect::MASTER_UNCORE_LSU_W;

  const auto ddr_data = single_word_data(0xdd440200u);
  const auto ddr_strobe = byte_strobe(0xfu);
  const auto mmio_data = single_word_data(0xee550084u);
  const auto mmio_strobe = byte_strobe(0xfu);
  issue_write_and_capture_axi(dut, trace.ddr, trace.ddr_master,
                              axi_interconnect::DownstreamPort::DDR, ddr_data,
                              ddr_strobe);
  issue_write_and_capture_axi(dut, trace.mmio, trace.mmio_master,
                              axi_interconnect::DownstreamPort::MMIO, mmio_data,
                              mmio_strobe);

  idle_request_outputs(dut);
  dut.axi_mmio_io.b.bvalid = true;
  dut.axi_mmio_io.b.bid = trace.mmio.awid;
  dut.axi_mmio_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  trace.mmio_bready_while_resp_stalled = dut.axi_mmio_io.b.bready;
  require(trace.mmio_bready_while_resp_stalled,
          "C++ overlapped MMIO B was backpressured by upstream stall");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  dut.comb_outputs();
  require(dut.write_ports[trace.mmio_master].resp.valid,
          "C++ overlapped MMIO write response was not held while stalled");
  require(!dut.write_ports[trace.ddr_master].resp.valid,
          "C++ overlapped DDR write response appeared before DDR B");

  idle_request_outputs(dut);
  dut.axi_ddr_io.b.bvalid = true;
  dut.axi_ddr_io.b.bid = trace.ddr.awid;
  dut.axi_ddr_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  trace.ddr_bready_while_resp_stalled = dut.axi_ddr_io.b.bready;
  require(trace.ddr_bready_while_resp_stalled,
          "C++ overlapped DDR B was backpressured by upstream stall");
  dut.seq();
  ++sim_time;

  capture_write_response(dut, trace.mmio, trace.mmio_master);
  capture_write_response(dut, trace.ddr, trace.ddr_master);
  return trace;
}

OverlapWriteTrace run_overlapped_write64_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);

  OverlapWriteTrace trace{};
  trace.ddr.prefix = "CPP_MODE0_OVERLAP_WRITE64_DDR";
  trace.ddr.req_addr = 0x40000400u;
  trace.ddr.req_size = 63;
  trace.ddr.req_id = 0xEu;
  trace.ddr.req_wdata = wide_write_words(line_write_data(0x6400u));
  trace.ddr.req_wstrb = write_strobe_mask(full_line_strobe());
  trace.mmio.prefix = "CPP_MODE0_OVERLAP_WRITE64_MMIO";
  trace.mmio.req_addr = 0x10000094u;
  trace.mmio.req_size = 3;
  trace.mmio.req_id = 0xFu;
  trace.mmio.req_wdata = wide_write_words(single_word_data(0xee550094u));
  trace.mmio.req_wstrb = write_strobe_mask(byte_strobe(0xfu));
  trace.ddr_master = axi_interconnect::MASTER_DCACHE_W;
  trace.mmio_master = axi_interconnect::MASTER_UNCORE_LSU_W;

  issue_write_and_capture_axi(dut, trace.ddr, trace.ddr_master,
                              axi_interconnect::DownstreamPort::DDR,
                              line_write_data(0x6400u), full_line_strobe());
  issue_write_and_capture_axi(dut, trace.mmio, trace.mmio_master,
                              axi_interconnect::DownstreamPort::MMIO,
                              single_word_data(0xee550094u),
                              byte_strobe(0xfu));

  idle_request_outputs(dut);
  dut.axi_mmio_io.b.bvalid = true;
  dut.axi_mmio_io.b.bid = trace.mmio.awid;
  dut.axi_mmio_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  trace.mmio_bready_while_resp_stalled = dut.axi_mmio_io.b.bready;
  require(trace.mmio_bready_while_resp_stalled,
          "C++ overlapped write64 MMIO B was backpressured by upstream stall");
  dut.seq();
  ++sim_time;

  clear_inputs(dut);
  dut.comb_outputs();
  require(dut.write_ports[trace.mmio_master].resp.valid,
          "C++ overlapped write64 MMIO response was not held while stalled");
  require(!dut.write_ports[trace.ddr_master].resp.valid,
          "C++ overlapped write64 DDR response appeared before DDR B");

  idle_request_outputs(dut);
  dut.axi_ddr_io.b.bvalid = true;
  dut.axi_ddr_io.b.bid = trace.ddr.awid;
  dut.axi_ddr_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  trace.ddr_bready_while_resp_stalled = dut.axi_ddr_io.b.bready;
  require(trace.ddr_bready_while_resp_stalled,
          "C++ overlapped write64 DDR B was backpressured by upstream stall");
  dut.seq();
  ++sim_time;

  capture_write_response(dut, trace.mmio, trace.mmio_master);
  capture_write_response(dut, trace.ddr, trace.ddr_master);
  return trace;
}

ReadBudgetReleaseTrace run_read_budget_release_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);

  ReadBudgetReleaseTrace trace{};
  trace.fill_base_addr = 0x40005000u;
  trace.fill_stride = 0x20u;
  trace.fill_limit = axi_interconnect::MAX_OUTSTANDING;
  trace.fill_req_size = 3;
  trace.blocked_master = axi_interconnect::MASTER_DCACHE_R;
  trace.blocked_addr = trace.fill_base_addr + trace.fill_limit * trace.fill_stride;
  trace.blocked_id = 0xFu;
  trace.release.prefix = "CPP_MODE0_READ_BUDGET_RELEASE";
  trace.release.req_addr = trace.fill_base_addr;
  trace.release.req_size = trace.fill_req_size;
  trace.release.req_id = 0;
  trace.release.beat_count = 1;
  trace.after_release.prefix = "CPP_MODE0_READ_BUDGET_AFTER_RELEASE";
  trace.after_release.req_addr = trace.blocked_addr + trace.fill_stride;
  trace.after_release.req_size = trace.fill_req_size;
  trace.after_release.req_id = 0xFu;
  trace.after_release.beat_count = 1;

  for (uint32_t idx = 0; idx < trace.fill_limit; ++idx) {
    ReadTrace fill{};
    fill.req_addr = trace.fill_base_addr + idx * trace.fill_stride;
    fill.req_size = trace.fill_req_size;
    fill.req_id = static_cast<uint8_t>(idx / axi_interconnect::NUM_READ_MASTERS);
    const uint8_t master =
        static_cast<uint8_t>(idx % axi_interconnect::NUM_READ_MASTERS);
    issue_read_and_capture_ar(dut, fill, master,
                              axi_interconnect::DownstreamPort::DDR);
    if (idx == 0) {
      trace.release.araddr = fill.araddr;
      trace.release.arlen = fill.arlen;
      trace.release.arsize = fill.arsize;
      trace.release.arburst = fill.arburst;
      trace.release.arid = fill.arid;
    }
  }

  idle_request_outputs(dut);
  auto &blocked_req = dut.read_ports[trace.blocked_master].req;
  blocked_req.valid = true;
  blocked_req.addr = trace.blocked_addr;
  blocked_req.total_size = trace.fill_req_size;
  blocked_req.id = trace.blocked_id;
  blocked_req.bypass = false;
  dut.comb_inputs();
  trace.blocked_ready = blocked_req.ready;
  require(!trace.blocked_ready,
          "C++ read-budget blocked request unexpectedly became ready");
  require(!dut.axi_ddr_io.ar.arvalid && !dut.axi_mmio_io.ar.arvalid,
          "C++ read-budget blocked request issued AR");

  idle_request_outputs(dut);
  dut.axi_ddr_io.r.rvalid = true;
  dut.axi_ddr_io.r.rid = trace.release.arid;
  dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_ddr_io.r.rlast = true;
  dut.axi_ddr_io.r.rdata = ddr_read_beat(0x5500u);
  trace.release.rbeats[0] = axi_words(dut.axi_ddr_io.r.rdata);
  dut.comb_outputs();
  trace.release_rready = dut.axi_ddr_io.r.rready;
  require(trace.release_rready,
          "C++ read-budget release R was backpressured");
  dut.seq();
  ++sim_time;
  capture_read_response(dut, trace.release, 0);

  issue_read_and_capture_ar(dut, trace.after_release,
                            trace.blocked_master,
                            axi_interconnect::DownstreamPort::DDR);
  require(trace.after_release.arid == trace.release.arid,
          "C++ read-budget after-release AR did not reuse freed AXI ID");
  idle_request_outputs(dut);
  dut.axi_ddr_io.r.rvalid = true;
  dut.axi_ddr_io.r.rid = trace.after_release.arid;
  dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_ddr_io.r.rlast = true;
  dut.axi_ddr_io.r.rdata = ddr_read_beat(0x5600u);
  trace.after_release.rbeats[0] = axi_words(dut.axi_ddr_io.r.rdata);
  dut.comb_outputs();
  require(dut.axi_ddr_io.r.rready,
          "C++ read-budget after-release R was backpressured");
  dut.seq();
  ++sim_time;
  capture_read_response(dut, trace.after_release, trace.blocked_master);
  return trace;
}

WriteReuseTrace run_write_reuse_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);

  WriteReuseTrace trace{};
  trace.master = axi_interconnect::MASTER_DCACHE_W;
  trace.first.prefix = "CPP_MODE0_WRITE_REUSE0";
  trace.first.req_addr = 0x40004000u;
  trace.first.req_size = 3;
  trace.first.req_id = 0x8u;
  trace.first.req_wdata = wide_write_words(single_word_data(0x66004000u));
  trace.first.req_wstrb = write_strobe_mask(byte_strobe(0xfu));
  trace.second.prefix = "CPP_MODE0_WRITE_REUSE1";
  trace.second.req_addr = 0x40004020u;
  trace.second.req_size = 3;
  trace.second.req_id = 0x9u;
  trace.second.req_wdata = wide_write_words(single_word_data(0x77004020u));
  trace.second.req_wstrb = write_strobe_mask(byte_strobe(0xfu));

  issue_write_and_capture_axi(dut, trace.first, trace.master,
                              axi_interconnect::DownstreamPort::DDR,
                              single_word_data(0x66004000u),
                              byte_strobe(0xfu));
  idle_request_outputs(dut);
  dut.axi_ddr_io.b.bvalid = true;
  dut.axi_ddr_io.b.bid = trace.first.awid;
  dut.axi_ddr_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  trace.first_bready = dut.axi_ddr_io.b.bready;
  require(trace.first_bready, "C++ write-reuse first B was backpressured");
  dut.seq();
  ++sim_time;
  capture_write_response(dut, trace.first, trace.master);

  issue_write_and_capture_axi(dut, trace.second, trace.master,
                              axi_interconnect::DownstreamPort::DDR,
                              single_word_data(0x77004020u),
                              byte_strobe(0xfu));
  require(trace.second.awid == trace.first.awid,
          "C++ write-reuse second AW did not reuse retired AXI ID");
  idle_request_outputs(dut);
  dut.axi_ddr_io.b.bvalid = true;
  dut.axi_ddr_io.b.bid = trace.second.awid;
  dut.axi_ddr_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  trace.second_bready = dut.axi_ddr_io.b.bready;
  require(trace.second_bready, "C++ write-reuse second B was backpressured");
  dut.seq();
  ++sim_time;
  capture_write_response(dut, trace.second, trace.master);

  return trace;
}

WriteBudgetReleaseTrace run_write_budget_release_trace() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);

  WriteBudgetReleaseTrace trace{};
  trace.fill_base_addr = 0x40006000u;
  trace.fill_stride = 0x40u;
  trace.fill_limit = axi_interconnect::MAX_WRITE_OUTSTANDING;
  trace.fill_req_size = 3;
  trace.blocked_master = axi_interconnect::MASTER_DCACHE_W;
  trace.blocked_addr = trace.fill_base_addr + trace.fill_limit * trace.fill_stride;
  trace.blocked_id = 0xFu;
  const auto blocked_data = single_word_data(0x8800f00du);
  const auto blocked_strobe = byte_strobe(0xfu);
  trace.blocked_wdata = wide_write_words(blocked_data);
  trace.blocked_wstrb = write_strobe_mask(blocked_strobe);
  trace.release.prefix = "CPP_MODE0_WRITE_BUDGET_RELEASE";
  trace.release.req_addr = trace.fill_base_addr;
  trace.release.req_size = trace.fill_req_size;
  trace.release.req_id = 0;
  trace.release.req_wdata = wide_write_words(single_word_data(0x88000000u));
  trace.release.req_wstrb = write_strobe_mask(byte_strobe(0xfu));
  trace.after_release.prefix = "CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE";
  trace.after_release.req_addr = trace.blocked_addr + trace.fill_stride;
  trace.after_release.req_size = trace.fill_req_size;
  trace.after_release.req_id = 0;
  const auto after_release_data = single_word_data(0x99000000u);
  const auto after_release_strobe = byte_strobe(0xfu);
  trace.after_release.req_wdata = wide_write_words(after_release_data);
  trace.after_release.req_wstrb = write_strobe_mask(after_release_strobe);

  for (uint32_t idx = 0; idx < trace.fill_limit; ++idx) {
    WriteTrace fill{};
    fill.req_addr = trace.fill_base_addr + idx * trace.fill_stride;
    fill.req_size = trace.fill_req_size;
    fill.req_id = static_cast<uint8_t>(idx / axi_interconnect::NUM_WRITE_MASTERS);
    const uint8_t master =
        static_cast<uint8_t>(idx % axi_interconnect::NUM_WRITE_MASTERS);
    const auto fill_data = single_word_data(0x88000000u + idx);
    const auto fill_strobe = byte_strobe(0xfu);
    issue_write_and_capture_axi(dut, fill, master,
                                axi_interconnect::DownstreamPort::DDR,
                                fill_data, fill_strobe);
    if (idx == 0) {
      trace.release.awaddr = fill.awaddr;
      trace.release.awlen = fill.awlen;
      trace.release.awsize = fill.awsize;
      trace.release.awburst = fill.awburst;
      trace.release.awid = fill.awid;
      trace.release.beat_count = fill.beat_count;
      trace.release.wbeats = fill.wbeats;
      trace.release.wstrb = fill.wstrb;
      trace.release.wlast = fill.wlast;
    }
  }

  idle_request_outputs(dut);
  auto &blocked_req = dut.write_ports[trace.blocked_master].req;
  blocked_req.valid = true;
  blocked_req.addr = trace.blocked_addr;
  blocked_req.total_size = trace.fill_req_size;
  blocked_req.id = trace.blocked_id;
  blocked_req.wdata = blocked_data;
  blocked_req.wstrb = blocked_strobe;
  blocked_req.bypass = false;
  dut.comb_inputs();
  trace.blocked_ready = blocked_req.ready;
  require(!trace.blocked_ready,
          "C++ write-budget blocked request unexpectedly became ready");
  require(!dut.axi_ddr_io.aw.awvalid && !dut.axi_mmio_io.aw.awvalid &&
              !dut.axi_ddr_io.w.wvalid && !dut.axi_mmio_io.w.wvalid,
          "C++ write-budget blocked request issued AW/W");

  idle_request_outputs(dut);
  dut.axi_ddr_io.b.bvalid = true;
  dut.axi_ddr_io.b.bid = trace.release.awid;
  dut.axi_ddr_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  trace.release_bready = dut.axi_ddr_io.b.bready;
  require(trace.release_bready,
          "C++ write-budget release B was backpressured");
  dut.seq();
  ++sim_time;
  capture_write_response(dut, trace.release, 0);

  issue_write_and_capture_axi(dut, trace.after_release,
                              trace.blocked_master,
                              axi_interconnect::DownstreamPort::DDR,
                              after_release_data, after_release_strobe);
  require(trace.after_release.awid == trace.release.awid,
          "C++ write-budget after-release AW did not reuse freed AXI ID");
  idle_request_outputs(dut);
  dut.axi_ddr_io.b.bvalid = true;
  dut.axi_ddr_io.b.bid = trace.after_release.awid;
  dut.axi_ddr_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
  dut.comb_outputs();
  require(dut.axi_ddr_io.b.bready,
          "C++ write-budget after-release B was backpressured");
  dut.seq();
  ++sim_time;
  capture_write_response(dut, trace.after_release, trace.blocked_master);
  return trace;
}

BlockedTrace run_unsupported_mmio_read_trace(const std::string &prefix,
                                             uint32_t addr,
                                             uint8_t total_size,
                                             uint8_t req_id,
                                             bool mapped_mode = false) {
  axi_interconnect::AXI_Interconnect dut;
  if (mapped_mode) {
    init_mapped_trace_dut(dut);
  } else {
    init_dut(dut);
  }
  clear_inputs(dut);

  BlockedTrace trace{};
  trace.prefix = prefix;
  trace.req_addr = addr;
  trace.req_size = total_size;
  trace.req_id = req_id;

  auto &req = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].req;
  req.valid = true;
  req.addr = addr;
  req.total_size = total_size;
  req.id = req_id;
  req.bypass = false;
  dut.comb_inputs();
  trace.req_ready = req.ready;
  require(!trace.req_ready, "C++ unsupported MMIO read was ready");
  require(!dut.axi_ddr_io.ar.arvalid && !dut.axi_mmio_io.ar.arvalid,
          "C++ unsupported MMIO read issued AR");
  require(!dut.axi_ddr_io.aw.awvalid && !dut.axi_mmio_io.aw.awvalid,
          "C++ unsupported MMIO read issued AW");
  require(!dut.axi_ddr_io.w.wvalid && !dut.axi_mmio_io.w.wvalid,
          "C++ unsupported MMIO read issued W");
  return trace;
}

BlockedTrace run_unsupported_mmio_write_trace(
    const std::string &prefix, uint32_t addr, uint8_t total_size,
    uint8_t req_id, const axi_interconnect::WideWriteData_t &data,
    const axi_interconnect::WideWriteStrb_t &strobe,
    bool mapped_mode = false) {
  axi_interconnect::AXI_Interconnect dut;
  if (mapped_mode) {
    init_mapped_trace_dut(dut);
  } else {
    init_dut(dut);
  }
  clear_inputs(dut);

  BlockedTrace trace{};
  trace.prefix = prefix;
  trace.req_addr = addr;
  trace.req_size = total_size;
  trace.req_id = req_id;
  trace.req_wdata = wide_write_words(data);
  trace.req_wstrb = write_strobe_mask(strobe);

  cycle_outputs(dut);
  auto &req = dut.write_ports[axi_interconnect::MASTER_DCACHE_W].req;
  req.valid = true;
  req.addr = addr;
  req.total_size = total_size;
  req.id = req_id;
  req.wdata = data;
  req.wstrb = strobe;
  req.bypass = false;
  dut.comb_inputs();
  trace.req_ready = req.ready;
  require(!trace.req_ready, "C++ unsupported MMIO write was ready");
  require(!dut.axi_ddr_io.ar.arvalid && !dut.axi_mmio_io.ar.arvalid,
          "C++ unsupported MMIO write issued AR");
  require(!dut.axi_ddr_io.aw.awvalid && !dut.axi_mmio_io.aw.awvalid,
          "C++ unsupported MMIO write issued AW");
  require(!dut.axi_ddr_io.w.wvalid && !dut.axi_mmio_io.w.wvalid,
          "C++ unsupported MMIO write issued W");
  return trace;
}

BlockedTrace run_mode1_invalidate_all_blocks_read_trace(
    const std::string &prefix, uint32_t addr, uint8_t total_size,
    uint8_t req_id) {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);

  BlockedTrace trace{};
  trace.prefix = prefix;
  trace.req_addr = addr;
  trace.req_size = total_size;
  trace.req_id = req_id;

  dut.set_llc_invalidate_all(true);
  auto &req = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].req;
  req.valid = true;
  req.addr = addr;
  req.total_size = total_size;
  req.id = req_id;
  req.bypass = false;
  dut.comb_outputs();
  dut.comb_inputs();
  trace.req_ready = req.ready;
  require(!trace.req_ready,
          "C++ mode1 invalidate-all read unexpectedly became ready");
  require(!dut.axi_ddr_io.ar.arvalid && !dut.axi_mmio_io.ar.arvalid,
          "C++ mode1 invalidate-all read issued AR");
  require(!dut.axi_ddr_io.aw.awvalid && !dut.axi_mmio_io.aw.awvalid,
          "C++ mode1 invalidate-all read issued AW");
  require(!dut.axi_ddr_io.w.wvalid && !dut.axi_mmio_io.w.wvalid,
          "C++ mode1 invalidate-all read issued W");
  return trace;
}

BlockedTrace run_mode1_invalidate_all_blocks_write_trace(
    const std::string &prefix, uint32_t addr, uint8_t total_size,
    uint8_t req_id, const axi_interconnect::WideWriteData_t &data,
    const axi_interconnect::WideWriteStrb_t &strobe) {
  axi_interconnect::AXI_Interconnect dut;
  init_cache_trace_dut(dut);
  clear_inputs(dut);

  BlockedTrace trace{};
  trace.prefix = prefix;
  trace.req_addr = addr;
  trace.req_size = total_size;
  trace.req_id = req_id;
  trace.req_wdata = wide_write_words(data);
  trace.req_wstrb = write_strobe_mask(strobe);

  dut.set_llc_invalidate_all(true);
  auto &req = dut.write_ports[axi_interconnect::MASTER_DCACHE_W].req;
  req.valid = true;
  req.addr = addr;
  req.total_size = total_size;
  req.id = req_id;
  req.wdata = data;
  req.wstrb = strobe;
  req.bypass = false;
  dut.comb_outputs();
  dut.comb_inputs();
  trace.req_ready = req.ready;
  require(!trace.req_ready,
          "C++ mode1 invalidate-all write unexpectedly became ready");
  require(!dut.axi_ddr_io.ar.arvalid && !dut.axi_mmio_io.ar.arvalid,
          "C++ mode1 invalidate-all write issued AR");
  require(!dut.axi_ddr_io.aw.awvalid && !dut.axi_mmio_io.aw.awvalid,
          "C++ mode1 invalidate-all write issued AW");
  require(!dut.axi_ddr_io.w.wvalid && !dut.axi_mmio_io.w.wvalid,
          "C++ mode1 invalidate-all write issued W");
  return trace;
}

void emit_read(std::ostream &os, const ReadTrace &trace) {
  os << "\n";
  os << "localparam [31:0] " << trace.prefix
     << "_REQ_ADDR = " << hex_u32(trace.req_addr) << ";\n";
  os << "localparam [7:0] " << trace.prefix
     << "_REQ_SIZE = 8'd" << static_cast<unsigned>(trace.req_size) << ";\n";
  os << "localparam [3:0] " << trace.prefix
     << "_REQ_ID = 4'd" << static_cast<unsigned>(trace.req_id) << ";\n";
  os << "localparam [31:0] " << trace.prefix
     << "_ARADDR = " << hex_u32(trace.araddr) << ";\n";
  os << "localparam [7:0] " << trace.prefix
     << "_ARLEN = 8'd" << static_cast<unsigned>(trace.arlen) << ";\n";
  os << "localparam [2:0] " << trace.prefix
     << "_ARSIZE = 3'd" << static_cast<unsigned>(trace.arsize) << ";\n";
  os << "localparam [1:0] " << trace.prefix
     << "_ARBURST = 2'd" << static_cast<unsigned>(trace.arburst) << ";\n";
  os << "localparam [5:0] " << trace.prefix
     << "_ARID = 6'd" << static_cast<unsigned>(trace.arid) << ";\n";
  os << "localparam integer " << trace.prefix
     << "_BEATS = " << trace.beat_count << ";\n";
  for (uint32_t beat = 0; beat < trace.beat_count; ++beat) {
    os << "localparam [255:0] " << trace.prefix << "_RBEAT" << beat
       << " = " << hex_words(trace.rbeats[beat], 8) << ";\n";
  }
  os << "localparam [3:0] " << trace.prefix
     << "_RESP_ID = 4'd" << static_cast<unsigned>(trace.resp_id) << ";\n";
  os << "localparam [2047:0] " << trace.prefix
     << "_RESP_DATA = " << hex_words(trace.resp_data, 64) << ";\n";
}

void emit_write(std::ostream &os, const WriteTrace &trace) {
  os << "\n";
  os << "localparam [31:0] " << trace.prefix
     << "_REQ_ADDR = " << hex_u32(trace.req_addr) << ";\n";
  os << "localparam [7:0] " << trace.prefix
     << "_REQ_SIZE = 8'd" << static_cast<unsigned>(trace.req_size) << ";\n";
  os << "localparam [3:0] " << trace.prefix
     << "_REQ_ID = 4'd" << static_cast<unsigned>(trace.req_id) << ";\n";
  os << "localparam [511:0] " << trace.prefix
     << "_REQ_WDATA = " << hex_words(trace.req_wdata, 16) << ";\n";
  os << "localparam [63:0] " << trace.prefix
     << "_REQ_WSTRB = " << hex_u64(trace.req_wstrb) << ";\n";
  os << "localparam [31:0] " << trace.prefix
     << "_AWADDR = " << hex_u32(trace.awaddr) << ";\n";
  os << "localparam [7:0] " << trace.prefix
     << "_AWLEN = 8'd" << static_cast<unsigned>(trace.awlen) << ";\n";
  os << "localparam [2:0] " << trace.prefix
     << "_AWSIZE = 3'd" << static_cast<unsigned>(trace.awsize) << ";\n";
  os << "localparam [1:0] " << trace.prefix
     << "_AWBURST = 2'd" << static_cast<unsigned>(trace.awburst) << ";\n";
  os << "localparam [5:0] " << trace.prefix
     << "_AWID = 6'd" << static_cast<unsigned>(trace.awid) << ";\n";
  os << "localparam integer " << trace.prefix
     << "_BEATS = " << trace.beat_count << ";\n";
  for (uint32_t beat = 0; beat < trace.beat_count; ++beat) {
    os << "localparam [255:0] " << trace.prefix << "_WBEAT" << beat
       << " = " << hex_words(trace.wbeats[beat], 8) << ";\n";
    os << "localparam [31:0] " << trace.prefix << "_WSTRB" << beat
       << " = " << hex_u32(trace.wstrb[beat]) << ";\n";
    os << "localparam " << trace.prefix << "_WLAST" << beat
       << " = 1'b" << static_cast<unsigned>(trace.wlast[beat]) << ";\n";
  }
  os << "localparam [3:0] " << trace.prefix
     << "_RESP_ID = 4'd" << static_cast<unsigned>(trace.resp_id) << ";\n";
  os << "localparam [1:0] " << trace.prefix
     << "_RESP_CODE = 2'd" << static_cast<unsigned>(trace.resp_code) << ";\n";
}

void emit_blocked_read(std::ostream &os, const BlockedTrace &trace) {
  os << "\n";
  os << "localparam [31:0] " << trace.prefix
     << "_REQ_ADDR = " << hex_u32(trace.req_addr) << ";\n";
  os << "localparam [7:0] " << trace.prefix
     << "_REQ_SIZE = 8'd" << static_cast<unsigned>(trace.req_size) << ";\n";
  os << "localparam [3:0] " << trace.prefix
     << "_REQ_ID = 4'd" << static_cast<unsigned>(trace.req_id) << ";\n";
  os << "localparam " << trace.prefix
     << "_REQ_READY = 1'b" << (trace.req_ready ? 1 : 0) << ";\n";
}

void emit_blocked_write(std::ostream &os, const BlockedTrace &trace) {
  os << "\n";
  os << "localparam [31:0] " << trace.prefix
     << "_REQ_ADDR = " << hex_u32(trace.req_addr) << ";\n";
  os << "localparam [7:0] " << trace.prefix
     << "_REQ_SIZE = 8'd" << static_cast<unsigned>(trace.req_size) << ";\n";
  os << "localparam [3:0] " << trace.prefix
     << "_REQ_ID = 4'd" << static_cast<unsigned>(trace.req_id) << ";\n";
  os << "localparam [511:0] " << trace.prefix
     << "_REQ_WDATA = " << hex_words(trace.req_wdata, 16) << ";\n";
  os << "localparam [63:0] " << trace.prefix
     << "_REQ_WSTRB = " << hex_u64(trace.req_wstrb) << ";\n";
  os << "localparam " << trace.prefix
     << "_REQ_READY = 1'b" << (trace.req_ready ? 1 : 0) << ";\n";
}

void emit_overlap_read(std::ostream &os, const OverlapReadTrace &trace) {
  emit_read(os, trace.ddr);
  os << "localparam integer " << trace.ddr.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.ddr_master) << ";\n";
  emit_read(os, trace.mmio);
  os << "localparam integer " << trace.mmio.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.mmio_master) << ";\n";
  os << "localparam " << trace.mmio.prefix << "_RREADY_STALLED = 1'b"
     << (trace.mmio_rready_while_resp_stalled ? 1 : 0) << ";\n";
  os << "localparam " << trace.ddr.prefix << "_RREADY_STALLED = 1'b"
     << (trace.ddr_rready_while_resp_stalled ? 1 : 0) << ";\n";
}

void emit_overlap_write(std::ostream &os, const OverlapWriteTrace &trace) {
  emit_write(os, trace.ddr);
  os << "localparam integer " << trace.ddr.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.ddr_master) << ";\n";
  emit_write(os, trace.mmio);
  os << "localparam integer " << trace.mmio.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.mmio_master) << ";\n";
  os << "localparam " << trace.mmio.prefix << "_BREADY_STALLED = 1'b"
     << (trace.mmio_bready_while_resp_stalled ? 1 : 0) << ";\n";
  os << "localparam " << trace.ddr.prefix << "_BREADY_STALLED = 1'b"
     << (trace.ddr_bready_while_resp_stalled ? 1 : 0) << ";\n";
}

void emit_same_master_read(std::ostream &os, const SameMasterReadTrace &trace) {
  emit_read(os, trace.older);
  os << "localparam integer " << trace.older.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.master) << ";\n";
  emit_read(os, trace.newer);
  os << "localparam integer " << trace.newer.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.master) << ";\n";
  os << "localparam " << trace.newer.prefix << "_RREADY_STALLED = 1'b"
     << (trace.newer_rready_while_resp_stalled ? 1 : 0) << ";\n";
  os << "localparam " << trace.older.prefix << "_RREADY_STALLED = 1'b"
     << (trace.older_rready_while_resp_stalled ? 1 : 0) << ";\n";
}

void emit_same_master_write(std::ostream &os,
                            const SameMasterWriteTrace &trace) {
  emit_write(os, trace.older);
  os << "localparam integer " << trace.older.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.master) << ";\n";
  emit_write(os, trace.newer);
  os << "localparam integer " << trace.newer.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.master) << ";\n";
  os << "localparam " << trace.newer.prefix << "_BREADY_STALLED = 1'b"
     << (trace.newer_bready_while_resp_stalled ? 1 : 0) << ";\n";
  os << "localparam " << trace.older.prefix << "_BREADY_STALLED = 1'b"
     << (trace.older_bready_while_resp_stalled ? 1 : 0) << ";\n";
}

void emit_read_reuse(std::ostream &os, const ReadReuseTrace &trace) {
  emit_read(os, trace.first);
  os << "localparam integer " << trace.first.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.master) << ";\n";
  os << "localparam " << trace.first.prefix << "_RREADY = 1'b"
     << (trace.first_rready ? 1 : 0) << ";\n";
  emit_read(os, trace.second);
  os << "localparam integer " << trace.second.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.master) << ";\n";
  os << "localparam " << trace.second.prefix << "_RREADY = 1'b"
     << (trace.second_rready ? 1 : 0) << ";\n";
}

void emit_read_budget_release(std::ostream &os,
                              const ReadBudgetReleaseTrace &trace) {
  os << "\n";
  os << "localparam integer CPP_MODE0_READ_BUDGET_LIMIT = "
     << trace.fill_limit << ";\n";
  os << "localparam [31:0] CPP_MODE0_READ_BUDGET_FILL_BASE = "
     << hex_u32(trace.fill_base_addr) << ";\n";
  os << "localparam [31:0] CPP_MODE0_READ_BUDGET_FILL_STRIDE = "
     << hex_u32(trace.fill_stride) << ";\n";
  os << "localparam [7:0] CPP_MODE0_READ_BUDGET_FILL_REQ_SIZE = 8'd"
     << static_cast<unsigned>(trace.fill_req_size) << ";\n";
  os << "localparam integer CPP_MODE0_READ_BUDGET_BLOCKED_MASTER = "
     << static_cast<unsigned>(trace.blocked_master) << ";\n";
  os << "localparam [31:0] CPP_MODE0_READ_BUDGET_BLOCKED_ADDR = "
     << hex_u32(trace.blocked_addr) << ";\n";
  os << "localparam [3:0] CPP_MODE0_READ_BUDGET_BLOCKED_ID = 4'd"
     << static_cast<unsigned>(trace.blocked_id) << ";\n";
  os << "localparam CPP_MODE0_READ_BUDGET_BLOCKED_READY = 1'b"
     << (trace.blocked_ready ? 1 : 0) << ";\n";
  emit_read(os, trace.release);
  os << "localparam integer " << trace.release.prefix << "_MASTER = 0;\n";
  os << "localparam " << trace.release.prefix << "_RREADY = 1'b"
     << (trace.release_rready ? 1 : 0) << ";\n";
  emit_read(os, trace.after_release);
  os << "localparam integer " << trace.after_release.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.blocked_master) << ";\n";
}

void emit_write_reuse(std::ostream &os, const WriteReuseTrace &trace) {
  emit_write(os, trace.first);
  os << "localparam integer " << trace.first.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.master) << ";\n";
  os << "localparam " << trace.first.prefix << "_BREADY = 1'b"
     << (trace.first_bready ? 1 : 0) << ";\n";
  emit_write(os, trace.second);
  os << "localparam integer " << trace.second.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.master) << ";\n";
  os << "localparam " << trace.second.prefix << "_BREADY = 1'b"
     << (trace.second_bready ? 1 : 0) << ";\n";
}

void emit_write_budget_release(std::ostream &os,
                               const WriteBudgetReleaseTrace &trace) {
  os << "\n";
  os << "localparam integer CPP_MODE0_WRITE_BUDGET_LIMIT = "
     << trace.fill_limit << ";\n";
  os << "localparam [31:0] CPP_MODE0_WRITE_BUDGET_FILL_BASE = "
     << hex_u32(trace.fill_base_addr) << ";\n";
  os << "localparam [31:0] CPP_MODE0_WRITE_BUDGET_FILL_STRIDE = "
     << hex_u32(trace.fill_stride) << ";\n";
  os << "localparam [7:0] CPP_MODE0_WRITE_BUDGET_FILL_REQ_SIZE = 8'd"
     << static_cast<unsigned>(trace.fill_req_size) << ";\n";
  os << "localparam integer CPP_MODE0_WRITE_BUDGET_BLOCKED_MASTER = "
     << static_cast<unsigned>(trace.blocked_master) << ";\n";
  os << "localparam [31:0] CPP_MODE0_WRITE_BUDGET_BLOCKED_ADDR = "
     << hex_u32(trace.blocked_addr) << ";\n";
  os << "localparam [3:0] CPP_MODE0_WRITE_BUDGET_BLOCKED_ID = 4'd"
     << static_cast<unsigned>(trace.blocked_id) << ";\n";
  os << "localparam [511:0] CPP_MODE0_WRITE_BUDGET_BLOCKED_WDATA = "
     << hex_words(trace.blocked_wdata, 16) << ";\n";
  os << "localparam [63:0] CPP_MODE0_WRITE_BUDGET_BLOCKED_WSTRB = "
     << hex_u64(trace.blocked_wstrb) << ";\n";
  os << "localparam CPP_MODE0_WRITE_BUDGET_BLOCKED_READY = 1'b"
     << (trace.blocked_ready ? 1 : 0) << ";\n";
  emit_write(os, trace.release);
  os << "localparam integer " << trace.release.prefix << "_MASTER = 0;\n";
  os << "localparam " << trace.release.prefix << "_BREADY = 1'b"
     << (trace.release_bready ? 1 : 0) << ";\n";
  emit_write(os, trace.after_release);
  os << "localparam integer " << trace.after_release.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.blocked_master) << ";\n";
}

void emit_cache_write_miss_mmio_write(
    std::ostream &os, const CacheWriteMissMmioWriteTrace &trace) {
  os << "\n";
  os << "localparam integer " << trace.cache.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.cache_master) << ";\n";
  os << "localparam [31:0] " << trace.cache.prefix
     << "_REQ_ADDR = " << hex_u32(trace.cache.req_addr) << ";\n";
  os << "localparam [7:0] " << trace.cache.prefix
     << "_REQ_SIZE = 8'd" << static_cast<unsigned>(trace.cache.req_size)
     << ";\n";
  os << "localparam [3:0] " << trace.cache.prefix
     << "_REQ_ID = 4'd" << static_cast<unsigned>(trace.cache.req_id)
     << ";\n";
  os << "localparam [511:0] " << trace.cache.prefix
     << "_REQ_WDATA = " << hex_words(trace.cache.req_wdata, 16) << ";\n";
  os << "localparam [63:0] " << trace.cache.prefix
     << "_REQ_WSTRB = " << hex_u64(trace.cache.req_wstrb) << ";\n";
  os << "localparam [3:0] " << trace.cache.prefix
     << "_RESP_ID = 4'd" << static_cast<unsigned>(trace.cache.resp_id)
     << ";\n";
  os << "localparam [1:0] " << trace.cache.prefix
     << "_RESP_CODE = 2'd" << static_cast<unsigned>(trace.cache.resp_code)
     << ";\n";
  emit_read(os, trace.refill);
  os << "localparam " << trace.refill.prefix << "_RREADY_STALLED = 1'b"
     << (trace.ddr_rready_while_resp_stalled ? 1 : 0) << ";\n";
  emit_write(os, trace.mmio);
  os << "localparam integer " << trace.mmio.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.mmio_master) << ";\n";
  os << "localparam " << trace.mmio.prefix << "_BREADY_STALLED = 1'b"
     << (trace.mmio_bready_while_resp_stalled ? 1 : 0) << ";\n";
}

void emit_cache_write_req_resp(std::ostream &os, const WriteTrace &trace) {
  os << "\n";
  os << "localparam [31:0] " << trace.prefix
     << "_REQ_ADDR = " << hex_u32(trace.req_addr) << ";\n";
  os << "localparam [7:0] " << trace.prefix
     << "_REQ_SIZE = 8'd" << static_cast<unsigned>(trace.req_size) << ";\n";
  os << "localparam [3:0] " << trace.prefix
     << "_REQ_ID = 4'd" << static_cast<unsigned>(trace.req_id) << ";\n";
  os << "localparam [511:0] " << trace.prefix
     << "_REQ_WDATA = " << hex_words(trace.req_wdata, 16) << ";\n";
  os << "localparam [63:0] " << trace.prefix
     << "_REQ_WSTRB = " << hex_u64(trace.req_wstrb) << ";\n";
  os << "localparam [3:0] " << trace.prefix
     << "_RESP_ID = 4'd" << static_cast<unsigned>(trace.resp_id) << ";\n";
  os << "localparam [1:0] " << trace.prefix
     << "_RESP_CODE = 2'd" << static_cast<unsigned>(trace.resp_code)
     << ";\n";
}

void emit_dirty_victim_mmio_write(std::ostream &os,
                                  const DirtyVictimMmioWriteTrace &trace) {
  os << "\n";
  os << "localparam integer CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER = "
     << static_cast<unsigned>(trace.cache_master) << ";\n";
  os << "localparam integer CPP_MODE1_DIRTY_VICTIM_MMIO_MASTER = "
     << static_cast<unsigned>(trace.mmio_master) << ";\n";
  emit_cache_write_req_resp(os, trace.setup0);
  emit_cache_write_req_resp(os, trace.setup1);
  emit_cache_write_req_resp(os, trace.cache);
  emit_write(os, trace.writeback);
  os << "localparam " << trace.writeback.prefix << "_BREADY_STALLED = 1'b"
     << (trace.ddr_bready_while_resp_stalled ? 1 : 0) << ";\n";
  emit_write(os, trace.mmio);
  os << "localparam " << trace.mmio.prefix << "_BREADY_STALLED = 1'b"
     << (trace.mmio_bready_while_resp_stalled ? 1 : 0) << ";\n";
  os << "localparam CPP_MODE1_DIRTY_VICTIM_INVALL_BLOCKED_MMIO_HELD = 1'b"
     << (trace.blocked_while_mmio_resp_held ? 1 : 0) << ";\n";
  os << "localparam CPP_MODE1_DIRTY_VICTIM_INVALL_BLOCKED_CACHE_HELD = 1'b"
     << (trace.blocked_while_cache_resp_held ? 1 : 0) << ";\n";
  os << "localparam CPP_MODE1_DIRTY_VICTIM_INVALL_ACCEPTED_AFTER_RETIRE = 1'b"
     << (trace.accepted_after_resp_retire ? 1 : 0) << ";\n";
  os << "localparam CPP_MODE1_DIRTY_VICTIM_INVLINE_ADDR = "
     << hex_u32(trace.invalidate_line_addr) << ";\n";
  os << "localparam CPP_MODE1_DIRTY_VICTIM_INVLINE_ACCEPTED_AFTER_RETIRE = 1'b"
     << (trace.invalidate_line_accepted_after_resp_retire ? 1 : 0) << ";\n";
}

void emit_dirty_victim_mmio_read(std::ostream &os,
                                 const DirtyVictimMmioReadTrace &trace) {
  os << "\n";
  os << "localparam integer CPP_MODE1_DIRTY_VICTIM_READ_CACHE_MASTER = "
     << static_cast<unsigned>(trace.cache_master) << ";\n";
  os << "localparam integer CPP_MODE1_DIRTY_VICTIM_READ_MMIO_MASTER = "
     << static_cast<unsigned>(trace.mmio_master) << ";\n";
  emit_cache_write_req_resp(os, trace.setup0);
  emit_cache_write_req_resp(os, trace.setup1);
  emit_cache_write_req_resp(os, trace.cache);
  emit_write(os, trace.writeback);
  os << "localparam " << trace.writeback.prefix << "_BREADY_STALLED = 1'b"
     << (trace.ddr_bready_while_resp_stalled ? 1 : 0) << ";\n";
  emit_read(os, trace.mmio);
  os << "localparam " << trace.mmio.prefix << "_RREADY_STALLED = 1'b"
     << (trace.mmio_rready_while_resp_stalled ? 1 : 0) << ";\n";
  os << "localparam CPP_MODE1_DIRTY_VICTIM_READ_INVALL_BLOCKED_MMIO_HELD = 1'b"
     << (trace.blocked_while_mmio_resp_held ? 1 : 0) << ";\n";
  os << "localparam CPP_MODE1_DIRTY_VICTIM_READ_INVALL_BLOCKED_CACHE_HELD = 1'b"
     << (trace.blocked_while_cache_resp_held ? 1 : 0) << ";\n";
  os << "localparam CPP_MODE1_DIRTY_VICTIM_READ_INVALL_ACCEPTED_AFTER_RETIRE = 1'b"
     << (trace.accepted_after_resp_retire ? 1 : 0) << ";\n";
  os << "localparam CPP_MODE1_DIRTY_VICTIM_READ_INVLINE_ADDR = "
     << hex_u32(trace.invalidate_line_addr) << ";\n";
  os << "localparam CPP_MODE1_DIRTY_VICTIM_READ_INVLINE_ACCEPTED_AFTER_RETIRE = 1'b"
     << (trace.invalidate_line_accepted_after_resp_retire ? 1 : 0) << ";\n";
}

void emit_dirty_victim_mmio_read_write(
    std::ostream &os, const DirtyVictimMmioReadWriteTrace &trace) {
  os << "\n";
  os << "localparam integer CPP_MODE1_DIRTY_VICTIM_RW_CACHE_MASTER = "
     << static_cast<unsigned>(trace.cache_master) << ";\n";
  os << "localparam integer CPP_MODE1_DIRTY_VICTIM_RW_MMIO_READ_MASTER = "
     << static_cast<unsigned>(trace.mmio_read_master) << ";\n";
  os << "localparam integer CPP_MODE1_DIRTY_VICTIM_RW_MMIO_WRITE_MASTER = "
     << static_cast<unsigned>(trace.mmio_write_master) << ";\n";
  emit_cache_write_req_resp(os, trace.setup0);
  emit_cache_write_req_resp(os, trace.setup1);
  emit_cache_write_req_resp(os, trace.cache);
  emit_write(os, trace.writeback);
  os << "localparam " << trace.writeback.prefix << "_BREADY_STALLED = 1'b"
     << (trace.ddr_bready_while_resp_stalled ? 1 : 0) << ";\n";
  emit_read(os, trace.mmio_read);
  os << "localparam " << trace.mmio_read.prefix << "_RREADY_STALLED = 1'b"
     << (trace.mmio_rready_while_resp_stalled ? 1 : 0) << ";\n";
  emit_write(os, trace.mmio_write);
  os << "localparam " << trace.mmio_write.prefix << "_BREADY_STALLED = 1'b"
     << (trace.mmio_bready_while_resp_stalled ? 1 : 0) << ";\n";
  os << "localparam CPP_MODE1_DIRTY_VICTIM_RW_INVALL_BLOCKED_MMIO_HELD = 1'b"
     << (trace.blocked_while_mmio_resp_held ? 1 : 0) << ";\n";
  os << "localparam CPP_MODE1_DIRTY_VICTIM_RW_INVALL_BLOCKED_CACHE_HELD = 1'b"
     << (trace.blocked_while_cache_resp_held ? 1 : 0) << ";\n";
  os << "localparam CPP_MODE1_DIRTY_VICTIM_RW_INVALL_ACCEPTED_AFTER_RETIRE = 1'b"
     << (trace.accepted_after_resp_retire ? 1 : 0) << ";\n";
  os << "localparam CPP_MODE1_DIRTY_VICTIM_RW_INVLINE_ADDR = "
     << hex_u32(trace.invalidate_line_addr) << ";\n";
  os << "localparam CPP_MODE1_DIRTY_VICTIM_RW_INVLINE_ACCEPTED_AFTER_RETIRE = 1'b"
     << (trace.invalidate_line_accepted_after_resp_retire ? 1 : 0) << ";\n";
}

void emit_mode2_mapped_local(std::ostream &os,
                             const Mode2MappedLocalTrace &trace) {
  os << "\n";
  os << "localparam integer " << trace.prefix << "_WRITE_MASTER = "
     << static_cast<unsigned>(trace.write_master) << ";\n";
  os << "localparam integer " << trace.prefix << "_READ_MASTER = "
     << static_cast<unsigned>(trace.read_master) << ";\n";
  emit_cache_write_req_resp(os, trace.write);
  os << "\n";
  os << "localparam [31:0] " << trace.read.prefix
     << "_REQ_ADDR = " << hex_u32(trace.read.req_addr) << ";\n";
  os << "localparam [7:0] " << trace.read.prefix
     << "_REQ_SIZE = 8'd" << static_cast<unsigned>(trace.read.req_size)
     << ";\n";
  os << "localparam [3:0] " << trace.read.prefix
     << "_REQ_ID = 4'd" << static_cast<unsigned>(trace.read.req_id) << ";\n";
  os << "localparam [3:0] " << trace.read.prefix
     << "_RESP_ID = 4'd" << static_cast<unsigned>(trace.read.resp_id) << ";\n";
  os << "localparam [2047:0] " << trace.read.prefix
     << "_RESP_DATA = "
     << hex_words(trace.read.resp_data,
                  axi_interconnect::MAX_READ_TRANSACTION_WORDS)
     << ";\n";
}

void emit_invalidate_line_pending_read(
    std::ostream &os, const InvalidateLinePendingReadTrace &trace) {
  emit_read(os, trace.read);
  os << "localparam integer " << trace.read.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.read_master) << ";\n";
  os << "localparam [31:0] " << trace.read.prefix
     << "_INVALIDATE_ADDR = " << hex_u32(trace.invalidate_addr) << ";\n";
  os << "localparam " << trace.read.prefix << "_BLOCKED_BEFORE_R = 1'b"
     << (trace.blocked_before_r ? 1 : 0) << ";\n";
  os << "localparam " << trace.read.prefix << "_RREADY_PENDING = 1'b"
     << (trace.rready_while_invalidate_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.read.prefix << "_BLOCKED_WHILE_RESP_HELD = 1'b"
     << (trace.blocked_while_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.read.prefix << "_ACCEPTED_AFTER_RETIRE = 1'b"
     << (trace.accepted_after_resp_retire ? 1 : 0) << ";\n";
}

void emit_invalidate_line_recovery_read(
    std::ostream &os, const InvalidateLineRecoveryReadTrace &trace) {
  emit_read(os, trace.first);
  emit_read(os, trace.second);
  os << "localparam integer " << trace.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.read_master) << ";\n";
  os << "localparam [31:0] " << trace.prefix
     << "_INVALIDATE_ADDR = " << hex_u32(trace.invalidate_addr) << ";\n";
  os << "localparam " << trace.prefix << "_INVALIDATE_ACCEPTED = 1'b"
     << (trace.invalidate_accepted ? 1 : 0) << ";\n";
}

void emit_invalidate_line_scope_read(
    std::ostream &os, const InvalidateLineScopeReadTrace &trace) {
  emit_read(os, trace.victim_fill);
  emit_read(os, trace.survivor_fill);
  emit_read(os, trace.victim_after);
  emit_read(os, trace.survivor_after);
  os << "localparam integer " << trace.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.read_master) << ";\n";
  os << "localparam [31:0] " << trace.prefix
     << "_INVALIDATE_ADDR = " << hex_u32(trace.invalidate_addr) << ";\n";
  os << "localparam " << trace.prefix << "_INVALIDATE_ACCEPTED = 1'b"
     << (trace.invalidate_accepted ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_SURVIVOR_HIT_NO_EXTERNAL = 1'b"
     << (trace.survivor_hit_no_external ? 1 : 0) << ";\n";
}

void emit_invalidate_all_recovery_cache_read(
    std::ostream &os, const InvalidateAllRecoveryReadTrace &trace) {
  emit_read(os, trace.first_fill);
  emit_read(os, trace.second_fill);
  emit_read(os, trace.first_after);
  emit_read(os, trace.second_after);
  os << "localparam integer " << trace.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.read_master) << ";\n";
  os << "localparam " << trace.prefix << "_INVALIDATE_ACCEPTED = 1'b"
     << (trace.invalidate_accepted ? 1 : 0) << ";\n";
}

void emit_invalidate_all_multi_master_recovery_cache_read(
    std::ostream &os, const InvalidateAllMultiMasterRecoveryReadTrace &trace) {
  emit_read(os, trace.first_fill);
  emit_read(os, trace.second_fill);
  emit_read(os, trace.first_after);
  emit_read(os, trace.second_after);
  os << "localparam integer " << trace.prefix
     << "_FIRST_MASTER = " << static_cast<unsigned>(trace.first_master)
     << ";\n";
  os << "localparam integer " << trace.prefix
     << "_SECOND_MASTER = " << static_cast<unsigned>(trace.second_master)
     << ";\n";
  os << "localparam " << trace.prefix << "_INVALIDATE_ACCEPTED = 1'b"
     << (trace.invalidate_accepted ? 1 : 0) << ";\n";
}

void emit_invalidate_all_recovery_cache_write(
    std::ostream &os, const InvalidateAllRecoveryWriteTrace &trace) {
  emit_read(os, trace.fill);
  emit_cache_write_req_resp(os, trace.write_after);
  emit_read(os, trace.refill_after);
  emit_read(os, trace.read_hit_after);
  os << "localparam integer " << trace.prefix
     << "_READ_MASTER = " << static_cast<unsigned>(trace.read_master) << ";\n";
  os << "localparam integer " << trace.prefix
     << "_WRITE_MASTER = " << static_cast<unsigned>(trace.write_master)
     << ";\n";
  os << "localparam " << trace.prefix << "_INVALIDATE_ACCEPTED = 1'b"
     << (trace.invalidate_accepted ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_HIT_NO_EXTERNAL = 1'b"
     << (trace.read_hit_no_external ? 1 : 0) << ";\n";
}

void emit_invalidate_all_multi_read(
    std::ostream &os, const InvalidateAllMultiReadTrace &trace) {
  emit_read(os, trace.first);
  emit_read(os, trace.second);
  os << "localparam integer " << trace.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.read_master) << ";\n";
  os << "localparam " << trace.prefix << "_FIRST_RREADY_PENDING = 1'b"
     << (trace.first_rready_while_invalidate_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_SECOND_RREADY_FIRST_HELD = 1'b"
     << (trace.second_rready_while_first_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_FIRST_HELD = 1'b"
     << (trace.blocked_while_first_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_SECOND_HELD = 1'b"
     << (trace.blocked_while_second_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_ACCEPTED_AFTER_RETIRE = 1'b"
     << (trace.accepted_after_resp_retire ? 1 : 0) << ";\n";
}

void emit_invalidate_all_multi_master_read(
    std::ostream &os, const InvalidateAllMultiMasterReadTrace &trace) {
  emit_read(os, trace.first);
  emit_read(os, trace.second);
  os << "localparam integer " << trace.prefix
     << "_FIRST_MASTER = " << static_cast<unsigned>(trace.first_master)
     << ";\n";
  os << "localparam integer " << trace.prefix
     << "_SECOND_MASTER = " << static_cast<unsigned>(trace.second_master)
     << ";\n";
  os << "localparam " << trace.prefix << "_FIRST_RREADY_PENDING = 1'b"
     << (trace.first_rready_while_invalidate_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_SECOND_RREADY_FIRST_HELD = 1'b"
     << (trace.second_rready_while_first_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_FIRST_HELD = 1'b"
     << (trace.blocked_while_first_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_SECOND_HELD = 1'b"
     << (trace.blocked_while_second_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_ACCEPTED_AFTER_RETIRE = 1'b"
     << (trace.accepted_after_resp_retire ? 1 : 0) << ";\n";
}

void emit_invalidate_line_multi_master_read(
    std::ostream &os, const InvalidateLineMultiMasterReadTrace &trace) {
  emit_read(os, trace.first);
  emit_read(os, trace.second);
  os << "localparam integer " << trace.prefix
     << "_FIRST_MASTER = " << static_cast<unsigned>(trace.first_master)
     << ";\n";
  os << "localparam integer " << trace.prefix
     << "_SECOND_MASTER = " << static_cast<unsigned>(trace.second_master)
     << ";\n";
  os << "localparam [31:0] " << trace.prefix
     << "_INVALIDATE_ADDR = " << hex_u32(trace.invalidate_addr) << ";\n";
  os << "localparam " << trace.prefix << "_FIRST_RREADY_PENDING = 1'b"
     << (trace.first_rready_while_invalidate_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_SECOND_RREADY_FIRST_HELD = 1'b"
     << (trace.second_rready_while_first_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_FIRST_HELD = 1'b"
     << (trace.blocked_while_first_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_SECOND_HELD = 1'b"
     << (trace.blocked_while_second_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_ACCEPTED_AFTER_RETIRE = 1'b"
     << (trace.accepted_after_resp_retire ? 1 : 0) << ";\n";
}

void emit_invalidate_line_multi_read(
    std::ostream &os, const InvalidateLineMultiReadTrace &trace) {
  emit_read(os, trace.first);
  emit_read(os, trace.second);
  os << "localparam integer " << trace.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.read_master) << ";\n";
  os << "localparam [31:0] " << trace.prefix
     << "_INVALIDATE_ADDR = " << hex_u32(trace.invalidate_addr) << ";\n";
  os << "localparam " << trace.prefix << "_FIRST_RREADY_PENDING = 1'b"
     << (trace.first_rready_while_invalidate_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_SECOND_RREADY_FIRST_HELD = 1'b"
     << (trace.second_rready_while_first_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_FIRST_HELD = 1'b"
     << (trace.blocked_while_first_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_SECOND_HELD = 1'b"
     << (trace.blocked_while_second_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_ACCEPTED_AFTER_RETIRE = 1'b"
     << (trace.accepted_after_resp_retire ? 1 : 0) << ";\n";
}

void emit_invalidate_line_cache_read_write(
    std::ostream &os, const InvalidateLineCacheReadWriteTrace &trace) {
  emit_read(os, trace.read);
  emit_cache_write_req_resp(os, trace.write);
  emit_read(os, trace.write_refill);
  os << "localparam integer " << trace.prefix
     << "_READ_MASTER = " << static_cast<unsigned>(trace.read_master) << ";\n";
  os << "localparam integer " << trace.prefix
     << "_WRITE_MASTER = " << static_cast<unsigned>(trace.write_master)
     << ";\n";
  os << "localparam [31:0] " << trace.prefix
     << "_INVALIDATE_ADDR = " << hex_u32(trace.invalidate_addr) << ";\n";
  os << "localparam " << trace.prefix << "_READ_RREADY_PENDING = 1'b"
     << (trace.read_rready_while_invalidate_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_WRITE_RREADY_READ_HELD = 1'b"
     << (trace.write_rready_while_read_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_READ_HELD = 1'b"
     << (trace.blocked_while_read_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_WRITE_HELD = 1'b"
     << (trace.blocked_while_write_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_ACCEPTED_AFTER_RETIRE = 1'b"
     << (trace.accepted_after_resp_retire ? 1 : 0) << ";\n";
}

void emit_invalidate_all_cache_read_write(
    std::ostream &os, const InvalidateAllCacheReadWriteTrace &trace) {
  emit_read(os, trace.read);
  emit_cache_write_req_resp(os, trace.write);
  emit_read(os, trace.write_refill);
  os << "localparam integer " << trace.prefix
     << "_READ_MASTER = " << static_cast<unsigned>(trace.read_master) << ";\n";
  os << "localparam integer " << trace.prefix
     << "_WRITE_MASTER = " << static_cast<unsigned>(trace.write_master)
     << ";\n";
  os << "localparam " << trace.prefix << "_READ_RREADY_PENDING = 1'b"
     << (trace.read_rready_while_invalidate_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_WRITE_RREADY_READ_HELD = 1'b"
     << (trace.write_rready_while_read_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_READ_HELD = 1'b"
     << (trace.blocked_while_read_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_WRITE_HELD = 1'b"
     << (trace.blocked_while_write_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_ACCEPTED_AFTER_RETIRE = 1'b"
     << (trace.accepted_after_resp_retire ? 1 : 0) << ";\n";
}

void emit_reconfig_cache_read(std::ostream &os,
                              const ReconfigCacheReadTrace &trace) {
  emit_read(os, trace.read);
  os << "localparam integer " << trace.read.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.read_master) << ";\n";
  os << "localparam " << trace.read.prefix << "_RREADY_PENDING = 1'b"
     << (trace.rready_while_reconfig_pending ? 1 : 0) << ";\n";
}

void emit_reconfig_cache_write(std::ostream &os,
                               const ReconfigCacheWriteTrace &trace) {
  emit_cache_write_req_resp(os, trace.write);
  os << "localparam integer " << trace.write.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.write_master) << ";\n";
  emit_read(os, trace.refill);
  os << "localparam " << trace.refill.prefix << "_RREADY_PENDING = 1'b"
     << (trace.rready_while_reconfig_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.write.prefix << "_BLOCKED_AFTER_RETIRE = 1'b"
     << (trace.blocked_after_resp_retire ? 1 : 0) << ";\n";
}

void emit_invalidate_line_cache_mmio_read(
    std::ostream &os, const InvalidateLineCacheMmioReadTrace &trace) {
  emit_overlap_read(os, trace.overlap);
  os << "localparam [31:0] " << trace.prefix
     << "_INVALIDATE_ADDR = " << hex_u32(trace.invalidate_addr) << ";\n";
  os << "localparam " << trace.prefix << "_MMIO_RREADY_PENDING = 1'b"
     << (trace.mmio_rready_while_invalidate_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_DDR_RREADY_MMIO_HELD = 1'b"
     << (trace.ddr_rready_while_mmio_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_MMIO_HELD = 1'b"
     << (trace.blocked_while_mmio_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_CACHE_HELD = 1'b"
     << (trace.blocked_while_cache_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_ACCEPTED_AFTER_RETIRE = 1'b"
     << (trace.accepted_after_resp_retire ? 1 : 0) << ";\n";
}

void emit_invalidate_line_cache_mmio_write(
    std::ostream &os, const InvalidateLineCacheMmioWriteTrace &trace) {
  emit_cache_write_miss_mmio_write(os, trace.flow);
  os << "localparam [31:0] " << trace.prefix
     << "_INVALIDATE_ADDR = " << hex_u32(trace.invalidate_addr) << ";\n";
  os << "localparam " << trace.prefix << "_MMIO_BREADY_PENDING = 1'b"
     << (trace.mmio_bready_while_invalidate_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_DDR_RREADY_MMIO_HELD = 1'b"
     << (trace.ddr_rready_while_mmio_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_MMIO_HELD = 1'b"
     << (trace.blocked_while_mmio_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_CACHE_HELD = 1'b"
     << (trace.blocked_while_cache_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_ACCEPTED_AFTER_RETIRE = 1'b"
     << (trace.accepted_after_resp_retire ? 1 : 0) << ";\n";
}

void emit_same_line_read_pending_write(
    std::ostream &os, const SameLineReadPendingWriteTrace &trace) {
  os << "\n";
  os << "localparam [31:0] " << trace.read.prefix
     << "_REQ_ADDR = " << hex_u32(trace.read.req_addr) << ";\n";
  os << "localparam [7:0] " << trace.read.prefix
     << "_REQ_SIZE = 8'd" << static_cast<unsigned>(trace.read.req_size)
     << ";\n";
  os << "localparam [3:0] " << trace.read.prefix
     << "_REQ_ID = 4'd" << static_cast<unsigned>(trace.read.req_id) << ";\n";
  os << "localparam [31:0] " << trace.read.prefix
     << "_ARADDR = " << hex_u32(trace.read.araddr) << ";\n";
  os << "localparam [7:0] " << trace.read.prefix
     << "_ARLEN = 8'd" << static_cast<unsigned>(trace.read.arlen) << ";\n";
  os << "localparam [2:0] " << trace.read.prefix
     << "_ARSIZE = 3'd" << static_cast<unsigned>(trace.read.arsize) << ";\n";
  os << "localparam [1:0] " << trace.read.prefix
     << "_ARBURST = 2'd" << static_cast<unsigned>(trace.read.arburst) << ";\n";
  os << "localparam [5:0] " << trace.read.prefix
     << "_ARID = 6'd" << static_cast<unsigned>(trace.read.arid) << ";\n";
  os << "localparam integer " << trace.read.prefix
     << "_BEATS = " << trace.read.beat_count << ";\n";
  os << "localparam integer " << trace.read.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.read_master) << ";\n";
  emit_blocked_write(os, trace.write);
  os << "localparam integer " << trace.write.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.write_master) << ";\n";
  os << "localparam " << trace.write.prefix
     << "_ACCEPTED_WHILE_READ_PENDING = 1'b"
     << (trace.write_accepted_while_read_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.write.prefix
     << "_NO_EXTERNAL_ISSUE_WHILE_READ_PENDING = 1'b"
     << (trace.no_external_issue_while_read_pending ? 1 : 0) << ";\n";
}

void emit_same_line_write_pending_read(
    std::ostream &os, const SameLineWritePendingReadTrace &trace) {
  emit_write(os, trace.write);
  os << "localparam integer " << trace.write.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.write_master) << ";\n";
  emit_blocked_read(os, trace.read);
  os << "localparam integer " << trace.read.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.read_master) << ";\n";
  os << "localparam " << trace.read.prefix
     << "_ACCEPTED_WHILE_WRITE_PENDING = 1'b"
     << (trace.read_accepted_while_write_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.read.prefix
     << "_NO_EXTERNAL_ISSUE_WHILE_WRITE_PENDING = 1'b"
     << (trace.no_external_issue_while_write_pending ? 1 : 0) << ";\n";
}

void emit_invalidate_all_cache_mmio_read(
    std::ostream &os, const InvalidateAllCacheMmioReadTrace &trace) {
  emit_overlap_read(os, trace.overlap);
  os << "localparam " << trace.prefix << "_MMIO_RREADY_PENDING = 1'b"
     << (trace.mmio_rready_while_invalidate_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_DDR_RREADY_MMIO_HELD = 1'b"
     << (trace.ddr_rready_while_mmio_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_MMIO_HELD = 1'b"
     << (trace.blocked_while_mmio_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_CACHE_HELD = 1'b"
     << (trace.blocked_while_cache_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_ACCEPTED_AFTER_RETIRE = 1'b"
     << (trace.accepted_after_resp_retire ? 1 : 0) << ";\n";
}

void emit_invalidate_all_cache_mmio_write(
    std::ostream &os, const InvalidateAllCacheMmioWriteTrace &trace) {
  emit_cache_write_miss_mmio_write(os, trace.flow);
  os << "localparam " << trace.prefix << "_MMIO_BREADY_PENDING = 1'b"
     << (trace.mmio_bready_while_invalidate_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_DDR_RREADY_MMIO_HELD = 1'b"
     << (trace.ddr_rready_while_mmio_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_MMIO_HELD = 1'b"
     << (trace.blocked_while_mmio_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_CACHE_HELD = 1'b"
     << (trace.blocked_while_cache_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_ACCEPTED_AFTER_RETIRE = 1'b"
     << (trace.accepted_after_resp_retire ? 1 : 0) << ";\n";
}

void emit_invalidate_all_cache_mmio_read_write(
    std::ostream &os, const InvalidateAllCacheMmioReadWriteTrace &trace) {
  emit_overlap_read(os, trace.overlap);
  emit_write(os, trace.mmio_write);
  os << "localparam integer " << trace.mmio_write.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.mmio_write_master) << ";\n";
  os << "localparam " << trace.mmio_write.prefix << "_BREADY_STALLED = 1'b"
     << (trace.mmio_bready_while_invalidate_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_MMIO_RREADY_PENDING = 1'b"
     << (trace.mmio_rready_while_invalidate_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_MMIO_BREADY_PENDING = 1'b"
     << (trace.mmio_bready_while_invalidate_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_DDR_RREADY_MMIO_HELD = 1'b"
     << (trace.ddr_rready_while_mmio_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_MMIO_HELD = 1'b"
     << (trace.blocked_while_mmio_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_CACHE_HELD = 1'b"
     << (trace.blocked_while_cache_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_ACCEPTED_AFTER_RETIRE = 1'b"
     << (trace.accepted_after_resp_retire ? 1 : 0) << ";\n";
}

void emit_invalidate_line_cache_mmio_read_write(
    std::ostream &os, const InvalidateLineCacheMmioReadWriteTrace &trace) {
  emit_overlap_read(os, trace.overlap);
  emit_write(os, trace.mmio_write);
  os << "localparam integer " << trace.mmio_write.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.mmio_write_master) << ";\n";
  os << "localparam [31:0] " << trace.prefix
     << "_INVALIDATE_ADDR = 32'h" << std::hex << std::setw(8)
     << std::setfill('0') << trace.invalidate_addr << std::dec
     << std::setfill(' ') << ";\n";
  os << "localparam " << trace.mmio_write.prefix << "_BREADY_STALLED = 1'b"
     << (trace.mmio_bready_while_invalidate_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_MMIO_RREADY_PENDING = 1'b"
     << (trace.mmio_rready_while_invalidate_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_MMIO_BREADY_PENDING = 1'b"
     << (trace.mmio_bready_while_invalidate_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_DDR_RREADY_MMIO_HELD = 1'b"
     << (trace.ddr_rready_while_mmio_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_MMIO_HELD = 1'b"
     << (trace.blocked_while_mmio_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_CACHE_HELD = 1'b"
     << (trace.blocked_while_cache_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_ACCEPTED_AFTER_RETIRE = 1'b"
     << (trace.accepted_after_resp_retire ? 1 : 0) << ";\n";
}

void emit_invalidate_line_cache_write_mmio_read_write(
    std::ostream &os,
    const InvalidateLineCacheWriteMmioReadWriteTrace &trace) {
  emit_cache_write_miss_mmio_write(os, trace.flow);
  emit_read(os, trace.mmio_read);
  os << "localparam integer " << trace.mmio_read.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.mmio_read_master)
     << ";\n";
  os << "localparam " << trace.mmio_read.prefix << "_RREADY_STALLED = 1'b"
     << (trace.mmio_rready_while_invalidate_pending ? 1 : 0) << ";\n";
  os << "localparam [31:0] " << trace.prefix
     << "_INVALIDATE_ADDR = " << hex_u32(trace.invalidate_addr) << ";\n";
  os << "localparam " << trace.prefix << "_MMIO_RREADY_PENDING = 1'b"
     << (trace.mmio_rready_while_invalidate_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_MMIO_BREADY_PENDING = 1'b"
     << (trace.mmio_bready_while_invalidate_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_DDR_RREADY_MMIO_HELD = 1'b"
     << (trace.ddr_rready_while_mmio_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_MMIO_HELD = 1'b"
     << (trace.blocked_while_mmio_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_CACHE_HELD = 1'b"
     << (trace.blocked_while_cache_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_ACCEPTED_AFTER_RETIRE = 1'b"
     << (trace.accepted_after_resp_retire ? 1 : 0) << ";\n";
}

void emit_invalidate_all_cache_write_mmio_read_write(
    std::ostream &os,
    const InvalidateAllCacheWriteMmioReadWriteTrace &trace) {
  emit_cache_write_miss_mmio_write(os, trace.flow);
  emit_read(os, trace.mmio_read);
  os << "localparam integer " << trace.mmio_read.prefix
     << "_MASTER = " << static_cast<unsigned>(trace.mmio_read_master)
     << ";\n";
  os << "localparam " << trace.mmio_read.prefix << "_RREADY_STALLED = 1'b"
     << (trace.mmio_rready_while_invalidate_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_MMIO_RREADY_PENDING = 1'b"
     << (trace.mmio_rready_while_invalidate_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_MMIO_BREADY_PENDING = 1'b"
     << (trace.mmio_bready_while_invalidate_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_DDR_RREADY_MMIO_HELD = 1'b"
     << (trace.ddr_rready_while_mmio_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_MMIO_HELD = 1'b"
     << (trace.blocked_while_mmio_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_CACHE_HELD = 1'b"
     << (trace.blocked_while_cache_resp_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_ACCEPTED_AFTER_RETIRE = 1'b"
     << (trace.accepted_after_resp_retire ? 1 : 0) << ";\n";
}

void emit_invalidate_all_mmio_read_write(
    std::ostream &os, const InvalidateAllMmioReadWriteTrace &trace) {
  emit_read(os, trace.read);
  emit_write(os, trace.write);
  os << "localparam " << trace.prefix << "_BLOCKED_BEFORE_RESP = 1'b"
     << (trace.blocked_before_resp ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_RREADY_PENDING = 1'b"
     << (trace.rready_while_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BREADY_PENDING = 1'b"
     << (trace.bready_while_pending ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_BOTH_HELD = 1'b"
     << (trace.blocked_while_both_held ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_BLOCKED_AFTER_READ_RETIRE = 1'b"
     << (trace.blocked_after_read_retire ? 1 : 0) << ";\n";
  os << "localparam " << trace.prefix << "_ACCEPTED_AFTER_BOTH_RETIRE = 1'b"
     << (trace.accepted_after_both_retire ? 1 : 0) << ";\n";
}

void emit_vectors(std::ostream &os) {
  const auto read1 = run_read_trace("CPP_MODE0_DDR_READ1", 0x4000001fu, 0,
                                    0xCu, {0xa5b61300u});
  const auto read2 = run_read_trace("CPP_MODE0_DDR_READ2", 0x4000001eu, 1,
                                    0xDu, {0xc7d81400u});
  const auto read4 = run_read_trace("CPP_MODE0_DDR_READ4", 0x40000004u, 3,
                                    0x1, {0x1000u});
  const auto read8 = run_read_trace("CPP_MODE0_DDR_READ8", 0x40000000u, 7,
                                    0x2, {0x1100u});
  const auto read16 = run_read_trace("CPP_MODE0_DDR_READ16", 0x40000010u, 15,
                                     0xBu, {0x1200u});
  const auto read32 = run_read_trace("CPP_MODE0_DDR_READ32", 0x40000020u, 31,
                                     0xEu, {0x1500u});
  const auto read64 = run_read_trace("CPP_MODE0_DDR_READ64", 0x40000000u, 63,
                                     0x4, {0x2000u, 0x3000u});
  const auto write1 =
      run_write_trace("CPP_MODE0_DDR_WRITE1", 0x4000001fu, 0, 0xCu,
                      single_word_data(0x000000a5u), byte_strobe(0x1u));
  const auto write2 =
      run_write_trace("CPP_MODE0_DDR_WRITE2", 0x4000001eu, 1, 0xDu,
                      single_word_data(0x0000b6a5u), byte_strobe(0x3u));
  const auto write4 =
      run_write_trace("CPP_MODE0_DDR_WRITE4", 0x40000004u, 3, 0x3,
                      single_word_data(0xaabbccddu), byte_strobe(0xfu));
  const auto write8 =
      run_write_trace("CPP_MODE0_DDR_WRITE8", 0x40000008u, 7, 0xEu,
                      line_write_data(0x6200u), byte_strobe(0xffu));
  const auto write16 =
      run_write_trace("CPP_MODE0_DDR_WRITE16", 0x40000010u, 15, 0xBu,
                      line_write_data(0x6100u), byte_strobe(0xffffu));
  const auto write32 =
      run_write_trace("CPP_MODE0_DDR_WRITE32", 0x40000020u, 31, 0xFu,
                      line_write_data(0x6300u), byte_strobe(0xffffffffu));
  const auto write64 =
      run_write_trace("CPP_MODE0_DDR_WRITE64", 0x40000000u, 63, 0x5,
                      line_write_data(0x5000u), full_line_strobe());
  const auto mmio_read4 = run_mmio_read_trace(
      "CPP_MODE0_MMIO_READ4", 0x10000020u, 3, 0x6, 0xc001d00du);
  const auto mmio_write4 =
      run_mmio_write_trace("CPP_MODE0_MMIO_WRITE4", 0x10000024u, 3, 0x7,
                           single_word_data(0x11223344u), byte_strobe(0xfu));
  const auto mmio_read8_blocked = run_unsupported_mmio_read_trace(
      "CPP_MODE0_MMIO_READ8_UNSUPPORTED", 0x10000040u, 7, 0x8);
  const auto mmio_write8_blocked = run_unsupported_mmio_write_trace(
      "CPP_MODE0_MMIO_WRITE8_UNSUPPORTED", 0x10000048u, 7, 0x9,
      line_write_data(0x9000u), byte_strobe(0xffu));
  const auto overlap_read = run_overlapped_read_trace();
  const auto overlap_read64 = run_overlapped_read64_trace();
  const auto same_master_read = run_same_master_read_order_trace();
  const auto same_master_write = run_same_master_write_order_trace();
  const auto read_reuse = run_read_reuse_trace();
  const auto read_budget_release = run_read_budget_release_trace();
  const auto overlap_write = run_overlapped_write_trace();
  const auto overlap_write64 = run_overlapped_write64_trace();
  const auto write_reuse = run_write_reuse_trace();
  const auto write_budget_release = run_write_budget_release_trace();
  const auto mode0_same_line_write_pending_read =
      run_mode0_same_line_write_pending_read_trace();
  const auto mode1_mmio_read4 = run_mode1_mmio_read_trace(
      "CPP_MODE1_MMIO_READ4", 0x10000088u, 3, 0xEu, 0xabcd0088u);
  const auto mode1_mmio_write4 =
      run_mode1_mmio_write_trace("CPP_MODE1_MMIO_WRITE4", 0x1000008cu, 3, 0xFu,
                                 single_word_data(0xface008cu),
                                 byte_strobe(0xfu));
  const auto mode1_cache_mmio_overlap_read =
      run_mode1_cache_mmio_overlap_read_trace();
  const auto mode1_invalidate_line_pending_read =
      run_mode1_invalidate_line_pending_read_trace();
  const auto mode1_invalidate_line_recovery_read =
      run_mode1_invalidate_line_recovery_read_trace();
  const auto mode1_invalidate_line_scope_read =
      run_mode1_invalidate_line_scope_read_trace();
  const auto mode1_invalidate_all_recovery_cache_read =
      run_mode1_invalidate_all_recovery_cache_read_trace();
  const auto mode1_invalidate_all_multi_master_recovery_cache_read =
      run_mode1_invalidate_all_multi_master_recovery_read_trace();
  const auto mode1_invalidate_all_recovery_cache_write =
      run_mode1_invalidate_all_recovery_cache_write_trace();
  const auto mode1_invalidate_all_multi_read =
      run_mode1_invalidate_all_multi_read_trace();
  const auto mode1_invalidate_all_multi_master_read =
      run_mode1_invalidate_all_multi_master_read_trace();
  const auto mode1_invalidate_line_multi_master_read =
      run_mode1_invalidate_line_multi_master_read_trace();
  const auto mode1_invalidate_line_multi_read =
      run_mode1_invalidate_line_multi_read_trace();
  const auto mode1_invalidate_line_cache_read_write =
      run_mode1_invalidate_line_cache_read_write_trace();
  const auto mode1_invalidate_all_cache_read_write =
      run_mode1_invalidate_all_cache_read_write_trace();
  const auto mode1_invalidate_line_cache_mmio_read =
      run_mode1_invalidate_line_cache_mmio_read_trace();
  const auto mode1_same_line_read_pending_write =
      run_mode1_same_line_read_pending_write_trace();
  const auto mode1_invalidate_all_cache_mmio_read =
      run_mode1_invalidate_all_cache_mmio_read_trace();
  const auto mode1_cache_write_miss_mmio_write =
      run_mode1_cache_write_miss_mmio_write_trace();
  const auto mode1_invalidate_all_cache_mmio_write =
      run_mode1_invalidate_all_cache_mmio_write_trace();
  const auto mode1_invalidate_line_cache_mmio_write =
      run_mode1_invalidate_line_cache_mmio_write_trace();
  const auto mode1_invalidate_line_cache_mmio_read_write =
      run_mode1_invalidate_line_cache_mmio_read_write_trace();
  const auto mode1_invalidate_line_other_cache_mmio_read_write =
      run_mode1_invalidate_line_cache_mmio_read_write_trace(
          "CPP_MODE1_INVLINE_OTHER_CACHE_MMIO_RW", 0x40001f04u, 0x9u,
          0x10000380u, 0xAu, 0xcafe0380u, 0x100003c0u, 0xBu,
          0xface03c0u, 0x40003f04u, 0xd00d1f00u);
  const auto mode1_invalidate_line_cache_write_mmio_read_write =
      run_mode1_invalidate_line_cache_write_mmio_read_write_trace();
  const auto mode1_invalidate_all_cache_write_mmio_read_write =
      run_mode1_invalidate_all_cache_write_mmio_read_write_trace();
  const auto mode1_invalidate_all_cache_mmio_read_write =
      run_mode1_invalidate_all_cache_mmio_read_write_trace();
  const auto mode1_dirty_victim_mmio_write =
      run_mode1_dirty_victim_mmio_write_trace();
  const auto mode1_dirty_victim_mmio_read =
      run_mode1_dirty_victim_mmio_read_trace();
  const auto mode1_dirty_victim_mmio_read_write =
      run_mode1_dirty_victim_mmio_read_write_trace();
  const auto mode2_mapped_local = run_mode2_mapped_local_write_read_trace();
  const auto mode2_mapped_low_boundary =
      run_mode2_mapped_local_write_read_trace(
          "CPP_MODE2_MAPPED_LOW_BOUNDARY", 0x30000000u, 3, 0x1u,
          single_word_data(0x0123abcdu), byte_strobe(0xfu), 0x30000000u, 3,
          0x2u);
  const auto mode2_mapped_contract_limit_boundary =
      run_mode2_mapped_local_write_read_trace(
          "CPP_MODE2_MAPPED_CONTRACT_LIMIT", 0x3001ffc0u, 63, 0x3u,
          line_write_data(0x83000000u), full_line_strobe(), 0x3001fffcu, 3,
          0x4u);
  const auto mode2_mmio_below_read4 = run_mode2_mmio_read_trace(
      "CPP_MODE2_MMIO_BELOW_READ4", 0x2ffffffcu, 3, 0xBu, 0xabcdfffcu);
  const auto mode2_mmio_below_write4 =
      run_mode2_mmio_write_trace("CPP_MODE2_MMIO_BELOW_WRITE4", 0x2ffffffcu,
                                 3, 0xDu, single_word_data(0xfacefffcu),
                                 byte_strobe(0xfu));
  const auto mode2_mmio_above_read4 = run_mode2_mmio_read_trace(
      "CPP_MODE2_MMIO_ABOVE_READ4", 0x30400000u, 3, 0xEu, 0xabcd4000u);
  const auto mode2_mmio_above_write4 =
      run_mode2_mmio_write_trace("CPP_MODE2_MMIO_ABOVE_WRITE4", 0x30400000u, 3,
                                 0xCu, single_word_data(0xface4000u),
                                 byte_strobe(0xfu));
  const auto mode2_cross_read8_blocked =
      run_unsupported_mmio_read_trace(
          "CPP_MODE2_MAPPED_CROSS_READ8_UNSUPPORTED", 0x303ffffcu, 7, 0x5u,
          true);
  const auto mode2_cross_write8_blocked =
      run_unsupported_mmio_write_trace(
          "CPP_MODE2_MAPPED_CROSS_WRITE8_UNSUPPORTED", 0x303ffffcu, 7, 0x6u,
          single_word_data(0xfacefffc), byte_strobe(0xffu), true);
  const auto mode1_invalidate_all_read_blocked =
      run_mode1_invalidate_all_blocks_read_trace(
          "CPP_MODE1_INVALIDATE_ALL_READ_BLOCKED", 0x40006000u, 3, 0x7u);
  const auto mode1_invalidate_all_write_blocked =
      run_mode1_invalidate_all_blocks_write_trace(
          "CPP_MODE1_INVALIDATE_ALL_WRITE_BLOCKED", 0x40006040u, 3, 0x8u,
          single_word_data(0xface6040u), byte_strobe(0xfu));
  const auto mode1_invalidate_all_recovery_mmio_read =
      run_mode1_invalidate_all_recovery_mmio_read_trace(
          "CPP_MODE1_INVALIDATE_ALL_RECOVERY_MMIO_READ", 0x1000009cu, 3, 0x9u,
          0xabcd009cu);
  const auto mode1_invalidate_all_pending_mmio_read =
      run_mode1_invalidate_all_pending_mmio_read_trace(
          "CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_READ", 0x100000a0u, 3, 0xBu,
          0xabcd00a0u);
  const auto mode1_invalidate_all_pending_mmio_write =
      run_mode1_invalidate_all_pending_mmio_write_trace(
          "CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_WRITE", 0x100000a4u, 3, 0xCu,
          single_word_data(0xface00a4u), byte_strobe(0xfu));
  const auto mode1_invalidate_all_pending_mmio_read_write =
      run_mode1_invalidate_all_pending_mmio_read_write_trace(
          "CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW", 0x100000b0u, 3, 0x3u,
          0xabcd00b0u, 0x10000110u, 3, 0x4u,
          single_word_data(0xface00b4u), byte_strobe(0xfu));
  const auto mode1_same_line_mmio_read_pending_write =
      run_mode1_same_line_mmio_read_pending_write_trace();
  const auto mode1_same_line_mmio_write_pending_read =
      run_mode1_same_line_mmio_write_pending_read_trace();
  const auto mode1_invalidate_all_pre_ar_mmio_read =
      run_mode1_invalidate_all_pre_ar_mmio_read_trace(
          "CPP_MODE1_INVALIDATE_ALL_PRE_AR_MMIO_READ", 0x100000a8u, 3, 0xDu,
          0xabcd00a8u);
  const auto mode1_invalidate_all_pre_aw_w_mmio_write =
      run_mode1_invalidate_all_pre_aw_w_mmio_write_trace(
          "CPP_MODE1_INVALIDATE_ALL_PRE_AW_W_MMIO_WRITE", 0x100000acu, 3, 0xEu,
          single_word_data(0xface00acu), byte_strobe(0xfu));
  const auto mode1_to_mode2_mmio_above_read4 =
      run_mode1_to_mode2_mmio_read_trace(
          "CPP_MODE1_TO_MODE2_MMIO_ABOVE_READ4", 0x30400004u, 3, 0xAu,
          0xabcd4004u);
  const auto mode1_to_mode2_pending_mmio_read =
      run_mode1_to_mode2_pending_mmio_read_trace(
          "CPP_MODE1_TO_MODE2_PENDING_MMIO_READ", 0x100000e0u, 3, 0xBu,
          0xabcd00e0u);
  const auto mode1_to_mode2_pending_mmio_write =
      run_mode1_to_mode2_pending_mmio_write_trace(
          "CPP_MODE1_TO_MODE2_PENDING_MMIO_WRITE", 0x100000e4u, 3, 0xCu,
          single_word_data(0xface00e4u), byte_strobe(0xfu));
  const auto mode1_to_mode2_pending_mmio_read_write =
      run_mode1_to_mode2_pending_mmio_read_write_trace(
          "CPP_MODE1_TO_MODE2_PENDING_MMIO_RW", 0x100000e8u, 3, 0xDu,
          0xabcd00e8u, 0x10000128u, 3, 0xEu,
          single_word_data(0xface0128u), byte_strobe(0xfu));
  const auto mode1_to_mode2_pending_cache_read =
      run_mode1_to_mode2_pending_cache_read_trace();
  const auto mode1_to_mode2_pending_cache_write =
      run_mode1_to_mode2_pending_cache_write_trace();

  os << "`ifndef AXI_DUAL_CPP_TRACE_VECTORS_VH\n";
  os << "`define AXI_DUAL_CPP_TRACE_VECTORS_VH\n";
  os << "// Generated by axi_interconnect_dual_port_trace_vectors_test.cpp from\n";
  os << "// the production AXI_Interconnect comb/seq model. Do not hand-edit\n";
  os << "// expected values in this file; regenerate them from the C++ model.\n";
  emit_read(os, read1);
  emit_read(os, read2);
  emit_read(os, read4);
  emit_read(os, read8);
  emit_read(os, read16);
  emit_read(os, read32);
  emit_read(os, read64);
  emit_write(os, write1);
  emit_write(os, write2);
  emit_write(os, write4);
  emit_write(os, write8);
  emit_write(os, write16);
  emit_write(os, write32);
  emit_write(os, write64);
  emit_read(os, mmio_read4);
  emit_write(os, mmio_write4);
  emit_blocked_read(os, mmio_read8_blocked);
  emit_blocked_write(os, mmio_write8_blocked);
  emit_overlap_read(os, overlap_read);
  emit_overlap_read(os, overlap_read64);
  emit_same_master_read(os, same_master_read);
  emit_same_master_write(os, same_master_write);
  emit_read_reuse(os, read_reuse);
  emit_read_budget_release(os, read_budget_release);
  emit_overlap_write(os, overlap_write);
  emit_overlap_write(os, overlap_write64);
  emit_write_reuse(os, write_reuse);
  emit_write_budget_release(os, write_budget_release);
  emit_same_line_write_pending_read(os, mode0_same_line_write_pending_read);
  emit_read(os, mode1_mmio_read4);
  emit_write(os, mode1_mmio_write4);
  emit_overlap_read(os, mode1_cache_mmio_overlap_read);
  emit_invalidate_line_pending_read(os, mode1_invalidate_line_pending_read);
  emit_invalidate_line_recovery_read(os,
                                     mode1_invalidate_line_recovery_read);
  emit_invalidate_line_scope_read(os, mode1_invalidate_line_scope_read);
  emit_invalidate_all_recovery_cache_read(
      os, mode1_invalidate_all_recovery_cache_read);
  emit_invalidate_all_multi_master_recovery_cache_read(
      os, mode1_invalidate_all_multi_master_recovery_cache_read);
  emit_invalidate_all_recovery_cache_write(
      os, mode1_invalidate_all_recovery_cache_write);
  emit_invalidate_all_multi_read(os, mode1_invalidate_all_multi_read);
  emit_invalidate_all_multi_master_read(
      os, mode1_invalidate_all_multi_master_read);
  emit_invalidate_line_multi_master_read(
      os, mode1_invalidate_line_multi_master_read);
  emit_invalidate_line_multi_read(os, mode1_invalidate_line_multi_read);
  emit_invalidate_line_cache_read_write(
      os, mode1_invalidate_line_cache_read_write);
  emit_invalidate_all_cache_read_write(
      os, mode1_invalidate_all_cache_read_write);
  emit_invalidate_line_cache_mmio_read(
      os, mode1_invalidate_line_cache_mmio_read);
  emit_same_line_read_pending_write(os, mode1_same_line_read_pending_write);
  emit_invalidate_all_cache_mmio_read(os,
                                      mode1_invalidate_all_cache_mmio_read);
  emit_cache_write_miss_mmio_write(os, mode1_cache_write_miss_mmio_write);
  emit_invalidate_all_cache_mmio_write(
      os, mode1_invalidate_all_cache_mmio_write);
  emit_invalidate_line_cache_mmio_write(
      os, mode1_invalidate_line_cache_mmio_write);
  emit_invalidate_line_cache_mmio_read_write(
      os, mode1_invalidate_line_cache_mmio_read_write);
  emit_invalidate_line_cache_mmio_read_write(
      os, mode1_invalidate_line_other_cache_mmio_read_write);
  emit_invalidate_line_cache_write_mmio_read_write(
      os, mode1_invalidate_line_cache_write_mmio_read_write);
  emit_invalidate_all_cache_write_mmio_read_write(
      os, mode1_invalidate_all_cache_write_mmio_read_write);
  emit_invalidate_all_cache_mmio_read_write(
      os, mode1_invalidate_all_cache_mmio_read_write);
  emit_dirty_victim_mmio_write(os, mode1_dirty_victim_mmio_write);
  emit_dirty_victim_mmio_read(os, mode1_dirty_victim_mmio_read);
  emit_dirty_victim_mmio_read_write(os, mode1_dirty_victim_mmio_read_write);
  emit_mode2_mapped_local(os, mode2_mapped_local);
  emit_mode2_mapped_local(os, mode2_mapped_low_boundary);
  emit_mode2_mapped_local(os, mode2_mapped_contract_limit_boundary);
  emit_read(os, mode2_mmio_below_read4);
  emit_write(os, mode2_mmio_below_write4);
  emit_read(os, mode2_mmio_above_read4);
  emit_write(os, mode2_mmio_above_write4);
  emit_blocked_read(os, mode2_cross_read8_blocked);
  emit_blocked_write(os, mode2_cross_write8_blocked);
  emit_blocked_read(os, mode1_invalidate_all_read_blocked);
  emit_blocked_write(os, mode1_invalidate_all_write_blocked);
  emit_read(os, mode1_invalidate_all_recovery_mmio_read);
  emit_read(os, mode1_invalidate_all_pending_mmio_read);
  emit_write(os, mode1_invalidate_all_pending_mmio_write);
  emit_invalidate_all_mmio_read_write(
      os, mode1_invalidate_all_pending_mmio_read_write);
  emit_same_line_read_pending_write(
      os, mode1_same_line_mmio_read_pending_write);
  emit_same_line_write_pending_read(
      os, mode1_same_line_mmio_write_pending_read);
  emit_read(os, mode1_invalidate_all_pre_ar_mmio_read);
  emit_write(os, mode1_invalidate_all_pre_aw_w_mmio_write);
  emit_read(os, mode1_to_mode2_mmio_above_read4);
  emit_read(os, mode1_to_mode2_pending_mmio_read);
  emit_write(os, mode1_to_mode2_pending_mmio_write);
  emit_read(os, mode1_to_mode2_pending_mmio_read_write.read);
  emit_write(os, mode1_to_mode2_pending_mmio_read_write.write);
  emit_reconfig_cache_read(os, mode1_to_mode2_pending_cache_read);
  emit_reconfig_cache_write(os, mode1_to_mode2_pending_cache_write);
  os << "\n`endif\n";
}

} // namespace

uint32_t pmem_read(uint32_t paddr) {
  if (paddr >= 0x10000000u &&
      legacy_backing_index(paddr) <
          (sizeof(g_legacy_backing_words) / sizeof(g_legacy_backing_words[0]))) {
    return g_legacy_backing_words[legacy_backing_index(paddr)];
  }
  return 0;
}

void pmem_write(uint32_t paddr, uint32_t data) {
  if (paddr >= 0x10000000u &&
      legacy_backing_index(paddr) <
          (sizeof(g_legacy_backing_words) / sizeof(g_legacy_backing_words[0]))) {
    g_legacy_backing_words[legacy_backing_index(paddr)] = data;
  }
}

int main(int argc, char **argv) {
  try {
    if (argc > 1) {
      std::ofstream out(argv[1]);
      require(out.good(), "failed to open output vector file");
      emit_vectors(out);
    } else {
      emit_vectors(std::cout);
    }
  } catch (const std::exception &e) {
    std::fprintf(stderr, "axi_interconnect_dual_port_trace_vectors FAIL: %s\n",
                 e.what());
    return 1;
  }
  return 0;
}
