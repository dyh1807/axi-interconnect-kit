#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

struct module_axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
{
  bool clk;
  bool rst_n;
  bool write_req_valid;
  bool write_req_ready;
  bool write_req_accepted;
  bool write_resp_valid;
  uint8_t write_resp_id;
  uint8_t write_resp_code;
  bool read_req_valid;
  bool read_req_ready;
  bool read_req_accepted;
  bool read_resp_valid;
  uint64_t read_resp_data;
  uint8_t read_resp_id;
  bool ddr_axi_arvalid;
  bool ddr_axi_awvalid;
  bool ddr_axi_wvalid;
  bool mmio_axi_arvalid;
  bool mmio_axi_awvalid;
  bool mmio_axi_wvalid;
  bool config_error;
};

extern struct
    module_axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
        axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top;

static void drive_idle(void)
{
  axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
      .write_req_valid = false;
  axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
      .read_req_valid = false;
}

int main(void)
{
  const uint64_t write_data = 0x1122334455667788ull;
  bool write_request_seen = false;
  bool write_accepted_seen = false;
  bool write_resp_seen = false;
  bool read_request_seen = false;
  bool read_accepted_seen = false;
  bool read_resp_seen = false;

  axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top.rst_n =
      false;
  for(unsigned reset_cycle = 0u; reset_cycle < 3u; reset_cycle++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }

  axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top.rst_n = true;
  for(unsigned warmup = 0u; warmup < 12u; warmup++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }
  drive_idle();
  set_inputs();

  for(unsigned step = 0u; step < 28u; step++)
  {
    axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
        .write_req_valid = !write_request_seen;
    axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
        .read_req_valid = write_resp_seen && !read_request_seen;
    set_inputs();

    assert(!axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
                .ddr_axi_arvalid);
    assert(!axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
                .ddr_axi_awvalid);
    assert(!axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
                .ddr_axi_wvalid);
    assert(!axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
                .mmio_axi_arvalid);
    assert(!axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
                .mmio_axi_awvalid);
    assert(!axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
                .mmio_axi_wvalid);
    assert(!axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
                .config_error);

    if(axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
           .write_req_valid &&
       axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
           .write_req_ready)
    {
      write_request_seen = true;
    }

    if(axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
           .write_req_accepted)
    {
      write_accepted_seen = true;
    }

    if(axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
           .write_resp_valid)
    {
      write_resp_seen = true;
      assert(axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
                 .write_resp_id == 6u);
      assert(axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
                 .write_resp_code == 0u);
    }

    if(axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
           .read_req_valid &&
       axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
           .read_req_ready)
    {
      read_request_seen = true;
    }

    if(axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
           .read_req_accepted)
    {
      read_accepted_seen = true;
    }

    if(axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
           .read_resp_valid)
    {
      read_resp_seen = true;
      assert(axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
                 .read_resp_id == 7u);
      assert(axi_llc_subsystem_dual_cache_full_write_hit_response_formal_top
                 .read_resp_data == write_data);
    }

    next_timeframe();
  }

  assert(write_request_seen);
  assert(write_accepted_seen);
  assert(write_resp_seen);
  assert(read_request_seen);
  assert(read_accepted_seen);
  assert(read_resp_seen);
}
