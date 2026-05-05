#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void next_timeframe(void);
void set_inputs(void);

uint32_t nondet_uint32_t(void);
uint8_t nondet_uint8_t(void);

struct module_axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
{
  bool clk;
  bool rst_n;
  bool bypass_req_valid;
  uint32_t bypass_req_addr;
  uint8_t bypass_req_size;
  bool bypass_req_mode2_ddr_aligned;
  bool ddr_axi_awready;
  bool ddr_axi_wready;
  bool mmio_axi_awready;
  bool mmio_axi_wready;
  bool bypass_req_ready;
  bool ddr_axi_awvalid;
  bool ddr_axi_awid;
  uint32_t ddr_axi_awaddr;
  uint8_t ddr_axi_awlen;
  uint8_t ddr_axi_awsize;
  uint8_t ddr_axi_awburst;
  bool ddr_axi_wvalid;
  bool ddr_axi_arvalid;
  bool mmio_axi_awvalid;
  bool mmio_axi_awid;
  uint32_t mmio_axi_awaddr;
  uint8_t mmio_axi_awlen;
  uint8_t mmio_axi_awsize;
  uint8_t mmio_axi_awburst;
  bool mmio_axi_wvalid;
  bool mmio_axi_arvalid;
};

extern struct
    module_axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
        axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top;

static uint8_t choose_ddr_size(uint8_t raw)
{
  switch(raw & 7u)
  {
    case 0u:
      return 0u;
    case 1u:
      return 1u;
    case 2u:
      return 3u;
    case 3u:
      return 7u;
    case 4u:
      return 15u;
    case 5u:
      return 31u;
    default:
      return 63u;
  }
}

static uint8_t choose_mmio_size(uint8_t raw)
{
  switch(raw & 3u)
  {
    case 0u:
      return 3u;
    case 1u:
      return 0u;
    case 2u:
      return 7u;
    default:
      return 63u;
  }
}

static void drive_idle(void)
{
  axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
      .bypass_req_valid = false;
  axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
      .bypass_req_addr = 0u;
  axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
      .bypass_req_size = 0u;
  axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
      .bypass_req_mode2_ddr_aligned = false;
}

static void hold_write_ready_low(void)
{
  axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
      .ddr_axi_awready = false;
  axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
      .ddr_axi_wready = false;
  axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
      .mmio_axi_awready = false;
  axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
      .mmio_axi_wready = false;
}

static void check_no_read_escape(void)
{
  assert(!axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
              .ddr_axi_arvalid);
  assert(!axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
              .mmio_axi_arvalid);
}

static void check_aw_against_ref(const AxiDualPortRouteShape *route,
                                 const AxiBridgeDownstreamIssueShape *ref)
{
  const bool ddr_awvalid =
      axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
          .ddr_axi_awvalid;
  const bool mmio_awvalid =
      axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
          .mmio_axi_awvalid;
  const bool ddr_wvalid =
      axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
          .ddr_axi_wvalid;
  const bool mmio_wvalid =
      axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
          .mmio_axi_wvalid;

  check_no_read_escape();
  assert(!(ddr_awvalid && mmio_awvalid));
  assert(!(ddr_wvalid && mmio_wvalid));

  if(ddr_awvalid)
  {
    assert(route->ddr_port);
    assert(axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
               .ddr_axi_awaddr == ref->issue_addr);
    assert(axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
               .ddr_axi_awlen == ref->axi_len);
    assert(axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
               .ddr_axi_awsize == ref->axi_size);
    assert(axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
               .ddr_axi_awburst == 1u);
  }

  if(mmio_awvalid)
  {
    assert(route->mmio_port);
    assert(axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
               .mmio_axi_awaddr == ref->issue_addr);
    assert(axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
               .mmio_axi_awlen == ref->axi_len);
    assert(axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
               .mmio_axi_awsize == ref->axi_size);
    assert(axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
               .mmio_axi_awburst == 1u);
  }

  if(ddr_wvalid)
  {
    assert(route->ddr_port);
  }
  if(mmio_wvalid)
  {
    assert(route->mmio_port);
  }
}

int main(void)
{
  const uint8_t raw = nondet_uint8_t();
  const bool ddr_case = (raw & 0x80u) != 0u;
  const uint32_t raw_addr = nondet_uint32_t();
  const uint32_t addr =
      ddr_case ? (0x40000000u + (raw_addr & 0x0000ffffu)) :
                 (0x10000000u + (raw_addr & 0x00000ffcu));
  const uint8_t total_size =
      ddr_case ? choose_ddr_size(raw) : choose_mmio_size(raw);
  const bool force_ddr_aligned = ddr_case;
  bool seen_aw = false;

  const AxiDualPortRouteShape route =
      axi_dual_port_route_shape(addr, total_size, 0x40000000u);
  const AxiBridgeDownstreamIssueShape ref =
      axi_bridge_downstream_write_issue_shape(route.mmio_port, addr,
                                              total_size, 64u, 32u,
                                              force_ddr_aligned);

  axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top.rst_n =
      false;
  drive_idle();
  hold_write_ready_low();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top.rst_n =
      true;
  drive_idle();
  hold_write_ready_low();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
      .bypass_req_valid = true;
  axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
      .bypass_req_addr = addr;
  axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
      .bypass_req_size = total_size;
  axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
      .bypass_req_mode2_ddr_aligned = force_ddr_aligned;
  hold_write_ready_low();
  set_inputs();

  assert(axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
             .bypass_req_ready == route.supported);
  check_aw_against_ref(&route, &ref);

  for(unsigned step = 0u; step < 6u; step++)
  {
    if(axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
           .ddr_axi_awvalid ||
       axi_llc_axi_bridge_dual_prod_helper_write_issue_shape_formal_top
           .mmio_axi_awvalid)
    {
      seen_aw = true;
    }

    next_timeframe();
    drive_idle();
    hold_write_ready_low();
    set_inputs();
    check_aw_against_ref(&route, &ref);
  }

  assert(seen_aw == route.supported);
}
