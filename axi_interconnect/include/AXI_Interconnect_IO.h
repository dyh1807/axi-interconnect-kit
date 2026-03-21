#pragma once
/**
 * @file AXI_Interconnect_IO.h
 * @brief AXI-Interconnect Upstream Interface Definitions
 *
 * Simplified master interfaces for icache/dcache/mmu:
 * - Read response can return one full upstream transaction (up to 256B)
 * - Write request payload can carry one full cache-line transaction
 * - total_size specifies transfer width in bytes minus 1
 * - ID for out-of-order response routing
 */

#include "axi_interconnect_compat.h"
#include <cstdint>

namespace axi_interconnect {

// ============================================================================
// Configuration
// ============================================================================
constexpr uint8_t NUM_READ_MASTERS = 4;  // icache, dcache, mmu, extra
constexpr uint8_t NUM_WRITE_MASTERS = 2; // dcache + extra
constexpr uint8_t MAX_OUTSTANDING = 8;

#ifndef AXI_KIT_MAX_WRITE_TRANSACTION_BYTES
#define AXI_KIT_MAX_WRITE_TRANSACTION_BYTES 64
#endif

static_assert((AXI_KIT_MAX_WRITE_TRANSACTION_BYTES % sizeof(uint32_t)) == 0,
              "AXI_KIT_MAX_WRITE_TRANSACTION_BYTES must be word-aligned");
static_assert(AXI_KIT_MAX_WRITE_TRANSACTION_BYTES > 0,
              "AXI_KIT_MAX_WRITE_TRANSACTION_BYTES must be non-zero");
static_assert(AXI_KIT_MAX_WRITE_TRANSACTION_BYTES <= 64,
              "AXI_KIT_MAX_WRITE_TRANSACTION_BYTES exceeds 64B strobe width");

constexpr uint16_t MAX_WRITE_TRANSACTION_BYTES =
    AXI_KIT_MAX_WRITE_TRANSACTION_BYTES;
constexpr uint16_t MAX_WRITE_TRANSACTION_WORDS =
    MAX_WRITE_TRANSACTION_BYTES / sizeof(uint32_t);
constexpr uint8_t CACHELINE_WORDS = MAX_WRITE_TRANSACTION_WORDS;
constexpr uint16_t MAX_READ_TRANSACTION_BYTES = 256;
constexpr uint16_t MAX_READ_TRANSACTION_WORDS =
    MAX_READ_TRANSACTION_BYTES / sizeof(uint32_t);

// Master IDs
constexpr uint8_t MASTER_ICACHE = 0;
constexpr uint8_t MASTER_DCACHE_R = 1;
constexpr uint8_t MASTER_MMU = 2;
constexpr uint8_t MASTER_EXTRA_R = 3;

constexpr uint8_t MASTER_DCACHE_W = 0;
constexpr uint8_t MASTER_EXTRA_W = 1;

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
// Write Payload Data Type (up to 64B by default)
// ============================================================================
struct WideWriteData_t {
  uint32_t words[MAX_WRITE_TRANSACTION_WORDS];

  void clear() {
    for (int i = 0; i < MAX_WRITE_TRANSACTION_WORDS; i++)
      words[i] = 0;
  }

  uint32_t &operator[](int idx) { return words[idx]; }
  const uint32_t &operator[](int idx) const { return words[idx]; }
};

// Backward-compatible alias kept for existing code paths/tests.
using WideData256_t = WideWriteData_t;

// ============================================================================
// Read Master Interface (for icache/dcache/mmu)
// ============================================================================

// Read Request: Master → Interleaver
struct ReadMasterReq_t {
  wire1_t valid;
  wire1_t ready;      // ← Output from interleaver
  wire32_t addr;      // Byte address
  wire8_t total_size; // 0=1B ... 255=256B
  wire4_t id;         // Transaction ID (for out-of-order)
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
  WideWriteData_t wdata; // Wide write data
  wire64_t wstrb;        // Byte strobe (1 bit per byte, up to 64B)
  wire8_t total_size;    // 0=1B ... 63=64B (default cap)
  wire4_t id;          // Transaction ID
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
