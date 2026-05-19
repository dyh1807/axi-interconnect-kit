#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#include "../../include/axi_dual_port_route_shape.h"

void set_inputs(void);
void __CPROVER_assume(int);

bool nondet_bool(void);
uint8_t nondet_uint8_t(void);
uint32_t nondet_uint32_t(void);

struct module_axi_read_pack_single4_formal_top
{
  uint32_t current_data;
  uint32_t beat_data;
  uint8_t req_addr;
  uint8_t issued_addr;
  uint8_t beat_idx;
  bool mode2_ddr_aligned;
  uint32_t merged_data;
  uint32_t final_data;
};

extern struct module_axi_read_pack_single4_formal_top
    axi_read_pack_single4_formal_top;

int main(void)
{
  const uint32_t current_data = nondet_uint32_t();
  const uint32_t beat_data = nondet_uint32_t();
  const uint8_t req_addr = nondet_uint8_t();
  const uint8_t issued_addr = nondet_uint8_t();
  const uint8_t beat_idx = nondet_uint8_t();
  const bool mode2_ddr_aligned = nondet_bool();

  if (mode2_ddr_aligned) {
    __CPROVER_assume(req_addr >= issued_addr);
    __CPROVER_assume((uint16_t)req_addr - (uint16_t)issued_addr < 4u);
  }

  axi_read_pack_single4_formal_top.current_data = current_data;
  axi_read_pack_single4_formal_top.beat_data = beat_data;
  axi_read_pack_single4_formal_top.req_addr = req_addr;
  axi_read_pack_single4_formal_top.issued_addr = issued_addr;
  axi_read_pack_single4_formal_top.beat_idx = beat_idx;
  axi_read_pack_single4_formal_top.mode2_ddr_aligned = mode2_ddr_aligned;
  set_inputs();

  const AxiBridgeReadPack64 ref = axi_bridge_read_pack64(
      current_data, beat_data, req_addr, issued_addr, beat_idx,
      mode2_ddr_aligned, 4u, 4u);

  assert(axi_read_pack_single4_formal_top.merged_data ==
         (uint32_t)ref.merged_data);
  assert(axi_read_pack_single4_formal_top.final_data ==
         (uint32_t)ref.final_data);

  if (!mode2_ddr_aligned) {
    assert(axi_read_pack_single4_formal_top.final_data ==
           axi_read_pack_single4_formal_top.merged_data);
  }
  if (beat_idx == 0u) {
    assert(axi_read_pack_single4_formal_top.merged_data == beat_data);
  } else {
    assert(axi_read_pack_single4_formal_top.merged_data == current_data);
  }
}
