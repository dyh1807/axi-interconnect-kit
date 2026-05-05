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

    assign single_axi_beat = mode2_single_axi_beat(addr, total_size);
    assign issue_addr =
        single_axi_beat ? align_down_addr(addr, AXI_DATA_BYTES_ADDR) :
                          align_down_addr(addr, LINE_BYTES_ADDR);
    assign issue_size =
        single_axi_beat ? AXI_DATA_SIZE_M1 : LINE_SIZE_M1;

endmodule
