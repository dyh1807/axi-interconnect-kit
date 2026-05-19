#pragma once

#include <stdbool.h>
#include <stdint.h>

#define AXI_DUAL_PORT_MMIO_TOTAL_SIZE 3u
#define AXI_DUAL_PORT_AXI_SIZE_32B 2u
#define AXI_DUAL_PORT_AXI_SIZE_256B 5u
#define AXI_DUAL_PORT_DDR_BEAT_BYTES 32u
#define AXI_DUAL_PORT_AXI_ID_MASK_FOR_WIDTH(width) \
  ((uint32_t)((width) >= 8u ? 0xFFu : ((1u << (width)) - 1u)))

typedef struct AxiDualPortRouteShape {
  bool ddr_port;
  bool mmio_port;
  bool supported;
  uint8_t axi_len;
  uint8_t axi_size;
} AxiDualPortRouteShape;

typedef struct AxiDualPortRouteSupport {
  bool ddr_port;
  bool mmio_port;
  bool supported;
} AxiDualPortRouteSupport;

typedef struct AxiDualPortAxiBeatShape {
  uint8_t total_beats;
  uint8_t axi_len;
  uint8_t axi_size;
} AxiDualPortAxiBeatShape;

typedef struct AxiDualPortIssueGateResult {
  bool bridge_arready;
  bool axi_arvalid;
  bool bridge_awready;
  bool axi_awvalid;
  bool ar_hazard;
  bool ar_would_issue;
  bool aw_same_cycle_read_hazard;
  bool aw_hazard;
  bool ar_fire;
  bool aw_fire;
} AxiDualPortIssueGateResult;

typedef struct AxiDualPortReqSteerResult {
  bool ddr_req_valid;
  bool mmio_req_valid;
  bool req_ready;
} AxiDualPortReqSteerResult;

typedef struct AxiDualPortRespMuxControl {
  bool ddr_resp_ready;
  bool mmio_resp_ready;
  bool resp_valid;
  bool select_mmio;
} AxiDualPortRespMuxControl;

typedef struct AxiBridgeRespAcceptControl {
  bool axi_rready;
  bool rd_resp_accept;
  bool axi_bready;
  bool wr_resp_accept;
} AxiBridgeRespAcceptControl;

typedef struct AxiBridgeReqAcceptControl {
  bool accept_cache;
  bool accept_bypass;
  bool accept_write;
  uint8_t accept_slot;
  uint8_t accept_axi_id;
  uint8_t accept_total_beats;
} AxiBridgeReqAcceptControl;

typedef struct AxiBridgePendingScanResult {
  bool free_found;
  uint8_t free_slot;
  bool axi_id_found;
  uint8_t axi_id;
  bool match_found;
  uint8_t match_slot;
  bool complete_found;
  uint8_t complete_slot;
} AxiBridgePendingScanResult;

typedef struct AxiBridgeIssueSelectControl {
  bool issue_valid;
  bool issue_mode2_ddr_aligned;
  uint32_t issue_addr;
  uint8_t issue_size;
  uint8_t issue_axi_id;
  uint8_t issue_beat_idx;
  uint8_t issue_total_beats;
} AxiBridgeIssueSelectControl;

typedef struct AxiBridgeMode2Shape {
  bool single_axi_beat;
  uint32_t issue_addr;
  uint8_t issue_size;
} AxiBridgeMode2Shape;

typedef struct AxiBridgeDownstreamIssueShape {
  uint32_t issue_addr;
  uint8_t issue_size;
  bool extract_from_aligned_beat;
  uint8_t total_beats;
  uint8_t axi_len;
  uint8_t axi_size;
} AxiBridgeDownstreamIssueShape;

typedef struct AxiBridgeSourceRespMuxControl {
  bool resp_valid;
  bool select_read;
  bool rd_pop;
  bool wr_pop;
} AxiBridgeSourceRespMuxControl;

typedef struct AxiBridgeRespRouteControl {
  bool rd_complete_rsp_space;
  bool rd_complete_push;
  bool cache_rd_rsp_push;
  bool bypass_rd_rsp_push;
  bool wr_match_rsp_space;
  bool cache_wr_rsp_push;
  bool bypass_wr_rsp_push;
} AxiBridgeRespRouteControl;

typedef struct AxiBridgeFifoPtrControl {
  uint8_t next_head;
  uint8_t next_tail;
  uint8_t next_count;
} AxiBridgeFifoPtrControl;

typedef struct AxiBridgeWritePack64 {
  uint64_t axi_wdata;
  uint32_t axi_wstrb;
} AxiBridgeWritePack64;

typedef struct AxiBridgeReadPack64 {
  uint64_t merged_data;
  uint64_t final_data;
} AxiBridgeReadPack64;

typedef struct AxiBridgeReadRespControl {
  bool rd_last_beat;
  uint8_t next_resp_code;
} AxiBridgeReadRespControl;

typedef struct AxiBridgeQueueControl {
  bool rd_issue_space;
  bool wr_aw_space;
  bool wr_w_space;
  bool cache_rd_rsp_valid;
  bool bypass_rd_rsp_valid;
  bool cache_wr_rsp_valid;
  bool bypass_wr_rsp_valid;
  bool cache_rd_rsp_space;
  bool bypass_rd_rsp_space;
  bool cache_wr_rsp_space;
  bool bypass_wr_rsp_space;
  bool rd_issue_handshake;
  bool wr_aw_handshake;
  bool wr_w_handshake;
  bool rd_issue_push;
  bool rd_issue_pop;
  bool wr_aw_push;
  bool wr_aw_pop;
  bool wr_w_push;
  bool wr_w_pop;
} AxiBridgeQueueControl;

typedef struct AxiDualPortSlotHazardResult {
  bool primary_slot_hazard;
  bool secondary_slot_hazard;
} AxiDualPortSlotHazardResult;

typedef struct AxiDualPortHazardMatchResult {
  bool ddr_line_match;
  bool mmio_line_match;
  bool ddr_id_match;
  bool mmio_id_match;
} AxiDualPortHazardMatchResult;

static inline bool axi_dual_port_is_ddr_addr(uint32_t addr,
                                             uint32_t ddr_base) {
  return addr >= ddr_base;
}

static inline bool axi_dual_port_mmio_request_supported(uint8_t total_size) {
  return total_size == AXI_DUAL_PORT_MMIO_TOTAL_SIZE;
}

static inline uint8_t axi_dual_port_axi_size_for_beat_bytes(uint8_t beat_bytes) {
  if (beat_bytes == 32u) {
    return 5u;
  }
  if (beat_bytes == 16u) {
    return 4u;
  }
  if (beat_bytes == 8u) {
    return 3u;
  }
  return 2u;
}

static inline uint8_t
axi_dual_port_axi_len_for_beat_bytes(uint8_t total_size, uint8_t beat_bytes) {
  if (beat_bytes == 0u) {
    return 0u;
  }
  const uint32_t bytes = (uint32_t)total_size + 1u;
  const uint32_t beats = (bytes + (uint32_t)beat_bytes - 1u) /
                         (uint32_t)beat_bytes;
  return beats > 0u ? (uint8_t)(beats - 1u) : 0u;
}

static inline AxiDualPortAxiBeatShape
axi_dual_port_axi_beat_shape(uint8_t total_size, uint8_t beat_bytes) {
  AxiDualPortAxiBeatShape out;
  out.axi_len = axi_dual_port_axi_len_for_beat_bytes(total_size, beat_bytes);
  out.total_beats = (uint8_t)(out.axi_len + 1u);
  out.axi_size = axi_dual_port_axi_size_for_beat_bytes(beat_bytes);
  return out;
}

static inline AxiDualPortRouteSupport
axi_dual_port_route_support(uint32_t addr, uint8_t total_size,
                            uint32_t ddr_base) {
  AxiDualPortRouteSupport out;
  out.ddr_port = axi_dual_port_is_ddr_addr(addr, ddr_base);
  out.mmio_port = !out.ddr_port;
  out.supported =
      out.ddr_port || axi_dual_port_mmio_request_supported(total_size);
  return out;
}

static inline uint8_t axi_dual_port_ddr_axi_len(uint8_t total_size) {
  return axi_dual_port_axi_len_for_beat_bytes(
      total_size, AXI_DUAL_PORT_DDR_BEAT_BYTES);
}

static inline AxiDualPortRouteShape
axi_dual_port_route_shape(uint32_t addr, uint8_t total_size,
                          uint32_t ddr_base) {
  AxiDualPortRouteShape out;
  const AxiDualPortRouteSupport route =
      axi_dual_port_route_support(addr, total_size, ddr_base);
  out.ddr_port = route.ddr_port;
  out.mmio_port = route.mmio_port;
  out.supported = route.supported;
  out.axi_len = out.ddr_port ? axi_dual_port_ddr_axi_len(total_size) : 0u;
  out.axi_size = out.ddr_port ? AXI_DUAL_PORT_AXI_SIZE_256B
                              : AXI_DUAL_PORT_AXI_SIZE_32B;
  return out;
}

static inline uint8_t axi_dual_port_mask_axi_id(uint8_t id_value,
                                                uint8_t id_width) {
  return (uint8_t)(id_value & AXI_DUAL_PORT_AXI_ID_MASK_FOR_WIDTH(id_width));
}

static inline uint8_t axi_dual_port_resize_axi_id(uint8_t id_value,
                                                  uint8_t in_id_width,
                                                  uint8_t out_id_width) {
  const uint8_t masked_input =
      axi_dual_port_mask_axi_id(id_value, in_id_width);
  return axi_dual_port_mask_axi_id(masked_input, out_id_width);
}

static inline AxiDualPortIssueGateResult axi_dual_port_issue_gate(
    bool bridge_arvalid, bool axi_arready, uint32_t ar_line,
    bool ar_slot_hazard, bool ar_pending_write_hazard, bool bridge_awvalid,
    bool axi_awready, uint32_t aw_line, bool aw_slot_hazard,
    bool aw_pending_read_hazard) {
  AxiDualPortIssueGateResult out;
  out.ar_hazard = ar_slot_hazard || ar_pending_write_hazard;
  out.ar_would_issue = bridge_arvalid && !out.ar_hazard;
  out.aw_same_cycle_read_hazard = out.ar_would_issue && (ar_line == aw_line);
  out.aw_hazard =
      aw_slot_hazard || aw_pending_read_hazard ||
      out.aw_same_cycle_read_hazard;
  out.bridge_arready = axi_arready && !out.ar_hazard;
  out.axi_arvalid = bridge_arvalid && !out.ar_hazard;
  out.bridge_awready = axi_awready && !out.aw_hazard;
  out.axi_awvalid = bridge_awvalid && !out.aw_hazard;
  out.ar_fire = out.axi_arvalid && axi_arready;
  out.aw_fire = out.axi_awvalid && axi_awready;
  return out;
}

static inline AxiDualPortReqSteerResult axi_dual_port_req_steer(
    bool req_valid, bool req_to_ddr, bool req_supported, bool ddr_req_ready,
    bool mmio_req_ready) {
  AxiDualPortReqSteerResult out;
  out.ddr_req_valid = req_valid && req_to_ddr;
  out.mmio_req_valid = req_valid && !req_to_ddr && req_supported;
  out.req_ready = req_to_ddr ? ddr_req_ready :
                               (req_supported && mmio_req_ready);
  return out;
}

static inline AxiDualPortRespMuxControl axi_dual_port_resp_mux_control(
    bool ddr_resp_valid, bool mmio_resp_valid, bool resp_ready) {
  AxiDualPortRespMuxControl out;
  out.select_mmio = mmio_resp_valid;
  out.resp_valid = out.select_mmio ? mmio_resp_valid : ddr_resp_valid;
  out.mmio_resp_ready = out.select_mmio && resp_ready;
  out.ddr_resp_ready = !out.select_mmio && resp_ready;
  return out;
}

static inline AxiBridgeRespAcceptControl axi_bridge_resp_accept_control(
    bool axi_rvalid, bool rd_match_found, bool axi_bvalid,
    bool wr_match_found, bool wr_match_rsp_space) {
  AxiBridgeRespAcceptControl out;
  out.axi_rready = rd_match_found;
  out.rd_resp_accept = axi_rvalid && rd_match_found;
  out.axi_bready = wr_match_found && wr_match_rsp_space;
  out.wr_resp_accept = axi_bvalid && wr_match_found && wr_match_rsp_space;
  return out;
}

static inline AxiBridgeReqAcceptControl axi_bridge_req_accept_control(
    bool cache_req_valid, bool cache_req_write, uint8_t cache_total_beats,
    bool bypass_req_valid, bool bypass_req_write, uint8_t bypass_total_beats,
    bool rd_free_found, uint8_t rd_free_slot, bool rd_axi_id_found,
    uint8_t rd_axi_id, bool rd_issue_space, bool wr_free_found,
    uint8_t wr_free_slot, bool wr_axi_id_found, uint8_t wr_axi_id,
    bool wr_aw_space, bool wr_w_space) {
  AxiBridgeReqAcceptControl out;
  out.accept_cache = false;
  out.accept_bypass = false;
  out.accept_write = false;
  out.accept_slot = 0u;
  out.accept_axi_id = 0u;
  out.accept_total_beats = 0u;

  if (cache_req_valid) {
    if (cache_req_write) {
      if (wr_free_found && wr_axi_id_found && wr_aw_space && wr_w_space) {
        out.accept_cache = true;
        out.accept_write = true;
        out.accept_slot = wr_free_slot;
        out.accept_axi_id = wr_axi_id;
        out.accept_total_beats = cache_total_beats;
      }
    } else if (rd_free_found && rd_axi_id_found && rd_issue_space) {
      out.accept_cache = true;
      out.accept_write = false;
      out.accept_slot = rd_free_slot;
      out.accept_axi_id = rd_axi_id;
      out.accept_total_beats = cache_total_beats;
    }
  } else if (bypass_req_valid) {
    if (bypass_req_write) {
      if (wr_free_found && wr_axi_id_found && wr_aw_space && wr_w_space) {
        out.accept_bypass = true;
        out.accept_write = true;
        out.accept_slot = wr_free_slot;
        out.accept_axi_id = wr_axi_id;
        out.accept_total_beats = bypass_total_beats;
      }
    } else if (rd_free_found && rd_axi_id_found && rd_issue_space) {
      out.accept_bypass = true;
      out.accept_write = false;
      out.accept_slot = rd_free_slot;
      out.accept_axi_id = rd_axi_id;
      out.accept_total_beats = bypass_total_beats;
    }
  }

  return out;
}

static inline uint8_t axi_bridge_scan_packed_id(uint64_t packed_ids,
                                                uint8_t slot,
                                                uint8_t id_width) {
  const uint8_t shift = (uint8_t)(slot * id_width);
  return axi_dual_port_mask_axi_id((uint8_t)(packed_ids >> shift), id_width);
}

static inline AxiBridgePendingScanResult axi_bridge_pending_scan_control(
    uint8_t entry_count, uint8_t id_width, uint32_t valid_mask,
    uint32_t complete_mask, uint64_t packed_ids, uint8_t match_id) {
  AxiBridgePendingScanResult out;
  uint64_t used_ids = 0u;
  const uint16_t id_count = (uint16_t)(1u << id_width);
  const bool slot_id_mode = id_count >= entry_count;
  const uint8_t masked_match_id =
      axi_dual_port_mask_axi_id(match_id, id_width);
  out.free_found = false;
  out.free_slot = 0u;
  out.axi_id_found = false;
  out.axi_id = 0u;
  out.match_found = false;
  out.match_slot = 0u;
  out.complete_found = false;
  out.complete_slot = 0u;

  for (uint8_t slot = 0u; slot < entry_count; ++slot) {
    const bool valid = ((valid_mask >> slot) & 1u) != 0u;
    const uint8_t slot_id =
        slot_id_mode ? slot : axi_bridge_scan_packed_id(packed_ids, slot, id_width);
    if (!out.free_found && !valid) {
      out.free_found = true;
      out.free_slot = slot;
    }
    if (valid && !slot_id_mode) {
      used_ids |= (1ull << slot_id);
    }
    if (!out.match_found && valid && (slot_id == masked_match_id)) {
      out.match_found = true;
      out.match_slot = slot;
    }
    if (!out.complete_found && valid &&
        (((complete_mask >> slot) & 1u) != 0u)) {
      out.complete_found = true;
      out.complete_slot = slot;
    }
  }

  if (slot_id_mode) {
    out.axi_id_found = out.free_found;
    out.axi_id = axi_dual_port_mask_axi_id(out.free_slot, id_width);
  } else {
    for (uint16_t id = 0u; id < id_count; ++id) {
      if (!out.axi_id_found && (((used_ids >> id) & 1ull) == 0u)) {
        out.axi_id_found = true;
        out.axi_id = (uint8_t)id;
      }
    }
  }

  return out;
}

static inline uint32_t axi_bridge_align_down_addr(uint32_t addr,
                                                  uint8_t align_bytes) {
  if (align_bytes <= 1u) {
    return addr;
  }
  return (addr / (uint32_t)align_bytes) * (uint32_t)align_bytes;
}

static inline bool axi_bridge_mode2_single_axi_beat(uint32_t addr,
                                                    uint8_t total_size,
                                                    uint8_t axi_data_bytes) {
  const uint16_t req_bytes = (uint16_t)total_size + 1u;
  const uint32_t beat_addr =
      axi_bridge_align_down_addr(addr, axi_data_bytes);
  const uint32_t end_byte = (addr - beat_addr) + (uint32_t)req_bytes;
  return (req_bytes <= (uint16_t)axi_data_bytes) &&
         (end_byte <= (uint32_t)axi_data_bytes);
}

static inline uint32_t axi_bridge_mode2_issue_addr(uint32_t addr,
                                                   uint8_t total_size,
                                                   uint8_t line_bytes,
                                                   uint8_t axi_data_bytes) {
  if (axi_bridge_mode2_single_axi_beat(addr, total_size, axi_data_bytes)) {
    return axi_bridge_align_down_addr(addr, axi_data_bytes);
  }
  return axi_bridge_align_down_addr(addr, line_bytes);
}

static inline uint8_t axi_bridge_mode2_issue_size(uint32_t addr,
                                                  uint8_t total_size,
                                                  uint8_t line_bytes,
                                                  uint8_t axi_data_bytes) {
  if (axi_bridge_mode2_single_axi_beat(addr, total_size, axi_data_bytes)) {
    return (uint8_t)(axi_data_bytes - 1u);
  }
  return (uint8_t)(line_bytes - 1u);
}

static inline AxiBridgeMode2Shape axi_bridge_mode2_shape(
    uint32_t addr, uint8_t total_size, uint8_t line_bytes,
    uint8_t axi_data_bytes) {
  AxiBridgeMode2Shape out;
  out.single_axi_beat =
      axi_bridge_mode2_single_axi_beat(addr, total_size, axi_data_bytes);
  out.issue_addr = out.single_axi_beat
                       ? axi_bridge_align_down_addr(addr, axi_data_bytes)
                       : axi_bridge_align_down_addr(addr, line_bytes);
  out.issue_size =
      out.single_axi_beat ? (uint8_t)(axi_data_bytes - 1u)
                          : (uint8_t)(line_bytes - 1u);
  return out;
}

static inline AxiBridgeDownstreamIssueShape
axi_bridge_downstream_read_issue_shape(bool mmio_port, uint32_t addr,
                                       uint8_t total_size,
                                       uint8_t line_bytes,
                                       uint8_t axi_data_bytes,
                                       bool force_ddr_aligned) {
  AxiBridgeDownstreamIssueShape out;
  out.issue_addr = addr;
  out.issue_size = total_size;
  out.extract_from_aligned_beat = false;

  if (mmio_port) {
    out.issue_size = AXI_DUAL_PORT_MMIO_TOTAL_SIZE;
  } else if (force_ddr_aligned) {
    const AxiBridgeMode2Shape mode2 =
        axi_bridge_mode2_shape(addr, total_size, line_bytes, axi_data_bytes);
    out.issue_addr = mode2.issue_addr;
    out.issue_size = mode2.issue_size;
    out.extract_from_aligned_beat =
        mode2.single_axi_beat || (out.issue_addr != addr);
  } else if (((uint16_t)total_size + 1u) <= (uint16_t)axi_data_bytes) {
    out.issue_addr = axi_bridge_align_down_addr(addr, axi_data_bytes);
    out.issue_size = (uint8_t)(axi_data_bytes - 1u);
    out.extract_from_aligned_beat = true;
  }

  const AxiDualPortAxiBeatShape beat =
      axi_dual_port_axi_beat_shape(out.issue_size,
                                   mmio_port ? 4u : axi_data_bytes);
  out.total_beats = beat.total_beats;
  out.axi_len = beat.axi_len;
  out.axi_size = mmio_port ? AXI_DUAL_PORT_AXI_SIZE_32B : beat.axi_size;
  return out;
}

static inline AxiBridgeDownstreamIssueShape
axi_bridge_downstream_write_issue_shape(bool mmio_port, uint32_t addr,
                                        uint8_t total_size,
                                        uint8_t line_bytes,
                                        uint8_t axi_data_bytes,
                                        bool force_ddr_aligned) {
  AxiBridgeDownstreamIssueShape out =
      axi_bridge_downstream_read_issue_shape(mmio_port, addr, total_size,
                                             line_bytes, axi_data_bytes,
                                             force_ddr_aligned);
  out.extract_from_aligned_beat = false;
  return out;
}

static inline AxiBridgeIssueSelectControl axi_bridge_issue_select_control(
    bool queue_has_entry, bool slot_valid, bool slot_from_cache,
    bool slot_mode2_ddr_aligned, bool ready_to_issue, bool issue_done,
    uint32_t slot_addr, uint8_t slot_size, uint8_t slot_axi_id,
    uint8_t slot_beat_idx, uint8_t slot_total_beats, uint8_t line_bytes,
    uint8_t axi_data_bytes) {
  AxiBridgeIssueSelectControl out;
  out.issue_valid =
      queue_has_entry && slot_valid && ready_to_issue && !issue_done;
  out.issue_mode2_ddr_aligned = !slot_from_cache && slot_mode2_ddr_aligned;
  const AxiBridgeMode2Shape mode2 =
      axi_bridge_mode2_shape(slot_addr, slot_size, line_bytes, axi_data_bytes);
  out.issue_addr = out.issue_mode2_ddr_aligned ? mode2.issue_addr : slot_addr;
  out.issue_size = out.issue_mode2_ddr_aligned ? mode2.issue_size : slot_size;
  out.issue_axi_id = slot_axi_id;
  out.issue_beat_idx = slot_beat_idx;
  out.issue_total_beats = slot_total_beats;
  return out;
}

static inline AxiBridgeSourceRespMuxControl axi_bridge_source_resp_mux_control(
    bool rd_valid, bool wr_valid, bool resp_ready) {
  AxiBridgeSourceRespMuxControl out;
  out.select_read = rd_valid;
  out.resp_valid = rd_valid || wr_valid;
  out.rd_pop = out.resp_valid && resp_ready && out.select_read;
  out.wr_pop = out.resp_valid && resp_ready && !out.select_read && wr_valid;
  return out;
}

static inline AxiBridgeRespRouteControl axi_bridge_resp_route_control(
    bool rd_complete_found, bool rd_complete_from_cache,
    bool cache_rd_rsp_space, bool bypass_rd_rsp_space,
    bool wr_match_from_cache, bool cache_wr_rsp_space,
    bool bypass_wr_rsp_space, bool wr_resp_accept) {
  AxiBridgeRespRouteControl out;
  out.rd_complete_rsp_space =
      rd_complete_from_cache ? cache_rd_rsp_space : bypass_rd_rsp_space;
  out.rd_complete_push = rd_complete_found && out.rd_complete_rsp_space;
  out.cache_rd_rsp_push = out.rd_complete_push && rd_complete_from_cache;
  out.bypass_rd_rsp_push = out.rd_complete_push && !rd_complete_from_cache;
  out.wr_match_rsp_space =
      wr_match_from_cache ? cache_wr_rsp_space : bypass_wr_rsp_space;
  out.cache_wr_rsp_push = wr_resp_accept && wr_match_from_cache;
  out.bypass_wr_rsp_push = wr_resp_accept && !wr_match_from_cache;
  return out;
}

static inline uint8_t axi_bridge_next_ptr(uint8_t ptr_value, uint8_t depth) {
  if (depth <= 1u) {
    return 0u;
  }
  return (ptr_value == (uint8_t)(depth - 1u)) ? 0u : (uint8_t)(ptr_value + 1u);
}

static inline AxiBridgeFifoPtrControl axi_bridge_fifo_ptr_control(
    uint8_t head, uint8_t tail, uint8_t count, bool push, bool pop,
    uint8_t depth) {
  AxiBridgeFifoPtrControl out;
  out.next_head = pop ? axi_bridge_next_ptr(head, depth) : head;
  out.next_tail = push ? axi_bridge_next_ptr(tail, depth) : tail;
  if (push && !pop) {
    out.next_count = (uint8_t)(count + 1u);
  } else if (!push && pop) {
    out.next_count = (uint8_t)(count - 1u);
  } else {
    out.next_count = count;
  }
  return out;
}

static inline uint8_t axi_bridge_get_byte64(uint64_t value, uint8_t byte_idx) {
  if (byte_idx >= 8u) {
    return 0u;
  }
  return (uint8_t)((value >> ((uint32_t)byte_idx * 8u)) & 0xFFu);
}

static inline uint64_t axi_bridge_set_byte64(uint64_t value, uint8_t byte_idx,
                                             uint8_t byte_value) {
  if (byte_idx >= 8u) {
    return value;
  }
  const uint32_t shift = (uint32_t)byte_idx * 8u;
  const uint64_t mask = 0xFFull << shift;
  return (value & ~mask) | (((uint64_t)byte_value << shift) & mask);
}

static inline AxiBridgeWritePack64 axi_bridge_write_pack64(
    uint64_t line_data, uint32_t line_strb, uint32_t req_addr,
    uint32_t issued_addr, uint8_t beat_idx, bool mode2_ddr_aligned,
    uint8_t line_bytes, uint8_t axi_data_bytes) {
  AxiBridgeWritePack64 out;
  out.axi_wdata = 0u;
  out.axi_wstrb = 0u;
  const int32_t byte_off = (int32_t)(req_addr - issued_addr);

  for (uint8_t byte_idx = 0; byte_idx < axi_data_bytes; ++byte_idx) {
    const int32_t dst_byte =
        (int32_t)((uint32_t)beat_idx * (uint32_t)axi_data_bytes +
                  (uint32_t)byte_idx);
    const int32_t src_byte =
        mode2_ddr_aligned ? (dst_byte - byte_off) : dst_byte;
    if (src_byte >= 0 && src_byte < (int32_t)line_bytes) {
      out.axi_wdata = axi_bridge_set_byte64(
          out.axi_wdata, byte_idx,
          axi_bridge_get_byte64(line_data, (uint8_t)src_byte));
      if (((line_strb >> (uint32_t)src_byte) & 1u) != 0u) {
        out.axi_wstrb |= (uint32_t)(1u << byte_idx);
      }
    }
  }
  return out;
}

static inline AxiBridgeReadPack64 axi_bridge_read_pack64(
    uint64_t current_data, uint64_t beat_data, uint32_t req_addr,
    uint32_t issued_addr, uint8_t beat_idx, bool mode2_ddr_aligned,
    uint8_t read_resp_bytes, uint8_t axi_data_bytes) {
  AxiBridgeReadPack64 out;
  out.merged_data = current_data;
  out.final_data = 0u;
  const int32_t byte_off = (int32_t)(req_addr - issued_addr);

  for (uint8_t byte_idx = 0; byte_idx < axi_data_bytes; ++byte_idx) {
    const int32_t dst_byte =
        (int32_t)((uint32_t)beat_idx * (uint32_t)axi_data_bytes +
                  (uint32_t)byte_idx);
    if (dst_byte >= 0 && dst_byte < (int32_t)read_resp_bytes) {
      out.merged_data = axi_bridge_set_byte64(
          out.merged_data, (uint8_t)dst_byte,
          axi_bridge_get_byte64(beat_data, byte_idx));
    }
  }

  if (!mode2_ddr_aligned) {
    out.final_data = out.merged_data;
    return out;
  }

  for (uint8_t dst_byte = 0; dst_byte < read_resp_bytes; ++dst_byte) {
    const int32_t src_byte = (int32_t)dst_byte + byte_off;
    if (src_byte >= 0 && src_byte < (int32_t)read_resp_bytes) {
      out.final_data = axi_bridge_set_byte64(
          out.final_data, dst_byte,
          axi_bridge_get_byte64(out.merged_data, (uint8_t)src_byte));
    }
  }
  return out;
}

static inline AxiBridgeReadRespControl axi_bridge_read_resp_control(
    bool rd_match_found, uint8_t rd_beats_done, uint8_t rd_total_beats,
    bool axi_rlast, uint8_t axi_rresp, uint8_t current_resp_code) {
  AxiBridgeReadRespControl out;
  out.rd_last_beat =
      rd_match_found &&
      (((uint8_t)(rd_beats_done + 1u) == rd_total_beats) || axi_rlast);
  out.next_resp_code = ((axi_rresp & 3u) != 0u)
                           ? (uint8_t)(axi_rresp & 3u)
                           : (uint8_t)(current_resp_code & 3u);
  return out;
}

static inline AxiBridgeQueueControl axi_bridge_queue_control(
    uint8_t rd_issue_count, uint8_t wr_aw_count, uint8_t wr_w_count,
    uint8_t cache_rd_rsp_count, uint8_t bypass_rd_rsp_count,
    uint8_t cache_wr_rsp_count, uint8_t bypass_wr_rsp_count,
    bool accept_cache, bool accept_bypass, bool accept_write,
    bool rd_issue_valid, bool axi_arready, bool wr_aw_valid,
    bool axi_awready, bool wr_w_valid, bool axi_wready, bool axi_wlast,
    uint8_t read_depth, uint8_t write_depth) {
  AxiBridgeQueueControl out;
  const bool accept_any = accept_cache || accept_bypass;
  out.rd_issue_space = rd_issue_count < read_depth;
  out.wr_aw_space = wr_aw_count < write_depth;
  out.wr_w_space = wr_w_count < write_depth;
  out.cache_rd_rsp_valid = cache_rd_rsp_count != 0u;
  out.bypass_rd_rsp_valid = bypass_rd_rsp_count != 0u;
  out.cache_wr_rsp_valid = cache_wr_rsp_count != 0u;
  out.bypass_wr_rsp_valid = bypass_wr_rsp_count != 0u;
  out.cache_rd_rsp_space = cache_rd_rsp_count < read_depth;
  out.bypass_rd_rsp_space = bypass_rd_rsp_count < read_depth;
  out.cache_wr_rsp_space = cache_wr_rsp_count < write_depth;
  out.bypass_wr_rsp_space = bypass_wr_rsp_count < write_depth;
  out.rd_issue_handshake = rd_issue_valid && axi_arready;
  out.wr_aw_handshake = wr_aw_valid && axi_awready;
  out.wr_w_handshake = wr_w_valid && axi_wready;
  out.rd_issue_push = accept_any && !accept_write;
  out.rd_issue_pop = out.rd_issue_handshake;
  out.wr_aw_push = accept_any && accept_write;
  out.wr_aw_pop = out.wr_aw_handshake;
  out.wr_w_push = accept_any && accept_write;
  out.wr_w_pop = out.wr_w_handshake && axi_wlast;
  return out;
}

static inline AxiDualPortSlotHazardResult axi_dual_port_slot_hazard(
    bool first_free_found, bool second_free_found, bool primary_fire) {
  AxiDualPortSlotHazardResult out;
  out.primary_slot_hazard = !first_free_found;
  out.secondary_slot_hazard =
      !first_free_found || (primary_fire && !second_free_found);
  return out;
}

static inline AxiDualPortHazardMatchResult axi_dual_port_hazard_match(
    bool entry_valid, bool entry_port, uint32_t entry_line, uint8_t entry_id,
    uint32_t ddr_line, uint32_t mmio_line, uint8_t ddr_id, uint8_t mmio_id) {
  AxiDualPortHazardMatchResult out;
  out.ddr_line_match =
      entry_valid && !entry_port && (entry_line == ddr_line);
  out.mmio_line_match =
      entry_valid && entry_port && (entry_line == mmio_line);
  out.ddr_id_match = entry_valid && !entry_port && (entry_id == ddr_id);
  out.mmio_id_match = entry_valid && entry_port && (entry_id == mmio_id);
  return out;
}
