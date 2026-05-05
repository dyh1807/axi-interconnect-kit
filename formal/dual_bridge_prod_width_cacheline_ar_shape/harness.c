#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

uint32_t nondet_uint32_t(void);

struct module_axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top
{
  bool clk;
  bool rst_n;
  bool cache_req_valid;
  uint32_t cache_req_addr;
  bool cache_req_ready;
  bool ddr_axi_arvalid;
  bool ddr_axi_arid;
  uint32_t ddr_axi_araddr;
  uint8_t ddr_axi_arlen;
  uint8_t ddr_axi_arsize;
  uint8_t ddr_axi_arburst;
  bool ddr_axi_awvalid;
  bool ddr_axi_wvalid;
  bool mmio_axi_arvalid;
  bool mmio_axi_awvalid;
  bool mmio_axi_wvalid;
  bool debug_ddr_cache_req_valid;
  bool debug_ddr_cache_req_ready;
  bool debug_ddr_bridge_arvalid;
  bool debug_ddr_bridge_arready;
  bool debug_ddr_ar_hazard;
  bool debug_ddr_ar_slot_hazard;
  bool debug_ddr_ar_pending_write_hazard;
  bool debug_ddr_accept_cache;
  bool debug_ddr_rd_valid_0;
  bool debug_ddr_rd_issue_count_nonzero;
  bool debug_wr_hazard_valid_0;
  bool debug_wr_hazard_valid_1;
  bool debug_ddr_aw_fire;
  bool debug_mmio_aw_fire;
};

extern struct
    module_axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top
        axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top;

static void drive_idle(void)
{
  axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top
      .cache_req_valid = false;
  axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top
      .cache_req_addr = 0u;
}

static void check_ar_snapshot(bool arvalid, uint32_t araddr, uint8_t arlen,
                              uint8_t arsize, uint8_t arburst, uint32_t addr)
{
  assert(!axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top
              .mmio_axi_arvalid);
  assert(!axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top
              .mmio_axi_awvalid);
  assert(!axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top
              .mmio_axi_wvalid);
  assert(!axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top
              .ddr_axi_awvalid);
  assert(!axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top
              .ddr_axi_wvalid);
  if(arvalid)
  {
    assert(araddr == addr);
    assert(arlen == 1u);
    assert(arsize == 5u);
    assert(arburst == 1u);
  }
}

int main(void)
{
  const uint32_t addr = 0x40000000u + (nondet_uint32_t() & 0x0000ffc0u);
  bool seen_ar = false;

  axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top.rst_n =
      false;
  drive_idle();
  set_inputs();
  next_timeframe();
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top.rst_n =
      true;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top
      .cache_req_valid = true;
  axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top
      .cache_req_addr = addr;
  set_inputs();

  assert(axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top
             .cache_req_ready);

  check_ar_snapshot(
      axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top
          .ddr_axi_arvalid,
      axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top
          .ddr_axi_araddr,
      axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top
          .ddr_axi_arlen,
      axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top
          .ddr_axi_arsize,
      axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top
          .ddr_axi_arburst,
      addr);
  if(axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top
         .ddr_axi_arvalid)
  {
    seen_ar = true;
  }

  for(unsigned step = 0u; step < 6u; step++)
  {
    next_timeframe();
    drive_idle();
    set_inputs();

    const bool arvalid =
        axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top
            .ddr_axi_arvalid;
    check_ar_snapshot(
        arvalid,
        axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top
            .ddr_axi_araddr,
        axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top
            .ddr_axi_arlen,
        axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top
            .ddr_axi_arsize,
        axi_llc_axi_bridge_dual_prod_width_cacheline_ar_shape_formal_top
            .ddr_axi_arburst,
        addr);
    seen_ar = seen_ar || arvalid;
  }

  assert(seen_ar);
}
