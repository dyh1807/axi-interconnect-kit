#include <assert.h>
#include <stdbool.h>

#include "../../include/axi_dual_port_route_shape.h"

void set_inputs(void);

bool nondet_bool(void);

struct module_axi_resp_accept_formal_top
{
  bool axi_rvalid;
  bool rd_match_found;
  bool axi_rready;
  bool rd_resp_accept;
  bool axi_bvalid;
  bool wr_match_found;
  bool wr_match_rsp_space;
  bool axi_bready;
  bool wr_resp_accept;
};

extern struct module_axi_resp_accept_formal_top axi_resp_accept_formal_top;

int main(void)
{
  const bool axi_rvalid = nondet_bool();
  const bool rd_match_found = nondet_bool();
  const bool axi_bvalid = nondet_bool();
  const bool wr_match_found = nondet_bool();
  const bool wr_match_rsp_space = nondet_bool();

  axi_resp_accept_formal_top.axi_rvalid = axi_rvalid;
  axi_resp_accept_formal_top.rd_match_found = rd_match_found;
  axi_resp_accept_formal_top.axi_bvalid = axi_bvalid;
  axi_resp_accept_formal_top.wr_match_found = wr_match_found;
  axi_resp_accept_formal_top.wr_match_rsp_space = wr_match_rsp_space;
  set_inputs();

  const AxiBridgeRespAcceptControl ref = axi_bridge_resp_accept_control(
      axi_rvalid, rd_match_found, axi_bvalid, wr_match_found,
      wr_match_rsp_space);

  assert(axi_resp_accept_formal_top.axi_rready == ref.axi_rready);
  assert(axi_resp_accept_formal_top.rd_resp_accept == ref.rd_resp_accept);
  assert(axi_resp_accept_formal_top.axi_bready == ref.axi_bready);
  assert(axi_resp_accept_formal_top.wr_resp_accept == ref.wr_resp_accept);

  assert(axi_resp_accept_formal_top.axi_rready == rd_match_found);
  assert(!wr_match_rsp_space || !wr_match_found ||
         axi_resp_accept_formal_top.axi_bready);
  assert(wr_match_rsp_space || !axi_resp_accept_formal_top.axi_bready);
}
