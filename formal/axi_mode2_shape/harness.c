#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void set_inputs(void);

uint8_t nondet_uint8_t(void);

struct module_axi_mode2_shape_formal_top
{
  uint8_t addr;
  uint8_t total_size;
  bool single_axi_beat;
  uint8_t issue_addr;
  uint8_t issue_size;
};

extern struct module_axi_mode2_shape_formal_top axi_mode2_shape_formal_top;

int main(void)
{
  const uint8_t addr = nondet_uint8_t();
  const uint8_t total_size = nondet_uint8_t();

  axi_mode2_shape_formal_top.addr = addr;
  axi_mode2_shape_formal_top.total_size = total_size;
  set_inputs();

  const AxiBridgeMode2Shape ref =
      axi_bridge_mode2_shape(addr, total_size, 8u, 4u);

  assert(axi_mode2_shape_formal_top.single_axi_beat ==
         ref.single_axi_beat);
  assert(axi_mode2_shape_formal_top.issue_addr == (uint8_t)ref.issue_addr);
  assert(axi_mode2_shape_formal_top.issue_size == ref.issue_size);

  if (axi_mode2_shape_formal_top.single_axi_beat) {
    assert((axi_mode2_shape_formal_top.issue_addr & 3u) == 0u);
    assert(axi_mode2_shape_formal_top.issue_size == 3u);
  } else {
    assert((axi_mode2_shape_formal_top.issue_addr & 7u) == 0u);
    assert(axi_mode2_shape_formal_top.issue_size == 7u);
  }
}
