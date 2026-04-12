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
    reg                write_busy_r;
    reg [SET_BITS-1:0] wr_set_r;
    reg [WAY_COUNT-1:0] wr_way_mask_r;
    reg [ROW_BITS-1:0] wr_row_r;
    integer way_idx;

    assign busy = write_busy_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_valid      <= 1'b0;
            rd_row        <= {ROW_BITS{1'b0}};
            write_busy_r  <= 1'b0;
            wr_set_r      <= {SET_BITS{1'b0}};
            wr_way_mask_r <= {WAY_COUNT{1'b0}};
            wr_row_r      <= {ROW_BITS{1'b0}};
        end else begin
            rd_valid <= 1'b0;

            if (!write_busy_r) begin
                if (rd_en && !wr_en) begin
                    rd_valid <= 1'b1;
                    rd_row   <= row_mem[rd_set];
                end else if (wr_en) begin
                    write_busy_r  <= 1'b1;
                    wr_set_r      <= wr_set;
                    wr_way_mask_r <= wr_way_mask;
                    wr_row_r      <= wr_row;
                end
            end else begin
                write_busy_r <= 1'b0;
                for (way_idx = 0; way_idx < WAY_COUNT; way_idx = way_idx + 1) begin
                    if (wr_way_mask_r[way_idx]) begin
                        row_mem[wr_set_r][(way_idx * META_BITS) +: META_BITS] <=
                            wr_row_r[(way_idx * META_BITS) +: META_BITS];
                    end
                end
            end
        end
    end

endmodule
