`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_read_master_timing_contract;

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
    localparam NUM_READ_MASTERS  = 4;
    localparam NUM_WRITE_MASTERS = 1;
    localparam AXI_ID_BITS       = `AXI_LLC_AXI_ID_BITS;
    localparam AXI_DATA_BYTES    = `AXI_LLC_AXI_DATA_BYTES;
    localparam AXI_DATA_BITS     = `AXI_LLC_AXI_DATA_BITS;
    localparam AXI_STRB_BITS     = `AXI_LLC_AXI_STRB_BITS;
    localparam READ_RESP_BITS    = `AXI_LLC_READ_RESP_BITS;

    localparam [MODE_BITS-1:0] MODE_CACHE = 2'b01;
    localparam [1:0] AXI_BURST_INCR = 2'b01;
    localparam [2:0] AXI_SIZE_32B = 3'd5;
    localparam integer MASTER_ICACHE   = 0;
    localparam integer MASTER_DCACHE_R = 1;

    localparam [ADDR_BITS-1:0] ICACHE_ADDR = 32'h1000_0010;
    localparam [ADDR_BITS-1:0] DCACHE_ADDR = 32'h1000_0040;
    localparam [ID_BITS-1:0]   ICACHE_ID   = 4'hA;
    localparam [ID_BITS-1:0]   DCACHE_ID   = 4'hB;

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
    reg  [AXI_ID_BITS-1:0]          last_arid;
    reg  [ADDR_BITS-1:0]            last_araddr;

    function [ID_BITS-1:0] get_read_accept_id;
        input integer master;
        begin
            get_read_accept_id =
                read_req_accepted_id[(master * ID_BITS) +: ID_BITS];
        end
    endfunction

    function [ID_BITS-1:0] get_read_resp_id;
        input integer master;
        begin
            get_read_resp_id =
                read_resp_id[(master * ID_BITS) +: ID_BITS];
        end
    endfunction

    always #5 clk = ~clk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ar_count <= 0;
            last_arid <= {AXI_ID_BITS{1'b0}};
            last_araddr <= {ADDR_BITS{1'b0}};
        end else if (axi_arvalid && axi_arready) begin
            ar_count <= ar_count + 1;
            last_arid <= axi_arid;
            last_araddr <= axi_araddr;
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
            $display("tb_axi_llc_subsystem_read_master_timing_contract FAIL: %0s", msg);
            $finish(1);
        end
    endtask

    task clear_read_inputs;
        begin
            read_req_valid = {NUM_READ_MASTERS{1'b0}};
            read_req_addr = {(NUM_READ_MASTERS * ADDR_BITS){1'b0}};
            read_req_total_size = {(NUM_READ_MASTERS * 8){1'b0}};
            read_req_id = {(NUM_READ_MASTERS * ID_BITS){1'b0}};
            read_req_bypass = {NUM_READ_MASTERS{1'b0}};
        end
    endtask

    task clear_write_inputs;
        begin
            write_req_valid = {NUM_WRITE_MASTERS{1'b0}};
            write_req_addr = {(NUM_WRITE_MASTERS * ADDR_BITS){1'b0}};
            write_req_wdata = {(NUM_WRITE_MASTERS * LINE_BITS){1'b0}};
            write_req_wstrb = {(NUM_WRITE_MASTERS * LINE_BYTES){1'b0}};
            write_req_total_size = {(NUM_WRITE_MASTERS * 8){1'b0}};
            write_req_id = {(NUM_WRITE_MASTERS * ID_BITS){1'b0}};
            write_req_bypass = {NUM_WRITE_MASTERS{1'b0}};
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
            while (((active_mode != MODE_CACHE) || reconfig_busy) &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("mode=1 activate timeout");
            end
            if (active_offset !== {ADDR_BITS{1'b0}}) begin
                fail_now("active_offset should stay zero");
            end
            if (reconfig_state !== 2'b00) begin
                fail_now("reconfig state should settle back to idle");
            end
        end
    endtask

    task wait_master_ready_low;
        input integer master;
        integer timeout;
        begin
            timeout = 20;
            while ((read_req_ready[master] !== 1'b0) && (timeout > 0)) begin
                @(posedge clk);
                #1;
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("ready did not return low after dropped request");
            end
        end
    endtask

    task issue_icache_single_cycle_strobe_expect_ready_first;
        begin
            @(negedge clk);
            read_req_valid[MASTER_ICACHE] = 1'b1;
            read_req_addr[(MASTER_ICACHE * ADDR_BITS) +: ADDR_BITS] = ICACHE_ADDR;
            read_req_total_size[(MASTER_ICACHE * 8) +: 8] = 8'd3;
            read_req_id[(MASTER_ICACHE * ID_BITS) +: ID_BITS] = ICACHE_ID;
            read_req_bypass[MASTER_ICACHE] = 1'b1;
            #1;
            if (read_req_ready[MASTER_ICACHE] !== 1'b0) begin
                fail_now("MASTER_ICACHE should not expose same-cycle ready");
            end
            @(posedge clk);
            #1;
            if (read_req_accepted[MASTER_ICACHE]) begin
                fail_now("MASTER_ICACHE one-cycle pulse should not be accepted");
            end
            @(negedge clk);
            read_req_valid[MASTER_ICACHE] = 1'b0;
            read_req_addr[(MASTER_ICACHE * ADDR_BITS) +: ADDR_BITS] = {ADDR_BITS{1'b0}};
            read_req_total_size[(MASTER_ICACHE * 8) +: 8] = 8'd0;
            read_req_id[(MASTER_ICACHE * ID_BITS) +: ID_BITS] = {ID_BITS{1'b0}};
            read_req_bypass[MASTER_ICACHE] = 1'b0;
            @(posedge clk);
            #1;
            if (read_req_accepted[MASTER_ICACHE]) begin
                fail_now("MASTER_ICACHE dropped pulse should not produce accepted");
            end
        end
    endtask

    task issue_dcache_same_cycle_expect_accept;
        begin
            @(negedge clk);
            read_req_valid[MASTER_DCACHE_R] = 1'b1;
            read_req_addr[(MASTER_DCACHE_R * ADDR_BITS) +: ADDR_BITS] = DCACHE_ADDR;
            read_req_total_size[(MASTER_DCACHE_R * 8) +: 8] = 8'd3;
            read_req_id[(MASTER_DCACHE_R * ID_BITS) +: ID_BITS] = DCACHE_ID;
            read_req_bypass[MASTER_DCACHE_R] = 1'b1;
            #1;
            if (read_req_ready[MASTER_DCACHE_R] !== 1'b1) begin
                fail_now("MASTER_DCACHE_R should expose same-cycle ready");
            end
            @(posedge clk);
            #1;
            if (!read_req_accepted[MASTER_DCACHE_R]) begin
                fail_now("MASTER_DCACHE_R same-cycle accepted pulse missing");
            end
            if (get_read_accept_id(MASTER_DCACHE_R) !== DCACHE_ID) begin
                fail_now("MASTER_DCACHE_R accepted_id mismatch");
            end
            @(negedge clk);
            read_req_valid[MASTER_DCACHE_R] = 1'b0;
            read_req_addr[(MASTER_DCACHE_R * ADDR_BITS) +: ADDR_BITS] = {ADDR_BITS{1'b0}};
            read_req_total_size[(MASTER_DCACHE_R * 8) +: 8] = 8'd0;
            read_req_id[(MASTER_DCACHE_R * ID_BITS) +: ID_BITS] = {ID_BITS{1'b0}};
            read_req_bypass[MASTER_DCACHE_R] = 1'b0;
        end
    endtask

    task issue_icache_hold_expect_accept;
        integer timeout;
        begin
            @(negedge clk);
            read_req_valid[MASTER_ICACHE] = 1'b1;
            read_req_addr[(MASTER_ICACHE * ADDR_BITS) +: ADDR_BITS] = ICACHE_ADDR;
            read_req_total_size[(MASTER_ICACHE * 8) +: 8] = 8'd3;
            read_req_id[(MASTER_ICACHE * ID_BITS) +: ID_BITS] = ICACHE_ID;
            read_req_bypass[MASTER_ICACHE] = 1'b1;
            #1;
            if (read_req_ready[MASTER_ICACHE] !== 1'b0) begin
                fail_now("MASTER_ICACHE should still be ready-first on held request");
            end
            @(posedge clk);
            #1;
            if (read_req_accepted[MASTER_ICACHE]) begin
                fail_now("MASTER_ICACHE should not accept on the first valid cycle");
            end
            timeout = 40;
            while (!read_req_ready[MASTER_ICACHE] && (timeout > 0)) begin
                @(posedge clk);
                #1;
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("MASTER_ICACHE did not eventually raise ready");
            end
            timeout = 40;
            while (!read_req_accepted[MASTER_ICACHE] && (timeout > 0)) begin
                @(posedge clk);
                #1;
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("MASTER_ICACHE held request was never accepted");
            end
            if (get_read_accept_id(MASTER_ICACHE) !== ICACHE_ID) begin
                fail_now("MASTER_ICACHE accepted_id mismatch");
            end
            @(negedge clk);
            read_req_valid[MASTER_ICACHE] = 1'b0;
            read_req_addr[(MASTER_ICACHE * ADDR_BITS) +: ADDR_BITS] = {ADDR_BITS{1'b0}};
            read_req_total_size[(MASTER_ICACHE * 8) +: 8] = 8'd0;
            read_req_id[(MASTER_ICACHE * ID_BITS) +: ID_BITS] = {ID_BITS{1'b0}};
            read_req_bypass[MASTER_ICACHE] = 1'b0;
        end
    endtask

    task wait_for_ar_count;
        input integer         expect_count;
        input [ADDR_BITS-1:0] exp_addr;
        integer timeout;
        begin
            timeout = 100;
            while ((ar_count < expect_count) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting AXI AR");
            end
            if (last_araddr !== exp_addr) begin
                fail_now("AXI AR address mismatch");
            end
            if (axi_arlen !== 8'd0) begin
                fail_now("bypass read must stay single-beat");
            end
            if (axi_arsize !== AXI_SIZE_32B) begin
                fail_now("bypass read must keep fixed downstream beat size");
            end
            if (axi_arburst !== AXI_BURST_INCR) begin
                fail_now("bypass read burst should stay INCR");
            end
        end
    endtask

    task drive_single_r;
        input [31:0] word_value;
        integer timeout;
        begin
            @(negedge clk);
            axi_rid = last_arid;
            axi_rdata = {AXI_DATA_BITS{1'b0}};
            axi_rdata[31:0] = word_value;
            axi_rresp = 2'b00;
            axi_rlast = 1'b1;
            axi_rvalid = 1'b1;
            timeout = 40;
            while (!(axi_rvalid && axi_rready) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting AXI R handshake");
            end
            @(negedge clk);
            axi_rvalid = 1'b0;
            axi_rid = {AXI_ID_BITS{1'b0}};
            axi_rdata = {AXI_DATA_BITS{1'b0}};
            axi_rresp = 2'b00;
            axi_rlast = 1'b0;
        end
    endtask

    task wait_read_resp;
        input integer       master;
        input [ID_BITS-1:0] exp_id;
        integer timeout;
        begin
            timeout = 100;
            while (!read_resp_valid[master] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting upstream read response");
            end
            if (get_read_resp_id(master) !== exp_id) begin
                fail_now("upstream read response id mismatch");
            end
            @(posedge clk);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        mode_req = MODE_CACHE;
        llc_mapped_offset_req = {ADDR_BITS{1'b0}};
        clear_read_inputs();
        clear_write_inputs();
        read_resp_ready = {NUM_READ_MASTERS{1'b1}};
        write_resp_ready = {NUM_WRITE_MASTERS{1'b1}};
        axi_awready = 1'b0;
        axi_wready = 1'b0;
        axi_bvalid = 1'b0;
        axi_bid = {AXI_ID_BITS{1'b0}};
        axi_bresp = 2'b00;
        axi_arready = 1'b1;
        axi_rvalid = 1'b0;
        axi_rid = {AXI_ID_BITS{1'b0}};
        axi_rdata = {AXI_DATA_BITS{1'b0}};
        axi_rresp = 2'b00;
        axi_rlast = 1'b0;
        invalidate_line_valid = 1'b0;
        invalidate_line_addr = {ADDR_BITS{1'b0}};
        invalidate_all_valid = 1'b0;

        wait_cycles(5);
        rst_n = 1'b1;
        wait_mode_cache_active();

        issue_icache_single_cycle_strobe_expect_ready_first();
        if (ar_count != 0) begin
            fail_now("MASTER_ICACHE one-cycle strobe should not emit AR");
        end
        wait_master_ready_low(MASTER_ICACHE);

        issue_dcache_same_cycle_expect_accept();
        wait_for_ar_count(1, DCACHE_ADDR);
        drive_single_r(32'hD00D_0001);
        wait_read_resp(MASTER_DCACHE_R, DCACHE_ID);

        wait_master_ready_low(MASTER_ICACHE);
        issue_icache_hold_expect_accept();
        wait_for_ar_count(2, ICACHE_ADDR);
        drive_single_r(32'h1CA0_0002);
        wait_read_resp(MASTER_ICACHE, ICACHE_ID);

        if (config_error) begin
            fail_now("config_error asserted unexpectedly");
        end

        $display("tb_axi_llc_subsystem_read_master_timing_contract PASS");
        $finish(0);
    end

endmodule
