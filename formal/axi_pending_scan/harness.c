#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void set_inputs(void);

uint8_t nondet_uint8_t(void);

struct module_axi_pending_scan_formal_top
{
  uint8_t entry_valid;
  uint8_t entry_complete;
  uint8_t entry_axi_id;
  uint8_t match_axi_id;
  bool free_found;
  uint8_t free_slot;
  bool axi_id_found;
  uint8_t axi_id;
  bool match_found;
  uint8_t match_slot;
  bool complete_found;
  uint8_t complete_slot;
};

extern struct module_axi_pending_scan_formal_top axi_pending_scan_formal_top;

int main(void)
{
  const uint8_t entry_valid = nondet_uint8_t() & 0xFu;
  const uint8_t entry_complete = nondet_uint8_t() & 0xFu;
  const uint8_t entry_axi_id = nondet_uint8_t();
  const uint8_t match_axi_id = nondet_uint8_t() & 3u;

  axi_pending_scan_formal_top.entry_valid = entry_valid;
  axi_pending_scan_formal_top.entry_complete = entry_complete;
  axi_pending_scan_formal_top.entry_axi_id = entry_axi_id;
  axi_pending_scan_formal_top.match_axi_id = match_axi_id;
  set_inputs();

  const AxiBridgePendingScanResult ref = axi_bridge_pending_scan_control(
      4u, 2u, entry_valid, entry_complete, entry_axi_id, match_axi_id);

  assert(axi_pending_scan_formal_top.free_found == ref.free_found);
  assert(axi_pending_scan_formal_top.free_slot == ref.free_slot);
  assert(axi_pending_scan_formal_top.axi_id_found == ref.axi_id_found);
  assert(axi_pending_scan_formal_top.axi_id == ref.axi_id);
  assert(axi_pending_scan_formal_top.match_found == ref.match_found);
  assert(axi_pending_scan_formal_top.match_slot == ref.match_slot);
  assert(axi_pending_scan_formal_top.complete_found == ref.complete_found);
  assert(axi_pending_scan_formal_top.complete_slot == ref.complete_slot);

  if (entry_valid != 0xFu) {
    assert(axi_pending_scan_formal_top.free_found);
    assert(((entry_valid >> axi_pending_scan_formal_top.free_slot) & 1u) ==
           0u);
  }
  if (axi_pending_scan_formal_top.match_found) {
    assert(((entry_valid >> axi_pending_scan_formal_top.match_slot) & 1u) ==
           1u);
    assert(axi_bridge_scan_packed_id(entry_axi_id,
                                     axi_pending_scan_formal_top.match_slot,
                                     2u) == match_axi_id);
  }
  if (axi_pending_scan_formal_top.complete_found) {
    assert(((entry_valid >> axi_pending_scan_formal_top.complete_slot) & 1u) ==
           1u);
    assert(((entry_complete >> axi_pending_scan_formal_top.complete_slot) &
            1u) == 1u);
  }
}
