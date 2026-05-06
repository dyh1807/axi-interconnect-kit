/**
 * @file axi_interconnect_dual_port_perf_vectors_test.cpp
 * @brief Emit cycle-level performance vectors from the production C++ model.
 *
 * This generator intentionally stays in the test tree. It does not add
 * synthesizable counters; the RTL side consumes the generated constants from
 * a testbench-only include.
 */

#include <array>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <map>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#include "AXI_Interconnect.h"

uint32_t *p_memory = nullptr;
long long sim_time = 0;

namespace {

constexpr int kReadLatency = 2;
constexpr int kWriteRespLatency = 2;
constexpr int kMaxCycles = 80;

enum class PerfPort : uint8_t {
  DDR = 0,
  MMIO = 1,
};

struct ReadSpec {
  std::string prefix;
  uint8_t master = 0;
  PerfPort port = PerfPort::DDR;
  uint32_t addr = 0;
  uint8_t size = 0;
  uint8_t id = 0;
  uint8_t beats = 1;
};

struct WriteSpec {
  std::string prefix;
  uint8_t master = 0;
  PerfPort port = PerfPort::DDR;
  uint32_t addr = 0;
  uint8_t size = 0;
  uint8_t id = 0;
  uint8_t beats = 1;
  axi_interconnect::WideWriteData_t data{};
  axi_interconnect::WideWriteStrb_t strobe{};
};

struct Scenario {
  std::string name;
  std::vector<ReadSpec> reads;
  std::vector<WriteSpec> writes;
};

struct ReadRuntime {
  bool ar_seen = false;
  int r_seen = 0;
};

struct WriteRuntime {
  bool aw_seen = false;
  int w_seen = 0;
};

struct ReadBeat {
  PerfPort port = PerfPort::DDR;
  int due_cycle = -1;
  uint8_t id = 0;
  int beat = 0;
  int beats = 1;
  std::string prefix;
};

struct WriteResp {
  PerfPort port = PerfPort::DDR;
  int due_cycle = -1;
  uint8_t id = 0;
  std::string prefix;
};

struct ScenarioResult {
  Scenario scenario;
  std::map<std::string, int> cycles;
};

void require(bool condition, const char *message) {
  if (!condition) {
    throw std::runtime_error(message);
  }
}

std::string hex_u32(uint32_t value) {
  std::ostringstream os;
  os << "32'h" << std::hex << std::setfill('0') << std::setw(8) << value;
  return os.str();
}

std::string hex_u64(uint64_t value) {
  std::ostringstream os;
  os << "64'h" << std::hex << std::setfill('0') << std::setw(16) << value;
  return os.str();
}

std::string hex_words(const std::vector<uint32_t> &words, uint32_t count) {
  std::ostringstream os;
  os << (count * 32) << "'h" << std::hex << std::setfill('0');
  for (int idx = static_cast<int>(count) - 1; idx >= 0; --idx) {
    const uint32_t word = idx < static_cast<int>(words.size()) ? words[idx] : 0;
    os << std::setw(8) << word;
  }
  return os.str();
}

std::vector<uint32_t> write_words(const axi_interconnect::WideWriteData_t &data) {
  std::vector<uint32_t> words(axi_interconnect::MAX_WRITE_TRANSACTION_WORDS);
  for (uint32_t idx = 0; idx < words.size(); ++idx) {
    words[idx] = data.words[idx];
  }
  return words;
}

axi_interconnect::WideWriteData_t patterned_line(uint32_t base) {
  axi_interconnect::WideWriteData_t data{};
  data.clear();
  for (uint32_t idx = 0; idx < axi_interconnect::MAX_WRITE_TRANSACTION_WORDS;
       ++idx) {
    data.words[idx] = base + idx;
  }
  return data;
}

axi_interconnect::WideWriteStrb_t full_line_strobe() {
  axi_interconnect::WideWriteStrb_t strobe{};
  strobe.clear();
  for (uint32_t idx = 0; idx < axi_interconnect::MAX_WRITE_TRANSACTION_BYTES;
       ++idx) {
    strobe.set(idx, true);
  }
  return strobe;
}

axi_interconnect::WideWriteData_t single_word_data(uint32_t value) {
  axi_interconnect::WideWriteData_t data{};
  data.clear();
  data.words[0] = value;
  return data;
}

axi_interconnect::WideWriteStrb_t word_strobe() {
  axi_interconnect::WideWriteStrb_t strobe{};
  strobe.clear();
  for (uint32_t idx = 0; idx < 4; ++idx) {
    strobe.set(idx, true);
  }
  return strobe;
}

void clear_downstream_responses(axi_interconnect::AXI_Interconnect &dut) {
  dut.axi_ddr_io.r.rvalid = false;
  dut.axi_ddr_io.r.rid = 0;
  dut.axi_ddr_io.r.rdata = {};
  dut.axi_ddr_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_ddr_io.r.rlast = false;
  dut.axi_ddr_io.b.bvalid = false;
  dut.axi_ddr_io.b.bid = 0;
  dut.axi_ddr_io.b.bresp = sim_ddr::AXI_RESP_OKAY;

  dut.axi_mmio_io.r.rvalid = false;
  dut.axi_mmio_io.r.rid = 0;
  dut.axi_mmio_io.r.rdata = {};
  dut.axi_mmio_io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  dut.axi_mmio_io.r.rlast = false;
  dut.axi_mmio_io.b.bvalid = false;
  dut.axi_mmio_io.b.bid = 0;
  dut.axi_mmio_io.b.bresp = sim_ddr::AXI_RESP_OKAY;
}

void clear_inputs(axi_interconnect::AXI_Interconnect &dut) {
  for (auto &port : dut.read_ports) {
    port.req.valid = false;
    port.req.addr = 0;
    port.req.total_size = 0;
    port.req.id = 0;
    port.req.bypass = false;
    port.resp.ready = true;
  }
  for (auto &port : dut.write_ports) {
    port.req.valid = false;
    port.req.addr = 0;
    port.req.wdata.clear();
    port.req.wstrb.clear();
    port.req.total_size = 0;
    port.req.id = 0;
    port.req.bypass = false;
    port.resp.ready = true;
  }
  clear_downstream_responses(dut);
  dut.axi_ddr_io.ar.arready = true;
  dut.axi_ddr_io.aw.awready = true;
  dut.axi_ddr_io.w.wready = true;
  dut.axi_mmio_io.ar.arready = true;
  dut.axi_mmio_io.aw.awready = true;
  dut.axi_mmio_io.w.wready = true;
}

void init_dut(axi_interconnect::AXI_Interconnect &dut) {
  unsetenv("AXI_SUBMODULE_MODE");
  unsetenv("AXI_SUBMODULE_OFFSET");
  axi_interconnect::AXI_LLCConfig cfg{};
  cfg.enable = false;
  dut.set_llc_config(cfg);
  dut.mode = 0;
  dut.init();
  clear_inputs(dut);
}

sim_ddr::axi_data_t perf_read_beat(uint32_t base) {
  sim_ddr::axi_data_t data{};
  for (uint32_t word = 0; word < sim_ddr::AXI_DATA_WORDS; ++word) {
    axi_compat::set_u32(data, word, base + word);
  }
  return data;
}

sim_ddr::SimDDR_IO_t &io_for(axi_interconnect::AXI_Interconnect &dut,
                             PerfPort port) {
  return port == PerfPort::DDR ? dut.axi_ddr_io : dut.axi_mmio_io;
}

void set_cycle_once(std::map<std::string, int> &cycles, const std::string &name,
                    int cycle) {
  if (cycles.find(name) == cycles.end()) {
    cycles[name] = cycle;
  }
}

void apply_read_response(axi_interconnect::AXI_Interconnect &dut,
                         const ReadBeat &beat) {
  auto &io = io_for(dut, beat.port);
  io.r.rvalid = true;
  io.r.rid = beat.id;
  io.r.rresp = sim_ddr::AXI_RESP_OKAY;
  io.r.rlast = beat.beat == beat.beats - 1;
  io.r.rdata = perf_read_beat(0x90000000u + (static_cast<uint32_t>(beat.beat)
                                             << 8));
}

void apply_write_response(axi_interconnect::AXI_Interconnect &dut,
                          const WriteResp &resp) {
  auto &io = io_for(dut, resp.port);
  io.b.bvalid = true;
  io.b.bid = resp.id;
  io.b.bresp = sim_ddr::AXI_RESP_OKAY;
}

int find_due_read(const std::vector<ReadBeat> &beats, PerfPort port, int cycle) {
  for (size_t idx = 0; idx < beats.size(); ++idx) {
    if (beats[idx].port == port && beats[idx].due_cycle <= cycle) {
      return static_cast<int>(idx);
    }
  }
  return -1;
}

int find_due_write_resp(const std::vector<WriteResp> &resps, PerfPort port,
                        int cycle) {
  for (size_t idx = 0; idx < resps.size(); ++idx) {
    if (resps[idx].port == port && resps[idx].due_cycle <= cycle) {
      return static_cast<int>(idx);
    }
  }
  return -1;
}

const ReadSpec *find_read_for_port(const Scenario &scenario,
                                   const std::vector<ReadRuntime> &runtime,
                                   PerfPort port) {
  for (size_t idx = 0; idx < scenario.reads.size(); ++idx) {
    if (!runtime[idx].ar_seen && scenario.reads[idx].port == port) {
      return &scenario.reads[idx];
    }
  }
  return nullptr;
}

ReadRuntime *runtime_for_read(const Scenario &scenario,
                              std::vector<ReadRuntime> &runtime,
                              const std::string &prefix) {
  for (size_t idx = 0; idx < scenario.reads.size(); ++idx) {
    if (scenario.reads[idx].prefix == prefix) {
      return &runtime[idx];
    }
  }
  return nullptr;
}

const WriteSpec *find_write_for_port(const Scenario &scenario,
                                     const std::vector<WriteRuntime> &runtime,
                                     PerfPort port) {
  for (size_t idx = 0; idx < scenario.writes.size(); ++idx) {
    if (!runtime[idx].aw_seen && scenario.writes[idx].port == port) {
      return &scenario.writes[idx];
    }
  }
  return nullptr;
}

WriteRuntime *runtime_for_write(const Scenario &scenario,
                                std::vector<WriteRuntime> &runtime,
                                PerfPort port) {
  for (size_t idx = 0; idx < scenario.writes.size(); ++idx) {
    if (scenario.writes[idx].port == port) {
      return &runtime[idx];
    }
  }
  return nullptr;
}

ScenarioResult run_scenario(const Scenario &scenario) {
  axi_interconnect::AXI_Interconnect dut;
  init_dut(dut);

  ScenarioResult result{};
  result.scenario = scenario;
  std::vector<ReadRuntime> read_runtime(scenario.reads.size());
  std::vector<WriteRuntime> write_runtime(scenario.writes.size());
  std::vector<ReadBeat> pending_reads;
  std::vector<WriteResp> pending_writes;
  std::array<uint8_t, 2> last_awid = {0, 0};

  for (int cycle = 0; cycle < kMaxCycles; ++cycle) {
    clear_inputs(dut);

    const int ddr_read_idx = find_due_read(pending_reads, PerfPort::DDR, cycle);
    const int mmio_read_idx = find_due_read(pending_reads, PerfPort::MMIO, cycle);
    const int ddr_b_idx = find_due_write_resp(pending_writes, PerfPort::DDR, cycle);
    const int mmio_b_idx =
        find_due_write_resp(pending_writes, PerfPort::MMIO, cycle);
    if (ddr_read_idx >= 0) {
      apply_read_response(dut, pending_reads[ddr_read_idx]);
    }
    if (mmio_read_idx >= 0) {
      apply_read_response(dut, pending_reads[mmio_read_idx]);
    }
    if (ddr_b_idx >= 0) {
      apply_write_response(dut, pending_writes[ddr_b_idx]);
    }
    if (mmio_b_idx >= 0) {
      apply_write_response(dut, pending_writes[mmio_b_idx]);
    }

    for (size_t idx = 0; idx < scenario.reads.size(); ++idx) {
      const auto &spec = scenario.reads[idx];
      if (!read_runtime[idx].ar_seen) {
        auto &req = dut.read_ports[spec.master].req;
        req.valid = true;
        req.addr = spec.addr;
        req.total_size = spec.size;
        req.id = spec.id;
        req.bypass = false;
      }
    }
    for (size_t idx = 0; idx < scenario.writes.size(); ++idx) {
      const auto &spec = scenario.writes[idx];
      if (!write_runtime[idx].aw_seen) {
        auto &req = dut.write_ports[spec.master].req;
        req.valid = true;
        req.addr = spec.addr;
        req.total_size = spec.size;
        req.id = spec.id;
        req.wdata = spec.data;
        req.wstrb = spec.strobe;
        req.bypass = false;
      }
    }

    dut.comb_outputs();
    dut.comb_inputs();

    for (const auto &spec : scenario.reads) {
      if (dut.read_ports[spec.master].req.valid &&
          dut.read_ports[spec.master].req.ready) {
        set_cycle_once(result.cycles, spec.prefix + "_REQ_READY", cycle);
      }
      if (dut.read_ports[spec.master].resp.valid &&
          dut.read_ports[spec.master].resp.ready &&
          static_cast<uint8_t>(dut.read_ports[spec.master].resp.id) == spec.id) {
        set_cycle_once(result.cycles, spec.prefix + "_RESP", cycle);
      }
    }
    for (const auto &spec : scenario.writes) {
      if (dut.write_ports[spec.master].req.valid &&
          dut.write_ports[spec.master].req.ready) {
        set_cycle_once(result.cycles, spec.prefix + "_REQ_READY", cycle);
      }
      if (dut.write_ports[spec.master].resp.valid &&
          dut.write_ports[spec.master].resp.ready &&
          static_cast<uint8_t>(dut.write_ports[spec.master].resp.id) == spec.id) {
        set_cycle_once(result.cycles, spec.prefix + "_RESP", cycle);
      }
    }

    auto observe_ar = [&](PerfPort port) {
      auto &io = io_for(dut, port);
      if (!(io.ar.arvalid && io.ar.arready)) {
        return;
      }
      const ReadSpec *spec = find_read_for_port(scenario, read_runtime, port);
      require(spec != nullptr, "unexpected C++ AR fire");
      set_cycle_once(result.cycles, spec->prefix + "_AR", cycle);
      const size_t idx = static_cast<size_t>(spec - scenario.reads.data());
      read_runtime[idx].ar_seen = true;
      const uint8_t beats = static_cast<uint8_t>(io.ar.arlen + 1);
      require(beats == spec->beats, "C++ AR beat count mismatch");
      for (uint8_t beat = 0; beat < beats; ++beat) {
        pending_reads.push_back(ReadBeat{port, cycle + kReadLatency + beat,
                                         static_cast<uint8_t>(io.ar.arid), beat,
                                         beats, spec->prefix});
      }
    };
    observe_ar(PerfPort::DDR);
    observe_ar(PerfPort::MMIO);

    auto observe_aw = [&](PerfPort port) {
      auto &io = io_for(dut, port);
      if (!(io.aw.awvalid && io.aw.awready)) {
        return;
      }
      const WriteSpec *spec = find_write_for_port(scenario, write_runtime, port);
      require(spec != nullptr, "unexpected C++ AW fire");
      set_cycle_once(result.cycles, spec->prefix + "_AW", cycle);
      const size_t idx = static_cast<size_t>(spec - scenario.writes.data());
      write_runtime[idx].aw_seen = true;
      const uint8_t beats = static_cast<uint8_t>(io.aw.awlen + 1);
      require(beats == spec->beats, "C++ AW beat count mismatch");
      last_awid[static_cast<int>(port)] = static_cast<uint8_t>(io.aw.awid);
    };
    observe_aw(PerfPort::DDR);
    observe_aw(PerfPort::MMIO);

    auto observe_w = [&](PerfPort port) {
      auto &io = io_for(dut, port);
      if (!(io.w.wvalid && io.w.wready)) {
        return;
      }
      WriteRuntime *runtime = runtime_for_write(scenario, write_runtime, port);
      require(runtime != nullptr, "unexpected C++ W fire");
      const WriteSpec *spec = find_write_for_port(scenario, write_runtime, port);
      if (spec == nullptr) {
        for (size_t idx = 0; idx < scenario.writes.size(); ++idx) {
          if (scenario.writes[idx].port == port) {
            spec = &scenario.writes[idx];
            break;
          }
        }
      }
      require(spec != nullptr, "unexpected C++ W owner");
      set_cycle_once(result.cycles,
                     spec->prefix + "_W" + std::to_string(runtime->w_seen),
                     cycle);
      runtime->w_seen++;
      if (io.w.wlast) {
        pending_writes.push_back(WriteResp{port, cycle + kWriteRespLatency,
                                           last_awid[static_cast<int>(port)],
                                           spec->prefix});
      }
    };
    observe_w(PerfPort::DDR);
    observe_w(PerfPort::MMIO);

    auto observe_r = [&](PerfPort port, int pending_idx) {
      if (pending_idx < 0) {
        return;
      }
      auto &io = io_for(dut, port);
      require(io.r.rready, "C++ lower R was unexpectedly backpressured");
      const ReadBeat &pending =
          pending_reads[static_cast<size_t>(pending_idx)];
      ReadRuntime *runtime =
          runtime_for_read(scenario, read_runtime, pending.prefix);
      require(runtime != nullptr, "unexpected C++ R owner");
      const ReadSpec *spec = nullptr;
      for (const auto &candidate : scenario.reads) {
        if (candidate.prefix == pending.prefix) {
          spec = &candidate;
          break;
        }
      }
      require(spec != nullptr, "unexpected C++ R spec");
      set_cycle_once(result.cycles,
                     spec->prefix + "_R" + std::to_string(runtime->r_seen),
                     cycle);
      runtime->r_seen++;
    };
    observe_r(PerfPort::DDR, ddr_read_idx);
    observe_r(PerfPort::MMIO, mmio_read_idx);

    auto observe_b = [&](PerfPort port, int pending_idx) {
      if (pending_idx < 0) {
        return;
      }
      auto &io = io_for(dut, port);
      require(io.b.bready, "C++ lower B was unexpectedly backpressured");
      const WriteSpec *spec = nullptr;
      for (const auto &candidate : scenario.writes) {
        if (candidate.port == port) {
          spec = &candidate;
          break;
        }
      }
      require(spec != nullptr, "unexpected C++ B owner");
      set_cycle_once(result.cycles, spec->prefix + "_B", cycle);
    };
    observe_b(PerfPort::DDR, ddr_b_idx);
    observe_b(PerfPort::MMIO, mmio_b_idx);

    dut.seq();
    ++sim_time;

    if (ddr_read_idx >= 0) {
      pending_reads.erase(pending_reads.begin() + ddr_read_idx);
    }
    if (mmio_read_idx >= 0) {
      const int adjusted = mmio_read_idx > ddr_read_idx && ddr_read_idx >= 0
                               ? mmio_read_idx - 1
                               : mmio_read_idx;
      pending_reads.erase(pending_reads.begin() + adjusted);
    }
    if (ddr_b_idx >= 0) {
      pending_writes.erase(pending_writes.begin() + ddr_b_idx);
    }
    if (mmio_b_idx >= 0) {
      const int adjusted = mmio_b_idx > ddr_b_idx && ddr_b_idx >= 0
                               ? mmio_b_idx - 1
                               : mmio_b_idx;
      pending_writes.erase(pending_writes.begin() + adjusted);
    }
  }

  for (const auto &spec : scenario.reads) {
    for (const auto &event : {"_REQ_READY", "_AR", "_R0", "_RESP"}) {
      require(result.cycles.count(spec.prefix + event) != 0,
              "missing C++ read perf event");
    }
    if (spec.beats > 1) {
      require(result.cycles.count(spec.prefix + "_R1") != 0,
              "missing C++ read second beat perf event");
    }
  }
  for (const auto &spec : scenario.writes) {
    for (const auto &event : {"_REQ_READY", "_AW", "_W0", "_B", "_RESP"}) {
      require(result.cycles.count(spec.prefix + event) != 0,
              "missing C++ write perf event");
    }
    if (spec.beats > 1) {
      require(result.cycles.count(spec.prefix + "_W1") != 0,
              "missing C++ write second beat perf event");
    }
  }

  return result;
}

int cycle_or_neg1(const std::map<std::string, int> &cycles,
                  const std::string &key) {
  const auto it = cycles.find(key);
  return it == cycles.end() ? -1 : it->second;
}

void emit_read_spec(std::ostream &os, const ReadSpec &spec,
                    const std::map<std::string, int> &cycles) {
  os << "\nlocalparam integer " << spec.prefix << "_MASTER = "
     << static_cast<unsigned>(spec.master) << ";\n";
  os << "localparam integer " << spec.prefix << "_PORT = "
     << static_cast<unsigned>(spec.port == PerfPort::DDR ? 0 : 1) << ";\n";
  os << "localparam [31:0] " << spec.prefix
     << "_REQ_ADDR = " << hex_u32(spec.addr) << ";\n";
  os << "localparam [7:0] " << spec.prefix
     << "_REQ_SIZE = 8'd" << static_cast<unsigned>(spec.size) << ";\n";
  os << "localparam [3:0] " << spec.prefix
     << "_REQ_ID = 4'd" << static_cast<unsigned>(spec.id) << ";\n";
  os << "localparam integer " << spec.prefix
     << "_BEATS = " << static_cast<unsigned>(spec.beats) << ";\n";
  for (const auto &event : {"REQ_READY", "AR", "R0", "R1", "RESP"}) {
    os << "localparam integer " << spec.prefix << "_" << event
       << "_CYCLE = " << cycle_or_neg1(cycles, spec.prefix + "_" + event)
       << ";\n";
  }
}

void emit_write_spec(std::ostream &os, const WriteSpec &spec,
                     const std::map<std::string, int> &cycles) {
  os << "\nlocalparam integer " << spec.prefix << "_MASTER = "
     << static_cast<unsigned>(spec.master) << ";\n";
  os << "localparam integer " << spec.prefix << "_PORT = "
     << static_cast<unsigned>(spec.port == PerfPort::DDR ? 0 : 1) << ";\n";
  os << "localparam [31:0] " << spec.prefix
     << "_REQ_ADDR = " << hex_u32(spec.addr) << ";\n";
  os << "localparam [7:0] " << spec.prefix
     << "_REQ_SIZE = 8'd" << static_cast<unsigned>(spec.size) << ";\n";
  os << "localparam [3:0] " << spec.prefix
     << "_REQ_ID = 4'd" << static_cast<unsigned>(spec.id) << ";\n";
  os << "localparam [511:0] " << spec.prefix
     << "_REQ_WDATA = " << hex_words(write_words(spec.data), 16) << ";\n";
  os << "localparam [63:0] " << spec.prefix
     << "_REQ_WSTRB = " << hex_u64(static_cast<uint64_t>(spec.strobe))
     << ";\n";
  os << "localparam integer " << spec.prefix
     << "_BEATS = " << static_cast<unsigned>(spec.beats) << ";\n";
  for (const auto &event : {"REQ_READY", "AW", "W0", "W1", "B", "RESP"}) {
    os << "localparam integer " << spec.prefix << "_" << event
       << "_CYCLE = " << cycle_or_neg1(cycles, spec.prefix + "_" + event)
       << ";\n";
  }
}

std::vector<Scenario> build_scenarios() {
  return {
      Scenario{
          "READ64_DDR",
          {ReadSpec{"CPP_PERF_READ64_DDR",
                    axi_interconnect::MASTER_DCACHE_R, PerfPort::DDR,
                    0x40001000u, 63, 3, 2}},
          {}},
      Scenario{
          "WRITE64_DDR",
          {},
          {WriteSpec{"CPP_PERF_WRITE64_DDR",
                     axi_interconnect::MASTER_DCACHE_W, PerfPort::DDR,
                     0x40002000u, 63, 4, 2, patterned_line(0x50000000u),
                     full_line_strobe()}}},
      Scenario{
          "OVERLAP_READ",
          {ReadSpec{"CPP_PERF_OVERLAP_READ_DDR",
                    axi_interconnect::MASTER_DCACHE_R, PerfPort::DDR,
                    0x40003000u, 63, 5, 2},
           ReadSpec{"CPP_PERF_OVERLAP_READ_MMIO",
                    axi_interconnect::MASTER_UNCORE_LSU_R, PerfPort::MMIO,
                    0x10000040u, 3, 6, 1}},
          {}},
      Scenario{
          "OVERLAP_WRITE",
          {},
          {WriteSpec{"CPP_PERF_OVERLAP_WRITE_DDR",
                     axi_interconnect::MASTER_DCACHE_W, PerfPort::DDR,
                     0x40004000u, 63, 7, 2, patterned_line(0x60000000u),
                     full_line_strobe()},
           WriteSpec{"CPP_PERF_OVERLAP_WRITE_MMIO",
                     axi_interconnect::MASTER_UNCORE_LSU_W, PerfPort::MMIO,
                     0x10000050u, 3, 8, 1, single_word_data(0xdead0050u),
                     word_strobe()}}},
  };
}

void emit_header(std::ostream &os, const std::vector<ScenarioResult> &results) {
  os << "`ifndef AXI_DUAL_CPP_PERF_VECTORS_VH\n";
  os << "`define AXI_DUAL_CPP_PERF_VECTORS_VH\n";
  os << "// Generated by axi_interconnect_dual_port_perf_vectors_test.cpp from\n";
  os << "// the production AXI_Interconnect comb/seq model. Do not hand-edit\n";
  os << "// expected cycle values in this file; regenerate them from C++.\n\n";
  os << "localparam integer CPP_PERF_READ_LATENCY = " << kReadLatency << ";\n";
  os << "localparam integer CPP_PERF_WRITE_RESP_LATENCY = "
     << kWriteRespLatency << ";\n";
  for (const auto &result : results) {
    os << "\n// Scenario: " << result.scenario.name << "\n";
    for (const auto &read : result.scenario.reads) {
      emit_read_spec(os, read, result.cycles);
    }
    for (const auto &write : result.scenario.writes) {
      emit_write_spec(os, write, result.cycles);
    }
  }
  os << "\n`endif\n";
}

} // namespace

int main(int argc, char **argv) {
  const char *out_path =
      argc > 1 ? argv[1] : "rtl/include/axi_dual_cpp_perf_vectors.vh";
  std::vector<ScenarioResult> results;
  for (const auto &scenario : build_scenarios()) {
    results.push_back(run_scenario(scenario));
  }
  std::ofstream out(out_path);
  if (!out) {
    throw std::runtime_error("failed to open output perf vector header");
  }
  emit_header(out, results);
  return 0;
}
