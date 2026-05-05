#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

uint32_t nondet_uint32_t(void);
uint8_t nondet_uint8_t(void);

struct module_axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top
{
  bool clk;
  bool rst_n;
  bool bypass_req_valid;
  uint32_t bypass_req_addr;
  uint8_t bypass_req_id;
  uint32_t bypass_req_wdata;
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
  uint64_t ddr_axi_wdata_0;
  uint64_t ddr_axi_wdata_1;
  uint64_t ddr_axi_wdata_2;
  uint64_t ddr_axi_wdata_3;
  uint32_t ddr_axi_wstrb;
  bool ddr_axi_wlast;
  bool ddr_axi_bvalid;
  bool ddr_axi_bready;
  uint8_t ddr_axi_bid;
  uint8_t ddr_axi_bresp;
  bool mmio_axi_awvalid;
  bool mmio_axi_wvalid;
};

extern struct module_axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top
    axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top;

typedef struct ExpectedWrite256
{
  uint64_t data_0;
  uint64_t data_1;
  uint64_t data_2;
  uint64_t data_3;
  uint32_t strb;
} ExpectedWrite256;

static uint64_t set_byte64(uint64_t value, uint8_t byte_index,
                           uint8_t byte_value)
{
  const uint64_t mask = 0xffull << ((uint32_t)byte_index * 8u);
  return (value & ~mask) | ((uint64_t)byte_value << ((uint32_t)byte_index * 8u));
}

static ExpectedWrite256 expected_write(uint32_t wdata, uint8_t offset)
{
  ExpectedWrite256 out = {0u, 0u, 0u, 0u, (uint32_t)0x0fu << offset};

  for(uint8_t src = 0u; src < 4u; src++)
  {
    const uint8_t dst = offset + src;
    const uint8_t chunk_byte = dst & 7u;
    const uint8_t byte_value = (uint8_t)((wdata >> ((uint32_t)src * 8u)) & 0xffu);
    if(dst < 8u)
      out.data_0 = set_byte64(out.data_0, chunk_byte, byte_value);
    else if(dst < 16u)
      out.data_1 = set_byte64(out.data_1, chunk_byte, byte_value);
    else if(dst < 24u)
      out.data_2 = set_byte64(out.data_2, chunk_byte, byte_value);
    else
      out.data_3 = set_byte64(out.data_3, chunk_byte, byte_value);
  }

  return out;
}

static void drive_idle(void)
{
  axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.bypass_req_valid =
      false;
  axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.bypass_req_addr = 0u;
  axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.bypass_req_id = 0u;
  axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.bypass_req_wdata = 0u;
  axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.bypass_req_wstrb = 0u;
  axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_bvalid =
      false;
  axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_bid = 0u;
  axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_bresp = 0u;
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
    assert(awsize == 5u);
  }
}

static void check_w_snapshot(bool wvalid, uint64_t data_0, uint64_t data_1,
                             uint64_t data_2, uint64_t data_3,
                             uint32_t wstrb, bool wlast, bool mmio_wvalid,
                             ExpectedWrite256 expected)
{
  assert(!mmio_wvalid);
  if(wvalid)
  {
    assert(data_0 == expected.data_0);
    assert(data_1 == expected.data_1);
    assert(data_2 == expected.data_2);
    assert(data_3 == expected.data_3);
    assert(wstrb == expected.strb);
    assert(wlast);
  }
}

int main(void)
{
  const uint32_t issue_addr = 0x40000000u + (nondet_uint32_t() & 0x0000ffe0u);
  const uint8_t offset = nondet_uint8_t() % 29u;
  const uint32_t req_addr = issue_addr + offset;
  const uint8_t req_id = nondet_uint8_t() & 0x3fu;
  const uint32_t wdata = nondet_uint32_t();
  const uint8_t bresp = nondet_uint8_t() & 3u;
  const ExpectedWrite256 expected = expected_write(wdata, offset);

  axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.rst_n = false;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.rst_n = true;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.bypass_req_valid =
      true;
  axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.bypass_req_addr =
      req_addr;
  axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.bypass_req_id =
      req_id;
  axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.bypass_req_wdata =
      wdata;
  axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.bypass_req_wstrb =
      0x0fu;
  set_inputs();
  assert(axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top
             .bypass_req_ready);

  next_timeframe();
  set_inputs();
  const bool awvalid_1 =
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_awvalid;
  const uint8_t awid_1 =
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_awid;
  const bool wvalid_1 =
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_wvalid;
  check_aw_snapshot(
      awvalid_1,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_awaddr,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_awlen,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_awsize,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.mmio_axi_awvalid,
      issue_addr);
  check_w_snapshot(
      wvalid_1,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_wdata_0,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_wdata_1,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_wdata_2,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_wdata_3,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_wstrb,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_wlast,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.mmio_axi_wvalid,
      expected);

  drive_idle();
  set_inputs();
  next_timeframe();
  set_inputs();
  const bool awvalid_2 =
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_awvalid;
  const uint8_t awid_2 =
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_awid;
  const bool wvalid_2 =
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_wvalid;
  check_aw_snapshot(
      awvalid_2,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_awaddr,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_awlen,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_awsize,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.mmio_axi_awvalid,
      issue_addr);
  check_w_snapshot(
      wvalid_2,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_wdata_0,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_wdata_1,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_wdata_2,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_wdata_3,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_wstrb,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_wlast,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.mmio_axi_wvalid,
      expected);

  drive_idle();
  set_inputs();
  next_timeframe();
  set_inputs();
  const bool awvalid_3 =
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_awvalid;
  const uint8_t awid_3 =
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_awid;
  const bool wvalid_3 =
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_wvalid;
  check_aw_snapshot(
      awvalid_3,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_awaddr,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_awlen,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_awsize,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.mmio_axi_awvalid,
      issue_addr);
  check_w_snapshot(
      wvalid_3,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_wdata_0,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_wdata_1,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_wdata_2,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_wdata_3,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_wstrb,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_wlast,
      axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.mmio_axi_wvalid,
      expected);

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
  axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_bvalid =
      true;
  axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_bid = awid;
  axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top.ddr_axi_bresp =
      bresp;
  set_inputs();
  assert(axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top
             .ddr_axi_bready);

  next_timeframe();
  drive_idle();
  set_inputs();
  assert(axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top
             .bypass_resp_valid);
  assert(axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top
             .bypass_resp_id == req_id);
  assert(axi_llc_axi_bridge_dual_prod_width_mode2_write_formal_top
             .bypass_resp_code == bresp);
}
