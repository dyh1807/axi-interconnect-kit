`timescale 1ns / 1ps

// AXI R channel beat merge and optional mode2 aligned read extraction helper.
module axi_llc_axi_read_pack #(
    parameter ADDR_BITS = 32,
    parameter READ_RESP_BYTES = 64,
    parameter AXI_DATA_BYTES = 32
) (
    input  [(READ_RESP_BYTES*8)-1:0] current_data,
    input  [(AXI_DATA_BYTES*8)-1:0]  beat_data,
    input  [ADDR_BITS-1:0]           req_addr,
    input  [ADDR_BITS-1:0]           issued_addr,
    input  [7:0]                     beat_idx,
    input                            mode2_ddr_aligned,
    output reg [(READ_RESP_BYTES*8)-1:0] merged_data,
    output reg [(READ_RESP_BYTES*8)-1:0] final_data
);

    localparam integer READ_RESP_BITS = READ_RESP_BYTES * 8;
    localparam integer AXI_DATA_BITS = AXI_DATA_BYTES * 8;

    function [7:0] get_axi_byte;
        input [AXI_DATA_BITS-1:0] value;
        input integer             byte_idx;
        begin
            get_axi_byte = (value >> (byte_idx * 8)) & 8'hff;
        end
    endfunction

    function [7:0] get_read_resp_byte;
        input [READ_RESP_BITS-1:0] value;
        input integer              byte_idx;
        begin
            get_read_resp_byte = (value >> (byte_idx * 8)) & 8'hff;
        end
    endfunction

    function [READ_RESP_BITS-1:0] set_read_resp_byte;
        input [READ_RESP_BITS-1:0] value;
        input integer              byte_idx;
        input [7:0]                byte_value;
        reg [READ_RESP_BITS-1:0]   byte_mask;
        begin
            byte_mask = {{(READ_RESP_BITS-8){1'b0}}, 8'hff} << (byte_idx * 8);
            set_read_resp_byte =
                (value & ~byte_mask) |
                (({{(READ_RESP_BITS-8){1'b0}}, byte_value} << (byte_idx * 8)) &
                 byte_mask);
        end
    endfunction

    integer byte_idx;
    integer dst_byte;
    integer src_byte;
    integer byte_off;

    always @(*) begin
        merged_data = current_data;
        final_data = {READ_RESP_BITS{1'b0}};
        byte_off = req_addr - issued_addr;

        for (byte_idx = 0; byte_idx < AXI_DATA_BYTES; byte_idx = byte_idx + 1) begin
            dst_byte = beat_idx * AXI_DATA_BYTES + byte_idx;
            if (dst_byte < READ_RESP_BYTES) begin
                merged_data =
                    set_read_resp_byte(merged_data, dst_byte,
                                       get_axi_byte(beat_data, byte_idx));
            end
        end

        if (!mode2_ddr_aligned) begin
            final_data = merged_data;
        end else begin
            for (dst_byte = 0; dst_byte < READ_RESP_BYTES; dst_byte = dst_byte + 1) begin
                src_byte = dst_byte + byte_off;
                if ((src_byte >= 0) && (src_byte < READ_RESP_BYTES)) begin
                    final_data =
                        set_read_resp_byte(final_data, dst_byte,
                                           get_read_resp_byte(merged_data,
                                                              src_byte));
                end
            end
        end
    end

endmodule
