#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

uint32_t nondet_uint32_t(void);

struct module_axi_llc_axi_bridge_prod_width_cacheline_write_shape_formal_top
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
  bool axi_wvalid;
  uint64_t axi_wdata_0;
  uint64_t axi_wdata_1;
  uint64_t axi_wdata_2;
  uint64_t axi_wdata_3;
  uint32_t axi_wstrb;
  bool axi_wlast;
};

extern struct
    module_axi_llc_axi_bridge_prod_width_cacheline_write_shape_formal_top
        axi_llc_axi_bridge_prod_width_cacheline_write_shape_formal_top;

static void drive_idle(void)
{
  axi_llc_axi_bridge_prod_width_cacheline_write_shape_formal_top
      .cache_req_valid = false;
  axi_llc_axi_bridge_prod_width_cacheline_write_shape_formal_top
      .cache_req_addr = 0u;
}

static void check_aw_snapshot(bool awvalid, uint32_t awaddr, uint8_t awlen,
                              uint8_t awsize, uint32_t addr)
{
  if(awvalid)
  {
    assert(awaddr == addr);
    assert(awlen == 1u);
    assert(awsize == 5u);
  }
}

static void check_w_snapshot(bool wvalid, uint64_t data_0, uint64_t data_1,
                             uint64_t data_2, uint64_t data_3,
                             uint32_t wstrb, bool wlast,
                             bool prior_w_seen)
{
  if(wvalid)
  {
    assert(wstrb == 0xffffffffu);
    if(!prior_w_seen)
    {
      assert(!wlast);
      assert(data_0 == 0xa5a55a5adeadbeefull);
      assert(data_1 == 0x1122334455667788ull);
      assert(data_2 == 0x8877665544332211ull);
      assert(data_3 == 0x0f1e2d3c4b5a6978ull);
    }
    else
    {
      assert(wlast);
      assert(data_0 == 0x89abcdef01234567ull);
      assert(data_1 == 0x0123456789abcdefull);
      assert(data_2 == 0xffeeddccbbaa9988ull);
      assert(data_3 == 0x7766554433221100ull);
    }
  }
}

int main(void)
{
  const uint32_t addr = 0x40000000u + (nondet_uint32_t() & 0x0000ffc0u);
  bool prior_w_seen = false;
  unsigned w_count = 0u;
  bool seen_aw = false;

  axi_llc_axi_bridge_prod_width_cacheline_write_shape_formal_top.rst_n =
      false;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_prod_width_cacheline_write_shape_formal_top.rst_n = true;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_prod_width_cacheline_write_shape_formal_top
      .cache_req_valid = true;
  axi_llc_axi_bridge_prod_width_cacheline_write_shape_formal_top
      .cache_req_addr = addr;
  set_inputs();

  assert(axi_llc_axi_bridge_prod_width_cacheline_write_shape_formal_top
             .cache_req_ready);

  for(unsigned step = 0u; step < 6u; step++)
  {
    next_timeframe();
    drive_idle();
    set_inputs();

    const bool awvalid =
        axi_llc_axi_bridge_prod_width_cacheline_write_shape_formal_top
            .axi_awvalid;
    const bool wvalid =
        axi_llc_axi_bridge_prod_width_cacheline_write_shape_formal_top
            .axi_wvalid;

    check_aw_snapshot(
        awvalid,
        axi_llc_axi_bridge_prod_width_cacheline_write_shape_formal_top
            .axi_awaddr,
        axi_llc_axi_bridge_prod_width_cacheline_write_shape_formal_top
            .axi_awlen,
        axi_llc_axi_bridge_prod_width_cacheline_write_shape_formal_top
            .axi_awsize,
        addr);

    check_w_snapshot(
        wvalid,
        axi_llc_axi_bridge_prod_width_cacheline_write_shape_formal_top
            .axi_wdata_0,
        axi_llc_axi_bridge_prod_width_cacheline_write_shape_formal_top
            .axi_wdata_1,
        axi_llc_axi_bridge_prod_width_cacheline_write_shape_formal_top
            .axi_wdata_2,
        axi_llc_axi_bridge_prod_width_cacheline_write_shape_formal_top
            .axi_wdata_3,
        axi_llc_axi_bridge_prod_width_cacheline_write_shape_formal_top
            .axi_wstrb,
        axi_llc_axi_bridge_prod_width_cacheline_write_shape_formal_top
            .axi_wlast,
        prior_w_seen);

    seen_aw = seen_aw || awvalid;
    if(wvalid)
    {
      prior_w_seen = true;
      w_count++;
    }
  }

  assert(seen_aw);
  assert(w_count == 2u);
}
