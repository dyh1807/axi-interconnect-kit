`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module llc_data_ram #(
    parameter SET_COUNT = `AXI_LLC_SET_COUNT,
    parameter SET_BITS  = `AXI_LLC_SET_BITS,
    parameter WAY_COUNT = `AXI_LLC_WAY_COUNT,
    parameter WAY_BITS  = `AXI_LLC_WAY_BITS,
    parameter LINE_BITS = `AXI_LLC_LINE_BITS
) (
    input                         clk,
    input                         rd_en,
    input      [SET_BITS-1:0]     rd_set,
    input      [WAY_BITS-1:0]     rd_way,
    output reg [LINE_BITS-1:0]    rd_line,
    input                         wr_en,
    input      [SET_BITS-1:0]     wr_set,
    input      [WAY_BITS-1:0]     wr_way,
    input      [LINE_BITS-1:0]    wr_line
);

    reg [LINE_BITS-1:0] data_mem [0:(SET_COUNT * WAY_COUNT) - 1];

    function integer flat_index;
        input [SET_BITS-1:0] set_idx;
        input [WAY_BITS-1:0] way_idx;
        begin
            flat_index = set_idx + (way_idx * SET_COUNT);
        end
    endfunction

    always @(*) begin
        if (rd_en) begin
            rd_line = data_mem[flat_index(rd_set, rd_way)];
        end else begin
            rd_line = {LINE_BITS{1'b0}};
        end
    end

    always @(posedge clk) begin
        if (wr_en) begin
            data_mem[flat_index(wr_set, wr_way)] <= wr_line;
        end
    end

endmodule
