#include <assert.h>
#include <stdbool.h>

#include "../../include/axi_dual_port_route_shape.h"

void set_inputs(void);

bool nondet_bool(void);

struct module_axi_dual_port_req_steer_formal_top
{
  bool req_valid;
  bool req_to_ddr;
  bool req_supported;
  bool ddr_req_ready;
  bool mmio_req_ready;
  bool ddr_req_valid;
  bool mmio_req_valid;
  bool req_ready;
};

extern struct module_axi_dual_port_req_steer_formal_top
  axi_dual_port_req_steer_formal_top;

int main(void)
{
  const bool req_valid = nondet_bool();
  const bool req_to_ddr = nondet_bool();
  const bool req_supported = nondet_bool();
  const bool ddr_req_ready = nondet_bool();
  const bool mmio_req_ready = nondet_bool();

  axi_dual_port_req_steer_formal_top.req_valid = req_valid;
  axi_dual_port_req_steer_formal_top.req_to_ddr = req_to_ddr;
  axi_dual_port_req_steer_formal_top.req_supported = req_supported;
  axi_dual_port_req_steer_formal_top.ddr_req_ready = ddr_req_ready;
  axi_dual_port_req_steer_formal_top.mmio_req_ready = mmio_req_ready;
  set_inputs();

  const AxiDualPortReqSteerResult ref = axi_dual_port_req_steer(
      req_valid, req_to_ddr, req_supported, ddr_req_ready, mmio_req_ready);

  assert(axi_dual_port_req_steer_formal_top.ddr_req_valid ==
         ref.ddr_req_valid);
  assert(axi_dual_port_req_steer_formal_top.mmio_req_valid ==
         ref.mmio_req_valid);
  assert(axi_dual_port_req_steer_formal_top.req_ready == ref.req_ready);
  assert(!(axi_dual_port_req_steer_formal_top.ddr_req_valid &&
           axi_dual_port_req_steer_formal_top.mmio_req_valid));
}
