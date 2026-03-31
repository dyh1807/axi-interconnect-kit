#pragma once

#if __has_include("config.h")
#include "config.h"
#endif

#include <cstdint>
#include <type_traits>

#ifndef AXI_KIT_HAS_PARENT_CONFIG
#if __has_include("config.h") && __has_include("base_types.h")
#define AXI_KIT_HAS_PARENT_CONFIG 1
#else
#define AXI_KIT_HAS_PARENT_CONFIG 0
#endif
#endif

#ifndef AXI_KIT_USE_PARENT_WIRE_REG
#define AXI_KIT_USE_PARENT_WIRE_REG AXI_KIT_HAS_PARENT_CONFIG
#endif

#if !AXI_KIT_USE_PARENT_WIRE_REG
template <int Bits>
struct AutoTypeHelper {
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

template <int Bits>
using AutoType = typename AutoTypeHelper<Bits>::type;
template <int Bits>
using wire = AutoType<Bits>;
template <int Bits>
using reg = AutoType<Bits>;

static_assert(std::is_same_v<wire<1>, bool>);
static_assert(std::is_same_v<wire<32>, uint32_t>);
static_assert(sizeof(wire<128>) == 16,
              "wire<128> must remain a real 128-bit carrier in standalone "
              "axi-interconnect-kit");
#endif

#if AXI_KIT_HAS_PARENT_CONFIG
#ifndef CONFIG_SIM_DDR_LATENCY
#error "simulator config.h must define CONFIG_SIM_DDR_LATENCY for AXI kit integration"
#endif
#ifndef CONFIG_AXI_KIT_SIM_DDR_WRITE_RESP_LATENCY
#error "simulator config.h must define CONFIG_AXI_KIT_SIM_DDR_WRITE_RESP_LATENCY"
#endif
#ifndef CONFIG_AXI_KIT_SIM_DDR_BEAT_BYTES
#error "simulator config.h must define CONFIG_AXI_KIT_SIM_DDR_BEAT_BYTES"
#endif
#ifndef CONFIG_AXI_KIT_MAX_OUTSTANDING
#error "simulator config.h must define CONFIG_AXI_KIT_MAX_OUTSTANDING"
#endif
#ifndef CONFIG_AXI_KIT_MAX_READ_OUTSTANDING_PER_MASTER
#error "simulator config.h must define CONFIG_AXI_KIT_MAX_READ_OUTSTANDING_PER_MASTER"
#endif
#ifndef CONFIG_AXI_KIT_MAX_WRITE_OUTSTANDING
#error "simulator config.h must define CONFIG_AXI_KIT_MAX_WRITE_OUTSTANDING"
#endif
#ifndef CONFIG_AXI_KIT_MAX_WRITE_TRANSACTION_BYTES
#error "simulator config.h must define CONFIG_AXI_KIT_MAX_WRITE_TRANSACTION_BYTES"
#endif
#ifndef CONFIG_AXI_KIT_SIM_DDR_MAX_OUTSTANDING
#error "simulator config.h must define CONFIG_AXI_KIT_SIM_DDR_MAX_OUTSTANDING"
#endif
#ifndef CONFIG_AXI_KIT_AXI_ID_WIDTH
#error "simulator config.h must define CONFIG_AXI_KIT_AXI_ID_WIDTH"
#endif
#ifndef CONFIG_AXI_KIT_DEBUG
#error "simulator config.h must define CONFIG_AXI_KIT_DEBUG"
#endif
#ifndef CONFIG_AXI_KIT_UART_BASE
#error "simulator config.h must define CONFIG_AXI_KIT_UART_BASE"
#endif
#ifndef CONFIG_AXI_KIT_MMIO_BASE
#error "simulator config.h must define CONFIG_AXI_KIT_MMIO_BASE"
#endif
#ifndef CONFIG_AXI_KIT_MMIO_SIZE
#error "simulator config.h must define CONFIG_AXI_KIT_MMIO_SIZE"
#endif
#endif

// Configurable defaults for standalone build (can be overridden via -D).
#ifndef CONFIG_SIM_DDR_LATENCY
#define CONFIG_SIM_DDR_LATENCY 50
#endif

#ifndef AXI_KIT_SIM_DDR_READ_LATENCY
#define AXI_KIT_SIM_DDR_READ_LATENCY CONFIG_SIM_DDR_LATENCY
#endif

#ifndef AXI_KIT_SIM_DDR_WRITE_RESP_LATENCY
#ifdef CONFIG_AXI_KIT_SIM_DDR_WRITE_RESP_LATENCY
#define AXI_KIT_SIM_DDR_WRITE_RESP_LATENCY \
  CONFIG_AXI_KIT_SIM_DDR_WRITE_RESP_LATENCY
#else
#define AXI_KIT_SIM_DDR_WRITE_RESP_LATENCY 2
#endif
#endif

#ifndef AXI_KIT_SIM_DDR_MAX_OUTSTANDING
#ifdef CONFIG_AXI_KIT_SIM_DDR_MAX_OUTSTANDING
#define AXI_KIT_SIM_DDR_MAX_OUTSTANDING CONFIG_AXI_KIT_SIM_DDR_MAX_OUTSTANDING
#else
#define AXI_KIT_SIM_DDR_MAX_OUTSTANDING 8
#endif
#endif

#ifndef AXI_KIT_AXI_ID_WIDTH
#ifdef CONFIG_AXI_KIT_AXI_ID_WIDTH
#define AXI_KIT_AXI_ID_WIDTH CONFIG_AXI_KIT_AXI_ID_WIDTH
#else
#define AXI_KIT_AXI_ID_WIDTH 6
#endif
#endif

#ifndef AXI_KIT_SIM_DDR_BEAT_BYTES
#ifdef CONFIG_AXI_KIT_SIM_DDR_BEAT_BYTES
#define AXI_KIT_SIM_DDR_BEAT_BYTES CONFIG_AXI_KIT_SIM_DDR_BEAT_BYTES
#else
#define AXI_KIT_SIM_DDR_BEAT_BYTES 4
#endif
#endif

#ifndef AXI_KIT_MAX_OUTSTANDING
#ifdef CONFIG_AXI_KIT_MAX_OUTSTANDING
#define AXI_KIT_MAX_OUTSTANDING CONFIG_AXI_KIT_MAX_OUTSTANDING
#else
#define AXI_KIT_MAX_OUTSTANDING 8
#endif
#endif

#ifndef AXI_KIT_MAX_READ_OUTSTANDING_PER_MASTER
#ifdef CONFIG_AXI_KIT_MAX_READ_OUTSTANDING_PER_MASTER
#define AXI_KIT_MAX_READ_OUTSTANDING_PER_MASTER \
  CONFIG_AXI_KIT_MAX_READ_OUTSTANDING_PER_MASTER
#else
#define AXI_KIT_MAX_READ_OUTSTANDING_PER_MASTER 4
#endif
#endif

#ifndef AXI_KIT_MAX_WRITE_OUTSTANDING
#ifdef CONFIG_AXI_KIT_MAX_WRITE_OUTSTANDING
#define AXI_KIT_MAX_WRITE_OUTSTANDING CONFIG_AXI_KIT_MAX_WRITE_OUTSTANDING
#else
#define AXI_KIT_MAX_WRITE_OUTSTANDING 8
#endif
#endif

#ifndef AXI_KIT_MAX_WRITE_TRANSACTION_BYTES
#ifdef CONFIG_AXI_KIT_MAX_WRITE_TRANSACTION_BYTES
#define AXI_KIT_MAX_WRITE_TRANSACTION_BYTES \
  CONFIG_AXI_KIT_MAX_WRITE_TRANSACTION_BYTES
#else
#define AXI_KIT_MAX_WRITE_TRANSACTION_BYTES 64
#endif
#endif

#ifndef AXI_KIT_DEBUG
#ifdef CONFIG_AXI_KIT_DEBUG
#define AXI_KIT_DEBUG CONFIG_AXI_KIT_DEBUG
#else
#define AXI_KIT_DEBUG 0
#endif
#endif

#ifndef AXI_KIT_DCACHE_LOG
#ifdef CONFIG_AXI_KIT_DCACHE_LOG
#define AXI_KIT_DCACHE_LOG CONFIG_AXI_KIT_DCACHE_LOG
#else
#define AXI_KIT_DCACHE_LOG 0
#endif
#endif

#ifndef AXI_KIT_UART_BASE
#ifdef CONFIG_AXI_KIT_UART_BASE
#define AXI_KIT_UART_BASE CONFIG_AXI_KIT_UART_BASE
#else
#define AXI_KIT_UART_BASE 0x10000000u
#endif
#endif

#ifndef AXI_KIT_MMIO_BASE
#ifdef CONFIG_AXI_KIT_MMIO_BASE
#define AXI_KIT_MMIO_BASE CONFIG_AXI_KIT_MMIO_BASE
#elif defined(MMIO_TEST_BASE)
#define AXI_KIT_MMIO_BASE MMIO_TEST_BASE
#else
#define AXI_KIT_MMIO_BASE AXI_KIT_UART_BASE
#endif
#endif

#ifdef MMIO_TEST_BASE
#undef AXI_KIT_MMIO_BASE
#define AXI_KIT_MMIO_BASE MMIO_TEST_BASE
#endif

#ifndef AXI_KIT_MMIO_SIZE
#ifdef CONFIG_AXI_KIT_MMIO_SIZE
#define AXI_KIT_MMIO_SIZE CONFIG_AXI_KIT_MMIO_SIZE
#elif defined(MMIO_TEST_SIZE)
#define AXI_KIT_MMIO_SIZE MMIO_TEST_SIZE
#else
#define AXI_KIT_MMIO_SIZE 0x00001000u
#endif
#endif

#ifdef MMIO_TEST_SIZE
#undef AXI_KIT_MMIO_SIZE
#define AXI_KIT_MMIO_SIZE MMIO_TEST_SIZE
#endif

static_assert(AXI_KIT_AXI_ID_WIDTH > 0,
              "AXI_KIT_AXI_ID_WIDTH must be positive");
static_assert(AXI_KIT_AXI_ID_WIDTH <= 7,
              "AXI_KIT_AXI_ID_WIDTH must stay <= 7; 0xFF is reserved as invalid ID");
static_assert(AXI_KIT_MAX_OUTSTANDING <= (1u << AXI_KIT_AXI_ID_WIDTH),
              "AXI_KIT_MAX_OUTSTANDING exceeds available AXI IDs");
static_assert(AXI_KIT_MAX_READ_OUTSTANDING_PER_MASTER <= AXI_KIT_MAX_OUTSTANDING,
              "AXI_KIT_MAX_READ_OUTSTANDING_PER_MASTER exceeds total outstanding budget");
static_assert(AXI_KIT_MAX_WRITE_OUTSTANDING <= (1u << AXI_KIT_AXI_ID_WIDTH),
              "AXI_KIT_MAX_WRITE_OUTSTANDING exceeds available AXI IDs");

#if AXI_KIT_HAS_PARENT_CONFIG
static_assert(AXI_KIT_SIM_DDR_READ_LATENCY == CONFIG_SIM_DDR_LATENCY,
              "parent simulator DDR read latency must come from config.h");
static_assert(
    AXI_KIT_SIM_DDR_WRITE_RESP_LATENCY ==
        CONFIG_AXI_KIT_SIM_DDR_WRITE_RESP_LATENCY,
    "parent simulator DDR write response latency must come from config.h");
static_assert(AXI_KIT_SIM_DDR_BEAT_BYTES == CONFIG_AXI_KIT_SIM_DDR_BEAT_BYTES,
              "parent simulator DDR beat bytes must come from config.h");
static_assert(AXI_KIT_MAX_OUTSTANDING == CONFIG_AXI_KIT_MAX_OUTSTANDING,
              "parent simulator AXI outstanding cap must come from config.h");
static_assert(AXI_KIT_MAX_READ_OUTSTANDING_PER_MASTER ==
                  CONFIG_AXI_KIT_MAX_READ_OUTSTANDING_PER_MASTER,
              "parent simulator read outstanding cap must come from config.h");
static_assert(AXI_KIT_MAX_WRITE_OUTSTANDING ==
                  CONFIG_AXI_KIT_MAX_WRITE_OUTSTANDING,
              "parent simulator write outstanding cap must come from config.h");
static_assert(
    AXI_KIT_MAX_WRITE_TRANSACTION_BYTES ==
        CONFIG_AXI_KIT_MAX_WRITE_TRANSACTION_BYTES,
    "parent simulator AXI write payload width must come from config.h");
static_assert(AXI_KIT_SIM_DDR_MAX_OUTSTANDING ==
                  CONFIG_AXI_KIT_SIM_DDR_MAX_OUTSTANDING,
              "parent simulator SimDDR queue depth must come from config.h");
static_assert(AXI_KIT_AXI_ID_WIDTH == CONFIG_AXI_KIT_AXI_ID_WIDTH,
              "parent simulator AXI ID width must come from config.h");
static_assert(AXI_KIT_UART_BASE == CONFIG_AXI_KIT_UART_BASE,
              "parent simulator UART base must come from config.h");
static_assert(AXI_KIT_MMIO_BASE == CONFIG_AXI_KIT_MMIO_BASE,
              "parent simulator MMIO base must come from config.h");
static_assert(AXI_KIT_MMIO_SIZE == CONFIG_AXI_KIT_MMIO_SIZE,
              "parent simulator MMIO size must come from config.h");
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
