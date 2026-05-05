#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void set_inputs(void);

bool nondet_bool(void);
uint8_t nondet_uint8_t(void);
uint16_t nondet_uint16_t(void);

struct module_axi_source_resp_mux_formal_top
{
  bool rd_valid;
  uint16_t rd_data;
  uint8_t rd_id;
  uint8_t rd_code;
  bool wr_valid;
  uint8_t wr_id;
  uint8_t wr_code;
  bool resp_ready;
  bool resp_valid;
  bool select_read;
  uint16_t resp_data;
  uint8_t resp_id;
  uint8_t resp_code;
  bool rd_pop;
  bool wr_pop;
};

extern struct module_axi_source_resp_mux_formal_top
    axi_source_resp_mux_formal_top;

int main(void)
{
  const bool rd_valid = nondet_bool();
  const uint16_t rd_data = nondet_uint16_t();
  const uint8_t rd_id = nondet_uint8_t() & 7u;
  const uint8_t rd_code = nondet_uint8_t() & 3u;
  const bool wr_valid = nondet_bool();
  const uint8_t wr_id = nondet_uint8_t() & 7u;
  const uint8_t wr_code = nondet_uint8_t() & 3u;
  const bool resp_ready = nondet_bool();

  axi_source_resp_mux_formal_top.rd_valid = rd_valid;
  axi_source_resp_mux_formal_top.rd_data = rd_data;
  axi_source_resp_mux_formal_top.rd_id = rd_id;
  axi_source_resp_mux_formal_top.rd_code = rd_code;
  axi_source_resp_mux_formal_top.wr_valid = wr_valid;
  axi_source_resp_mux_formal_top.wr_id = wr_id;
  axi_source_resp_mux_formal_top.wr_code = wr_code;
  axi_source_resp_mux_formal_top.resp_ready = resp_ready;
  set_inputs();

  const AxiBridgeSourceRespMuxControl ref =
      axi_bridge_source_resp_mux_control(rd_valid, wr_valid, resp_ready);

  assert(axi_source_resp_mux_formal_top.resp_valid == ref.resp_valid);
  assert(axi_source_resp_mux_formal_top.select_read == ref.select_read);
  assert(axi_source_resp_mux_formal_top.rd_pop == ref.rd_pop);
  assert(axi_source_resp_mux_formal_top.wr_pop == ref.wr_pop);

  if (rd_valid) {
    assert(axi_source_resp_mux_formal_top.resp_valid);
    assert(axi_source_resp_mux_formal_top.select_read);
    assert(axi_source_resp_mux_formal_top.resp_data == rd_data);
    assert(axi_source_resp_mux_formal_top.resp_id == rd_id);
    assert(axi_source_resp_mux_formal_top.resp_code == rd_code);
  } else if (wr_valid) {
    assert(axi_source_resp_mux_formal_top.resp_valid);
    assert(!axi_source_resp_mux_formal_top.select_read);
    assert(axi_source_resp_mux_formal_top.resp_data == 0u);
    assert(axi_source_resp_mux_formal_top.resp_id == wr_id);
    assert(axi_source_resp_mux_formal_top.resp_code == wr_code);
  } else {
    assert(!axi_source_resp_mux_formal_top.resp_valid);
  }
  assert(!(axi_source_resp_mux_formal_top.rd_pop &&
           axi_source_resp_mux_formal_top.wr_pop));
}
