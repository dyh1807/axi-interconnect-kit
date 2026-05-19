`timescale 1ns / 1ps

// mode2 DDR-aligned issue address/size helper used by axi_llc_axi_bridge.
module axi_llc_axi_mode2_shape #(
    parameter ADDR_BITS = 32,
    parameter LINE_BYTES = 64,
    parameter AXI_DATA_BYTES = 32
) (
    input      [ADDR_BITS-1:0] addr,
    input      [7:0]           total_size,
    output                     single_axi_beat,
    output     [ADDR_BITS-1:0] issue_addr,
    output     [7:0]           issue_size
);

    localparam [ADDR_BITS-1:0] AXI_DATA_BYTES_ADDR = AXI_DATA_BYTES;
    localparam [ADDR_BITS-1:0] LINE_BYTES_ADDR = LINE_BYTES;
    localparam [15:0]          AXI_DATA_BYTES_16 = AXI_DATA_BYTES;
    localparam [ADDR_BITS:0]   AXI_DATA_BYTES_EXT = AXI_DATA_BYTES;
    localparam [7:0]           AXI_DATA_SIZE_M1 = AXI_DATA_BYTES - 1;
    localparam [7:0]           LINE_SIZE_M1 = LINE_BYTES - 1;
    localparam                 SPECIAL_64B_32B =
        (LINE_BYTES == 64) && (AXI_DATA_BYTES == 32);
    localparam                 SPECIAL_8B_4B =
        (LINE_BYTES == 8) && (AXI_DATA_BYTES == 4);
    localparam                 SPECIAL_4B_4B =
        (LINE_BYTES == 4) && (AXI_DATA_BYTES == 4);

    function [ADDR_BITS-1:0] align_down_addr;
        input [ADDR_BITS-1:0] addr_value;
        input [ADDR_BITS-1:0] align_bytes;
        begin
            if (align_bytes <= {{(ADDR_BITS-1){1'b0}}, 1'b1}) begin
                align_down_addr = addr_value;
            end else begin
                align_down_addr = (addr_value / align_bytes) * align_bytes;
            end
        end
    endfunction

    function mode2_single_axi_beat;
        input [ADDR_BITS-1:0] addr_value;
        input [7:0]           size_value;
        reg [15:0]            req_bytes;
        reg [ADDR_BITS-1:0]   beat_addr;
        reg [ADDR_BITS:0]     req_bytes_ext;
        reg [ADDR_BITS:0]     end_byte;
        begin
            req_bytes = {8'd0, size_value} + 16'd1;
            req_bytes_ext = req_bytes;
            beat_addr = align_down_addr(addr_value, AXI_DATA_BYTES_ADDR);
            end_byte = {1'b0, (addr_value - beat_addr)} + req_bytes_ext;
            mode2_single_axi_beat =
                (req_bytes <= AXI_DATA_BYTES_16) &&
                (end_byte <= AXI_DATA_BYTES_EXT);
        end
    endfunction

    generate
        if (SPECIAL_64B_32B) begin : gen_64b_32b_shape
            wire [8:0] end_size_sum_w;
            wire       single_w;

            assign end_size_sum_w = {4'b0000, addr[4:0]} + {1'b0, total_size};
            assign single_w = end_size_sum_w <= 9'd31;

            assign single_axi_beat = single_w;
            assign issue_addr = single_w ? {addr[ADDR_BITS-1:5], 5'b00000} :
                                           {addr[ADDR_BITS-1:6], 6'b000000};
            assign issue_size = single_w ? AXI_DATA_SIZE_M1 : LINE_SIZE_M1;
        end else if (SPECIAL_8B_4B) begin : gen_8b_4b_shape
            wire [8:0] end_size_sum_w;
            wire       single_w;

            assign end_size_sum_w = {6'b000000, addr[1:0]} + {1'b0, total_size};
            assign single_w = end_size_sum_w <= 9'd3;

            assign single_axi_beat = single_w;
            assign issue_addr = single_w ? {addr[ADDR_BITS-1:2], 2'b00} :
                                           {addr[ADDR_BITS-1:3], 3'b000};
            assign issue_size = single_w ? AXI_DATA_SIZE_M1 : LINE_SIZE_M1;
        end else if (SPECIAL_4B_4B) begin : gen_4b_4b_shape
            wire [8:0] end_size_sum_w;

            assign end_size_sum_w = {6'b000000, addr[1:0]} + {1'b0, total_size};

            assign single_axi_beat = end_size_sum_w <= 9'd3;
            assign issue_addr = {addr[ADDR_BITS-1:2], 2'b00};
            assign issue_size = AXI_DATA_SIZE_M1;
        end else begin : gen_generic_shape
            assign single_axi_beat = mode2_single_axi_beat(addr, total_size);
            assign issue_addr =
                single_axi_beat ? align_down_addr(addr, AXI_DATA_BYTES_ADDR) :
                                  align_down_addr(addr, LINE_BYTES_ADDR);
            assign issue_size =
                single_axi_beat ? AXI_DATA_SIZE_M1 : LINE_SIZE_M1;
        end
    endgenerate

endmodule
