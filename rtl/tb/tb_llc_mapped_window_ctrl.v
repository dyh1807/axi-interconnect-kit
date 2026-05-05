`timescale 1ns / 1ps

module tb_llc_mapped_window_ctrl;

    localparam PROD_LINE_BYTES   = 64;
    localparam PROD_LINE_BITS    = 512;
    localparam PROD_SET_BITS     = 16;
    localparam PROD_WAY_COUNT    = 2;
    localparam PROD_WAY_BITS     = 1;
    localparam PROD_WINDOW_BYTES = 32'h0040_0000;

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

    reg  [31:0] prod_req_addr;
    reg  [7:0]  prod_req_total_size;
    reg  [31:0] prod_window_offset;
    reg  [PROD_WAY_COUNT*PROD_LINE_BITS-1:0] prod_row_data_in;
    reg  [PROD_WAY_COUNT-1:0]                prod_valid_bits_in;
    reg  [PROD_LINE_BITS-1:0]                prod_write_data_in;
    reg  [PROD_LINE_BYTES-1:0]               prod_write_strb_in;

    wire                         prod_in_window;
    wire                         prod_offset_aligned;
    wire                         prod_mapped_way_legal;
    wire [31:0]                  prod_local_addr;
    wire [PROD_SET_BITS-1:0]     prod_direct_set;
    wire [PROD_WAY_BITS-1:0]     prod_direct_way;
    wire                         prod_line_valid_out;
    wire [PROD_LINE_BITS-1:0]    prod_read_line_out;
    wire [PROD_LINE_BITS-1:0]    prod_write_line_out;
    wire                         prod_next_valid_bit_out;

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

    llc_mapped_window_ctrl #(
        .ADDR_BITS        (32),
        .LINE_BYTES       (PROD_LINE_BYTES),
        .LINE_BITS        (PROD_LINE_BITS),
        .LINE_OFFSET_BITS (6),
        .SET_COUNT        (65536),
        .SET_BITS         (PROD_SET_BITS),
        .WAY_COUNT        (PROD_WAY_COUNT),
        .WAY_BITS         (PROD_WAY_BITS),
        .WINDOW_BYTES     (PROD_WINDOW_BYTES),
        .WINDOW_WAYS      (1)
    ) prod_dut (
        .req_addr           (prod_req_addr),
        .req_total_size     (prod_req_total_size),
        .window_offset      (prod_window_offset),
        .row_data_in        (prod_row_data_in),
        .valid_bits_in      (prod_valid_bits_in),
        .write_data_in      (prod_write_data_in),
        .write_strb_in      (prod_write_strb_in),
        .in_window          (prod_in_window),
        .offset_aligned     (prod_offset_aligned),
        .mapped_way_legal   (prod_mapped_way_legal),
        .local_addr         (prod_local_addr),
        .direct_set         (prod_direct_set),
        .direct_way         (prod_direct_way),
        .line_valid_out     (prod_line_valid_out),
        .read_line_out      (prod_read_line_out),
        .write_line_out     (prod_write_line_out),
        .next_valid_bit_out (prod_next_valid_bit_out)
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

        prod_window_offset = 32'h3000_0000;
        prod_row_data_in = {(PROD_WAY_COUNT*PROD_LINE_BITS){1'b0}};
        prod_row_data_in[511:480] = 32'h1122_3344;
        prod_valid_bits_in = 2'b01;
        prod_write_data_in = {PROD_LINE_BITS{1'b0}};
        prod_write_data_in[31:0] = 32'hA5C3_5A3C;
        prod_write_strb_in = {PROD_LINE_BYTES{1'b0}};
        prod_req_addr = 32'h3000_0000;
        prod_req_total_size = 8'd3;

        #1;
        if (!prod_in_window || !prod_offset_aligned ||
            !prod_mapped_way_legal || prod_local_addr !== 32'h0000_0000 ||
            prod_direct_set !== 16'h0000 || prod_direct_way !== 1'b0) begin
            $display("tb_llc_mapped_window_ctrl FAIL: bad production window low boundary");
            $finish;
        end

        prod_req_addr = 32'h303f_fffc;
        prod_req_total_size = 8'd3;
        prod_write_strb_in = 64'h0000_0000_0000_000f;
        #1;
        if (!prod_in_window || !prod_offset_aligned ||
            !prod_mapped_way_legal || !prod_line_valid_out ||
            !prod_next_valid_bit_out ||
            prod_local_addr !== 32'h003f_fffc ||
            prod_direct_set !== 16'hffff || prod_direct_way !== 1'b0 ||
            prod_read_line_out[511:480] !== 32'h1122_3344 ||
            prod_write_line_out[511:480] !== 32'hA5C3_5A3C) begin
            $display("tb_llc_mapped_window_ctrl FAIL: bad production window high boundary");
            $finish;
        end

        prod_req_total_size = 8'd7;
        #1;
        if (prod_in_window) begin
            $display("tb_llc_mapped_window_ctrl FAIL: expected production high cross-boundary reject");
            $finish;
        end

        prod_req_addr = 32'h3040_0000;
        prod_req_total_size = 8'd3;
        #1;
        if (prod_in_window) begin
            $display("tb_llc_mapped_window_ctrl FAIL: expected production above-window reject");
            $finish;
        end

        prod_req_addr = 32'h2fff_fffc;
        #1;
        if (prod_in_window) begin
            $display("tb_llc_mapped_window_ctrl FAIL: expected production below-window reject");
            $finish;
        end

        $display("tb_llc_mapped_window_ctrl PASS");
        $finish;
    end

endmodule
