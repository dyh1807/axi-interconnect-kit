module axi_llc_axi_bridge_dual_read_route_formal_top(
    input             clk,
    input             rst_n,
    input             cache_req_valid,
    input             cache_req_write,
    input      [31:0] cache_req_addr,
    input      [7:0]  cache_req_size,
    output            cache_req_ready,
    output            ddr_axi_arvalid,
    output     [31:0] ddr_axi_araddr,
    output     [7:0]  ddr_axi_arlen,
    output     [2:0]  ddr_axi_arsize,
    output            mmio_axi_arvalid,
    output     [31:0] mmio_axi_araddr,
    output     [7:0]  mmio_axi_arlen,
    output     [2:0]  mmio_axi_arsize
);

    localparam integer FORMAL_LINE_BYTES = 8;
    localparam integer FORMAL_LINE_BITS = 64;
    localparam integer FORMAL_LINE_OFFSET_BITS = 3;
    localparam integer FORMAL_DDR_DATA_BYTES = 8;
    localparam integer FORMAL_DDR_DATA_BITS = 64;
    localparam integer FORMAL_DDR_STRB_BITS = 8;
    localparam integer FORMAL_AXI_ID_BITS = 1;
    localparam integer FORMAL_READ_RESP_BYTES = 8;
    localparam integer FORMAL_READ_RESP_BITS = 64;

    wire cache_resp_valid_w;
    wire [FORMAL_READ_RESP_BITS-1:0] cache_resp_rdata_w;
    wire [5:0] cache_resp_id_w;
    wire [1:0] cache_resp_code_w;
    wire bypass_req_ready_w;
    wire bypass_resp_valid_w;
    wire [FORMAL_READ_RESP_BITS-1:0] bypass_resp_rdata_w;
    wire [5:0] bypass_resp_id_w;
    wire [1:0] bypass_resp_code_w;

    wire ddr_axi_awvalid_w;
    wire [FORMAL_AXI_ID_BITS-1:0] ddr_axi_awid_w;
    wire [31:0] ddr_axi_awaddr_w;
    wire [7:0] ddr_axi_awlen_w;
    wire [2:0] ddr_axi_awsize_w;
    wire [1:0] ddr_axi_awburst_w;
    wire ddr_axi_wvalid_w;
    wire [FORMAL_DDR_DATA_BITS-1:0] ddr_axi_wdata_w;
    wire [FORMAL_DDR_STRB_BITS-1:0] ddr_axi_wstrb_w;
    wire ddr_axi_wlast_w;
    wire ddr_axi_bready_w;
    wire [FORMAL_AXI_ID_BITS-1:0] ddr_axi_arid_w;
    wire [1:0] ddr_axi_arburst_w;
    wire ddr_axi_rready_w;

    wire mmio_axi_awvalid_w;
    wire [FORMAL_AXI_ID_BITS-1:0] mmio_axi_awid_w;
    wire [31:0] mmio_axi_awaddr_w;
    wire [7:0] mmio_axi_awlen_w;
    wire [2:0] mmio_axi_awsize_w;
    wire [1:0] mmio_axi_awburst_w;
    wire mmio_axi_wvalid_w;
    wire [31:0] mmio_axi_wdata_w;
    wire [3:0] mmio_axi_wstrb_w;
    wire mmio_axi_wlast_w;
    wire mmio_axi_bready_w;
    wire [FORMAL_AXI_ID_BITS-1:0] mmio_axi_arid_w;
    wire [1:0] mmio_axi_arburst_w;
    wire mmio_axi_rready_w;

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
        .cache_req_write(cache_req_write),
        .cache_req_addr(cache_req_addr),
        .cache_req_id(6'd0),
        .cache_req_size(cache_req_size),
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
        .ddr_axi_awvalid(ddr_axi_awvalid_w),
        .ddr_axi_awready(1'b1),
        .ddr_axi_awid(ddr_axi_awid_w),
        .ddr_axi_awaddr(ddr_axi_awaddr_w),
        .ddr_axi_awlen(ddr_axi_awlen_w),
        .ddr_axi_awsize(ddr_axi_awsize_w),
        .ddr_axi_awburst(ddr_axi_awburst_w),
        .ddr_axi_wvalid(ddr_axi_wvalid_w),
        .ddr_axi_wready(1'b1),
        .ddr_axi_wdata(ddr_axi_wdata_w),
        .ddr_axi_wstrb(ddr_axi_wstrb_w),
        .ddr_axi_wlast(ddr_axi_wlast_w),
        .ddr_axi_bvalid(1'b0),
        .ddr_axi_bready(ddr_axi_bready_w),
        .ddr_axi_bid({FORMAL_AXI_ID_BITS{1'b0}}),
        .ddr_axi_bresp(2'b00),
        .ddr_axi_arvalid(ddr_axi_arvalid),
        .ddr_axi_arready(1'b1),
        .ddr_axi_arid(ddr_axi_arid_w),
        .ddr_axi_araddr(ddr_axi_araddr),
        .ddr_axi_arlen(ddr_axi_arlen),
        .ddr_axi_arsize(ddr_axi_arsize),
        .ddr_axi_arburst(ddr_axi_arburst_w),
        .ddr_axi_rvalid(1'b0),
        .ddr_axi_rready(ddr_axi_rready_w),
        .ddr_axi_rid({FORMAL_AXI_ID_BITS{1'b0}}),
        .ddr_axi_rdata({FORMAL_DDR_DATA_BITS{1'b0}}),
        .ddr_axi_rresp(2'b00),
        .ddr_axi_rlast(1'b0),
        .mmio_axi_awvalid(mmio_axi_awvalid_w),
        .mmio_axi_awready(1'b1),
        .mmio_axi_awid(mmio_axi_awid_w),
        .mmio_axi_awaddr(mmio_axi_awaddr_w),
        .mmio_axi_awlen(mmio_axi_awlen_w),
        .mmio_axi_awsize(mmio_axi_awsize_w),
        .mmio_axi_awburst(mmio_axi_awburst_w),
        .mmio_axi_wvalid(mmio_axi_wvalid_w),
        .mmio_axi_wready(1'b1),
        .mmio_axi_wdata(mmio_axi_wdata_w),
        .mmio_axi_wstrb(mmio_axi_wstrb_w),
        .mmio_axi_wlast(mmio_axi_wlast_w),
        .mmio_axi_bvalid(1'b0),
        .mmio_axi_bready(mmio_axi_bready_w),
        .mmio_axi_bid({FORMAL_AXI_ID_BITS{1'b0}}),
        .mmio_axi_bresp(2'b00),
        .mmio_axi_arvalid(mmio_axi_arvalid),
        .mmio_axi_arready(1'b1),
        .mmio_axi_arid(mmio_axi_arid_w),
        .mmio_axi_araddr(mmio_axi_araddr),
        .mmio_axi_arlen(mmio_axi_arlen),
        .mmio_axi_arsize(mmio_axi_arsize),
        .mmio_axi_arburst(mmio_axi_arburst_w),
        .mmio_axi_rvalid(1'b0),
        .mmio_axi_rready(mmio_axi_rready_w),
        .mmio_axi_rid({FORMAL_AXI_ID_BITS{1'b0}}),
        .mmio_axi_rdata(32'd0),
        .mmio_axi_rresp(2'b00),
        .mmio_axi_rlast(1'b0)
    );

endmodule
