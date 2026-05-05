/**
 * @file axi_llc_cache_trace_vectors.cpp
 * @brief Emit RTL cache-control vectors from the production AXI_LLC model.
 *
 * The generated include is consumed by RTL contract tests. Expected cache
 * table updates come from the actual C++ AXI_LLC comb/seq path; this file only
 * adapts the abstract C++ table encoding to the RTL llc_cache_ctrl row format.
 */

#include "AXI_LLC.h"

#include <array>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>

uint32_t *p_memory = nullptr;
long long sim_time = 0;

namespace {

using u128 = unsigned __int128;

constexpr uint32_t kAddrBits = 32;
constexpr uint32_t kIdBits = 4;
constexpr uint32_t kLineBytes = 8;
constexpr uint32_t kLineBits = 64;
constexpr uint32_t kLineOffsetBits = 3;
constexpr uint32_t kSetCount = 2;
constexpr uint32_t kSetBits = 1;
constexpr uint32_t kWayCount = 2;
constexpr uint32_t kWayBits = 1;
constexpr uint32_t kTagBits = kAddrBits - kSetBits - kLineOffsetBits;
constexpr uint32_t kMetaBits = kTagBits + 1;
constexpr uint32_t kDataRowBits = kWayCount * kLineBits;
constexpr uint32_t kMetaRowBits = kWayCount * kMetaBits;

constexpr uint32_t kReqAddr = 0x40000102u;
constexpr uint8_t kReqSize = 1;
constexpr uint8_t kReqId = 7;
constexpr uint64_t kBaseLine = 0x1122334455667788ull;
constexpr uint64_t kOtherLine = 0x0102030405060708ull;
constexpr uint64_t kReqData = 0x000000000000bbaaull;
constexpr uint64_t kReqStrb = 0x03ull;
constexpr uint32_t kMissAddr = 0x40000200u;
constexpr uint8_t kMissSize = 7;
constexpr uint8_t kMissId = 0;
constexpr uint64_t kMissRefillLine = 0x99aabbccddeeff00ull;
constexpr uint32_t kWriteMissAddr = 0x40000302u;
constexpr uint8_t kWriteMissSize = 1;
constexpr uint8_t kWriteMissId = 0;
constexpr uint64_t kWriteMissData = 0x000000000000bbaaull;
constexpr uint64_t kWriteMissStrb = 0x03ull;
constexpr uint64_t kWriteMissRefillLine = 0x1122334455667788ull;
constexpr uint32_t kDirtyVictimAddr = 0x40000400u;
constexpr uint32_t kDirtyCleanAddr = 0x40000410u;
constexpr uint32_t kDirtyReqAddr = 0x40000420u;
constexpr uint8_t kDirtyReqSize = 7;
constexpr uint8_t kDirtyReqId = 0;
constexpr uint64_t kDirtyVictimLine = 0x0102030405060708ull;
constexpr uint64_t kDirtyCleanLine = 0x1112131415161718ull;
constexpr uint64_t kDirtyReqLine = 0x2122232425262728ull;
constexpr uint64_t kDirtyReqStrb = 0xffull;
constexpr uint32_t kDirtyPartialVictimAddr = 0x40000600u;
constexpr uint32_t kDirtyPartialCleanAddr = 0x40000610u;
constexpr uint32_t kDirtyPartialReqAddr = 0x40000622u;
constexpr uint8_t kDirtyPartialReqSize = 1;
constexpr uint8_t kDirtyPartialReqId = 0;
constexpr uint64_t kDirtyPartialVictimLine = 0x5152535455565758ull;
constexpr uint64_t kDirtyPartialCleanLine = 0x6162636465666768ull;
constexpr uint64_t kDirtyPartialRefillLine = 0x7172737475767778ull;
constexpr uint64_t kDirtyPartialReqData = 0x000000000000d4c3ull;
constexpr uint64_t kDirtyPartialReqStrb = 0x03ull;
constexpr uint32_t kInvAddr = 0x40000508u;
constexpr uint64_t kInvVictimLine = 0x3132333435363738ull;
constexpr uint64_t kInvOtherLine = 0x4142434445464748ull;

void require(bool condition, const char *message) {
  if (!condition) {
    throw std::runtime_error(message);
  }
}

axi_interconnect::AXI_LLCConfig make_config() {
  axi_interconnect::AXI_LLCConfig config{};
  config.enable = true;
  config.size_bytes = kSetCount * kWayCount * kLineBytes;
  config.line_bytes = kLineBytes;
  config.ways = kWayCount;
  config.mshr_num = 2;
  return config;
}

void clear_inputs(axi_interconnect::AXI_LLC &llc) {
  llc.io.ext_in = {};
  llc.io.lookup_in = {};
}

void seq(axi_interconnect::AXI_LLC &llc) {
  llc.seq();
  ++sim_time;
}

void cycle(axi_interconnect::AXI_LLC &llc) {
  llc.comb();
  seq(llc);
}

void write_u64_le(axi_interconnect::AXI_LLC_Bytes_t &bytes, size_t offset,
                  uint64_t value) {
  for (uint32_t i = 0; i < 8; ++i) {
    bytes.data()[offset + i] = static_cast<uint8_t>((value >> (i * 8)) & 0xffu);
  }
}

uint64_t read_u64_le(const axi_interconnect::AXI_LLC_Bytes_t &bytes,
                     size_t offset) {
  uint64_t value = 0;
  for (uint32_t i = 0; i < 8; ++i) {
    value |= static_cast<uint64_t>(bytes.data()[offset + i]) << (i * 8);
  }
  return value;
}

uint32_t read_u32_le(const axi_interconnect::AXI_LLC_Bytes_t &bytes,
                     size_t offset) {
  uint32_t value = 0;
  for (uint32_t i = 0; i < 4; ++i) {
    value |= static_cast<uint32_t>(bytes.data()[offset + i]) << (i * 8);
  }
  return value;
}

axi_interconnect::AXI_LLC_Bytes_t make_data_row(uint64_t way0,
                                                uint64_t way1) {
  axi_interconnect::AXI_LLC_Bytes_t row{};
  row.resize(kWayCount * kLineBytes);
  write_u64_le(row, 0, way0);
  write_u64_le(row, kLineBytes, way1);
  return row;
}

axi_interconnect::AXI_LLC_Bytes_t make_meta_row(uint32_t way0_tag,
                                                uint8_t way0_flags,
                                                uint32_t way1_tag,
                                                uint8_t way1_flags) {
  axi_interconnect::AXI_LLC_Bytes_t row{};
  row.resize(kWayCount * axi_interconnect::AXI_LLC_META_ENTRY_BYTES);
  std::array<axi_interconnect::AXI_LLCMetaEntry_t, kWayCount> entries{};
  entries[0].tag = way0_tag;
  entries[0].flags = way0_flags;
  entries[1].tag = way1_tag;
  entries[1].flags = way1_flags;
  for (uint32_t way = 0; way < kWayCount; ++way) {
    axi_interconnect::AXI_LLC_Bytes_t encoded{};
    axi_interconnect::AXI_LLC::encode_meta(entries[way], encoded);
    for (uint32_t byte = 0; byte < axi_interconnect::AXI_LLC_META_ENTRY_BYTES;
         ++byte) {
      row.data()[way * axi_interconnect::AXI_LLC_META_ENTRY_BYTES + byte] =
          encoded.data()[byte];
    }
  }
  return row;
}

axi_interconnect::AXI_LLC_Bytes_t make_valid_row(uint32_t valid_bits) {
  axi_interconnect::AXI_LLC_Bytes_t row{};
  row.resize(1);
  row.data()[0] = static_cast<uint8_t>(valid_bits & 0xffu);
  return row;
}

axi_interconnect::AXI_LLC_Bytes_t make_repl(uint32_t way) {
  axi_interconnect::AXI_LLC_Bytes_t row{};
  row.resize(axi_interconnect::AXI_LLC_REPL_BYTES);
  for (uint32_t i = 0; i < axi_interconnect::AXI_LLC_REPL_BYTES; ++i) {
    row.data()[i] = static_cast<uint8_t>((way >> (i * 8)) & 0xffu);
  }
  return row;
}

std::string hex_width(uint32_t width, u128 value) {
  const uint32_t nibbles = (width + 3u) / 4u;
  std::string digits(nibbles, '0');
  for (uint32_t i = 0; i < nibbles; ++i) {
    const uint32_t shift = (nibbles - 1u - i) * 4u;
    const uint32_t nibble = static_cast<uint32_t>((value >> shift) & 0xfu);
    digits[i] = static_cast<char>(nibble < 10 ? ('0' + nibble)
                                               : ('a' + (nibble - 10)));
  }
  std::ostringstream os;
  os << width << "'h" << digits;
  return os.str();
}

std::string dec_width(uint32_t width, uint64_t value) {
  std::ostringstream os;
  os << width << "'d" << std::dec << value;
  return os.str();
}

uint64_t rtl_meta(uint32_t tag, bool dirty) {
  const uint64_t tag_mask = (uint64_t{1} << kTagBits) - 1u;
  uint64_t value = tag & tag_mask;
  if (dirty) {
    value |= uint64_t{1} << kTagBits;
  }
  return value;
}

u128 rtl_data_row(uint32_t way, uint64_t line) {
  return way == 0 ? static_cast<u128>(line)
                  : (static_cast<u128>(line) << kLineBits);
}

uint64_t rtl_meta_row(uint32_t way, uint64_t meta) {
  return way == 0 ? meta : (meta << kMetaBits);
}

uint64_t line_from_payload(const axi_interconnect::AXI_LLC_TableReq_t &req) {
  require(req.payload.size() >= kLineBytes, "table data payload too small");
  return read_u64_le(req.payload, 0);
}

uint32_t valid_bits_from_payload(const axi_interconnect::AXI_LLC_TableReq_t &req) {
  require(req.payload.size() >= 1, "valid payload too small");
  return req.payload.data()[0] & ((1u << kWayCount) - 1u);
}

axi_interconnect::WideReadData_t wide_read_line(uint64_t line) {
  axi_interconnect::WideReadData_t data{};
  data.clear();
  data[0] = static_cast<uint32_t>(line & 0xffffffffu);
  data[1] = static_cast<uint32_t>((line >> 32) & 0xffffffffu);
  return data;
}

uint64_t wide_read_to_u64(const axi_interconnect::WideReadData_t &data) {
  return static_cast<uint64_t>(data.words[0]) |
         (static_cast<uint64_t>(data.words[1]) << 32);
}

axi_interconnect::WideWriteData_t wide_write_line(uint64_t line) {
  axi_interconnect::WideWriteData_t data{};
  data.clear();
  data[0] = static_cast<uint32_t>(line & 0xffffffffu);
  data[1] = static_cast<uint32_t>((line >> 32) & 0xffffffffu);
  return data;
}

uint64_t wide_write_to_u64(const axi_interconnect::WideWriteData_t &data) {
  return static_cast<uint64_t>(data.words[0]) |
         (static_cast<uint64_t>(data.words[1]) << 32);
}

struct CacheTrace {
  uint32_t req_addr = 0;
  uint8_t req_size = 0;
  uint8_t req_id = 0;
  uint64_t req_wdata = 0;
  uint64_t req_wstrb = 0;
  uint32_t req_set = 0;
  uint32_t req_tag = 0;
  u128 data_rd_row = 0;
  uint64_t meta_rd_row = 0;
  uint32_t valid_rd_bits = 0;
  uint32_t repl_rd_way = 0;
  uint32_t data_wr_set = 0;
  uint32_t data_wr_way_mask = 0;
  u128 data_wr_row = 0;
  uint32_t meta_wr_set = 0;
  uint32_t meta_wr_way_mask = 0;
  uint64_t meta_wr_row = 0;
  uint32_t valid_wr_set = 0;
  uint32_t valid_wr_mask = 0;
  uint32_t valid_wr_bits = 0;
  uint32_t repl_wr_set = 0;
  uint32_t repl_wr_way = 0;
  uint8_t resp_id = 0;
  uint8_t resp_code = 0;
};

struct MissTrace {
  uint32_t req_addr = 0;
  uint8_t req_size = 0;
  uint8_t req_id = 0;
  uint32_t req_set = 0;
  uint32_t req_tag = 0;
  u128 data_rd_row = 0;
  uint64_t meta_rd_row = 0;
  uint32_t valid_rd_bits = 0;
  uint32_t repl_rd_way = 0;
  uint32_t mem_req_addr = 0;
  uint8_t mem_req_size = 0;
  uint8_t mem_req_id = 0;
  uint64_t mem_resp_line = 0;
  uint32_t data_wr_set = 0;
  uint32_t data_wr_way_mask = 0;
  u128 data_wr_row = 0;
  uint32_t meta_wr_set = 0;
  uint32_t meta_wr_way_mask = 0;
  uint64_t meta_wr_row = 0;
  uint32_t valid_wr_set = 0;
  uint32_t valid_wr_mask = 0;
  uint32_t valid_wr_bits = 0;
  uint32_t repl_wr_set = 0;
  uint32_t repl_wr_way = 0;
  uint8_t resp_id = 0;
  uint8_t resp_code = 0;
  uint64_t resp_rdata = 0;
};

struct WriteMissTrace {
  uint32_t req_addr = 0;
  uint8_t req_size = 0;
  uint8_t req_id = 0;
  uint64_t req_wdata = 0;
  uint64_t req_wstrb = 0;
  uint32_t req_set = 0;
  uint32_t req_tag = 0;
  u128 data_rd_row = 0;
  uint64_t meta_rd_row = 0;
  uint32_t valid_rd_bits = 0;
  uint32_t repl_rd_way = 0;
  uint32_t mem_req_addr = 0;
  uint8_t mem_req_size = 0;
  uint8_t mem_req_id = 0;
  uint64_t mem_resp_line = 0;
  uint32_t data_wr_set = 0;
  uint32_t data_wr_way_mask = 0;
  u128 data_wr_row = 0;
  uint32_t meta_wr_set = 0;
  uint32_t meta_wr_way_mask = 0;
  uint64_t meta_wr_row = 0;
  uint32_t valid_wr_set = 0;
  uint32_t valid_wr_mask = 0;
  uint32_t valid_wr_bits = 0;
  uint32_t repl_wr_set = 0;
  uint32_t repl_wr_way = 0;
  uint8_t resp_id = 0;
  uint8_t resp_code = 0;
};

struct DirtyTrace {
  uint32_t req_addr = 0;
  uint8_t req_size = 0;
  uint8_t req_id = 0;
  uint64_t req_wdata = 0;
  uint64_t req_wstrb = 0;
  uint32_t req_set = 0;
  uint32_t req_tag = 0;
  u128 data_rd_row = 0;
  uint64_t meta_rd_row = 0;
  uint32_t valid_rd_bits = 0;
  uint32_t repl_rd_way = 0;
  uint32_t wb_req_addr = 0;
  uint8_t wb_req_size = 0;
  uint8_t wb_req_id = 0;
  uint64_t wb_req_data = 0;
  uint64_t wb_req_strb = 0;
  uint32_t data_wr_set = 0;
  uint32_t data_wr_way_mask = 0;
  u128 data_wr_row = 0;
  uint32_t meta_wr_set = 0;
  uint32_t meta_wr_way_mask = 0;
  uint64_t meta_wr_row = 0;
  uint32_t valid_wr_set = 0;
  uint32_t valid_wr_mask = 0;
  uint32_t valid_wr_bits = 0;
  uint32_t repl_wr_set = 0;
  uint32_t repl_wr_way = 0;
  uint8_t resp_id = 0;
  uint8_t resp_code = 0;
};

struct DirtyPartialTrace {
  uint32_t req_addr = 0;
  uint8_t req_size = 0;
  uint8_t req_id = 0;
  uint64_t req_wdata = 0;
  uint64_t req_wstrb = 0;
  uint32_t req_set = 0;
  uint32_t req_tag = 0;
  u128 data_rd_row = 0;
  uint64_t meta_rd_row = 0;
  uint32_t valid_rd_bits = 0;
  uint32_t repl_rd_way = 0;
  uint32_t wb_req_addr = 0;
  uint8_t wb_req_size = 0;
  uint8_t wb_req_id = 0;
  uint64_t wb_req_data = 0;
  uint64_t wb_req_strb = 0;
  uint32_t refill_req_addr = 0;
  uint8_t refill_req_size = 0;
  uint8_t refill_req_id = 0;
  uint64_t refill_resp_line = 0;
  uint32_t data_wr_set = 0;
  uint32_t data_wr_way_mask = 0;
  u128 data_wr_row = 0;
  uint32_t meta_wr_set = 0;
  uint32_t meta_wr_way_mask = 0;
  uint64_t meta_wr_row = 0;
  uint32_t valid_wr_set = 0;
  uint32_t valid_wr_mask = 0;
  uint32_t valid_wr_bits = 0;
  uint32_t repl_wr_set = 0;
  uint32_t repl_wr_way = 0;
  uint8_t resp_id = 0;
  uint8_t resp_code = 0;
};

struct InvalidateTrace {
  uint32_t addr = 0;
  uint32_t set = 0;
  u128 data_rd_row = 0;
  uint64_t meta_rd_row = 0;
  uint32_t valid_rd_bits = 0;
  uint32_t repl_rd_way = 0;
  uint32_t valid_wr_set = 0;
  uint32_t valid_wr_mask = 0;
  uint32_t valid_wr_bits = 0;
};

CacheTrace generate_partial_write_hit() {
  using namespace axi_interconnect;

  CacheTrace trace{};
  AXI_LLC llc{};
  const auto config = make_config();
  llc.set_config(config);
  llc.reset();
  sim_time = 0;

  const uint32_t tag = AXI_LLC::tag_of(config, kReqAddr);
  const uint32_t set = AXI_LLC::set_index(config, kReqAddr);
  const uint32_t other_tag = tag + 1u;
  const auto data_row = make_data_row(kBaseLine, kOtherLine);
  const auto meta_row =
      make_meta_row(tag, AXI_LLC_META_VALID, other_tag,
                    AXI_LLC_META_VALID | AXI_LLC_META_DIRTY);
  const auto valid_row = make_valid_row(0x3u);
  const auto repl_row = make_repl(0);

  clear_inputs(llc);
  auto &req = llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W];
  req.valid = true;
  req.addr = kReqAddr;
  req.total_size = kReqSize;
  req.id = kReqId;
  req.wdata[0] = static_cast<uint32_t>(kReqData & 0xffffffffu);
  req.wstrb.set(0, true);
  req.wstrb.set(1, true);
  llc.comb();
  require(llc.io.ext_out.upstream.write_req[MASTER_DCACHE_W].ready,
          "C++ LLC did not accept partial write hit request");
  require(!llc.io.ext_out.mem.write_req_valid && !llc.io.ext_out.mem.read_req_valid,
          "partial write hit issued lower memory request before lookup");
  seq(llc);

  clear_inputs(llc);
  llc.comb();
  require(llc.io.table_out.data.enable && !llc.io.table_out.data.write,
          "C++ LLC did not issue data lookup");
  require(llc.io.table_out.meta.enable && !llc.io.table_out.meta.write,
          "C++ LLC did not issue meta lookup");
  require(llc.io.table_out.valid.enable && !llc.io.table_out.valid.write,
          "C++ LLC did not issue valid lookup");
  require(llc.io.table_out.repl.enable && !llc.io.table_out.repl.write,
          "C++ LLC did not issue repl lookup");
  require(llc.io.table_out.data.index == set &&
              llc.io.table_out.meta.index == set &&
              llc.io.table_out.valid.index == set &&
              llc.io.table_out.repl.index == set,
          "C++ LLC lookup set mismatch");
  seq(llc);

  clear_inputs(llc);
  llc.io.lookup_in.data_valid = true;
  llc.io.lookup_in.meta_valid = true;
  llc.io.lookup_in.valid_valid = true;
  llc.io.lookup_in.repl_valid = true;
  llc.io.lookup_in.data = data_row;
  llc.io.lookup_in.meta = meta_row;
  llc.io.lookup_in.valid = valid_row;
  llc.io.lookup_in.repl = repl_row;
  llc.comb();

  require(llc.io.table_out.data.enable && llc.io.table_out.data.write,
          "C++ LLC did not write data on partial write hit");
  require(llc.io.table_out.meta.enable && llc.io.table_out.meta.write,
          "C++ LLC did not write meta on partial write hit");
  require(llc.io.table_out.valid.enable && llc.io.table_out.valid.write,
          "C++ LLC did not write valid on partial write hit");
  require(llc.io.table_out.repl.enable && llc.io.table_out.repl.write,
          "C++ LLC did not write repl on partial write hit");
  require(!llc.io.ext_out.mem.write_req_valid && !llc.io.ext_out.mem.read_req_valid,
          "partial write hit unexpectedly issued lower memory request");

  const uint32_t hit_way = llc.io.table_out.data.way;
  const auto out_meta = AXI_LLC::decode_meta(llc.io.table_out.meta.payload, 0);
  require(hit_way == llc.io.table_out.meta.way &&
              hit_way == llc.io.table_out.valid.way,
          "C++ LLC table write way mismatch");
  require(out_meta.tag == tag, "C++ LLC output meta tag mismatch");
  require((out_meta.flags & AXI_LLC_META_VALID) != 0,
          "C++ LLC output meta missing valid flag");
  require((out_meta.flags & AXI_LLC_META_DIRTY) != 0,
          "C++ LLC output meta missing dirty flag");

  trace.req_addr = kReqAddr;
  trace.req_size = kReqSize;
  trace.req_id = kReqId;
  trace.req_wdata = kReqData;
  trace.req_wstrb = kReqStrb;
  trace.req_set = set;
  trace.req_tag = tag;
  trace.data_rd_row =
      static_cast<u128>(kBaseLine) | (static_cast<u128>(kOtherLine) << kLineBits);
  trace.meta_rd_row =
      rtl_meta(tag, false) | (rtl_meta(other_tag, true) << kMetaBits);
  trace.valid_rd_bits = 0x3u;
  trace.repl_rd_way = read_u32_le(repl_row, 0);
  trace.data_wr_set = llc.io.table_out.data.index;
  trace.data_wr_way_mask = 1u << hit_way;
  trace.data_wr_row = rtl_data_row(hit_way, line_from_payload(llc.io.table_out.data));
  trace.meta_wr_set = llc.io.table_out.meta.index;
  trace.meta_wr_way_mask = 1u << hit_way;
  trace.meta_wr_row =
      rtl_meta_row(hit_way, rtl_meta(out_meta.tag,
                                     (out_meta.flags & AXI_LLC_META_DIRTY) != 0));
  trace.valid_wr_set = llc.io.table_out.valid.index;
  trace.valid_wr_mask = 1u << hit_way;
  trace.valid_wr_bits = valid_bits_from_payload(llc.io.table_out.valid);
  trace.repl_wr_set = llc.io.table_out.repl.index;
  trace.repl_wr_way = read_u32_le(llc.io.table_out.repl.payload, 0);

  seq(llc);
  clear_inputs(llc);
  cycle(llc);
  clear_inputs(llc);
  llc.comb();
  const auto &resp = llc.io.ext_out.upstream.write_resp[MASTER_DCACHE_W];
  require(resp.valid, "C++ LLC partial write hit did not produce response");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_code = static_cast<uint8_t>(resp.resp);
  require(trace.resp_id == kReqId, "C++ LLC write response id mismatch");
  require(trace.resp_code == 0, "C++ LLC write response code mismatch");

  return trace;
}

InvalidateTrace generate_invalidate_line() {
  using namespace axi_interconnect;

  InvalidateTrace trace{};
  AXI_LLC llc{};
  const auto config = make_config();
  llc.set_config(config);
  llc.reset();
  sim_time = 0;

  const uint32_t victim_tag = AXI_LLC::tag_of(config, kInvAddr);
  const uint32_t other_tag = victim_tag + 1u;
  const uint32_t set = AXI_LLC::set_index(config, kInvAddr);
  const auto data_row = make_data_row(kInvOtherLine, kInvVictimLine);
  const auto meta_row =
      make_meta_row(other_tag, AXI_LLC_META_VALID, victim_tag,
                    AXI_LLC_META_VALID | AXI_LLC_META_DIRTY);
  const auto valid_row = make_valid_row(0x3u);
  const auto repl_row = make_repl(0);

  clear_inputs(llc);
  llc.io.ext_in.mem.invalidate_line_valid = true;
  llc.io.ext_in.mem.invalidate_line_addr = kInvAddr;
  llc.comb();
  require(llc.io.ext_out.mem.invalidate_line_accepted,
          "C++ LLC invalidate_line was not accepted");
  seq(llc);

  clear_inputs(llc);
  llc.comb();
  require(llc.io.table_out.data.enable && !llc.io.table_out.data.write,
          "C++ LLC invalidate_line did not issue data lookup");
  require(llc.io.table_out.meta.enable && !llc.io.table_out.meta.write,
          "C++ LLC invalidate_line did not issue meta lookup");
  require(llc.io.table_out.valid.enable && !llc.io.table_out.valid.write,
          "C++ LLC invalidate_line did not issue valid lookup");
  require(llc.io.table_out.repl.enable && !llc.io.table_out.repl.write,
          "C++ LLC invalidate_line did not issue repl lookup");
  require(llc.io.table_out.data.index == set,
          "C++ LLC invalidate_line lookup set mismatch");
  seq(llc);

  clear_inputs(llc);
  llc.io.lookup_in.data_valid = true;
  llc.io.lookup_in.meta_valid = true;
  llc.io.lookup_in.valid_valid = true;
  llc.io.lookup_in.repl_valid = true;
  llc.io.lookup_in.data = data_row;
  llc.io.lookup_in.meta = meta_row;
  llc.io.lookup_in.valid = valid_row;
  llc.io.lookup_in.repl = repl_row;
  llc.comb();

  require(!llc.io.table_out.data.enable && !llc.io.table_out.meta.enable &&
              !llc.io.table_out.repl.enable,
          "C++ LLC invalidate_line should not update data/meta/repl");
  require(llc.io.table_out.valid.enable && llc.io.table_out.valid.write,
          "C++ LLC invalidate_line did not clear valid table");
  require(llc.io.table_out.valid.way == 1,
          "C++ LLC invalidate_line cleared wrong way");

  trace.addr = kInvAddr;
  trace.set = set;
  trace.data_rd_row =
      static_cast<u128>(kInvOtherLine) |
      (static_cast<u128>(kInvVictimLine) << kLineBits);
  trace.meta_rd_row =
      rtl_meta(other_tag, false) | (rtl_meta(victim_tag, true) << kMetaBits);
  trace.valid_rd_bits = 0x3u;
  trace.repl_rd_way = read_u32_le(repl_row, 0);
  trace.valid_wr_set = llc.io.table_out.valid.index;
  trace.valid_wr_mask = 1u << llc.io.table_out.valid.way;
  trace.valid_wr_bits = valid_bits_from_payload(llc.io.table_out.valid);

  return trace;
}

DirtyTrace generate_dirty_victim_writeback() {
  using namespace axi_interconnect;

  DirtyTrace trace{};
  AXI_LLC llc{};
  const auto config = make_config();
  llc.set_config(config);
  llc.reset();
  sim_time = 0;

  const uint32_t clean_tag = AXI_LLC::tag_of(config, kDirtyCleanAddr);
  const uint32_t victim_tag = AXI_LLC::tag_of(config, kDirtyVictimAddr);
  const uint32_t req_tag = AXI_LLC::tag_of(config, kDirtyReqAddr);
  const uint32_t set = AXI_LLC::set_index(config, kDirtyReqAddr);
  require(AXI_LLC::set_index(config, kDirtyVictimAddr) == set &&
              AXI_LLC::set_index(config, kDirtyCleanAddr) == set,
          "dirty trace addresses must map to same set");

  const auto data_row = make_data_row(kDirtyCleanLine, kDirtyVictimLine);
  const auto meta_row =
      make_meta_row(clean_tag, AXI_LLC_META_VALID, victim_tag,
                    AXI_LLC_META_VALID | AXI_LLC_META_DIRTY);
  const auto valid_row = make_valid_row(0x3u);
  const auto repl_row = make_repl(1);

  clear_inputs(llc);
  auto &req = llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W];
  req.valid = true;
  req.addr = kDirtyReqAddr;
  req.total_size = kDirtyReqSize;
  req.id = kDirtyReqId;
  req.wdata = wide_write_line(kDirtyReqLine);
  for (uint32_t byte = 0; byte < kLineBytes; ++byte) {
    req.wstrb.set(byte, true);
  }
  llc.comb();
  require(llc.io.ext_out.upstream.write_req[MASTER_DCACHE_W].ready,
          "C++ LLC did not accept dirty victim write request");
  seq(llc);

  clear_inputs(llc);
  llc.comb();
  require(llc.io.table_out.data.enable && !llc.io.table_out.data.write,
          "C++ LLC did not issue dirty victim lookup");
  require(llc.io.table_out.data.index == set,
          "C++ LLC dirty victim lookup set mismatch");
  seq(llc);

  clear_inputs(llc);
  llc.io.lookup_in.data_valid = true;
  llc.io.lookup_in.meta_valid = true;
  llc.io.lookup_in.valid_valid = true;
  llc.io.lookup_in.repl_valid = true;
  llc.io.lookup_in.data = data_row;
  llc.io.lookup_in.meta = meta_row;
  llc.io.lookup_in.valid = valid_row;
  llc.io.lookup_in.repl = repl_row;
  cycle(llc);

  for (uint32_t guard = 0; guard < 8; ++guard) {
    clear_inputs(llc);
    llc.io.ext_in.mem.write_req_ready = true;
    llc.comb();
    if (llc.io.ext_out.mem.write_req_valid) {
      break;
    }
    seq(llc);
  }
  require(llc.io.ext_out.mem.write_req_valid,
          "C++ LLC dirty victim did not issue writeback");
  require(llc.io.ext_out.mem.write_req_addr == kDirtyVictimAddr,
          "C++ LLC dirty victim writeback address mismatch");
  require(llc.io.ext_out.mem.write_req_size == kLineBytes - 1,
          "C++ LLC dirty victim writeback size mismatch");
  trace.wb_req_addr = llc.io.ext_out.mem.write_req_addr;
  trace.wb_req_size = static_cast<uint8_t>(llc.io.ext_out.mem.write_req_size);
  trace.wb_req_id = static_cast<uint8_t>(llc.io.ext_out.mem.write_req_id);
  trace.wb_req_data = wide_write_to_u64(llc.io.ext_out.mem.write_req_data);
  trace.wb_req_strb = kDirtyReqStrb;
  require(trace.wb_req_data == kDirtyVictimLine,
          "C++ LLC dirty victim writeback data mismatch");
  seq(llc);

  clear_inputs(llc);
  llc.io.ext_in.mem.write_resp_valid = true;
  llc.io.ext_in.mem.write_resp_id = trace.wb_req_id;
  llc.io.ext_in.mem.write_resp = 0;
  llc.comb();
  require(llc.io.ext_out.mem.write_resp_ready,
          "C++ LLC dirty victim did not accept writeback response");
  require(llc.io.table_out.data.enable && llc.io.table_out.data.write,
          "C++ LLC dirty victim did not write new data after B");
  require(llc.io.table_out.meta.enable && llc.io.table_out.meta.write,
          "C++ LLC dirty victim did not write new meta after B");
  require(llc.io.table_out.valid.enable && llc.io.table_out.valid.write,
          "C++ LLC dirty victim did not write valid after B");
  require(llc.io.table_out.repl.enable && llc.io.table_out.repl.write,
          "C++ LLC dirty victim did not write repl after B");

  const uint32_t fill_way = llc.io.table_out.data.way;
  const auto out_meta = AXI_LLC::decode_meta(llc.io.table_out.meta.payload, 0);
  require(fill_way == 1, "C++ LLC dirty victim fill way mismatch");
  require(out_meta.tag == req_tag, "C++ LLC dirty victim meta tag mismatch");
  require((out_meta.flags & AXI_LLC_META_VALID) != 0 &&
              (out_meta.flags & AXI_LLC_META_DIRTY) != 0,
          "C++ LLC dirty victim meta flags mismatch");

  trace.req_addr = kDirtyReqAddr;
  trace.req_size = kDirtyReqSize;
  trace.req_id = kDirtyReqId;
  trace.req_wdata = kDirtyReqLine;
  trace.req_wstrb = kDirtyReqStrb;
  trace.req_set = set;
  trace.req_tag = req_tag;
  trace.data_rd_row =
      static_cast<u128>(kDirtyCleanLine) |
      (static_cast<u128>(kDirtyVictimLine) << kLineBits);
  trace.meta_rd_row =
      rtl_meta(clean_tag, false) | (rtl_meta(victim_tag, true) << kMetaBits);
  trace.valid_rd_bits = 0x3u;
  trace.repl_rd_way = read_u32_le(repl_row, 0);
  trace.data_wr_set = llc.io.table_out.data.index;
  trace.data_wr_way_mask = 1u << fill_way;
  trace.data_wr_row = rtl_data_row(fill_way, line_from_payload(llc.io.table_out.data));
  trace.meta_wr_set = llc.io.table_out.meta.index;
  trace.meta_wr_way_mask = 1u << fill_way;
  trace.meta_wr_row =
      rtl_meta_row(fill_way, rtl_meta(out_meta.tag,
                                      (out_meta.flags & AXI_LLC_META_DIRTY) != 0));
  trace.valid_wr_set = llc.io.table_out.valid.index;
  trace.valid_wr_mask = 1u << fill_way;
  trace.valid_wr_bits = valid_bits_from_payload(llc.io.table_out.valid);
  trace.repl_wr_set = llc.io.table_out.repl.index;
  trace.repl_wr_way = read_u32_le(llc.io.table_out.repl.payload, 0);

  seq(llc);
  clear_inputs(llc);
  cycle(llc);
  clear_inputs(llc);
  cycle(llc);
  clear_inputs(llc);
  llc.comb();
  const auto &resp = llc.io.ext_out.upstream.write_resp[MASTER_DCACHE_W];
  require(resp.valid, "C++ LLC dirty victim did not produce write response");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_code = static_cast<uint8_t>(resp.resp);
  require(trace.resp_id == kDirtyReqId,
          "C++ LLC dirty victim response id mismatch");
  require(trace.resp_code == 0,
          "C++ LLC dirty victim response code mismatch");

  return trace;
}

DirtyPartialTrace generate_dirty_partial_write_miss() {
  using namespace axi_interconnect;

  DirtyPartialTrace trace{};
  AXI_LLC llc{};
  const auto config = make_config();
  llc.set_config(config);
  llc.reset();
  sim_time = 0;

  const uint32_t clean_tag = AXI_LLC::tag_of(config, kDirtyPartialCleanAddr);
  const uint32_t victim_tag = AXI_LLC::tag_of(config, kDirtyPartialVictimAddr);
  const uint32_t req_tag = AXI_LLC::tag_of(config, kDirtyPartialReqAddr);
  const uint32_t set = AXI_LLC::set_index(config, kDirtyPartialReqAddr);
  require(AXI_LLC::set_index(config, kDirtyPartialVictimAddr) == set &&
              AXI_LLC::set_index(config, kDirtyPartialCleanAddr) == set,
          "dirty partial trace addresses must map to same set");

  const auto data_row =
      make_data_row(kDirtyPartialCleanLine, kDirtyPartialVictimLine);
  const auto meta_row =
      make_meta_row(clean_tag, AXI_LLC_META_VALID, victim_tag,
                    AXI_LLC_META_VALID | AXI_LLC_META_DIRTY);
  const auto valid_row = make_valid_row(0x3u);
  const auto repl_row = make_repl(1);

  clear_inputs(llc);
  auto &req = llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W];
  req.valid = true;
  req.addr = kDirtyPartialReqAddr;
  req.total_size = kDirtyPartialReqSize;
  req.id = kDirtyPartialReqId;
  req.wdata[0] = static_cast<uint32_t>(kDirtyPartialReqData & 0xffffffffu);
  req.wstrb.set(0, true);
  req.wstrb.set(1, true);
  llc.comb();
  require(llc.io.ext_out.upstream.write_req[MASTER_DCACHE_W].ready,
          "C++ LLC did not accept dirty partial write request");
  seq(llc);

  clear_inputs(llc);
  llc.comb();
  require(llc.io.table_out.data.enable && !llc.io.table_out.data.write,
          "C++ LLC did not issue dirty partial lookup");
  require(llc.io.table_out.data.index == set,
          "C++ LLC dirty partial lookup set mismatch");
  seq(llc);

  clear_inputs(llc);
  llc.io.lookup_in.data_valid = true;
  llc.io.lookup_in.meta_valid = true;
  llc.io.lookup_in.valid_valid = true;
  llc.io.lookup_in.repl_valid = true;
  llc.io.lookup_in.data = data_row;
  llc.io.lookup_in.meta = meta_row;
  llc.io.lookup_in.valid = valid_row;
  llc.io.lookup_in.repl = repl_row;
  cycle(llc);

  for (uint32_t guard = 0; guard < 8; ++guard) {
    clear_inputs(llc);
    llc.io.ext_in.mem.read_req_ready = true;
    llc.comb();
    if (llc.io.ext_out.mem.read_req_valid) {
      break;
    }
    seq(llc);
  }
  require(llc.io.ext_out.mem.read_req_valid,
          "C++ LLC dirty partial did not issue refill");
  require(llc.io.ext_out.mem.read_req_addr ==
              AXI_LLC::line_addr(config, kDirtyPartialReqAddr),
          "C++ LLC dirty partial refill address mismatch");
  require(llc.io.ext_out.mem.read_req_size == kLineBytes - 1,
          "C++ LLC dirty partial refill size mismatch");
  trace.refill_req_addr = llc.io.ext_out.mem.read_req_addr;
  trace.refill_req_size = static_cast<uint8_t>(llc.io.ext_out.mem.read_req_size);
  trace.refill_req_id = static_cast<uint8_t>(llc.io.ext_out.mem.read_req_id);
  seq(llc);

  clear_inputs(llc);
  llc.io.ext_in.mem.read_resp_valid = true;
  llc.io.ext_in.mem.read_resp_id = trace.refill_req_id;
  llc.io.ext_in.mem.read_resp_data = wide_read_line(kDirtyPartialRefillLine);
  llc.comb();
  require(llc.io.ext_out.mem.read_resp_ready,
          "C++ LLC dirty partial did not accept refill response");
  seq(llc);

  clear_inputs(llc);
  llc.comb();
  require(llc.io.table_out.data.enable && llc.io.table_out.data.write,
          "C++ LLC dirty partial did not write refill data");
  require(llc.io.table_out.meta.enable && llc.io.table_out.meta.write,
          "C++ LLC dirty partial did not write refill meta");
  require(llc.io.table_out.valid.enable && llc.io.table_out.valid.write,
          "C++ LLC dirty partial did not write refill valid");
  require(llc.io.table_out.repl.enable && llc.io.table_out.repl.write,
          "C++ LLC dirty partial did not write refill repl");

  const uint32_t fill_way = llc.io.table_out.data.way;
  const auto out_meta = AXI_LLC::decode_meta(llc.io.table_out.meta.payload, 0);
  require(fill_way == 1, "C++ LLC dirty partial fill way mismatch");
  require(out_meta.tag == req_tag,
          "C++ LLC dirty partial refill meta tag mismatch");
  require((out_meta.flags & AXI_LLC_META_VALID) != 0 &&
              (out_meta.flags & AXI_LLC_META_DIRTY) != 0,
          "C++ LLC dirty partial meta flags mismatch");

  trace.req_addr = kDirtyPartialReqAddr;
  trace.req_size = kDirtyPartialReqSize;
  trace.req_id = kDirtyPartialReqId;
  trace.req_wdata = kDirtyPartialReqData;
  trace.req_wstrb = kDirtyPartialReqStrb;
  trace.req_set = set;
  trace.req_tag = req_tag;
  trace.data_rd_row =
      static_cast<u128>(kDirtyPartialCleanLine) |
      (static_cast<u128>(kDirtyPartialVictimLine) << kLineBits);
  trace.meta_rd_row =
      rtl_meta(clean_tag, false) | (rtl_meta(victim_tag, true) << kMetaBits);
  trace.valid_rd_bits = 0x3u;
  trace.repl_rd_way = read_u32_le(repl_row, 0);
  trace.refill_resp_line = kDirtyPartialRefillLine;
  trace.data_wr_set = llc.io.table_out.data.index;
  trace.data_wr_way_mask = 1u << fill_way;
  trace.data_wr_row = rtl_data_row(fill_way, line_from_payload(llc.io.table_out.data));
  trace.meta_wr_set = llc.io.table_out.meta.index;
  trace.meta_wr_way_mask = 1u << fill_way;
  trace.meta_wr_row =
      rtl_meta_row(fill_way, rtl_meta(out_meta.tag,
                                      (out_meta.flags & AXI_LLC_META_DIRTY) != 0));
  trace.valid_wr_set = llc.io.table_out.valid.index;
  trace.valid_wr_mask = 1u << fill_way;
  trace.valid_wr_bits = valid_bits_from_payload(llc.io.table_out.valid);
  trace.repl_wr_set = llc.io.table_out.repl.index;
  trace.repl_wr_way = read_u32_le(llc.io.table_out.repl.payload, 0);

  seq(llc);

  for (uint32_t guard = 0; guard < 8; ++guard) {
    clear_inputs(llc);
    llc.io.ext_in.mem.write_req_ready = true;
    llc.comb();
    if (llc.io.ext_out.mem.write_req_valid) {
      break;
    }
    seq(llc);
  }
  require(llc.io.ext_out.mem.write_req_valid,
          "C++ LLC dirty partial did not issue victim writeback");
  require(llc.io.ext_out.mem.write_req_addr == kDirtyPartialVictimAddr,
          "C++ LLC dirty partial writeback address mismatch");
  require(llc.io.ext_out.mem.write_req_size == kLineBytes - 1,
          "C++ LLC dirty partial writeback size mismatch");
  trace.wb_req_addr = llc.io.ext_out.mem.write_req_addr;
  trace.wb_req_size = static_cast<uint8_t>(llc.io.ext_out.mem.write_req_size);
  trace.wb_req_id = static_cast<uint8_t>(llc.io.ext_out.mem.write_req_id);
  trace.wb_req_data = wide_write_to_u64(llc.io.ext_out.mem.write_req_data);
  trace.wb_req_strb = kDirtyReqStrb;
  require(trace.wb_req_data == kDirtyPartialVictimLine,
          "C++ LLC dirty partial writeback data mismatch");
  seq(llc);

  clear_inputs(llc);
  llc.comb();
  const auto &resp = llc.io.ext_out.upstream.write_resp[MASTER_DCACHE_W];
  require(resp.valid, "C++ LLC dirty partial did not produce write response");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_code = static_cast<uint8_t>(resp.resp);
  require(trace.resp_id == kDirtyPartialReqId,
          "C++ LLC dirty partial response id mismatch");
  require(trace.resp_code == 0,
          "C++ LLC dirty partial response code mismatch");

  return trace;
}

WriteMissTrace generate_partial_write_miss_refill() {
  using namespace axi_interconnect;

  WriteMissTrace trace{};
  AXI_LLC llc{};
  const auto config = make_config();
  llc.set_config(config);
  llc.reset();
  sim_time = 0;

  const uint32_t tag = AXI_LLC::tag_of(config, kWriteMissAddr);
  const uint32_t set = AXI_LLC::set_index(config, kWriteMissAddr);
  const auto empty_data_row = make_data_row(0, 0);
  AXI_LLC_Bytes_t empty_meta_row{};
  empty_meta_row.resize(kWayCount * AXI_LLC_META_ENTRY_BYTES);
  const auto empty_valid_row = make_valid_row(0);
  const auto repl_row = make_repl(1);

  clear_inputs(llc);
  auto &req = llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W];
  req.valid = true;
  req.addr = kWriteMissAddr;
  req.total_size = kWriteMissSize;
  req.id = kWriteMissId;
  req.wdata[0] = static_cast<uint32_t>(kWriteMissData & 0xffffffffu);
  req.wstrb.set(0, true);
  req.wstrb.set(1, true);
  llc.comb();
  require(llc.io.ext_out.upstream.write_req[MASTER_DCACHE_W].ready,
          "C++ LLC did not accept partial write miss request");
  seq(llc);

  clear_inputs(llc);
  llc.comb();
  require(llc.io.table_out.data.enable && !llc.io.table_out.data.write,
          "C++ LLC did not issue partial write miss data lookup");
  require(llc.io.table_out.data.index == set,
          "C++ LLC partial write miss lookup set mismatch");
  seq(llc);

  clear_inputs(llc);
  llc.io.lookup_in.data_valid = true;
  llc.io.lookup_in.meta_valid = true;
  llc.io.lookup_in.valid_valid = true;
  llc.io.lookup_in.repl_valid = true;
  llc.io.lookup_in.data = empty_data_row;
  llc.io.lookup_in.meta = empty_meta_row;
  llc.io.lookup_in.valid = empty_valid_row;
  llc.io.lookup_in.repl = repl_row;
  cycle(llc);

  clear_inputs(llc);
  llc.io.ext_in.mem.read_req_ready = true;
  llc.comb();
  require(llc.io.ext_out.mem.read_req_valid,
          "C++ LLC partial write miss did not issue refill request");
  require(llc.io.ext_out.mem.read_req_addr ==
              AXI_LLC::line_addr(config, kWriteMissAddr),
          "C++ LLC partial write miss refill address mismatch");
  require(llc.io.ext_out.mem.read_req_size == kLineBytes - 1,
          "C++ LLC partial write miss refill size mismatch");
  trace.mem_req_addr = llc.io.ext_out.mem.read_req_addr;
  trace.mem_req_size = static_cast<uint8_t>(llc.io.ext_out.mem.read_req_size);
  trace.mem_req_id = static_cast<uint8_t>(llc.io.ext_out.mem.read_req_id);
  seq(llc);

  clear_inputs(llc);
  llc.io.ext_in.mem.read_resp_valid = true;
  llc.io.ext_in.mem.read_resp_id = trace.mem_req_id;
  llc.io.ext_in.mem.read_resp_data = wide_read_line(kWriteMissRefillLine);
  llc.comb();
  require(llc.io.ext_out.mem.read_resp_ready,
          "C++ LLC partial write miss did not accept refill response");
  seq(llc);

  clear_inputs(llc);
  llc.comb();
  require(llc.io.table_out.data.enable && llc.io.table_out.data.write,
          "C++ LLC partial write miss did not write refill data");
  require(llc.io.table_out.meta.enable && llc.io.table_out.meta.write,
          "C++ LLC partial write miss did not write refill meta");
  require(llc.io.table_out.valid.enable && llc.io.table_out.valid.write,
          "C++ LLC partial write miss did not write refill valid");
  require(llc.io.table_out.repl.enable && llc.io.table_out.repl.write,
          "C++ LLC partial write miss did not write refill repl");

  const uint32_t fill_way = llc.io.table_out.data.way;
  const auto out_meta = AXI_LLC::decode_meta(llc.io.table_out.meta.payload, 0);
  require(out_meta.tag == tag,
          "C++ LLC partial write miss refill meta tag mismatch");
  require((out_meta.flags & AXI_LLC_META_VALID) != 0,
          "C++ LLC partial write miss refill meta missing valid flag");
  require((out_meta.flags & AXI_LLC_META_DIRTY) != 0,
          "C++ LLC partial write miss refill meta missing dirty flag");

  trace.req_addr = kWriteMissAddr;
  trace.req_size = kWriteMissSize;
  trace.req_id = kWriteMissId;
  trace.req_wdata = kWriteMissData;
  trace.req_wstrb = kWriteMissStrb;
  trace.req_set = set;
  trace.req_tag = tag;
  trace.data_rd_row = 0;
  trace.meta_rd_row = 0;
  trace.valid_rd_bits = 0;
  trace.repl_rd_way = read_u32_le(repl_row, 0);
  trace.mem_resp_line = kWriteMissRefillLine;
  trace.data_wr_set = llc.io.table_out.data.index;
  trace.data_wr_way_mask = 1u << fill_way;
  trace.data_wr_row = rtl_data_row(fill_way, line_from_payload(llc.io.table_out.data));
  trace.meta_wr_set = llc.io.table_out.meta.index;
  trace.meta_wr_way_mask = 1u << fill_way;
  trace.meta_wr_row =
      rtl_meta_row(fill_way, rtl_meta(out_meta.tag,
                                      (out_meta.flags & AXI_LLC_META_DIRTY) != 0));
  trace.valid_wr_set = llc.io.table_out.valid.index;
  trace.valid_wr_mask = 1u << fill_way;
  trace.valid_wr_bits = valid_bits_from_payload(llc.io.table_out.valid);
  trace.repl_wr_set = llc.io.table_out.repl.index;
  trace.repl_wr_way = read_u32_le(llc.io.table_out.repl.payload, 0);

  seq(llc);
  clear_inputs(llc);
  cycle(llc);
  clear_inputs(llc);
  llc.comb();
  const auto &resp = llc.io.ext_out.upstream.write_resp[MASTER_DCACHE_W];
  require(resp.valid,
          "C++ LLC partial write miss did not produce write response");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_code = static_cast<uint8_t>(resp.resp);
  require(trace.resp_id == kWriteMissId,
          "C++ LLC partial write miss response id mismatch");
  require(trace.resp_code == 0,
          "C++ LLC partial write miss response code mismatch");

  return trace;
}

MissTrace generate_read_miss_refill() {
  using namespace axi_interconnect;

  MissTrace trace{};
  AXI_LLC llc{};
  const auto config = make_config();
  llc.set_config(config);
  llc.reset();
  sim_time = 0;

  const uint32_t tag = AXI_LLC::tag_of(config, kMissAddr);
  const uint32_t set = AXI_LLC::set_index(config, kMissAddr);
  const auto empty_data_row = make_data_row(0, 0);
  AXI_LLC_Bytes_t empty_meta_row{};
  empty_meta_row.resize(kWayCount * AXI_LLC_META_ENTRY_BYTES);
  const auto empty_valid_row = make_valid_row(0);
  const auto repl_row = make_repl(1);

  clear_inputs(llc);
  auto &req = llc.io.ext_in.upstream.read_req[MASTER_ICACHE];
  req.valid = true;
  req.addr = kMissAddr;
  req.total_size = kMissSize;
  req.id = kMissId;
  llc.comb();
  require(llc.io.ext_out.upstream.read_req[MASTER_ICACHE].ready,
          "C++ LLC did not accept read miss request");
  seq(llc);

  clear_inputs(llc);
  llc.comb();
  require(llc.io.table_out.data.enable && !llc.io.table_out.data.write,
          "C++ LLC did not issue read miss data lookup");
  require(llc.io.table_out.data.index == set,
          "C++ LLC read miss lookup set mismatch");
  seq(llc);

  clear_inputs(llc);
  llc.io.lookup_in.data_valid = true;
  llc.io.lookup_in.meta_valid = true;
  llc.io.lookup_in.valid_valid = true;
  llc.io.lookup_in.repl_valid = true;
  llc.io.lookup_in.data = empty_data_row;
  llc.io.lookup_in.meta = empty_meta_row;
  llc.io.lookup_in.valid = empty_valid_row;
  llc.io.lookup_in.repl = repl_row;
  cycle(llc);

  clear_inputs(llc);
  llc.io.ext_in.mem.read_req_ready = true;
  llc.comb();
  require(llc.io.ext_out.mem.read_req_valid,
          "C++ LLC read miss did not issue refill request");
  require(llc.io.ext_out.mem.read_req_addr == AXI_LLC::line_addr(config, kMissAddr),
          "C++ LLC read miss refill address mismatch");
  require(llc.io.ext_out.mem.read_req_size == kLineBytes - 1,
          "C++ LLC read miss refill size mismatch");
  trace.mem_req_addr = llc.io.ext_out.mem.read_req_addr;
  trace.mem_req_size = static_cast<uint8_t>(llc.io.ext_out.mem.read_req_size);
  trace.mem_req_id = static_cast<uint8_t>(llc.io.ext_out.mem.read_req_id);
  seq(llc);

  clear_inputs(llc);
  llc.io.ext_in.mem.read_resp_valid = true;
  llc.io.ext_in.mem.read_resp_id = trace.mem_req_id;
  llc.io.ext_in.mem.read_resp_data = wide_read_line(kMissRefillLine);
  llc.comb();
  require(llc.io.ext_out.mem.read_resp_ready,
          "C++ LLC read miss did not accept refill response");
  seq(llc);

  clear_inputs(llc);
  llc.comb();
  require(llc.io.table_out.data.enable && llc.io.table_out.data.write,
          "C++ LLC read miss did not write refill data");
  require(llc.io.table_out.meta.enable && llc.io.table_out.meta.write,
          "C++ LLC read miss did not write refill meta");
  require(llc.io.table_out.valid.enable && llc.io.table_out.valid.write,
          "C++ LLC read miss did not write refill valid");
  require(llc.io.table_out.repl.enable && llc.io.table_out.repl.write,
          "C++ LLC read miss did not write refill repl");

  const uint32_t fill_way = llc.io.table_out.data.way;
  const auto out_meta = AXI_LLC::decode_meta(llc.io.table_out.meta.payload, 0);
  require(out_meta.tag == tag, "C++ LLC read miss refill meta tag mismatch");
  require((out_meta.flags & AXI_LLC_META_VALID) != 0,
          "C++ LLC read miss refill meta missing valid flag");
  require((out_meta.flags & AXI_LLC_META_DIRTY) == 0,
          "C++ LLC read miss refill unexpectedly dirty");

  trace.req_addr = kMissAddr;
  trace.req_size = kMissSize;
  trace.req_id = kMissId;
  trace.req_set = set;
  trace.req_tag = tag;
  trace.data_rd_row = 0;
  trace.meta_rd_row = 0;
  trace.valid_rd_bits = 0;
  trace.repl_rd_way = read_u32_le(repl_row, 0);
  trace.mem_resp_line = kMissRefillLine;
  trace.data_wr_set = llc.io.table_out.data.index;
  trace.data_wr_way_mask = 1u << fill_way;
  trace.data_wr_row = rtl_data_row(fill_way, line_from_payload(llc.io.table_out.data));
  trace.meta_wr_set = llc.io.table_out.meta.index;
  trace.meta_wr_way_mask = 1u << fill_way;
  trace.meta_wr_row =
      rtl_meta_row(fill_way, rtl_meta(out_meta.tag,
                                      (out_meta.flags & AXI_LLC_META_DIRTY) != 0));
  trace.valid_wr_set = llc.io.table_out.valid.index;
  trace.valid_wr_mask = 1u << fill_way;
  trace.valid_wr_bits = valid_bits_from_payload(llc.io.table_out.valid);
  trace.repl_wr_set = llc.io.table_out.repl.index;
  trace.repl_wr_way = read_u32_le(llc.io.table_out.repl.payload, 0);

  seq(llc);
  clear_inputs(llc);
  cycle(llc);
  clear_inputs(llc);
  llc.comb();
  const auto &resp = llc.io.ext_out.upstream.read_resp[MASTER_ICACHE];
  require(resp.valid, "C++ LLC read miss did not produce read response");
  trace.resp_id = static_cast<uint8_t>(resp.id);
  trace.resp_code = 0;
  trace.resp_rdata = wide_read_to_u64(resp.data);
  require(trace.resp_id == kMissId, "C++ LLC read miss response id mismatch");
  require(trace.resp_rdata == kMissRefillLine,
          "C++ LLC read miss response data mismatch");

  return trace;
}

void emit_trace(std::ostream &os, const CacheTrace &trace,
                const MissTrace &miss, const WriteMissTrace &write_miss,
                const DirtyTrace &dirty,
                const DirtyPartialTrace &dirty_partial,
                const InvalidateTrace &inv) {
  os << "`ifndef AXI_LLC_CACHE_CPP_TRACE_VECTORS_VH\n";
  os << "`define AXI_LLC_CACHE_CPP_TRACE_VECTORS_VH\n";
  os << "// Generated by axi_llc_cache_trace_vectors.cpp from the production\n";
  os << "// AXI_LLC comb/seq model. Do not hand-edit expected values here.\n\n";

  os << "localparam integer CPP_LLC_CACHE_ADDR_BITS = " << kAddrBits << ";\n";
  os << "localparam integer CPP_LLC_CACHE_ID_BITS = " << kIdBits << ";\n";
  os << "localparam integer CPP_LLC_CACHE_LINE_BYTES = " << kLineBytes << ";\n";
  os << "localparam integer CPP_LLC_CACHE_LINE_BITS = " << kLineBits << ";\n";
  os << "localparam integer CPP_LLC_CACHE_LINE_OFFSET_BITS = "
     << kLineOffsetBits << ";\n";
  os << "localparam integer CPP_LLC_CACHE_SET_COUNT = " << kSetCount << ";\n";
  os << "localparam integer CPP_LLC_CACHE_SET_BITS = " << kSetBits << ";\n";
  os << "localparam integer CPP_LLC_CACHE_WAY_COUNT = " << kWayCount << ";\n";
  os << "localparam integer CPP_LLC_CACHE_WAY_BITS = " << kWayBits << ";\n";
  os << "localparam integer CPP_LLC_CACHE_TAG_BITS = " << kTagBits << ";\n";
  os << "localparam integer CPP_LLC_CACHE_META_BITS = " << kMetaBits << ";\n";
  os << "localparam integer CPP_LLC_CACHE_DATA_ROW_BITS = "
     << kDataRowBits << ";\n";
  os << "localparam integer CPP_LLC_CACHE_META_ROW_BITS = "
     << kMetaRowBits << ";\n\n";

  os << "localparam [31:0] CPP_LLC_PWH_REQ_ADDR = "
     << hex_width(32, trace.req_addr) << ";\n";
  os << "localparam [7:0] CPP_LLC_PWH_REQ_SIZE = "
     << dec_width(8, trace.req_size) << ";\n";
  os << "localparam [3:0] CPP_LLC_PWH_REQ_ID = "
     << dec_width(4, trace.req_id) << ";\n";
  os << "localparam [63:0] CPP_LLC_PWH_REQ_WDATA = "
     << hex_width(64, trace.req_wdata) << ";\n";
  os << "localparam [7:0] CPP_LLC_PWH_REQ_WSTRB = "
     << hex_width(8, trace.req_wstrb) << ";\n";
  os << "localparam [" << (kSetBits - 1) << ":0] CPP_LLC_PWH_REQ_SET = "
     << dec_width(kSetBits, trace.req_set) << ";\n";
  os << "localparam [" << (kTagBits - 1) << ":0] CPP_LLC_PWH_REQ_TAG = "
     << hex_width(kTagBits, trace.req_tag) << ";\n";
  os << "localparam [" << (kDataRowBits - 1)
     << ":0] CPP_LLC_PWH_DATA_RD_ROW = "
     << hex_width(kDataRowBits, trace.data_rd_row) << ";\n";
  os << "localparam [" << (kMetaRowBits - 1)
     << ":0] CPP_LLC_PWH_META_RD_ROW = "
     << hex_width(kMetaRowBits, trace.meta_rd_row) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_PWH_VALID_RD_BITS = "
     << hex_width(kWayCount, trace.valid_rd_bits) << ";\n";
  os << "localparam [" << (kWayBits - 1)
     << ":0] CPP_LLC_PWH_REPL_RD_WAY = "
     << dec_width(kWayBits, trace.repl_rd_way) << ";\n";
  os << "localparam [" << (kSetBits - 1)
     << ":0] CPP_LLC_PWH_DATA_WR_SET = "
     << dec_width(kSetBits, trace.data_wr_set) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_PWH_DATA_WR_WAY_MASK = "
     << hex_width(kWayCount, trace.data_wr_way_mask) << ";\n";
  os << "localparam [" << (kDataRowBits - 1)
     << ":0] CPP_LLC_PWH_DATA_WR_ROW = "
     << hex_width(kDataRowBits, trace.data_wr_row) << ";\n";
  os << "localparam [" << (kSetBits - 1)
     << ":0] CPP_LLC_PWH_META_WR_SET = "
     << dec_width(kSetBits, trace.meta_wr_set) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_PWH_META_WR_WAY_MASK = "
     << hex_width(kWayCount, trace.meta_wr_way_mask) << ";\n";
  os << "localparam [" << (kMetaRowBits - 1)
     << ":0] CPP_LLC_PWH_META_WR_ROW = "
     << hex_width(kMetaRowBits, trace.meta_wr_row) << ";\n";
  os << "localparam [" << (kSetBits - 1)
     << ":0] CPP_LLC_PWH_VALID_WR_SET = "
     << dec_width(kSetBits, trace.valid_wr_set) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_PWH_VALID_WR_MASK = "
     << hex_width(kWayCount, trace.valid_wr_mask) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_PWH_VALID_WR_BITS = "
     << hex_width(kWayCount, trace.valid_wr_bits) << ";\n";
  os << "localparam [" << (kSetBits - 1)
     << ":0] CPP_LLC_PWH_REPL_WR_SET = "
     << dec_width(kSetBits, trace.repl_wr_set) << ";\n";
  os << "localparam [" << (kWayBits - 1)
     << ":0] CPP_LLC_PWH_REPL_WR_WAY = "
     << dec_width(kWayBits, trace.repl_wr_way) << ";\n";
  os << "localparam [3:0] CPP_LLC_PWH_RESP_ID = "
     << dec_width(4, trace.resp_id) << ";\n";
  os << "localparam [1:0] CPP_LLC_PWH_RESP_CODE = "
     << dec_width(2, trace.resp_code) << ";\n\n";

  os << "localparam [31:0] CPP_LLC_RMR_REQ_ADDR = "
     << hex_width(32, miss.req_addr) << ";\n";
  os << "localparam [7:0] CPP_LLC_RMR_REQ_SIZE = "
     << dec_width(8, miss.req_size) << ";\n";
  os << "localparam [3:0] CPP_LLC_RMR_REQ_ID = "
     << dec_width(4, miss.req_id) << ";\n";
  os << "localparam [" << (kSetBits - 1) << ":0] CPP_LLC_RMR_REQ_SET = "
     << dec_width(kSetBits, miss.req_set) << ";\n";
  os << "localparam [" << (kTagBits - 1) << ":0] CPP_LLC_RMR_REQ_TAG = "
     << hex_width(kTagBits, miss.req_tag) << ";\n";
  os << "localparam [" << (kDataRowBits - 1)
     << ":0] CPP_LLC_RMR_DATA_RD_ROW = "
     << hex_width(kDataRowBits, miss.data_rd_row) << ";\n";
  os << "localparam [" << (kMetaRowBits - 1)
     << ":0] CPP_LLC_RMR_META_RD_ROW = "
     << hex_width(kMetaRowBits, miss.meta_rd_row) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_RMR_VALID_RD_BITS = "
     << hex_width(kWayCount, miss.valid_rd_bits) << ";\n";
  os << "localparam [" << (kWayBits - 1)
     << ":0] CPP_LLC_RMR_REPL_RD_WAY = "
     << dec_width(kWayBits, miss.repl_rd_way) << ";\n";
  os << "localparam [31:0] CPP_LLC_RMR_MEM_REQ_ADDR = "
     << hex_width(32, miss.mem_req_addr) << ";\n";
  os << "localparam [7:0] CPP_LLC_RMR_MEM_REQ_SIZE = "
     << dec_width(8, miss.mem_req_size) << ";\n";
  os << "localparam [3:0] CPP_LLC_RMR_MEM_REQ_ID = "
     << dec_width(4, miss.mem_req_id) << ";\n";
  os << "localparam [63:0] CPP_LLC_RMR_MEM_RESP_LINE = "
     << hex_width(64, miss.mem_resp_line) << ";\n";
  os << "localparam [" << (kSetBits - 1)
     << ":0] CPP_LLC_RMR_DATA_WR_SET = "
     << dec_width(kSetBits, miss.data_wr_set) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_RMR_DATA_WR_WAY_MASK = "
     << hex_width(kWayCount, miss.data_wr_way_mask) << ";\n";
  os << "localparam [" << (kDataRowBits - 1)
     << ":0] CPP_LLC_RMR_DATA_WR_ROW = "
     << hex_width(kDataRowBits, miss.data_wr_row) << ";\n";
  os << "localparam [" << (kSetBits - 1)
     << ":0] CPP_LLC_RMR_META_WR_SET = "
     << dec_width(kSetBits, miss.meta_wr_set) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_RMR_META_WR_WAY_MASK = "
     << hex_width(kWayCount, miss.meta_wr_way_mask) << ";\n";
  os << "localparam [" << (kMetaRowBits - 1)
     << ":0] CPP_LLC_RMR_META_WR_ROW = "
     << hex_width(kMetaRowBits, miss.meta_wr_row) << ";\n";
  os << "localparam [" << (kSetBits - 1)
     << ":0] CPP_LLC_RMR_VALID_WR_SET = "
     << dec_width(kSetBits, miss.valid_wr_set) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_RMR_VALID_WR_MASK = "
     << hex_width(kWayCount, miss.valid_wr_mask) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_RMR_VALID_WR_BITS = "
     << hex_width(kWayCount, miss.valid_wr_bits) << ";\n";
  os << "localparam [" << (kSetBits - 1)
     << ":0] CPP_LLC_RMR_REPL_WR_SET = "
     << dec_width(kSetBits, miss.repl_wr_set) << ";\n";
  os << "localparam [" << (kWayBits - 1)
     << ":0] CPP_LLC_RMR_REPL_WR_WAY = "
     << dec_width(kWayBits, miss.repl_wr_way) << ";\n";
  os << "localparam [3:0] CPP_LLC_RMR_RESP_ID = "
     << dec_width(4, miss.resp_id) << ";\n";
  os << "localparam [1:0] CPP_LLC_RMR_RESP_CODE = "
     << dec_width(2, miss.resp_code) << ";\n";
  os << "localparam [63:0] CPP_LLC_RMR_RESP_RDATA = "
     << hex_width(64, miss.resp_rdata) << ";\n\n";

  os << "localparam [31:0] CPP_LLC_PWM_REQ_ADDR = "
     << hex_width(32, write_miss.req_addr) << ";\n";
  os << "localparam [7:0] CPP_LLC_PWM_REQ_SIZE = "
     << dec_width(8, write_miss.req_size) << ";\n";
  os << "localparam [3:0] CPP_LLC_PWM_REQ_ID = "
     << dec_width(4, write_miss.req_id) << ";\n";
  os << "localparam [63:0] CPP_LLC_PWM_REQ_WDATA = "
     << hex_width(64, write_miss.req_wdata) << ";\n";
  os << "localparam [7:0] CPP_LLC_PWM_REQ_WSTRB = "
     << hex_width(8, write_miss.req_wstrb) << ";\n";
  os << "localparam [" << (kSetBits - 1) << ":0] CPP_LLC_PWM_REQ_SET = "
     << dec_width(kSetBits, write_miss.req_set) << ";\n";
  os << "localparam [" << (kTagBits - 1) << ":0] CPP_LLC_PWM_REQ_TAG = "
     << hex_width(kTagBits, write_miss.req_tag) << ";\n";
  os << "localparam [" << (kDataRowBits - 1)
     << ":0] CPP_LLC_PWM_DATA_RD_ROW = "
     << hex_width(kDataRowBits, write_miss.data_rd_row) << ";\n";
  os << "localparam [" << (kMetaRowBits - 1)
     << ":0] CPP_LLC_PWM_META_RD_ROW = "
     << hex_width(kMetaRowBits, write_miss.meta_rd_row) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_PWM_VALID_RD_BITS = "
     << hex_width(kWayCount, write_miss.valid_rd_bits) << ";\n";
  os << "localparam [" << (kWayBits - 1)
     << ":0] CPP_LLC_PWM_REPL_RD_WAY = "
     << dec_width(kWayBits, write_miss.repl_rd_way) << ";\n";
  os << "localparam [31:0] CPP_LLC_PWM_MEM_REQ_ADDR = "
     << hex_width(32, write_miss.mem_req_addr) << ";\n";
  os << "localparam [7:0] CPP_LLC_PWM_MEM_REQ_SIZE = "
     << dec_width(8, write_miss.mem_req_size) << ";\n";
  os << "localparam [3:0] CPP_LLC_PWM_MEM_REQ_ID = "
     << dec_width(4, write_miss.mem_req_id) << ";\n";
  os << "localparam [63:0] CPP_LLC_PWM_MEM_RESP_LINE = "
     << hex_width(64, write_miss.mem_resp_line) << ";\n";
  os << "localparam [" << (kSetBits - 1)
     << ":0] CPP_LLC_PWM_DATA_WR_SET = "
     << dec_width(kSetBits, write_miss.data_wr_set) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_PWM_DATA_WR_WAY_MASK = "
     << hex_width(kWayCount, write_miss.data_wr_way_mask) << ";\n";
  os << "localparam [" << (kDataRowBits - 1)
     << ":0] CPP_LLC_PWM_DATA_WR_ROW = "
     << hex_width(kDataRowBits, write_miss.data_wr_row) << ";\n";
  os << "localparam [" << (kSetBits - 1)
     << ":0] CPP_LLC_PWM_META_WR_SET = "
     << dec_width(kSetBits, write_miss.meta_wr_set) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_PWM_META_WR_WAY_MASK = "
     << hex_width(kWayCount, write_miss.meta_wr_way_mask) << ";\n";
  os << "localparam [" << (kMetaRowBits - 1)
     << ":0] CPP_LLC_PWM_META_WR_ROW = "
     << hex_width(kMetaRowBits, write_miss.meta_wr_row) << ";\n";
  os << "localparam [" << (kSetBits - 1)
     << ":0] CPP_LLC_PWM_VALID_WR_SET = "
     << dec_width(kSetBits, write_miss.valid_wr_set) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_PWM_VALID_WR_MASK = "
     << hex_width(kWayCount, write_miss.valid_wr_mask) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_PWM_VALID_WR_BITS = "
     << hex_width(kWayCount, write_miss.valid_wr_bits) << ";\n";
  os << "localparam [" << (kSetBits - 1)
     << ":0] CPP_LLC_PWM_REPL_WR_SET = "
     << dec_width(kSetBits, write_miss.repl_wr_set) << ";\n";
  os << "localparam [" << (kWayBits - 1)
     << ":0] CPP_LLC_PWM_REPL_WR_WAY = "
     << dec_width(kWayBits, write_miss.repl_wr_way) << ";\n";
  os << "localparam [3:0] CPP_LLC_PWM_RESP_ID = "
     << dec_width(4, write_miss.resp_id) << ";\n";
  os << "localparam [1:0] CPP_LLC_PWM_RESP_CODE = "
     << dec_width(2, write_miss.resp_code) << ";\n\n";

  os << "localparam [31:0] CPP_LLC_DVW_REQ_ADDR = "
     << hex_width(32, dirty.req_addr) << ";\n";
  os << "localparam [7:0] CPP_LLC_DVW_REQ_SIZE = "
     << dec_width(8, dirty.req_size) << ";\n";
  os << "localparam [3:0] CPP_LLC_DVW_REQ_ID = "
     << dec_width(4, dirty.req_id) << ";\n";
  os << "localparam [63:0] CPP_LLC_DVW_REQ_WDATA = "
     << hex_width(64, dirty.req_wdata) << ";\n";
  os << "localparam [7:0] CPP_LLC_DVW_REQ_WSTRB = "
     << hex_width(8, dirty.req_wstrb) << ";\n";
  os << "localparam [" << (kSetBits - 1) << ":0] CPP_LLC_DVW_REQ_SET = "
     << dec_width(kSetBits, dirty.req_set) << ";\n";
  os << "localparam [" << (kDataRowBits - 1)
     << ":0] CPP_LLC_DVW_DATA_RD_ROW = "
     << hex_width(kDataRowBits, dirty.data_rd_row) << ";\n";
  os << "localparam [" << (kMetaRowBits - 1)
     << ":0] CPP_LLC_DVW_META_RD_ROW = "
     << hex_width(kMetaRowBits, dirty.meta_rd_row) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_DVW_VALID_RD_BITS = "
     << hex_width(kWayCount, dirty.valid_rd_bits) << ";\n";
  os << "localparam [" << (kWayBits - 1)
     << ":0] CPP_LLC_DVW_REPL_RD_WAY = "
     << dec_width(kWayBits, dirty.repl_rd_way) << ";\n";
  os << "localparam [31:0] CPP_LLC_DVW_WB_REQ_ADDR = "
     << hex_width(32, dirty.wb_req_addr) << ";\n";
  os << "localparam [7:0] CPP_LLC_DVW_WB_REQ_SIZE = "
     << dec_width(8, dirty.wb_req_size) << ";\n";
  os << "localparam [3:0] CPP_LLC_DVW_WB_REQ_ID = "
     << dec_width(4, dirty.wb_req_id) << ";\n";
  os << "localparam [63:0] CPP_LLC_DVW_WB_REQ_DATA = "
     << hex_width(64, dirty.wb_req_data) << ";\n";
  os << "localparam [7:0] CPP_LLC_DVW_WB_REQ_STRB = "
     << hex_width(8, dirty.wb_req_strb) << ";\n";
  os << "localparam [" << (kSetBits - 1)
     << ":0] CPP_LLC_DVW_DATA_WR_SET = "
     << dec_width(kSetBits, dirty.data_wr_set) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_DVW_DATA_WR_WAY_MASK = "
     << hex_width(kWayCount, dirty.data_wr_way_mask) << ";\n";
  os << "localparam [" << (kDataRowBits - 1)
     << ":0] CPP_LLC_DVW_DATA_WR_ROW = "
     << hex_width(kDataRowBits, dirty.data_wr_row) << ";\n";
  os << "localparam [" << (kSetBits - 1)
     << ":0] CPP_LLC_DVW_META_WR_SET = "
     << dec_width(kSetBits, dirty.meta_wr_set) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_DVW_META_WR_WAY_MASK = "
     << hex_width(kWayCount, dirty.meta_wr_way_mask) << ";\n";
  os << "localparam [" << (kMetaRowBits - 1)
     << ":0] CPP_LLC_DVW_META_WR_ROW = "
     << hex_width(kMetaRowBits, dirty.meta_wr_row) << ";\n";
  os << "localparam [" << (kSetBits - 1)
     << ":0] CPP_LLC_DVW_VALID_WR_SET = "
     << dec_width(kSetBits, dirty.valid_wr_set) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_DVW_VALID_WR_MASK = "
     << hex_width(kWayCount, dirty.valid_wr_mask) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_DVW_VALID_WR_BITS = "
     << hex_width(kWayCount, dirty.valid_wr_bits) << ";\n";
  os << "localparam [" << (kSetBits - 1)
     << ":0] CPP_LLC_DVW_REPL_WR_SET = "
     << dec_width(kSetBits, dirty.repl_wr_set) << ";\n";
  os << "localparam [" << (kWayBits - 1)
     << ":0] CPP_LLC_DVW_REPL_WR_WAY = "
     << dec_width(kWayBits, dirty.repl_wr_way) << ";\n";
  os << "localparam [3:0] CPP_LLC_DVW_RESP_ID = "
     << dec_width(4, dirty.resp_id) << ";\n";
  os << "localparam [1:0] CPP_LLC_DVW_RESP_CODE = "
     << dec_width(2, dirty.resp_code) << ";\n\n";

  os << "localparam [31:0] CPP_LLC_DVPW_REQ_ADDR = "
     << hex_width(32, dirty_partial.req_addr) << ";\n";
  os << "localparam [7:0] CPP_LLC_DVPW_REQ_SIZE = "
     << dec_width(8, dirty_partial.req_size) << ";\n";
  os << "localparam [3:0] CPP_LLC_DVPW_REQ_ID = "
     << dec_width(4, dirty_partial.req_id) << ";\n";
  os << "localparam [63:0] CPP_LLC_DVPW_REQ_WDATA = "
     << hex_width(64, dirty_partial.req_wdata) << ";\n";
  os << "localparam [7:0] CPP_LLC_DVPW_REQ_WSTRB = "
     << hex_width(8, dirty_partial.req_wstrb) << ";\n";
  os << "localparam [" << (kSetBits - 1) << ":0] CPP_LLC_DVPW_REQ_SET = "
     << dec_width(kSetBits, dirty_partial.req_set) << ";\n";
  os << "localparam [" << (kDataRowBits - 1)
     << ":0] CPP_LLC_DVPW_DATA_RD_ROW = "
     << hex_width(kDataRowBits, dirty_partial.data_rd_row) << ";\n";
  os << "localparam [" << (kMetaRowBits - 1)
     << ":0] CPP_LLC_DVPW_META_RD_ROW = "
     << hex_width(kMetaRowBits, dirty_partial.meta_rd_row) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_DVPW_VALID_RD_BITS = "
     << hex_width(kWayCount, dirty_partial.valid_rd_bits) << ";\n";
  os << "localparam [" << (kWayBits - 1)
     << ":0] CPP_LLC_DVPW_REPL_RD_WAY = "
     << dec_width(kWayBits, dirty_partial.repl_rd_way) << ";\n";
  os << "localparam [31:0] CPP_LLC_DVPW_WB_REQ_ADDR = "
     << hex_width(32, dirty_partial.wb_req_addr) << ";\n";
  os << "localparam [7:0] CPP_LLC_DVPW_WB_REQ_SIZE = "
     << dec_width(8, dirty_partial.wb_req_size) << ";\n";
  os << "localparam [3:0] CPP_LLC_DVPW_WB_REQ_ID = "
     << dec_width(4, dirty_partial.wb_req_id) << ";\n";
  os << "localparam [63:0] CPP_LLC_DVPW_WB_REQ_DATA = "
     << hex_width(64, dirty_partial.wb_req_data) << ";\n";
  os << "localparam [7:0] CPP_LLC_DVPW_WB_REQ_STRB = "
     << hex_width(8, dirty_partial.wb_req_strb) << ";\n";
  os << "localparam [31:0] CPP_LLC_DVPW_REFILL_REQ_ADDR = "
     << hex_width(32, dirty_partial.refill_req_addr) << ";\n";
  os << "localparam [7:0] CPP_LLC_DVPW_REFILL_REQ_SIZE = "
     << dec_width(8, dirty_partial.refill_req_size) << ";\n";
  os << "localparam [3:0] CPP_LLC_DVPW_REFILL_REQ_ID = "
     << dec_width(4, dirty_partial.refill_req_id) << ";\n";
  os << "localparam [63:0] CPP_LLC_DVPW_REFILL_RESP_LINE = "
     << hex_width(64, dirty_partial.refill_resp_line) << ";\n";
  os << "localparam [" << (kSetBits - 1)
     << ":0] CPP_LLC_DVPW_DATA_WR_SET = "
     << dec_width(kSetBits, dirty_partial.data_wr_set) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_DVPW_DATA_WR_WAY_MASK = "
     << hex_width(kWayCount, dirty_partial.data_wr_way_mask) << ";\n";
  os << "localparam [" << (kDataRowBits - 1)
     << ":0] CPP_LLC_DVPW_DATA_WR_ROW = "
     << hex_width(kDataRowBits, dirty_partial.data_wr_row) << ";\n";
  os << "localparam [" << (kSetBits - 1)
     << ":0] CPP_LLC_DVPW_META_WR_SET = "
     << dec_width(kSetBits, dirty_partial.meta_wr_set) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_DVPW_META_WR_WAY_MASK = "
     << hex_width(kWayCount, dirty_partial.meta_wr_way_mask) << ";\n";
  os << "localparam [" << (kMetaRowBits - 1)
     << ":0] CPP_LLC_DVPW_META_WR_ROW = "
     << hex_width(kMetaRowBits, dirty_partial.meta_wr_row) << ";\n";
  os << "localparam [" << (kSetBits - 1)
     << ":0] CPP_LLC_DVPW_VALID_WR_SET = "
     << dec_width(kSetBits, dirty_partial.valid_wr_set) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_DVPW_VALID_WR_MASK = "
     << hex_width(kWayCount, dirty_partial.valid_wr_mask) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_DVPW_VALID_WR_BITS = "
     << hex_width(kWayCount, dirty_partial.valid_wr_bits) << ";\n";
  os << "localparam [" << (kSetBits - 1)
     << ":0] CPP_LLC_DVPW_REPL_WR_SET = "
     << dec_width(kSetBits, dirty_partial.repl_wr_set) << ";\n";
  os << "localparam [" << (kWayBits - 1)
     << ":0] CPP_LLC_DVPW_REPL_WR_WAY = "
     << dec_width(kWayBits, dirty_partial.repl_wr_way) << ";\n";
  os << "localparam [3:0] CPP_LLC_DVPW_RESP_ID = "
     << dec_width(4, dirty_partial.resp_id) << ";\n";
  os << "localparam [1:0] CPP_LLC_DVPW_RESP_CODE = "
     << dec_width(2, dirty_partial.resp_code) << ";\n\n";

  os << "localparam [31:0] CPP_LLC_INV_ADDR = "
     << hex_width(32, inv.addr) << ";\n";
  os << "localparam [" << (kSetBits - 1) << ":0] CPP_LLC_INV_SET = "
     << dec_width(kSetBits, inv.set) << ";\n";
  os << "localparam [" << (kDataRowBits - 1)
     << ":0] CPP_LLC_INV_DATA_RD_ROW = "
     << hex_width(kDataRowBits, inv.data_rd_row) << ";\n";
  os << "localparam [" << (kMetaRowBits - 1)
     << ":0] CPP_LLC_INV_META_RD_ROW = "
     << hex_width(kMetaRowBits, inv.meta_rd_row) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_INV_VALID_RD_BITS = "
     << hex_width(kWayCount, inv.valid_rd_bits) << ";\n";
  os << "localparam [" << (kWayBits - 1)
     << ":0] CPP_LLC_INV_REPL_RD_WAY = "
     << dec_width(kWayBits, inv.repl_rd_way) << ";\n";
  os << "localparam [" << (kSetBits - 1)
     << ":0] CPP_LLC_INV_VALID_WR_SET = "
     << dec_width(kSetBits, inv.valid_wr_set) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_INV_VALID_WR_MASK = "
     << hex_width(kWayCount, inv.valid_wr_mask) << ";\n";
  os << "localparam [" << (kWayCount - 1)
     << ":0] CPP_LLC_INV_VALID_WR_BITS = "
     << hex_width(kWayCount, inv.valid_wr_bits) << ";\n\n";
  os << "`endif\n";
}

} // namespace

int main(int argc, char **argv) {
  try {
    if (argc != 2) {
      std::cerr << "usage: " << argv[0] << " <output.vh>\n";
      return 2;
    }
    const auto trace = generate_partial_write_hit();
    const auto miss = generate_read_miss_refill();
    const auto write_miss = generate_partial_write_miss_refill();
    const auto dirty = generate_dirty_victim_writeback();
    const auto dirty_partial = generate_dirty_partial_write_miss();
    const auto inv = generate_invalidate_line();
    std::ofstream out(argv[1]);
    if (!out) {
      std::cerr << "failed to open output: " << argv[1] << "\n";
      return 2;
    }
    emit_trace(out, trace, miss, write_miss, dirty, dirty_partial, inv);
    return 0;
  } catch (const std::exception &ex) {
    std::cerr << "axi_llc_cache_trace_vectors: " << ex.what() << "\n";
    return 1;
  }
}
