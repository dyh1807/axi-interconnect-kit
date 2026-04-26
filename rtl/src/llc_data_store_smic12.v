`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module llc_data_store_smic12 #(
    parameter SET_COUNT = `AXI_LLC_SET_COUNT,
    parameter SET_BITS  = `AXI_LLC_SET_BITS,
    parameter WAY_COUNT = `AXI_LLC_WAY_COUNT,
    parameter LINE_BITS = `AXI_LLC_LINE_BITS,
    parameter ROW_BITS  = WAY_COUNT * LINE_BITS,
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

    localparam BANK_COUNT     = 2;
    localparam BANK_BITS      = 1;
    localparam BANK_ADDR_BITS = 12;
    localparam CHUNK_BITS     = 256;
    localparam CHUNK_COUNT    = LINE_BITS / CHUNK_BITS;
    localparam integer READ_DELAY_W =
        (READ_LATENCY_CYCLES <= 2) ? 1 :
        (READ_LATENCY_CYCLES <= 4) ? 2 :
        (READ_LATENCY_CYCLES <= 8) ? 3 :
        (READ_LATENCY_CYCLES <= 16) ? 4 :
        (READ_LATENCY_CYCLES <= 32) ? 5 :
        (READ_LATENCY_CYCLES <= 64) ? 6 :
        (READ_LATENCY_CYCLES <= 128) ? 7 : 8;

    reg [BANK_BITS-1:0] rd_bank_r;
    reg [ROW_BITS-1:0]  rd_row_capture_r;
    reg                 read_pending_r;
    reg                 read_capture_pending_r;
    reg [READ_DELAY_W-1:0] read_delay_left_r;
    wire [BANK_BITS-1:0] rd_bank_w;
    wire [BANK_BITS-1:0] wr_bank_w;
    wire [BANK_ADDR_BITS-1:0] rd_addr_w;
    wire [BANK_ADDR_BITS-1:0] wr_addr_w;
    wire [255:0] macro_q [0:BANK_COUNT-1][0:WAY_COUNT-1][0:CHUNK_COUNT-1];

    genvar bank_idx;
    genvar way_idx;
    genvar chunk_idx;
    integer capture_way_idx;
    integer capture_chunk_idx;

    assign busy = 1'b0;
    assign rd_bank_w = rd_set[SET_BITS-1:BANK_ADDR_BITS];
    assign wr_bank_w = wr_set[SET_BITS-1:BANK_ADDR_BITS];
    assign rd_addr_w = rd_set[BANK_ADDR_BITS-1:0];
    assign wr_addr_w = wr_set[BANK_ADDR_BITS-1:0];

    generate
        for (bank_idx = 0; bank_idx < BANK_COUNT; bank_idx = bank_idx + 1) begin : gen_bank
            for (way_idx = 0; way_idx < WAY_COUNT; way_idx = way_idx + 1) begin : gen_way
                for (chunk_idx = 0; chunk_idx < CHUNK_COUNT; chunk_idx = chunk_idx + 1) begin : gen_chunk
                    llc_smic12_data_4096x256_sass_bw u_macro (
                        .clk  (clk),
                        .rst_n(rst_n),
                        .me   ((wr_en &&
                                (wr_bank_w == bank_idx[BANK_BITS-1:0]) &&
                                wr_way_mask[way_idx]) ||
                               (!wr_en &&
                                rd_en &&
                                (rd_bank_w == bank_idx[BANK_BITS-1:0]))),
                        .we   (wr_en &&
                               (wr_bank_w == bank_idx[BANK_BITS-1:0]) &&
                               wr_way_mask[way_idx]),
                        .addr (wr_en ? wr_addr_w : rd_addr_w),
                        .din  (wr_row[(way_idx * LINE_BITS) + (chunk_idx * CHUNK_BITS) +:
                                      CHUNK_BITS]),
                        .wem  ({CHUNK_BITS{wr_en &&
                                            (wr_bank_w == bank_idx[BANK_BITS-1:0]) &&
                                            wr_way_mask[way_idx]}}),
                        .q    (macro_q[bank_idx][way_idx][chunk_idx])
                    );
                end
            end
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_valid   <= 1'b0;
            rd_row     <= {ROW_BITS{1'b0}};
            rd_row_capture_r <= {ROW_BITS{1'b0}};
            rd_bank_r  <= {BANK_BITS{1'b0}};
            read_pending_r <= 1'b0;
            read_capture_pending_r <= 1'b0;
            read_delay_left_r <= {READ_DELAY_W{1'b0}};
        end else begin
            rd_valid <= 1'b0;

            if (read_capture_pending_r) begin
                for (capture_way_idx = 0;
                     capture_way_idx < WAY_COUNT;
                     capture_way_idx = capture_way_idx + 1) begin
                    for (capture_chunk_idx = 0;
                         capture_chunk_idx < CHUNK_COUNT;
                         capture_chunk_idx = capture_chunk_idx + 1) begin
                        rd_row_capture_r[(capture_way_idx * LINE_BITS) +
                                         (capture_chunk_idx * CHUNK_BITS) +:
                                         CHUNK_BITS] <=
                            macro_q[rd_bank_r][capture_way_idx][capture_chunk_idx];
                    end
                end
                read_capture_pending_r <= 1'b0;
            end

            if (read_pending_r) begin
                if (read_delay_left_r != 0) begin
                    read_delay_left_r <= read_delay_left_r - 8'd1;
                end else begin
                    rd_valid <= 1'b1;
                    if (read_capture_pending_r) begin
                        for (capture_way_idx = 0;
                             capture_way_idx < WAY_COUNT;
                             capture_way_idx = capture_way_idx + 1) begin
                            for (capture_chunk_idx = 0;
                                 capture_chunk_idx < CHUNK_COUNT;
                                 capture_chunk_idx = capture_chunk_idx + 1) begin
                                rd_row[(capture_way_idx * LINE_BITS) +
                                       (capture_chunk_idx * CHUNK_BITS) +:
                                       CHUNK_BITS] <=
                                    macro_q[rd_bank_r][capture_way_idx][capture_chunk_idx];
                            end
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
    end

endmodule
