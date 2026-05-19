`timescale 1ns / 1ps
`include "axi_llc_params.vh"

// DC-only timing probe: register the wide AXI pack helper inputs and outputs
// so quick-map reports the packer's local reg-to-reg setup timing.
module axi_llc_pack_timing_probe #(
    parameter ADDR_BITS      = `AXI_LLC_ADDR_BITS,
    parameter LINE_BYTES     = `AXI_LLC_LINE_BYTES,
    parameter LINE_BITS      = `AXI_LLC_LINE_BITS,
    parameter READ_RESP_BYTES = `AXI_LLC_READ_RESP_BYTES,
    parameter READ_RESP_BITS = `AXI_LLC_READ_RESP_BITS,
    parameter AXI_DATA_BYTES = `AXI_LLC_AXI_DATA_BYTES,
    parameter AXI_DATA_BITS  = `AXI_LLC_AXI_DATA_BITS,
    parameter READ_MODE2_EXTRACT_BYTES = LINE_BYTES,
    parameter WRITE_SINGLE_BEAT_ONLY = 0
) (
    input                         clk,
    input                         rst_n,
    input      [READ_RESP_BITS-1:0] current_data_i,
    input      [AXI_DATA_BITS-1:0]  beat_data_i,
    input      [ADDR_BITS-1:0]      req_addr_i,
    input      [ADDR_BITS-1:0]      issued_addr_i,
    input      [7:0]                beat_idx_i,
    input                           mode2_ddr_aligned_i,
    input      [LINE_BITS-1:0]      line_data_i,
    input      [LINE_BYTES-1:0]     line_strb_i,
    output reg [READ_RESP_BITS-1:0] read_merged_o,
    output reg [READ_RESP_BITS-1:0] read_final_o,
    output reg [AXI_DATA_BITS-1:0]  write_data_o,
    output reg [AXI_DATA_BYTES-1:0] write_strb_o
);

    reg [READ_RESP_BITS-1:0] current_data_r;
    reg [AXI_DATA_BITS-1:0]  beat_data_r;
    reg [ADDR_BITS-1:0]      req_addr_r;
    reg [ADDR_BITS-1:0]      issued_addr_r;
    reg [7:0]                beat_idx_r;
    reg                      mode2_ddr_aligned_r;
    reg [LINE_BITS-1:0]      line_data_r;
    reg [LINE_BYTES-1:0]     line_strb_r;

    wire [READ_RESP_BITS-1:0] read_merged_w;
    wire [READ_RESP_BITS-1:0] read_final_w;
    wire [AXI_DATA_BITS-1:0]  write_data_w;
    wire [AXI_DATA_BYTES-1:0] write_strb_w;

    axi_llc_axi_read_pack #(
        .ADDR_BITS(ADDR_BITS),
        .READ_RESP_BYTES(READ_RESP_BYTES),
        .AXI_DATA_BYTES(AXI_DATA_BYTES),
        .MODE2_EXTRACT_BYTES(READ_MODE2_EXTRACT_BYTES)
    ) u_read_pack (
        .current_data(current_data_r),
        .beat_data(beat_data_r),
        .req_addr(req_addr_r),
        .issued_addr(issued_addr_r),
        .beat_idx(beat_idx_r),
        .mode2_ddr_aligned(mode2_ddr_aligned_r),
        .merged_data(read_merged_w),
        .final_data(read_final_w)
    );

    axi_llc_axi_write_pack #(
        .ADDR_BITS(ADDR_BITS),
        .LINE_BYTES(LINE_BYTES),
        .AXI_DATA_BYTES(AXI_DATA_BYTES),
        .SINGLE_BEAT_ONLY(WRITE_SINGLE_BEAT_ONLY)
    ) u_write_pack (
        .line_data(line_data_r),
        .line_strb(line_strb_r),
        .req_addr(req_addr_r),
        .issued_addr(issued_addr_r),
        .beat_idx(beat_idx_r),
        .mode2_ddr_aligned(mode2_ddr_aligned_r),
        .axi_wdata(write_data_w),
        .axi_wstrb(write_strb_w)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_data_r <= {READ_RESP_BITS{1'b0}};
            beat_data_r <= {AXI_DATA_BITS{1'b0}};
            req_addr_r <= {ADDR_BITS{1'b0}};
            issued_addr_r <= {ADDR_BITS{1'b0}};
            beat_idx_r <= 8'd0;
            mode2_ddr_aligned_r <= 1'b0;
            line_data_r <= {LINE_BITS{1'b0}};
            line_strb_r <= {LINE_BYTES{1'b0}};
            read_merged_o <= {READ_RESP_BITS{1'b0}};
            read_final_o <= {READ_RESP_BITS{1'b0}};
            write_data_o <= {AXI_DATA_BITS{1'b0}};
            write_strb_o <= {AXI_DATA_BYTES{1'b0}};
        end else begin
            current_data_r <= current_data_i;
            beat_data_r <= beat_data_i;
            req_addr_r <= req_addr_i;
            issued_addr_r <= issued_addr_i;
            beat_idx_r <= beat_idx_i;
            mode2_ddr_aligned_r <= mode2_ddr_aligned_i;
            line_data_r <= line_data_i;
            line_strb_r <= line_strb_i;
            read_merged_o <= read_merged_w;
            read_final_o <= read_final_w;
            write_data_o <= write_data_w;
            write_strb_o <= write_strb_w;
        end
    end

endmodule
