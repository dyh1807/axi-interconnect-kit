#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

uint32_t nondet_uint32_t(void);

struct module_axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top
{
  bool clk;
  bool rst_n;
  bool cache_req_valid;
  bool cache_req_write;
  uint32_t cache_req_addr;
  uint8_t cache_req_size;
  uint64_t cache_req_wdata_lo;
  uint64_t cache_req_wdata_hi;
  uint16_t cache_req_wstrb;
  bool cache_req_ready;
  bool ddr_axi_awvalid;
  uint8_t ddr_axi_awid;
  uint32_t ddr_axi_awaddr;
  uint8_t ddr_axi_awlen;
  uint8_t ddr_axi_awsize;
  bool ddr_axi_wvalid;
  uint64_t ddr_axi_wdata;
  uint8_t ddr_axi_wstrb;
  bool ddr_axi_wlast;
  bool mmio_axi_awvalid;
  bool mmio_axi_wvalid;
};

extern struct module_axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top
  axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top;

static void drive_idle(void)
{
  axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.cache_req_valid =
      false;
  axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.cache_req_write =
      true;
  axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.cache_req_addr = 0u;
  axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.cache_req_size = 15u;
  axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.cache_req_wdata_lo =
      0u;
  axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.cache_req_wdata_hi =
      0u;
  axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.cache_req_wstrb =
      0u;
}

static void check_aw_snapshot(bool awvalid, uint32_t awaddr, uint8_t awlen,
                              uint8_t awsize, bool mmio_awvalid,
                              uint32_t addr)
{
  assert(!mmio_awvalid);
  if(awvalid)
  {
    assert(awaddr == addr);
    assert(awlen == 1u);
    assert(awsize == 3u);
  }
}

static void check_w_snapshot(bool wvalid, uint64_t wdata, uint8_t wstrb,
                             bool wlast, bool mmio_wvalid,
                             bool prior_w_seen, uint64_t wdata_lo,
                             uint64_t wdata_hi)
{
  assert(!mmio_wvalid);
  if(wvalid)
  {
    if(!prior_w_seen)
    {
      assert(!wlast);
      assert(wdata == wdata_lo);
      assert(wstrb == 0xffu);
    }
    else
    {
      assert(wlast);
      assert(wdata == wdata_hi);
      assert(wstrb == 0xffu);
    }
  }
}

int main(void)
{
  const uint32_t addr = 0x40000000u + (nondet_uint32_t() & 0x0000fff0u);
  const uint64_t wdata_lo =
      ((uint64_t)nondet_uint32_t() << 32u) | nondet_uint32_t();
  const uint64_t wdata_hi =
      ((uint64_t)nondet_uint32_t() << 32u) | nondet_uint32_t();
  bool prior_w_seen = false;

  axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.rst_n = false;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.rst_n = true;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.cache_req_valid =
      true;
  axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.cache_req_write =
      true;
  axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.cache_req_addr =
      addr;
  axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.cache_req_size = 15u;
  axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.cache_req_wdata_lo =
      wdata_lo;
  axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.cache_req_wdata_hi =
      wdata_hi;
  axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.cache_req_wstrb =
      0xffffu;
  set_inputs();

  assert(axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top
             .cache_req_ready);

  next_timeframe();
  set_inputs();
  const bool awvalid_1 =
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_awvalid;
  const bool wvalid_1 =
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_wvalid;
  check_aw_snapshot(
      awvalid_1,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_awaddr,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_awlen,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_awsize,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.mmio_axi_awvalid,
      addr);
  check_w_snapshot(
      wvalid_1,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_wdata,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_wstrb,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_wlast,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.mmio_axi_wvalid,
      prior_w_seen, wdata_lo, wdata_hi);
  prior_w_seen = prior_w_seen || wvalid_1;

  drive_idle();
  set_inputs();
  next_timeframe();
  set_inputs();
  const bool awvalid_2 =
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_awvalid;
  const bool wvalid_2 =
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_wvalid;
  check_aw_snapshot(
      awvalid_2,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_awaddr,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_awlen,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_awsize,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.mmio_axi_awvalid,
      addr);
  check_w_snapshot(
      wvalid_2,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_wdata,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_wstrb,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_wlast,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.mmio_axi_wvalid,
      prior_w_seen, wdata_lo, wdata_hi);
  prior_w_seen = prior_w_seen || wvalid_2;

  drive_idle();
  set_inputs();
  next_timeframe();
  set_inputs();
  const bool awvalid_3 =
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_awvalid;
  const bool wvalid_3 =
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_wvalid;
  check_aw_snapshot(
      awvalid_3,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_awaddr,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_awlen,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_awsize,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.mmio_axi_awvalid,
      addr);
  check_w_snapshot(
      wvalid_3,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_wdata,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_wstrb,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_wlast,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.mmio_axi_wvalid,
      prior_w_seen, wdata_lo, wdata_hi);
  prior_w_seen = prior_w_seen || wvalid_3;

  drive_idle();
  set_inputs();
  next_timeframe();
  set_inputs();
  const bool awvalid_4 =
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_awvalid;
  const bool wvalid_4 =
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_wvalid;
  check_aw_snapshot(
      awvalid_4,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_awaddr,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_awlen,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_awsize,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.mmio_axi_awvalid,
      addr);
  check_w_snapshot(
      wvalid_4,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_wdata,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_wstrb,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.ddr_axi_wlast,
      axi_llc_axi_bridge_dual_ddr_multibeat_write_formal_top.mmio_axi_wvalid,
      prior_w_seen, wdata_lo, wdata_hi);

  assert(awvalid_1 || awvalid_2 || awvalid_3 || awvalid_4);
  assert(wvalid_1 || wvalid_2 || wvalid_3 || wvalid_4);
  assert((wvalid_1 ? 1u : 0u) + (wvalid_2 ? 1u : 0u) +
             (wvalid_3 ? 1u : 0u) + (wvalid_4 ? 1u : 0u) ==
         2u);
}
