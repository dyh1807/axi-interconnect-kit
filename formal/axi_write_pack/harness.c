#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void set_inputs(void);

bool nondet_bool(void);
uint8_t nondet_uint8_t(void);
uint32_t nondet_uint32_t(void);

struct module_axi_write_pack_formal_top
{
  uint64_t line_data;
  uint8_t line_strb;
  uint8_t req_addr;
  uint8_t issued_addr;
  uint8_t beat_idx;
  bool mode2_ddr_aligned;
  uint32_t axi_wdata;
  uint8_t axi_wstrb;
};

extern struct module_axi_write_pack_formal_top axi_write_pack_formal_top;

int main(void)
{
  const uint64_t line_data =
      ((uint64_t)nondet_uint32_t() << 32u) | (uint64_t)nondet_uint32_t();
  const uint8_t line_strb = nondet_uint8_t();
  const uint8_t req_addr = nondet_uint8_t();
  const uint8_t issued_addr = nondet_uint8_t();
  const uint8_t beat_idx = nondet_uint8_t();
  const bool mode2_ddr_aligned = nondet_bool();

  axi_write_pack_formal_top.line_data = line_data;
  axi_write_pack_formal_top.line_strb = line_strb;
  axi_write_pack_formal_top.req_addr = req_addr;
  axi_write_pack_formal_top.issued_addr = issued_addr;
  axi_write_pack_formal_top.beat_idx = beat_idx;
  axi_write_pack_formal_top.mode2_ddr_aligned = mode2_ddr_aligned;
  set_inputs();

  const AxiBridgeWritePack64 ref = axi_bridge_write_pack64(
      line_data, line_strb, req_addr, issued_addr, beat_idx,
      mode2_ddr_aligned, 8u, 4u);

  assert(axi_write_pack_formal_top.axi_wdata == (uint32_t)ref.axi_wdata);
  assert(axi_write_pack_formal_top.axi_wstrb == (uint8_t)ref.axi_wstrb);

  if (!mode2_ddr_aligned && beat_idx == 0u) {
    assert(axi_write_pack_formal_top.axi_wdata == (uint32_t)line_data);
    assert(axi_write_pack_formal_top.axi_wstrb == (line_strb & 0xFu));
  }
  if (!mode2_ddr_aligned && beat_idx == 1u) {
    assert(axi_write_pack_formal_top.axi_wdata ==
           (uint32_t)(line_data >> 32u));
    assert(axi_write_pack_formal_top.axi_wstrb ==
           ((line_strb >> 4u) & 0xFu));
  }
  if (mode2_ddr_aligned && req_addr == issued_addr) {
    const AxiBridgeWritePack64 aligned_ref = axi_bridge_write_pack64(
        line_data, line_strb, req_addr, issued_addr, beat_idx, false, 8u, 4u);
    assert(axi_write_pack_formal_top.axi_wdata ==
           (uint32_t)aligned_ref.axi_wdata);
    assert(axi_write_pack_formal_top.axi_wstrb ==
           (uint8_t)aligned_ref.axi_wstrb);
  }
}
