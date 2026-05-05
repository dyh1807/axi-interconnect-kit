#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

struct module_cache_ctrl_partial_write_hit_merge_formal_top
{
  bool clk;
  bool rst_n;
  bool req_valid;
  bool req_ready;
  bool resp_valid;
  uint8_t resp_id;
  uint8_t resp_code;
  bool data_wr_en;
  uint8_t data_wr_way_mask;
  uint64_t data_wr_line0;
  uint64_t data_wr_line1;
  bool meta_wr_en;
  uint8_t meta_wr_way_mask;
  uint8_t meta_wr_way0;
  uint8_t meta_wr_way1;
  bool valid_wr_en;
  uint8_t valid_wr_mask;
  uint8_t valid_wr_bits;
  bool repl_wr_en;
  bool repl_wr_way;
  bool mem_req_valid;
};

extern struct module_cache_ctrl_partial_write_hit_merge_formal_top
    cache_ctrl_partial_write_hit_merge_formal_top;

static void drive_idle(void)
{
  cache_ctrl_partial_write_hit_merge_formal_top.req_valid = false;
}

int main(void)
{
  const uint64_t merged_line = 0x11223344bbaa7788ull;
  bool request_seen = false;
  bool write_seen = false;
  bool response_seen = false;

  cache_ctrl_partial_write_hit_merge_formal_top.rst_n = false;
  for(unsigned reset_cycle = 0u; reset_cycle < 3u; reset_cycle++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }

  cache_ctrl_partial_write_hit_merge_formal_top.rst_n = true;
  drive_idle();
  set_inputs();

  for(unsigned step = 0u; step < 16u; step++)
  {
    cache_ctrl_partial_write_hit_merge_formal_top.req_valid = !request_seen;
    set_inputs();

    assert(!cache_ctrl_partial_write_hit_merge_formal_top.mem_req_valid);

    if(cache_ctrl_partial_write_hit_merge_formal_top.req_valid &&
       cache_ctrl_partial_write_hit_merge_formal_top.req_ready)
    {
      request_seen = true;
    }

    if(cache_ctrl_partial_write_hit_merge_formal_top.data_wr_en ||
       cache_ctrl_partial_write_hit_merge_formal_top.meta_wr_en ||
       cache_ctrl_partial_write_hit_merge_formal_top.valid_wr_en)
    {
      assert(request_seen);
      assert(!write_seen);
      assert(cache_ctrl_partial_write_hit_merge_formal_top.data_wr_en);
      assert(cache_ctrl_partial_write_hit_merge_formal_top.meta_wr_en);
      assert(cache_ctrl_partial_write_hit_merge_formal_top.valid_wr_en);
      assert(cache_ctrl_partial_write_hit_merge_formal_top.data_wr_way_mask ==
             1u);
      assert(cache_ctrl_partial_write_hit_merge_formal_top.meta_wr_way_mask ==
             1u);
      assert(cache_ctrl_partial_write_hit_merge_formal_top.valid_wr_mask ==
             1u);
      assert(cache_ctrl_partial_write_hit_merge_formal_top.valid_wr_bits ==
             1u);
      assert(cache_ctrl_partial_write_hit_merge_formal_top.data_wr_line0 ==
             merged_line);
      assert(cache_ctrl_partial_write_hit_merge_formal_top.data_wr_line1 ==
             0u);
      assert(cache_ctrl_partial_write_hit_merge_formal_top.meta_wr_way0 ==
             0x90u);
      assert(cache_ctrl_partial_write_hit_merge_formal_top.meta_wr_way1 ==
             0u);
      write_seen = true;
    }

    if(cache_ctrl_partial_write_hit_merge_formal_top.repl_wr_en)
    {
      assert(write_seen);
      assert(cache_ctrl_partial_write_hit_merge_formal_top.repl_wr_way);
    }

    if(cache_ctrl_partial_write_hit_merge_formal_top.resp_valid)
    {
      assert(write_seen);
      response_seen = true;
      assert(cache_ctrl_partial_write_hit_merge_formal_top.resp_id == 0u);
      assert(cache_ctrl_partial_write_hit_merge_formal_top.resp_code == 0u);
    }

    next_timeframe();
  }

  assert(request_seen);
  assert(write_seen);
  assert(response_seen);
}
