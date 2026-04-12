`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module llc_repl_ram #(
    parameter SET_COUNT = `AXI_LLC_SET_COUNT,
    parameter SET_BITS  = `AXI_LLC_SET_BITS,
    parameter WAY_COUNT = `AXI_LLC_WAY_COUNT,
    parameter WAY_BITS  = `AXI_LLC_WAY_BITS
) (
    input                         clk,
    input                         rst_n,
    input      [SET_BITS-1:0]     rd_set,
    output reg [WAY_BITS-1:0]     rd_way,
    input                         wr_en,
    input      [SET_BITS-1:0]     wr_set,
    input      [WAY_BITS-1:0]     wr_way
);

    reg [WAY_BITS-1:0] repl_mem [0:SET_COUNT-1];
    integer set_idx;

    always @(*) begin
        rd_way = repl_mem[rd_set];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (set_idx = 0; set_idx < SET_COUNT; set_idx = set_idx + 1) begin
                repl_mem[set_idx] <= {WAY_BITS{1'b0}};
            end
        end else if (wr_en) begin
            repl_mem[wr_set] <= wr_way;
        end
    end

endmodule
