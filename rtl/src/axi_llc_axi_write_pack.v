`timescale 1ns / 1ps

// AXI W channel data/strobe packing helper used by axi_llc_axi_bridge.
module axi_llc_axi_write_pack #(
    parameter ADDR_BITS = 32,
    parameter LINE_BYTES = 64,
    parameter AXI_DATA_BYTES = 32
) (
    input  [(LINE_BYTES*8)-1:0]     line_data,
    input  [LINE_BYTES-1:0]         line_strb,
    input  [ADDR_BITS-1:0]          req_addr,
    input  [ADDR_BITS-1:0]          issued_addr,
    input  [7:0]                    beat_idx,
    input                           mode2_ddr_aligned,
    output reg [(AXI_DATA_BYTES*8)-1:0] axi_wdata,
    output reg [AXI_DATA_BYTES-1:0] axi_wstrb
);

    localparam integer AXI_DATA_BITS = AXI_DATA_BYTES * 8;
    localparam integer LINE_BITS = LINE_BYTES * 8;

    function [7:0] get_line_byte;
        input [LINE_BITS-1:0] value;
        input integer         byte_idx;
        begin
            get_line_byte = (value >> (byte_idx * 8)) & 8'hff;
        end
    endfunction

    function [AXI_DATA_BITS-1:0] set_axi_byte;
        input [AXI_DATA_BITS-1:0] value;
        input integer             byte_idx;
        input [7:0]               byte_value;
        reg [AXI_DATA_BITS-1:0]   byte_mask;
        begin
            byte_mask = {{(AXI_DATA_BITS-8){1'b0}}, 8'hff} << (byte_idx * 8);
            set_axi_byte =
                (value & ~byte_mask) |
                (({{(AXI_DATA_BITS-8){1'b0}}, byte_value} << (byte_idx * 8)) &
                 byte_mask);
        end
    endfunction

    integer byte_idx;
    integer dst_byte;
    integer src_byte;
    integer byte_off;

    always @(*) begin
        axi_wdata = {AXI_DATA_BITS{1'b0}};
        axi_wstrb = {AXI_DATA_BYTES{1'b0}};
        byte_off = req_addr - issued_addr;
        for (byte_idx = 0; byte_idx < AXI_DATA_BYTES; byte_idx = byte_idx + 1) begin
            dst_byte = beat_idx * AXI_DATA_BYTES + byte_idx;
            src_byte = mode2_ddr_aligned ? (dst_byte - byte_off) : dst_byte;
            if ((src_byte >= 0) && (src_byte < LINE_BYTES)) begin
                axi_wdata =
                    set_axi_byte(axi_wdata, byte_idx,
                                 get_line_byte(line_data, src_byte));
                axi_wstrb[byte_idx] = line_strb[src_byte];
            end
        end
    end

endmodule
