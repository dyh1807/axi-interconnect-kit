#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

struct module_axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
{
  bool clk;
  bool rst_n;
  bool cache_req_valid;
  bool bypass_req_valid;
  bool ddr_axi_arready;
  bool mmio_axi_arready;
  bool ddr_axi_rvalid;
  bool ddr_axi_rid;
  uint64_t ddr_axi_rdata_0;
  uint64_t ddr_axi_rdata_1;
  uint64_t ddr_axi_rdata_2;
  uint64_t ddr_axi_rdata_3;
  uint8_t ddr_axi_rresp;
  bool ddr_axi_rlast;
  bool mmio_axi_rvalid;
  bool mmio_axi_rid;
  uint32_t mmio_axi_rdata;
  uint8_t mmio_axi_rresp;
  bool mmio_axi_rlast;
  bool cache_req_ready;
  bool bypass_req_ready;
  bool cache_resp_valid;
  uint64_t cache_resp_rdata_0;
  uint64_t cache_resp_rdata_1;
  uint64_t cache_resp_rdata_2;
  uint64_t cache_resp_rdata_3;
  uint64_t cache_resp_rdata_4;
  uint64_t cache_resp_rdata_5;
  uint64_t cache_resp_rdata_6;
  uint64_t cache_resp_rdata_7;
  uint8_t cache_resp_id;
  uint8_t cache_resp_code;
  bool bypass_resp_valid;
  uint32_t bypass_resp_rdata;
  uint8_t bypass_resp_id;
  uint8_t bypass_resp_code;
  bool ddr_axi_arvalid;
  bool ddr_axi_arid;
  uint32_t ddr_axi_araddr;
  uint8_t ddr_axi_arlen;
  uint8_t ddr_axi_arsize;
  uint8_t ddr_axi_arburst;
  bool ddr_axi_rready;
  bool mmio_axi_arvalid;
  bool mmio_axi_arid;
  uint32_t mmio_axi_araddr;
  uint8_t mmio_axi_arlen;
  uint8_t mmio_axi_arsize;
  uint8_t mmio_axi_arburst;
  bool mmio_axi_rready;
  bool ddr_axi_awvalid;
  bool ddr_axi_wvalid;
  bool mmio_axi_awvalid;
  bool mmio_axi_wvalid;
};

extern struct
    module_axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
        axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top;

static void drive_idle(void)
{
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .cache_req_valid = false;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .bypass_req_valid = false;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rvalid = false;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rid = false;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rdata_0 = 0u;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rdata_1 = 0u;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rdata_2 = 0u;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rdata_3 = 0u;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rresp = 0u;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rlast = false;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .mmio_axi_rvalid = false;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .mmio_axi_rid = false;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .mmio_axi_rdata = 0u;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .mmio_axi_rresp = 0u;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .mmio_axi_rlast = false;
}

static void hold_ar_ready_low(void)
{
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_arready = false;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .mmio_axi_arready = false;
}

static void check_no_write_escape(void)
{
  assert(!axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
              .ddr_axi_awvalid);
  assert(!axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
              .ddr_axi_wvalid);
  assert(!axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
              .mmio_axi_awvalid);
  assert(!axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
              .mmio_axi_wvalid);
}

static void check_ar_shape(bool ddr_arvalid, bool mmio_arvalid)
{
  if(ddr_arvalid)
  {
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
               .ddr_axi_araddr == 0x40000300u);
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
               .ddr_axi_arlen == 1u);
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
               .ddr_axi_arsize == 5u);
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
               .ddr_axi_arburst == 1u);
  }
  if(mmio_arvalid)
  {
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
               .mmio_axi_araddr == 0x10000028u);
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
               .mmio_axi_arlen == 0u);
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
               .mmio_axi_arsize == 2u);
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
               .mmio_axi_arburst == 1u);
  }
}

int main(void)
{
  const uint64_t beat0_0 = 0xa5a55a5adeadbeefull;
  const uint64_t beat0_1 = 0x1122334455667788ull;
  const uint64_t beat0_2 = 0x8877665544332211ull;
  const uint64_t beat0_3 = 0x0f1e2d3c4b5a6978ull;
  const uint64_t beat1_0 = 0x89abcdef01234567ull;
  const uint64_t beat1_1 = 0x0123456789abcdefull;
  const uint64_t beat1_2 = 0xffeeddccbbaa9988ull;
  const uint64_t beat1_3 = 0x7766554433221100ull;
  bool seen_ar_together = false;
  bool ddr_arid = false;
  bool mmio_arid = false;

  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .rst_n = false;
  drive_idle();
  hold_ar_ready_low();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .rst_n = true;
  drive_idle();
  hold_ar_ready_low();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .cache_req_valid = true;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .bypass_req_valid = true;
  hold_ar_ready_low();
  set_inputs();

  assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
             .cache_req_ready);
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
             .bypass_req_ready);

  for(unsigned step = 0u; step < 4u; step++)
  {
    next_timeframe();
    drive_idle();
    hold_ar_ready_low();
    set_inputs();

    const bool ddr_arvalid =
        axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
            .ddr_axi_arvalid;
    const bool mmio_arvalid =
        axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
            .mmio_axi_arvalid;
    check_no_write_escape();
    check_ar_shape(ddr_arvalid, mmio_arvalid);
    if(ddr_arvalid || mmio_arvalid)
    {
      assert(ddr_arvalid && mmio_arvalid);
      seen_ar_together = true;
      ddr_arid =
          axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
              .ddr_axi_arid;
      mmio_arid =
          axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
              .mmio_axi_arid;
    }
  }

  assert(seen_ar_together);

  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_arready = true;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .mmio_axi_arready = true;
  set_inputs();
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
             .ddr_axi_arvalid);
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
             .mmio_axi_arvalid);
  check_ar_shape(true, true);
  next_timeframe();

  drive_idle();
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .mmio_axi_rvalid = true;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .mmio_axi_rid = mmio_arid;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .mmio_axi_rdata = 0xcafe0208u;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .mmio_axi_rresp = 0u;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .mmio_axi_rlast = true;
  set_inputs();

  assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
             .mmio_axi_rready);
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
             .ddr_axi_rready);
  next_timeframe();

  drive_idle();
  set_inputs();
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
             .bypass_resp_valid);
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
             .bypass_resp_id == 0x0au);
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
             .bypass_resp_code == 0u);
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
             .bypass_resp_rdata == 0xcafe0208u);
  assert(!axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
              .cache_resp_valid);

  drive_idle();
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rvalid = true;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rid = ddr_arid;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rdata_0 = beat0_0;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rdata_1 = beat0_1;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rdata_2 = beat0_2;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rdata_3 = beat0_3;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rresp = 0u;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rlast = false;
  set_inputs();

  assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
             .ddr_axi_rready);
  next_timeframe();

  drive_idle();
  set_inputs();
  assert(!axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
              .cache_resp_valid);

  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rvalid = true;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rid = ddr_arid;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rdata_0 = beat1_0;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rdata_1 = beat1_1;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rdata_2 = beat1_2;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rdata_3 = beat1_3;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rresp = 0u;
  axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
      .ddr_axi_rlast = true;
  set_inputs();

  assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
             .ddr_axi_rready);
  next_timeframe();

  drive_idle();
  set_inputs();
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
             .cache_resp_valid);
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
             .cache_resp_id == 0x05u);
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
             .cache_resp_code == 0u);
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
             .cache_resp_rdata_0 == beat0_0);
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
             .cache_resp_rdata_1 == beat0_1);
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
             .cache_resp_rdata_2 == beat0_2);
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
             .cache_resp_rdata_3 == beat0_3);
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
             .cache_resp_rdata_4 == beat1_0);
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
             .cache_resp_rdata_5 == beat1_1);
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
             .cache_resp_rdata_6 == beat1_2);
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top
             .cache_resp_rdata_7 == beat1_3);
}
