#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void set_inputs(void);

bool nondet_bool(void);
uint8_t nondet_uint8_t(void);

struct module_axi_queue_ctrl_formal_top
{
  uint8_t rd_issue_count;
  uint8_t wr_aw_count;
  uint8_t wr_w_count;
  uint8_t cache_rd_rsp_count;
  uint8_t bypass_rd_rsp_count;
  uint8_t cache_wr_rsp_count;
  uint8_t bypass_wr_rsp_count;
  bool accept_cache;
  bool accept_bypass;
  bool accept_write;
  bool rd_issue_valid;
  bool axi_arready;
  bool wr_aw_valid;
  bool axi_awready;
  bool wr_w_valid;
  bool axi_wready;
  bool axi_wlast;
  bool rd_issue_space;
  bool wr_aw_space;
  bool wr_w_space;
  bool cache_rd_rsp_valid;
  bool bypass_rd_rsp_valid;
  bool cache_wr_rsp_valid;
  bool bypass_wr_rsp_valid;
  bool cache_rd_rsp_space;
  bool bypass_rd_rsp_space;
  bool cache_wr_rsp_space;
  bool bypass_wr_rsp_space;
  bool rd_issue_handshake;
  bool wr_aw_handshake;
  bool wr_w_handshake;
  bool rd_issue_push;
  bool rd_issue_pop;
  bool wr_aw_push;
  bool wr_aw_pop;
  bool wr_w_push;
  bool wr_w_pop;
};

extern struct module_axi_queue_ctrl_formal_top axi_queue_ctrl_formal_top;

static uint8_t small_count(void)
{
  return (uint8_t)(nondet_uint8_t() & 7u);
}

int main(void)
{
  const uint8_t rd_issue_count = small_count();
  const uint8_t wr_aw_count = small_count();
  const uint8_t wr_w_count = small_count();
  const uint8_t cache_rd_rsp_count = small_count();
  const uint8_t bypass_rd_rsp_count = small_count();
  const uint8_t cache_wr_rsp_count = small_count();
  const uint8_t bypass_wr_rsp_count = small_count();
  const bool accept_cache = nondet_bool();
  const bool accept_bypass = nondet_bool();
  const bool accept_write = nondet_bool();
  const bool rd_issue_valid = nondet_bool();
  const bool axi_arready = nondet_bool();
  const bool wr_aw_valid = nondet_bool();
  const bool axi_awready = nondet_bool();
  const bool wr_w_valid = nondet_bool();
  const bool axi_wready = nondet_bool();
  const bool axi_wlast = nondet_bool();

  axi_queue_ctrl_formal_top.rd_issue_count = rd_issue_count;
  axi_queue_ctrl_formal_top.wr_aw_count = wr_aw_count;
  axi_queue_ctrl_formal_top.wr_w_count = wr_w_count;
  axi_queue_ctrl_formal_top.cache_rd_rsp_count = cache_rd_rsp_count;
  axi_queue_ctrl_formal_top.bypass_rd_rsp_count = bypass_rd_rsp_count;
  axi_queue_ctrl_formal_top.cache_wr_rsp_count = cache_wr_rsp_count;
  axi_queue_ctrl_formal_top.bypass_wr_rsp_count = bypass_wr_rsp_count;
  axi_queue_ctrl_formal_top.accept_cache = accept_cache;
  axi_queue_ctrl_formal_top.accept_bypass = accept_bypass;
  axi_queue_ctrl_formal_top.accept_write = accept_write;
  axi_queue_ctrl_formal_top.rd_issue_valid = rd_issue_valid;
  axi_queue_ctrl_formal_top.axi_arready = axi_arready;
  axi_queue_ctrl_formal_top.wr_aw_valid = wr_aw_valid;
  axi_queue_ctrl_formal_top.axi_awready = axi_awready;
  axi_queue_ctrl_formal_top.wr_w_valid = wr_w_valid;
  axi_queue_ctrl_formal_top.axi_wready = axi_wready;
  axi_queue_ctrl_formal_top.axi_wlast = axi_wlast;
  set_inputs();

  const AxiBridgeQueueControl ref = axi_bridge_queue_control(
      rd_issue_count, wr_aw_count, wr_w_count, cache_rd_rsp_count,
      bypass_rd_rsp_count, cache_wr_rsp_count, bypass_wr_rsp_count,
      accept_cache, accept_bypass, accept_write, rd_issue_valid, axi_arready,
      wr_aw_valid, axi_awready, wr_w_valid, axi_wready, axi_wlast, 4u, 4u);

  assert(axi_queue_ctrl_formal_top.rd_issue_space == ref.rd_issue_space);
  assert(axi_queue_ctrl_formal_top.wr_aw_space == ref.wr_aw_space);
  assert(axi_queue_ctrl_formal_top.wr_w_space == ref.wr_w_space);
  assert(axi_queue_ctrl_formal_top.cache_rd_rsp_valid ==
         ref.cache_rd_rsp_valid);
  assert(axi_queue_ctrl_formal_top.bypass_rd_rsp_valid ==
         ref.bypass_rd_rsp_valid);
  assert(axi_queue_ctrl_formal_top.cache_wr_rsp_valid ==
         ref.cache_wr_rsp_valid);
  assert(axi_queue_ctrl_formal_top.bypass_wr_rsp_valid ==
         ref.bypass_wr_rsp_valid);
  assert(axi_queue_ctrl_formal_top.cache_rd_rsp_space ==
         ref.cache_rd_rsp_space);
  assert(axi_queue_ctrl_formal_top.bypass_rd_rsp_space ==
         ref.bypass_rd_rsp_space);
  assert(axi_queue_ctrl_formal_top.cache_wr_rsp_space ==
         ref.cache_wr_rsp_space);
  assert(axi_queue_ctrl_formal_top.bypass_wr_rsp_space ==
         ref.bypass_wr_rsp_space);
  assert(axi_queue_ctrl_formal_top.rd_issue_handshake ==
         ref.rd_issue_handshake);
  assert(axi_queue_ctrl_formal_top.wr_aw_handshake == ref.wr_aw_handshake);
  assert(axi_queue_ctrl_formal_top.wr_w_handshake == ref.wr_w_handshake);
  assert(axi_queue_ctrl_formal_top.rd_issue_push == ref.rd_issue_push);
  assert(axi_queue_ctrl_formal_top.rd_issue_pop == ref.rd_issue_pop);
  assert(axi_queue_ctrl_formal_top.wr_aw_push == ref.wr_aw_push);
  assert(axi_queue_ctrl_formal_top.wr_aw_pop == ref.wr_aw_pop);
  assert(axi_queue_ctrl_formal_top.wr_w_push == ref.wr_w_push);
  assert(axi_queue_ctrl_formal_top.wr_w_pop == ref.wr_w_pop);

  if (!accept_cache && !accept_bypass) {
    assert(!axi_queue_ctrl_formal_top.rd_issue_push);
    assert(!axi_queue_ctrl_formal_top.wr_aw_push);
    assert(!axi_queue_ctrl_formal_top.wr_w_push);
  }
  if (!axi_wlast) {
    assert(!axi_queue_ctrl_formal_top.wr_w_pop ||
           !axi_queue_ctrl_formal_top.wr_w_handshake);
  }
}
