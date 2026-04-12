`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module llc_meta_store #(
    parameter SET_COUNT = `AXI_LLC_SET_COUNT,
    parameter SET_BITS  = `AXI_LLC_SET_BITS,
    parameter WAY_COUNT = `AXI_LLC_WAY_COUNT,
    parameter META_BITS = `AXI_LLC_META_BITS,
    parameter ROW_BITS  = WAY_COUNT * META_BITS
) (
    input                         clk,
    input                         rd_en,
    input      [SET_BITS-1:0]     rd_set,
    output reg [ROW_BITS-1:0]     rd_row,
    input                         wr_en,
    input      [SET_BITS-1:0]     wr_set,
    input      [WAY_COUNT-1:0]    wr_way_mask,
    input      [ROW_BITS-1:0]     wr_row
);

    reg [ROW_BITS-1:0] row_mem [0:SET_COUNT-1];
    integer way_idx;

    always @(*) begin
        if (rd_en) begin
            rd_row = row_mem[rd_set];
        end else begin
            rd_row = {ROW_BITS{1'b0}};
        end
    end

    always @(posedge clk) begin
        if (wr_en) begin
            for (way_idx = 0; way_idx < WAY_COUNT; way_idx = way_idx + 1) begin
                if (wr_way_mask[way_idx]) begin
                    row_mem[wr_set][(way_idx * META_BITS) +: META_BITS] <=
                        wr_row[(way_idx * META_BITS) +: META_BITS];
                end
            end
        end
    end

endmodule
