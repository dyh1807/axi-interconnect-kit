`timescale 1ns / 1ps

module llc_mapped_window_ctrl_timing_probe (
    input  clk,
    output sink
);
    localparam ADDR_BITS = 32;
    localparam LINE_BYTES = 64;
    localparam LINE_BITS = 512;
    localparam LINE_OFFSET_BITS = 6;
    localparam SET_COUNT = 8192;
    localparam SET_BITS = 13;
    localparam WAY_COUNT = 16;
    localparam WAY_BITS = 4;
    localparam WINDOW_BYTES = 32'h0040_0000;
    localparam WINDOW_WAYS = 8;

    reg [ADDR_BITS-1:0] req_addr_r;
    reg [7:0] req_total_size_r;
    reg [ADDR_BITS-1:0] window_offset_r;
    reg [WAY_COUNT*LINE_BITS-1:0] row_data_r;
    reg [WAY_COUNT-1:0] valid_bits_r;
    reg [LINE_BITS-1:0] write_data_r;
    reg [LINE_BYTES-1:0] write_strb_r;

    wire in_window_w;
    wire offset_aligned_w;
    wire mapped_way_legal_w;
    wire [ADDR_BITS-1:0] local_addr_w;
    wire [SET_BITS-1:0] direct_set_w;
    wire [WAY_BITS-1:0] direct_way_w;
    wire line_valid_w;
    wire [LINE_BITS-1:0] read_line_w;
    wire [LINE_BITS-1:0] write_line_w;
    wire next_valid_bit_w;

    reg sink_r;
    assign sink = sink_r;

    llc_mapped_window_ctrl #(
        .ADDR_BITS(ADDR_BITS),
        .LINE_BYTES(LINE_BYTES),
        .LINE_BITS(LINE_BITS),
        .LINE_OFFSET_BITS(LINE_OFFSET_BITS),
        .SET_COUNT(SET_COUNT),
        .SET_BITS(SET_BITS),
        .WAY_COUNT(WAY_COUNT),
        .WAY_BITS(WAY_BITS),
        .WINDOW_BYTES(WINDOW_BYTES),
        .WINDOW_WAYS(WINDOW_WAYS)
    ) dut (
        .req_addr(req_addr_r),
        .req_total_size(req_total_size_r),
        .window_offset(window_offset_r),
        .row_data_in(row_data_r),
        .valid_bits_in(valid_bits_r),
        .write_data_in(write_data_r),
        .write_strb_in(write_strb_r),
        .in_window(in_window_w),
        .offset_aligned(offset_aligned_w),
        .mapped_way_legal(mapped_way_legal_w),
        .local_addr(local_addr_w),
        .direct_set(direct_set_w),
        .direct_way(direct_way_w),
        .line_valid_out(line_valid_w),
        .read_line_out(read_line_w),
        .write_line_out(write_line_w),
        .next_valid_bit_out(next_valid_bit_w)
    );

    always @(posedge clk) begin
        req_addr_r <= {req_addr_r[30:0],
                       in_window_w ^ mapped_way_legal_w ^ line_valid_w};
        req_total_size_r <= {req_total_size_r[6:0],
                             offset_aligned_w ^ next_valid_bit_w};
        window_offset_r <= {window_offset_r[30:0],
                            in_window_w ^ offset_aligned_w};
        row_data_r <= {row_data_r[(WAY_COUNT*LINE_BITS)-2:0],
                       ^write_line_w};
        valid_bits_r <= {valid_bits_r[WAY_COUNT-2:0], ^read_line_w};
        write_data_r <= {write_data_r[LINE_BITS-2:0], line_valid_w};
        write_strb_r <= {write_strb_r[LINE_BYTES-2:0], in_window_w};
        sink_r <= in_window_w ^
                  offset_aligned_w ^
                  mapped_way_legal_w ^
                  ^local_addr_w ^
                  ^direct_set_w ^
                  ^direct_way_w ^
                  line_valid_w ^
                  ^read_line_w ^
                  ^write_line_w ^
                  next_valid_bit_w;
    end
endmodule
