#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void set_inputs(void);

bool nondet_bool(void);
uint8_t nondet_uint8_t(void);

struct module_axi_dual_port_issue_gate_formal_top
{
  bool bridge_arvalid;
  bool axi_arready;
  uint8_t ar_line;
  bool ar_slot_hazard;
  bool ar_pending_write_hazard;
  bool bridge_awvalid;
  bool axi_awready;
  uint8_t aw_line;
  bool aw_slot_hazard;
  bool aw_pending_read_hazard;
  bool bridge_arready;
  bool axi_arvalid;
  bool bridge_awready;
  bool axi_awvalid;
  bool ar_hazard;
  bool ar_would_issue;
  bool aw_same_cycle_read_hazard;
  bool aw_hazard;
  bool ar_fire;
  bool aw_fire;
};

extern struct module_axi_dual_port_issue_gate_formal_top
  axi_dual_port_issue_gate_formal_top;

int main(void)
{
  const bool bridge_arvalid = nondet_bool();
  const bool axi_arready = nondet_bool();
  const uint8_t ar_line = nondet_uint8_t() & 3u;
  const bool ar_slot_hazard = nondet_bool();
  const bool ar_pending_write_hazard = nondet_bool();
  const bool bridge_awvalid = nondet_bool();
  const bool axi_awready = nondet_bool();
  const uint8_t aw_line = nondet_uint8_t() & 3u;
  const bool aw_slot_hazard = nondet_bool();
  const bool aw_pending_read_hazard = nondet_bool();

  axi_dual_port_issue_gate_formal_top.bridge_arvalid = bridge_arvalid;
  axi_dual_port_issue_gate_formal_top.axi_arready = axi_arready;
  axi_dual_port_issue_gate_formal_top.ar_line = ar_line;
  axi_dual_port_issue_gate_formal_top.ar_slot_hazard = ar_slot_hazard;
  axi_dual_port_issue_gate_formal_top.ar_pending_write_hazard =
      ar_pending_write_hazard;
  axi_dual_port_issue_gate_formal_top.bridge_awvalid = bridge_awvalid;
  axi_dual_port_issue_gate_formal_top.axi_awready = axi_awready;
  axi_dual_port_issue_gate_formal_top.aw_line = aw_line;
  axi_dual_port_issue_gate_formal_top.aw_slot_hazard = aw_slot_hazard;
  axi_dual_port_issue_gate_formal_top.aw_pending_read_hazard =
      aw_pending_read_hazard;
  set_inputs();

  const AxiDualPortIssueGateResult ref = axi_dual_port_issue_gate(
      bridge_arvalid, axi_arready, ar_line, ar_slot_hazard,
      ar_pending_write_hazard, bridge_awvalid, axi_awready, aw_line,
      aw_slot_hazard, aw_pending_read_hazard);

  assert(axi_dual_port_issue_gate_formal_top.ar_hazard == ref.ar_hazard);
  assert(axi_dual_port_issue_gate_formal_top.ar_would_issue ==
         ref.ar_would_issue);
  assert(axi_dual_port_issue_gate_formal_top.aw_same_cycle_read_hazard ==
         ref.aw_same_cycle_read_hazard);
  assert(axi_dual_port_issue_gate_formal_top.aw_hazard == ref.aw_hazard);
  assert(axi_dual_port_issue_gate_formal_top.axi_arvalid ==
         ref.axi_arvalid);
  assert(axi_dual_port_issue_gate_formal_top.bridge_arready ==
         ref.bridge_arready);
  assert(axi_dual_port_issue_gate_formal_top.axi_awvalid ==
         ref.axi_awvalid);
  assert(axi_dual_port_issue_gate_formal_top.bridge_awready ==
         ref.bridge_awready);
  assert(axi_dual_port_issue_gate_formal_top.ar_fire == ref.ar_fire);
  assert(axi_dual_port_issue_gate_formal_top.aw_fire == ref.aw_fire);

  const bool same_line = ar_line == aw_line;
  if (bridge_arvalid && bridge_awvalid && axi_arready && axi_awready &&
      same_line && !ref.ar_hazard && !aw_slot_hazard &&
      !aw_pending_read_hazard) {
    assert(axi_dual_port_issue_gate_formal_top.axi_arvalid);
    assert(!axi_dual_port_issue_gate_formal_top.axi_awvalid);
  }
}
