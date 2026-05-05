#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

struct module_axi_dual_port_hazard_scoreboard_formal_top
{
  bool clk;
  bool rst_n;
  uint8_t ddr_ar_line;
  uint8_t mmio_ar_line;
  uint8_t ddr_aw_line;
  uint8_t mmio_aw_line;
  uint8_t ddr_arid;
  uint8_t mmio_arid;
  uint8_t ddr_awid;
  uint8_t mmio_awid;
  uint8_t ddr_rid;
  uint8_t mmio_rid;
  uint8_t ddr_bid;
  uint8_t mmio_bid;
  bool ddr_ar_fire;
  bool mmio_ar_fire;
  bool ddr_aw_fire;
  bool mmio_aw_fire;
  bool ddr_r_fire;
  bool mmio_r_fire;
  bool ddr_b_fire;
  bool mmio_b_fire;
  bool ddr_ar_slot_hazard;
  bool mmio_ar_slot_hazard;
  bool ddr_aw_slot_hazard;
  bool mmio_aw_slot_hazard;
  bool ddr_aw_pending_read_hazard;
  bool mmio_aw_pending_read_hazard;
  bool ddr_ar_pending_write_hazard;
  bool mmio_ar_pending_write_hazard;
};

extern struct module_axi_dual_port_hazard_scoreboard_formal_top
  axi_dual_port_hazard_scoreboard_formal_top;

static void idle_inputs(void)
{
  axi_dual_port_hazard_scoreboard_formal_top.ddr_ar_line = 0u;
  axi_dual_port_hazard_scoreboard_formal_top.mmio_ar_line = 0u;
  axi_dual_port_hazard_scoreboard_formal_top.ddr_aw_line = 0u;
  axi_dual_port_hazard_scoreboard_formal_top.mmio_aw_line = 0u;
  axi_dual_port_hazard_scoreboard_formal_top.ddr_arid = 0u;
  axi_dual_port_hazard_scoreboard_formal_top.mmio_arid = 0u;
  axi_dual_port_hazard_scoreboard_formal_top.ddr_awid = 0u;
  axi_dual_port_hazard_scoreboard_formal_top.mmio_awid = 0u;
  axi_dual_port_hazard_scoreboard_formal_top.ddr_rid = 0u;
  axi_dual_port_hazard_scoreboard_formal_top.mmio_rid = 0u;
  axi_dual_port_hazard_scoreboard_formal_top.ddr_bid = 0u;
  axi_dual_port_hazard_scoreboard_formal_top.mmio_bid = 0u;
  axi_dual_port_hazard_scoreboard_formal_top.ddr_ar_fire = false;
  axi_dual_port_hazard_scoreboard_formal_top.mmio_ar_fire = false;
  axi_dual_port_hazard_scoreboard_formal_top.ddr_aw_fire = false;
  axi_dual_port_hazard_scoreboard_formal_top.mmio_aw_fire = false;
  axi_dual_port_hazard_scoreboard_formal_top.ddr_r_fire = false;
  axi_dual_port_hazard_scoreboard_formal_top.mmio_r_fire = false;
  axi_dual_port_hazard_scoreboard_formal_top.ddr_b_fire = false;
  axi_dual_port_hazard_scoreboard_formal_top.mmio_b_fire = false;
}

static void reset_scoreboard(void)
{
  idle_inputs();
  axi_dual_port_hazard_scoreboard_formal_top.rst_n = false;
  set_inputs();
  next_timeframe();
  axi_dual_port_hazard_scoreboard_formal_top.rst_n = true;
  idle_inputs();
  set_inputs();
}

int main(void)
{
  reset_scoreboard();
  assert(!axi_dual_port_hazard_scoreboard_formal_top.ddr_ar_slot_hazard);
  assert(!axi_dual_port_hazard_scoreboard_formal_top.mmio_ar_slot_hazard);
  assert(!axi_dual_port_hazard_scoreboard_formal_top.ddr_aw_slot_hazard);
  assert(!axi_dual_port_hazard_scoreboard_formal_top.mmio_aw_slot_hazard);

  axi_dual_port_hazard_scoreboard_formal_top.ddr_ar_line = 1u;
  axi_dual_port_hazard_scoreboard_formal_top.ddr_arid = 2u;
  axi_dual_port_hazard_scoreboard_formal_top.ddr_ar_fire = true;
  set_inputs();
  next_timeframe();

  idle_inputs();
  axi_dual_port_hazard_scoreboard_formal_top.rst_n = true;
  axi_dual_port_hazard_scoreboard_formal_top.ddr_aw_line = 1u;
  set_inputs();
  assert(axi_dual_port_hazard_scoreboard_formal_top.ddr_aw_pending_read_hazard);
  assert(!axi_dual_port_hazard_scoreboard_formal_top.mmio_aw_pending_read_hazard);

  axi_dual_port_hazard_scoreboard_formal_top.ddr_rid = 2u;
  axi_dual_port_hazard_scoreboard_formal_top.ddr_r_fire = true;
  set_inputs();
  next_timeframe();

  idle_inputs();
  axi_dual_port_hazard_scoreboard_formal_top.rst_n = true;
  axi_dual_port_hazard_scoreboard_formal_top.ddr_aw_line = 1u;
  set_inputs();
  assert(!axi_dual_port_hazard_scoreboard_formal_top.ddr_aw_pending_read_hazard);

  axi_dual_port_hazard_scoreboard_formal_top.ddr_aw_line = 3u;
  axi_dual_port_hazard_scoreboard_formal_top.ddr_awid = 1u;
  axi_dual_port_hazard_scoreboard_formal_top.ddr_aw_fire = true;
  set_inputs();
  next_timeframe();

  idle_inputs();
  axi_dual_port_hazard_scoreboard_formal_top.rst_n = true;
  axi_dual_port_hazard_scoreboard_formal_top.ddr_ar_line = 3u;
  set_inputs();
  assert(axi_dual_port_hazard_scoreboard_formal_top.ddr_ar_pending_write_hazard);
  assert(!axi_dual_port_hazard_scoreboard_formal_top.mmio_ar_pending_write_hazard);

  axi_dual_port_hazard_scoreboard_formal_top.ddr_bid = 1u;
  axi_dual_port_hazard_scoreboard_formal_top.ddr_b_fire = true;
  set_inputs();
  next_timeframe();

  idle_inputs();
  axi_dual_port_hazard_scoreboard_formal_top.rst_n = true;
  axi_dual_port_hazard_scoreboard_formal_top.ddr_ar_line = 3u;
  set_inputs();
  assert(!axi_dual_port_hazard_scoreboard_formal_top.ddr_ar_pending_write_hazard);

  reset_scoreboard();
  axi_dual_port_hazard_scoreboard_formal_top.ddr_ar_line = 0u;
  axi_dual_port_hazard_scoreboard_formal_top.ddr_arid = 0u;
  axi_dual_port_hazard_scoreboard_formal_top.ddr_ar_fire = true;
  axi_dual_port_hazard_scoreboard_formal_top.mmio_ar_line = 2u;
  axi_dual_port_hazard_scoreboard_formal_top.mmio_arid = 3u;
  axi_dual_port_hazard_scoreboard_formal_top.mmio_ar_fire = true;
  set_inputs();
  next_timeframe();

  idle_inputs();
  axi_dual_port_hazard_scoreboard_formal_top.rst_n = true;
  axi_dual_port_hazard_scoreboard_formal_top.ddr_aw_line = 0u;
  axi_dual_port_hazard_scoreboard_formal_top.mmio_aw_line = 2u;
  set_inputs();
  assert(axi_dual_port_hazard_scoreboard_formal_top.ddr_aw_pending_read_hazard);
  assert(axi_dual_port_hazard_scoreboard_formal_top.mmio_aw_pending_read_hazard);
  assert(axi_dual_port_hazard_scoreboard_formal_top.ddr_ar_slot_hazard);
  assert(axi_dual_port_hazard_scoreboard_formal_top.mmio_ar_slot_hazard);
}
