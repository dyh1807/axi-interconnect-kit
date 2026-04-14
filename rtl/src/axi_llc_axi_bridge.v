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
    parameter ID_BITS         = `AXI_LLC_ID_BITS,
    parameter LINE_BYTES      = `AXI_LLC_LINE_BYTES,
    parameter LINE_BITS       = `AXI_LLC_LINE_BITS,
    parameter AXI_ID_BITS     = `AXI_LLC_AXI_ID_BITS,
    parameter AXI_DATA_BYTES  = `AXI_LLC_AXI_DATA_BYTES,
    parameter AXI_DATA_BITS   = `AXI_LLC_AXI_DATA_BITS,
    parameter AXI_STRB_BITS   = `AXI_LLC_AXI_STRB_BITS,
    parameter READ_RESP_BYTES = `AXI_LLC_READ_RESP_BYTES,
    parameter READ_RESP_BITS  = `AXI_LLC_READ_RESP_BITS
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
    localparam integer READ_PENDING_COUNT  = `AXI_LLC_MAX_OUTSTANDING;
    localparam integer WRITE_PENDING_COUNT = `AXI_LLC_MAX_WRITE_OUTSTANDING;
    localparam integer AXI_ID_COUNT        = (1 << AXI_ID_BITS);
    localparam [2:0] AXI_SIZE_CODE =
        (AXI_DATA_BYTES == 32) ? 3'd5 :
        (AXI_DATA_BYTES == 16) ? 3'd4 :
        (AXI_DATA_BYTES == 8)  ? 3'd3 : 3'd2;

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

    reg                           rd_free_found_w;
    reg [7:0]                     rd_free_slot_w;
    reg [AXI_ID_COUNT-1:0]        rd_axi_id_used_w;
    reg                           rd_axi_id_found_w;
    reg [AXI_ID_BITS-1:0]         rd_axi_id_w;
    reg                           wr_free_found_w;
    reg [7:0]                     wr_free_slot_w;
    reg [AXI_ID_COUNT-1:0]        wr_axi_id_used_w;
    reg                           wr_axi_id_found_w;
    reg [AXI_ID_BITS-1:0]         wr_axi_id_w;
    reg                           accept_cache_w;
    reg                           accept_bypass_w;
    reg                           accept_write_w;
    reg [7:0]                     accept_slot_w;
    reg [AXI_ID_BITS-1:0]         accept_axi_id_w;
    reg [7:0]                     accept_total_beats_w;
    reg [7:0]                     rd_match_slot_w;
    reg                           rd_match_found_w;
    reg [7:0]                     rd_complete_slot_w;
    reg                           rd_complete_found_w;
    reg [7:0]                     wr_match_slot_w;
    reg                           wr_match_found_w;

    integer                       idx;

    function [7:0] calc_total_beats;
        input [7:0] total_size;
        reg [15:0] bytes;
        reg [15:0] beats;
        begin
            bytes = {8'd0, total_size} + 16'd1;
            beats = (bytes + AXI_DATA_BYTES - 1) / AXI_DATA_BYTES;
            if (beats == 0) begin
                calc_total_beats = 8'd1;
            end else begin
                calc_total_beats = beats[7:0];
            end
        end
    endfunction

    function [7:0] calc_burst_len;
        input [7:0] total_size;
        begin
            calc_burst_len = calc_total_beats(total_size) - 8'd1;
        end
    endfunction

    function [ADDR_BITS-1:0] align_down_addr;
        input [ADDR_BITS-1:0] addr_value;
        input integer         align_bytes;
        begin
            if (align_bytes <= 1) begin
                align_down_addr = addr_value;
            end else begin
                align_down_addr = (addr_value / align_bytes) * align_bytes;
            end
        end
    endfunction

    function mode2_single_axi_beat;
        input [ADDR_BITS-1:0] addr_value;
        input [7:0]           total_size;
        reg [15:0]            req_bytes;
        reg [ADDR_BITS-1:0]   beat_addr;
        reg [ADDR_BITS:0]     end_byte;
        begin
            req_bytes = {8'd0, total_size} + 16'd1;
            beat_addr = align_down_addr(addr_value, AXI_DATA_BYTES);
            end_byte = {1'b0, (addr_value - beat_addr)} + req_bytes;
            mode2_single_axi_beat =
                (req_bytes <= AXI_DATA_BYTES) &&
                (end_byte <= AXI_DATA_BYTES);
        end
    endfunction

    function [ADDR_BITS-1:0] mode2_issue_addr;
        input [ADDR_BITS-1:0] addr_value;
        input [7:0]           total_size;
        begin
            if (mode2_single_axi_beat(addr_value, total_size)) begin
                mode2_issue_addr = align_down_addr(addr_value, AXI_DATA_BYTES);
            end else begin
                mode2_issue_addr = align_down_addr(addr_value, LINE_BYTES);
            end
        end
    endfunction

    function [7:0] mode2_issue_size;
        input [ADDR_BITS-1:0] addr_value;
        input [7:0]           total_size;
        begin
            if (mode2_single_axi_beat(addr_value, total_size)) begin
                mode2_issue_size = AXI_DATA_BYTES - 1;
            end else begin
                mode2_issue_size = LINE_BYTES - 1;
            end
        end
    endfunction

    function [AXI_DATA_BITS-1:0] pack_write_beat;
        input [LINE_BITS-1:0] line_data;
        input [7:0] beat_idx;
        integer byte_idx;
        integer src_byte;
        begin
            pack_write_beat = {AXI_DATA_BITS{1'b0}};
            for (byte_idx = 0; byte_idx < AXI_DATA_BYTES; byte_idx = byte_idx + 1) begin
                src_byte = beat_idx * AXI_DATA_BYTES + byte_idx;
                if (src_byte < LINE_BYTES) begin
                    pack_write_beat[(byte_idx * 8) +: 8] =
                        line_data[(src_byte * 8) +: 8];
                end
            end
        end
    endfunction

    function [AXI_DATA_BITS-1:0] pack_mode2_write_beat;
        input [LINE_BITS-1:0]      line_data;
        input [ADDR_BITS-1:0]      req_addr;
        input [ADDR_BITS-1:0]      issued_addr;
        input [7:0]                beat_idx;
        integer byte_idx;
        integer dst_byte;
        integer src_byte;
        integer byte_off;
        begin
            pack_mode2_write_beat = {AXI_DATA_BITS{1'b0}};
            byte_off = req_addr - issued_addr;
            for (byte_idx = 0; byte_idx < AXI_DATA_BYTES; byte_idx = byte_idx + 1) begin
                dst_byte = beat_idx * AXI_DATA_BYTES + byte_idx;
                src_byte = dst_byte - byte_off;
                if ((dst_byte >= byte_off) &&
                    (src_byte >= 0) &&
                    (src_byte < LINE_BYTES)) begin
                    pack_mode2_write_beat[(byte_idx * 8) +: 8] =
                        line_data[(src_byte * 8) +: 8];
                end
            end
        end
    endfunction

    function [AXI_STRB_BITS-1:0] pack_write_strobe;
        input [LINE_BYTES-1:0] line_strb;
        input [7:0] beat_idx;
        integer byte_idx;
        integer src_byte;
        begin
            pack_write_strobe = {AXI_STRB_BITS{1'b0}};
            for (byte_idx = 0; byte_idx < AXI_DATA_BYTES; byte_idx = byte_idx + 1) begin
                src_byte = beat_idx * AXI_DATA_BYTES + byte_idx;
                if (src_byte < LINE_BYTES) begin
                    pack_write_strobe[byte_idx] = line_strb[src_byte];
                end
            end
        end
    endfunction

    function [AXI_STRB_BITS-1:0] pack_mode2_write_strobe;
        input [LINE_BYTES-1:0]     line_strb;
        input [ADDR_BITS-1:0]      req_addr;
        input [ADDR_BITS-1:0]      issued_addr;
        input [7:0]                beat_idx;
        integer byte_idx;
        integer dst_byte;
        integer src_byte;
        integer byte_off;
        begin
            pack_mode2_write_strobe = {AXI_STRB_BITS{1'b0}};
            byte_off = req_addr - issued_addr;
            for (byte_idx = 0; byte_idx < AXI_DATA_BYTES; byte_idx = byte_idx + 1) begin
                dst_byte = beat_idx * AXI_DATA_BYTES + byte_idx;
                src_byte = dst_byte - byte_off;
                if ((dst_byte >= byte_off) &&
                    (src_byte >= 0) &&
                    (src_byte < LINE_BYTES)) begin
                    pack_mode2_write_strobe[byte_idx] = line_strb[src_byte];
                end
            end
        end
    endfunction

    function [READ_RESP_BITS-1:0] merge_read_beat;
        input [READ_RESP_BITS-1:0] line_data;
        input [AXI_DATA_BITS-1:0] beat_data;
        input [7:0] beat_idx;
        integer byte_idx;
        integer dst_byte;
        begin
            merge_read_beat = line_data;
            for (byte_idx = 0; byte_idx < AXI_DATA_BYTES; byte_idx = byte_idx + 1) begin
                dst_byte = beat_idx * AXI_DATA_BYTES + byte_idx;
                if (dst_byte < READ_RESP_BYTES) begin
                    merge_read_beat[(dst_byte * 8) +: 8] =
                        beat_data[(byte_idx * 8) +: 8];
                end
            end
        end
    endfunction

    function [READ_RESP_BITS-1:0] extract_mode2_read_data;
        input [READ_RESP_BITS-1:0] line_data;
        input [ADDR_BITS-1:0]      req_addr;
        input [ADDR_BITS-1:0]      issued_addr;
        integer dst_byte;
        integer src_byte;
        integer byte_off;
        begin
            extract_mode2_read_data = {READ_RESP_BITS{1'b0}};
            byte_off = req_addr - issued_addr;
            for (dst_byte = 0; dst_byte < READ_RESP_BYTES; dst_byte = dst_byte + 1) begin
                src_byte = dst_byte + byte_off;
                if ((src_byte >= 0) && (src_byte < READ_RESP_BYTES)) begin
                    extract_mode2_read_data[(dst_byte * 8) +: 8] =
                        line_data[(src_byte * 8) +: 8];
                end
            end
        end
    endfunction

    function [7:0] next_ptr;
        input [7:0] ptr_value;
        input integer depth;
        begin
            if (ptr_value == (depth - 1)) begin
                next_ptr = 8'd0;
            end else begin
                next_ptr = ptr_value + 8'd1;
            end
        end
    endfunction

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
    wire                      cache_rd_rsp_valid_w;
    wire                      bypass_rd_rsp_valid_w;
    wire                      cache_wr_rsp_valid_w;
    wire                      bypass_wr_rsp_valid_w;
    wire                      cache_resp_select_read_w;
    wire                      bypass_resp_select_read_w;
    wire                      rd_issue_handshake_w;
    wire                      wr_aw_handshake_w;
    wire                      wr_w_handshake_w;
    wire                      cache_resp_handshake_w;
    wire                      bypass_resp_handshake_w;
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
    wire [1:0]                rd_match_resp_code_w;
    wire [READ_RESP_BITS-1:0] rd_complete_data_w;
    wire                      cache_rd_rsp_space_w;
    wire                      bypass_rd_rsp_space_w;
    wire                      cache_wr_rsp_space_w;
    wire                      bypass_wr_rsp_space_w;
    wire                      rd_resp_accept_w;
    wire                      rd_complete_push_w;
    wire                      wr_resp_accept_w;

    assign rd_issue_valid_w =
        (rd_issue_count_r != 0) &&
        rd_valid_r[rd_issue_q_slot_r[rd_issue_head_r]] &&
        !rd_ar_sent_r[rd_issue_q_slot_r[rd_issue_head_r]];
    assign rd_issue_slot_w = rd_issue_q_slot_r[rd_issue_head_r];
    assign rd_issue_mode2_ddr_aligned_w =
        !rd_from_cache_r[rd_issue_slot_w] &&
        rd_mode2_ddr_aligned_r[rd_issue_slot_w];
    assign rd_issue_addr_w = rd_issue_mode2_ddr_aligned_w ?
                             mode2_issue_addr(rd_addr_r[rd_issue_slot_w],
                                              rd_size_r[rd_issue_slot_w]) :
                             rd_addr_r[rd_issue_slot_w];
    assign rd_issue_axi_id_w = rd_axi_id_r[rd_issue_slot_w];
    assign rd_issue_size_w = rd_issue_mode2_ddr_aligned_w ?
                             mode2_issue_size(rd_addr_r[rd_issue_slot_w],
                                              rd_size_r[rd_issue_slot_w]) :
                             rd_size_r[rd_issue_slot_w];

    assign wr_aw_valid_w =
        (wr_aw_count_r != 0) &&
        wr_valid_r[wr_aw_q_slot_r[wr_aw_head_r]] &&
        !wr_aw_sent_r[wr_aw_q_slot_r[wr_aw_head_r]];
    assign wr_aw_slot_w = wr_aw_q_slot_r[wr_aw_head_r];
    assign wr_aw_mode2_ddr_aligned_w =
        !wr_from_cache_r[wr_aw_slot_w] &&
        wr_mode2_ddr_aligned_r[wr_aw_slot_w];
    assign wr_aw_addr_w = wr_aw_mode2_ddr_aligned_w ?
                          mode2_issue_addr(wr_addr_r[wr_aw_slot_w],
                                           wr_size_r[wr_aw_slot_w]) :
                          wr_addr_r[wr_aw_slot_w];
    assign wr_aw_axi_id_w = wr_axi_id_r[wr_aw_slot_w];
    assign wr_aw_size_w = wr_aw_mode2_ddr_aligned_w ?
                          mode2_issue_size(wr_addr_r[wr_aw_slot_w],
                                           wr_size_r[wr_aw_slot_w]) :
                          wr_size_r[wr_aw_slot_w];

    assign wr_w_valid_w =
        (wr_w_count_r != 0) &&
        wr_valid_r[wr_w_q_slot_r[wr_w_head_r]] &&
        wr_aw_sent_r[wr_w_q_slot_r[wr_w_head_r]] &&
        !wr_w_done_r[wr_w_q_slot_r[wr_w_head_r]];
    assign wr_w_slot_w = wr_w_q_slot_r[wr_w_head_r];
    assign wr_w_beat_idx_w = wr_beats_sent_r[wr_w_slot_w];
    assign wr_w_total_beats_w = wr_total_beats_r[wr_w_slot_w];
    assign wr_w_issue_addr_w = wr_mode2_ddr_aligned_r[wr_w_slot_w] ?
                               mode2_issue_addr(wr_addr_r[wr_w_slot_w],
                                                wr_size_r[wr_w_slot_w]) :
                               wr_addr_r[wr_w_slot_w];

    assign cache_rd_rsp_valid_w = (cache_rd_rsp_count_r != 0);
    assign bypass_rd_rsp_valid_w = (bypass_rd_rsp_count_r != 0);
    assign cache_wr_rsp_valid_w = (cache_wr_rsp_count_r != 0);
    assign bypass_wr_rsp_valid_w = (bypass_wr_rsp_count_r != 0);
    assign cache_resp_select_read_w = cache_rd_rsp_valid_w;
    assign bypass_resp_select_read_w = bypass_rd_rsp_valid_w;

    assign rd_issue_handshake_w = axi_arvalid && axi_arready;
    assign wr_aw_handshake_w = axi_awvalid && axi_awready;
    assign wr_w_handshake_w = axi_wvalid && axi_wready;
    assign cache_resp_handshake_w = cache_resp_valid && cache_resp_ready;
    assign bypass_resp_handshake_w = bypass_resp_valid && bypass_resp_ready;

    assign rd_issue_push_w = (accept_cache_w || accept_bypass_w) && !accept_write_w;
    assign rd_issue_pop_w = rd_issue_handshake_w;
    assign wr_aw_push_w = (accept_cache_w || accept_bypass_w) && accept_write_w;
    assign wr_aw_pop_w = wr_aw_handshake_w;
    assign wr_w_push_w = (accept_cache_w || accept_bypass_w) && accept_write_w;
    assign wr_w_pop_w = wr_w_handshake_w && axi_wlast;

    assign rd_match_from_cache_w = rd_from_cache_r[rd_match_slot_w];
    assign wr_match_from_cache_w = wr_from_cache_r[wr_match_slot_w];
    assign rd_match_merged_data_w =
        merge_read_beat(rd_rdata_r[rd_match_slot_w],
                        axi_rdata,
                        rd_beats_done_r[rd_match_slot_w]);
    assign rd_match_resp_code_w =
        (axi_rresp != RESP_OKAY) ? axi_rresp : rd_resp_code_r[rd_match_slot_w];
    assign rd_last_beat_w =
        rd_match_found_w &&
        (((rd_beats_done_r[rd_match_slot_w] + 8'd1) ==
          rd_total_beats_r[rd_match_slot_w]) || axi_rlast);

    assign cache_rd_rsp_space_w = (cache_rd_rsp_count_r < READ_PENDING_COUNT);
    assign bypass_rd_rsp_space_w = (bypass_rd_rsp_count_r < READ_PENDING_COUNT);
    assign cache_wr_rsp_space_w = (cache_wr_rsp_count_r < WRITE_PENDING_COUNT);
    assign bypass_wr_rsp_space_w = (bypass_wr_rsp_count_r < WRITE_PENDING_COUNT);
    assign rd_complete_from_cache_w = rd_from_cache_r[rd_complete_slot_w];
    assign rd_complete_rsp_space_w =
        rd_complete_from_cache_w ? cache_rd_rsp_space_w : bypass_rd_rsp_space_w;
    assign rd_complete_data_w = rd_rdata_r[rd_complete_slot_w];
    assign wr_match_rsp_space_w =
        wr_match_from_cache_w ? cache_wr_rsp_space_w : bypass_wr_rsp_space_w;
    // Accept the last AXI R beat as soon as the matching pending slot is
    // found, then push the assembled line into the source-local response queue
    // one cycle later via rd_complete_push_w.
    assign rd_resp_accept_w = axi_rvalid && rd_match_found_w;
    assign rd_complete_push_w = rd_complete_found_w && rd_complete_rsp_space_w;
    assign wr_resp_accept_w =
        axi_bvalid && wr_match_found_w && wr_match_rsp_space_w;

    assign cache_rd_rsp_push_w =
        rd_complete_push_w && rd_complete_from_cache_w;
    assign bypass_rd_rsp_push_w =
        rd_complete_push_w && !rd_complete_from_cache_w;
    assign cache_wr_rsp_push_w =
        wr_resp_accept_w && wr_match_from_cache_w;
    assign bypass_wr_rsp_push_w =
        wr_resp_accept_w && !wr_match_from_cache_w;

    assign cache_rd_rsp_pop_w = cache_resp_handshake_w && cache_resp_select_read_w;
    assign cache_wr_rsp_pop_w =
        cache_resp_handshake_w && !cache_resp_select_read_w && cache_wr_rsp_valid_w;
    assign bypass_rd_rsp_pop_w = bypass_resp_handshake_w && bypass_resp_select_read_w;
    assign bypass_wr_rsp_pop_w =
        bypass_resp_handshake_w && !bypass_resp_select_read_w && bypass_wr_rsp_valid_w;

    always @(*) begin
        rd_free_found_w = 1'b0;
        rd_free_slot_w = 8'd0;
        rd_axi_id_used_w = {AXI_ID_COUNT{1'b0}};
        rd_axi_id_found_w = 1'b0;
        rd_axi_id_w = {AXI_ID_BITS{1'b0}};
        wr_free_found_w = 1'b0;
        wr_free_slot_w = 8'd0;
        wr_axi_id_used_w = {AXI_ID_COUNT{1'b0}};
        wr_axi_id_found_w = 1'b0;
        wr_axi_id_w = {AXI_ID_BITS{1'b0}};
        accept_cache_w = 1'b0;
        accept_bypass_w = 1'b0;
        accept_write_w = 1'b0;
        accept_slot_w = 8'd0;
        accept_axi_id_w = {AXI_ID_BITS{1'b0}};
        accept_total_beats_w = 8'd0;
        rd_match_slot_w = 8'd0;
        rd_match_found_w = 1'b0;
        rd_complete_slot_w = 8'd0;
        rd_complete_found_w = 1'b0;
        wr_match_slot_w = 8'd0;
        wr_match_found_w = 1'b0;

        for (idx = 0; idx < READ_PENDING_COUNT; idx = idx + 1) begin
            if (!rd_free_found_w && !rd_valid_r[idx]) begin
                rd_free_found_w = 1'b1;
                rd_free_slot_w = idx[7:0];
            end
            if (rd_valid_r[idx]) begin
                rd_axi_id_used_w[rd_axi_id_r[idx]] = 1'b1;
            end
            if (!rd_match_found_w &&
                rd_valid_r[idx] &&
                (rd_axi_id_r[idx] == axi_rid)) begin
                rd_match_found_w = 1'b1;
                rd_match_slot_w = idx[7:0];
            end
            if (!rd_complete_found_w && rd_valid_r[idx] && rd_complete_r[idx]) begin
                rd_complete_found_w = 1'b1;
                rd_complete_slot_w = idx[7:0];
            end
        end
        for (idx = 0; idx < AXI_ID_COUNT; idx = idx + 1) begin
            if (!rd_axi_id_found_w && !rd_axi_id_used_w[idx]) begin
                rd_axi_id_found_w = 1'b1;
                rd_axi_id_w = idx[AXI_ID_BITS-1:0];
            end
        end

        for (idx = 0; idx < WRITE_PENDING_COUNT; idx = idx + 1) begin
            if (!wr_free_found_w && !wr_valid_r[idx]) begin
                wr_free_found_w = 1'b1;
                wr_free_slot_w = idx[7:0];
            end
            if (wr_valid_r[idx]) begin
                wr_axi_id_used_w[wr_axi_id_r[idx]] = 1'b1;
            end
            if (!wr_match_found_w &&
                wr_valid_r[idx] &&
                (wr_axi_id_r[idx] == axi_bid)) begin
                wr_match_found_w = 1'b1;
                wr_match_slot_w = idx[7:0];
            end
        end
        for (idx = 0; idx < AXI_ID_COUNT; idx = idx + 1) begin
            if (!wr_axi_id_found_w && !wr_axi_id_used_w[idx]) begin
                wr_axi_id_found_w = 1'b1;
                wr_axi_id_w = idx[AXI_ID_BITS-1:0];
            end
        end

        if (cache_req_valid) begin
            if (cache_req_write) begin
                if (wr_free_found_w &&
                    wr_axi_id_found_w &&
                    (wr_aw_count_r < WRITE_PENDING_COUNT) &&
                    (wr_w_count_r < WRITE_PENDING_COUNT)) begin
                    accept_cache_w = 1'b1;
                    accept_write_w = 1'b1;
                    accept_slot_w = wr_free_slot_w;
                    accept_axi_id_w = wr_axi_id_w;
                    accept_total_beats_w = calc_total_beats(cache_req_size);
                end
            end else begin
                if (rd_free_found_w &&
                    rd_axi_id_found_w &&
                    (rd_issue_count_r < READ_PENDING_COUNT)) begin
                    accept_cache_w = 1'b1;
                    accept_write_w = 1'b0;
                    accept_slot_w = rd_free_slot_w;
                    accept_axi_id_w = rd_axi_id_w;
                    accept_total_beats_w = calc_total_beats(cache_req_size);
                end
            end
        end else if (bypass_req_valid) begin
            if (bypass_req_write) begin
                if (wr_free_found_w &&
                    wr_axi_id_found_w &&
                    (wr_aw_count_r < WRITE_PENDING_COUNT) &&
                    (wr_w_count_r < WRITE_PENDING_COUNT)) begin
                    accept_bypass_w = 1'b1;
                    accept_write_w = 1'b1;
                    accept_slot_w = wr_free_slot_w;
                    accept_axi_id_w = wr_axi_id_w;
                    accept_total_beats_w =
                        calc_total_beats(bypass_req_mode2_ddr_aligned ?
                                             mode2_issue_size(bypass_req_addr,
                                                              bypass_req_size) :
                                             bypass_req_size);
                end
            end else begin
                if (rd_free_found_w &&
                    rd_axi_id_found_w &&
                    (rd_issue_count_r < READ_PENDING_COUNT)) begin
                    accept_bypass_w = 1'b1;
                    accept_write_w = 1'b0;
                    accept_slot_w = rd_free_slot_w;
                    accept_axi_id_w = rd_axi_id_w;
                    accept_total_beats_w =
                        calc_total_beats(bypass_req_mode2_ddr_aligned ?
                                             mode2_issue_size(bypass_req_addr,
                                                              bypass_req_size) :
                                             bypass_req_size);
                end
            end
        end
    end

    assign cache_req_ready = accept_cache_w;
    assign bypass_req_ready = accept_bypass_w;

    assign axi_arvalid = rd_issue_valid_w;
    assign axi_arid = rd_issue_axi_id_w;
    assign axi_araddr = rd_issue_addr_w;
    assign axi_arlen = calc_burst_len(rd_issue_size_w);
    assign axi_arsize = AXI_SIZE_CODE;
    assign axi_arburst = AXI_BURST_INCR;
    assign axi_rready = rd_match_found_w;

    assign axi_awvalid = wr_aw_valid_w;
    assign axi_awid = wr_aw_axi_id_w;
    assign axi_awaddr = wr_aw_addr_w;
    assign axi_awlen = calc_burst_len(wr_aw_size_w);
    assign axi_awsize = AXI_SIZE_CODE;
    assign axi_awburst = AXI_BURST_INCR;

    assign axi_wvalid = wr_w_valid_w;
    assign axi_wdata = wr_mode2_ddr_aligned_r[wr_w_slot_w] ?
                       pack_mode2_write_beat(wr_wdata_r[wr_w_slot_w],
                                             wr_addr_r[wr_w_slot_w],
                                             wr_w_issue_addr_w,
                                             wr_w_beat_idx_w) :
                       pack_write_beat(wr_wdata_r[wr_w_slot_w], wr_w_beat_idx_w);
    assign axi_wstrb = wr_mode2_ddr_aligned_r[wr_w_slot_w] ?
                       pack_mode2_write_strobe(wr_wstrb_r[wr_w_slot_w],
                                               wr_addr_r[wr_w_slot_w],
                                               wr_w_issue_addr_w,
                                               wr_w_beat_idx_w) :
                       pack_write_strobe(wr_wstrb_r[wr_w_slot_w], wr_w_beat_idx_w);
    assign axi_wlast = (wr_w_beat_idx_w + 8'd1 == wr_w_total_beats_w);
    assign axi_bready = wr_match_found_w && wr_match_rsp_space_w;

    assign cache_resp_valid = cache_rd_rsp_valid_w || cache_wr_rsp_valid_w;
    assign cache_resp_rdata = cache_resp_select_read_w ?
                              cache_rd_rsp_data_r[cache_rd_rsp_head_r] :
                              {READ_RESP_BITS{1'b0}};
    assign cache_resp_id = cache_resp_select_read_w ?
                           cache_rd_rsp_id_r[cache_rd_rsp_head_r] :
                           cache_wr_rsp_id_r[cache_wr_rsp_head_r];
    assign cache_resp_code = cache_resp_select_read_w ?
                             cache_rd_rsp_code_r[cache_rd_rsp_head_r] :
                             cache_wr_rsp_code_r[cache_wr_rsp_head_r];

    assign bypass_resp_valid = bypass_rd_rsp_valid_w || bypass_wr_rsp_valid_w;
    assign bypass_resp_rdata = bypass_resp_select_read_w ?
                               bypass_rd_rsp_data_r[bypass_rd_rsp_head_r] :
                               {READ_RESP_BITS{1'b0}};
    assign bypass_resp_id = bypass_resp_select_read_w ?
                            bypass_rd_rsp_id_r[bypass_rd_rsp_head_r] :
                            bypass_wr_rsp_id_r[bypass_wr_rsp_head_r];
    assign bypass_resp_code = bypass_resp_select_read_w ?
                              bypass_rd_rsp_code_r[bypass_rd_rsp_head_r] :
                              bypass_wr_rsp_code_r[bypass_wr_rsp_head_r];

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
            for (idx = 0; idx < READ_PENDING_COUNT; idx = idx + 1) begin
                rd_valid_r[idx] <= 1'b0;
                rd_from_cache_r[idx] <= 1'b0;
                rd_addr_r[idx] <= {ADDR_BITS{1'b0}};
                rd_req_id_r[idx] <= {ID_BITS{1'b0}};
                rd_size_r[idx] <= 8'd0;
                rd_mode2_ddr_aligned_r[idx] <= 1'b0;
                rd_axi_id_r[idx] <= {AXI_ID_BITS{1'b0}};
                rd_total_beats_r[idx] <= 8'd0;
                rd_beats_done_r[idx] <= 8'd0;
                rd_ar_sent_r[idx] <= 1'b0;
                rd_complete_r[idx] <= 1'b0;
                rd_rdata_r[idx] <= {READ_RESP_BITS{1'b0}};
                rd_resp_code_r[idx] <= RESP_OKAY;
                rd_issue_q_slot_r[idx] <= 8'd0;
                cache_rd_rsp_id_r[idx] <= {ID_BITS{1'b0}};
                cache_rd_rsp_code_r[idx] <= RESP_OKAY;
                cache_rd_rsp_data_r[idx] <= {READ_RESP_BITS{1'b0}};
                bypass_rd_rsp_id_r[idx] <= {ID_BITS{1'b0}};
                bypass_rd_rsp_code_r[idx] <= RESP_OKAY;
                bypass_rd_rsp_data_r[idx] <= {READ_RESP_BITS{1'b0}};
            end
            for (idx = 0; idx < WRITE_PENDING_COUNT; idx = idx + 1) begin
                wr_valid_r[idx] <= 1'b0;
                wr_from_cache_r[idx] <= 1'b0;
                wr_addr_r[idx] <= {ADDR_BITS{1'b0}};
                wr_req_id_r[idx] <= {ID_BITS{1'b0}};
                wr_size_r[idx] <= 8'd0;
                wr_mode2_ddr_aligned_r[idx] <= 1'b0;
                wr_wdata_r[idx] <= {LINE_BITS{1'b0}};
                wr_wstrb_r[idx] <= {LINE_BYTES{1'b0}};
                wr_axi_id_r[idx] <= {AXI_ID_BITS{1'b0}};
                wr_total_beats_r[idx] <= 8'd0;
                wr_beats_sent_r[idx] <= 8'd0;
                wr_aw_sent_r[idx] <= 1'b0;
                wr_w_done_r[idx] <= 1'b0;
                wr_aw_q_slot_r[idx] <= 8'd0;
                wr_w_q_slot_r[idx] <= 8'd0;
                cache_wr_rsp_id_r[idx] <= {ID_BITS{1'b0}};
                cache_wr_rsp_code_r[idx] <= RESP_OKAY;
                bypass_wr_rsp_id_r[idx] <= {ID_BITS{1'b0}};
                bypass_wr_rsp_code_r[idx] <= RESP_OKAY;
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

            if (rd_issue_push_w && rd_issue_pop_w) begin
                rd_issue_q_slot_r[rd_issue_tail_r] <= accept_slot_w;
                rd_issue_head_r <= next_ptr(rd_issue_head_r, READ_PENDING_COUNT);
                rd_issue_tail_r <= next_ptr(rd_issue_tail_r, READ_PENDING_COUNT);
            end else if (rd_issue_push_w) begin
                rd_issue_q_slot_r[rd_issue_tail_r] <= accept_slot_w;
                rd_issue_tail_r <= next_ptr(rd_issue_tail_r, READ_PENDING_COUNT);
                rd_issue_count_r <= rd_issue_count_r + 8'd1;
            end else if (rd_issue_pop_w) begin
                rd_issue_head_r <= next_ptr(rd_issue_head_r, READ_PENDING_COUNT);
                rd_issue_count_r <= rd_issue_count_r - 8'd1;
            end

            if (wr_aw_push_w && wr_aw_pop_w) begin
                wr_aw_q_slot_r[wr_aw_tail_r] <= accept_slot_w;
                wr_aw_head_r <= next_ptr(wr_aw_head_r, WRITE_PENDING_COUNT);
                wr_aw_tail_r <= next_ptr(wr_aw_tail_r, WRITE_PENDING_COUNT);
            end else if (wr_aw_push_w) begin
                wr_aw_q_slot_r[wr_aw_tail_r] <= accept_slot_w;
                wr_aw_tail_r <= next_ptr(wr_aw_tail_r, WRITE_PENDING_COUNT);
                wr_aw_count_r <= wr_aw_count_r + 8'd1;
            end else if (wr_aw_pop_w) begin
                wr_aw_head_r <= next_ptr(wr_aw_head_r, WRITE_PENDING_COUNT);
                wr_aw_count_r <= wr_aw_count_r - 8'd1;
            end

            if (wr_w_push_w && wr_w_pop_w) begin
                wr_w_q_slot_r[wr_w_tail_r] <= accept_slot_w;
                wr_w_head_r <= next_ptr(wr_w_head_r, WRITE_PENDING_COUNT);
                wr_w_tail_r <= next_ptr(wr_w_tail_r, WRITE_PENDING_COUNT);
            end else if (wr_w_push_w) begin
                wr_w_q_slot_r[wr_w_tail_r] <= accept_slot_w;
                wr_w_tail_r <= next_ptr(wr_w_tail_r, WRITE_PENDING_COUNT);
                wr_w_count_r <= wr_w_count_r + 8'd1;
            end else if (wr_w_pop_w) begin
                wr_w_head_r <= next_ptr(wr_w_head_r, WRITE_PENDING_COUNT);
                wr_w_count_r <= wr_w_count_r - 8'd1;
            end

            if (cache_rd_rsp_push_w && cache_rd_rsp_pop_w) begin
                cache_rd_rsp_id_r[cache_rd_rsp_tail_r] <= rd_req_id_r[rd_complete_slot_w];
                cache_rd_rsp_code_r[cache_rd_rsp_tail_r] <= rd_resp_code_r[rd_complete_slot_w];
                cache_rd_rsp_data_r[cache_rd_rsp_tail_r] <= rd_complete_data_w;
                cache_rd_rsp_head_r <= next_ptr(cache_rd_rsp_head_r, READ_PENDING_COUNT);
                cache_rd_rsp_tail_r <= next_ptr(cache_rd_rsp_tail_r, READ_PENDING_COUNT);
            end else if (cache_rd_rsp_push_w) begin
                cache_rd_rsp_id_r[cache_rd_rsp_tail_r] <= rd_req_id_r[rd_complete_slot_w];
                cache_rd_rsp_code_r[cache_rd_rsp_tail_r] <= rd_resp_code_r[rd_complete_slot_w];
                cache_rd_rsp_data_r[cache_rd_rsp_tail_r] <= rd_complete_data_w;
                cache_rd_rsp_tail_r <= next_ptr(cache_rd_rsp_tail_r, READ_PENDING_COUNT);
                cache_rd_rsp_count_r <= cache_rd_rsp_count_r + 8'd1;
            end else if (cache_rd_rsp_pop_w) begin
                cache_rd_rsp_head_r <= next_ptr(cache_rd_rsp_head_r, READ_PENDING_COUNT);
                cache_rd_rsp_count_r <= cache_rd_rsp_count_r - 8'd1;
            end

            if (bypass_rd_rsp_push_w && bypass_rd_rsp_pop_w) begin
                bypass_rd_rsp_id_r[bypass_rd_rsp_tail_r] <= rd_req_id_r[rd_complete_slot_w];
                bypass_rd_rsp_code_r[bypass_rd_rsp_tail_r] <= rd_resp_code_r[rd_complete_slot_w];
                bypass_rd_rsp_data_r[bypass_rd_rsp_tail_r] <= rd_complete_data_w;
                bypass_rd_rsp_head_r <= next_ptr(bypass_rd_rsp_head_r, READ_PENDING_COUNT);
                bypass_rd_rsp_tail_r <= next_ptr(bypass_rd_rsp_tail_r, READ_PENDING_COUNT);
            end else if (bypass_rd_rsp_push_w) begin
                bypass_rd_rsp_id_r[bypass_rd_rsp_tail_r] <= rd_req_id_r[rd_complete_slot_w];
                bypass_rd_rsp_code_r[bypass_rd_rsp_tail_r] <= rd_resp_code_r[rd_complete_slot_w];
                bypass_rd_rsp_data_r[bypass_rd_rsp_tail_r] <= rd_complete_data_w;
                bypass_rd_rsp_tail_r <= next_ptr(bypass_rd_rsp_tail_r, READ_PENDING_COUNT);
                bypass_rd_rsp_count_r <= bypass_rd_rsp_count_r + 8'd1;
            end else if (bypass_rd_rsp_pop_w) begin
                bypass_rd_rsp_head_r <= next_ptr(bypass_rd_rsp_head_r, READ_PENDING_COUNT);
                bypass_rd_rsp_count_r <= bypass_rd_rsp_count_r - 8'd1;
            end

            if (cache_wr_rsp_push_w && cache_wr_rsp_pop_w) begin
                cache_wr_rsp_id_r[cache_wr_rsp_tail_r] <= wr_req_id_r[wr_match_slot_w];
                cache_wr_rsp_code_r[cache_wr_rsp_tail_r] <= axi_bresp;
                cache_wr_rsp_head_r <= next_ptr(cache_wr_rsp_head_r, WRITE_PENDING_COUNT);
                cache_wr_rsp_tail_r <= next_ptr(cache_wr_rsp_tail_r, WRITE_PENDING_COUNT);
            end else if (cache_wr_rsp_push_w) begin
                cache_wr_rsp_id_r[cache_wr_rsp_tail_r] <= wr_req_id_r[wr_match_slot_w];
                cache_wr_rsp_code_r[cache_wr_rsp_tail_r] <= axi_bresp;
                cache_wr_rsp_tail_r <= next_ptr(cache_wr_rsp_tail_r, WRITE_PENDING_COUNT);
                cache_wr_rsp_count_r <= cache_wr_rsp_count_r + 8'd1;
            end else if (cache_wr_rsp_pop_w) begin
                cache_wr_rsp_head_r <= next_ptr(cache_wr_rsp_head_r, WRITE_PENDING_COUNT);
                cache_wr_rsp_count_r <= cache_wr_rsp_count_r - 8'd1;
            end

            if (bypass_wr_rsp_push_w && bypass_wr_rsp_pop_w) begin
                bypass_wr_rsp_id_r[bypass_wr_rsp_tail_r] <= wr_req_id_r[wr_match_slot_w];
                bypass_wr_rsp_code_r[bypass_wr_rsp_tail_r] <= axi_bresp;
                bypass_wr_rsp_head_r <= next_ptr(bypass_wr_rsp_head_r, WRITE_PENDING_COUNT);
                bypass_wr_rsp_tail_r <= next_ptr(bypass_wr_rsp_tail_r, WRITE_PENDING_COUNT);
            end else if (bypass_wr_rsp_push_w) begin
                bypass_wr_rsp_id_r[bypass_wr_rsp_tail_r] <= wr_req_id_r[wr_match_slot_w];
                bypass_wr_rsp_code_r[bypass_wr_rsp_tail_r] <= axi_bresp;
                bypass_wr_rsp_tail_r <= next_ptr(bypass_wr_rsp_tail_r, WRITE_PENDING_COUNT);
                bypass_wr_rsp_count_r <= bypass_wr_rsp_count_r + 8'd1;
            end else if (bypass_wr_rsp_pop_w) begin
                bypass_wr_rsp_head_r <= next_ptr(bypass_wr_rsp_head_r, WRITE_PENDING_COUNT);
                bypass_wr_rsp_count_r <= bypass_wr_rsp_count_r - 8'd1;
            end

            if (rd_issue_handshake_w) begin
                rd_ar_sent_r[rd_issue_slot_w] <= 1'b1;
            end

            if (rd_resp_accept_w) begin
                if (rd_last_beat_w) begin
                    rd_rdata_r[rd_match_slot_w] <=
                        (!rd_from_cache_r[rd_match_slot_w] &&
                         rd_mode2_ddr_aligned_r[rd_match_slot_w]) ?
                            extract_mode2_read_data(
                                rd_match_merged_data_w,
                                rd_addr_r[rd_match_slot_w],
                                mode2_issue_addr(rd_addr_r[rd_match_slot_w],
                                                 rd_size_r[rd_match_slot_w])) :
                            rd_match_merged_data_w;
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
                rd_from_cache_r[rd_complete_slot_w] <= 1'b0;
                rd_addr_r[rd_complete_slot_w] <= {ADDR_BITS{1'b0}};
                rd_req_id_r[rd_complete_slot_w] <= {ID_BITS{1'b0}};
                rd_size_r[rd_complete_slot_w] <= 8'd0;
                rd_mode2_ddr_aligned_r[rd_complete_slot_w] <= 1'b0;
                rd_axi_id_r[rd_complete_slot_w] <= {AXI_ID_BITS{1'b0}};
                rd_total_beats_r[rd_complete_slot_w] <= 8'd0;
                rd_beats_done_r[rd_complete_slot_w] <= 8'd0;
                rd_ar_sent_r[rd_complete_slot_w] <= 1'b0;
                rd_complete_r[rd_complete_slot_w] <= 1'b0;
                rd_rdata_r[rd_complete_slot_w] <= {READ_RESP_BITS{1'b0}};
                rd_resp_code_r[rd_complete_slot_w] <= RESP_OKAY;
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
                wr_from_cache_r[wr_match_slot_w] <= 1'b0;
                wr_addr_r[wr_match_slot_w] <= {ADDR_BITS{1'b0}};
                wr_req_id_r[wr_match_slot_w] <= {ID_BITS{1'b0}};
                wr_size_r[wr_match_slot_w] <= 8'd0;
                wr_mode2_ddr_aligned_r[wr_match_slot_w] <= 1'b0;
                wr_wdata_r[wr_match_slot_w] <= {LINE_BITS{1'b0}};
                wr_wstrb_r[wr_match_slot_w] <= {LINE_BYTES{1'b0}};
                wr_axi_id_r[wr_match_slot_w] <= {AXI_ID_BITS{1'b0}};
                wr_total_beats_r[wr_match_slot_w] <= 8'd0;
                wr_beats_sent_r[wr_match_slot_w] <= 8'd0;
                wr_aw_sent_r[wr_match_slot_w] <= 1'b0;
                wr_w_done_r[wr_match_slot_w] <= 1'b0;
            end
        end
    end

endmodule
