`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_axi_mode2_aligned_read_contract;

    localparam ADDR_BITS         = `AXI_LLC_ADDR_BITS;
    localparam ID_BITS           = `AXI_LLC_ID_BITS;
    localparam MODE_BITS         = `AXI_LLC_MODE_BITS;
    localparam LINE_BYTES        = `AXI_LLC_LINE_BYTES;
    localparam LINE_BITS         = `AXI_LLC_LINE_BITS;
    localparam LINE_OFFSET_BITS  = `AXI_LLC_LINE_OFFSET_BITS;
    localparam SET_COUNT         = 4;
    localparam SET_BITS          = 2;
    localparam WAY_COUNT         = 2;
    localparam WAY_BITS          = 1;
    localparam META_BITS         = `AXI_LLC_META_BITS;
    localparam LLC_SIZE_BYTES    = LINE_BYTES * SET_COUNT * WAY_COUNT;
    localparam WINDOW_BYTES      = LINE_BYTES * SET_COUNT;
    localparam WINDOW_WAYS       = 1;
    localparam NUM_READ_MASTERS  = 1;
    localparam NUM_WRITE_MASTERS = 1;
    localparam AXI_ID_BITS       = `AXI_LLC_AXI_ID_BITS;
    localparam AXI_DATA_BYTES    = `AXI_LLC_AXI_DATA_BYTES;
    localparam AXI_DATA_BITS     = `AXI_LLC_AXI_DATA_BITS;
    localparam AXI_STRB_BITS     = `AXI_LLC_AXI_STRB_BITS;
    localparam READ_RESP_BITS    = `AXI_LLC_READ_RESP_BITS;
    localparam MMIO_BASE         = `AXI_LLC_MMIO_BASE;

    localparam [MODE_BITS-1:0] MODE_MAPPED = 2'b10;
    localparam [2:0] AXI_SIZE_32B = 3'd5;
    localparam [1:0] AXI_BURST_INCR = 2'b01;
    localparam [ADDR_BITS-1:0] WINDOW_OFFSET = 32'h0000_1000;
    localparam [ADDR_BITS-1:0] DDR_SMALL_ADDR = 32'h0000_200C;
    localparam [ADDR_BITS-1:0] DDR_CROSS_ADDR = 32'h0000_201C;
    localparam [ADDR_BITS-1:0] DDR_SMALL_ALIGN = 32'h0000_2000;
    localparam [ADDR_BITS-1:0] DDR_LINE_ALIGN = 32'h0000_2000;
    localparam [ADDR_BITS-1:0] MMIO_READ_ADDR = MMIO_BASE + 32'h0000_000C;
    localparam [ADDR_BITS-1:0] MMIO_CROSS_READ_ADDR =
        MMIO_BASE + `AXI_LLC_MMIO_SIZE - 32'h0000_0004;

    reg                             clk;
    reg                             rst_n;
    reg  [MODE_BITS-1:0]            mode_req;
    reg  [ADDR_BITS-1:0]            llc_mapped_offset_req;
    reg  [NUM_READ_MASTERS-1:0]     read_req_valid;
    wire [NUM_READ_MASTERS-1:0]     read_req_ready;
    wire [NUM_READ_MASTERS-1:0]     read_req_accepted;
    wire [NUM_READ_MASTERS*ID_BITS-1:0] read_req_accepted_id;
    reg  [NUM_READ_MASTERS*ADDR_BITS-1:0] read_req_addr;
    reg  [NUM_READ_MASTERS*8-1:0]   read_req_total_size;
    reg  [NUM_READ_MASTERS*ID_BITS-1:0] read_req_id;
    reg  [NUM_READ_MASTERS-1:0]     read_req_bypass;
    wire [NUM_READ_MASTERS-1:0]     read_resp_valid;
    reg  [NUM_READ_MASTERS-1:0]     read_resp_ready;
    wire [NUM_READ_MASTERS*READ_RESP_BITS-1:0] read_resp_data;
    wire [NUM_READ_MASTERS*ID_BITS-1:0] read_resp_id;
    reg  [NUM_WRITE_MASTERS-1:0]    write_req_valid;
    wire [NUM_WRITE_MASTERS-1:0]    write_req_ready;
    wire [NUM_WRITE_MASTERS-1:0]    write_req_accepted;
    reg  [NUM_WRITE_MASTERS*ADDR_BITS-1:0] write_req_addr;
    reg  [NUM_WRITE_MASTERS*LINE_BITS-1:0] write_req_wdata;
    reg  [NUM_WRITE_MASTERS*LINE_BYTES-1:0] write_req_wstrb;
    reg  [NUM_WRITE_MASTERS*8-1:0]  write_req_total_size;
    reg  [NUM_WRITE_MASTERS*ID_BITS-1:0] write_req_id;
    reg  [NUM_WRITE_MASTERS-1:0]    write_req_bypass;
    wire [NUM_WRITE_MASTERS-1:0]    write_resp_valid;
    reg  [NUM_WRITE_MASTERS-1:0]    write_resp_ready;
    wire [NUM_WRITE_MASTERS*ID_BITS-1:0] write_resp_id;
    wire [NUM_WRITE_MASTERS*2-1:0]  write_resp_code;

    wire                            axi_awvalid;
    reg                             axi_awready;
    wire [AXI_ID_BITS-1:0]          axi_awid;
    wire [ADDR_BITS-1:0]            axi_awaddr;
    wire [7:0]                      axi_awlen;
    wire [2:0]                      axi_awsize;
    wire [1:0]                      axi_awburst;
    wire                            axi_wvalid;
    reg                             axi_wready;
    wire [AXI_DATA_BITS-1:0]        axi_wdata;
    wire [AXI_STRB_BITS-1:0]        axi_wstrb;
    wire                            axi_wlast;
    reg                             axi_bvalid;
    wire                            axi_bready;
    reg  [AXI_ID_BITS-1:0]          axi_bid;
    reg  [1:0]                      axi_bresp;
    wire                            axi_arvalid;
    reg                             axi_arready;
    wire [AXI_ID_BITS-1:0]          axi_arid;
    wire [ADDR_BITS-1:0]            axi_araddr;
    wire [7:0]                      axi_arlen;
    wire [2:0]                      axi_arsize;
    wire [1:0]                      axi_arburst;
    reg                             axi_rvalid;
    wire                            axi_rready;
    reg  [AXI_ID_BITS-1:0]          axi_rid;
    reg  [AXI_DATA_BITS-1:0]        axi_rdata;
    reg  [1:0]                      axi_rresp;
    reg                             axi_rlast;

    reg                             invalidate_line_valid;
    reg  [ADDR_BITS-1:0]            invalidate_line_addr;
    wire                            invalidate_line_accepted;
    reg                             invalidate_all_valid;
    wire                            invalidate_all_accepted;
    wire [MODE_BITS-1:0]            active_mode;
    wire [ADDR_BITS-1:0]            active_offset;
    wire                            reconfig_busy;
    wire [1:0]                      reconfig_state;
    wire                            config_error;

    integer                         ar_count;
    integer                         r_count;
    reg  [AXI_ID_BITS-1:0]          seen_arid;
    reg  [31:0]                     expected_word0;
    reg  [31:0]                     expected_word1;

    wire [ID_BITS-1:0]              read_accept_id_w;
    wire [ID_BITS-1:0]              read_resp_id_w;

    assign read_accept_id_w = read_req_accepted_id[ID_BITS-1:0];
    assign read_resp_id_w = read_resp_id[ID_BITS-1:0];

    always #5 clk = ~clk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ar_count <= 0;
            r_count <= 0;
        end else begin
            if (axi_arvalid && axi_arready) begin
                ar_count <= ar_count + 1;
            end
            if (axi_rvalid && axi_rready) begin
                r_count <= r_count + 1;
            end
        end
    end

    axi_llc_subsystem #(
        .ADDR_BITS         (ADDR_BITS),
        .ID_BITS           (ID_BITS),
        .MODE_BITS         (MODE_BITS),
        .LINE_BYTES        (LINE_BYTES),
        .LINE_BITS         (LINE_BITS),
        .LINE_OFFSET_BITS  (LINE_OFFSET_BITS),
        .SET_COUNT         (SET_COUNT),
        .SET_BITS          (SET_BITS),
        .WAY_COUNT         (WAY_COUNT),
        .WAY_BITS          (WAY_BITS),
        .META_BITS         (META_BITS),
        .LLC_SIZE_BYTES    (LLC_SIZE_BYTES),
        .WINDOW_BYTES      (WINDOW_BYTES),
        .WINDOW_WAYS       (WINDOW_WAYS),
        .NUM_READ_MASTERS  (NUM_READ_MASTERS),
        .NUM_WRITE_MASTERS (NUM_WRITE_MASTERS),
        .AXI_ID_BITS       (AXI_ID_BITS),
        .AXI_DATA_BYTES    (AXI_DATA_BYTES),
        .AXI_DATA_BITS     (AXI_DATA_BITS),
        .AXI_STRB_BITS     (AXI_STRB_BITS),
        .READ_RESP_BITS    (READ_RESP_BITS)
    ) dut (
        .clk                   (clk),
        .rst_n                 (rst_n),
        .mode_req              (mode_req),
        .llc_mapped_offset_req (llc_mapped_offset_req),
        .read_req_valid        (read_req_valid),
        .read_req_ready        (read_req_ready),
        .read_req_accepted     (read_req_accepted),
        .read_req_accepted_id  (read_req_accepted_id),
        .read_req_addr         (read_req_addr),
        .read_req_total_size   (read_req_total_size),
        .read_req_id           (read_req_id),
        .read_req_bypass       (read_req_bypass),
        .read_resp_valid       (read_resp_valid),
        .read_resp_ready       (read_resp_ready),
        .read_resp_data        (read_resp_data),
        .read_resp_id          (read_resp_id),
        .write_req_valid       (write_req_valid),
        .write_req_ready       (write_req_ready),
        .write_req_accepted    (write_req_accepted),
        .write_req_addr        (write_req_addr),
        .write_req_wdata       (write_req_wdata),
        .write_req_wstrb       (write_req_wstrb),
        .write_req_total_size  (write_req_total_size),
        .write_req_id          (write_req_id),
        .write_req_bypass      (write_req_bypass),
        .write_resp_valid      (write_resp_valid),
        .write_resp_ready      (write_resp_ready),
        .write_resp_id         (write_resp_id),
        .write_resp_code       (write_resp_code),
        .axi_awvalid           (axi_awvalid),
        .axi_awready           (axi_awready),
        .axi_awid              (axi_awid),
        .axi_awaddr            (axi_awaddr),
        .axi_awlen             (axi_awlen),
        .axi_awsize            (axi_awsize),
        .axi_awburst           (axi_awburst),
        .axi_wvalid            (axi_wvalid),
        .axi_wready            (axi_wready),
        .axi_wdata             (axi_wdata),
        .axi_wstrb             (axi_wstrb),
        .axi_wlast             (axi_wlast),
        .axi_bvalid            (axi_bvalid),
        .axi_bready            (axi_bready),
        .axi_bid               (axi_bid),
        .axi_bresp             (axi_bresp),
        .axi_arvalid           (axi_arvalid),
        .axi_arready           (axi_arready),
        .axi_arid              (axi_arid),
        .axi_araddr            (axi_araddr),
        .axi_arlen             (axi_arlen),
        .axi_arsize            (axi_arsize),
        .axi_arburst           (axi_arburst),
        .axi_rvalid            (axi_rvalid),
        .axi_rready            (axi_rready),
        .axi_rid               (axi_rid),
        .axi_rdata             (axi_rdata),
        .axi_rresp             (axi_rresp),
        .axi_rlast             (axi_rlast),
        .invalidate_line_valid (invalidate_line_valid),
        .invalidate_line_addr  (invalidate_line_addr),
        .invalidate_line_accepted(invalidate_line_accepted),
        .invalidate_all_valid  (invalidate_all_valid),
        .invalidate_all_accepted(invalidate_all_accepted),
        .active_mode           (active_mode),
        .active_offset         (active_offset),
        .reconfig_busy         (reconfig_busy),
        .reconfig_state        (reconfig_state),
        .config_error          (config_error)
    );

    task fail_now;
        input [8*160-1:0] msg;
        begin
            $display("tb_axi_llc_subsystem_axi_mode2_aligned_read_contract FAIL: %0s", msg);
            $finish(1);
        end
    endtask

    task wait_cycles;
        input integer cycles;
        integer idx;
        begin
            for (idx = 0; idx < cycles; idx = idx + 1) begin
                @(posedge clk);
            end
        end
    endtask

    task wait_mode_mapped_active;
        integer timeout;
        begin
            timeout = 1000;
            while (((active_mode != MODE_MAPPED) ||
                    (active_offset != WINDOW_OFFSET) ||
                    reconfig_busy) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("mode=2 activate timeout");
            end
        end
    endtask

    task issue_read;
        input [ADDR_BITS-1:0] req_addr;
        input [7:0]           req_size;
        input [ID_BITS-1:0]   req_id_value;
        integer timeout;
        begin
            read_req_addr[ADDR_BITS-1:0] = req_addr;
            read_req_total_size[7:0] = req_size;
            read_req_id[ID_BITS-1:0] = req_id_value;
            read_req_bypass[0] = 1'b0;
            read_req_valid[0] = 1'b1;
            timeout = 100;
            while (timeout > 0) begin
                @(posedge clk);
                if (read_req_valid[0] && read_req_ready[0]) begin
                    timeout = 0;
                end else begin
                    timeout = timeout - 1;
                end
            end
            if (!(read_req_valid[0] && read_req_ready[0])) begin
                fail_now("mode2 read request handshake timeout");
            end
            #1;
            if (!read_req_accepted[0]) begin
                fail_now("mode2 read accepted pulse missing");
            end
            if (read_accept_id_w !== req_id_value) begin
                fail_now("mode2 read accepted_id mismatch");
            end
            read_req_valid[0] = 1'b0;
            @(negedge clk);
        end
    endtask

    task expect_ar;
        input [ADDR_BITS-1:0] exp_addr;
        input [7:0]           exp_len;
        integer timeout;
        begin
            timeout = 100;
            while (!axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("mode2 read AR timeout");
            end
            if (axi_araddr !== exp_addr) begin
                fail_now("mode2 read AR address mismatch");
            end
            if (axi_arlen !== exp_len) begin
                fail_now("mode2 read AR length mismatch");
            end
            if (axi_arsize !== AXI_SIZE_32B) begin
                fail_now("mode2 read AR size mismatch");
            end
            if (axi_arburst !== AXI_BURST_INCR) begin
                fail_now("mode2 read burst must be INCR");
            end
            if (axi_awvalid || axi_wvalid) begin
                fail_now("mode2 read unexpectedly drove write channels");
            end
            seen_arid = axi_arid;
            axi_arready = 1'b1;
            @(posedge clk);
            axi_arready = 1'b0;
        end
    endtask

    task drive_r_beat_pattern;
        input [31:0] base_word;
        input [31:0] word_bias;
        input        last_value;
        integer lane;
        integer start_r_count;
        begin
            @(negedge clk);
            axi_rdata = {AXI_DATA_BITS{1'b0}};
            for (lane = 0; lane < (AXI_DATA_BYTES / 4); lane = lane + 1) begin
                axi_rdata[(lane * 32) +: 32] = base_word + word_bias + lane;
            end
            axi_rid = seen_arid;
            axi_rresp = 2'b00;
            axi_rlast = last_value;
            start_r_count = r_count;
            axi_rvalid = 1'b1;
            @(posedge clk);
            if (!axi_rready) begin
                fail_now("mode2 read beat ready was low on driven cycle");
            end
            #1;
            axi_rvalid = 1'b0;
            axi_rlast = 1'b0;
            if (r_count != (start_r_count + 1)) begin
                fail_now("mode2 read beat should handshake exactly once");
            end
        end
    endtask

    task drive_single_r_pattern;
        input [31:0] base_word;
        begin
            drive_r_beat_pattern(base_word, 32'd0, 1'b1);
        end
    endtask

    task drive_two_r_pattern;
        input [31:0] base_word;
        begin
            drive_r_beat_pattern(base_word, 32'd0, 1'b0);
            drive_r_beat_pattern(base_word, AXI_DATA_BYTES / 4, 1'b1);
        end
    endtask

    task wait_read_resp_words;
        input [ID_BITS-1:0] exp_id;
        input integer       word_count;
        integer timeout;
        begin
            timeout = 100;
            while (!read_resp_valid[0] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("mode2 read response timeout");
            end
            if (read_resp_id_w !== exp_id) begin
                fail_now("mode2 read response id mismatch");
            end
            if (read_resp_data[31:0] !== expected_word0) begin
                $display("DBG mode2 read low word actual=%h expected=%h",
                         read_resp_data[31:0], expected_word0);
                fail_now("mode2 read response low word mismatch");
            end
            if ((word_count > 1) &&
                (read_resp_data[63:32] !== expected_word1)) begin
                $display("DBG mode2 read high word actual=%h expected=%h",
                         read_resp_data[63:32], expected_word1);
                fail_now("mode2 read response second word mismatch");
            end
            @(posedge clk);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        mode_req = MODE_MAPPED;
        llc_mapped_offset_req = WINDOW_OFFSET;
        read_req_valid = {NUM_READ_MASTERS{1'b0}};
        read_req_addr = {(NUM_READ_MASTERS*ADDR_BITS){1'b0}};
        read_req_total_size = {(NUM_READ_MASTERS*8){1'b0}};
        read_req_id = {(NUM_READ_MASTERS*ID_BITS){1'b0}};
        read_req_bypass = {NUM_READ_MASTERS{1'b0}};
        read_resp_ready = {NUM_READ_MASTERS{1'b1}};
        write_req_valid = {NUM_WRITE_MASTERS{1'b0}};
        write_req_addr = {(NUM_WRITE_MASTERS*ADDR_BITS){1'b0}};
        write_req_wdata = {(NUM_WRITE_MASTERS*LINE_BITS){1'b0}};
        write_req_wstrb = {(NUM_WRITE_MASTERS*LINE_BYTES){1'b0}};
        write_req_total_size = {(NUM_WRITE_MASTERS*8){1'b0}};
        write_req_id = {(NUM_WRITE_MASTERS*ID_BITS){1'b0}};
        write_req_bypass = {NUM_WRITE_MASTERS{1'b0}};
        write_resp_ready = {NUM_WRITE_MASTERS{1'b1}};
        axi_awready = 1'b0;
        axi_wready = 1'b0;
        axi_bvalid = 1'b0;
        axi_bid = {AXI_ID_BITS{1'b0}};
        axi_bresp = 2'b00;
        axi_arready = 1'b0;
        axi_rvalid = 1'b0;
        axi_rid = {AXI_ID_BITS{1'b0}};
        axi_rdata = {AXI_DATA_BITS{1'b0}};
        axi_rresp = 2'b00;
        axi_rlast = 1'b0;
        invalidate_line_valid = 1'b0;
        invalidate_line_addr = {ADDR_BITS{1'b0}};
        invalidate_all_valid = 1'b0;
        expected_word0 = 32'd0;
        expected_word1 = 32'd0;

        wait_cycles(5);
        rst_n = 1'b1;
        wait_mode_mapped_active();

        issue_read(DDR_SMALL_ADDR, 8'd3, 4'h1);
        expect_ar(DDR_SMALL_ALIGN, 8'd0);
        expected_word0 = 32'h0000_A203;
        drive_single_r_pattern(32'h0000_A200);
        wait_read_resp_words(4'h1, 1);

        issue_read(DDR_CROSS_ADDR, 8'd7, 4'h2);
        expect_ar(DDR_LINE_ALIGN, 8'd1);
        expected_word0 = 32'h0000_C207;
        expected_word1 = 32'h0000_C208;
        drive_two_r_pattern(32'h0000_C200);
        wait_read_resp_words(4'h2, 2);

        issue_read(MMIO_READ_ADDR, 8'd3, 4'h3);
        expect_ar(MMIO_READ_ADDR, 8'd0);
        expected_word0 = 32'h0000_D300;
        drive_single_r_pattern(32'h0000_D300);
        wait_read_resp_words(4'h3, 1);

        issue_read(MMIO_CROSS_READ_ADDR, 8'd7, 4'h4);
        expect_ar(MMIO_CROSS_READ_ADDR, 8'd0);
        expected_word0 = 32'h0000_E400;
        expected_word1 = 32'h0000_E401;
        drive_single_r_pattern(32'h0000_E400);
        wait_read_resp_words(4'h4, 2);

        if (ar_count !== 4) begin
            fail_now("mode2 aligned read bench expected exactly four AR handshakes");
        end
        if (r_count !== 5) begin
            fail_now("mode2 aligned read bench expected five R handshakes");
        end
        if (config_error) begin
            fail_now("config_error asserted unexpectedly");
        end

        $display("tb_axi_llc_subsystem_axi_mode2_aligned_read_contract PASS");
        $finish(0);
    end

endmodule
