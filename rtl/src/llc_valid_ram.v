`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module llc_valid_ram #(
    parameter SET_COUNT = `AXI_LLC_SET_COUNT,
    parameter SET_BITS  = `AXI_LLC_SET_BITS,
    parameter WAY_COUNT = `AXI_LLC_WAY_COUNT
) (
    input                         clk,
    input                         rd_en,
    input      [SET_BITS-1:0]     rd_set,
    output reg [WAY_COUNT-1:0]    rd_bits,
    input                         wr_en,
    input      [SET_BITS-1:0]     wr_set,
    input      [WAY_COUNT-1:0]    wr_mask,
    input      [WAY_COUNT-1:0]    wr_bits
);

    reg [WAY_COUNT-1:0] valid_mem [0:SET_COUNT-1];

    always @(*) begin
        if (rd_en) begin
            rd_bits = valid_mem[rd_set];
        end else begin
            rd_bits = {WAY_COUNT{1'b0}};
        end
    end

    always @(posedge clk) begin
        if (wr_en) begin
            valid_mem[wr_set] <= (valid_mem[wr_set] & (~wr_mask)) | (wr_bits & wr_mask);
        end
    end

endmodule
