#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void next_timeframe(void);
void set_inputs(void);

uint32_t nondet_uint32_t(void);
uint8_t nondet_uint8_t(void);

struct module_axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top
{
  bool clk;
  bool rst_n;
  bool bypass_req_valid;
  uint32_t bypass_req_addr;
  uint8_t bypass_req_id;
  uint64_t bypass_req_wdata;
  uint8_t bypass_req_wstrb;
  bool bypass_req_ready;
  bool bypass_resp_valid;
  uint8_t bypass_resp_id;
  uint8_t bypass_resp_code;
  bool ddr_axi_awvalid;
  uint8_t ddr_axi_awid;
  uint32_t ddr_axi_awaddr;
  uint8_t ddr_axi_awlen;
  uint8_t ddr_axi_awsize;
  bool ddr_axi_wvalid;
  uint64_t ddr_axi_wdata;
  uint8_t ddr_axi_wstrb;
  bool ddr_axi_wlast;
  bool ddr_axi_bvalid;
  bool ddr_axi_bready;
  uint8_t ddr_axi_bid;
  uint8_t ddr_axi_bresp;
  bool mmio_axi_awvalid;
  bool mmio_axi_wvalid;
};

extern struct module_axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top
    axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top;

static void drive_idle(void)
{
  axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.bypass_req_valid =
      false;
  axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.bypass_req_addr = 0u;
  axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.bypass_req_id = 0u;
  axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.bypass_req_wdata = 0u;
  axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.bypass_req_wstrb = 0u;
  axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_bvalid =
      false;
  axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_bid = 0u;
  axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_bresp = 0u;
}

static void check_aw_snapshot(bool awvalid, uint32_t awaddr, uint8_t awlen,
                              uint8_t awsize, bool mmio_awvalid,
                              uint32_t expected_issue_addr)
{
  assert(!mmio_awvalid);
  if(awvalid)
  {
    assert(awaddr == expected_issue_addr);
    assert(awlen == 0u);
    assert(awsize == 3u);
  }
}

static void check_w_snapshot(bool wvalid, uint64_t wdata, uint8_t wstrb,
                             bool wlast, bool mmio_wvalid,
                             uint64_t expected_wdata,
                             uint8_t expected_wstrb)
{
  assert(!mmio_wvalid);
  if(wvalid)
  {
    assert(wdata == expected_wdata);
    assert(wstrb == expected_wstrb);
    assert(wlast);
  }
}

int main(void)
{
  const uint32_t issue_addr = 0x40000000u + (nondet_uint32_t() & 0x0000fff8u);
  const uint32_t req_addr = issue_addr + 2u;
  const uint8_t req_id = nondet_uint8_t() & 0x3fu;
  const uint64_t wdata =
      ((uint64_t)nondet_uint32_t() << 32u) | nondet_uint32_t();
  const uint8_t bresp = nondet_uint8_t() & 3u;
  const AxiBridgeWritePack64 expected =
      axi_bridge_write_pack64(wdata, 0x0fu, req_addr, issue_addr, 0u, true, 8u,
                              8u);

  axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.rst_n = false;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.rst_n = true;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.bypass_req_valid =
      true;
  axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.bypass_req_addr =
      req_addr;
  axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.bypass_req_id = req_id;
  axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.bypass_req_wdata =
      wdata;
  axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.bypass_req_wstrb =
      0x0fu;
  set_inputs();
  assert(axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top
             .bypass_req_ready);

  next_timeframe();
  set_inputs();
  const bool awvalid_1 =
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_awvalid;
  const uint8_t awid_1 =
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_awid;
  const bool wvalid_1 =
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_wvalid;
  check_aw_snapshot(
      awvalid_1,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_awaddr,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_awlen,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_awsize,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.mmio_axi_awvalid,
      issue_addr);
  check_w_snapshot(
      wvalid_1,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_wdata,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_wstrb,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_wlast,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.mmio_axi_wvalid,
      expected.axi_wdata, (uint8_t)expected.axi_wstrb);

  drive_idle();
  set_inputs();
  next_timeframe();
  set_inputs();
  const bool awvalid_2 =
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_awvalid;
  const uint8_t awid_2 =
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_awid;
  const bool wvalid_2 =
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_wvalid;
  check_aw_snapshot(
      awvalid_2,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_awaddr,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_awlen,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_awsize,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.mmio_axi_awvalid,
      issue_addr);
  check_w_snapshot(
      wvalid_2,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_wdata,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_wstrb,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_wlast,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.mmio_axi_wvalid,
      expected.axi_wdata, (uint8_t)expected.axi_wstrb);

  drive_idle();
  set_inputs();
  next_timeframe();
  set_inputs();
  const bool awvalid_3 =
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_awvalid;
  const uint8_t awid_3 =
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_awid;
  const bool wvalid_3 =
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_wvalid;
  check_aw_snapshot(
      awvalid_3,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_awaddr,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_awlen,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_awsize,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.mmio_axi_awvalid,
      issue_addr);
  check_w_snapshot(
      wvalid_3,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_wdata,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_wstrb,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_wlast,
      axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.mmio_axi_wvalid,
      expected.axi_wdata, (uint8_t)expected.axi_wstrb);

  const bool seen_aw = awvalid_1 || awvalid_2 || awvalid_3;
  const bool seen_w = wvalid_1 || wvalid_2 || wvalid_3;
  const uint8_t awid =
      awvalid_1 ? awid_1 : (awvalid_2 ? awid_2 : awid_3);
  assert(seen_aw);
  assert(seen_w);

  drive_idle();
  set_inputs();
  next_timeframe();

  drive_idle();
  axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_bvalid =
      true;
  axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_bid = awid;
  axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_bresp = bresp;
  set_inputs();
  assert(axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.ddr_axi_bready);

  next_timeframe();
  drive_idle();
  set_inputs();
  assert(axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top
             .bypass_resp_valid);
  assert(axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top.bypass_resp_id ==
         req_id);
  assert(axi_llc_axi_bridge_dual_mode2_aligned_write_formal_top
             .bypass_resp_code == bresp);
}
