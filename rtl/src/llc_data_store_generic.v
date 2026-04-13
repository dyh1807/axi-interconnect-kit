`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module llc_data_store_generic #(
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

    reg [ROW_BITS-1:0] row_mem [0:SET_COUNT-1];
    reg                read_pending_r;
    reg [SET_BITS-1:0] read_set_r;
    reg [7:0]          read_delay_left_r;
    integer way_idx;

    assign busy = 1'b0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_valid <= 1'b0;
            rd_row   <= {ROW_BITS{1'b0}};
            read_pending_r <= 1'b0;
            read_set_r <= {SET_BITS{1'b0}};
            read_delay_left_r <= 8'd0;
        end else begin
            rd_valid <= 1'b0;

            if (read_pending_r) begin
                if (read_delay_left_r != 0) begin
                    read_delay_left_r <= read_delay_left_r - 8'd1;
                end else begin
                    rd_valid <= 1'b1;
                    rd_row <= row_mem[read_set_r];
                    read_pending_r <= 1'b0;
                end
            end else if (rd_en && !wr_en) begin
                if (READ_LATENCY_CYCLES <= 1) begin
                    rd_valid <= 1'b1;
                    rd_row <= row_mem[rd_set];
                end else begin
                    read_pending_r <= 1'b1;
                    read_set_r <= rd_set;
                    read_delay_left_r <= READ_LATENCY_CYCLES - 2;
                end
            end

            if (wr_en) begin
                for (way_idx = 0; way_idx < WAY_COUNT; way_idx = way_idx + 1) begin
                    if (wr_way_mask[way_idx]) begin
                        row_mem[wr_set][(way_idx * LINE_BITS) +: LINE_BITS] <=
                            wr_row[(way_idx * LINE_BITS) +: LINE_BITS];
                    end
                end
            end
        end
    end

endmodule
