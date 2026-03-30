#pragma once
/**
 * @file AXI_Router_AXI4.h
 * @brief Simple AXI4 address router (DDR vs MMIO).
 *
 * Routes one AXI4 master interface to either:
 * - SimDDR (normal memory range)
 * - MMIO bus (MMIO range)
 *
 * The router tracks read targets by AXI ID so DDR/MMIO reads can be
 * outstanding concurrently. The write side still keeps a single active stream.
 */

#include "SimDDR_IO.h"

namespace axi_interconnect {

class AXI_Router_AXI4 {
public:
  void init();

  // Phase 1: route responses from downstream to upstream
  void comb_outputs(sim_ddr::SimDDR_IO_t &up, const sim_ddr::SimDDR_IO_t &ddr,
                    const sim_ddr::SimDDR_IO_t &mmio);

  // Phase 2: route requests from upstream to downstream
  void comb_inputs(sim_ddr::SimDDR_IO_t &up, sim_ddr::SimDDR_IO_t &ddr,
                   sim_ddr::SimDDR_IO_t &mmio);

  // Sequential update
  void seq(const sim_ddr::SimDDR_IO_t &up, const sim_ddr::SimDDR_IO_t &ddr,
           const sim_ddr::SimDDR_IO_t &mmio);

private:
  static constexpr uint32_t ROUTER_AXI_ID_SLOTS = 256;

  bool r_route_valid[ROUTER_AXI_ID_SLOTS];
  bool r_route_to_mmio[ROUTER_AXI_ID_SLOTS];
  bool r_drive_valid;
  bool r_drive_to_mmio;
  uint8_t r_drive_id;

  bool w_active;
  bool w_to_mmio;
};

} // namespace axi_interconnect
