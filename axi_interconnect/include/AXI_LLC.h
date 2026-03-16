#pragma once

#include "AXI_Interconnect_IO.h"
#include "AXI_LLC_Config.h"
#include <array>
#include <cstdint>
#include <vector>

namespace axi_interconnect {

struct AXI_LLC_Bytes_t {
  std::vector<uint8_t> bytes{};

  void clear() { bytes.clear(); }
  void resize(size_t size) { bytes.assign(size, 0); }
  size_t size() const { return bytes.size(); }
  uint8_t *data() { return bytes.data(); }
  const uint8_t *data() const { return bytes.data(); }
};

struct AXI_LLCMetaEntry_t {
  uint32_t tag = 0;
  uint8_t flags = 0;
};

constexpr uint8_t AXI_LLC_META_VALID = 1u << 0;
constexpr uint8_t AXI_LLC_META_DIRTY = 1u << 1;
constexpr uint32_t AXI_LLC_META_ENTRY_BYTES = 8;
constexpr uint32_t AXI_LLC_REPL_BYTES = 4;

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

struct AXI_LLCMissEntry_t {
  bool valid = false;
  bool bypass = false;
  bool mem_req_issued = false;
  bool refill_valid = false;
  bool refill_committed = false;
  uint32_t addr = 0;
  uint32_t line_addr = 0;
  uint32_t set = 0;
  uint32_t tag = 0;
  uint8_t way = 0;
  uint8_t total_size = 0;
  uint8_t master = 0;
  uint8_t id = 0;
  WideReadData_t refill_data{};
};

struct AXI_LLC_Regs_t {
  bool enable_r = false;
  AXI_LLCState state = AXI_LLCState::kDisabled;

  bool lookup_valid_r = false;
  uint32_t lookup_addr_r = 0;
  uint8_t lookup_size_r = 0;
  uint8_t lookup_master_r = 0;
  uint8_t lookup_id_r = 0;

  uint8_t rr_read_master_r = 0;
  uint8_t rr_write_master_r = 0;

  bool read_resp_valid_r[NUM_READ_MASTERS] = {false};
  WideReadData_t read_resp_data_r[NUM_READ_MASTERS] = {};
  uint8_t read_resp_id_r[NUM_READ_MASTERS] = {0};

  bool write_active_r = false;
  uint8_t write_active_master_r = 0;
  uint8_t write_active_id_r = 0;
  bool write_resp_valid_r[NUM_WRITE_MASTERS] = {false};
  uint8_t write_resp_id_r[NUM_WRITE_MASTERS] = {0};
  uint8_t write_resp_code_r[NUM_WRITE_MASTERS] = {0};

  AXI_LLCMissEntry_t mshr[MAX_OUTSTANDING] = {};
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

  static uint32_t line_words(const AXI_LLCConfig &config);
  static uint32_t line_addr(const AXI_LLCConfig &config, uint32_t addr);
  static uint32_t set_index(const AXI_LLCConfig &config, uint32_t addr);
  static uint32_t tag_of(const AXI_LLCConfig &config, uint32_t addr);
  static AXI_LLCMetaEntry_t decode_meta(const AXI_LLC_Bytes_t &payload,
                                        uint32_t way);
  static void encode_meta(const AXI_LLCMetaEntry_t &entry,
                          AXI_LLC_Bytes_t &payload);

  AXI_LLC_IO_t io;

private:
  int find_free_mshr(const AXI_LLC_Regs_t &regs) const;
  int pick_mem_issue_slot(const AXI_LLC_Regs_t &regs) const;
  int find_mshr_by_mem_id(const AXI_LLC_Regs_t &regs, uint8_t mem_id) const;
  int pick_refill_commit_slot(const AXI_LLC_Regs_t &regs) const;
  int pick_new_read_master(const AXI_LLC_Regs_t &regs) const;
  int pick_new_write_master(const AXI_LLC_Regs_t &regs) const;

  void drive_read_responses();
  void drive_write_path();
  void drive_lookup_request();
  bool try_complete_lookup();
  void drive_mem_read_path();
  void accept_new_requests();
  void comb_disabled();

  AXI_LLCConfig config_{};
};

} // namespace axi_interconnect
