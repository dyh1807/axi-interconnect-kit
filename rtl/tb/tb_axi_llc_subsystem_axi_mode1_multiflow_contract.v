`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_axi_mode1_multiflow_contract;

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
    localparam NUM_WRITE_MASTERS = 2;
    localparam AXI_ID_BITS       = `AXI_LLC_AXI_ID_BITS;
    localparam AXI_DATA_BYTES    = `AXI_LLC_AXI_DATA_BYTES;
    localparam AXI_DATA_BITS     = `AXI_LLC_AXI_DATA_BITS;
    localparam AXI_STRB_BITS     = `AXI_LLC_AXI_STRB_BITS;
    localparam READ_RESP_BITS    = `AXI_LLC_READ_RESP_BITS;

    localparam [MODE_BITS-1:0] MODE_CACHE = 2'b01;
    localparam [1:0] AXI_BURST_INCR = 2'b01;
    localparam [2:0] AXI_SIZE_32B = 3'd5;
    localparam [1:0] AXI_RESP_OKAY = 2'b00;
    localparam [1:0] AXI_RESP_SLVERR = 2'b10;

    localparam integer CACHE_MASTER = 0;
    localparam integer BYPASS_READ_MASTER = 1;
    localparam integer BYPASS_WRITE_MASTER = 1;

    localparam [ADDR_BITS-1:0] CACHE_ADDR = 32'h0000_0040;
    localparam [ADDR_BITS-1:0] BYPASS_READ_ADDR = 32'h1000_0000;
    localparam [ADDR_BITS-1:0] BYPASS_WRITE_ADDR = 32'h1000_0004;
    localparam [ID_BITS-1:0] CACHE_READ_ID_0 = 4'h3;
    localparam [ID_BITS-1:0] CACHE_READ_ID_1 = 4'h7;
    localparam [ID_BITS-1:0] BYPASS_READ_ID = 4'h9;
    localparam [ID_BITS-1:0] BYPASS_WRITE_ID = 4'hA;

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

    reg  [AXI_ID_BITS-1:0]          cache_arid_0;
    reg  [AXI_ID_BITS-1:0]          bypass_arid;
    reg  [AXI_ID_BITS-1:0]          cache_arid_1;
    reg  [AXI_ID_BITS-1:0]          bypass_awid;
    reg  [AXI_ID_BITS-1:0]          cache_arid_2;
    reg  [AXI_ID_BITS-1:0]          bypass_arid_2;
    reg  [AXI_ID_BITS-1:0]          cache_arid_3;
    reg  [AXI_ID_BITS-1:0]          bypass_awid_2;
    reg  [AXI_DATA_BITS-1:0]        cache_beat0;
    reg  [AXI_DATA_BITS-1:0]        cache_beat1;
    reg  [AXI_DATA_BITS-1:0]        cache_beat2;
    reg  [AXI_DATA_BITS-1:0]        cache_beat3;
    reg  [LINE_BITS-1:0]            expected_cache_line0;
    reg  [LINE_BITS-1:0]            expected_cache_line1;
    integer                         ar_count;
    integer                         aw_count;
    integer                         w_count;
    reg  [ADDR_BITS-1:0]            ar_addr_log [0:3];
    reg  [AXI_ID_BITS-1:0]          ar_id_log [0:3];
    reg  [ADDR_BITS-1:0]            aw_addr_log [0:3];
    reg  [AXI_ID_BITS-1:0]          aw_id_log [0:3];
    reg  [AXI_DATA_BITS-1:0]        w_data_log [0:3];
    reg  [AXI_STRB_BITS-1:0]        w_strb_log [0:3];
    integer                         timeout;

    wire [ID_BITS-1:0]             read_resp_id_m0_w;
    wire [ID_BITS-1:0]             read_resp_id_m1_w;
    wire [LINE_BITS-1:0]           read_resp_data_m0_w;
    wire [31:0]                    read_resp_word_m1_w;
    wire [ID_BITS-1:0]             write_resp_id_m1_w;
    wire [1:0]                     write_resp_code_m1_w;

    assign read_resp_id_m0_w =
        read_resp_id[(CACHE_MASTER * ID_BITS) +: ID_BITS];
    assign read_resp_id_m1_w =
        read_resp_id[(BYPASS_READ_MASTER * ID_BITS) +: ID_BITS];
    assign read_resp_data_m0_w =
        read_resp_data[(CACHE_MASTER * READ_RESP_BITS) +: LINE_BITS];
    assign read_resp_word_m1_w =
        read_resp_data[(BYPASS_READ_MASTER * READ_RESP_BITS) +: 32];
    assign write_resp_id_m1_w =
        write_resp_id[(BYPASS_WRITE_MASTER * ID_BITS) +: ID_BITS];
    assign write_resp_code_m1_w =
        write_resp_code[(BYPASS_WRITE_MASTER * 2) +: 2];

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
            $display("tb_axi_llc_subsystem_axi_mode1_multiflow_contract FAIL: %0s", msg);
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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ar_count <= 0;
            aw_count <= 0;
            w_count <= 0;
        end else begin
            if (axi_arvalid && axi_arready) begin
                ar_addr_log[ar_count] <= axi_araddr;
                ar_id_log[ar_count] <= axi_arid;
                ar_count <= ar_count + 1;
            end
            if (axi_awvalid && axi_awready) begin
                aw_addr_log[aw_count] <= axi_awaddr;
                aw_id_log[aw_count] <= axi_awid;
                aw_count <= aw_count + 1;
            end
            if (axi_wvalid && axi_wready) begin
                w_data_log[w_count] <= axi_wdata;
                w_strb_log[w_count] <= axi_wstrb;
                w_count <= w_count + 1;
            end
        end
    end

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

    task clear_reqs;
        begin
            read_req_valid = {NUM_READ_MASTERS{1'b0}};
            read_req_addr = {(NUM_READ_MASTERS*ADDR_BITS){1'b0}};
            read_req_total_size = {(NUM_READ_MASTERS*8){1'b0}};
            read_req_id = {(NUM_READ_MASTERS*ID_BITS){1'b0}};
            read_req_bypass = {NUM_READ_MASTERS{1'b0}};
            write_req_valid = {NUM_WRITE_MASTERS{1'b0}};
            write_req_addr = {(NUM_WRITE_MASTERS*ADDR_BITS){1'b0}};
            write_req_wdata = {(NUM_WRITE_MASTERS*LINE_BITS){1'b0}};
            write_req_wstrb = {(NUM_WRITE_MASTERS*LINE_BYTES){1'b0}};
            write_req_total_size = {(NUM_WRITE_MASTERS*8){1'b0}};
            write_req_id = {(NUM_WRITE_MASTERS*ID_BITS){1'b0}};
            write_req_bypass = {NUM_WRITE_MASTERS{1'b0}};
        end
    endtask

    task issue_cache_read;
        input [ID_BITS-1:0] id_value;
        integer timeout;
        begin
            @(negedge clk);
            read_req_valid[CACHE_MASTER] = 1'b1;
            read_req_addr[(CACHE_MASTER * ADDR_BITS) +: ADDR_BITS] = CACHE_ADDR;
            read_req_total_size[(CACHE_MASTER * 8) +: 8] = LINE_BYTES - 1;
            read_req_id[(CACHE_MASTER * ID_BITS) +: ID_BITS] = id_value;
            read_req_bypass[CACHE_MASTER] = 1'b0;
            timeout = 100;
            while ((read_req_accepted[CACHE_MASTER] !== 1'b1) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("cache read accepted pulse missing");
            end
            @(negedge clk);
            read_req_valid[CACHE_MASTER] = 1'b0;
        end
    endtask

    task issue_bypass_read;
        integer timeout;
        begin
            @(negedge clk);
            read_req_valid[BYPASS_READ_MASTER] = 1'b1;
            read_req_addr[(BYPASS_READ_MASTER * ADDR_BITS) +: ADDR_BITS] = BYPASS_READ_ADDR;
            read_req_total_size[(BYPASS_READ_MASTER * 8) +: 8] = 8'd3;
            read_req_id[(BYPASS_READ_MASTER * ID_BITS) +: ID_BITS] = BYPASS_READ_ID;
            read_req_bypass[BYPASS_READ_MASTER] = 1'b1;
            timeout = 100;
            while ((read_req_accepted[BYPASS_READ_MASTER] !== 1'b1) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("bypass read accepted pulse missing");
            end
            @(negedge clk);
            read_req_valid[BYPASS_READ_MASTER] = 1'b0;
        end
    endtask

    task issue_bypass_write;
        integer timeout;
        begin
            @(negedge clk);
            write_req_valid[BYPASS_WRITE_MASTER] = 1'b1;
            write_req_addr[(BYPASS_WRITE_MASTER * ADDR_BITS) +: ADDR_BITS] = BYPASS_WRITE_ADDR;
            write_req_total_size[(BYPASS_WRITE_MASTER * 8) +: 8] = 8'd3;
            write_req_id[(BYPASS_WRITE_MASTER * ID_BITS) +: ID_BITS] = BYPASS_WRITE_ID;
            write_req_wdata[(BYPASS_WRITE_MASTER * LINE_BITS) +: LINE_BITS] =
                64'h0000_0000_89AB_CDEF;
            write_req_wstrb[(BYPASS_WRITE_MASTER * LINE_BYTES) +: LINE_BYTES] =
                8'h0F;
            write_req_bypass[BYPASS_WRITE_MASTER] = 1'b1;
            timeout = 100;
            while ((write_req_accepted[BYPASS_WRITE_MASTER] !== 1'b1) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("bypass write accepted pulse missing");
            end
            @(negedge clk);
            write_req_valid[BYPASS_WRITE_MASTER] = 1'b0;
        end
    endtask

    task wait_for_ar;
        input [ADDR_BITS-1:0] exp_addr;
        input [7:0]           exp_len;
        output [AXI_ID_BITS-1:0] arid_value;
        integer timeout;
        begin
            timeout = 200;
            while (!axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting AXI AR");
            end
            if (axi_araddr !== exp_addr) begin
                fail_now("AXI AR address mismatch");
            end
            if (axi_arlen !== exp_len) begin
                fail_now("AXI AR len mismatch");
            end
            if (axi_arsize !== AXI_SIZE_32B) begin
                fail_now("AXI AR size mismatch");
            end
            if (axi_arburst !== AXI_BURST_INCR) begin
                fail_now("AXI AR burst mismatch");
            end
            arid_value = axi_arid;
            @(negedge clk);
            axi_arready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            axi_arready = 1'b0;
        end
    endtask

    task wait_for_aw;
        input [ADDR_BITS-1:0] exp_addr;
        input [7:0]           exp_len;
        output [AXI_ID_BITS-1:0] awid_value;
        integer timeout;
        begin
            timeout = 200;
            while (!axi_awvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting AXI AW");
            end
            if (axi_awaddr !== exp_addr) begin
                fail_now("AXI AW address mismatch");
            end
            if (axi_awlen !== exp_len) begin
                fail_now("AXI AW len mismatch");
            end
            if (axi_awsize !== AXI_SIZE_32B) begin
                fail_now("AXI AW size mismatch");
            end
            awid_value = axi_awid;
            @(negedge clk);
            axi_awready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            axi_awready = 1'b0;
        end
    endtask

    task wait_for_w;
        input [AXI_DATA_BITS-1:0] exp_wdata;
        input [AXI_STRB_BITS-1:0] exp_wstrb;
        input exp_last;
        integer timeout;
        begin
            timeout = 200;
            while (!axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting AXI W");
            end
            if (axi_wdata !== exp_wdata) begin
                fail_now("AXI W data mismatch");
            end
            if (axi_wstrb !== exp_wstrb) begin
                fail_now("AXI W strobe mismatch");
            end
            if (axi_wlast !== exp_last) begin
                fail_now("AXI W last mismatch");
            end
            @(negedge clk);
            axi_wready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            axi_wready = 1'b0;
        end
    endtask

    task drive_b;
        input [AXI_ID_BITS-1:0] bid_value;
        input [1:0]             bresp_value;
        begin
            @(negedge clk);
            axi_bvalid = 1'b1;
            axi_bid = bid_value;
            axi_bresp = bresp_value;
            while (!axi_bready) begin
                @(posedge clk);
                @(negedge clk);
            end
            @(posedge clk);
            @(negedge clk);
            axi_bvalid = 1'b0;
            axi_bid = {AXI_ID_BITS{1'b0}};
            axi_bresp = AXI_RESP_OKAY;
        end
    endtask

    task drive_r;
        input [AXI_ID_BITS-1:0] rid_value;
        input [AXI_DATA_BITS-1:0] rdata_value;
        input [1:0]               rresp_value;
        input                     rlast_value;
        begin
            @(negedge clk);
            axi_rvalid = 1'b1;
            axi_rid = rid_value;
            axi_rdata = rdata_value;
            axi_rresp = rresp_value;
            axi_rlast = rlast_value;
            while (!axi_rready) begin
                @(posedge clk);
                @(negedge clk);
            end
            @(posedge clk);
            @(negedge clk);
            axi_rvalid = 1'b0;
            axi_rid = {AXI_ID_BITS{1'b0}};
            axi_rdata = {AXI_DATA_BITS{1'b0}};
            axi_rresp = AXI_RESP_OKAY;
            axi_rlast = 1'b0;
        end
    endtask

    task wait_for_read_resp_master;
        input integer master;
        input [ID_BITS-1:0] exp_id;
        input [31:0] exp_word;
        integer timeout;
        begin
            timeout = 200;
            while (!read_resp_valid[master] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting read response");
            end
            if (master == CACHE_MASTER) begin
                if (read_resp_id_m0_w !== exp_id) begin
                    fail_now("cache read response id mismatch");
                end
            end else begin
                if (read_resp_id_m1_w !== exp_id) begin
                    fail_now("bypass read response id mismatch");
                end
                if (read_resp_word_m1_w !== exp_word) begin
                    fail_now("bypass read response data mismatch");
                end
            end
            @(posedge clk);
        end
    endtask

    task wait_for_write_resp_master1;
        input [ID_BITS-1:0] exp_id;
        input [1:0]         exp_code;
        integer timeout;
        begin
            timeout = 200;
            while (!write_resp_valid[BYPASS_WRITE_MASTER] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting write response");
            end
            if (write_resp_id_m1_w !== exp_id) begin
                fail_now("bypass write response id mismatch");
            end
            if (write_resp_code_m1_w !== exp_code) begin
                fail_now("bypass write response code mismatch");
            end
            @(posedge clk);
        end
    endtask

    always #5 clk = ~clk;

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
        read_resp_ready = {NUM_READ_MASTERS{1'b1}};
        write_resp_ready = {NUM_WRITE_MASTERS{1'b1}};
        clear_reqs();
        axi_awready = 1'b1;
        axi_wready = 1'b1;
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

        cache_beat0 = 256'h1F1E1D1C1B1A191817161514131211100F0E0D0C0B0A09080706050403020100;
        cache_beat1 = 256'h3F3E3D3C3B3A393837363534333231302F2E2D2C2B2A29282726252423222120;
        cache_beat2 = 256'h5F5E5D5C5B5A595857565554535251504F4E4D4C4B4A49484746454443424140;
        cache_beat3 = 256'h7F7E7D7C7B7A797877767574737271706F6E6D6C6B6A69686766656463626160;
        expected_cache_line0 = assemble_two_beats(cache_beat1, cache_beat0);
        expected_cache_line1 = assemble_two_beats(cache_beat3, cache_beat2);

        wait_cycles(4);
        rst_n = 1'b1;
        wait_mode_cache_active();
        if (config_error) begin
            fail_now("config_error should stay low");
        end

        // Case 1: cache miss read and mode1 bypass read can both be outstanding.
        issue_cache_read(CACHE_READ_ID_0);
        timeout = 200;
        while (ar_count < 1 && timeout > 0) begin
            @(posedge clk);
            timeout = timeout - 1;
        end
        if (timeout == 0) begin
            fail_now("cache read should issue first AXI AR");
        end
        if (ar_addr_log[0] !== CACHE_ADDR) begin
            fail_now("first AXI AR should belong to cache miss");
        end
        cache_arid_0 = ar_id_log[0];

        issue_bypass_read();
        timeout = 200;
        while (ar_count < 2 && timeout > 0) begin
            @(posedge clk);
            timeout = timeout - 1;
        end
        if (timeout == 0) begin
            fail_now("bypass read should issue second AXI AR");
        end
        if (ar_addr_log[1] !== BYPASS_READ_ADDR) begin
            fail_now("second AXI AR should belong to bypass read");
        end
        bypass_arid = ar_id_log[1];
        if (bypass_arid == cache_arid_0) begin
            fail_now("bypass read should use a different AXI id");
        end

        drive_r(bypass_arid,
                256'h00000000000000000000000000000000000000000000000000000000DEADBEEF,
                AXI_RESP_OKAY,
                1'b1);
        wait_for_read_resp_master(BYPASS_READ_MASTER, BYPASS_READ_ID, 32'hDEAD_BEEF);

        drive_r(cache_arid_0, cache_beat0, AXI_RESP_OKAY, 1'b0);
        drive_r(cache_arid_0, cache_beat1, AXI_RESP_OKAY, 1'b1);
        wait_for_read_resp_master(CACHE_MASTER, CACHE_READ_ID_0,
                                  expected_cache_line0[31:0]);

        // Restart from a clean state before the write-concurrency case.
        @(negedge clk);
        rst_n = 1'b0;
        clear_reqs();
        axi_bvalid = 1'b0;
        axi_bid = {AXI_ID_BITS{1'b0}};
        axi_bresp = AXI_RESP_OKAY;
        axi_rvalid = 1'b0;
        axi_rid = {AXI_ID_BITS{1'b0}};
        axi_rdata = {AXI_DATA_BITS{1'b0}};
        axi_rresp = AXI_RESP_OKAY;
        axi_rlast = 1'b0;
        wait_cycles(4);
        rst_n = 1'b1;
        wait_mode_cache_active();

        // Case 2: cache miss read and mode1 bypass write can both be outstanding.
        issue_cache_read(CACHE_READ_ID_1);
        timeout = 200;
        while (ar_count < 1 && timeout > 0) begin
            @(posedge clk);
            timeout = timeout - 1;
        end
        if (timeout == 0) begin
            fail_now("second case cache miss should issue an AXI AR");
        end
        if (ar_addr_log[0] !== CACHE_ADDR) begin
            fail_now("write case first AXI AR should belong to cache miss");
        end
        cache_arid_1 = ar_id_log[0];

        issue_bypass_write();
        timeout = 200;
        while ((aw_count < 1 || w_count < 1) && timeout > 0) begin
            @(posedge clk);
            timeout = timeout - 1;
        end
        if (timeout == 0) begin
            fail_now("bypass write should issue AXI AW/W while cache read is pending");
        end
        if (aw_addr_log[0] !== BYPASS_WRITE_ADDR) begin
            fail_now("first AXI AW should belong to bypass write");
        end
        if (w_data_log[0] !==
            256'h0000000000000000000000000000000000000000000000000000000089ABCDEF) begin
            fail_now("AXI W data mismatch for bypass write");
        end
        if (w_strb_log[0] !== 32'h0000000F) begin
            fail_now("AXI W strobe mismatch for bypass write");
        end
        bypass_awid = aw_id_log[0];
        drive_b(bypass_awid, AXI_RESP_SLVERR);
        wait_for_write_resp_master1(BYPASS_WRITE_ID, AXI_RESP_SLVERR);

        drive_r(cache_arid_1, cache_beat2, AXI_RESP_OKAY, 1'b0);
        drive_r(cache_arid_1, cache_beat3, AXI_RESP_OKAY, 1'b1);
        wait_for_read_resp_master(CACHE_MASTER, CACHE_READ_ID_1,
                                  expected_cache_line1[31:0]);

        // Restart from a clean state before the reverse-order read case.
        @(negedge clk);
        rst_n = 1'b0;
        clear_reqs();
        axi_bvalid = 1'b0;
        axi_bid = {AXI_ID_BITS{1'b0}};
        axi_bresp = AXI_RESP_OKAY;
        axi_rvalid = 1'b0;
        axi_rid = {AXI_ID_BITS{1'b0}};
        axi_rdata = {AXI_DATA_BITS{1'b0}};
        axi_rresp = AXI_RESP_OKAY;
        axi_rlast = 1'b0;
        wait_cycles(4);
        rst_n = 1'b1;
        wait_mode_cache_active();

        // Case 3: mode1 bypass read miss in flight must not block a later cache miss read.
        issue_bypass_read();
        timeout = 200;
        while (ar_count < 1 && timeout > 0) begin
            @(posedge clk);
            timeout = timeout - 1;
        end
        if (timeout == 0) begin
            fail_now("reverse-order bypass read should issue first AXI AR");
        end
        if (ar_addr_log[0] !== BYPASS_READ_ADDR) begin
            fail_now("reverse-order first AXI AR should belong to bypass read");
        end
        bypass_arid_2 = ar_id_log[0];

        issue_cache_read(CACHE_READ_ID_0);
        timeout = 200;
        while (ar_count < 2 && timeout > 0) begin
            @(posedge clk);
            timeout = timeout - 1;
        end
        if (timeout == 0) begin
            fail_now("cache miss should issue AXI AR while bypass read is pending");
        end
        if (ar_addr_log[1] !== CACHE_ADDR) begin
            fail_now("reverse-order second AXI AR should belong to cache miss");
        end
        cache_arid_2 = ar_id_log[1];
        if (cache_arid_2 == bypass_arid_2) begin
            fail_now("reverse-order cache miss should use a different AXI id");
        end

        drive_r(cache_arid_2, cache_beat0, AXI_RESP_OKAY, 1'b0);
        drive_r(cache_arid_2, cache_beat1, AXI_RESP_OKAY, 1'b1);
        wait_for_read_resp_master(CACHE_MASTER, CACHE_READ_ID_0,
                                  expected_cache_line0[31:0]);

        drive_r(bypass_arid_2,
                256'h00000000000000000000000000000000000000000000000000000000DEADBEEF,
                AXI_RESP_OKAY,
                1'b1);
        wait_for_read_resp_master(BYPASS_READ_MASTER, BYPASS_READ_ID, 32'hDEAD_BEEF);

        // Restart from a clean state before the reverse-order write-through case.
        @(negedge clk);
        rst_n = 1'b0;
        clear_reqs();
        axi_bvalid = 1'b0;
        axi_bid = {AXI_ID_BITS{1'b0}};
        axi_bresp = AXI_RESP_OKAY;
        axi_rvalid = 1'b0;
        axi_rid = {AXI_ID_BITS{1'b0}};
        axi_rdata = {AXI_DATA_BITS{1'b0}};
        axi_rresp = AXI_RESP_OKAY;
        axi_rlast = 1'b0;
        wait_cycles(4);
        rst_n = 1'b1;
        wait_mode_cache_active();

        // Case 4: mode1 bypass write-through in flight must not block a later cache miss read.
        issue_bypass_write();
        timeout = 200;
        while ((aw_count < 1 || w_count < 1) && timeout > 0) begin
            @(posedge clk);
            timeout = timeout - 1;
        end
        if (timeout == 0) begin
            fail_now("reverse-order bypass write should issue AXI AW/W first");
        end
        if (aw_addr_log[0] !== BYPASS_WRITE_ADDR) begin
            fail_now("reverse-order first AXI AW should belong to bypass write");
        end
        bypass_awid_2 = aw_id_log[0];

        issue_cache_read(CACHE_READ_ID_1);
        timeout = 200;
        while (ar_count < 1 && timeout > 0) begin
            @(posedge clk);
            timeout = timeout - 1;
        end
        if (timeout == 0) begin
            fail_now("cache miss should issue AXI AR while bypass write is pending");
        end
        if (ar_addr_log[0] !== CACHE_ADDR) begin
            fail_now("reverse-order cache read AXI AR address mismatch");
        end
        cache_arid_3 = ar_id_log[0];

        drive_b(bypass_awid_2, AXI_RESP_SLVERR);
        wait_for_write_resp_master1(BYPASS_WRITE_ID, AXI_RESP_SLVERR);

        drive_r(cache_arid_3, cache_beat2, AXI_RESP_OKAY, 1'b0);
        drive_r(cache_arid_3, cache_beat3, AXI_RESP_OKAY, 1'b1);
        wait_for_read_resp_master(CACHE_MASTER, CACHE_READ_ID_1,
                                  expected_cache_line1[31:0]);

        $display("tb_axi_llc_subsystem_axi_mode1_multiflow_contract PASS");
        $finish(0);
    end

endmodule
