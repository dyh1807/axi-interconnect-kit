#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

struct module_axi_llc_subsystem_dual_mmio_write_response_formal_top
{
  bool clk;
  bool rst_n;
  bool write_req_valid;
  uint32_t write_req_addr;
  uint8_t write_req_id;
  uint32_t write_req_wdata;
  uint8_t write_req_wstrb;
  bool write_req_ready;
  bool write_req_accepted;
  bool write_resp_valid;
  uint8_t write_resp_id;
  uint8_t write_resp_code;
  bool mmio_axi_awvalid;
  bool mmio_axi_awid;
  uint32_t mmio_axi_awaddr;
  uint8_t mmio_axi_awlen;
  uint8_t mmio_axi_awsize;
  uint8_t mmio_axi_awburst;
  bool mmio_axi_wvalid;
  uint32_t mmio_axi_wdata;
  uint8_t mmio_axi_wstrb;
  bool mmio_axi_wlast;
  bool mmio_axi_bvalid;
  bool mmio_axi_bready;
  bool mmio_axi_bid;
  uint8_t mmio_axi_bresp;
  bool ddr_axi_arvalid;
  bool ddr_axi_awvalid;
  bool ddr_axi_wvalid;
};

extern struct module_axi_llc_subsystem_dual_mmio_write_response_formal_top
    axi_llc_subsystem_dual_mmio_write_response_formal_top;

static void drive_idle(void)
{
  axi_llc_subsystem_dual_mmio_write_response_formal_top.write_req_valid = false;
  axi_llc_subsystem_dual_mmio_write_response_formal_top.write_req_addr = 0u;
  axi_llc_subsystem_dual_mmio_write_response_formal_top.write_req_id = 0u;
  axi_llc_subsystem_dual_mmio_write_response_formal_top.write_req_wdata = 0u;
  axi_llc_subsystem_dual_mmio_write_response_formal_top.write_req_wstrb = 0u;
  axi_llc_subsystem_dual_mmio_write_response_formal_top.mmio_axi_bvalid = false;
  axi_llc_subsystem_dual_mmio_write_response_formal_top.mmio_axi_bid = false;
  axi_llc_subsystem_dual_mmio_write_response_formal_top.mmio_axi_bresp = 0u;
}

int main(void)
{
  const uint32_t addr = 0x10000008u;
  const uint8_t req_id = 11u;
  const uint32_t wdata = 0x5aa55aa5u;
  const uint8_t wstrb = 0x0fu;
  const uint8_t bresp = 2u;
  bool request_seen = false;
  bool accepted_seen = false;
  bool seen_aw = false;
  bool seen_w = false;
  bool awid = false;
  bool b_accepted = false;
  bool seen_resp = false;

  axi_llc_subsystem_dual_mmio_write_response_formal_top.rst_n = false;
  for(unsigned reset_cycle = 0u; reset_cycle < 3u; reset_cycle++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }

  axi_llc_subsystem_dual_mmio_write_response_formal_top.rst_n = true;
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
    axi_llc_subsystem_dual_mmio_write_response_formal_top.write_req_valid =
        !request_seen;
    axi_llc_subsystem_dual_mmio_write_response_formal_top.write_req_addr = addr;
    axi_llc_subsystem_dual_mmio_write_response_formal_top.write_req_id =
        req_id;
    axi_llc_subsystem_dual_mmio_write_response_formal_top.write_req_wdata =
        wdata;
    axi_llc_subsystem_dual_mmio_write_response_formal_top.write_req_wstrb =
        wstrb;
    axi_llc_subsystem_dual_mmio_write_response_formal_top.mmio_axi_bvalid =
        seen_aw && seen_w && !b_accepted;
    axi_llc_subsystem_dual_mmio_write_response_formal_top.mmio_axi_bid = awid;
    axi_llc_subsystem_dual_mmio_write_response_formal_top.mmio_axi_bresp =
        bresp;
    set_inputs();

    assert(!axi_llc_subsystem_dual_mmio_write_response_formal_top
                .ddr_axi_arvalid);
    assert(!axi_llc_subsystem_dual_mmio_write_response_formal_top
                .ddr_axi_awvalid);
    assert(!axi_llc_subsystem_dual_mmio_write_response_formal_top
                .ddr_axi_wvalid);

    if(axi_llc_subsystem_dual_mmio_write_response_formal_top.write_req_valid &&
       axi_llc_subsystem_dual_mmio_write_response_formal_top.write_req_ready)
    {
      request_seen = true;
    }

    if(axi_llc_subsystem_dual_mmio_write_response_formal_top
           .write_req_accepted)
    {
      accepted_seen = true;
    }

    if(axi_llc_subsystem_dual_mmio_write_response_formal_top.mmio_axi_awvalid)
    {
      seen_aw = true;
      awid = axi_llc_subsystem_dual_mmio_write_response_formal_top
                 .mmio_axi_awid;
      assert(axi_llc_subsystem_dual_mmio_write_response_formal_top
                 .mmio_axi_awaddr == addr);
      assert(axi_llc_subsystem_dual_mmio_write_response_formal_top
                 .mmio_axi_awlen == 0u);
      assert(axi_llc_subsystem_dual_mmio_write_response_formal_top
                 .mmio_axi_awsize == 2u);
      assert(axi_llc_subsystem_dual_mmio_write_response_formal_top
                 .mmio_axi_awburst == 1u);
    }

    if(axi_llc_subsystem_dual_mmio_write_response_formal_top.mmio_axi_wvalid)
    {
      seen_w = true;
      assert(axi_llc_subsystem_dual_mmio_write_response_formal_top
                 .mmio_axi_wdata == wdata);
      assert(axi_llc_subsystem_dual_mmio_write_response_formal_top
                 .mmio_axi_wstrb == wstrb);
      assert(axi_llc_subsystem_dual_mmio_write_response_formal_top
                 .mmio_axi_wlast);
    }

    if(axi_llc_subsystem_dual_mmio_write_response_formal_top.mmio_axi_bvalid)
    {
      assert(axi_llc_subsystem_dual_mmio_write_response_formal_top
                 .mmio_axi_bready);
    }

    if(axi_llc_subsystem_dual_mmio_write_response_formal_top.mmio_axi_bvalid &&
       axi_llc_subsystem_dual_mmio_write_response_formal_top.mmio_axi_bready)
    {
      b_accepted = true;
    }

    if(axi_llc_subsystem_dual_mmio_write_response_formal_top.write_resp_valid)
    {
      seen_resp = true;
      assert(axi_llc_subsystem_dual_mmio_write_response_formal_top
                 .write_resp_id == req_id);
      assert(axi_llc_subsystem_dual_mmio_write_response_formal_top
                 .write_resp_code == bresp);
    }

    next_timeframe();
  }

  assert(request_seen);
  assert(accepted_seen);
  assert(seen_aw);
  assert(seen_w);
  assert(b_accepted);
  assert(seen_resp);
}
