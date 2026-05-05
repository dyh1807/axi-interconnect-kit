#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void set_inputs(void);

bool nondet_bool(void);
uint8_t nondet_uint8_t(void);
uint32_t nondet_uint32_t(void);

struct module_axi_issue_select_formal_top
{
  bool queue_has_entry;
  bool slot_valid;
  bool slot_from_cache;
  bool slot_mode2_ddr_aligned;
  bool ready_to_issue;
  bool issue_done;
  uint32_t slot_addr;
  uint8_t slot_size;
  uint8_t slot_axi_id;
  uint8_t slot_beat_idx;
  uint8_t slot_total_beats;
  bool issue_valid;
  bool issue_mode2_ddr_aligned;
  uint32_t issue_addr;
  uint8_t issue_size;
  uint8_t issue_axi_id;
  uint8_t issue_beat_idx;
  uint8_t issue_total_beats;
};

extern struct module_axi_issue_select_formal_top axi_issue_select_formal_top;

int main(void)
{
  const bool queue_has_entry = nondet_bool();
  const bool slot_valid = nondet_bool();
  const bool slot_from_cache = nondet_bool();
  const bool slot_mode2_ddr_aligned = nondet_bool();
  const bool ready_to_issue = nondet_bool();
  const bool issue_done = nondet_bool();
  const uint32_t slot_addr = nondet_uint32_t();
  const uint8_t slot_size = nondet_uint8_t();
  const uint8_t slot_axi_id = nondet_uint8_t() & 7u;
  const uint8_t slot_beat_idx = nondet_uint8_t();
  const uint8_t slot_total_beats = nondet_uint8_t();

  axi_issue_select_formal_top.queue_has_entry = queue_has_entry;
  axi_issue_select_formal_top.slot_valid = slot_valid;
  axi_issue_select_formal_top.slot_from_cache = slot_from_cache;
  axi_issue_select_formal_top.slot_mode2_ddr_aligned =
      slot_mode2_ddr_aligned;
  axi_issue_select_formal_top.ready_to_issue = ready_to_issue;
  axi_issue_select_formal_top.issue_done = issue_done;
  axi_issue_select_formal_top.slot_addr = slot_addr;
  axi_issue_select_formal_top.slot_size = slot_size;
  axi_issue_select_formal_top.slot_axi_id = slot_axi_id;
  axi_issue_select_formal_top.slot_beat_idx = slot_beat_idx;
  axi_issue_select_formal_top.slot_total_beats = slot_total_beats;
  set_inputs();

  const AxiBridgeIssueSelectControl ref = axi_bridge_issue_select_control(
      queue_has_entry, slot_valid, slot_from_cache, slot_mode2_ddr_aligned,
      ready_to_issue, issue_done, slot_addr, slot_size, slot_axi_id,
      slot_beat_idx, slot_total_beats, 64u, 32u);

  assert(axi_issue_select_formal_top.issue_valid == ref.issue_valid);
  assert(axi_issue_select_formal_top.issue_mode2_ddr_aligned ==
         ref.issue_mode2_ddr_aligned);
  assert(axi_issue_select_formal_top.issue_addr == ref.issue_addr);
  assert(axi_issue_select_formal_top.issue_size == ref.issue_size);
  assert(axi_issue_select_formal_top.issue_axi_id == ref.issue_axi_id);
  assert(axi_issue_select_formal_top.issue_beat_idx == ref.issue_beat_idx);
  assert(axi_issue_select_formal_top.issue_total_beats ==
         ref.issue_total_beats);

  if (axi_issue_select_formal_top.issue_valid) {
    assert(queue_has_entry && slot_valid && ready_to_issue && !issue_done);
  }
  if (slot_from_cache) {
    assert(!axi_issue_select_formal_top.issue_mode2_ddr_aligned);
  }
  if (!axi_issue_select_formal_top.issue_mode2_ddr_aligned) {
    assert(axi_issue_select_formal_top.issue_addr == slot_addr);
    assert(axi_issue_select_formal_top.issue_size == slot_size);
  }
}
