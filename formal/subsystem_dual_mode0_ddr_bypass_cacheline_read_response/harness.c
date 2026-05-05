#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

uint32_t nondet_uint32_t(void);
uint8_t nondet_uint8_t(void);

struct module_axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
{
  bool clk;
  bool rst_n;
  bool read_req_valid;
  uint32_t read_req_addr;
  uint8_t read_req_id;
  bool read_req_ready;
  bool read_req_accepted;
  uint8_t read_req_accepted_id;
  bool read_resp_valid;
  uint64_t read_resp_data_0;
  uint64_t read_resp_data_1;
  uint64_t read_resp_data_2;
  uint64_t read_resp_data_3;
  uint64_t read_resp_data_4;
  uint64_t read_resp_data_5;
  uint64_t read_resp_data_6;
  uint64_t read_resp_data_7;
  uint8_t read_resp_id;
  bool ddr_axi_arvalid;
  uint32_t ddr_axi_araddr;
  uint8_t ddr_axi_arlen;
  uint8_t ddr_axi_arsize;
  uint8_t ddr_axi_arburst;
  bool ddr_axi_rvalid;
  bool ddr_axi_rready;
  uint64_t ddr_axi_rdata_0;
  uint64_t ddr_axi_rdata_1;
  uint64_t ddr_axi_rdata_2;
  uint64_t ddr_axi_rdata_3;
  uint8_t ddr_axi_rresp;
  bool ddr_axi_rlast;
  bool ddr_axi_awvalid;
  bool ddr_axi_wvalid;
  bool mmio_axi_arvalid;
  bool mmio_axi_awvalid;
  bool mmio_axi_wvalid;
  bool config_error;
};

extern struct
    module_axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
        axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top;

static void drive_idle(void)
{
  axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
      .read_req_valid = false;
  axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
      .read_req_addr = 0u;
  axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
      .read_req_id = 0u;
  axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
      .ddr_axi_rvalid = false;
  axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
      .ddr_axi_rdata_0 = 0u;
  axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
      .ddr_axi_rdata_1 = 0u;
  axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
      .ddr_axi_rdata_2 = 0u;
  axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
      .ddr_axi_rdata_3 = 0u;
  axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
      .ddr_axi_rresp = 0u;
  axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
      .ddr_axi_rlast = false;
}

static void assert_no_wrong_port(void)
{
  assert(!axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
              .ddr_axi_awvalid);
  assert(!axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
              .ddr_axi_wvalid);
  assert(!axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
              .mmio_axi_arvalid);
  assert(!axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
              .mmio_axi_awvalid);
  assert(!axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
              .mmio_axi_wvalid);
  assert(!axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
              .config_error);
}

int main(void)
{
  const uint32_t addr = 0x40000000u + (nondet_uint32_t() & 0x0000ffc0u);
  const uint8_t req_id = nondet_uint8_t() & 0x0fu;
  const uint64_t beat0_0 = 0xa5a55a5adeadbeefull;
  const uint64_t beat0_1 = 0x1122334455667788ull;
  const uint64_t beat0_2 = 0x8877665544332211ull;
  const uint64_t beat0_3 = 0x0f1e2d3c4b5a6978ull;
  const uint64_t beat1_0 = 0x89abcdef01234567ull;
  const uint64_t beat1_1 = 0x0123456789abcdefull;
  const uint64_t beat1_2 = 0xffeeddccbbaa9988ull;
  const uint64_t beat1_3 = 0x7766554433221100ull;
  bool request_seen = false;
  bool accepted_seen = false;
  bool seen_ar = false;
  bool first_r_accepted = false;
  bool second_r_accepted = false;
  bool seen_resp = false;

  axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
      .rst_n = false;
  for(unsigned reset_cycle = 0u; reset_cycle < 3u; reset_cycle++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }

  axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
      .rst_n = true;
  for(unsigned warmup = 0u; warmup < 12u; warmup++)
  {
    drive_idle();
    set_inputs();
    next_timeframe();
  }

  for(unsigned step = 0u; step < 36u; step++)
  {
    drive_idle();
    axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
        .read_req_valid = !request_seen;
    axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
        .read_req_addr = addr;
    axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
        .read_req_id = req_id;
    if(seen_ar && !first_r_accepted)
    {
      axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
          .ddr_axi_rvalid = true;
      axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
          .ddr_axi_rdata_0 = beat0_0;
      axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
          .ddr_axi_rdata_1 = beat0_1;
      axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
          .ddr_axi_rdata_2 = beat0_2;
      axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
          .ddr_axi_rdata_3 = beat0_3;
      axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
          .ddr_axi_rlast = false;
    }
    else if(first_r_accepted && !second_r_accepted)
    {
      axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
          .ddr_axi_rvalid = true;
      axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
          .ddr_axi_rdata_0 = beat1_0;
      axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
          .ddr_axi_rdata_1 = beat1_1;
      axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
          .ddr_axi_rdata_2 = beat1_2;
      axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
          .ddr_axi_rdata_3 = beat1_3;
      axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
          .ddr_axi_rlast = true;
    }
    set_inputs();

    assert_no_wrong_port();

    if(axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
           .read_req_valid &&
       axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
           .read_req_ready)
    {
      request_seen = true;
    }
    if(axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
           .read_req_accepted)
    {
      accepted_seen = true;
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
                 .read_req_accepted_id == req_id);
    }
    if(axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
           .ddr_axi_arvalid)
    {
      seen_ar = true;
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
                 .ddr_axi_araddr == addr);
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
                 .ddr_axi_arlen == 1u);
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
                 .ddr_axi_arsize == 5u);
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
                 .ddr_axi_arburst == 1u);
    }
    if(axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
           .ddr_axi_rvalid &&
       axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
           .ddr_axi_rready)
    {
      if(!first_r_accepted)
      {
        first_r_accepted = true;
      }
      else
      {
        second_r_accepted = true;
      }
    }
    if(first_r_accepted && !second_r_accepted)
    {
      assert(!axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
                  .read_resp_valid);
    }
    if(axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
           .read_resp_valid)
    {
      seen_resp = true;
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
                 .read_resp_id == req_id);
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
                 .read_resp_data_0 == beat0_0);
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
                 .read_resp_data_1 == beat0_1);
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
                 .read_resp_data_2 == beat0_2);
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
                 .read_resp_data_3 == beat0_3);
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
                 .read_resp_data_4 == beat1_0);
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
                 .read_resp_data_5 == beat1_1);
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
                 .read_resp_data_6 == beat1_2);
      assert(axi_llc_subsystem_dual_mode0_ddr_bypass_cacheline_read_response_formal_top
                 .read_resp_data_7 == beat1_3);
    }
    next_timeframe();
  }

  assert(request_seen);
  assert(accepted_seen);
  assert(seen_ar);
  assert(first_r_accepted);
  assert(second_r_accepted);
  assert(seen_resp);
}
