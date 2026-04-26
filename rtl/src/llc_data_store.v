`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module llc_data_store #(
    parameter SET_COUNT  = `AXI_LLC_SET_COUNT,
    parameter SET_BITS   = `AXI_LLC_SET_BITS,
    parameter WAY_COUNT  = `AXI_LLC_WAY_COUNT,
    parameter LINE_BITS  = `AXI_LLC_LINE_BITS,
    parameter ROW_BITS   = WAY_COUNT * LINE_BITS,
    parameter READ_LATENCY_CYCLES = `AXI_LLC_TABLE_READ_LATENCY,
    parameter USE_SMIC12 = 1
) (
    input                         clk,
    input                         rst_n,
    input                         rd_en,
    input      [SET_BITS-1:0]     rd_set,
    output                        rd_valid,
    output     [ROW_BITS-1:0]     rd_row,
    input                         wr_en,
    input      [SET_BITS-1:0]     wr_set,
    input      [WAY_COUNT-1:0]    wr_way_mask,
    input      [ROW_BITS-1:0]     wr_row,
    output                        busy
);

    generate
        if (USE_SMIC12 &&
            (SET_COUNT == 8192) &&
            (SET_BITS == 13) &&
            (WAY_COUNT == 16) &&
            (LINE_BITS == 512) &&
            (ROW_BITS == (WAY_COUNT * LINE_BITS))) begin : gen_smic12
            llc_data_store_smic12 #(
                .SET_COUNT (SET_COUNT),
                .SET_BITS  (SET_BITS),
                .WAY_COUNT (WAY_COUNT),
                .LINE_BITS (LINE_BITS),
                .ROW_BITS  (ROW_BITS),
                .READ_LATENCY_CYCLES(READ_LATENCY_CYCLES)
            ) u_impl (
                .clk         (clk),
                .rst_n       (rst_n),
                .rd_en       (rd_en),
                .rd_set      (rd_set),
                .rd_valid    (rd_valid),
                .rd_row      (rd_row),
                .wr_en       (wr_en),
                .wr_set      (wr_set),
                .wr_way_mask (wr_way_mask),
                .wr_row      (wr_row),
                .busy        (busy)
            );
        end else begin : gen_generic
            llc_data_store_generic #(
                .SET_COUNT (SET_COUNT),
                .SET_BITS  (SET_BITS),
                .WAY_COUNT (WAY_COUNT),
                .LINE_BITS (LINE_BITS),
                .ROW_BITS  (ROW_BITS),
                .READ_LATENCY_CYCLES(READ_LATENCY_CYCLES)
            ) u_impl (
                .clk         (clk),
                .rst_n       (rst_n),
                .rd_en       (rd_en),
                .rd_set      (rd_set),
                .rd_valid    (rd_valid),
                .rd_row      (rd_row),
                .wr_en       (wr_en),
                .wr_set      (wr_set),
                .wr_way_mask (wr_way_mask),
                .wr_row      (wr_row),
                .busy        (busy)
            );
        end
    endgenerate

endmodule
