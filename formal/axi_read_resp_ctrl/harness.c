#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void set_inputs(void);

bool nondet_bool(void);
uint8_t nondet_uint8_t(void);

struct module_axi_read_resp_ctrl_formal_top
{
  bool rd_match_found;
  uint8_t rd_beats_done;
  uint8_t rd_total_beats;
  bool axi_rlast;
  uint8_t axi_rresp;
  uint8_t current_resp_code;
  bool rd_last_beat;
  uint8_t next_resp_code;
};

extern struct module_axi_read_resp_ctrl_formal_top
    axi_read_resp_ctrl_formal_top;

int main(void)
{
  const bool rd_match_found = nondet_bool();
  const uint8_t rd_beats_done = nondet_uint8_t();
  const uint8_t rd_total_beats = nondet_uint8_t();
  const bool axi_rlast = nondet_bool();
  const uint8_t axi_rresp = (uint8_t)(nondet_uint8_t() & 3u);
  const uint8_t current_resp_code = (uint8_t)(nondet_uint8_t() & 3u);

  axi_read_resp_ctrl_formal_top.rd_match_found = rd_match_found;
  axi_read_resp_ctrl_formal_top.rd_beats_done = rd_beats_done;
  axi_read_resp_ctrl_formal_top.rd_total_beats = rd_total_beats;
  axi_read_resp_ctrl_formal_top.axi_rlast = axi_rlast;
  axi_read_resp_ctrl_formal_top.axi_rresp = axi_rresp;
  axi_read_resp_ctrl_formal_top.current_resp_code = current_resp_code;
  set_inputs();

  const AxiBridgeReadRespControl ref = axi_bridge_read_resp_control(
      rd_match_found, rd_beats_done, rd_total_beats, axi_rlast, axi_rresp,
      current_resp_code);

  assert(axi_read_resp_ctrl_formal_top.rd_last_beat == ref.rd_last_beat);
  assert(axi_read_resp_ctrl_formal_top.next_resp_code == ref.next_resp_code);

  if (!rd_match_found) {
    assert(!axi_read_resp_ctrl_formal_top.rd_last_beat);
  }
  if (axi_rresp != 0u) {
    assert(axi_read_resp_ctrl_formal_top.next_resp_code == axi_rresp);
  }
  if (axi_rresp == 0u) {
    assert(axi_read_resp_ctrl_formal_top.next_resp_code == current_resp_code);
  }
  if (rd_match_found && axi_rlast) {
    assert(axi_read_resp_ctrl_formal_top.rd_last_beat);
  }
}
