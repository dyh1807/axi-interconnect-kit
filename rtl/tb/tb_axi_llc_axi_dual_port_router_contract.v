`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_axi_dual_port_router_contract;

    localparam ADDR_BITS      = `AXI_LLC_ADDR_BITS;
    localparam AXI_ID_BITS    = `AXI_LLC_AXI_ID_BITS;
    localparam AXI_DATA_BITS  = `AXI_LLC_AXI_DATA_BITS;
    localparam AXI_STRB_BITS  = `AXI_LLC_AXI_STRB_BITS;
    localparam DDR_BASE       = 32'h4000_0000;
    localparam [2:0] AXI_SIZE_256 = 3'd5;
    localparam [2:0] AXI_SIZE_32  = 3'd2;
    localparam [1:0] AXI_BURST_INCR = 2'b01;

    reg                          clk;
    reg                          rst_n;

    reg                          s_axi_awvalid;
    wire                         s_axi_awready;
    reg  [AXI_ID_BITS-1:0]       s_axi_awid;
    reg  [ADDR_BITS-1:0]         s_axi_awaddr;
    reg  [7:0]                   s_axi_awlen;
    reg  [2:0]                   s_axi_awsize;
    reg  [1:0]                   s_axi_awburst;
    reg                          s_axi_wvalid;
    wire                         s_axi_wready;
    reg  [AXI_DATA_BITS-1:0]     s_axi_wdata;
    reg  [AXI_STRB_BITS-1:0]     s_axi_wstrb;
    reg                          s_axi_wlast;
    wire                         s_axi_bvalid;
    reg                          s_axi_bready;
    wire [AXI_ID_BITS-1:0]       s_axi_bid;
    wire [1:0]                   s_axi_bresp;
    reg                          s_axi_arvalid;
    wire                         s_axi_arready;
    reg  [AXI_ID_BITS-1:0]       s_axi_arid;
    reg  [ADDR_BITS-1:0]         s_axi_araddr;
    reg  [7:0]                   s_axi_arlen;
    reg  [2:0]                   s_axi_arsize;
    reg  [1:0]                   s_axi_arburst;
    wire                         s_axi_rvalid;
    reg                          s_axi_rready;
    wire [AXI_ID_BITS-1:0]       s_axi_rid;
    wire [AXI_DATA_BITS-1:0]     s_axi_rdata;
    wire [1:0]                   s_axi_rresp;
    wire                         s_axi_rlast;

    wire                         ddr_axi_awvalid;
    reg                          ddr_axi_awready;
    wire [AXI_ID_BITS-1:0]       ddr_axi_awid;
    wire [ADDR_BITS-1:0]         ddr_axi_awaddr;
    wire [7:0]                   ddr_axi_awlen;
    wire [2:0]                   ddr_axi_awsize;
    wire [1:0]                   ddr_axi_awburst;
    wire                         ddr_axi_wvalid;
    reg                          ddr_axi_wready;
    wire [AXI_DATA_BITS-1:0]     ddr_axi_wdata;
    wire [AXI_STRB_BITS-1:0]     ddr_axi_wstrb;
    wire                         ddr_axi_wlast;
    reg                          ddr_axi_bvalid;
    wire                         ddr_axi_bready;
    reg  [AXI_ID_BITS-1:0]       ddr_axi_bid;
    reg  [1:0]                   ddr_axi_bresp;
    wire                         ddr_axi_arvalid;
    reg                          ddr_axi_arready;
    wire [AXI_ID_BITS-1:0]       ddr_axi_arid;
    wire [ADDR_BITS-1:0]         ddr_axi_araddr;
    wire [7:0]                   ddr_axi_arlen;
    wire [2:0]                   ddr_axi_arsize;
    wire [1:0]                   ddr_axi_arburst;
    reg                          ddr_axi_rvalid;
    wire                         ddr_axi_rready;
    reg  [AXI_ID_BITS-1:0]       ddr_axi_rid;
    reg  [AXI_DATA_BITS-1:0]     ddr_axi_rdata;
    reg  [1:0]                   ddr_axi_rresp;
    reg                          ddr_axi_rlast;

    wire                         mmio_axi_awvalid;
    reg                          mmio_axi_awready;
    wire [AXI_ID_BITS-1:0]       mmio_axi_awid;
    wire [ADDR_BITS-1:0]         mmio_axi_awaddr;
    wire [7:0]                   mmio_axi_awlen;
    wire [2:0]                   mmio_axi_awsize;
    wire [1:0]                   mmio_axi_awburst;
    wire                         mmio_axi_wvalid;
    reg                          mmio_axi_wready;
    wire [AXI_DATA_BITS-1:0]     mmio_axi_wdata;
    wire [AXI_STRB_BITS-1:0]     mmio_axi_wstrb;
    wire                         mmio_axi_wlast;
    reg                          mmio_axi_bvalid;
    wire                         mmio_axi_bready;
    reg  [AXI_ID_BITS-1:0]       mmio_axi_bid;
    reg  [1:0]                   mmio_axi_bresp;
    wire                         mmio_axi_arvalid;
    reg                          mmio_axi_arready;
    wire [AXI_ID_BITS-1:0]       mmio_axi_arid;
    wire [ADDR_BITS-1:0]         mmio_axi_araddr;
    wire [7:0]                   mmio_axi_arlen;
    wire [2:0]                   mmio_axi_arsize;
    wire [1:0]                   mmio_axi_arburst;
    reg                          mmio_axi_rvalid;
    wire                         mmio_axi_rready;
    reg  [AXI_ID_BITS-1:0]       mmio_axi_rid;
    reg  [AXI_DATA_BITS-1:0]     mmio_axi_rdata;
    reg  [1:0]                   mmio_axi_rresp;
    reg                          mmio_axi_rlast;

    always #5 clk = ~clk;

    task fail_now;
        input [8*180-1:0] msg;
        begin
            $display("tb_axi_llc_axi_dual_port_router_contract FAIL: %0s", msg);
            $finish(1);
        end
    endtask

    task clear_inputs;
        begin
            s_axi_awvalid = 1'b0;
            s_axi_awid = {AXI_ID_BITS{1'b0}};
            s_axi_awaddr = {ADDR_BITS{1'b0}};
            s_axi_awlen = 8'd0;
            s_axi_awsize = AXI_SIZE_256;
            s_axi_awburst = AXI_BURST_INCR;
            s_axi_wvalid = 1'b0;
            s_axi_wdata = {AXI_DATA_BITS{1'b0}};
            s_axi_wstrb = {AXI_STRB_BITS{1'b0}};
            s_axi_wlast = 1'b0;
            s_axi_bready = 1'b1;
            s_axi_arvalid = 1'b0;
            s_axi_arid = {AXI_ID_BITS{1'b0}};
            s_axi_araddr = {ADDR_BITS{1'b0}};
            s_axi_arlen = 8'd0;
            s_axi_arsize = AXI_SIZE_256;
            s_axi_arburst = AXI_BURST_INCR;
            s_axi_rready = 1'b1;
            ddr_axi_awready = 1'b1;
            ddr_axi_wready = 1'b1;
            ddr_axi_bvalid = 1'b0;
            ddr_axi_bid = {AXI_ID_BITS{1'b0}};
            ddr_axi_bresp = 2'b00;
            ddr_axi_arready = 1'b1;
            ddr_axi_rvalid = 1'b0;
            ddr_axi_rid = {AXI_ID_BITS{1'b0}};
            ddr_axi_rdata = {AXI_DATA_BITS{1'b0}};
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
            mmio_axi_rdata = {AXI_DATA_BITS{1'b0}};
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

    task issue_read;
        input [AXI_ID_BITS-1:0] id;
        input [ADDR_BITS-1:0]   addr;
        input [7:0]             len;
        begin
            @(negedge clk);
            s_axi_arvalid = 1'b1;
            s_axi_arid = id;
            s_axi_araddr = addr;
            s_axi_arlen = len;
            s_axi_arsize = AXI_SIZE_256;
            s_axi_arburst = AXI_BURST_INCR;
            #1;
            if (!s_axi_arready) begin
                fail_now("read address channel was not ready");
            end
            @(posedge clk);
            @(negedge clk);
            s_axi_arvalid = 1'b0;
        end
    endtask

    task complete_ddr_read;
        input [AXI_ID_BITS-1:0] id;
        input [31:0]            data_word;
        begin
            @(negedge clk);
            ddr_axi_rvalid = 1'b1;
            ddr_axi_rid = id;
            ddr_axi_rdata = {AXI_DATA_BITS{1'b0}};
            ddr_axi_rdata[31:0] = data_word;
            ddr_axi_rresp = 2'b00;
            ddr_axi_rlast = 1'b1;
            #1;
            if (!s_axi_rvalid || !ddr_axi_rready || s_axi_rid != id ||
                s_axi_rdata[31:0] != data_word || !s_axi_rlast) begin
                fail_now("DDR read response did not route back to upstream");
            end
            if (mmio_axi_rready) begin
                fail_now("MMIO R ready asserted during DDR response");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;
            ddr_axi_rlast = 1'b0;
        end
    endtask

    task complete_mmio_read;
        input [AXI_ID_BITS-1:0] id;
        input [31:0]            data_word;
        begin
            @(negedge clk);
            mmio_axi_rvalid = 1'b1;
            mmio_axi_rid = id;
            mmio_axi_rdata = {AXI_DATA_BITS{1'b0}};
            mmio_axi_rdata[31:0] = data_word;
            mmio_axi_rresp = 2'b00;
            mmio_axi_rlast = 1'b1;
            #1;
            if (!s_axi_rvalid || !mmio_axi_rready || s_axi_rid != id ||
                s_axi_rdata[31:0] != data_word || !s_axi_rlast) begin
                fail_now("MMIO read response did not route back to upstream");
            end
            if (ddr_axi_rready) begin
                fail_now("DDR R ready asserted during MMIO response");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_rvalid = 1'b0;
            mmio_axi_rlast = 1'b0;
        end
    endtask

    task complete_ddr_write;
        input [AXI_ID_BITS-1:0] id;
        begin
            @(negedge clk);
            ddr_axi_bvalid = 1'b1;
            ddr_axi_bid = id;
            ddr_axi_bresp = 2'b00;
            #1;
            if (!s_axi_bvalid || !ddr_axi_bready || s_axi_bid != id ||
                s_axi_bresp != 2'b00) begin
                fail_now("DDR B response did not route back to upstream");
            end
            if (mmio_axi_bready) begin
                fail_now("MMIO B ready asserted during DDR response");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_bvalid = 1'b0;
        end
    endtask

    task complete_mmio_write;
        input [AXI_ID_BITS-1:0] id;
        begin
            @(negedge clk);
            mmio_axi_bvalid = 1'b1;
            mmio_axi_bid = id;
            mmio_axi_bresp = 2'b00;
            #1;
            if (!s_axi_bvalid || !mmio_axi_bready || s_axi_bid != id ||
                s_axi_bresp != 2'b00) begin
                fail_now("MMIO B response did not route back to upstream");
            end
            if (ddr_axi_bready) begin
                fail_now("DDR B ready asserted during MMIO response");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_bvalid = 1'b0;
        end
    endtask

    task test_ddr_read_shape;
        begin
            @(negedge clk);
            s_axi_arvalid = 1'b1;
            s_axi_arid = 6'h05;
            s_axi_araddr = DDR_BASE + 32'h0000_0020;
            s_axi_arlen = 8'd1;
            s_axi_arsize = AXI_SIZE_256;
            s_axi_arburst = AXI_BURST_INCR;
            #1;
            if (!ddr_axi_arvalid || mmio_axi_arvalid) begin
                fail_now("DDR read did not route exclusively to DDR port");
            end
            if (ddr_axi_arid != 6'h05 || ddr_axi_araddr != DDR_BASE + 32'h20 ||
                ddr_axi_arlen != 8'd1 || ddr_axi_arsize != AXI_SIZE_256 ||
                ddr_axi_arburst != AXI_BURST_INCR) begin
                fail_now("DDR read address shape was not preserved");
            end
            @(posedge clk);
            @(negedge clk);
            s_axi_arvalid = 1'b0;
            complete_ddr_read(6'h05, 32'hD00D_0001);
        end
    endtask

    task test_mmio_read_shape;
        begin
            issue_read(6'h06, 32'h1000_0004, 8'd0);
            if (ddr_axi_arvalid) begin
                fail_now("DDR AR still valid after MMIO read handshake");
            end
            complete_mmio_read(6'h06, 32'hA55A_0002);
        end
    endtask

    task test_mmio_read_channel_rewrite;
        begin
            @(negedge clk);
            s_axi_arvalid = 1'b1;
            s_axi_arid = 6'h07;
            s_axi_araddr = 32'h1000_0010;
            s_axi_arlen = 8'd0;
            s_axi_arsize = AXI_SIZE_256;
            s_axi_arburst = AXI_BURST_INCR;
            #1;
            if (ddr_axi_arvalid || !mmio_axi_arvalid) begin
                fail_now("MMIO read did not route exclusively to MMIO port");
            end
            if (mmio_axi_arid != 6'h07 || mmio_axi_araddr != 32'h1000_0010 ||
                mmio_axi_arlen != 8'd0 || mmio_axi_arsize != AXI_SIZE_32 ||
                mmio_axi_arburst != AXI_BURST_INCR) begin
                fail_now("MMIO read was not rewritten to 32-bit single beat");
            end
            @(posedge clk);
            @(negedge clk);
            s_axi_arvalid = 1'b0;
            complete_mmio_read(6'h07, 32'hA55A_0003);
        end
    endtask

    task test_out_of_order_read_returns;
        begin
            issue_read(6'h08, DDR_BASE + 32'h0000_1000, 8'd0);
            issue_read(6'h09, 32'h1000_0020, 8'd0);
            complete_mmio_read(6'h09, 32'hBEEF_0009);
            complete_ddr_read(6'h08, 32'hBEEF_0008);
        end
    endtask

    task test_ddr_write_shape;
        begin
            @(negedge clk);
            s_axi_awvalid = 1'b1;
            s_axi_awid = 6'h11;
            s_axi_awaddr = DDR_BASE + 32'h0000_2000;
            s_axi_awlen = 8'd1;
            s_axi_awsize = AXI_SIZE_256;
            s_axi_awburst = AXI_BURST_INCR;
            s_axi_wvalid = 1'b1;
            s_axi_wdata = {AXI_DATA_BITS{1'b0}};
            s_axi_wdata[31:0] = 32'hCAFE_0001;
            s_axi_wstrb = {AXI_STRB_BITS{1'b1}};
            s_axi_wlast = 1'b0;
            #1;
            if (!ddr_axi_awvalid || mmio_axi_awvalid || !ddr_axi_wvalid ||
                mmio_axi_wvalid || !s_axi_awready || !s_axi_wready) begin
                fail_now("DDR AW/W did not route exclusively to DDR port");
            end
            if (ddr_axi_awid != 6'h11 || ddr_axi_awaddr != DDR_BASE + 32'h2000 ||
                ddr_axi_awlen != 8'd1 || ddr_axi_awsize != AXI_SIZE_256 ||
                ddr_axi_wstrb != {AXI_STRB_BITS{1'b1}} || ddr_axi_wlast) begin
                fail_now("DDR write first beat shape was not preserved");
            end
            @(posedge clk);
            @(negedge clk);
            s_axi_awvalid = 1'b0;
            s_axi_wdata[31:0] = 32'hCAFE_0002;
            s_axi_wlast = 1'b1;
            #1;
            if (!ddr_axi_wvalid || !s_axi_wready || !ddr_axi_wlast ||
                ddr_axi_wdata[31:0] != 32'hCAFE_0002) begin
                fail_now("DDR write second beat did not keep data route");
            end
            @(posedge clk);
            @(negedge clk);
            s_axi_wvalid = 1'b0;
            s_axi_wlast = 1'b0;
            complete_ddr_write(6'h11);
        end
    endtask

    task test_mmio_write_shape;
        begin
            @(negedge clk);
            s_axi_awvalid = 1'b1;
            s_axi_awid = 6'h12;
            s_axi_awaddr = 32'h1000_0030;
            s_axi_awlen = 8'd0;
            s_axi_awsize = AXI_SIZE_256;
            s_axi_awburst = AXI_BURST_INCR;
            s_axi_wvalid = 1'b1;
            s_axi_wdata = {AXI_DATA_BITS{1'b0}};
            s_axi_wdata[31:0] = 32'h1234_ABCD;
            s_axi_wstrb = {AXI_STRB_BITS{1'b1}};
            s_axi_wlast = 1'b1;
            #1;
            if (ddr_axi_awvalid || !mmio_axi_awvalid || ddr_axi_wvalid ||
                !mmio_axi_wvalid || !s_axi_awready || !s_axi_wready) begin
                fail_now("MMIO AW/W did not route exclusively to MMIO port");
            end
            if (mmio_axi_awid != 6'h12 || mmio_axi_awaddr != 32'h1000_0030 ||
                mmio_axi_awlen != 8'd0 || mmio_axi_awsize != AXI_SIZE_32 ||
                mmio_axi_wdata[31:0] != 32'h1234_ABCD ||
                mmio_axi_wstrb != {{(AXI_STRB_BITS-4){1'b0}}, 4'hF} ||
                !mmio_axi_wlast) begin
                fail_now("MMIO write was not rewritten to 32-bit single beat");
            end
            @(posedge clk);
            @(negedge clk);
            s_axi_awvalid = 1'b0;
            s_axi_wvalid = 1'b0;
            s_axi_wlast = 1'b0;
            complete_mmio_write(6'h12);
        end
    endtask

    axi_llc_axi_dual_port_router #(
        .ADDR_BITS(ADDR_BITS),
        .AXI_ID_BITS(AXI_ID_BITS),
        .AXI_DATA_BITS(AXI_DATA_BITS),
        .AXI_STRB_BITS(AXI_STRB_BITS),
        .DDR_BASE(DDR_BASE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_awid(s_axi_awid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awsize(s_axi_awsize),
        .s_axi_awburst(s_axi_awburst),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_bid(s_axi_bid),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_arid(s_axi_arid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arsize(s_axi_arsize),
        .s_axi_arburst(s_axi_arburst),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .s_axi_rid(s_axi_rid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rlast(s_axi_rlast),
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
        test_ddr_read_shape();
        test_mmio_read_channel_rewrite();
        test_out_of_order_read_returns();
        test_ddr_write_shape();
        test_mmio_write_shape();
        $display("tb_axi_llc_axi_dual_port_router_contract PASS");
        $finish;
    end

endmodule
