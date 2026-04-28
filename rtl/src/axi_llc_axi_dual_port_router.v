`timescale 1ns / 1ps
`include "axi_llc_params.vh"

// Route the existing single AXI4 lower-memory master to dedicated DDR and
// MMIO AXI4 master ports. This is intentionally kept as a narrow shim so the
// legacy single-port subsystem remains testable while the new external ABI is
// brought up.
module axi_llc_axi_dual_port_router #(
    parameter ADDR_BITS       = `AXI_LLC_ADDR_BITS,
    parameter AXI_ID_BITS     = `AXI_LLC_AXI_ID_BITS,
    parameter AXI_DATA_BITS   = `AXI_LLC_AXI_DATA_BITS,
    parameter AXI_STRB_BITS   = `AXI_LLC_AXI_STRB_BITS,
    parameter DDR_BASE        = 32'h4000_0000,
    parameter MMIO_AXI_SIZE   = 3'd2,
    parameter WRITE_ROUTE_DEPTH = `AXI_LLC_MAX_WRITE_OUTSTANDING
) (
    input                           clk,
    input                           rst_n,

    // Single AXI4 master port from the existing LLC AXI bridge.
    input                           s_axi_awvalid,
    output                          s_axi_awready,
    input      [AXI_ID_BITS-1:0]    s_axi_awid,
    input      [ADDR_BITS-1:0]      s_axi_awaddr,
    input      [7:0]                s_axi_awlen,
    input      [2:0]                s_axi_awsize,
    input      [1:0]                s_axi_awburst,
    input                           s_axi_wvalid,
    output                          s_axi_wready,
    input      [AXI_DATA_BITS-1:0]  s_axi_wdata,
    input      [AXI_STRB_BITS-1:0]  s_axi_wstrb,
    input                           s_axi_wlast,
    output                          s_axi_bvalid,
    input                           s_axi_bready,
    output     [AXI_ID_BITS-1:0]    s_axi_bid,
    output     [1:0]                s_axi_bresp,
    input                           s_axi_arvalid,
    output                          s_axi_arready,
    input      [AXI_ID_BITS-1:0]    s_axi_arid,
    input      [ADDR_BITS-1:0]      s_axi_araddr,
    input      [7:0]                s_axi_arlen,
    input      [2:0]                s_axi_arsize,
    input      [1:0]                s_axi_arburst,
    output                          s_axi_rvalid,
    input                           s_axi_rready,
    output     [AXI_ID_BITS-1:0]    s_axi_rid,
    output     [AXI_DATA_BITS-1:0]  s_axi_rdata,
    output     [1:0]                s_axi_rresp,
    output                          s_axi_rlast,

    // DDR/SDRAM AXI4 master port. Transactions keep the bridge's 256-bit
    // beat shape and may be multi-beat.
    output                          ddr_axi_awvalid,
    input                           ddr_axi_awready,
    output     [AXI_ID_BITS-1:0]    ddr_axi_awid,
    output     [ADDR_BITS-1:0]      ddr_axi_awaddr,
    output     [7:0]                ddr_axi_awlen,
    output     [2:0]                ddr_axi_awsize,
    output     [1:0]                ddr_axi_awburst,
    output                          ddr_axi_wvalid,
    input                           ddr_axi_wready,
    output     [AXI_DATA_BITS-1:0]  ddr_axi_wdata,
    output     [AXI_STRB_BITS-1:0]  ddr_axi_wstrb,
    output                          ddr_axi_wlast,
    input                           ddr_axi_bvalid,
    output                          ddr_axi_bready,
    input      [AXI_ID_BITS-1:0]    ddr_axi_bid,
    input      [1:0]                ddr_axi_bresp,
    output                          ddr_axi_arvalid,
    input                           ddr_axi_arready,
    output     [AXI_ID_BITS-1:0]    ddr_axi_arid,
    output     [ADDR_BITS-1:0]      ddr_axi_araddr,
    output     [7:0]                ddr_axi_arlen,
    output     [2:0]                ddr_axi_arsize,
    output     [1:0]                ddr_axi_arburst,
    input                           ddr_axi_rvalid,
    output                          ddr_axi_rready,
    input      [AXI_ID_BITS-1:0]    ddr_axi_rid,
    input      [AXI_DATA_BITS-1:0]  ddr_axi_rdata,
    input      [1:0]                ddr_axi_rresp,
    input                           ddr_axi_rlast,

    // MMIO AXI4 master port. The router only accepts single-beat requests and
    // rewrites them to 32-bit beats.
    output                          mmio_axi_awvalid,
    input                           mmio_axi_awready,
    output     [AXI_ID_BITS-1:0]    mmio_axi_awid,
    output     [ADDR_BITS-1:0]      mmio_axi_awaddr,
    output     [7:0]                mmio_axi_awlen,
    output     [2:0]                mmio_axi_awsize,
    output     [1:0]                mmio_axi_awburst,
    output                          mmio_axi_wvalid,
    input                           mmio_axi_wready,
    output     [AXI_DATA_BITS-1:0]  mmio_axi_wdata,
    output     [AXI_STRB_BITS-1:0]  mmio_axi_wstrb,
    output                          mmio_axi_wlast,
    input                           mmio_axi_bvalid,
    output                          mmio_axi_bready,
    input      [AXI_ID_BITS-1:0]    mmio_axi_bid,
    input      [1:0]                mmio_axi_bresp,
    output                          mmio_axi_arvalid,
    input                           mmio_axi_arready,
    output     [AXI_ID_BITS-1:0]    mmio_axi_arid,
    output     [ADDR_BITS-1:0]      mmio_axi_araddr,
    output     [7:0]                mmio_axi_arlen,
    output     [2:0]                mmio_axi_arsize,
    output     [1:0]                mmio_axi_arburst,
    input                           mmio_axi_rvalid,
    output                          mmio_axi_rready,
    input      [AXI_ID_BITS-1:0]    mmio_axi_rid,
    input      [AXI_DATA_BITS-1:0]  mmio_axi_rdata,
    input      [1:0]                mmio_axi_rresp,
    input                           mmio_axi_rlast
);

    localparam [1:0] AXI_BURST_INCR = 2'b01;
    localparam integer AXI_ID_COUNT = (1 << AXI_ID_BITS);
    localparam integer MMIO_STRB_BYTES = (1 << MMIO_AXI_SIZE);
    localparam [7:0] WRITE_ROUTE_DEPTH_U8 = WRITE_ROUTE_DEPTH;

    reg                           rd_route_valid_r [0:AXI_ID_COUNT-1];
    reg                           rd_route_mmio_r [0:AXI_ID_COUNT-1];
    reg                           wr_resp_route_valid_r [0:AXI_ID_COUNT-1];
    reg                           wr_resp_route_mmio_r [0:AXI_ID_COUNT-1];

    reg                           wr_data_route_mmio_r [0:WRITE_ROUTE_DEPTH-1];
    reg [7:0]                     wr_data_route_head_r;
    reg [7:0]                     wr_data_route_tail_r;
    reg [7:0]                     wr_data_route_count_r;

    wire                          ar_to_mmio_w;
    wire                          aw_to_mmio_w;
    wire                          ar_supported_w;
    wire                          aw_supported_w;
    wire                          wr_data_route_full_w;
    wire                          aw_fire_w;
    wire                          ar_fire_w;
    wire                          w_route_from_fifo_w;
    wire                          w_route_from_aw_w;
    wire                          w_route_valid_w;
    wire                          w_route_mmio_w;
    wire                          w_fire_w;
    wire                          r_select_mmio_w;
    wire                          r_select_ddr_w;
    wire                          r_fire_w;
    wire [AXI_ID_BITS-1:0]        r_fire_id_w;
    wire                          b_select_mmio_w;
    wire                          b_select_ddr_w;
    wire                          b_fire_w;
    wire [AXI_ID_BITS-1:0]        b_fire_id_w;

    integer                       idx;

    function is_mmio_addr;
        input [ADDR_BITS-1:0] addr_value;
        begin
            is_mmio_addr = (addr_value < DDR_BASE[ADDR_BITS-1:0]);
        end
    endfunction

    function [AXI_STRB_BITS-1:0] mask_mmio_strb;
        input [AXI_STRB_BITS-1:0] in_strb;
        integer byte_idx;
        begin
            mask_mmio_strb = {AXI_STRB_BITS{1'b0}};
            for (byte_idx = 0; byte_idx < AXI_STRB_BITS; byte_idx = byte_idx + 1) begin
                if (byte_idx < MMIO_STRB_BYTES) begin
                    mask_mmio_strb[byte_idx] = in_strb[byte_idx];
                end
            end
        end
    endfunction

    assign ar_to_mmio_w = is_mmio_addr(s_axi_araddr);
    assign aw_to_mmio_w = is_mmio_addr(s_axi_awaddr);
    assign ar_supported_w = (!ar_to_mmio_w) || (s_axi_arlen == 8'd0);
    assign aw_supported_w = (!aw_to_mmio_w) || (s_axi_awlen == 8'd0);
    assign wr_data_route_full_w =
        (wr_data_route_count_r == WRITE_ROUTE_DEPTH_U8);

    assign s_axi_arready = ar_supported_w &&
                           (ar_to_mmio_w ? mmio_axi_arready : ddr_axi_arready);
    assign ddr_axi_arvalid = s_axi_arvalid && ar_supported_w && !ar_to_mmio_w;
    assign ddr_axi_arid = s_axi_arid;
    assign ddr_axi_araddr = s_axi_araddr;
    assign ddr_axi_arlen = s_axi_arlen;
    assign ddr_axi_arsize = s_axi_arsize;
    assign ddr_axi_arburst = s_axi_arburst;
    assign mmio_axi_arvalid = s_axi_arvalid && ar_supported_w && ar_to_mmio_w;
    assign mmio_axi_arid = s_axi_arid;
    assign mmio_axi_araddr = s_axi_araddr;
    assign mmio_axi_arlen = 8'd0;
    assign mmio_axi_arsize = MMIO_AXI_SIZE;
    assign mmio_axi_arburst = AXI_BURST_INCR;
    assign ar_fire_w = s_axi_arvalid && s_axi_arready;

    assign s_axi_awready = aw_supported_w && !wr_data_route_full_w &&
                           (aw_to_mmio_w ? mmio_axi_awready : ddr_axi_awready);
    assign ddr_axi_awvalid = s_axi_awvalid && aw_supported_w &&
                             !wr_data_route_full_w && !aw_to_mmio_w;
    assign ddr_axi_awid = s_axi_awid;
    assign ddr_axi_awaddr = s_axi_awaddr;
    assign ddr_axi_awlen = s_axi_awlen;
    assign ddr_axi_awsize = s_axi_awsize;
    assign ddr_axi_awburst = s_axi_awburst;
    assign mmio_axi_awvalid = s_axi_awvalid && aw_supported_w &&
                              !wr_data_route_full_w && aw_to_mmio_w;
    assign mmio_axi_awid = s_axi_awid;
    assign mmio_axi_awaddr = s_axi_awaddr;
    assign mmio_axi_awlen = 8'd0;
    assign mmio_axi_awsize = MMIO_AXI_SIZE;
    assign mmio_axi_awburst = AXI_BURST_INCR;
    assign aw_fire_w = s_axi_awvalid && s_axi_awready;

    assign w_route_from_fifo_w = (wr_data_route_count_r != 8'd0);
    assign w_route_from_aw_w = (!w_route_from_fifo_w) && aw_fire_w;
    assign w_route_valid_w = w_route_from_fifo_w || w_route_from_aw_w;
    assign w_route_mmio_w = w_route_from_fifo_w ?
                            wr_data_route_mmio_r[wr_data_route_head_r] :
                            aw_to_mmio_w;
    assign s_axi_wready = w_route_valid_w &&
                          (w_route_mmio_w ? mmio_axi_wready : ddr_axi_wready);
    assign ddr_axi_wvalid = s_axi_wvalid && w_route_valid_w && !w_route_mmio_w;
    assign ddr_axi_wdata = s_axi_wdata;
    assign ddr_axi_wstrb = s_axi_wstrb;
    assign ddr_axi_wlast = s_axi_wlast;
    assign mmio_axi_wvalid = s_axi_wvalid && w_route_valid_w && w_route_mmio_w;
    assign mmio_axi_wdata = s_axi_wdata;
    assign mmio_axi_wstrb = mask_mmio_strb(s_axi_wstrb);
    assign mmio_axi_wlast = 1'b1;
    assign w_fire_w = s_axi_wvalid && s_axi_wready;

    assign r_select_mmio_w =
        mmio_axi_rvalid &&
        rd_route_valid_r[mmio_axi_rid] &&
        rd_route_mmio_r[mmio_axi_rid];
    assign r_select_ddr_w =
        (!r_select_mmio_w) &&
        ddr_axi_rvalid &&
        rd_route_valid_r[ddr_axi_rid] &&
        !rd_route_mmio_r[ddr_axi_rid];
    assign s_axi_rvalid = r_select_mmio_w ? mmio_axi_rvalid :
                          (r_select_ddr_w ? ddr_axi_rvalid : 1'b0);
    assign s_axi_rid = r_select_mmio_w ? mmio_axi_rid : ddr_axi_rid;
    assign s_axi_rdata = r_select_mmio_w ? mmio_axi_rdata : ddr_axi_rdata;
    assign s_axi_rresp = r_select_mmio_w ? mmio_axi_rresp : ddr_axi_rresp;
    assign s_axi_rlast = r_select_mmio_w ? mmio_axi_rlast : ddr_axi_rlast;
    assign mmio_axi_rready = r_select_mmio_w && s_axi_rready;
    assign ddr_axi_rready = r_select_ddr_w && s_axi_rready;
    assign r_fire_w = s_axi_rvalid && s_axi_rready;
    assign r_fire_id_w = r_select_mmio_w ? mmio_axi_rid : ddr_axi_rid;

    assign b_select_mmio_w =
        mmio_axi_bvalid &&
        wr_resp_route_valid_r[mmio_axi_bid] &&
        wr_resp_route_mmio_r[mmio_axi_bid];
    assign b_select_ddr_w =
        (!b_select_mmio_w) &&
        ddr_axi_bvalid &&
        wr_resp_route_valid_r[ddr_axi_bid] &&
        !wr_resp_route_mmio_r[ddr_axi_bid];
    assign s_axi_bvalid = b_select_mmio_w ? mmio_axi_bvalid :
                          (b_select_ddr_w ? ddr_axi_bvalid : 1'b0);
    assign s_axi_bid = b_select_mmio_w ? mmio_axi_bid : ddr_axi_bid;
    assign s_axi_bresp = b_select_mmio_w ? mmio_axi_bresp : ddr_axi_bresp;
    assign mmio_axi_bready = b_select_mmio_w && s_axi_bready;
    assign ddr_axi_bready = b_select_ddr_w && s_axi_bready;
    assign b_fire_w = s_axi_bvalid && s_axi_bready;
    assign b_fire_id_w = b_select_mmio_w ? mmio_axi_bid : ddr_axi_bid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (idx = 0; idx < AXI_ID_COUNT; idx = idx + 1) begin
                rd_route_valid_r[idx] <= 1'b0;
                rd_route_mmio_r[idx] <= 1'b0;
                wr_resp_route_valid_r[idx] <= 1'b0;
                wr_resp_route_mmio_r[idx] <= 1'b0;
            end
            for (idx = 0; idx < WRITE_ROUTE_DEPTH; idx = idx + 1) begin
                wr_data_route_mmio_r[idx] <= 1'b0;
            end
            wr_data_route_head_r <= 8'd0;
            wr_data_route_tail_r <= 8'd0;
            wr_data_route_count_r <= 8'd0;
        end else begin
            if (ar_fire_w) begin
                rd_route_valid_r[s_axi_arid] <= 1'b1;
                rd_route_mmio_r[s_axi_arid] <= ar_to_mmio_w;
            end
            if (r_fire_w && s_axi_rlast) begin
                rd_route_valid_r[r_fire_id_w] <= 1'b0;
                rd_route_mmio_r[r_fire_id_w] <= 1'b0;
            end

            if (aw_fire_w) begin
                wr_resp_route_valid_r[s_axi_awid] <= 1'b1;
                wr_resp_route_mmio_r[s_axi_awid] <= aw_to_mmio_w;
            end
            if (b_fire_w) begin
                wr_resp_route_valid_r[b_fire_id_w] <= 1'b0;
                wr_resp_route_mmio_r[b_fire_id_w] <= 1'b0;
            end

            if (wr_data_route_count_r == 8'd0) begin
                if (aw_fire_w) begin
                    if (!(w_fire_w && s_axi_wlast)) begin
                        wr_data_route_mmio_r[wr_data_route_tail_r] <= aw_to_mmio_w;
                        if (wr_data_route_tail_r == WRITE_ROUTE_DEPTH_U8 - 8'd1) begin
                            wr_data_route_tail_r <= 8'd0;
                        end else begin
                            wr_data_route_tail_r <= wr_data_route_tail_r + 8'd1;
                        end
                        wr_data_route_count_r <= 8'd1;
                    end
                end
            end else begin
                if (w_fire_w && s_axi_wlast) begin
                    if (wr_data_route_head_r == WRITE_ROUTE_DEPTH_U8 - 8'd1) begin
                        wr_data_route_head_r <= 8'd0;
                    end else begin
                        wr_data_route_head_r <= wr_data_route_head_r + 8'd1;
                    end
                end
                if (aw_fire_w) begin
                    wr_data_route_mmio_r[wr_data_route_tail_r] <= aw_to_mmio_w;
                    if (wr_data_route_tail_r == WRITE_ROUTE_DEPTH_U8 - 8'd1) begin
                        wr_data_route_tail_r <= 8'd0;
                    end else begin
                        wr_data_route_tail_r <= wr_data_route_tail_r + 8'd1;
                    end
                end
                if ((w_fire_w && s_axi_wlast) && !aw_fire_w) begin
                    wr_data_route_count_r <= wr_data_route_count_r - 8'd1;
                end else if (!(w_fire_w && s_axi_wlast) && aw_fire_w) begin
                    wr_data_route_count_r <= wr_data_route_count_r + 8'd1;
                end
            end
        end
    end

endmodule
