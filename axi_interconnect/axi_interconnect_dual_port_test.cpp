/**
 * @file axi_interconnect_dual_port_test.cpp
 * @brief Focused coverage for DDR/MMIO split-port address routing.
 */

#include <cstdio>
#include <cstdlib>

#define private public
#include "AXI_Interconnect.h"
#undef private

static_assert(axi_interconnect::MAX_OUTSTANDING == 32,
              "dual-port contract requires 32 shared read outstanding slots");
static_assert(axi_interconnect::MAX_WRITE_OUTSTANDING == 32,
              "dual-port contract requires 32 shared write outstanding slots");

uint32_t *p_memory = nullptr;
long long sim_time = 0;

namespace {
uint32_t g_legacy_backing_words[32] = {};

void reset_legacy_backing() {
  for (auto &word : g_legacy_backing_words) {
    word = 0;
  }
}

uint32_t legacy_backing_index(uint32_t paddr) {
  return (paddr - 0x10000000u) >> 2;
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

namespace {

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
}

void set_downstream_ready(axi_interconnect::AXI_Interconnect &dut) {
  dut.axi_ddr_io.ar.arready = true;
  dut.axi_ddr_io.aw.awready = true;
  dut.axi_ddr_io.w.wready = true;
  dut.axi_mmio_io.ar.arready = true;
  dut.axi_mmio_io.aw.awready = true;
  dut.axi_mmio_io.w.wready = true;
}

void init_dut(axi_interconnect::AXI_Interconnect &dut) {
  unsetenv("AXI_SUBMODULE_MODE");
  unsetenv("AXI_SUBMODULE_OFFSET");
  reset_legacy_backing();
  axi_interconnect::AXI_LLCConfig cfg{};
  cfg.enable = false;
  dut.set_llc_config(cfg);
  dut.mode = 0;
  dut.init();
  set_downstream_ready(dut);
}

void init_llc_dut(axi_interconnect::AXI_Interconnect &dut) {
  unsetenv("AXI_SUBMODULE_MODE");
  unsetenv("AXI_SUBMODULE_OFFSET");
  reset_legacy_backing();
  axi_interconnect::AXI_LLCConfig cfg{};
  cfg.enable = true;
  dut.set_llc_config(cfg);
  dut.mode = 1;
  dut.init();
  set_downstream_ready(dut);
}

void init_llc_dut_mode(axi_interconnect::AXI_Interconnect &dut, uint8_t mode,
                       uint32_t offset = 0x30000000u) {
  unsetenv("AXI_SUBMODULE_MODE");
  unsetenv("AXI_SUBMODULE_OFFSET");
  reset_legacy_backing();
  axi_interconnect::AXI_LLCConfig cfg{};
  cfg.enable = true;
  cfg.size_bytes = 8u << 20;
  dut.set_llc_config(cfg);
  dut.mode = mode;
  dut.llc_mapped_offset = offset;
  dut.init();
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
    if ((mask & (1u << byte)) != 0) {
      strobe.set(byte, true);
    }
  }
  return strobe;
}

bool enqueue_non_llc_write(axi_interconnect::AXI_Interconnect &dut,
                           uint8_t master, uint32_t addr, uint8_t total_size,
                           uint32_t data, uint32_t strobe, uint8_t id) {
  for (int retry = 0; retry < 8; ++retry) {
    cycle_outputs(dut);
    const bool ready_snapshot = dut.write_ports[master].req.ready;
    auto &req = dut.write_ports[master].req;
    req.valid = true;
    req.addr = addr;
    req.total_size = total_size;
    req.id = id;
    req.wdata = single_word_data(data);
    req.wstrb = byte_strobe(strobe);
    req.bypass = false;
    cycle_inputs(dut);
    if (ready_snapshot) {
      return true;
    }
  }
  return false;
}

bool capture_llc_write(axi_interconnect::AXI_Interconnect &dut,
                       uint8_t master, uint32_t addr, uint8_t total_size,
                       uint32_t data, uint32_t strobe, uint8_t id) {
  for (int retry = 0; retry < 8; ++retry) {
    cycle_outputs(dut);
    const bool ready_snapshot = dut.write_ports[master].req.ready;
    auto &req = dut.write_ports[master].req;
    req.valid = true;
    req.addr = addr;
    req.total_size = total_size;
    req.id = id;
    req.wdata = single_word_data(data);
    req.wstrb = byte_strobe(strobe);
    req.bypass = false;
    cycle_inputs(dut);
    if (ready_snapshot) {
      return dut.llc_upstream_write_req[master].valid;
    }
  }
  return false;
}

void fill_read_outstanding(axi_interconnect::AXI_Interconnect &dut) {
  dut.r_pending.clear();
  for (uint32_t i = 0; i < axi_interconnect::MAX_OUTSTANDING; ++i) {
    const bool use_ddr = (i % 2u) == 0;
    const uint32_t addr =
        use_ddr ? (0x50000000u + i * 0x100u)
                : (0x10010000u + i * 0x100u);
    axi_interconnect::ReadPendingTxn txn{};
    txn.axi_id = static_cast<uint8_t>(i);
    txn.master_id =
        static_cast<uint8_t>(i % axi_interconnect::NUM_READ_MASTERS);
    txn.orig_id = static_cast<uint8_t>(i);
    txn.total_beats = 1;
    txn.beats_done = 0;
    txn.port = use_ddr ? axi_interconnect::DownstreamPort::DDR
                       : axi_interconnect::DownstreamPort::MMIO;
    txn.addr = addr;
    txn.upstream_addr = addr;
    txn.upstream_total_size = 3;
    txn.data.clear();
    dut.r_pending.push_back(txn);
  }
}

void fill_write_outstanding(axi_interconnect::AXI_Interconnect &dut) {
  dut.w_pending.clear();
  for (uint32_t i = 0; i < axi_interconnect::MAX_WRITE_OUTSTANDING; ++i) {
    const bool use_ddr = (i % 2u) == 0;
    const uint32_t addr =
        use_ddr ? (0x50000000u + i * 0x100u)
                : (0x10010000u + i * 0x100u);
    axi_interconnect::WritePendingTxn txn{};
    txn.axi_id = static_cast<uint8_t>(i);
    txn.master_id =
        static_cast<uint8_t>(i % axi_interconnect::NUM_WRITE_MASTERS);
    txn.orig_id = static_cast<uint8_t>(i);
    txn.port = use_ddr ? axi_interconnect::DownstreamPort::DDR
                       : axi_interconnect::DownstreamPort::MMIO;
    txn.addr = addr;
    txn.wdata.clear();
    txn.wstrb.clear();
    txn.total_beats = 1;
    dut.w_pending.push_back(txn);
  }
}

bool test_ddr_read_routes_to_port0() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);
  auto &req = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].req;
  req.valid = true;
  req.addr = 0x40000004u;
  req.total_size = 3;
  req.id = 1;
  dut.comb_inputs();

  if (!dut.axi_ddr_io.ar.arvalid || dut.axi_mmio_io.ar.arvalid) {
    std::printf("FAIL: DDR read did not route exclusively to DDR port\n");
    return false;
  }
  if (dut.axi_ddr_io.ar.araddr != 0x40000000u || dut.axi_ddr_io.ar.arlen != 0 ||
      dut.axi_ddr_io.ar.arsize != sim_ddr::AXI_SIZE_CODE) {
    std::printf("FAIL: DDR read alignment mismatch addr=0x%08x len=%u size=%u\n",
                static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr),
                static_cast<unsigned>(dut.axi_ddr_io.ar.arlen),
                static_cast<unsigned>(dut.axi_ddr_io.ar.arsize));
    return false;
  }
  return true;
}

bool test_mmio_read_routes_to_port1() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);
  auto &req = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].req;
  req.valid = true;
  req.addr = 0x10000000u;
  req.total_size = 3;
  req.id = 2;
  dut.comb_inputs();

  if (dut.axi_ddr_io.ar.arvalid || !dut.axi_mmio_io.ar.arvalid) {
    std::printf("FAIL: MMIO read did not route exclusively to MMIO port\n");
    return false;
  }
  if (dut.axi_mmio_io.ar.araddr != 0x10000000u ||
      dut.axi_mmio_io.ar.arlen != 0 || dut.axi_mmio_io.ar.arsize != 2) {
    std::printf("FAIL: MMIO read shape mismatch addr=0x%08x len=%u size=%u\n",
                static_cast<uint32_t>(dut.axi_mmio_io.ar.araddr),
                static_cast<unsigned>(dut.axi_mmio_io.ar.arlen),
                static_cast<unsigned>(dut.axi_mmio_io.ar.arsize));
    return false;
  }
  return true;
}

bool test_mmio_large_read_blocks() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);
  auto &req = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].req;
  req.valid = true;
  req.addr = 0x10000000u;
  req.total_size = 63;
  req.id = 5;
  dut.comb_inputs();

  if (dut.axi_ddr_io.ar.arvalid || dut.axi_mmio_io.ar.arvalid || req.ready) {
    std::printf("FAIL: unsupported MMIO cacheline read was accepted\n");
    return false;
  }
  return true;
}

bool test_mmio_large_write_blocks() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);
  auto &req = dut.write_ports[axi_interconnect::MASTER_DCACHE_W].req;
  req.valid = true;
  req.addr = 0x10000000u;
  req.total_size = 63;
  req.id = 6;
  req.wdata[0] = 0x55667788u;
  req.wstrb = 0xFu;
  dut.comb_inputs();

  if (dut.axi_ddr_io.aw.awvalid || dut.axi_mmio_io.aw.awvalid ||
      dut.axi_ddr_io.w.wvalid || dut.axi_mmio_io.w.wvalid || req.ready) {
    std::printf("FAIL: unsupported MMIO cacheline write was accepted\n");
    return false;
  }
  return true;
}

bool test_llc_unsupported_mmio_read_synthesizes_response() {
  axi_interconnect::AXI_Interconnect dut;
  init_llc_dut(dut);
  clear_inputs(dut);
  g_legacy_backing_words[0] = 0xaabbccddu;
  g_legacy_backing_words[1] = 0x11223344u;

  dut.llc.io.ext_out.mem.read_req_valid = true;
  dut.llc.io.ext_out.mem.read_req_addr = 0x10000000u;
  dut.llc.io.ext_out.mem.read_req_size = 63;
  dut.llc.io.ext_out.mem.read_req_id = 4;
  dut.prepare_llc_inputs(true);
  if (!dut.llc.io.ext_in.mem.read_req_ready) {
    std::printf("FAIL: unsupported LLC MMIO read did not complete internally\n");
    return false;
  }

  dut.comb_read_arbiter();
  if (dut.axi_ddr_io.ar.arvalid || dut.axi_mmio_io.ar.arvalid) {
    std::printf("FAIL: unsupported LLC MMIO read escaped to external AXI\n");
    return false;
  }

  dut.seq();
  dut.prepare_llc_inputs(true);
  if (!dut.llc.io.ext_in.mem.read_resp_valid ||
      dut.llc.io.ext_in.mem.read_resp_id != 4 ||
      dut.llc.io.ext_in.mem.read_resp_data[0] != 0xaabbccddu ||
      dut.llc.io.ext_in.mem.read_resp_data[1] != 0x11223344u) {
    std::printf("FAIL: synthesized LLC MMIO read response missing\n");
    return false;
  }
  return true;
}

bool test_llc_unsupported_mmio_write_synthesizes_response() {
  axi_interconnect::AXI_Interconnect dut;
  init_llc_dut(dut);
  clear_inputs(dut);

  dut.llc.io.ext_out.mem.write_req_valid = true;
  dut.llc.io.ext_out.mem.write_req_addr = 0x10000000u;
  dut.llc.io.ext_out.mem.write_req_size = 63;
  dut.llc.io.ext_out.mem.write_req_id = 5;
  dut.llc.io.ext_out.mem.write_req_data[0] = 0x55667788u;
  dut.llc.io.ext_out.mem.write_req_data[1] = 0x99aabbccu;
  dut.llc.io.ext_out.mem.write_req_strobe.set(0, true);
  dut.llc.io.ext_out.mem.write_req_strobe.set(1, true);
  dut.llc.io.ext_out.mem.write_req_strobe.set(2, true);
  dut.llc.io.ext_out.mem.write_req_strobe.set(3, true);
  dut.llc.io.ext_out.mem.write_req_strobe.set(4, true);
  dut.llc.io.ext_out.mem.write_req_strobe.set(5, true);
  dut.llc.io.ext_out.mem.write_req_strobe.set(6, true);
  dut.llc.io.ext_out.mem.write_req_strobe.set(7, true);
  dut.llc.io.ext_out.mem.write_resp_ready = true;
  dut.prepare_llc_inputs(true);
  if (!dut.llc.io.ext_in.mem.write_req_ready) {
    std::printf("FAIL: unsupported LLC MMIO write did not complete internally\n");
    return false;
  }

  dut.comb_write_request();
  if (dut.axi_ddr_io.aw.awvalid || dut.axi_mmio_io.aw.awvalid ||
      dut.axi_ddr_io.w.wvalid || dut.axi_mmio_io.w.wvalid) {
    std::printf("FAIL: unsupported LLC MMIO write escaped to external AXI\n");
    return false;
  }

  dut.seq();
  dut.prepare_llc_inputs(true);
  if (!dut.llc.io.ext_in.mem.write_resp_valid ||
      dut.llc.io.ext_in.mem.write_resp != sim_ddr::AXI_RESP_OKAY ||
      g_legacy_backing_words[0] != 0x55667788u ||
      g_legacy_backing_words[1] != 0x99aabbccu) {
    std::printf("FAIL: synthesized LLC MMIO write response missing\n");
    return false;
  }
  return true;
}

bool test_llc_mmio_upstream_forces_bypass() {
  axi_interconnect::AXI_Interconnect dut;
  init_llc_dut(dut);
  clear_inputs(dut);

  auto &req = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].req;
  req.valid = true;
  req.addr = 0x10000000u;
  req.total_size = 63;
  req.id = 9;
  req.bypass = false;
  dut.comb_read_arbiter();

  const auto &cap = dut.llc_upstream_capture_c[axi_interconnect::MASTER_DCACHE_R];
  if (!cap.valid || !cap.bypass || cap.addr != 0x10000000u ||
      cap.total_size != 63) {
    std::printf("FAIL: MMIO-classified LLC upstream read was not forced bypass\n");
    return false;
  }
  if (dut.axi_ddr_io.ar.arvalid || dut.axi_mmio_io.ar.arvalid) {
    std::printf("FAIL: upstream LLC MMIO capture escaped directly to AXI\n");
    return false;
  }
  return true;
}

bool test_ddr_and_mmio_read_issue_same_cycle() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);

  dut.req_ready_r[axi_interconnect::MASTER_ICACHE] = true;
  auto &icache_req = dut.read_ports[axi_interconnect::MASTER_ICACHE].req;
  icache_req.valid = true;
  icache_req.addr = 0x40000200u;
  icache_req.total_size = 63;
  icache_req.id = 7;

  auto &dcache_req = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].req;
  dcache_req.valid = true;
  dcache_req.addr = 0x10000000u;
  dcache_req.total_size = 3;
  dcache_req.id = 8;

  dut.comb_inputs();

  if (!dut.axi_ddr_io.ar.arvalid || !dut.axi_mmio_io.ar.arvalid) {
    std::printf("FAIL: DDR/MMIO AR did not issue in the same cycle\n");
    return false;
  }
  if (dut.axi_ddr_io.ar.araddr != 0x40000200u ||
      dut.axi_ddr_io.ar.arlen != 1 ||
      dut.axi_mmio_io.ar.araddr != 0x10000000u ||
      dut.axi_mmio_io.ar.arlen != 0) {
    std::printf("FAIL: same-cycle AR shape mismatch ddr_addr=0x%08x "
                "ddr_len=%u mmio_addr=0x%08x mmio_len=%u\n",
                static_cast<uint32_t>(dut.axi_ddr_io.ar.araddr),
                static_cast<unsigned>(dut.axi_ddr_io.ar.arlen),
                static_cast<uint32_t>(dut.axi_mmio_io.ar.araddr),
                static_cast<unsigned>(dut.axi_mmio_io.ar.arlen));
    return false;
  }
  return true;
}

bool test_ddr_and_mmio_aw_issue_same_cycle() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);

  axi_interconnect::WritePendingTxn ddr{};
  ddr.axi_id = 1;
  ddr.master_id = axi_interconnect::MASTER_DCACHE_W;
  ddr.orig_id = 1;
  ddr.port = axi_interconnect::DownstreamPort::DDR;
  ddr.addr = 0x40000400u;
  ddr.total_beats = 2;
  axi_interconnect::WritePendingTxn mmio{};
  mmio.axi_id = 2;
  mmio.master_id = axi_interconnect::MASTER_UNCORE_LSU_W;
  mmio.orig_id = 2;
  mmio.port = axi_interconnect::DownstreamPort::MMIO;
  mmio.addr = 0x10000004u;
  mmio.total_beats = 1;
  dut.w_pending.push_back(ddr);
  dut.w_pending.push_back(mmio);

  dut.comb_inputs();

  if (!dut.axi_ddr_io.aw.awvalid || !dut.axi_mmio_io.aw.awvalid) {
    std::printf("FAIL: DDR/MMIO AW did not issue in the same cycle\n");
    return false;
  }
  if (dut.axi_ddr_io.aw.awaddr != 0x40000400u ||
      dut.axi_ddr_io.aw.awlen != 1 ||
      dut.axi_mmio_io.aw.awaddr != 0x10000004u ||
      dut.axi_mmio_io.aw.awlen != 0) {
    std::printf("FAIL: same-cycle AW shape mismatch\n");
    return false;
  }
  return true;
}

bool test_ddr_and_mmio_w_issue_same_cycle() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);

  dut.w_active = true;
  dut.w_current = {};
  dut.w_current.port = axi_interconnect::DownstreamPort::DDR;
  dut.w_current.aw_done = true;
  dut.w_current.total_beats = 2;
  dut.w_current.wdata[0] = 0x11112222u;
  dut.w_current.wstrb.set(0, true);

  dut.w_active_mmio = true;
  dut.w_current_mmio = {};
  dut.w_current_mmio.port = axi_interconnect::DownstreamPort::MMIO;
  dut.w_current_mmio.aw_done = true;
  dut.w_current_mmio.total_beats = 1;
  dut.w_current_mmio.wdata[0] = 0x33334444u;
  dut.w_current_mmio.wstrb.set(0, true);

  dut.comb_inputs();

  if (!dut.axi_ddr_io.w.wvalid || !dut.axi_mmio_io.w.wvalid) {
    std::printf("FAIL: DDR/MMIO W did not issue in the same cycle\n");
    return false;
  }
  if (dut.axi_ddr_io.w.wlast || !dut.axi_mmio_io.w.wlast) {
    std::printf("FAIL: same-cycle W last mismatch ddr_last=%u mmio_last=%u\n",
                static_cast<unsigned>(dut.axi_ddr_io.w.wlast),
                static_cast<unsigned>(dut.axi_mmio_io.w.wlast));
    return false;
  }
  return true;
}

bool test_same_line_write_waits_for_read_return() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);
  auto &read_req = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].req;
  read_req.valid = true;
  read_req.addr = 0x40000100u;
  read_req.total_size = 63;
  read_req.id = 3;
  dut.comb_inputs();
  if (!dut.axi_ddr_io.ar.arvalid) {
    std::printf("FAIL: setup read did not issue AR\n");
    return false;
  }
  dut.seq();

  clear_inputs(dut);
  auto &write_req = dut.write_ports[axi_interconnect::MASTER_DCACHE_W].req;
  write_req.valid = true;
  write_req.addr = 0x40000110u;
  write_req.total_size = 3;
  write_req.id = 4;
  write_req.wdata[0] = 0x11223344u;
  write_req.wstrb = 0xFu;
  dut.comb_inputs();
  dut.seq();

  clear_inputs(dut);
  auto &write_req_held = dut.write_ports[axi_interconnect::MASTER_DCACHE_W].req;
  write_req_held.valid = true;
  write_req_held.addr = 0x40000110u;
  write_req_held.total_size = 3;
  write_req_held.id = 4;
  write_req_held.wdata[0] = 0x11223344u;
  write_req_held.wstrb = 0xFu;
  dut.comb_inputs();
  dut.seq();

  clear_inputs(dut);
  dut.comb_inputs();
  if (dut.axi_ddr_io.aw.awvalid || dut.axi_mmio_io.aw.awvalid) {
    std::printf("FAIL: same-line AW issued before read R returned\n");
    return false;
  }
  return true;
}

bool test_same_line_read_waits_for_write_b() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);

  axi_interconnect::WritePendingTxn pending{};
  pending.axi_id = 3;
  pending.master_id = axi_interconnect::MASTER_DCACHE_W;
  pending.orig_id = 3;
  pending.port = axi_interconnect::DownstreamPort::DDR;
  pending.addr = 0x40000200u;
  pending.total_beats = 1;
  pending.beats_sent = 1;
  pending.aw_done = true;
  pending.w_done = true;
  dut.w_pending.push_back(pending);

  auto &read_req = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].req;
  read_req.valid = true;
  read_req.addr = 0x40000210u;
  read_req.total_size = 3;
  read_req.id = 5;
  dut.comb_inputs();

  if (dut.axi_ddr_io.ar.arvalid || dut.axi_mmio_io.ar.arvalid) {
    std::printf("FAIL: same-line AR issued before write B returned\n");
    return false;
  }
  return true;
}

bool test_different_port_read_not_blocked_by_ddr_write() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);

  axi_interconnect::WritePendingTxn pending{};
  pending.axi_id = 4;
  pending.master_id = axi_interconnect::MASTER_DCACHE_W;
  pending.orig_id = 4;
  pending.port = axi_interconnect::DownstreamPort::DDR;
  pending.addr = 0x40000300u;
  pending.total_beats = 1;
  pending.aw_done = false;
  pending.w_done = false;
  dut.w_pending.push_back(pending);

  auto &read_req = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].req;
  read_req.valid = true;
  read_req.addr = 0x10000000u;
  read_req.total_size = 3;
  read_req.id = 6;
  dut.comb_inputs();

  if (!dut.axi_mmio_io.ar.arvalid || dut.axi_ddr_io.ar.arvalid) {
    std::printf("FAIL: MMIO AR was incorrectly blocked by DDR write\n");
    return false;
  }
  if (!dut.axi_ddr_io.aw.awvalid) {
    std::printf("FAIL: DDR AW setup was not driven alongside MMIO AR\n");
    return false;
  }
  return true;
}

bool test_different_port_write_not_blocked_by_ddr_read() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);

  axi_interconnect::ReadPendingTxn pending{};
  pending.axi_id = 5;
  pending.master_id = axi_interconnect::MASTER_DCACHE_R;
  pending.orig_id = 5;
  pending.total_beats = 2;
  pending.beats_done = 0;
  pending.port = axi_interconnect::DownstreamPort::DDR;
  pending.addr = 0x40000400u;
  pending.upstream_addr = 0x40000400u;
  pending.upstream_total_size = 63;
  pending.to_llc = false;
  dut.r_pending.push_back(pending);

  axi_interconnect::WritePendingTxn write{};
  write.axi_id = 6;
  write.master_id = axi_interconnect::MASTER_UNCORE_LSU_W;
  write.orig_id = 6;
  write.port = axi_interconnect::DownstreamPort::MMIO;
  write.addr = 0x10000004u;
  write.total_beats = 1;
  write.aw_done = false;
  write.w_done = false;
  dut.w_pending.push_back(write);

  dut.comb_inputs();

  if (!dut.axi_mmio_io.aw.awvalid || dut.axi_ddr_io.aw.awvalid) {
    std::printf("FAIL: MMIO AW was incorrectly blocked by DDR read\n");
    return false;
  }
  return true;
}

bool test_llc_mem_write_waits_for_read_return() {
  axi_interconnect::AXI_Interconnect dut;
  init_llc_dut(dut);
  clear_inputs(dut);

  axi_interconnect::ReadPendingTxn pending{};
  pending.axi_id = 1;
  pending.master_id = 0;
  pending.orig_id = 1;
  pending.total_beats = 2;
  pending.beats_done = 1;
  pending.port = axi_interconnect::DownstreamPort::DDR;
  pending.addr = 0x40000800u;
  pending.upstream_addr = 0x40000800u;
  pending.upstream_total_size = 63;
  pending.to_llc = true;
  dut.r_pending.push_back(pending);

  dut.llc.io.ext_out.mem.write_req_valid = true;
  dut.llc.io.ext_out.mem.write_req_addr = 0x40000820u;
  dut.llc.io.ext_out.mem.write_req_size = 63;
  dut.prepare_llc_inputs(true);
  if (dut.llc.io.ext_in.mem.write_req_ready) {
    std::printf("FAIL: LLC mem write was ready before same-line R returned\n");
    return false;
  }

  dut.r_pending[0].beats_done = dut.r_pending[0].total_beats;
  dut.prepare_llc_inputs(true);
  if (!dut.llc.io.ext_in.mem.write_req_ready) {
    std::printf("FAIL: LLC mem write stayed blocked after R returned\n");
    return false;
  }
  return true;
}

bool test_llc_mem_read_waits_for_write_b() {
  axi_interconnect::AXI_Interconnect dut;
  init_llc_dut(dut);
  clear_inputs(dut);

  dut.w_active = true;
  dut.w_current = {};
  dut.w_current.port = axi_interconnect::DownstreamPort::DDR;
  dut.w_current.addr = 0x40000900u;
  dut.w_current.total_beats = 1;
  dut.w_current.aw_done = true;
  dut.w_current.w_done = true;

  dut.llc.io.ext_out.mem.read_req_valid = true;
  dut.llc.io.ext_out.mem.read_req_addr = 0x40000920u;
  dut.llc.io.ext_out.mem.read_req_size = 63;
  dut.llc.io.ext_out.mem.read_req_id = 2;
  dut.prepare_llc_inputs(true);
  if (dut.llc.io.ext_in.mem.read_req_ready) {
    std::printf("FAIL: LLC mem read was ready before same-line B returned\n");
    return false;
  }

  dut.w_active = false;
  dut.w_current = {};
  dut.prepare_llc_inputs(true);
  if (!dut.llc.io.ext_in.mem.read_req_ready) {
    std::printf("FAIL: LLC mem read stayed blocked after write completion\n");
    return false;
  }
  return true;
}

bool test_shared_read_outstanding_budget_blocks_both_ports() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);
  fill_read_outstanding(dut);

  auto &ddr_req = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].req;
  ddr_req.valid = true;
  ddr_req.addr = 0x40000004u;
  ddr_req.total_size = 3;
  ddr_req.id = 0x31;
  dut.comb_inputs();
  if (dut.axi_ddr_io.ar.arvalid || dut.axi_mmio_io.ar.arvalid ||
      ddr_req.ready) {
    std::printf("FAIL: full shared read budget still accepted DDR read\n");
    return false;
  }

  clear_inputs(dut);
  auto &mmio_req = dut.read_ports[axi_interconnect::MASTER_UNCORE_LSU_R].req;
  mmio_req.valid = true;
  mmio_req.addr = 0x10000000u;
  mmio_req.total_size = 3;
  mmio_req.id = 0x32;
  dut.comb_inputs();
  if (dut.axi_ddr_io.ar.arvalid || dut.axi_mmio_io.ar.arvalid ||
      mmio_req.ready) {
    std::printf("FAIL: full shared read budget still accepted MMIO read\n");
    return false;
  }
  return true;
}

bool test_read_outstanding_does_not_block_write_budget() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);
  fill_read_outstanding(dut);

  if (!enqueue_non_llc_write(dut, axi_interconnect::MASTER_DCACHE_W,
                             0x40000004u, 3, 0x11223344u, 0xfu, 0x33)) {
    std::printf("FAIL: full read budget incorrectly blocked write request\n");
    return false;
  }
  if (dut.w_pending.empty()) {
    std::printf("FAIL: write was accepted but no write pending entry exists\n");
    return false;
  }
  return true;
}

bool test_shared_write_outstanding_budget_blocks_both_ports() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);
  fill_write_outstanding(dut);

  auto &ddr_req = dut.write_ports[axi_interconnect::MASTER_DCACHE_W].req;
  ddr_req.valid = true;
  ddr_req.addr = 0x40000004u;
  ddr_req.total_size = 3;
  ddr_req.id = 0x34;
  ddr_req.wdata = single_word_data(0xaabbccddu);
  ddr_req.wstrb = byte_strobe(0xfu);
  dut.comb_inputs();
  if (ddr_req.ready ||
      dut.w_pending.size() != axi_interconnect::MAX_WRITE_OUTSTANDING) {
    std::printf("FAIL: full shared write budget still accepted DDR write\n");
    return false;
  }

  clear_inputs(dut);
  auto &mmio_req = dut.write_ports[axi_interconnect::MASTER_UNCORE_LSU_W].req;
  mmio_req.valid = true;
  mmio_req.addr = 0x10000000u;
  mmio_req.total_size = 3;
  mmio_req.id = 0x35;
  mmio_req.wdata = single_word_data(0xddccbbaau);
  mmio_req.wstrb = byte_strobe(0xfu);
  dut.comb_inputs();
  if (mmio_req.ready ||
      dut.w_pending.size() != axi_interconnect::MAX_WRITE_OUTSTANDING) {
    std::printf("FAIL: full shared write budget still accepted MMIO write\n");
    return false;
  }
  return true;
}

bool test_write_outstanding_does_not_block_read_budget() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);
  fill_write_outstanding(dut);

  auto &req = dut.read_ports[axi_interconnect::MASTER_DCACHE_R].req;
  req.valid = true;
  req.addr = 0x40000004u;
  req.total_size = 3;
  req.id = 0x36;
  dut.comb_inputs();
  if (!dut.axi_ddr_io.ar.arvalid || dut.axi_mmio_io.ar.arvalid ||
      !req.ready) {
    std::printf("FAIL: full write budget incorrectly blocked DDR read\n");
    return false;
  }
  return true;
}

bool test_mode0_ddr_partial_write_aligns_to_256b() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);

  if (!enqueue_non_llc_write(dut, axi_interconnect::MASTER_DCACHE_W,
                             0x40000004u, 3, 0xaabbccddu, 0xfu, 0x11)) {
    std::printf("FAIL: mode0 DDR partial write was not accepted\n");
    return false;
  }
  if (dut.w_pending.empty()) {
    std::printf("FAIL: mode0 DDR write was not enqueued\n");
    return false;
  }
  const auto &txn = dut.w_pending.back();
  if (txn.port != axi_interconnect::DownstreamPort::DDR ||
      txn.addr != 0x40000000u || txn.total_beats != 1 ||
      txn.wdata[1] != 0xaabbccddu) {
    std::printf("FAIL: mode0 DDR write alignment mismatch addr=0x%08x "
                "beats=%u data1=0x%08x\n",
                txn.addr, static_cast<unsigned>(txn.total_beats),
                txn.wdata[1]);
    return false;
  }
  for (int byte = 0; byte < 8; ++byte) {
    const bool expected = byte >= 4;
    if (txn.wstrb.test(byte) != expected) {
      std::printf("FAIL: mode0 DDR shifted strobe mismatch byte=%d got=%d\n",
                  byte, static_cast<int>(txn.wstrb.test(byte)));
      return false;
    }
  }
  return true;
}

bool test_mode0_mmio_word_write_uses_mmio_port() {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);
  clear_inputs(dut);

  if (!enqueue_non_llc_write(dut, axi_interconnect::MASTER_UNCORE_LSU_W,
                             0x10000004u, 3, 0x11223344u, 0xfu, 0x12)) {
    std::printf("FAIL: mode0 MMIO word write was not accepted\n");
    return false;
  }
  if (dut.w_pending.empty()) {
    std::printf("FAIL: mode0 MMIO write was not enqueued\n");
    return false;
  }
  const auto &txn = dut.w_pending.back();
  if (txn.port != axi_interconnect::DownstreamPort::MMIO ||
      txn.addr != 0x10000004u || txn.total_beats != 1 ||
      txn.wdata[0] != 0x11223344u || txn.wstrb.slice_u32(0) != 0xfu) {
    std::printf("FAIL: mode0 MMIO write shape mismatch addr=0x%08x "
                "beats=%u data0=0x%08x strb=0x%llx\n",
                txn.addr, static_cast<unsigned>(txn.total_beats),
                txn.wdata[0],
                static_cast<unsigned long long>(txn.wstrb.slice_u32(0)));
    return false;
  }
  return true;
}

bool test_mode2_mapped_write_captures_direct_mapped_llc() {
  axi_interconnect::AXI_Interconnect dut;
  init_llc_dut_mode(dut, 2, 0x30000000u);
  clear_inputs(dut);

  if (!capture_llc_write(dut, axi_interconnect::MASTER_DCACHE_W,
                         0x30000004u, 3, 0x55667788u, 0xfu, 0x13)) {
    std::printf("FAIL: mode2 mapped write was not captured\n");
    return false;
  }
  const auto &cap = dut.llc_upstream_write_req[axi_interconnect::MASTER_DCACHE_W];
  if (cap.addr != 0x00000004u || !cap.direct_mapped || cap.bypass ||
      cap.mode2_ddr_aligned) {
    std::printf("FAIL: mode2 mapped write flags mismatch addr=0x%08x "
                "direct=%d bypass=%d aligned=%d\n",
                cap.addr, static_cast<int>(cap.direct_mapped),
                static_cast<int>(cap.bypass),
                static_cast<int>(cap.mode2_ddr_aligned));
    return false;
  }
  return true;
}

bool test_mode3_ddr_write_forces_llc_bypass() {
  axi_interconnect::AXI_Interconnect dut;
  init_llc_dut_mode(dut, 3, 0x30000000u);
  clear_inputs(dut);

  if (!capture_llc_write(dut, axi_interconnect::MASTER_DCACHE_W,
                         0x40000004u, 3, 0x99aabbccu, 0xfu, 0x14)) {
    std::printf("FAIL: mode3 DDR write was not captured\n");
    return false;
  }
  const auto &cap = dut.llc_upstream_write_req[axi_interconnect::MASTER_DCACHE_W];
  if (cap.addr != 0x40000004u || cap.direct_mapped || !cap.bypass ||
      cap.mode2_ddr_aligned) {
    std::printf("FAIL: mode3 DDR write flags mismatch addr=0x%08x "
                "direct=%d bypass=%d aligned=%d\n",
                cap.addr, static_cast<int>(cap.direct_mapped),
                static_cast<int>(cap.bypass),
                static_cast<int>(cap.mode2_ddr_aligned));
    return false;
  }
  return true;
}

} // namespace

int main() {
  int passed = 0;
  int failed = 0;
  auto run = [&](const char *name, bool (*fn)()) {
    std::printf("=== %s ===\n", name);
    if (fn()) {
      std::printf("PASS\n");
      ++passed;
    } else {
      ++failed;
    }
  };

  run("DDR read routes to port0", test_ddr_read_routes_to_port0);
  run("MMIO read routes to port1", test_mmio_read_routes_to_port1);
  run("MMIO cacheline read blocks", test_mmio_large_read_blocks);
  run("MMIO cacheline write blocks", test_mmio_large_write_blocks);
  run("LLC unsupported MMIO read synthesizes response",
      test_llc_unsupported_mmio_read_synthesizes_response);
  run("LLC unsupported MMIO write synthesizes response",
      test_llc_unsupported_mmio_write_synthesizes_response);
  run("LLC MMIO upstream forces bypass", test_llc_mmio_upstream_forces_bypass);
  run("DDR and MMIO AR issue same-cycle",
      test_ddr_and_mmio_read_issue_same_cycle);
  run("DDR and MMIO AW issue same-cycle",
      test_ddr_and_mmio_aw_issue_same_cycle);
  run("DDR and MMIO W issue same-cycle", test_ddr_and_mmio_w_issue_same_cycle);
  run("same-line AW waits for R", test_same_line_write_waits_for_read_return);
  run("same-line AR waits for B", test_same_line_read_waits_for_write_b);
  run("MMIO AR not blocked by DDR write",
      test_different_port_read_not_blocked_by_ddr_write);
  run("MMIO AW not blocked by DDR read",
      test_different_port_write_not_blocked_by_ddr_read);
  run("LLC mem write waits for same-line R",
      test_llc_mem_write_waits_for_read_return);
  run("LLC mem read waits for same-line B",
      test_llc_mem_read_waits_for_write_b);
  run("shared read budget blocks both ports",
      test_shared_read_outstanding_budget_blocks_both_ports);
  run("read outstanding does not block write budget",
      test_read_outstanding_does_not_block_write_budget);
  run("shared write budget blocks both ports",
      test_shared_write_outstanding_budget_blocks_both_ports);
  run("write outstanding does not block read budget",
      test_write_outstanding_does_not_block_read_budget);
  run("mode0 DDR partial write aligns to 256b",
      test_mode0_ddr_partial_write_aligns_to_256b);
  run("mode0 MMIO word write uses MMIO port",
      test_mode0_mmio_word_write_uses_mmio_port);
  run("mode2 mapped write captures direct-mapped LLC",
      test_mode2_mapped_write_captures_direct_mapped_llc);
  run("mode3 DDR write forces LLC bypass",
      test_mode3_ddr_write_forces_llc_bypass);

  std::printf("dual-port routing results: %d passed, %d failed\n", passed,
              failed);
  return failed == 0 ? 0 : 1;
}
