#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

struct module_axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
{
  bool clk;
  bool rst_n;
  bool cache_req_valid;
  bool cache_req_write;
  uint32_t cache_req_addr;
  uint8_t cache_req_id;
  uint8_t cache_req_size;
  uint64_t cache_req_wdata;
  uint8_t cache_req_wstrb;
  bool cache_req_ready;
  bool cache_resp_valid;
  bool ddr_axi_arvalid;
  bool ddr_axi_arid;
  uint32_t ddr_axi_araddr;
  bool ddr_axi_awvalid;
  bool ddr_axi_awid;
  uint32_t ddr_axi_awaddr;
  bool ddr_axi_wvalid;
  bool ddr_axi_wlast;
  bool mmio_axi_arvalid;
  bool mmio_axi_awvalid;
  bool mmio_axi_wvalid;
};

extern struct
    module_axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
        axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top;

static void drive_idle(void)
{
  axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
      .cache_req_valid = false;
  axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
      .cache_req_write = false;
  axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
      .cache_req_addr = 0u;
  axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top.cache_req_id =
      0u;
  axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
      .cache_req_size = 7u;
  axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
      .cache_req_wdata = 0u;
  axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
      .cache_req_wstrb = 0u;
}

static void drive_read(uint32_t addr, uint8_t id)
{
  axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
      .cache_req_valid = true;
  axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
      .cache_req_write = false;
  axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
      .cache_req_addr = addr;
  axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top.cache_req_id =
      id;
  axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
      .cache_req_size = 7u;
  axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
      .cache_req_wdata = 0u;
  axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
      .cache_req_wstrb = 0u;
}

static void drive_write(uint32_t addr, uint8_t id, uint64_t data)
{
  axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
      .cache_req_valid = true;
  axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
      .cache_req_write = true;
  axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
      .cache_req_addr = addr;
  axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top.cache_req_id =
      id;
  axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
      .cache_req_size = 7u;
  axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
      .cache_req_wdata = data;
  axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
      .cache_req_wstrb = 0xffu;
}

static void sample_write_issue(uint32_t addr, bool *seen_aw, bool *seen_w)
{
  assert(!axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
              .mmio_axi_awvalid);
  assert(!axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
              .mmio_axi_wvalid);
  assert(!axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
              .cache_resp_valid);

  if(axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
         .ddr_axi_awvalid)
  {
    assert(axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
               .ddr_axi_awaddr == addr);
    *seen_aw = true;
  }

  if(axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
         .ddr_axi_wvalid)
  {
    assert(axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
               .ddr_axi_wlast);
    *seen_w = true;
  }
}

static void sample_read_issue(uint32_t addr, bool *seen_ar)
{
  assert(!axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
              .mmio_axi_arvalid);
  assert(!axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
              .cache_resp_valid);

  if(axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
         .ddr_axi_arvalid)
  {
    assert(axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
               .ddr_axi_araddr == addr);
    *seen_ar = true;
  }
}

int main(void)
{
  const uint32_t write_addr = 0x40000000u;
  const uint32_t read_addr = 0x40000008u;
  bool seen_aw = false;
  bool seen_w = false;
  bool seen_ar = false;

  axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top.rst_n = false;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top.rst_n = true;
  drive_idle();
  set_inputs();
  next_timeframe();

  drive_write(write_addr, 11u, 0x8877665544332211ull);
  set_inputs();
  assert(axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
             .cache_req_ready);

  next_timeframe();
  set_inputs();
  sample_write_issue(write_addr, &seen_aw, &seen_w);
  for(unsigned step = 0; step < 5u && !(seen_aw && seen_w); step++)
  {
    drive_idle();
    set_inputs();
    sample_write_issue(write_addr, &seen_aw, &seen_w);
    next_timeframe();
  }
  assert(seen_aw);
  assert(seen_w);

  drive_read(read_addr, 5u);
  set_inputs();
  assert(axi_llc_axi_bridge_dual_write_then_read_outstanding_formal_top
             .cache_req_ready);

  next_timeframe();
  set_inputs();
  sample_read_issue(read_addr, &seen_ar);
  for(unsigned step = 0; step < 5u; step++)
  {
    drive_idle();
    set_inputs();
    sample_read_issue(read_addr, &seen_ar);
    next_timeframe();
  }

  assert(seen_ar);
}
