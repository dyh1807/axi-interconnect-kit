#pragma once

#if __has_include("config.h")
#include "config.h"
#endif

#include <cstdint>
#include <type_traits>

#ifndef AXI_KIT_USE_PARENT_WIRE_REG
template <int Bits> struct AutoTypeHelper {
  static_assert(Bits > 0, "wire/reg bit width must be positive");
  static_assert(Bits <= 128,
                "axi-interconnect-kit currently supports wire/reg up to 128 "
                "bits; wider carriers are a later follow-up");

  using type = std::conditional_t<
      Bits == 1, bool,
      std::conditional_t<
          (Bits <= 8), uint8_t,
          std::conditional_t<
              (Bits <= 16), uint16_t,
              std::conditional_t<(Bits <= 32), uint32_t,
                                 std::conditional_t<(Bits <= 64), uint64_t,
                                                    unsigned __int128>>>>>;
};

template <int Bits> using AutoType = typename AutoTypeHelper<Bits>::type;
template <int Bits> using wire = AutoType<Bits>;
template <int Bits> using reg = AutoType<Bits>;

static_assert(std::is_same_v<wire<1>, bool>);
static_assert(std::is_same_v<wire<32>, uint32_t>);
static_assert(sizeof(wire<128>) == 16,
              "wire<128> must remain a real 128-bit carrier in standalone "
              "axi-interconnect-kit");
#endif

// Configurable defaults for standalone build (can be overridden via -D).
// Keep a single simulator-facing DDR read latency entrypoint.
#ifndef CONFIG_SIM_DDR_LATENCY
#define CONFIG_SIM_DDR_LATENCY 50
#endif

#ifndef AXI_KIT_DEBUG
#define AXI_KIT_DEBUG 0
#endif

#ifndef AXI_KIT_DCACHE_LOG
#define AXI_KIT_DCACHE_LOG 0
#endif

#ifndef AXI_KIT_UART_BASE
#define AXI_KIT_UART_BASE 0x10000000u
#endif

#ifndef AXI_KIT_MMIO_BASE
#ifdef MMIO_TEST_BASE
#define AXI_KIT_MMIO_BASE MMIO_TEST_BASE
#else
#define AXI_KIT_MMIO_BASE AXI_KIT_UART_BASE
#endif
#endif

#ifndef AXI_KIT_MMIO_SIZE
#ifdef MMIO_TEST_SIZE
#define AXI_KIT_MMIO_SIZE MMIO_TEST_SIZE
#else
#define AXI_KIT_MMIO_SIZE 0x00001000u
#endif
#endif

#ifndef DEBUG
#define DEBUG AXI_KIT_DEBUG
#endif

#ifndef DCACHE_LOG
#define DCACHE_LOG AXI_KIT_DCACHE_LOG
#endif

#ifndef UART_BASE
#define UART_BASE AXI_KIT_UART_BASE
#endif

#ifndef MMIO_BASE
#define MMIO_BASE AXI_KIT_MMIO_BASE
#endif

#ifndef MMIO_SIZE
#define MMIO_SIZE AXI_KIT_MMIO_SIZE
#endif
