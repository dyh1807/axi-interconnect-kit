#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

struct module_axi_llc_subsystem_core_dirty_evict_writeback_formal_top
{
  bool clk;
  bool rst_n;
  bool up_req_valid;
  uint8_t up_req_sel;
  bool up_req_ready;
  bool up_resp_valid;
  uint8_t up_resp_id;
  uint8_t up_resp_code;
  bool cache_req_valid;
  bool cache_req_ready;
  bool cache_req_write;
  uint32_t cache_req_addr;
  uint8_t cache_req_id;
  uint8_t cache_req_size;
  uint64_t cache_req_wdata;
  uint8_t cache_req_wstrb;
  bool cache_resp_valid;
  bool cache_resp_ready;
  uint8_t cache_resp_id;
  bool bypass_req_valid;
  bool config_error;
  uint8_t active_mode;
  uint8_t reconfig_state;
};

extern struct module_axi_llc_subsystem_core_dirty_evict_writeback_formal_top
    axi_llc_subsystem_core_dirty_evict_writeback_formal_top;

static void drive_idle(void)
{
  axi_llc_subsystem_core_dirty_evict_writeback_formal_top.up_req_valid = false;
  axi_llc_subsystem_core_dirty_evict_writeback_formal_top.up_req_sel = 0u;
  axi_llc_subsystem_core_dirty_evict_writeback_formal_top.cache_req_ready =
      false;
  axi_llc_subsystem_core_dirty_evict_writeback_formal_top.cache_resp_valid =
      false;
  axi_llc_subsystem_core_dirty_evict_writeback_formal_top.cache_resp_id = 0u;
}

int main(void)
{
  const uint64_t victim_data = 0x0102030405060708ull;
  uint8_t stage = 0u;
  bool req0_seen = false;
  bool resp0_seen = false;
  bool req1_seen = false;
  bool resp1_seen = false;
  bool req2_seen = false;
  bool resp2_seen = false;
  bool cache_req_seen = false;
  bool cache_req_accepted = false;
  bool cache_resp_accepted = false;
  uint8_t cache_id = 0u;

  axi_llc_subsystem_core_dirty_evict_writeback_formal_top.rst_n = false;
  for(unsigned reset_cycle = 0u; reset_cycle < 3u; reset_cycle++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }

  axi_llc_subsystem_core_dirty_evict_writeback_formal_top.rst_n = true;
  for(unsigned warmup = 0u; warmup < 32u; warmup++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }

  for(unsigned step = 0u; step < 56u; step++)
  {
    const bool issue_current = (stage == 0u) || (stage == 2u) ||
                               (stage == 4u);
    const bool drive_cache_resp = cache_req_accepted && !cache_resp_accepted;
    uint8_t req_sel = 0u;
    if(stage == 2u)
    {
      req_sel = 1u;
    }
    else if(stage == 4u)
    {
      req_sel = 2u;
    }

    axi_llc_subsystem_core_dirty_evict_writeback_formal_top.up_req_valid =
        issue_current;
    axi_llc_subsystem_core_dirty_evict_writeback_formal_top.up_req_sel =
        req_sel;
    axi_llc_subsystem_core_dirty_evict_writeback_formal_top.cache_req_ready =
        req2_seen && !cache_req_accepted;
    axi_llc_subsystem_core_dirty_evict_writeback_formal_top.cache_resp_valid =
        drive_cache_resp;
    axi_llc_subsystem_core_dirty_evict_writeback_formal_top.cache_resp_id =
        cache_id;
    set_inputs();

    const bool cache_resp_fire =
        axi_llc_subsystem_core_dirty_evict_writeback_formal_top
            .cache_resp_valid &&
        axi_llc_subsystem_core_dirty_evict_writeback_formal_top
            .cache_resp_ready;

    assert(!axi_llc_subsystem_core_dirty_evict_writeback_formal_top
                .bypass_req_valid);
    assert(!axi_llc_subsystem_core_dirty_evict_writeback_formal_top
                .config_error);
    assert(axi_llc_subsystem_core_dirty_evict_writeback_formal_top
               .active_mode == 1u);
    assert(axi_llc_subsystem_core_dirty_evict_writeback_formal_top
               .reconfig_state == 0u);

    if(stage < 5u)
    {
      assert(!axi_llc_subsystem_core_dirty_evict_writeback_formal_top
                  .cache_req_valid);
    }

    if(axi_llc_subsystem_core_dirty_evict_writeback_formal_top.up_req_valid &&
       axi_llc_subsystem_core_dirty_evict_writeback_formal_top.up_req_ready)
    {
      if(stage == 0u)
      {
        req0_seen = true;
        stage = 1u;
      }
      else if(stage == 2u)
      {
        req1_seen = true;
        stage = 3u;
      }
      else if(stage == 4u)
      {
        req2_seen = true;
        stage = 5u;
      }
      else
      {
        assert(0);
      }
    }

    if(axi_llc_subsystem_core_dirty_evict_writeback_formal_top.cache_req_valid)
    {
      assert(req2_seen);
      cache_req_seen = true;
      cache_id =
          axi_llc_subsystem_core_dirty_evict_writeback_formal_top.cache_req_id;
      assert(axi_llc_subsystem_core_dirty_evict_writeback_formal_top
                 .cache_req_write);
      assert(axi_llc_subsystem_core_dirty_evict_writeback_formal_top
                 .cache_req_addr == 0x40000100u);
      assert(axi_llc_subsystem_core_dirty_evict_writeback_formal_top
                 .cache_req_size == 7u);
      assert(axi_llc_subsystem_core_dirty_evict_writeback_formal_top
                 .cache_req_wdata == victim_data);
      assert(axi_llc_subsystem_core_dirty_evict_writeback_formal_top
                 .cache_req_wstrb == 0xffu);
    }

    if(axi_llc_subsystem_core_dirty_evict_writeback_formal_top
           .cache_req_valid &&
       axi_llc_subsystem_core_dirty_evict_writeback_formal_top
           .cache_req_ready)
    {
      assert(!cache_req_accepted);
      cache_req_accepted = true;
    }

    if(axi_llc_subsystem_core_dirty_evict_writeback_formal_top
           .cache_resp_valid)
    {
      assert(cache_req_accepted);
      assert(axi_llc_subsystem_core_dirty_evict_writeback_formal_top
                 .cache_resp_ready);
    }

    if(cache_resp_fire)
    {
      assert(!cache_resp_accepted);
      cache_resp_accepted = true;
    }

    if(axi_llc_subsystem_core_dirty_evict_writeback_formal_top.up_resp_valid)
    {
      assert(axi_llc_subsystem_core_dirty_evict_writeback_formal_top
                 .up_resp_code == 0u);
      if(stage == 1u)
      {
        resp0_seen = true;
        assert(axi_llc_subsystem_core_dirty_evict_writeback_formal_top
                   .up_resp_id == 0u);
        stage = 2u;
      }
      else if(stage == 3u)
      {
        resp1_seen = true;
        assert(axi_llc_subsystem_core_dirty_evict_writeback_formal_top
                   .up_resp_id == 1u);
        stage = 4u;
      }
      else if(stage == 5u)
      {
        assert(cache_resp_accepted || cache_resp_fire);
        resp2_seen = true;
        assert(axi_llc_subsystem_core_dirty_evict_writeback_formal_top
                   .up_resp_id == 0u);
        stage = 6u;
      }
      else
      {
        assert(0);
      }
    }

    next_timeframe();
  }

  assert(req0_seen);
  assert(resp0_seen);
  assert(req1_seen);
  assert(resp1_seen);
  assert(req2_seen);
  assert(cache_req_seen);
  assert(cache_req_accepted);
  assert(cache_resp_accepted);
  assert(resp2_seen);
  assert(stage == 6u);
}
