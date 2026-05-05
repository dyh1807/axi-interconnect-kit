#include <assert.h>
#include <stdbool.h>

#include "../../include/axi_dual_port_route_shape.h"

void set_inputs(void);

bool nondet_bool(void);

struct module_axi_dual_port_slot_hazard_formal_top
{
  bool first_free_found;
  bool second_free_found;
  bool primary_fire;
  bool primary_slot_hazard;
  bool secondary_slot_hazard;
};

extern struct module_axi_dual_port_slot_hazard_formal_top
  axi_dual_port_slot_hazard_formal_top;

int main(void)
{
  const bool first_free_found = nondet_bool();
  const bool second_free_found = nondet_bool();
  const bool primary_fire = nondet_bool();

  axi_dual_port_slot_hazard_formal_top.first_free_found = first_free_found;
  axi_dual_port_slot_hazard_formal_top.second_free_found = second_free_found;
  axi_dual_port_slot_hazard_formal_top.primary_fire = primary_fire;
  set_inputs();

  const AxiDualPortSlotHazardResult ref =
      axi_dual_port_slot_hazard(first_free_found, second_free_found,
                                primary_fire);

  assert(axi_dual_port_slot_hazard_formal_top.primary_slot_hazard ==
         ref.primary_slot_hazard);
  assert(axi_dual_port_slot_hazard_formal_top.secondary_slot_hazard ==
         ref.secondary_slot_hazard);

  if (first_free_found && !primary_fire) {
    assert(!axi_dual_port_slot_hazard_formal_top.secondary_slot_hazard);
  }
  if (first_free_found && primary_fire && !second_free_found) {
    assert(axi_dual_port_slot_hazard_formal_top.secondary_slot_hazard);
  }
}
