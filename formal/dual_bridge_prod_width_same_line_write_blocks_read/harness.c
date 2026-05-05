#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

struct module_axi_llc_axi_bridge_dual_prod_width_same_line_write_blocks_read_formal_top
{
  bool clk;
  bool rst_n;
  bool cache_req_valid;
  bool cache_req_write;
  bool cache_req_ready;
  bool ddr_axi_arvalid;
  uint32_t ddr_axi_araddr;
  uint8_t ddr_axi_arlen;
  uint8_t ddr_axi_arsize;
  bool ddr_axi_awvalid;
  bool ddr_axi_awid;
  uint32_t ddr_axi_awaddr;
  uint8_t ddr_axi_awlen;
  uint8_t ddr_axi_awsize;
  bool ddr_axi_wvalid;
  bool ddr_axi_wlast;
  bool ddr_axi_bready;
  bool mmio_axi_arvalid;
  bool mmio_axi_awvalid;
  bool mmio_axi_wvalid;
};

extern struct
    module_axi_llc_axi_bridge_dual_prod_width_same_line_write_blocks_read_formal_top
        axi_llc_axi_bridge_dual_prod_width_same_line_write_blocks_read_formal_top;

static void drive_idle(void)
{
  axi_llc_axi_bridge_dual_prod_width_same_line_write_blocks_read_formal_top
      .cache_req_valid = false;
  axi_llc_axi_bridge_dual_prod_width_same_line_write_blocks_read_formal_top
      .cache_req_write = false;
}

static void check_no_read_issue(void)
{
  assert(!axi_llc_axi_bridge_dual_prod_width_same_line_write_blocks_read_formal_top
              .ddr_axi_arvalid);
  assert(!axi_llc_axi_bridge_dual_prod_width_same_line_write_blocks_read_formal_top
              .mmio_axi_arvalid);
}

static void check_write_shape(bool awvalid, bool wvalid, uint32_t expected_addr)
{
  assert(!axi_llc_axi_bridge_dual_prod_width_same_line_write_blocks_read_formal_top
              .mmio_axi_awvalid);
  assert(!axi_llc_axi_bridge_dual_prod_width_same_line_write_blocks_read_formal_top
              .mmio_axi_wvalid);
  if(awvalid)
  {
    assert(axi_llc_axi_bridge_dual_prod_width_same_line_write_blocks_read_formal_top
               .ddr_axi_awaddr == expected_addr);
    assert(axi_llc_axi_bridge_dual_prod_width_same_line_write_blocks_read_formal_top
               .ddr_axi_awlen == 1u);
    assert(axi_llc_axi_bridge_dual_prod_width_same_line_write_blocks_read_formal_top
               .ddr_axi_awsize == 5u);
  }
  (void)wvalid;
}

int main(void)
{
  const uint32_t addr = 0x40000300u;
  bool seen_aw = false;
  bool seen_wlast = false;

  axi_llc_axi_bridge_dual_prod_width_same_line_write_blocks_read_formal_top
      .rst_n = false;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_prod_width_same_line_write_blocks_read_formal_top
      .rst_n = true;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_prod_width_same_line_write_blocks_read_formal_top
      .cache_req_valid = true;
  axi_llc_axi_bridge_dual_prod_width_same_line_write_blocks_read_formal_top
      .cache_req_write = true;
  set_inputs();
  assert(axi_llc_axi_bridge_dual_prod_width_same_line_write_blocks_read_formal_top
             .cache_req_ready);

  for(unsigned step = 0u; step < 4u; step++)
  {
    next_timeframe();
    drive_idle();
    set_inputs();
    const bool awvalid =
        axi_llc_axi_bridge_dual_prod_width_same_line_write_blocks_read_formal_top
            .ddr_axi_awvalid;
    const bool wvalid =
        axi_llc_axi_bridge_dual_prod_width_same_line_write_blocks_read_formal_top
            .ddr_axi_wvalid;
    check_write_shape(awvalid, wvalid, addr);
    if(awvalid)
    {
      seen_aw = true;
    }
    seen_wlast =
        seen_wlast ||
        (wvalid &&
         axi_llc_axi_bridge_dual_prod_width_same_line_write_blocks_read_formal_top
             .ddr_axi_wlast);
  }
  assert(seen_aw);
  assert(seen_wlast);

  axi_llc_axi_bridge_dual_prod_width_same_line_write_blocks_read_formal_top
      .cache_req_valid = true;
  axi_llc_axi_bridge_dual_prod_width_same_line_write_blocks_read_formal_top
      .cache_req_write = false;
  set_inputs();
  assert(axi_llc_axi_bridge_dual_prod_width_same_line_write_blocks_read_formal_top
             .cache_req_ready);
  check_no_read_issue();

  next_timeframe();
  drive_idle();
  set_inputs();
  check_no_read_issue();
}
