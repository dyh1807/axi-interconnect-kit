module cache_ctrl_table_oracle_dirty_evict_then_read_formal_top(
    input             clk,
    input             rst_n,
    input             req_valid,
    input             req_write,
    output            req_ready,
    output            resp_valid,
    output     [63:0] resp_rdata,
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

    localparam [FORMAL_ADDR_BITS-1:0] REQ_ADDR = 32'h4000_0140;
    localparam [FORMAL_LINE_BITS-1:0] VICTIM_DATA = 64'h0102_0304_0506_0708;
    localparam [FORMAL_LINE_BITS-1:0] OTHER_DATA = 64'h1112_1314_1516_1718;
    localparam [FORMAL_LINE_BITS-1:0] REQ_DATA = 64'h2122_2324_2526_2728;
    localparam [FORMAL_META_BITS-1:0] VICTIM_META = 8'h90;
    localparam [FORMAL_META_BITS-1:0] OTHER_META = 8'h92;

    reg [FORMAL_DATA_ROW_BITS-1:0] data_row_r;
    reg [FORMAL_META_ROW_BITS-1:0] meta_row_r;
    reg [FORMAL_WAY_COUNT-1:0] valid_bits_r;
    reg [FORMAL_WAY_BITS-1:0] repl_way_r;

    wire [FORMAL_DATA_ROW_BITS-1:0] data_wr_row_w;
    wire [FORMAL_SET_BITS-1:0] data_rd_set_w;
    wire [FORMAL_SET_BITS-1:0] data_wr_set_w;
    wire data_rd_en_w;
    wire data_busy_w;
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

    assign data_busy_w = 1'b0;
    assign meta_busy_w = 1'b0;
    assign data_wr_line0 = data_wr_row_w[63:0];
    assign data_wr_line1 = data_wr_row_w[127:64];
    assign meta_wr_way0 = meta_wr_row_w[7:0];
    assign meta_wr_way1 = meta_wr_row_w[15:8];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_row_r <= {OTHER_DATA, VICTIM_DATA};
            meta_row_r <= {OTHER_META, VICTIM_META};
            valid_bits_r <= 2'b11;
            repl_way_r <= 1'b0;
        end else begin
            if (data_wr_en) begin
                if (data_wr_way_mask[0]) begin
                    data_row_r[63:0] <= data_wr_row_w[63:0];
                end
                if (data_wr_way_mask[1]) begin
                    data_row_r[127:64] <= data_wr_row_w[127:64];
                end
            end
            if (meta_wr_en) begin
                if (meta_wr_way_mask[0]) begin
                    meta_row_r[7:0] <= meta_wr_row_w[7:0];
                end
                if (meta_wr_way_mask[1]) begin
                    meta_row_r[15:8] <= meta_wr_row_w[15:8];
                end
            end
            if (valid_wr_en) begin
                valid_bits_r <= (valid_bits_r & (~valid_wr_mask)) |
                                (valid_wr_bits & valid_wr_mask);
            end
            if (repl_wr_en) begin
                repl_way_r <= repl_wr_way;
            end
        end
    end

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
        .req_write(req_write),
        .req_bypass(1'b0),
        .req_addr(REQ_ADDR),
        .req_id(4'h0),
        .req_total_size(8'd7),
        .req_wdata(REQ_DATA),
        .req_wstrb({FORMAL_LINE_BYTES{1'b1}}),
        .resp_valid(resp_valid),
        .resp_ready(1'b1),
        .resp_rdata(resp_rdata),
        .resp_id(resp_id),
        .resp_code(resp_code),
        .invalidate_line_valid(1'b0),
        .invalidate_line_addr({FORMAL_ADDR_BITS{1'b0}}),
        .invalidate_line_accepted(),
        .data_rd_en(data_rd_en_w),
        .data_rd_set(data_rd_set_w),
        .data_rd_valid(1'b1),
        .data_rd_row(data_row_r),
        .data_wr_en(data_wr_en),
        .data_wr_set(data_wr_set_w),
        .data_wr_way_mask(data_wr_way_mask),
        .data_wr_row(data_wr_row_w),
        .data_busy(data_busy_w),
        .meta_rd_en(meta_rd_en_w),
        .meta_rd_set(meta_rd_set_w),
        .meta_rd_valid(1'b1),
        .meta_rd_row(meta_row_r),
        .meta_wr_en(meta_wr_en),
        .meta_wr_set(meta_wr_set_w),
        .meta_wr_way_mask(meta_wr_way_mask),
        .meta_wr_row(meta_wr_row_w),
        .meta_busy(meta_busy_w),
        .valid_rd_en(valid_rd_en_w),
        .valid_rd_set(valid_rd_set_w),
        .valid_rd_valid(1'b1),
        .valid_rd_bits(valid_bits_r),
        .valid_wr_en(valid_wr_en),
        .valid_wr_set(valid_wr_set_w),
        .valid_wr_mask(valid_wr_mask),
        .valid_wr_bits(valid_wr_bits),
        .repl_rd_en(repl_rd_en_w),
        .repl_rd_set(repl_rd_set_w),
        .repl_rd_valid(1'b1),
        .repl_rd_way(repl_way_r),
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
        .mem_resp_rdata({FORMAL_READ_RESP_BITS{1'b0}}),
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
