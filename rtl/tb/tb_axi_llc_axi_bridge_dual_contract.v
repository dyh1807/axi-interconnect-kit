`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_axi_bridge_dual_contract;

    localparam ADDR_BITS       = `AXI_LLC_ADDR_BITS;
    localparam ID_BITS         = `AXI_LLC_SLOT_ID_BITS;
    localparam LINE_BYTES      = `AXI_LLC_LINE_BYTES;
    localparam LINE_BITS       = `AXI_LLC_LINE_BITS;
    localparam AXI_ID_BITS     = `AXI_LLC_AXI_ID_BITS;
    localparam DDR_DATA_BITS   = `AXI_LLC_AXI_DATA_BITS;
    localparam DDR_STRB_BITS   = `AXI_LLC_AXI_STRB_BITS;
    localparam MMIO_DATA_BITS  = 32;
    localparam MMIO_STRB_BITS  = 4;
    localparam READ_RESP_BITS  = `AXI_LLC_READ_RESP_BITS;
    localparam DDR_BASE        = 32'h4000_0000;

    reg                           clk;
    reg                           rst_n;
    reg                           cache_req_valid;
    wire                          cache_req_ready;
    reg                           cache_req_write;
    reg  [ADDR_BITS-1:0]          cache_req_addr;
    reg  [ID_BITS-1:0]            cache_req_id;
    reg  [7:0]                    cache_req_size;
    reg  [LINE_BITS-1:0]          cache_req_wdata;
    reg  [LINE_BYTES-1:0]         cache_req_wstrb;
    wire                          cache_resp_valid;
    reg                           cache_resp_ready;
    wire [READ_RESP_BITS-1:0]     cache_resp_rdata;
    wire [ID_BITS-1:0]            cache_resp_id;
    wire [1:0]                    cache_resp_code;
    reg                           bypass_req_valid;
    wire                          bypass_req_ready;
    reg                           bypass_req_write;
    reg  [ADDR_BITS-1:0]          bypass_req_addr;
    reg  [ID_BITS-1:0]            bypass_req_id;
    reg  [7:0]                    bypass_req_size;
    reg                           bypass_req_mode2_ddr_aligned;
    reg  [LINE_BITS-1:0]          bypass_req_wdata;
    reg  [LINE_BYTES-1:0]         bypass_req_wstrb;
    wire                          bypass_resp_valid;
    reg                           bypass_resp_ready;
    wire [READ_RESP_BITS-1:0]     bypass_resp_rdata;
    wire [ID_BITS-1:0]            bypass_resp_id;
    wire [1:0]                    bypass_resp_code;

    wire                          ddr_axi_awvalid;
    reg                           ddr_axi_awready;
    wire [AXI_ID_BITS-1:0]        ddr_axi_awid;
    wire [ADDR_BITS-1:0]          ddr_axi_awaddr;
    wire [7:0]                    ddr_axi_awlen;
    wire [2:0]                    ddr_axi_awsize;
    wire [1:0]                    ddr_axi_awburst;
    wire                          ddr_axi_wvalid;
    reg                           ddr_axi_wready;
    wire [DDR_DATA_BITS-1:0]      ddr_axi_wdata;
    wire [DDR_STRB_BITS-1:0]      ddr_axi_wstrb;
    wire                          ddr_axi_wlast;
    reg                           ddr_axi_bvalid;
    wire                          ddr_axi_bready;
    reg  [AXI_ID_BITS-1:0]        ddr_axi_bid;
    reg  [1:0]                    ddr_axi_bresp;
    wire                          ddr_axi_arvalid;
    reg                           ddr_axi_arready;
    wire [AXI_ID_BITS-1:0]        ddr_axi_arid;
    wire [ADDR_BITS-1:0]          ddr_axi_araddr;
    wire [7:0]                    ddr_axi_arlen;
    wire [2:0]                    ddr_axi_arsize;
    wire [1:0]                    ddr_axi_arburst;
    reg                           ddr_axi_rvalid;
    wire                          ddr_axi_rready;
    reg  [AXI_ID_BITS-1:0]        ddr_axi_rid;
    reg  [DDR_DATA_BITS-1:0]      ddr_axi_rdata;
    reg  [1:0]                    ddr_axi_rresp;
    reg                           ddr_axi_rlast;

    wire                          mmio_axi_awvalid;
    reg                           mmio_axi_awready;
    wire [AXI_ID_BITS-1:0]        mmio_axi_awid;
    wire [ADDR_BITS-1:0]          mmio_axi_awaddr;
    wire [7:0]                    mmio_axi_awlen;
    wire [2:0]                    mmio_axi_awsize;
    wire [1:0]                    mmio_axi_awburst;
    wire                          mmio_axi_wvalid;
    reg                           mmio_axi_wready;
    wire [MMIO_DATA_BITS-1:0]     mmio_axi_wdata;
    wire [MMIO_STRB_BITS-1:0]     mmio_axi_wstrb;
    wire                          mmio_axi_wlast;
    reg                           mmio_axi_bvalid;
    wire                          mmio_axi_bready;
    reg  [AXI_ID_BITS-1:0]        mmio_axi_bid;
    reg  [1:0]                    mmio_axi_bresp;
    wire                          mmio_axi_arvalid;
    reg                           mmio_axi_arready;
    wire [AXI_ID_BITS-1:0]        mmio_axi_arid;
    wire [ADDR_BITS-1:0]          mmio_axi_araddr;
    wire [7:0]                    mmio_axi_arlen;
    wire [2:0]                    mmio_axi_arsize;
    wire [1:0]                    mmio_axi_arburst;
    reg                           mmio_axi_rvalid;
    wire                          mmio_axi_rready;
    reg  [AXI_ID_BITS-1:0]        mmio_axi_rid;
    reg  [MMIO_DATA_BITS-1:0]     mmio_axi_rdata;
    reg  [1:0]                    mmio_axi_rresp;
    reg                           mmio_axi_rlast;

    reg [AXI_ID_BITS-1:0]         captured_ddr_arid;
    reg [AXI_ID_BITS-1:0]         captured_ddr_awid;
    reg [AXI_ID_BITS-1:0]         captured_mmio_arid;
    reg [AXI_ID_BITS-1:0]         captured_mmio_awid;

    always #5 clk = ~clk;

    task fail_now;
        input [8*180-1:0] msg;
        begin
            $display("tb_axi_llc_axi_bridge_dual_contract FAIL: %0s", msg);
            $finish(1);
        end
    endtask

    task clear_inputs;
        begin
            cache_req_valid = 1'b0;
            cache_req_write = 1'b0;
            cache_req_addr = {ADDR_BITS{1'b0}};
            cache_req_id = {ID_BITS{1'b0}};
            cache_req_size = 8'd0;
            cache_req_wdata = {LINE_BITS{1'b0}};
            cache_req_wstrb = {LINE_BYTES{1'b0}};
            cache_resp_ready = 1'b1;
            bypass_req_valid = 1'b0;
            bypass_req_write = 1'b0;
            bypass_req_addr = {ADDR_BITS{1'b0}};
            bypass_req_id = {ID_BITS{1'b0}};
            bypass_req_size = 8'd0;
            bypass_req_mode2_ddr_aligned = 1'b0;
            bypass_req_wdata = {LINE_BITS{1'b0}};
            bypass_req_wstrb = {LINE_BYTES{1'b0}};
            bypass_resp_ready = 1'b1;
            ddr_axi_awready = 1'b1;
            ddr_axi_wready = 1'b1;
            ddr_axi_bvalid = 1'b0;
            ddr_axi_bid = {AXI_ID_BITS{1'b0}};
            ddr_axi_bresp = 2'b00;
            ddr_axi_arready = 1'b1;
            ddr_axi_rvalid = 1'b0;
            ddr_axi_rid = {AXI_ID_BITS{1'b0}};
            ddr_axi_rdata = {DDR_DATA_BITS{1'b0}};
            ddr_axi_rresp = 2'b00;
            ddr_axi_rlast = 1'b0;
            mmio_axi_awready = 1'b1;
            mmio_axi_wready = 1'b1;
            mmio_axi_bvalid = 1'b0;
            mmio_axi_bid = {AXI_ID_BITS{1'b0}};
            mmio_axi_bresp = 2'b00;
            mmio_axi_arready = 1'b1;
            mmio_axi_rvalid = 1'b0;
            mmio_axi_rid = {AXI_ID_BITS{1'b0}};
            mmio_axi_rdata = {MMIO_DATA_BITS{1'b0}};
            mmio_axi_rresp = 2'b00;
            mmio_axi_rlast = 1'b0;
        end
    endtask

    task reset_dut;
        begin
            clk = 1'b0;
            rst_n = 1'b0;
            clear_inputs();
            repeat (4) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;
            @(negedge clk);
        end
    endtask

    task wait_dual_ar;
        integer timeout;
        begin
            timeout = 0;
            while (!(ddr_axi_arvalid && mmio_axi_arvalid) && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!(ddr_axi_arvalid && mmio_axi_arvalid)) begin
                fail_now("DDR/MMIO AR did not become concurrently valid");
            end
        end
    endtask

    task send_mmio_read_resp;
        input [AXI_ID_BITS-1:0] id;
        input [31:0] data_word;
        integer timeout;
        begin
            @(negedge clk);
            mmio_axi_rvalid = 1'b1;
            mmio_axi_rid = id;
            mmio_axi_rdata = data_word;
            mmio_axi_rresp = 2'b00;
            mmio_axi_rlast = 1'b1;
            #1;
            if (!mmio_axi_rready) begin
                fail_now("MMIO R was not accepted");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_rvalid = 1'b0;
            mmio_axi_rlast = 1'b0;
            timeout = 0;
            while (!bypass_resp_valid && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!bypass_resp_valid || bypass_resp_id != 4'h9 ||
                bypass_resp_rdata[31:0] != data_word) begin
                fail_now("MMIO read response did not return to bypass source");
            end
            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task send_ddr_read_resp;
        input [AXI_ID_BITS-1:0] id;
        input [31:0] data_word;
        integer timeout;
        begin
            @(negedge clk);
            ddr_axi_rvalid = 1'b1;
            ddr_axi_rid = id;
            ddr_axi_rdata = {DDR_DATA_BITS{1'b0}};
            ddr_axi_rdata[31:0] = 32'h1111_0001;
            ddr_axi_rresp = 2'b00;
            ddr_axi_rlast = 1'b0;
            #1;
            if (!ddr_axi_rready) begin
                fail_now("DDR first R beat was not accepted");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rdata[31:0] = data_word;
            ddr_axi_rlast = 1'b1;
            #1;
            if (!ddr_axi_rready) begin
                fail_now("DDR last R beat was not accepted");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;
            ddr_axi_rlast = 1'b0;
            timeout = 0;
            while (!cache_resp_valid && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!cache_resp_valid || cache_resp_id != 4'h3 ||
                cache_resp_rdata[31:0] != 32'h1111_0001) begin
                fail_now("DDR cache read response did not return to cache source");
            end
            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task send_ddr_bypass_write_resp;
        input [AXI_ID_BITS-1:0] id;
        input [ID_BITS-1:0] expected_id;
        integer timeout;
        begin
            @(negedge clk);
            ddr_axi_bvalid = 1'b1;
            ddr_axi_bid = id;
            ddr_axi_bresp = 2'b00;
            #1;
            if (!ddr_axi_bready) begin
                fail_now("DDR B was not accepted");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_bvalid = 1'b0;
            timeout = 0;
            while (!bypass_resp_valid && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!bypass_resp_valid || bypass_resp_id != expected_id ||
                bypass_resp_code != 2'b00) begin
                fail_now("DDR write response did not return to bypass source");
            end
            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task issue_ddr_cache_read;
        input [ADDR_BITS-1:0] addr;
        input [ID_BITS-1:0] id;
        begin
            @(negedge clk);
            cache_req_valid = 1'b1;
            cache_req_write = 1'b0;
            cache_req_addr = addr;
            cache_req_id = id;
            cache_req_size = 8'd63;
            #1;
            if (!cache_req_ready) begin
                fail_now("DDR cache read request was not accepted");
            end
            @(posedge clk);
            @(negedge clk);
            cache_req_valid = 1'b0;
        end
    endtask

    task issue_ddr_bypass_word_write;
        input [ADDR_BITS-1:0] addr;
        input [ID_BITS-1:0] id;
        input [31:0] data_word;
        begin
            @(negedge clk);
            bypass_req_valid = 1'b1;
            bypass_req_write = 1'b1;
            bypass_req_addr = addr;
            bypass_req_id = id;
            bypass_req_size = 8'd3;
            bypass_req_wdata = {LINE_BITS{1'b0}};
            bypass_req_wdata[31:0] = data_word;
            bypass_req_wstrb = {LINE_BYTES{1'b0}};
            bypass_req_wstrb[3:0] = 4'hF;
            #1;
            if (!bypass_req_ready) begin
                fail_now("DDR bypass write request was not accepted");
            end
            @(posedge clk);
            @(negedge clk);
            bypass_req_valid = 1'b0;
        end
    endtask

    task wait_ddr_ar;
        input [ADDR_BITS-1:0] expected_addr;
        integer timeout;
        begin
            timeout = 0;
            while (!ddr_axi_arvalid && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!ddr_axi_arvalid) begin
                fail_now("DDR AR did not become valid");
            end
            if (ddr_axi_araddr != expected_addr) begin
                fail_now("DDR AR address mismatch");
            end
            captured_ddr_arid = ddr_axi_arid;
            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task wait_ddr_aw_and_w;
        input [ADDR_BITS-1:0] expected_addr;
        integer timeout;
        begin
            timeout = 0;
            while (!ddr_axi_awvalid && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!ddr_axi_awvalid) begin
                fail_now("DDR AW did not become valid");
            end
            if (ddr_axi_awaddr != expected_addr) begin
                fail_now("DDR AW address mismatch");
            end
            captured_ddr_awid = ddr_axi_awid;
            @(posedge clk);
            @(negedge clk);
            timeout = 0;
            while (!ddr_axi_wvalid && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!ddr_axi_wvalid || !ddr_axi_wlast) begin
                fail_now("DDR W did not become valid as one beat");
            end
            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task test_mixed_read_concurrent_issue;
        begin
            @(negedge clk);
            cache_req_valid = 1'b1;
            cache_req_write = 1'b0;
            cache_req_addr = DDR_BASE + 32'h0000_0100;
            cache_req_id = 4'h3;
            cache_req_size = 8'd63;
            bypass_req_valid = 1'b1;
            bypass_req_write = 1'b0;
            bypass_req_addr = 32'h1000_0004;
            bypass_req_id = 4'h9;
            bypass_req_size = 8'd3;
            #1;
            if (!cache_req_ready || !bypass_req_ready) begin
                fail_now("DDR cache and MMIO bypass reads were not both accepted");
            end
            @(posedge clk);
            @(negedge clk);
            cache_req_valid = 1'b0;
            bypass_req_valid = 1'b0;
            wait_dual_ar();
            if (ddr_axi_araddr != DDR_BASE + 32'h0000_0100 ||
                ddr_axi_arlen != 8'd1 || ddr_axi_arsize != 3'd5) begin
                fail_now("DDR read shape mismatch");
            end
            if (mmio_axi_araddr != 32'h1000_0004 ||
                mmio_axi_arlen != 8'd0 || mmio_axi_arsize != 3'd2) begin
                fail_now("MMIO read shape mismatch");
            end
            captured_ddr_arid = ddr_axi_arid;
            captured_mmio_arid = mmio_axi_arid;
            @(posedge clk);
            @(negedge clk);
            send_mmio_read_resp(captured_mmio_arid, 32'hA5A5_0009);
            send_ddr_read_resp(captured_ddr_arid, 32'hD00D_0003);
        end
    endtask

    task issue_mmio_cache_word_read;
        input [ADDR_BITS-1:0] addr;
        input [ID_BITS-1:0] id;
        begin
            @(negedge clk);
            cache_req_valid = 1'b1;
            cache_req_write = 1'b0;
            cache_req_addr = addr;
            cache_req_id = id;
            cache_req_size = 8'd3;
            #1;
            if (!cache_req_ready) begin
                fail_now("MMIO cache read request was not accepted");
            end
            @(posedge clk);
            @(negedge clk);
            cache_req_valid = 1'b0;
        end
    endtask

    task wait_mmio_ar;
        input [ADDR_BITS-1:0] expected_addr;
        integer timeout;
        begin
            timeout = 0;
            while (!mmio_axi_arvalid && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!mmio_axi_arvalid) begin
                fail_now("MMIO AR did not become valid");
            end
            if (mmio_axi_araddr != expected_addr ||
                mmio_axi_arlen != 8'd0 ||
                mmio_axi_arsize != 3'd2) begin
                fail_now("MMIO AR shape mismatch");
            end
            captured_mmio_arid = mmio_axi_arid;
            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task test_cache_resp_mux_does_not_backpressure_external_r;
        integer timeout;
        reg [AXI_ID_BITS-1:0] ddr_id;
        reg [AXI_ID_BITS-1:0] mmio_id;
        begin
            cache_resp_ready = 1'b0;

            issue_ddr_cache_read(DDR_BASE + 32'h0000_0B00, 4'h4);
            wait_ddr_ar(DDR_BASE + 32'h0000_0B00);
            ddr_id = captured_ddr_arid;

            issue_mmio_cache_word_read(32'h1000_0030, 4'h6);
            wait_mmio_ar(32'h1000_0030);
            mmio_id = captured_mmio_arid;

            @(negedge clk);
            ddr_axi_rvalid = 1'b1;
            ddr_axi_rid = ddr_id;
            ddr_axi_rdata = {DDR_DATA_BITS{1'b0}};
            ddr_axi_rdata[31:0] = 32'h1111_0B00;
            ddr_axi_rresp = 2'b00;
            ddr_axi_rlast = 1'b0;
            #1;
            if (!ddr_axi_rready) begin
                fail_now("DDR first R was backpressured before mux conflict");
            end
            @(posedge clk);
            @(negedge clk);

            ddr_axi_rdata = {DDR_DATA_BITS{1'b0}};
            ddr_axi_rdata[31:0] = 32'h2222_0B00;
            ddr_axi_rlast = 1'b1;
            mmio_axi_rvalid = 1'b1;
            mmio_axi_rid = mmio_id;
            mmio_axi_rdata = 32'hA5A5_0B00;
            mmio_axi_rresp = 2'b00;
            mmio_axi_rlast = 1'b1;
            #1;
            if (!ddr_axi_rready) begin
                fail_now("DDR last R was backpressured by cache resp mux stall");
            end
            if (!mmio_axi_rready) begin
                fail_now("MMIO R was backpressured by cache resp mux stall");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;
            ddr_axi_rlast = 1'b0;
            mmio_axi_rvalid = 1'b0;
            mmio_axi_rlast = 1'b0;

            timeout = 0;
            while (!cache_resp_valid && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!cache_resp_valid ||
                cache_resp_id != 4'h6 ||
                cache_resp_rdata[31:0] != 32'hA5A5_0B00) begin
                fail_now("MMIO cache response was not buffered first");
            end

            cache_resp_ready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            cache_resp_ready = 1'b0;

            timeout = 0;
            while ((!cache_resp_valid || cache_resp_id != 4'h4) && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!cache_resp_valid ||
                cache_resp_id != 4'h4 ||
                cache_resp_rdata[31:0] != 32'h1111_0B00) begin
                fail_now("DDR cache response was not buffered behind MMIO response");
            end
            cache_resp_ready = 1'b1;
            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task issue_mmio_cache_word_write;
        input [ADDR_BITS-1:0] addr;
        input [ID_BITS-1:0] id;
        input [31:0] data_word;
        begin
            @(negedge clk);
            cache_req_valid = 1'b1;
            cache_req_write = 1'b1;
            cache_req_addr = addr;
            cache_req_id = id;
            cache_req_size = 8'd3;
            cache_req_wdata = {LINE_BITS{1'b0}};
            cache_req_wdata[31:0] = data_word;
            cache_req_wstrb = {LINE_BYTES{1'b0}};
            cache_req_wstrb[3:0] = 4'hF;
            #1;
            if (!cache_req_ready) begin
                fail_now("MMIO cache write request was not accepted");
            end
            @(posedge clk);
            @(negedge clk);
            cache_req_valid = 1'b0;
        end
    endtask

    task test_cache_resp_mux_does_not_backpressure_external_b;
        integer timeout;
        reg [AXI_ID_BITS-1:0] ddr_id;
        reg [AXI_ID_BITS-1:0] mmio_id;
        begin
            cache_resp_ready = 1'b0;
            ddr_axi_awready = 1'b0;
            ddr_axi_wready = 1'b0;
            mmio_axi_awready = 1'b0;
            mmio_axi_wready = 1'b0;

            @(negedge clk);
            cache_req_valid = 1'b1;
            cache_req_write = 1'b1;
            cache_req_addr = DDR_BASE + 32'h0000_0C00;
            cache_req_id = 4'h7;
            cache_req_size = 8'd63;
            cache_req_wdata = {LINE_BITS{1'b0}};
            cache_req_wdata[63:0] = 64'h1122_3344_5566_7788;
            cache_req_wstrb = {LINE_BYTES{1'b1}};
            #1;
            if (!cache_req_ready) begin
                fail_now("DDR cache write request was not accepted");
            end
            @(posedge clk);
            @(negedge clk);
            cache_req_valid = 1'b0;

            timeout = 0;
            while (!ddr_axi_awvalid && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!ddr_axi_awvalid ||
                ddr_axi_awaddr != DDR_BASE + 32'h0000_0C00 ||
                ddr_axi_awlen != 8'd1 ||
                ddr_axi_awsize != 3'd5) begin
                fail_now("DDR cache write AW shape mismatch in B mux test");
            end
            ddr_id = ddr_axi_awid;
            ddr_axi_awready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_awready = 1'b0;

            timeout = 0;
            while (!ddr_axi_wvalid && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!ddr_axi_wvalid || ddr_axi_wlast) begin
                fail_now("DDR cache write first W shape mismatch in B mux test");
            end
            ddr_axi_wready = 1'b1;
            @(posedge clk);
            @(negedge clk);

            timeout = 0;
            while (!ddr_axi_wvalid && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!ddr_axi_wvalid || !ddr_axi_wlast) begin
                fail_now("DDR cache write last W shape mismatch in B mux test");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_wready = 1'b0;

            issue_mmio_cache_word_write(32'h1000_0040, 4'h8, 32'hCAFE_0C00);

            timeout = 0;
            while (!mmio_axi_awvalid && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!mmio_axi_awvalid ||
                mmio_axi_awaddr != 32'h1000_0040 ||
                mmio_axi_awlen != 8'd0 ||
                mmio_axi_awsize != 3'd2) begin
                fail_now("MMIO cache write AW shape mismatch in B mux test");
            end
            mmio_id = mmio_axi_awid;
            mmio_axi_awready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_awready = 1'b0;

            timeout = 0;
            while (!mmio_axi_wvalid && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!mmio_axi_wvalid ||
                mmio_axi_wdata != 32'hCAFE_0C00 ||
                mmio_axi_wstrb != 4'hF ||
                !mmio_axi_wlast) begin
                fail_now("MMIO cache write W shape mismatch in B mux test");
            end
            mmio_axi_wready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_wready = 1'b0;

            ddr_axi_bvalid = 1'b1;
            ddr_axi_bid = ddr_id;
            ddr_axi_bresp = 2'b00;
            mmio_axi_bvalid = 1'b1;
            mmio_axi_bid = mmio_id;
            mmio_axi_bresp = 2'b01;
            #1;
            if (!ddr_axi_bready) begin
                fail_now("DDR B was backpressured by cache resp mux stall");
            end
            if (!mmio_axi_bready) begin
                fail_now("MMIO B was backpressured by cache resp mux stall");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_bvalid = 1'b0;
            mmio_axi_bvalid = 1'b0;

            timeout = 0;
            while (!cache_resp_valid && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!cache_resp_valid ||
                cache_resp_id != 4'h8 ||
                cache_resp_code != 2'b01) begin
                fail_now("MMIO cache write response was not buffered first");
            end
            cache_resp_ready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            cache_resp_ready = 1'b0;

            timeout = 0;
            while ((!cache_resp_valid || cache_resp_id != 4'h7) && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!cache_resp_valid ||
                cache_resp_id != 4'h7 ||
                cache_resp_code != 2'b00) begin
                fail_now("DDR cache write response was not buffered behind MMIO response");
            end
            cache_resp_ready = 1'b1;
            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task test_mixed_write_concurrent_issue;
        integer timeout;
        begin
            ddr_axi_awready = 1'b0;
            ddr_axi_wready = 1'b0;
            mmio_axi_awready = 1'b0;
            mmio_axi_wready = 1'b0;

            @(negedge clk);
            cache_req_valid = 1'b1;
            cache_req_write = 1'b1;
            cache_req_addr = DDR_BASE + 32'h0000_0200;
            cache_req_id = 4'h5;
            cache_req_size = 8'd63;
            cache_req_wdata = {LINE_BITS{1'b0}};
            cache_req_wdata[63:0] = 64'h5566_7788_1122_3344;
            cache_req_wstrb = {LINE_BYTES{1'b1}};
            bypass_req_valid = 1'b1;
            bypass_req_write = 1'b1;
            bypass_req_addr = 32'h1000_0024;
            bypass_req_id = 4'hA;
            bypass_req_size = 8'd3;
            bypass_req_wdata = {LINE_BITS{1'b0}};
            bypass_req_wdata[31:0] = 32'hCAFE_0204;
            bypass_req_wstrb = {LINE_BYTES{1'b0}};
            bypass_req_wstrb[3:0] = 4'hF;
            #1;
            if (!cache_req_ready || !bypass_req_ready) begin
                fail_now("DDR cache and MMIO bypass writes were not both accepted");
            end
            @(posedge clk);
            @(negedge clk);
            cache_req_valid = 1'b0;
            bypass_req_valid = 1'b0;

            timeout = 0;
            while (!(ddr_axi_awvalid && mmio_axi_awvalid) && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!(ddr_axi_awvalid && mmio_axi_awvalid)) begin
                fail_now("DDR/MMIO AW did not become concurrently valid");
            end
            if (ddr_axi_awaddr != DDR_BASE + 32'h0000_0200 ||
                ddr_axi_awlen != 8'd1 || ddr_axi_awsize != 3'd5) begin
                fail_now("DDR write AW shape mismatch");
            end
            if (mmio_axi_awaddr != 32'h1000_0024 ||
                mmio_axi_awlen != 8'd0 || mmio_axi_awsize != 3'd2) begin
                fail_now("MMIO write AW shape mismatch in mixed write");
            end
            captured_ddr_awid = ddr_axi_awid;
            captured_mmio_awid = mmio_axi_awid;

            ddr_axi_awready = 1'b1;
            mmio_axi_awready = 1'b1;
            @(posedge clk);
            @(negedge clk);

            timeout = 0;
            while (!(ddr_axi_wvalid && mmio_axi_wvalid) && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!(ddr_axi_wvalid && mmio_axi_wvalid)) begin
                fail_now("DDR/MMIO W did not become concurrently valid after AW");
            end
            if (ddr_axi_wlast) begin
                fail_now("DDR first write beat should not be last");
            end
            if (ddr_axi_wdata[63:0] != 64'h5566_7788_1122_3344 ||
                ddr_axi_wstrb != {DDR_STRB_BITS{1'b1}}) begin
                fail_now("DDR first write beat data/strobe mismatch");
            end
            if (mmio_axi_wdata != 32'hCAFE_0204 || mmio_axi_wstrb != 4'hF ||
                !mmio_axi_wlast) begin
                fail_now("MMIO write W shape mismatch in mixed write");
            end

            ddr_axi_wready = 1'b1;
            mmio_axi_wready = 1'b1;
            @(posedge clk);
            @(negedge clk);

            timeout = 0;
            while (!ddr_axi_wvalid && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!ddr_axi_wvalid || !ddr_axi_wlast) begin
                fail_now("DDR second write beat did not become last");
            end
            @(posedge clk);
            @(negedge clk);

            mmio_axi_bvalid = 1'b1;
            mmio_axi_bid = captured_mmio_awid;
            mmio_axi_bresp = 2'b01;
            #1;
            if (!mmio_axi_bready) begin
                fail_now("MMIO B was not accepted in mixed write");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_bvalid = 1'b0;

            timeout = 0;
            while (!bypass_resp_valid && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!bypass_resp_valid || bypass_resp_id != 4'hA ||
                bypass_resp_code != 2'b01) begin
                fail_now("MMIO mixed write response did not return to bypass source");
            end
            if (cache_resp_valid) begin
                fail_now("DDR cache write response appeared before DDR B");
            end
            @(posedge clk);
            @(negedge clk);

            ddr_axi_bvalid = 1'b1;
            ddr_axi_bid = captured_ddr_awid;
            ddr_axi_bresp = 2'b00;
            #1;
            if (!ddr_axi_bready) begin
                fail_now("DDR B was not accepted in mixed write");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_bvalid = 1'b0;

            timeout = 0;
            while (!cache_resp_valid && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!cache_resp_valid || cache_resp_id != 4'h5 ||
                cache_resp_code != 2'b00) begin
                fail_now("DDR mixed write response did not return to cache source");
            end
            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task test_mmio_write_shape;
        integer timeout;
        begin
            @(negedge clk);
            bypass_req_valid = 1'b1;
            bypass_req_write = 1'b1;
            bypass_req_addr = 32'h1000_0020;
            bypass_req_id = 4'hA;
            bypass_req_size = 8'd3;
            bypass_req_wdata = {LINE_BITS{1'b0}};
            bypass_req_wdata[31:0] = 32'hCAFE_BABE;
            bypass_req_wstrb = {LINE_BYTES{1'b0}};
            bypass_req_wstrb[3:0] = 4'hF;
            #1;
            if (!bypass_req_ready) begin
                fail_now("MMIO write request was not accepted");
            end
            @(posedge clk);
            @(negedge clk);
            bypass_req_valid = 1'b0;
            timeout = 0;
            while (!mmio_axi_awvalid && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!mmio_axi_awvalid) begin
                fail_now("MMIO AW did not become valid");
            end
            if (ddr_axi_awvalid) begin
                fail_now("MMIO AW leaked to DDR AXI port");
            end
            if (mmio_axi_awaddr != 32'h1000_0020 || mmio_axi_awlen != 8'd0 ||
                mmio_axi_awsize != 3'd2) begin
                fail_now("MMIO AW shape mismatch");
            end
            captured_mmio_awid = mmio_axi_awid;
            @(posedge clk);
            @(negedge clk);
            timeout = 0;
            while (!mmio_axi_wvalid && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!mmio_axi_wvalid) begin
                fail_now("MMIO W did not become valid");
            end
            if (ddr_axi_wvalid) begin
                fail_now("MMIO W leaked to DDR AXI port");
            end
            if (mmio_axi_wdata != 32'hCAFE_BABE || mmio_axi_wstrb != 4'hF ||
                !mmio_axi_wlast) begin
                fail_now("MMIO W shape mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_bvalid = 1'b1;
            mmio_axi_bid = captured_mmio_awid;
            mmio_axi_bresp = 2'b00;
            #1;
            if (!mmio_axi_bready) begin
                fail_now("MMIO B was not accepted");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_bvalid = 1'b0;
            timeout = 0;
            while (!bypass_resp_valid && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!bypass_resp_valid || bypass_resp_id != 4'hA ||
                bypass_resp_code != 2'b00) begin
                fail_now("MMIO write response did not return to bypass source");
            end
            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task test_unsupported_mmio_line_blocks;
        begin
            @(negedge clk);
            cache_req_valid = 1'b1;
            cache_req_write = 1'b0;
            cache_req_addr = 32'h1000_1000;
            cache_req_id = 4'h1;
            cache_req_size = 8'd63;
            #1;
            if (cache_req_ready) begin
                fail_now("large MMIO cache request should be blocked");
            end
            @(negedge clk);
            cache_req_valid = 1'b0;
        end
    endtask

    task test_read_blocks_same_line_write;
        integer timeout;
        begin
            issue_ddr_cache_read(DDR_BASE + 32'h0000_0300, 4'h3);
            wait_ddr_ar(DDR_BASE + 32'h0000_0300);

            issue_ddr_bypass_word_write(DDR_BASE + 32'h0000_0320, 4'hB,
                                        32'hB10C_0001);
            for (timeout = 0; timeout < 5; timeout = timeout + 1) begin
                #1;
                if (ddr_axi_awvalid || ddr_axi_wvalid) begin
                    fail_now("same-line AW/W escaped before read completed");
                end
                @(negedge clk);
            end

            ddr_axi_awready = 1'b0;
            ddr_axi_wready = 1'b0;
            send_ddr_read_resp(captured_ddr_arid, 32'hD00D_0300);
            ddr_axi_awready = 1'b1;
            ddr_axi_wready = 1'b1;
            wait_ddr_aw_and_w(DDR_BASE + 32'h0000_0320);
            send_ddr_bypass_write_resp(captured_ddr_awid, 4'hB);
        end
    endtask

    task test_rready_ignores_response_backpressure;
        integer timeout;
        begin
            issue_ddr_cache_read(DDR_BASE + 32'h0000_0900, 4'h3);
            wait_ddr_ar(DDR_BASE + 32'h0000_0900);

            issue_ddr_bypass_word_write(DDR_BASE + 32'h0000_0920, 4'hE,
                                        32'hB10C_0004);
            repeat (3) begin
                #1;
                if (ddr_axi_awvalid || ddr_axi_wvalid) begin
                    fail_now("same-line write escaped before R was accepted");
                end
                @(negedge clk);
            end

            cache_resp_ready = 1'b0;
            ddr_axi_awready = 1'b0;
            ddr_axi_wready = 1'b0;
            @(negedge clk);
            ddr_axi_rvalid = 1'b1;
            ddr_axi_rid = captured_ddr_arid;
            ddr_axi_rdata = {DDR_DATA_BITS{1'b0}};
            ddr_axi_rdata[31:0] = 32'h1111_0900;
            ddr_axi_rresp = 2'b00;
            ddr_axi_rlast = 1'b0;
            #1;
            if (!ddr_axi_rready) begin
                fail_now("DDR first R was backpressured by upstream resp stall");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rdata[31:0] = 32'h2222_0900;
            ddr_axi_rlast = 1'b1;
            #1;
            if (!ddr_axi_rready) begin
                fail_now("DDR last R was backpressured by upstream resp stall");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;
            ddr_axi_rlast = 1'b0;

            timeout = 0;
            while (!cache_resp_valid && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!cache_resp_valid || cache_resp_id != 4'h3 ||
                cache_resp_rdata[31:0] != 32'h1111_0900) begin
                fail_now("read response was not buffered while upstream stalled");
            end

            ddr_axi_awready = 1'b1;
            ddr_axi_wready = 1'b1;
            wait_ddr_aw_and_w(DDR_BASE + 32'h0000_0920);
            cache_resp_ready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            send_ddr_bypass_write_resp(captured_ddr_awid, 4'hE);
        end
    endtask

    task test_write_blocks_same_line_read;
        integer timeout;
        begin
            issue_ddr_bypass_word_write(DDR_BASE + 32'h0000_0400, 4'hC,
                                        32'hB10C_0002);
            wait_ddr_aw_and_w(DDR_BASE + 32'h0000_0400);

            issue_ddr_cache_read(DDR_BASE + 32'h0000_0420, 4'h3);
            for (timeout = 0; timeout < 5; timeout = timeout + 1) begin
                #1;
                if (ddr_axi_arvalid) begin
                    fail_now("same-line AR escaped before write completed");
                end
                @(negedge clk);
            end

            ddr_axi_arready = 1'b0;
            send_ddr_bypass_write_resp(captured_ddr_awid, 4'hC);
            ddr_axi_arready = 1'b1;
            wait_ddr_ar(DDR_BASE + 32'h0000_0420);
            send_ddr_read_resp(captured_ddr_arid, 32'hD00D_0400);
        end
    endtask

    task test_bready_ignores_response_backpressure;
        integer timeout;
        begin
            issue_ddr_bypass_word_write(DDR_BASE + 32'h0000_0A00, 4'hF,
                                        32'hB10C_0005);
            wait_ddr_aw_and_w(DDR_BASE + 32'h0000_0A00);

            issue_ddr_cache_read(DDR_BASE + 32'h0000_0A20, 4'h3);
            repeat (3) begin
                #1;
                if (ddr_axi_arvalid) begin
                    fail_now("same-line read escaped before B was accepted");
                end
                @(negedge clk);
            end

            bypass_resp_ready = 1'b0;
            ddr_axi_arready = 1'b0;
            @(negedge clk);
            ddr_axi_bvalid = 1'b1;
            ddr_axi_bid = captured_ddr_awid;
            ddr_axi_bresp = 2'b00;
            #1;
            if (!ddr_axi_bready) begin
                fail_now("DDR B was backpressured by upstream write resp stall");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_bvalid = 1'b0;

            timeout = 0;
            while (!bypass_resp_valid && timeout < 20) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!bypass_resp_valid || bypass_resp_id != 4'hF ||
                bypass_resp_code != 2'b00) begin
                fail_now("write response was not buffered while upstream stalled");
            end

            ddr_axi_arready = 1'b1;
            wait_ddr_ar(DDR_BASE + 32'h0000_0A20);
            bypass_resp_ready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            send_ddr_read_resp(captured_ddr_arid, 32'hD00D_0A00);
        end
    endtask

    task test_different_line_write_not_blocked_by_read;
        begin
            issue_ddr_cache_read(DDR_BASE + 32'h0000_0700, 4'h3);
            wait_ddr_ar(DDR_BASE + 32'h0000_0700);

            issue_ddr_bypass_word_write(DDR_BASE + 32'h0000_0780, 4'hD,
                                        32'hB10C_0003);
            wait_ddr_aw_and_w(DDR_BASE + 32'h0000_0780);
            send_ddr_bypass_write_resp(captured_ddr_awid, 4'hD);
            send_ddr_read_resp(captured_ddr_arid, 32'hD00D_0700);
        end
    endtask

    axi_llc_axi_bridge_dual #(
        .ADDR_BITS(ADDR_BITS),
        .ID_BITS(ID_BITS),
        .LINE_BYTES(LINE_BYTES),
        .LINE_BITS(LINE_BITS),
        .DDR_AXI_ID_BITS(AXI_ID_BITS),
        .DDR_AXI_DATA_BITS(DDR_DATA_BITS),
        .DDR_AXI_STRB_BITS(DDR_STRB_BITS),
        .MMIO_AXI_ID_BITS(AXI_ID_BITS),
        .MMIO_AXI_DATA_BITS(MMIO_DATA_BITS),
        .MMIO_AXI_STRB_BITS(MMIO_STRB_BITS),
        .READ_RESP_BITS(READ_RESP_BITS),
        .DDR_BASE(DDR_BASE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .cache_req_valid(cache_req_valid),
        .cache_req_ready(cache_req_ready),
        .cache_req_write(cache_req_write),
        .cache_req_addr(cache_req_addr),
        .cache_req_id(cache_req_id),
        .cache_req_size(cache_req_size),
        .cache_req_wdata(cache_req_wdata),
        .cache_req_wstrb(cache_req_wstrb),
        .cache_resp_valid(cache_resp_valid),
        .cache_resp_ready(cache_resp_ready),
        .cache_resp_rdata(cache_resp_rdata),
        .cache_resp_id(cache_resp_id),
        .cache_resp_code(cache_resp_code),
        .bypass_req_valid(bypass_req_valid),
        .bypass_req_ready(bypass_req_ready),
        .bypass_req_write(bypass_req_write),
        .bypass_req_addr(bypass_req_addr),
        .bypass_req_id(bypass_req_id),
        .bypass_req_size(bypass_req_size),
        .bypass_req_mode2_ddr_aligned(bypass_req_mode2_ddr_aligned),
        .bypass_req_wdata(bypass_req_wdata),
        .bypass_req_wstrb(bypass_req_wstrb),
        .bypass_resp_valid(bypass_resp_valid),
        .bypass_resp_ready(bypass_resp_ready),
        .bypass_resp_rdata(bypass_resp_rdata),
        .bypass_resp_id(bypass_resp_id),
        .bypass_resp_code(bypass_resp_code),
        .ddr_axi_awvalid(ddr_axi_awvalid),
        .ddr_axi_awready(ddr_axi_awready),
        .ddr_axi_awid(ddr_axi_awid),
        .ddr_axi_awaddr(ddr_axi_awaddr),
        .ddr_axi_awlen(ddr_axi_awlen),
        .ddr_axi_awsize(ddr_axi_awsize),
        .ddr_axi_awburst(ddr_axi_awburst),
        .ddr_axi_wvalid(ddr_axi_wvalid),
        .ddr_axi_wready(ddr_axi_wready),
        .ddr_axi_wdata(ddr_axi_wdata),
        .ddr_axi_wstrb(ddr_axi_wstrb),
        .ddr_axi_wlast(ddr_axi_wlast),
        .ddr_axi_bvalid(ddr_axi_bvalid),
        .ddr_axi_bready(ddr_axi_bready),
        .ddr_axi_bid(ddr_axi_bid),
        .ddr_axi_bresp(ddr_axi_bresp),
        .ddr_axi_arvalid(ddr_axi_arvalid),
        .ddr_axi_arready(ddr_axi_arready),
        .ddr_axi_arid(ddr_axi_arid),
        .ddr_axi_araddr(ddr_axi_araddr),
        .ddr_axi_arlen(ddr_axi_arlen),
        .ddr_axi_arsize(ddr_axi_arsize),
        .ddr_axi_arburst(ddr_axi_arburst),
        .ddr_axi_rvalid(ddr_axi_rvalid),
        .ddr_axi_rready(ddr_axi_rready),
        .ddr_axi_rid(ddr_axi_rid),
        .ddr_axi_rdata(ddr_axi_rdata),
        .ddr_axi_rresp(ddr_axi_rresp),
        .ddr_axi_rlast(ddr_axi_rlast),
        .mmio_axi_awvalid(mmio_axi_awvalid),
        .mmio_axi_awready(mmio_axi_awready),
        .mmio_axi_awid(mmio_axi_awid),
        .mmio_axi_awaddr(mmio_axi_awaddr),
        .mmio_axi_awlen(mmio_axi_awlen),
        .mmio_axi_awsize(mmio_axi_awsize),
        .mmio_axi_awburst(mmio_axi_awburst),
        .mmio_axi_wvalid(mmio_axi_wvalid),
        .mmio_axi_wready(mmio_axi_wready),
        .mmio_axi_wdata(mmio_axi_wdata),
        .mmio_axi_wstrb(mmio_axi_wstrb),
        .mmio_axi_wlast(mmio_axi_wlast),
        .mmio_axi_bvalid(mmio_axi_bvalid),
        .mmio_axi_bready(mmio_axi_bready),
        .mmio_axi_bid(mmio_axi_bid),
        .mmio_axi_bresp(mmio_axi_bresp),
        .mmio_axi_arvalid(mmio_axi_arvalid),
        .mmio_axi_arready(mmio_axi_arready),
        .mmio_axi_arid(mmio_axi_arid),
        .mmio_axi_araddr(mmio_axi_araddr),
        .mmio_axi_arlen(mmio_axi_arlen),
        .mmio_axi_arsize(mmio_axi_arsize),
        .mmio_axi_arburst(mmio_axi_arburst),
        .mmio_axi_rvalid(mmio_axi_rvalid),
        .mmio_axi_rready(mmio_axi_rready),
        .mmio_axi_rid(mmio_axi_rid),
        .mmio_axi_rdata(mmio_axi_rdata),
        .mmio_axi_rresp(mmio_axi_rresp),
        .mmio_axi_rlast(mmio_axi_rlast)
    );

    initial begin
        reset_dut();
        test_mixed_read_concurrent_issue();
        test_cache_resp_mux_does_not_backpressure_external_r();
        test_cache_resp_mux_does_not_backpressure_external_b();
        test_mixed_write_concurrent_issue();
        test_mmio_write_shape();
        test_unsupported_mmio_line_blocks();
        test_read_blocks_same_line_write();
        test_rready_ignores_response_backpressure();
        test_write_blocks_same_line_read();
        test_bready_ignores_response_backpressure();
        test_different_line_write_not_blocked_by_read();
        $display("tb_axi_llc_axi_bridge_dual_contract PASS");
        $finish;
    end

endmodule
