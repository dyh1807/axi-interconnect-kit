#include "AXI_LLC.h"

namespace axi_interconnect {

AXI_LLC::AXI_LLC() { reset(); }

void AXI_LLC::set_config(const AXI_LLCConfig &config) {
  config_ = config;
  io.regs.enable_r = config_.enable;
  io.regs.state =
      config_.enable ? AXI_LLCState::kIdle : AXI_LLCState::kDisabled;
}

void AXI_LLC::reset() {
  io = {};
  io.regs.enable_r = config_.enable;
  io.regs.state =
      config_.enable ? AXI_LLCState::kIdle : AXI_LLCState::kDisabled;
}

void AXI_LLC::comb_disabled() {
  for (uint8_t i = 0; i < NUM_READ_MASTERS; ++i) {
    io.ext_out.upstream.read_req[i].ready = false;
    io.ext_out.upstream.read_resp[i].valid = false;
    io.ext_out.upstream.read_resp[i].id = 0;
    io.ext_out.upstream.read_resp[i].data.clear();
  }
  for (uint8_t i = 0; i < NUM_WRITE_MASTERS; ++i) {
    io.ext_out.upstream.write_req[i].ready = false;
    io.ext_out.upstream.write_resp[i].valid = false;
    io.ext_out.upstream.write_resp[i].id = 0;
    io.ext_out.upstream.write_resp[i].resp = 0;
  }
  io.ext_out.mem = {};
}

void AXI_LLC::comb() {
  io.ext_out = {};
  io.table_out = {};
  io.reg_write = io.regs;

  if (!config_.enable) {
    comb_disabled();
    io.reg_write.enable_r = false;
    io.reg_write.state = AXI_LLCState::kDisabled;
    return;
  }

  io.reg_write.enable_r = true;
  if (io.regs.state == AXI_LLCState::kDisabled) {
    io.reg_write.state = AXI_LLCState::kIdle;
  }
}

void AXI_LLC::seq() { io.regs = io.reg_write; }

} // namespace axi_interconnect
