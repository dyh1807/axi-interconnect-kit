#pragma once

#include "AXI_Interconnect_IO.h"
#include "AXI_LLC_Config.h"
#include <cstdint>
#include <vector>

namespace axi_interconnect {

struct AXI_LLC_Bytes_t {
  std::vector<uint8_t> bytes{};

  void clear() { bytes.clear(); }
};

struct AXI_LLC_ReadReqIn_t {
  wire1_t valid = false;
  wire32_t addr = 0;
  wire8_t total_size = 0;
  wire4_t id = 0;
  wire1_t bypass = false;
};

struct AXI_LLC_ReadReqOut_t {
  wire1_t ready = false;
};

struct AXI_LLC_ReadRespIn_t {
  wire1_t ready = false;
};

struct AXI_LLC_ReadRespOut_t {
  wire1_t valid = false;
  WideReadData_t data{};
  wire4_t id = 0;
};

struct AXI_LLC_WriteReqIn_t {
  wire1_t valid = false;
  wire32_t addr = 0;
  WideData256_t wdata{};
  wire32_t wstrb = 0;
  wire5_t total_size = 0;
  wire4_t id = 0;
  wire1_t bypass = false;
};

struct AXI_LLC_WriteReqOut_t {
  wire1_t ready = false;
};

struct AXI_LLC_WriteRespIn_t {
  wire1_t ready = false;
};

struct AXI_LLC_WriteRespOut_t {
  wire1_t valid = false;
  wire4_t id = 0;
  wire2_t resp = 0;
};

struct AXI_LLC_UpstreamIn_t {
  AXI_LLC_ReadReqIn_t read_req[NUM_READ_MASTERS];
  AXI_LLC_ReadRespIn_t read_resp[NUM_READ_MASTERS];
  AXI_LLC_WriteReqIn_t write_req[NUM_WRITE_MASTERS];
  AXI_LLC_WriteRespIn_t write_resp[NUM_WRITE_MASTERS];
};

struct AXI_LLC_UpstreamOut_t {
  AXI_LLC_ReadReqOut_t read_req[NUM_READ_MASTERS];
  AXI_LLC_ReadRespOut_t read_resp[NUM_READ_MASTERS];
  AXI_LLC_WriteReqOut_t write_req[NUM_WRITE_MASTERS];
  AXI_LLC_WriteRespOut_t write_resp[NUM_WRITE_MASTERS];
};

struct AXI_LLC_MemIn_t {
  wire1_t read_req_ready = false;
  wire1_t read_resp_valid = false;
  WideReadData_t read_resp_data{};
  wire4_t read_resp_id = 0;
  wire1_t write_req_ready = false;
  wire1_t write_resp_valid = false;
  wire4_t write_resp_id = 0;
  wire2_t write_resp = 0;
};

struct AXI_LLC_MemOut_t {
  wire1_t read_req_valid = false;
  wire32_t read_req_addr = 0;
  wire8_t read_req_size = 0;
  wire4_t read_req_id = 0;
  wire1_t read_resp_ready = false;
  wire1_t write_req_valid = false;
  wire32_t write_req_addr = 0;
  WideData256_t write_req_data{};
  wire32_t write_req_strobe = 0;
  wire5_t write_req_size = 0;
  wire4_t write_req_id = 0;
  wire1_t write_resp_ready = false;
};

struct AXI_LLC_ExtIn_t {
  AXI_LLC_UpstreamIn_t upstream;
  AXI_LLC_MemIn_t mem;
};

struct AXI_LLC_ExtOut_t {
  AXI_LLC_UpstreamOut_t upstream;
  AXI_LLC_MemOut_t mem;
};

struct AXI_LLC_LookupIn_t {
  wire1_t data_valid = false;
  wire1_t meta_valid = false;
  wire1_t repl_valid = false;
  AXI_LLC_Bytes_t data{};
  AXI_LLC_Bytes_t meta{};
  AXI_LLC_Bytes_t repl{};
};

struct AXI_LLC_TableReq_t {
  wire1_t enable = false;
  wire1_t write = false;
  uint32_t index = 0;
  uint32_t way = 0;
  AXI_LLC_Bytes_t payload{};
  std::vector<uint8_t> byte_enable{};
};

struct AXI_LLC_TableOut_t {
  AXI_LLC_TableReq_t data{};
  AXI_LLC_TableReq_t meta{};
  AXI_LLC_TableReq_t repl{};
  wire1_t invalidate_all = false;
};

enum class AXI_LLCState : uint8_t {
  kDisabled = 0,
  kIdle = 1,
  kLookup = 2,
  kMiss = 3,
  kRefill = 4,
};

struct AXI_LLC_Regs_t {
  bool enable_r = false;
  AXI_LLCState state = AXI_LLCState::kDisabled;
  bool lookup_pending_r = false;
  bool miss_pending_r = false;
  bool refill_pending_r = false;
  uint32_t active_addr_r = 0;
  uint8_t active_size_r = 0;
  uint8_t active_master_r = 0;
  uint8_t active_id_r = 0;
  uint32_t mshr_busy_mask_r = 0;
};

using AXI_LLC_RegWrite_t = AXI_LLC_Regs_t;

struct AXI_LLC_IO_t {
  AXI_LLC_ExtIn_t ext_in;
  AXI_LLC_Regs_t regs;
  AXI_LLC_LookupIn_t lookup_in;
  AXI_LLC_ExtOut_t ext_out;
  AXI_LLC_RegWrite_t reg_write;
  AXI_LLC_TableOut_t table_out;
};

class AXI_LLC {
public:
  AXI_LLC();

  void set_config(const AXI_LLCConfig &config);
  const AXI_LLCConfig &config() const { return config_; }

  void reset();
  void comb();
  void seq();

  AXI_LLC_IO_t io;

private:
  void comb_disabled();

  AXI_LLCConfig config_{};
};

} // namespace axi_interconnect
