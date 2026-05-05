#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void set_inputs(void);

uint32_t nondet_uint32_t(void);
uint8_t nondet_uint8_t(void);

struct module_axi_dual_port_route_shape_formal_top
{
  uint32_t addr;
  uint8_t total_size;
  bool ddr_port;
  bool mmio_port;
  bool supported;
  uint8_t axi_len;
  uint8_t axi_size;
};

extern struct module_axi_dual_port_route_shape_formal_top
  axi_dual_port_route_shape_formal_top;

int main(void)
{
  const uint32_t addr = nondet_uint32_t();
  const uint8_t total_size = nondet_uint8_t();

  axi_dual_port_route_shape_formal_top.addr = addr;
  axi_dual_port_route_shape_formal_top.total_size = total_size;
  set_inputs();

  const AxiDualPortRouteShape ref =
      axi_dual_port_route_shape(addr, total_size, 0x40000000u);

  assert(axi_dual_port_route_shape_formal_top.ddr_port == ref.ddr_port);
  assert(axi_dual_port_route_shape_formal_top.mmio_port == ref.mmio_port);
  assert(axi_dual_port_route_shape_formal_top.supported == ref.supported);
  assert(axi_dual_port_route_shape_formal_top.axi_len == ref.axi_len);
  assert(axi_dual_port_route_shape_formal_top.axi_size == ref.axi_size);
}
