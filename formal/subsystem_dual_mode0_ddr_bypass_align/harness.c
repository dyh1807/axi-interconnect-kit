#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void next_timeframe(void);
void set_inputs(void);

uint8_t nondet_uint8_t(void);

struct module_axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
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
  bool write_req_valid;
  uint32_t write_req_addr;
  uint8_t write_req_total_size;
  uint8_t write_req_id;
  uint64_t write_req_wdata;
  uint8_t write_req_wstrb;
  bool write_req_ready;
  bool write_req_accepted;
  bool ddr_axi_arvalid;
  uint32_t ddr_axi_araddr;
  uint8_t ddr_axi_arlen;
  uint8_t ddr_axi_arsize;
  uint8_t ddr_axi_arburst;
  bool ddr_axi_awvalid;
  uint32_t ddr_axi_awaddr;
  uint8_t ddr_axi_awlen;
  uint8_t ddr_axi_awsize;
  uint8_t ddr_axi_awburst;
  bool ddr_axi_wvalid;
  uint64_t ddr_axi_wdata;
  uint8_t ddr_axi_wstrb;
  bool ddr_axi_wlast;
  bool mmio_axi_arvalid;
  bool mmio_axi_awvalid;
  bool mmio_axi_wvalid;
  bool config_error;
};

extern struct module_axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
    axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top;

static void drive_idle(void)
{
  axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top.read_req_valid =
      false;
  axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top.read_req_addr = 0u;
  axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
      .read_req_total_size = 0u;
  axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top.read_req_id = 0u;
  axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top.write_req_valid =
      false;
  axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top.write_req_addr = 0u;
  axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
      .write_req_total_size = 0u;
  axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top.write_req_id = 0u;
  axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top.write_req_wdata = 0u;
  axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top.write_req_wstrb = 0u;
}

int main(void)
{
  const bool read_8b = (nondet_uint8_t() & 1u) != 0u;
  const uint8_t read_size = read_8b ? 7u : 3u;
  const uint8_t write_size = 3u;
  const uint8_t read_byte_offset =
      read_8b ? 0u : (uint8_t)(nondet_uint8_t() % 5u);
  const uint32_t read_addr = 0x40000000u + read_byte_offset;
  const uint32_t write_addr = 0x40000104u;
  const uint8_t read_id = 3u;
  const uint8_t write_id = 5u;
  const uint64_t write_data = 0x00000000a5c33c5au;
  const uint8_t write_strb = 0x0fu;
  const AxiBridgeDownstreamIssueShape read_ref =
      axi_bridge_downstream_read_issue_shape(false, read_addr, read_size, 8u,
                                             8u, false);
  const AxiBridgeDownstreamIssueShape write_ref =
      axi_bridge_downstream_write_issue_shape(false, write_addr, write_size, 8u,
                                              8u, false);
  const AxiBridgeWritePack64 write_pack_ref =
      axi_bridge_write_pack64((uint64_t)write_data, write_strb, write_addr,
                              write_ref.issue_addr, 0u, true, 8u, 8u);
  bool read_request_seen = false;
  bool write_request_seen = false;
  bool read_accepted_seen = false;
  bool write_accepted_seen = false;
  bool seen_ddr_ar = false;
  bool seen_ddr_aw = false;
  bool seen_ddr_w = false;

  assert(read_ref.issue_addr == (read_addr & ~7u));
  assert(read_ref.issue_size == 7u);
  assert(read_ref.extract_from_aligned_beat);
  assert(write_ref.issue_addr == (write_addr & ~7u));
  assert(write_ref.issue_size == 7u);

  axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top.rst_n = false;
  for(unsigned reset_cycle = 0u; reset_cycle < 3u; reset_cycle++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }

  axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top.rst_n = true;
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
    axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top.read_req_valid =
        !read_request_seen;
    axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top.read_req_addr =
        read_addr;
    axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
        .read_req_total_size = read_size;
    axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top.read_req_id =
        read_id;
    axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top.write_req_valid =
        !write_request_seen;
    axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top.write_req_addr =
        write_addr;
    axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
        .write_req_total_size = write_size;
    axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top.write_req_id =
        write_id;
    axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top.write_req_wdata =
        write_data;
    axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top.write_req_wstrb =
        write_strb;
    set_inputs();

    assert(!axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
                .mmio_axi_arvalid);
    assert(!axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
                .mmio_axi_awvalid);
    assert(!axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
                .mmio_axi_wvalid);
    assert(!axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
                .config_error);

    if(axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
           .read_req_valid &&
       axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top.read_req_ready)
    {
      read_request_seen = true;
    }

    if(axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
           .write_req_valid &&
       axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
           .write_req_ready)
    {
      write_request_seen = true;
    }

    if(axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
           .read_req_accepted)
    {
      read_accepted_seen = true;
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
                 .read_req_accepted_id == read_id);
    }

    if(axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
           .write_req_accepted)
    {
      write_accepted_seen = true;
    }

    if(axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
           .ddr_axi_arvalid)
    {
      seen_ddr_ar = true;
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
                 .ddr_axi_araddr == read_ref.issue_addr);
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
                 .ddr_axi_arlen == read_ref.axi_len);
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
                 .ddr_axi_arsize == read_ref.axi_size);
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
                 .ddr_axi_arburst == 1u);
    }

    if(axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
           .ddr_axi_awvalid)
    {
      seen_ddr_aw = true;
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
                 .ddr_axi_awaddr == write_ref.issue_addr);
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
                 .ddr_axi_awlen == write_ref.axi_len);
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
                 .ddr_axi_awsize == write_ref.axi_size);
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
                 .ddr_axi_awburst == 1u);
    }

    if(axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
           .ddr_axi_wvalid)
    {
      seen_ddr_w = true;
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
                 .ddr_axi_wdata == write_pack_ref.axi_wdata);
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
                 .ddr_axi_wstrb == write_pack_ref.axi_wstrb);
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_align_formal_top
                 .ddr_axi_wlast);
    }

    next_timeframe();
  }

  assert(read_request_seen);
  assert(write_request_seen);
  assert(read_accepted_seen);
  assert(write_accepted_seen);
  assert(seen_ddr_ar);
  assert(seen_ddr_aw);
  assert(seen_ddr_w);
}
