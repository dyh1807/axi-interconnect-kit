#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

uint32_t nondet_uint32_t(void);
uint8_t nondet_uint8_t(void);

struct module_axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top
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
  uint64_t cache_resp_rdata_lo;
  uint64_t cache_resp_rdata_hi;
  uint8_t cache_resp_id;
  uint8_t cache_resp_code;
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
  bool mmio_axi_rready;
};

extern struct module_axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top;

static void drive_idle(void)
{
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.cache_req_valid =
      false;
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.cache_req_write =
      false;
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.cache_req_addr = 0u;
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.cache_req_id = 0u;
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.cache_req_size = 15u;
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_rvalid =
      false;
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_rid = 0u;
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_rdata = 0u;
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_rresp = 0u;
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_rlast =
      false;
}

static void check_ar_snapshot(bool ddr_arvalid, uint32_t ddr_araddr,
                              uint8_t ddr_arlen, uint8_t ddr_arsize,
                              bool mmio_arvalid, uint32_t addr)
{
  assert(!mmio_arvalid);
  if(ddr_arvalid)
  {
    assert(ddr_araddr == addr);
    assert(ddr_arlen == 1u);
    assert(ddr_arsize == 3u);
  }
}

int main(void)
{
  const uint32_t addr = 0x40000000u + (nondet_uint32_t() & 0x0000fff0u);
  const uint8_t req_id = nondet_uint8_t() & 0x3fu;
  const uint64_t beat0 =
      ((uint64_t)nondet_uint32_t() << 32u) | nondet_uint32_t();
  const uint64_t beat1 =
      ((uint64_t)nondet_uint32_t() << 32u) | nondet_uint32_t();
  const uint8_t resp0 = nondet_uint8_t() & 3u;
  const uint8_t resp1 = nondet_uint8_t() & 3u;
  const uint8_t final_resp = (resp1 != 0u) ? resp1 : resp0;

  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.rst_n = false;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.rst_n = true;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.cache_req_valid = true;
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.cache_req_write =
      false;
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.cache_req_addr = addr;
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.cache_req_id = req_id;
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.cache_req_size = 15u;
  set_inputs();

  assert(axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top
             .cache_req_ready);

  next_timeframe();
  set_inputs();
  const bool arvalid_1 =
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_arvalid;
  const uint8_t arid_1 =
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_arid;
  check_ar_snapshot(
      arvalid_1,
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_araddr,
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_arlen,
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_arsize,
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.mmio_axi_arvalid,
      addr);

  drive_idle();
  set_inputs();
  next_timeframe();
  set_inputs();
  const bool arvalid_2 =
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_arvalid;
  const uint8_t arid_2 =
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_arid;
  check_ar_snapshot(
      arvalid_2,
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_araddr,
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_arlen,
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_arsize,
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.mmio_axi_arvalid,
      addr);

  drive_idle();
  set_inputs();
  next_timeframe();
  set_inputs();
  const bool arvalid_3 =
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_arvalid;
  const uint8_t arid_3 =
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_arid;
  check_ar_snapshot(
      arvalid_3,
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_araddr,
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_arlen,
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_arsize,
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.mmio_axi_arvalid,
      addr);

  drive_idle();
  set_inputs();
  next_timeframe();
  set_inputs();
  const bool arvalid_4 =
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_arvalid;
  const uint8_t arid_4 =
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_arid;
  check_ar_snapshot(
      arvalid_4,
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_araddr,
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_arlen,
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_arsize,
      axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.mmio_axi_arvalid,
      addr);

  const bool seen_ar = arvalid_1 || arvalid_2 || arvalid_3 || arvalid_4;
  const uint8_t arid =
      arvalid_1 ? arid_1 : (arvalid_2 ? arid_2 :
                            (arvalid_3 ? arid_3 : arid_4));
  assert(seen_ar);

  drive_idle();
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_rvalid = true;
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_rid = arid;
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_rdata = beat0;
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_rresp = resp0;
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_rlast = false;
  set_inputs();

  assert(axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_rready);
  assert(!axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top
              .mmio_axi_rready);

  next_timeframe();
  drive_idle();
  set_inputs();
  assert(!axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top
              .cache_resp_valid);

  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_rvalid = true;
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_rid = arid;
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_rdata = beat1;
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_rresp = resp1;
  axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_rlast = true;
  set_inputs();

  assert(axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.ddr_axi_rready);
  assert(!axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top
              .mmio_axi_rready);

  next_timeframe();
  drive_idle();
  set_inputs();

  assert(axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top
             .cache_resp_valid);
  assert(axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top.cache_resp_id ==
         req_id);
  assert(axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top
             .cache_resp_code == final_resp);
  assert(axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top
             .cache_resp_rdata_lo == beat0);
  assert(axi_llc_axi_bridge_dual_ddr_multibeat_read_formal_top
             .cache_resp_rdata_hi == beat1);
}
