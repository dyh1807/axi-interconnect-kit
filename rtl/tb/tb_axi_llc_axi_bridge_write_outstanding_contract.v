`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_axi_bridge_write_outstanding_contract;

    localparam ADDR_BITS       = `AXI_LLC_ADDR_BITS;
    localparam ID_BITS         = `AXI_LLC_ID_BITS;
    localparam LINE_BYTES      = `AXI_LLC_LINE_BYTES;
    localparam LINE_BITS       = `AXI_LLC_LINE_BITS;
    localparam AXI_ID_BITS     = `AXI_LLC_AXI_ID_BITS;
    localparam AXI_DATA_BYTES  = `AXI_LLC_AXI_DATA_BYTES;
    localparam AXI_DATA_BITS   = `AXI_LLC_AXI_DATA_BITS;
    localparam AXI_STRB_BITS   = `AXI_LLC_AXI_STRB_BITS;
    localparam READ_RESP_BITS  = `AXI_LLC_READ_RESP_BITS;

    localparam [ADDR_BITS-1:0] CACHE_ADDR  = 32'h0000_1080;
    localparam [ADDR_BITS-1:0] BYPASS_ADDR = 32'h1000_0010;
    localparam [ID_BITS-1:0]   CACHE_ID    = 4'h5;
    localparam [ID_BITS-1:0]   BYPASS_ID   = 4'hA;

    reg                          clk;
    reg                          rst_n;
    reg                          cache_req_valid;
    wire                         cache_req_ready;
    reg                          cache_req_write;
    reg  [ADDR_BITS-1:0]         cache_req_addr;
    reg  [ID_BITS-1:0]           cache_req_id;
    reg  [7:0]                   cache_req_size;
    reg  [LINE_BITS-1:0]         cache_req_wdata;
    reg  [LINE_BYTES-1:0]        cache_req_wstrb;
    wire                         cache_resp_valid;
    reg                          cache_resp_ready;
    wire [READ_RESP_BITS-1:0]    cache_resp_rdata;
    wire [ID_BITS-1:0]           cache_resp_id;
    wire [1:0]                   cache_resp_code;
    reg                          bypass_req_valid;
    wire                         bypass_req_ready;
    reg                          bypass_req_write;
    reg  [ADDR_BITS-1:0]         bypass_req_addr;
    reg  [ID_BITS-1:0]           bypass_req_id;
    reg  [7:0]                   bypass_req_size;
    reg  [LINE_BITS-1:0]         bypass_req_wdata;
    reg  [LINE_BYTES-1:0]        bypass_req_wstrb;
    wire                         bypass_resp_valid;
    reg                          bypass_resp_ready;
    wire [READ_RESP_BITS-1:0]    bypass_resp_rdata;
    wire [ID_BITS-1:0]           bypass_resp_id;
    wire [1:0]                   bypass_resp_code;
    wire                         axi_awvalid;
    reg                          axi_awready;
    wire [AXI_ID_BITS-1:0]       axi_awid;
    wire [ADDR_BITS-1:0]         axi_awaddr;
    wire [7:0]                   axi_awlen;
    wire [2:0]                   axi_awsize;
    wire [1:0]                   axi_awburst;
    wire                         axi_wvalid;
    reg                          axi_wready;
    wire [AXI_DATA_BITS-1:0]     axi_wdata;
    wire [AXI_STRB_BITS-1:0]     axi_wstrb;
    wire                         axi_wlast;
    reg                          axi_bvalid;
    wire                         axi_bready;
    reg  [AXI_ID_BITS-1:0]       axi_bid;
    reg  [1:0]                   axi_bresp;
    wire                         axi_arvalid;
    reg                          axi_arready;
    wire [AXI_ID_BITS-1:0]       axi_arid;
    wire [ADDR_BITS-1:0]         axi_araddr;
    wire [7:0]                   axi_arlen;
    wire [2:0]                   axi_arsize;
    wire [1:0]                   axi_arburst;
    reg                          axi_rvalid;
    wire                         axi_rready;
    reg  [AXI_ID_BITS-1:0]       axi_rid;
    reg  [AXI_DATA_BITS-1:0]     axi_rdata;
    reg  [1:0]                   axi_rresp;
    reg                          axi_rlast;

    reg  [AXI_ID_BITS-1:0]       cache_axi_id;
    reg  [AXI_ID_BITS-1:0]       bypass_axi_id;
    integer                      aw_count;
    integer                      w_count;
    integer                      b_count;

    task fail_now;
        input [8*160-1:0] msg;
        begin
            $display("tb_axi_llc_axi_bridge_write_outstanding_contract FAIL: %0s", msg);
            $finish(1);
        end
    endtask

    always #5 clk = ~clk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cache_axi_id <= {AXI_ID_BITS{1'b0}};
            bypass_axi_id <= {AXI_ID_BITS{1'b0}};
            aw_count <= 0;
            w_count <= 0;
            b_count <= 0;
        end else begin
            if (axi_awvalid && axi_awready) begin
                aw_count <= aw_count + 1;
                if (axi_awaddr == CACHE_ADDR) begin
                    cache_axi_id <= axi_awid;
                end
                if (axi_awaddr == BYPASS_ADDR) begin
                    bypass_axi_id <= axi_awid;
                end
            end
            if (axi_wvalid && axi_wready) begin
                w_count <= w_count + 1;
            end
            if (axi_bvalid && axi_bready) begin
                b_count <= b_count + 1;
            end
        end
    end

    axi_llc_axi_bridge dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .cache_req_valid  (cache_req_valid),
        .cache_req_ready  (cache_req_ready),
        .cache_req_write  (cache_req_write),
        .cache_req_addr   (cache_req_addr),
        .cache_req_id     (cache_req_id),
        .cache_req_size   (cache_req_size),
        .cache_req_wdata  (cache_req_wdata),
        .cache_req_wstrb  (cache_req_wstrb),
        .cache_resp_valid (cache_resp_valid),
        .cache_resp_ready (cache_resp_ready),
        .cache_resp_rdata (cache_resp_rdata),
        .cache_resp_id    (cache_resp_id),
        .cache_resp_code  (cache_resp_code),
        .bypass_req_valid (bypass_req_valid),
        .bypass_req_ready (bypass_req_ready),
        .bypass_req_write (bypass_req_write),
        .bypass_req_addr  (bypass_req_addr),
        .bypass_req_id    (bypass_req_id),
        .bypass_req_size  (bypass_req_size),
        .bypass_req_mode2_ddr_aligned(1'b0),
        .bypass_req_wdata (bypass_req_wdata),
        .bypass_req_wstrb (bypass_req_wstrb),
        .bypass_resp_valid(bypass_resp_valid),
        .bypass_resp_ready(bypass_resp_ready),
        .bypass_resp_rdata(bypass_resp_rdata),
        .bypass_resp_id   (bypass_resp_id),
        .bypass_resp_code (bypass_resp_code),
        .axi_awvalid      (axi_awvalid),
        .axi_awready      (axi_awready),
        .axi_awid         (axi_awid),
        .axi_awaddr       (axi_awaddr),
        .axi_awlen        (axi_awlen),
        .axi_awsize       (axi_awsize),
        .axi_awburst      (axi_awburst),
        .axi_wvalid       (axi_wvalid),
        .axi_wready       (axi_wready),
        .axi_wdata        (axi_wdata),
        .axi_wstrb        (axi_wstrb),
        .axi_wlast        (axi_wlast),
        .axi_bvalid       (axi_bvalid),
        .axi_bready       (axi_bready),
        .axi_bid          (axi_bid),
        .axi_bresp        (axi_bresp),
        .axi_arvalid      (axi_arvalid),
        .axi_arready      (axi_arready),
        .axi_arid         (axi_arid),
        .axi_araddr       (axi_araddr),
        .axi_arlen        (axi_arlen),
        .axi_arsize       (axi_arsize),
        .axi_arburst      (axi_arburst),
        .axi_rvalid       (axi_rvalid),
        .axi_rready       (axi_rready),
        .axi_rid          (axi_rid),
        .axi_rdata        (axi_rdata),
        .axi_rresp        (axi_rresp),
        .axi_rlast        (axi_rlast)
    );

    task clear_inputs;
        begin
            cache_req_valid = 1'b0;
            cache_req_write = 1'b0;
            cache_req_addr = {ADDR_BITS{1'b0}};
            cache_req_id = {ID_BITS{1'b0}};
            cache_req_size = 8'd0;
            cache_req_wdata = {LINE_BITS{1'b0}};
            cache_req_wstrb = {LINE_BYTES{1'b0}};
            bypass_req_valid = 1'b0;
            bypass_req_write = 1'b0;
            bypass_req_addr = {ADDR_BITS{1'b0}};
            bypass_req_id = {ID_BITS{1'b0}};
            bypass_req_size = 8'd0;
            bypass_req_wdata = {LINE_BITS{1'b0}};
            bypass_req_wstrb = {LINE_BYTES{1'b0}};
        end
    endtask

    task issue_cache_write;
        integer timeout;
        begin
            @(negedge clk);
            cache_req_valid = 1'b1;
            cache_req_write = 1'b1;
            cache_req_addr = CACHE_ADDR;
            cache_req_id = CACHE_ID;
            cache_req_size = LINE_BYTES - 1;
            cache_req_wdata = {16{32'hCAFE_0001}};
            cache_req_wstrb = {LINE_BYTES{1'b1}};
            timeout = 40;
            while (timeout > 0) begin
                @(posedge clk);
                if (cache_req_valid && cache_req_ready) begin
                    timeout = 0;
                end else begin
                    timeout = timeout - 1;
                end
            end
            if (!(cache_req_valid && cache_req_ready)) begin
                fail_now("cache write accept timeout");
            end
            @(negedge clk);
            cache_req_valid = 1'b0;
            cache_req_addr = {ADDR_BITS{1'b0}};
            cache_req_id = {ID_BITS{1'b0}};
            cache_req_size = 8'd0;
            cache_req_wdata = {LINE_BITS{1'b0}};
            cache_req_wstrb = {LINE_BYTES{1'b0}};
        end
    endtask

    task issue_bypass_write;
        integer timeout;
        begin
            @(negedge clk);
            bypass_req_valid = 1'b1;
            bypass_req_write = 1'b1;
            bypass_req_addr = BYPASS_ADDR;
            bypass_req_id = BYPASS_ID;
            bypass_req_size = 8'd3;
            bypass_req_wdata = {LINE_BITS{1'b0}};
            bypass_req_wdata[31:0] = 32'hDEAD_0042;
            bypass_req_wstrb = {LINE_BYTES{1'b0}};
            bypass_req_wstrb[3:0] = 4'hF;
            timeout = 40;
            while (timeout > 0) begin
                @(posedge clk);
                if (bypass_req_valid && bypass_req_ready) begin
                    timeout = 0;
                end else begin
                    timeout = timeout - 1;
                end
            end
            if (!(bypass_req_valid && bypass_req_ready)) begin
                fail_now("bypass write accept timeout");
            end
            @(negedge clk);
            bypass_req_valid = 1'b0;
            bypass_req_addr = {ADDR_BITS{1'b0}};
            bypass_req_id = {ID_BITS{1'b0}};
            bypass_req_size = 8'd0;
            bypass_req_wdata = {LINE_BITS{1'b0}};
            bypass_req_wstrb = {LINE_BYTES{1'b0}};
        end
    endtask

    task wait_two_aw;
        integer timeout;
        begin
            timeout = 80;
            while ((aw_count < 2) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            #1;
            if (aw_count != 2) begin
                fail_now("expected two AXI AW handshakes");
            end
            if ((^cache_axi_id === 1'bx) || (^bypass_axi_id === 1'bx)) begin
                fail_now("captured AXI write ids must be known");
            end
            if (cache_axi_id === bypass_axi_id) begin
                fail_now("cache/bypass outstanding writes must use distinct AXI ids");
            end
        end
    endtask

    task wait_w_beats;
        input integer expected_count;
        integer timeout;
        begin
            timeout = 80;
            while ((w_count < expected_count) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (w_count != expected_count) begin
                fail_now("unexpected AXI W handshake count");
            end
        end
    endtask

    task drive_b;
        input [AXI_ID_BITS-1:0] bid_value;
        input [1:0]             bresp_value;
        integer start_b_count;
        integer timeout;
        reg     handshake_seen;
        begin
            axi_bid = bid_value;
            axi_bresp = bresp_value;
            axi_bvalid = 1'b1;
            start_b_count = b_count;
            handshake_seen = 1'b0;
            timeout = 40;
            while ((timeout > 0) && !handshake_seen) begin
                @(posedge clk);
                #1;
                if (b_count != start_b_count) begin
                    handshake_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!handshake_seen) begin
                fail_now("AXI B handshake timeout");
            end
            @(negedge clk);
            axi_bvalid = 1'b0;
            axi_bid = {AXI_ID_BITS{1'b0}};
            axi_bresp = 2'b00;
        end
    endtask

    task wait_bypass_resp;
        integer timeout;
        begin
            timeout = 60;
            while (!bypass_resp_valid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (!bypass_resp_valid) begin
                fail_now("bypass write response timeout");
            end
            if (bypass_resp_id != BYPASS_ID) begin
                fail_now("bypass write response id mismatch");
            end
            if (bypass_resp_code != 2'b00) begin
                fail_now("bypass write response code mismatch");
            end
            if (bypass_resp_rdata != {READ_RESP_BITS{1'b0}}) begin
                fail_now("bypass write response data must be zero");
            end
        end
    endtask

    task consume_bypass_resp;
        begin
            @(negedge clk);
            bypass_resp_ready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            bypass_resp_ready = 1'b0;
        end
    endtask

    task wait_cache_resp;
        integer timeout;
        begin
            timeout = 60;
            while (!cache_resp_valid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (!cache_resp_valid) begin
                fail_now("cache write response timeout");
            end
            if (cache_resp_id != CACHE_ID) begin
                fail_now("cache write response id mismatch");
            end
            if (cache_resp_code != 2'b00) begin
                fail_now("cache write response code mismatch");
            end
            if (cache_resp_rdata != {READ_RESP_BITS{1'b0}}) begin
                fail_now("cache write response data must be zero");
            end
        end
    endtask

    task consume_cache_resp;
        begin
            @(negedge clk);
            cache_resp_ready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            cache_resp_ready = 1'b0;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        cache_resp_ready = 1'b0;
        bypass_resp_ready = 1'b0;
        axi_awready = 1'b1;
        axi_wready = 1'b1;
        axi_bvalid = 1'b0;
        axi_bid = {AXI_ID_BITS{1'b0}};
        axi_bresp = 2'b00;
        axi_arready = 1'b0;
        axi_rvalid = 1'b0;
        axi_rid = {AXI_ID_BITS{1'b0}};
        axi_rdata = {AXI_DATA_BITS{1'b0}};
        axi_rresp = 2'b00;
        axi_rlast = 1'b0;
        clear_inputs();

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        issue_cache_write();
        issue_bypass_write();
        wait_two_aw();
        wait_w_beats(3);

        drive_b(bypass_axi_id, 2'b00);
        if (cache_resp_valid) begin
            fail_now("cache write response must not appear before cache B completes");
        end
        wait_bypass_resp();
        consume_bypass_resp();

        drive_b(cache_axi_id, 2'b00);
        wait_cache_resp();
        consume_cache_resp();

        $display("tb_axi_llc_axi_bridge_write_outstanding_contract PASS");
        $finish(0);
    end

endmodule
