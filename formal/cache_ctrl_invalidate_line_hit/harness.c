#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

typedef unsigned __CPROVER_bitvector[2] u2;

struct module_cache_ctrl_invalidate_line_hit_formal_top
{
  bool clk;
  bool rst_n;
  bool invalidate_valid;
  bool invalidate_accepted;
  bool valid_wr_en;
  u2 valid_wr_mask;
  u2 valid_wr_bits;
  bool data_wr_en;
  bool meta_wr_en;
  bool repl_wr_en;
  bool mem_req_valid;
  bool bypass_req_valid;
  bool resp_valid;
};

extern struct module_cache_ctrl_invalidate_line_hit_formal_top
    cache_ctrl_invalidate_line_hit_formal_top;

static void drive_idle(void)
{
  cache_ctrl_invalidate_line_hit_formal_top.invalidate_valid = false;
}

int main(void)
{
  bool accepted_seen = false;
  bool clear_seen = false;

  cache_ctrl_invalidate_line_hit_formal_top.rst_n = false;
  for(unsigned reset_cycle = 0u; reset_cycle < 3u; reset_cycle++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }

  cache_ctrl_invalidate_line_hit_formal_top.rst_n = true;
  drive_idle();
  set_inputs();
  next_timeframe();

  for(unsigned step = 0u; step < 12u; step++)
  {
    cache_ctrl_invalidate_line_hit_formal_top.invalidate_valid =
        !accepted_seen;
    set_inputs();

    if(cache_ctrl_invalidate_line_hit_formal_top.invalidate_accepted)
    {
      accepted_seen = true;
    }

    if(cache_ctrl_invalidate_line_hit_formal_top.valid_wr_en &&
       cache_ctrl_invalidate_line_hit_formal_top.valid_wr_mask == 2u &&
       cache_ctrl_invalidate_line_hit_formal_top.valid_wr_bits == 0u)
    {
      assert(accepted_seen);
      clear_seen = true;
    }

    next_timeframe();
  }

  assert(accepted_seen);
  assert(clear_seen);
}
