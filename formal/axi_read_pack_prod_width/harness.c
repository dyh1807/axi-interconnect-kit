#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void set_inputs(void);

bool nondet_bool(void);
uint8_t nondet_uint8_t(void);
uint32_t nondet_uint32_t(void);

struct module_axi_read_pack_prod_width_formal_top
{
  uint64_t current_data_0;
  uint64_t current_data_1;
  uint64_t current_data_2;
  uint64_t current_data_3;
  uint64_t current_data_4;
  uint64_t current_data_5;
  uint64_t current_data_6;
  uint64_t current_data_7;
  uint64_t beat_data_0;
  uint64_t beat_data_1;
  uint64_t beat_data_2;
  uint64_t beat_data_3;
  uint32_t req_addr;
  uint32_t issued_addr;
  uint8_t beat_idx;
  bool mode2_ddr_aligned;
  uint64_t merged_data_0;
  uint64_t merged_data_1;
  uint64_t merged_data_2;
  uint64_t merged_data_3;
  uint64_t merged_data_4;
  uint64_t merged_data_5;
  uint64_t merged_data_6;
  uint64_t merged_data_7;
  uint64_t final_data_0;
  uint64_t final_data_1;
  uint64_t final_data_2;
  uint64_t final_data_3;
  uint64_t final_data_4;
  uint64_t final_data_5;
  uint64_t final_data_6;
  uint64_t final_data_7;
};

extern struct module_axi_read_pack_prod_width_formal_top
    axi_read_pack_prod_width_formal_top;

typedef struct Read512
{
  uint64_t data_0;
  uint64_t data_1;
  uint64_t data_2;
  uint64_t data_3;
  uint64_t data_4;
  uint64_t data_5;
  uint64_t data_6;
  uint64_t data_7;
} Read512;

static uint64_t mk64(void)
{
  return ((uint64_t)nondet_uint32_t() << 32u) | nondet_uint32_t();
}

static uint8_t get_byte64(uint64_t value, uint8_t byte_index)
{
  return (uint8_t)((value >> ((uint32_t)byte_index * 8u)) & 0xffu);
}

static uint64_t set_byte64(uint64_t value, uint8_t byte_index,
                           uint8_t byte_value)
{
  const uint64_t mask = 0xffull << ((uint32_t)byte_index * 8u);
  return (value & ~mask) | ((uint64_t)byte_value << ((uint32_t)byte_index * 8u));
}

static uint8_t get_read_byte(const Read512 *value, uint8_t index)
{
  const uint8_t chunk_byte = index & 7u;
  if(index < 8u)
    return get_byte64(value->data_0, chunk_byte);
  if(index < 16u)
    return get_byte64(value->data_1, chunk_byte);
  if(index < 24u)
    return get_byte64(value->data_2, chunk_byte);
  if(index < 32u)
    return get_byte64(value->data_3, chunk_byte);
  if(index < 40u)
    return get_byte64(value->data_4, chunk_byte);
  if(index < 48u)
    return get_byte64(value->data_5, chunk_byte);
  if(index < 56u)
    return get_byte64(value->data_6, chunk_byte);
  return get_byte64(value->data_7, chunk_byte);
}

static void set_read_byte(Read512 *value, uint8_t index, uint8_t byte_value)
{
  const uint8_t chunk_byte = index & 7u;
  if(index < 8u)
    value->data_0 = set_byte64(value->data_0, chunk_byte, byte_value);
  else if(index < 16u)
    value->data_1 = set_byte64(value->data_1, chunk_byte, byte_value);
  else if(index < 24u)
    value->data_2 = set_byte64(value->data_2, chunk_byte, byte_value);
  else if(index < 32u)
    value->data_3 = set_byte64(value->data_3, chunk_byte, byte_value);
  else if(index < 40u)
    value->data_4 = set_byte64(value->data_4, chunk_byte, byte_value);
  else if(index < 48u)
    value->data_5 = set_byte64(value->data_5, chunk_byte, byte_value);
  else if(index < 56u)
    value->data_6 = set_byte64(value->data_6, chunk_byte, byte_value);
  else
    value->data_7 = set_byte64(value->data_7, chunk_byte, byte_value);
}

static uint8_t get_beat_byte(uint8_t index)
{
  const uint8_t chunk_byte = index & 7u;
  if(index < 8u)
    return get_byte64(axi_read_pack_prod_width_formal_top.beat_data_0,
                      chunk_byte);
  if(index < 16u)
    return get_byte64(axi_read_pack_prod_width_formal_top.beat_data_1,
                      chunk_byte);
  if(index < 24u)
    return get_byte64(axi_read_pack_prod_width_formal_top.beat_data_2,
                      chunk_byte);
  return get_byte64(axi_read_pack_prod_width_formal_top.beat_data_3,
                    chunk_byte);
}

static Read512 current_data(void)
{
  Read512 out;
  out.data_0 = axi_read_pack_prod_width_formal_top.current_data_0;
  out.data_1 = axi_read_pack_prod_width_formal_top.current_data_1;
  out.data_2 = axi_read_pack_prod_width_formal_top.current_data_2;
  out.data_3 = axi_read_pack_prod_width_formal_top.current_data_3;
  out.data_4 = axi_read_pack_prod_width_formal_top.current_data_4;
  out.data_5 = axi_read_pack_prod_width_formal_top.current_data_5;
  out.data_6 = axi_read_pack_prod_width_formal_top.current_data_6;
  out.data_7 = axi_read_pack_prod_width_formal_top.current_data_7;
  return out;
}

static Read512 zero_data(void)
{
  Read512 out = {0u, 0u, 0u, 0u, 0u, 0u, 0u, 0u};
  return out;
}

static Read512 expected_merged(uint8_t beat_idx)
{
  Read512 out = current_data();
  for(uint8_t byte_idx = 0u; byte_idx < 32u; byte_idx++)
  {
    const uint32_t dst = (uint32_t)beat_idx * 32u + byte_idx;
    if(dst < 64u)
      set_read_byte(&out, (uint8_t)dst, get_beat_byte(byte_idx));
  }
  return out;
}

static Read512 expected_final(const Read512 *merged, bool mode2,
                              uint32_t req_addr, uint32_t issued_addr)
{
  if(!mode2)
    return *merged;

  Read512 out = zero_data();
  const int32_t byte_off = (int32_t)(req_addr - issued_addr);
  for(uint8_t dst = 0u; dst < 64u; dst++)
  {
    const int32_t src = (int32_t)dst + byte_off;
    if(src >= 0 && src < 64)
      set_read_byte(&out, dst, get_read_byte(merged, (uint8_t)src));
  }
  return out;
}

static void assert_read512_equal_outputs(const Read512 *merged,
                                         const Read512 *final)
{
  assert(axi_read_pack_prod_width_formal_top.merged_data_0 == merged->data_0);
  assert(axi_read_pack_prod_width_formal_top.merged_data_1 == merged->data_1);
  assert(axi_read_pack_prod_width_formal_top.merged_data_2 == merged->data_2);
  assert(axi_read_pack_prod_width_formal_top.merged_data_3 == merged->data_3);
  assert(axi_read_pack_prod_width_formal_top.merged_data_4 == merged->data_4);
  assert(axi_read_pack_prod_width_formal_top.merged_data_5 == merged->data_5);
  assert(axi_read_pack_prod_width_formal_top.merged_data_6 == merged->data_6);
  assert(axi_read_pack_prod_width_formal_top.merged_data_7 == merged->data_7);

  assert(axi_read_pack_prod_width_formal_top.final_data_0 == final->data_0);
  assert(axi_read_pack_prod_width_formal_top.final_data_1 == final->data_1);
  assert(axi_read_pack_prod_width_formal_top.final_data_2 == final->data_2);
  assert(axi_read_pack_prod_width_formal_top.final_data_3 == final->data_3);
  assert(axi_read_pack_prod_width_formal_top.final_data_4 == final->data_4);
  assert(axi_read_pack_prod_width_formal_top.final_data_5 == final->data_5);
  assert(axi_read_pack_prod_width_formal_top.final_data_6 == final->data_6);
  assert(axi_read_pack_prod_width_formal_top.final_data_7 == final->data_7);
}

int main(void)
{
  const bool mode2 = nondet_bool();
  const uint32_t issued_addr =
      0x40000000u + (nondet_uint32_t() & 0x0000ffe0u);
  const uint8_t offset = nondet_uint8_t() % 29u;
  const uint32_t req_addr = mode2 ? (issued_addr + offset) : 0u;
  const uint8_t beat_idx = mode2 ? 0u : (nondet_uint8_t() & 1u);

  axi_read_pack_prod_width_formal_top.current_data_0 = mk64();
  axi_read_pack_prod_width_formal_top.current_data_1 = mk64();
  axi_read_pack_prod_width_formal_top.current_data_2 = mk64();
  axi_read_pack_prod_width_formal_top.current_data_3 = mk64();
  axi_read_pack_prod_width_formal_top.current_data_4 = mk64();
  axi_read_pack_prod_width_formal_top.current_data_5 = mk64();
  axi_read_pack_prod_width_formal_top.current_data_6 = mk64();
  axi_read_pack_prod_width_formal_top.current_data_7 = mk64();
  axi_read_pack_prod_width_formal_top.beat_data_0 = mk64();
  axi_read_pack_prod_width_formal_top.beat_data_1 = mk64();
  axi_read_pack_prod_width_formal_top.beat_data_2 = mk64();
  axi_read_pack_prod_width_formal_top.beat_data_3 = mk64();
  axi_read_pack_prod_width_formal_top.req_addr = req_addr;
  axi_read_pack_prod_width_formal_top.issued_addr = issued_addr;
  axi_read_pack_prod_width_formal_top.beat_idx = beat_idx;
  axi_read_pack_prod_width_formal_top.mode2_ddr_aligned = mode2;
  set_inputs();

  const Read512 merged = expected_merged(beat_idx);
  const Read512 final = expected_final(&merged, mode2, req_addr, issued_addr);
  assert_read512_equal_outputs(&merged, &final);

  if(!mode2 && beat_idx == 0u)
  {
    assert(axi_read_pack_prod_width_formal_top.merged_data_0 ==
           axi_read_pack_prod_width_formal_top.beat_data_0);
    assert(axi_read_pack_prod_width_formal_top.merged_data_3 ==
           axi_read_pack_prod_width_formal_top.beat_data_3);
    assert(axi_read_pack_prod_width_formal_top.merged_data_4 ==
           axi_read_pack_prod_width_formal_top.current_data_4);
  }
  if(!mode2 && beat_idx == 1u)
  {
    assert(axi_read_pack_prod_width_formal_top.merged_data_0 ==
           axi_read_pack_prod_width_formal_top.current_data_0);
    assert(axi_read_pack_prod_width_formal_top.merged_data_4 ==
           axi_read_pack_prod_width_formal_top.beat_data_0);
    assert(axi_read_pack_prod_width_formal_top.merged_data_7 ==
           axi_read_pack_prod_width_formal_top.beat_data_3);
  }
  if(mode2 && offset == 0u)
  {
    assert(axi_read_pack_prod_width_formal_top.final_data_0 ==
           axi_read_pack_prod_width_formal_top.beat_data_0);
    assert(axi_read_pack_prod_width_formal_top.final_data_3 ==
           axi_read_pack_prod_width_formal_top.beat_data_3);
  }
}
