`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module axi_llc_subsystem_top #(
    parameter ADDR_BITS        = `AXI_LLC_ADDR_BITS,
    parameter MODE_BITS        = `AXI_LLC_MODE_BITS,
    parameter LINE_BYTES       = `AXI_LLC_LINE_BYTES,
    parameter LINE_BITS        = `AXI_LLC_LINE_BITS,
    parameter LINE_OFFSET_BITS = `AXI_LLC_LINE_OFFSET_BITS,
    parameter SET_COUNT        = `AXI_LLC_SET_COUNT,
    parameter SET_BITS         = `AXI_LLC_SET_BITS,
    parameter WAY_COUNT        = `AXI_LLC_WAY_COUNT,
    parameter WAY_BITS         = `AXI_LLC_WAY_BITS,
    parameter LLC_SIZE_BYTES   = `AXI_LLC_LLC_SIZE_BYTES,
    parameter WINDOW_BYTES     = `AXI_LLC_WINDOW_BYTES,
    parameter WINDOW_WAYS      = `AXI_LLC_WINDOW_WAYS
) (
    input                       clk,
    input                       rst_n,
    input      [MODE_BITS-1:0]  mode_req,
    input      [ADDR_BITS-1:0]  llc_mapped_offset_req,
    input                       up_req_valid,
    output                      up_req_ready,
    input                       up_req_write,
    input      [ADDR_BITS-1:0]  up_req_addr,
    input      [LINE_BITS-1:0]  up_req_wdata,
    input      [LINE_BYTES-1:0] up_req_wstrb,
    input                       up_req_bypass,
    output                      up_resp_valid,
    input                       up_resp_ready,
    output     [LINE_BITS-1:0]  up_resp_rdata,
    output                      cache_req_valid,
    input                       cache_req_ready,
    output                      cache_req_write,
    output     [ADDR_BITS-1:0]  cache_req_addr,
    output     [LINE_BITS-1:0]  cache_req_wdata,
    output     [LINE_BYTES-1:0] cache_req_wstrb,
    input                       cache_resp_valid,
    output                      cache_resp_ready,
    input      [LINE_BITS-1:0]  cache_resp_rdata,
    output                      bypass_req_valid,
    input                       bypass_req_ready,
    output                      bypass_req_write,
    output     [ADDR_BITS-1:0]  bypass_req_addr,
    output     [LINE_BITS-1:0]  bypass_req_wdata,
    output     [LINE_BYTES-1:0] bypass_req_wstrb,
    input                       bypass_resp_valid,
    output                      bypass_resp_ready,
    input      [LINE_BITS-1:0]  bypass_resp_rdata,
    output     [MODE_BITS-1:0]  active_mode,
    output     [ADDR_BITS-1:0]  active_offset,
    output                      reconfig_busy,
    output     [1:0]            reconfig_state,
    output                      config_error
);

    localparam [MODE_BITS-1:0] MODE_CACHE  = 2'b01;
    localparam [MODE_BITS-1:0] MODE_MAPPED = 2'b10;
    localparam [1:0] ROUTE_CACHE  = 2'b01;
    localparam [1:0] ROUTE_BYPASS = 2'b10;

    reg                       resp_pending_r;
    reg [LINE_BITS-1:0]       resp_data_r;
    reg                       ext_pending_r;
    reg                       ext_issued_r;
    reg [1:0]                 ext_route_r;
    reg                       ext_req_write_r;
    reg [ADDR_BITS-1:0]       ext_req_addr_r;
    reg [LINE_BITS-1:0]       ext_req_wdata_r;
    reg [LINE_BYTES-1:0]      ext_req_wstrb_r;

    wire [MODE_BITS-1:0]      active_mode_w;
    wire [ADDR_BITS-1:0]      active_offset_w;
    wire [MODE_BITS-1:0]      target_mode_w;
    wire [ADDR_BITS-1:0]      target_offset_w;
    wire                      reconfig_block_accepts_w;
    wire                      sweep_busy_w;
    wire                      sweep_done_w;
    wire                      sweep_start_w;
    wire                      valid_wr_en_sweep_w;
    wire [SET_BITS-1:0]       valid_wr_set_sweep_w;
    wire [WAY_COUNT-1:0]      valid_wr_mask_sweep_w;
    wire [WAY_COUNT-1:0]      valid_wr_bits_sweep_w;
    wire [WAY_COUNT-1:0]      valid_rd_bits_w;
    wire                      offset_aligned_w;
    wire                      mapped_in_window_w;
    wire                      mapped_way_legal_w;
    wire [SET_BITS-1:0]       mapped_set_w;
    wire [WAY_BITS-1:0]       mapped_way_w;
    wire [LINE_BITS-1:0]      mapped_read_line_w;
    wire [LINE_BITS-1:0]      mapped_merged_line_w;
    wire                      mapped_next_valid_bit_w;
    wire [LINE_BITS-1:0]      data_rd_line_w;
    wire                      cfg_req_legal_w;
    wire [MODE_BITS-1:0]      reconfig_req_mode_w;
    wire [ADDR_BITS-1:0]      reconfig_req_offset_w;
    wire                      route_direct_w;
    wire                      route_cache_w;
    wire                      direct_accept_w;
    wire                      ext_accept_w;
    wire                      global_quiescent_w;
    wire                      direct_valid_wr_en_w;
    wire [SET_BITS-1:0]       direct_valid_wr_set_w;
    wire [WAY_COUNT-1:0]      direct_valid_wr_mask_w;
    wire [WAY_COUNT-1:0]      direct_valid_wr_bits_w;
    wire                      data_wr_en_w;
    wire                      valid_wr_en_w;
    wire [SET_BITS-1:0]       valid_wr_set_w;
    wire [WAY_COUNT-1:0]      valid_wr_mask_w;
    wire [WAY_COUNT-1:0]      valid_wr_bits_w;

    function [WAY_COUNT-1:0] way_onehot;
        input [WAY_BITS-1:0] way_idx;
        integer idx;
        begin
            way_onehot = {WAY_COUNT{1'b0}};
            for (idx = 0; idx < WAY_COUNT; idx = idx + 1) begin
                if (way_idx == idx) begin
                    way_onehot[idx] = 1'b1;
                end
            end
        end
    endfunction

    initial begin
        if (WINDOW_BYTES > LLC_SIZE_BYTES) begin
            $display("ERROR: axi_llc_subsystem_top WINDOW_BYTES exceeds LLC_SIZE_BYTES");
            $finish;
        end

        if ((WINDOW_BYTES % (SET_COUNT * LINE_BYTES)) != 0) begin
            $display("ERROR: axi_llc_subsystem_top WINDOW_BYTES must be an integer way-slice");
            $finish;
        end

        if (WINDOW_WAYS > WAY_COUNT) begin
            $display("ERROR: axi_llc_subsystem_top WINDOW_WAYS exceeds WAY_COUNT");
            $finish;
        end
    end

    assign cfg_req_legal_w = (mode_req != MODE_MAPPED) ||
                             (llc_mapped_offset_req[LINE_OFFSET_BITS-1:0] == {LINE_OFFSET_BITS{1'b0}});
    assign config_error = (mode_req == MODE_MAPPED) && !cfg_req_legal_w;
    assign reconfig_req_mode_w   = cfg_req_legal_w ? mode_req : active_mode_w;
    assign reconfig_req_offset_w = cfg_req_legal_w ? llc_mapped_offset_req : active_offset_w;
    assign active_mode   = active_mode_w;
    assign active_offset = active_offset_w;
    assign reconfig_busy = (reconfig_state != 2'b00);
    assign global_quiescent_w = !ext_pending_r && !resp_pending_r;

    axi_reconfig_ctrl reconfig_ctrl (
        .clk              (clk),
        .rst_n            (rst_n),
        .req_mode         (reconfig_req_mode_w),
        .req_offset       (reconfig_req_offset_w),
        .global_quiescent (global_quiescent_w),
        .sweep_busy       (sweep_busy_w),
        .sweep_done       (sweep_done_w),
        .active_mode      (active_mode_w),
        .active_offset    (active_offset_w),
        .target_mode      (target_mode_w),
        .target_offset    (target_offset_w),
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
        .rd_en   (1'b1),
        .rd_set  (mapped_set_w),
        .rd_bits (valid_rd_bits_w),
        .wr_en   (valid_wr_en_w),
        .wr_set  (valid_wr_set_w),
        .wr_mask (valid_wr_mask_w),
        .wr_bits (valid_wr_bits_w)
    );

    llc_data_ram #(
        .SET_COUNT (SET_COUNT),
        .SET_BITS  (SET_BITS),
        .WAY_COUNT (WAY_COUNT),
        .WAY_BITS  (WAY_BITS),
        .LINE_BITS (LINE_BITS)
    ) data_ram (
        .clk     (clk),
        .rd_en   (1'b1),
        .rd_set  (mapped_set_w),
        .rd_way  (mapped_way_w),
        .rd_line (data_rd_line_w),
        .wr_en   (data_wr_en_w),
        .wr_set  (mapped_set_w),
        .wr_way  (mapped_way_w),
        .wr_line (mapped_merged_line_w)
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
        .req_addr           (up_req_addr),
        .window_offset      (active_offset_w),
        .line_data_in       (data_rd_line_w),
        .line_valid_in      (mapped_way_legal_w ? valid_rd_bits_w[mapped_way_w] : 1'b0),
        .write_data_in      (up_req_wdata),
        .write_strb_in      (up_req_wstrb),
        .in_window          (mapped_in_window_w),
        .offset_aligned     (offset_aligned_w),
        .mapped_way_legal   (mapped_way_legal_w),
        .local_addr         (),
        .direct_set         (mapped_set_w),
        .direct_way         (mapped_way_w),
        .read_line_out      (mapped_read_line_w),
        .merged_line_out    (mapped_merged_line_w),
        .next_valid_bit_out (mapped_next_valid_bit_w)
    );

    assign route_direct_w = (active_mode_w == MODE_MAPPED) &&
                            mapped_in_window_w &&
                            mapped_way_legal_w &&
                            offset_aligned_w;
    assign route_cache_w  = (active_mode_w == MODE_CACHE) && !up_req_bypass;

    assign up_req_ready   = !reconfig_block_accepts_w && !resp_pending_r && !ext_pending_r;
    assign direct_accept_w = up_req_valid && up_req_ready && route_direct_w;
    assign ext_accept_w    = up_req_valid && up_req_ready && !route_direct_w;

    assign direct_valid_wr_en_w   = direct_accept_w && up_req_write;
    assign direct_valid_wr_set_w  = mapped_set_w;
    assign direct_valid_wr_mask_w = way_onehot(mapped_way_w);
    assign direct_valid_wr_bits_w = mapped_next_valid_bit_w ? way_onehot(mapped_way_w)
                                                            : {WAY_COUNT{1'b0}};
    assign data_wr_en_w = direct_accept_w && up_req_write;

    assign valid_wr_en_w   = valid_wr_en_sweep_w | direct_valid_wr_en_w;
    assign valid_wr_set_w  = valid_wr_en_sweep_w ? valid_wr_set_sweep_w  : direct_valid_wr_set_w;
    assign valid_wr_mask_w = valid_wr_en_sweep_w ? valid_wr_mask_sweep_w : direct_valid_wr_mask_w;
    assign valid_wr_bits_w = valid_wr_en_sweep_w ? valid_wr_bits_sweep_w : direct_valid_wr_bits_w;

    assign up_resp_valid = resp_pending_r;
    assign up_resp_rdata = resp_data_r;

    assign cache_req_valid = ext_pending_r && !ext_issued_r && (ext_route_r == ROUTE_CACHE);
    assign cache_req_write = ext_req_write_r;
    assign cache_req_addr  = ext_req_addr_r;
    assign cache_req_wdata = ext_req_wdata_r;
    assign cache_req_wstrb = ext_req_wstrb_r;

    assign bypass_req_valid = ext_pending_r && !ext_issued_r && (ext_route_r == ROUTE_BYPASS);
    assign bypass_req_write = ext_req_write_r;
    assign bypass_req_addr  = ext_req_addr_r;
    assign bypass_req_wdata = ext_req_wdata_r;
    assign bypass_req_wstrb = ext_req_wstrb_r;

    assign cache_resp_ready  = ext_pending_r && ext_issued_r &&
                               (ext_route_r == ROUTE_CACHE) && !resp_pending_r;
    assign bypass_resp_ready = ext_pending_r && ext_issued_r &&
                               (ext_route_r == ROUTE_BYPASS) && !resp_pending_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            resp_pending_r  <= 1'b0;
            resp_data_r     <= {LINE_BITS{1'b0}};
            ext_pending_r   <= 1'b0;
            ext_issued_r    <= 1'b0;
            ext_route_r     <= ROUTE_BYPASS;
            ext_req_write_r <= 1'b0;
            ext_req_addr_r  <= {ADDR_BITS{1'b0}};
            ext_req_wdata_r <= {LINE_BITS{1'b0}};
            ext_req_wstrb_r <= {LINE_BYTES{1'b0}};
        end else begin
            if (resp_pending_r && up_resp_ready) begin
                resp_pending_r <= 1'b0;
            end

            if (direct_accept_w) begin
                resp_pending_r <= 1'b1;
                if (up_req_write) begin
                    resp_data_r <= {LINE_BITS{1'b0}};
                end else begin
                    resp_data_r <= mapped_read_line_w;
                end
            end

            if (ext_accept_w) begin
                ext_pending_r   <= 1'b1;
                ext_issued_r    <= 1'b0;
                ext_route_r     <= route_cache_w ? ROUTE_CACHE : ROUTE_BYPASS;
                ext_req_write_r <= up_req_write;
                ext_req_addr_r  <= up_req_addr;
                ext_req_wdata_r <= up_req_wdata;
                ext_req_wstrb_r <= up_req_wstrb;
            end

            if (cache_req_valid && cache_req_ready) begin
                ext_issued_r <= 1'b1;
            end

            if (bypass_req_valid && bypass_req_ready) begin
                ext_issued_r <= 1'b1;
            end

            if (cache_resp_valid && cache_resp_ready) begin
                ext_pending_r  <= 1'b0;
                ext_issued_r   <= 1'b0;
                resp_pending_r <= 1'b1;
                resp_data_r    <= cache_resp_rdata;
            end

            if (bypass_resp_valid && bypass_resp_ready) begin
                ext_pending_r  <= 1'b0;
                ext_issued_r   <= 1'b0;
                resp_pending_r <= 1'b1;
                resp_data_r    <= bypass_resp_rdata;
            end
        end
    end

endmodule
