#include <assert.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void set_inputs(void);

uint8_t nondet_uint8_t(void);

struct module_axi_beat_shape_formal_top
{
  uint8_t total_size;
  uint8_t total_beats_32b;
  uint8_t axi_len_32b;
  uint8_t axi_size_32b;
  uint8_t total_beats_4b;
  uint8_t axi_len_4b;
  uint8_t axi_size_4b;
};

extern struct module_axi_beat_shape_formal_top axi_beat_shape_formal_top;

int main(void)
{
  const uint8_t total_size = nondet_uint8_t();
  const AxiDualPortAxiBeatShape ref_32b =
      axi_dual_port_axi_beat_shape(total_size, AXI_DUAL_PORT_DDR_BEAT_BYTES);
  const AxiDualPortAxiBeatShape ref_4b =
      axi_dual_port_axi_beat_shape(total_size, 4u);

  axi_beat_shape_formal_top.total_size = total_size;
  set_inputs();

  assert(axi_beat_shape_formal_top.total_beats_32b == ref_32b.total_beats);
  assert(axi_beat_shape_formal_top.axi_len_32b == ref_32b.axi_len);
  assert(axi_beat_shape_formal_top.axi_size_32b == ref_32b.axi_size);
  assert(axi_beat_shape_formal_top.total_beats_4b == ref_4b.total_beats);
  assert(axi_beat_shape_formal_top.axi_len_4b == ref_4b.axi_len);
  assert(axi_beat_shape_formal_top.axi_size_4b == ref_4b.axi_size);
}
