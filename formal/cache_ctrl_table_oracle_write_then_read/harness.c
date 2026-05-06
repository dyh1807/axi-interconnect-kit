#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

struct module_cache_ctrl_table_oracle_write_then_read_formal_top
{
  bool clk;
  bool rst_n;
  bool req_valid;
  bool req_write;
  bool req_ready;
  bool resp_valid;
  uint64_t resp_rdata;
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

extern struct module_cache_ctrl_table_oracle_write_then_read_formal_top
    cache_ctrl_table_oracle_write_then_read_formal_top;

static void drive_idle(void)
{
  cache_ctrl_table_oracle_write_then_read_formal_top.req_valid = false;
  cache_ctrl_table_oracle_write_then_read_formal_top.req_write = false;
}

int main(void)
{
  const uint64_t merged_line = 0x11223344bbaa7788ull;
  bool write_request_seen = false;
  bool write_seen = false;
  bool write_response_seen = false;
  bool read_request_seen = false;
  bool read_response_seen = false;

  cache_ctrl_table_oracle_write_then_read_formal_top.rst_n = false;
  for(unsigned reset_cycle = 0u; reset_cycle < 3u; reset_cycle++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }

  cache_ctrl_table_oracle_write_then_read_formal_top.rst_n = true;
  drive_idle();
  set_inputs();

  for(unsigned step = 0u; step < 32u; step++)
  {
    if(!write_response_seen)
    {
      cache_ctrl_table_oracle_write_then_read_formal_top.req_valid =
          !write_request_seen;
      cache_ctrl_table_oracle_write_then_read_formal_top.req_write = true;
    }
    else
    {
      cache_ctrl_table_oracle_write_then_read_formal_top.req_valid =
          !read_request_seen;
      cache_ctrl_table_oracle_write_then_read_formal_top.req_write = false;
    }
    set_inputs();

    assert(!cache_ctrl_table_oracle_write_then_read_formal_top.mem_req_valid);

    if(cache_ctrl_table_oracle_write_then_read_formal_top.req_valid &&
       cache_ctrl_table_oracle_write_then_read_formal_top.req_ready)
    {
      if(!write_response_seen)
      {
        write_request_seen = true;
      }
      else
      {
        read_request_seen = true;
      }
    }

    if(cache_ctrl_table_oracle_write_then_read_formal_top.data_wr_en ||
       cache_ctrl_table_oracle_write_then_read_formal_top.meta_wr_en ||
       cache_ctrl_table_oracle_write_then_read_formal_top.valid_wr_en)
    {
      assert(write_request_seen);
      assert(!write_seen);
      assert(!write_response_seen);
      assert(cache_ctrl_table_oracle_write_then_read_formal_top.data_wr_en);
      assert(cache_ctrl_table_oracle_write_then_read_formal_top.meta_wr_en);
      assert(cache_ctrl_table_oracle_write_then_read_formal_top.valid_wr_en);
      assert(cache_ctrl_table_oracle_write_then_read_formal_top.data_wr_way_mask ==
             1u);
      assert(cache_ctrl_table_oracle_write_then_read_formal_top.meta_wr_way_mask ==
             1u);
      assert(cache_ctrl_table_oracle_write_then_read_formal_top.valid_wr_mask ==
             1u);
      assert(cache_ctrl_table_oracle_write_then_read_formal_top.valid_wr_bits ==
             1u);
      assert(cache_ctrl_table_oracle_write_then_read_formal_top.data_wr_line0 ==
             merged_line);
      assert(cache_ctrl_table_oracle_write_then_read_formal_top.data_wr_line1 ==
             0u);
      assert(cache_ctrl_table_oracle_write_then_read_formal_top.meta_wr_way0 ==
             0x90u);
      assert(cache_ctrl_table_oracle_write_then_read_formal_top.meta_wr_way1 ==
             0u);
      write_seen = true;
    }

    if(cache_ctrl_table_oracle_write_then_read_formal_top.repl_wr_en)
    {
      assert(write_seen);
      assert(cache_ctrl_table_oracle_write_then_read_formal_top.repl_wr_way);
    }

    if(cache_ctrl_table_oracle_write_then_read_formal_top.resp_valid)
    {
      assert(cache_ctrl_table_oracle_write_then_read_formal_top.resp_id == 0u);
      assert(cache_ctrl_table_oracle_write_then_read_formal_top.resp_code == 0u);
      if(!write_response_seen)
      {
        assert(write_seen);
        assert(cache_ctrl_table_oracle_write_then_read_formal_top.resp_rdata ==
               0u);
        write_response_seen = true;
      }
      else
      {
        assert(read_request_seen);
        assert(cache_ctrl_table_oracle_write_then_read_formal_top.resp_rdata ==
               merged_line);
        read_response_seen = true;
      }
    }

    next_timeframe();
  }

  assert(write_request_seen);
  assert(write_seen);
  assert(write_response_seen);
  assert(read_request_seen);
  assert(read_response_seen);
}
