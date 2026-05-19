`timescale 1ns / 1ps

// Shared AXI beat shape helper used by the production lower AXI bridge.
module axi_llc_axi_beat_shape #(
    parameter integer AXI_DATA_BYTES = 32
) (
    input      [7:0] total_size,
    output     [7:0] total_beats,
    output     [7:0] axi_len,
    output     [2:0] axi_size
);

    localparam [2:0] AXI_SIZE_CODE =
        (AXI_DATA_BYTES == 32) ? 3'd5 :
        (AXI_DATA_BYTES == 16) ? 3'd4 :
        (AXI_DATA_BYTES == 8)  ? 3'd3 : 3'd2;

    generate
        if (AXI_DATA_BYTES == 32) begin : gen_32b_fast_shape
            assign total_beats = (total_size <= 8'd31)  ? 8'd1 :
                                 (total_size <= 8'd63)  ? 8'd2 :
                                 (total_size <= 8'd95)  ? 8'd3 :
                                 (total_size <= 8'd127) ? 8'd4 :
                                 (total_size <= 8'd159) ? 8'd5 :
                                 (total_size <= 8'd191) ? 8'd6 :
                                 (total_size <= 8'd223) ? 8'd7 : 8'd8;
            assign axi_len = (total_size <= 8'd31)  ? 8'd0 :
                             (total_size <= 8'd63)  ? 8'd1 :
                             (total_size <= 8'd95)  ? 8'd2 :
                             (total_size <= 8'd127) ? 8'd3 :
                             (total_size <= 8'd159) ? 8'd4 :
                             (total_size <= 8'd191) ? 8'd5 :
                             (total_size <= 8'd223) ? 8'd6 : 8'd7;
        end else begin : gen_generic_shape
            wire [15:0] bytes_w;
            wire [15:0] beats_w;

            assign bytes_w = {8'd0, total_size} + 16'd1;
            assign beats_w = (bytes_w + AXI_DATA_BYTES - 1) / AXI_DATA_BYTES;
            assign total_beats = (beats_w == 16'd0) ? 8'd1 : beats_w[7:0];
            assign axi_len = total_beats - 8'd1;
        end
    endgenerate

    assign axi_size = AXI_SIZE_CODE;

endmodule
