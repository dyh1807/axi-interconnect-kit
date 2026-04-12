`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module llc_cache_ctrl #(
    parameter ADDR_BITS        = `AXI_LLC_ADDR_BITS,
    parameter ID_BITS          = `AXI_LLC_ID_BITS,
    parameter LINE_BYTES       = `AXI_LLC_LINE_BYTES,
    parameter LINE_BITS        = `AXI_LLC_LINE_BITS,
    parameter LINE_OFFSET_BITS = `AXI_LLC_LINE_OFFSET_BITS,
    parameter SET_COUNT        = `AXI_LLC_SET_COUNT,
    parameter SET_BITS         = `AXI_LLC_SET_BITS,
    parameter WAY_COUNT        = `AXI_LLC_WAY_COUNT,
    parameter WAY_BITS         = `AXI_LLC_WAY_BITS,
    parameter META_BITS        = `AXI_LLC_META_BITS,
    parameter DATA_ROW_BITS    = WAY_COUNT * LINE_BITS,
    parameter META_ROW_BITS    = WAY_COUNT * META_BITS,
    parameter TAG_BITS         = ADDR_BITS - SET_BITS - LINE_OFFSET_BITS
) (
    input                       clk,
    input                       rst_n,
    input                       req_valid,
    output                      req_ready,
    input                       req_write,
    input      [ADDR_BITS-1:0]  req_addr,
    input      [ID_BITS-1:0]    req_id,
    input      [7:0]            req_total_size,
    input      [LINE_BITS-1:0]  req_wdata,
    input      [LINE_BYTES-1:0] req_wstrb,
    output                      resp_valid,
    input                       resp_ready,
    output     [LINE_BITS-1:0]  resp_rdata,
    output     [ID_BITS-1:0]    resp_id,
    input                       invalidate_line_valid,
    input      [ADDR_BITS-1:0]  invalidate_line_addr,
    output                      invalidate_line_accepted,
    output                      data_rd_en,
    output     [SET_BITS-1:0]   data_rd_set,
    input                       data_rd_valid,
    input      [DATA_ROW_BITS-1:0] data_rd_row,
    output                      data_wr_en,
    output     [SET_BITS-1:0]   data_wr_set,
    output     [WAY_COUNT-1:0]  data_wr_way_mask,
    output     [DATA_ROW_BITS-1:0] data_wr_row,
    input                       data_busy,
    output                      meta_rd_en,
    output     [SET_BITS-1:0]   meta_rd_set,
    input                       meta_rd_valid,
    input      [META_ROW_BITS-1:0] meta_rd_row,
    output                      meta_wr_en,
    output     [SET_BITS-1:0]   meta_wr_set,
    output     [WAY_COUNT-1:0]  meta_wr_way_mask,
    output     [META_ROW_BITS-1:0] meta_wr_row,
    input                       meta_busy,
    output     [SET_BITS-1:0]   valid_rd_set,
    input      [WAY_COUNT-1:0]  valid_rd_bits,
    output                      valid_wr_en,
    output     [SET_BITS-1:0]   valid_wr_set,
    output     [WAY_COUNT-1:0]  valid_wr_mask,
    output     [WAY_COUNT-1:0]  valid_wr_bits,
    output     [SET_BITS-1:0]   repl_rd_set,
    input      [WAY_BITS-1:0]   repl_rd_way,
    output                      repl_wr_en,
    output     [SET_BITS-1:0]   repl_wr_set,
    output     [WAY_BITS-1:0]   repl_wr_way,
    input                       flush_start,
    output                      flush_busy,
    output                      dirty_present,
    output                      quiescent,
    output                      mem_req_valid,
    input                       mem_req_ready,
    output                      mem_req_write,
    output     [ADDR_BITS-1:0]  mem_req_addr,
    output     [ID_BITS-1:0]    mem_req_id,
    output     [LINE_BITS-1:0]  mem_req_wdata,
    output     [LINE_BYTES-1:0] mem_req_wstrb,
    output     [7:0]            mem_req_size,
    input                       mem_resp_valid,
    output                      mem_resp_ready,
    input      [LINE_BITS-1:0]  mem_resp_rdata,
    input      [ID_BITS-1:0]    mem_resp_id
);

    localparam [3:0] ST_IDLE            = 4'd0;
    localparam [3:0] ST_LOOKUP_WAIT     = 4'd1;
    localparam [3:0] ST_WRITE_HIT       = 4'd2;
    localparam [3:0] ST_MISS_WB_REQ     = 4'd3;
    localparam [3:0] ST_MISS_WB_WAIT    = 4'd4;
    localparam [3:0] ST_REFILL_REQ      = 4'd5;
    localparam [3:0] ST_REFILL_WAIT     = 4'd6;
    localparam [3:0] ST_INSTALL         = 4'd7;
    localparam [3:0] ST_FLUSH_SCAN_REQ  = 4'd8;
    localparam [3:0] ST_FLUSH_SCAN_WAIT = 4'd9;
    localparam [3:0] ST_FLUSH_WB_REQ    = 4'd10;
    localparam [3:0] ST_FLUSH_WB_WAIT   = 4'd11;
    localparam [ID_BITS-1:0] WRITEBACK_MEM_ID = {ID_BITS{1'b0}};
    localparam [ID_BITS-1:0] DEMAND_MEM_ID =
        {{(ID_BITS-1){1'b0}}, 1'b1};
    localparam integer RESP_WORD_BITS = 32;
    localparam integer RESP_WORDS = LINE_BITS / RESP_WORD_BITS;
    localparam integer META_TAG_BITS = (TAG_BITS < (META_BITS - 1)) ?
                                       TAG_BITS : (META_BITS - 1);

    reg [3:0] state_r;
    reg       req_write_r;
    reg [ADDR_BITS-1:0] req_addr_r;
    reg [ID_BITS-1:0] req_id_r;
    reg [7:0] req_total_size_r;
    reg [LINE_BITS-1:0] req_wdata_r;
    reg [LINE_BYTES-1:0] req_wstrb_r;
    reg [SET_BITS-1:0] req_set_r;
    reg [TAG_BITS-1:0] req_tag_r;
    reg                req_invalidate_r;

    reg [WAY_BITS-1:0] hit_way_r;
    reg                hit_dirty_r;
    reg [WAY_BITS-1:0] install_way_r;
    reg [LINE_BITS-1:0] install_line_r;
    reg                install_dirty_r;
    reg                replace_dirty_r;
    reg [ADDR_BITS-1:0] victim_addr_r;
    reg [LINE_BITS-1:0] victim_data_r;

    reg [SET_BITS-1:0] flush_set_r;
    reg [WAY_BITS-1:0] flush_way_start_r;
    reg [ADDR_BITS-1:0] flush_wb_addr_r;
    reg [LINE_BITS-1:0] flush_wb_data_r;
    reg [31:0] dirty_count_r;

    reg                resp_valid_r;
    reg [LINE_BITS-1:0] resp_rdata_r;

    reg                lookup_hit_r;
    reg [WAY_BITS-1:0] lookup_hit_way_r;
    reg [LINE_BITS-1:0] lookup_hit_line_r;
    reg                lookup_hit_dirty_r;
    reg                lookup_victim_valid_r;
    reg                lookup_victim_dirty_r;
    reg                lookup_found_invalid_r;
    reg [WAY_BITS-1:0] lookup_select_way_r;
    reg [LINE_BITS-1:0] lookup_victim_line_r;
    reg [ADDR_BITS-1:0] lookup_victim_addr_r;

    reg                flush_found_dirty_r;
    reg [WAY_BITS-1:0] flush_found_way_r;
    reg [LINE_BITS-1:0] flush_found_line_r;
    reg [ADDR_BITS-1:0] flush_found_addr_r;
    reg [SET_BITS-1:0] flush_next_set_r;
    reg [WAY_BITS-1:0] flush_next_way_r;

    integer lookup_way_idx;
    integer flush_way_idx;

    function [META_BITS-1:0] make_meta;
        input [TAG_BITS-1:0] tag_value;
        input dirty_value;
        begin
            make_meta = {META_BITS{1'b0}};
            make_meta[META_TAG_BITS-1:0] = tag_value[META_TAG_BITS-1:0];
            make_meta[META_TAG_BITS] = dirty_value;
        end
    endfunction

    function [TAG_BITS-1:0] meta_tag;
        input [META_BITS-1:0] meta_value;
        begin
            meta_tag = {TAG_BITS{1'b0}};
            meta_tag[META_TAG_BITS-1:0] = meta_value[META_TAG_BITS-1:0];
        end
    endfunction

    function meta_dirty;
        input [META_BITS-1:0] meta_value;
        begin
            meta_dirty = meta_value[META_TAG_BITS];
        end
    endfunction

    function [LINE_BITS-1:0] extract_line;
        input [DATA_ROW_BITS-1:0] row_value;
        input [WAY_BITS-1:0]      way_value;
        integer idx;
        begin
            extract_line = {LINE_BITS{1'b0}};
            for (idx = 0; idx < WAY_COUNT; idx = idx + 1) begin
                if (way_value == idx[WAY_BITS-1:0]) begin
                    extract_line = row_value[(idx * LINE_BITS) +: LINE_BITS];
                end
            end
        end
    endfunction

    function [META_BITS-1:0] extract_meta;
        input [META_ROW_BITS-1:0] row_value;
        input [WAY_BITS-1:0]      way_value;
        integer idx;
        begin
            extract_meta = {META_BITS{1'b0}};
            for (idx = 0; idx < WAY_COUNT; idx = idx + 1) begin
                if (way_value == idx[WAY_BITS-1:0]) begin
                    extract_meta = row_value[(idx * META_BITS) +: META_BITS];
                end
            end
        end
    endfunction

    function [LINE_BITS-1:0] merge_line;
        input [LINE_BITS-1:0] base_line;
        input [ADDR_BITS-1:0] addr_value;
        input [LINE_BITS-1:0] write_data;
        input [LINE_BYTES-1:0] write_strb;
        integer idx;
        integer line_off;
        integer dst_idx;
        begin
            merge_line = base_line;
            line_off = addr_value[LINE_OFFSET_BITS-1:0];
            for (idx = 0; idx < LINE_BYTES; idx = idx + 1) begin
                dst_idx = line_off + idx;
                if (write_strb[idx] && (dst_idx < LINE_BYTES)) begin
                    merge_line[(dst_idx * 8) +: 8] = write_data[(idx * 8) +: 8];
                end
            end
        end
    endfunction

    function [DATA_ROW_BITS-1:0] place_line_in_row;
        input [WAY_BITS-1:0]      way_value;
        input [LINE_BITS-1:0]     line_value;
        integer idx;
        begin
            place_line_in_row = {DATA_ROW_BITS{1'b0}};
            for (idx = 0; idx < WAY_COUNT; idx = idx + 1) begin
                if (way_value == idx[WAY_BITS-1:0]) begin
                    place_line_in_row[(idx * LINE_BITS) +: LINE_BITS] = line_value;
                end
            end
        end
    endfunction

    function [META_ROW_BITS-1:0] place_meta_in_row;
        input [WAY_BITS-1:0]      way_value;
        input [META_BITS-1:0]     meta_value;
        integer idx;
        begin
            place_meta_in_row = {META_ROW_BITS{1'b0}};
            for (idx = 0; idx < WAY_COUNT; idx = idx + 1) begin
                if (way_value == idx[WAY_BITS-1:0]) begin
                    place_meta_in_row[(idx * META_BITS) +: META_BITS] = meta_value;
                end
            end
        end
    endfunction

    function [WAY_COUNT-1:0] way_onehot;
        input [WAY_BITS-1:0] way_value;
        integer idx;
        begin
            way_onehot = {WAY_COUNT{1'b0}};
            for (idx = 0; idx < WAY_COUNT; idx = idx + 1) begin
                if (way_value == idx[WAY_BITS-1:0]) begin
                    way_onehot[idx] = 1'b1;
                end
            end
        end
    endfunction

    function [WAY_BITS-1:0] next_way;
        input [WAY_BITS-1:0] way_value;
        begin
            if (way_value == (WAY_COUNT - 1)) begin
                next_way = {WAY_BITS{1'b0}};
            end else begin
                next_way = way_value + {{(WAY_BITS-1){1'b0}}, 1'b1};
            end
        end
    endfunction

    function [ADDR_BITS-1:0] line_align_addr;
        input [ADDR_BITS-1:0] addr_value;
        begin
            line_align_addr = {addr_value[ADDR_BITS-1:LINE_OFFSET_BITS],
                               {LINE_OFFSET_BITS{1'b0}}};
        end
    endfunction

    function [ADDR_BITS-1:0] build_line_addr;
        input [TAG_BITS-1:0] tag_value;
        input [SET_BITS-1:0] set_value;
        begin
            build_line_addr = {tag_value, set_value, {LINE_OFFSET_BITS{1'b0}}};
        end
    endfunction

    function [LINE_BITS-1:0] extract_read_response;
        input [ADDR_BITS-1:0] addr_value;
        input [LINE_BITS-1:0] line_value;
        integer dst_idx;
        integer src_idx;
        integer start_word;
        begin
            extract_read_response = {LINE_BITS{1'b0}};
            start_word = addr_value[LINE_OFFSET_BITS-1:2];
            for (dst_idx = 0; dst_idx < RESP_WORDS; dst_idx = dst_idx + 1) begin
                src_idx = start_word + dst_idx;
                if (src_idx < RESP_WORDS) begin
                    extract_read_response[(dst_idx * RESP_WORD_BITS) +: RESP_WORD_BITS] =
                        line_value[(src_idx * RESP_WORD_BITS) +: RESP_WORD_BITS];
                end
            end
        end
    endfunction

    wire [SET_BITS-1:0] req_set_w;
    wire [TAG_BITS-1:0] req_tag_w;
    wire                full_write_w;
    wire                store_write_busy_w;
    wire                launch_lookup_w;
    wire                launch_invalidate_lookup_w;
    wire                launch_flush_scan_w;
    wire                accept_invalidate_line_w;
    wire                invalidate_valid_clear_w;
    wire [SET_BITS-1:0] active_lookup_set_w;
    wire [SET_BITS-1:0] active_valid_set_w;
    wire [SET_BITS-1:0] invalidate_lookup_set_w;
    wire [ID_BITS-1:0] expected_mem_resp_id_w;
    wire                mem_resp_match_w;

    assign req_set_w = req_addr[LINE_OFFSET_BITS + SET_BITS - 1:LINE_OFFSET_BITS];
    assign req_tag_w = req_addr[ADDR_BITS-1:LINE_OFFSET_BITS + SET_BITS];
    assign full_write_w = (req_addr_r[LINE_OFFSET_BITS-1:0] == {LINE_OFFSET_BITS{1'b0}}) &&
                          ((req_total_size_r + 8'd1) == LINE_BYTES[7:0]) &&
                          (&req_wstrb_r);
    assign store_write_busy_w = data_busy | meta_busy;
    assign req_ready = (state_r == ST_IDLE) && !resp_valid_r && !flush_start &&
                       !store_write_busy_w;
    assign accept_invalidate_line_w = (state_r == ST_IDLE) &&
                                      !resp_valid_r &&
                                      !flush_start &&
                                      !store_write_busy_w &&
                                      invalidate_line_valid;
    assign invalidate_line_accepted = accept_invalidate_line_w;
    assign quiescent = (state_r == ST_IDLE) && !resp_valid_r;
    assign flush_busy = (state_r == ST_FLUSH_SCAN_REQ) ||
                        (state_r == ST_FLUSH_SCAN_WAIT) ||
                        (state_r == ST_FLUSH_WB_REQ) ||
                        (state_r == ST_FLUSH_WB_WAIT);
    assign dirty_present = (dirty_count_r != 0);

    assign launch_lookup_w = (state_r == ST_IDLE) && req_valid && req_ready;
    assign launch_invalidate_lookup_w = accept_invalidate_line_w;
    assign launch_flush_scan_w = (state_r == ST_FLUSH_SCAN_REQ);
    assign active_lookup_set_w = (state_r == ST_IDLE) ? req_set_w : req_set_r;
    assign active_valid_set_w = flush_busy ? flush_set_r : active_lookup_set_w;
    assign invalidate_lookup_set_w =
        invalidate_line_addr[LINE_OFFSET_BITS + SET_BITS - 1:LINE_OFFSET_BITS];

    assign data_rd_en = launch_lookup_w || launch_invalidate_lookup_w || launch_flush_scan_w;
    assign data_rd_set = launch_flush_scan_w ? flush_set_r :
                         launch_invalidate_lookup_w ? invalidate_lookup_set_w :
                         req_set_w;
    assign meta_rd_en = launch_lookup_w || launch_invalidate_lookup_w || launch_flush_scan_w;
    assign meta_rd_set = launch_flush_scan_w ? flush_set_r :
                         launch_invalidate_lookup_w ? invalidate_lookup_set_w :
                         req_set_w;

    assign data_wr_en = (state_r == ST_WRITE_HIT) || (state_r == ST_INSTALL);
    assign data_wr_set = req_set_r;
    assign data_wr_way_mask = (state_r == ST_WRITE_HIT) ? way_onehot(hit_way_r)
                                                        : way_onehot(install_way_r);
    assign data_wr_row = (state_r == ST_WRITE_HIT) ? place_line_in_row(hit_way_r, install_line_r)
                                                   : place_line_in_row(install_way_r, install_line_r);

    assign meta_wr_en = (state_r == ST_WRITE_HIT) || (state_r == ST_INSTALL);
    assign meta_wr_set = req_set_r;
    assign meta_wr_way_mask = (state_r == ST_WRITE_HIT) ? way_onehot(hit_way_r)
                                                        : way_onehot(install_way_r);
    assign meta_wr_row = (state_r == ST_WRITE_HIT) ?
                         place_meta_in_row(hit_way_r, make_meta(req_tag_r, 1'b1)) :
                         place_meta_in_row(install_way_r, make_meta(req_tag_r, install_dirty_r));

    assign valid_rd_set = active_valid_set_w;
    assign invalidate_valid_clear_w = (state_r == ST_LOOKUP_WAIT) &&
                                      req_invalidate_r &&
                                      data_rd_valid &&
                                      meta_rd_valid &&
                                      lookup_hit_r;
    assign valid_wr_en = (state_r == ST_INSTALL) || invalidate_valid_clear_w;
    assign valid_wr_set = req_set_r;
    assign valid_wr_mask = invalidate_valid_clear_w ? way_onehot(lookup_hit_way_r)
                                                    : way_onehot(install_way_r);
    assign valid_wr_bits = invalidate_valid_clear_w ? {WAY_COUNT{1'b0}}
                                                    : way_onehot(install_way_r);

    assign repl_rd_set = flush_busy ? flush_set_r : active_lookup_set_w;
    assign repl_wr_en = (state_r == ST_INSTALL);
    assign repl_wr_set = req_set_r;
    assign repl_wr_way = next_way(install_way_r);

    assign resp_valid = resp_valid_r;
    assign resp_rdata = resp_rdata_r;
    assign resp_id = req_id_r;

    assign mem_req_valid = (state_r == ST_MISS_WB_REQ) ||
                           (state_r == ST_REFILL_REQ) ||
                           (state_r == ST_FLUSH_WB_REQ);
    assign mem_req_write = (state_r == ST_MISS_WB_REQ) || (state_r == ST_FLUSH_WB_REQ);
    assign mem_req_addr = (state_r == ST_MISS_WB_REQ) ? victim_addr_r :
                          (state_r == ST_FLUSH_WB_REQ) ? flush_wb_addr_r :
                          line_align_addr(req_addr_r);
    assign mem_req_id = (state_r == ST_REFILL_REQ) ? DEMAND_MEM_ID
                                                   : WRITEBACK_MEM_ID;
    assign mem_req_wdata = (state_r == ST_MISS_WB_REQ) ? victim_data_r : flush_wb_data_r;
    assign mem_req_wstrb = {LINE_BYTES{1'b1}};
    assign mem_req_size = LINE_BYTES[7:0] - 8'd1;
    assign expected_mem_resp_id_w = (state_r == ST_REFILL_WAIT) ? DEMAND_MEM_ID
                                                                : WRITEBACK_MEM_ID;
    assign mem_resp_match_w = mem_resp_valid && (mem_resp_id == expected_mem_resp_id_w);
    assign mem_resp_ready = ((state_r == ST_MISS_WB_WAIT) ||
                             (state_r == ST_REFILL_WAIT) ||
                             (state_r == ST_FLUSH_WB_WAIT)) &&
                            (mem_resp_id == expected_mem_resp_id_w);

    always @(*) begin
        lookup_hit_r = 1'b0;
        lookup_hit_way_r = {WAY_BITS{1'b0}};
        lookup_hit_line_r = {LINE_BITS{1'b0}};
        lookup_hit_dirty_r = 1'b0;
        lookup_victim_valid_r = 1'b0;
        lookup_victim_dirty_r = 1'b0;
        lookup_found_invalid_r = 1'b0;
        lookup_select_way_r = repl_rd_way;
        lookup_victim_line_r = {LINE_BITS{1'b0}};
        lookup_victim_addr_r = {ADDR_BITS{1'b0}};

        if (state_r == ST_LOOKUP_WAIT && data_rd_valid && meta_rd_valid) begin
            for (lookup_way_idx = 0;
                 lookup_way_idx < WAY_COUNT;
                 lookup_way_idx = lookup_way_idx + 1) begin
                if (!lookup_hit_r &&
                    valid_rd_bits[lookup_way_idx] &&
                    (meta_tag(extract_meta(meta_rd_row,
                                           lookup_way_idx[WAY_BITS-1:0])) == req_tag_r)) begin
                    lookup_hit_r = 1'b1;
                    lookup_hit_way_r = lookup_way_idx[WAY_BITS-1:0];
                    lookup_hit_line_r = data_rd_row[(lookup_way_idx * LINE_BITS) +: LINE_BITS];
                    lookup_hit_dirty_r = meta_dirty(extract_meta(meta_rd_row,
                                                                 lookup_way_idx[WAY_BITS-1:0]));
                end
            end

            if (!lookup_hit_r) begin
                for (lookup_way_idx = 0;
                     lookup_way_idx < WAY_COUNT;
                     lookup_way_idx = lookup_way_idx + 1) begin
                    if (!lookup_found_invalid_r && !valid_rd_bits[lookup_way_idx]) begin
                        lookup_found_invalid_r = 1'b1;
                        lookup_select_way_r = lookup_way_idx[WAY_BITS-1:0];
                    end
                end
                lookup_victim_valid_r = valid_rd_bits[lookup_select_way_r];
                lookup_victim_dirty_r = lookup_victim_valid_r &&
                                        meta_dirty(extract_meta(meta_rd_row, lookup_select_way_r));
                lookup_victim_line_r = extract_line(data_rd_row, lookup_select_way_r);
                lookup_victim_addr_r = build_line_addr(
                    meta_tag(extract_meta(meta_rd_row, lookup_select_way_r)),
                    req_set_r
                );
            end
        end
    end

    always @(*) begin
        flush_found_dirty_r = 1'b0;
        flush_found_way_r = {WAY_BITS{1'b0}};
        flush_found_line_r = {LINE_BITS{1'b0}};
        flush_found_addr_r = {ADDR_BITS{1'b0}};
        flush_next_set_r = flush_set_r;
        flush_next_way_r = flush_way_start_r;

        if (state_r == ST_FLUSH_SCAN_WAIT && data_rd_valid && meta_rd_valid) begin
            for (flush_way_idx = 0;
                 flush_way_idx < WAY_COUNT;
                 flush_way_idx = flush_way_idx + 1) begin
                if (!flush_found_dirty_r &&
                    (flush_way_idx >= flush_way_start_r) &&
                    valid_rd_bits[flush_way_idx] &&
                    meta_dirty(extract_meta(meta_rd_row,
                                            flush_way_idx[WAY_BITS-1:0]))) begin
                    flush_found_dirty_r = 1'b1;
                    flush_found_way_r = flush_way_idx[WAY_BITS-1:0];
                    flush_found_line_r = data_rd_row[(flush_way_idx * LINE_BITS) +: LINE_BITS];
                    flush_found_addr_r = build_line_addr(
                        meta_tag(extract_meta(meta_rd_row, flush_way_idx[WAY_BITS-1:0])),
                        flush_set_r
                    );
                    if (flush_way_idx == (WAY_COUNT - 1)) begin
                        flush_next_way_r = {WAY_BITS{1'b0}};
                        flush_next_set_r = flush_set_r + {{(SET_BITS-1){1'b0}}, 1'b1};
                    end else begin
                        flush_next_way_r = flush_way_idx[WAY_BITS-1:0] +
                                           {{(WAY_BITS-1){1'b0}}, 1'b1};
                        flush_next_set_r = flush_set_r;
                    end
                end
            end

            if (!flush_found_dirty_r) begin
                flush_next_way_r = {WAY_BITS{1'b0}};
                flush_next_set_r = flush_set_r + {{(SET_BITS-1){1'b0}}, 1'b1};
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r <= ST_IDLE;
            req_write_r <= 1'b0;
            req_addr_r <= {ADDR_BITS{1'b0}};
            req_id_r <= {ID_BITS{1'b0}};
            req_total_size_r <= 8'd0;
            req_wdata_r <= {LINE_BITS{1'b0}};
            req_wstrb_r <= {LINE_BYTES{1'b0}};
            req_set_r <= {SET_BITS{1'b0}};
            req_tag_r <= {TAG_BITS{1'b0}};
            req_invalidate_r <= 1'b0;
            hit_way_r <= {WAY_BITS{1'b0}};
            hit_dirty_r <= 1'b0;
            install_way_r <= {WAY_BITS{1'b0}};
            install_line_r <= {LINE_BITS{1'b0}};
            install_dirty_r <= 1'b0;
            replace_dirty_r <= 1'b0;
            victim_addr_r <= {ADDR_BITS{1'b0}};
            victim_data_r <= {LINE_BITS{1'b0}};
            flush_set_r <= {SET_BITS{1'b0}};
            flush_way_start_r <= {WAY_BITS{1'b0}};
            flush_wb_addr_r <= {ADDR_BITS{1'b0}};
            flush_wb_data_r <= {LINE_BITS{1'b0}};
            dirty_count_r <= 32'd0;
            resp_valid_r <= 1'b0;
            resp_rdata_r <= {LINE_BITS{1'b0}};
        end else begin
            if (resp_valid_r && resp_ready) begin
                resp_valid_r <= 1'b0;
            end

            case (state_r)
                ST_IDLE: begin
                    if (flush_start && (dirty_count_r != 0)) begin
                        flush_set_r <= {SET_BITS{1'b0}};
                        flush_way_start_r <= {WAY_BITS{1'b0}};
                        state_r <= ST_FLUSH_SCAN_REQ;
                    end else if (accept_invalidate_line_w) begin
                        req_write_r <= 1'b0;
                        req_addr_r <= invalidate_line_addr;
                        req_id_r <= {ID_BITS{1'b0}};
                        req_total_size_r <= 8'd0;
                        req_wdata_r <= {LINE_BITS{1'b0}};
                        req_wstrb_r <= {LINE_BYTES{1'b0}};
                        req_set_r <= invalidate_line_addr[LINE_OFFSET_BITS + SET_BITS - 1:
                                                          LINE_OFFSET_BITS];
                        req_tag_r <= invalidate_line_addr[ADDR_BITS-1:
                                                          LINE_OFFSET_BITS + SET_BITS];
                        req_invalidate_r <= 1'b1;
                        state_r <= ST_LOOKUP_WAIT;
                    end else if (launch_lookup_w) begin
                        req_write_r <= req_write;
                        req_addr_r <= req_addr;
                        req_id_r <= req_id;
                        req_total_size_r <= req_total_size;
                        req_wdata_r <= req_wdata;
                        req_wstrb_r <= req_wstrb;
                        req_set_r <= req_set_w;
                        req_tag_r <= req_tag_w;
                        req_invalidate_r <= 1'b0;
                        state_r <= ST_LOOKUP_WAIT;
                    end
                end

                ST_LOOKUP_WAIT: begin
                    if (data_rd_valid && meta_rd_valid) begin
                        if (req_invalidate_r) begin
                            if (lookup_hit_r && lookup_hit_dirty_r && (dirty_count_r != 0)) begin
                                dirty_count_r <= dirty_count_r - 32'd1;
                            end
                            req_invalidate_r <= 1'b0;
                            state_r <= ST_IDLE;
                        end else if (lookup_hit_r) begin
                            if (req_write_r) begin
                                hit_way_r <= lookup_hit_way_r;
                                hit_dirty_r <= lookup_hit_dirty_r;
                                install_line_r <= merge_line(lookup_hit_line_r,
                                                             req_addr_r,
                                                             req_wdata_r,
                                                             req_wstrb_r);
                                state_r <= ST_WRITE_HIT;
                            end else begin
                                resp_valid_r <= 1'b1;
                                resp_rdata_r <= extract_read_response(req_addr_r,
                                                                      lookup_hit_line_r);
                                state_r <= ST_IDLE;
                            end
                        end else begin
                            install_way_r <= lookup_select_way_r;
                            replace_dirty_r <= lookup_victim_dirty_r;
                            victim_addr_r <= lookup_victim_addr_r;
                            victim_data_r <= lookup_victim_line_r;

                            if (req_write_r && full_write_w) begin
                                install_line_r <= req_wdata_r;
                                install_dirty_r <= 1'b1;
                                if (lookup_victim_dirty_r) begin
                                    state_r <= ST_MISS_WB_REQ;
                                end else begin
                                    state_r <= ST_INSTALL;
                                end
                            end else begin
                                if (lookup_victim_dirty_r) begin
                                    state_r <= ST_MISS_WB_REQ;
                                end else begin
                                    state_r <= ST_REFILL_REQ;
                                end
                            end
                        end
                    end
                end

                ST_WRITE_HIT: begin
                    if (!hit_dirty_r) begin
                        dirty_count_r <= dirty_count_r + 32'd1;
                    end
                    resp_valid_r <= 1'b1;
                    resp_rdata_r <= {LINE_BITS{1'b0}};
                    state_r <= ST_IDLE;
                end

                ST_MISS_WB_REQ: begin
                    if (mem_req_valid && mem_req_ready) begin
                        state_r <= ST_MISS_WB_WAIT;
                    end
                end

                ST_MISS_WB_WAIT: begin
                    if (mem_resp_match_w) begin
                        if (dirty_count_r != 0) begin
                            dirty_count_r <= dirty_count_r - 32'd1;
                        end
                        if (req_write_r && full_write_w) begin
                            state_r <= ST_INSTALL;
                        end else begin
                            state_r <= ST_REFILL_REQ;
                        end
                    end
                end

                ST_REFILL_REQ: begin
                    if (mem_req_valid && mem_req_ready) begin
                        state_r <= ST_REFILL_WAIT;
                    end
                end

                ST_REFILL_WAIT: begin
                    if (mem_resp_match_w) begin
                        if (req_write_r) begin
                            install_line_r <= merge_line(mem_resp_rdata,
                                                         req_addr_r,
                                                         req_wdata_r,
                                                         req_wstrb_r);
                            install_dirty_r <= 1'b1;
                        end else begin
                            install_line_r <= mem_resp_rdata;
                            install_dirty_r <= 1'b0;
                        end
                        state_r <= ST_INSTALL;
                    end
                end

                ST_INSTALL: begin
                    if (install_dirty_r && !replace_dirty_r) begin
                        dirty_count_r <= dirty_count_r + 32'd1;
                    end
                    resp_valid_r <= 1'b1;
                    if (req_write_r) begin
                        resp_rdata_r <= {LINE_BITS{1'b0}};
                    end else begin
                        resp_rdata_r <= extract_read_response(req_addr_r,
                                                              install_line_r);
                    end
                    state_r <= ST_IDLE;
                end

                ST_FLUSH_SCAN_REQ: begin
                    state_r <= ST_FLUSH_SCAN_WAIT;
                end

                ST_FLUSH_SCAN_WAIT: begin
                    if (data_rd_valid && meta_rd_valid) begin
                        if (flush_found_dirty_r) begin
                            flush_wb_addr_r <= flush_found_addr_r;
                            flush_wb_data_r <= flush_found_line_r;
                            flush_set_r <= flush_next_set_r;
                            flush_way_start_r <= flush_next_way_r;
                            state_r <= ST_FLUSH_WB_REQ;
                        end else if (flush_set_r == (SET_COUNT - 1)) begin
                            state_r <= ST_IDLE;
                        end else begin
                            flush_set_r <= flush_next_set_r;
                            flush_way_start_r <= {WAY_BITS{1'b0}};
                            state_r <= ST_FLUSH_SCAN_REQ;
                        end
                    end
                end

                ST_FLUSH_WB_REQ: begin
                    if (mem_req_valid && mem_req_ready) begin
                        state_r <= ST_FLUSH_WB_WAIT;
                    end
                end

                ST_FLUSH_WB_WAIT: begin
                    if (mem_resp_match_w) begin
                        if (dirty_count_r != 0) begin
                            dirty_count_r <= dirty_count_r - 32'd1;
                        end
                        if (dirty_count_r <= 32'd1) begin
                            state_r <= ST_IDLE;
                        end else begin
                            state_r <= ST_FLUSH_SCAN_REQ;
                        end
                    end
                end

                default: begin
                    state_r <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
