module cache_ctrl_partial_write_miss_refill_formal_top(
    input             clk,
    input             rst_n,
    input             req_valid,
    output            req_ready,
    output            resp_valid,
    output     [3:0]  resp_id,
    output     [1:0]  resp_code,
    output            data_wr_en,
    output     [1:0]  data_wr_way_mask,
    output     [63:0] data_wr_line0,
    output     [63:0] data_wr_line1,
    output            meta_wr_en,
    output     [1:0]  meta_wr_way_mask,
    output     [7:0]  meta_wr_way0,
    output     [7:0]  meta_wr_way1,
    output            valid_wr_en,
    output     [1:0]  valid_wr_mask,
    output     [1:0]  valid_wr_bits,
    output            repl_wr_en,
    output            repl_wr_way,
    output            mem_req_valid,
    input             mem_req_ready,
    output            mem_req_write,
    output     [31:0] mem_req_addr,
    output     [3:0]  mem_req_id,
    output     [63:0] mem_req_wdata,
    output     [7:0]  mem_req_wstrb,
    output     [7:0]  mem_req_size,
    input             mem_resp_valid,
    output            mem_resp_ready,
    input      [3:0]  mem_resp_id
);

    localparam integer FORMAL_ADDR_BITS = 32;
    localparam integer FORMAL_ID_BITS = 4;
    localparam integer FORMAL_LINE_BYTES = 8;
    localparam integer FORMAL_LINE_BITS = 64;
    localparam integer FORMAL_LINE_OFFSET_BITS = 3;
    localparam integer FORMAL_SET_COUNT = 2;
    localparam integer FORMAL_SET_BITS = 1;
    localparam integer FORMAL_WAY_COUNT = 2;
    localparam integer FORMAL_WAY_BITS = 1;
    localparam integer FORMAL_META_BITS = 8;
    localparam integer FORMAL_READ_RESP_BYTES = 8;
    localparam integer FORMAL_READ_RESP_BITS = 64;
    localparam integer FORMAL_DATA_ROW_BITS = FORMAL_WAY_COUNT * FORMAL_LINE_BITS;
    localparam integer FORMAL_META_ROW_BITS = FORMAL_WAY_COUNT * FORMAL_META_BITS;

    localparam [FORMAL_ADDR_BITS-1:0] REQ_ADDR = 32'h4000_0102;
    localparam [FORMAL_LINE_BITS-1:0] REQ_DATA = 64'h0000_0000_0000_bbaa;
    localparam [FORMAL_LINE_BYTES-1:0] REQ_STRB = 8'h03;
    localparam [FORMAL_READ_RESP_BITS-1:0] REFILL_DATA = 64'h1122_3344_5566_7788;

    wire [FORMAL_DATA_ROW_BITS-1:0] data_rd_row_w;
    wire [FORMAL_DATA_ROW_BITS-1:0] data_wr_row_w;
    wire [FORMAL_SET_BITS-1:0] data_rd_set_w;
    wire [FORMAL_SET_BITS-1:0] data_wr_set_w;
    wire data_rd_en_w;
    wire data_busy_w;
    wire [FORMAL_META_ROW_BITS-1:0] meta_rd_row_w;
    wire [FORMAL_META_ROW_BITS-1:0] meta_wr_row_w;
    wire [FORMAL_SET_BITS-1:0] meta_rd_set_w;
    wire [FORMAL_SET_BITS-1:0] meta_wr_set_w;
    wire meta_rd_en_w;
    wire meta_busy_w;
    wire valid_rd_en_w;
    wire [FORMAL_SET_BITS-1:0] valid_rd_set_w;
    wire [FORMAL_SET_BITS-1:0] valid_wr_set_w;
    wire repl_rd_en_w;
    wire [FORMAL_SET_BITS-1:0] repl_rd_set_w;
    wire [FORMAL_SET_BITS-1:0] repl_wr_set_w;
    wire flush_busy_w;
    wire dirty_present_w;
    wire quiescent_w;
    wire [31:0] victim_line_valid_w;
    wire [(32*FORMAL_ADDR_BITS)-1:0] victim_line_addr_w;
    wire bypass_req_valid_w;
    wire bypass_req_write_w;
    wire [FORMAL_ADDR_BITS-1:0] bypass_req_addr_w;
    wire [FORMAL_ID_BITS-1:0] bypass_req_id_w;
    wire [7:0] bypass_req_size_w;
    wire [FORMAL_LINE_BITS-1:0] bypass_req_wdata_w;
    wire [FORMAL_LINE_BYTES-1:0] bypass_req_wstrb_w;
    wire bypass_resp_ready_w;
    wire [FORMAL_READ_RESP_BITS-1:0] resp_rdata_w;

    assign data_rd_row_w = {FORMAL_DATA_ROW_BITS{1'b0}};
    assign meta_rd_row_w = {FORMAL_META_ROW_BITS{1'b0}};
    assign data_busy_w = 1'b0;
    assign meta_busy_w = 1'b0;
    assign data_wr_line0 = data_wr_row_w[63:0];
    assign data_wr_line1 = data_wr_row_w[127:64];
    assign meta_wr_way0 = meta_wr_row_w[7:0];
    assign meta_wr_way1 = meta_wr_row_w[15:8];

    llc_cache_ctrl #(
        .ADDR_BITS(FORMAL_ADDR_BITS),
        .ID_BITS(FORMAL_ID_BITS),
        .LINE_BYTES(FORMAL_LINE_BYTES),
        .LINE_BITS(FORMAL_LINE_BITS),
        .LINE_OFFSET_BITS(FORMAL_LINE_OFFSET_BITS),
        .SET_COUNT(FORMAL_SET_COUNT),
        .SET_BITS(FORMAL_SET_BITS),
        .WAY_COUNT(FORMAL_WAY_COUNT),
        .WAY_BITS(FORMAL_WAY_BITS),
        .META_BITS(FORMAL_META_BITS),
        .READ_RESP_BYTES(FORMAL_READ_RESP_BYTES),
        .READ_RESP_BITS(FORMAL_READ_RESP_BITS),
        .DATA_ROW_BITS(FORMAL_DATA_ROW_BITS),
        .META_ROW_BITS(FORMAL_META_ROW_BITS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(req_valid),
        .req_ready(req_ready),
        .req_write(1'b1),
        .req_bypass(1'b0),
        .req_addr(REQ_ADDR),
        .req_id(4'h0),
        .req_total_size(8'd1),
        .req_wdata(REQ_DATA),
        .req_wstrb(REQ_STRB),
        .resp_valid(resp_valid),
        .resp_ready(1'b1),
        .resp_rdata(resp_rdata_w),
        .resp_id(resp_id),
        .resp_code(resp_code),
        .invalidate_line_valid(1'b0),
        .invalidate_line_addr({FORMAL_ADDR_BITS{1'b0}}),
        .invalidate_line_accepted(),
        .data_rd_en(data_rd_en_w),
        .data_rd_set(data_rd_set_w),
        .data_rd_valid(1'b1),
        .data_rd_row(data_rd_row_w),
        .data_wr_en(data_wr_en),
        .data_wr_set(data_wr_set_w),
        .data_wr_way_mask(data_wr_way_mask),
        .data_wr_row(data_wr_row_w),
        .data_busy(data_busy_w),
        .meta_rd_en(meta_rd_en_w),
        .meta_rd_set(meta_rd_set_w),
        .meta_rd_valid(1'b1),
        .meta_rd_row(meta_rd_row_w),
        .meta_wr_en(meta_wr_en),
        .meta_wr_set(meta_wr_set_w),
        .meta_wr_way_mask(meta_wr_way_mask),
        .meta_wr_row(meta_wr_row_w),
        .meta_busy(meta_busy_w),
        .valid_rd_en(valid_rd_en_w),
        .valid_rd_set(valid_rd_set_w),
        .valid_rd_valid(1'b1),
        .valid_rd_bits(2'b00),
        .valid_wr_en(valid_wr_en),
        .valid_wr_set(valid_wr_set_w),
        .valid_wr_mask(valid_wr_mask),
        .valid_wr_bits(valid_wr_bits),
        .repl_rd_en(repl_rd_en_w),
        .repl_rd_set(repl_rd_set_w),
        .repl_rd_valid(1'b1),
        .repl_rd_way(1'b0),
        .repl_wr_en(repl_wr_en),
        .repl_wr_set(repl_wr_set_w),
        .repl_wr_way(repl_wr_way),
        .flush_start(1'b0),
        .flush_busy(flush_busy_w),
        .dirty_present(dirty_present_w),
        .quiescent(quiescent_w),
        .victim_line_valid(victim_line_valid_w),
        .victim_line_addr(victim_line_addr_w),
        .mem_req_valid(mem_req_valid),
        .mem_req_ready(mem_req_ready),
        .mem_req_write(mem_req_write),
        .mem_req_addr(mem_req_addr),
        .mem_req_id(mem_req_id),
        .mem_req_wdata(mem_req_wdata),
        .mem_req_wstrb(mem_req_wstrb),
        .mem_req_size(mem_req_size),
        .mem_resp_valid(mem_resp_valid),
        .mem_resp_ready(mem_resp_ready),
        .mem_resp_rdata(REFILL_DATA),
        .mem_resp_id(mem_resp_id),
        .mem_resp_code(2'b00),
        .bypass_req_valid(bypass_req_valid_w),
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
        .bypass_resp_code(2'b00)
    );

endmodule
