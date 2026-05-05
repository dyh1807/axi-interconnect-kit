#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

struct module_axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
{
  bool clk;
  bool rst_n;
  bool ddr_write_req_valid;
  bool mmio_write_req_valid;
  bool ddr_write_req_ready;
  bool mmio_write_req_ready;
  bool ddr_write_req_accepted;
  bool mmio_write_req_accepted;
  bool ddr_axi_awvalid;
  uint32_t ddr_axi_awaddr;
  uint8_t ddr_axi_awlen;
  uint8_t ddr_axi_awsize;
  uint8_t ddr_axi_awburst;
  bool ddr_axi_wvalid;
  uint64_t ddr_axi_wdata;
  uint8_t ddr_axi_wstrb;
  bool ddr_axi_wlast;
  bool ddr_axi_arvalid;
  bool mmio_axi_awvalid;
  uint32_t mmio_axi_awaddr;
  uint8_t mmio_axi_awlen;
  uint8_t mmio_axi_awsize;
  uint8_t mmio_axi_awburst;
  bool mmio_axi_wvalid;
  uint32_t mmio_axi_wdata;
  uint8_t mmio_axi_wstrb;
  bool mmio_axi_wlast;
  bool mmio_axi_arvalid;
};

extern struct
    module_axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
        axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top;

static void drive_idle(void)
{
  axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
      .ddr_write_req_valid = false;
  axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
      .mmio_write_req_valid = false;
}

int main(void)
{
  bool ddr_request_seen = false;
  bool ddr_accepted_seen = false;
  bool mmio_request_seen = false;
  bool mmio_accepted_seen = false;
  bool seen_ddr_aw = false;
  bool seen_ddr_w = false;
  bool seen_mmio_aw = false;
  bool seen_mmio_w = false;

  axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top.rst_n =
      false;
  for(unsigned reset_cycle = 0u; reset_cycle < 3u; reset_cycle++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }

  axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top.rst_n =
      true;
  for(unsigned warmup = 0u; warmup < 12u; warmup++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }
  drive_idle();
  set_inputs();

  for(unsigned step = 0u; step < 24u; step++)
  {
    const bool ddr_write_pending = seen_ddr_aw && seen_ddr_w;

    axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
        .ddr_write_req_valid = !ddr_request_seen;
    axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
        .mmio_write_req_valid = ddr_write_pending && !mmio_request_seen;
    set_inputs();

    assert(!axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
                .ddr_axi_arvalid);
    assert(!axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
                .mmio_axi_arvalid);

    if(axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
           .ddr_write_req_valid &&
       axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
           .ddr_write_req_ready)
    {
      ddr_request_seen = true;
    }

    if(axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
           .ddr_write_req_accepted)
      ddr_accepted_seen = true;

    if(axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
           .ddr_axi_awvalid)
    {
      seen_ddr_aw = true;
      assert(axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
                 .ddr_axi_awaddr == 0x40000008u);
      assert(axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
                 .ddr_axi_awlen == 0u);
      assert(axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
                 .ddr_axi_awsize == 3u);
      assert(axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
                 .ddr_axi_awburst == 1u);
    }

    if(axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
           .ddr_axi_wvalid)
    {
      seen_ddr_w = true;
      assert(axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
                 .ddr_axi_wdata == (uint64_t)0xa53cc35au);
      assert(axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
                 .ddr_axi_wstrb == 0x0fu);
      assert(axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
                 .ddr_axi_wlast);
    }

    if(axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
           .mmio_write_req_valid &&
       axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
           .mmio_write_req_ready)
    {
      mmio_request_seen = true;
    }

    if(axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
           .mmio_write_req_accepted)
      mmio_accepted_seen = true;

    if(axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
           .mmio_axi_awvalid)
    {
      seen_mmio_aw = true;
      assert(ddr_write_pending);
      assert(axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
                 .mmio_axi_awaddr == 0x10000004u);
      assert(axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
                 .mmio_axi_awlen == 0u);
      assert(axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
                 .mmio_axi_awsize == 2u);
      assert(axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
                 .mmio_axi_awburst == 1u);
    }

    if(axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
           .mmio_axi_wvalid)
    {
      seen_mmio_w = true;
      assert(ddr_write_pending);
      assert(axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
                 .mmio_axi_wdata == 0x5ac33ca5u);
      assert(axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
                 .mmio_axi_wstrb == 0x0du);
      assert(axi_llc_subsystem_dual_ddr_write_mmio_write_independent_formal_top
                 .mmio_axi_wlast);
    }

    next_timeframe();
  }

  assert(ddr_request_seen);
  assert(ddr_accepted_seen);
  assert(seen_ddr_aw);
  assert(seen_ddr_w);
  assert(mmio_request_seen);
  assert(mmio_accepted_seen);
  assert(seen_mmio_aw);
  assert(seen_mmio_w);
}
