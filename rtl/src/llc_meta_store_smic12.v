`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module llc_meta_store_smic12 #(
    parameter SET_COUNT = `AXI_LLC_SET_COUNT,
    parameter SET_BITS  = `AXI_LLC_SET_BITS,
    parameter WAY_COUNT = `AXI_LLC_WAY_COUNT,
    parameter META_BITS = `AXI_LLC_META_BITS,
    parameter ROW_BITS  = WAY_COUNT * META_BITS,
    parameter READ_LATENCY_CYCLES = `AXI_LLC_TABLE_READ_LATENCY
) (
    input                         clk,
    input                         rst_n,
    input                         rd_en,
    input      [SET_BITS-1:0]     rd_set,
    output reg                    rd_valid,
    output reg [ROW_BITS-1:0]     rd_row,
    input                         wr_en,
    input      [SET_BITS-1:0]     wr_set,
    input      [WAY_COUNT-1:0]    wr_way_mask,
    input      [ROW_BITS-1:0]     wr_row,
    output                        busy
);

    localparam integer MACRO_BITS      = `AXI_LLC_META_SRAM_BITS;
    localparam integer MACRO_DEPTH     = `AXI_LLC_META_SRAM_DEPTH;
    localparam integer BANK_COUNT      = (SET_COUNT + MACRO_DEPTH - 1) / MACRO_DEPTH;
    localparam integer BANK_BITS       = (BANK_COUNT <= 1) ? 1 : $clog2(BANK_COUNT);
    localparam integer BANK_ADDR_BITS  = `AXI_LLC_META_SRAM_ADDR_BITS;
    localparam integer READ_DELAY_W =
        (READ_LATENCY_CYCLES <= 2) ? 1 :
        (READ_LATENCY_CYCLES <= 4) ? 2 :
        (READ_LATENCY_CYCLES <= 8) ? 3 :
        (READ_LATENCY_CYCLES <= 16) ? 4 :
        (READ_LATENCY_CYCLES <= 32) ? 5 :
        (READ_LATENCY_CYCLES <= 64) ? 6 :
        (READ_LATENCY_CYCLES <= 128) ? 7 : 8;

    reg [BANK_BITS-1:0]      rd_bank_r;
    reg [ROW_BITS-1:0]       rd_row_capture_r;
    reg                      read_pending_r;
    reg                      read_capture_pending_r;
    reg [READ_DELAY_W-1:0]   read_delay_left_r;
    reg                      write_pending_r;
    reg [BANK_BITS-1:0]      wr_bank_r;
    reg [BANK_ADDR_BITS-1:0] wr_addr_r;
    reg [WAY_COUNT-1:0]      wr_way_mask_r;
    reg [ROW_BITS-1:0]       wr_row_r;

    wire [BANK_BITS-1:0]      rd_bank_w;
    wire [BANK_BITS-1:0]      wr_bank_w;
    wire [BANK_ADDR_BITS-1:0] rd_addr_w;
    wire [BANK_ADDR_BITS-1:0] wr_addr_w;
    wire [MACRO_BITS-1:0]     macro_q [0:BANK_COUNT-1][0:WAY_COUNT-1];

    genvar bank_idx;
    genvar way_idx;
    integer capture_way_idx;

    function [MACRO_BITS-1:0] pack_meta_word;
        input [META_BITS-1:0] meta_value;
        begin
            pack_meta_word = {MACRO_BITS{1'b0}};
            pack_meta_word[META_BITS-1:0] = meta_value;
        end
    endfunction

    assign busy = write_pending_r;
    assign rd_bank_w = rd_set / MACRO_DEPTH;
    assign wr_bank_w = wr_set / MACRO_DEPTH;
    assign rd_addr_w = rd_set % MACRO_DEPTH;
    assign wr_addr_w = wr_set % MACRO_DEPTH;

    generate
        for (bank_idx = 0; bank_idx < BANK_COUNT; bank_idx = bank_idx + 1) begin : gen_bank
            for (way_idx = 0; way_idx < WAY_COUNT; way_idx = way_idx + 1) begin : gen_way
                llc_smic12_meta_4096x16_bw u_macro (
                    .clk  (clk),
                    .rst_n(rst_n),
                    .me   ((write_pending_r &&
                            (wr_bank_r == bank_idx[BANK_BITS-1:0]) &&
                            wr_way_mask_r[way_idx]) ||
                           (!write_pending_r &&
                            !wr_en &&
                            rd_en &&
                            (rd_bank_w == bank_idx[BANK_BITS-1:0]))),
                    .we   (write_pending_r &&
                           (wr_bank_r == bank_idx[BANK_BITS-1:0]) &&
                           wr_way_mask_r[way_idx]),
                    .addr (write_pending_r ? wr_addr_r : rd_addr_w),
                    .din  (pack_meta_word(
                               wr_row_r[(way_idx * META_BITS) +: META_BITS]
                           )),
                    .q    (macro_q[bank_idx][way_idx])
                );
            end
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_valid        <= 1'b0;
            rd_row          <= {ROW_BITS{1'b0}};
            rd_row_capture_r <= {ROW_BITS{1'b0}};
            rd_bank_r       <= {BANK_BITS{1'b0}};
            read_pending_r  <= 1'b0;
            read_capture_pending_r <= 1'b0;
            read_delay_left_r <= {READ_DELAY_W{1'b0}};
            write_pending_r <= 1'b0;
            wr_bank_r       <= {BANK_BITS{1'b0}};
            wr_addr_r       <= {BANK_ADDR_BITS{1'b0}};
            wr_way_mask_r   <= {WAY_COUNT{1'b0}};
            wr_row_r        <= {ROW_BITS{1'b0}};
        end else begin
            rd_valid <= 1'b0;

            if (read_capture_pending_r) begin
                for (capture_way_idx = 0;
                     capture_way_idx < WAY_COUNT;
                     capture_way_idx = capture_way_idx + 1) begin
                    rd_row_capture_r[(capture_way_idx * META_BITS) +: META_BITS] <=
                        macro_q[rd_bank_r][capture_way_idx][META_BITS-1:0];
                end
                read_capture_pending_r <= 1'b0;
            end

            if (!write_pending_r) begin
                if (read_pending_r) begin
                    if (read_delay_left_r != 0) begin
                        read_delay_left_r <= read_delay_left_r - 8'd1;
                    end else begin
                        rd_valid <= 1'b1;
                        if (read_capture_pending_r) begin
                            for (capture_way_idx = 0;
                                 capture_way_idx < WAY_COUNT;
                                 capture_way_idx = capture_way_idx + 1) begin
                                rd_row[(capture_way_idx * META_BITS) +: META_BITS] <=
                                    macro_q[rd_bank_r][capture_way_idx][META_BITS-1:0];
                            end
                        end else begin
                            rd_row <= rd_row_capture_r;
                        end
                        read_pending_r <= 1'b0;
                    end
                end else if (rd_en && !wr_en) begin
                    rd_bank_r <= rd_bank_w;
                    if (READ_LATENCY_CYCLES <= 1) begin
                        read_pending_r <= 1'b1;
                        read_capture_pending_r <= 1'b1;
                        read_delay_left_r <= {READ_DELAY_W{1'b0}};
                    end else begin
                        read_pending_r <= 1'b1;
                        read_capture_pending_r <= 1'b1;
                        read_delay_left_r <= READ_LATENCY_CYCLES - 2;
                    end
                end
            end

            if (write_pending_r) begin
                write_pending_r <= 1'b0;
            end else if (wr_en) begin
                write_pending_r <= 1'b1;
                wr_bank_r       <= wr_bank_w;
                wr_addr_r       <= wr_addr_w;
                wr_way_mask_r   <= wr_way_mask;
                wr_row_r        <= wr_row;
            end
        end
    end

endmodule
