#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

uint32_t nondet_uint32_t(void);

struct module_axi_llc_axi_bridge_prod_width_cacheline_aw_shape_formal_top
{
  bool clk;
  bool rst_n;
  bool cache_req_valid;
  uint32_t cache_req_addr;
  bool cache_req_ready;
  bool axi_awvalid;
  uint32_t axi_awaddr;
  uint8_t axi_awlen;
  uint8_t axi_awsize;
  uint8_t axi_awburst;
};

extern struct module_axi_llc_axi_bridge_prod_width_cacheline_aw_shape_formal_top
    axi_llc_axi_bridge_prod_width_cacheline_aw_shape_formal_top;

static void drive_idle(void)
{
  axi_llc_axi_bridge_prod_width_cacheline_aw_shape_formal_top.cache_req_valid =
      false;
  axi_llc_axi_bridge_prod_width_cacheline_aw_shape_formal_top.cache_req_addr =
      0u;
}

int main(void)
{
  const uint32_t addr = 0x40000000u + (nondet_uint32_t() & 0x0000ffc0u);
  bool seen_aw = false;

  axi_llc_axi_bridge_prod_width_cacheline_aw_shape_formal_top.rst_n = false;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_prod_width_cacheline_aw_shape_formal_top.rst_n = true;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_prod_width_cacheline_aw_shape_formal_top.cache_req_valid =
      true;
  axi_llc_axi_bridge_prod_width_cacheline_aw_shape_formal_top.cache_req_addr =
      addr;
  set_inputs();
  assert(
      axi_llc_axi_bridge_prod_width_cacheline_aw_shape_formal_top
          .cache_req_ready);

  for(unsigned step = 0u; step < 4u; step++)
  {
    next_timeframe();
    drive_idle();
    set_inputs();
    if(axi_llc_axi_bridge_prod_width_cacheline_aw_shape_formal_top.axi_awvalid)
    {
      seen_aw = true;
      assert(axi_llc_axi_bridge_prod_width_cacheline_aw_shape_formal_top
                 .axi_awaddr == addr);
      assert(axi_llc_axi_bridge_prod_width_cacheline_aw_shape_formal_top
                 .axi_awlen == 1u);
      assert(axi_llc_axi_bridge_prod_width_cacheline_aw_shape_formal_top
                 .axi_awsize == 5u);
      assert(axi_llc_axi_bridge_prod_width_cacheline_aw_shape_formal_top
                 .axi_awburst == 1u);
    }
  }

  assert(seen_aw);
}
