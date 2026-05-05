#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void set_inputs(void);

bool nondet_bool(void);
uint8_t nondet_uint8_t(void);
uint32_t nondet_uint32_t(void);

struct module_axi_write_pack_prod_width_formal_top
{
  uint64_t line_data_0;
  uint64_t line_data_1;
  uint64_t line_data_2;
  uint64_t line_data_3;
  uint64_t line_data_4;
  uint64_t line_data_5;
  uint64_t line_data_6;
  uint64_t line_data_7;
  uint64_t line_strb;
  uint32_t req_addr;
  uint32_t issued_addr;
  uint8_t beat_idx;
  bool mode2_ddr_aligned;
  uint64_t axi_wdata_0;
  uint64_t axi_wdata_1;
  uint64_t axi_wdata_2;
  uint64_t axi_wdata_3;
  uint32_t axi_wstrb;
};

extern struct module_axi_write_pack_prod_width_formal_top
    axi_write_pack_prod_width_formal_top;

typedef struct ExpectedWrite256
{
  uint64_t data_0;
  uint64_t data_1;
  uint64_t data_2;
  uint64_t data_3;
  uint32_t strb;
} ExpectedWrite256;

static uint8_t get_line_byte(uint8_t index, uint64_t d0, uint64_t d1,
                             uint64_t d2, uint64_t d3, uint64_t d4,
                             uint64_t d5, uint64_t d6, uint64_t d7)
{
  const uint8_t chunk_byte = index & 7u;
  const uint32_t shift = (uint32_t)chunk_byte * 8u;
  if(index < 8u)
    return (uint8_t)((d0 >> shift) & 0xffu);
  if(index < 16u)
    return (uint8_t)((d1 >> shift) & 0xffu);
  if(index < 24u)
    return (uint8_t)((d2 >> shift) & 0xffu);
  if(index < 32u)
    return (uint8_t)((d3 >> shift) & 0xffu);
  if(index < 40u)
    return (uint8_t)((d4 >> shift) & 0xffu);
  if(index < 48u)
    return (uint8_t)((d5 >> shift) & 0xffu);
  if(index < 56u)
    return (uint8_t)((d6 >> shift) & 0xffu);
  return (uint8_t)((d7 >> shift) & 0xffu);
}

static uint64_t set_byte64(uint64_t value, uint8_t byte_index,
                           uint8_t byte_value)
{
  const uint64_t mask = 0xffull << ((uint32_t)byte_index * 8u);
  return (value & ~mask) | ((uint64_t)byte_value << ((uint32_t)byte_index * 8u));
}

static void set_axi_byte(ExpectedWrite256 *out, uint8_t index,
                         uint8_t byte_value)
{
  const uint8_t chunk_byte = index & 7u;
  if(index < 8u)
    out->data_0 = set_byte64(out->data_0, chunk_byte, byte_value);
  else if(index < 16u)
    out->data_1 = set_byte64(out->data_1, chunk_byte, byte_value);
  else if(index < 24u)
    out->data_2 = set_byte64(out->data_2, chunk_byte, byte_value);
  else
    out->data_3 = set_byte64(out->data_3, chunk_byte, byte_value);
}

static bool get_strb_bit(uint64_t line_strb, uint8_t index)
{
  return ((line_strb >> index) & 1u) != 0u;
}

static ExpectedWrite256 expected_pack(uint8_t beat_idx, bool mode2,
                                      uint32_t req_addr, uint32_t issued_addr)
{
  ExpectedWrite256 out = {0u, 0u, 0u, 0u, 0u};
  const int32_t byte_off = (int32_t)(req_addr - issued_addr);

  for(uint8_t byte_idx = 0u; byte_idx < 32u; byte_idx++)
  {
    const int32_t dst = (int32_t)((uint32_t)beat_idx * 32u + byte_idx);
    const int32_t src = mode2 ? (dst - byte_off) : dst;
    if(src >= 0 && src < 64)
    {
      const uint8_t src_u = (uint8_t)src;
      const uint8_t value = get_line_byte(
          src_u, axi_write_pack_prod_width_formal_top.line_data_0,
          axi_write_pack_prod_width_formal_top.line_data_1,
          axi_write_pack_prod_width_formal_top.line_data_2,
          axi_write_pack_prod_width_formal_top.line_data_3,
          axi_write_pack_prod_width_formal_top.line_data_4,
          axi_write_pack_prod_width_formal_top.line_data_5,
          axi_write_pack_prod_width_formal_top.line_data_6,
          axi_write_pack_prod_width_formal_top.line_data_7);
      set_axi_byte(&out, byte_idx, value);
      if(get_strb_bit(axi_write_pack_prod_width_formal_top.line_strb, src_u))
        out.strb |= (uint32_t)1u << byte_idx;
    }
  }

  return out;
}

int main(void)
{
  const bool mode2 = nondet_bool();
  const uint32_t issued_addr =
      0x40000000u + (nondet_uint32_t() & 0x0000ffe0u);
  const uint8_t offset = nondet_uint8_t() % 29u;
  const uint32_t req_addr = mode2 ? (issued_addr + offset) : 0u;
  const uint8_t beat_idx = mode2 ? 0u : (nondet_uint8_t() & 1u);

  axi_write_pack_prod_width_formal_top.line_data_0 =
      ((uint64_t)nondet_uint32_t() << 32u) | nondet_uint32_t();
  axi_write_pack_prod_width_formal_top.line_data_1 =
      ((uint64_t)nondet_uint32_t() << 32u) | nondet_uint32_t();
  axi_write_pack_prod_width_formal_top.line_data_2 =
      ((uint64_t)nondet_uint32_t() << 32u) | nondet_uint32_t();
  axi_write_pack_prod_width_formal_top.line_data_3 =
      ((uint64_t)nondet_uint32_t() << 32u) | nondet_uint32_t();
  axi_write_pack_prod_width_formal_top.line_data_4 =
      ((uint64_t)nondet_uint32_t() << 32u) | nondet_uint32_t();
  axi_write_pack_prod_width_formal_top.line_data_5 =
      ((uint64_t)nondet_uint32_t() << 32u) | nondet_uint32_t();
  axi_write_pack_prod_width_formal_top.line_data_6 =
      ((uint64_t)nondet_uint32_t() << 32u) | nondet_uint32_t();
  axi_write_pack_prod_width_formal_top.line_data_7 =
      ((uint64_t)nondet_uint32_t() << 32u) | nondet_uint32_t();
  axi_write_pack_prod_width_formal_top.line_strb =
      ((uint64_t)nondet_uint32_t() << 32u) | nondet_uint32_t();
  axi_write_pack_prod_width_formal_top.req_addr = req_addr;
  axi_write_pack_prod_width_formal_top.issued_addr = issued_addr;
  axi_write_pack_prod_width_formal_top.beat_idx = beat_idx;
  axi_write_pack_prod_width_formal_top.mode2_ddr_aligned = mode2;
  set_inputs();

  const ExpectedWrite256 expected =
      expected_pack(beat_idx, mode2, req_addr, issued_addr);

  assert(axi_write_pack_prod_width_formal_top.axi_wdata_0 == expected.data_0);
  assert(axi_write_pack_prod_width_formal_top.axi_wdata_1 == expected.data_1);
  assert(axi_write_pack_prod_width_formal_top.axi_wdata_2 == expected.data_2);
  assert(axi_write_pack_prod_width_formal_top.axi_wdata_3 == expected.data_3);
  assert(axi_write_pack_prod_width_formal_top.axi_wstrb == expected.strb);

  if(!mode2 && beat_idx == 0u)
  {
    assert(axi_write_pack_prod_width_formal_top.axi_wdata_0 ==
           axi_write_pack_prod_width_formal_top.line_data_0);
    assert(axi_write_pack_prod_width_formal_top.axi_wdata_3 ==
           axi_write_pack_prod_width_formal_top.line_data_3);
    assert(axi_write_pack_prod_width_formal_top.axi_wstrb ==
           (uint32_t)axi_write_pack_prod_width_formal_top.line_strb);
  }
  if(!mode2 && beat_idx == 1u)
  {
    assert(axi_write_pack_prod_width_formal_top.axi_wdata_0 ==
           axi_write_pack_prod_width_formal_top.line_data_4);
    assert(axi_write_pack_prod_width_formal_top.axi_wdata_3 ==
           axi_write_pack_prod_width_formal_top.line_data_7);
    assert(axi_write_pack_prod_width_formal_top.axi_wstrb ==
           (uint32_t)(axi_write_pack_prod_width_formal_top.line_strb >> 32u));
  }
}
