#include "AXI_LLC.h"
#include <cstdio>
#include <cstring>

using namespace axi_interconnect;

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

bool test_same_master_multi_mshr_bypass() {
  printf("=== LLC Test 5: same-master multi-MSHR bypass ===\n");
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

  if (test_same_master_multi_mshr_bypass())
    passed++;
  else
    failed++;

  printf("LLC results: %d passed, %d failed\n", passed, failed);
  return failed == 0 ? 0 : 1;
}
