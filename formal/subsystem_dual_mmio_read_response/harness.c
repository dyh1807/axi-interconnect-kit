#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

struct module_axi_llc_subsystem_dual_mmio_read_response_formal_top
{
  bool clk;
  bool rst_n;
  bool read_req_valid;
  uint32_t read_req_addr;
  uint8_t read_req_id;
  bool read_req_ready;
  bool read_req_accepted;
  uint8_t read_req_accepted_id;
  bool read_resp_valid;
  uint64_t read_resp_data;
  uint8_t read_resp_id;
  bool mmio_axi_arvalid;
  bool mmio_axi_arid;
  uint32_t mmio_axi_araddr;
  uint8_t mmio_axi_arlen;
  uint8_t mmio_axi_arsize;
  uint8_t mmio_axi_arburst;
  bool mmio_axi_rvalid;
  bool mmio_axi_rready;
  uint32_t mmio_axi_rdata;
  uint8_t mmio_axi_rresp;
  bool mmio_axi_rlast;
  bool ddr_axi_arvalid;
  bool ddr_axi_awvalid;
  bool ddr_axi_wvalid;
};

extern struct module_axi_llc_subsystem_dual_mmio_read_response_formal_top
    axi_llc_subsystem_dual_mmio_read_response_formal_top;

static void drive_idle(void)
{
  axi_llc_subsystem_dual_mmio_read_response_formal_top.read_req_valid = false;
  axi_llc_subsystem_dual_mmio_read_response_formal_top.read_req_addr = 0u;
  axi_llc_subsystem_dual_mmio_read_response_formal_top.read_req_id = 0u;
  axi_llc_subsystem_dual_mmio_read_response_formal_top.mmio_axi_rvalid = false;
  axi_llc_subsystem_dual_mmio_read_response_formal_top.mmio_axi_rdata = 0u;
  axi_llc_subsystem_dual_mmio_read_response_formal_top.mmio_axi_rresp = 0u;
  axi_llc_subsystem_dual_mmio_read_response_formal_top.mmio_axi_rlast = false;
}

int main(void)
{
  const uint32_t addr = 0x10000004u;
  const uint8_t req_id = 9u;
  const uint32_t rdata = 0xa5a51234u;
  bool request_seen = false;
  bool accepted_seen = false;
  bool seen_ar = false;
  bool r_accepted = false;
  bool seen_resp = false;

  axi_llc_subsystem_dual_mmio_read_response_formal_top.rst_n = false;
  for(unsigned reset_cycle = 0u; reset_cycle < 3u; reset_cycle++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }

  axi_llc_subsystem_dual_mmio_read_response_formal_top.rst_n = true;
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
    axi_llc_subsystem_dual_mmio_read_response_formal_top.read_req_valid =
        !request_seen;
    axi_llc_subsystem_dual_mmio_read_response_formal_top.read_req_addr = addr;
    axi_llc_subsystem_dual_mmio_read_response_formal_top.read_req_id = req_id;
    axi_llc_subsystem_dual_mmio_read_response_formal_top.mmio_axi_rvalid =
        seen_ar && !r_accepted;
    axi_llc_subsystem_dual_mmio_read_response_formal_top.mmio_axi_rdata = rdata;
    axi_llc_subsystem_dual_mmio_read_response_formal_top.mmio_axi_rresp = 0u;
    axi_llc_subsystem_dual_mmio_read_response_formal_top.mmio_axi_rlast =
        seen_ar && !r_accepted;
    set_inputs();

    assert(!axi_llc_subsystem_dual_mmio_read_response_formal_top
                .ddr_axi_arvalid);
    assert(!axi_llc_subsystem_dual_mmio_read_response_formal_top
                .ddr_axi_awvalid);
    assert(!axi_llc_subsystem_dual_mmio_read_response_formal_top
                .ddr_axi_wvalid);

    if(axi_llc_subsystem_dual_mmio_read_response_formal_top.read_req_valid &&
       axi_llc_subsystem_dual_mmio_read_response_formal_top.read_req_ready)
    {
      request_seen = true;
    }

    if(axi_llc_subsystem_dual_mmio_read_response_formal_top.read_req_accepted)
    {
      accepted_seen = true;
      assert(axi_llc_subsystem_dual_mmio_read_response_formal_top
                 .read_req_accepted_id == req_id);
    }

    if(axi_llc_subsystem_dual_mmio_read_response_formal_top.mmio_axi_arvalid)
    {
      seen_ar = true;
      assert(axi_llc_subsystem_dual_mmio_read_response_formal_top
                 .mmio_axi_araddr == addr);
      assert(axi_llc_subsystem_dual_mmio_read_response_formal_top
                 .mmio_axi_arlen == 0u);
      assert(axi_llc_subsystem_dual_mmio_read_response_formal_top
                 .mmio_axi_arsize == 2u);
      assert(axi_llc_subsystem_dual_mmio_read_response_formal_top
                 .mmio_axi_arburst == 1u);
    }

    if(axi_llc_subsystem_dual_mmio_read_response_formal_top.mmio_axi_rvalid &&
       axi_llc_subsystem_dual_mmio_read_response_formal_top.mmio_axi_rready)
    {
      r_accepted = true;
    }

    if(axi_llc_subsystem_dual_mmio_read_response_formal_top.read_resp_valid)
    {
      seen_resp = true;
      assert(axi_llc_subsystem_dual_mmio_read_response_formal_top
                 .read_resp_id == req_id);
      assert((uint32_t)axi_llc_subsystem_dual_mmio_read_response_formal_top
                 .read_resp_data == rdata);
    }

    next_timeframe();
  }

  assert(request_seen);
  assert(accepted_seen);
  assert(seen_ar);
  assert(r_accepted);
  assert(seen_resp);
}
