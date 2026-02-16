#pragma once

#include <cstdint>

// Single-cycle demo keeps a small, local config surface.
// AXI-related defaults are still provided by include/axi_interconnect_compat.h.

#ifndef PHYSICAL_MEMORY_LENGTH
#define PHYSICAL_MEMORY_LENGTH (1024u * 1024u * 1024u)
#endif

#ifndef MAX_COMMIT_INST
#define MAX_COMMIT_INST 150000000ull
#endif

#ifndef ICACHE_MISS_LATENCY
#define ICACHE_MISS_LATENCY 8u
#endif

#ifndef UART_BASE
#define UART_BASE 0x10000000u
#endif
