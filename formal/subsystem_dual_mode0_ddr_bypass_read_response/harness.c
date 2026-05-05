#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void next_timeframe(void);
void set_inputs(void);

#ifndef FORMAL_READ_REQ_ADDR
#define FORMAL_READ_REQ_ADDR 0x40000004u
#endif

#ifndef FORMAL_READ_REQ_TOTAL_SIZE
#define FORMAL_READ_REQ_TOTAL_SIZE 3u
#endif

#ifndef FORMAL_READ_RDATA
#define FORMAL_READ_RDATA 0x8877665544332211ull
#endif

struct module_axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
{
  bool clk;
  bool rst_n;
  bool read_req_valid;
  uint32_t read_req_addr;
  uint8_t read_req_total_size;
  uint8_t read_req_id;
  bool read_req_ready;
  bool read_req_accepted;
  uint8_t read_req_accepted_id;
  bool read_resp_valid;
  uint64_t read_resp_data;
  uint8_t read_resp_id;
  bool ddr_axi_arvalid;
  uint32_t ddr_axi_araddr;
  uint8_t ddr_axi_arlen;
  uint8_t ddr_axi_arsize;
  uint8_t ddr_axi_arburst;
  bool ddr_axi_rvalid;
  bool ddr_axi_rready;
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

extern struct
    module_axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
        axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top;

static void drive_idle(void)
{
  axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
      .read_req_valid = false;
  axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
      .read_req_addr = 0u;
  axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
      .read_req_total_size = 0u;
  axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
      .read_req_id = 0u;
  axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
      .ddr_axi_rvalid = false;
  axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
      .ddr_axi_rdata = 0u;
  axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
      .ddr_axi_rresp = 0u;
  axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
      .ddr_axi_rlast = false;
}

int main(void)
{
  const uint32_t addr = FORMAL_READ_REQ_ADDR;
  const uint8_t read_size = FORMAL_READ_REQ_TOTAL_SIZE;
  const uint8_t req_id = 7u;
  const uint64_t rdata = FORMAL_READ_RDATA;
  const AxiBridgeDownstreamIssueShape read_ref =
      axi_bridge_downstream_read_issue_shape(false, addr, read_size, 8u, 8u,
                                             false);
  const AxiBridgeReadPack64 read_pack_ref =
      axi_bridge_read_pack64(0u, rdata, addr, read_ref.issue_addr, 0u,
                             read_ref.extract_from_aligned_beat, 8u, 8u);
  bool request_seen = false;
  bool accepted_seen = false;
  bool seen_ar = false;
  bool r_accepted = false;
  bool seen_resp = false;

  assert(read_ref.issue_addr == (addr & ~7u));
  assert(read_ref.issue_size == 7u);
  assert(read_ref.extract_from_aligned_beat);

  axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top.rst_n =
      false;
  for(unsigned reset_cycle = 0u; reset_cycle < 3u; reset_cycle++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }

  axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top.rst_n =
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
    axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
        .read_req_valid = !request_seen;
    axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
        .read_req_addr = addr;
    axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
        .read_req_total_size = read_size;
    axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
        .read_req_id = req_id;
    axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
        .ddr_axi_rvalid = seen_ar && !r_accepted;
    axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
        .ddr_axi_rdata = rdata;
    axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
        .ddr_axi_rresp = 0u;
    axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
        .ddr_axi_rlast = seen_ar && !r_accepted;
    set_inputs();

    assert(!axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
                .ddr_axi_awvalid);
    assert(!axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
                .ddr_axi_wvalid);
    assert(!axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
                .mmio_axi_arvalid);
    assert(!axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
                .mmio_axi_awvalid);
    assert(!axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
                .mmio_axi_wvalid);
    assert(!axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
                .config_error);

    if(axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
           .read_req_valid &&
       axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
           .read_req_ready)
    {
      request_seen = true;
    }

    if(axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
           .read_req_accepted)
    {
      accepted_seen = true;
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
                 .read_req_accepted_id == req_id);
    }

    if(axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
           .ddr_axi_arvalid)
    {
      seen_ar = true;
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
                 .ddr_axi_araddr == read_ref.issue_addr);
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
                 .ddr_axi_arlen == read_ref.axi_len);
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
                 .ddr_axi_arsize == read_ref.axi_size);
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
                 .ddr_axi_arburst == 1u);
    }

    if(axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
           .ddr_axi_rvalid &&
       axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
           .ddr_axi_rready)
    {
      r_accepted = true;
    }

    if(axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
           .read_resp_valid)
    {
      seen_resp = true;
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
                 .read_resp_id == req_id);
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_read_response_formal_top
                 .read_resp_data == read_pack_ref.final_data);
    }

    next_timeframe();
  }

  assert(request_seen);
  assert(accepted_seen);
  assert(seen_ar);
  assert(r_accepted);
  assert(seen_resp);
}
