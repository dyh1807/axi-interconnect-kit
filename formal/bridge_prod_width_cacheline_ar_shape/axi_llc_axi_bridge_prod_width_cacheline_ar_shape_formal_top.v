module axi_llc_axi_bridge_prod_width_cacheline_ar_shape_formal_top(
    input             clk,
    input             rst_n,
    input             cache_req_valid,
    input      [31:0] cache_req_addr,
    input      [5:0]  cache_req_id,
    output            cache_req_ready,
    output            axi_arvalid,
    output     [31:0] axi_araddr,
    output     [7:0]  axi_arlen,
    output     [2:0]  axi_arsize,
    output     [1:0]  axi_arburst
);

    localparam integer FORMAL_LINE_BYTES = 64;
    localparam integer FORMAL_LINE_BITS = 512;
    localparam integer FORMAL_DDR_DATA_BYTES = 32;
    localparam integer FORMAL_DDR_DATA_BITS = 256;
    localparam integer FORMAL_DDR_STRB_BITS = 32;
    localparam integer FORMAL_AXI_ID_BITS = 1;
    localparam integer FORMAL_READ_RESP_BYTES = 64;
    localparam integer FORMAL_READ_RESP_BITS = 512;

    wire cache_resp_valid_w;
    wire [FORMAL_READ_RESP_BITS-1:0] cache_resp_rdata_w;
    wire [5:0] cache_resp_id_w;
    wire [1:0] cache_resp_code_w;
    wire bypass_req_ready_w;
    wire bypass_resp_valid_w;
    wire [FORMAL_READ_RESP_BITS-1:0] bypass_resp_rdata_w;
    wire [5:0] bypass_resp_id_w;
    wire [1:0] bypass_resp_code_w;
    wire axi_awvalid_w;
    wire [FORMAL_AXI_ID_BITS-1:0] axi_awid_w;
    wire [31:0] axi_awaddr_w;
    wire [7:0] axi_awlen_w;
    wire [2:0] axi_awsize_w;
    wire [1:0] axi_awburst_w;
    wire axi_wvalid_w;
    wire [FORMAL_DDR_DATA_BITS-1:0] axi_wdata_w;
    wire [FORMAL_DDR_STRB_BITS-1:0] axi_wstrb_w;
    wire axi_wlast_w;
    wire axi_bready_w;
    wire [FORMAL_AXI_ID_BITS-1:0] axi_arid_w;
    wire axi_rready_w;

    axi_llc_axi_bridge #(
        .LINE_BYTES(FORMAL_LINE_BYTES),
        .LINE_BITS(FORMAL_LINE_BITS),
        .AXI_ID_BITS(FORMAL_AXI_ID_BITS),
        .AXI_DATA_BYTES(FORMAL_DDR_DATA_BYTES),
        .AXI_DATA_BITS(FORMAL_DDR_DATA_BITS),
        .AXI_STRB_BITS(FORMAL_DDR_STRB_BITS),
        .READ_RESP_BYTES(FORMAL_READ_RESP_BYTES),
        .READ_RESP_BITS(FORMAL_READ_RESP_BITS),
        .READ_PENDING_COUNT(1),
        .WRITE_PENDING_COUNT(1)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .cache_req_valid(cache_req_valid),
        .cache_req_ready(cache_req_ready),
        .cache_req_write(1'b0),
        .cache_req_addr(cache_req_addr),
        .cache_req_id(cache_req_id),
        .cache_req_size(8'd63),
        .cache_req_wdata({FORMAL_LINE_BITS{1'b0}}),
        .cache_req_wstrb({FORMAL_LINE_BYTES{1'b0}}),
        .cache_resp_valid(cache_resp_valid_w),
        .cache_resp_ready(1'b1),
        .cache_resp_rdata(cache_resp_rdata_w),
        .cache_resp_id(cache_resp_id_w),
        .cache_resp_code(cache_resp_code_w),
        .bypass_req_valid(1'b0),
        .bypass_req_ready(bypass_req_ready_w),
        .bypass_req_write(1'b0),
        .bypass_req_addr(32'd0),
        .bypass_req_id(6'd0),
        .bypass_req_size(8'd0),
        .bypass_req_mode2_ddr_aligned(1'b0),
        .bypass_req_wdata({FORMAL_LINE_BITS{1'b0}}),
        .bypass_req_wstrb({FORMAL_LINE_BYTES{1'b0}}),
        .bypass_resp_valid(bypass_resp_valid_w),
        .bypass_resp_ready(1'b1),
        .bypass_resp_rdata(bypass_resp_rdata_w),
        .bypass_resp_id(bypass_resp_id_w),
        .bypass_resp_code(bypass_resp_code_w),
        .axi_awvalid(axi_awvalid_w),
        .axi_awready(1'b1),
        .axi_awid(axi_awid_w),
        .axi_awaddr(axi_awaddr_w),
        .axi_awlen(axi_awlen_w),
        .axi_awsize(axi_awsize_w),
        .axi_awburst(axi_awburst_w),
        .axi_wvalid(axi_wvalid_w),
        .axi_wready(1'b1),
        .axi_wdata(axi_wdata_w),
        .axi_wstrb(axi_wstrb_w),
        .axi_wlast(axi_wlast_w),
        .axi_bvalid(1'b0),
        .axi_bready(axi_bready_w),
        .axi_bid({FORMAL_AXI_ID_BITS{1'b0}}),
        .axi_bresp(2'b00),
        .axi_arvalid(axi_arvalid),
        .axi_arready(1'b1),
        .axi_arid(axi_arid_w),
        .axi_araddr(axi_araddr),
        .axi_arlen(axi_arlen),
        .axi_arsize(axi_arsize),
        .axi_arburst(axi_arburst),
        .axi_rvalid(1'b0),
        .axi_rready(axi_rready_w),
        .axi_rid({FORMAL_AXI_ID_BITS{1'b0}}),
        .axi_rdata({FORMAL_DDR_DATA_BITS{1'b0}}),
        .axi_rresp(2'b00),
        .axi_rlast(1'b0)
    );

endmodule
