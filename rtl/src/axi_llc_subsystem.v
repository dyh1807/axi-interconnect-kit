`timescale 1ns / 1ps
`include "axi_llc_params.vh"

// Final external RTL top for the AXI/LLC submodule.
//
// Hierarchy:
//   axi_llc_subsystem
//     |- axi_llc_subsystem_compat
//     `- axi_llc_axi_bridge
//
// External boundary:
//   - Upstream: current C++-style multi read/write master custom interface
//   - Downstream: a single AXI4 master port
//
// Open this file first if the goal is to find the current external IO.
module axi_llc_subsystem #(
    parameter ADDR_BITS         = `AXI_LLC_ADDR_BITS,
    parameter ID_BITS           = `AXI_LLC_ID_BITS,
    parameter MODE_BITS         = `AXI_LLC_MODE_BITS,
    parameter LINE_BYTES        = `AXI_LLC_LINE_BYTES,
    parameter LINE_BITS         = `AXI_LLC_LINE_BITS,
    parameter LINE_OFFSET_BITS  = `AXI_LLC_LINE_OFFSET_BITS,
    parameter SET_COUNT         = `AXI_LLC_SET_COUNT,
    parameter SET_BITS          = `AXI_LLC_SET_BITS,
    parameter WAY_COUNT         = `AXI_LLC_WAY_COUNT,
    parameter WAY_BITS          = `AXI_LLC_WAY_BITS,
    parameter META_BITS         = `AXI_LLC_META_BITS,
    parameter LLC_SIZE_BYTES    = `AXI_LLC_LLC_SIZE_BYTES,
    parameter WINDOW_BYTES      = `AXI_LLC_WINDOW_BYTES,
    parameter WINDOW_WAYS       = `AXI_LLC_WINDOW_WAYS,
    parameter MMIO_BASE         = `AXI_LLC_MMIO_BASE,
    parameter MMIO_SIZE         = `AXI_LLC_MMIO_SIZE,
    parameter RESET_MODE        = {{(`AXI_LLC_MODE_BITS-2){1'b0}}, 2'b01},
    parameter RESET_OFFSET      = {`AXI_LLC_ADDR_BITS{1'b0}},
    parameter USE_SMIC12_STORES = 0,
    parameter NUM_READ_MASTERS  = 4,
    parameter NUM_WRITE_MASTERS = 2,
    parameter AXI_ID_BITS       = `AXI_LLC_AXI_ID_BITS,
    parameter AXI_DATA_BYTES    = `AXI_LLC_AXI_DATA_BYTES,
    parameter AXI_DATA_BITS     = `AXI_LLC_AXI_DATA_BITS,
    parameter AXI_STRB_BITS     = `AXI_LLC_AXI_STRB_BITS
) (
    input                                   clk,
    input                                   rst_n,
    // Reconfiguration / maintenance control.
    input      [MODE_BITS-1:0]              mode_req,
    input      [ADDR_BITS-1:0]              llc_mapped_offset_req,
    // Upstream read masters.
    input      [NUM_READ_MASTERS-1:0]       read_req_valid,
    output     [NUM_READ_MASTERS-1:0]       read_req_ready,
    output     [NUM_READ_MASTERS-1:0]       read_req_accepted,
    output     [NUM_READ_MASTERS*ID_BITS-1:0] read_req_accepted_id,
    input      [NUM_READ_MASTERS*ADDR_BITS-1:0] read_req_addr,
    input      [NUM_READ_MASTERS*8-1:0]     read_req_total_size,
    input      [NUM_READ_MASTERS*ID_BITS-1:0] read_req_id,
    input      [NUM_READ_MASTERS-1:0]       read_req_bypass,
    output     [NUM_READ_MASTERS-1:0]       read_resp_valid,
    input      [NUM_READ_MASTERS-1:0]       read_resp_ready,
    output     [NUM_READ_MASTERS*LINE_BITS-1:0] read_resp_data,
    output     [NUM_READ_MASTERS*ID_BITS-1:0] read_resp_id,
    // Upstream write masters.
    input      [NUM_WRITE_MASTERS-1:0]      write_req_valid,
    output     [NUM_WRITE_MASTERS-1:0]      write_req_ready,
    output     [NUM_WRITE_MASTERS-1:0]      write_req_accepted,
    input      [NUM_WRITE_MASTERS*ADDR_BITS-1:0] write_req_addr,
    input      [NUM_WRITE_MASTERS*LINE_BITS-1:0] write_req_wdata,
    input      [NUM_WRITE_MASTERS*LINE_BYTES-1:0] write_req_wstrb,
    input      [NUM_WRITE_MASTERS*8-1:0]    write_req_total_size,
    input      [NUM_WRITE_MASTERS*ID_BITS-1:0] write_req_id,
    input      [NUM_WRITE_MASTERS-1:0]      write_req_bypass,
    output     [NUM_WRITE_MASTERS-1:0]      write_resp_valid,
    input      [NUM_WRITE_MASTERS-1:0]      write_resp_ready,
    output     [NUM_WRITE_MASTERS*ID_BITS-1:0] write_resp_id,
    output     [NUM_WRITE_MASTERS*2-1:0]    write_resp_code,
    // Downstream single AXI4 master.
    output                                  axi_awvalid,
    input                                   axi_awready,
    output     [AXI_ID_BITS-1:0]            axi_awid,
    output     [ADDR_BITS-1:0]              axi_awaddr,
    output     [7:0]                        axi_awlen,
    output     [2:0]                        axi_awsize,
    output     [1:0]                        axi_awburst,
    output                                  axi_wvalid,
    input                                   axi_wready,
    output     [AXI_DATA_BITS-1:0]          axi_wdata,
    output     [AXI_STRB_BITS-1:0]          axi_wstrb,
    output                                  axi_wlast,
    input                                   axi_bvalid,
    output                                  axi_bready,
    input      [AXI_ID_BITS-1:0]            axi_bid,
    input      [1:0]                        axi_bresp,
    output                                  axi_arvalid,
    input                                   axi_arready,
    output     [AXI_ID_BITS-1:0]            axi_arid,
    output     [ADDR_BITS-1:0]              axi_araddr,
    output     [7:0]                        axi_arlen,
    output     [2:0]                        axi_arsize,
    output     [1:0]                        axi_arburst,
    input                                   axi_rvalid,
    output                                  axi_rready,
    input      [AXI_ID_BITS-1:0]            axi_rid,
    input      [AXI_DATA_BITS-1:0]          axi_rdata,
    input      [1:0]                        axi_rresp,
    input                                   axi_rlast,
    // Explicit maintenance interface.
    input                                   invalidate_line_valid,
    input      [ADDR_BITS-1:0]              invalidate_line_addr,
    output                                  invalidate_line_accepted,
    input                                   invalidate_all_valid,
    output                                  invalidate_all_accepted,
    output     [MODE_BITS-1:0]              active_mode,
    output     [ADDR_BITS-1:0]              active_offset,
    output                                  reconfig_busy,
    output     [1:0]                        reconfig_state,
    output                                  config_error
);

    // Internal lower-memory abstract interfaces between the compat layer and
    // the AXI bridge. These are not current external IO.
    wire                     cache_req_valid_w;
    wire                     cache_req_ready_w;
    wire                     cache_req_write_w;
    wire [ADDR_BITS-1:0]     cache_req_addr_w;
    wire [ID_BITS-1:0]       cache_req_id_w;
    wire [7:0]               cache_req_size_w;
    wire [LINE_BITS-1:0]     cache_req_wdata_w;
    wire [LINE_BYTES-1:0]    cache_req_wstrb_w;
    wire                     cache_resp_valid_w;
    wire                     cache_resp_ready_w;
    wire [LINE_BITS-1:0]     cache_resp_rdata_w;
    wire [ID_BITS-1:0]       cache_resp_id_w;

    wire                     bypass_req_valid_w;
    wire                     bypass_req_ready_w;
    wire                     bypass_req_write_w;
    wire [ADDR_BITS-1:0]     bypass_req_addr_w;
    wire [ID_BITS-1:0]       bypass_req_id_w;
    wire [7:0]               bypass_req_size_w;
    wire [LINE_BITS-1:0]     bypass_req_wdata_w;
    wire [LINE_BYTES-1:0]    bypass_req_wstrb_w;
    wire                     bypass_resp_valid_w;
    wire                     bypass_resp_ready_w;
    wire [LINE_BITS-1:0]     bypass_resp_rdata_w;
    wire [ID_BITS-1:0]       bypass_resp_id_w;

    // Multi-master compatibility layer around the single-flow core.
    axi_llc_subsystem_compat #(
        .ADDR_BITS         (ADDR_BITS),
        .ID_BITS           (ID_BITS),
        .MODE_BITS         (MODE_BITS),
        .LINE_BYTES        (LINE_BYTES),
        .LINE_BITS         (LINE_BITS),
        .LINE_OFFSET_BITS  (LINE_OFFSET_BITS),
        .SET_COUNT         (SET_COUNT),
        .SET_BITS          (SET_BITS),
        .WAY_COUNT         (WAY_COUNT),
        .WAY_BITS          (WAY_BITS),
        .META_BITS         (META_BITS),
        .LLC_SIZE_BYTES    (LLC_SIZE_BYTES),
        .WINDOW_BYTES      (WINDOW_BYTES),
        .WINDOW_WAYS       (WINDOW_WAYS),
        .MMIO_BASE         (MMIO_BASE),
        .MMIO_SIZE         (MMIO_SIZE),
        .RESET_MODE        (RESET_MODE),
        .RESET_OFFSET      (RESET_OFFSET),
        .USE_SMIC12_STORES (USE_SMIC12_STORES),
        .NUM_READ_MASTERS  (NUM_READ_MASTERS),
        .NUM_WRITE_MASTERS (NUM_WRITE_MASTERS)
    ) compat (
        .clk                   (clk),
        .rst_n                 (rst_n),
        .mode_req              (mode_req),
        .llc_mapped_offset_req (llc_mapped_offset_req),
        .read_req_valid        (read_req_valid),
        .read_req_ready        (read_req_ready),
        .read_req_accepted     (read_req_accepted),
        .read_req_accepted_id  (read_req_accepted_id),
        .read_req_addr         (read_req_addr),
        .read_req_total_size   (read_req_total_size),
        .read_req_id           (read_req_id),
        .read_req_bypass       (read_req_bypass),
        .read_resp_valid       (read_resp_valid),
        .read_resp_ready       (read_resp_ready),
        .read_resp_data        (read_resp_data),
        .read_resp_id          (read_resp_id),
        .write_req_valid       (write_req_valid),
        .write_req_ready       (write_req_ready),
        .write_req_accepted    (write_req_accepted),
        .write_req_addr        (write_req_addr),
        .write_req_wdata       (write_req_wdata),
        .write_req_wstrb       (write_req_wstrb),
        .write_req_total_size  (write_req_total_size),
        .write_req_id          (write_req_id),
        .write_req_bypass      (write_req_bypass),
        .write_resp_valid      (write_resp_valid),
        .write_resp_ready      (write_resp_ready),
        .write_resp_id         (write_resp_id),
        .write_resp_code       (write_resp_code),
        .cache_req_valid       (cache_req_valid_w),
        .cache_req_ready       (cache_req_ready_w),
        .cache_req_write       (cache_req_write_w),
        .cache_req_addr        (cache_req_addr_w),
        .cache_req_id          (cache_req_id_w),
        .cache_req_size        (cache_req_size_w),
        .cache_req_wdata       (cache_req_wdata_w),
        .cache_req_wstrb       (cache_req_wstrb_w),
        .cache_resp_valid      (cache_resp_valid_w),
        .cache_resp_ready      (cache_resp_ready_w),
        .cache_resp_rdata      (cache_resp_rdata_w),
        .cache_resp_id         (cache_resp_id_w),
        .bypass_req_valid      (bypass_req_valid_w),
        .bypass_req_ready      (bypass_req_ready_w),
        .bypass_req_write      (bypass_req_write_w),
        .bypass_req_addr       (bypass_req_addr_w),
        .bypass_req_id         (bypass_req_id_w),
        .bypass_req_size       (bypass_req_size_w),
        .bypass_req_wdata      (bypass_req_wdata_w),
        .bypass_req_wstrb      (bypass_req_wstrb_w),
        .bypass_resp_valid     (bypass_resp_valid_w),
        .bypass_resp_ready     (bypass_resp_ready_w),
        .bypass_resp_rdata     (bypass_resp_rdata_w),
        .bypass_resp_id        (bypass_resp_id_w),
        .invalidate_line_valid (invalidate_line_valid),
        .invalidate_line_addr  (invalidate_line_addr),
        .invalidate_line_accepted(invalidate_line_accepted),
        .invalidate_all_valid  (invalidate_all_valid),
        .invalidate_all_accepted(invalidate_all_accepted),
        .active_mode           (active_mode),
        .active_offset         (active_offset),
        .reconfig_busy         (reconfig_busy),
        .reconfig_state        (reconfig_state),
        .config_error          (config_error)
    );

    // AXI packing / response recovery for cache and bypass lower requests.
    axi_llc_axi_bridge #(
        .ADDR_BITS      (ADDR_BITS),
        .ID_BITS        (ID_BITS),
        .LINE_BYTES     (LINE_BYTES),
        .LINE_BITS      (LINE_BITS),
        .AXI_ID_BITS    (AXI_ID_BITS),
        .AXI_DATA_BYTES (AXI_DATA_BYTES),
        .AXI_DATA_BITS  (AXI_DATA_BITS),
        .AXI_STRB_BITS  (AXI_STRB_BITS)
    ) bridge (
        .clk               (clk),
        .rst_n             (rst_n),
        .cache_req_valid   (cache_req_valid_w),
        .cache_req_ready   (cache_req_ready_w),
        .cache_req_write   (cache_req_write_w),
        .cache_req_addr    (cache_req_addr_w),
        .cache_req_id      (cache_req_id_w),
        .cache_req_size    (cache_req_size_w),
        .cache_req_wdata   (cache_req_wdata_w),
        .cache_req_wstrb   (cache_req_wstrb_w),
        .cache_resp_valid  (cache_resp_valid_w),
        .cache_resp_ready  (cache_resp_ready_w),
        .cache_resp_rdata  (cache_resp_rdata_w),
        .cache_resp_id     (cache_resp_id_w),
        .bypass_req_valid  (bypass_req_valid_w),
        .bypass_req_ready  (bypass_req_ready_w),
        .bypass_req_write  (bypass_req_write_w),
        .bypass_req_addr   (bypass_req_addr_w),
        .bypass_req_id     (bypass_req_id_w),
        .bypass_req_size   (bypass_req_size_w),
        .bypass_req_wdata  (bypass_req_wdata_w),
        .bypass_req_wstrb  (bypass_req_wstrb_w),
        .bypass_resp_valid (bypass_resp_valid_w),
        .bypass_resp_ready (bypass_resp_ready_w),
        .bypass_resp_rdata (bypass_resp_rdata_w),
        .bypass_resp_id    (bypass_resp_id_w),
        .axi_awvalid       (axi_awvalid),
        .axi_awready       (axi_awready),
        .axi_awid          (axi_awid),
        .axi_awaddr        (axi_awaddr),
        .axi_awlen         (axi_awlen),
        .axi_awsize        (axi_awsize),
        .axi_awburst       (axi_awburst),
        .axi_wvalid        (axi_wvalid),
        .axi_wready        (axi_wready),
        .axi_wdata         (axi_wdata),
        .axi_wstrb         (axi_wstrb),
        .axi_wlast         (axi_wlast),
        .axi_bvalid        (axi_bvalid),
        .axi_bready        (axi_bready),
        .axi_bid           (axi_bid),
        .axi_bresp         (axi_bresp),
        .axi_arvalid       (axi_arvalid),
        .axi_arready       (axi_arready),
        .axi_arid          (axi_arid),
        .axi_araddr        (axi_araddr),
        .axi_arlen         (axi_arlen),
        .axi_arsize        (axi_arsize),
        .axi_arburst       (axi_arburst),
        .axi_rvalid        (axi_rvalid),
        .axi_rready        (axi_rready),
        .axi_rid           (axi_rid),
        .axi_rdata         (axi_rdata),
        .axi_rresp         (axi_rresp),
        .axi_rlast         (axi_rlast)
    );

endmodule
