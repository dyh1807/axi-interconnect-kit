`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_axi_cache_multiread_contract;

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
    localparam NUM_READ_MASTERS  = 2;
    localparam NUM_WRITE_MASTERS = 1;
    localparam AXI_ID_BITS       = `AXI_LLC_AXI_ID_BITS;
    localparam AXI_DATA_BYTES    = `AXI_LLC_AXI_DATA_BYTES;
    localparam AXI_DATA_BITS     = `AXI_LLC_AXI_DATA_BITS;
    localparam AXI_STRB_BITS     = `AXI_LLC_AXI_STRB_BITS;
    localparam READ_RESP_BITS    = `AXI_LLC_READ_RESP_BITS;

    localparam [MODE_BITS-1:0] MODE_CACHE = 2'b01;
    localparam [1:0] AXI_BURST_INCR = 2'b01;
    localparam [2:0] AXI_SIZE_32B = 3'd5;
    localparam [1:0] AXI_RESP_OKAY = 2'b00;

    localparam integer MASTER0 = 0;
    localparam integer MASTER1 = 1;
    localparam [ADDR_BITS-1:0] ADDR0 = 32'h0000_0040;
    localparam [ADDR_BITS-1:0] ADDR1 = 32'h0000_0080;
    localparam [ID_BITS-1:0] ID0 = 4'h2;
    localparam [ID_BITS-1:0] ID1 = 4'h6;

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
    reg  [ADDR_BITS-1:0]            ar_addr_log [0:3];
    reg  [AXI_ID_BITS-1:0]          ar_id_log [0:3];
    reg  [AXI_DATA_BITS-1:0]        line0_beat0;
    reg  [AXI_DATA_BITS-1:0]        line0_beat1;
    reg  [AXI_DATA_BITS-1:0]        line1_beat0;
    reg  [AXI_DATA_BITS-1:0]        line1_beat1;
    reg  [LINE_BITS-1:0]            expected_line0;
    reg  [LINE_BITS-1:0]            expected_line1;
    integer                         byte_idx;

    wire [ID_BITS-1:0]             read_resp_id_m0_w;
    wire [ID_BITS-1:0]             read_resp_id_m1_w;
    wire [LINE_BITS-1:0]           read_resp_data_m0_w;
    wire [LINE_BITS-1:0]           read_resp_data_m1_w;

    assign read_resp_id_m0_w =
        read_resp_id[(MASTER0 * ID_BITS) +: ID_BITS];
    assign read_resp_id_m1_w =
        read_resp_id[(MASTER1 * ID_BITS) +: ID_BITS];
    assign read_resp_data_m0_w =
        read_resp_data[(MASTER0 * READ_RESP_BITS) +: LINE_BITS];
    assign read_resp_data_m1_w =
        read_resp_data[(MASTER1 * READ_RESP_BITS) +: LINE_BITS];

    function [LINE_BITS-1:0] assemble_two_beats;
        input [AXI_DATA_BITS-1:0] lo;
        input [AXI_DATA_BITS-1:0] hi;
        begin
            assemble_two_beats = {hi, lo};
        end
    endfunction

    task fail_now;
        input [8*160-1:0] msg;
        begin
            $display("tb_axi_llc_subsystem_axi_cache_multiread_contract FAIL: %0s", msg);
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

    task wait_mode_cache_active;
        integer timeout;
        begin
            timeout = 1000;
            while (((active_mode != MODE_CACHE) || reconfig_busy) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("mode=1 activate timeout");
            end
        end
    endtask

    task issue_cache_read;
        input integer master_idx;
        input [ADDR_BITS-1:0] addr_value;
        input [ID_BITS-1:0] id_value;
        integer timeout;
        begin
            @(negedge clk);
            read_req_valid[master_idx] = 1'b1;
            read_req_addr[(master_idx * ADDR_BITS) +: ADDR_BITS] = addr_value;
            read_req_total_size[(master_idx * 8) +: 8] = LINE_BYTES - 1;
            read_req_id[(master_idx * ID_BITS) +: ID_BITS] = id_value;
            read_req_bypass[master_idx] = 1'b0;
            timeout = 100;
            while ((read_req_accepted[master_idx] !== 1'b1) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("cache read accepted pulse missing");
            end
            @(negedge clk);
            read_req_valid[master_idx] = 1'b0;
        end
    endtask

    task wait_two_ar_before_r;
        integer timeout;
        begin
            timeout = 200;
            while ((ar_count < 2) && (timeout > 0)) begin
                @(posedge clk);
                if (r_count != 0) begin
                    fail_now("R returned before two cache-miss ARs were issued");
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("two cache-miss ARs not observed");
            end
            if (ar_addr_log[0] !== ADDR0) begin
                fail_now("first cache AR address mismatch");
            end
            if (ar_addr_log[1] !== ADDR1) begin
                fail_now("second cache AR address mismatch");
            end
        end
    endtask

    task drive_read_line;
        input [AXI_ID_BITS-1:0] ar_id_value;
        input [AXI_DATA_BITS-1:0] beat0_value;
        input [AXI_DATA_BITS-1:0] beat1_value;
        integer timeout;
        reg     handshake_seen;
        begin
            @(negedge clk);
            axi_rid = ar_id_value;
            axi_rdata = beat0_value;
            axi_rresp = AXI_RESP_OKAY;
            axi_rlast = 1'b0;
            axi_rvalid = 1'b1;
            handshake_seen = 1'b0;
            timeout = 100;
            while ((timeout > 0) && !handshake_seen) begin
                @(posedge clk);
                #1;
                if (axi_rvalid && axi_rready) begin
                    handshake_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("first R beat timeout");
            end

            @(negedge clk);
            axi_rid = ar_id_value;
            axi_rdata = beat1_value;
            axi_rresp = AXI_RESP_OKAY;
            axi_rlast = 1'b1;
            handshake_seen = 1'b0;
            timeout = 100;
            while ((timeout > 0) && !handshake_seen) begin
                @(posedge clk);
                #1;
                if (axi_rvalid && axi_rready) begin
                    handshake_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("second R beat timeout");
            end
            @(negedge clk);
            axi_rvalid = 1'b0;
            axi_rlast = 1'b0;
            axi_rdata = {AXI_DATA_BITS{1'b0}};
        end
    endtask

    task wait_read_response;
        input integer master_idx;
        input [ID_BITS-1:0] expected_id;
        input [LINE_BITS-1:0] expected_line;
        integer timeout;
        begin
            timeout = 100;
            while (!read_resp_valid[master_idx] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("upstream read response timeout");
            end
            if (master_idx == MASTER0) begin
                if (read_resp_id_m0_w !== expected_id) begin
                    fail_now("master0 response id mismatch");
                end
                if (read_resp_data_m0_w !== expected_line) begin
                    fail_now("master0 response line mismatch");
                end
            end else begin
                if (read_resp_id_m1_w !== expected_id) begin
                    fail_now("master1 response id mismatch");
                end
                if (read_resp_data_m1_w !== expected_line) begin
                    fail_now("master1 response line mismatch");
                end
            end
            @(posedge clk);
        end
    endtask

    always #5 clk = ~clk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ar_count <= 0;
            r_count <= 0;
        end else begin
            if (axi_arvalid && axi_arready) begin
                ar_addr_log[ar_count] <= axi_araddr;
                ar_id_log[ar_count] <= axi_arid;
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

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        mode_req = MODE_CACHE;
        llc_mapped_offset_req = {ADDR_BITS{1'b0}};
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
        axi_arready = 1'b1;
        axi_rvalid = 1'b0;
        axi_rid = {AXI_ID_BITS{1'b0}};
        axi_rdata = {AXI_DATA_BITS{1'b0}};
        axi_rresp = AXI_RESP_OKAY;
        axi_rlast = 1'b0;
        invalidate_line_valid = 1'b0;
        invalidate_line_addr = {ADDR_BITS{1'b0}};
        invalidate_all_valid = 1'b0;

        line0_beat0 = {AXI_DATA_BITS{1'b0}};
        line0_beat1 = {AXI_DATA_BITS{1'b0}};
        line1_beat0 = {AXI_DATA_BITS{1'b0}};
        line1_beat1 = {AXI_DATA_BITS{1'b0}};
        for (byte_idx = 0; byte_idx < AXI_DATA_BYTES; byte_idx = byte_idx + 1) begin
            line0_beat0[(byte_idx * 8) +: 8] = 8'h10 + byte_idx[7:0];
            line0_beat1[(byte_idx * 8) +: 8] = 8'h40 + byte_idx[7:0];
            line1_beat0[(byte_idx * 8) +: 8] = 8'h80 + byte_idx[7:0];
            line1_beat1[(byte_idx * 8) +: 8] = 8'hc0 + byte_idx[7:0];
        end
        expected_line0 = assemble_two_beats(line0_beat0, line0_beat1);
        expected_line1 = assemble_two_beats(line1_beat0, line1_beat1);

        wait_cycles(5);
        rst_n = 1'b1;
        wait_mode_cache_active();

        issue_cache_read(MASTER0, ADDR0, ID0);
        issue_cache_read(MASTER1, ADDR1, ID1);
        wait_two_ar_before_r();

        if (axi_awvalid || axi_wvalid || axi_bvalid) begin
            fail_now("cache multiread test unexpectedly drove AXI write channels");
        end
        if (axi_arlen !== 8'd1) begin
            fail_now("cache AR len should remain 2 beats for 64B line");
        end
        if (axi_arsize !== AXI_SIZE_32B) begin
            fail_now("cache AR size should remain 32B");
        end
        if (axi_arburst !== AXI_BURST_INCR) begin
            fail_now("cache AR burst should be INCR");
        end

        drive_read_line(ar_id_log[0], line0_beat0, line0_beat1);
        wait_read_response(MASTER0, ID0, expected_line0);
        drive_read_line(ar_id_log[1], line1_beat0, line1_beat1);
        wait_read_response(MASTER1, ID1, expected_line1);

        if (config_error) begin
            fail_now("config_error asserted unexpectedly");
        end

        $display("tb_axi_llc_subsystem_axi_cache_multiread_contract PASS");
        $finish(0);
    end

endmodule
