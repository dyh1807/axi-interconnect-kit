#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void set_inputs(void);

bool nondet_bool(void);
uint8_t nondet_uint8_t(void);

struct module_axi_dual_port_hazard_match_formal_top
{
  bool entry_valid;
  bool entry_port;
  uint8_t entry_line;
  uint8_t entry_id;
  uint8_t ddr_line;
  uint8_t mmio_line;
  uint8_t ddr_id;
  uint8_t mmio_id;
  bool ddr_line_match;
  bool mmio_line_match;
  bool ddr_id_match;
  bool mmio_id_match;
};

extern struct module_axi_dual_port_hazard_match_formal_top
  axi_dual_port_hazard_match_formal_top;

int main(void)
{
  const bool entry_valid = nondet_bool();
  const bool entry_port = nondet_bool();
  const uint8_t entry_line = nondet_uint8_t() & 3u;
  const uint8_t entry_id = nondet_uint8_t() & 3u;
  const uint8_t ddr_line = nondet_uint8_t() & 3u;
  const uint8_t mmio_line = nondet_uint8_t() & 3u;
  const uint8_t ddr_id = nondet_uint8_t() & 3u;
  const uint8_t mmio_id = nondet_uint8_t() & 3u;

  axi_dual_port_hazard_match_formal_top.entry_valid = entry_valid;
  axi_dual_port_hazard_match_formal_top.entry_port = entry_port;
  axi_dual_port_hazard_match_formal_top.entry_line = entry_line;
  axi_dual_port_hazard_match_formal_top.entry_id = entry_id;
  axi_dual_port_hazard_match_formal_top.ddr_line = ddr_line;
  axi_dual_port_hazard_match_formal_top.mmio_line = mmio_line;
  axi_dual_port_hazard_match_formal_top.ddr_id = ddr_id;
  axi_dual_port_hazard_match_formal_top.mmio_id = mmio_id;
  set_inputs();

  const AxiDualPortHazardMatchResult ref = axi_dual_port_hazard_match(
      entry_valid, entry_port, entry_line, entry_id, ddr_line, mmio_line,
      ddr_id, mmio_id);

  assert(axi_dual_port_hazard_match_formal_top.ddr_line_match ==
         ref.ddr_line_match);
  assert(axi_dual_port_hazard_match_formal_top.mmio_line_match ==
         ref.mmio_line_match);
  assert(axi_dual_port_hazard_match_formal_top.ddr_id_match ==
         ref.ddr_id_match);
  assert(axi_dual_port_hazard_match_formal_top.mmio_id_match ==
         ref.mmio_id_match);

  if (!entry_valid) {
    assert(!axi_dual_port_hazard_match_formal_top.ddr_line_match);
    assert(!axi_dual_port_hazard_match_formal_top.mmio_line_match);
    assert(!axi_dual_port_hazard_match_formal_top.ddr_id_match);
    assert(!axi_dual_port_hazard_match_formal_top.mmio_id_match);
  }
  if (!entry_port) {
    assert(!axi_dual_port_hazard_match_formal_top.mmio_line_match);
    assert(!axi_dual_port_hazard_match_formal_top.mmio_id_match);
  } else {
    assert(!axi_dual_port_hazard_match_formal_top.ddr_line_match);
    assert(!axi_dual_port_hazard_match_formal_top.ddr_id_match);
  }
}
