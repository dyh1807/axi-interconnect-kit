#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void next_timeframe(void);
void set_inputs(void);

uint32_t nondet_uint32_t(void);
uint8_t nondet_uint8_t(void);

struct module_axi_llc_axi_bridge_dual_read_r_response_formal_top
{
  bool clk;
  bool rst_n;
  bool cache_req_valid;
  bool cache_req_write;
  uint32_t cache_req_addr;
  uint8_t cache_req_id;
  uint8_t cache_req_size;
  bool cache_req_ready;
  bool cache_resp_valid;
  uint64_t cache_resp_rdata;
  uint8_t cache_resp_id;
  uint8_t cache_resp_code;
  bool ddr_axi_arvalid;
  uint8_t ddr_axi_arid;
  bool ddr_axi_rvalid;
  bool ddr_axi_rready;
  uint8_t ddr_axi_rid;
  uint64_t ddr_axi_rdata;
  uint8_t ddr_axi_rresp;
  bool ddr_axi_rlast;
  bool mmio_axi_arvalid;
  uint8_t mmio_axi_arid;
  bool mmio_axi_rvalid;
  bool mmio_axi_rready;
  uint8_t mmio_axi_rid;
  uint32_t mmio_axi_rdata;
  uint8_t mmio_axi_rresp;
  bool mmio_axi_rlast;
};

extern struct module_axi_llc_axi_bridge_dual_read_r_response_formal_top
  axi_llc_axi_bridge_dual_read_r_response_formal_top;

static void drive_idle(void)
{
  axi_llc_axi_bridge_dual_read_r_response_formal_top.cache_req_valid = false;
  axi_llc_axi_bridge_dual_read_r_response_formal_top.cache_req_write = false;
  axi_llc_axi_bridge_dual_read_r_response_formal_top.cache_req_addr = 0u;
  axi_llc_axi_bridge_dual_read_r_response_formal_top.cache_req_id = 0u;
  axi_llc_axi_bridge_dual_read_r_response_formal_top.cache_req_size =
      AXI_DUAL_PORT_MMIO_TOTAL_SIZE;
  axi_llc_axi_bridge_dual_read_r_response_formal_top.ddr_axi_rvalid = false;
  axi_llc_axi_bridge_dual_read_r_response_formal_top.ddr_axi_rid = 0u;
  axi_llc_axi_bridge_dual_read_r_response_formal_top.ddr_axi_rdata = 0u;
  axi_llc_axi_bridge_dual_read_r_response_formal_top.ddr_axi_rresp = 0u;
  axi_llc_axi_bridge_dual_read_r_response_formal_top.ddr_axi_rlast = false;
  axi_llc_axi_bridge_dual_read_r_response_formal_top.mmio_axi_rvalid = false;
  axi_llc_axi_bridge_dual_read_r_response_formal_top.mmio_axi_rid = 0u;
  axi_llc_axi_bridge_dual_read_r_response_formal_top.mmio_axi_rdata = 0u;
  axi_llc_axi_bridge_dual_read_r_response_formal_top.mmio_axi_rresp = 0u;
  axi_llc_axi_bridge_dual_read_r_response_formal_top.mmio_axi_rlast = false;
}

int main(void)
{
  const uint32_t addr = nondet_uint32_t() & ~3u;
  const uint8_t req_id = nondet_uint8_t() & 0x3fu;
  const uint64_t ddr_rdata =
      ((uint64_t)nondet_uint32_t() << 32u) | nondet_uint32_t();
  const uint32_t mmio_rdata = nondet_uint32_t();
  const uint8_t rresp = nondet_uint8_t() & 3u;
  const uint8_t total_size = AXI_DUAL_PORT_MMIO_TOTAL_SIZE;
  const AxiDualPortRouteSupport route =
      axi_dual_port_route_support(addr, total_size, 0x40000000u);

  axi_llc_axi_bridge_dual_read_r_response_formal_top.rst_n = false;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_read_r_response_formal_top.rst_n = true;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_read_r_response_formal_top.cache_req_valid = true;
  axi_llc_axi_bridge_dual_read_r_response_formal_top.cache_req_write = false;
  axi_llc_axi_bridge_dual_read_r_response_formal_top.cache_req_addr = addr;
  axi_llc_axi_bridge_dual_read_r_response_formal_top.cache_req_id = req_id;
  axi_llc_axi_bridge_dual_read_r_response_formal_top.cache_req_size =
      total_size;
  set_inputs();

  assert(axi_llc_axi_bridge_dual_read_r_response_formal_top.cache_req_ready ==
         route.supported);

  next_timeframe();
  set_inputs();

  const bool ddr_arvalid_1 =
      axi_llc_axi_bridge_dual_read_r_response_formal_top.ddr_axi_arvalid;
  const uint8_t ddr_arid_1 =
      axi_llc_axi_bridge_dual_read_r_response_formal_top.ddr_axi_arid;
  const bool mmio_arvalid_1 =
      axi_llc_axi_bridge_dual_read_r_response_formal_top.mmio_axi_arvalid;
  const uint8_t mmio_arid_1 =
      axi_llc_axi_bridge_dual_read_r_response_formal_top.mmio_axi_arid;

  drive_idle();
  set_inputs();
  next_timeframe();
  set_inputs();

  const bool ddr_arvalid_2 =
      axi_llc_axi_bridge_dual_read_r_response_formal_top.ddr_axi_arvalid;
  const uint8_t ddr_arid_2 =
      axi_llc_axi_bridge_dual_read_r_response_formal_top.ddr_axi_arid;
  const bool mmio_arvalid_2 =
      axi_llc_axi_bridge_dual_read_r_response_formal_top.mmio_axi_arvalid;
  const uint8_t mmio_arid_2 =
      axi_llc_axi_bridge_dual_read_r_response_formal_top.mmio_axi_arid;

  next_timeframe();
  set_inputs();

  const bool ddr_arvalid_3 =
      axi_llc_axi_bridge_dual_read_r_response_formal_top.ddr_axi_arvalid;
  const uint8_t ddr_arid_3 =
      axi_llc_axi_bridge_dual_read_r_response_formal_top.ddr_axi_arid;
  const bool mmio_arvalid_3 =
      axi_llc_axi_bridge_dual_read_r_response_formal_top.mmio_axi_arvalid;
  const uint8_t mmio_arid_3 =
      axi_llc_axi_bridge_dual_read_r_response_formal_top.mmio_axi_arid;

  const uint8_t ddr_rid =
      ddr_arvalid_1 ? ddr_arid_1 : (ddr_arvalid_2 ? ddr_arid_2 : ddr_arid_3);
  const uint8_t mmio_rid =
      mmio_arvalid_1 ? mmio_arid_1 :
                       (mmio_arvalid_2 ? mmio_arid_2 : mmio_arid_3);

  if(route.ddr_port)
  {
    assert(ddr_arvalid_1 || ddr_arvalid_2 || ddr_arvalid_3);
    assert(!mmio_arvalid_1);
    assert(!mmio_arvalid_2);
    assert(!mmio_arvalid_3);
  }
  else
  {
    assert(!ddr_arvalid_1);
    assert(!ddr_arvalid_2);
    assert(!ddr_arvalid_3);
    assert(mmio_arvalid_1 || mmio_arvalid_2 || mmio_arvalid_3);
  }

  drive_idle();
  set_inputs();
  next_timeframe();

  drive_idle();
  if(route.ddr_port)
  {
    axi_llc_axi_bridge_dual_read_r_response_formal_top.ddr_axi_rvalid = true;
    axi_llc_axi_bridge_dual_read_r_response_formal_top.ddr_axi_rid = ddr_rid;
    axi_llc_axi_bridge_dual_read_r_response_formal_top.ddr_axi_rdata =
        ddr_rdata;
    axi_llc_axi_bridge_dual_read_r_response_formal_top.ddr_axi_rresp = rresp;
    axi_llc_axi_bridge_dual_read_r_response_formal_top.ddr_axi_rlast = true;
  }
  else
  {
    axi_llc_axi_bridge_dual_read_r_response_formal_top.mmio_axi_rvalid = true;
    axi_llc_axi_bridge_dual_read_r_response_formal_top.mmio_axi_rid = mmio_rid;
    axi_llc_axi_bridge_dual_read_r_response_formal_top.mmio_axi_rdata =
        mmio_rdata;
    axi_llc_axi_bridge_dual_read_r_response_formal_top.mmio_axi_rresp = rresp;
    axi_llc_axi_bridge_dual_read_r_response_formal_top.mmio_axi_rlast = true;
  }
  set_inputs();

  if(route.ddr_port)
  {
    assert(axi_llc_axi_bridge_dual_read_r_response_formal_top.ddr_axi_rready);
    assert(!axi_llc_axi_bridge_dual_read_r_response_formal_top
                .mmio_axi_rready);
  }
  else
  {
    assert(!axi_llc_axi_bridge_dual_read_r_response_formal_top.ddr_axi_rready);
    assert(axi_llc_axi_bridge_dual_read_r_response_formal_top.mmio_axi_rready);
  }

  next_timeframe();
  drive_idle();
  set_inputs();

  assert(axi_llc_axi_bridge_dual_read_r_response_formal_top.cache_resp_valid);
  assert(axi_llc_axi_bridge_dual_read_r_response_formal_top.cache_resp_id ==
         req_id);
  assert(axi_llc_axi_bridge_dual_read_r_response_formal_top.cache_resp_code ==
         rresp);
  if(route.ddr_port)
  {
    assert(axi_llc_axi_bridge_dual_read_r_response_formal_top.cache_resp_rdata ==
           ddr_rdata);
  }
  else
  {
    assert(axi_llc_axi_bridge_dual_read_r_response_formal_top.cache_resp_rdata ==
           (uint64_t)mmio_rdata);
  }
}
