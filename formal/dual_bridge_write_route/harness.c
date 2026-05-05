#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void next_timeframe(void);
void set_inputs(void);

uint32_t nondet_uint32_t(void);
bool nondet_bool(void);

struct module_axi_llc_axi_bridge_dual_write_route_formal_top
{
  bool clk;
  bool rst_n;
  bool cache_req_valid;
  bool cache_req_write;
  uint32_t cache_req_addr;
  uint8_t cache_req_size;
  uint8_t cache_req_wstrb;
  bool cache_req_ready;
  bool ddr_axi_awvalid;
  uint32_t ddr_axi_awaddr;
  uint8_t ddr_axi_awlen;
  uint8_t ddr_axi_awsize;
  bool ddr_axi_wvalid;
  uint8_t ddr_axi_wstrb;
  bool ddr_axi_wlast;
  bool mmio_axi_awvalid;
  uint32_t mmio_axi_awaddr;
  uint8_t mmio_axi_awlen;
  uint8_t mmio_axi_awsize;
  bool mmio_axi_wvalid;
  uint8_t mmio_axi_wstrb;
  bool mmio_axi_wlast;
};

extern struct module_axi_llc_axi_bridge_dual_write_route_formal_top
  axi_llc_axi_bridge_dual_write_route_formal_top;

static void drive_idle(void)
{
  axi_llc_axi_bridge_dual_write_route_formal_top.cache_req_valid = false;
  axi_llc_axi_bridge_dual_write_route_formal_top.cache_req_write = true;
  axi_llc_axi_bridge_dual_write_route_formal_top.cache_req_addr = 0u;
  axi_llc_axi_bridge_dual_write_route_formal_top.cache_req_size =
      AXI_DUAL_PORT_MMIO_TOTAL_SIZE;
  axi_llc_axi_bridge_dual_write_route_formal_top.cache_req_wstrb = 0u;
}

int main(void)
{
  const bool unsupported_mmio_case = nondet_bool();
  const uint32_t raw_addr = nondet_uint32_t();
  const uint32_t addr = unsupported_mmio_case ? (raw_addr & 0x0ffffffcu)
                                              : (raw_addr & ~3u);
  const uint8_t total_size = unsupported_mmio_case
                                 ? 63u
                                 : AXI_DUAL_PORT_MMIO_TOTAL_SIZE;
  const uint8_t line_wstrb = 0x0fu;
  const AxiDualPortRouteSupport route =
      axi_dual_port_route_support(addr, total_size, 0x40000000u);

  if(unsupported_mmio_case)
  {
    assert(route.mmio_port);
    assert(!route.supported);
  }

  axi_llc_axi_bridge_dual_write_route_formal_top.rst_n = false;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_write_route_formal_top.rst_n = true;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_write_route_formal_top.cache_req_valid = true;
  axi_llc_axi_bridge_dual_write_route_formal_top.cache_req_write = true;
  axi_llc_axi_bridge_dual_write_route_formal_top.cache_req_addr = addr;
  axi_llc_axi_bridge_dual_write_route_formal_top.cache_req_size = total_size;
  axi_llc_axi_bridge_dual_write_route_formal_top.cache_req_wstrb = line_wstrb;
  set_inputs();

  assert(axi_llc_axi_bridge_dual_write_route_formal_top.cache_req_ready ==
         route.supported);

  next_timeframe();

  set_inputs();
  const bool ddr_awvalid_1 =
      axi_llc_axi_bridge_dual_write_route_formal_top.ddr_axi_awvalid;
  const bool ddr_wvalid_1 =
      axi_llc_axi_bridge_dual_write_route_formal_top.ddr_axi_wvalid;
  const bool mmio_awvalid_1 =
      axi_llc_axi_bridge_dual_write_route_formal_top.mmio_axi_awvalid;
  const bool mmio_wvalid_1 =
      axi_llc_axi_bridge_dual_write_route_formal_top.mmio_axi_wvalid;
  const uint32_t ddr_awaddr_1 =
      axi_llc_axi_bridge_dual_write_route_formal_top.ddr_axi_awaddr;
  const uint8_t ddr_awlen_1 =
      axi_llc_axi_bridge_dual_write_route_formal_top.ddr_axi_awlen;
  const uint8_t ddr_awsize_1 =
      axi_llc_axi_bridge_dual_write_route_formal_top.ddr_axi_awsize;
  const uint8_t ddr_wstrb_1 =
      axi_llc_axi_bridge_dual_write_route_formal_top.ddr_axi_wstrb;
  const bool ddr_wlast_1 =
      axi_llc_axi_bridge_dual_write_route_formal_top.ddr_axi_wlast;
  const uint32_t mmio_awaddr_1 =
      axi_llc_axi_bridge_dual_write_route_formal_top.mmio_axi_awaddr;
  const uint8_t mmio_awlen_1 =
      axi_llc_axi_bridge_dual_write_route_formal_top.mmio_axi_awlen;
  const uint8_t mmio_awsize_1 =
      axi_llc_axi_bridge_dual_write_route_formal_top.mmio_axi_awsize;
  const uint8_t mmio_wstrb_1 =
      axi_llc_axi_bridge_dual_write_route_formal_top.mmio_axi_wstrb;
  const bool mmio_wlast_1 =
      axi_llc_axi_bridge_dual_write_route_formal_top.mmio_axi_wlast;

  drive_idle();
  set_inputs();
  next_timeframe();
  set_inputs();

  const bool ddr_awvalid_2 =
      axi_llc_axi_bridge_dual_write_route_formal_top.ddr_axi_awvalid;
  const bool ddr_wvalid_2 =
      axi_llc_axi_bridge_dual_write_route_formal_top.ddr_axi_wvalid;
  const bool mmio_awvalid_2 =
      axi_llc_axi_bridge_dual_write_route_formal_top.mmio_axi_awvalid;
  const bool mmio_wvalid_2 =
      axi_llc_axi_bridge_dual_write_route_formal_top.mmio_axi_wvalid;
  const uint32_t ddr_awaddr_2 =
      axi_llc_axi_bridge_dual_write_route_formal_top.ddr_axi_awaddr;
  const uint8_t ddr_awlen_2 =
      axi_llc_axi_bridge_dual_write_route_formal_top.ddr_axi_awlen;
  const uint8_t ddr_awsize_2 =
      axi_llc_axi_bridge_dual_write_route_formal_top.ddr_axi_awsize;
  const uint8_t ddr_wstrb_2 =
      axi_llc_axi_bridge_dual_write_route_formal_top.ddr_axi_wstrb;
  const bool ddr_wlast_2 =
      axi_llc_axi_bridge_dual_write_route_formal_top.ddr_axi_wlast;
  const uint32_t mmio_awaddr_2 =
      axi_llc_axi_bridge_dual_write_route_formal_top.mmio_axi_awaddr;
  const uint8_t mmio_awlen_2 =
      axi_llc_axi_bridge_dual_write_route_formal_top.mmio_axi_awlen;
  const uint8_t mmio_awsize_2 =
      axi_llc_axi_bridge_dual_write_route_formal_top.mmio_axi_awsize;
  const uint8_t mmio_wstrb_2 =
      axi_llc_axi_bridge_dual_write_route_formal_top.mmio_axi_wstrb;
  const bool mmio_wlast_2 =
      axi_llc_axi_bridge_dual_write_route_formal_top.mmio_axi_wlast;

  next_timeframe();
  set_inputs();

  const bool ddr_awvalid_3 =
      axi_llc_axi_bridge_dual_write_route_formal_top.ddr_axi_awvalid;
  const bool ddr_wvalid_3 =
      axi_llc_axi_bridge_dual_write_route_formal_top.ddr_axi_wvalid;
  const bool mmio_awvalid_3 =
      axi_llc_axi_bridge_dual_write_route_formal_top.mmio_axi_awvalid;
  const bool mmio_wvalid_3 =
      axi_llc_axi_bridge_dual_write_route_formal_top.mmio_axi_wvalid;
  const uint32_t ddr_awaddr_3 =
      axi_llc_axi_bridge_dual_write_route_formal_top.ddr_axi_awaddr;
  const uint8_t ddr_awlen_3 =
      axi_llc_axi_bridge_dual_write_route_formal_top.ddr_axi_awlen;
  const uint8_t ddr_awsize_3 =
      axi_llc_axi_bridge_dual_write_route_formal_top.ddr_axi_awsize;
  const uint8_t ddr_wstrb_3 =
      axi_llc_axi_bridge_dual_write_route_formal_top.ddr_axi_wstrb;
  const bool ddr_wlast_3 =
      axi_llc_axi_bridge_dual_write_route_formal_top.ddr_axi_wlast;
  const uint32_t mmio_awaddr_3 =
      axi_llc_axi_bridge_dual_write_route_formal_top.mmio_axi_awaddr;
  const uint8_t mmio_awlen_3 =
      axi_llc_axi_bridge_dual_write_route_formal_top.mmio_axi_awlen;
  const uint8_t mmio_awsize_3 =
      axi_llc_axi_bridge_dual_write_route_formal_top.mmio_axi_awsize;
  const uint8_t mmio_wstrb_3 =
      axi_llc_axi_bridge_dual_write_route_formal_top.mmio_axi_wstrb;
  const bool mmio_wlast_3 =
      axi_llc_axi_bridge_dual_write_route_formal_top.mmio_axi_wlast;

  if(route.supported && route.ddr_port)
  {
    assert(ddr_awvalid_1 || ddr_awvalid_2 || ddr_awvalid_3);
    assert(ddr_wvalid_1 || ddr_wvalid_2 || ddr_wvalid_3);
    assert(!mmio_awvalid_1);
    assert(!mmio_awvalid_2);
    assert(!mmio_awvalid_3);
    assert(!mmio_wvalid_1);
    assert(!mmio_wvalid_2);
    assert(!mmio_wvalid_3);
    if(ddr_awvalid_1)
    {
      assert(ddr_awaddr_1 == addr);
      assert(ddr_awlen_1 == 0u);
      assert(ddr_awsize_1 == 3u);
    }
    if(ddr_awvalid_2)
    {
      assert(ddr_awaddr_2 == addr);
      assert(ddr_awlen_2 == 0u);
      assert(ddr_awsize_2 == 3u);
    }
    if(ddr_awvalid_3)
    {
      assert(ddr_awaddr_3 == addr);
      assert(ddr_awlen_3 == 0u);
      assert(ddr_awsize_3 == 3u);
    }
    if(ddr_wvalid_1)
    {
      assert(ddr_wstrb_1 == line_wstrb);
      assert(ddr_wlast_1);
    }
    if(ddr_wvalid_2)
    {
      assert(ddr_wstrb_2 == line_wstrb);
      assert(ddr_wlast_2);
    }
    if(ddr_wvalid_3)
    {
      assert(ddr_wstrb_3 == line_wstrb);
      assert(ddr_wlast_3);
    }
  }

  if(route.supported && route.mmio_port)
  {
    assert(!ddr_awvalid_1);
    assert(!ddr_awvalid_2);
    assert(!ddr_awvalid_3);
    assert(!ddr_wvalid_1);
    assert(!ddr_wvalid_2);
    assert(!ddr_wvalid_3);
    assert(mmio_awvalid_1 || mmio_awvalid_2 || mmio_awvalid_3);
    assert(mmio_wvalid_1 || mmio_wvalid_2 || mmio_wvalid_3);
    if(mmio_awvalid_1)
    {
      assert(mmio_awaddr_1 == addr);
      assert(mmio_awlen_1 == 0u);
      assert(mmio_awsize_1 == AXI_DUAL_PORT_AXI_SIZE_32B);
    }
    if(mmio_awvalid_2)
    {
      assert(mmio_awaddr_2 == addr);
      assert(mmio_awlen_2 == 0u);
      assert(mmio_awsize_2 == AXI_DUAL_PORT_AXI_SIZE_32B);
    }
    if(mmio_awvalid_3)
    {
      assert(mmio_awaddr_3 == addr);
      assert(mmio_awlen_3 == 0u);
      assert(mmio_awsize_3 == AXI_DUAL_PORT_AXI_SIZE_32B);
    }
    if(mmio_wvalid_1)
    {
      assert(mmio_wstrb_1 == line_wstrb);
      assert(mmio_wlast_1);
    }
    if(mmio_wvalid_2)
    {
      assert(mmio_wstrb_2 == line_wstrb);
      assert(mmio_wlast_2);
    }
    if(mmio_wvalid_3)
    {
      assert(mmio_wstrb_3 == line_wstrb);
      assert(mmio_wlast_3);
    }
  }

  if(!route.supported)
  {
    assert(!ddr_awvalid_1);
    assert(!ddr_awvalid_2);
    assert(!ddr_awvalid_3);
    assert(!ddr_wvalid_1);
    assert(!ddr_wvalid_2);
    assert(!ddr_wvalid_3);
    assert(!mmio_awvalid_1);
    assert(!mmio_awvalid_2);
    assert(!mmio_awvalid_3);
    assert(!mmio_wvalid_1);
    assert(!mmio_wvalid_2);
    assert(!mmio_wvalid_3);
  }
}
