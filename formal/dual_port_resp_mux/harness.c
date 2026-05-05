#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void set_inputs(void);

bool nondet_bool(void);
uint8_t nondet_uint8_t(void);

struct module_axi_dual_port_resp_mux_formal_top
{
  bool ddr_resp_valid;
  uint8_t ddr_resp_rdata;
  uint8_t ddr_resp_id;
  uint8_t ddr_resp_code;
  bool mmio_resp_valid;
  uint8_t mmio_resp_rdata;
  uint8_t mmio_resp_id;
  uint8_t mmio_resp_code;
  bool resp_ready;
  bool ddr_resp_ready;
  bool mmio_resp_ready;
  bool resp_valid;
  uint8_t resp_rdata;
  uint8_t resp_id;
  uint8_t resp_code;
  bool select_mmio;
};

extern struct module_axi_dual_port_resp_mux_formal_top
  axi_dual_port_resp_mux_formal_top;

int main(void)
{
  const bool ddr_resp_valid = nondet_bool();
  const uint8_t ddr_resp_rdata = nondet_uint8_t();
  const uint8_t ddr_resp_id = nondet_uint8_t() & 3u;
  const uint8_t ddr_resp_code = nondet_uint8_t() & 3u;
  const bool mmio_resp_valid = nondet_bool();
  const uint8_t mmio_resp_rdata = nondet_uint8_t();
  const uint8_t mmio_resp_id = nondet_uint8_t() & 3u;
  const uint8_t mmio_resp_code = nondet_uint8_t() & 3u;
  const bool resp_ready = nondet_bool();

  axi_dual_port_resp_mux_formal_top.ddr_resp_valid = ddr_resp_valid;
  axi_dual_port_resp_mux_formal_top.ddr_resp_rdata = ddr_resp_rdata;
  axi_dual_port_resp_mux_formal_top.ddr_resp_id = ddr_resp_id;
  axi_dual_port_resp_mux_formal_top.ddr_resp_code = ddr_resp_code;
  axi_dual_port_resp_mux_formal_top.mmio_resp_valid = mmio_resp_valid;
  axi_dual_port_resp_mux_formal_top.mmio_resp_rdata = mmio_resp_rdata;
  axi_dual_port_resp_mux_formal_top.mmio_resp_id = mmio_resp_id;
  axi_dual_port_resp_mux_formal_top.mmio_resp_code = mmio_resp_code;
  axi_dual_port_resp_mux_formal_top.resp_ready = resp_ready;
  set_inputs();

  const AxiDualPortRespMuxControl ref =
      axi_dual_port_resp_mux_control(ddr_resp_valid, mmio_resp_valid,
                                     resp_ready);

  assert(axi_dual_port_resp_mux_formal_top.select_mmio == ref.select_mmio);
  assert(axi_dual_port_resp_mux_formal_top.resp_valid ==
         ref.resp_valid);
  assert(axi_dual_port_resp_mux_formal_top.resp_rdata ==
         (ref.select_mmio ? mmio_resp_rdata : ddr_resp_rdata));
  assert(axi_dual_port_resp_mux_formal_top.resp_id ==
         (ref.select_mmio ? mmio_resp_id : ddr_resp_id));
  assert(axi_dual_port_resp_mux_formal_top.resp_code ==
         (ref.select_mmio ? mmio_resp_code : ddr_resp_code));
  assert(axi_dual_port_resp_mux_formal_top.mmio_resp_ready ==
         ref.mmio_resp_ready);
  assert(axi_dual_port_resp_mux_formal_top.ddr_resp_ready ==
         ref.ddr_resp_ready);
}
