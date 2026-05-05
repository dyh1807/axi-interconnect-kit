#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

struct
    module_axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
{
  bool clk;
  bool rst_n;
  bool cache_req_valid;
  bool bypass_req_valid;
  bool ddr_axi_awready;
  bool ddr_axi_wready;
  bool mmio_axi_arready;
  bool mmio_axi_rvalid;
  bool mmio_axi_rid;
  uint32_t mmio_axi_rdata;
  uint8_t mmio_axi_rresp;
  bool mmio_axi_rlast;
  bool cache_req_ready;
  bool bypass_req_ready;
  bool ddr_axi_awvalid;
  bool ddr_axi_awid;
  uint32_t ddr_axi_awaddr;
  uint8_t ddr_axi_awlen;
  uint8_t ddr_axi_awsize;
  uint8_t ddr_axi_awburst;
  bool ddr_axi_wvalid;
  uint64_t ddr_axi_wdata_0;
  uint64_t ddr_axi_wdata_1;
  uint64_t ddr_axi_wdata_2;
  uint64_t ddr_axi_wdata_3;
  uint32_t ddr_axi_wstrb;
  bool ddr_axi_wlast;
  bool mmio_axi_arvalid;
  bool mmio_axi_arid;
  uint32_t mmio_axi_araddr;
  uint8_t mmio_axi_arlen;
  uint8_t mmio_axi_arsize;
  uint8_t mmio_axi_arburst;
  bool mmio_axi_rready;
  bool bypass_resp_valid;
  uint32_t bypass_resp_rdata;
  uint8_t bypass_resp_id;
  uint8_t bypass_resp_code;
  bool ddr_axi_arvalid;
  bool mmio_axi_awvalid;
  bool mmio_axi_wvalid;
};

extern struct
    module_axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
        axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top;

static void drive_idle(void)
{
  axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
      .cache_req_valid = false;
  axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
      .bypass_req_valid = false;
  axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
      .mmio_axi_rvalid = false;
  axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
      .mmio_axi_rid = false;
  axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
      .mmio_axi_rdata = 0u;
  axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
      .mmio_axi_rresp = 0u;
  axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
      .mmio_axi_rlast = false;
}

static void hold_lower_ready_low(void)
{
  axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
      .ddr_axi_awready = false;
  axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
      .ddr_axi_wready = false;
  axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
      .mmio_axi_arready = false;
}

static void check_no_opposite_escape(void)
{
  assert(!axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
              .ddr_axi_arvalid);
  assert(!axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
              .mmio_axi_awvalid);
  assert(!axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
              .mmio_axi_wvalid);
}

static void check_aw_shape(bool ddr_awvalid)
{
  if(ddr_awvalid)
  {
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
               .ddr_axi_awaddr == 0x40000400u);
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
               .ddr_axi_awlen == 1u);
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
               .ddr_axi_awsize == 5u);
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
               .ddr_axi_awburst == 1u);
  }
}

static void check_ar_shape(bool mmio_arvalid)
{
  if(mmio_arvalid)
  {
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
               .mmio_axi_araddr == 0x1000002cu);
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
               .mmio_axi_arlen == 0u);
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
               .mmio_axi_arsize == 2u);
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
               .mmio_axi_arburst == 1u);
  }
}

static void check_w_shape(bool ddr_wvalid, bool prior_ddr_w_seen)
{
  if(!ddr_wvalid)
  {
    return;
  }

  assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
             .ddr_axi_wstrb == 0xffffffffu);
  if(!prior_ddr_w_seen)
  {
    assert(!axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
                .ddr_axi_wlast);
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
               .ddr_axi_wdata_0 == 0xa5a55a5adeadbeefull);
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
               .ddr_axi_wdata_1 == 0x1122334455667788ull);
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
               .ddr_axi_wdata_2 == 0x8877665544332211ull);
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
               .ddr_axi_wdata_3 == 0x0f1e2d3c4b5a6978ull);
  }
  else
  {
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
               .ddr_axi_wlast);
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
               .ddr_axi_wdata_0 == 0x89abcdef01234567ull);
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
               .ddr_axi_wdata_1 == 0x0123456789abcdefull);
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
               .ddr_axi_wdata_2 == 0xffeeddccbbaa9988ull);
    assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
               .ddr_axi_wdata_3 == 0x7766554433221100ull);
  }
}

int main(void)
{
  bool seen_aw_ar_together = false;
  bool seen_ddr_w = false;
  bool mmio_arid = false;

  axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
      .rst_n = false;
  drive_idle();
  hold_lower_ready_low();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
      .rst_n = true;
  drive_idle();
  hold_lower_ready_low();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
      .cache_req_valid = true;
  axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
      .bypass_req_valid = true;
  hold_lower_ready_low();
  set_inputs();

  assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
             .cache_req_ready);
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
             .bypass_req_ready);

  for(unsigned step = 0u; step < 4u; step++)
  {
    next_timeframe();
    drive_idle();
    hold_lower_ready_low();
    set_inputs();

    const bool ddr_awvalid =
        axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
            .ddr_axi_awvalid;
    const bool ddr_wvalid =
        axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
            .ddr_axi_wvalid;
    const bool mmio_arvalid =
        axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
            .mmio_axi_arvalid;
    check_no_opposite_escape();
    check_aw_shape(ddr_awvalid);
    check_ar_shape(mmio_arvalid);
    check_w_shape(ddr_wvalid, seen_ddr_w);
    seen_ddr_w = seen_ddr_w || ddr_wvalid;
    if(ddr_awvalid || mmio_arvalid)
    {
      assert(ddr_awvalid && mmio_arvalid);
      seen_aw_ar_together = true;
      mmio_arid =
          axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
              .mmio_axi_arid;
    }
  }

  assert(seen_aw_ar_together);

  axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
      .ddr_axi_awready = false;
  axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
      .ddr_axi_wready = false;
  axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
      .mmio_axi_arready = true;
  set_inputs();
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
             .mmio_axi_arvalid);
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
             .ddr_axi_awvalid);
  check_aw_shape(true);
  check_ar_shape(true);
  next_timeframe();

  drive_idle();
  hold_lower_ready_low();
  axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
      .mmio_axi_rvalid = true;
  axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
      .mmio_axi_rid = mmio_arid;
  axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
      .mmio_axi_rdata = 0xcafe020cu;
  axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
      .mmio_axi_rresp = 0u;
  axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
      .mmio_axi_rlast = true;
  set_inputs();

  assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
             .mmio_axi_rready);
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
             .ddr_axi_awvalid);
  check_aw_shape(true);
  next_timeframe();

  drive_idle();
  hold_lower_ready_low();
  set_inputs();
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
             .bypass_resp_valid);
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
             .bypass_resp_id == 0x0au);
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
             .bypass_resp_code == 0u);
  assert(axi_llc_axi_bridge_dual_prod_width_ddr_write_mmio_read_independent_formal_top
             .bypass_resp_rdata == 0xcafe020cu);
}
