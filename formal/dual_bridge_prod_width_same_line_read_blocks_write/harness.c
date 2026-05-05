#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

struct module_axi_llc_axi_bridge_dual_prod_width_same_line_read_blocks_write_formal_top
{
  bool clk;
  bool rst_n;
  bool cache_req_valid;
  bool cache_req_write;
  bool cache_req_ready;
  bool ddr_axi_arvalid;
  bool ddr_axi_arid;
  uint32_t ddr_axi_araddr;
  uint8_t ddr_axi_arlen;
  uint8_t ddr_axi_arsize;
  bool ddr_axi_awvalid;
  uint32_t ddr_axi_awaddr;
  uint8_t ddr_axi_awlen;
  uint8_t ddr_axi_awsize;
  bool ddr_axi_wvalid;
  bool ddr_axi_wlast;
  bool mmio_axi_arvalid;
  bool mmio_axi_awvalid;
  bool mmio_axi_wvalid;
};

extern struct
    module_axi_llc_axi_bridge_dual_prod_width_same_line_read_blocks_write_formal_top
        axi_llc_axi_bridge_dual_prod_width_same_line_read_blocks_write_formal_top;

static void drive_idle(void)
{
  axi_llc_axi_bridge_dual_prod_width_same_line_read_blocks_write_formal_top
      .cache_req_valid = false;
  axi_llc_axi_bridge_dual_prod_width_same_line_read_blocks_write_formal_top
      .cache_req_write = false;
}

static void check_no_write_issue(void)
{
  assert(!axi_llc_axi_bridge_dual_prod_width_same_line_read_blocks_write_formal_top
              .ddr_axi_awvalid);
  assert(!axi_llc_axi_bridge_dual_prod_width_same_line_read_blocks_write_formal_top
              .ddr_axi_wvalid);
  assert(!axi_llc_axi_bridge_dual_prod_width_same_line_read_blocks_write_formal_top
              .mmio_axi_awvalid);
  assert(!axi_llc_axi_bridge_dual_prod_width_same_line_read_blocks_write_formal_top
              .mmio_axi_wvalid);
}

static void check_ar_shape(bool arvalid, uint32_t expected_addr)
{
  assert(!axi_llc_axi_bridge_dual_prod_width_same_line_read_blocks_write_formal_top
              .mmio_axi_arvalid);
  if(arvalid)
  {
    assert(axi_llc_axi_bridge_dual_prod_width_same_line_read_blocks_write_formal_top
               .ddr_axi_araddr == expected_addr);
    assert(axi_llc_axi_bridge_dual_prod_width_same_line_read_blocks_write_formal_top
               .ddr_axi_arlen == 1u);
    assert(axi_llc_axi_bridge_dual_prod_width_same_line_read_blocks_write_formal_top
               .ddr_axi_arsize == 5u);
  }
}

int main(void)
{
  const uint32_t addr = 0x40000300u;

  axi_llc_axi_bridge_dual_prod_width_same_line_read_blocks_write_formal_top
      .rst_n = false;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_prod_width_same_line_read_blocks_write_formal_top
      .rst_n = true;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_dual_prod_width_same_line_read_blocks_write_formal_top
      .cache_req_valid = true;
  axi_llc_axi_bridge_dual_prod_width_same_line_read_blocks_write_formal_top
      .cache_req_write = false;
  set_inputs();
  assert(axi_llc_axi_bridge_dual_prod_width_same_line_read_blocks_write_formal_top
             .cache_req_ready);

  next_timeframe();
  drive_idle();
  set_inputs();
  assert(axi_llc_axi_bridge_dual_prod_width_same_line_read_blocks_write_formal_top
             .ddr_axi_arvalid);
  check_ar_shape(true, addr);

  axi_llc_axi_bridge_dual_prod_width_same_line_read_blocks_write_formal_top
      .cache_req_valid = true;
  axi_llc_axi_bridge_dual_prod_width_same_line_read_blocks_write_formal_top
      .cache_req_write = true;
  set_inputs();
  assert(axi_llc_axi_bridge_dual_prod_width_same_line_read_blocks_write_formal_top
             .cache_req_ready);
  check_no_write_issue();

  next_timeframe();
  drive_idle();
  set_inputs();
  check_no_write_issue();
}
