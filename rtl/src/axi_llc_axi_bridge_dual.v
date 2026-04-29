`timescale 1ns / 1ps
`include "axi_llc_params.vh"

// Native dual-port lower-memory bridge.
//
// This wrapper routes lower cache/bypass requests before AXI channel
// generation, so DDR and MMIO traffic do not collapse into a single AXI
// address channel. It reuses the proven single-port bridge twice:
//   - DDR bridge: 256-bit AXI beats, multi-beat cache-line support.
//   - MMIO bridge: 32-bit AXI beats, single-beat 32-bit requests only.
//
// Current scope:
//   - Address route: addr >= DDR_BASE -> DDR, otherwise MMIO.
//   - MMIO accepts only total_size == 3 (4 bytes).
//   - Response muxes are per source and backpressure the non-selected port.
//   - Shared global 32-entry outstanding accounting is still a TODO; the
//     underlying bridges currently retain their existing per-port limits.
module axi_llc_axi_bridge_dual #(
    parameter ADDR_BITS           = `AXI_LLC_ADDR_BITS,
    parameter ID_BITS             = `AXI_LLC_SLOT_ID_BITS,
    parameter LINE_BYTES          = `AXI_LLC_LINE_BYTES,
    parameter LINE_BITS           = `AXI_LLC_LINE_BITS,
    parameter DDR_AXI_ID_BITS     = `AXI_LLC_AXI_ID_BITS,
    parameter DDR_AXI_DATA_BYTES  = `AXI_LLC_AXI_DATA_BYTES,
    parameter DDR_AXI_DATA_BITS   = `AXI_LLC_AXI_DATA_BITS,
    parameter DDR_AXI_STRB_BITS   = `AXI_LLC_AXI_STRB_BITS,
    parameter MMIO_AXI_ID_BITS    = `AXI_LLC_AXI_ID_BITS,
    parameter MMIO_AXI_DATA_BYTES = 4,
    parameter MMIO_AXI_DATA_BITS  = 32,
    parameter MMIO_AXI_STRB_BITS  = 4,
    parameter READ_RESP_BYTES     = `AXI_LLC_READ_RESP_BYTES,
    parameter READ_RESP_BITS      = `AXI_LLC_READ_RESP_BITS,
    parameter DDR_BASE            = 32'h4000_0000
) (
    input                            clk,
    input                            rst_n,

    input                            cache_req_valid,
    output                           cache_req_ready,
    input                            cache_req_write,
    input      [ADDR_BITS-1:0]       cache_req_addr,
    input      [ID_BITS-1:0]         cache_req_id,
    input      [7:0]                 cache_req_size,
    input      [LINE_BITS-1:0]       cache_req_wdata,
    input      [LINE_BYTES-1:0]      cache_req_wstrb,
    output                           cache_resp_valid,
    input                            cache_resp_ready,
    output     [READ_RESP_BITS-1:0]  cache_resp_rdata,
    output     [ID_BITS-1:0]         cache_resp_id,
    output     [1:0]                 cache_resp_code,

    input                            bypass_req_valid,
    output                           bypass_req_ready,
    input                            bypass_req_write,
    input      [ADDR_BITS-1:0]       bypass_req_addr,
    input      [ID_BITS-1:0]         bypass_req_id,
    input      [7:0]                 bypass_req_size,
    input                            bypass_req_mode2_ddr_aligned,
    input      [LINE_BITS-1:0]       bypass_req_wdata,
    input      [LINE_BYTES-1:0]      bypass_req_wstrb,
    output                           bypass_resp_valid,
    input                            bypass_resp_ready,
    output     [READ_RESP_BITS-1:0]  bypass_resp_rdata,
    output     [ID_BITS-1:0]         bypass_resp_id,
    output     [1:0]                 bypass_resp_code,

    output                           ddr_axi_awvalid,
    input                            ddr_axi_awready,
    output     [DDR_AXI_ID_BITS-1:0] ddr_axi_awid,
    output     [ADDR_BITS-1:0]       ddr_axi_awaddr,
    output     [7:0]                 ddr_axi_awlen,
    output     [2:0]                 ddr_axi_awsize,
    output     [1:0]                 ddr_axi_awburst,
    output                           ddr_axi_wvalid,
    input                            ddr_axi_wready,
    output     [DDR_AXI_DATA_BITS-1:0] ddr_axi_wdata,
    output     [DDR_AXI_STRB_BITS-1:0] ddr_axi_wstrb,
    output                           ddr_axi_wlast,
    input                            ddr_axi_bvalid,
    output                           ddr_axi_bready,
    input      [DDR_AXI_ID_BITS-1:0] ddr_axi_bid,
    input      [1:0]                 ddr_axi_bresp,
    output                           ddr_axi_arvalid,
    input                            ddr_axi_arready,
    output     [DDR_AXI_ID_BITS-1:0] ddr_axi_arid,
    output     [ADDR_BITS-1:0]       ddr_axi_araddr,
    output     [7:0]                 ddr_axi_arlen,
    output     [2:0]                 ddr_axi_arsize,
    output     [1:0]                 ddr_axi_arburst,
    input                            ddr_axi_rvalid,
    output                           ddr_axi_rready,
    input      [DDR_AXI_ID_BITS-1:0] ddr_axi_rid,
    input      [DDR_AXI_DATA_BITS-1:0] ddr_axi_rdata,
    input      [1:0]                 ddr_axi_rresp,
    input                            ddr_axi_rlast,

    output                           mmio_axi_awvalid,
    input                            mmio_axi_awready,
    output     [MMIO_AXI_ID_BITS-1:0] mmio_axi_awid,
    output     [ADDR_BITS-1:0]       mmio_axi_awaddr,
    output     [7:0]                 mmio_axi_awlen,
    output     [2:0]                 mmio_axi_awsize,
    output     [1:0]                 mmio_axi_awburst,
    output                           mmio_axi_wvalid,
    input                            mmio_axi_wready,
    output     [MMIO_AXI_DATA_BITS-1:0] mmio_axi_wdata,
    output     [MMIO_AXI_STRB_BITS-1:0] mmio_axi_wstrb,
    output                           mmio_axi_wlast,
    input                            mmio_axi_bvalid,
    output                           mmio_axi_bready,
    input      [MMIO_AXI_ID_BITS-1:0] mmio_axi_bid,
    input      [1:0]                 mmio_axi_bresp,
    output                           mmio_axi_arvalid,
    input                            mmio_axi_arready,
    output     [MMIO_AXI_ID_BITS-1:0] mmio_axi_arid,
    output     [ADDR_BITS-1:0]       mmio_axi_araddr,
    output     [7:0]                 mmio_axi_arlen,
    output     [2:0]                 mmio_axi_arsize,
    output     [1:0]                 mmio_axi_arburst,
    input                            mmio_axi_rvalid,
    output                           mmio_axi_rready,
    input      [MMIO_AXI_ID_BITS-1:0] mmio_axi_rid,
    input      [MMIO_AXI_DATA_BITS-1:0] mmio_axi_rdata,
    input      [1:0]                 mmio_axi_rresp,
    input                            mmio_axi_rlast
);

    wire cache_to_mmio_w;
    wire bypass_to_mmio_w;
    wire cache_mmio_supported_w;
    wire bypass_mmio_supported_w;

    wire ddr_cache_req_valid_w;
    wire ddr_cache_req_ready_w;
    wire ddr_cache_resp_valid_w;
    wire ddr_cache_resp_ready_w;
    wire [READ_RESP_BITS-1:0] ddr_cache_resp_rdata_w;
    wire [ID_BITS-1:0]        ddr_cache_resp_id_w;
    wire [1:0]                ddr_cache_resp_code_w;
    wire ddr_bypass_req_valid_w;
    wire ddr_bypass_req_ready_w;
    wire ddr_bypass_resp_valid_w;
    wire ddr_bypass_resp_ready_w;
    wire [READ_RESP_BITS-1:0] ddr_bypass_resp_rdata_w;
    wire [ID_BITS-1:0]        ddr_bypass_resp_id_w;
    wire [1:0]                ddr_bypass_resp_code_w;

    wire mmio_cache_req_valid_w;
    wire mmio_cache_req_ready_w;
    wire mmio_cache_resp_valid_w;
    wire mmio_cache_resp_ready_w;
    wire [READ_RESP_BITS-1:0] mmio_cache_resp_rdata_w;
    wire [ID_BITS-1:0]        mmio_cache_resp_id_w;
    wire [1:0]                mmio_cache_resp_code_w;
    wire mmio_bypass_req_valid_w;
    wire mmio_bypass_req_ready_w;
    wire mmio_bypass_resp_valid_w;
    wire mmio_bypass_resp_ready_w;
    wire [READ_RESP_BITS-1:0] mmio_bypass_resp_rdata_w;
    wire [ID_BITS-1:0]        mmio_bypass_resp_id_w;
    wire [1:0]                mmio_bypass_resp_code_w;

    wire cache_resp_select_mmio_w;
    wire bypass_resp_select_mmio_w;

    function is_mmio_addr;
        input [ADDR_BITS-1:0] addr_value;
        begin
            is_mmio_addr = (addr_value < DDR_BASE[ADDR_BITS-1:0]);
        end
    endfunction

    assign cache_to_mmio_w = is_mmio_addr(cache_req_addr);
    assign bypass_to_mmio_w = is_mmio_addr(bypass_req_addr);
    assign cache_mmio_supported_w = (!cache_to_mmio_w) || (cache_req_size == 8'd3);
    assign bypass_mmio_supported_w = (!bypass_to_mmio_w) || (bypass_req_size == 8'd3);

    assign ddr_cache_req_valid_w =
        cache_req_valid && !cache_to_mmio_w;
    assign mmio_cache_req_valid_w =
        cache_req_valid && cache_to_mmio_w && cache_mmio_supported_w;
    assign cache_req_ready =
        cache_to_mmio_w ?
            (cache_mmio_supported_w && mmio_cache_req_ready_w) :
            ddr_cache_req_ready_w;

    assign ddr_bypass_req_valid_w =
        bypass_req_valid && !bypass_to_mmio_w;
    assign mmio_bypass_req_valid_w =
        bypass_req_valid && bypass_to_mmio_w && bypass_mmio_supported_w;
    assign bypass_req_ready =
        bypass_to_mmio_w ?
            (bypass_mmio_supported_w && mmio_bypass_req_ready_w) :
            ddr_bypass_req_ready_w;

    assign cache_resp_select_mmio_w = mmio_cache_resp_valid_w;
    assign cache_resp_valid = cache_resp_select_mmio_w ?
                              mmio_cache_resp_valid_w :
                              ddr_cache_resp_valid_w;
    assign cache_resp_rdata = cache_resp_select_mmio_w ?
                              mmio_cache_resp_rdata_w :
                              ddr_cache_resp_rdata_w;
    assign cache_resp_id = cache_resp_select_mmio_w ?
                           mmio_cache_resp_id_w :
                           ddr_cache_resp_id_w;
    assign cache_resp_code = cache_resp_select_mmio_w ?
                             mmio_cache_resp_code_w :
                             ddr_cache_resp_code_w;
    assign mmio_cache_resp_ready_w = cache_resp_select_mmio_w && cache_resp_ready;
    assign ddr_cache_resp_ready_w = (!cache_resp_select_mmio_w) && cache_resp_ready;

    assign bypass_resp_select_mmio_w = mmio_bypass_resp_valid_w;
    assign bypass_resp_valid = bypass_resp_select_mmio_w ?
                               mmio_bypass_resp_valid_w :
                               ddr_bypass_resp_valid_w;
    assign bypass_resp_rdata = bypass_resp_select_mmio_w ?
                               mmio_bypass_resp_rdata_w :
                               ddr_bypass_resp_rdata_w;
    assign bypass_resp_id = bypass_resp_select_mmio_w ?
                            mmio_bypass_resp_id_w :
                            ddr_bypass_resp_id_w;
    assign bypass_resp_code = bypass_resp_select_mmio_w ?
                              mmio_bypass_resp_code_w :
                              ddr_bypass_resp_code_w;
    assign mmio_bypass_resp_ready_w =
        bypass_resp_select_mmio_w && bypass_resp_ready;
    assign ddr_bypass_resp_ready_w =
        (!bypass_resp_select_mmio_w) && bypass_resp_ready;

    axi_llc_axi_bridge #(
        .ADDR_BITS(ADDR_BITS),
        .ID_BITS(ID_BITS),
        .LINE_BYTES(LINE_BYTES),
        .LINE_BITS(LINE_BITS),
        .AXI_ID_BITS(DDR_AXI_ID_BITS),
        .AXI_DATA_BYTES(DDR_AXI_DATA_BYTES),
        .AXI_DATA_BITS(DDR_AXI_DATA_BITS),
        .AXI_STRB_BITS(DDR_AXI_STRB_BITS),
        .READ_RESP_BYTES(READ_RESP_BYTES),
        .READ_RESP_BITS(READ_RESP_BITS)
    ) ddr_bridge (
        .clk(clk),
        .rst_n(rst_n),
        .cache_req_valid(ddr_cache_req_valid_w),
        .cache_req_ready(ddr_cache_req_ready_w),
        .cache_req_write(cache_req_write),
        .cache_req_addr(cache_req_addr),
        .cache_req_id(cache_req_id),
        .cache_req_size(cache_req_size),
        .cache_req_wdata(cache_req_wdata),
        .cache_req_wstrb(cache_req_wstrb),
        .cache_resp_valid(ddr_cache_resp_valid_w),
        .cache_resp_ready(ddr_cache_resp_ready_w),
        .cache_resp_rdata(ddr_cache_resp_rdata_w),
        .cache_resp_id(ddr_cache_resp_id_w),
        .cache_resp_code(ddr_cache_resp_code_w),
        .bypass_req_valid(ddr_bypass_req_valid_w),
        .bypass_req_ready(ddr_bypass_req_ready_w),
        .bypass_req_write(bypass_req_write),
        .bypass_req_addr(bypass_req_addr),
        .bypass_req_id(bypass_req_id),
        .bypass_req_size(bypass_req_size),
        .bypass_req_mode2_ddr_aligned(bypass_req_mode2_ddr_aligned),
        .bypass_req_wdata(bypass_req_wdata),
        .bypass_req_wstrb(bypass_req_wstrb),
        .bypass_resp_valid(ddr_bypass_resp_valid_w),
        .bypass_resp_ready(ddr_bypass_resp_ready_w),
        .bypass_resp_rdata(ddr_bypass_resp_rdata_w),
        .bypass_resp_id(ddr_bypass_resp_id_w),
        .bypass_resp_code(ddr_bypass_resp_code_w),
        .axi_awvalid(ddr_axi_awvalid),
        .axi_awready(ddr_axi_awready),
        .axi_awid(ddr_axi_awid),
        .axi_awaddr(ddr_axi_awaddr),
        .axi_awlen(ddr_axi_awlen),
        .axi_awsize(ddr_axi_awsize),
        .axi_awburst(ddr_axi_awburst),
        .axi_wvalid(ddr_axi_wvalid),
        .axi_wready(ddr_axi_wready),
        .axi_wdata(ddr_axi_wdata),
        .axi_wstrb(ddr_axi_wstrb),
        .axi_wlast(ddr_axi_wlast),
        .axi_bvalid(ddr_axi_bvalid),
        .axi_bready(ddr_axi_bready),
        .axi_bid(ddr_axi_bid),
        .axi_bresp(ddr_axi_bresp),
        .axi_arvalid(ddr_axi_arvalid),
        .axi_arready(ddr_axi_arready),
        .axi_arid(ddr_axi_arid),
        .axi_araddr(ddr_axi_araddr),
        .axi_arlen(ddr_axi_arlen),
        .axi_arsize(ddr_axi_arsize),
        .axi_arburst(ddr_axi_arburst),
        .axi_rvalid(ddr_axi_rvalid),
        .axi_rready(ddr_axi_rready),
        .axi_rid(ddr_axi_rid),
        .axi_rdata(ddr_axi_rdata),
        .axi_rresp(ddr_axi_rresp),
        .axi_rlast(ddr_axi_rlast)
    );

    axi_llc_axi_bridge #(
        .ADDR_BITS(ADDR_BITS),
        .ID_BITS(ID_BITS),
        .LINE_BYTES(LINE_BYTES),
        .LINE_BITS(LINE_BITS),
        .AXI_ID_BITS(MMIO_AXI_ID_BITS),
        .AXI_DATA_BYTES(MMIO_AXI_DATA_BYTES),
        .AXI_DATA_BITS(MMIO_AXI_DATA_BITS),
        .AXI_STRB_BITS(MMIO_AXI_STRB_BITS),
        .READ_RESP_BYTES(READ_RESP_BYTES),
        .READ_RESP_BITS(READ_RESP_BITS)
    ) mmio_bridge (
        .clk(clk),
        .rst_n(rst_n),
        .cache_req_valid(mmio_cache_req_valid_w),
        .cache_req_ready(mmio_cache_req_ready_w),
        .cache_req_write(cache_req_write),
        .cache_req_addr(cache_req_addr),
        .cache_req_id(cache_req_id),
        .cache_req_size(cache_req_size),
        .cache_req_wdata(cache_req_wdata),
        .cache_req_wstrb(cache_req_wstrb),
        .cache_resp_valid(mmio_cache_resp_valid_w),
        .cache_resp_ready(mmio_cache_resp_ready_w),
        .cache_resp_rdata(mmio_cache_resp_rdata_w),
        .cache_resp_id(mmio_cache_resp_id_w),
        .cache_resp_code(mmio_cache_resp_code_w),
        .bypass_req_valid(mmio_bypass_req_valid_w),
        .bypass_req_ready(mmio_bypass_req_ready_w),
        .bypass_req_write(bypass_req_write),
        .bypass_req_addr(bypass_req_addr),
        .bypass_req_id(bypass_req_id),
        .bypass_req_size(bypass_req_size),
        .bypass_req_mode2_ddr_aligned(1'b0),
        .bypass_req_wdata(bypass_req_wdata),
        .bypass_req_wstrb(bypass_req_wstrb),
        .bypass_resp_valid(mmio_bypass_resp_valid_w),
        .bypass_resp_ready(mmio_bypass_resp_ready_w),
        .bypass_resp_rdata(mmio_bypass_resp_rdata_w),
        .bypass_resp_id(mmio_bypass_resp_id_w),
        .bypass_resp_code(mmio_bypass_resp_code_w),
        .axi_awvalid(mmio_axi_awvalid),
        .axi_awready(mmio_axi_awready),
        .axi_awid(mmio_axi_awid),
        .axi_awaddr(mmio_axi_awaddr),
        .axi_awlen(mmio_axi_awlen),
        .axi_awsize(mmio_axi_awsize),
        .axi_awburst(mmio_axi_awburst),
        .axi_wvalid(mmio_axi_wvalid),
        .axi_wready(mmio_axi_wready),
        .axi_wdata(mmio_axi_wdata),
        .axi_wstrb(mmio_axi_wstrb),
        .axi_wlast(mmio_axi_wlast),
        .axi_bvalid(mmio_axi_bvalid),
        .axi_bready(mmio_axi_bready),
        .axi_bid(mmio_axi_bid),
        .axi_bresp(mmio_axi_bresp),
        .axi_arvalid(mmio_axi_arvalid),
        .axi_arready(mmio_axi_arready),
        .axi_arid(mmio_axi_arid),
        .axi_araddr(mmio_axi_araddr),
        .axi_arlen(mmio_axi_arlen),
        .axi_arsize(mmio_axi_arsize),
        .axi_arburst(mmio_axi_arburst),
        .axi_rvalid(mmio_axi_rvalid),
        .axi_rready(mmio_axi_rready),
        .axi_rid(mmio_axi_rid),
        .axi_rdata(mmio_axi_rdata),
        .axi_rresp(mmio_axi_rresp),
        .axi_rlast(mmio_axi_rlast)
    );

endmodule
