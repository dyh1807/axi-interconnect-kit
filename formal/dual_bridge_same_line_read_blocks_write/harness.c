#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

uint32_t nondet_uint32_t(void);
uint8_t nondet_uint8_t(void);

struct module_axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
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
  uint8_t ddr_axi_arid;
  uint32_t ddr_axi_araddr;
  bool ddr_axi_awvalid;
  uint32_t ddr_axi_awaddr;
  bool ddr_axi_wvalid;
  bool ddr_axi_wlast;
  bool ddr_axi_rvalid;
  bool ddr_axi_rready;
  uint8_t ddr_axi_rid;
  uint64_t ddr_axi_rdata;
  uint8_t ddr_axi_rresp;
  bool ddr_axi_rlast;
  bool mmio_axi_arvalid;
  bool mmio_axi_awvalid;
  bool mmio_axi_wvalid;
};

extern struct
    module_axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
        axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top;

static void drive_idle(void)
{
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
      .cache_req_valid = false;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
      .cache_req_write = false;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
      .cache_req_addr = 0u;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
      .cache_req_id = 0u;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
      .cache_req_size = 7u;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
      .cache_req_wdata = 0u;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
      .cache_req_wstrb = 0u;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
      .ddr_axi_rvalid = false;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top.ddr_axi_rid =
      0u;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
      .ddr_axi_rdata = 0u;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
      .ddr_axi_rresp = 0u;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
      .ddr_axi_rlast = false;
}

static void check_no_write_issue(void)
{
  assert(!axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
              .ddr_axi_awvalid);
  assert(!axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
              .ddr_axi_wvalid);
  assert(!axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
              .mmio_axi_awvalid);
  assert(!axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
	              .mmio_axi_wvalid);
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
  const uint8_t read_id = nondet_uint8_t() & 0x3fu;
  const uint8_t write_id = nondet_uint8_t() & 0x3fu;
  const uint64_t wdata =
      ((uint64_t)nondet_uint32_t() << 32u) | nondet_uint32_t();
  bool seen_aw_after_r = false;
  bool seen_w_after_r = false;

  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top.rst_n =
      false;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top.rst_n = true;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
      .cache_req_valid = true;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
      .cache_req_write = false;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
      .cache_req_addr = addr;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top.cache_req_id =
      read_id;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
      .cache_req_size = 7u;
  set_inputs();
  assert(axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
             .cache_req_ready);

  next_timeframe();
  set_inputs();
  const bool arvalid_1 =
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .ddr_axi_arvalid;
  const uint8_t arid_1 =
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .ddr_axi_arid;
  check_ar_snapshot(
      arvalid_1,
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .ddr_axi_araddr,
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .mmio_axi_arvalid,
      addr);

  drive_idle();
  set_inputs();
  next_timeframe();
  set_inputs();
  const bool arvalid_2 =
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .ddr_axi_arvalid;
  const uint8_t arid_2 =
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .ddr_axi_arid;
  check_ar_snapshot(
      arvalid_2,
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .ddr_axi_araddr,
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .mmio_axi_arvalid,
      addr);

  drive_idle();
  set_inputs();
  next_timeframe();
  set_inputs();
  const bool arvalid_3 =
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .ddr_axi_arvalid;
  const uint8_t arid_3 =
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .ddr_axi_arid;
  check_ar_snapshot(
      arvalid_3,
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .ddr_axi_araddr,
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .mmio_axi_arvalid,
      addr);

  drive_idle();
  set_inputs();
  next_timeframe();
  set_inputs();
  const bool arvalid_4 =
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .ddr_axi_arvalid;
  const uint8_t arid_4 =
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .ddr_axi_arid;
  check_ar_snapshot(
      arvalid_4,
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .ddr_axi_araddr,
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .mmio_axi_arvalid,
      addr);

  drive_idle();
  set_inputs();
  next_timeframe();
  set_inputs();
  const bool arvalid_5 =
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .ddr_axi_arvalid;
  const uint8_t arid_5 =
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .ddr_axi_arid;
  check_ar_snapshot(
      arvalid_5,
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .ddr_axi_araddr,
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .mmio_axi_arvalid,
      addr);

  drive_idle();
  set_inputs();
  next_timeframe();
  set_inputs();
  const bool arvalid_6 =
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .ddr_axi_arvalid;
  const uint8_t arid_6 =
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .ddr_axi_arid;
  check_ar_snapshot(
      arvalid_6,
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .ddr_axi_araddr,
      axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
          .mmio_axi_arvalid,
      addr);

  const bool seen_ar =
      arvalid_1 || arvalid_2 || arvalid_3 || arvalid_4 || arvalid_5 ||
      arvalid_6;
  const uint8_t arid =
      arvalid_1
          ? arid_1
          : (arvalid_2 ? arid_2
                       : (arvalid_3 ? arid_3
                                    : (arvalid_4 ? arid_4
                                                 : (arvalid_5 ? arid_5
                                                              : arid_6))));
  assert(seen_ar);

  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
      .cache_req_valid = true;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
      .cache_req_write = true;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
      .cache_req_addr = addr;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top.cache_req_id =
      write_id;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
      .cache_req_size = 7u;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
      .cache_req_wdata = wdata;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
      .cache_req_wstrb = 0xffu;
  set_inputs();
  assert(axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
             .cache_req_ready);
  check_no_write_issue();

  next_timeframe();
  drive_idle();
  set_inputs();
  check_no_write_issue();

  next_timeframe();
  drive_idle();
  set_inputs();
  check_no_write_issue();

  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top.ddr_axi_rvalid =
      true;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top.ddr_axi_rid =
      arid;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top.ddr_axi_rdata =
      0u;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top.ddr_axi_rresp =
      0u;
  axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top.ddr_axi_rlast =
      true;
  set_inputs();
  assert(axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
             .ddr_axi_rready);

  next_timeframe();
  drive_idle();
  set_inputs();
  if(axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
         .ddr_axi_awvalid)
  {
    assert(axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
               .ddr_axi_awaddr == addr);
    seen_aw_after_r = true;
  }
  if(axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
         .ddr_axi_wvalid)
  {
    assert(axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
               .ddr_axi_wlast);
    seen_w_after_r = true;
  }

  next_timeframe();
  drive_idle();
  set_inputs();
  if(axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
         .ddr_axi_awvalid)
  {
    assert(axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
               .ddr_axi_awaddr == addr);
    seen_aw_after_r = true;
  }
  if(axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
         .ddr_axi_wvalid)
  {
    assert(axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
               .ddr_axi_wlast);
    seen_w_after_r = true;
  }

  next_timeframe();
  drive_idle();
  set_inputs();
  if(axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
         .ddr_axi_awvalid)
  {
    assert(axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
               .ddr_axi_awaddr == addr);
    seen_aw_after_r = true;
  }
  if(axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
         .ddr_axi_wvalid)
  {
    assert(axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
               .ddr_axi_wlast);
    seen_w_after_r = true;
  }

  assert(seen_aw_after_r);
  assert(seen_w_after_r);
  assert(!axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
              .mmio_axi_awvalid);
  assert(!axi_llc_axi_bridge_dual_same_line_read_blocks_write_formal_top
              .mmio_axi_wvalid);
}
