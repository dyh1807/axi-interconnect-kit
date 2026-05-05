#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void set_inputs(void);

bool nondet_bool(void);
uint8_t nondet_uint8_t(void);

struct module_axi_req_accept_formal_top
{
  bool cache_req_valid;
  bool cache_req_write;
  uint8_t cache_total_beats;
  bool bypass_req_valid;
  bool bypass_req_write;
  uint8_t bypass_total_beats;
  bool rd_free_found;
  uint8_t rd_free_slot;
  bool rd_axi_id_found;
  uint8_t rd_axi_id;
  bool rd_issue_space;
  bool wr_free_found;
  uint8_t wr_free_slot;
  bool wr_axi_id_found;
  uint8_t wr_axi_id;
  bool wr_aw_space;
  bool wr_w_space;
  bool accept_cache;
  bool accept_bypass;
  bool accept_write;
  uint8_t accept_slot;
  uint8_t accept_axi_id;
  uint8_t accept_total_beats;
};

extern struct module_axi_req_accept_formal_top axi_req_accept_formal_top;

int main(void)
{
  const bool cache_req_valid = nondet_bool();
  const bool cache_req_write = nondet_bool();
  const uint8_t cache_total_beats = nondet_uint8_t();
  const bool bypass_req_valid = nondet_bool();
  const bool bypass_req_write = nondet_bool();
  const uint8_t bypass_total_beats = nondet_uint8_t();
  const bool rd_free_found = nondet_bool();
  const uint8_t rd_free_slot = nondet_uint8_t();
  const bool rd_axi_id_found = nondet_bool();
  const uint8_t rd_axi_id = nondet_uint8_t() & 7u;
  const bool rd_issue_space = nondet_bool();
  const bool wr_free_found = nondet_bool();
  const uint8_t wr_free_slot = nondet_uint8_t();
  const bool wr_axi_id_found = nondet_bool();
  const uint8_t wr_axi_id = nondet_uint8_t() & 7u;
  const bool wr_aw_space = nondet_bool();
  const bool wr_w_space = nondet_bool();

  axi_req_accept_formal_top.cache_req_valid = cache_req_valid;
  axi_req_accept_formal_top.cache_req_write = cache_req_write;
  axi_req_accept_formal_top.cache_total_beats = cache_total_beats;
  axi_req_accept_formal_top.bypass_req_valid = bypass_req_valid;
  axi_req_accept_formal_top.bypass_req_write = bypass_req_write;
  axi_req_accept_formal_top.bypass_total_beats = bypass_total_beats;
  axi_req_accept_formal_top.rd_free_found = rd_free_found;
  axi_req_accept_formal_top.rd_free_slot = rd_free_slot;
  axi_req_accept_formal_top.rd_axi_id_found = rd_axi_id_found;
  axi_req_accept_formal_top.rd_axi_id = rd_axi_id;
  axi_req_accept_formal_top.rd_issue_space = rd_issue_space;
  axi_req_accept_formal_top.wr_free_found = wr_free_found;
  axi_req_accept_formal_top.wr_free_slot = wr_free_slot;
  axi_req_accept_formal_top.wr_axi_id_found = wr_axi_id_found;
  axi_req_accept_formal_top.wr_axi_id = wr_axi_id;
  axi_req_accept_formal_top.wr_aw_space = wr_aw_space;
  axi_req_accept_formal_top.wr_w_space = wr_w_space;
  set_inputs();

  const AxiBridgeReqAcceptControl ref = axi_bridge_req_accept_control(
      cache_req_valid, cache_req_write, cache_total_beats, bypass_req_valid,
      bypass_req_write, bypass_total_beats, rd_free_found, rd_free_slot,
      rd_axi_id_found, rd_axi_id, rd_issue_space, wr_free_found, wr_free_slot,
      wr_axi_id_found, wr_axi_id, wr_aw_space, wr_w_space);

  assert(axi_req_accept_formal_top.accept_cache == ref.accept_cache);
  assert(axi_req_accept_formal_top.accept_bypass == ref.accept_bypass);
  assert(axi_req_accept_formal_top.accept_write == ref.accept_write);
  assert(axi_req_accept_formal_top.accept_slot == ref.accept_slot);
  assert(axi_req_accept_formal_top.accept_axi_id == ref.accept_axi_id);
  assert(axi_req_accept_formal_top.accept_total_beats ==
         ref.accept_total_beats);

  assert(!(axi_req_accept_formal_top.accept_cache &&
           axi_req_accept_formal_top.accept_bypass));
  if (cache_req_valid) {
    assert(!axi_req_accept_formal_top.accept_bypass);
  }
  if (!cache_req_valid && !bypass_req_valid) {
    assert(!axi_req_accept_formal_top.accept_cache);
    assert(!axi_req_accept_formal_top.accept_bypass);
  }
  if (axi_req_accept_formal_top.accept_cache ||
      axi_req_accept_formal_top.accept_bypass) {
    if (axi_req_accept_formal_top.accept_write) {
      assert(wr_free_found && wr_axi_id_found && wr_aw_space && wr_w_space);
    } else {
      assert(rd_free_found && rd_axi_id_found && rd_issue_space);
    }
  }
}
