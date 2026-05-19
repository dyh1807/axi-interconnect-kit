`timescale 1ns / 1ps
`include "axi_llc_params.vh"

// DC-only wrapper for the MMIO-side bridge pack datapath:
// 4B read response storage, 4B AXI beats, and single-beat write packing.
module axi_llc_pack_timing_probe_mmio4 (
    input                         clk,
    input                         rst_n,
    input      [31:0]             current_data_i,
    input      [31:0]             beat_data_i,
    input      [`AXI_LLC_ADDR_BITS-1:0] req_addr_i,
    input      [`AXI_LLC_ADDR_BITS-1:0] issued_addr_i,
    input      [7:0]              beat_idx_i,
    input                         mode2_ddr_aligned_i,
    input      [`AXI_LLC_LINE_BITS-1:0] line_data_i,
    input      [`AXI_LLC_LINE_BYTES-1:0] line_strb_i,
    output     [31:0]             read_merged_o,
    output     [31:0]             read_final_o,
    output     [31:0]             write_data_o,
    output     [3:0]              write_strb_o
);

    axi_llc_pack_timing_probe #(
        .READ_RESP_BYTES(4),
        .READ_RESP_BITS(32),
        .AXI_DATA_BYTES(4),
        .AXI_DATA_BITS(32),
        .READ_MODE2_EXTRACT_BYTES(4),
        .WRITE_SINGLE_BEAT_ONLY(1)
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
