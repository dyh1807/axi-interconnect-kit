module axi_llc_axi_bridge_dual_prod_width_ddr_read_mmio_read_independent_formal_top(
    input             clk,
    input             rst_n,
    input             cache_req_valid,
    input             bypass_req_valid,
    input             ddr_axi_arready,
    input             mmio_axi_arready,
    input             ddr_axi_rvalid,
    input             ddr_axi_rid,
    input      [63:0] ddr_axi_rdata_0,
    input      [63:0] ddr_axi_rdata_1,
    input      [63:0] ddr_axi_rdata_2,
    input      [63:0] ddr_axi_rdata_3,
    input      [1:0]  ddr_axi_rresp,
    input             ddr_axi_rlast,
    input             mmio_axi_rvalid,
    input             mmio_axi_rid,
    input      [31:0] mmio_axi_rdata,
    input      [1:0]  mmio_axi_rresp,
    input             mmio_axi_rlast,
    output            cache_req_ready,
    output            bypass_req_ready,
    output            cache_resp_valid,
    output     [63:0] cache_resp_rdata_0,
    output     [63:0] cache_resp_rdata_1,
    output     [63:0] cache_resp_rdata_2,
    output     [63:0] cache_resp_rdata_3,
    output     [63:0] cache_resp_rdata_4,
    output     [63:0] cache_resp_rdata_5,
    output     [63:0] cache_resp_rdata_6,
    output     [63:0] cache_resp_rdata_7,
    output     [5:0]  cache_resp_id,
    output     [1:0]  cache_resp_code,
    output            bypass_resp_valid,
    output     [31:0] bypass_resp_rdata,
    output     [5:0]  bypass_resp_id,
    output     [1:0]  bypass_resp_code,
    output            ddr_axi_arvalid,
    output            ddr_axi_arid,
    output     [31:0] ddr_axi_araddr,
    output     [7:0]  ddr_axi_arlen,
    output     [2:0]  ddr_axi_arsize,
    output     [1:0]  ddr_axi_arburst,
    output            ddr_axi_rready,
    output            mmio_axi_arvalid,
    output            mmio_axi_arid,
    output     [31:0] mmio_axi_araddr,
    output     [7:0]  mmio_axi_arlen,
    output     [2:0]  mmio_axi_arsize,
    output     [1:0]  mmio_axi_arburst,
    output            mmio_axi_rready,
    output            ddr_axi_awvalid,
    output            ddr_axi_wvalid,
    output            mmio_axi_awvalid,
    output            mmio_axi_wvalid
);

    localparam integer FORMAL_LINE_BYTES = 64;
    localparam integer FORMAL_LINE_BITS = 512;
    localparam integer FORMAL_LINE_OFFSET_BITS = 6;
    localparam integer FORMAL_DDR_DATA_BYTES = 32;
    localparam integer FORMAL_DDR_DATA_BITS = 256;
    localparam integer FORMAL_DDR_STRB_BITS = 32;
    localparam integer FORMAL_AXI_ID_BITS = 1;
    localparam integer FORMAL_READ_RESP_BYTES = 64;
    localparam integer FORMAL_READ_RESP_BITS = 512;

    localparam [31:0] DDR_ADDR = 32'h4000_0300;
    localparam [31:0] MMIO_ADDR = 32'h1000_0028;

    wire [FORMAL_READ_RESP_BITS-1:0] cache_resp_rdata_w;
    wire [FORMAL_READ_RESP_BITS-1:0] bypass_resp_rdata_w;
    wire [FORMAL_AXI_ID_BITS-1:0] ddr_axi_awid_w;
    wire [31:0] ddr_axi_awaddr_w;
    wire [7:0] ddr_axi_awlen_w;
    wire [2:0] ddr_axi_awsize_w;
    wire [1:0] ddr_axi_awburst_w;
    wire [FORMAL_DDR_DATA_BITS-1:0] ddr_axi_wdata_w;
    wire [FORMAL_DDR_STRB_BITS-1:0] ddr_axi_wstrb_w;
    wire ddr_axi_wlast_w;
    wire ddr_axi_bready_w;
    wire [FORMAL_DDR_DATA_BITS-1:0] ddr_axi_rdata_w;

    wire [FORMAL_AXI_ID_BITS-1:0] mmio_axi_awid_w;
    wire [31:0] mmio_axi_awaddr_w;
    wire [7:0] mmio_axi_awlen_w;
    wire [2:0] mmio_axi_awsize_w;
    wire [1:0] mmio_axi_awburst_w;
    wire [31:0] mmio_axi_wdata_w;
    wire [3:0] mmio_axi_wstrb_w;
    wire mmio_axi_wlast_w;
    wire mmio_axi_bready_w;

    assign cache_resp_rdata_0 = cache_resp_rdata_w[63:0];
    assign cache_resp_rdata_1 = cache_resp_rdata_w[127:64];
    assign cache_resp_rdata_2 = cache_resp_rdata_w[191:128];
    assign cache_resp_rdata_3 = cache_resp_rdata_w[255:192];
    assign cache_resp_rdata_4 = cache_resp_rdata_w[319:256];
    assign cache_resp_rdata_5 = cache_resp_rdata_w[383:320];
    assign cache_resp_rdata_6 = cache_resp_rdata_w[447:384];
    assign cache_resp_rdata_7 = cache_resp_rdata_w[511:448];
    assign bypass_resp_rdata = bypass_resp_rdata_w[31:0];
    assign ddr_axi_rdata_w = {ddr_axi_rdata_3, ddr_axi_rdata_2,
                              ddr_axi_rdata_1, ddr_axi_rdata_0};

    axi_llc_axi_bridge_dual #(
        .LINE_BYTES(FORMAL_LINE_BYTES),
        .LINE_BITS(FORMAL_LINE_BITS),
        .LINE_OFFSET_BITS(FORMAL_LINE_OFFSET_BITS),
        .DDR_AXI_ID_BITS(FORMAL_AXI_ID_BITS),
        .DDR_AXI_DATA_BYTES(FORMAL_DDR_DATA_BYTES),
        .DDR_AXI_DATA_BITS(FORMAL_DDR_DATA_BITS),
        .DDR_AXI_STRB_BITS(FORMAL_DDR_STRB_BITS),
        .MMIO_AXI_ID_BITS(FORMAL_AXI_ID_BITS),
        .READ_RESP_BYTES(FORMAL_READ_RESP_BYTES),
        .READ_RESP_BITS(FORMAL_READ_RESP_BITS),
        .BRIDGE_READ_PENDING_COUNT(1),
        .BRIDGE_WRITE_PENDING_COUNT(1)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .cache_req_valid(cache_req_valid),
        .cache_req_ready(cache_req_ready),
        .cache_req_write(1'b0),
        .cache_req_addr(DDR_ADDR),
        .cache_req_id(6'h05),
        .cache_req_size(8'd63),
        .cache_req_wdata({FORMAL_LINE_BITS{1'b0}}),
        .cache_req_wstrb({FORMAL_LINE_BYTES{1'b0}}),
        .cache_resp_valid(cache_resp_valid),
        .cache_resp_ready(1'b1),
        .cache_resp_rdata(cache_resp_rdata_w),
        .cache_resp_id(cache_resp_id),
        .cache_resp_code(cache_resp_code),
        .bypass_req_valid(bypass_req_valid),
        .bypass_req_ready(bypass_req_ready),
        .bypass_req_write(1'b0),
        .bypass_req_addr(MMIO_ADDR),
        .bypass_req_id(6'h0a),
        .bypass_req_size(8'd3),
        .bypass_req_mode2_ddr_aligned(1'b0),
        .bypass_req_wdata({FORMAL_LINE_BITS{1'b0}}),
        .bypass_req_wstrb({FORMAL_LINE_BYTES{1'b0}}),
        .bypass_resp_valid(bypass_resp_valid),
        .bypass_resp_ready(1'b1),
        .bypass_resp_rdata(bypass_resp_rdata_w),
        .bypass_resp_id(bypass_resp_id),
        .bypass_resp_code(bypass_resp_code),
        .ddr_axi_awvalid(ddr_axi_awvalid),
        .ddr_axi_awready(1'b1),
        .ddr_axi_awid(ddr_axi_awid_w),
        .ddr_axi_awaddr(ddr_axi_awaddr_w),
        .ddr_axi_awlen(ddr_axi_awlen_w),
        .ddr_axi_awsize(ddr_axi_awsize_w),
        .ddr_axi_awburst(ddr_axi_awburst_w),
        .ddr_axi_wvalid(ddr_axi_wvalid),
        .ddr_axi_wready(1'b1),
        .ddr_axi_wdata(ddr_axi_wdata_w),
        .ddr_axi_wstrb(ddr_axi_wstrb_w),
        .ddr_axi_wlast(ddr_axi_wlast_w),
        .ddr_axi_bvalid(1'b0),
        .ddr_axi_bready(ddr_axi_bready_w),
        .ddr_axi_bid({FORMAL_AXI_ID_BITS{1'b0}}),
        .ddr_axi_bresp(2'b00),
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
        .ddr_axi_rdata(ddr_axi_rdata_w),
        .ddr_axi_rresp(ddr_axi_rresp),
        .ddr_axi_rlast(ddr_axi_rlast),
        .mmio_axi_awvalid(mmio_axi_awvalid),
        .mmio_axi_awready(1'b1),
        .mmio_axi_awid(mmio_axi_awid_w),
        .mmio_axi_awaddr(mmio_axi_awaddr_w),
        .mmio_axi_awlen(mmio_axi_awlen_w),
        .mmio_axi_awsize(mmio_axi_awsize_w),
        .mmio_axi_awburst(mmio_axi_awburst_w),
        .mmio_axi_wvalid(mmio_axi_wvalid),
        .mmio_axi_wready(1'b1),
        .mmio_axi_wdata(mmio_axi_wdata_w),
        .mmio_axi_wstrb(mmio_axi_wstrb_w),
        .mmio_axi_wlast(mmio_axi_wlast_w),
        .mmio_axi_bvalid(1'b0),
        .mmio_axi_bready(mmio_axi_bready_w),
        .mmio_axi_bid({FORMAL_AXI_ID_BITS{1'b0}}),
        .mmio_axi_bresp(2'b00),
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

endmodule
