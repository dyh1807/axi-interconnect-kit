#include <cstdio>
#include <cstring>
#include <vector>

#include "AXI_Interconnect.h"
#include "AXI_Interconnect_AXI3.h"
#include "SimDDR.h"
#include "SimDDR_AXI3.h"

uint32_t *p_memory = nullptr;
long long sim_time = 0;
constexpr uint32_t TEST_MEM_SIZE_WORDS = 0x100000;

namespace {

using namespace axi_interconnect;

struct ReadResult {
  uint8_t master = 0;
  uint8_t id = 0;
  WideReadData_t data{};
};

struct WriteResult {
  uint8_t master = 0;
  uint8_t id = 0;
  uint8_t resp = 0;
};

struct ScriptResult {
  std::vector<ReadResult> reads{};
  std::vector<WriteResult> writes{};
  std::vector<uint32_t> mem_words{};
};

void init_memory_image(std::vector<uint32_t> &image) {
  image.resize(TEST_MEM_SIZE_WORDS);
  for (uint32_t i = 0; i < TEST_MEM_SIZE_WORDS; ++i) {
    image[i] = (i * 0x9E3779B9u) ^ 0xA5A50000u;
  }
}

void load_memory_image(const std::vector<uint32_t> &image) {
  std::memcpy(p_memory, image.data(), image.size() * sizeof(uint32_t));
}

void snapshot_words(ScriptResult &result, uint32_t base_addr, uint32_t words) {
  result.mem_words.clear();
  for (uint32_t i = 0; i < words; ++i) {
    result.mem_words.push_back(p_memory[(base_addr >> 2) + i]);
  }
}

void fill_line32(WideWriteData_t &wdata, WideWriteStrb_t &wstrb, uint32_t base_word) {
  wdata.clear();
  wstrb.clear();
  for (uint32_t i = 0; i < CACHELINE_WORDS; ++i) {
    wdata[i] = base_word + i;
  }
  for (uint32_t i = 0; i < 32; ++i) {
    wstrb.set(i, true);
  }
}

struct Axi4Env {
  AXI_Interconnect interconnect;
  sim_ddr::SimDDR ddr;
};

void clear_upstream_inputs(Axi4Env &env) {
  for (int i = 0; i < NUM_READ_MASTERS; ++i) {
    env.interconnect.read_ports[i].req.valid = false;
    env.interconnect.read_ports[i].req.addr = 0;
    env.interconnect.read_ports[i].req.total_size = 0;
    env.interconnect.read_ports[i].req.id = 0;
    env.interconnect.read_ports[i].req.bypass = false;
    env.interconnect.read_ports[i].resp.ready = false;
  }
  for (int i = 0; i < NUM_WRITE_MASTERS; ++i) {
    env.interconnect.write_ports[i].req.valid = false;
    env.interconnect.write_ports[i].req.addr = 0;
    env.interconnect.write_ports[i].req.total_size = 0;
    env.interconnect.write_ports[i].req.id = 0;
    env.interconnect.write_ports[i].req.bypass = false;
    env.interconnect.write_ports[i].req.wdata.clear();
    env.interconnect.write_ports[i].req.wstrb.clear();
    env.interconnect.write_ports[i].resp.ready = false;
  }
}

void cycle_outputs(Axi4Env &env) {
  clear_upstream_inputs(env);
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

void cycle_inputs(Axi4Env &env) {
  env.interconnect.comb_inputs();
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
  env.ddr.seq();
  env.interconnect.seq();
  ++sim_time;
}

bool issue_read(Axi4Env &env, uint8_t master, uint32_t addr, uint8_t total_size,
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

bool wait_read(Axi4Env &env, uint8_t master, uint8_t id, ReadResult &out) {
  int timeout = sim_ddr::SIM_DDR_LATENCY * 80;
  while (timeout-- > 0) {
    cycle_outputs(env);
    auto &resp = env.interconnect.read_ports[master].resp;
    if (resp.valid) {
      if (resp.id != id) {
        return false;
      }
      out.master = master;
      out.id = id;
      out.data = resp.data;
      resp.ready = true;
      cycle_inputs(env);
      return true;
    }
    cycle_inputs(env);
  }
  return false;
}

bool issue_write(Axi4Env &env, uint8_t master, uint32_t addr,
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

bool wait_write(Axi4Env &env, uint8_t master, uint8_t id, WriteResult &out) {
  int timeout = sim_ddr::SIM_DDR_LATENCY * 80;
  while (timeout-- > 0) {
    cycle_outputs(env);
    auto &resp = env.interconnect.write_ports[master].resp;
    if (resp.valid) {
      if (resp.id != id) {
        return false;
      }
      out.master = master;
      out.id = id;
      out.resp = resp.resp;
      resp.ready = true;
      cycle_inputs(env);
      return true;
    }
    cycle_inputs(env);
  }
  return false;
}

ScriptResult run_axi4_script(const std::vector<uint32_t> &image) {
  load_memory_image(image);
  sim_time = 0;
  Axi4Env env;
  env.interconnect.init();
  env.ddr.init();

  ScriptResult result;
  WideWriteData_t wdata;
  WideWriteStrb_t wstrb;

  issue_read(env, MASTER_ICACHE, 0x1000, 31, 1, false);
  ReadResult r0;
  wait_read(env, MASTER_ICACHE, 1, r0);
  result.reads.push_back(r0);

  wdata.clear();
  wstrb.clear();
  wdata[0] = 0xDEADBEEF;
  for (uint32_t i = 0; i < 4; ++i) {
    wstrb.set(i, true);
  }
  issue_write(env, MASTER_DCACHE_W, 0x1104, wdata, wstrb, 3, 2, false);
  WriteResult w0;
  wait_write(env, MASTER_DCACHE_W, 2, w0);
  result.writes.push_back(w0);

  issue_read(env, MASTER_DCACHE_R, 0x1100, 7, 3, false);
  ReadResult r1;
  wait_read(env, MASTER_DCACHE_R, 3, r1);
  result.reads.push_back(r1);

  issue_read(env, MASTER_UNCORE_LSU_R, 0x1208, 15, 4, true);
  ReadResult r2;
  wait_read(env, MASTER_UNCORE_LSU_R, 4, r2);
  result.reads.push_back(r2);

  fill_line32(wdata, wstrb, 0x6600);
  if (!issue_write(env, MASTER_DCACHE_W, 0x1300, wdata, wstrb, 31, 5, false)) {
    std::printf("AXI4 issue_write failed for second write\n");
    return result;
  }
  WriteResult w1;
  if (!wait_write(env, MASTER_DCACHE_W, 5, w1)) {
    std::printf("AXI4 wait_write failed for second write\n");
    return result;
  }
  result.writes.push_back(w1);

  issue_read(env, MASTER_EXTRA_R, 0x1300, 31, 6, false);
  ReadResult r3;
  wait_read(env, MASTER_EXTRA_R, 6, r3);
  result.reads.push_back(r3);

  snapshot_words(result, 0x1100, 20);
  return result;
}

struct Axi3Env {
  AXI_Interconnect_AXI3 interconnect;
  sim_ddr_axi3::SimDDR_AXI3 ddr;
};

void clear_upstream_inputs(Axi3Env &env) {
  for (int i = 0; i < NUM_READ_MASTERS; ++i) {
    env.interconnect.read_ports[i].req.valid = false;
    env.interconnect.read_ports[i].req.addr = 0;
    env.interconnect.read_ports[i].req.total_size = 0;
    env.interconnect.read_ports[i].req.id = 0;
    env.interconnect.read_ports[i].resp.ready = false;
  }
  for (int i = 0; i < NUM_WRITE_MASTERS; ++i) {
    env.interconnect.write_ports[i].req.valid = false;
    env.interconnect.write_ports[i].req.addr = 0;
    env.interconnect.write_ports[i].req.total_size = 0;
    env.interconnect.write_ports[i].req.id = 0;
    env.interconnect.write_ports[i].req.bypass = false;
    env.interconnect.write_ports[i].req.wdata.clear();
    env.interconnect.write_ports[i].req.wstrb.clear();
    env.interconnect.write_ports[i].resp.ready = false;
  }
}

void cycle_outputs(Axi3Env &env) {
  clear_upstream_inputs(env);
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

void cycle_inputs(Axi3Env &env) {
  env.interconnect.comb_inputs();
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
  env.ddr.io.w.wid = env.interconnect.axi_io.w.wid;
  env.ddr.io.w.wdata = env.interconnect.axi_io.w.wdata;
  env.ddr.io.w.wstrb = env.interconnect.axi_io.w.wstrb;
  env.ddr.io.w.wlast = env.interconnect.axi_io.w.wlast;
  env.ddr.io.r.rready = env.interconnect.axi_io.r.rready;
  env.ddr.io.b.bready = env.interconnect.axi_io.b.bready;
  env.ddr.comb_inputs();
  env.ddr.seq();
  env.interconnect.seq();
  ++sim_time;
}

bool issue_read(Axi3Env &env, uint8_t master, uint32_t addr, uint8_t total_size,
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

bool wait_read(Axi3Env &env, uint8_t master, uint8_t id, ReadResult &out) {
  int timeout = sim_ddr_axi3::SIM_DDR_AXI3_LATENCY * 80;
  while (timeout-- > 0) {
    cycle_outputs(env);
    auto &resp = env.interconnect.read_ports[master].resp;
    if (resp.valid) {
      if (resp.id != (id & 0xF)) {
        return false;
      }
      out.master = master;
      out.id = id;
      out.data = resp.data;
      resp.ready = true;
      cycle_inputs(env);
      return true;
    }
    cycle_inputs(env);
  }
  return false;
}

bool issue_write(Axi3Env &env, uint8_t master, uint32_t addr,
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

bool wait_write(Axi3Env &env, uint8_t master, uint8_t id, WriteResult &out) {
  int timeout = sim_ddr_axi3::SIM_DDR_AXI3_LATENCY * 80;
  while (timeout-- > 0) {
    cycle_outputs(env);
    auto &resp = env.interconnect.write_ports[master].resp;
    if (resp.valid) {
      if (resp.id != (id & 0xF)) {
        std::printf("AXI3 write resp id mismatch exp=%u got=%u\n", id & 0xF,
                    resp.id);
        return false;
      }
      out.master = master;
      out.id = id;
      out.resp = resp.resp;
      resp.ready = true;
      cycle_inputs(env);
      return true;
    }
    cycle_inputs(env);
  }
  std::printf("AXI3 write resp timeout master=%u id=%u\n", master, id);
  return false;
}

ScriptResult run_axi3_script(const std::vector<uint32_t> &image) {
  load_memory_image(image);
  sim_time = 0;
  Axi3Env env;
  env.interconnect.init();
  env.ddr.init();

  ScriptResult result;
  WideWriteData_t wdata;
  WideWriteStrb_t wstrb;

  issue_read(env, MASTER_ICACHE, 0x1000, 31, 1, false);
  ReadResult r0;
  wait_read(env, MASTER_ICACHE, 1, r0);
  result.reads.push_back(r0);

  wdata.clear();
  wstrb.clear();
  wdata[0] = 0xDEADBEEF;
  for (uint32_t i = 0; i < 4; ++i) {
    wstrb.set(i, true);
  }
  issue_write(env, MASTER_DCACHE_W, 0x1104, wdata, wstrb, 3, 2, false);
  WriteResult w0;
  wait_write(env, MASTER_DCACHE_W, 2, w0);
  result.writes.push_back(w0);

  issue_read(env, MASTER_DCACHE_R, 0x1100, 7, 3, false);
  ReadResult r1;
  wait_read(env, MASTER_DCACHE_R, 3, r1);
  result.reads.push_back(r1);

  issue_read(env, MASTER_UNCORE_LSU_R, 0x1208, 15, 4, true);
  ReadResult r2;
  wait_read(env, MASTER_UNCORE_LSU_R, 4, r2);
  result.reads.push_back(r2);

  fill_line32(wdata, wstrb, 0x6600);
  if (!issue_write(env, MASTER_DCACHE_W, 0x1300, wdata, wstrb, 31, 5, false)) {
    std::printf("AXI3 issue_write failed for second write\n");
    return result;
  }
  WriteResult w1;
  if (!wait_write(env, MASTER_DCACHE_W, 5, w1)) {
    std::printf("AXI3 wait_write failed for second write\n");
    return result;
  }
  result.writes.push_back(w1);

  issue_read(env, MASTER_EXTRA_R, 0x1300, 31, 6, false);
  ReadResult r3;
  wait_read(env, MASTER_EXTRA_R, 6, r3);
  result.reads.push_back(r3);

  snapshot_words(result, 0x1100, 20);
  return result;
}

bool equal_reads(const std::vector<ReadResult> &lhs, const std::vector<ReadResult> &rhs) {
  if (lhs.size() != rhs.size()) {
    return false;
  }
  for (size_t i = 0; i < lhs.size(); ++i) {
    if (lhs[i].master != rhs[i].master || lhs[i].id != rhs[i].id) {
      return false;
    }
    for (uint32_t w = 0; w < MAX_READ_TRANSACTION_WORDS; ++w) {
      if (lhs[i].data[w] != rhs[i].data[w]) {
        return false;
      }
    }
  }
  return true;
}

bool equal_writes(const std::vector<WriteResult> &lhs,
                  const std::vector<WriteResult> &rhs) {
  if (lhs.size() != rhs.size()) {
    std::printf("write size mismatch lhs=%zu rhs=%zu\n", lhs.size(), rhs.size());
    return false;
  }
  for (size_t i = 0; i < lhs.size(); ++i) {
    if (lhs[i].master != rhs[i].master || lhs[i].id != rhs[i].id ||
        lhs[i].resp != rhs[i].resp) {
      std::printf(
          "write mismatch idx=%zu lhs{m=%u id=%u resp=%u} rhs{m=%u id=%u resp=%u}\n",
          i, lhs[i].master, lhs[i].id, lhs[i].resp, rhs[i].master, rhs[i].id,
          rhs[i].resp);
      return false;
    }
  }
  return true;
}

bool test_axi3_axi4_common_subset_equivalence() {
  std::printf("=== AXI Protocol Equivalence Test 1: common subset ===\n");

  std::vector<uint32_t> image;
  init_memory_image(image);

  const ScriptResult axi4 = run_axi4_script(image);
  const ScriptResult axi3 = run_axi3_script(image);

  if (!equal_reads(axi4.reads, axi3.reads)) {
    std::printf("FAIL: AXI4/AXI3 read responses diverged\n");
    return false;
  }
  if (!equal_writes(axi4.writes, axi3.writes)) {
    std::printf("FAIL: AXI4/AXI3 write responses diverged\n");
    return false;
  }
  if (axi4.mem_words != axi3.mem_words) {
    std::printf("FAIL: AXI4/AXI3 final memory state diverged\n");
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

  if (test_axi3_axi4_common_subset_equivalence()) {
    passed++;
  } else {
    failed++;
  }

  std::printf("AXI protocol equivalence results: %d passed, %d failed\n", passed,
              failed);
  delete[] p_memory;
  return failed == 0 ? 0 : 1;
}
