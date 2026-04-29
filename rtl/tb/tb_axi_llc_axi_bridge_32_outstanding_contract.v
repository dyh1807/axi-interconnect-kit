`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_axi_bridge_32_outstanding_contract;

    localparam ADDR_BITS       = `AXI_LLC_ADDR_BITS;
    localparam ID_BITS         = `AXI_LLC_SLOT_ID_BITS;
    localparam LINE_BYTES      = `AXI_LLC_LINE_BYTES;
    localparam LINE_BITS       = `AXI_LLC_LINE_BITS;
    localparam AXI_ID_BITS     = `AXI_LLC_AXI_ID_BITS;
    localparam AXI_DATA_BYTES  = `AXI_LLC_AXI_DATA_BYTES;
    localparam AXI_DATA_BITS   = `AXI_LLC_AXI_DATA_BITS;
    localparam AXI_STRB_BITS   = `AXI_LLC_AXI_STRB_BITS;
    localparam READ_RESP_BITS  = `AXI_LLC_READ_RESP_BITS;
    localparam integer LIMIT   = `AXI_LLC_MAX_OUTSTANDING;

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

    integer                      ar_count;
    integer                      aw_count;
    integer                      w_count;
    integer                      i;

    always #5 clk = ~clk;

    task fail_now;
        input [8*180-1:0] msg;
        begin
            $display("tb_axi_llc_axi_bridge_32_outstanding_contract FAIL: %0s", msg);
            $finish(1);
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ar_count <= 0;
            aw_count <= 0;
            w_count <= 0;
        end else begin
            if (axi_arvalid && axi_arready) begin
                ar_count <= ar_count + 1;
            end
            if (axi_awvalid && axi_awready) begin
                aw_count <= aw_count + 1;
            end
            if (axi_wvalid && axi_wready) begin
                w_count <= w_count + 1;
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

    task issue_bypass_read;
        input integer index;
        integer timeout;
        begin
            @(negedge clk);
            bypass_req_valid = 1'b1;
            bypass_req_write = 1'b0;
            bypass_req_addr = 32'h1000_0000 + (index * AXI_DATA_BYTES);
            bypass_req_id = index;
            bypass_req_size = 8'd3;
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
                fail_now("bypass read accept timeout");
            end
            @(negedge clk);
            clear_inputs();
        end
    endtask

    task issue_bypass_write;
        input integer index;
        integer timeout;
        begin
            @(negedge clk);
            bypass_req_valid = 1'b1;
            bypass_req_write = 1'b1;
            bypass_req_addr = 32'h2000_0000 + (index * AXI_DATA_BYTES);
            bypass_req_id = index;
            bypass_req_size = 8'd3;
            bypass_req_wdata = {LINE_BITS{1'b0}};
            bypass_req_wdata[31:0] = 32'hD00D_0000 + index;
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
            clear_inputs();
        end
    endtask

    task wait_count;
        input integer expected_ar;
        input integer expected_aw;
        input integer expected_w;
        integer timeout;
        begin
            timeout = 200;
            while (((ar_count < expected_ar) ||
                    (aw_count < expected_aw) ||
                    (w_count < expected_w)) &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if ((ar_count != expected_ar) ||
                (aw_count != expected_aw) ||
                (w_count != expected_w)) begin
                fail_now("AXI handshake count mismatch");
            end
        end
    endtask

    task expect_blocked_request;
        input is_write;
        integer cycles;
        begin
            @(negedge clk);
            bypass_req_valid = 1'b1;
            bypass_req_write = is_write;
            bypass_req_addr = is_write ? 32'h2000_F000 : 32'h1000_F000;
            bypass_req_id = LIMIT;
            bypass_req_size = 8'd3;
            bypass_req_wdata = {LINE_BITS{1'b0}};
            bypass_req_wstrb = {LINE_BYTES{1'b0}};
            bypass_req_wstrb[3:0] = 4'hF;
            for (cycles = 0; cycles < 4; cycles = cycles + 1) begin
                @(posedge clk);
                #1;
                if (bypass_req_ready) begin
                    if (is_write) begin
                        fail_now("33rd write was accepted");
                    end else begin
                        fail_now("33rd read was accepted");
                    end
                end
            end
            @(negedge clk);
            clear_inputs();
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
        axi_arready = 1'b1;
        axi_rvalid = 1'b0;
        axi_rid = {AXI_ID_BITS{1'b0}};
        axi_rdata = {AXI_DATA_BITS{1'b0}};
        axi_rresp = 2'b00;
        axi_rlast = 1'b0;
        clear_inputs();

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        for (i = 0; i < LIMIT; i = i + 1) begin
            issue_bypass_read(i);
        end
        wait_count(LIMIT, 0, 0);
        expect_blocked_request(1'b0);

        for (i = 0; i < LIMIT; i = i + 1) begin
            issue_bypass_write(i);
        end
        wait_count(LIMIT, LIMIT, LIMIT);
        expect_blocked_request(1'b1);

        $display("tb_axi_llc_axi_bridge_32_outstanding_contract PASS");
        $finish(0);
    end

endmodule
