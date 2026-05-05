#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void next_timeframe(void);
void set_inputs(void);

uint32_t nondet_uint32_t(void);
uint8_t nondet_uint8_t(void);

struct module_axi_llc_axi_bridge_dual_write_b_response_formal_top
{
  bool clk;
  bool rst_n;
  bool cache_req_valid;
  bool cache_req_write;
  uint32_t cache_req_addr;
  uint8_t cache_req_id;
  uint8_t cache_req_size;
  uint8_t cache_req_wstrb;
  bool cache_req_ready;
  bool cache_resp_valid;
  uint8_t cache_resp_id;
  uint8_t cache_resp_code;
  bool ddr_axi_awvalid;
  uint8_t ddr_axi_awid;
  bool ddr_axi_wvalid;
  bool ddr_axi_wlast;
  bool ddr_axi_bvalid;
  bool ddr_axi_bready;
  uint8_t ddr_axi_bid;
  uint8_t ddr_axi_bresp;
  bool mmio_axi_awvalid;
  uint8_t mmio_axi_awid;
  bool mmio_axi_wvalid;
  bool mmio_axi_wlast;
  bool mmio_axi_bvalid;
  bool mmio_axi_bready;
  uint8_t mmio_axi_bid;
  uint8_t mmio_axi_bresp;
};

extern struct module_axi_llc_axi_bridge_dual_write_b_response_formal_top
  axi_llc_axi_bridge_dual_write_b_response_formal_top;

static void drive_idle(void)
{
  axi_llc_axi_bridge_dual_write_b_response_formal_top.cache_req_valid = false;
  axi_llc_axi_bridge_dual_write_b_response_formal_top.cache_req_write = true;
  axi_llc_axi_bridge_dual_write_b_response_formal_top.cache_req_addr = 0u;
  axi_llc_axi_bridge_dual_write_b_response_formal_top.cache_req_id = 0u;
  axi_llc_axi_bridge_dual_write_b_response_formal_top.cache_req_size =
      AXI_DUAL_PORT_MMIO_TOTAL_SIZE;
  axi_llc_axi_bridge_dual_write_b_response_formal_top.cache_req_wstrb = 0u;
  axi_llc_axi_bridge_dual_write_b_response_formal_top.ddr_axi_bvalid = false;
  axi_llc_axi_bridge_dual_write_b_response_formal_top.ddr_axi_bid = 0u;
  axi_llc_axi_bridge_dual_write_b_response_formal_top.ddr_axi_bresp = 0u;
  axi_llc_axi_bridge_dual_write_b_response_formal_top.mmio_axi_bvalid = false;
  axi_llc_axi_bridge_dual_write_b_response_formal_top.mmio_axi_bid = 0u;
  axi_llc_axi_bridge_dual_write_b_response_formal_top.mmio_axi_bresp = 0u;
}

int main(void)
{
  const uint32_t addr = nondet_uint32_t() & ~3u;
  const uint8_t req_id = nondet_uint8_t() & 0x3fu;
  const uint8_t bresp = nondet_uint8_t() & 3u;
  const uint8_t total_size = AXI_DUAL_PORT_MMIO_TOTAL_SIZE;
  const uint8_t line_wstrb = 0x0fu;
  const AxiDualPortRouteSupport route =
      axi_dual_port_route_support(addr, total_size, 0x40000000u);

  axi_llc_axi_bridge_dual_write_b_response_formal_top.rst_n = false;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_write_b_response_formal_top.rst_n = true;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_write_b_response_formal_top.cache_req_valid = true;
  axi_llc_axi_bridge_dual_write_b_response_formal_top.cache_req_write = true;
  axi_llc_axi_bridge_dual_write_b_response_formal_top.cache_req_addr = addr;
  axi_llc_axi_bridge_dual_write_b_response_formal_top.cache_req_id = req_id;
  axi_llc_axi_bridge_dual_write_b_response_formal_top.cache_req_size =
      total_size;
  axi_llc_axi_bridge_dual_write_b_response_formal_top.cache_req_wstrb =
      line_wstrb;
  set_inputs();

  assert(axi_llc_axi_bridge_dual_write_b_response_formal_top.cache_req_ready ==
         route.supported);

  next_timeframe();
  set_inputs();

  const bool ddr_awvalid_1 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.ddr_axi_awvalid;
  const uint8_t ddr_awid_1 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.ddr_axi_awid;
  const bool ddr_wvalid_1 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.ddr_axi_wvalid;
  const bool ddr_wlast_1 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.ddr_axi_wlast;
  const bool mmio_awvalid_1 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.mmio_axi_awvalid;
  const uint8_t mmio_awid_1 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.mmio_axi_awid;
  const bool mmio_wvalid_1 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.mmio_axi_wvalid;
  const bool mmio_wlast_1 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.mmio_axi_wlast;

  drive_idle();
  set_inputs();
  next_timeframe();
  set_inputs();

  const bool ddr_awvalid_2 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.ddr_axi_awvalid;
  const uint8_t ddr_awid_2 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.ddr_axi_awid;
  const bool ddr_wvalid_2 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.ddr_axi_wvalid;
  const bool ddr_wlast_2 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.ddr_axi_wlast;
  const bool mmio_awvalid_2 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.mmio_axi_awvalid;
  const uint8_t mmio_awid_2 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.mmio_axi_awid;
  const bool mmio_wvalid_2 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.mmio_axi_wvalid;
  const bool mmio_wlast_2 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.mmio_axi_wlast;

  next_timeframe();
  set_inputs();

  const bool ddr_awvalid_3 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.ddr_axi_awvalid;
  const uint8_t ddr_awid_3 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.ddr_axi_awid;
  const bool ddr_wvalid_3 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.ddr_axi_wvalid;
  const bool ddr_wlast_3 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.ddr_axi_wlast;
  const bool mmio_awvalid_3 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.mmio_axi_awvalid;
  const uint8_t mmio_awid_3 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.mmio_axi_awid;
  const bool mmio_wvalid_3 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.mmio_axi_wvalid;
  const bool mmio_wlast_3 =
      axi_llc_axi_bridge_dual_write_b_response_formal_top.mmio_axi_wlast;

  const uint8_t ddr_bid =
      ddr_awvalid_1 ? ddr_awid_1 : (ddr_awvalid_2 ? ddr_awid_2 : ddr_awid_3);
  const uint8_t mmio_bid =
      mmio_awvalid_1 ? mmio_awid_1 :
                       (mmio_awvalid_2 ? mmio_awid_2 : mmio_awid_3);

  if(route.ddr_port)
  {
    assert(ddr_awvalid_1 || ddr_awvalid_2 || ddr_awvalid_3);
    assert(ddr_wvalid_1 || ddr_wvalid_2 || ddr_wvalid_3);
    if(ddr_wvalid_1)
    {
      assert(ddr_wlast_1);
    }
    if(ddr_wvalid_2)
    {
      assert(ddr_wlast_2);
    }
    if(ddr_wvalid_3)
    {
      assert(ddr_wlast_3);
    }
    assert(!mmio_awvalid_1);
    assert(!mmio_awvalid_2);
    assert(!mmio_awvalid_3);
    assert(!mmio_wvalid_1);
    assert(!mmio_wvalid_2);
    assert(!mmio_wvalid_3);
  }
  else
  {
    assert(!ddr_awvalid_1);
    assert(!ddr_awvalid_2);
    assert(!ddr_awvalid_3);
    assert(!ddr_wvalid_1);
    assert(!ddr_wvalid_2);
    assert(!ddr_wvalid_3);
    assert(mmio_awvalid_1 || mmio_awvalid_2 || mmio_awvalid_3);
    assert(mmio_wvalid_1 || mmio_wvalid_2 || mmio_wvalid_3);
    if(mmio_wvalid_1)
    {
      assert(mmio_wlast_1);
    }
    if(mmio_wvalid_2)
    {
      assert(mmio_wlast_2);
    }
    if(mmio_wvalid_3)
    {
      assert(mmio_wlast_3);
    }
  }

  drive_idle();
  set_inputs();
  next_timeframe();

  drive_idle();
  if(route.ddr_port)
  {
    axi_llc_axi_bridge_dual_write_b_response_formal_top.ddr_axi_bvalid = true;
    axi_llc_axi_bridge_dual_write_b_response_formal_top.ddr_axi_bid = ddr_bid;
    axi_llc_axi_bridge_dual_write_b_response_formal_top.ddr_axi_bresp = bresp;
  }
  else
  {
    axi_llc_axi_bridge_dual_write_b_response_formal_top.mmio_axi_bvalid = true;
    axi_llc_axi_bridge_dual_write_b_response_formal_top.mmio_axi_bid =
        mmio_bid;
    axi_llc_axi_bridge_dual_write_b_response_formal_top.mmio_axi_bresp = bresp;
  }
  set_inputs();

  if(route.ddr_port)
  {
    assert(axi_llc_axi_bridge_dual_write_b_response_formal_top.ddr_axi_bready);
    assert(!axi_llc_axi_bridge_dual_write_b_response_formal_top
                .mmio_axi_bready);
  }
  else
  {
    assert(!axi_llc_axi_bridge_dual_write_b_response_formal_top
                .ddr_axi_bready);
    assert(axi_llc_axi_bridge_dual_write_b_response_formal_top.mmio_axi_bready);
  }

  next_timeframe();
  drive_idle();
  set_inputs();

  assert(axi_llc_axi_bridge_dual_write_b_response_formal_top.cache_resp_valid);
  assert(axi_llc_axi_bridge_dual_write_b_response_formal_top.cache_resp_id ==
         req_id);
  assert(axi_llc_axi_bridge_dual_write_b_response_formal_top.cache_resp_code ==
         bresp);
}
