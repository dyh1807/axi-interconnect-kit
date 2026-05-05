#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

struct module_axi_llc_subsystem_dual_cache_refill_response_formal_top
{
  bool clk;
  bool rst_n;
  bool read_req_valid;
  bool read_req_ready;
  bool read_req_accepted;
  uint8_t read_req_accepted_id;
  bool read_resp_valid;
  uint64_t read_resp_data;
  uint8_t read_resp_id;
  bool ddr_axi_arvalid;
  bool ddr_axi_arready;
  bool ddr_axi_arid;
  uint32_t ddr_axi_araddr;
  uint8_t ddr_axi_arlen;
  uint8_t ddr_axi_arsize;
  uint8_t ddr_axi_arburst;
  bool ddr_axi_rvalid;
  bool ddr_axi_rready;
  bool ddr_axi_rid;
  uint64_t ddr_axi_rdata;
  uint8_t ddr_axi_rresp;
  bool ddr_axi_rlast;
  bool ddr_axi_awvalid;
  bool ddr_axi_wvalid;
  bool mmio_axi_arvalid;
  bool mmio_axi_awvalid;
  bool mmio_axi_wvalid;
  bool config_error;
};

extern struct module_axi_llc_subsystem_dual_cache_refill_response_formal_top
    axi_llc_subsystem_dual_cache_refill_response_formal_top;

static void drive_idle(void)
{
  axi_llc_subsystem_dual_cache_refill_response_formal_top.read_req_valid =
      false;
  axi_llc_subsystem_dual_cache_refill_response_formal_top.ddr_axi_arready =
      false;
  axi_llc_subsystem_dual_cache_refill_response_formal_top.ddr_axi_rvalid =
      false;
  axi_llc_subsystem_dual_cache_refill_response_formal_top.ddr_axi_rid = false;
  axi_llc_subsystem_dual_cache_refill_response_formal_top.ddr_axi_rdata = 0u;
  axi_llc_subsystem_dual_cache_refill_response_formal_top.ddr_axi_rresp = 0u;
  axi_llc_subsystem_dual_cache_refill_response_formal_top.ddr_axi_rlast =
      false;
}

int main(void)
{
  const uint64_t refill_data = 0x0123456789abcdefull;
  bool request_seen = false;
  bool accepted_seen = false;
  bool seen_ar = false;
  bool ar_accepted = false;
  bool arid = false;
  bool r_accepted = false;
  bool seen_resp = false;

  axi_llc_subsystem_dual_cache_refill_response_formal_top.rst_n = false;
  for(unsigned reset_cycle = 0u; reset_cycle < 3u; reset_cycle++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }

  axi_llc_subsystem_dual_cache_refill_response_formal_top.rst_n = true;
  for(unsigned warmup = 0u; warmup < 12u; warmup++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }
  drive_idle();
  set_inputs();

  for(unsigned step = 0u; step < 28u; step++)
  {
    axi_llc_subsystem_dual_cache_refill_response_formal_top.read_req_valid =
        !request_seen;
    axi_llc_subsystem_dual_cache_refill_response_formal_top.ddr_axi_arready =
        seen_ar && !ar_accepted;
    axi_llc_subsystem_dual_cache_refill_response_formal_top.ddr_axi_rvalid =
        ar_accepted && !r_accepted;
    axi_llc_subsystem_dual_cache_refill_response_formal_top.ddr_axi_rid = arid;
    axi_llc_subsystem_dual_cache_refill_response_formal_top.ddr_axi_rdata =
        refill_data;
    axi_llc_subsystem_dual_cache_refill_response_formal_top.ddr_axi_rresp =
        0u;
    axi_llc_subsystem_dual_cache_refill_response_formal_top.ddr_axi_rlast =
        ar_accepted && !r_accepted;
    set_inputs();

    assert(!axi_llc_subsystem_dual_cache_refill_response_formal_top
                .ddr_axi_awvalid);
    assert(!axi_llc_subsystem_dual_cache_refill_response_formal_top
                .ddr_axi_wvalid);
    assert(!axi_llc_subsystem_dual_cache_refill_response_formal_top
                .mmio_axi_arvalid);
    assert(!axi_llc_subsystem_dual_cache_refill_response_formal_top
                .mmio_axi_awvalid);
    assert(!axi_llc_subsystem_dual_cache_refill_response_formal_top
                .mmio_axi_wvalid);
    assert(!axi_llc_subsystem_dual_cache_refill_response_formal_top
                .config_error);

    if(axi_llc_subsystem_dual_cache_refill_response_formal_top.read_req_valid &&
       axi_llc_subsystem_dual_cache_refill_response_formal_top.read_req_ready)
    {
      request_seen = true;
    }

    if(axi_llc_subsystem_dual_cache_refill_response_formal_top
           .read_req_accepted)
    {
      accepted_seen = true;
      assert(axi_llc_subsystem_dual_cache_refill_response_formal_top
                 .read_req_accepted_id == 6u);
    }

    if(axi_llc_subsystem_dual_cache_refill_response_formal_top.ddr_axi_arvalid)
    {
      seen_ar = true;
      arid =
          axi_llc_subsystem_dual_cache_refill_response_formal_top.ddr_axi_arid;
      assert(axi_llc_subsystem_dual_cache_refill_response_formal_top
                 .ddr_axi_araddr == 0x40000100u);
      assert(axi_llc_subsystem_dual_cache_refill_response_formal_top
                 .ddr_axi_arlen == 0u);
      assert(axi_llc_subsystem_dual_cache_refill_response_formal_top
                 .ddr_axi_arsize == 3u);
      assert(axi_llc_subsystem_dual_cache_refill_response_formal_top
                 .ddr_axi_arburst == 1u);
    }

    if(axi_llc_subsystem_dual_cache_refill_response_formal_top.ddr_axi_arvalid &&
       axi_llc_subsystem_dual_cache_refill_response_formal_top.ddr_axi_arready)
    {
      ar_accepted = true;
    }

    if(axi_llc_subsystem_dual_cache_refill_response_formal_top.ddr_axi_rvalid)
    {
      assert(axi_llc_subsystem_dual_cache_refill_response_formal_top
                 .ddr_axi_rready);
    }

    if(axi_llc_subsystem_dual_cache_refill_response_formal_top.ddr_axi_rvalid &&
       axi_llc_subsystem_dual_cache_refill_response_formal_top.ddr_axi_rready)
    {
      r_accepted = true;
    }

    if(axi_llc_subsystem_dual_cache_refill_response_formal_top.read_resp_valid)
    {
      seen_resp = true;
      assert(axi_llc_subsystem_dual_cache_refill_response_formal_top
                 .read_resp_id == 6u);
      assert(axi_llc_subsystem_dual_cache_refill_response_formal_top
                 .read_resp_data == refill_data);
    }

    next_timeframe();
  }

  assert(request_seen);
  assert(accepted_seen);
  assert(seen_ar);
  assert(ar_accepted);
  assert(r_accepted);
  assert(seen_resp);
}
