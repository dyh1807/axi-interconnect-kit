#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

struct module_axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
{
  bool clk;
  bool rst_n;
  bool read_req_valid;
  uint32_t read_req_addr;
  uint8_t read_req_id;
  bool read_req_ready;
  bool read_req_accepted;
  uint8_t read_req_accepted_id;
  bool write_req_valid;
  uint32_t write_req_addr;
  uint8_t write_req_id;
  uint32_t write_req_wdata;
  uint8_t write_req_wstrb;
  bool write_req_ready;
  bool write_req_accepted;
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
  bool mmio_axi_arvalid;
  uint32_t mmio_axi_araddr;
  uint8_t mmio_axi_arlen;
  uint8_t mmio_axi_arsize;
  uint8_t mmio_axi_arburst;
  bool mmio_axi_awvalid;
  bool mmio_axi_wvalid;
};

extern struct
    module_axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
        axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top;

static void drive_idle(void)
{
  axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
      .read_req_valid = false;
  axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
      .read_req_addr = 0u;
  axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
      .read_req_id = 0u;
  axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
      .write_req_valid = false;
  axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
      .write_req_addr = 0u;
  axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
      .write_req_id = 0u;
  axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
      .write_req_wdata = 0u;
  axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
      .write_req_wstrb = 0u;
}

int main(void)
{
  const uint32_t ddr_addr = 0x40000008u;
  const uint32_t mmio_addr = 0x10000004u;
  const uint8_t read_id = 3u;
  const uint8_t write_id = 5u;
  const uint32_t wdata = 0xa53cc35au;
  const uint8_t wstrb = 0x0fu;
  bool read_request_seen = false;
  bool write_request_seen = false;
  bool read_accepted_seen = false;
  bool write_accepted_seen = false;
  bool seen_ddr_aw = false;
  bool seen_ddr_w = false;
  bool seen_mmio_ar = false;

  axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top.rst_n =
      false;
  for(unsigned reset_cycle = 0u; reset_cycle < 3u; reset_cycle++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }

  axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top.rst_n =
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
    const bool write_pending = seen_ddr_aw && seen_ddr_w;

    axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
        .write_req_valid = !write_request_seen;
    axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
        .write_req_addr = ddr_addr;
    axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
        .write_req_id = write_id;
    axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
        .write_req_wdata = wdata;
    axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
        .write_req_wstrb = wstrb;
    axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
        .read_req_valid = write_pending && !read_request_seen;
    axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
        .read_req_addr = mmio_addr;
    axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
        .read_req_id = read_id;
    set_inputs();

    assert(!axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
                .ddr_axi_arvalid);
    assert(!axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
                .mmio_axi_awvalid);
    assert(!axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
                .mmio_axi_wvalid);

    if(axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
           .write_req_valid &&
       axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
           .write_req_ready)
    {
      write_request_seen = true;
    }

    if(axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
           .write_req_accepted)
      write_accepted_seen = true;

    if(axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
           .ddr_axi_awvalid)
    {
      seen_ddr_aw = true;
      assert(axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
                 .ddr_axi_awaddr == ddr_addr);
      assert(axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
                 .ddr_axi_awlen == 0u);
      assert(axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
                 .ddr_axi_awsize == 3u);
      assert(axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
                 .ddr_axi_awburst == 1u);
    }

    if(axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
           .ddr_axi_wvalid)
    {
      seen_ddr_w = true;
      assert(axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
                 .ddr_axi_wdata == (uint64_t)wdata);
      assert(axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
                 .ddr_axi_wstrb == wstrb);
      assert(axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
                 .ddr_axi_wlast);
    }

    if(axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
           .read_req_valid &&
       axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
           .read_req_ready)
    {
      read_request_seen = true;
    }

    if(axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
           .read_req_accepted)
    {
      read_accepted_seen = true;
      assert(axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
                 .read_req_accepted_id == read_id);
    }

    if(axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
           .mmio_axi_arvalid)
    {
      seen_mmio_ar = true;
      assert(write_pending);
      assert(axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
                 .mmio_axi_araddr == mmio_addr);
      assert(axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
                 .mmio_axi_arlen == 0u);
      assert(axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
                 .mmio_axi_arsize == 2u);
      assert(axi_llc_subsystem_dual_ddr_write_mmio_read_independent_formal_top
                 .mmio_axi_arburst == 1u);
    }

    next_timeframe();
  }

  assert(write_request_seen);
  assert(write_accepted_seen);
  assert(seen_ddr_aw);
  assert(seen_ddr_w);
  assert(read_request_seen);
  assert(read_accepted_seen);
  assert(seen_mmio_ar);
}
