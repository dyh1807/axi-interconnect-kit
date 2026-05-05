#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

struct module_cache_ctrl_dirty_evict_writeback_formal_top
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
  bool meta_wr_en;
  uint8_t meta_wr_way_mask;
  bool valid_wr_en;
  uint8_t valid_wr_mask;
  uint8_t valid_wr_bits;
  bool repl_wr_en;
  bool repl_wr_way;
  bool mem_req_valid;
  bool mem_req_ready;
  bool mem_req_write;
  uint32_t mem_req_addr;
  uint8_t mem_req_id;
  uint64_t mem_req_wdata;
  uint8_t mem_req_wstrb;
  uint8_t mem_req_size;
  bool mem_resp_valid;
  bool mem_resp_ready;
  uint8_t mem_resp_id;
};

extern struct module_cache_ctrl_dirty_evict_writeback_formal_top
    cache_ctrl_dirty_evict_writeback_formal_top;

static void drive_idle(void)
{
  cache_ctrl_dirty_evict_writeback_formal_top.req_valid = false;
  cache_ctrl_dirty_evict_writeback_formal_top.mem_req_ready = false;
  cache_ctrl_dirty_evict_writeback_formal_top.mem_resp_valid = false;
  cache_ctrl_dirty_evict_writeback_formal_top.mem_resp_id = 0u;
}

int main(void)
{
  const uint64_t victim_data = 0x0102030405060708ull;
  bool request_seen = false;
  bool mem_req_seen = false;
  bool mem_req_accepted = false;
  bool mem_resp_accepted = false;
  bool install_seen = false;
  bool response_seen = false;
  uint8_t mem_id = 0u;

  cache_ctrl_dirty_evict_writeback_formal_top.rst_n = false;
  for(unsigned reset_cycle = 0u; reset_cycle < 3u; reset_cycle++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }

  cache_ctrl_dirty_evict_writeback_formal_top.rst_n = true;
  drive_idle();
  set_inputs();

  for(unsigned step = 0u; step < 32u; step++)
  {
    cache_ctrl_dirty_evict_writeback_formal_top.req_valid = !request_seen;
    cache_ctrl_dirty_evict_writeback_formal_top.mem_req_ready =
        mem_req_seen && !mem_req_accepted;
    cache_ctrl_dirty_evict_writeback_formal_top.mem_resp_valid =
        mem_req_accepted && !mem_resp_accepted;
    cache_ctrl_dirty_evict_writeback_formal_top.mem_resp_id = mem_id;
    set_inputs();

    const bool mem_resp_fire =
        cache_ctrl_dirty_evict_writeback_formal_top.mem_resp_valid &&
        cache_ctrl_dirty_evict_writeback_formal_top.mem_resp_ready;

    if(cache_ctrl_dirty_evict_writeback_formal_top.req_valid &&
       cache_ctrl_dirty_evict_writeback_formal_top.req_ready)
    {
      request_seen = true;
    }

    if(cache_ctrl_dirty_evict_writeback_formal_top.mem_req_valid)
    {
      mem_req_seen = true;
      mem_id = cache_ctrl_dirty_evict_writeback_formal_top.mem_req_id;
      assert(cache_ctrl_dirty_evict_writeback_formal_top.mem_req_write);
      assert(cache_ctrl_dirty_evict_writeback_formal_top.mem_req_addr ==
             0x40000100u);
      assert(cache_ctrl_dirty_evict_writeback_formal_top.mem_req_id == 0u);
      assert(cache_ctrl_dirty_evict_writeback_formal_top.mem_req_wdata ==
             victim_data);
      assert(cache_ctrl_dirty_evict_writeback_formal_top.mem_req_wstrb ==
             0xffu);
      assert(cache_ctrl_dirty_evict_writeback_formal_top.mem_req_size == 7u);
    }

    if(cache_ctrl_dirty_evict_writeback_formal_top.mem_req_valid &&
       cache_ctrl_dirty_evict_writeback_formal_top.mem_req_ready)
    {
      assert(!mem_req_accepted);
      mem_req_accepted = true;
    }

    if(cache_ctrl_dirty_evict_writeback_formal_top.mem_resp_valid)
    {
      assert(mem_req_accepted);
      assert(cache_ctrl_dirty_evict_writeback_formal_top.mem_resp_ready);
    }

    if(mem_resp_fire)
    {
      assert(!mem_resp_accepted);
      mem_resp_accepted = true;
    }

    if(cache_ctrl_dirty_evict_writeback_formal_top.data_wr_en ||
       cache_ctrl_dirty_evict_writeback_formal_top.meta_wr_en ||
       cache_ctrl_dirty_evict_writeback_formal_top.valid_wr_en)
    {
      assert(mem_resp_accepted || mem_resp_fire);
      assert(cache_ctrl_dirty_evict_writeback_formal_top.data_wr_en);
      assert(cache_ctrl_dirty_evict_writeback_formal_top.meta_wr_en);
      assert(cache_ctrl_dirty_evict_writeback_formal_top.valid_wr_en);
      assert(cache_ctrl_dirty_evict_writeback_formal_top.data_wr_way_mask ==
             1u);
      assert(cache_ctrl_dirty_evict_writeback_formal_top.meta_wr_way_mask ==
             1u);
      assert(cache_ctrl_dirty_evict_writeback_formal_top.valid_wr_mask == 1u);
      assert(cache_ctrl_dirty_evict_writeback_formal_top.valid_wr_bits == 1u);
      install_seen = true;
    }

    if(cache_ctrl_dirty_evict_writeback_formal_top.repl_wr_en)
    {
      assert(install_seen);
      assert(cache_ctrl_dirty_evict_writeback_formal_top.repl_wr_way);
    }

    if(cache_ctrl_dirty_evict_writeback_formal_top.resp_valid)
    {
      assert(mem_resp_accepted || mem_resp_fire);
      assert(install_seen);
      response_seen = true;
      assert(cache_ctrl_dirty_evict_writeback_formal_top.resp_id == 0u);
      assert(cache_ctrl_dirty_evict_writeback_formal_top.resp_code == 0u);
    }

    next_timeframe();
  }

  assert(request_seen);
  assert(mem_req_seen);
  assert(mem_req_accepted);
  assert(mem_resp_accepted);
  assert(install_seen);
  assert(response_seen);
}
