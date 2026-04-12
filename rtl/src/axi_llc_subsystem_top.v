`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module axi_llc_subsystem_top #(
    parameter ADDR_BITS        = `AXI_LLC_ADDR_BITS,
    parameter ID_BITS          = `AXI_LLC_ID_BITS,
    parameter MODE_BITS        = `AXI_LLC_MODE_BITS,
    parameter LINE_BYTES       = `AXI_LLC_LINE_BYTES,
    parameter LINE_BITS        = `AXI_LLC_LINE_BITS,
    parameter LINE_OFFSET_BITS = `AXI_LLC_LINE_OFFSET_BITS,
    parameter SET_COUNT        = `AXI_LLC_SET_COUNT,
    parameter SET_BITS         = `AXI_LLC_SET_BITS,
    parameter WAY_COUNT        = `AXI_LLC_WAY_COUNT,
    parameter WAY_BITS         = `AXI_LLC_WAY_BITS,
    parameter META_BITS        = `AXI_LLC_META_BITS,
    parameter LLC_SIZE_BYTES   = `AXI_LLC_LLC_SIZE_BYTES,
    parameter WINDOW_BYTES     = `AXI_LLC_WINDOW_BYTES,
    parameter WINDOW_WAYS      = `AXI_LLC_WINDOW_WAYS,
    parameter MMIO_BASE        = `AXI_LLC_MMIO_BASE,
    parameter MMIO_SIZE        = `AXI_LLC_MMIO_SIZE,
    parameter RESET_MODE       = {{(`AXI_LLC_MODE_BITS-2){1'b0}}, 2'b01},
    parameter RESET_OFFSET     = {`AXI_LLC_ADDR_BITS{1'b0}},
    parameter USE_SMIC12_STORES = 0,
    parameter DATA_ROW_BITS    = WAY_COUNT * LINE_BITS,
    parameter META_ROW_BITS    = WAY_COUNT * META_BITS
) (
    input                       clk,
    input                       rst_n,
    input      [MODE_BITS-1:0]  mode_req,
    input      [ADDR_BITS-1:0]  llc_mapped_offset_req,
    input                       up_req_valid,
    output                      up_req_ready,
    input                       up_req_write,
    input      [ADDR_BITS-1:0]  up_req_addr,
    input      [ID_BITS-1:0]    up_req_id,
    input      [7:0]            up_req_total_size,
    input      [LINE_BITS-1:0]  up_req_wdata,
    input      [LINE_BYTES-1:0] up_req_wstrb,
    input                       up_req_bypass,
    output                      up_resp_valid,
    input                       up_resp_ready,
    output     [LINE_BITS-1:0]  up_resp_rdata,
    output     [ID_BITS-1:0]    up_resp_id,
    output                      cache_req_valid,
    input                       cache_req_ready,
    output                      cache_req_write,
    output     [ADDR_BITS-1:0]  cache_req_addr,
    output     [ID_BITS-1:0]    cache_req_id,
    output     [7:0]            cache_req_size,
    output     [LINE_BITS-1:0]  cache_req_wdata,
    output     [LINE_BYTES-1:0] cache_req_wstrb,
    input                       cache_resp_valid,
    output                      cache_resp_ready,
    input      [LINE_BITS-1:0]  cache_resp_rdata,
    input      [ID_BITS-1:0]    cache_resp_id,
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
    input      [LINE_BITS-1:0]  bypass_resp_rdata,
    input      [ID_BITS-1:0]    bypass_resp_id,
    input                       invalidate_line_valid,
    input      [ADDR_BITS-1:0]  invalidate_line_addr,
    output                      invalidate_line_accepted,
    input                       invalidate_all_valid,
    output                      invalidate_all_accepted,
    output     [MODE_BITS-1:0]  active_mode,
    output     [ADDR_BITS-1:0]  active_offset,
    output                      reconfig_busy,
    output     [1:0]            reconfig_state,
    output                      config_error
);

    localparam [MODE_BITS-1:0] MODE_CACHE  = 2'b01;
    localparam [MODE_BITS-1:0] MODE_MAPPED = 2'b10;

    reg                       direct_wait_rd_r;
    reg                       direct_write_r;
    reg [ADDR_BITS-1:0]       direct_addr_r;
    reg [ID_BITS-1:0]         direct_id_r;
    reg [LINE_BITS-1:0]       direct_wdata_r;
    reg [LINE_BYTES-1:0]      direct_wstrb_r;
    reg [SET_BITS-1:0]        direct_set_r;

    reg                       resp_pending_r;
    reg [LINE_BITS-1:0]       resp_data_r;
    reg [ID_BITS-1:0]         resp_id_r;

    reg                       bypass_pending_r;
    reg                       bypass_issued_r;
    reg                       bypass_req_write_r;
    reg [ADDR_BITS-1:0]       bypass_req_addr_r;
    reg [ID_BITS-1:0]         bypass_req_id_r;
    reg [7:0]                 bypass_req_size_r;
    reg [LINE_BITS-1:0]       bypass_req_wdata_r;
    reg [LINE_BYTES-1:0]      bypass_req_wstrb_r;

    wire [MODE_BITS-1:0]      active_mode_w;
    wire [ADDR_BITS-1:0]      active_offset_w;
    wire [MODE_BITS-1:0]      reconfig_req_mode_w;
    wire [ADDR_BITS-1:0]      reconfig_req_offset_w;
    wire                      reconfig_block_accepts_w;
    wire                      sweep_busy_w;
    wire                      sweep_done_w;
    wire                      sweep_start_w;
    wire                      valid_wr_en_sweep_w;
    wire [SET_BITS-1:0]       valid_wr_set_sweep_w;
    wire [WAY_COUNT-1:0]      valid_wr_mask_sweep_w;
    wire [WAY_COUNT-1:0]      valid_wr_bits_sweep_w;

    wire                      offset_aligned_w;
    wire                      mapped_in_window_w;
    wire                      mapped_way_legal_w;
    wire                      mapped_next_valid_bit_w;
    wire [SET_BITS-1:0]       mapped_set_w;
    wire [WAY_BITS-1:0]       mapped_way_w;
    wire [LINE_BITS-1:0]      mapped_read_line_w;
    wire [LINE_BITS-1:0]      mapped_write_line_w;

    wire [ADDR_BITS-1:0]      mapped_req_addr_w;
    wire [LINE_BITS-1:0]      mapped_req_wdata_w;
    wire [LINE_BYTES-1:0]     mapped_req_wstrb_w;
    wire [SET_BITS-1:0]       direct_valid_rd_set_w;

    wire                      cfg_req_legal_w;
    wire                      is_mmio_w;
    wire                      route_direct_w;
    wire                      route_cache_w;
    wire                      route_bypass_w;

    wire                      direct_accept_w;
    wire                      bypass_accept_w;
    wire                      cache_invalidate_line_accepted_w;
    wire                      noop_invalidate_line_accepted_w;
    wire                      invalidate_line_fire_w;

    wire                      cache_up_req_valid_w;
    wire                      cache_up_req_ready_w;
    wire                      cache_up_resp_valid_w;
    wire                      cache_up_resp_visible_w;
    wire [LINE_BITS-1:0]      cache_up_resp_rdata_w;
    wire [ID_BITS-1:0]        cache_up_resp_id_w;
    wire                      cache_mem_req_valid_w;
    wire                      cache_mem_req_write_w;
    wire [ADDR_BITS-1:0]      cache_mem_req_addr_w;
    wire [ID_BITS-1:0]        cache_mem_req_id_w;
    wire [7:0]                cache_mem_req_size_w;
    wire [LINE_BITS-1:0]      cache_mem_req_wdata_w;
    wire [LINE_BYTES-1:0]     cache_mem_req_wstrb_w;
    wire                      cache_mem_resp_ready_w;

    wire                      cache_quiescent_w;
    wire                      cache_flush_busy_w;
    wire                      cache_dirty_present_w;
    wire                      cache_flush_start_w;

    wire                      cache_data_rd_en_w;
    wire [SET_BITS-1:0]       cache_data_rd_set_w;
    wire                      cache_data_wr_en_w;
    wire [SET_BITS-1:0]       cache_data_wr_set_w;
    wire [WAY_COUNT-1:0]      cache_data_wr_way_mask_w;
    wire [DATA_ROW_BITS-1:0]  cache_data_wr_row_w;

    wire                      cache_meta_rd_en_w;
    wire [SET_BITS-1:0]       cache_meta_rd_set_w;
    wire                      cache_meta_wr_en_w;
    wire [SET_BITS-1:0]       cache_meta_wr_set_w;
    wire [WAY_COUNT-1:0]      cache_meta_wr_way_mask_w;
    wire [META_ROW_BITS-1:0]  cache_meta_wr_row_w;

    wire [SET_BITS-1:0]       cache_valid_rd_set_w;
    wire                      cache_valid_wr_en_w;
    wire [SET_BITS-1:0]       cache_valid_wr_set_w;
    wire [WAY_COUNT-1:0]      cache_valid_wr_mask_w;
    wire [WAY_COUNT-1:0]      cache_valid_wr_bits_w;

    wire [SET_BITS-1:0]       cache_repl_rd_set_w;
    wire [WAY_BITS-1:0]       repl_rd_way_w;
    wire                      cache_repl_wr_en_w;
    wire [SET_BITS-1:0]       cache_repl_wr_set_w;
    wire [WAY_BITS-1:0]       cache_repl_wr_way_w;

    wire                      valid_wr_en_w;
    wire [SET_BITS-1:0]       valid_wr_set_w;
    wire [WAY_COUNT-1:0]      valid_wr_mask_w;
    wire [WAY_COUNT-1:0]      valid_wr_bits_w;
    wire [WAY_COUNT-1:0]      valid_rd_bits_w;

    wire                      data_rd_en_w;
    wire [SET_BITS-1:0]       data_rd_set_w;
    wire                      data_rd_valid_w;
    wire [DATA_ROW_BITS-1:0]  data_rd_row_w;
    wire                      data_wr_en_w;
    wire [SET_BITS-1:0]       data_wr_set_w;
    wire [WAY_COUNT-1:0]      data_wr_way_mask_w;
    wire [DATA_ROW_BITS-1:0]  data_wr_row_w;
    wire                      data_busy_w;

    wire                      meta_rd_en_w;
    wire [SET_BITS-1:0]       meta_rd_set_w;
    wire                      meta_rd_valid_w;
    wire [META_ROW_BITS-1:0]  meta_rd_row_w;
    wire                      meta_wr_en_w;
    wire [SET_BITS-1:0]       meta_wr_set_w;
    wire [WAY_COUNT-1:0]      meta_wr_way_mask_w;
    wire [META_ROW_BITS-1:0]  meta_wr_row_w;
    wire                      meta_busy_w;

    wire                      direct_data_wr_en_w;
    wire [WAY_COUNT-1:0]      direct_data_wr_way_mask_w;
    wire [DATA_ROW_BITS-1:0]  direct_data_wr_row_w;
    wire                      direct_valid_wr_en_w;
    wire [SET_BITS-1:0]       direct_valid_wr_set_w;
    wire [WAY_COUNT-1:0]      direct_valid_wr_mask_w;
    wire [WAY_COUNT-1:0]      direct_valid_wr_bits_w;
    wire                      global_quiescent_w;
    wire [ADDR_BITS:0]        up_req_end_w;
    wire [ADDR_BITS:0]        mmio_limit_w;

    function [WAY_COUNT-1:0] way_onehot;
        input [WAY_BITS-1:0] way_idx;
        integer idx;
        begin
            way_onehot = {WAY_COUNT{1'b0}};
            for (idx = 0; idx < WAY_COUNT; idx = idx + 1) begin
                if (way_idx == idx[WAY_BITS-1:0]) begin
                    way_onehot[idx] = 1'b1;
                end
            end
        end
    endfunction

    function [DATA_ROW_BITS-1:0] place_line_in_row;
        input [WAY_BITS-1:0]  way_idx;
        input [LINE_BITS-1:0] line_data;
        integer idx;
        begin
            place_line_in_row = {DATA_ROW_BITS{1'b0}};
            for (idx = 0; idx < WAY_COUNT; idx = idx + 1) begin
                if (way_idx == idx[WAY_BITS-1:0]) begin
                    place_line_in_row[(idx * LINE_BITS) +: LINE_BITS] = line_data;
                end
            end
        end
    endfunction

    assign up_req_end_w = {1'b0, up_req_addr} +
                          {{(ADDR_BITS-7){1'b0}}, up_req_total_size} +
                          {{ADDR_BITS{1'b0}}, 1'b1};
    assign mmio_limit_w = {1'b0, MMIO_BASE} + {1'b0, MMIO_SIZE};

    assign cfg_req_legal_w = (mode_req != MODE_MAPPED) ||
                             (llc_mapped_offset_req[LINE_OFFSET_BITS-1:0] ==
                              {LINE_OFFSET_BITS{1'b0}});
    assign config_error = (mode_req == MODE_MAPPED) && !cfg_req_legal_w;
    assign reconfig_req_mode_w   = cfg_req_legal_w ? mode_req : active_mode_w;
    assign reconfig_req_offset_w = cfg_req_legal_w ?
                                   ((mode_req == MODE_MAPPED) ? llc_mapped_offset_req :
                                    active_offset_w) :
                                   active_offset_w;

    assign active_mode = active_mode_w;
    assign active_offset = active_offset_w;
    assign reconfig_busy = (reconfig_state != 2'b00);

    assign mapped_req_addr_w = direct_wait_rd_r ? direct_addr_r : up_req_addr;
    assign mapped_req_wdata_w = direct_wait_rd_r ? direct_wdata_r : up_req_wdata;
    assign mapped_req_wstrb_w = direct_wait_rd_r ? direct_wstrb_r : up_req_wstrb;

    assign direct_valid_rd_set_w = direct_wait_rd_r ? direct_set_r : mapped_set_w;
    assign is_mmio_w = (up_req_addr >= MMIO_BASE) &&
                       (up_req_end_w <= mmio_limit_w);

    assign route_direct_w = (active_mode_w == MODE_MAPPED) &&
                            mapped_in_window_w &&
                            mapped_way_legal_w &&
                            offset_aligned_w;
    assign route_cache_w = (active_mode_w == MODE_CACHE) &&
                           !up_req_bypass &&
                           !is_mmio_w;
    assign route_bypass_w = !route_direct_w && !route_cache_w;
    assign cache_up_resp_visible_w = (active_mode_w == MODE_CACHE) &&
                                     cache_up_resp_valid_w;

    assign cache_up_req_valid_w = up_req_valid && route_cache_w &&
                                  !invalidate_line_valid &&
                                  !invalidate_all_valid &&
                                  !reconfig_block_accepts_w &&
                                  !resp_pending_r &&
                                  !bypass_pending_r &&
                                  !direct_wait_rd_r;

    assign direct_accept_w = up_req_valid && up_req_ready && route_direct_w;
    assign bypass_accept_w = up_req_valid && up_req_ready && route_bypass_w;
    assign noop_invalidate_line_accepted_w = invalidate_line_valid &&
                                             !invalidate_all_valid &&
                                             !reconfig_block_accepts_w &&
                                             (active_mode_w != MODE_CACHE);
    assign invalidate_line_fire_w = cache_invalidate_line_accepted_w ||
                                    noop_invalidate_line_accepted_w;
    assign invalidate_line_accepted = invalidate_line_fire_w;

    assign direct_data_wr_en_w = direct_wait_rd_r && data_rd_valid_w && direct_write_r;
    assign direct_data_wr_way_mask_w = way_onehot(mapped_way_w);
    assign direct_data_wr_row_w = place_line_in_row(mapped_way_w, mapped_write_line_w);

    assign direct_valid_wr_en_w = direct_wait_rd_r && data_rd_valid_w && direct_write_r;
    assign direct_valid_wr_set_w = direct_set_r;
    assign direct_valid_wr_mask_w = way_onehot(mapped_way_w);
    assign direct_valid_wr_bits_w = mapped_next_valid_bit_w ? way_onehot(mapped_way_w)
                                                            : {WAY_COUNT{1'b0}};
    assign valid_wr_en_w = valid_wr_en_sweep_w ? 1'b1 :
                           (active_mode_w == MODE_CACHE) ? cache_valid_wr_en_w :
                           direct_valid_wr_en_w;
    assign valid_wr_set_w = valid_wr_en_sweep_w ? valid_wr_set_sweep_w :
                            (active_mode_w == MODE_CACHE) ? cache_valid_wr_set_w :
                            direct_valid_wr_set_w;
    assign valid_wr_mask_w = valid_wr_en_sweep_w ? valid_wr_mask_sweep_w :
                             (active_mode_w == MODE_CACHE) ? cache_valid_wr_mask_w :
                             direct_valid_wr_mask_w;
    assign valid_wr_bits_w = valid_wr_en_sweep_w ? valid_wr_bits_sweep_w :
                             (active_mode_w == MODE_CACHE) ? cache_valid_wr_bits_w :
                             direct_valid_wr_bits_w;

    assign data_rd_en_w = (active_mode_w == MODE_CACHE) ? cache_data_rd_en_w :
                          direct_accept_w;
    assign data_rd_set_w = (active_mode_w == MODE_CACHE) ? cache_data_rd_set_w :
                           mapped_set_w;
    assign data_wr_en_w = (active_mode_w == MODE_CACHE) ? cache_data_wr_en_w :
                          direct_data_wr_en_w;
    assign data_wr_set_w = (active_mode_w == MODE_CACHE) ? cache_data_wr_set_w :
                           direct_set_r;
    assign data_wr_way_mask_w = (active_mode_w == MODE_CACHE) ?
                                cache_data_wr_way_mask_w : direct_data_wr_way_mask_w;
    assign data_wr_row_w = (active_mode_w == MODE_CACHE) ? cache_data_wr_row_w :
                           direct_data_wr_row_w;

    assign meta_rd_en_w = (active_mode_w == MODE_CACHE) ? cache_meta_rd_en_w : 1'b0;
    assign meta_rd_set_w = (active_mode_w == MODE_CACHE) ? cache_meta_rd_set_w :
                           {SET_BITS{1'b0}};
    assign meta_wr_en_w = (active_mode_w == MODE_CACHE) ? cache_meta_wr_en_w : 1'b0;
    assign meta_wr_set_w = (active_mode_w == MODE_CACHE) ? cache_meta_wr_set_w :
                           {SET_BITS{1'b0}};
    assign meta_wr_way_mask_w = (active_mode_w == MODE_CACHE) ?
                                cache_meta_wr_way_mask_w : {WAY_COUNT{1'b0}};
    assign meta_wr_row_w = (active_mode_w == MODE_CACHE) ? cache_meta_wr_row_w :
                           {META_ROW_BITS{1'b0}};

    assign cache_flush_start_w = reconfig_block_accepts_w &&
                                 (active_mode_w == MODE_CACHE) &&
                                 cache_quiescent_w &&
                                 cache_dirty_present_w &&
                                 !cache_flush_busy_w;

    assign global_quiescent_w = !resp_pending_r &&
                                !bypass_pending_r &&
                                !direct_wait_rd_r &&
                                !data_busy_w &&
                                !meta_busy_w &&
                                ((active_mode_w != MODE_CACHE) ||
                                 (cache_quiescent_w && !cache_dirty_present_w));

    assign up_req_ready = !reconfig_block_accepts_w &&
                          !invalidate_all_valid &&
                          !((active_mode_w == MODE_CACHE) && invalidate_line_valid) &&
                          !resp_pending_r &&
                          !bypass_pending_r &&
                          !direct_wait_rd_r &&
                          !data_busy_w &&
                          !meta_busy_w &&
                          !cache_up_resp_visible_w &&
                          ((active_mode_w != MODE_CACHE) || cache_quiescent_w) &&
                          (route_direct_w ? 1'b1 :
                           route_cache_w ? cache_up_req_ready_w :
                           1'b1);

    assign up_resp_valid = resp_pending_r | cache_up_resp_visible_w;
    assign up_resp_rdata = resp_pending_r ? resp_data_r : cache_up_resp_rdata_w;
    assign up_resp_id = resp_pending_r ? resp_id_r : cache_up_resp_id_w;

    assign cache_req_valid = cache_mem_req_valid_w;
    assign cache_req_write = cache_mem_req_write_w;
    assign cache_req_addr = cache_mem_req_addr_w;
    assign cache_req_id = cache_mem_req_id_w;
    assign cache_req_size = cache_mem_req_size_w;
    assign cache_req_wdata = cache_mem_req_wdata_w;
    assign cache_req_wstrb = cache_mem_req_wstrb_w;
    assign cache_resp_ready = cache_mem_resp_ready_w;

    assign bypass_req_valid = bypass_pending_r && !bypass_issued_r;
    assign bypass_req_write = bypass_req_write_r;
    assign bypass_req_addr = bypass_req_addr_r;
    assign bypass_req_id = bypass_req_id_r;
    assign bypass_req_size = bypass_req_size_r;
    assign bypass_req_wdata = bypass_req_wdata_r;
    assign bypass_req_wstrb = bypass_req_wstrb_r;
    assign bypass_resp_ready = bypass_pending_r && bypass_issued_r &&
                               !resp_pending_r && !cache_up_resp_visible_w &&
                               (bypass_resp_id == bypass_req_id_r);

    axi_reconfig_ctrl #(
        .MODE_BITS    (MODE_BITS),
        .ADDR_BITS    (ADDR_BITS),
        .RESET_MODE   (RESET_MODE),
        .RESET_OFFSET (RESET_OFFSET)
    ) reconfig_ctrl (
        .clk              (clk),
        .rst_n            (rst_n),
        .req_mode         (reconfig_req_mode_w),
        .req_offset       (reconfig_req_offset_w),
        .invalidate_all_valid(invalidate_all_valid),
        .global_quiescent (global_quiescent_w),
        .sweep_busy       (sweep_busy_w),
        .sweep_done       (sweep_done_w),
        .invalidate_all_accepted(invalidate_all_accepted),
        .active_mode      (active_mode_w),
        .active_offset    (active_offset_w),
        .target_mode      (),
        .target_offset    (),
        .block_accepts    (reconfig_block_accepts_w),
        .busy             (),
        .sweep_start      (sweep_start_w),
        .state            (reconfig_state)
    );

    llc_invalidate_sweep #(
        .SET_COUNT (SET_COUNT),
        .SET_BITS  (SET_BITS),
        .WAY_COUNT (WAY_COUNT)
    ) invalidate_sweep (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (sweep_start_w),
        .busy          (sweep_busy_w),
        .done          (sweep_done_w),
        .valid_wr_en   (valid_wr_en_sweep_w),
        .valid_wr_set  (valid_wr_set_sweep_w),
        .valid_wr_mask (valid_wr_mask_sweep_w),
        .valid_wr_bits (valid_wr_bits_sweep_w)
    );

    llc_valid_ram #(
        .SET_COUNT (SET_COUNT),
        .SET_BITS  (SET_BITS),
        .WAY_COUNT (WAY_COUNT)
    ) valid_ram (
        .clk     (clk),
        .rst_n   (rst_n),
        .rd_en   (1'b1),
        .rd_set  ((active_mode_w == MODE_CACHE) ? cache_valid_rd_set_w : direct_valid_rd_set_w),
        .rd_bits (valid_rd_bits_w),
        .wr_en   (valid_wr_en_w),
        .wr_set  (valid_wr_set_w),
        .wr_mask (valid_wr_mask_w),
        .wr_bits (valid_wr_bits_w)
    );

    llc_repl_ram #(
        .SET_COUNT (SET_COUNT),
        .SET_BITS  (SET_BITS),
        .WAY_COUNT (WAY_COUNT),
        .WAY_BITS  (WAY_BITS)
    ) repl_ram (
        .clk    (clk),
        .rst_n  (rst_n),
        .rd_set (cache_repl_rd_set_w),
        .rd_way (repl_rd_way_w),
        .wr_en  (cache_repl_wr_en_w),
        .wr_set (cache_repl_wr_set_w),
        .wr_way (cache_repl_wr_way_w)
    );

    llc_data_store #(
        .SET_COUNT (SET_COUNT),
        .SET_BITS  (SET_BITS),
        .WAY_COUNT (WAY_COUNT),
        .LINE_BITS (LINE_BITS),
        .ROW_BITS  (DATA_ROW_BITS),
        .USE_SMIC12(USE_SMIC12_STORES)
    ) data_store (
        .clk         (clk),
        .rst_n       (rst_n),
        .rd_en       (data_rd_en_w),
        .rd_set      (data_rd_set_w),
        .rd_valid    (data_rd_valid_w),
        .rd_row      (data_rd_row_w),
        .wr_en       (data_wr_en_w),
        .wr_set      (data_wr_set_w),
        .wr_way_mask (data_wr_way_mask_w),
        .wr_row      (data_wr_row_w),
        .busy        (data_busy_w)
    );

    llc_meta_store #(
        .SET_COUNT (SET_COUNT),
        .SET_BITS  (SET_BITS),
        .WAY_COUNT (WAY_COUNT),
        .META_BITS (META_BITS),
        .ROW_BITS  (META_ROW_BITS),
        .USE_SMIC12(USE_SMIC12_STORES)
    ) meta_store (
        .clk         (clk),
        .rst_n       (rst_n),
        .rd_en       (meta_rd_en_w),
        .rd_set      (meta_rd_set_w),
        .rd_valid    (meta_rd_valid_w),
        .rd_row      (meta_rd_row_w),
        .wr_en       (meta_wr_en_w),
        .wr_set      (meta_wr_set_w),
        .wr_way_mask (meta_wr_way_mask_w),
        .wr_row      (meta_wr_row_w),
        .busy        (meta_busy_w)
    );

    llc_cache_ctrl #(
        .ADDR_BITS        (ADDR_BITS),
        .LINE_BYTES       (LINE_BYTES),
        .LINE_BITS        (LINE_BITS),
        .LINE_OFFSET_BITS (LINE_OFFSET_BITS),
        .SET_COUNT        (SET_COUNT),
        .SET_BITS         (SET_BITS),
        .WAY_COUNT        (WAY_COUNT),
        .WAY_BITS         (WAY_BITS),
        .META_BITS        (META_BITS),
        .ID_BITS          (ID_BITS),
        .DATA_ROW_BITS    (DATA_ROW_BITS),
        .META_ROW_BITS    (META_ROW_BITS)
    ) cache_ctrl (
        .clk          (clk),
        .rst_n        (rst_n),
        .req_valid    (cache_up_req_valid_w),
        .req_ready    (cache_up_req_ready_w),
        .req_write    (up_req_write),
        .req_addr     (up_req_addr),
        .req_id       (up_req_id),
        .req_total_size(up_req_total_size),
        .req_wdata    (up_req_wdata),
        .req_wstrb    (up_req_wstrb),
        .resp_valid   (cache_up_resp_valid_w),
        .resp_ready   (up_resp_ready && !resp_pending_r),
        .resp_rdata   (cache_up_resp_rdata_w),
        .resp_id      (cache_up_resp_id_w),
        .invalidate_line_valid(invalidate_line_valid && (active_mode_w == MODE_CACHE)),
        .invalidate_line_addr({
            invalidate_line_addr[ADDR_BITS-1:LINE_OFFSET_BITS],
            {LINE_OFFSET_BITS{1'b0}}
        }),
        .invalidate_line_accepted(cache_invalidate_line_accepted_w),
        .data_rd_en   (cache_data_rd_en_w),
        .data_rd_set  (cache_data_rd_set_w),
        .data_rd_valid(data_rd_valid_w),
        .data_rd_row  (data_rd_row_w),
        .data_wr_en   (cache_data_wr_en_w),
        .data_wr_set  (cache_data_wr_set_w),
        .data_wr_way_mask(cache_data_wr_way_mask_w),
        .data_wr_row  (cache_data_wr_row_w),
        .data_busy    (data_busy_w),
        .meta_rd_en   (cache_meta_rd_en_w),
        .meta_rd_set  (cache_meta_rd_set_w),
        .meta_rd_valid(meta_rd_valid_w),
        .meta_rd_row  (meta_rd_row_w),
        .meta_wr_en   (cache_meta_wr_en_w),
        .meta_wr_set  (cache_meta_wr_set_w),
        .meta_wr_way_mask(cache_meta_wr_way_mask_w),
        .meta_wr_row  (cache_meta_wr_row_w),
        .meta_busy    (meta_busy_w),
        .valid_rd_set (cache_valid_rd_set_w),
        .valid_rd_bits(valid_rd_bits_w),
        .valid_wr_en  (cache_valid_wr_en_w),
        .valid_wr_set (cache_valid_wr_set_w),
        .valid_wr_mask(cache_valid_wr_mask_w),
        .valid_wr_bits(cache_valid_wr_bits_w),
        .repl_rd_set  (cache_repl_rd_set_w),
        .repl_rd_way  (repl_rd_way_w),
        .repl_wr_en   (cache_repl_wr_en_w),
        .repl_wr_set  (cache_repl_wr_set_w),
        .repl_wr_way  (cache_repl_wr_way_w),
        .flush_start  (cache_flush_start_w),
        .flush_busy   (cache_flush_busy_w),
        .dirty_present(cache_dirty_present_w),
        .quiescent    (cache_quiescent_w),
        .mem_req_valid(cache_mem_req_valid_w),
        .mem_req_ready(cache_req_ready),
        .mem_req_write(cache_mem_req_write_w),
        .mem_req_addr (cache_mem_req_addr_w),
        .mem_req_id   (cache_mem_req_id_w),
        .mem_req_wdata(cache_mem_req_wdata_w),
        .mem_req_wstrb(cache_mem_req_wstrb_w),
        .mem_req_size (cache_mem_req_size_w),
        .mem_resp_valid(cache_resp_valid),
        .mem_resp_ready(cache_mem_resp_ready_w),
        .mem_resp_rdata(cache_resp_rdata),
        .mem_resp_id  (cache_resp_id)
    );

    llc_mapped_window_ctrl #(
        .ADDR_BITS        (ADDR_BITS),
        .LINE_BYTES       (LINE_BYTES),
        .LINE_BITS        (LINE_BITS),
        .LINE_OFFSET_BITS (LINE_OFFSET_BITS),
        .SET_COUNT        (SET_COUNT),
        .SET_BITS         (SET_BITS),
        .WAY_COUNT        (WAY_COUNT),
        .WAY_BITS         (WAY_BITS),
        .WINDOW_BYTES     (WINDOW_BYTES),
        .WINDOW_WAYS      (WINDOW_WAYS)
    ) mapped_window_ctrl (
        .req_addr           (mapped_req_addr_w),
        .req_total_size     (direct_wait_rd_r ? 8'd0 : up_req_total_size),
        .window_offset      (active_offset_w),
        .row_data_in        (data_rd_row_w),
        .valid_bits_in      (valid_rd_bits_w),
        .write_data_in      (mapped_req_wdata_w),
        .write_strb_in      (mapped_req_wstrb_w),
        .in_window          (mapped_in_window_w),
        .offset_aligned     (offset_aligned_w),
        .mapped_way_legal   (mapped_way_legal_w),
        .local_addr         (),
        .direct_set         (mapped_set_w),
        .direct_way         (mapped_way_w),
        .line_valid_out     (),
        .read_line_out      (mapped_read_line_w),
        .write_line_out     (mapped_write_line_w),
        .next_valid_bit_out (mapped_next_valid_bit_w)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            direct_wait_rd_r <= 1'b0;
            direct_write_r <= 1'b0;
            direct_addr_r <= {ADDR_BITS{1'b0}};
            direct_id_r <= {ID_BITS{1'b0}};
            direct_wdata_r <= {LINE_BITS{1'b0}};
            direct_wstrb_r <= {LINE_BYTES{1'b0}};
            direct_set_r <= {SET_BITS{1'b0}};
            resp_pending_r <= 1'b0;
            resp_data_r <= {LINE_BITS{1'b0}};
            resp_id_r <= {ID_BITS{1'b0}};
            bypass_pending_r <= 1'b0;
            bypass_issued_r <= 1'b0;
            bypass_req_write_r <= 1'b0;
            bypass_req_addr_r <= {ADDR_BITS{1'b0}};
            bypass_req_id_r <= {ID_BITS{1'b0}};
            bypass_req_size_r <= 8'd0;
            bypass_req_wdata_r <= {LINE_BITS{1'b0}};
            bypass_req_wstrb_r <= {LINE_BYTES{1'b0}};
        end else begin
            if (resp_pending_r && up_resp_ready) begin
                resp_pending_r <= 1'b0;
            end

            if (direct_accept_w) begin
                direct_wait_rd_r <= 1'b1;
                direct_write_r <= up_req_write;
                direct_addr_r <= up_req_addr;
                direct_id_r <= up_req_id;
                direct_wdata_r <= up_req_wdata;
                direct_wstrb_r <= up_req_wstrb;
                direct_set_r <= mapped_set_w;
            end

            if (direct_wait_rd_r && data_rd_valid_w) begin
                direct_wait_rd_r <= 1'b0;
                resp_pending_r <= 1'b1;
                resp_id_r <= direct_id_r;
                if (direct_write_r) begin
                    resp_data_r <= {LINE_BITS{1'b0}};
                end else begin
                    resp_data_r <= mapped_read_line_w;
                end
            end

            if (bypass_accept_w) begin
                bypass_pending_r <= 1'b1;
                bypass_issued_r <= 1'b0;
                bypass_req_write_r <= up_req_write;
                bypass_req_addr_r <= up_req_addr;
                bypass_req_id_r <= up_req_id;
                bypass_req_size_r <= up_req_total_size;
                bypass_req_wdata_r <= up_req_wdata;
                bypass_req_wstrb_r <= up_req_wstrb;
            end

            if (bypass_req_valid && bypass_req_ready) begin
                bypass_issued_r <= 1'b1;
            end

            if (bypass_resp_valid && bypass_resp_ready) begin
                bypass_pending_r <= 1'b0;
                bypass_issued_r <= 1'b0;
                resp_pending_r <= 1'b1;
                resp_data_r <= bypass_resp_rdata;
                resp_id_r <= bypass_req_id_r;
            end
        end
    end

endmodule
