#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

uint32_t nondet_uint32_t(void);
uint8_t nondet_uint8_t(void);

struct module_axi_llc_axi_bridge_prod_width_cacheline_ar_shape_formal_top
{
  bool clk;
  bool rst_n;
  bool cache_req_valid;
  uint32_t cache_req_addr;
  uint8_t cache_req_id;
  bool cache_req_ready;
  bool axi_arvalid;
  uint32_t axi_araddr;
  uint8_t axi_arlen;
  uint8_t axi_arsize;
  uint8_t axi_arburst;
};

extern struct module_axi_llc_axi_bridge_prod_width_cacheline_ar_shape_formal_top
    axi_llc_axi_bridge_prod_width_cacheline_ar_shape_formal_top;

static void drive_idle(void)
{
  axi_llc_axi_bridge_prod_width_cacheline_ar_shape_formal_top.cache_req_valid =
      false;
  axi_llc_axi_bridge_prod_width_cacheline_ar_shape_formal_top.cache_req_addr =
      0u;
  axi_llc_axi_bridge_prod_width_cacheline_ar_shape_formal_top.cache_req_id =
      0u;
}

int main(void)
{
  const uint32_t addr = 0x40000000u + (nondet_uint32_t() & 0x0000ffc0u);
  const uint8_t req_id = nondet_uint8_t() & 0x3fu;
  bool seen_ar = false;

  axi_llc_axi_bridge_prod_width_cacheline_ar_shape_formal_top.rst_n = false;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_prod_width_cacheline_ar_shape_formal_top.rst_n = true;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_prod_width_cacheline_ar_shape_formal_top.cache_req_valid =
      true;
  axi_llc_axi_bridge_prod_width_cacheline_ar_shape_formal_top.cache_req_addr =
      addr;
  axi_llc_axi_bridge_prod_width_cacheline_ar_shape_formal_top.cache_req_id =
      req_id;
  set_inputs();
  assert(
      axi_llc_axi_bridge_prod_width_cacheline_ar_shape_formal_top
          .cache_req_ready);

  for(unsigned step = 0u; step < 4u; step++)
  {
    next_timeframe();
    drive_idle();
    set_inputs();
    if(axi_llc_axi_bridge_prod_width_cacheline_ar_shape_formal_top.axi_arvalid)
    {
      seen_ar = true;
      assert(axi_llc_axi_bridge_prod_width_cacheline_ar_shape_formal_top
                 .axi_araddr == addr);
      assert(axi_llc_axi_bridge_prod_width_cacheline_ar_shape_formal_top
                 .axi_arlen == 1u);
      assert(axi_llc_axi_bridge_prod_width_cacheline_ar_shape_formal_top
                 .axi_arsize == 5u);
      assert(axi_llc_axi_bridge_prod_width_cacheline_ar_shape_formal_top
                 .axi_arburst == 1u);
    }
  }

  assert(seen_ar);
}
