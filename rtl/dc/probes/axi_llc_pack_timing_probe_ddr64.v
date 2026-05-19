`timescale 1ns / 1ps
`include "axi_llc_params.vh"

// DC-only wrapper for the current DDR-side bridge pack datapath:
// 64B read response storage and 32B AXI beats.
module axi_llc_pack_timing_probe_ddr64 (
    input                         clk,
    input                         rst_n,
    input      [511:0]             current_data_i,
    input      [255:0]             beat_data_i,
    input      [`AXI_LLC_ADDR_BITS-1:0] req_addr_i,
    input      [`AXI_LLC_ADDR_BITS-1:0] issued_addr_i,
    input      [7:0]               beat_idx_i,
    input                          mode2_ddr_aligned_i,
    input      [`AXI_LLC_LINE_BITS-1:0] line_data_i,
    input      [`AXI_LLC_LINE_BYTES-1:0] line_strb_i,
    output     [511:0]             read_merged_o,
    output     [511:0]             read_final_o,
    output     [255:0]             write_data_o,
    output     [31:0]              write_strb_o
);

    axi_llc_pack_timing_probe #(
        .READ_RESP_BYTES(64),
        .READ_RESP_BITS(512),
        .AXI_DATA_BYTES(32),
        .AXI_DATA_BITS(256)
    ) u_probe (
        .clk(clk),
        .rst_n(rst_n),
        .current_data_i(current_data_i),
        .beat_data_i(beat_data_i),
        .req_addr_i(req_addr_i),
        .issued_addr_i(issued_addr_i),
        .beat_idx_i(beat_idx_i),
        .mode2_ddr_aligned_i(mode2_ddr_aligned_i),
        .line_data_i(line_data_i),
        .line_strb_i(line_strb_i),
        .read_merged_o(read_merged_o),
        .read_final_o(read_final_o),
        .write_data_o(write_data_o),
        .write_strb_o(write_strb_o)
    );

endmodule
