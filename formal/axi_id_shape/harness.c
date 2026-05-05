#include <assert.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void set_inputs(void);

uint8_t nondet_uint8_t(void);

struct module_axi_id_shape_formal_top
{
  uint8_t id_in;
  uint8_t id_6_to_8;
  uint8_t id_3_to_8;
  uint8_t id_8_to_6;
  uint8_t id_6_to_6;
};

extern struct module_axi_id_shape_formal_top axi_id_shape_formal_top;

int main(void)
{
  const uint8_t id = nondet_uint8_t();

  axi_id_shape_formal_top.id_in = id;
  set_inputs();

  assert(axi_id_shape_formal_top.id_6_to_8 ==
         axi_dual_port_resize_axi_id(id, 6u, 8u));
  assert(axi_id_shape_formal_top.id_3_to_8 ==
         axi_dual_port_resize_axi_id(id, 3u, 8u));
  assert(axi_id_shape_formal_top.id_8_to_6 ==
         axi_dual_port_resize_axi_id(id, 8u, 6u));
  assert(axi_id_shape_formal_top.id_6_to_6 ==
         axi_dual_port_resize_axi_id(id, 6u, 6u));
}
