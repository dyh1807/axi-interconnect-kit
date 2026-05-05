#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

uint32_t nondet_uint32_t(void);
uint8_t nondet_uint8_t(void);

struct module_axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
{
  bool clk;
  bool rst_n;
  bool cache_req_valid;
  bool cache_req_write;
  uint32_t cache_req_addr;
  uint8_t cache_req_id;
  uint8_t cache_req_size;
  uint64_t cache_req_wdata;
  uint8_t cache_req_wstrb;
  bool cache_req_ready;
  bool ddr_axi_arvalid;
  uint32_t ddr_axi_araddr;
  bool ddr_axi_awvalid;
  uint8_t ddr_axi_awid;
  uint32_t ddr_axi_awaddr;
  bool ddr_axi_wvalid;
  bool ddr_axi_wlast;
  bool ddr_axi_bvalid;
  bool ddr_axi_bready;
  uint8_t ddr_axi_bid;
  uint8_t ddr_axi_bresp;
  bool mmio_axi_arvalid;
  bool mmio_axi_awvalid;
  bool mmio_axi_wvalid;
};

extern struct
    module_axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
        axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top;

static void drive_idle(void)
{
  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
      .cache_req_valid = false;
  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
      .cache_req_write = false;
  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
      .cache_req_addr = 0u;
  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top.cache_req_id =
      0u;
  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
      .cache_req_size = 7u;
  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
      .cache_req_wdata = 0u;
  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
      .cache_req_wstrb = 0u;
  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top.ddr_axi_bvalid =
      false;
  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top.ddr_axi_bid =
      0u;
  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top.ddr_axi_bresp =
      0u;
}

static void check_write_snapshot(bool awvalid, uint32_t awaddr, bool wvalid,
                                 bool wlast, bool mmio_awvalid,
                                 bool mmio_wvalid, uint32_t expected_addr)
{
  assert(!mmio_awvalid);
  assert(!mmio_wvalid);
  if(awvalid)
  {
    assert(awaddr == expected_addr);
  }
  if(wvalid)
  {
    assert(wlast);
  }
}

static void check_no_read_issue(void)
{
  assert(!axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
              .ddr_axi_arvalid);
  assert(!axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
              .mmio_axi_arvalid);
}

static void check_ar_snapshot(bool arvalid, uint32_t araddr, bool mmio_arvalid,
                              uint32_t expected_addr)
{
  assert(!mmio_arvalid);
  if(arvalid)
  {
    assert(araddr == expected_addr);
  }
}

int main(void)
{
  const uint32_t addr = 0x40000000u + (nondet_uint32_t() & 0x0000fff8u);
  const uint8_t write_id = nondet_uint8_t() & 0x3fu;
  const uint8_t read_id = nondet_uint8_t() & 0x3fu;
  const uint64_t wdata =
      ((uint64_t)nondet_uint32_t() << 32u) | nondet_uint32_t();

  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top.rst_n = false;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top.rst_n = true;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
      .cache_req_valid = true;
  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
      .cache_req_write = true;
  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top.cache_req_addr =
      addr;
  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top.cache_req_id =
      write_id;
  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top.cache_req_size =
      7u;
  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top.cache_req_wdata =
      wdata;
  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top.cache_req_wstrb =
      0xffu;
  set_inputs();
  assert(axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
             .cache_req_ready);

  next_timeframe();
  set_inputs();
  const bool awvalid_1 =
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .ddr_axi_awvalid;
  const uint8_t awid_1 =
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .ddr_axi_awid;
  const bool wvalid_1 =
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .ddr_axi_wvalid;
  check_write_snapshot(
      awvalid_1,
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .ddr_axi_awaddr,
      wvalid_1,
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .ddr_axi_wlast,
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .mmio_axi_awvalid,
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .mmio_axi_wvalid,
      addr);

  drive_idle();
  set_inputs();
  next_timeframe();
  set_inputs();
  const bool awvalid_2 =
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .ddr_axi_awvalid;
  const uint8_t awid_2 =
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .ddr_axi_awid;
  const bool wvalid_2 =
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .ddr_axi_wvalid;
  check_write_snapshot(
      awvalid_2,
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .ddr_axi_awaddr,
      wvalid_2,
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .ddr_axi_wlast,
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .mmio_axi_awvalid,
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .mmio_axi_wvalid,
      addr);

  drive_idle();
  set_inputs();
  next_timeframe();
  set_inputs();
  const bool awvalid_3 =
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .ddr_axi_awvalid;
  const uint8_t awid_3 =
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .ddr_axi_awid;
  const bool wvalid_3 =
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .ddr_axi_wvalid;
  check_write_snapshot(
      awvalid_3,
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .ddr_axi_awaddr,
      wvalid_3,
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .ddr_axi_wlast,
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .mmio_axi_awvalid,
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .mmio_axi_wvalid,
      addr);

  const bool seen_aw = awvalid_1 || awvalid_2 || awvalid_3;
  const bool seen_w = wvalid_1 || wvalid_2 || wvalid_3;
  const uint8_t awid =
      awvalid_1 ? awid_1 : (awvalid_2 ? awid_2 : awid_3);
  assert(seen_aw);
  assert(seen_w);

  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
      .cache_req_valid = true;
  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
      .cache_req_write = false;
  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top.cache_req_addr =
      addr;
  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top.cache_req_id =
      read_id;
  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top.cache_req_size =
      7u;
  set_inputs();
  assert(axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
             .cache_req_ready);
  check_no_read_issue();

  next_timeframe();
  drive_idle();
  set_inputs();
  check_no_read_issue();

  next_timeframe();
  drive_idle();
  set_inputs();
  check_no_read_issue();

  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top.ddr_axi_bvalid =
      true;
  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top.ddr_axi_bid =
      awid;
  axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top.ddr_axi_bresp =
      0u;
  set_inputs();
  assert(axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
             .ddr_axi_bready);

  next_timeframe();
  drive_idle();
  set_inputs();
  const bool arvalid_1 =
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .ddr_axi_arvalid;
  check_ar_snapshot(
      arvalid_1,
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .ddr_axi_araddr,
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .mmio_axi_arvalid,
      addr);

  next_timeframe();
  drive_idle();
  set_inputs();
  const bool arvalid_2 =
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .ddr_axi_arvalid;
  check_ar_snapshot(
      arvalid_2,
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .ddr_axi_araddr,
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .mmio_axi_arvalid,
      addr);

  next_timeframe();
  drive_idle();
  set_inputs();
  const bool arvalid_3 =
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .ddr_axi_arvalid;
  check_ar_snapshot(
      arvalid_3,
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .ddr_axi_araddr,
      axi_llc_axi_bridge_dual_same_line_write_blocks_read_formal_top
          .mmio_axi_arvalid,
      addr);

  assert(arvalid_1 || arvalid_2 || arvalid_3);
}
