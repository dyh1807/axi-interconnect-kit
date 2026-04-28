/**
 * @file axi_interconnect_dual_port_test.cpp
 * @brief Focused coverage for DDR/MMIO split-port address routing.
 */

#include <cstdio>
#include <cstdlib>

#define private public
#include "AXI_Interconnect.h"
#undef private

uint32_t *p_memory = nullptr;
long long sim_time = 0;

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
  axi_interconnect::AXI_LLCConfig cfg{};
  cfg.enable = false;
  dut.set_llc_config(cfg);
  dut.mode = 0;
  dut.init();
  set_downstream_ready(dut);
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
  run("same-line AW waits for R", test_same_line_write_waits_for_read_return);

  std::printf("dual-port routing results: %d passed, %d failed\n", passed,
              failed);
  return failed == 0 ? 0 : 1;
}
