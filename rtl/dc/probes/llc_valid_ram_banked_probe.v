`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module llc_valid_ram_banked_probe_bank #(
    parameter BANK_DEPTH = 128,
    parameter BANK_SET_BITS = 7,
    parameter WAY_COUNT = `AXI_LLC_WAY_COUNT
) (
    input                         clk,
    input      [BANK_SET_BITS-1:0] rd_index,
    output     [WAY_COUNT-1:0]    rd_bits,
    input                         wr_en,
    input      [BANK_SET_BITS-1:0] wr_index,
    input      [WAY_COUNT-1:0]    wr_mask,
    input      [WAY_COUNT-1:0]    wr_bits
);

    reg [WAY_COUNT-1:0] valid_mem [0:BANK_DEPTH-1];

    assign rd_bits = valid_mem[rd_index];

    always @(posedge clk) begin
        if (wr_en) begin
            valid_mem[wr_index] <= (valid_mem[wr_index] & (~wr_mask)) |
                                   (wr_bits & wr_mask);
        end
    end

endmodule

module llc_valid_ram_banked_probe #(
    parameter SET_COUNT = `AXI_LLC_SET_COUNT,
    parameter SET_BITS  = `AXI_LLC_SET_BITS,
    parameter WAY_COUNT = `AXI_LLC_WAY_COUNT,
    parameter READ_LATENCY_CYCLES = `AXI_LLC_TABLE_READ_LATENCY
) (
    input                         clk,
    input                         rst_n,
    input                         rd_en,
    input      [SET_BITS-1:0]     rd_set,
    output reg                    rd_valid,
    output reg [WAY_COUNT-1:0]    rd_bits,
    input                         wr_en,
    input      [SET_BITS-1:0]     wr_set,
    input      [WAY_COUNT-1:0]    wr_mask,
    input      [WAY_COUNT-1:0]    wr_bits
);

    localparam integer BANK_COUNT = 64;
    localparam integer BANK_BITS = 6;
    localparam integer BANK_SET_BITS = SET_BITS - BANK_BITS;
    localparam integer BANK_DEPTH = SET_COUNT / BANK_COUNT;
    localparam integer READ_DELAY_INIT_INT =
        (READ_LATENCY_CYCLES > 1) ? (READ_LATENCY_CYCLES - 2) : 0;
    localparam [7:0] READ_DELAY_INIT = READ_DELAY_INIT_INT;

    reg                 read_pending_r;
    reg [7:0]           read_delay_left_r;
    reg [BANK_BITS-1:0] read_bank_r;
    reg [BANK_SET_BITS-1:0] read_index_r;

    wire [WAY_COUNT-1:0] bank_rd_bits [0:BANK_COUNT-1];
    reg  [WAY_COUNT-1:0] selected_bank_bits_w;

    integer sel_idx;
    always @(*) begin
        selected_bank_bits_w = {WAY_COUNT{1'b0}};
        for (sel_idx = 0; sel_idx < BANK_COUNT; sel_idx = sel_idx + 1) begin
            if (read_bank_r == sel_idx[BANK_BITS-1:0]) begin
                selected_bank_bits_w = bank_rd_bits[sel_idx];
            end
        end
    end

    genvar bank_idx;
    generate
        for (bank_idx = 0; bank_idx < BANK_COUNT; bank_idx = bank_idx + 1) begin : gen_bank
            localparam [BANK_BITS-1:0] BANK_ID = bank_idx[BANK_BITS-1:0];
            wire bank_wr_en = wr_en &&
                (wr_set[SET_BITS-1:BANK_SET_BITS] == BANK_ID);

            llc_valid_ram_banked_probe_bank #(
                .BANK_DEPTH(BANK_DEPTH),
                .BANK_SET_BITS(BANK_SET_BITS),
                .WAY_COUNT(WAY_COUNT)
            ) bank (
                .clk      (clk),
                .rd_index (read_index_r),
                .rd_bits  (bank_rd_bits[bank_idx]),
                .wr_en    (bank_wr_en),
                .wr_index (wr_set[BANK_SET_BITS-1:0]),
                .wr_mask  (wr_mask),
                .wr_bits  (wr_bits)
            );
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_valid <= 1'b0;
            rd_bits <= {WAY_COUNT{1'b0}};
            read_pending_r <= 1'b0;
            read_delay_left_r <= 8'd0;
            read_bank_r <= {BANK_BITS{1'b0}};
            read_index_r <= {BANK_SET_BITS{1'b0}};
        end else begin
            rd_valid <= 1'b0;

            if (read_pending_r) begin
                if (read_delay_left_r != 0) begin
                    read_delay_left_r <= read_delay_left_r - 8'd1;
                end else begin
                    rd_valid <= 1'b1;
                    rd_bits <= selected_bank_bits_w;
                    read_pending_r <= 1'b0;
                end
            end else if (rd_en) begin
                read_pending_r <= 1'b1;
                read_bank_r <= rd_set[SET_BITS-1:BANK_SET_BITS];
                read_index_r <= rd_set[BANK_SET_BITS-1:0];
                read_delay_left_r <= READ_DELAY_INIT;
            end
        end
    end

endmodule
