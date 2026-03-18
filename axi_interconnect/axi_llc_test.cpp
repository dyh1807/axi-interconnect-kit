#include "AXI_LLC.h"
#include <cstdio>
#include <cstring>

using namespace axi_interconnect;

long long sim_time = 0;

namespace {

AXI_LLCConfig make_config() {
  AXI_LLCConfig config;
  config.enable = true;
  config.size_bytes = 512;
  config.line_bytes = 64;
  config.ways = 2;
  config.mshr_num = 2;
  return config;
}

void clear_inputs(AXI_LLC &llc) {
  llc.io.ext_in = {};
  llc.io.lookup_in = {};
}

void cycle(AXI_LLC &llc) { llc.comb(); llc.seq(); }

AXI_LLC_Bytes_t make_meta_set(const AXI_LLCConfig &config, uint32_t hit_way,
                              uint32_t tag) {
  AXI_LLC_Bytes_t meta;
  meta.resize(static_cast<size_t>(config.ways) * AXI_LLC_META_ENTRY_BYTES);
  for (uint32_t way = 0; way < config.ways; ++way) {
    AXI_LLCMetaEntry_t entry{};
    if (way == hit_way) {
      entry.tag = tag;
      entry.flags = AXI_LLC_META_VALID;
    }
    AXI_LLC_Bytes_t enc;
    AXI_LLC::encode_meta(entry, enc);
    std::memcpy(meta.data() + static_cast<size_t>(way) * AXI_LLC_META_ENTRY_BYTES,
                enc.data(), AXI_LLC_META_ENTRY_BYTES);
  }
  return meta;
}

AXI_LLC_Bytes_t make_meta_set_with_flags(const AXI_LLCConfig &config,
                                         uint32_t hit_way, uint32_t tag,
                                         uint8_t flags) {
  AXI_LLC_Bytes_t meta;
  meta.resize(static_cast<size_t>(config.ways) * AXI_LLC_META_ENTRY_BYTES);
  for (uint32_t way = 0; way < config.ways; ++way) {
    AXI_LLCMetaEntry_t entry{};
    if (way == hit_way) {
      entry.tag = tag;
      entry.flags = flags;
    }
    AXI_LLC_Bytes_t enc;
    AXI_LLC::encode_meta(entry, enc);
    std::memcpy(meta.data() + static_cast<size_t>(way) * AXI_LLC_META_ENTRY_BYTES,
                enc.data(), AXI_LLC_META_ENTRY_BYTES);
  }
  return meta;
}

void write_line_words(AXI_LLC_Bytes_t &data, const AXI_LLCConfig &config,
                      uint32_t way, uint32_t base_word) {
  const uint32_t words = AXI_LLC::line_words(config);
  for (uint32_t word = 0; word < words; ++word) {
    const uint32_t value = base_word + word;
    const size_t offset = static_cast<size_t>(way) * config.line_bytes +
                          static_cast<size_t>(word) * sizeof(uint32_t);
    data.data()[offset + 0] = static_cast<uint8_t>(value & 0xFFu);
    data.data()[offset + 1] = static_cast<uint8_t>((value >> 8) & 0xFFu);
    data.data()[offset + 2] = static_cast<uint8_t>((value >> 16) & 0xFFu);
    data.data()[offset + 3] = static_cast<uint8_t>((value >> 24) & 0xFFu);
  }
}

AXI_LLC_Bytes_t make_data_set(const AXI_LLCConfig &config, uint32_t hit_way,
                              uint32_t base_word) {
  AXI_LLC_Bytes_t data;
  data.resize(static_cast<size_t>(config.ways) * config.line_bytes);
  const uint32_t words = AXI_LLC::line_words(config);
  for (uint32_t word = 0; word < words; ++word) {
    const uint32_t value = base_word + word;
    const size_t offset = static_cast<size_t>(hit_way) * config.line_bytes +
                          static_cast<size_t>(word) * sizeof(uint32_t);
    data.data()[offset + 0] = static_cast<uint8_t>(value & 0xFFu);
    data.data()[offset + 1] = static_cast<uint8_t>((value >> 8) & 0xFFu);
    data.data()[offset + 2] = static_cast<uint8_t>((value >> 16) & 0xFFu);
    data.data()[offset + 3] = static_cast<uint8_t>((value >> 24) & 0xFFu);
  }
  return data;
}

AXI_LLC_Bytes_t make_repl(uint32_t way) {
  AXI_LLC_Bytes_t repl;
  repl.resize(AXI_LLC_REPL_BYTES);
  repl.data()[0] = static_cast<uint8_t>(way & 0xFFu);
  repl.data()[1] = static_cast<uint8_t>((way >> 8) & 0xFFu);
  repl.data()[2] = static_cast<uint8_t>((way >> 16) & 0xFFu);
  repl.data()[3] = static_cast<uint8_t>((way >> 24) & 0xFFu);
  return repl;
}

WideReadData_t make_line_data(uint32_t base_word) {
  WideReadData_t data;
  data.clear();
  for (uint32_t i = 0; i < 16; ++i) {
    data[i] = base_word + i;
  }
  return data;
}

bool test_hit_path() {
  printf("=== LLC Test 1: cacheable hit ===\n");
  AXI_LLC llc;
  auto config = make_config();
  llc.set_config(config);
  llc.reset();

  const uint32_t addr = 0x120 + 8;
  const uint32_t tag = AXI_LLC::tag_of(config, addr);
  const uint32_t exp_word0 = 0x1000 + ((addr % config.line_bytes) / 4);

  clear_inputs(llc);
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].valid = true;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].addr = addr;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].total_size = 15;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].id = 3;
  llc.comb();
  if (!llc.io.ext_out.upstream.read_req[MASTER_ICACHE].ready) {
    printf("FAIL: hit req not accepted\n");
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.comb();
  if (!llc.io.table_out.data.enable || !llc.io.table_out.meta.enable ||
      !llc.io.table_out.repl.enable) {
    printf("FAIL: lookup table read not issued\n");
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.io.lookup_in.data_valid = true;
  llc.io.lookup_in.meta_valid = true;
  llc.io.lookup_in.repl_valid = true;
  llc.io.lookup_in.data = make_data_set(config, 1, 0x1000);
  llc.io.lookup_in.meta = make_meta_set(config, 1, tag);
  llc.io.lookup_in.repl = make_repl(0);
  cycle(llc);

  clear_inputs(llc);
  llc.comb();
  auto &resp = llc.io.ext_out.upstream.read_resp[MASTER_ICACHE];
  if (!resp.valid || resp.id != 3 || resp.data[0] != exp_word0 ||
      resp.data[1] != exp_word0 + 1) {
    printf("FAIL: hit response mismatch id=%u d0=0x%x d1=0x%x\n", resp.id,
           resp.data[0], resp.data[1]);
    return false;
  }
  printf("PASS\n");
  return true;
}

bool test_miss_refill() {
  printf("=== LLC Test 2: miss refill ===\n");
  AXI_LLC llc;
  auto config = make_config();
  llc.set_config(config);
  llc.reset();

  const uint32_t addr = 0x1A0 + 12;
  const uint32_t set = AXI_LLC::set_index(config, addr);
  const uint32_t exp_word0 = 0x3000 + ((addr % config.line_bytes) / 4);

  clear_inputs(llc);
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].valid = true;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].addr = addr;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].total_size = 15;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].id = 5;
  cycle(llc);

  clear_inputs(llc);
  cycle(llc);

  clear_inputs(llc);
  llc.io.lookup_in.data_valid = true;
  llc.io.lookup_in.meta_valid = true;
  llc.io.lookup_in.repl_valid = true;
  llc.io.lookup_in.data = make_data_set(config, 0, 0x2000);
  llc.io.lookup_in.meta.resize(static_cast<size_t>(config.ways) * AXI_LLC_META_ENTRY_BYTES);
  llc.io.lookup_in.repl = make_repl(1);
  cycle(llc);

  clear_inputs(llc);
  llc.io.ext_in.mem.read_req_ready = true;
  llc.comb();
  if (!llc.io.ext_out.mem.read_req_valid ||
      llc.io.ext_out.mem.read_req_addr != AXI_LLC::line_addr(config, addr) ||
      llc.io.ext_out.mem.read_req_size != config.line_bytes - 1) {
    printf("FAIL: miss mem req mismatch valid=%d addr=0x%x size=%u\n",
           llc.io.ext_out.mem.read_req_valid, llc.io.ext_out.mem.read_req_addr,
           llc.io.ext_out.mem.read_req_size);
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.io.ext_in.mem.read_resp_valid = true;
  llc.io.ext_in.mem.read_resp_id = 0;
  llc.io.ext_in.mem.read_resp_data = make_line_data(0x3000);
  cycle(llc);

  clear_inputs(llc);
  llc.comb();
  if (!llc.io.table_out.data.write || !llc.io.table_out.meta.write ||
      !llc.io.table_out.repl.write || llc.io.table_out.data.index != set) {
    printf("FAIL: refill table writes missing\n");
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  cycle(llc);

  clear_inputs(llc);
  llc.comb();
  auto &resp = llc.io.ext_out.upstream.read_resp[MASTER_ICACHE];
  if (!resp.valid || resp.id != 5 || resp.data[0] != exp_word0 ||
      resp.data[1] != exp_word0 + 1) {
    printf("FAIL: refill resp mismatch id=%u d0=0x%x d1=0x%x\n", resp.id,
           resp.data[0], resp.data[1]);
    return false;
  }
  printf("PASS\n");
  return true;
}

bool test_bypass_read() {
  printf("=== LLC Test 3: bypass read ===\n");
  AXI_LLC llc;
  auto config = make_config();
  llc.set_config(config);
  llc.reset();

  clear_inputs(llc);
  llc.io.ext_in.upstream.read_req[MASTER_UNCORE_LSU_R].valid = true;
  llc.io.ext_in.upstream.read_req[MASTER_UNCORE_LSU_R].addr = 0x404;
  llc.io.ext_in.upstream.read_req[MASTER_UNCORE_LSU_R].total_size = 7;
  llc.io.ext_in.upstream.read_req[MASTER_UNCORE_LSU_R].id = 6;
  llc.io.ext_in.upstream.read_req[MASTER_UNCORE_LSU_R].bypass = true;
  cycle(llc);

  clear_inputs(llc);
  llc.io.ext_in.mem.read_req_ready = true;
  llc.comb();
  if (!llc.io.ext_out.mem.read_req_valid || llc.io.ext_out.mem.read_req_addr != 0x404 ||
      llc.io.ext_out.mem.read_req_size != 7) {
    printf("FAIL: bypass mem req mismatch\n");
    return false;
  }
  if (llc.io.table_out.data.enable || llc.io.table_out.meta.enable) {
    printf("FAIL: bypass unexpectedly touched table\n");
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.io.ext_in.mem.read_resp_valid = true;
  llc.io.ext_in.mem.read_resp_id = 0;
  llc.io.ext_in.mem.read_resp_data = make_line_data(0x4000);
  cycle(llc);

  clear_inputs(llc);
  cycle(llc);

  clear_inputs(llc);
  cycle(llc);

  clear_inputs(llc);
  cycle(llc);

  clear_inputs(llc);
  cycle(llc);

  clear_inputs(llc);
  llc.comb();
  auto &resp = llc.io.ext_out.upstream.read_resp[MASTER_UNCORE_LSU_R];
  if (!resp.valid || resp.id != 6 || resp.data[0] != 0x4000) {
    printf("FAIL: bypass resp mismatch id=%u d0=0x%x\n", resp.id, resp.data[0]);
    return false;
  }
  printf("PASS\n");
  return true;
}

bool test_write_passthrough() {
  printf("=== LLC Test 4: write passthrough ===\n");
  AXI_LLC llc;
  auto config = make_config();
  llc.set_config(config);
  llc.reset();

  clear_inputs(llc);
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].valid = true;
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].addr = 0x800;
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].total_size = 3;
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].id = 1;
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].wdata[0] = 0xDEADBEEF;
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].wstrb = 0xF;
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].bypass = true;
  llc.io.ext_in.mem.write_req_ready = true;
  llc.comb();
  if (!llc.io.ext_out.upstream.write_req[MASTER_DCACHE_W].ready ||
      !llc.io.ext_out.mem.write_req_valid ||
      llc.io.ext_out.mem.write_req_addr != 0x800 ||
      llc.io.ext_out.mem.write_req_data[0] != 0xDEADBEEF) {
    printf("FAIL: write passthrough req mismatch\n");
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.io.ext_in.mem.write_resp_valid = true;
  llc.io.ext_in.mem.write_resp = 0;
  cycle(llc);

  clear_inputs(llc);
  llc.comb();
  auto &resp = llc.io.ext_out.upstream.write_resp[MASTER_DCACHE_W];
  if (!resp.valid || resp.id != 1 || resp.resp != 0) {
    printf("FAIL: write passthrough resp mismatch\n");
    return false;
  }
  printf("PASS\n");
  return true;
}

bool test_cacheable_write_updates_table() {
  printf("=== LLC Test 5: cacheable write updates LLC ===\n");
  AXI_LLC llc;
  auto config = make_config();
  llc.set_config(config);
  llc.reset();

  const uint32_t addr = 0x840;
  const uint32_t tag = AXI_LLC::tag_of(config, addr);

  clear_inputs(llc);
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].valid = true;
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].addr = addr;
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].total_size =
      static_cast<uint8_t>(config.line_bytes - 1);
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].id = 2;
  for (uint32_t i = 0; i < config.line_bytes / sizeof(uint32_t); ++i) {
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].wdata[i] = 0x7000 + i;
  }
  for (uint32_t b = 0; b < config.line_bytes; ++b) {
    llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].wstrb.set(b, true);
  }
  llc.comb();
  if (!llc.io.ext_out.upstream.write_req[MASTER_DCACHE_W].ready ||
      llc.io.ext_out.mem.write_req_valid) {
    printf("FAIL: cacheable write req not accepted\n");
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.comb();
  if (!llc.io.table_out.data.enable || !llc.io.table_out.meta.enable ||
      !llc.io.table_out.repl.enable) {
    printf("FAIL: cacheable write lookup not issued\n");
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.io.lookup_in.data_valid = true;
  llc.io.lookup_in.meta_valid = true;
  llc.io.lookup_in.repl_valid = true;
  llc.io.lookup_in.data.resize(static_cast<size_t>(config.ways) * config.line_bytes);
  llc.io.lookup_in.meta.resize(static_cast<size_t>(config.ways) * AXI_LLC_META_ENTRY_BYTES);
  llc.io.lookup_in.repl = make_repl(1);
  llc.comb();
  if (!llc.io.table_out.data.enable || !llc.io.table_out.data.write ||
      !llc.io.table_out.meta.enable || !llc.io.table_out.meta.write) {
    printf("FAIL: cacheable write table update missing\n");
    return false;
  }
  if (llc.io.table_out.data.way != 0 || llc.io.table_out.meta.way != 0) {
    printf("FAIL: cacheable write replacement way mismatch data_way=%u meta_way=%u\n",
           llc.io.table_out.data.way, llc.io.table_out.meta.way);
    return false;
  }
  const auto meta = AXI_LLC::decode_meta(llc.io.table_out.meta.payload, 0);
  if (meta.tag != tag ||
      meta.flags != (AXI_LLC_META_VALID | AXI_LLC_META_DIRTY)) {
    printf("FAIL: cacheable write meta mismatch tag=0x%x flags=0x%x\n", meta.tag,
           meta.flags);
    return false;
  }
  cycle(llc);

  clear_inputs(llc);
  cycle(llc);

  clear_inputs(llc);
  llc.comb();
  auto &resp = llc.io.ext_out.upstream.write_resp[MASTER_DCACHE_W];
  if (!resp.valid || resp.id != 2 || resp.resp != 0) {
    printf("FAIL: cacheable write resp mismatch\n");
    return false;
  }
  printf("PASS\n");
  return true;
}

bool test_cacheable_write_dirty_victim_writeback() {
  printf("=== LLC Test 6: cacheable write dirty victim writeback ===\n");
  AXI_LLC llc;
  auto config = make_config();
  llc.set_config(config);
  llc.reset();

  const uint32_t victim_addr = 0x000;
  const uint32_t addr = 0x100;
  const uint32_t clean_addr = 0x080;
  const uint32_t victim_tag = AXI_LLC::tag_of(config, victim_addr);
  const uint32_t clean_tag = AXI_LLC::tag_of(config, clean_addr);
  const uint32_t tag = AXI_LLC::tag_of(config, addr);

  clear_inputs(llc);
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].valid = true;
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].addr = addr;
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].total_size =
      static_cast<uint8_t>(config.line_bytes - 1);
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].id = 3;
  for (uint32_t i = 0; i < config.line_bytes / sizeof(uint32_t); ++i) {
    llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].wdata[i] = 0x8800 + i;
  }
  for (uint32_t b = 0; b < config.line_bytes; ++b) {
    llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].wstrb.set(b, true);
  }
  llc.comb();
  if (!llc.io.ext_out.upstream.write_req[MASTER_DCACHE_W].ready ||
      llc.io.ext_out.mem.write_req_valid) {
    printf("FAIL: dirty victim write req not accepted cleanly\n");
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.comb();
  if (!llc.io.table_out.data.enable || !llc.io.table_out.meta.enable ||
      !llc.io.table_out.repl.enable) {
    printf("FAIL: dirty victim write lookup not issued\n");
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.io.lookup_in.data_valid = true;
  llc.io.lookup_in.meta_valid = true;
  llc.io.lookup_in.repl_valid = true;
  llc.io.lookup_in.data.resize(static_cast<size_t>(config.ways) * config.line_bytes);
  write_line_words(llc.io.lookup_in.data, config, 0, 0x3300);
  write_line_words(llc.io.lookup_in.data, config, 1, 0x4400);
  llc.io.lookup_in.meta.resize(static_cast<size_t>(config.ways) *
                               AXI_LLC_META_ENTRY_BYTES);
  AXI_LLCMetaEntry_t clean_meta{};
  clean_meta.tag = clean_tag;
  clean_meta.flags = AXI_LLC_META_VALID;
  AXI_LLC_Bytes_t enc_clean;
  AXI_LLC::encode_meta(clean_meta, enc_clean);
  std::memcpy(llc.io.lookup_in.meta.data(), enc_clean.data(), AXI_LLC_META_ENTRY_BYTES);
  AXI_LLCMetaEntry_t dirty_meta{};
  dirty_meta.tag = victim_tag;
  dirty_meta.flags = AXI_LLC_META_VALID | AXI_LLC_META_DIRTY;
  AXI_LLC_Bytes_t enc_dirty;
  AXI_LLC::encode_meta(dirty_meta, enc_dirty);
  std::memcpy(llc.io.lookup_in.meta.data() + AXI_LLC_META_ENTRY_BYTES,
              enc_dirty.data(), AXI_LLC_META_ENTRY_BYTES);
  llc.io.lookup_in.repl = make_repl(1);
  cycle(llc);

  clear_inputs(llc);
  cycle(llc);

  clear_inputs(llc);
  llc.io.ext_in.mem.write_req_ready = true;
  llc.comb();
  if (!llc.io.ext_out.mem.write_req_valid ||
      llc.io.ext_out.mem.write_req_addr != victim_addr ||
      llc.io.ext_out.mem.write_req_size != config.line_bytes - 1) {
    printf("FAIL: dirty victim wb req mismatch valid=%d addr=0x%x size=%u\n",
           llc.io.ext_out.mem.write_req_valid, llc.io.ext_out.mem.write_req_addr,
           llc.io.ext_out.mem.write_req_size);
    return false;
  }
  if (llc.io.table_out.data.enable || llc.io.table_out.meta.enable) {
    printf("FAIL: dirty victim prematurely updated tables\n");
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.io.ext_in.mem.write_resp_valid = true;
  llc.io.ext_in.mem.write_resp = 0;
  llc.comb();
  if (!llc.io.table_out.data.enable || !llc.io.table_out.data.write ||
      !llc.io.table_out.meta.enable || !llc.io.table_out.meta.write ||
      llc.io.table_out.data.way != 1) {
    printf("FAIL: dirty victim post-wb table update missing way=%u\n",
           llc.io.table_out.data.way);
    return false;
  }
  const auto meta = AXI_LLC::decode_meta(llc.io.table_out.meta.payload, 0);
  if (meta.tag != tag ||
      meta.flags != (AXI_LLC_META_VALID | AXI_LLC_META_DIRTY)) {
    printf("FAIL: dirty victim meta mismatch tag=0x%x flags=0x%x\n", meta.tag,
           meta.flags);
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  cycle(llc);

  clear_inputs(llc);
  cycle(llc);

  clear_inputs(llc);
  llc.comb();
  auto &resp = llc.io.ext_out.upstream.write_resp[MASTER_DCACHE_W];
  if (!resp.valid || resp.id != 3 || resp.resp != 0) {
    printf("FAIL: dirty victim final resp mismatch\n");
    return false;
  }
  printf("PASS\n");
  return true;
}

bool test_same_master_multi_mshr_bypass() {
  printf("=== LLC Test 7: same-master multi-MSHR bypass ===\n");
  AXI_LLC llc;
  auto config = make_config();
  config.mshr_num = 2;
  llc.set_config(config);
  llc.reset();

  struct Req {
    uint32_t addr;
    uint8_t id;
    uint32_t base_word;
  };
  const Req reqs[2] = {
      {.addr = 0x500, .id = 7, .base_word = 0x5000},
      {.addr = 0x540, .id = 8, .base_word = 0x6000},
  };

  clear_inputs(llc);
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].valid = true;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].addr = reqs[0].addr;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].total_size = 7;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].id = reqs[0].id;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].bypass = true;
  llc.comb();
  if (!llc.io.ext_out.upstream.read_req[MASTER_ICACHE].ready) {
    printf("FAIL: first bypass req not accepted\n");
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].valid = true;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].addr = reqs[1].addr;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].total_size = 7;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].id = reqs[1].id;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].bypass = true;
  llc.comb();
  if (!llc.io.ext_out.upstream.read_req[MASTER_ICACHE].ready) {
    printf("FAIL: second bypass req not accepted while first outstanding\n");
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.io.ext_in.mem.read_req_ready = true;
  llc.comb();
  if (!llc.io.ext_out.mem.read_req_valid || llc.io.ext_out.mem.read_req_id != 0 ||
      llc.io.ext_out.mem.read_req_addr != reqs[0].addr) {
    printf("FAIL: first mem read issue mismatch valid=%d id=%u addr=0x%x\n",
           llc.io.ext_out.mem.read_req_valid, llc.io.ext_out.mem.read_req_id,
           llc.io.ext_out.mem.read_req_addr);
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.io.ext_in.mem.read_req_ready = true;
  llc.comb();
  if (!llc.io.ext_out.mem.read_req_valid || llc.io.ext_out.mem.read_req_id != 1 ||
      llc.io.ext_out.mem.read_req_addr != reqs[1].addr) {
    printf("FAIL: second mem read issue mismatch valid=%d id=%u addr=0x%x\n",
           llc.io.ext_out.mem.read_req_valid, llc.io.ext_out.mem.read_req_id,
           llc.io.ext_out.mem.read_req_addr);
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.io.ext_in.mem.read_resp_valid = true;
  llc.io.ext_in.mem.read_resp_id = 0;
  llc.io.ext_in.mem.read_resp_data = make_line_data(reqs[0].base_word);
  cycle(llc);

  bool first_resp_latched = false;
  for (int i = 0; i < 3; ++i) {
    clear_inputs(llc);
    cycle(llc);
    if (llc.io.regs.read_resp_valid_r[MASTER_ICACHE]) {
      first_resp_latched = true;
      break;
    }
  }
  if (!first_resp_latched) {
    printf("FAIL: first bypass resp never latched\n");
    return false;
  }

  clear_inputs(llc);
  llc.comb();
  auto &resp0 = llc.io.ext_out.upstream.read_resp[MASTER_ICACHE];
  if (!resp0.valid || resp0.id != reqs[0].id || resp0.data[0] != reqs[0].base_word) {
    printf("FAIL: first bypass resp mismatch id=%u d0=0x%x\n", resp0.id,
           resp0.data[0]);
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.io.ext_in.upstream.read_resp[MASTER_ICACHE].ready = true;
  cycle(llc);

  clear_inputs(llc);
  llc.io.ext_in.mem.read_resp_valid = true;
  llc.io.ext_in.mem.read_resp_id = 1;
  llc.io.ext_in.mem.read_resp_data = make_line_data(reqs[1].base_word);
  cycle(llc);

  bool second_resp_latched = false;
  for (int i = 0; i < 3; ++i) {
    clear_inputs(llc);
    cycle(llc);
    if (llc.io.regs.read_resp_valid_r[MASTER_ICACHE]) {
      second_resp_latched = true;
      break;
    }
  }
  if (!second_resp_latched) {
    printf("FAIL: second bypass resp never latched\n");
    return false;
  }

  clear_inputs(llc);
  llc.comb();
  auto &resp1 = llc.io.ext_out.upstream.read_resp[MASTER_ICACHE];
  if (!resp1.valid || resp1.id != reqs[1].id || resp1.data[0] != reqs[1].base_word) {
    printf("FAIL: second bypass resp mismatch id=%u d0=0x%x\n", resp1.id,
           resp1.data[0]);
    return false;
  }
  printf("PASS\n");
  return true;
}

bool test_read_resp_holds_until_ready() {
  printf("=== LLC Test 8: read response holds until ready ===\n");
  AXI_LLC llc;
  auto config = make_config();
  llc.set_config(config);
  llc.reset();

  clear_inputs(llc);
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].valid = true;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].addr = 0x900;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].total_size = 7;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].id = 9;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].bypass = true;
  cycle(llc);

  clear_inputs(llc);
  llc.io.ext_in.mem.read_req_ready = true;
  cycle(llc);

  clear_inputs(llc);
  llc.io.ext_in.mem.read_resp_valid = true;
  llc.io.ext_in.mem.read_resp_id = 0;
  llc.io.ext_in.mem.read_resp_data = make_line_data(0x9000);
  cycle(llc);

  clear_inputs(llc);
  cycle(llc);

  for (int i = 0; i < 3; ++i) {
    clear_inputs(llc);
    llc.comb();
    auto &resp = llc.io.ext_out.upstream.read_resp[MASTER_ICACHE];
    if (!resp.valid || resp.id != 9 || resp.data[0] != 0x9000) {
      printf("FAIL: response dropped before ready on hold cycle %d\n", i);
      return false;
    }
    llc.seq();
  }

  clear_inputs(llc);
  llc.io.ext_in.upstream.read_resp[MASTER_ICACHE].ready = true;
  llc.comb();
  if (!llc.io.ext_out.upstream.read_resp[MASTER_ICACHE].valid) {
    printf("FAIL: response not visible on ready handshake cycle\n");
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.comb();
  if (llc.io.ext_out.upstream.read_resp[MASTER_ICACHE].valid) {
    printf("FAIL: response not cleared after ready handshake\n");
    return false;
  }
  printf("PASS\n");
  return true;
}

bool test_stream_prefetch_table_fill() {
  printf("=== LLC Test 9: stream prefetch table fill ===\n");
  AXI_LLC llc;
  auto config = make_config();
  config.prefetch_enable = true;
  config.mshr_num = 2;
  llc.set_config(config);
  llc.reset();

  const uint32_t addr_a = 0x200 + 16;
  const uint32_t line_b = AXI_LLC::line_addr(config, addr_a) + config.line_bytes;
  const uint32_t addr_b = line_b + 12;
  const uint32_t line_c = line_b + config.line_bytes;
  const uint32_t addr_c = line_c + 8;
  const uint32_t set_a = AXI_LLC::set_index(config, addr_a);
  const uint32_t set_b = AXI_LLC::set_index(config, addr_b);
  const uint32_t set_c = AXI_LLC::set_index(config, addr_c);
  const uint32_t word_a = 0x7000 + ((addr_a % config.line_bytes) / 4);
  const uint32_t word_b = 0x7100 + ((addr_b % config.line_bytes) / 4);
  const uint32_t tag_c = AXI_LLC::tag_of(config, addr_c);

  auto issue_miss = [&](uint32_t addr, uint8_t id) {
    clear_inputs(llc);
    llc.io.ext_in.upstream.read_req[MASTER_ICACHE].valid = true;
    llc.io.ext_in.upstream.read_req[MASTER_ICACHE].addr = addr;
    llc.io.ext_in.upstream.read_req[MASTER_ICACHE].total_size = 15;
    llc.io.ext_in.upstream.read_req[MASTER_ICACHE].id = id;
    cycle(llc);

    clear_inputs(llc);
    cycle(llc);

    clear_inputs(llc);
    llc.io.lookup_in.data_valid = true;
    llc.io.lookup_in.meta_valid = true;
    llc.io.lookup_in.repl_valid = true;
    llc.io.lookup_in.data.resize(static_cast<size_t>(config.ways) * config.line_bytes);
    llc.io.lookup_in.meta.resize(static_cast<size_t>(config.ways) *
                                 AXI_LLC_META_ENTRY_BYTES);
    llc.io.lookup_in.repl = make_repl(0);
    cycle(llc);

    clear_inputs(llc);
    llc.io.ext_in.mem.read_req_ready = true;
    cycle(llc);
  };

  issue_miss(addr_a, 10);
  clear_inputs(llc);
  llc.io.ext_in.mem.read_resp_valid = true;
  llc.io.ext_in.mem.read_resp_id = 0;
  llc.io.ext_in.mem.read_resp_data = make_line_data(0x7000);
  cycle(llc);

  clear_inputs(llc);
  llc.comb();
  if (!llc.io.table_out.data.write || !llc.io.table_out.meta.write ||
      llc.io.table_out.data.index != set_a) {
    printf("FAIL: demand A refill table write missing\n");
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  cycle(llc);

  clear_inputs(llc);
  llc.comb();
  if (!llc.io.ext_out.upstream.read_resp[MASTER_ICACHE].valid ||
      llc.io.ext_out.upstream.read_resp[MASTER_ICACHE].data[0] != word_a) {
    printf("FAIL: demand A response mismatch\n");
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.io.ext_in.upstream.read_resp[MASTER_ICACHE].ready = true;
  cycle(llc);

  issue_miss(addr_b, 11);
  clear_inputs(llc);
  llc.io.ext_in.mem.read_resp_valid = true;
  llc.io.ext_in.mem.read_resp_id = 0;
  llc.io.ext_in.mem.read_resp_data = make_line_data(0x7100);
  cycle(llc);

  clear_inputs(llc);
  llc.comb();
  if (!llc.io.table_out.data.write || !llc.io.table_out.meta.write ||
      llc.io.table_out.data.index != set_b) {
    printf("FAIL: demand B refill table write missing\n");
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  cycle(llc);

  clear_inputs(llc);
  llc.io.ext_in.mem.read_req_ready = true;
  llc.comb();
  if (!llc.io.ext_out.upstream.read_resp[MASTER_ICACHE].valid ||
      llc.io.ext_out.upstream.read_resp[MASTER_ICACHE].data[0] != word_b) {
    printf("FAIL: demand B response mismatch\n");
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.io.ext_in.upstream.read_resp[MASTER_ICACHE].ready = true;
  cycle(llc);

  bool prefetch_lookup_seen = false;
  for (int i = 0; i < 8; ++i) {
    clear_inputs(llc);
    llc.comb();
    if (llc.io.table_out.data.enable && llc.io.table_out.meta.enable &&
        llc.io.table_out.repl.enable) {
      prefetch_lookup_seen = true;
      break;
    }
    llc.seq();
  }
  if (!prefetch_lookup_seen) {
    printf("FAIL: stream prefetch lookup not issued\n");
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.io.lookup_in.data_valid = true;
  llc.io.lookup_in.meta_valid = true;
  llc.io.lookup_in.repl_valid = true;
  llc.io.lookup_in.data.resize(static_cast<size_t>(config.ways) * config.line_bytes);
  llc.io.lookup_in.meta.resize(static_cast<size_t>(config.ways) *
                               AXI_LLC_META_ENTRY_BYTES);
  llc.io.lookup_in.repl = make_repl(0);
  cycle(llc);

  clear_inputs(llc);
  llc.io.ext_in.mem.read_req_ready = true;
  llc.comb();
  const uint8_t prefetch_mem_id = llc.io.ext_out.mem.read_req_id;
  if (!llc.io.ext_out.mem.read_req_valid ||
      llc.io.ext_out.mem.read_req_addr != line_c) {
    printf("FAIL: stream prefetch mem req mismatch valid=%d addr=0x%x id=%u\n",
           llc.io.ext_out.mem.read_req_valid, llc.io.ext_out.mem.read_req_addr,
           llc.io.ext_out.mem.read_req_id);
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.io.ext_in.mem.read_resp_valid = true;
  llc.io.ext_in.mem.read_resp_id = prefetch_mem_id;
  llc.io.ext_in.mem.read_resp_data = make_line_data(0x7200);
  cycle(llc);

  clear_inputs(llc);
  llc.comb();
  if (!llc.io.table_out.data.write || !llc.io.table_out.meta.write ||
      llc.io.table_out.data.index != set_c) {
    printf("FAIL: prefetch refill table write missing data=%d meta=%d idx=%u state=%u\n",
           llc.io.table_out.data.write, llc.io.table_out.meta.write,
           llc.io.table_out.data.index, static_cast<unsigned>(llc.io.regs.state));
    return false;
  }
  const auto prefetch_meta = AXI_LLC::decode_meta(llc.io.table_out.meta.payload, 0);
  if ((prefetch_meta.flags & AXI_LLC_META_PREFETCH) == 0 || prefetch_meta.tag != tag_c) {
    printf("FAIL: prefetch meta flag/tag mismatch flags=0x%x tag=0x%x\n",
           prefetch_meta.flags, prefetch_meta.tag);
    return false;
  }
  const auto &perf = llc.perf_counters();
  if (perf.prefetch_issue != 1 || perf.read_access != 2 || perf.read_miss != 2) {
    printf("FAIL: prefetch perf mismatch issue=%llu hit=%llu acc=%llu rh=%llu rm=%llu\n",
           static_cast<unsigned long long>(perf.prefetch_issue),
           static_cast<unsigned long long>(perf.prefetch_hit),
           static_cast<unsigned long long>(perf.read_access),
           static_cast<unsigned long long>(perf.read_hit),
           static_cast<unsigned long long>(perf.read_miss));
    return false;
  }
  printf("PASS\n");
  return true;
}

bool test_prefetch_degree_two_queue() {
  printf("=== LLC Test 10: prefetch degree two queue ===\n");
  AXI_LLC llc;
  auto config = make_config();
  config.prefetch_enable = true;
  config.prefetch_degree = 2;
  config.mshr_num = 2;
  llc.set_config(config);
  llc.reset();

  const uint32_t addr_a = 0x200 + 16;
  const uint32_t line_b = AXI_LLC::line_addr(config, addr_a) + config.line_bytes;
  const uint32_t addr_b = line_b + 12;
  const uint32_t line_c = line_b + config.line_bytes;
  const uint32_t line_d = line_c + config.line_bytes;

  auto issue_demand_miss = [&](uint32_t addr, uint8_t id, uint32_t fill_base) {
    clear_inputs(llc);
    llc.io.ext_in.upstream.read_req[MASTER_ICACHE].valid = true;
    llc.io.ext_in.upstream.read_req[MASTER_ICACHE].addr = addr;
    llc.io.ext_in.upstream.read_req[MASTER_ICACHE].total_size = 15;
    llc.io.ext_in.upstream.read_req[MASTER_ICACHE].id = id;
    cycle(llc);

    clear_inputs(llc);
    cycle(llc);

    clear_inputs(llc);
    llc.io.lookup_in.data_valid = true;
    llc.io.lookup_in.meta_valid = true;
    llc.io.lookup_in.repl_valid = true;
    llc.io.lookup_in.data.resize(static_cast<size_t>(config.ways) * config.line_bytes);
    llc.io.lookup_in.meta.resize(static_cast<size_t>(config.ways) *
                                 AXI_LLC_META_ENTRY_BYTES);
    llc.io.lookup_in.repl = make_repl(0);
    cycle(llc);

    clear_inputs(llc);
    llc.io.ext_in.mem.read_req_ready = true;
    cycle(llc);

    clear_inputs(llc);
    llc.io.ext_in.mem.read_resp_valid = true;
    llc.io.ext_in.mem.read_resp_id = 0;
    llc.io.ext_in.mem.read_resp_data = make_line_data(fill_base);
    cycle(llc);

    clear_inputs(llc);
    llc.comb();
    llc.seq();

    clear_inputs(llc);
    llc.comb();
    llc.seq();

    clear_inputs(llc);
    llc.io.ext_in.upstream.read_resp[MASTER_ICACHE].ready = true;
    cycle(llc);
  };

  issue_demand_miss(addr_a, 1, 0x7000);
  issue_demand_miss(addr_b, 2, 0x7100);

  bool lookup_seen = false;
  for (int i = 0; i < 8; ++i) {
    clear_inputs(llc);
    llc.comb();
    if (llc.io.table_out.data.enable && llc.io.table_out.meta.enable &&
        llc.io.table_out.repl.enable) {
      lookup_seen = true;
      break;
    }
    llc.seq();
  }
  if (!lookup_seen) {
    printf("FAIL: first queued prefetch lookup not issued\n");
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.io.lookup_in.data_valid = true;
  llc.io.lookup_in.meta_valid = true;
  llc.io.lookup_in.repl_valid = true;
  llc.io.lookup_in.data.resize(static_cast<size_t>(config.ways) * config.line_bytes);
  llc.io.lookup_in.meta.resize(static_cast<size_t>(config.ways) *
                               AXI_LLC_META_ENTRY_BYTES);
  llc.io.lookup_in.repl = make_repl(0);
  cycle(llc);

  clear_inputs(llc);
  llc.io.ext_in.mem.read_req_ready = true;
  llc.comb();
  if (!llc.io.ext_out.mem.read_req_valid || llc.io.ext_out.mem.read_req_addr != line_c) {
    printf("FAIL: first degree-two prefetch mem req mismatch addr=0x%x\n",
           llc.io.ext_out.mem.read_req_addr);
    return false;
  }
  const uint8_t pref_c_id = llc.io.ext_out.mem.read_req_id;
  llc.seq();

  clear_inputs(llc);
  llc.io.ext_in.mem.read_resp_valid = true;
  llc.io.ext_in.mem.read_resp_id = pref_c_id;
  llc.io.ext_in.mem.read_resp_data = make_line_data(0x7200);
  cycle(llc);

  bool queued_line_d = false;
  for (uint32_t i = 0; i < AXI_LLC_MAX_PREFETCH_QUEUE; ++i) {
    if (llc.io.regs.prefetch_q[i].valid && llc.io.regs.prefetch_q[i].line_addr == line_d) {
      queued_line_d = true;
      break;
    }
  }
  const auto &perf = llc.perf_counters();
  if (!queued_line_d || perf.prefetch_issue != 1 || perf.prefetch_drop_queue_full != 0) {
    printf("FAIL: degree-two queue mismatch queued_d=%d issue=%llu queue_drop=%llu\n",
           queued_line_d,
           static_cast<unsigned long long>(perf.prefetch_issue),
           static_cast<unsigned long long>(perf.prefetch_drop_queue_full));
    return false;
  }
  printf("PASS\n");
  return true;
}

bool test_demand_mem_issue_preempts_prefetch() {
  printf("=== LLC Test 11: demand mem issue preempts prefetch ===\n");
  AXI_LLC llc;
  auto config = make_config();
  config.prefetch_enable = true;
  config.mshr_num = 2;
  llc.set_config(config);
  llc.reset();

  clear_inputs(llc);
  llc.io.regs.mshr[0].valid = true;
  llc.io.regs.mshr[0].is_prefetch = true;
  llc.io.regs.mshr[0].line_addr = 0x400;
  llc.io.regs.mshr[1].valid = true;
  llc.io.regs.mshr[1].line_addr = 0x800;
  llc.comb();

  if (!llc.io.ext_out.mem.read_req_valid || llc.io.ext_out.mem.read_req_addr != 0x800 ||
      llc.io.ext_out.mem.read_req_id != 1) {
    printf("FAIL: demand mem issue was not prioritized addr=0x%x id=%u\n",
           llc.io.ext_out.mem.read_req_addr, llc.io.ext_out.mem.read_req_id);
    return false;
  }
  printf("PASS\n");
  return true;
}

bool test_lookup_request_is_one_shot() {
  printf("=== LLC Test 12: lookup request is one-shot ===\n");
  AXI_LLC llc;
  auto config = make_config();
  llc.set_config(config);
  llc.reset();

  const uint32_t addr = 0x180 + 4;
  const uint32_t tag = AXI_LLC::tag_of(config, addr);

  clear_inputs(llc);
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].valid = true;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].addr = addr;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].total_size = 15;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].id = 2;
  cycle(llc);

  clear_inputs(llc);
  llc.comb();
  if (!llc.io.table_out.data.enable || !llc.io.table_out.meta.enable ||
      !llc.io.table_out.repl.enable || !llc.io.reg_write.lookup_issued_r) {
    printf("FAIL: initial lookup pulse missing\n");
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.comb();
  if (llc.io.table_out.data.enable || llc.io.table_out.meta.enable ||
      llc.io.table_out.repl.enable) {
    printf("FAIL: lookup request repeated while waiting for SRAM response\n");
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.io.lookup_in.data_valid = true;
  llc.io.lookup_in.meta_valid = true;
  llc.io.lookup_in.repl_valid = true;
  llc.io.lookup_in.data = make_data_set(config, 0, 0x2200);
  llc.io.lookup_in.meta = make_meta_set(config, 0, tag);
  llc.io.lookup_in.repl = make_repl(1);
  cycle(llc);

  clear_inputs(llc);
  llc.comb();
  if (!llc.io.ext_out.upstream.read_resp[MASTER_ICACHE].valid ||
      llc.io.ext_out.upstream.read_resp[MASTER_ICACHE].id != 2) {
    printf("FAIL: hit response missing after one-shot lookup\n");
    return false;
  }
  printf("PASS\n");
  return true;
}

bool test_same_line_inflight_not_ready() {
  printf("=== LLC Test 13: same-line inflight blocks early ready ===\n");
  AXI_LLC llc;
  auto config = make_config();
  llc.set_config(config);
  llc.reset();

  const uint32_t addr = 0x180;
  llc.io.regs.mshr[0].valid = true;
  llc.io.regs.mshr[0].line_addr = AXI_LLC::line_addr(config, addr);
  llc.io.regs.mshr[0].is_prefetch = true;

  if (llc.can_accept_read_now(MASTER_ICACHE, false, addr)) {
    printf("FAIL: early ready allowed while same line is inflight\n");
    return false;
  }
  printf("PASS\n");
  return true;
}

bool test_line_invalidate_maintenance() {
  printf("=== LLC Test 14: line invalidate maintenance ===\n");
  AXI_LLC llc;
  auto config = make_config();
  llc.set_config(config);
  llc.reset();

  const uint32_t addr = 0x240;
  const uint32_t tag = AXI_LLC::tag_of(config, addr);

  clear_inputs(llc);
  llc.io.ext_in.mem.invalidate_line_valid = true;
  llc.io.ext_in.mem.invalidate_line_addr = addr;
  llc.comb();
  if (!llc.io.ext_out.mem.invalidate_line_accepted) {
    printf("FAIL: invalidate maintenance not accepted\n");
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.comb();
  if (!llc.io.table_out.data.enable || !llc.io.table_out.meta.enable ||
      !llc.io.table_out.repl.enable) {
    printf("FAIL: invalidate lookup not issued\n");
    return false;
  }
  llc.seq();

  clear_inputs(llc);
  llc.io.lookup_in.data_valid = true;
  llc.io.lookup_in.meta_valid = true;
  llc.io.lookup_in.repl_valid = true;
  llc.io.lookup_in.data = make_data_set(config, 1, 0x4000);
  llc.io.lookup_in.meta = make_meta_set(config, 1, tag);
  llc.io.lookup_in.repl = make_repl(0);
  llc.comb();
  if (!llc.io.table_out.meta.enable || !llc.io.table_out.meta.write ||
      llc.io.table_out.meta.way != 1) {
    printf("FAIL: invalidate meta write missing enable=%d write=%d way=%u\n",
           static_cast<int>(llc.io.table_out.meta.enable),
           static_cast<int>(llc.io.table_out.meta.write), llc.io.table_out.meta.way);
    return false;
  }
  const auto meta = AXI_LLC::decode_meta(llc.io.table_out.meta.payload, 0);
  if (meta.flags != 0) {
    printf("FAIL: invalidate meta flags not cleared flags=0x%x\n", meta.flags);
    return false;
  }
  if (llc.io.ext_out.upstream.read_resp[MASTER_ICACHE].valid) {
    printf("FAIL: invalidate maintenance incorrectly produced read response\n");
    return false;
  }

  printf("PASS\n");
  return true;
}

bool test_cacheable_write_wins_lookup_slot() {
  printf("=== LLC Test 15: cacheable write wins shared lookup slot ===\n");
  AXI_LLC llc;
  auto config = make_config();
  llc.set_config(config);
  llc.reset();

  const uint32_t write_addr = 0x840;
  const uint32_t read_addr = 0x180;

  clear_inputs(llc);
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].valid = true;
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].addr = write_addr;
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].total_size =
      static_cast<uint8_t>(config.line_bytes - 1);
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].id = 4;
  for (uint32_t i = 0; i < config.line_bytes / sizeof(uint32_t); ++i) {
    llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].wdata[i] = 0x9900 + i;
  }
  for (uint32_t b = 0; b < config.line_bytes; ++b) {
    llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].wstrb.set(b, true);
  }
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].valid = true;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].addr = read_addr;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].total_size = 15;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].id = 7;
  llc.comb();
  if (!llc.io.ext_out.upstream.write_req[MASTER_DCACHE_W].ready) {
    printf("FAIL: cacheable write not accepted\n");
    return false;
  }
  if (llc.io.ext_out.upstream.read_req[MASTER_ICACHE].ready) {
    printf("FAIL: read incorrectly accepted in same cycle as write lookup allocation\n");
    return false;
  }
  llc.seq();

  if (!llc.io.regs.write_active_r || llc.io.regs.write_is_bypass_r ||
      !llc.io.regs.lookup_valid_r || !llc.io.regs.lookup_is_write_r ||
      llc.io.regs.lookup_addr_r != write_addr) {
    printf(
        "FAIL: write lookup state corrupted active=%d bypass=%d lookup=%d is_write=%d addr=0x%x\n",
        static_cast<int>(llc.io.regs.write_active_r),
        static_cast<int>(llc.io.regs.write_is_bypass_r),
        static_cast<int>(llc.io.regs.lookup_valid_r),
        static_cast<int>(llc.io.regs.lookup_is_write_r),
        llc.io.regs.lookup_addr_r);
    return false;
  }

  clear_inputs(llc);
  llc.comb();
  if (!llc.io.table_out.data.enable || !llc.io.table_out.meta.enable ||
      !llc.io.table_out.repl.enable) {
    printf("FAIL: write lookup request not issued after arbitration\n");
    return false;
  }

  printf("PASS\n");
  return true;
}

bool test_pending_upstream_write_blocks_same_line_read() {
  printf("=== LLC Test 16: pending upstream write blocks same-line read ===\n");
  AXI_LLC llc;
  auto config = make_config();
  llc.set_config(config);
  llc.reset();

  const uint32_t line_addr = 0x840;
  const uint32_t same_line_read = line_addr + 8;
  const uint32_t other_line_read = 0x900;

  llc.io.regs.write_active_r = true;
  llc.io.regs.write_is_bypass_r = true;
  llc.io.regs.write_active_master_r = MASTER_UNCORE_LSU_W;

  clear_inputs(llc);
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].valid = true;
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].addr = line_addr;
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].total_size =
      static_cast<uint8_t>(config.line_bytes - 1);
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].id = 9;
  for (uint32_t i = 0; i < config.line_bytes / sizeof(uint32_t); ++i) {
    llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].wdata[i] = 0xAA00 + i;
  }
  for (uint32_t b = 0; b < config.line_bytes; ++b) {
    llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].wstrb.set(b, true);
  }
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].valid = true;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].addr = same_line_read;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].total_size = 15;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].id = 10;
  llc.comb();
  if (llc.io.ext_out.upstream.write_req[MASTER_DCACHE_W].ready) {
    printf("FAIL: queued write unexpectedly accepted while another write is active\n");
    return false;
  }
  if (llc.io.ext_out.upstream.read_req[MASTER_ICACHE].ready) {
    printf("FAIL: same-line read incorrectly accepted while queued write is pending\n");
    return false;
  }

  clear_inputs(llc);
  llc.io.regs.write_active_r = true;
  llc.io.regs.write_is_bypass_r = true;
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].valid = true;
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].addr = line_addr;
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].total_size =
      static_cast<uint8_t>(config.line_bytes - 1);
  llc.io.ext_in.upstream.write_req[MASTER_DCACHE_W].id = 9;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].valid = true;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].addr = other_line_read;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].total_size = 15;
  llc.io.ext_in.upstream.read_req[MASTER_ICACHE].id = 11;
  llc.comb();
  if (!llc.io.ext_out.upstream.read_req[MASTER_ICACHE].ready) {
    printf("FAIL: other-line read should not be blocked by queued write\n");
    return false;
  }

  printf("PASS\n");
  return true;
}

} // namespace

int main() {
  int passed = 0;
  int failed = 0;

  if (test_hit_path())
    passed++;
  else
    failed++;

  if (test_miss_refill())
    passed++;
  else
    failed++;

  if (test_bypass_read())
    passed++;
  else
    failed++;

  if (test_write_passthrough())
    passed++;
  else
    failed++;

  if (test_cacheable_write_updates_table())
    passed++;
  else
    failed++;

  if (test_cacheable_write_dirty_victim_writeback())
    passed++;
  else
    failed++;

  if (test_same_master_multi_mshr_bypass())
    passed++;
  else
    failed++;

  if (test_read_resp_holds_until_ready())
    passed++;
  else
    failed++;

  if (test_stream_prefetch_table_fill())
    passed++;
  else
    failed++;

  if (test_prefetch_degree_two_queue())
    passed++;
  else
    failed++;

  if (test_demand_mem_issue_preempts_prefetch())
    passed++;
  else
    failed++;

  if (test_lookup_request_is_one_shot())
    passed++;
  else
    failed++;

  if (test_same_line_inflight_not_ready())
    passed++;
  else
    failed++;

  if (test_line_invalidate_maintenance())
    passed++;
  else
    failed++;

  if (test_cacheable_write_wins_lookup_slot())
    passed++;
  else
    failed++;

  if (test_pending_upstream_write_blocks_same_line_read())
    passed++;
  else
    failed++;

  printf("LLC results: %d passed, %d failed\n", passed, failed);
  return failed == 0 ? 0 : 1;
}
