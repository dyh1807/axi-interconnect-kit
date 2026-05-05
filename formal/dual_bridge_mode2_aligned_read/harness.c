#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void next_timeframe(void);
void set_inputs(void);

uint32_t nondet_uint32_t(void);
uint8_t nondet_uint8_t(void);

struct module_axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top
{
  bool clk;
  bool rst_n;
  bool bypass_req_valid;
  uint32_t bypass_req_addr;
  uint8_t bypass_req_id;
  bool bypass_req_ready;
  bool bypass_resp_valid;
  uint64_t bypass_resp_rdata;
  uint8_t bypass_resp_id;
  uint8_t bypass_resp_code;
  bool ddr_axi_arvalid;
  uint8_t ddr_axi_arid;
  uint32_t ddr_axi_araddr;
  uint8_t ddr_axi_arlen;
  uint8_t ddr_axi_arsize;
  bool ddr_axi_rvalid;
  bool ddr_axi_rready;
  uint8_t ddr_axi_rid;
  uint64_t ddr_axi_rdata;
  uint8_t ddr_axi_rresp;
  bool ddr_axi_rlast;
  bool mmio_axi_arvalid;
};

extern struct module_axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top
    axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top;

static void drive_idle(void)
{
  axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.bypass_req_valid =
      false;
  axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.bypass_req_addr = 0u;
  axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.bypass_req_id = 0u;
  axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_rvalid = false;
  axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_rid = 0u;
  axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_rdata = 0u;
  axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_rresp = 0u;
  axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_rlast = false;
}

static void check_ar_snapshot(bool arvalid, uint8_t arid, uint32_t araddr,
                              uint8_t arlen, uint8_t arsize,
                              bool mmio_arvalid, uint32_t expected_issue_addr)
{
  assert(!mmio_arvalid);
  if(arvalid)
  {
    assert(araddr == expected_issue_addr);
    assert(arlen == 0u);
    assert(arsize == 3u);
    (void)arid;
  }
}

int main(void)
{
  const uint32_t issue_addr = 0x40000000u + (nondet_uint32_t() & 0x0000fff8u);
  const uint32_t req_addr = issue_addr + 2u;
  const uint8_t req_id = nondet_uint8_t() & 0x3fu;
  const uint64_t beat_data =
      ((uint64_t)nondet_uint32_t() << 32u) | nondet_uint32_t();
  const uint8_t rresp = nondet_uint8_t() & 3u;
  const AxiBridgeReadPack64 expected =
      axi_bridge_read_pack64(0u, beat_data, req_addr, issue_addr, 0u, true, 8u,
                             8u);

  axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.rst_n = false;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.rst_n = true;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.bypass_req_valid = true;
  axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.bypass_req_addr =
      req_addr;
  axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.bypass_req_id = req_id;
  set_inputs();
  assert(axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top
             .bypass_req_ready);

  next_timeframe();
  set_inputs();
  const bool arvalid_1 =
      axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_arvalid;
  const uint8_t arid_1 =
      axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_arid;
  check_ar_snapshot(
      arvalid_1, arid_1,
      axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_araddr,
      axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_arlen,
      axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_arsize,
      axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.mmio_axi_arvalid,
      issue_addr);

  drive_idle();
  set_inputs();
  next_timeframe();
  set_inputs();
  const bool arvalid_2 =
      axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_arvalid;
  const uint8_t arid_2 =
      axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_arid;
  check_ar_snapshot(
      arvalid_2, arid_2,
      axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_araddr,
      axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_arlen,
      axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_arsize,
      axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.mmio_axi_arvalid,
      issue_addr);

  drive_idle();
  set_inputs();
  next_timeframe();
  set_inputs();
  const bool arvalid_3 =
      axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_arvalid;
  const uint8_t arid_3 =
      axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_arid;
  check_ar_snapshot(
      arvalid_3, arid_3,
      axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_araddr,
      axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_arlen,
      axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_arsize,
      axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.mmio_axi_arvalid,
      issue_addr);

  const bool seen_ar = arvalid_1 || arvalid_2 || arvalid_3;
  const uint8_t arid =
      arvalid_1 ? arid_1 : (arvalid_2 ? arid_2 : arid_3);
  assert(seen_ar);

  drive_idle();
  axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_rvalid = true;
  axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_rid = arid;
  axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_rdata =
      beat_data;
  axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_rresp = rresp;
  axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_rlast = true;
  set_inputs();
  assert(axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top.ddr_axi_rready);

  next_timeframe();
  drive_idle();
  set_inputs();
  assert(axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top
             .bypass_resp_valid);
  assert(axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top
             .bypass_resp_id == req_id);
  assert(axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top
             .bypass_resp_code == rresp);
  assert(axi_llc_axi_bridge_dual_mode2_aligned_read_formal_top
             .bypass_resp_rdata == expected.final_data);
}
