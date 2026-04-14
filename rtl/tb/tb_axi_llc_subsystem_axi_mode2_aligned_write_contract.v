`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_axi_mode2_aligned_write_contract;

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
    localparam [1:0] AXI_RESP_OKAY = 2'b00;
    localparam [ADDR_BITS-1:0] WINDOW_OFFSET = 32'h0000_1000;
    localparam [ADDR_BITS-1:0] DDR_SMALL_ADDR = 32'h0000_2008;
    localparam [ADDR_BITS-1:0] DDR_CROSS_ADDR = 32'h0000_201C;
    localparam [ADDR_BITS-1:0] DDR_SMALL_ALIGN = 32'h0000_2000;
    localparam [ADDR_BITS-1:0] DDR_LINE_ALIGN = 32'h0000_2000;
    localparam [ADDR_BITS-1:0] MMIO_WRITE_ADDR = MMIO_BASE + 32'h0000_0004;
    localparam [ADDR_BITS-1:0] MMIO_CROSS_WRITE_ADDR =
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

    integer                         aw_count;
    integer                         w_count;
    integer                         b_count;
    reg  [AXI_ID_BITS-1:0]          seen_awid;
    reg  [AXI_DATA_BITS-1:0]        expected_wdata0;
    reg  [AXI_STRB_BITS-1:0]        expected_wstrb0;
    reg  [AXI_DATA_BITS-1:0]        expected_wdata1;
    reg  [AXI_STRB_BITS-1:0]        expected_wstrb1;

    wire [ID_BITS-1:0]              write_resp_id_w;
    wire [1:0]                      write_resp_code_w;

    assign write_resp_id_w = write_resp_id[ID_BITS-1:0];
    assign write_resp_code_w = write_resp_code[1:0];

    always #5 clk = ~clk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_count <= 0;
            w_count <= 0;
            b_count <= 0;
        end else begin
            if (axi_awvalid && axi_awready) begin
                aw_count <= aw_count + 1;
            end
            if (axi_wvalid && axi_wready) begin
                w_count <= w_count + 1;
            end
            if (axi_bvalid && axi_bready) begin
                b_count <= b_count + 1;
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
            $display("tb_axi_llc_subsystem_axi_mode2_aligned_write_contract FAIL: %0s", msg);
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

    task issue_write;
        input [ADDR_BITS-1:0] req_addr;
        input [7:0]           req_size;
        input [ID_BITS-1:0]   req_id_value;
        input [63:0]          req_data;
        input [7:0]           req_strb;
        integer timeout;
        begin
            write_req_addr[ADDR_BITS-1:0] = req_addr;
            write_req_total_size[7:0] = req_size;
            write_req_id[ID_BITS-1:0] = req_id_value;
            write_req_bypass[0] = 1'b0;
            write_req_wdata = {LINE_BITS{1'b0}};
            write_req_wstrb = {LINE_BYTES{1'b0}};
            write_req_wdata[63:0] = req_data;
            write_req_wstrb[7:0] = req_strb;
            write_req_valid[0] = 1'b1;
            timeout = 100;
            while (timeout > 0) begin
                @(posedge clk);
                if (write_req_valid[0] && write_req_ready[0]) begin
                    timeout = 0;
                end else begin
                    timeout = timeout - 1;
                end
            end
            if (!(write_req_valid[0] && write_req_ready[0])) begin
                fail_now("mode2 write request handshake timeout");
            end
            #1;
            if (!write_req_accepted[0]) begin
                fail_now("mode2 write accepted pulse missing");
            end
            write_req_valid[0] = 1'b0;
            @(negedge clk);
        end
    endtask

    task expect_aw;
        input [ADDR_BITS-1:0] exp_addr;
        input [7:0]           exp_len;
        integer timeout;
        begin
            timeout = 100;
            while (!axi_awvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("mode2 write AW timeout");
            end
            if (axi_awaddr !== exp_addr) begin
                fail_now("mode2 write AW address mismatch");
            end
            if (axi_awlen !== exp_len) begin
                fail_now("mode2 write AW length mismatch");
            end
            if (axi_awsize !== AXI_SIZE_32B) begin
                fail_now("mode2 write AW size mismatch");
            end
            if (axi_awburst !== AXI_BURST_INCR) begin
                fail_now("mode2 write burst must be INCR");
            end
            seen_awid = axi_awid;
            axi_awready = 1'b1;
            @(posedge clk);
            axi_awready = 1'b0;
        end
    endtask

    task expect_w_beat;
        input [AXI_DATA_BITS-1:0] exp_wdata;
        input [AXI_STRB_BITS-1:0] exp_wstrb;
        input                     exp_last;
        integer timeout;
        begin
            timeout = 100;
            while (!axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("mode2 write W timeout");
            end
            if (axi_wdata !== exp_wdata) begin
                fail_now("mode2 write WDATA mismatch");
            end
            if (axi_wstrb !== exp_wstrb) begin
                fail_now("mode2 write WSTRB mismatch");
            end
            if (axi_wlast !== exp_last) begin
                fail_now("mode2 write WLAST mismatch");
            end
            axi_wready = 1'b1;
            @(posedge clk);
            axi_wready = 1'b0;
        end
    endtask

    task drive_b_resp;
        integer start_b_count;
        begin
            @(negedge clk);
            axi_bid = seen_awid;
            axi_bresp = AXI_RESP_OKAY;
            start_b_count = b_count;
            axi_bvalid = 1'b1;
            @(posedge clk);
            if (!axi_bready) begin
                fail_now("mode2 write B ready was low on driven cycle");
            end
            #1;
            axi_bvalid = 1'b0;
            if (b_count != (start_b_count + 1)) begin
                fail_now("mode2 write B should handshake exactly once");
            end
        end
    endtask

    task wait_write_resp;
        input [ID_BITS-1:0] exp_id;
        integer timeout;
        begin
            timeout = 100;
            while (!write_resp_valid[0] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("mode2 write response timeout");
            end
            if (write_resp_id_w !== exp_id) begin
                fail_now("mode2 write response id mismatch");
            end
            if (write_resp_code_w !== AXI_RESP_OKAY) begin
                fail_now("mode2 write response code mismatch");
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
        axi_bresp = AXI_RESP_OKAY;
        axi_arready = 1'b0;
        axi_rvalid = 1'b0;
        axi_rid = {AXI_ID_BITS{1'b0}};
        axi_rdata = {AXI_DATA_BITS{1'b0}};
        axi_rresp = 2'b00;
        axi_rlast = 1'b0;
        invalidate_line_valid = 1'b0;
        invalidate_line_addr = {ADDR_BITS{1'b0}};
        invalidate_all_valid = 1'b0;
        expected_wdata0 = {AXI_DATA_BITS{1'b0}};
        expected_wstrb0 = {AXI_STRB_BITS{1'b0}};
        expected_wdata1 = {AXI_DATA_BITS{1'b0}};
        expected_wstrb1 = {AXI_STRB_BITS{1'b0}};

        wait_cycles(5);
        rst_n = 1'b1;
        wait_mode_mapped_active();

        expected_wdata0 = {AXI_DATA_BITS{1'b0}};
        expected_wstrb0 = {AXI_STRB_BITS{1'b0}};
        expected_wdata0[95:64] = 32'hDEAD_BEEF;
        expected_wstrb0[11:8] = 4'hF;
        issue_write(DDR_SMALL_ADDR, 8'd3, 4'h1, 64'h0000_0000_DEAD_BEEF, 8'h0F);
        expect_aw(DDR_SMALL_ALIGN, 8'd0);
        expect_w_beat(expected_wdata0, expected_wstrb0, 1'b1);
        drive_b_resp();
        wait_write_resp(4'h1);

        expected_wdata0 = {AXI_DATA_BITS{1'b0}};
        expected_wstrb0 = {AXI_STRB_BITS{1'b0}};
        expected_wdata1 = {AXI_DATA_BITS{1'b0}};
        expected_wstrb1 = {AXI_STRB_BITS{1'b0}};
        expected_wdata0[255:224] = 32'h1122_3344;
        expected_wstrb0[31:28] = 4'hF;
        expected_wdata1[31:0] = 32'h5566_7788;
        expected_wstrb1[3:0] = 4'hF;
        issue_write(DDR_CROSS_ADDR, 8'd7, 4'h2, 64'h5566_7788_1122_3344, 8'hFF);
        expect_aw(DDR_LINE_ALIGN, 8'd1);
        expect_w_beat(expected_wdata0, expected_wstrb0, 1'b0);
        expect_w_beat(expected_wdata1, expected_wstrb1, 1'b1);
        drive_b_resp();
        wait_write_resp(4'h2);

        expected_wdata0 = {AXI_DATA_BITS{1'b0}};
        expected_wstrb0 = {AXI_STRB_BITS{1'b0}};
        expected_wdata0[31:0] = 32'hCAFE_BABE;
        expected_wstrb0[3:0] = 4'hF;
        issue_write(MMIO_WRITE_ADDR, 8'd3, 4'h3, 64'h0000_0000_CAFE_BABE, 8'h0F);
        expect_aw(MMIO_WRITE_ADDR, 8'd0);
        expect_w_beat(expected_wdata0, expected_wstrb0, 1'b1);
        drive_b_resp();
        wait_write_resp(4'h3);

        expected_wdata0 = {AXI_DATA_BITS{1'b0}};
        expected_wstrb0 = {AXI_STRB_BITS{1'b0}};
        expected_wdata0[63:0] = 64'h8899_AABB_CCDD_EEFF;
        expected_wstrb0[7:0] = 8'hFF;
        issue_write(MMIO_CROSS_WRITE_ADDR, 8'd7, 4'h4,
                    64'h8899_AABB_CCDD_EEFF, 8'hFF);
        expect_aw(MMIO_CROSS_WRITE_ADDR, 8'd0);
        expect_w_beat(expected_wdata0, expected_wstrb0, 1'b1);
        drive_b_resp();
        wait_write_resp(4'h4);

        if (aw_count !== 4) begin
            $display("DBG mode2 write counts aw=%0d w=%0d b=%0d",
                     aw_count, w_count, b_count);
            fail_now("mode2 aligned write bench expected exactly four AW handshakes");
        end
        if (w_count !== 5) begin
            $display("DBG mode2 write counts aw=%0d w=%0d b=%0d",
                     aw_count, w_count, b_count);
            fail_now("mode2 aligned write bench expected five W handshakes");
        end
        if (b_count !== 4) begin
            $display("DBG mode2 write counts aw=%0d w=%0d b=%0d",
                     aw_count, w_count, b_count);
            fail_now("mode2 aligned write bench expected four B handshakes");
        end
        if (config_error) begin
            fail_now("config_error asserted unexpectedly");
        end

        $display("tb_axi_llc_subsystem_axi_mode2_aligned_write_contract PASS");
        $finish(0);
    end

endmodule
