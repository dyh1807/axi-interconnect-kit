`timescale 1ns / 1ps

module tb_llc_mapped_window_ctrl;

    reg  [31:0] req_addr;
    reg  [7:0]  req_total_size;
    reg  [31:0] window_offset;
    reg  [255:0] row_data_in;
    reg  [3:0]   valid_bits_in;
    reg  [63:0] write_data_in;
    reg  [7:0]  write_strb_in;

    wire        in_window;
    wire        offset_aligned;
    wire        mapped_way_legal;
    wire [31:0] local_addr;
    wire [1:0]  direct_set;
    wire [1:0]  direct_way;
    wire        line_valid_out;
    wire [63:0] read_line_out;
    wire [63:0] write_line_out;
    wire        next_valid_bit_out;

    llc_mapped_window_ctrl #(
        .ADDR_BITS        (32),
        .LINE_BYTES       (8),
        .LINE_BITS        (64),
        .LINE_OFFSET_BITS (3),
        .SET_COUNT        (4),
        .SET_BITS         (2),
        .WAY_COUNT        (4),
        .WAY_BITS         (2),
        .WINDOW_BYTES     (64),
        .WINDOW_WAYS      (2)
    ) dut (
        .req_addr           (req_addr),
        .req_total_size     (req_total_size),
        .window_offset      (window_offset),
        .row_data_in        (row_data_in),
        .valid_bits_in      (valid_bits_in),
        .write_data_in      (write_data_in),
        .write_strb_in      (write_strb_in),
        .in_window          (in_window),
        .offset_aligned     (offset_aligned),
        .mapped_way_legal   (mapped_way_legal),
        .local_addr         (local_addr),
        .direct_set         (direct_set),
        .direct_way         (direct_way),
        .line_valid_out     (line_valid_out),
        .read_line_out      (read_line_out),
        .write_line_out     (write_line_out),
        .next_valid_bit_out (next_valid_bit_out)
    );

    task expect64;
        input [63:0] got;
        input [63:0] expected;
        begin
            if (got !== expected) begin
                $display("tb_llc_mapped_window_ctrl FAIL: expected=%h got=%h", expected, got);
                $finish;
            end
        end
    endtask

    initial begin
        window_offset = 32'h0000_1000;
        row_data_in   = 256'h0;
        row_data_in[63:0] = 64'h1122_3344_5566_7788;
        write_data_in = 64'hAABB_CCDD_EEFF_0011;
        write_strb_in = 8'h00;
        valid_bits_in = 4'b0000;
        req_addr      = 32'h0000_1008;
        req_total_size = 8'd7;

        #1;
        if (!in_window || !offset_aligned || !mapped_way_legal || !next_valid_bit_out || line_valid_out) begin
            $display("tb_llc_mapped_window_ctrl FAIL: expected in-window aligned direct access");
            $finish;
        end

        if (local_addr !== 32'h0000_0008 || direct_set !== 2'b01 || direct_way !== 2'b00) begin
            $display("tb_llc_mapped_window_ctrl FAIL: bad local mapping");
            $finish;
        end

        #1;
        expect64(read_line_out, 64'h0000_0000_0000_0000);

        write_strb_in = 8'b0000_0011;
        write_data_in = 64'h0000_0000_0000_BBAA;
        #1;
        expect64(write_line_out, 64'h0000_0000_0000_BBAA);

        valid_bits_in = 4'b0001;
        write_strb_in = 8'b0000_0011;
        write_data_in = 64'h0000_0000_0000_BBAA;
        #1;
        expect64(read_line_out, 64'h1122_3344_5566_7788);
        expect64(write_line_out, 64'h1122_3344_5566_BBAA);

        req_addr = 32'h0000_2000;
        #1;
        if (in_window) begin
            $display("tb_llc_mapped_window_ctrl FAIL: expected out-of-window");
            $finish;
        end

        $display("tb_llc_mapped_window_ctrl PASS");
        $finish;
    end

endmodule
