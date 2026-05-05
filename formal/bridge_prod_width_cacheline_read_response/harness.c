#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

void next_timeframe(void);
void set_inputs(void);

uint32_t nondet_uint32_t(void);
uint8_t nondet_uint8_t(void);

struct module_axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
{
  bool clk;
  bool rst_n;
  bool cache_req_valid;
  uint32_t cache_req_addr;
  uint8_t cache_req_id;
  bool cache_req_ready;
  bool cache_resp_valid;
  uint64_t cache_resp_rdata_0;
  uint64_t cache_resp_rdata_1;
  uint64_t cache_resp_rdata_2;
  uint64_t cache_resp_rdata_3;
  uint64_t cache_resp_rdata_4;
  uint64_t cache_resp_rdata_5;
  uint64_t cache_resp_rdata_6;
  uint64_t cache_resp_rdata_7;
  uint8_t cache_resp_id;
  uint8_t cache_resp_code;
  bool axi_arvalid;
  bool axi_arid;
  uint32_t axi_araddr;
  uint8_t axi_arlen;
  uint8_t axi_arsize;
  uint8_t axi_arburst;
  bool axi_rvalid;
  bool axi_rready;
  bool axi_rid;
  uint64_t axi_rdata_0;
  uint64_t axi_rdata_1;
  uint64_t axi_rdata_2;
  uint64_t axi_rdata_3;
  uint8_t axi_rresp;
  bool axi_rlast;
  bool axi_awvalid;
  bool axi_wvalid;
};

extern struct
    module_axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
        axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top;

static void drive_idle(void)
{
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .cache_req_valid = false;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .cache_req_addr = 0u;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .cache_req_id = 0u;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .axi_rvalid = false;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top.axi_rid =
      false;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .axi_rdata_0 = 0u;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .axi_rdata_1 = 0u;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .axi_rdata_2 = 0u;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .axi_rdata_3 = 0u;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .axi_rresp = 0u;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .axi_rlast = false;
}

static void check_ar_snapshot(bool arvalid, uint32_t araddr, uint8_t arlen,
                              uint8_t arsize, uint8_t arburst, uint32_t addr)
{
  if(arvalid)
  {
    assert(araddr == addr);
    assert(arlen == 1u);
    assert(arsize == 5u);
    assert(arburst == 1u);
  }
}

int main(void)
{
  const uint32_t addr = 0x40000000u + (nondet_uint32_t() & 0x0000ffc0u);
  const uint8_t req_id = nondet_uint8_t() & 0x3fu;
  const uint64_t beat0_0 = 0xa5a55a5adeadbeefull;
  const uint64_t beat0_1 = 0x1122334455667788ull;
  const uint64_t beat0_2 = 0x8877665544332211ull;
  const uint64_t beat0_3 = 0x0f1e2d3c4b5a6978ull;
  const uint64_t beat1_0 = 0x89abcdef01234567ull;
  const uint64_t beat1_1 = 0x0123456789abcdefull;
  const uint64_t beat1_2 = 0xffeeddccbbaa9988ull;
  const uint64_t beat1_3 = 0x7766554433221100ull;
  bool seen_ar = false;
  bool arid = false;

  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top.rst_n =
      false;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top.rst_n =
      true;
  drive_idle();
  set_inputs();
  next_timeframe();

  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .cache_req_valid = true;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .cache_req_addr = addr;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .cache_req_id = req_id;
  set_inputs();

  assert(axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
             .cache_req_ready);

  for(unsigned step = 0u; step < 4u; step++)
  {
    next_timeframe();
    drive_idle();
    set_inputs();

    const bool arvalid =
        axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
            .axi_arvalid;
    check_ar_snapshot(
        arvalid,
        axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
            .axi_araddr,
        axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
            .axi_arlen,
        axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
            .axi_arsize,
        axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
            .axi_arburst,
        addr);

    if(arvalid)
    {
      seen_ar = true;
      arid =
          axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
              .axi_arid;
    }
  }

  assert(seen_ar);
  assert(!axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
              .axi_awvalid);
  assert(!axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
              .axi_wvalid);

  drive_idle();
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .axi_rvalid = true;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top.axi_rid =
      arid;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .axi_rdata_0 = beat0_0;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .axi_rdata_1 = beat0_1;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .axi_rdata_2 = beat0_2;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .axi_rdata_3 = beat0_3;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .axi_rresp = 0u;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .axi_rlast = false;
  set_inputs();

  assert(axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
             .axi_rready);

  next_timeframe();
  drive_idle();
  set_inputs();
  assert(!axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
              .cache_resp_valid);

  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .axi_rvalid = true;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top.axi_rid =
      arid;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .axi_rdata_0 = beat1_0;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .axi_rdata_1 = beat1_1;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .axi_rdata_2 = beat1_2;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .axi_rdata_3 = beat1_3;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .axi_rresp = 0u;
  axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
      .axi_rlast = true;
  set_inputs();

  assert(axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
             .axi_rready);

  next_timeframe();
  drive_idle();
  set_inputs();

  assert(axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
             .cache_resp_valid);
  assert(axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
             .cache_resp_id == req_id);
  assert(axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
             .cache_resp_code == 0u);
  assert(axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
             .cache_resp_rdata_0 == beat0_0);
  assert(axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
             .cache_resp_rdata_1 == beat0_1);
  assert(axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
             .cache_resp_rdata_2 == beat0_2);
  assert(axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
             .cache_resp_rdata_3 == beat0_3);
  assert(axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
             .cache_resp_rdata_4 == beat1_0);
  assert(axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
             .cache_resp_rdata_5 == beat1_1);
  assert(axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
             .cache_resp_rdata_6 == beat1_2);
  assert(axi_llc_axi_bridge_prod_width_cacheline_read_response_formal_top
             .cache_resp_rdata_7 == beat1_3);
}
