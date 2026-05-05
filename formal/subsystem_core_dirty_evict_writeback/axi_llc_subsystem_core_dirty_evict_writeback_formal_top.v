module axi_llc_subsystem_core_dirty_evict_writeback_formal_top(
    input             clk,
    input             rst_n,
    input             up_req_valid,
    input      [1:0]  up_req_sel,
    output            up_req_ready,
    output            up_resp_valid,
    output     [3:0]  up_resp_id,
    output     [1:0]  up_resp_code,
    output            cache_req_valid,
    input             cache_req_ready,
    output            cache_req_write,
    output     [31:0] cache_req_addr,
    output     [3:0]  cache_req_id,
    output     [7:0]  cache_req_size,
    output     [63:0] cache_req_wdata,
    output     [7:0]  cache_req_wstrb,
    input             cache_resp_valid,
    output            cache_resp_ready,
    input      [3:0]  cache_resp_id,
    output            bypass_req_valid,
    output            config_error,
    output     [2:0]  active_mode,
    output     [1:0]  reconfig_state
);

    localparam integer FORMAL_ADDR_BITS = 32;
    localparam integer FORMAL_ID_BITS = 4;
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
    localparam integer FORMAL_READ_RESP_BYTES = 8;
    localparam integer FORMAL_READ_RESP_BITS = 64;
    localparam integer FORMAL_DATA_ROW_BITS = FORMAL_WAY_COUNT * FORMAL_LINE_BITS;
    localparam integer FORMAL_META_ROW_BITS = FORMAL_WAY_COUNT * FORMAL_META_BITS;

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

    wire [FORMAL_READ_RESP_BITS-1:0] up_resp_rdata_w;
    wire [FORMAL_READ_RESP_BITS-1:0] cache_resp_rdata_w;
    wire [FORMAL_LINE_BITS-1:0] bypass_req_wdata_w;
    wire [FORMAL_LINE_BYTES-1:0] bypass_req_wstrb_w;
    wire [FORMAL_ADDR_BITS-1:0] bypass_req_addr_w;
    wire [FORMAL_ID_BITS-1:0] bypass_req_id_w;
    wire [7:0] bypass_req_size_w;
    wire bypass_req_write_w;
    wire bypass_resp_ready_w;
    wire invalidate_line_accepted_w;
    wire invalidate_all_accepted_w;
    wire [FORMAL_MODE_BITS-1:0] active_mode_w;
    wire [FORMAL_ADDR_BITS-1:0] active_offset_w;
    wire reconfig_busy_w;
    wire [1:0] reconfig_state_w;
    wire [1:0] victim_line_valid_w;
    wire [(2*FORMAL_ADDR_BITS)-1:0] victim_line_addr_w;

    assign cache_resp_rdata_w = {FORMAL_READ_RESP_BITS{1'b0}};
    assign active_mode = active_mode_w;
    assign reconfig_state = reconfig_state_w;

    always @(*) begin
        selected_write_addr = DDR_ADDR0;
        selected_write_data = WRITE_DATA0;
        selected_write_id = 4'h0;
        if (up_req_sel == 2'd1) begin
            selected_write_addr = DDR_ADDR1;
            selected_write_data = WRITE_DATA1;
            selected_write_id = 4'h1;
        end else if (up_req_sel == 2'd2) begin
            selected_write_addr = DDR_ADDR2;
            selected_write_data = WRITE_DATA2;
            selected_write_id = 4'h0;
        end
    end

    axi_llc_subsystem_core #(
        .ADDR_BITS(FORMAL_ADDR_BITS),
        .ID_BITS(FORMAL_ID_BITS),
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
        .RESET_MODE(MODE_CACHE),
        .RESET_OFFSET({FORMAL_ADDR_BITS{1'b0}}),
        .USE_SMIC12_STORES(0),
        .TABLE_READ_LATENCY(1),
        .READ_RESP_BYTES(FORMAL_READ_RESP_BYTES),
        .READ_RESP_BITS(FORMAL_READ_RESP_BITS),
        .DATA_ROW_BITS(FORMAL_DATA_ROW_BITS),
        .META_ROW_BITS(FORMAL_META_ROW_BITS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .mode_req(MODE_CACHE),
        .llc_mapped_offset_req({FORMAL_ADDR_BITS{1'b0}}),
        .up_req_valid(up_req_valid),
        .up_req_ready(up_req_ready),
        .up_req_write(1'b1),
        .up_req_addr(selected_write_addr),
        .up_req_id(selected_write_id),
        .up_req_total_size(8'd7),
        .up_req_wdata(selected_write_data),
        .up_req_wstrb({FORMAL_LINE_BYTES{1'b1}}),
        .up_req_bypass(1'b0),
        .up_resp_valid(up_resp_valid),
        .up_resp_ready(1'b1),
        .up_resp_rdata(up_resp_rdata_w),
        .up_resp_id(up_resp_id),
        .up_resp_code(up_resp_code),
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
        .cache_resp_rdata(cache_resp_rdata_w),
        .cache_resp_id(cache_resp_id),
        .cache_resp_code(2'b00),
        .bypass_req_valid(bypass_req_valid),
        .bypass_req_ready(1'b0),
        .bypass_req_write(bypass_req_write_w),
        .bypass_req_addr(bypass_req_addr_w),
        .bypass_req_id(bypass_req_id_w),
        .bypass_req_size(bypass_req_size_w),
        .bypass_req_wdata(bypass_req_wdata_w),
        .bypass_req_wstrb(bypass_req_wstrb_w),
        .bypass_resp_valid(1'b0),
        .bypass_resp_ready(bypass_resp_ready_w),
        .bypass_resp_rdata({FORMAL_READ_RESP_BITS{1'b0}}),
        .bypass_resp_id({FORMAL_ID_BITS{1'b0}}),
        .bypass_resp_code(2'b00),
        .invalidate_line_valid(1'b0),
        .invalidate_line_addr({FORMAL_ADDR_BITS{1'b0}}),
        .invalidate_line_accepted(invalidate_line_accepted_w),
        .invalidate_all_valid(1'b0),
        .invalidate_all_accepted(invalidate_all_accepted_w),
        .active_mode(active_mode_w),
        .active_offset(active_offset_w),
        .reconfig_busy(reconfig_busy_w),
        .reconfig_state(reconfig_state_w),
        .config_error(config_error),
        .victim_line_valid(victim_line_valid_w),
        .victim_line_addr(victim_line_addr_w)
    );

endmodule
