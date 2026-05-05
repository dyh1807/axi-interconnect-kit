#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

uint8_t nondet_uint8_t(void);
uint32_t nondet_uint32_t(void);
bool nondet_bool(void);

struct module_axi_llc_subsystem_dual_mmio_write_route_formal_top
{
  bool clk;
  bool rst_n;
  bool write_req_valid;
  uint32_t write_req_addr;
  uint8_t write_req_total_size;
  uint8_t write_req_id;
  uint32_t write_req_wdata;
  uint8_t write_req_wstrb;
  bool write_req_ready;
  bool write_req_accepted;
  bool mmio_axi_awvalid;
  bool mmio_axi_wvalid;
  bool mmio_axi_arvalid;
  uint8_t mmio_axi_awid;
  uint32_t mmio_axi_awaddr;
  uint8_t mmio_axi_awlen;
  uint8_t mmio_axi_awsize;
  uint8_t mmio_axi_awburst;
  uint32_t mmio_axi_wdata;
  uint8_t mmio_axi_wstrb;
  bool mmio_axi_wlast;
  bool ddr_axi_arvalid;
  bool ddr_axi_awvalid;
  bool ddr_axi_wvalid;
  uint8_t active_mode;
  bool reconfig_busy;
  bool config_error;
};

extern struct module_axi_llc_subsystem_dual_mmio_write_route_formal_top
    axi_llc_subsystem_dual_mmio_write_route_formal_top;

static void drive_idle(void)
{
  axi_llc_subsystem_dual_mmio_write_route_formal_top.write_req_valid = false;
  axi_llc_subsystem_dual_mmio_write_route_formal_top.write_req_addr = 0u;
  axi_llc_subsystem_dual_mmio_write_route_formal_top.write_req_total_size = 0u;
  axi_llc_subsystem_dual_mmio_write_route_formal_top.write_req_id = 0u;
  axi_llc_subsystem_dual_mmio_write_route_formal_top.write_req_wdata = 0u;
  axi_llc_subsystem_dual_mmio_write_route_formal_top.write_req_wstrb = 0u;
}

int main(void)
{
  const bool unsupported_mmio_case = nondet_bool();
  const uint32_t addr = 0x10000000u + ((uint32_t)(nondet_uint8_t() & 0xfcu));
  const uint8_t total_size = unsupported_mmio_case ? 63u : 3u;
  const uint8_t req_id = nondet_uint8_t() & 0x0fu;
  const uint32_t wdata = nondet_uint32_t();
  const uint8_t wstrb = nondet_uint8_t() & 0x0fu;
  bool request_seen = false;
  bool accepted_seen = false;
  bool seen_aw = false;
  bool seen_w = false;

  axi_llc_subsystem_dual_mmio_write_route_formal_top.rst_n = false;
  for(unsigned reset_cycle = 0u; reset_cycle < 3u; reset_cycle++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }

  axi_llc_subsystem_dual_mmio_write_route_formal_top.rst_n = true;
  for(unsigned warmup = 0u; warmup < 12u; warmup++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }
  drive_idle();
  set_inputs();

  for(unsigned step = 0u; step < 20u; step++)
  {
    axi_llc_subsystem_dual_mmio_write_route_formal_top.write_req_valid =
        !request_seen;
    axi_llc_subsystem_dual_mmio_write_route_formal_top.write_req_addr = addr;
    axi_llc_subsystem_dual_mmio_write_route_formal_top.write_req_total_size =
        total_size;
    axi_llc_subsystem_dual_mmio_write_route_formal_top.write_req_id = req_id;
    axi_llc_subsystem_dual_mmio_write_route_formal_top.write_req_wdata = wdata;
    axi_llc_subsystem_dual_mmio_write_route_formal_top.write_req_wstrb = wstrb;
    set_inputs();

    assert(!axi_llc_subsystem_dual_mmio_write_route_formal_top.ddr_axi_arvalid);
    assert(!axi_llc_subsystem_dual_mmio_write_route_formal_top.ddr_axi_awvalid);
    assert(!axi_llc_subsystem_dual_mmio_write_route_formal_top.ddr_axi_wvalid);
    assert(!axi_llc_subsystem_dual_mmio_write_route_formal_top.mmio_axi_arvalid);

    if(unsupported_mmio_case)
    {
      assert(
          !axi_llc_subsystem_dual_mmio_write_route_formal_top.write_req_ready);
      assert(!axi_llc_subsystem_dual_mmio_write_route_formal_top
                  .write_req_accepted);
      assert(
          !axi_llc_subsystem_dual_mmio_write_route_formal_top.mmio_axi_awvalid);
      assert(
          !axi_llc_subsystem_dual_mmio_write_route_formal_top.mmio_axi_wvalid);
    }

    if(axi_llc_subsystem_dual_mmio_write_route_formal_top.write_req_valid &&
       axi_llc_subsystem_dual_mmio_write_route_formal_top.write_req_ready)
    {
      request_seen = true;
    }

    if(axi_llc_subsystem_dual_mmio_write_route_formal_top.write_req_accepted)
      accepted_seen = true;

    if(axi_llc_subsystem_dual_mmio_write_route_formal_top.mmio_axi_awvalid)
    {
      seen_aw = true;
      assert(axi_llc_subsystem_dual_mmio_write_route_formal_top
                 .mmio_axi_awaddr == addr);
      assert(axi_llc_subsystem_dual_mmio_write_route_formal_top
                 .mmio_axi_awlen == 0u);
      assert(axi_llc_subsystem_dual_mmio_write_route_formal_top
                 .mmio_axi_awsize == 2u);
      assert(axi_llc_subsystem_dual_mmio_write_route_formal_top
                 .mmio_axi_awburst == 1u);
    }

    if(axi_llc_subsystem_dual_mmio_write_route_formal_top.mmio_axi_wvalid)
    {
      seen_w = true;
      assert(axi_llc_subsystem_dual_mmio_write_route_formal_top
                 .mmio_axi_wdata == wdata);
      assert(axi_llc_subsystem_dual_mmio_write_route_formal_top
                 .mmio_axi_wstrb == wstrb);
      assert(axi_llc_subsystem_dual_mmio_write_route_formal_top
                 .mmio_axi_wlast);
    }

    next_timeframe();
  }

  if(unsupported_mmio_case)
  {
    assert(!request_seen);
    assert(!accepted_seen);
    assert(!seen_aw);
    assert(!seen_w);
  }
  else
  {
    assert(request_seen);
    assert(accepted_seen);
    assert(seen_aw);
    assert(seen_w);
  }
}
