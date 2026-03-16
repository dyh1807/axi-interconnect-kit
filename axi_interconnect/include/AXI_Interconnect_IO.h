#pragma once
/**
 * @file AXI_Interconnect_IO.h
 * @brief AXI-Interconnect Upstream Interface Definitions
 *
 * Simplified master interfaces for icache/dcache/uncore-lsu/extra:
 * - Read response can return one full upstream transaction (up to 256B)
 * - Write request payload remains 256-bit (32B), matching current dcache use
 * - total_size specifies transfer width in bytes minus 1
 * - ID for out-of-order response routing
 */

#include "axi_interconnect_compat.h"
#include <cstdint>

namespace axi_interconnect {

// ============================================================================
// Configuration
// ============================================================================
constexpr uint8_t NUM_READ_MASTERS = 4;  // icache, dcache, uncore-lsu, extra
constexpr uint8_t NUM_WRITE_MASTERS = 2; // dcache + uncore-lsu
constexpr uint8_t MAX_OUTSTANDING = 8;
constexpr uint8_t MAX_READ_OUTSTANDING_PER_MASTER = 4;
constexpr uint8_t CACHELINE_WORDS = 8; // 256-bit = 8 x 32-bit
constexpr uint16_t MAX_READ_TRANSACTION_BYTES = 256;
constexpr uint16_t MAX_READ_TRANSACTION_WORDS =
    MAX_READ_TRANSACTION_BYTES / sizeof(uint32_t);

// Master IDs
constexpr uint8_t MASTER_ICACHE = 0;
constexpr uint8_t MASTER_DCACHE_R = 1;
constexpr uint8_t MASTER_UNCORE_LSU_R = 2;
constexpr uint8_t MASTER_EXTRA_R = 3;

constexpr uint8_t MASTER_DCACHE_W = 0;
constexpr uint8_t MASTER_UNCORE_LSU_W = 1;

// Legacy aliases kept for source compatibility while simulator wiring migrates.
constexpr uint8_t MASTER_MMU = MASTER_UNCORE_LSU_R;
constexpr uint8_t MASTER_EXTRA_W = MASTER_UNCORE_LSU_W;

// ============================================================================
// Read Response Data Type (up to 256B = 64 x 32-bit words)
// ============================================================================
struct WideReadData_t {
  uint32_t words[MAX_READ_TRANSACTION_WORDS];

  void clear() {
    for (int i = 0; i < MAX_READ_TRANSACTION_WORDS; i++)
      words[i] = 0;
  }

  uint32_t &operator[](int idx) { return words[idx]; }
  const uint32_t &operator[](int idx) const { return words[idx]; }
};

// ============================================================================
// Write Payload Data Type (256-bit = 8 x 32-bit words)
// ============================================================================
struct WideData256_t {
  uint32_t words[CACHELINE_WORDS];

  void clear() {
    for (int i = 0; i < CACHELINE_WORDS; i++)
      words[i] = 0;
  }

  uint32_t &operator[](int idx) { return words[idx]; }
  const uint32_t &operator[](int idx) const { return words[idx]; }
};

// ============================================================================
// Read Master Interface (for icache/dcache/uncore-lsu/extra)
// ============================================================================

// Read Request: Master → Interleaver
struct ReadMasterReq_t {
  wire1_t valid;
  wire1_t ready;      // ← Output from interleaver
  wire32_t addr;      // Byte address
  wire8_t total_size; // 0=1B ... 255=256B
  wire4_t id;         // Transaction ID (for out-of-order)
  wire1_t bypass;     // Skip LLC / cacheable path and force memory/MMIO routing
};

// Read Response: Interleaver → Master
struct ReadMasterResp_t {
  wire1_t valid; // ← Output from interleaver
  wire1_t ready;
  WideReadData_t data; // Wide data (up to one 256B upstream transaction)
  wire4_t id;         // Matching transaction ID
};

// Combined Read Master Port
struct ReadMasterPort_t {
  ReadMasterReq_t req;
  ReadMasterResp_t resp;
};

// ============================================================================
// Write Master Interface
// ============================================================================

// Write Request: Master → Interleaver (AW+W combined)
struct WriteMasterReq_t {
  wire1_t valid;
  wire1_t ready;       // ← Output from interleaver
  wire32_t addr;       // Byte address
  WideData256_t wdata; // Wide write data
  wire32_t wstrb;      // Byte strobe (32 bits for 256-bit data)
  wire5_t total_size;  // 0=1B, 3=4B, 31=32B
  wire4_t id;          // Transaction ID
  wire1_t bypass;      // Skip LLC / cacheable path and force memory/MMIO routing
};

// Write Response: Interleaver → Master
struct WriteMasterResp_t {
  wire1_t valid; // ← Output from interleaver
  wire1_t ready;
  wire4_t id;   // Matching transaction ID
  wire2_t resp; // AXI response (OKAY, SLVERR, etc.)
};

// Combined Write Master Port
struct WriteMasterPort_t {
  WriteMasterReq_t req;
  WriteMasterResp_t resp;
};

// ============================================================================
// AXI-Interconnect Combined IO
// ============================================================================

struct AXI_Interconnect_IO_t {
  // Upstream: Read Masters (3 ports)
  ReadMasterPort_t read_masters[NUM_READ_MASTERS];

  // Upstream: Write Masters (2 ports)
  WriteMasterPort_t write_masters[NUM_WRITE_MASTERS];

  // Downstream: AXI4 to SimDDR
  // (Use SimDDR_IO_t from sim_ddr module)
};

} // namespace axi_interconnect
