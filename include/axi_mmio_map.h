#pragma once

#include "axi_interconnect_compat.h"
#include <cstdint>

struct AxiMmioRange {
  uint32_t base;
  uint32_t size;
};

static constexpr AxiMmioRange kAxiMmioRanges[] = {
    {UART_ADDR_BASE, UART_MMIO_SIZE},
    {XPS_INTC_ADDR_BASE, XPS_INTC_MMIO_SIZE},
    {OPENSBI_TIMER_BASE, 0x00000010u},
    {0x1fe10000u, 0x00000064u},
    {0x4ff00000u, 0x00100000u},
    {0x87f00000u, 0x00100000u},
    {0xfff00000u, 0x00100000u},
};

#ifndef MMIO_RANGE_BASE
#define MMIO_RANGE_BASE MMIO_BASE
#endif

#ifndef MMIO_RANGE_SIZE
#define MMIO_RANGE_SIZE MMIO_SIZE
#endif

static inline bool is_mmio_addr(uint32_t addr) {
  for (const auto &range : kAxiMmioRanges) {
    const auto start = static_cast<uint64_t>(range.base);
    const auto end = start + static_cast<uint64_t>(range.size);
    if (static_cast<uint64_t>(addr) >= start &&
        static_cast<uint64_t>(addr) < end) {
      return true;
    }
  }
  return false;
}
