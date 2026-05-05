`timescale 1ns / 1ps
`include "axi_llc_params.vh"

// Native dual-port lower-memory bridge.
//
// This wrapper routes lower cache/bypass requests before AXI channel
// generation, so DDR and MMIO traffic do not collapse into a single AXI
// address channel. It reuses the proven single-port bridge twice:
//   - DDR bridge: 256-bit AXI beats, multi-beat cache-line support.
//   - MMIO bridge: 32-bit AXI beats, single-beat 32-bit requests only.
//
// Current scope:
//   - Address route: addr >= DDR_BASE -> DDR, otherwise MMIO.
//   - MMIO accepts only total_size == 3 (4 bytes).
//   - Response muxes are per source and backpressure the non-selected port.
//   - Same-line read/write AXI issue ambiguity is blocked at the external
//     AR/AW boundary: an issued AR holds the line until R last, and an issued
//     AW holds the line until B.
//   - Shared global 32-entry outstanding accounting is enforced by the
//     upstream compat/top layer; the underlying bridges still retain their
//     per-port local limits in standalone bridge use.
module axi_llc_axi_bridge_dual #(
    parameter ADDR_BITS           = `AXI_LLC_ADDR_BITS,
    parameter ID_BITS             = `AXI_LLC_SLOT_ID_BITS,
    parameter LINE_BYTES          = `AXI_LLC_LINE_BYTES,
    parameter LINE_BITS           = `AXI_LLC_LINE_BITS,
    parameter LINE_OFFSET_BITS    = `AXI_LLC_LINE_OFFSET_BITS,
    parameter DDR_AXI_ID_BITS     = `AXI_LLC_AXI_ID_BITS,
    parameter DDR_AXI_DATA_BYTES  = `AXI_LLC_AXI_DATA_BYTES,
    parameter DDR_AXI_DATA_BITS   = `AXI_LLC_AXI_DATA_BITS,
    parameter DDR_AXI_STRB_BITS   = `AXI_LLC_AXI_STRB_BITS,
    parameter MMIO_AXI_ID_BITS    = `AXI_LLC_AXI_ID_BITS,
    parameter MMIO_AXI_DATA_BYTES = 4,
    parameter MMIO_AXI_DATA_BITS  = 32,
    parameter MMIO_AXI_STRB_BITS  = 4,
    parameter READ_RESP_BYTES          = `AXI_LLC_READ_RESP_BYTES,
    parameter READ_RESP_BITS           = `AXI_LLC_READ_RESP_BITS,
    parameter DDR_BASE                 = 32'h4000_0000,
    parameter BRIDGE_READ_PENDING_COUNT  = `AXI_LLC_BRIDGE_READ_PENDING_COUNT,
    parameter BRIDGE_WRITE_PENDING_COUNT = `AXI_LLC_BRIDGE_WRITE_PENDING_COUNT,
    parameter READ_HAZARD_COUNT          = 2 * BRIDGE_READ_PENDING_COUNT,
    parameter WRITE_HAZARD_COUNT         = 2 * BRIDGE_WRITE_PENDING_COUNT
) (
    input                            clk,
    input                            rst_n,

    input                            cache_req_valid,
    output                           cache_req_ready,
    input                            cache_req_write,
    input      [ADDR_BITS-1:0]       cache_req_addr,
    input      [ID_BITS-1:0]         cache_req_id,
    input      [7:0]                 cache_req_size,
    input      [LINE_BITS-1:0]       cache_req_wdata,
    input      [LINE_BYTES-1:0]      cache_req_wstrb,
    output                           cache_resp_valid,
    input                            cache_resp_ready,
    output     [READ_RESP_BITS-1:0]  cache_resp_rdata,
    output     [ID_BITS-1:0]         cache_resp_id,
    output     [1:0]                 cache_resp_code,

    input                            bypass_req_valid,
    output                           bypass_req_ready,
    input                            bypass_req_write,
    input      [ADDR_BITS-1:0]       bypass_req_addr,
    input      [ID_BITS-1:0]         bypass_req_id,
    input      [7:0]                 bypass_req_size,
    input                            bypass_req_mode2_ddr_aligned,
    input      [LINE_BITS-1:0]       bypass_req_wdata,
    input      [LINE_BYTES-1:0]      bypass_req_wstrb,
    output                           bypass_resp_valid,
    input                            bypass_resp_ready,
    output     [READ_RESP_BITS-1:0]  bypass_resp_rdata,
    output     [ID_BITS-1:0]         bypass_resp_id,
    output     [1:0]                 bypass_resp_code,

    output                           ddr_axi_awvalid,
    input                            ddr_axi_awready,
    output     [DDR_AXI_ID_BITS-1:0] ddr_axi_awid,
    output     [ADDR_BITS-1:0]       ddr_axi_awaddr,
    output     [7:0]                 ddr_axi_awlen,
    output     [2:0]                 ddr_axi_awsize,
    output     [1:0]                 ddr_axi_awburst,
    output                           ddr_axi_wvalid,
    input                            ddr_axi_wready,
    output     [DDR_AXI_DATA_BITS-1:0] ddr_axi_wdata,
    output     [DDR_AXI_STRB_BITS-1:0] ddr_axi_wstrb,
    output                           ddr_axi_wlast,
    input                            ddr_axi_bvalid,
    output                           ddr_axi_bready,
    input      [DDR_AXI_ID_BITS-1:0] ddr_axi_bid,
    input      [1:0]                 ddr_axi_bresp,
    output                           ddr_axi_arvalid,
    input                            ddr_axi_arready,
    output     [DDR_AXI_ID_BITS-1:0] ddr_axi_arid,
    output     [ADDR_BITS-1:0]       ddr_axi_araddr,
    output     [7:0]                 ddr_axi_arlen,
    output     [2:0]                 ddr_axi_arsize,
    output     [1:0]                 ddr_axi_arburst,
    input                            ddr_axi_rvalid,
    output                           ddr_axi_rready,
    input      [DDR_AXI_ID_BITS-1:0] ddr_axi_rid,
    input      [DDR_AXI_DATA_BITS-1:0] ddr_axi_rdata,
    input      [1:0]                 ddr_axi_rresp,
    input                            ddr_axi_rlast,

    output                           mmio_axi_awvalid,
    input                            mmio_axi_awready,
    output     [MMIO_AXI_ID_BITS-1:0] mmio_axi_awid,
    output     [ADDR_BITS-1:0]       mmio_axi_awaddr,
    output     [7:0]                 mmio_axi_awlen,
    output     [2:0]                 mmio_axi_awsize,
    output     [1:0]                 mmio_axi_awburst,
    output                           mmio_axi_wvalid,
    input                            mmio_axi_wready,
    output     [MMIO_AXI_DATA_BITS-1:0] mmio_axi_wdata,
    output     [MMIO_AXI_STRB_BITS-1:0] mmio_axi_wstrb,
    output                           mmio_axi_wlast,
    input                            mmio_axi_bvalid,
    output                           mmio_axi_bready,
    input      [MMIO_AXI_ID_BITS-1:0] mmio_axi_bid,
    input      [1:0]                 mmio_axi_bresp,
    output                           mmio_axi_arvalid,
    input                            mmio_axi_arready,
    output     [MMIO_AXI_ID_BITS-1:0] mmio_axi_arid,
    output     [ADDR_BITS-1:0]       mmio_axi_araddr,
    output     [7:0]                 mmio_axi_arlen,
    output     [2:0]                 mmio_axi_arsize,
    output     [1:0]                 mmio_axi_arburst,
    input                            mmio_axi_rvalid,
    output                           mmio_axi_rready,
    input      [MMIO_AXI_ID_BITS-1:0] mmio_axi_rid,
    input      [MMIO_AXI_DATA_BITS-1:0] mmio_axi_rdata,
    input      [1:0]                 mmio_axi_rresp,
    input                            mmio_axi_rlast
);

    wire cache_mmio_supported_w;
    wire bypass_mmio_supported_w;
    wire cache_to_ddr_w;
    wire bypass_to_ddr_w;
    wire unused_cache_mmio_port_w;
    wire unused_bypass_mmio_port_w;
    wire [7:0] unused_cache_axi_len_w;
    wire [7:0] unused_bypass_axi_len_w;
    wire [2:0] unused_cache_axi_size_w;
    wire [2:0] unused_bypass_axi_size_w;

    wire ddr_cache_req_valid_w;
    wire ddr_cache_req_ready_w;
    wire ddr_cache_resp_valid_w;
    wire ddr_cache_resp_ready_w;
    wire [READ_RESP_BITS-1:0] ddr_cache_resp_rdata_w;
    wire [ID_BITS-1:0]        ddr_cache_resp_id_w;
    wire [1:0]                ddr_cache_resp_code_w;
    wire ddr_bypass_req_valid_w;
    wire ddr_bypass_req_ready_w;
    wire ddr_bypass_resp_valid_w;
    wire ddr_bypass_resp_ready_w;
    wire [READ_RESP_BITS-1:0] ddr_bypass_resp_rdata_w;
    wire [ID_BITS-1:0]        ddr_bypass_resp_id_w;
    wire [1:0]                ddr_bypass_resp_code_w;

    wire mmio_cache_req_valid_w;
    wire mmio_cache_req_ready_w;
    wire mmio_cache_resp_valid_w;
    wire mmio_cache_resp_ready_w;
    wire [READ_RESP_BITS-1:0] mmio_cache_resp_rdata_w;
    wire [ID_BITS-1:0]        mmio_cache_resp_id_w;
    wire [1:0]                mmio_cache_resp_code_w;
    wire mmio_bypass_req_valid_w;
    wire mmio_bypass_req_ready_w;
    wire mmio_bypass_resp_valid_w;
    wire mmio_bypass_resp_ready_w;
    wire [READ_RESP_BITS-1:0] mmio_bypass_resp_rdata_w;
    wire [ID_BITS-1:0]        mmio_bypass_resp_id_w;
    wire [1:0]                mmio_bypass_resp_code_w;

    wire cache_resp_select_mmio_w;
    wire bypass_resp_select_mmio_w;

    localparam integer LINE_TAG_BITS = ADDR_BITS - LINE_OFFSET_BITS;
    localparam integer HAZARD_AXI_ID_BITS =
        (DDR_AXI_ID_BITS > MMIO_AXI_ID_BITS) ? DDR_AXI_ID_BITS : MMIO_AXI_ID_BITS;

    wire ddr_bridge_awvalid_w;
    wire ddr_bridge_awready_w;
    wire ddr_bridge_arvalid_w;
    wire ddr_bridge_arready_w;
    wire mmio_bridge_awvalid_w;
    wire mmio_bridge_awready_w;
    wire mmio_bridge_arvalid_w;
    wire mmio_bridge_arready_w;

    wire [LINE_TAG_BITS-1:0] ddr_aw_line_w;
    wire [LINE_TAG_BITS-1:0] ddr_ar_line_w;
    wire [LINE_TAG_BITS-1:0] mmio_aw_line_w;
    wire [LINE_TAG_BITS-1:0] mmio_ar_line_w;
    wire [HAZARD_AXI_ID_BITS-1:0] ddr_rid_hazard_w;
    wire [HAZARD_AXI_ID_BITS-1:0] ddr_bid_hazard_w;
    wire [HAZARD_AXI_ID_BITS-1:0] ddr_arid_hazard_w;
    wire [HAZARD_AXI_ID_BITS-1:0] ddr_awid_hazard_w;
    wire [HAZARD_AXI_ID_BITS-1:0] mmio_rid_hazard_w;
    wire [HAZARD_AXI_ID_BITS-1:0] mmio_bid_hazard_w;
    wire [HAZARD_AXI_ID_BITS-1:0] mmio_arid_hazard_w;
    wire [HAZARD_AXI_ID_BITS-1:0] mmio_awid_hazard_w;

    wire ddr_ar_slot_hazard_w;
    wire mmio_ar_slot_hazard_w;
    wire ddr_aw_slot_hazard_w;
    wire mmio_aw_slot_hazard_w;
    wire ddr_aw_pending_read_hazard_w;
    wire mmio_aw_pending_read_hazard_w;
    wire ddr_ar_pending_write_hazard_w;
    wire mmio_ar_pending_write_hazard_w;
    wire ddr_ar_hazard_w;
    wire mmio_ar_hazard_w;
    wire ddr_aw_hazard_w;
    wire mmio_aw_hazard_w;
    wire ddr_ar_would_issue_w;
    wire mmio_ar_would_issue_w;
    wire ddr_aw_same_cycle_read_hazard_w;
    wire mmio_aw_same_cycle_read_hazard_w;
    wire ddr_ar_fire_w;
    wire mmio_ar_fire_w;
    wire ddr_aw_fire_w;
    wire mmio_aw_fire_w;
    wire ddr_r_fire_w;
    wire mmio_r_fire_w;
    wire ddr_b_fire_w;
    wire mmio_b_fire_w;

    function [LINE_TAG_BITS-1:0] line_tag_of_addr;
        input [ADDR_BITS-1:0] addr_value;
        begin
            line_tag_of_addr = addr_value[ADDR_BITS-1:LINE_OFFSET_BITS];
        end
    endfunction

    axi_llc_dual_port_route_shape #(
        .ADDR_BITS(ADDR_BITS),
        .DDR_BASE(DDR_BASE[ADDR_BITS-1:0])
    ) cache_route_shape (
        .addr(cache_req_addr),
        .total_size(cache_req_size),
        .ddr_port(cache_to_ddr_w),
        .mmio_port(unused_cache_mmio_port_w),
        .supported(cache_mmio_supported_w),
        .axi_len(unused_cache_axi_len_w),
        .axi_size(unused_cache_axi_size_w)
    );

    axi_llc_dual_port_route_shape #(
        .ADDR_BITS(ADDR_BITS),
        .DDR_BASE(DDR_BASE[ADDR_BITS-1:0])
    ) bypass_route_shape (
        .addr(bypass_req_addr),
        .total_size(bypass_req_size),
        .ddr_port(bypass_to_ddr_w),
        .mmio_port(unused_bypass_mmio_port_w),
        .supported(bypass_mmio_supported_w),
        .axi_len(unused_bypass_axi_len_w),
        .axi_size(unused_bypass_axi_size_w)
    );

    axi_llc_dual_port_req_steer cache_req_steer (
        .req_valid(cache_req_valid),
        .req_to_ddr(cache_to_ddr_w),
        .req_supported(cache_mmio_supported_w),
        .ddr_req_valid(ddr_cache_req_valid_w),
        .ddr_req_ready(ddr_cache_req_ready_w),
        .mmio_req_valid(mmio_cache_req_valid_w),
        .mmio_req_ready(mmio_cache_req_ready_w),
        .req_ready(cache_req_ready)
    );

    axi_llc_dual_port_req_steer bypass_req_steer (
        .req_valid(bypass_req_valid),
        .req_to_ddr(bypass_to_ddr_w),
        .req_supported(bypass_mmio_supported_w),
        .ddr_req_valid(ddr_bypass_req_valid_w),
        .ddr_req_ready(ddr_bypass_req_ready_w),
        .mmio_req_valid(mmio_bypass_req_valid_w),
        .mmio_req_ready(mmio_bypass_req_ready_w),
        .req_ready(bypass_req_ready)
    );

    axi_llc_dual_port_resp_mux #(
        .RESP_BITS(READ_RESP_BITS),
        .ID_BITS(ID_BITS)
    ) cache_resp_mux (
        .ddr_resp_valid(ddr_cache_resp_valid_w),
        .ddr_resp_ready(ddr_cache_resp_ready_w),
        .ddr_resp_rdata(ddr_cache_resp_rdata_w),
        .ddr_resp_id(ddr_cache_resp_id_w),
        .ddr_resp_code(ddr_cache_resp_code_w),
        .mmio_resp_valid(mmio_cache_resp_valid_w),
        .mmio_resp_ready(mmio_cache_resp_ready_w),
        .mmio_resp_rdata(mmio_cache_resp_rdata_w),
        .mmio_resp_id(mmio_cache_resp_id_w),
        .mmio_resp_code(mmio_cache_resp_code_w),
        .resp_valid(cache_resp_valid),
        .resp_ready(cache_resp_ready),
        .resp_rdata(cache_resp_rdata),
        .resp_id(cache_resp_id),
        .resp_code(cache_resp_code),
        .select_mmio(cache_resp_select_mmio_w)
    );

    axi_llc_dual_port_resp_mux #(
        .RESP_BITS(READ_RESP_BITS),
        .ID_BITS(ID_BITS)
    ) bypass_resp_mux (
        .ddr_resp_valid(ddr_bypass_resp_valid_w),
        .ddr_resp_ready(ddr_bypass_resp_ready_w),
        .ddr_resp_rdata(ddr_bypass_resp_rdata_w),
        .ddr_resp_id(ddr_bypass_resp_id_w),
        .ddr_resp_code(ddr_bypass_resp_code_w),
        .mmio_resp_valid(mmio_bypass_resp_valid_w),
        .mmio_resp_ready(mmio_bypass_resp_ready_w),
        .mmio_resp_rdata(mmio_bypass_resp_rdata_w),
        .mmio_resp_id(mmio_bypass_resp_id_w),
        .mmio_resp_code(mmio_bypass_resp_code_w),
        .resp_valid(bypass_resp_valid),
        .resp_ready(bypass_resp_ready),
        .resp_rdata(bypass_resp_rdata),
        .resp_id(bypass_resp_id),
        .resp_code(bypass_resp_code),
        .select_mmio(bypass_resp_select_mmio_w)
    );

    assign ddr_aw_line_w = line_tag_of_addr(ddr_axi_awaddr);
    assign ddr_ar_line_w = line_tag_of_addr(ddr_axi_araddr);
    assign mmio_aw_line_w = line_tag_of_addr(mmio_axi_awaddr);
    assign mmio_ar_line_w = line_tag_of_addr(mmio_axi_araddr);

    axi_llc_axi_id_shape #(
        .IN_ID_BITS(DDR_AXI_ID_BITS),
        .OUT_ID_BITS(HAZARD_AXI_ID_BITS)
    ) ddr_rid_hazard_id_shape (
        .id_in(ddr_axi_rid),
        .id_out(ddr_rid_hazard_w)
    );

    axi_llc_axi_id_shape #(
        .IN_ID_BITS(DDR_AXI_ID_BITS),
        .OUT_ID_BITS(HAZARD_AXI_ID_BITS)
    ) ddr_bid_hazard_id_shape (
        .id_in(ddr_axi_bid),
        .id_out(ddr_bid_hazard_w)
    );

    axi_llc_axi_id_shape #(
        .IN_ID_BITS(DDR_AXI_ID_BITS),
        .OUT_ID_BITS(HAZARD_AXI_ID_BITS)
    ) ddr_arid_hazard_id_shape (
        .id_in(ddr_axi_arid),
        .id_out(ddr_arid_hazard_w)
    );

    axi_llc_axi_id_shape #(
        .IN_ID_BITS(DDR_AXI_ID_BITS),
        .OUT_ID_BITS(HAZARD_AXI_ID_BITS)
    ) ddr_awid_hazard_id_shape (
        .id_in(ddr_axi_awid),
        .id_out(ddr_awid_hazard_w)
    );

    axi_llc_axi_id_shape #(
        .IN_ID_BITS(MMIO_AXI_ID_BITS),
        .OUT_ID_BITS(HAZARD_AXI_ID_BITS)
    ) mmio_rid_hazard_id_shape (
        .id_in(mmio_axi_rid),
        .id_out(mmio_rid_hazard_w)
    );

    axi_llc_axi_id_shape #(
        .IN_ID_BITS(MMIO_AXI_ID_BITS),
        .OUT_ID_BITS(HAZARD_AXI_ID_BITS)
    ) mmio_bid_hazard_id_shape (
        .id_in(mmio_axi_bid),
        .id_out(mmio_bid_hazard_w)
    );

    axi_llc_axi_id_shape #(
        .IN_ID_BITS(MMIO_AXI_ID_BITS),
        .OUT_ID_BITS(HAZARD_AXI_ID_BITS)
    ) mmio_arid_hazard_id_shape (
        .id_in(mmio_axi_arid),
        .id_out(mmio_arid_hazard_w)
    );

    axi_llc_axi_id_shape #(
        .IN_ID_BITS(MMIO_AXI_ID_BITS),
        .OUT_ID_BITS(HAZARD_AXI_ID_BITS)
    ) mmio_awid_hazard_id_shape (
        .id_in(mmio_axi_awid),
        .id_out(mmio_awid_hazard_w)
    );

    axi_llc_dual_port_hazard_scoreboard #(
        .LINE_TAG_BITS(LINE_TAG_BITS),
        .HAZARD_AXI_ID_BITS(HAZARD_AXI_ID_BITS),
        .READ_HAZARD_COUNT(READ_HAZARD_COUNT),
        .WRITE_HAZARD_COUNT(WRITE_HAZARD_COUNT)
    ) hazard_scoreboard (
        .clk(clk),
        .rst_n(rst_n),
        .ddr_ar_line(ddr_ar_line_w),
        .mmio_ar_line(mmio_ar_line_w),
        .ddr_aw_line(ddr_aw_line_w),
        .mmio_aw_line(mmio_aw_line_w),
        .ddr_arid(ddr_arid_hazard_w),
        .mmio_arid(mmio_arid_hazard_w),
        .ddr_awid(ddr_awid_hazard_w),
        .mmio_awid(mmio_awid_hazard_w),
        .ddr_rid(ddr_rid_hazard_w),
        .mmio_rid(mmio_rid_hazard_w),
        .ddr_bid(ddr_bid_hazard_w),
        .mmio_bid(mmio_bid_hazard_w),
        .ddr_ar_fire(ddr_ar_fire_w),
        .mmio_ar_fire(mmio_ar_fire_w),
        .ddr_aw_fire(ddr_aw_fire_w),
        .mmio_aw_fire(mmio_aw_fire_w),
        .ddr_r_fire(ddr_r_fire_w),
        .mmio_r_fire(mmio_r_fire_w),
        .ddr_b_fire(ddr_b_fire_w),
        .mmio_b_fire(mmio_b_fire_w),
        .ddr_ar_slot_hazard(ddr_ar_slot_hazard_w),
        .mmio_ar_slot_hazard(mmio_ar_slot_hazard_w),
        .ddr_aw_slot_hazard(ddr_aw_slot_hazard_w),
        .mmio_aw_slot_hazard(mmio_aw_slot_hazard_w),
        .ddr_aw_pending_read_hazard(ddr_aw_pending_read_hazard_w),
        .mmio_aw_pending_read_hazard(mmio_aw_pending_read_hazard_w),
        .ddr_ar_pending_write_hazard(ddr_ar_pending_write_hazard_w),
        .mmio_ar_pending_write_hazard(mmio_ar_pending_write_hazard_w)
    );

    axi_llc_dual_port_issue_gate #(
        .LINE_TAG_BITS(LINE_TAG_BITS)
    ) ddr_issue_gate (
        .bridge_arvalid(ddr_bridge_arvalid_w),
        .bridge_arready(ddr_bridge_arready_w),
        .axi_arvalid(ddr_axi_arvalid),
        .axi_arready(ddr_axi_arready),
        .ar_line(ddr_ar_line_w),
        .ar_slot_hazard(ddr_ar_slot_hazard_w),
        .ar_pending_write_hazard(ddr_ar_pending_write_hazard_w),
        .bridge_awvalid(ddr_bridge_awvalid_w),
        .bridge_awready(ddr_bridge_awready_w),
        .axi_awvalid(ddr_axi_awvalid),
        .axi_awready(ddr_axi_awready),
        .aw_line(ddr_aw_line_w),
        .aw_slot_hazard(ddr_aw_slot_hazard_w),
        .aw_pending_read_hazard(ddr_aw_pending_read_hazard_w),
        .ar_hazard(ddr_ar_hazard_w),
        .ar_would_issue(ddr_ar_would_issue_w),
        .aw_same_cycle_read_hazard(ddr_aw_same_cycle_read_hazard_w),
        .aw_hazard(ddr_aw_hazard_w),
        .ar_fire(ddr_ar_fire_w),
        .aw_fire(ddr_aw_fire_w)
    );

    axi_llc_dual_port_issue_gate #(
        .LINE_TAG_BITS(LINE_TAG_BITS)
    ) mmio_issue_gate (
        .bridge_arvalid(mmio_bridge_arvalid_w),
        .bridge_arready(mmio_bridge_arready_w),
        .axi_arvalid(mmio_axi_arvalid),
        .axi_arready(mmio_axi_arready),
        .ar_line(mmio_ar_line_w),
        .ar_slot_hazard(mmio_ar_slot_hazard_w),
        .ar_pending_write_hazard(mmio_ar_pending_write_hazard_w),
        .bridge_awvalid(mmio_bridge_awvalid_w),
        .bridge_awready(mmio_bridge_awready_w),
        .axi_awvalid(mmio_axi_awvalid),
        .axi_awready(mmio_axi_awready),
        .aw_line(mmio_aw_line_w),
        .aw_slot_hazard(mmio_aw_slot_hazard_w),
        .aw_pending_read_hazard(mmio_aw_pending_read_hazard_w),
        .ar_hazard(mmio_ar_hazard_w),
        .ar_would_issue(mmio_ar_would_issue_w),
        .aw_same_cycle_read_hazard(mmio_aw_same_cycle_read_hazard_w),
        .aw_hazard(mmio_aw_hazard_w),
        .ar_fire(mmio_ar_fire_w),
        .aw_fire(mmio_aw_fire_w)
    );

    assign ddr_r_fire_w = ddr_axi_rvalid && ddr_axi_rready && ddr_axi_rlast;
    assign mmio_r_fire_w = mmio_axi_rvalid && mmio_axi_rready && mmio_axi_rlast;
    assign ddr_b_fire_w = ddr_axi_bvalid && ddr_axi_bready;
    assign mmio_b_fire_w = mmio_axi_bvalid && mmio_axi_bready;

    axi_llc_axi_bridge #(
        .ADDR_BITS(ADDR_BITS),
        .ID_BITS(ID_BITS),
        .LINE_BYTES(LINE_BYTES),
        .LINE_BITS(LINE_BITS),
        .AXI_ID_BITS(DDR_AXI_ID_BITS),
        .AXI_DATA_BYTES(DDR_AXI_DATA_BYTES),
        .AXI_DATA_BITS(DDR_AXI_DATA_BITS),
        .AXI_STRB_BITS(DDR_AXI_STRB_BITS),
        .READ_RESP_BYTES(READ_RESP_BYTES),
        .READ_RESP_BITS(READ_RESP_BITS),
        .READ_PENDING_COUNT(BRIDGE_READ_PENDING_COUNT),
        .WRITE_PENDING_COUNT(BRIDGE_WRITE_PENDING_COUNT)
    ) ddr_bridge (
        .clk(clk),
        .rst_n(rst_n),
        .cache_req_valid(ddr_cache_req_valid_w),
        .cache_req_ready(ddr_cache_req_ready_w),
        .cache_req_write(cache_req_write),
        .cache_req_addr(cache_req_addr),
        .cache_req_id(cache_req_id),
        .cache_req_size(cache_req_size),
        .cache_req_wdata(cache_req_wdata),
        .cache_req_wstrb(cache_req_wstrb),
        .cache_resp_valid(ddr_cache_resp_valid_w),
        .cache_resp_ready(ddr_cache_resp_ready_w),
        .cache_resp_rdata(ddr_cache_resp_rdata_w),
        .cache_resp_id(ddr_cache_resp_id_w),
        .cache_resp_code(ddr_cache_resp_code_w),
        .bypass_req_valid(ddr_bypass_req_valid_w),
        .bypass_req_ready(ddr_bypass_req_ready_w),
        .bypass_req_write(bypass_req_write),
        .bypass_req_addr(bypass_req_addr),
        .bypass_req_id(bypass_req_id),
        .bypass_req_size(bypass_req_size),
        .bypass_req_mode2_ddr_aligned(bypass_req_mode2_ddr_aligned),
        .bypass_req_wdata(bypass_req_wdata),
        .bypass_req_wstrb(bypass_req_wstrb),
        .bypass_resp_valid(ddr_bypass_resp_valid_w),
        .bypass_resp_ready(ddr_bypass_resp_ready_w),
        .bypass_resp_rdata(ddr_bypass_resp_rdata_w),
        .bypass_resp_id(ddr_bypass_resp_id_w),
        .bypass_resp_code(ddr_bypass_resp_code_w),
        .axi_awvalid(ddr_bridge_awvalid_w),
        .axi_awready(ddr_bridge_awready_w),
        .axi_awid(ddr_axi_awid),
        .axi_awaddr(ddr_axi_awaddr),
        .axi_awlen(ddr_axi_awlen),
        .axi_awsize(ddr_axi_awsize),
        .axi_awburst(ddr_axi_awburst),
        .axi_wvalid(ddr_axi_wvalid),
        .axi_wready(ddr_axi_wready),
        .axi_wdata(ddr_axi_wdata),
        .axi_wstrb(ddr_axi_wstrb),
        .axi_wlast(ddr_axi_wlast),
        .axi_bvalid(ddr_axi_bvalid),
        .axi_bready(ddr_axi_bready),
        .axi_bid(ddr_axi_bid),
        .axi_bresp(ddr_axi_bresp),
        .axi_arvalid(ddr_bridge_arvalid_w),
        .axi_arready(ddr_bridge_arready_w),
        .axi_arid(ddr_axi_arid),
        .axi_araddr(ddr_axi_araddr),
        .axi_arlen(ddr_axi_arlen),
        .axi_arsize(ddr_axi_arsize),
        .axi_arburst(ddr_axi_arburst),
        .axi_rvalid(ddr_axi_rvalid),
        .axi_rready(ddr_axi_rready),
        .axi_rid(ddr_axi_rid),
        .axi_rdata(ddr_axi_rdata),
        .axi_rresp(ddr_axi_rresp),
        .axi_rlast(ddr_axi_rlast)
    );

    axi_llc_axi_bridge #(
        .ADDR_BITS(ADDR_BITS),
        .ID_BITS(ID_BITS),
        .LINE_BYTES(LINE_BYTES),
        .LINE_BITS(LINE_BITS),
        .AXI_ID_BITS(MMIO_AXI_ID_BITS),
        .AXI_DATA_BYTES(MMIO_AXI_DATA_BYTES),
        .AXI_DATA_BITS(MMIO_AXI_DATA_BITS),
        .AXI_STRB_BITS(MMIO_AXI_STRB_BITS),
        .READ_RESP_BYTES(READ_RESP_BYTES),
        .READ_RESP_BITS(READ_RESP_BITS),
        .READ_PENDING_COUNT(BRIDGE_READ_PENDING_COUNT),
        .WRITE_PENDING_COUNT(BRIDGE_WRITE_PENDING_COUNT)
    ) mmio_bridge (
        .clk(clk),
        .rst_n(rst_n),
        .cache_req_valid(mmio_cache_req_valid_w),
        .cache_req_ready(mmio_cache_req_ready_w),
        .cache_req_write(cache_req_write),
        .cache_req_addr(cache_req_addr),
        .cache_req_id(cache_req_id),
        .cache_req_size(cache_req_size),
        .cache_req_wdata(cache_req_wdata),
        .cache_req_wstrb(cache_req_wstrb),
        .cache_resp_valid(mmio_cache_resp_valid_w),
        .cache_resp_ready(mmio_cache_resp_ready_w),
        .cache_resp_rdata(mmio_cache_resp_rdata_w),
        .cache_resp_id(mmio_cache_resp_id_w),
        .cache_resp_code(mmio_cache_resp_code_w),
        .bypass_req_valid(mmio_bypass_req_valid_w),
        .bypass_req_ready(mmio_bypass_req_ready_w),
        .bypass_req_write(bypass_req_write),
        .bypass_req_addr(bypass_req_addr),
        .bypass_req_id(bypass_req_id),
        .bypass_req_size(bypass_req_size),
        .bypass_req_mode2_ddr_aligned(1'b0),
        .bypass_req_wdata(bypass_req_wdata),
        .bypass_req_wstrb(bypass_req_wstrb),
        .bypass_resp_valid(mmio_bypass_resp_valid_w),
        .bypass_resp_ready(mmio_bypass_resp_ready_w),
        .bypass_resp_rdata(mmio_bypass_resp_rdata_w),
        .bypass_resp_id(mmio_bypass_resp_id_w),
        .bypass_resp_code(mmio_bypass_resp_code_w),
        .axi_awvalid(mmio_bridge_awvalid_w),
        .axi_awready(mmio_bridge_awready_w),
        .axi_awid(mmio_axi_awid),
        .axi_awaddr(mmio_axi_awaddr),
        .axi_awlen(mmio_axi_awlen),
        .axi_awsize(mmio_axi_awsize),
        .axi_awburst(mmio_axi_awburst),
        .axi_wvalid(mmio_axi_wvalid),
        .axi_wready(mmio_axi_wready),
        .axi_wdata(mmio_axi_wdata),
        .axi_wstrb(mmio_axi_wstrb),
        .axi_wlast(mmio_axi_wlast),
        .axi_bvalid(mmio_axi_bvalid),
        .axi_bready(mmio_axi_bready),
        .axi_bid(mmio_axi_bid),
        .axi_bresp(mmio_axi_bresp),
        .axi_arvalid(mmio_bridge_arvalid_w),
        .axi_arready(mmio_bridge_arready_w),
        .axi_arid(mmio_axi_arid),
        .axi_araddr(mmio_axi_araddr),
        .axi_arlen(mmio_axi_arlen),
        .axi_arsize(mmio_axi_arsize),
        .axi_arburst(mmio_axi_arburst),
        .axi_rvalid(mmio_axi_rvalid),
        .axi_rready(mmio_axi_rready),
        .axi_rid(mmio_axi_rid),
        .axi_rdata(mmio_axi_rdata),
        .axi_rresp(mmio_axi_rresp),
        .axi_rlast(mmio_axi_rlast)
    );

endmodule
