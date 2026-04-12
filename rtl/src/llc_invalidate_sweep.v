`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module llc_invalidate_sweep #(
    parameter SET_COUNT = `AXI_LLC_SET_COUNT,
    parameter SET_BITS  = `AXI_LLC_SET_BITS,
    parameter WAY_COUNT = `AXI_LLC_WAY_COUNT
) (
    input                      clk,
    input                      rst_n,
    input                      start,
    output                     busy,
    output reg                 done,
    output                     valid_wr_en,
    output reg [SET_BITS-1:0]  valid_wr_set,
    output [WAY_COUNT-1:0]     valid_wr_mask,
    output [WAY_COUNT-1:0]     valid_wr_bits
);

    reg busy_r;
    reg [SET_BITS-1:0] sweep_index_r;

    assign busy          = busy_r;
    assign valid_wr_en   = busy_r;
    assign valid_wr_mask = {WAY_COUNT{1'b1}};
    assign valid_wr_bits = {WAY_COUNT{1'b0}};

    always @(*) begin
        valid_wr_set = sweep_index_r;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy_r        <= 1'b0;
            done          <= 1'b0;
            sweep_index_r <= {SET_BITS{1'b0}};
        end else begin
            done <= 1'b0;

            if (!busy_r) begin
                if (start) begin
                    busy_r        <= 1'b1;
                    sweep_index_r <= {SET_BITS{1'b0}};
                end
            end else begin
                if (sweep_index_r == (SET_COUNT - 1)) begin
                    busy_r        <= 1'b0;
                    done          <= 1'b1;
                    sweep_index_r <= {SET_BITS{1'b0}};
                end else begin
                    sweep_index_r <= sweep_index_r + 1'b1;
                end
            end
        end
    end

endmodule
