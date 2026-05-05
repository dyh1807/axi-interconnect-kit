#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

struct module_axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
{
  bool clk;
  bool rst_n;
  bool ddr_read_req_valid;
  bool mmio_read_req_valid;
  bool ddr_read_req_ready;
  bool mmio_read_req_ready;
  bool ddr_read_req_accepted;
  bool mmio_read_req_accepted;
  uint8_t ddr_read_req_accepted_id;
  uint8_t mmio_read_req_accepted_id;
  bool ddr_axi_arvalid;
  bool ddr_axi_arready;
  uint32_t ddr_axi_araddr;
  uint8_t ddr_axi_arlen;
  uint8_t ddr_axi_arsize;
  uint8_t ddr_axi_arburst;
  bool ddr_axi_awvalid;
  bool ddr_axi_wvalid;
  bool mmio_axi_arvalid;
  bool mmio_axi_arready;
  uint32_t mmio_axi_araddr;
  uint8_t mmio_axi_arlen;
  uint8_t mmio_axi_arsize;
  uint8_t mmio_axi_arburst;
  bool mmio_axi_awvalid;
  bool mmio_axi_wvalid;
  bool config_error;
};

extern struct
    module_axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
        axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top;

static void drive_idle(void)
{
  axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
      .ddr_read_req_valid = false;
  axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
      .mmio_read_req_valid = false;
  axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
      .ddr_axi_arready = false;
  axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
      .mmio_axi_arready = false;
}

int main(void)
{
  bool ddr_request_seen = false;
  bool ddr_accepted_seen = false;
  bool seen_ddr_ar = false;
  bool mmio_request_seen = false;
  bool mmio_accepted_seen = false;
  bool seen_mmio_ar = false;

  axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top.rst_n =
      false;
  for(unsigned reset_cycle = 0u; reset_cycle < 3u; reset_cycle++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }

  axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top.rst_n =
      true;
  for(unsigned warmup = 0u; warmup < 12u; warmup++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }
  drive_idle();
  set_inputs();

  for(unsigned step = 0u; step < 36u; step++)
  {
    axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
        .ddr_read_req_valid = !ddr_request_seen;
    axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
        .mmio_read_req_valid = seen_ddr_ar && !mmio_request_seen;
    axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
        .ddr_axi_arready = false;
    axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
        .mmio_axi_arready = false;
    set_inputs();

    assert(!axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
                .ddr_axi_awvalid);
    assert(!axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
                .ddr_axi_wvalid);
    assert(!axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
                .mmio_axi_awvalid);
    assert(!axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
                .mmio_axi_wvalid);
    assert(!axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
                .config_error);

    if(axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
           .ddr_read_req_valid &&
       axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
           .ddr_read_req_ready)
    {
      ddr_request_seen = true;
    }

    if(axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
           .ddr_read_req_accepted)
    {
      ddr_accepted_seen = true;
      assert(axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
                 .ddr_read_req_accepted_id == 6u);
    }

    if(seen_ddr_ar)
    {
      assert(axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
                 .ddr_axi_arvalid);
    }

    if(axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
           .ddr_axi_arvalid)
    {
      seen_ddr_ar = true;
      assert(axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
                 .ddr_axi_araddr == 0x40000100u);
      assert(axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
                 .ddr_axi_arlen == 0u);
      assert(axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
                 .ddr_axi_arsize == 3u);
      assert(axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
                 .ddr_axi_arburst == 1u);
    }

    if(axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
           .mmio_read_req_valid &&
       axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
           .mmio_read_req_ready)
    {
      mmio_request_seen = true;
    }

    if(axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
           .mmio_read_req_accepted)
    {
      mmio_accepted_seen = true;
      assert(axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
                 .mmio_read_req_accepted_id == 9u);
    }

    if(axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
           .mmio_axi_arvalid)
    {
      seen_mmio_ar = true;
      assert(axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
                 .ddr_axi_arvalid);
      assert(axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
                 .mmio_axi_araddr == 0x1000000cu);
      assert(axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
                 .mmio_axi_arlen == 0u);
      assert(axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
                 .mmio_axi_arsize == 2u);
      assert(axi_llc_subsystem_dual_cache_refill_mmio_read_independent_formal_top
                 .mmio_axi_arburst == 1u);
    }

    next_timeframe();
  }

  assert(ddr_request_seen);
  assert(ddr_accepted_seen);
  assert(seen_ddr_ar);
  assert(mmio_request_seen);
  assert(mmio_accepted_seen);
  assert(seen_mmio_ar);
}
