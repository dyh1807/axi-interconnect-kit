#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

struct module_axi_llc_axi_bridge_dual_multi_read_outstanding_formal_top
{
  bool clk;
  bool rst_n;
  bool cache_req_valid;
  uint32_t cache_req_addr;
  bool cache_req_ready;
  bool ddr_axi_arvalid;
  bool ddr_axi_arid;
  uint32_t ddr_axi_araddr;
  bool mmio_axi_arvalid;
  bool cache_resp_valid;
};

extern struct module_axi_llc_axi_bridge_dual_multi_read_outstanding_formal_top
    axi_llc_axi_bridge_dual_multi_read_outstanding_formal_top;

static void drive_idle(bool rst_n)
{
  axi_llc_axi_bridge_dual_multi_read_outstanding_formal_top.rst_n = rst_n;
  axi_llc_axi_bridge_dual_multi_read_outstanding_formal_top.cache_req_valid =
      false;
  axi_llc_axi_bridge_dual_multi_read_outstanding_formal_top.cache_req_addr =
      0u;
  set_inputs();
}

static void drive_read(uint32_t addr)
{
  axi_llc_axi_bridge_dual_multi_read_outstanding_formal_top.rst_n = true;
  axi_llc_axi_bridge_dual_multi_read_outstanding_formal_top.cache_req_valid =
      true;
  axi_llc_axi_bridge_dual_multi_read_outstanding_formal_top.cache_req_addr =
      addr;
  set_inputs();
}

static void sample_ar(uint32_t addr0, uint32_t addr1, bool *seen0,
                      bool *seen1, bool *seen_id0, bool *seen_id1)
{
  assert(!axi_llc_axi_bridge_dual_multi_read_outstanding_formal_top
              .mmio_axi_arvalid);
  assert(!axi_llc_axi_bridge_dual_multi_read_outstanding_formal_top
              .cache_resp_valid);

  if(axi_llc_axi_bridge_dual_multi_read_outstanding_formal_top.ddr_axi_arvalid)
  {
    const uint32_t araddr =
        axi_llc_axi_bridge_dual_multi_read_outstanding_formal_top
            .ddr_axi_araddr;
    assert(araddr == addr0 || araddr == addr1);

    if(araddr == addr0)
      *seen0 = true;
    if(araddr == addr1)
      *seen1 = true;

    if(axi_llc_axi_bridge_dual_multi_read_outstanding_formal_top.ddr_axi_arid)
      *seen_id1 = true;
    else
      *seen_id0 = true;
  }
}

int main(void)
{
  const uint32_t addr0 = 0x40000000u;
  const uint32_t addr1 = 0x40000008u;
  bool seen0 = false;
  bool seen1 = false;
  bool seen_id0 = false;
  bool seen_id1 = false;

  drive_idle(false);
  next_timeframe();

  drive_idle(true);
  next_timeframe();

  drive_read(addr0);
  assert(axi_llc_axi_bridge_dual_multi_read_outstanding_formal_top
             .cache_req_ready);
  next_timeframe();

  drive_idle(true);
  sample_ar(addr0, addr1, &seen0, &seen1, &seen_id0, &seen_id1);

  drive_read(addr1);
  assert(axi_llc_axi_bridge_dual_multi_read_outstanding_formal_top
             .cache_req_ready);
  next_timeframe();

  drive_idle(true);
  for(unsigned step = 0; step < 5u; step++)
  {
    sample_ar(addr0, addr1, &seen0, &seen1, &seen_id0, &seen_id1);
    next_timeframe();
    drive_idle(true);
  }

  assert(seen0);
  assert(seen1);
  assert(seen_id0);
  assert(seen_id1);
}
