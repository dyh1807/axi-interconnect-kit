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
// This file owns AXI len/size/burst packing and beat-wise data/strobe assembly.
module axi_llc_axi_bridge #(
    parameter ADDR_BITS      = `AXI_LLC_ADDR_BITS,
    parameter ID_BITS        = `AXI_LLC_ID_BITS,
    parameter LINE_BYTES     = `AXI_LLC_LINE_BYTES,
    parameter LINE_BITS      = `AXI_LLC_LINE_BITS,
    parameter AXI_ID_BITS    = `AXI_LLC_AXI_ID_BITS,
    parameter AXI_DATA_BYTES = `AXI_LLC_AXI_DATA_BYTES,
    parameter AXI_DATA_BITS  = `AXI_LLC_AXI_DATA_BITS,
    parameter AXI_STRB_BITS  = `AXI_LLC_AXI_STRB_BITS
) (
    input                       clk,
    input                       rst_n,
    // Cache lower path.
    input                       cache_req_valid,
    output                      cache_req_ready,
    input                       cache_req_write,
    input      [ADDR_BITS-1:0]  cache_req_addr,
    input      [ID_BITS-1:0]    cache_req_id,
    input      [7:0]            cache_req_size,
    input      [LINE_BITS-1:0]  cache_req_wdata,
    input      [LINE_BYTES-1:0] cache_req_wstrb,
    output                      cache_resp_valid,
    input                       cache_resp_ready,
    output     [LINE_BITS-1:0]  cache_resp_rdata,
    output     [ID_BITS-1:0]    cache_resp_id,
    // Bypass lower path.
    input                       bypass_req_valid,
    output                      bypass_req_ready,
    input                       bypass_req_write,
    input      [ADDR_BITS-1:0]  bypass_req_addr,
    input      [ID_BITS-1:0]    bypass_req_id,
    input      [7:0]            bypass_req_size,
    input      [LINE_BITS-1:0]  bypass_req_wdata,
    input      [LINE_BYTES-1:0] bypass_req_wstrb,
    output                      bypass_resp_valid,
    input                       bypass_resp_ready,
    output     [LINE_BITS-1:0]  bypass_resp_rdata,
    output     [ID_BITS-1:0]    bypass_resp_id,
    // Single AXI4 master port.
    output                      axi_awvalid,
    input                       axi_awready,
    output     [AXI_ID_BITS-1:0] axi_awid,
    output     [ADDR_BITS-1:0]  axi_awaddr,
    output     [7:0]            axi_awlen,
    output     [2:0]            axi_awsize,
    output     [1:0]            axi_awburst,
    output                      axi_wvalid,
    input                       axi_wready,
    output     [AXI_DATA_BITS-1:0] axi_wdata,
    output     [AXI_STRB_BITS-1:0] axi_wstrb,
    output                      axi_wlast,
    input                       axi_bvalid,
    output                      axi_bready,
    input      [AXI_ID_BITS-1:0] axi_bid,
    input      [1:0]            axi_bresp,
    output                      axi_arvalid,
    input                       axi_arready,
    output     [AXI_ID_BITS-1:0] axi_arid,
    output     [ADDR_BITS-1:0]  axi_araddr,
    output     [7:0]            axi_arlen,
    output     [2:0]            axi_arsize,
    output     [1:0]            axi_arburst,
    input                       axi_rvalid,
    output                      axi_rready,
    input      [AXI_ID_BITS-1:0] axi_rid,
    input      [AXI_DATA_BITS-1:0] axi_rdata,
    input      [1:0]            axi_rresp,
    input                       axi_rlast
);

    localparam [2:0] ST_IDLE        = 3'd0;
    localparam [2:0] ST_RD_ADDR     = 3'd1;
    localparam [2:0] ST_RD_DATA     = 3'd2;
    localparam [2:0] ST_RD_RESP     = 3'd3;
    localparam [2:0] ST_WR_ADDR     = 3'd4;
    localparam [2:0] ST_WR_DATA     = 3'd5;
    localparam [2:0] ST_WR_B        = 3'd6;
    localparam [2:0] ST_WR_RESP     = 3'd7;
    localparam [1:0] AXI_BURST_INCR = 2'b01;
    localparam integer MAX_AXI_BEATS = (LINE_BYTES + AXI_DATA_BYTES - 1) / AXI_DATA_BYTES;
    localparam [2:0] AXI_SIZE_CODE =
        (AXI_DATA_BYTES == 32) ? 3'd5 :
        (AXI_DATA_BYTES == 16) ? 3'd4 :
        (AXI_DATA_BYTES == 8)  ? 3'd3 : 3'd2;

    // One in-flight AXI transaction at a time. This matches the current
    // simplified RTL contract, not the full C++ multi-outstanding design.
    reg [2:0]                 state_r;
    reg                       txn_from_cache_r;
    reg                       txn_write_r;
    reg [ADDR_BITS-1:0]       txn_addr_r;
    reg [ID_BITS-1:0]         txn_req_id_r;
    reg [7:0]                 txn_size_r;
    reg [LINE_BITS-1:0]       txn_wdata_r;
    reg [LINE_BYTES-1:0]      txn_wstrb_r;
    reg [LINE_BITS-1:0]       txn_rdata_r;
    reg [AXI_ID_BITS-1:0]     txn_axi_id_r;
    reg [7:0]                 txn_total_beats_r;
    reg [7:0]                 txn_beats_done_r;
    reg [AXI_ID_BITS-1:0]     next_axi_id_r;

    wire                      select_cache_w;
    wire                      select_bypass_w;
    wire                      idle_accept_w;
    wire [7:0]                cache_beats_w;
    wire [7:0]                bypass_beats_w;
    wire [7:0]                selected_beats_w;
    wire                      rd_target_ready_w;
    wire                      wr_target_ready_w;
    wire                      axi_r_match_w;
    wire                      axi_b_match_w;

    // AXI packaging helpers.
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
        reg [7:0] beats;
        begin
            beats = calc_total_beats(total_size);
            calc_burst_len = beats - 8'd1;
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

    function [LINE_BITS-1:0] merge_read_beat;
        input [LINE_BITS-1:0] line_data;
        input [AXI_DATA_BITS-1:0] beat_data;
        input [7:0] beat_idx;
        integer byte_idx;
        integer dst_byte;
        begin
            merge_read_beat = line_data;
            for (byte_idx = 0; byte_idx < AXI_DATA_BYTES; byte_idx = byte_idx + 1) begin
                dst_byte = beat_idx * AXI_DATA_BYTES + byte_idx;
                if (dst_byte < LINE_BYTES) begin
                    merge_read_beat[(dst_byte * 8) +: 8] =
                        beat_data[(byte_idx * 8) +: 8];
                end
            end
        end
    endfunction

    // Cache requests win when both sources are ready in the same idle cycle.
    assign select_cache_w = (state_r == ST_IDLE) && cache_req_valid;
    assign select_bypass_w = (state_r == ST_IDLE) && !cache_req_valid && bypass_req_valid;
    assign idle_accept_w = select_cache_w || select_bypass_w;
    assign cache_beats_w = calc_total_beats(cache_req_size);
    assign bypass_beats_w = calc_total_beats(bypass_req_size);
    assign selected_beats_w = select_cache_w ? cache_beats_w : bypass_beats_w;

    assign cache_req_ready = select_cache_w;
    assign bypass_req_ready = select_bypass_w;

    assign rd_target_ready_w = txn_from_cache_r ? cache_resp_ready : bypass_resp_ready;
    assign wr_target_ready_w = txn_from_cache_r ? cache_resp_ready : bypass_resp_ready;
    assign axi_r_match_w = axi_rvalid && (axi_rid == txn_axi_id_r);
    assign axi_b_match_w = axi_bvalid && (axi_bid == txn_axi_id_r);

    assign axi_awvalid = (state_r == ST_WR_ADDR);
    assign axi_awid = txn_axi_id_r;
    assign axi_awaddr = txn_addr_r;
    assign axi_awlen = calc_burst_len(txn_size_r);
    assign axi_awsize = AXI_SIZE_CODE;
    assign axi_awburst = AXI_BURST_INCR;

    assign axi_wvalid = (state_r == ST_WR_DATA);
    assign axi_wdata = pack_write_beat(txn_wdata_r, txn_beats_done_r);
    assign axi_wstrb = pack_write_strobe(txn_wstrb_r, txn_beats_done_r);
    assign axi_wlast = (txn_beats_done_r + 8'd1 == txn_total_beats_r);

    assign axi_bready = (state_r == ST_WR_B);

    assign axi_arvalid = (state_r == ST_RD_ADDR);
    assign axi_arid = txn_axi_id_r;
    assign axi_araddr = txn_addr_r;
    assign axi_arlen = calc_burst_len(txn_size_r);
    assign axi_arsize = AXI_SIZE_CODE;
    assign axi_arburst = AXI_BURST_INCR;

    assign axi_rready = (state_r == ST_RD_DATA);

    assign cache_resp_valid = txn_from_cache_r &&
                              ((state_r == ST_RD_RESP) || (state_r == ST_WR_RESP));
    assign cache_resp_rdata = txn_rdata_r;
    assign cache_resp_id = txn_req_id_r;
    assign bypass_resp_valid = !txn_from_cache_r &&
                               ((state_r == ST_RD_RESP) || (state_r == ST_WR_RESP));
    assign bypass_resp_rdata = txn_rdata_r;
    assign bypass_resp_id = txn_req_id_r;

    // Transaction capture, beat accumulation and AXI response retirement.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r <= ST_IDLE;
            txn_from_cache_r <= 1'b0;
            txn_write_r <= 1'b0;
            txn_addr_r <= {ADDR_BITS{1'b0}};
            txn_req_id_r <= {ID_BITS{1'b0}};
            txn_size_r <= 8'd0;
            txn_wdata_r <= {LINE_BITS{1'b0}};
            txn_wstrb_r <= {LINE_BYTES{1'b0}};
            txn_rdata_r <= {LINE_BITS{1'b0}};
            txn_axi_id_r <= {{(AXI_ID_BITS-1){1'b0}}, 1'b1};
            txn_total_beats_r <= 8'd0;
            txn_beats_done_r <= 8'd0;
            next_axi_id_r <= {{(AXI_ID_BITS-1){1'b0}}, 1'b1};
        end else begin
            case (state_r)
                ST_IDLE: begin
                    if (idle_accept_w) begin
                        txn_from_cache_r <= select_cache_w;
                        txn_write_r <= select_cache_w ? cache_req_write : bypass_req_write;
                        txn_addr_r <= select_cache_w ? cache_req_addr : bypass_req_addr;
                        txn_req_id_r <= select_cache_w ? cache_req_id : bypass_req_id;
                        txn_size_r <= select_cache_w ? cache_req_size : bypass_req_size;
                        txn_wdata_r <= select_cache_w ? cache_req_wdata : bypass_req_wdata;
                        txn_wstrb_r <= select_cache_w ? cache_req_wstrb : bypass_req_wstrb;
                        txn_rdata_r <= {LINE_BITS{1'b0}};
                        txn_axi_id_r <= next_axi_id_r;
                        txn_total_beats_r <= selected_beats_w;
                        txn_beats_done_r <= 8'd0;
                        next_axi_id_r <= next_axi_id_r + {{(AXI_ID_BITS-1){1'b0}}, 1'b1};
                        if (select_cache_w ? cache_req_write : bypass_req_write) begin
                            state_r <= ST_WR_ADDR;
                        end else begin
                            state_r <= ST_RD_ADDR;
                        end
                    end
                end

                ST_RD_ADDR: begin
                    if (axi_arvalid && axi_arready) begin
                        state_r <= ST_RD_DATA;
                    end
                end

                ST_RD_DATA: begin
                    if (axi_r_match_w) begin
                        txn_rdata_r <= merge_read_beat(txn_rdata_r, axi_rdata, txn_beats_done_r);
                        if ((txn_beats_done_r + 8'd1 == txn_total_beats_r) || axi_rlast) begin
                            txn_beats_done_r <= 8'd0;
                            state_r <= ST_RD_RESP;
                        end else begin
                            txn_beats_done_r <= txn_beats_done_r + 8'd1;
                        end
                    end
                end

                ST_RD_RESP: begin
                    if (rd_target_ready_w) begin
                        state_r <= ST_IDLE;
                    end
                end

                ST_WR_ADDR: begin
                    if (axi_awvalid && axi_awready) begin
                        state_r <= ST_WR_DATA;
                    end
                end

                ST_WR_DATA: begin
                    if (axi_wvalid && axi_wready) begin
                        if (txn_beats_done_r + 8'd1 == txn_total_beats_r) begin
                            txn_beats_done_r <= 8'd0;
                            state_r <= ST_WR_B;
                        end else begin
                            txn_beats_done_r <= txn_beats_done_r + 8'd1;
                        end
                    end
                end

                ST_WR_B: begin
                    if (axi_b_match_w) begin
                        txn_rdata_r <= {LINE_BITS{1'b0}};
                        state_r <= ST_WR_RESP;
                    end
                end

                ST_WR_RESP: begin
                    if (wr_target_ready_w) begin
                        state_r <= ST_IDLE;
                    end
                end

                default: begin
                    state_r <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
