#pragma once

#include "AXI_Interconnect_IO.h"
#include "AXI_LLC_Config.h"
#include <array>
#include <cstddef>
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
constexpr uint8_t AXI_LLC_META_PREFETCH = 1u << 2;
constexpr uint32_t AXI_LLC_META_ENTRY_BYTES = 4;
constexpr uint32_t AXI_LLC_REPL_BYTES = 4;
constexpr uint32_t AXI_LLC_MAX_PREFETCH_QUEUE = 8;
constexpr uint8_t AXI_LLC_INVALID_VICTIM_MSHR_SLOT = 0xFFu;
constexpr uint8_t AXI_LLC_READ_RESP_QUEUE_DEPTH = MAX_OUTSTANDING;
constexpr uint8_t AXI_LLC_READ_VICTIM_WB_QUEUE_DEPTH = MAX_OUTSTANDING;

struct AXI_LLCPerfCounters_t {
  uint64_t read_access = 0;
  uint64_t read_hit = 0;
  uint64_t read_miss = 0;
  uint64_t read_access_by_master[NUM_READ_MASTERS]{};
  uint64_t read_hit_by_master[NUM_READ_MASTERS]{};
  uint64_t read_miss_by_master[NUM_READ_MASTERS]{};
  uint64_t bypass_read = 0;
  uint64_t write_passthrough = 0;
  uint64_t refill = 0;
  uint64_t mshr_alloc = 0;
  uint64_t mshr_merge = 0;
  uint64_t prefetch_issue = 0;
  uint64_t prefetch_hit = 0;
  uint64_t prefetch_drop_inflight = 0;
  uint64_t prefetch_drop_mshr_full = 0;
  uint64_t prefetch_drop_queue_full = 0;
  uint64_t prefetch_drop_table_hit = 0;
  uint64_t ddr_read_total_cycles = 0;
  uint64_t ddr_read_samples = 0;
  uint64_t ddr_write_total_cycles = 0;
  uint64_t ddr_write_samples = 0;
  uint64_t lookup_active_cycles = 0;
  uint64_t read_resp_block_cycles = 0;
  uint64_t read_resp_pending_cycles = 0;
  uint64_t mem_read_wait_cycles = 0;
  uint64_t mem_read_block_cycles = 0;
  uint64_t victim_writeback_wait_cycles = 0;
  uint64_t write_lookup_wait_cycles = 0;
  uint64_t write_victim_wait_cycles = 0;
};

struct AXI_LLC_ReadReqIn_t {
  wire<1> valid = false;
  wire<32> addr = 0;
  wire<8> total_size = 0;
  wire<4> id = 0;
  wire<1> bypass = false;
  wire<1> direct_mapped = false;
  wire<1> mode2_ddr_aligned = false;
};

struct AXI_LLC_ReadReqOut_t {
  wire<1> ready = false;
};

struct AXI_LLC_ReadRespIn_t {
  wire<1> ready = false;
};

struct AXI_LLC_ReadRespOut_t {
  wire<1> valid = false;
  WideReadData_t data{};
  wire<4> id = 0;
};

struct AXI_LLC_WriteReqIn_t {
  wire<1> valid = false;
  wire<32> addr = 0;
  WideWriteData_t wdata{};
  WideWriteStrb_t wstrb{};
  wire<8> total_size = 0;
  wire<4> id = 0;
  wire<1> bypass = false;
  wire<1> direct_mapped = false;
  wire<1> mode2_ddr_aligned = false;
};

struct AXI_LLC_WriteReqOut_t {
  wire<1> ready = false;
};

struct AXI_LLC_WriteRespIn_t {
  wire<1> ready = false;
};

struct AXI_LLC_WriteRespOut_t {
  wire<1> valid = false;
  wire<4> id = 0;
  wire<2> resp = 0;
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
  wire<1> invalidate_all = false;
  wire<1> invalidate_line_valid = false;
  wire<32> invalidate_line_addr = 0;
  wire<1> prefetch_allow = true;
  wire<1> read_req_ready = false;
  wire<1> read_resp_valid = false;
  WideReadData_t read_resp_data{};
  wire<4> read_resp_id = 0;
  wire<1> write_req_ready = false;
  wire<1> write_resp_valid = false;
  wire<4> write_resp_id = 0;
  wire<2> write_resp = 0;
};

struct AXI_LLC_MemOut_t {
  wire<1> invalidate_all_accepted = false;
  wire<1> invalidate_line_accepted = false;
  wire<1> read_req_valid = false;
  wire<32> read_req_addr = 0;
  wire<8> read_req_size = 0;
  wire<1> read_req_mode2_ddr_aligned = false;
  wire<4> read_req_id = 0;
  wire<1> read_resp_ready = false;
  wire<1> write_req_valid = false;
  wire<32> write_req_addr = 0;
  WideWriteData_t write_req_data{};
  WideWriteStrb_t write_req_strobe{};
  wire<8> write_req_size = 0;
  wire<1> write_req_mode2_ddr_aligned = false;
  wire<4> write_req_id = 0;
  wire<1> write_resp_ready = false;
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
  wire<1> data_valid = false;
  wire<1> meta_valid = false;
  wire<1> valid_valid = false;
  wire<1> repl_valid = false;
  AXI_LLC_Bytes_t data{};
  AXI_LLC_Bytes_t meta{};
  AXI_LLC_Bytes_t valid{};
  AXI_LLC_Bytes_t repl{};
};

struct AXI_LLC_TableReq_t {
  wire<1> enable = false;
  wire<1> write = false;
  uint32_t index = 0;
  uint32_t way = 0;
  AXI_LLC_Bytes_t payload{};
  std::vector<uint8_t> byte_enable{};
};

struct AXI_LLC_TableOut_t {
  AXI_LLC_TableReq_t data{};
  AXI_LLC_TableReq_t meta{};
  AXI_LLC_TableReq_t valid{};
  AXI_LLC_TableReq_t repl{};
  wire<1> invalidate_all = false;
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
  bool is_prefetch = false;
  bool is_write = false;
  bool mode2_ddr_aligned = false;
  bool prefetch_train = false;
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
  uint8_t epoch = 0;
  uint64_t mem_issue_cycle = 0;
  bool victim_dirty = false;
  bool victim_writeback_done = false;
  uint32_t victim_addr = 0;
  WideWriteData_t victim_data{};
  WideReadData_t refill_data{};
};

struct AXI_LLCPrefetchReq_t {
  bool valid = false;
  uint32_t line_addr = 0;
};

struct AXI_LLCWritePendingReq_t {
  bool valid = false;
  bool bypass = false;
  bool direct_mapped = false;
  bool mode2_ddr_aligned = false;
  uint8_t master = 0;
  uint8_t id = 0;
  uint8_t total_size = 0;
  uint32_t addr = 0;
  WideWriteData_t wdata{};
  WideWriteStrb_t wstrb{};
};

struct AXI_LLCWriteCtx_t {
  bool valid = false;
  bool bypass = false;
  bool direct_mapped = false;
  bool mode2_ddr_aligned = false;
  bool lookup_pending = false;
  bool mem_issued = false;
  bool mem_done = false;
  bool cache_done = false;
  bool cache_pending = false;
  bool victim_mem_done = false;
  bool victim_dirty = false;
  uint8_t id = 0;
  uint8_t total_size = 0;
  uint8_t mem_resp_code = 0;
  uint32_t addr = 0;
  uint32_t line_addr = 0;
  uint32_t victim_addr = 0;
  uint32_t set = 0;
  uint8_t way = 0;
  uint32_t repl_next_way = 0;
  uint32_t tag = 0;
  uint64_t mem_issue_cycle = 0;
  WideWriteData_t data{};
  WideWriteStrb_t strobe{};
  WideWriteData_t line{};
};

struct AXI_LLCReadVictimWbReq_t {
  bool valid = false;
  uint8_t owner_slot = AXI_LLC_INVALID_VICTIM_MSHR_SLOT;
  uint32_t victim_addr = 0;
  WideWriteData_t victim_data{};
  WideWriteStrb_t victim_strobe{};
};

struct AXI_LLC_Regs_t {
  bool enable_r = false;
  AXI_LLCState state = AXI_LLCState::kDisabled;
  AXI_LLCPerfCounters_t perf{};

  bool lookup_valid_r = false;
  bool lookup_issued_r = false;
  uint32_t lookup_addr_r = 0;
  uint8_t lookup_size_r = 0;
  uint8_t lookup_master_r = 0;
  uint8_t lookup_id_r = 0;
  bool lookup_is_prefetch_r = false;
  bool lookup_is_invalidate_r = false;
  bool lookup_is_write_r = false;
  bool lookup_is_bypass_r = false;
  bool lookup_is_direct_mapped_r = false;
  bool lookup_is_mode2_ddr_aligned_r = false;
  bool prefetch_stream_valid_r = false;
  uint32_t prefetch_last_miss_line_r = 0;
  uint8_t prefetch_quiet_cycles_r = 0;
  AXI_LLCPrefetchReq_t prefetch_q[AXI_LLC_MAX_PREFETCH_QUEUE] = {};

  uint8_t rr_read_master_r = 0;
  uint8_t rr_write_master_r = 0;
  uint8_t invalidate_epoch_r = 0;
  uint32_t dirty_line_count_r = 0;

  bool read_resp_valid_r[NUM_READ_MASTERS] = {false};
  bool read_resp_fresh_r[NUM_READ_MASTERS] = {false};
  WideReadData_t read_resp_data_r[NUM_READ_MASTERS] = {};
  uint8_t read_resp_id_r[NUM_READ_MASTERS] = {0};
  uint8_t read_resp_q_head_r[NUM_READ_MASTERS] = {0};
  uint8_t read_resp_q_tail_r[NUM_READ_MASTERS] = {0};
  uint8_t read_resp_q_count_r[NUM_READ_MASTERS] = {0};
  WideReadData_t read_resp_q_data_r[NUM_READ_MASTERS]
                                   [AXI_LLC_READ_RESP_QUEUE_DEPTH] = {};
  uint8_t read_resp_q_id_r[NUM_READ_MASTERS][AXI_LLC_READ_RESP_QUEUE_DEPTH] = {};
  uint8_t read_victim_wb_q_head_r = 0;
  uint8_t read_victim_wb_q_tail_r = 0;
  uint8_t read_victim_wb_q_count_r = 0;
  AXI_LLCReadVictimWbReq_t
      read_victim_wb_q[AXI_LLC_READ_VICTIM_WB_QUEUE_DEPTH] = {};

  AXI_LLCWriteCtx_t write_ctx[NUM_WRITE_MASTERS] = {};
  uint8_t write_q_head_r[NUM_WRITE_MASTERS] = {0};
  uint8_t write_q_tail_r[NUM_WRITE_MASTERS] = {0};
  uint8_t write_q_count_r[NUM_WRITE_MASTERS] = {0};
  AXI_LLCWritePendingReq_t write_q[NUM_WRITE_MASTERS][MAX_WRITE_OUTSTANDING] = {};
  bool write_resp_valid_r[NUM_WRITE_MASTERS] = {false};
  uint8_t write_resp_id_r[NUM_WRITE_MASTERS] = {0};
  uint8_t write_resp_code_r[NUM_WRITE_MASTERS] = {0};
  uint32_t write_resp_line_addr_r[NUM_WRITE_MASTERS] = {0};

  bool victim_wb_valid_r = false;
  bool victim_wb_issued_r = false;
  bool victim_wb_for_write_r = false;
  uint8_t victim_wb_write_master_r = 0;
  uint8_t victim_wb_mshr_slot_r = 0;
  uint32_t victim_wb_addr_r = 0;
  uint64_t victim_wb_issue_cycle_r = 0;
  WideWriteData_t victim_wb_data_r{};
  WideWriteStrb_t victim_wb_strobe_r{};

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
  bool can_accept_read_now(uint8_t master, bool bypass, uint32_t addr) const;
  const AXI_LLCPerfCounters_t &perf_counters() const { return io.regs.perf; }
  void debug_print() const;

  static uint32_t line_words(const AXI_LLCConfig &config);
  static uint32_t line_addr(const AXI_LLCConfig &config, uint32_t addr);
  static uint32_t set_index(const AXI_LLCConfig &config, uint32_t addr);
  static uint32_t tag_of(const AXI_LLCConfig &config, uint32_t addr);
  static uint32_t valid_row_bytes(const AXI_LLCConfig &config);
  static AXI_LLCMetaEntry_t decode_meta(const AXI_LLC_Bytes_t &payload,
                                        uint32_t way);
  static void encode_meta(const AXI_LLCMetaEntry_t &entry,
                          AXI_LLC_Bytes_t &payload);

  AXI_LLC_IO_t io;

private:
  int find_free_mshr(const AXI_LLC_Regs_t &regs) const;
  int find_mshr_by_line_addr(const AXI_LLC_Regs_t &regs, uint32_t line_addr) const;
  int find_mshr_by_victim_addr(const AXI_LLC_Regs_t &regs,
                               uint32_t victim_addr) const;
  bool has_mshr_for_master(const AXI_LLC_Regs_t &regs, uint8_t master) const;
  uint32_t count_free_mshrs(const AXI_LLC_Regs_t &regs) const;
  bool has_demand_mshr(const AXI_LLC_Regs_t &regs) const;
  int pick_mem_issue_slot(const AXI_LLC_Regs_t &regs) const;
  int find_mshr_by_mem_id(const AXI_LLC_Regs_t &regs, uint8_t mem_id) const;
  int pick_refill_commit_slot(const AXI_LLC_Regs_t &regs) const;
  int pick_new_read_master(const AXI_LLC_Regs_t &regs) const;
  int pick_new_write_master(const AXI_LLC_Regs_t &regs) const;
  int pick_write_lookup_master(const AXI_LLC_Regs_t &regs) const;
  int pick_bypass_write_issue_master(const AXI_LLC_Regs_t &regs) const;
  int find_bypass_write_mem_owner(const AXI_LLC_Regs_t &regs) const;
  bool write_queue_full(const AXI_LLC_Regs_t &regs, uint8_t master) const;
  bool write_queue_empty(const AXI_LLC_Regs_t &regs, uint8_t master) const;
  const AXI_LLCWritePendingReq_t *write_queue_front(
      const AXI_LLC_Regs_t &regs, uint8_t master) const;
  int find_prefetch_queue_slot(const AXI_LLC_Regs_t &regs, uint32_t line_addr) const;
  int find_free_prefetch_queue_slot(const AXI_LLC_Regs_t &regs) const;
  int pick_prefetch_queue_slot(const AXI_LLC_Regs_t &regs) const;
  bool prefetch_candidate_exists(const AXI_LLC_Regs_t &regs, uint32_t line_addr) const;
  bool has_pending_upstream_write_line(uint32_t line_addr) const;
  bool can_allocate_prefetch_mshr(const AXI_LLC_Regs_t &regs) const;
  bool write_line_pending(const AXI_LLC_Regs_t &regs, uint32_t line_addr) const;
  bool read_victim_snapshot_present(const AXI_LLC_Regs_t &regs,
                                    uint32_t victim_addr) const;
  bool victim_snapshot_waits_for_write_resolution(const AXI_LLC_Regs_t &regs,
                                                  uint32_t victim_addr) const;
  bool victim_line_pending(const AXI_LLC_Regs_t &regs, uint32_t line_addr) const;
  bool way_reserved_by_pending_write(const AXI_LLC_Regs_t &regs, uint32_t set,
                                     uint8_t way,
                                     uint32_t line_addr_value) const;
  bool way_reserved_by_pending_refill(const AXI_LLC_Regs_t &regs, uint32_t set,
                                      uint8_t way,
                                      uint32_t line_addr_value) const;
  int pick_unreserved_way(const AXI_LLC_Regs_t &regs, uint32_t set,
                          int first_invalid_way, uint32_t repl_way_raw,
                          uint32_t line_addr_value) const;
  bool can_accept_invalidate_line_now(uint32_t line_addr) const;
  bool has_dirty_or_write_hazard(const AXI_LLC_Regs_t &regs) const;
  bool has_read_resp_pending(const AXI_LLC_Regs_t &regs) const;
  bool can_accept_invalidate_all_now(const AXI_LLC_Regs_t &regs) const;
  bool direct_mapped_coords(uint32_t addr, uint32_t *set,
                            uint8_t *way) const;
  bool line_has_valid_meta(const AXI_LLC_Bytes_t &valid_payload,
                           const AXI_LLC_Bytes_t &meta_payload, uint32_t tag,
                           int *hit_way, int *first_invalid_way,
                           AXI_LLCMetaEntry_t *hit_meta) const;
  bool enqueue_read_response(uint8_t master, uint8_t id,
                             const WideReadData_t &data);
  bool read_victim_wb_queue_full(const AXI_LLC_Regs_t &regs) const;
  bool read_victim_snapshot_queued(const AXI_LLC_Regs_t &regs, uint8_t owner_slot,
                                   uint32_t victim_addr) const;
  bool enqueue_read_victim_snapshot(uint8_t owner_slot, uint32_t victim_addr,
                                    const WideWriteData_t &victim_data,
                                    const WideWriteStrb_t &victim_strobe);
  void try_schedule_prefetch(const AXI_LLCMissEntry_t &entry);
  void try_launch_prefetch_lookup();
  bool try_launch_pending_write_lookup();

  void drive_read_responses();
  void drive_write_path();
  void drive_lookup_request();
  bool try_complete_lookup();
  void drive_mem_read_path();
  void accept_new_requests();
  void accept_maintenance_request();
  void comb_disabled();

  AXI_LLCConfig config_{};
};

} // namespace axi_interconnect
