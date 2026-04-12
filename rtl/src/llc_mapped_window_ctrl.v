`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module llc_mapped_window_ctrl #(
    parameter ADDR_BITS        = `AXI_LLC_ADDR_BITS,
    parameter LINE_BYTES       = `AXI_LLC_LINE_BYTES,
    parameter LINE_BITS        = `AXI_LLC_LINE_BITS,
    parameter LINE_OFFSET_BITS = `AXI_LLC_LINE_OFFSET_BITS,
    parameter SET_COUNT        = `AXI_LLC_SET_COUNT,
    parameter SET_BITS         = `AXI_LLC_SET_BITS,
    parameter WAY_COUNT        = `AXI_LLC_WAY_COUNT,
    parameter WAY_BITS         = `AXI_LLC_WAY_BITS,
    parameter WINDOW_BYTES     = `AXI_LLC_WINDOW_BYTES,
    parameter WINDOW_WAYS      = `AXI_LLC_WINDOW_WAYS
) (
    input      [ADDR_BITS-1:0]  req_addr,
    input      [ADDR_BITS-1:0]  window_offset,
    input      [LINE_BITS-1:0]  line_data_in,
    input                       line_valid_in,
    input      [LINE_BITS-1:0]  write_data_in,
    input      [LINE_BYTES-1:0] write_strb_in,
    output reg                  in_window,
    output reg                  offset_aligned,
    output reg                  mapped_way_legal,
    output reg [ADDR_BITS-1:0]  local_addr,
    output reg [SET_BITS-1:0]   direct_set,
    output reg [WAY_BITS-1:0]   direct_way,
    output reg [LINE_BITS-1:0]  read_line_out,
    output reg [LINE_BITS-1:0]  merged_line_out,
    output reg                  next_valid_bit_out
);

    localparam integer LLC_SIZE_BYTES = SET_COUNT * WAY_COUNT * LINE_BYTES;
    localparam [ADDR_BITS-1:0] WINDOW_BYTES_C = WINDOW_BYTES;

    reg [SET_BITS + WAY_BITS - 1:0] line_idx;
    integer byte_idx;

    initial begin
        if (WINDOW_BYTES > LLC_SIZE_BYTES) begin
            $display("ERROR: llc_mapped_window_ctrl WINDOW_BYTES exceeds LLC capacity");
            $finish;
        end

        if ((WINDOW_BYTES % (SET_COUNT * LINE_BYTES)) != 0) begin
            $display("ERROR: llc_mapped_window_ctrl WINDOW_BYTES must be an integer way-slice");
            $finish;
        end

        if (WINDOW_WAYS > WAY_COUNT) begin
            $display("ERROR: llc_mapped_window_ctrl WINDOW_WAYS exceeds WAY_COUNT");
            $finish;
        end
    end

    always @(*) begin
        offset_aligned = (window_offset[LINE_OFFSET_BITS-1:0] == {LINE_OFFSET_BITS{1'b0}});

        if (req_addr >= window_offset) begin
            local_addr = req_addr - window_offset;
            in_window  = ((req_addr - window_offset) < WINDOW_BYTES_C);
        end else begin
            local_addr = {ADDR_BITS{1'b0}};
            in_window  = 1'b0;
        end

        line_idx         = local_addr >> LINE_OFFSET_BITS;
        direct_set       = line_idx[SET_BITS-1:0];
        direct_way       = line_idx[SET_BITS + WAY_BITS - 1:SET_BITS];
        mapped_way_legal = (direct_way < WINDOW_WAYS);

        if (line_valid_in) begin
            read_line_out = line_data_in;
        end else begin
            read_line_out = {LINE_BITS{1'b0}};
        end

        merged_line_out   = read_line_out;
        next_valid_bit_out = 1'b1;

        for (byte_idx = 0; byte_idx < LINE_BYTES; byte_idx = byte_idx + 1) begin
            if (write_strb_in[byte_idx]) begin
                merged_line_out[(byte_idx * 8) +: 8] = write_data_in[(byte_idx * 8) +: 8];
            end
        end
    end

endmodule
