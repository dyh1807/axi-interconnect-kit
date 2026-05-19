`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module llc_cache_ctrl #(
    parameter ADDR_BITS        = `AXI_LLC_ADDR_BITS,
    parameter ID_BITS          = `AXI_LLC_SLOT_ID_BITS,
    parameter LINE_BYTES       = `AXI_LLC_LINE_BYTES,
    parameter LINE_BITS        = `AXI_LLC_LINE_BITS,
    parameter LINE_OFFSET_BITS = `AXI_LLC_LINE_OFFSET_BITS,
    parameter SET_COUNT        = `AXI_LLC_SET_COUNT,
    parameter SET_BITS         = `AXI_LLC_SET_BITS,
    parameter WAY_COUNT        = `AXI_LLC_WAY_COUNT,
    parameter WAY_BITS         = `AXI_LLC_WAY_BITS,
    parameter META_BITS        = `AXI_LLC_META_BITS,
    parameter READ_RESP_BYTES  = `AXI_LLC_READ_RESP_BYTES,
    parameter READ_RESP_BITS   = `AXI_LLC_READ_RESP_BITS,
    parameter DATA_ROW_BITS    = WAY_COUNT * LINE_BITS,
    parameter META_ROW_BITS    = WAY_COUNT * META_BITS,
    parameter TAG_BITS         = ADDR_BITS - SET_BITS - LINE_OFFSET_BITS
) (
    input                       clk,
    input                       rst_n,
    input                       req_valid,
    output                      req_ready,
    input                       req_write,
    input                       req_bypass,
    input      [ADDR_BITS-1:0]  req_addr,
    input      [ID_BITS-1:0]    req_id,
    input      [7:0]            req_total_size,
    input      [LINE_BITS-1:0]  req_wdata,
    input      [LINE_BYTES-1:0] req_wstrb,
    output                      resp_valid,
    input                       resp_ready,
    output     [READ_RESP_BITS-1:0] resp_rdata,
    output     [ID_BITS-1:0]    resp_id,
    output     [1:0]            resp_code,
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
    output                      valid_rd_en,
    output     [SET_BITS-1:0]   valid_rd_set,
    input                       valid_rd_valid,
    input      [WAY_COUNT-1:0]  valid_rd_bits,
    output                      valid_wr_en,
    output     [SET_BITS-1:0]   valid_wr_set,
    output     [WAY_COUNT-1:0]  valid_wr_mask,
    output     [WAY_COUNT-1:0]  valid_wr_bits,
    output                      repl_rd_en,
    output     [SET_BITS-1:0]   repl_rd_set,
    input                       repl_rd_valid,
    input      [WAY_BITS-1:0]   repl_rd_way,
    output                      repl_wr_en,
    output     [SET_BITS-1:0]   repl_wr_set,
    output     [WAY_BITS-1:0]   repl_wr_way,
    input                       flush_start,
    output                      flush_busy,
    output                      dirty_present,
    output                      quiescent,
    output     [`AXI_LLC_MAX_OUTSTANDING-1:0] victim_line_valid,
    output     [(`AXI_LLC_MAX_OUTSTANDING*ADDR_BITS)-1:0] victim_line_addr,
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
    input      [READ_RESP_BITS-1:0] mem_resp_rdata,
    input      [ID_BITS-1:0]    mem_resp_id,
    input      [1:0]            mem_resp_code,
    output                      bypass_req_valid,
    input                       bypass_req_ready,
    output                      bypass_req_write,
    output     [ADDR_BITS-1:0]  bypass_req_addr,
    output     [ID_BITS-1:0]    bypass_req_id,
    output     [7:0]            bypass_req_size,
    output     [LINE_BITS-1:0]  bypass_req_wdata,
    output     [LINE_BYTES-1:0] bypass_req_wstrb,
    input                       bypass_resp_valid,
    output                      bypass_resp_ready,
    input      [READ_RESP_BITS-1:0] bypass_resp_rdata,
    input      [ID_BITS-1:0]    bypass_resp_id,
    input      [1:0]            bypass_resp_code
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
    localparam [3:0] ST_BYPASS_REQ      = 4'd12;
    localparam [3:0] ST_BYPASS_WAIT     = 4'd13;
    localparam [3:0] ST_MSHR_COMMIT_PREP = 4'd14;
    localparam integer MSHR_COUNT = `AXI_LLC_MAX_OUTSTANDING;
    localparam integer MASTER_DCACHE_R = 1;
    localparam [ID_BITS-1:0] WRITEBACK_MEM_ID = {ID_BITS{1'b1}};
    localparam [ID_BITS-1:0] DEMAND_MEM_ID =
        {ID_BITS{1'b1}} - {{(ID_BITS-1){1'b0}}, 1'b1};
    localparam integer RESP_WORD_BITS = 32;
    localparam integer RESP_WORDS = READ_RESP_BITS / RESP_WORD_BITS;
    localparam integer LINE_WORDS = LINE_BITS / RESP_WORD_BITS;
    localparam integer SPECIAL_READ_RESP_64B =
        (LINE_BYTES == 64) && (LINE_BITS == 512) && (READ_RESP_BITS >= LINE_BITS);
    localparam integer META_TAG_BITS = (TAG_BITS < (META_BITS - 1)) ?
                                       TAG_BITS : (META_BITS - 1);
    localparam [WAY_BITS-1:0] LAST_WAY = WAY_COUNT - 1;
    localparam [SET_BITS-1:0] LAST_SET = SET_COUNT - 1;
    localparam [ID_BITS+1:0] MSHR_COUNT_ID = MSHR_COUNT;

    reg [3:0] state_r;
    reg       req_write_r;
    reg       req_bypass_r;
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
    reg [READ_RESP_BITS-1:0] resp_rdata_r;
    reg [1:0]          resp_code_r;

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
    wire [LINE_BITS-1:0] mem_resp_line_w;
    reg                install_from_mshr_r;
    reg [ID_BITS-1:0]  install_mshr_slot_r;
    reg                mshr_commit_need_refill_r;
    reg [LINE_BITS-1:0] mshr_commit_refill_line_r;

    reg                mshr_issue_stage_valid_r;
    reg                mshr_issue_stage_write_r;
    reg [ID_BITS-1:0]  mshr_issue_stage_slot_r;
    reg [ADDR_BITS-1:0] mshr_issue_stage_addr_r;
    reg [LINE_BITS-1:0] mshr_issue_stage_wdata_r;

    // Read misses now decouple from the single lookup FSM: a miss allocates an
    // internal slot keyed by req_id, lower memory traffic is issued later, and
    // refill/install is committed back through ST_INSTALL one slot at a time.
    reg [MSHR_COUNT-1:0] mshr_valid_r;
    reg [(MSHR_COUNT*ADDR_BITS)-1:0] mshr_addr_r;
    reg [(MSHR_COUNT*SET_BITS)-1:0] mshr_set_r;
    reg [(MSHR_COUNT*TAG_BITS)-1:0] mshr_tag_r;
    reg [(MSHR_COUNT*WAY_BITS)-1:0] mshr_way_r;
    // Keep the original write metadata per slot so a partial write miss can
    // merge the refill line and still retire as a write response.
    reg [MSHR_COUNT-1:0] mshr_is_write_r;
    reg [MSHR_COUNT-1:0] mshr_committed_r;
    reg [MSHR_COUNT-1:0] mshr_victim_dirty_r;
    reg [MSHR_COUNT-1:0] mshr_wb_done_r;
    reg [MSHR_COUNT-1:0] mshr_wb_issued_r;
    reg [MSHR_COUNT-1:0] mshr_refill_issued_r;
    reg [MSHR_COUNT-1:0] mshr_refill_valid_r;
    reg [(MSHR_COUNT*ADDR_BITS)-1:0] mshr_victim_addr_r;
    // Keep wide MSHR payloads as per-slot banks instead of one flattened
    // vector; otherwise DC builds 16K-bit select/write-mask cones.
    reg [LINE_BITS-1:0] mshr_victim_data_r [0:MSHR_COUNT-1];
    reg [LINE_BITS-1:0] mshr_refill_line_r [0:MSHR_COUNT-1];
    reg [LINE_BITS-1:0] mshr_wdata_r [0:MSHR_COUNT-1];
    reg [LINE_BYTES-1:0] mshr_wstrb_r [0:MSHR_COUNT-1];
    reg [MSHR_COUNT-1:0] mshr_need_refill_r;
    reg [(MSHR_COUNT*8)-1:0] mshr_total_size_r;

`define LLC_MSHR_ADDR(slot) mshr_addr_r[((slot) * ADDR_BITS) +: ADDR_BITS]
`define LLC_MSHR_SET(slot) mshr_set_r[((slot) * SET_BITS) +: SET_BITS]
`define LLC_MSHR_TAG(slot) mshr_tag_r[((slot) * TAG_BITS) +: TAG_BITS]
`define LLC_MSHR_WAY(slot) mshr_way_r[((slot) * WAY_BITS) +: WAY_BITS]
`define LLC_MSHR_VICTIM_ADDR(slot) mshr_victim_addr_r[((slot) * ADDR_BITS) +: ADDR_BITS]
`define LLC_MSHR_VICTIM_DATA(slot) mshr_victim_data_r[(slot)]
`define LLC_MSHR_REFILL_LINE(slot) mshr_refill_line_r[(slot)]
`define LLC_MSHR_WDATA(slot) mshr_wdata_r[(slot)]
`define LLC_MSHR_WSTRB(slot) mshr_wstrb_r[(slot)]
`define LLC_MSHR_TOTAL_SIZE(slot) mshr_total_size_r[((slot) * 8) +: 8]

    wire               req_line_mshr_pending_r;
    wire               req_victim_line_pending_r;
    wire               req_master_mshr_pending_r;
    wire               mshr_any_valid_r;
    wire               invalidate_line_mshr_pending_r;
    wire               invalidate_line_victim_pending_r;
    wire               mshr_issue_found_r;
    wire               mshr_issue_write_r;
    wire [ID_BITS-1:0] mshr_issue_slot_r;
    reg                mshr_resp_match_r;
    reg                mshr_resp_is_wb_r;
    reg [ID_BITS-1:0]  mshr_resp_slot_r;
    wire               mshr_commit_found_r;
    wire [ID_BITS-1:0] mshr_commit_slot_r;
    wire [MSHR_COUNT-1:0] mshr_write_hit_update_mask_w;
    wire               write_hit_mshr_update_en_w;
    wire [READ_RESP_BITS-1:0] lookup_hit_resp_rdata_w;
    wire [READ_RESP_BITS-1:0] install_resp_rdata_w;

    reg [31:0] lookup_way_idx;
    reg [31:0] flush_way_idx;
    reg [31:0] mshr_seq_idx;

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
        reg [31:0] idx;
        begin
            extract_line = {LINE_BITS{1'b0}};
            for (idx = 32'd0; idx < WAY_COUNT; idx = idx + 32'd1) begin
                if (way_value == idx[WAY_BITS-1:0]) begin
                    extract_line = row_value[(idx * LINE_BITS) +: LINE_BITS];
                end
            end
        end
    endfunction

    function [META_BITS-1:0] extract_meta;
        input [META_ROW_BITS-1:0] row_value;
        input [WAY_BITS-1:0]      way_value;
        reg [31:0] idx;
        begin
            extract_meta = {META_BITS{1'b0}};
            for (idx = 32'd0; idx < WAY_COUNT; idx = idx + 32'd1) begin
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
        reg [31:0] src_idx;
        reg [31:0] line_off;
        reg [31:0] dst_idx;
        begin
            merge_line = base_line;
            line_off = addr_value[LINE_OFFSET_BITS-1:0];
            for (dst_idx = 32'd0; dst_idx < LINE_BYTES; dst_idx = dst_idx + 32'd1) begin
                if (dst_idx >= line_off) begin
                    src_idx = dst_idx - line_off;
                    if ((src_idx < LINE_BYTES) && write_strb[src_idx]) begin
                        merge_line[(dst_idx * 8) +: 8] =
                            write_data[(src_idx * 8) +: 8];
                    end
                end
            end
        end
    endfunction

    function [DATA_ROW_BITS-1:0] place_line_in_row;
        input [WAY_BITS-1:0]      way_value;
        input [LINE_BITS-1:0]     line_value;
        reg [31:0] idx;
        begin
            place_line_in_row = {DATA_ROW_BITS{1'b0}};
            for (idx = 32'd0; idx < WAY_COUNT; idx = idx + 32'd1) begin
                if (way_value == idx[WAY_BITS-1:0]) begin
                    place_line_in_row[(idx * LINE_BITS) +: LINE_BITS] = line_value;
                end
            end
        end
    endfunction

    function [META_ROW_BITS-1:0] place_meta_in_row;
        input [WAY_BITS-1:0]      way_value;
        input [META_BITS-1:0]     meta_value;
        reg [31:0] idx;
        begin
            place_meta_in_row = {META_ROW_BITS{1'b0}};
            for (idx = 32'd0; idx < WAY_COUNT; idx = idx + 32'd1) begin
                if (way_value == idx[WAY_BITS-1:0]) begin
                    place_meta_in_row[(idx * META_BITS) +: META_BITS] = meta_value;
                end
            end
        end
    endfunction

    function [WAY_COUNT-1:0] way_onehot;
        input [WAY_BITS-1:0] way_value;
        reg [31:0] idx;
        begin
            way_onehot = {WAY_COUNT{1'b0}};
            for (idx = 32'd0; idx < WAY_COUNT; idx = idx + 32'd1) begin
                if (way_value == idx[WAY_BITS-1:0]) begin
                    way_onehot[idx] = 1'b1;
                end
            end
        end
    endfunction

    function [WAY_BITS-1:0] next_way;
        input [WAY_BITS-1:0] way_value;
        begin
            if (way_value == LAST_WAY) begin
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

    function same_line_addr;
        input [ADDR_BITS-1:0] lhs_addr;
        input [ADDR_BITS-1:0] rhs_addr;
        begin
            same_line_addr =
                lhs_addr[ADDR_BITS-1:LINE_OFFSET_BITS] ==
                rhs_addr[ADDR_BITS-1:LINE_OFFSET_BITS];
        end
    endfunction

    function [ADDR_BITS-1:0] build_line_addr;
        input [TAG_BITS-1:0] tag_value;
        input [SET_BITS-1:0] set_value;
        begin
            build_line_addr = {tag_value, set_value, {LINE_OFFSET_BITS{1'b0}}};
        end
    endfunction

    function [READ_RESP_BITS-1:0] extract_read_response;
        input [ADDR_BITS-1:0] addr_value;
        input [LINE_BITS-1:0] line_value;
        reg [31:0] dst_idx;
        reg [31:0] src_idx;
        reg [31:0] start_word;
        begin
            extract_read_response = {READ_RESP_BITS{1'b0}};
            start_word = addr_value[LINE_OFFSET_BITS-1:2];
            for (dst_idx = 32'd0; dst_idx < RESP_WORDS; dst_idx = dst_idx + 32'd1) begin
                src_idx = start_word + dst_idx;
                if (src_idx < LINE_WORDS) begin
                    extract_read_response[(dst_idx * RESP_WORD_BITS) +: RESP_WORD_BITS] =
                        line_value[(src_idx * RESP_WORD_BITS) +: RESP_WORD_BITS];
                end
            end
        end
    endfunction

    generate
        if (SPECIAL_READ_RESP_64B) begin : gen_read_resp_64b
            reg [READ_RESP_BITS-1:0] lookup_hit_resp_rdata_64b_r;
            reg [READ_RESP_BITS-1:0] install_resp_rdata_64b_r;

            always @(*) begin
                lookup_hit_resp_rdata_64b_r = {READ_RESP_BITS{1'b0}};
                case (req_addr_r[5:2])
                    4'd0:  lookup_hit_resp_rdata_64b_r[511:0] = lookup_hit_line_r[511:0];
                    4'd1:  lookup_hit_resp_rdata_64b_r[479:0] = lookup_hit_line_r[511:32];
                    4'd2:  lookup_hit_resp_rdata_64b_r[447:0] = lookup_hit_line_r[511:64];
                    4'd3:  lookup_hit_resp_rdata_64b_r[415:0] = lookup_hit_line_r[511:96];
                    4'd4:  lookup_hit_resp_rdata_64b_r[383:0] = lookup_hit_line_r[511:128];
                    4'd5:  lookup_hit_resp_rdata_64b_r[351:0] = lookup_hit_line_r[511:160];
                    4'd6:  lookup_hit_resp_rdata_64b_r[319:0] = lookup_hit_line_r[511:192];
                    4'd7:  lookup_hit_resp_rdata_64b_r[287:0] = lookup_hit_line_r[511:224];
                    4'd8:  lookup_hit_resp_rdata_64b_r[255:0] = lookup_hit_line_r[511:256];
                    4'd9:  lookup_hit_resp_rdata_64b_r[223:0] = lookup_hit_line_r[511:288];
                    4'd10: lookup_hit_resp_rdata_64b_r[191:0] = lookup_hit_line_r[511:320];
                    4'd11: lookup_hit_resp_rdata_64b_r[159:0] = lookup_hit_line_r[511:352];
                    4'd12: lookup_hit_resp_rdata_64b_r[127:0] = lookup_hit_line_r[511:384];
                    4'd13: lookup_hit_resp_rdata_64b_r[95:0] = lookup_hit_line_r[511:416];
                    4'd14: lookup_hit_resp_rdata_64b_r[63:0] = lookup_hit_line_r[511:448];
                    4'd15: lookup_hit_resp_rdata_64b_r[31:0] = lookup_hit_line_r[511:480];
                    default: lookup_hit_resp_rdata_64b_r = {READ_RESP_BITS{1'b0}};
                endcase
            end

            always @(*) begin
                install_resp_rdata_64b_r = {READ_RESP_BITS{1'b0}};
                case (req_addr_r[5:2])
                    4'd0:  install_resp_rdata_64b_r[511:0] = install_line_r[511:0];
                    4'd1:  install_resp_rdata_64b_r[479:0] = install_line_r[511:32];
                    4'd2:  install_resp_rdata_64b_r[447:0] = install_line_r[511:64];
                    4'd3:  install_resp_rdata_64b_r[415:0] = install_line_r[511:96];
                    4'd4:  install_resp_rdata_64b_r[383:0] = install_line_r[511:128];
                    4'd5:  install_resp_rdata_64b_r[351:0] = install_line_r[511:160];
                    4'd6:  install_resp_rdata_64b_r[319:0] = install_line_r[511:192];
                    4'd7:  install_resp_rdata_64b_r[287:0] = install_line_r[511:224];
                    4'd8:  install_resp_rdata_64b_r[255:0] = install_line_r[511:256];
                    4'd9:  install_resp_rdata_64b_r[223:0] = install_line_r[511:288];
                    4'd10: install_resp_rdata_64b_r[191:0] = install_line_r[511:320];
                    4'd11: install_resp_rdata_64b_r[159:0] = install_line_r[511:352];
                    4'd12: install_resp_rdata_64b_r[127:0] = install_line_r[511:384];
                    4'd13: install_resp_rdata_64b_r[95:0] = install_line_r[511:416];
                    4'd14: install_resp_rdata_64b_r[63:0] = install_line_r[511:448];
                    4'd15: install_resp_rdata_64b_r[31:0] = install_line_r[511:480];
                    default: install_resp_rdata_64b_r = {READ_RESP_BITS{1'b0}};
                endcase
            end

            assign lookup_hit_resp_rdata_w = lookup_hit_resp_rdata_64b_r;
            assign install_resp_rdata_w = install_resp_rdata_64b_r;
        end else begin : gen_read_resp_generic
            assign lookup_hit_resp_rdata_w = extract_read_response(req_addr_r, lookup_hit_line_r);
            assign install_resp_rdata_w = extract_read_response(req_addr_r, install_line_r);
        end
    endgenerate

    wire               req_id_mshr_slot_in_range_w;
    wire               mem_resp_mshr_slot_in_range_w;

    assign req_id_mshr_slot_in_range_w = ({2'b00, req_id} < MSHR_COUNT_ID);
    assign mem_resp_mshr_slot_in_range_w = ({2'b00, mem_resp_id} < MSHR_COUNT_ID);

    llc_mshr_pending_scan #(
        .ADDR_BITS(ADDR_BITS),
        .ID_BITS(ID_BITS),
        .LINE_OFFSET_BITS(LINE_OFFSET_BITS),
        .MSHR_COUNT(MSHR_COUNT)
    ) mshr_pending_scan (
        .req_addr(req_addr),
        .req_id(req_id),
        .invalidate_line_addr(invalidate_line_addr),
        .mshr_valid(mshr_valid_r),
        .mshr_is_write(mshr_is_write_r),
        .mshr_committed(mshr_committed_r),
        .mshr_victim_dirty(mshr_victim_dirty_r),
        .mshr_wb_done(mshr_wb_done_r),
        .mshr_wb_issued(mshr_wb_issued_r),
        .mshr_refill_valid(mshr_refill_valid_r),
        .mshr_need_refill(mshr_need_refill_r),
        .mshr_addr(mshr_addr_r),
        .mshr_victim_addr(mshr_victim_addr_r),
        .req_line_mshr_pending(req_line_mshr_pending_r),
        .req_victim_line_pending(req_victim_line_pending_r),
        .req_master_mshr_pending(req_master_mshr_pending_r),
        .mshr_any_valid(mshr_any_valid_r),
        .invalidate_line_mshr_pending(invalidate_line_mshr_pending_r),
        .invalidate_line_victim_pending(invalidate_line_victim_pending_r),
        .victim_line_valid(victim_line_valid),
        .victim_line_addr(victim_line_addr)
    );

    llc_mshr_select_scan #(
        .ID_BITS(ID_BITS),
        .MSHR_COUNT(MSHR_COUNT)
    ) mshr_select_scan (
        .mshr_valid(mshr_valid_r),
        .mshr_committed(mshr_committed_r),
        .mshr_victim_dirty(mshr_victim_dirty_r),
        .mshr_wb_done(mshr_wb_done_r),
        .mshr_wb_issued(mshr_wb_issued_r),
        .mshr_refill_issued(mshr_refill_issued_r),
        .mshr_refill_valid(mshr_refill_valid_r),
        .mshr_need_refill(mshr_need_refill_r),
        .issue_found(mshr_issue_found_r),
        .issue_write(mshr_issue_write_r),
        .issue_slot(mshr_issue_slot_r),
        .commit_found(mshr_commit_found_r),
        .commit_slot(mshr_commit_slot_r)
    );

    llc_mshr_write_hit_scan #(
        .ADDR_BITS(ADDR_BITS),
        .SET_BITS(SET_BITS),
        .WAY_BITS(WAY_BITS),
        .LINE_OFFSET_BITS(LINE_OFFSET_BITS),
        .MSHR_COUNT(MSHR_COUNT)
    ) mshr_write_hit_scan (
        .enable(write_hit_mshr_update_en_w),
        .req_addr(req_addr_r),
        .req_set(req_set_r),
        .hit_way(lookup_hit_way_r),
        .mshr_valid(mshr_valid_r),
        .mshr_is_write(mshr_is_write_r),
        .mshr_wb_issued(mshr_wb_issued_r),
        .mshr_refill_valid(mshr_refill_valid_r),
        .mshr_addr(mshr_addr_r),
        .mshr_set(mshr_set_r),
        .mshr_way(mshr_way_r),
        .update_mask(mshr_write_hit_update_mask_w)
    );

    always @(*) begin
        mshr_resp_match_r = 1'b0;
        mshr_resp_is_wb_r = 1'b0;
        mshr_resp_slot_r = {ID_BITS{1'b0}};
        if (mem_resp_valid && mem_resp_mshr_slot_in_range_w) begin
            if (mshr_valid_r[mem_resp_id]) begin
                if (mshr_need_refill_r[mem_resp_id] &&
                    mshr_refill_issued_r[mem_resp_id]) begin
                    mshr_resp_match_r = 1'b1;
                    mshr_resp_is_wb_r = 1'b0;
                    mshr_resp_slot_r = mem_resp_id;
                end else if (mshr_victim_dirty_r[mem_resp_id] &&
                             !mshr_wb_done_r[mem_resp_id] &&
                             mshr_wb_issued_r[mem_resp_id]) begin
                    mshr_resp_match_r = 1'b1;
                    mshr_resp_is_wb_r = 1'b1;
                    mshr_resp_slot_r = mem_resp_id;
                end
            end
        end
    end

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
    wire                bypass_resp_match_w;
    wire                hit_write_dirty_w;
    wire [LINE_BITS-1:0] write_hit_merged_line_w;
    wire                state_mem_req_valid_w;
    wire                state_mem_req_write_w;
    wire [ADDR_BITS-1:0] state_mem_req_addr_w;
    wire [ID_BITS-1:0]  state_mem_req_id_w;
    wire [LINE_BITS-1:0] state_mem_req_wdata_w;
    wire [LINE_BYTES-1:0] state_mem_req_wstrb_w;
    wire [7:0]         state_mem_req_size_w;
    wire               can_accept_read_w;

    assign req_set_w = req_addr[LINE_OFFSET_BITS + SET_BITS - 1:LINE_OFFSET_BITS];
    assign req_tag_w = req_addr[ADDR_BITS-1:LINE_OFFSET_BITS + SET_BITS];
    assign full_write_w = (req_addr_r[LINE_OFFSET_BITS-1:0] == {LINE_OFFSET_BITS{1'b0}}) &&
                          ((req_total_size_r + 8'd1) == LINE_BYTES[7:0]) &&
                          (&req_wstrb_r);
    assign write_hit_merged_line_w = merge_line(lookup_hit_line_r,
                                                req_addr_r,
                                                req_wdata_r,
                                                req_wstrb_r);
    assign write_hit_mshr_update_en_w = (state_r == ST_LOOKUP_WAIT) &&
                                        data_rd_valid &&
                                        meta_rd_valid &&
                                        valid_rd_valid &&
                                        repl_rd_valid &&
                                        !req_invalidate_r &&
                                        lookup_hit_r &&
                                        req_write_r &&
                                        !req_bypass_r;
    assign store_write_busy_w = data_busy | meta_busy;
    assign can_accept_read_w = (state_r == ST_IDLE) && !resp_valid_r &&
                               !flush_start && !store_write_busy_w &&
                               !req_line_mshr_pending_r &&
                               !req_victim_line_pending_r &&
                               !req_master_mshr_pending_r &&
                               !mshr_commit_found_r;
    assign req_ready = req_write ? ((state_r == ST_IDLE) && !resp_valid_r &&
                                    !flush_start && !store_write_busy_w &&
                                    !mshr_commit_found_r &&
                                    !req_line_mshr_pending_r &&
                                    !req_victim_line_pending_r)
                                 : can_accept_read_w;
    // Align invalidate_line acceptance with the C++ LLC contract: the same
    // line must not be invalidated while an inflight read miss/refill still
    // owns it, or while a pending dirty victim writeback still carries it.
    assign accept_invalidate_line_w = (state_r == ST_IDLE) &&
                                      !resp_valid_r &&
                                      !flush_start &&
                                      !store_write_busy_w &&
                                      !mshr_commit_found_r &&
                                      !invalidate_line_mshr_pending_r &&
                                      !invalidate_line_victim_pending_r &&
                                      invalidate_line_valid;
    assign invalidate_line_accepted = accept_invalidate_line_w;
    assign quiescent = (state_r == ST_IDLE) && !resp_valid_r &&
                       !mshr_any_valid_r && !mshr_commit_found_r &&
                       !mshr_issue_found_r && !mshr_issue_stage_valid_r &&
                       !mshr_resp_match_r;
    assign flush_busy = (state_r == ST_FLUSH_SCAN_REQ) ||
                        (state_r == ST_FLUSH_SCAN_WAIT) ||
                        (state_r == ST_FLUSH_WB_REQ) ||
                        (state_r == ST_FLUSH_WB_WAIT);
    assign dirty_present = (dirty_count_r != 0);

    assign launch_lookup_w = (state_r == ST_IDLE) && req_valid && req_ready;
    assign launch_invalidate_lookup_w = accept_invalidate_line_w;
    assign launch_flush_scan_w = (state_r == ST_FLUSH_SCAN_REQ);
    assign active_lookup_set_w = (state_r == ST_IDLE) ? req_set_w : req_set_r;
    assign active_valid_set_w = flush_busy ? flush_set_r :
                                launch_invalidate_lookup_w ? invalidate_lookup_set_w :
                                active_lookup_set_w;
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
    assign valid_rd_en = launch_lookup_w || launch_invalidate_lookup_w || launch_flush_scan_w;

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
    assign hit_write_dirty_w = req_bypass_r ? hit_dirty_r : 1'b1;
    assign meta_wr_row = (state_r == ST_WRITE_HIT) ?
                         place_meta_in_row(hit_way_r,
                                           make_meta(req_tag_r, hit_write_dirty_w)) :
                         place_meta_in_row(install_way_r, make_meta(req_tag_r, install_dirty_r));

    assign valid_rd_set = active_valid_set_w;
    assign invalidate_valid_clear_w = (state_r == ST_LOOKUP_WAIT) &&
                                      req_invalidate_r &&
                                      data_rd_valid &&
                                      meta_rd_valid &&
                                      valid_rd_valid &&
                                      lookup_hit_r;
    assign valid_wr_en = (state_r == ST_INSTALL) ||
                         (state_r == ST_WRITE_HIT) ||
                         invalidate_valid_clear_w;
    assign valid_wr_set = req_set_r;
    assign valid_wr_mask = invalidate_valid_clear_w ? way_onehot(lookup_hit_way_r) :
                           (state_r == ST_WRITE_HIT) ? way_onehot(hit_way_r)
                                                     : way_onehot(install_way_r);
    assign valid_wr_bits = invalidate_valid_clear_w ? {WAY_COUNT{1'b0}} :
                           (state_r == ST_WRITE_HIT) ? way_onehot(hit_way_r)
                                                     : way_onehot(install_way_r);

    assign repl_rd_en = launch_lookup_w || launch_invalidate_lookup_w || launch_flush_scan_w;
    assign repl_rd_set = flush_busy ? flush_set_r :
                         launch_invalidate_lookup_w ? invalidate_lookup_set_w :
                         active_lookup_set_w;
    assign repl_wr_en = (state_r == ST_INSTALL) || (state_r == ST_WRITE_HIT);
    assign repl_wr_set = req_set_r;
    assign repl_wr_way = (state_r == ST_WRITE_HIT) ? next_way(hit_way_r)
                                                   : next_way(install_way_r);

    assign resp_valid = resp_valid_r;
    assign resp_rdata = resp_rdata_r;
    assign resp_id = req_id_r;
    assign resp_code = resp_code_r;

    assign state_mem_req_valid_w = (state_r == ST_MISS_WB_REQ) ||
                                   (state_r == ST_REFILL_REQ) ||
                                   (state_r == ST_FLUSH_WB_REQ);
    assign state_mem_req_write_w = (state_r == ST_MISS_WB_REQ) ||
                                   (state_r == ST_FLUSH_WB_REQ);
    assign state_mem_req_addr_w = (state_r == ST_MISS_WB_REQ) ? victim_addr_r :
                                  (state_r == ST_FLUSH_WB_REQ) ? flush_wb_addr_r :
                                  line_align_addr(req_addr_r);
    assign state_mem_req_id_w = (state_r == ST_REFILL_REQ) ? DEMAND_MEM_ID
                                                           : WRITEBACK_MEM_ID;
    assign state_mem_req_wdata_w = (state_r == ST_MISS_WB_REQ) ? victim_data_r :
                                   flush_wb_data_r;
    assign state_mem_req_wstrb_w = {LINE_BYTES{1'b1}};
    assign state_mem_req_size_w = LINE_BYTES[7:0] - 8'd1;
    assign mem_req_valid = state_mem_req_valid_w || mshr_issue_stage_valid_r;
    assign mem_req_write = state_mem_req_valid_w ? state_mem_req_write_w
                                                 : mshr_issue_stage_write_r;
    assign mem_req_addr = state_mem_req_valid_w ? state_mem_req_addr_w :
                          mshr_issue_stage_addr_r;
    assign mem_req_id = state_mem_req_valid_w ? state_mem_req_id_w
                                              : mshr_issue_stage_slot_r;
    assign mem_req_wdata = state_mem_req_valid_w ? state_mem_req_wdata_w
                                                 : mshr_issue_stage_wdata_r;
    assign mem_req_wstrb = state_mem_req_valid_w ? state_mem_req_wstrb_w
                                                 : {LINE_BYTES{1'b1}};
    assign mem_req_size = state_mem_req_valid_w ? state_mem_req_size_w
                                                : (LINE_BYTES[7:0] - 8'd1);
    assign mem_resp_line_w = mem_resp_rdata[LINE_BITS-1:0];
    assign expected_mem_resp_id_w = (state_r == ST_REFILL_WAIT) ? DEMAND_MEM_ID
                                                                : WRITEBACK_MEM_ID;
    assign mem_resp_match_w = mem_resp_valid && (mem_resp_id == expected_mem_resp_id_w);
    assign mem_resp_ready = (((state_r == ST_MISS_WB_WAIT) ||
                              (state_r == ST_REFILL_WAIT) ||
                              (state_r == ST_FLUSH_WB_WAIT)) &&
                             (mem_resp_id == expected_mem_resp_id_w)) ||
                            mshr_resp_match_r;
    assign bypass_req_valid = (state_r == ST_BYPASS_REQ);
    assign bypass_req_write = req_write_r;
    assign bypass_req_addr = req_addr_r;
    assign bypass_req_id = req_id_r;
    assign bypass_req_size = req_total_size_r;
    assign bypass_req_wdata = req_wdata_r;
    assign bypass_req_wstrb = req_wstrb_r;
    assign bypass_resp_match_w = bypass_resp_valid && (bypass_resp_id == req_id_r);
    // Lower bypass completions are retired by the outer compat layer once the
    // request has been issued, so the cache-control FSM no longer stalls in a
    // dedicated bypass-wait state.
    assign bypass_resp_ready = 1'b0;

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

        if (state_r == ST_LOOKUP_WAIT &&
            data_rd_valid &&
            meta_rd_valid &&
            valid_rd_valid &&
            repl_rd_valid) begin
            for (lookup_way_idx = 32'd0;
                 lookup_way_idx < WAY_COUNT;
                 lookup_way_idx = lookup_way_idx + 32'd1) begin
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
                for (lookup_way_idx = 32'd0;
                     lookup_way_idx < WAY_COUNT;
                     lookup_way_idx = lookup_way_idx + 32'd1) begin
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

        if (state_r == ST_FLUSH_SCAN_WAIT &&
            data_rd_valid &&
            meta_rd_valid &&
            valid_rd_valid &&
            repl_rd_valid) begin
            for (flush_way_idx = 32'd0;
                 flush_way_idx < WAY_COUNT;
                 flush_way_idx = flush_way_idx + 32'd1) begin
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
                    if (flush_way_idx[WAY_BITS-1:0] == LAST_WAY) begin
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
            req_bypass_r <= 1'b0;
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
            resp_rdata_r <= {READ_RESP_BITS{1'b0}};
            resp_code_r <= 2'b00;
            install_from_mshr_r <= 1'b0;
            install_mshr_slot_r <= {ID_BITS{1'b0}};
            mshr_commit_need_refill_r <= 1'b0;
            mshr_issue_stage_valid_r <= 1'b0;
            mshr_issue_stage_write_r <= 1'b0;
            mshr_issue_stage_slot_r <= {ID_BITS{1'b0}};
            mshr_issue_stage_addr_r <= {ADDR_BITS{1'b0}};
            // Wide MSHR payload arrays are guarded by valid bits, so invalid
            // entries intentionally keep unconstrained reset values.
            for (mshr_seq_idx = 32'd0;
                 mshr_seq_idx < MSHR_COUNT;
                 mshr_seq_idx = mshr_seq_idx + 32'd1) begin
                mshr_valid_r[mshr_seq_idx] <= 1'b0;
                `LLC_MSHR_ADDR(mshr_seq_idx) <= {ADDR_BITS{1'b0}};
                `LLC_MSHR_SET(mshr_seq_idx) <= {SET_BITS{1'b0}};
                `LLC_MSHR_TAG(mshr_seq_idx) <= {TAG_BITS{1'b0}};
                `LLC_MSHR_WAY(mshr_seq_idx) <= {WAY_BITS{1'b0}};
                mshr_is_write_r[mshr_seq_idx] <= 1'b0;
                mshr_committed_r[mshr_seq_idx] <= 1'b0;
                mshr_victim_dirty_r[mshr_seq_idx] <= 1'b0;
                mshr_wb_done_r[mshr_seq_idx] <= 1'b0;
                mshr_wb_issued_r[mshr_seq_idx] <= 1'b0;
                mshr_refill_issued_r[mshr_seq_idx] <= 1'b0;
                mshr_refill_valid_r[mshr_seq_idx] <= 1'b0;
                `LLC_MSHR_VICTIM_ADDR(mshr_seq_idx) <= {ADDR_BITS{1'b0}};
                mshr_need_refill_r[mshr_seq_idx] <= 1'b0;
                `LLC_MSHR_TOTAL_SIZE(mshr_seq_idx) <= 8'd0;
            end
        end else begin
            if (resp_valid_r && resp_ready) begin
                resp_valid_r <= 1'b0;
                resp_code_r <= 2'b00;
            end

            if (mshr_issue_stage_valid_r && !state_mem_req_valid_w && mem_req_ready) begin
                if (mshr_issue_stage_write_r) begin
                    mshr_wb_issued_r[mshr_issue_stage_slot_r] <= 1'b1;
                end else begin
                    mshr_refill_issued_r[mshr_issue_stage_slot_r] <= 1'b1;
                end
                mshr_issue_stage_valid_r <= 1'b0;
            end else if (!mshr_issue_stage_valid_r &&
                         !state_mem_req_valid_w &&
                         mshr_issue_found_r) begin
                mshr_issue_stage_valid_r <= 1'b1;
                mshr_issue_stage_write_r <= mshr_issue_write_r;
                mshr_issue_stage_slot_r <= mshr_issue_slot_r;
                mshr_issue_stage_addr_r <= mshr_issue_write_r ?
                                           `LLC_MSHR_VICTIM_ADDR(mshr_issue_slot_r) :
                                           line_align_addr(`LLC_MSHR_ADDR(mshr_issue_slot_r));
                mshr_issue_stage_wdata_r <= mshr_issue_write_r ?
                                            `LLC_MSHR_VICTIM_DATA(mshr_issue_slot_r) :
                                            {LINE_BITS{1'b0}};
            end

            if (mshr_resp_match_r && !state_mem_req_valid_w) begin
                if (mshr_resp_is_wb_r) begin
                    mshr_wb_done_r[mshr_resp_slot_r] <= 1'b1;
                    mshr_wb_issued_r[mshr_resp_slot_r] <= 1'b0;
                    if (dirty_count_r != 0) begin
                        dirty_count_r <= dirty_count_r - 32'd1;
                    end
                    if (mshr_committed_r[mshr_resp_slot_r]) begin
                        mshr_valid_r[mshr_resp_slot_r] <= 1'b0;
                        mshr_is_write_r[mshr_resp_slot_r] <= 1'b0;
                        mshr_committed_r[mshr_resp_slot_r] <= 1'b0;
                        mshr_victim_dirty_r[mshr_resp_slot_r] <= 1'b0;
                        mshr_wb_done_r[mshr_resp_slot_r] <= 1'b0;
                        mshr_refill_issued_r[mshr_resp_slot_r] <= 1'b0;
                        mshr_refill_valid_r[mshr_resp_slot_r] <= 1'b0;
                        `LLC_MSHR_ADDR(mshr_resp_slot_r) <= {ADDR_BITS{1'b0}};
                        `LLC_MSHR_SET(mshr_resp_slot_r) <= {SET_BITS{1'b0}};
                        `LLC_MSHR_TAG(mshr_resp_slot_r) <= {TAG_BITS{1'b0}};
                        `LLC_MSHR_WAY(mshr_resp_slot_r) <= {WAY_BITS{1'b0}};
                        `LLC_MSHR_VICTIM_ADDR(mshr_resp_slot_r) <= {ADDR_BITS{1'b0}};
                        mshr_need_refill_r[mshr_resp_slot_r] <= 1'b0;
                        `LLC_MSHR_TOTAL_SIZE(mshr_resp_slot_r) <= 8'd0;
                    end
                end else begin
                    mshr_refill_issued_r[mshr_resp_slot_r] <= 1'b0;
                    mshr_refill_valid_r[mshr_resp_slot_r] <= 1'b1;
                    `LLC_MSHR_REFILL_LINE(mshr_resp_slot_r) <= mem_resp_line_w;
                end
            end

            case (state_r)
                ST_IDLE: begin
                    if (flush_start && (dirty_count_r != 0)) begin
                        flush_set_r <= {SET_BITS{1'b0}};
                        flush_way_start_r <= {WAY_BITS{1'b0}};
                        state_r <= ST_FLUSH_SCAN_REQ;
                    end else if (mshr_commit_found_r && !store_write_busy_w &&
                                 !resp_valid_r) begin
                        req_write_r <= mshr_is_write_r[mshr_commit_slot_r];
                        install_from_mshr_r <= 1'b1;
                        install_mshr_slot_r <= mshr_commit_slot_r;
                        req_bypass_r <= 1'b0;
                        req_addr_r <= `LLC_MSHR_ADDR(mshr_commit_slot_r);
                        req_id_r <= mshr_commit_slot_r;
                        req_total_size_r <= `LLC_MSHR_TOTAL_SIZE(mshr_commit_slot_r);
                        req_wdata_r <= `LLC_MSHR_WDATA(mshr_commit_slot_r);
                        req_wstrb_r <= `LLC_MSHR_WSTRB(mshr_commit_slot_r);
                        req_set_r <= `LLC_MSHR_SET(mshr_commit_slot_r);
                        req_tag_r <= `LLC_MSHR_TAG(mshr_commit_slot_r);
                        req_invalidate_r <= 1'b0;
                        install_way_r <= `LLC_MSHR_WAY(mshr_commit_slot_r);
                        mshr_commit_need_refill_r <= mshr_need_refill_r[mshr_commit_slot_r];
                        mshr_commit_refill_line_r <= `LLC_MSHR_REFILL_LINE(mshr_commit_slot_r);
                        replace_dirty_r <= mshr_victim_dirty_r[mshr_commit_slot_r];
                        state_r <= ST_MSHR_COMMIT_PREP;
                    end else if (accept_invalidate_line_w) begin
                        req_write_r <= 1'b0;
                        req_bypass_r <= 1'b0;
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
                        req_bypass_r <= req_bypass;
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
                    if (data_rd_valid &&
                        meta_rd_valid &&
                        valid_rd_valid &&
                        repl_rd_valid) begin
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
                                install_line_r <= write_hit_merged_line_w;
                                if (!req_bypass_r) begin
                                    for (mshr_seq_idx = 32'd0;
                                         mshr_seq_idx < MSHR_COUNT;
                                         mshr_seq_idx = mshr_seq_idx + 32'd1) begin
                                        if (mshr_write_hit_update_mask_w[mshr_seq_idx]) begin
                                            mshr_victim_dirty_r[mshr_seq_idx] <= 1'b1;
                                            mshr_wb_done_r[mshr_seq_idx] <= 1'b0;
                                            `LLC_MSHR_VICTIM_ADDR(mshr_seq_idx) <=
                                                line_align_addr(req_addr_r);
                                            `LLC_MSHR_VICTIM_DATA(mshr_seq_idx) <=
                                                write_hit_merged_line_w;
                                        end
                                    end
                                end
                                state_r <= ST_WRITE_HIT;
                            end else if (req_bypass_r) begin
                                resp_valid_r <= 1'b1;
                                resp_rdata_r <= lookup_hit_resp_rdata_w;
                                resp_code_r <= 2'b00;
                                state_r <= ST_IDLE;
                            end else begin
                                resp_valid_r <= 1'b1;
                                resp_rdata_r <= lookup_hit_resp_rdata_w;
                                resp_code_r <= 2'b00;
                                state_r <= ST_IDLE;
                            end
                        end else begin
                            install_way_r <= lookup_select_way_r;
                            replace_dirty_r <= lookup_victim_dirty_r;
                            victim_addr_r <= lookup_victim_addr_r;
                            victim_data_r <= lookup_victim_line_r;

                            if (req_bypass_r) begin
                                state_r <= ST_BYPASS_REQ;
                            end else if (req_write_r && full_write_w &&
                                         !lookup_victim_dirty_r) begin
                                install_line_r <= req_wdata_r;
                                install_dirty_r <= 1'b1;
                                state_r <= ST_INSTALL;
                            end else begin
                                mshr_valid_r[req_id_r] <= 1'b1;
                                `LLC_MSHR_ADDR(req_id_r) <= req_addr_r;
                                `LLC_MSHR_SET(req_id_r) <= req_set_r;
                                `LLC_MSHR_TAG(req_id_r) <= req_tag_r;
                                `LLC_MSHR_WAY(req_id_r) <= lookup_select_way_r;
                                mshr_is_write_r[req_id_r] <= req_write_r;
                                mshr_committed_r[req_id_r] <= 1'b0;
                                mshr_victim_dirty_r[req_id_r] <= lookup_victim_dirty_r;
                                mshr_wb_done_r[req_id_r] <= !lookup_victim_dirty_r;
                                mshr_wb_issued_r[req_id_r] <= 1'b0;
                                mshr_refill_issued_r[req_id_r] <= 1'b0;
                                mshr_refill_valid_r[req_id_r] <= 1'b0;
                                `LLC_MSHR_VICTIM_ADDR(req_id_r) <= lookup_victim_addr_r;
                                `LLC_MSHR_VICTIM_DATA(req_id_r) <= lookup_victim_line_r;
                                `LLC_MSHR_WDATA(req_id_r) <= req_wdata_r;
                                `LLC_MSHR_WSTRB(req_id_r) <= req_wstrb_r;
                                mshr_need_refill_r[req_id_r] <= !req_write_r || !full_write_w;
                                `LLC_MSHR_TOTAL_SIZE(req_id_r) <= req_total_size_r;
                                install_from_mshr_r <= 1'b0;
                                install_mshr_slot_r <= {ID_BITS{1'b0}};
                                state_r <= ST_IDLE;
                            end
                        end
                    end
                end

                ST_MSHR_COMMIT_PREP: begin
                    if (req_write_r) begin
                        if (mshr_commit_need_refill_r) begin
                            install_line_r <= merge_line(mshr_commit_refill_line_r,
                                                         req_addr_r,
                                                         req_wdata_r,
                                                         req_wstrb_r);
                        end else begin
                            install_line_r <= req_wdata_r;
                        end
                        install_dirty_r <= 1'b1;
                    end else begin
                        install_line_r <= mshr_commit_refill_line_r;
                        install_dirty_r <= 1'b0;
                    end
                    state_r <= ST_INSTALL;
                end

                ST_WRITE_HIT: begin
                    if (!req_bypass_r && !hit_dirty_r) begin
                        dirty_count_r <= dirty_count_r + 32'd1;
                    end
                    if (req_bypass_r) begin
                        state_r <= ST_BYPASS_REQ;
                    end else begin
                        resp_valid_r <= 1'b1;
                        resp_rdata_r <= {READ_RESP_BITS{1'b0}};
                        resp_code_r <= 2'b00;
                        state_r <= ST_IDLE;
                    end
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
                            install_line_r <= merge_line(mem_resp_line_w,
                                                         req_addr_r,
                                                         req_wdata_r,
                                                         req_wstrb_r);
                            install_dirty_r <= 1'b1;
                        end else begin
                            install_line_r <= mem_resp_line_w;
                            install_dirty_r <= 1'b0;
                        end
                        state_r <= ST_INSTALL;
                    end
                end

                ST_INSTALL: begin
                    if (install_dirty_r && !replace_dirty_r) begin
                        dirty_count_r <= dirty_count_r + 32'd1;
                    end
                    if (install_from_mshr_r) begin
                        if (mshr_victim_dirty_r[install_mshr_slot_r] &&
                            !mshr_wb_done_r[install_mshr_slot_r]) begin
                            mshr_committed_r[install_mshr_slot_r] <= 1'b1;
                            mshr_refill_valid_r[install_mshr_slot_r] <= 1'b0;
                            mshr_need_refill_r[install_mshr_slot_r] <= 1'b0;
                        end else begin
                            mshr_valid_r[install_mshr_slot_r] <= 1'b0;
                            mshr_is_write_r[install_mshr_slot_r] <= 1'b0;
                            mshr_committed_r[install_mshr_slot_r] <= 1'b0;
                            mshr_victim_dirty_r[install_mshr_slot_r] <= 1'b0;
                            mshr_wb_done_r[install_mshr_slot_r] <= 1'b0;
                            mshr_wb_issued_r[install_mshr_slot_r] <= 1'b0;
                            mshr_refill_issued_r[install_mshr_slot_r] <= 1'b0;
                            mshr_refill_valid_r[install_mshr_slot_r] <= 1'b0;
                            `LLC_MSHR_ADDR(install_mshr_slot_r) <= {ADDR_BITS{1'b0}};
                            `LLC_MSHR_SET(install_mshr_slot_r) <= {SET_BITS{1'b0}};
                            `LLC_MSHR_TAG(install_mshr_slot_r) <= {TAG_BITS{1'b0}};
                            `LLC_MSHR_WAY(install_mshr_slot_r) <= {WAY_BITS{1'b0}};
                            `LLC_MSHR_VICTIM_ADDR(install_mshr_slot_r) <=
                                {ADDR_BITS{1'b0}};
                            mshr_need_refill_r[install_mshr_slot_r] <= 1'b0;
                            `LLC_MSHR_TOTAL_SIZE(install_mshr_slot_r) <= 8'd0;
                        end
                        install_from_mshr_r <= 1'b0;
                    end
                    resp_valid_r <= 1'b1;
                        if (req_write_r) begin
                            resp_rdata_r <= {READ_RESP_BITS{1'b0}};
                            resp_code_r <= 2'b00;
                        end else begin
                            resp_rdata_r <= install_resp_rdata_w;
                            resp_code_r <= 2'b00;
                        end
                    state_r <= ST_IDLE;
                end

                ST_FLUSH_SCAN_REQ: begin
                    state_r <= ST_FLUSH_SCAN_WAIT;
                end

                ST_FLUSH_SCAN_WAIT: begin
                    if (data_rd_valid &&
                        meta_rd_valid &&
                        valid_rd_valid &&
                        repl_rd_valid) begin
                        if (flush_found_dirty_r) begin
                            flush_wb_addr_r <= flush_found_addr_r;
                            flush_wb_data_r <= flush_found_line_r;
                            flush_set_r <= flush_next_set_r;
                            flush_way_start_r <= flush_next_way_r;
                            state_r <= ST_FLUSH_WB_REQ;
                        end else if (flush_set_r == LAST_SET) begin
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

                ST_BYPASS_REQ: begin
                    if (bypass_req_valid && bypass_req_ready) begin
                        state_r <= ST_IDLE;
                    end
                end

                ST_BYPASS_WAIT: begin
                    if (bypass_resp_match_w) begin
                        resp_valid_r <= 1'b1;
                        if (req_write_r) begin
                            resp_rdata_r <= {READ_RESP_BITS{1'b0}};
                            resp_code_r <= bypass_resp_code;
                        end else begin
                            resp_rdata_r <= bypass_resp_rdata;
                            resp_code_r <= 2'b00;
                        end
                        state_r <= ST_IDLE;
                    end
                end

                default: begin
                    state_r <= ST_IDLE;
                end
            endcase
        end
    end

`undef LLC_MSHR_ADDR
`undef LLC_MSHR_SET
`undef LLC_MSHR_TAG
`undef LLC_MSHR_WAY
`undef LLC_MSHR_VICTIM_ADDR
`undef LLC_MSHR_VICTIM_DATA
`undef LLC_MSHR_REFILL_LINE
`undef LLC_MSHR_WDATA
`undef LLC_MSHR_WSTRB
`undef LLC_MSHR_TOTAL_SIZE

endmodule
