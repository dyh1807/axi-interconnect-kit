#include <assert.h>
#include <stdbool.h>

#include "../../include/axi_dual_port_route_shape.h"

void set_inputs(void);

bool nondet_bool(void);

struct module_axi_resp_route_formal_top
{
  bool rd_complete_found;
  bool rd_complete_from_cache;
  bool cache_rd_rsp_space;
  bool bypass_rd_rsp_space;
  bool wr_match_from_cache;
  bool cache_wr_rsp_space;
  bool bypass_wr_rsp_space;
  bool wr_resp_accept;
  bool rd_complete_rsp_space;
  bool rd_complete_push;
  bool cache_rd_rsp_push;
  bool bypass_rd_rsp_push;
  bool wr_match_rsp_space;
  bool cache_wr_rsp_push;
  bool bypass_wr_rsp_push;
};

extern struct module_axi_resp_route_formal_top axi_resp_route_formal_top;

int main(void)
{
  const bool rd_complete_found = nondet_bool();
  const bool rd_complete_from_cache = nondet_bool();
  const bool cache_rd_rsp_space = nondet_bool();
  const bool bypass_rd_rsp_space = nondet_bool();
  const bool wr_match_from_cache = nondet_bool();
  const bool cache_wr_rsp_space = nondet_bool();
  const bool bypass_wr_rsp_space = nondet_bool();
  const bool wr_resp_accept = nondet_bool();

  axi_resp_route_formal_top.rd_complete_found = rd_complete_found;
  axi_resp_route_formal_top.rd_complete_from_cache = rd_complete_from_cache;
  axi_resp_route_formal_top.cache_rd_rsp_space = cache_rd_rsp_space;
  axi_resp_route_formal_top.bypass_rd_rsp_space = bypass_rd_rsp_space;
  axi_resp_route_formal_top.wr_match_from_cache = wr_match_from_cache;
  axi_resp_route_formal_top.cache_wr_rsp_space = cache_wr_rsp_space;
  axi_resp_route_formal_top.bypass_wr_rsp_space = bypass_wr_rsp_space;
  axi_resp_route_formal_top.wr_resp_accept = wr_resp_accept;
  set_inputs();

  const AxiBridgeRespRouteControl ref = axi_bridge_resp_route_control(
      rd_complete_found, rd_complete_from_cache, cache_rd_rsp_space,
      bypass_rd_rsp_space, wr_match_from_cache, cache_wr_rsp_space,
      bypass_wr_rsp_space, wr_resp_accept);

  assert(axi_resp_route_formal_top.rd_complete_rsp_space ==
         ref.rd_complete_rsp_space);
  assert(axi_resp_route_formal_top.rd_complete_push ==
         ref.rd_complete_push);
  assert(axi_resp_route_formal_top.cache_rd_rsp_push ==
         ref.cache_rd_rsp_push);
  assert(axi_resp_route_formal_top.bypass_rd_rsp_push ==
         ref.bypass_rd_rsp_push);
  assert(axi_resp_route_formal_top.wr_match_rsp_space ==
         ref.wr_match_rsp_space);
  assert(axi_resp_route_formal_top.cache_wr_rsp_push ==
         ref.cache_wr_rsp_push);
  assert(axi_resp_route_formal_top.bypass_wr_rsp_push ==
         ref.bypass_wr_rsp_push);

  assert(!(axi_resp_route_formal_top.cache_rd_rsp_push &&
           axi_resp_route_formal_top.bypass_rd_rsp_push));
  assert(!(axi_resp_route_formal_top.cache_wr_rsp_push &&
           axi_resp_route_formal_top.bypass_wr_rsp_push));
  if (axi_resp_route_formal_top.cache_rd_rsp_push) {
    assert(rd_complete_found && rd_complete_from_cache && cache_rd_rsp_space);
  }
  if (axi_resp_route_formal_top.bypass_rd_rsp_push) {
    assert(rd_complete_found && !rd_complete_from_cache &&
           bypass_rd_rsp_space);
  }
}
