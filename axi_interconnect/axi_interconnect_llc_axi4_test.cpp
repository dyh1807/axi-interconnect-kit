#include <cstdio>
#include <cstring>
#include <random>
#include <unordered_map>
#include <vector>

#include "AXI_Interconnect.h"
#include "SimDDR.h"

uint32_t *p_memory = nullptr;
long long sim_time = 0;
constexpr uint32_t TEST_MEM_SIZE_WORDS = 0x100000;

namespace {

using namespace axi_interconnect;

struct ArEvent {
  uint32_t addr = 0;
  uint8_t id = 0;
  uint8_t len = 0;
};

struct FakeLlcTables {
  AXI_LLCConfig config{};
  AXI_LLC_LookupIn_t lookup_in{};
  std::vector<AXI_LLC_Bytes_t> data_sets{};
  std::vector<AXI_LLC_Bytes_t> meta_sets{};
  std::vector<AXI_LLC_Bytes_t> repl_sets{};

  bool pending_data = false;
  bool pending_meta = false;
  bool pending_repl = false;
  uint32_t pending_data_index = 0;
  uint32_t pending_meta_index = 0;
  uint32_t pending_repl_index = 0;

  void init(const AXI_LLCConfig &cfg) {
    config = cfg;
    const uint32_t sets = config.set_count();
    data_sets.assign(sets, {});
    meta_sets.assign(sets, {});
    repl_sets.assign(sets, {});
    for (uint32_t set = 0; set < sets; ++set) {
      data_sets[set].resize(static_cast<size_t>(config.ways) * config.line_bytes);
      meta_sets[set].resize(static_cast<size_t>(config.ways) * AXI_LLC_META_ENTRY_BYTES);
      repl_sets[set].resize(AXI_LLC_REPL_BYTES);
    }
    lookup_in = {};
    pending_data = pending_meta = pending_repl = false;
    pending_data_index = pending_meta_index = pending_repl_index = 0;
  }

  void comb_outputs() {
    lookup_in = {};
    if (pending_data && pending_data_index < data_sets.size()) {
      lookup_in.data_valid = true;
      lookup_in.data = data_sets[pending_data_index];
    }
    if (pending_meta && pending_meta_index < meta_sets.size()) {
      lookup_in.meta_valid = true;
      lookup_in.meta = meta_sets[pending_meta_index];
    }
    if (pending_repl && pending_repl_index < repl_sets.size()) {
      lookup_in.repl_valid = true;
      lookup_in.repl = repl_sets[pending_repl_index];
    }
  }

  static void write_way_payload(AXI_LLC_Bytes_t &set_payload, uint32_t way,
                                uint32_t bytes_per_way,
                                const AXI_LLC_Bytes_t &payload,
                                const std::vector<uint8_t> &byte_enable) {
    const size_t base = static_cast<size_t>(way) * bytes_per_way;
    for (uint32_t i = 0; i < bytes_per_way; ++i) {
      if (base + i >= set_payload.size() || i >= payload.size()) {
        break;
      }
      if (!byte_enable.empty() && i < byte_enable.size() && byte_enable[i] == 0) {
        continue;
      }
      set_payload.data()[base + i] = payload.data()[i];
    }
  }

  static void write_plain_payload(AXI_LLC_Bytes_t &dst,
                                  const AXI_LLC_Bytes_t &payload,
                                  const std::vector<uint8_t> &byte_enable) {
    const size_t limit = std::min(dst.size(), payload.size());
    for (size_t i = 0; i < limit; ++i) {
      if (!byte_enable.empty() && i < byte_enable.size() && byte_enable[i] == 0) {
        continue;
      }
      dst.data()[i] = payload.data()[i];
    }
  }

  void seq(const AXI_LLC_TableOut_t &table_out) {
    pending_data = pending_meta = pending_repl = false;

    if (table_out.invalidate_all) {
      for (auto &data : data_sets) {
        data.resize(static_cast<size_t>(config.ways) * config.line_bytes);
      }
      for (auto &meta : meta_sets) {
        meta.resize(static_cast<size_t>(config.ways) * AXI_LLC_META_ENTRY_BYTES);
      }
      for (auto &repl : repl_sets) {
        repl.resize(AXI_LLC_REPL_BYTES);
      }
    }

    if (table_out.data.write && table_out.data.index < data_sets.size()) {
      write_way_payload(data_sets[table_out.data.index], table_out.data.way,
                        config.line_bytes, table_out.data.payload,
                        table_out.data.byte_enable);
    } else if (table_out.data.enable && table_out.data.index < data_sets.size()) {
      pending_data = true;
      pending_data_index = table_out.data.index;
    }

    if (table_out.meta.write && table_out.meta.index < meta_sets.size()) {
      write_way_payload(meta_sets[table_out.meta.index], table_out.meta.way,
                        AXI_LLC_META_ENTRY_BYTES, table_out.meta.payload,
                        table_out.meta.byte_enable);
    } else if (table_out.meta.enable && table_out.meta.index < meta_sets.size()) {
      pending_meta = true;
      pending_meta_index = table_out.meta.index;
    }

    if (table_out.repl.write && table_out.repl.index < repl_sets.size()) {
      write_plain_payload(repl_sets[table_out.repl.index], table_out.repl.payload,
                          table_out.repl.byte_enable);
    } else if (table_out.repl.enable && table_out.repl.index < repl_sets.size()) {
      pending_repl = true;
      pending_repl_index = table_out.repl.index;
    }
  }
};

struct TestEnv {
  AXI_Interconnect interconnect;
  sim_ddr::SimDDR ddr;
  FakeLlcTables tables;
  std::vector<ArEvent> ar_events{};
};

void clear_upstream_inputs(AXI_Interconnect &interconnect) {
  for (int i = 0; i < NUM_READ_MASTERS; ++i) {
    interconnect.read_ports[i].req.valid = false;
    interconnect.read_ports[i].req.addr = 0;
    interconnect.read_ports[i].req.total_size = 0;
    interconnect.read_ports[i].req.id = 0;
    interconnect.read_ports[i].req.bypass = false;
    interconnect.read_ports[i].resp.ready = false;
  }
  for (int i = 0; i < NUM_WRITE_MASTERS; ++i) {
    interconnect.write_ports[i].req.valid = false;
    interconnect.write_ports[i].req.addr = 0;
    interconnect.write_ports[i].req.total_size = 0;
    interconnect.write_ports[i].req.id = 0;
    interconnect.write_ports[i].req.bypass = false;
    interconnect.write_ports[i].req.wdata.clear();
    interconnect.write_ports[i].req.wstrb.clear();
    interconnect.write_ports[i].resp.ready = false;
  }
}

void cycle_outputs(TestEnv &env) {
  clear_upstream_inputs(env.interconnect);
  env.tables.comb_outputs();
  env.interconnect.set_llc_lookup_in(env.tables.lookup_in);

  env.ddr.comb_outputs();
  env.interconnect.axi_io.ar.arready = env.ddr.io.ar.arready;
  env.interconnect.axi_io.r.rvalid = env.ddr.io.r.rvalid;
  env.interconnect.axi_io.r.rid = env.ddr.io.r.rid;
  env.interconnect.axi_io.r.rdata = env.ddr.io.r.rdata;
  env.interconnect.axi_io.r.rlast = env.ddr.io.r.rlast;
  env.interconnect.axi_io.r.rresp = env.ddr.io.r.rresp;
  env.interconnect.axi_io.aw.awready = env.ddr.io.aw.awready;
  env.interconnect.axi_io.w.wready = env.ddr.io.w.wready;
  env.interconnect.axi_io.b.bvalid = env.ddr.io.b.bvalid;
  env.interconnect.axi_io.b.bid = env.ddr.io.b.bid;
  env.interconnect.axi_io.b.bresp = env.ddr.io.b.bresp;

  env.interconnect.comb_outputs();
}

void cycle_inputs(TestEnv &env) {
  env.interconnect.comb_inputs();

  if (env.interconnect.axi_io.ar.arvalid && env.interconnect.axi_io.ar.arready) {
    env.ar_events.push_back({env.interconnect.axi_io.ar.araddr,
                             static_cast<uint8_t>(env.interconnect.axi_io.ar.arid),
                             static_cast<uint8_t>(env.interconnect.axi_io.ar.arlen)});
  }

  env.ddr.io.ar.arvalid = env.interconnect.axi_io.ar.arvalid;
  env.ddr.io.ar.araddr = env.interconnect.axi_io.ar.araddr;
  env.ddr.io.ar.arid = env.interconnect.axi_io.ar.arid;
  env.ddr.io.ar.arlen = env.interconnect.axi_io.ar.arlen;
  env.ddr.io.ar.arsize = env.interconnect.axi_io.ar.arsize;
  env.ddr.io.ar.arburst = env.interconnect.axi_io.ar.arburst;

  env.ddr.io.aw.awvalid = env.interconnect.axi_io.aw.awvalid;
  env.ddr.io.aw.awaddr = env.interconnect.axi_io.aw.awaddr;
  env.ddr.io.aw.awid = env.interconnect.axi_io.aw.awid;
  env.ddr.io.aw.awlen = env.interconnect.axi_io.aw.awlen;
  env.ddr.io.aw.awsize = env.interconnect.axi_io.aw.awsize;
  env.ddr.io.aw.awburst = env.interconnect.axi_io.aw.awburst;

  env.ddr.io.w.wvalid = env.interconnect.axi_io.w.wvalid;
  env.ddr.io.w.wdata = env.interconnect.axi_io.w.wdata;
  env.ddr.io.w.wstrb = env.interconnect.axi_io.w.wstrb;
  env.ddr.io.w.wlast = env.interconnect.axi_io.w.wlast;

  env.ddr.io.r.rready = env.interconnect.axi_io.r.rready;
  env.ddr.io.b.bready = env.interconnect.axi_io.b.bready;

  env.ddr.comb_inputs();
  env.tables.seq(env.interconnect.get_llc_table_out());
  env.ddr.seq();
  env.interconnect.seq();
  ++sim_time;
}

AXI_LLCConfig make_config() {
  AXI_LLCConfig cfg;
  cfg.enable = true;
  cfg.size_bytes = 512;
  cfg.line_bytes = 64;
  cfg.ways = 2;
  cfg.mshr_num = 2;
  cfg.prefetch_enable = false;
  return cfg;
}

void init_env(TestEnv &env) {
  AXI_LLCConfig cfg = make_config();
  env.interconnect.set_llc_config(cfg);
  env.interconnect.init();
  env.ddr.init();
  env.tables.init(cfg);
  env.ar_events.clear();
}

void init_env(TestEnv &env, const AXI_LLCConfig &cfg) {
  env.interconnect.set_llc_config(cfg);
  env.interconnect.init();
  env.ddr.init();
  env.tables.init(cfg);
  env.ar_events.clear();
}

uint32_t read_mem_word(uint32_t addr) { return p_memory[addr >> 2]; }

void write_memory_line(uint32_t line_addr, uint32_t base_word) {
  for (uint32_t i = 0; i < 16; ++i) {
    p_memory[(line_addr >> 2) + i] = base_word + i;
  }
}

bool issue_read(TestEnv &env, uint8_t master, uint32_t addr, uint8_t total_size,
                uint8_t id, bool bypass) {
  int timeout = 200;
  while (timeout-- > 0) {
    cycle_outputs(env);
    const bool ready_snapshot = env.interconnect.read_ports[master].req.ready;

    auto &rp = env.interconnect.read_ports[master];
    rp.req.valid = true;
    rp.req.addr = addr;
    rp.req.total_size = total_size;
    rp.req.id = id;
    rp.req.bypass = bypass;

    cycle_inputs(env);
    if (ready_snapshot) {
      return true;
    }
  }
  return false;
}

bool issue_write(TestEnv &env, uint8_t master, uint32_t addr,
                 const WideWriteData_t &wdata, const WideWriteStrb_t &wstrb,
                 uint8_t total_size, uint8_t id, bool bypass) {
  int timeout = 200;
  while (timeout-- > 0) {
    cycle_outputs(env);
    const bool ready_snapshot = env.interconnect.write_ports[master].req.ready;

    auto &wp = env.interconnect.write_ports[master];
    wp.req.valid = true;
    wp.req.addr = addr;
    wp.req.wdata = wdata;
    wp.req.wstrb = wstrb;
    wp.req.total_size = total_size;
    wp.req.id = id;
    wp.req.bypass = bypass;

    cycle_inputs(env);
    if (ready_snapshot) {
      return true;
    }
  }
  return false;
}

bool wait_read_resp(TestEnv &env, uint8_t master, uint8_t id, uint32_t exp_word0,
                    uint32_t exp_word1) {
  int timeout = sim_ddr::SIM_DDR_LATENCY * 80;
  while (timeout-- > 0) {
    cycle_outputs(env);
    auto &resp = env.interconnect.read_ports[master].resp;
    if (resp.valid) {
      if (resp.id != id || resp.data[0] != exp_word0 || resp.data[1] != exp_word1) {
        std::printf("FAIL: read resp mismatch id=%u d0=0x%x d1=0x%x\n", resp.id,
                    resp.data[0], resp.data[1]);
        return false;
      }
      resp.ready = true;
      cycle_inputs(env);
      return true;
    }
    cycle_inputs(env);
  }
  std::printf("FAIL: read resp timeout master=%u id=%u\n", master, id);
  return false;
}

bool wait_write_resp(TestEnv &env, uint8_t master, uint8_t id) {
  int timeout = sim_ddr::SIM_DDR_LATENCY * 80;
  while (timeout-- > 0) {
    cycle_outputs(env);
    auto &resp = env.interconnect.write_ports[master].resp;
    if (resp.valid) {
      if (resp.id != id || resp.resp != sim_ddr::AXI_RESP_OKAY) {
        std::printf("FAIL: write resp mismatch id=%u resp=%u\n", resp.id,
                    resp.resp);
        return false;
      }
      resp.ready = true;
      cycle_inputs(env);
      return true;
    }
    cycle_inputs(env);
  }
  std::printf("FAIL: write resp timeout master=%u id=%u\n", master, id);
  env.interconnect.debug_print();
  return false;
}

bool test_cross_master_write_then_read_latest() {
  std::printf("=== AXI4 LLC Integration Test 1: cross-master latest value ===\n");

  TestEnv env;
  init_env(env);

  const uint32_t line_addr = 0x1800;
  const uint32_t read_addr = line_addr + 8;
  write_memory_line(line_addr, 0x1100);

  WideWriteData_t wdata;
  wdata.clear();
  for (uint32_t i = 0; i < 16; ++i) {
    wdata[i] = 0x2200 + i;
  }
  WideWriteStrb_t wstrb;
  wstrb.clear();
  for (uint32_t i = 0; i < 64; ++i) {
    wstrb.set(i, true);
  }

  if (!issue_write(env, MASTER_DCACHE_W, line_addr, wdata, wstrb, 63, 3, false)) {
    std::printf("FAIL: cacheable write not accepted\n");
    return false;
  }
  if (!wait_write_resp(env, MASTER_DCACHE_W, 3)) {
    return false;
  }

  env.ar_events.clear();
  if (!issue_read(env, MASTER_ICACHE, read_addr, 15, 4, false)) {
    std::printf("FAIL: post-write cacheable read not accepted\n");
    return false;
  }
  if (!wait_read_resp(env, MASTER_ICACHE, 4, 0x2202, 0x2203)) {
    return false;
  }
  if (!env.ar_events.empty()) {
    std::printf("FAIL: post-write cacheable read unexpectedly missed LLC ar_count=%zu\n",
                env.ar_events.size());
    return false;
  }
  if (env.interconnect.get_llc_perf_counters().read_hit == 0) {
    std::printf("FAIL: LLC did not record read hit after cacheable write\n");
    return false;
  }

  std::printf("PASS\n");
  return true;
}

bool test_bypass_read_does_not_allocate_line() {
  std::printf("=== AXI4 LLC Integration Test 2: bypass read does not allocate ===\n");

  TestEnv env;
  init_env(env);

  const uint32_t line_addr = 0x1c00;
  const uint32_t read_addr = line_addr + 4;
  write_memory_line(line_addr, 0x3300);

  if (!issue_read(env, MASTER_UNCORE_LSU_R, read_addr, 15, 5, true)) {
    std::printf("FAIL: bypass read not accepted\n");
    return false;
  }
  if (!wait_read_resp(env, MASTER_UNCORE_LSU_R, 5, 0x3301, 0x3302)) {
    return false;
  }
  if (env.ar_events.size() != 1) {
    std::printf("FAIL: bypass read expected one DDR AR, got %zu\n",
                env.ar_events.size());
    return false;
  }

  env.ar_events.clear();
  if (!issue_read(env, MASTER_ICACHE, read_addr, 15, 6, false)) {
    std::printf("FAIL: first cacheable read not accepted\n");
    return false;
  }
  if (!wait_read_resp(env, MASTER_ICACHE, 6, 0x3301, 0x3302)) {
    return false;
  }
  if (env.ar_events.size() != 1) {
    std::printf("FAIL: first cacheable read should miss LLC once, got ar_count=%zu\n",
                env.ar_events.size());
    return false;
  }

  env.ar_events.clear();
  if (!issue_read(env, MASTER_DCACHE_R, read_addr, 15, 7, false)) {
    std::printf("FAIL: second cacheable read not accepted\n");
    return false;
  }
  if (!wait_read_resp(env, MASTER_DCACHE_R, 7, 0x3301, 0x3302)) {
    return false;
  }
  if (!env.ar_events.empty()) {
    std::printf("FAIL: second cacheable read should hit LLC without DDR AR, got %zu\n",
                env.ar_events.size());
    return false;
  }

  const auto &perf = env.interconnect.get_llc_perf_counters();
  if (perf.bypass_read == 0 || perf.read_miss == 0 || perf.read_hit == 0) {
    std::printf("FAIL: LLC perf counters unexpected bypass=%llu miss=%llu hit=%llu\n",
                static_cast<unsigned long long>(perf.bypass_read),
                static_cast<unsigned long long>(perf.read_miss),
                static_cast<unsigned long long>(perf.read_hit));
    return false;
  }

  std::printf("PASS\n");
  return true;
}

bool test_cacheable_and_bypass_parallel_disjoint() {
  std::printf("=== AXI4 LLC Integration Test 3: cacheable+bypass coexist ===\n");

  TestEnv env;
  init_env(env);

  const uint32_t bypass_line = 0x2400;
  const uint32_t cache_line = 0x2480;
  const uint32_t bypass_addr = bypass_line + 4;
  const uint32_t cache_addr = cache_line + 8;
  write_memory_line(bypass_line, 0x4400);
  write_memory_line(cache_line, 0x5500);

  bool bypass_issued = false;
  bool cache_issued = false;
  int timeout = 200;
  while ((!bypass_issued || !cache_issued) && timeout-- > 0) {
    cycle_outputs(env);
    const bool bypass_ready =
        env.interconnect.read_ports[MASTER_UNCORE_LSU_R].req.ready;
    const bool cache_ready =
        env.interconnect.read_ports[MASTER_ICACHE].req.ready;

    if (!bypass_issued) {
      auto &rp = env.interconnect.read_ports[MASTER_UNCORE_LSU_R];
      rp.req.valid = true;
      rp.req.addr = bypass_addr;
      rp.req.total_size = 15;
      rp.req.id = 8;
      rp.req.bypass = true;
    }
    if (!cache_issued) {
      auto &rp = env.interconnect.read_ports[MASTER_ICACHE];
      rp.req.valid = true;
      rp.req.addr = cache_addr;
      rp.req.total_size = 15;
      rp.req.id = 9;
      rp.req.bypass = false;
    }

    cycle_inputs(env);
    bypass_issued = bypass_issued || bypass_ready;
    cache_issued = cache_issued || cache_ready;
  }
  if (!bypass_issued || !cache_issued) {
    std::printf("FAIL: parallel cacheable+bypass issue timeout bypass=%d cache=%d\n",
                static_cast<int>(bypass_issued), static_cast<int>(cache_issued));
    return false;
  }

  bool bypass_done = false;
  bool cache_done = false;
  timeout = sim_ddr::SIM_DDR_LATENCY * 100;
  while ((!bypass_done || !cache_done) && timeout-- > 0) {
    cycle_outputs(env);
    auto &bypass_resp = env.interconnect.read_ports[MASTER_UNCORE_LSU_R].resp;
    if (!bypass_done && bypass_resp.valid) {
      if (bypass_resp.id != 8 || bypass_resp.data[0] != 0x4401 ||
          bypass_resp.data[1] != 0x4402) {
        std::printf("FAIL: bypass parallel resp mismatch id=%u d0=0x%x d1=0x%x\n",
                    bypass_resp.id, bypass_resp.data[0], bypass_resp.data[1]);
        return false;
      }
      bypass_resp.ready = true;
      bypass_done = true;
    }
    auto &cache_resp = env.interconnect.read_ports[MASTER_ICACHE].resp;
    if (!cache_done && cache_resp.valid) {
      if (cache_resp.id != 9 || cache_resp.data[0] != 0x5502 ||
          cache_resp.data[1] != 0x5503) {
        std::printf("FAIL: cacheable parallel resp mismatch id=%u d0=0x%x d1=0x%x\n",
                    cache_resp.id, cache_resp.data[0], cache_resp.data[1]);
        return false;
      }
      cache_resp.ready = true;
      cache_done = true;
    }
    cycle_inputs(env);
  }
  if (!bypass_done || !cache_done) {
    std::printf("FAIL: parallel response timeout bypass=%d cache=%d\n",
                static_cast<int>(bypass_done), static_cast<int>(cache_done));
    return false;
  }

  if (env.ar_events.size() != 2) {
    std::printf("FAIL: expected two DDR ARs for bypass+cacheable miss, got %zu\n",
                env.ar_events.size());
    return false;
  }

  env.ar_events.clear();
  if (!issue_read(env, MASTER_DCACHE_R, cache_addr, 15, 10, false)) {
    std::printf("FAIL: cacheable follow-up read not accepted\n");
    return false;
  }
  if (!wait_read_resp(env, MASTER_DCACHE_R, 10, 0x5502, 0x5503)) {
    return false;
  }
  if (!env.ar_events.empty()) {
    std::printf("FAIL: cacheable follow-up read should hit LLC, got ar_count=%zu\n",
                env.ar_events.size());
    return false;
  }

  const auto &perf = env.interconnect.get_llc_perf_counters();
  if (perf.bypass_read == 0 || perf.read_miss == 0 || perf.read_hit == 0) {
    std::printf("FAIL: coexist perf counters unexpected bypass=%llu miss=%llu hit=%llu\n",
                static_cast<unsigned long long>(perf.bypass_read),
                static_cast<unsigned long long>(perf.read_miss),
                static_cast<unsigned long long>(perf.read_hit));
    return false;
  }

  std::printf("PASS\n");
  return true;
}

bool test_same_set_eviction_roundtrip_latest() {
  std::printf("=== AXI4 LLC Integration Test 4: same-set eviction preserves latest ===\n");

  TestEnv env;
  AXI_LLCConfig cfg = make_config();
  cfg.size_bytes = 256;
  cfg.line_bytes = 64;
  cfg.ways = 2;
  cfg.mshr_num = 2;
  init_env(env, cfg);

  const uint32_t line_a = 0x000;
  const uint32_t line_b = 0x080;
  const uint32_t line_c = 0x100;
  const uint32_t read_a = line_a + 8;
  const uint32_t read_b = line_b + 8;
  const uint32_t read_c = line_c + 8;
  write_memory_line(line_a, 0x1000);
  write_memory_line(line_b, 0x2000);
  write_memory_line(line_c, 0x3000);

  auto make_line = [](uint32_t base_word) {
    WideWriteData_t wdata;
    wdata.clear();
    for (uint32_t i = 0; i < 16; ++i) {
      wdata[i] = base_word + i;
    }
    return wdata;
  };

  WideWriteStrb_t full_strobe;
  full_strobe.clear();
  for (uint32_t i = 0; i < 64; ++i) {
    full_strobe.set(i, true);
  }

  if (!issue_write(env, MASTER_DCACHE_W, line_a, make_line(0xA000), full_strobe, 63, 1,
                   false) ||
      !wait_write_resp(env, MASTER_DCACHE_W, 1)) {
    std::printf("FAIL: write line A failed\n");
    return false;
  }
  if (!issue_write(env, MASTER_DCACHE_W, line_b, make_line(0xB000), full_strobe, 63, 2,
                   false) ||
      !wait_write_resp(env, MASTER_DCACHE_W, 2)) {
    std::printf("FAIL: write line B failed\n");
    return false;
  }

  env.ar_events.clear();
  if (!issue_read(env, MASTER_ICACHE, read_c, 15, 3, false) ||
      !wait_read_resp(env, MASTER_ICACHE, 3, 0x3002, 0x3003)) {
    std::printf("FAIL: read line C failed\n");
    return false;
  }
  if (env.ar_events.size() != 1) {
    std::printf("FAIL: line C should issue exactly one DDR AR, got %zu\n",
                env.ar_events.size());
    return false;
  }

  env.ar_events.clear();
  if (!issue_read(env, MASTER_DCACHE_R, read_a, 15, 4, false) ||
      !wait_read_resp(env, MASTER_DCACHE_R, 4, 0xA002, 0xA003)) {
    std::printf("FAIL: roundtrip read line A failed\n");
    return false;
  }
  if (read_mem_word(read_a) != 0xA002) {
    std::printf("FAIL: line A latest value did not reach memory got=0x%08x\n",
                read_mem_word(read_a));
    return false;
  }

  env.ar_events.clear();
  if (!issue_read(env, MASTER_ICACHE, read_b, 15, 5, false) ||
      !wait_read_resp(env, MASTER_ICACHE, 5, 0xB002, 0xB003)) {
    std::printf("FAIL: roundtrip read line B failed\n");
    return false;
  }
  if (read_mem_word(read_b) != 0xB002) {
    std::printf("FAIL: line B latest value did not reach memory got=0x%08x\n",
                read_mem_word(read_b));
    return false;
  }

  std::printf("PASS\n");
  return true;
}

bool test_bypass_read_sees_latest_after_cacheable_write() {
  std::printf("=== AXI4 LLC Integration Test 5: bypass read sees latest after cacheable write ===\n");

  TestEnv env;
  init_env(env);

  const uint32_t line = 0x40;
  const uint32_t addr = line + 0x10;
  write_memory_line(line, 0x6400);

  WideWriteData_t wdata;
  wdata.clear();
  for (uint32_t i = 0; i < 16; ++i) {
    wdata[i] = 0x7700 + i;
  }
  WideWriteStrb_t wstrb;
  wstrb.clear();
  for (uint32_t i = 0; i < 64; ++i) {
    wstrb.set(i, true);
  }

  if (!issue_write(env, MASTER_DCACHE_W, line, wdata, wstrb, 63, 0x21, false) ||
      !wait_write_resp(env, MASTER_DCACHE_W, 0x21)) {
    std::printf("FAIL: cacheable write before bypass read failed\n");
    return false;
  }

  if (!issue_read(env, MASTER_UNCORE_LSU_R, addr, 15, 0x22, true) ||
      !wait_read_resp(env, MASTER_UNCORE_LSU_R, 0x22, 0x7704, 0x7705)) {
    std::printf("FAIL: bypass read did not see latest line contents\n");
    return false;
  }

  std::printf("PASS\n");
  return true;
}

bool test_bypass_write_hit_updates_resident_line() {
  std::printf("=== AXI4 LLC Integration Test 6: bypass write hit updates resident line ===\n");

  TestEnv env;
  init_env(env);

  const uint32_t line = 0x400;
  const uint32_t addr = line + 0x10;
  const uint32_t write_value = 0x8A04DEAD;
  write_memory_line(line, 0x8100);

  if (!issue_read(env, MASTER_ICACHE, addr, 15, 0x31, false) ||
      !wait_read_resp(env, MASTER_ICACHE, 0x31, 0x8104, 0x8105)) {
    std::printf("FAIL: resident-line priming read failed\n");
    return false;
  }

  WideWriteData_t wdata;
  wdata.clear();
  wdata[0] = write_value;
  WideWriteStrb_t wstrb;
  wstrb.clear();
  for (uint32_t i = 0; i < 4; ++i) {
    wstrb.set(i, true);
  }

  if (!issue_write(env, MASTER_UNCORE_LSU_W, addr, wdata, wstrb, 3, 0x32, true) ||
      !wait_write_resp(env, MASTER_UNCORE_LSU_W, 0x32)) {
    std::printf("FAIL: bypass write-hit request failed\n");
    return false;
  }
  if (read_mem_word(addr) != write_value) {
    std::printf("FAIL: bypass write-hit did not update memory got=0x%08x\n",
                read_mem_word(addr));
    return false;
  }

  env.ar_events.clear();
  if (!issue_read(env, MASTER_DCACHE_R, addr, 15, 0x33, false) ||
      !wait_read_resp(env, MASTER_DCACHE_R, 0x33, write_value, 0x8105)) {
    std::printf("FAIL: cacheable read after bypass write-hit failed\n");
    return false;
  }
  if (!env.ar_events.empty()) {
    std::printf("FAIL: cacheable read after bypass write-hit should not issue DDR AR, got %zu\n",
                env.ar_events.size());
    return false;
  }

  std::printf("PASS\n");
  return true;
}

bool test_bypass_write_miss_does_not_allocate_line() {
  std::printf("=== AXI4 LLC Integration Test 7: bypass write miss does not allocate ===\n");

  TestEnv env;
  init_env(env);

  const uint32_t line = 0x480;
  const uint32_t addr = line + 0x10;
  const uint32_t write_value = 0x9B04BEEF;
  write_memory_line(line, 0x9100);

  WideWriteData_t wdata;
  wdata.clear();
  wdata[0] = write_value;
  WideWriteStrb_t wstrb;
  wstrb.clear();
  for (uint32_t i = 0; i < 4; ++i) {
    wstrb.set(i, true);
  }

  if (!issue_write(env, MASTER_UNCORE_LSU_W, addr, wdata, wstrb, 3, 0x34, true) ||
      !wait_write_resp(env, MASTER_UNCORE_LSU_W, 0x34)) {
    std::printf("FAIL: bypass write-miss request failed\n");
    return false;
  }
  if (read_mem_word(addr) != write_value) {
    std::printf("FAIL: bypass write-miss did not update memory got=0x%08x\n",
                read_mem_word(addr));
    return false;
  }

  env.ar_events.clear();
  if (!issue_read(env, MASTER_ICACHE, addr, 15, 0x35, false) ||
      !wait_read_resp(env, MASTER_ICACHE, 0x35, write_value, 0x9105)) {
    std::printf("FAIL: cacheable read after bypass write-miss failed\n");
    return false;
  }
  if (env.ar_events.size() != 1) {
    std::printf("FAIL: cacheable read after bypass write-miss should issue one DDR AR, got %zu\n",
                env.ar_events.size());
    return false;
  }

  std::printf("PASS\n");
  return true;
}

bool test_bypass_write_miss_preserves_same_set_residents() {
  std::printf("=== AXI4 LLC Integration Test 8: bypass write miss preserves same-set residents ===\n");

  TestEnv env;
  AXI_LLCConfig cfg = make_config();
  cfg.size_bytes = 512;
  cfg.line_bytes = 64;
  cfg.ways = 2;
  cfg.mshr_num = 2;
  init_env(env, cfg);

  const uint32_t line_a = 0x000;
  const uint32_t line_b = 0x100;
  const uint32_t line_c = 0x200;
  const uint32_t addr_a = line_a + 0x10;
  const uint32_t addr_b = line_b + 0x10;
  const uint32_t addr_c = line_c + 0x10;
  const uint32_t write_value = 0xCAFE0004;
  write_memory_line(line_a, 0xA100);
  write_memory_line(line_b, 0xB100);
  write_memory_line(line_c, 0xC100);

  if (!issue_read(env, MASTER_ICACHE, addr_a, 15, 0x41, false) ||
      !wait_read_resp(env, MASTER_ICACHE, 0x41, 0xA104, 0xA105)) {
    std::printf("FAIL: fill line A failed\n");
    return false;
  }
  if (!issue_read(env, MASTER_DCACHE_R, addr_b, 15, 0x42, false) ||
      !wait_read_resp(env, MASTER_DCACHE_R, 0x42, 0xB104, 0xB105)) {
    std::printf("FAIL: fill line B failed\n");
    return false;
  }

  WideWriteData_t wdata;
  wdata.clear();
  wdata[0] = write_value;
  WideWriteStrb_t wstrb;
  wstrb.clear();
  for (uint32_t i = 0; i < 4; ++i) {
    wstrb.set(i, true);
  }
  if (!issue_write(env, MASTER_UNCORE_LSU_W, addr_c, wdata, wstrb, 3, 0x43, true) ||
      !wait_write_resp(env, MASTER_UNCORE_LSU_W, 0x43)) {
    std::printf("FAIL: bypass write miss failed\n");
    return false;
  }
  if (read_mem_word(addr_c) != write_value) {
    std::printf("FAIL: bypass write miss did not update backing memory got=0x%08x\n",
                read_mem_word(addr_c));
    return false;
  }

  env.ar_events.clear();
  if (!issue_read(env, MASTER_ICACHE, addr_a, 15, 0x44, false) ||
      !wait_read_resp(env, MASTER_ICACHE, 0x44, 0xA104, 0xA105)) {
    std::printf("FAIL: resident line A lost after bypass miss\n");
    return false;
  }
  if (!issue_read(env, MASTER_DCACHE_R, addr_b, 15, 0x45, false) ||
      !wait_read_resp(env, MASTER_DCACHE_R, 0x45, 0xB104, 0xB105)) {
    std::printf("FAIL: resident line B lost after bypass miss\n");
    return false;
  }
  if (!env.ar_events.empty()) {
    std::printf("FAIL: resident lines should remain in LLC after bypass miss, got %zu ARs\n",
                env.ar_events.size());
    return false;
  }

  env.ar_events.clear();
  if (!issue_read(env, MASTER_DCACHE_R, addr_c, 15, 0x46, false) ||
      !wait_read_resp(env, MASTER_DCACHE_R, 0x46, write_value, 0xC105)) {
    std::printf("FAIL: cacheable read of bypass-miss line failed\n");
    return false;
  }
  if (env.ar_events.size() != 1) {
    std::printf("FAIL: bypass-miss line should still require one DDR AR, got %zu\n",
                env.ar_events.size());
    return false;
  }

  std::printf("PASS\n");
  return true;
}

bool test_seeded_small_depth_stress() {
  std::printf("=== AXI4 LLC Integration Test 9: seeded small-depth stress ===\n");

  TestEnv env;
  AXI_LLCConfig cfg = make_config();
  cfg.size_bytes = 256;
  cfg.line_bytes = 64;
  cfg.ways = 2;
  cfg.mshr_num = 2;
  init_env(env, cfg);

  const std::vector<uint32_t> lines = {0x000, 0x080, 0x100, 0x180, 0x040, 0x0C0};
  std::unordered_map<uint32_t, std::vector<uint32_t>> shadow;
  for (size_t idx = 0; idx < lines.size(); ++idx) {
    const uint32_t base = 0x6000 + static_cast<uint32_t>(idx) * 0x100;
    write_memory_line(lines[idx], base);
    shadow[lines[idx]].resize(16);
    for (uint32_t word = 0; word < 16; ++word) {
      shadow[lines[idx]][word] = base + word;
    }
  }

  WideWriteStrb_t full_strobe;
  full_strobe.clear();
  for (uint32_t i = 0; i < 64; ++i) {
    full_strobe.set(i, true);
  }

  std::mt19937 rng(0xC0DEC0DEu);
  for (uint32_t step = 0; step < 60; ++step) {
    const uint32_t line = lines[rng() % lines.size()];
    const uint32_t word_idx = static_cast<uint32_t>(rng() % 14);
    const uint32_t addr = line + word_idx * 4;
    const uint32_t op = rng() % 4;

    if (op == 0 || op == 1) {
      const uint8_t master = (op == 0) ? MASTER_ICACHE : MASTER_DCACHE_R;
      const uint8_t id = static_cast<uint8_t>((step & 0xF) + 1);
      if (!issue_read(env, master, addr, 15, id, false)) {
        std::printf("FAIL: stress cacheable read issue failed step=%u master=%u addr=0x%x\n",
                    step, master, addr);
        return false;
      }
      if (!wait_read_resp(env, master, id, shadow[line][word_idx],
                          shadow[line][word_idx + 1])) {
        std::printf("FAIL: stress cacheable read resp failed step=%u addr=0x%x\n",
                    step, addr);
        return false;
      }
    } else if (op == 2) {
      const uint8_t id = static_cast<uint8_t>((step & 0xF) + 1);
      if (!issue_read(env, MASTER_UNCORE_LSU_R, addr, 15, id, true)) {
        std::printf("FAIL: stress bypass read issue failed step=%u addr=0x%x\n",
                    step, addr);
        return false;
      }
      if (!wait_read_resp(env, MASTER_UNCORE_LSU_R, id, shadow[line][word_idx],
                          shadow[line][word_idx + 1])) {
        std::printf("FAIL: stress bypass read resp failed step=%u addr=0x%x\n",
                    step, addr);
        return false;
      }
    } else {
      const uint32_t base = 0x90000000u + step * 0x100u;
      WideWriteData_t wdata;
      wdata.clear();
      for (uint32_t word = 0; word < 16; ++word) {
        const uint32_t value = base + word;
        wdata[word] = value;
        shadow[line][word] = value;
      }
      const uint8_t id = static_cast<uint8_t>((step & 0xF) + 1);
      if (!issue_write(env, MASTER_DCACHE_W, line, wdata, full_strobe, 63, id, false)) {
        std::printf("FAIL: stress cacheable write issue failed step=%u line=0x%x\n",
                    step, line);
        return false;
      }
      if (!wait_write_resp(env, MASTER_DCACHE_W, id)) {
        std::printf("FAIL: stress cacheable write resp failed step=%u line=0x%x\n",
                    step, line);
        return false;
      }
    }
  }

  uint8_t final_id = 0x40;
  for (uint32_t line : lines) {
    if (!issue_read(env, MASTER_DCACHE_R, line, 15, final_id, false)) {
      std::printf("FAIL: final sweep read issue failed line=0x%x id=%u\n", line,
                  final_id);
      return false;
    }
    if (!wait_read_resp(env, MASTER_DCACHE_R, final_id, shadow[line][0],
                        shadow[line][1])) {
      std::printf("FAIL: final sweep read resp failed line=0x%x id=%u\n", line,
                  final_id);
      return false;
    }
    ++final_id;
  }

  const auto &perf = env.interconnect.get_llc_perf_counters();
  if (perf.read_access == 0 || perf.read_miss == 0 || perf.read_hit == 0 ||
      perf.bypass_read == 0) {
    std::printf("FAIL: seeded stress perf coverage too weak access=%llu miss=%llu hit=%llu bypass=%llu\n",
                static_cast<unsigned long long>(perf.read_access),
                static_cast<unsigned long long>(perf.read_miss),
                static_cast<unsigned long long>(perf.read_hit),
                static_cast<unsigned long long>(perf.bypass_read));
    return false;
  }

  std::printf("PASS\n");
  return true;
}

bool test_llc_same_master_multi_write_accepts_before_first_resp() {
  std::printf("=== AXI4 LLC Integration Test 10: LLC path queues same-master writes ===\n");

  TestEnv env;
  init_env(env);

  const uint32_t line0 = 0xA000;
  const uint32_t line1 = 0xA040;
  write_memory_line(line0, 0x1000);
  write_memory_line(line1, 0x2000);

  auto make_line = [](uint32_t base_word) {
    WideWriteData_t wdata;
    wdata.clear();
    for (uint32_t i = 0; i < 16; ++i) {
      wdata[i] = base_word + i;
    }
    return wdata;
  };
  WideWriteData_t wdata0 = make_line(0x3300);
  WideWriteData_t wdata1 = make_line(0x4400);
  WideWriteStrb_t full_strobe;
  full_strobe.clear();
  for (uint32_t i = 0; i < 64; ++i) {
    full_strobe.set(i, true);
  }

  bool first_issued = false;
  int timeout = 200;
  while (!first_issued && timeout-- > 0) {
    cycle_outputs(env);
    const bool ready_snapshot = env.interconnect.write_ports[MASTER_DCACHE_W].req.ready;
    auto &req = env.interconnect.write_ports[MASTER_DCACHE_W].req;
    req.valid = true;
    req.addr = line0;
    req.wdata = wdata0;
    req.wstrb = full_strobe;
    req.total_size = 63;
    req.id = 0x51;
    req.bypass = false;
    cycle_inputs(env);
    if (ready_snapshot) {
      first_issued = true;
    }
  }
  if (!first_issued) {
    std::printf("FAIL: first LLC write was not accepted\n");
    return false;
  }

  bool second_issued = false;
  timeout = 200;
  while (!second_issued && timeout-- > 0) {
    cycle_outputs(env);
    if (env.interconnect.write_ports[MASTER_DCACHE_W].resp.valid) {
      std::printf("FAIL: first LLC write response became visible before second issue\n");
      return false;
    }
    const bool ready_snapshot = env.interconnect.write_ports[MASTER_DCACHE_W].req.ready;
    auto &req = env.interconnect.write_ports[MASTER_DCACHE_W].req;
    req.valid = true;
    req.addr = line1;
    req.wdata = wdata1;
    req.wstrb = full_strobe;
    req.total_size = 63;
    req.id = 0x52;
    req.bypass = false;
    cycle_inputs(env);
    if (ready_snapshot) {
      second_issued = true;
    }
  }
  if (!second_issued) {
    std::printf("FAIL: second LLC write was not accepted before first response\n");
    return false;
  }

  if (!wait_write_resp(env, MASTER_DCACHE_W, 0x51) ||
      !wait_write_resp(env, MASTER_DCACHE_W, 0x52)) {
    std::printf("FAIL: LLC queued write responses did not complete\n");
    return false;
  }

  if (!issue_read(env, MASTER_DCACHE_R, line0, 15, 0x61, false) ||
      !wait_read_resp(env, MASTER_DCACHE_R, 0x61, 0x3300, 0x3301)) {
    std::printf("FAIL: LLC queued first write not visible to readback\n");
    return false;
  }
  if (!issue_read(env, MASTER_DCACHE_R, line1, 15, 0x62, false) ||
      !wait_read_resp(env, MASTER_DCACHE_R, 0x62, 0x4400, 0x4401)) {
    std::printf("FAIL: LLC queued second write not visible to readback\n");
    return false;
  }

  std::printf("PASS\n");
  return true;
}

} // namespace

int main() {
  p_memory = new uint32_t[TEST_MEM_SIZE_WORDS];
  std::memset(p_memory, 0, TEST_MEM_SIZE_WORDS * sizeof(uint32_t));

  int passed = 0;
  int failed = 0;

  if (test_cross_master_write_then_read_latest()) {
    passed++;
  } else {
    failed++;
  }

  if (test_bypass_read_does_not_allocate_line()) {
    passed++;
  } else {
    failed++;
  }

  if (test_cacheable_and_bypass_parallel_disjoint()) {
    passed++;
  } else {
    failed++;
  }

  if (test_same_set_eviction_roundtrip_latest()) {
    passed++;
  } else {
    failed++;
  }

  if (test_bypass_read_sees_latest_after_cacheable_write()) {
    passed++;
  } else {
    failed++;
  }

  if (test_bypass_write_hit_updates_resident_line()) {
    passed++;
  } else {
    failed++;
  }

  if (test_bypass_write_miss_does_not_allocate_line()) {
    passed++;
  } else {
    failed++;
  }

  if (test_bypass_write_miss_preserves_same_set_residents()) {
    passed++;
  } else {
    failed++;
  }

  if (test_seeded_small_depth_stress()) {
    passed++;
  } else {
    failed++;
  }

  if (test_llc_same_master_multi_write_accepts_before_first_resp()) {
    passed++;
  } else {
    failed++;
  }

  std::printf("AXI4 LLC integration results: %d passed, %d failed\n", passed, failed);
  delete[] p_memory;
  return failed == 0 ? 0 : 1;
}
