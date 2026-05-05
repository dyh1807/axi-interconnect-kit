#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

struct module_axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
{
  bool clk;
  bool rst_n;
  bool write_req_valid;
  uint8_t write_req_sel;
  bool write_req_ready;
  bool write_req_accepted;
  bool write_resp_valid;
  uint8_t write_resp_id;
  uint8_t write_resp_code;
  bool ddr_axi_arvalid;
  bool ddr_axi_awvalid;
  bool ddr_axi_awready;
  bool ddr_axi_awid;
  uint32_t ddr_axi_awaddr;
  uint8_t ddr_axi_awlen;
  uint8_t ddr_axi_awsize;
  uint8_t ddr_axi_awburst;
  bool ddr_axi_wvalid;
  bool ddr_axi_wready;
  uint64_t ddr_axi_wdata;
  uint8_t ddr_axi_wstrb;
  bool ddr_axi_wlast;
  bool ddr_axi_bvalid;
  bool ddr_axi_bready;
  bool ddr_axi_bid;
  bool mmio_axi_arvalid;
  bool mmio_axi_awvalid;
  bool mmio_axi_wvalid;
  bool config_error;
};

extern struct
    module_axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
        axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top;

static void drive_idle(void)
{
  axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
      .write_req_valid = false;
  axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top.write_req_sel =
      0u;
  axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
      .ddr_axi_awready = false;
  axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
      .ddr_axi_wready = false;
  axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
      .ddr_axi_bvalid = false;
  axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top.ddr_axi_bid =
      false;
}

int main(void)
{
  const uint64_t victim_data = 0x0102030405060708ull;
  unsigned phase = 0u;
  bool request_seen[3] = {false, false, false};
  bool accepted_seen[3] = {false, false, false};
  bool response_seen[3] = {false, false, false};
  bool seen_aw = false;
  bool aw_accepted = false;
  bool awid = false;
  bool seen_w = false;
  bool w_accepted = false;
  bool b_accepted = false;

  axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top.rst_n = false;
  for(unsigned reset_cycle = 0u; reset_cycle < 3u; reset_cycle++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }

  axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top.rst_n = true;
  for(unsigned warmup = 0u; warmup < 12u; warmup++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }
  drive_idle();
  set_inputs();

  for(unsigned step = 0u; step < 40u; step++)
  {
    const bool issue_current = (phase < 3u) && !request_seen[phase];
    const bool b_should_drive = aw_accepted && w_accepted && !b_accepted;

    axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
        .write_req_valid = issue_current;
    axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
        .write_req_sel = (uint8_t)phase;
    axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
        .ddr_axi_awready = request_seen[2] && !aw_accepted;
    axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
        .ddr_axi_wready = request_seen[2] && !w_accepted;
    axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
        .ddr_axi_bvalid = b_should_drive;
    axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
        .ddr_axi_bid = awid;
    set_inputs();

    assert(!axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
                .ddr_axi_arvalid);
    assert(!axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
                .mmio_axi_arvalid);
    assert(!axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
                .mmio_axi_awvalid);
    assert(!axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
                .mmio_axi_wvalid);
    assert(!axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
                .config_error);

    if(phase < 2u)
    {
      assert(!axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
                  .ddr_axi_awvalid);
      assert(!axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
                  .ddr_axi_wvalid);
    }

    if(axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
           .write_req_valid &&
       axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
           .write_req_ready)
    {
      assert(phase < 3u);
      request_seen[phase] = true;
    }

    if(axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
           .write_req_accepted)
    {
      assert(phase < 3u);
      accepted_seen[phase] = true;
    }

    if(axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
           .ddr_axi_awvalid)
    {
      assert(request_seen[2]);
      seen_aw = true;
      awid =
          axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
              .ddr_axi_awid;
      assert(axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
                 .ddr_axi_awaddr == 0x40000100u);
      assert(axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
                 .ddr_axi_awlen == 0u);
      assert(axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
                 .ddr_axi_awsize == 3u);
      assert(axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
                 .ddr_axi_awburst == 1u);
    }

    if(axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
           .ddr_axi_awvalid &&
       axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
           .ddr_axi_awready)
    {
      assert(!aw_accepted);
      aw_accepted = true;
    }

    if(axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
           .ddr_axi_wvalid)
    {
      assert(request_seen[2]);
      seen_w = true;
      assert(axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
                 .ddr_axi_wdata == victim_data);
      assert(axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
                 .ddr_axi_wstrb == 0xffu);
      assert(axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
                 .ddr_axi_wlast);
    }

    if(axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
           .ddr_axi_wvalid &&
       axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
           .ddr_axi_wready)
    {
      assert(!w_accepted);
      w_accepted = true;
    }

    if(axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
           .ddr_axi_bvalid)
    {
      assert(aw_accepted);
      assert(w_accepted);
      assert(axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
                 .ddr_axi_bready);
    }

    if(axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
           .ddr_axi_bvalid &&
       axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
           .ddr_axi_bready)
    {
      assert(!b_accepted);
      b_accepted = true;
    }

    if(axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
           .write_resp_valid)
    {
      assert(phase < 3u);
      response_seen[phase] = true;
      assert(axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
                 .write_resp_id == (uint8_t)(phase + 1u));
      assert(axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
                 .write_resp_code == 0u);
      if(phase == 2u)
      {
        assert(b_accepted ||
               (axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
                    .ddr_axi_bvalid &&
                axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top
                    .ddr_axi_bready));
      }
      phase++;
    }

    next_timeframe();
  }

  assert(request_seen[0]);
  assert(accepted_seen[0]);
  assert(response_seen[0]);
  assert(request_seen[1]);
  assert(accepted_seen[1]);
  assert(response_seen[1]);
  assert(request_seen[2]);
  assert(accepted_seen[2]);
  assert(seen_aw);
  assert(aw_accepted);
  assert(seen_w);
  assert(w_accepted);
  assert(b_accepted);
  assert(response_seen[2]);
}
