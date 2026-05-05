module axi_llc_subsystem_dual_cache_dirty_evict_writeback_formal_top(
    input             clk,
    input             rst_n,
    input             write_req_valid,
    input      [1:0]  write_req_sel,
    output            write_req_ready,
    output            write_req_accepted,
    output            write_resp_valid,
    output     [3:0]  write_resp_id,
    output     [1:0]  write_resp_code,
    output            ddr_axi_arvalid,
    output            ddr_axi_awvalid,
    input             ddr_axi_awready,
    output            ddr_axi_awid,
    output     [31:0] ddr_axi_awaddr,
    output     [7:0]  ddr_axi_awlen,
    output     [2:0]  ddr_axi_awsize,
    output     [1:0]  ddr_axi_awburst,
    output            ddr_axi_wvalid,
    input             ddr_axi_wready,
    output     [63:0] ddr_axi_wdata,
    output     [7:0]  ddr_axi_wstrb,
    output            ddr_axi_wlast,
    input             ddr_axi_bvalid,
    output            ddr_axi_bready,
    input             ddr_axi_bid,
    output            mmio_axi_arvalid,
    output            mmio_axi_awvalid,
    output            mmio_axi_wvalid,
    output            config_error
);

    localparam integer FORMAL_ADDR_BITS = 32;
    localparam integer FORMAL_ID_BITS = 4;
    localparam integer FORMAL_SLOT_ID_BITS = 4;
    localparam integer FORMAL_MODE_BITS = 3;
    localparam integer FORMAL_LINE_BYTES = 8;
    localparam integer FORMAL_LINE_BITS = 64;
    localparam integer FORMAL_LINE_OFFSET_BITS = 3;
    localparam integer FORMAL_SET_COUNT = 2;
    localparam integer FORMAL_SET_BITS = 1;
    localparam integer FORMAL_WAY_COUNT = 2;
    localparam integer FORMAL_WAY_BITS = 1;
    localparam integer FORMAL_META_BITS = 8;
    localparam integer FORMAL_LLC_SIZE_BYTES = 16;
    localparam integer FORMAL_WINDOW_BYTES = 8;
    localparam integer FORMAL_WINDOW_WAYS = 1;
    localparam integer FORMAL_DDR_DATA_BYTES = 8;
    localparam integer FORMAL_DDR_DATA_BITS = 64;
    localparam integer FORMAL_DDR_STRB_BITS = 8;
    localparam integer FORMAL_AXI_ID_BITS = 1;
    localparam integer FORMAL_MMIO_DATA_BYTES = 4;
    localparam integer FORMAL_MMIO_DATA_BITS = 32;
    localparam integer FORMAL_MMIO_STRB_BITS = 4;
    localparam integer FORMAL_READ_RESP_BYTES = 8;
    localparam integer FORMAL_READ_RESP_BITS = 64;

    localparam [FORMAL_MODE_BITS-1:0] MODE_CACHE = 3'b001;
    localparam [FORMAL_ADDR_BITS-1:0] MMIO_BASE = 32'h1000_0000;
    localparam [FORMAL_ADDR_BITS-1:0] MMIO_SIZE = 32'h0000_1000;
    localparam [FORMAL_ADDR_BITS-1:0] DDR_ADDR0 = 32'h4000_0100;
    localparam [FORMAL_ADDR_BITS-1:0] DDR_ADDR1 = 32'h4000_0120;
    localparam [FORMAL_ADDR_BITS-1:0] DDR_ADDR2 = 32'h4000_0140;
    localparam [FORMAL_LINE_BITS-1:0] WRITE_DATA0 = 64'h0102_0304_0506_0708;
    localparam [FORMAL_LINE_BITS-1:0] WRITE_DATA1 = 64'h1112_1314_1516_1718;
    localparam [FORMAL_LINE_BITS-1:0] WRITE_DATA2 = 64'h2122_2324_2526_2728;

    reg [FORMAL_ADDR_BITS-1:0] selected_write_addr;
    reg [FORMAL_LINE_BITS-1:0] selected_write_data;
    reg [FORMAL_ID_BITS-1:0] selected_write_id;

    wire read_req_ready_w;
    wire read_req_accepted_w;
    wire [FORMAL_ID_BITS-1:0] read_req_accepted_id_w;
    wire read_resp_valid_w;
    wire [FORMAL_READ_RESP_BITS-1:0] read_resp_data_w;
    wire [FORMAL_ID_BITS-1:0] read_resp_id_w;

    wire [FORMAL_AXI_ID_BITS-1:0] ddr_axi_arid_w;
    wire [FORMAL_ADDR_BITS-1:0] ddr_axi_araddr_w;
    wire [7:0] ddr_axi_arlen_w;
    wire [2:0] ddr_axi_arsize_w;
    wire [1:0] ddr_axi_arburst_w;
    wire ddr_axi_rready_w;

    wire [FORMAL_AXI_ID_BITS-1:0] mmio_axi_awid_w;
    wire [FORMAL_ADDR_BITS-1:0] mmio_axi_awaddr_w;
    wire [7:0] mmio_axi_awlen_w;
    wire [2:0] mmio_axi_awsize_w;
    wire [1:0] mmio_axi_awburst_w;
    wire [FORMAL_MMIO_DATA_BITS-1:0] mmio_axi_wdata_w;
    wire [FORMAL_MMIO_STRB_BITS-1:0] mmio_axi_wstrb_w;
    wire mmio_axi_wlast_w;
    wire mmio_axi_bready_w;
    wire [FORMAL_AXI_ID_BITS-1:0] mmio_axi_arid_w;
    wire [FORMAL_ADDR_BITS-1:0] mmio_axi_araddr_w;
    wire [7:0] mmio_axi_arlen_w;
    wire [2:0] mmio_axi_arsize_w;
    wire [1:0] mmio_axi_arburst_w;
    wire mmio_axi_rready_w;
    wire invalidate_line_accepted_w;
    wire invalidate_all_accepted_w;
    wire [FORMAL_MODE_BITS-1:0] active_mode_w;
    wire [FORMAL_ADDR_BITS-1:0] active_offset_w;
    wire reconfig_busy_w;
    wire [1:0] reconfig_state_w;

    always @(*) begin
        selected_write_addr = DDR_ADDR0;
        selected_write_data = WRITE_DATA0;
        selected_write_id = 4'h1;
        if (write_req_sel == 2'd1) begin
            selected_write_addr = DDR_ADDR1;
            selected_write_data = WRITE_DATA1;
            selected_write_id = 4'h2;
        end else if (write_req_sel == 2'd2) begin
            selected_write_addr = DDR_ADDR2;
            selected_write_data = WRITE_DATA2;
            selected_write_id = 4'h3;
        end
    end

    axi_llc_subsystem_dual #(
        .ADDR_BITS(FORMAL_ADDR_BITS),
        .ID_BITS(FORMAL_ID_BITS),
        .SLOT_ID_BITS(FORMAL_SLOT_ID_BITS),
        .MODE_BITS(FORMAL_MODE_BITS),
        .LINE_BYTES(FORMAL_LINE_BYTES),
        .LINE_BITS(FORMAL_LINE_BITS),
        .LINE_OFFSET_BITS(FORMAL_LINE_OFFSET_BITS),
        .SET_COUNT(FORMAL_SET_COUNT),
        .SET_BITS(FORMAL_SET_BITS),
        .WAY_COUNT(FORMAL_WAY_COUNT),
        .WAY_BITS(FORMAL_WAY_BITS),
        .META_BITS(FORMAL_META_BITS),
        .LLC_SIZE_BYTES(FORMAL_LLC_SIZE_BYTES),
        .WINDOW_BYTES(FORMAL_WINDOW_BYTES),
        .WINDOW_WAYS(FORMAL_WINDOW_WAYS),
        .MMIO_BASE(MMIO_BASE),
        .MMIO_SIZE(MMIO_SIZE),
        .DDR_BASE(32'h4000_0000),
        .RESET_MODE(MODE_CACHE),
        .RESET_OFFSET({FORMAL_ADDR_BITS{1'b0}}),
        .USE_SMIC12_STORES(0),
        .TABLE_READ_LATENCY(1),
        .NUM_READ_MASTERS(1),
        .NUM_WRITE_MASTERS(1),
        .DDR_AXI_ID_BITS(FORMAL_AXI_ID_BITS),
        .DDR_AXI_DATA_BYTES(FORMAL_DDR_DATA_BYTES),
        .DDR_AXI_DATA_BITS(FORMAL_DDR_DATA_BITS),
        .DDR_AXI_STRB_BITS(FORMAL_DDR_STRB_BITS),
        .MMIO_AXI_ID_BITS(FORMAL_AXI_ID_BITS),
        .MMIO_AXI_DATA_BYTES(FORMAL_MMIO_DATA_BYTES),
        .MMIO_AXI_DATA_BITS(FORMAL_MMIO_DATA_BITS),
        .MMIO_AXI_STRB_BITS(FORMAL_MMIO_STRB_BITS),
        .READ_RESP_BYTES(FORMAL_READ_RESP_BYTES),
        .READ_RESP_BITS(FORMAL_READ_RESP_BITS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .mode_req(MODE_CACHE),
        .llc_mapped_offset_req({FORMAL_ADDR_BITS{1'b0}}),
        .read_req_valid(1'b0),
        .read_req_ready(read_req_ready_w),
        .read_req_accepted(read_req_accepted_w),
        .read_req_accepted_id(read_req_accepted_id_w),
        .read_req_addr({FORMAL_ADDR_BITS{1'b0}}),
        .read_req_total_size(8'd0),
        .read_req_id({FORMAL_ID_BITS{1'b0}}),
        .read_req_bypass(1'b0),
        .read_resp_valid(read_resp_valid_w),
        .read_resp_ready(1'b1),
        .read_resp_data(read_resp_data_w),
        .read_resp_id(read_resp_id_w),
        .write_req_valid(write_req_valid),
        .write_req_ready(write_req_ready),
        .write_req_accepted(write_req_accepted),
        .write_req_addr(selected_write_addr),
        .write_req_wdata(selected_write_data),
        .write_req_wstrb({FORMAL_LINE_BYTES{1'b1}}),
        .write_req_total_size(8'd7),
        .write_req_id(selected_write_id),
        .write_req_bypass(1'b0),
        .write_resp_valid(write_resp_valid),
        .write_resp_ready(1'b1),
        .write_resp_id(write_resp_id),
        .write_resp_code(write_resp_code),
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
        .ddr_axi_bresp(2'b00),
        .ddr_axi_arvalid(ddr_axi_arvalid),
        .ddr_axi_arready(1'b0),
        .ddr_axi_arid(ddr_axi_arid_w),
        .ddr_axi_araddr(ddr_axi_araddr_w),
        .ddr_axi_arlen(ddr_axi_arlen_w),
        .ddr_axi_arsize(ddr_axi_arsize_w),
        .ddr_axi_arburst(ddr_axi_arburst_w),
        .ddr_axi_rvalid(1'b0),
        .ddr_axi_rready(ddr_axi_rready_w),
        .ddr_axi_rid({FORMAL_AXI_ID_BITS{1'b0}}),
        .ddr_axi_rdata({FORMAL_DDR_DATA_BITS{1'b0}}),
        .ddr_axi_rresp(2'b00),
        .ddr_axi_rlast(1'b0),
        .mmio_axi_awvalid(mmio_axi_awvalid),
        .mmio_axi_awready(1'b0),
        .mmio_axi_awid(mmio_axi_awid_w),
        .mmio_axi_awaddr(mmio_axi_awaddr_w),
        .mmio_axi_awlen(mmio_axi_awlen_w),
        .mmio_axi_awsize(mmio_axi_awsize_w),
        .mmio_axi_awburst(mmio_axi_awburst_w),
        .mmio_axi_wvalid(mmio_axi_wvalid),
        .mmio_axi_wready(1'b0),
        .mmio_axi_wdata(mmio_axi_wdata_w),
        .mmio_axi_wstrb(mmio_axi_wstrb_w),
        .mmio_axi_wlast(mmio_axi_wlast_w),
        .mmio_axi_bvalid(1'b0),
        .mmio_axi_bready(mmio_axi_bready_w),
        .mmio_axi_bid({FORMAL_AXI_ID_BITS{1'b0}}),
        .mmio_axi_bresp(2'b00),
        .mmio_axi_arvalid(mmio_axi_arvalid),
        .mmio_axi_arready(1'b0),
        .mmio_axi_arid(mmio_axi_arid_w),
        .mmio_axi_araddr(mmio_axi_araddr_w),
        .mmio_axi_arlen(mmio_axi_arlen_w),
        .mmio_axi_arsize(mmio_axi_arsize_w),
        .mmio_axi_arburst(mmio_axi_arburst_w),
        .mmio_axi_rvalid(1'b0),
        .mmio_axi_rready(mmio_axi_rready_w),
        .mmio_axi_rid({FORMAL_AXI_ID_BITS{1'b0}}),
        .mmio_axi_rdata({FORMAL_MMIO_DATA_BITS{1'b0}}),
        .mmio_axi_rresp(2'b00),
        .mmio_axi_rlast(1'b0),
        .invalidate_line_valid(1'b0),
        .invalidate_line_addr({FORMAL_ADDR_BITS{1'b0}}),
        .invalidate_line_accepted(invalidate_line_accepted_w),
        .invalidate_all_valid(1'b0),
        .invalidate_all_accepted(invalidate_all_accepted_w),
        .active_mode(active_mode_w),
        .active_offset(active_offset_w),
        .reconfig_busy(reconfig_busy_w),
        .reconfig_state(reconfig_state_w),
        .config_error(config_error)
    );

endmodule
