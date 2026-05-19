`timescale 1ns / 1ps
`include "axi_llc_params.vh"

// Lower-memory to AXI4 translation layer.
//
// Input side:
//   - cache_*  : line-memory requests from the cache path
//   - bypass_* : lower bypass read/write requests
//
// Output side:
//   - a single AXI4 master AW/W/B/AR/R interface
//
// Internal rules:
//   - source-local req_id stays inside the cache/bypass domains
//   - lower AXI uses independently allocated read/write axi_id
//   - read/write completions are queued when the AXI transaction completes,
//     not when the request is accepted
//   - write axi_id is released on B handshake, matching the C++ model
module axi_llc_axi_bridge #(
    parameter ADDR_BITS       = `AXI_LLC_ADDR_BITS,
    parameter ID_BITS         = `AXI_LLC_SLOT_ID_BITS,
    parameter LINE_BYTES      = `AXI_LLC_LINE_BYTES,
    parameter LINE_BITS       = `AXI_LLC_LINE_BITS,
    parameter AXI_ID_BITS     = `AXI_LLC_AXI_ID_BITS,
    parameter AXI_DATA_BYTES  = `AXI_LLC_AXI_DATA_BYTES,
    parameter AXI_DATA_BITS   = `AXI_LLC_AXI_DATA_BITS,
    parameter AXI_STRB_BITS        = `AXI_LLC_AXI_STRB_BITS,
    parameter READ_RESP_BYTES      = `AXI_LLC_READ_RESP_BYTES,
    parameter READ_RESP_BITS       = `AXI_LLC_READ_RESP_BITS,
    parameter READ_PENDING_COUNT   = `AXI_LLC_BRIDGE_READ_PENDING_COUNT,
    parameter WRITE_PENDING_COUNT  = `AXI_LLC_BRIDGE_WRITE_PENDING_COUNT
) (
    input                           clk,
    input                           rst_n,
    // Cache lower path.
    input                           cache_req_valid,
    output                          cache_req_ready,
    input                           cache_req_write,
    input      [ADDR_BITS-1:0]      cache_req_addr,
    input      [ID_BITS-1:0]        cache_req_id,
    input      [7:0]                cache_req_size,
    input      [LINE_BITS-1:0]      cache_req_wdata,
    input      [LINE_BYTES-1:0]     cache_req_wstrb,
    output                          cache_resp_valid,
    input                           cache_resp_ready,
    output     [READ_RESP_BITS-1:0] cache_resp_rdata,
    output     [ID_BITS-1:0]        cache_resp_id,
    output     [1:0]                cache_resp_code,
    // Bypass lower path.
    input                           bypass_req_valid,
    output                          bypass_req_ready,
    input                           bypass_req_write,
    input      [ADDR_BITS-1:0]      bypass_req_addr,
    input      [ID_BITS-1:0]        bypass_req_id,
    input      [7:0]                bypass_req_size,
    input                           bypass_req_mode2_ddr_aligned,
    input      [LINE_BITS-1:0]      bypass_req_wdata,
    input      [LINE_BYTES-1:0]     bypass_req_wstrb,
    output                          bypass_resp_valid,
    input                           bypass_resp_ready,
    output     [READ_RESP_BITS-1:0] bypass_resp_rdata,
    output     [ID_BITS-1:0]        bypass_resp_id,
    output     [1:0]                bypass_resp_code,
    // Single AXI4 master port.
    output                          axi_awvalid,
    input                           axi_awready,
    output     [AXI_ID_BITS-1:0]    axi_awid,
    output     [ADDR_BITS-1:0]      axi_awaddr,
    output     [7:0]                axi_awlen,
    output     [2:0]                axi_awsize,
    output     [1:0]                axi_awburst,
    output                          axi_wvalid,
    input                           axi_wready,
    output     [AXI_DATA_BITS-1:0]  axi_wdata,
    output     [AXI_STRB_BITS-1:0]  axi_wstrb,
    output                          axi_wlast,
    input                           axi_bvalid,
    output                          axi_bready,
    input      [AXI_ID_BITS-1:0]    axi_bid,
    input      [1:0]                axi_bresp,
    output                          axi_arvalid,
    input                           axi_arready,
    output     [AXI_ID_BITS-1:0]    axi_arid,
    output     [ADDR_BITS-1:0]      axi_araddr,
    output     [7:0]                axi_arlen,
    output     [2:0]                axi_arsize,
    output     [1:0]                axi_arburst,
    input                           axi_rvalid,
    output                          axi_rready,
    input      [AXI_ID_BITS-1:0]    axi_rid,
    input      [AXI_DATA_BITS-1:0]  axi_rdata,
    input      [1:0]                axi_rresp,
    input                           axi_rlast
);

    localparam [1:0] AXI_BURST_INCR = 2'b01;
    localparam [1:0] RESP_OKAY      = 2'b00;
    localparam integer AXI_ID_COUNT        = (1 << AXI_ID_BITS);
    localparam integer READ_PACK_MODE2_EXTRACT_BYTES =
        (LINE_BYTES < READ_RESP_BYTES) ? LINE_BYTES : READ_RESP_BYTES;
    localparam integer WRITE_PACK_SINGLE_BEAT_ONLY =
        (AXI_DATA_BYTES == 4) && (READ_RESP_BYTES == AXI_DATA_BYTES);
    reg                           rd_valid_r [0:READ_PENDING_COUNT-1];
    reg                           rd_from_cache_r [0:READ_PENDING_COUNT-1];
    reg [ADDR_BITS-1:0]           rd_addr_r [0:READ_PENDING_COUNT-1];
    reg [ID_BITS-1:0]             rd_req_id_r [0:READ_PENDING_COUNT-1];
    reg [7:0]                     rd_size_r [0:READ_PENDING_COUNT-1];
    reg                           rd_mode2_ddr_aligned_r [0:READ_PENDING_COUNT-1];
    reg [AXI_ID_BITS-1:0]         rd_axi_id_r [0:READ_PENDING_COUNT-1];
    reg [7:0]                     rd_total_beats_r [0:READ_PENDING_COUNT-1];
    reg [7:0]                     rd_beats_done_r [0:READ_PENDING_COUNT-1];
    reg                           rd_ar_sent_r [0:READ_PENDING_COUNT-1];
    reg                           rd_complete_r [0:READ_PENDING_COUNT-1];
    reg [READ_RESP_BITS-1:0]      rd_rdata_r [0:READ_PENDING_COUNT-1];
    reg [1:0]                     rd_resp_code_r [0:READ_PENDING_COUNT-1];

    reg                           wr_valid_r [0:WRITE_PENDING_COUNT-1];
    reg                           wr_from_cache_r [0:WRITE_PENDING_COUNT-1];
    reg [ADDR_BITS-1:0]           wr_addr_r [0:WRITE_PENDING_COUNT-1];
    reg [ID_BITS-1:0]             wr_req_id_r [0:WRITE_PENDING_COUNT-1];
    reg [7:0]                     wr_size_r [0:WRITE_PENDING_COUNT-1];
    reg                           wr_mode2_ddr_aligned_r [0:WRITE_PENDING_COUNT-1];
    // Wide payload arrays are written before their valid/count gates expose
    // them. Avoid invalid-entry reset/free clears to keep DC from building
    // unnecessary wide mux trees.
    reg [LINE_BITS-1:0]           wr_wdata_r [0:WRITE_PENDING_COUNT-1];
    reg [LINE_BYTES-1:0]          wr_wstrb_r [0:WRITE_PENDING_COUNT-1];
    reg [AXI_ID_BITS-1:0]         wr_axi_id_r [0:WRITE_PENDING_COUNT-1];
    reg [7:0]                     wr_total_beats_r [0:WRITE_PENDING_COUNT-1];
    reg [7:0]                     wr_beats_sent_r [0:WRITE_PENDING_COUNT-1];
    reg                           wr_aw_sent_r [0:WRITE_PENDING_COUNT-1];
    reg                           wr_w_done_r [0:WRITE_PENDING_COUNT-1];

    reg [7:0]                     rd_issue_q_slot_r [0:READ_PENDING_COUNT-1];
    reg [7:0]                     rd_issue_head_r;
    reg [7:0]                     rd_issue_tail_r;
    reg [7:0]                     rd_issue_count_r;

    reg [7:0]                     wr_aw_q_slot_r [0:WRITE_PENDING_COUNT-1];
    reg [7:0]                     wr_aw_head_r;
    reg [7:0]                     wr_aw_tail_r;
    reg [7:0]                     wr_aw_count_r;

    reg [7:0]                     wr_w_q_slot_r [0:WRITE_PENDING_COUNT-1];
    reg [7:0]                     wr_w_head_r;
    reg [7:0]                     wr_w_tail_r;
    reg [7:0]                     wr_w_count_r;

    reg [ID_BITS-1:0]             cache_rd_rsp_id_r [0:READ_PENDING_COUNT-1];
    reg [1:0]                     cache_rd_rsp_code_r [0:READ_PENDING_COUNT-1];
    reg [READ_RESP_BITS-1:0]      cache_rd_rsp_data_r [0:READ_PENDING_COUNT-1];
    reg [7:0]                     cache_rd_rsp_head_r;
    reg [7:0]                     cache_rd_rsp_tail_r;
    reg [7:0]                     cache_rd_rsp_count_r;

    reg [ID_BITS-1:0]             bypass_rd_rsp_id_r [0:READ_PENDING_COUNT-1];
    reg [1:0]                     bypass_rd_rsp_code_r [0:READ_PENDING_COUNT-1];
    reg [READ_RESP_BITS-1:0]      bypass_rd_rsp_data_r [0:READ_PENDING_COUNT-1];
    reg [7:0]                     bypass_rd_rsp_head_r;
    reg [7:0]                     bypass_rd_rsp_tail_r;
    reg [7:0]                     bypass_rd_rsp_count_r;

    reg [ID_BITS-1:0]             cache_wr_rsp_id_r [0:WRITE_PENDING_COUNT-1];
    reg [1:0]                     cache_wr_rsp_code_r [0:WRITE_PENDING_COUNT-1];
    reg [7:0]                     cache_wr_rsp_head_r;
    reg [7:0]                     cache_wr_rsp_tail_r;
    reg [7:0]                     cache_wr_rsp_count_r;

    reg [ID_BITS-1:0]             bypass_wr_rsp_id_r [0:WRITE_PENDING_COUNT-1];
    reg [1:0]                     bypass_wr_rsp_code_r [0:WRITE_PENDING_COUNT-1];
    reg [7:0]                     bypass_wr_rsp_head_r;
    reg [7:0]                     bypass_wr_rsp_tail_r;
    reg [7:0]                     bypass_wr_rsp_count_r;

    wire                          rd_free_found_w;
    wire [7:0]                    rd_free_slot_w;
    wire                          rd_axi_id_found_w;
    wire [AXI_ID_BITS-1:0]        rd_axi_id_w;
    wire                          wr_free_found_w;
    wire [7:0]                    wr_free_slot_w;
    wire                          wr_axi_id_found_w;
    wire [AXI_ID_BITS-1:0]        wr_axi_id_w;
    wire                          accept_cache_w;
    wire                          accept_bypass_w;
    wire                          accept_write_w;
    wire [7:0]                    accept_slot_w;
    wire [AXI_ID_BITS-1:0]        accept_axi_id_w;
    wire [7:0]                    accept_total_beats_w;
    wire [7:0]                    rd_match_slot_w;
    wire                          rd_match_found_w;
    wire [7:0]                    rd_complete_slot_w;
    wire                          rd_complete_found_w;
    wire [7:0]                    wr_match_slot_w;
    wire                          wr_match_found_w;
    wire [7:0]                    unused_wr_complete_slot_w;
    wire                          unused_wr_complete_found_w;

    integer                       seq_idx;
    genvar                        pending_pack_idx;

    wire                      rd_issue_valid_w;
    wire [7:0]                rd_issue_slot_w;
    wire [ADDR_BITS-1:0]      rd_issue_addr_w;
    wire [AXI_ID_BITS-1:0]    rd_issue_axi_id_w;
    wire [7:0]                rd_issue_size_w;
    wire                      rd_issue_mode2_ddr_aligned_w;
    wire                      wr_aw_valid_w;
    wire [7:0]                wr_aw_slot_w;
    wire [ADDR_BITS-1:0]      wr_aw_addr_w;
    wire [AXI_ID_BITS-1:0]    wr_aw_axi_id_w;
    wire [7:0]                wr_aw_size_w;
    wire                      wr_aw_mode2_ddr_aligned_w;
    wire                      wr_w_valid_w;
    wire [7:0]                wr_w_slot_w;
    wire [7:0]                wr_w_beat_idx_w;
    wire [7:0]                wr_w_total_beats_w;
    wire [ADDR_BITS-1:0]      wr_w_issue_addr_w;
    wire                      wr_w_mode2_ddr_aligned_w;
    wire                      cache_rd_rsp_valid_w;
    wire                      bypass_rd_rsp_valid_w;
    wire                      cache_wr_rsp_valid_w;
    wire                      bypass_wr_rsp_valid_w;
    wire                      cache_resp_select_read_w;
    wire                      bypass_resp_select_read_w;
    wire                      rd_issue_handshake_w;
    wire                      wr_aw_handshake_w;
    wire                      wr_w_handshake_w;
    wire                      rd_issue_pop_w;
    wire                      rd_issue_push_w;
    wire                      wr_aw_push_w;
    wire                      wr_aw_pop_w;
    wire                      wr_w_push_w;
    wire                      wr_w_pop_w;
    wire                      cache_rd_rsp_push_w;
    wire                      bypass_rd_rsp_push_w;
    wire                      cache_wr_rsp_push_w;
    wire                      bypass_wr_rsp_push_w;
    wire                      cache_rd_rsp_pop_w;
    wire                      bypass_rd_rsp_pop_w;
    wire                      cache_wr_rsp_pop_w;
    wire                      bypass_wr_rsp_pop_w;
    wire                      rd_last_beat_w;
    wire                      rd_match_from_cache_w;
    wire                      rd_complete_from_cache_w;
    wire                      wr_match_from_cache_w;
    wire                      rd_complete_rsp_space_w;
    wire                      wr_match_rsp_space_w;
    wire [READ_RESP_BITS-1:0] rd_match_merged_data_w;
    wire [READ_RESP_BITS-1:0] rd_match_final_data_w;
    wire [1:0]                rd_match_resp_code_w;
    wire [READ_RESP_BITS-1:0] rd_complete_data_w;
    wire                      cache_rd_rsp_space_w;
    wire                      bypass_rd_rsp_space_w;
    wire                      cache_wr_rsp_space_w;
    wire                      bypass_wr_rsp_space_w;
    wire                      rd_resp_accept_w;
    wire                      rd_complete_push_w;
    wire                      wr_resp_accept_w;
    wire [7:0]                cache_req_total_beats_w;
    wire [7:0]                unused_cache_req_axi_len_w;
    wire [2:0]                unused_cache_req_axi_size_w;
    wire                      unused_bypass_req_mode2_single_axi_beat_w;
    wire [ADDR_BITS-1:0]      unused_bypass_req_mode2_issue_addr_w;
    wire [7:0]                bypass_req_mode2_issue_size_w;
    wire                      unused_rd_match_mode2_single_axi_beat_w;
    wire [ADDR_BITS-1:0]      rd_match_mode2_issue_addr_w;
    wire [7:0]                unused_rd_match_mode2_issue_size_w;
    wire [7:0]                bypass_req_issue_size_w;
    wire [7:0]                bypass_req_total_beats_w;
    wire [7:0]                unused_bypass_req_axi_len_w;
    wire [2:0]                unused_bypass_req_axi_size_w;
    wire [READ_PENDING_COUNT-1:0] rd_valid_bits_w;
    wire [READ_PENDING_COUNT-1:0] rd_complete_bits_w;
    wire [(READ_PENDING_COUNT*AXI_ID_BITS)-1:0] rd_axi_id_flat_w;
    wire [WRITE_PENDING_COUNT-1:0] wr_valid_bits_w;
    wire [WRITE_PENDING_COUNT-1:0] wr_complete_bits_w;
    wire [(WRITE_PENDING_COUNT*AXI_ID_BITS)-1:0] wr_axi_id_flat_w;
    wire                      rd_issue_space_w;
    wire                      wr_aw_space_w;
    wire                      wr_w_space_w;
    wire [7:0]                rd_issue_axi_len_w;
    wire [7:0]                unused_rd_issue_total_beats_w;
    wire [2:0]                rd_issue_axi_size_w;
    wire [7:0]                wr_aw_axi_len_w;
    wire [7:0]                unused_wr_aw_total_beats_w;
    wire [2:0]                wr_aw_axi_size_w;
    wire [7:0]                unused_rd_issue_beat_idx_w;
    wire [7:0]                unused_rd_issue_total_beats_select_w;
    wire [7:0]                unused_wr_aw_beat_idx_w;
    wire [7:0]                unused_wr_aw_total_beats_select_w;
    wire [7:0]                unused_wr_w_issue_size_w;
    wire [AXI_ID_BITS-1:0]    unused_wr_w_axi_id_w;
    wire [7:0]                rd_issue_next_head_w;
    wire [7:0]                rd_issue_next_tail_w;
    wire [7:0]                rd_issue_next_count_w;
    wire [7:0]                wr_aw_next_head_w;
    wire [7:0]                wr_aw_next_tail_w;
    wire [7:0]                wr_aw_next_count_w;
    wire [7:0]                wr_w_next_head_w;
    wire [7:0]                wr_w_next_tail_w;
    wire [7:0]                wr_w_next_count_w;
    wire [7:0]                cache_rd_rsp_next_head_w;
    wire [7:0]                cache_rd_rsp_next_tail_w;
    wire [7:0]                cache_rd_rsp_next_count_w;
    wire [7:0]                bypass_rd_rsp_next_head_w;
    wire [7:0]                bypass_rd_rsp_next_tail_w;
    wire [7:0]                bypass_rd_rsp_next_count_w;
    wire [7:0]                cache_wr_rsp_next_head_w;
    wire [7:0]                cache_wr_rsp_next_tail_w;
    wire [7:0]                cache_wr_rsp_next_count_w;
    wire [7:0]                bypass_wr_rsp_next_head_w;
    wire [7:0]                bypass_wr_rsp_next_tail_w;
    wire [7:0]                bypass_wr_rsp_next_count_w;

    axi_llc_axi_mode2_shape #(
        .ADDR_BITS(ADDR_BITS),
        .LINE_BYTES(LINE_BYTES),
        .AXI_DATA_BYTES(AXI_DATA_BYTES)
    ) bypass_req_mode2_shape (
        .addr(bypass_req_addr),
        .total_size(bypass_req_size),
        .single_axi_beat(unused_bypass_req_mode2_single_axi_beat_w),
        .issue_addr(unused_bypass_req_mode2_issue_addr_w),
        .issue_size(bypass_req_mode2_issue_size_w)
    );

    assign bypass_req_issue_size_w =
        bypass_req_mode2_ddr_aligned ? bypass_req_mode2_issue_size_w :
                                       bypass_req_size;

    axi_llc_axi_beat_shape #(
        .AXI_DATA_BYTES(AXI_DATA_BYTES)
    ) cache_req_shape (
        .total_size(cache_req_size),
        .total_beats(cache_req_total_beats_w),
        .axi_len(unused_cache_req_axi_len_w),
        .axi_size(unused_cache_req_axi_size_w)
    );

    axi_llc_axi_beat_shape #(
        .AXI_DATA_BYTES(AXI_DATA_BYTES)
    ) bypass_req_shape (
        .total_size(bypass_req_issue_size_w),
        .total_beats(bypass_req_total_beats_w),
        .axi_len(unused_bypass_req_axi_len_w),
        .axi_size(unused_bypass_req_axi_size_w)
    );

    generate
        for (pending_pack_idx = 0;
             pending_pack_idx < READ_PENDING_COUNT;
             pending_pack_idx = pending_pack_idx + 1) begin : gen_rd_pending_scan_pack
            assign rd_valid_bits_w[pending_pack_idx] = rd_valid_r[pending_pack_idx];
            assign rd_complete_bits_w[pending_pack_idx] = rd_complete_r[pending_pack_idx];
            assign rd_axi_id_flat_w[(pending_pack_idx * AXI_ID_BITS) +: AXI_ID_BITS] =
                rd_axi_id_r[pending_pack_idx];
        end
        for (pending_pack_idx = 0;
             pending_pack_idx < WRITE_PENDING_COUNT;
             pending_pack_idx = pending_pack_idx + 1) begin : gen_wr_pending_scan_pack
            assign wr_valid_bits_w[pending_pack_idx] = wr_valid_r[pending_pack_idx];
            assign wr_complete_bits_w[pending_pack_idx] = 1'b0;
            assign wr_axi_id_flat_w[(pending_pack_idx * AXI_ID_BITS) +: AXI_ID_BITS] =
                wr_axi_id_r[pending_pack_idx];
        end
    endgenerate

    axi_llc_axi_pending_scan #(
        .ENTRY_COUNT(READ_PENDING_COUNT),
        .AXI_ID_BITS(AXI_ID_BITS)
    ) read_pending_scan (
        .entry_valid(rd_valid_bits_w),
        .entry_complete(rd_complete_bits_w),
        .entry_axi_id(rd_axi_id_flat_w),
        .match_axi_id(axi_rid),
        .free_found(rd_free_found_w),
        .free_slot(rd_free_slot_w),
        .axi_id_found(rd_axi_id_found_w),
        .axi_id(rd_axi_id_w),
        .match_found(rd_match_found_w),
        .match_slot(rd_match_slot_w),
        .complete_found(rd_complete_found_w),
        .complete_slot(rd_complete_slot_w)
    );

    axi_llc_axi_pending_scan #(
        .ENTRY_COUNT(WRITE_PENDING_COUNT),
        .AXI_ID_BITS(AXI_ID_BITS)
    ) write_pending_scan (
        .entry_valid(wr_valid_bits_w),
        .entry_complete(wr_complete_bits_w),
        .entry_axi_id(wr_axi_id_flat_w),
        .match_axi_id(axi_bid),
        .free_found(wr_free_found_w),
        .free_slot(wr_free_slot_w),
        .axi_id_found(wr_axi_id_found_w),
        .axi_id(wr_axi_id_w),
        .match_found(wr_match_found_w),
        .match_slot(wr_match_slot_w),
        .complete_found(unused_wr_complete_found_w),
        .complete_slot(unused_wr_complete_slot_w)
    );

    axi_llc_axi_req_accept #(
        .AXI_ID_BITS(AXI_ID_BITS)
    ) req_accept_ctrl (
        .cache_req_valid(cache_req_valid),
        .cache_req_write(cache_req_write),
        .cache_total_beats(cache_req_total_beats_w),
        .bypass_req_valid(bypass_req_valid),
        .bypass_req_write(bypass_req_write),
        .bypass_total_beats(bypass_req_total_beats_w),
        .rd_free_found(rd_free_found_w),
        .rd_free_slot(rd_free_slot_w),
        .rd_axi_id_found(rd_axi_id_found_w),
        .rd_axi_id(rd_axi_id_w),
        .rd_issue_space(rd_issue_space_w),
        .wr_free_found(wr_free_found_w),
        .wr_free_slot(wr_free_slot_w),
        .wr_axi_id_found(wr_axi_id_found_w),
        .wr_axi_id(wr_axi_id_w),
        .wr_aw_space(wr_aw_space_w),
        .wr_w_space(wr_w_space_w),
        .accept_cache(accept_cache_w),
        .accept_bypass(accept_bypass_w),
        .accept_write(accept_write_w),
        .accept_slot(accept_slot_w),
        .accept_axi_id(accept_axi_id_w),
        .accept_total_beats(accept_total_beats_w)
    );

    axi_llc_axi_beat_shape #(
        .AXI_DATA_BYTES(AXI_DATA_BYTES)
    ) rd_issue_shape (
        .total_size(rd_issue_size_w),
        .total_beats(unused_rd_issue_total_beats_w),
        .axi_len(rd_issue_axi_len_w),
        .axi_size(rd_issue_axi_size_w)
    );

    axi_llc_axi_beat_shape #(
        .AXI_DATA_BYTES(AXI_DATA_BYTES)
    ) wr_aw_shape (
        .total_size(wr_aw_size_w),
        .total_beats(unused_wr_aw_total_beats_w),
        .axi_len(wr_aw_axi_len_w),
        .axi_size(wr_aw_axi_size_w)
    );

    assign rd_issue_slot_w = rd_issue_q_slot_r[rd_issue_head_r];
    assign wr_aw_slot_w = wr_aw_q_slot_r[wr_aw_head_r];
    assign wr_w_slot_w = wr_w_q_slot_r[wr_w_head_r];

    axi_llc_axi_issue_select #(
        .ADDR_BITS(ADDR_BITS),
        .AXI_ID_BITS(AXI_ID_BITS),
        .LINE_BYTES(LINE_BYTES),
        .AXI_DATA_BYTES(AXI_DATA_BYTES)
    ) read_issue_select (
        .queue_has_entry(rd_issue_count_r != 0),
        .slot_valid(rd_valid_r[rd_issue_slot_w]),
        .slot_from_cache(rd_from_cache_r[rd_issue_slot_w]),
        .slot_mode2_ddr_aligned(rd_mode2_ddr_aligned_r[rd_issue_slot_w]),
        .ready_to_issue(1'b1),
        .issue_done(rd_ar_sent_r[rd_issue_slot_w]),
        .slot_addr(rd_addr_r[rd_issue_slot_w]),
        .slot_size(rd_size_r[rd_issue_slot_w]),
        .slot_axi_id(rd_axi_id_r[rd_issue_slot_w]),
        .slot_beat_idx(8'd0),
        .slot_total_beats(rd_total_beats_r[rd_issue_slot_w]),
        .issue_valid(rd_issue_valid_w),
        .issue_mode2_ddr_aligned(rd_issue_mode2_ddr_aligned_w),
        .issue_addr(rd_issue_addr_w),
        .issue_size(rd_issue_size_w),
        .issue_axi_id(rd_issue_axi_id_w),
        .issue_beat_idx(unused_rd_issue_beat_idx_w),
        .issue_total_beats(unused_rd_issue_total_beats_select_w)
    );

    axi_llc_axi_issue_select #(
        .ADDR_BITS(ADDR_BITS),
        .AXI_ID_BITS(AXI_ID_BITS),
        .LINE_BYTES(LINE_BYTES),
        .AXI_DATA_BYTES(AXI_DATA_BYTES)
    ) write_aw_select (
        .queue_has_entry(wr_aw_count_r != 0),
        .slot_valid(wr_valid_r[wr_aw_slot_w]),
        .slot_from_cache(wr_from_cache_r[wr_aw_slot_w]),
        .slot_mode2_ddr_aligned(wr_mode2_ddr_aligned_r[wr_aw_slot_w]),
        .ready_to_issue(1'b1),
        .issue_done(wr_aw_sent_r[wr_aw_slot_w]),
        .slot_addr(wr_addr_r[wr_aw_slot_w]),
        .slot_size(wr_size_r[wr_aw_slot_w]),
        .slot_axi_id(wr_axi_id_r[wr_aw_slot_w]),
        .slot_beat_idx(8'd0),
        .slot_total_beats(wr_total_beats_r[wr_aw_slot_w]),
        .issue_valid(wr_aw_valid_w),
        .issue_mode2_ddr_aligned(wr_aw_mode2_ddr_aligned_w),
        .issue_addr(wr_aw_addr_w),
        .issue_size(wr_aw_size_w),
        .issue_axi_id(wr_aw_axi_id_w),
        .issue_beat_idx(unused_wr_aw_beat_idx_w),
        .issue_total_beats(unused_wr_aw_total_beats_select_w)
    );

    axi_llc_axi_issue_select #(
        .ADDR_BITS(ADDR_BITS),
        .AXI_ID_BITS(AXI_ID_BITS),
        .LINE_BYTES(LINE_BYTES),
        .AXI_DATA_BYTES(AXI_DATA_BYTES)
    ) write_w_select (
        .queue_has_entry(wr_w_count_r != 0),
        .slot_valid(wr_valid_r[wr_w_slot_w]),
        .slot_from_cache(wr_from_cache_r[wr_w_slot_w]),
        .slot_mode2_ddr_aligned(wr_mode2_ddr_aligned_r[wr_w_slot_w]),
        .ready_to_issue(wr_aw_sent_r[wr_w_slot_w]),
        .issue_done(wr_w_done_r[wr_w_slot_w]),
        .slot_addr(wr_addr_r[wr_w_slot_w]),
        .slot_size(wr_size_r[wr_w_slot_w]),
        .slot_axi_id(wr_axi_id_r[wr_w_slot_w]),
        .slot_beat_idx(wr_beats_sent_r[wr_w_slot_w]),
        .slot_total_beats(wr_total_beats_r[wr_w_slot_w]),
        .issue_valid(wr_w_valid_w),
        .issue_mode2_ddr_aligned(wr_w_mode2_ddr_aligned_w),
        .issue_addr(wr_w_issue_addr_w),
        .issue_size(unused_wr_w_issue_size_w),
        .issue_axi_id(unused_wr_w_axi_id_w),
        .issue_beat_idx(wr_w_beat_idx_w),
        .issue_total_beats(wr_w_total_beats_w)
    );

    axi_llc_axi_queue_ctrl #(
        .READ_DEPTH(READ_PENDING_COUNT),
        .WRITE_DEPTH(WRITE_PENDING_COUNT)
    ) queue_ctrl (
        .rd_issue_count(rd_issue_count_r),
        .wr_aw_count(wr_aw_count_r),
        .wr_w_count(wr_w_count_r),
        .cache_rd_rsp_count(cache_rd_rsp_count_r),
        .bypass_rd_rsp_count(bypass_rd_rsp_count_r),
        .cache_wr_rsp_count(cache_wr_rsp_count_r),
        .bypass_wr_rsp_count(bypass_wr_rsp_count_r),
        .accept_cache(accept_cache_w),
        .accept_bypass(accept_bypass_w),
        .accept_write(accept_write_w),
        .rd_issue_valid(rd_issue_valid_w),
        .axi_arready(axi_arready),
        .wr_aw_valid(wr_aw_valid_w),
        .axi_awready(axi_awready),
        .wr_w_valid(wr_w_valid_w),
        .axi_wready(axi_wready),
        .axi_wlast(axi_wlast),
        .rd_issue_space(rd_issue_space_w),
        .wr_aw_space(wr_aw_space_w),
        .wr_w_space(wr_w_space_w),
        .cache_rd_rsp_valid(cache_rd_rsp_valid_w),
        .bypass_rd_rsp_valid(bypass_rd_rsp_valid_w),
        .cache_wr_rsp_valid(cache_wr_rsp_valid_w),
        .bypass_wr_rsp_valid(bypass_wr_rsp_valid_w),
        .cache_rd_rsp_space(cache_rd_rsp_space_w),
        .bypass_rd_rsp_space(bypass_rd_rsp_space_w),
        .cache_wr_rsp_space(cache_wr_rsp_space_w),
        .bypass_wr_rsp_space(bypass_wr_rsp_space_w),
        .rd_issue_handshake(rd_issue_handshake_w),
        .wr_aw_handshake(wr_aw_handshake_w),
        .wr_w_handshake(wr_w_handshake_w),
        .rd_issue_push(rd_issue_push_w),
        .rd_issue_pop(rd_issue_pop_w),
        .wr_aw_push(wr_aw_push_w),
        .wr_aw_pop(wr_aw_pop_w),
        .wr_w_push(wr_w_push_w),
        .wr_w_pop(wr_w_pop_w)
    );

    axi_llc_axi_fifo_ptr #(
        .DEPTH(READ_PENDING_COUNT)
    ) rd_issue_fifo_ptr (
        .head(rd_issue_head_r),
        .tail(rd_issue_tail_r),
        .count(rd_issue_count_r),
        .push(rd_issue_push_w),
        .pop(rd_issue_pop_w),
        .next_head(rd_issue_next_head_w),
        .next_tail(rd_issue_next_tail_w),
        .next_count(rd_issue_next_count_w)
    );

    axi_llc_axi_fifo_ptr #(
        .DEPTH(WRITE_PENDING_COUNT)
    ) wr_aw_fifo_ptr (
        .head(wr_aw_head_r),
        .tail(wr_aw_tail_r),
        .count(wr_aw_count_r),
        .push(wr_aw_push_w),
        .pop(wr_aw_pop_w),
        .next_head(wr_aw_next_head_w),
        .next_tail(wr_aw_next_tail_w),
        .next_count(wr_aw_next_count_w)
    );

    axi_llc_axi_fifo_ptr #(
        .DEPTH(WRITE_PENDING_COUNT)
    ) wr_w_fifo_ptr (
        .head(wr_w_head_r),
        .tail(wr_w_tail_r),
        .count(wr_w_count_r),
        .push(wr_w_push_w),
        .pop(wr_w_pop_w),
        .next_head(wr_w_next_head_w),
        .next_tail(wr_w_next_tail_w),
        .next_count(wr_w_next_count_w)
    );

    axi_llc_axi_fifo_ptr #(
        .DEPTH(READ_PENDING_COUNT)
    ) cache_rd_rsp_fifo_ptr (
        .head(cache_rd_rsp_head_r),
        .tail(cache_rd_rsp_tail_r),
        .count(cache_rd_rsp_count_r),
        .push(cache_rd_rsp_push_w),
        .pop(cache_rd_rsp_pop_w),
        .next_head(cache_rd_rsp_next_head_w),
        .next_tail(cache_rd_rsp_next_tail_w),
        .next_count(cache_rd_rsp_next_count_w)
    );

    axi_llc_axi_fifo_ptr #(
        .DEPTH(READ_PENDING_COUNT)
    ) bypass_rd_rsp_fifo_ptr (
        .head(bypass_rd_rsp_head_r),
        .tail(bypass_rd_rsp_tail_r),
        .count(bypass_rd_rsp_count_r),
        .push(bypass_rd_rsp_push_w),
        .pop(bypass_rd_rsp_pop_w),
        .next_head(bypass_rd_rsp_next_head_w),
        .next_tail(bypass_rd_rsp_next_tail_w),
        .next_count(bypass_rd_rsp_next_count_w)
    );

    axi_llc_axi_fifo_ptr #(
        .DEPTH(WRITE_PENDING_COUNT)
    ) cache_wr_rsp_fifo_ptr (
        .head(cache_wr_rsp_head_r),
        .tail(cache_wr_rsp_tail_r),
        .count(cache_wr_rsp_count_r),
        .push(cache_wr_rsp_push_w),
        .pop(cache_wr_rsp_pop_w),
        .next_head(cache_wr_rsp_next_head_w),
        .next_tail(cache_wr_rsp_next_tail_w),
        .next_count(cache_wr_rsp_next_count_w)
    );

    axi_llc_axi_fifo_ptr #(
        .DEPTH(WRITE_PENDING_COUNT)
    ) bypass_wr_rsp_fifo_ptr (
        .head(bypass_wr_rsp_head_r),
        .tail(bypass_wr_rsp_tail_r),
        .count(bypass_wr_rsp_count_r),
        .push(bypass_wr_rsp_push_w),
        .pop(bypass_wr_rsp_pop_w),
        .next_head(bypass_wr_rsp_next_head_w),
        .next_tail(bypass_wr_rsp_next_tail_w),
        .next_count(bypass_wr_rsp_next_count_w)
    );

    assign rd_match_from_cache_w = rd_from_cache_r[rd_match_slot_w];
    assign wr_match_from_cache_w = wr_from_cache_r[wr_match_slot_w];
    axi_llc_axi_mode2_shape #(
        .ADDR_BITS(ADDR_BITS),
        .LINE_BYTES(LINE_BYTES),
        .AXI_DATA_BYTES(AXI_DATA_BYTES)
    ) rd_match_mode2_shape (
        .addr(rd_addr_r[rd_match_slot_w]),
        .total_size(rd_size_r[rd_match_slot_w]),
        .single_axi_beat(unused_rd_match_mode2_single_axi_beat_w),
        .issue_addr(rd_match_mode2_issue_addr_w),
        .issue_size(unused_rd_match_mode2_issue_size_w)
    );

    axi_llc_axi_read_pack #(
        .ADDR_BITS(ADDR_BITS),
        .READ_RESP_BYTES(READ_RESP_BYTES),
        .AXI_DATA_BYTES(AXI_DATA_BYTES),
        .MODE2_EXTRACT_BYTES(READ_PACK_MODE2_EXTRACT_BYTES)
    ) read_pack (
        .current_data(rd_rdata_r[rd_match_slot_w]),
        .beat_data(axi_rdata),
        .req_addr(rd_addr_r[rd_match_slot_w]),
        .issued_addr(rd_match_mode2_issue_addr_w),
        .beat_idx(rd_beats_done_r[rd_match_slot_w]),
        .mode2_ddr_aligned(!rd_from_cache_r[rd_match_slot_w] &&
                           rd_mode2_ddr_aligned_r[rd_match_slot_w]),
        .merged_data(rd_match_merged_data_w),
        .final_data(rd_match_final_data_w)
    );

    axi_llc_axi_read_resp_ctrl read_resp_ctrl (
        .rd_match_found(rd_match_found_w),
        .rd_beats_done(rd_beats_done_r[rd_match_slot_w]),
        .rd_total_beats(rd_total_beats_r[rd_match_slot_w]),
        .axi_rlast(axi_rlast),
        .axi_rresp(axi_rresp),
        .current_resp_code(rd_resp_code_r[rd_match_slot_w]),
        .rd_last_beat(rd_last_beat_w),
        .next_resp_code(rd_match_resp_code_w)
    );

    assign rd_complete_from_cache_w = rd_from_cache_r[rd_complete_slot_w];
    assign rd_complete_data_w = rd_rdata_r[rd_complete_slot_w];

    axi_llc_axi_resp_accept resp_accept_ctrl (
        .axi_rvalid(axi_rvalid),
        .rd_match_found(rd_match_found_w),
        .axi_rready(axi_rready),
        .rd_resp_accept(rd_resp_accept_w),
        .axi_bvalid(axi_bvalid),
        .wr_match_found(wr_match_found_w),
        .wr_match_rsp_space(wr_match_rsp_space_w),
        .axi_bready(axi_bready),
        .wr_resp_accept(wr_resp_accept_w)
    );

    axi_llc_axi_resp_route resp_route_ctrl (
        .rd_complete_found(rd_complete_found_w),
        .rd_complete_from_cache(rd_complete_from_cache_w),
        .cache_rd_rsp_space(cache_rd_rsp_space_w),
        .bypass_rd_rsp_space(bypass_rd_rsp_space_w),
        .wr_match_from_cache(wr_match_from_cache_w),
        .cache_wr_rsp_space(cache_wr_rsp_space_w),
        .bypass_wr_rsp_space(bypass_wr_rsp_space_w),
        .wr_resp_accept(wr_resp_accept_w),
        .rd_complete_rsp_space(rd_complete_rsp_space_w),
        .rd_complete_push(rd_complete_push_w),
        .cache_rd_rsp_push(cache_rd_rsp_push_w),
        .bypass_rd_rsp_push(bypass_rd_rsp_push_w),
        .wr_match_rsp_space(wr_match_rsp_space_w),
        .cache_wr_rsp_push(cache_wr_rsp_push_w),
        .bypass_wr_rsp_push(bypass_wr_rsp_push_w)
    );

    assign cache_req_ready = accept_cache_w;
    assign bypass_req_ready = accept_bypass_w;

    assign axi_arvalid = rd_issue_valid_w;
    assign axi_arid = rd_issue_axi_id_w;
    assign axi_araddr = rd_issue_addr_w;
    assign axi_arlen = rd_issue_axi_len_w;
    assign axi_arsize = rd_issue_axi_size_w;
    assign axi_arburst = AXI_BURST_INCR;

    assign axi_awvalid = wr_aw_valid_w;
    assign axi_awid = wr_aw_axi_id_w;
    assign axi_awaddr = wr_aw_addr_w;
    assign axi_awlen = wr_aw_axi_len_w;
    assign axi_awsize = wr_aw_axi_size_w;
    assign axi_awburst = AXI_BURST_INCR;

    assign axi_wvalid = wr_w_valid_w;
    axi_llc_axi_write_pack #(
        .ADDR_BITS(ADDR_BITS),
        .LINE_BYTES(LINE_BYTES),
        .AXI_DATA_BYTES(AXI_DATA_BYTES),
        .SINGLE_BEAT_ONLY(WRITE_PACK_SINGLE_BEAT_ONLY)
    ) write_pack (
        .line_data(wr_wdata_r[wr_w_slot_w]),
        .line_strb(wr_wstrb_r[wr_w_slot_w]),
        .req_addr(wr_addr_r[wr_w_slot_w]),
        .issued_addr(wr_w_issue_addr_w),
        .beat_idx(wr_w_beat_idx_w),
        .mode2_ddr_aligned(wr_w_mode2_ddr_aligned_w),
        .axi_wdata(axi_wdata),
        .axi_wstrb(axi_wstrb)
    );
    assign axi_wlast = (wr_w_beat_idx_w + 8'd1 == wr_w_total_beats_w);

    axi_llc_axi_source_resp_mux #(
        .DATA_BITS(READ_RESP_BITS),
        .ID_BITS(ID_BITS)
    ) cache_resp_mux (
        .rd_valid(cache_rd_rsp_valid_w),
        .rd_data(cache_rd_rsp_data_r[cache_rd_rsp_head_r]),
        .rd_id(cache_rd_rsp_id_r[cache_rd_rsp_head_r]),
        .rd_code(cache_rd_rsp_code_r[cache_rd_rsp_head_r]),
        .wr_valid(cache_wr_rsp_valid_w),
        .wr_id(cache_wr_rsp_id_r[cache_wr_rsp_head_r]),
        .wr_code(cache_wr_rsp_code_r[cache_wr_rsp_head_r]),
        .resp_ready(cache_resp_ready),
        .resp_valid(cache_resp_valid),
        .select_read(cache_resp_select_read_w),
        .resp_data(cache_resp_rdata),
        .resp_id(cache_resp_id),
        .resp_code(cache_resp_code),
        .rd_pop(cache_rd_rsp_pop_w),
        .wr_pop(cache_wr_rsp_pop_w)
    );

    axi_llc_axi_source_resp_mux #(
        .DATA_BITS(READ_RESP_BITS),
        .ID_BITS(ID_BITS)
    ) bypass_resp_mux (
        .rd_valid(bypass_rd_rsp_valid_w),
        .rd_data(bypass_rd_rsp_data_r[bypass_rd_rsp_head_r]),
        .rd_id(bypass_rd_rsp_id_r[bypass_rd_rsp_head_r]),
        .rd_code(bypass_rd_rsp_code_r[bypass_rd_rsp_head_r]),
        .wr_valid(bypass_wr_rsp_valid_w),
        .wr_id(bypass_wr_rsp_id_r[bypass_wr_rsp_head_r]),
        .wr_code(bypass_wr_rsp_code_r[bypass_wr_rsp_head_r]),
        .resp_ready(bypass_resp_ready),
        .resp_valid(bypass_resp_valid),
        .select_read(bypass_resp_select_read_w),
        .resp_data(bypass_resp_rdata),
        .resp_id(bypass_resp_id),
        .resp_code(bypass_resp_code),
        .rd_pop(bypass_rd_rsp_pop_w),
        .wr_pop(bypass_wr_rsp_pop_w)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_issue_head_r <= 8'd0;
            rd_issue_tail_r <= 8'd0;
            rd_issue_count_r <= 8'd0;
            wr_aw_head_r <= 8'd0;
            wr_aw_tail_r <= 8'd0;
            wr_aw_count_r <= 8'd0;
            wr_w_head_r <= 8'd0;
            wr_w_tail_r <= 8'd0;
            wr_w_count_r <= 8'd0;
            cache_rd_rsp_head_r <= 8'd0;
            cache_rd_rsp_tail_r <= 8'd0;
            cache_rd_rsp_count_r <= 8'd0;
            bypass_rd_rsp_head_r <= 8'd0;
            bypass_rd_rsp_tail_r <= 8'd0;
            bypass_rd_rsp_count_r <= 8'd0;
            cache_wr_rsp_head_r <= 8'd0;
            cache_wr_rsp_tail_r <= 8'd0;
            cache_wr_rsp_count_r <= 8'd0;
            bypass_wr_rsp_head_r <= 8'd0;
            bypass_wr_rsp_tail_r <= 8'd0;
            bypass_wr_rsp_count_r <= 8'd0;
            for (seq_idx = 0; seq_idx < READ_PENDING_COUNT; seq_idx = seq_idx + 1) begin
                rd_valid_r[seq_idx] <= 1'b0;
                rd_from_cache_r[seq_idx] <= 1'b0;
                rd_addr_r[seq_idx] <= {ADDR_BITS{1'b0}};
                rd_req_id_r[seq_idx] <= {ID_BITS{1'b0}};
                rd_size_r[seq_idx] <= 8'd0;
                rd_mode2_ddr_aligned_r[seq_idx] <= 1'b0;
                rd_axi_id_r[seq_idx] <= {AXI_ID_BITS{1'b0}};
                rd_total_beats_r[seq_idx] <= 8'd0;
                rd_beats_done_r[seq_idx] <= 8'd0;
                rd_ar_sent_r[seq_idx] <= 1'b0;
                rd_complete_r[seq_idx] <= 1'b0;
                rd_resp_code_r[seq_idx] <= RESP_OKAY;
                rd_issue_q_slot_r[seq_idx] <= 8'd0;
                cache_rd_rsp_id_r[seq_idx] <= {ID_BITS{1'b0}};
                cache_rd_rsp_code_r[seq_idx] <= RESP_OKAY;
                bypass_rd_rsp_id_r[seq_idx] <= {ID_BITS{1'b0}};
                bypass_rd_rsp_code_r[seq_idx] <= RESP_OKAY;
            end
            for (seq_idx = 0; seq_idx < WRITE_PENDING_COUNT; seq_idx = seq_idx + 1) begin
                wr_valid_r[seq_idx] <= 1'b0;
                wr_from_cache_r[seq_idx] <= 1'b0;
                wr_addr_r[seq_idx] <= {ADDR_BITS{1'b0}};
                wr_req_id_r[seq_idx] <= {ID_BITS{1'b0}};
                wr_size_r[seq_idx] <= 8'd0;
                wr_mode2_ddr_aligned_r[seq_idx] <= 1'b0;
                wr_axi_id_r[seq_idx] <= {AXI_ID_BITS{1'b0}};
                wr_total_beats_r[seq_idx] <= 8'd0;
                wr_beats_sent_r[seq_idx] <= 8'd0;
                wr_aw_sent_r[seq_idx] <= 1'b0;
                wr_w_done_r[seq_idx] <= 1'b0;
                wr_aw_q_slot_r[seq_idx] <= 8'd0;
                wr_w_q_slot_r[seq_idx] <= 8'd0;
                cache_wr_rsp_id_r[seq_idx] <= {ID_BITS{1'b0}};
                cache_wr_rsp_code_r[seq_idx] <= RESP_OKAY;
                bypass_wr_rsp_id_r[seq_idx] <= {ID_BITS{1'b0}};
                bypass_wr_rsp_code_r[seq_idx] <= RESP_OKAY;
            end
        end else begin
            if (accept_cache_w || accept_bypass_w) begin
                if (accept_write_w) begin
                    wr_valid_r[accept_slot_w] <= 1'b1;
                    wr_from_cache_r[accept_slot_w] <= accept_cache_w;
                    wr_addr_r[accept_slot_w] <= accept_cache_w ? cache_req_addr : bypass_req_addr;
                    wr_req_id_r[accept_slot_w] <= accept_cache_w ? cache_req_id : bypass_req_id;
                    wr_size_r[accept_slot_w] <= accept_cache_w ? cache_req_size : bypass_req_size;
                    wr_mode2_ddr_aligned_r[accept_slot_w] <=
                        accept_cache_w ? 1'b0 : bypass_req_mode2_ddr_aligned;
                    wr_wdata_r[accept_slot_w] <= accept_cache_w ? cache_req_wdata : bypass_req_wdata;
                    wr_wstrb_r[accept_slot_w] <= accept_cache_w ? cache_req_wstrb : bypass_req_wstrb;
                    wr_axi_id_r[accept_slot_w] <= accept_axi_id_w;
                    wr_total_beats_r[accept_slot_w] <= accept_total_beats_w;
                    wr_beats_sent_r[accept_slot_w] <= 8'd0;
                    wr_aw_sent_r[accept_slot_w] <= 1'b0;
                    wr_w_done_r[accept_slot_w] <= 1'b0;
                end else begin
                    rd_valid_r[accept_slot_w] <= 1'b1;
                    rd_from_cache_r[accept_slot_w] <= accept_cache_w;
                    rd_addr_r[accept_slot_w] <= accept_cache_w ? cache_req_addr : bypass_req_addr;
                    rd_req_id_r[accept_slot_w] <= accept_cache_w ? cache_req_id : bypass_req_id;
                    rd_size_r[accept_slot_w] <= accept_cache_w ? cache_req_size : bypass_req_size;
                    rd_mode2_ddr_aligned_r[accept_slot_w] <=
                        accept_cache_w ? 1'b0 : bypass_req_mode2_ddr_aligned;
                    rd_axi_id_r[accept_slot_w] <= accept_axi_id_w;
                    rd_total_beats_r[accept_slot_w] <= accept_total_beats_w;
                    rd_beats_done_r[accept_slot_w] <= 8'd0;
                    rd_ar_sent_r[accept_slot_w] <= 1'b0;
                    rd_complete_r[accept_slot_w] <= 1'b0;
                    rd_rdata_r[accept_slot_w] <= {READ_RESP_BITS{1'b0}};
                    rd_resp_code_r[accept_slot_w] <= RESP_OKAY;
                end
            end

            if (rd_issue_push_w) begin
                rd_issue_q_slot_r[rd_issue_tail_r] <= accept_slot_w;
            end
            rd_issue_head_r <= rd_issue_next_head_w;
            rd_issue_tail_r <= rd_issue_next_tail_w;
            rd_issue_count_r <= rd_issue_next_count_w;

            if (wr_aw_push_w) begin
                wr_aw_q_slot_r[wr_aw_tail_r] <= accept_slot_w;
            end
            wr_aw_head_r <= wr_aw_next_head_w;
            wr_aw_tail_r <= wr_aw_next_tail_w;
            wr_aw_count_r <= wr_aw_next_count_w;

            if (wr_w_push_w) begin
                wr_w_q_slot_r[wr_w_tail_r] <= accept_slot_w;
            end
            wr_w_head_r <= wr_w_next_head_w;
            wr_w_tail_r <= wr_w_next_tail_w;
            wr_w_count_r <= wr_w_next_count_w;

            if (cache_rd_rsp_push_w) begin
                cache_rd_rsp_id_r[cache_rd_rsp_tail_r] <= rd_req_id_r[rd_complete_slot_w];
                cache_rd_rsp_code_r[cache_rd_rsp_tail_r] <= rd_resp_code_r[rd_complete_slot_w];
                cache_rd_rsp_data_r[cache_rd_rsp_tail_r] <= rd_complete_data_w;
            end
            cache_rd_rsp_head_r <= cache_rd_rsp_next_head_w;
            cache_rd_rsp_tail_r <= cache_rd_rsp_next_tail_w;
            cache_rd_rsp_count_r <= cache_rd_rsp_next_count_w;

            if (bypass_rd_rsp_push_w) begin
                bypass_rd_rsp_id_r[bypass_rd_rsp_tail_r] <= rd_req_id_r[rd_complete_slot_w];
                bypass_rd_rsp_code_r[bypass_rd_rsp_tail_r] <= rd_resp_code_r[rd_complete_slot_w];
                bypass_rd_rsp_data_r[bypass_rd_rsp_tail_r] <= rd_complete_data_w;
            end
            bypass_rd_rsp_head_r <= bypass_rd_rsp_next_head_w;
            bypass_rd_rsp_tail_r <= bypass_rd_rsp_next_tail_w;
            bypass_rd_rsp_count_r <= bypass_rd_rsp_next_count_w;

            if (cache_wr_rsp_push_w) begin
                cache_wr_rsp_id_r[cache_wr_rsp_tail_r] <= wr_req_id_r[wr_match_slot_w];
                cache_wr_rsp_code_r[cache_wr_rsp_tail_r] <= axi_bresp;
            end
            cache_wr_rsp_head_r <= cache_wr_rsp_next_head_w;
            cache_wr_rsp_tail_r <= cache_wr_rsp_next_tail_w;
            cache_wr_rsp_count_r <= cache_wr_rsp_next_count_w;

            if (bypass_wr_rsp_push_w) begin
                bypass_wr_rsp_id_r[bypass_wr_rsp_tail_r] <= wr_req_id_r[wr_match_slot_w];
                bypass_wr_rsp_code_r[bypass_wr_rsp_tail_r] <= axi_bresp;
            end
            bypass_wr_rsp_head_r <= bypass_wr_rsp_next_head_w;
            bypass_wr_rsp_tail_r <= bypass_wr_rsp_next_tail_w;
            bypass_wr_rsp_count_r <= bypass_wr_rsp_next_count_w;

            if (rd_issue_handshake_w) begin
                rd_ar_sent_r[rd_issue_slot_w] <= 1'b1;
            end

            if (rd_resp_accept_w) begin
                if (rd_last_beat_w) begin
                    rd_rdata_r[rd_match_slot_w] <= rd_match_final_data_w;
                    rd_resp_code_r[rd_match_slot_w] <= rd_match_resp_code_w;
                    rd_complete_r[rd_match_slot_w] <= 1'b1;
                end else begin
                    rd_rdata_r[rd_match_slot_w] <= rd_match_merged_data_w;
                    rd_resp_code_r[rd_match_slot_w] <= rd_match_resp_code_w;
                    rd_beats_done_r[rd_match_slot_w] <=
                        rd_beats_done_r[rd_match_slot_w] + 8'd1;
                end
            end

            if (rd_complete_push_w) begin
                rd_valid_r[rd_complete_slot_w] <= 1'b0;
                rd_ar_sent_r[rd_complete_slot_w] <= 1'b0;
                rd_complete_r[rd_complete_slot_w] <= 1'b0;
            end

            if (wr_aw_handshake_w) begin
                wr_aw_sent_r[wr_aw_slot_w] <= 1'b1;
            end

            if (wr_w_handshake_w) begin
                if (axi_wlast) begin
                    wr_beats_sent_r[wr_w_slot_w] <= 8'd0;
                    wr_w_done_r[wr_w_slot_w] <= 1'b1;
                end else begin
                    wr_beats_sent_r[wr_w_slot_w] <=
                        wr_beats_sent_r[wr_w_slot_w] + 8'd1;
                end
            end

            if (wr_resp_accept_w) begin
                wr_valid_r[wr_match_slot_w] <= 1'b0;
                wr_aw_sent_r[wr_match_slot_w] <= 1'b0;
                wr_w_done_r[wr_match_slot_w] <= 1'b0;
            end
        end
    end

endmodule
