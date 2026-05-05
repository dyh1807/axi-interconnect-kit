#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void next_timeframe(void);
void set_inputs(void);

uint32_t nondet_uint32_t(void);
uint8_t nondet_uint8_t(void);

struct module_axi_llc_axi_bridge_dual_read_route_formal_top
{
  bool clk;
  bool rst_n;
  bool cache_req_valid;
  bool cache_req_write;
  uint32_t cache_req_addr;
  uint8_t cache_req_size;
  bool cache_req_ready;
  bool ddr_axi_arvalid;
  uint32_t ddr_axi_araddr;
  uint8_t ddr_axi_arlen;
  uint8_t ddr_axi_arsize;
  bool mmio_axi_arvalid;
  uint32_t mmio_axi_araddr;
  uint8_t mmio_axi_arlen;
  uint8_t mmio_axi_arsize;
};

extern struct module_axi_llc_axi_bridge_dual_read_route_formal_top
  axi_llc_axi_bridge_dual_read_route_formal_top;

int main(void)
{
  const uint32_t addr = nondet_uint32_t();
  const uint8_t total_size = nondet_uint8_t();
  const AxiDualPortRouteSupport route =
      axi_dual_port_route_support(addr, total_size, 0x40000000u);

  axi_llc_axi_bridge_dual_read_route_formal_top.rst_n = false;
  axi_llc_axi_bridge_dual_read_route_formal_top.cache_req_valid = false;
  axi_llc_axi_bridge_dual_read_route_formal_top.cache_req_write = false;
  axi_llc_axi_bridge_dual_read_route_formal_top.cache_req_addr = 0u;
  axi_llc_axi_bridge_dual_read_route_formal_top.cache_req_size = 0u;
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_read_route_formal_top.rst_n = true;
  axi_llc_axi_bridge_dual_read_route_formal_top.cache_req_valid = false;
  axi_llc_axi_bridge_dual_read_route_formal_top.cache_req_write = false;
  axi_llc_axi_bridge_dual_read_route_formal_top.cache_req_addr = 0u;
  axi_llc_axi_bridge_dual_read_route_formal_top.cache_req_size = 0u;
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_read_route_formal_top.cache_req_valid = true;
  axi_llc_axi_bridge_dual_read_route_formal_top.cache_req_write = false;
  axi_llc_axi_bridge_dual_read_route_formal_top.cache_req_addr = addr;
  axi_llc_axi_bridge_dual_read_route_formal_top.cache_req_size = total_size;
  set_inputs();

  assert(axi_llc_axi_bridge_dual_read_route_formal_top.cache_req_ready ==
         route.supported);

  next_timeframe();

  set_inputs();
  const bool ddr_arvalid_1 =
      axi_llc_axi_bridge_dual_read_route_formal_top.ddr_axi_arvalid;
  const bool mmio_arvalid_1 =
      axi_llc_axi_bridge_dual_read_route_formal_top.mmio_axi_arvalid;
  const uint32_t ddr_araddr_1 =
      axi_llc_axi_bridge_dual_read_route_formal_top.ddr_axi_araddr;
  const uint32_t mmio_araddr_1 =
      axi_llc_axi_bridge_dual_read_route_formal_top.mmio_axi_araddr;
  const uint8_t mmio_arlen_1 =
      axi_llc_axi_bridge_dual_read_route_formal_top.mmio_axi_arlen;
  const uint8_t mmio_arsize_1 =
      axi_llc_axi_bridge_dual_read_route_formal_top.mmio_axi_arsize;

  axi_llc_axi_bridge_dual_read_route_formal_top.cache_req_valid = false;
  set_inputs();
  next_timeframe();
  set_inputs();
  const bool ddr_arvalid_2 =
      axi_llc_axi_bridge_dual_read_route_formal_top.ddr_axi_arvalid;
  const bool mmio_arvalid_2 =
      axi_llc_axi_bridge_dual_read_route_formal_top.mmio_axi_arvalid;
  const uint32_t ddr_araddr_2 =
      axi_llc_axi_bridge_dual_read_route_formal_top.ddr_axi_araddr;
  const uint32_t mmio_araddr_2 =
      axi_llc_axi_bridge_dual_read_route_formal_top.mmio_axi_araddr;
  const uint8_t mmio_arlen_2 =
      axi_llc_axi_bridge_dual_read_route_formal_top.mmio_axi_arlen;
  const uint8_t mmio_arsize_2 =
      axi_llc_axi_bridge_dual_read_route_formal_top.mmio_axi_arsize;

  if(route.supported && route.ddr_port)
  {
    assert(ddr_arvalid_1 || ddr_arvalid_2);
    assert(!mmio_arvalid_1);
    assert(!mmio_arvalid_2);
    if(ddr_arvalid_1)
    {
      assert(ddr_araddr_1 == addr);
    }
    if(ddr_arvalid_2)
    {
      assert(ddr_araddr_2 == addr);
    }
  }

  if(route.supported && route.mmio_port)
  {
    assert(!ddr_arvalid_1);
    assert(!ddr_arvalid_2);
    assert(mmio_arvalid_1 || mmio_arvalid_2);
    if(mmio_arvalid_1)
    {
      assert(mmio_araddr_1 == addr);
      assert(mmio_arlen_1 == 0u);
      assert(mmio_arsize_1 == AXI_DUAL_PORT_AXI_SIZE_32B);
    }
    if(mmio_arvalid_2)
    {
      assert(mmio_araddr_2 == addr);
      assert(mmio_arlen_2 == 0u);
      assert(mmio_arsize_2 == AXI_DUAL_PORT_AXI_SIZE_32B);
    }
  }

  if(!route.supported)
  {
    assert(!ddr_arvalid_1);
    assert(!ddr_arvalid_2);
    assert(!mmio_arvalid_1);
    assert(!mmio_arvalid_2);
  }
}
