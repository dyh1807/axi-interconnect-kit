`timescale 1ns / 1ps
`include "axi_llc_params.vh"

// Compatibility layer between the C++-style multi-master external boundary
// and the single-flow RTL core.
//
// Responsibilities:
//   - Hold one queued request per upstream master
//   - Return accepted / accepted_id / independent write responses
//   - Serialize requests into axi_llc_subsystem_core
//
// This layer does not translate to AXI and does not own resident storage.
module axi_llc_subsystem_compat #(
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
    parameter NUM_WRITE_MASTERS = 2
) (
    input                                   clk,
    input                                   rst_n,
    // Reconfiguration / maintenance control.
    input      [MODE_BITS-1:0]              mode_req,
    input      [ADDR_BITS-1:0]              llc_mapped_offset_req,
    // Upstream read masters.
    input      [NUM_READ_MASTERS-1:0]       read_req_valid,
    output reg [NUM_READ_MASTERS-1:0]       read_req_ready,
    output reg [NUM_READ_MASTERS-1:0]       read_req_accepted,
    output reg [NUM_READ_MASTERS*ID_BITS-1:0] read_req_accepted_id,
    input      [NUM_READ_MASTERS*ADDR_BITS-1:0] read_req_addr,
    input      [NUM_READ_MASTERS*8-1:0]     read_req_total_size,
    input      [NUM_READ_MASTERS*ID_BITS-1:0] read_req_id,
    input      [NUM_READ_MASTERS-1:0]       read_req_bypass,
    output reg [NUM_READ_MASTERS-1:0]       read_resp_valid,
    input      [NUM_READ_MASTERS-1:0]       read_resp_ready,
    output reg [NUM_READ_MASTERS*LINE_BITS-1:0] read_resp_data,
    output reg [NUM_READ_MASTERS*ID_BITS-1:0] read_resp_id,
    // Upstream write masters.
    input      [NUM_WRITE_MASTERS-1:0]      write_req_valid,
    output reg [NUM_WRITE_MASTERS-1:0]      write_req_ready,
    output reg [NUM_WRITE_MASTERS-1:0]      write_req_accepted,
    input      [NUM_WRITE_MASTERS*ADDR_BITS-1:0] write_req_addr,
    input      [NUM_WRITE_MASTERS*LINE_BITS-1:0] write_req_wdata,
    input      [NUM_WRITE_MASTERS*LINE_BYTES-1:0] write_req_wstrb,
    input      [NUM_WRITE_MASTERS*8-1:0]    write_req_total_size,
    input      [NUM_WRITE_MASTERS*ID_BITS-1:0] write_req_id,
    input      [NUM_WRITE_MASTERS-1:0]      write_req_bypass,
    output reg [NUM_WRITE_MASTERS-1:0]      write_resp_valid,
    input      [NUM_WRITE_MASTERS-1:0]      write_resp_ready,
    output reg [NUM_WRITE_MASTERS*ID_BITS-1:0] write_resp_id,
    output reg [NUM_WRITE_MASTERS*2-1:0]    write_resp_code,
    // Core-exported lower interfaces toward the AXI bridge.
    output                                  cache_req_valid,
    input                                   cache_req_ready,
    output                                  cache_req_write,
    output     [ADDR_BITS-1:0]              cache_req_addr,
    output     [ID_BITS-1:0]                cache_req_id,
    output     [7:0]                        cache_req_size,
    output     [LINE_BITS-1:0]              cache_req_wdata,
    output     [LINE_BYTES-1:0]             cache_req_wstrb,
    input                                   cache_resp_valid,
    output                                  cache_resp_ready,
    input      [LINE_BITS-1:0]              cache_resp_rdata,
    input      [ID_BITS-1:0]                cache_resp_id,
    output                                  bypass_req_valid,
    input                                   bypass_req_ready,
    output                                  bypass_req_write,
    output     [ADDR_BITS-1:0]              bypass_req_addr,
    output     [ID_BITS-1:0]                bypass_req_id,
    output     [7:0]                        bypass_req_size,
    output     [LINE_BITS-1:0]              bypass_req_wdata,
    output     [LINE_BYTES-1:0]             bypass_req_wstrb,
    input                                   bypass_resp_valid,
    output                                  bypass_resp_ready,
    input      [LINE_BITS-1:0]              bypass_resp_rdata,
    input      [ID_BITS-1:0]                bypass_resp_id,
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

    localparam integer TOTAL_PORTS = NUM_READ_MASTERS + NUM_WRITE_MASTERS;
    localparam [1:0] WRITE_RESP_OKAY = 2'b00;

    // Per-master one-entry request queues.
    reg [NUM_READ_MASTERS-1:0]   rd_q_valid;
    reg [ADDR_BITS-1:0]          rd_q_addr [0:NUM_READ_MASTERS-1];
    reg [7:0]                    rd_q_size [0:NUM_READ_MASTERS-1];
    reg [ID_BITS-1:0]            rd_q_id [0:NUM_READ_MASTERS-1];
    reg                          rd_q_bypass [0:NUM_READ_MASTERS-1];

    reg [NUM_WRITE_MASTERS-1:0]  wr_q_valid;
    reg [ADDR_BITS-1:0]          wr_q_addr [0:NUM_WRITE_MASTERS-1];
    reg [LINE_BITS-1:0]          wr_q_wdata [0:NUM_WRITE_MASTERS-1];
    reg [LINE_BYTES-1:0]         wr_q_wstrb [0:NUM_WRITE_MASTERS-1];
    reg [7:0]                    wr_q_size [0:NUM_WRITE_MASTERS-1];
    reg [ID_BITS-1:0]            wr_q_id [0:NUM_WRITE_MASTERS-1];
    reg                          wr_q_bypass [0:NUM_WRITE_MASTERS-1];

    reg                          rd_resp_valid_r [0:NUM_READ_MASTERS-1];
    reg [LINE_BITS-1:0]          rd_resp_data_r [0:NUM_READ_MASTERS-1];
    reg [ID_BITS-1:0]            rd_resp_id_r [0:NUM_READ_MASTERS-1];
    reg [NUM_READ_MASTERS-1:0]   read_req_accepted_r;
    reg [NUM_READ_MASTERS*ID_BITS-1:0] read_req_accepted_id_r;

    reg                          wr_resp_valid_r [0:NUM_WRITE_MASTERS-1];
    reg [ID_BITS-1:0]            wr_resp_id_r [0:NUM_WRITE_MASTERS-1];
    reg [1:0]                    wr_resp_code_r [0:NUM_WRITE_MASTERS-1];
    reg [NUM_WRITE_MASTERS-1:0]  write_req_accepted_r;

    reg [7:0]                    rr_ptr_r;
    reg                          inflight_valid_r;
    reg                          inflight_is_write_r;
    reg [7:0]                    inflight_master_r;
    reg [ID_BITS-1:0]            inflight_id_r;

    // Single request presented to the core in the current cycle.
    reg                          core_up_req_valid_w;
    wire                         core_up_req_ready_w;
    reg                          core_up_req_write_w;
    reg [ADDR_BITS-1:0]          core_up_req_addr_w;
    reg [ID_BITS-1:0]            core_up_req_id_w;
    reg [7:0]                    core_up_req_total_size_w;
    reg [LINE_BITS-1:0]          core_up_req_wdata_w;
    reg [LINE_BYTES-1:0]         core_up_req_wstrb_w;
    reg                          core_up_req_bypass_w;
    wire                         core_up_resp_valid_w;
    wire                         core_up_resp_ready_w;
    wire [LINE_BITS-1:0]         core_up_resp_rdata_w;
    wire [ID_BITS-1:0]           core_up_resp_id_w;

    reg                          dispatch_found_w;
    reg                          dispatch_is_write_w;
    reg [7:0]                    dispatch_master_w;
    integer                      dispatch_slot_w;
    integer                      rr_off;
    integer                      flat_idx;
    integer                      next_port;

    wire target_read_resp_ready_w;
    wire target_write_resp_ready_w;

    assign target_read_resp_ready_w =
        inflight_valid_r && !inflight_is_write_r &&
        !rd_resp_valid_r[inflight_master_r];
    assign target_write_resp_ready_w =
        inflight_valid_r && inflight_is_write_r &&
        !wr_resp_valid_r[inflight_master_r];
    assign core_up_resp_ready_w = target_read_resp_ready_w ||
                                  target_write_resp_ready_w;

    always @(*) begin
        // Round-robin selection over all read and write queues.
        dispatch_found_w = 1'b0;
        dispatch_is_write_w = 1'b0;
        dispatch_master_w = 8'd0;
        dispatch_slot_w = 0;
        core_up_req_valid_w = 1'b0;
        core_up_req_write_w = 1'b0;
        core_up_req_addr_w = {ADDR_BITS{1'b0}};
        core_up_req_id_w = {ID_BITS{1'b0}};
        core_up_req_total_size_w = 8'd0;
        core_up_req_wdata_w = {LINE_BITS{1'b0}};
        core_up_req_wstrb_w = {LINE_BYTES{1'b0}};
        core_up_req_bypass_w = 1'b0;

        if (!inflight_valid_r) begin
            for (rr_off = 0; rr_off < TOTAL_PORTS; rr_off = rr_off + 1) begin
                next_port = rr_ptr_r + rr_off;
                if (next_port >= TOTAL_PORTS) begin
                    next_port = next_port - TOTAL_PORTS;
                end
                if (!dispatch_found_w) begin
                    if (next_port < NUM_READ_MASTERS) begin
                        if (rd_q_valid[next_port] && !rd_resp_valid_r[next_port]) begin
                            dispatch_found_w = 1'b1;
                            dispatch_is_write_w = 1'b0;
                            dispatch_master_w = next_port[7:0];
                            dispatch_slot_w = next_port;
                            core_up_req_valid_w = 1'b1;
                            core_up_req_write_w = 1'b0;
                            core_up_req_addr_w = rd_q_addr[next_port];
                            core_up_req_id_w = rd_q_id[next_port];
                            core_up_req_total_size_w = rd_q_size[next_port];
                            core_up_req_wdata_w = {LINE_BITS{1'b0}};
                            core_up_req_wstrb_w = {LINE_BYTES{1'b0}};
                            core_up_req_bypass_w = rd_q_bypass[next_port];
                        end
                    end else begin
                        flat_idx = next_port - NUM_READ_MASTERS;
                        if (wr_q_valid[flat_idx] && !wr_resp_valid_r[flat_idx]) begin
                            dispatch_found_w = 1'b1;
                            dispatch_is_write_w = 1'b1;
                            dispatch_master_w = flat_idx[7:0];
                            dispatch_slot_w = next_port;
                            core_up_req_valid_w = 1'b1;
                            core_up_req_write_w = 1'b1;
                            core_up_req_addr_w = wr_q_addr[flat_idx];
                            core_up_req_id_w = wr_q_id[flat_idx];
                            core_up_req_total_size_w = wr_q_size[flat_idx];
                            core_up_req_wdata_w = wr_q_wdata[flat_idx];
                            core_up_req_wstrb_w = wr_q_wstrb[flat_idx];
                            core_up_req_bypass_w = wr_q_bypass[flat_idx];
                        end
                    end
                end
            end
        end

        read_req_ready = {NUM_READ_MASTERS{1'b0}};
        read_req_accepted = read_req_accepted_r;
        read_req_accepted_id = read_req_accepted_id_r;
        read_resp_valid = {NUM_READ_MASTERS{1'b0}};
        read_resp_data = {(NUM_READ_MASTERS*LINE_BITS){1'b0}};
        read_resp_id = {(NUM_READ_MASTERS*ID_BITS){1'b0}};
        for (flat_idx = 0; flat_idx < NUM_READ_MASTERS; flat_idx = flat_idx + 1) begin
            read_req_ready[flat_idx] = !rd_q_valid[flat_idx];
            read_resp_valid[flat_idx] = rd_resp_valid_r[flat_idx];
            read_resp_data[(flat_idx * LINE_BITS) +: LINE_BITS] =
                rd_resp_data_r[flat_idx];
            read_resp_id[(flat_idx * ID_BITS) +: ID_BITS] =
                rd_resp_id_r[flat_idx];
        end

        write_req_ready = {NUM_WRITE_MASTERS{1'b0}};
        write_req_accepted = write_req_accepted_r;
        write_resp_valid = {NUM_WRITE_MASTERS{1'b0}};
        write_resp_id = {(NUM_WRITE_MASTERS*ID_BITS){1'b0}};
        write_resp_code = {(NUM_WRITE_MASTERS*2){1'b0}};
        for (flat_idx = 0; flat_idx < NUM_WRITE_MASTERS; flat_idx = flat_idx + 1) begin
            write_req_ready[flat_idx] = !wr_q_valid[flat_idx];
            write_resp_valid[flat_idx] = wr_resp_valid_r[flat_idx];
            write_resp_id[(flat_idx * ID_BITS) +: ID_BITS] =
                wr_resp_id_r[flat_idx];
            write_resp_code[(flat_idx * 2) +: 2] =
                wr_resp_code_r[flat_idx];
        end
    end

    // Single-flow core instance.
    axi_llc_subsystem_core #(
        .ADDR_BITS        (ADDR_BITS),
        .ID_BITS          (ID_BITS),
        .MODE_BITS        (MODE_BITS),
        .LINE_BYTES       (LINE_BYTES),
        .LINE_BITS        (LINE_BITS),
        .LINE_OFFSET_BITS (LINE_OFFSET_BITS),
        .SET_COUNT        (SET_COUNT),
        .SET_BITS         (SET_BITS),
        .WAY_COUNT        (WAY_COUNT),
        .WAY_BITS         (WAY_BITS),
        .META_BITS        (META_BITS),
        .LLC_SIZE_BYTES   (LLC_SIZE_BYTES),
        .WINDOW_BYTES     (WINDOW_BYTES),
        .WINDOW_WAYS      (WINDOW_WAYS),
        .MMIO_BASE        (MMIO_BASE),
        .MMIO_SIZE        (MMIO_SIZE),
        .RESET_MODE       (RESET_MODE),
        .RESET_OFFSET     (RESET_OFFSET),
        .USE_SMIC12_STORES(USE_SMIC12_STORES)
    ) core (
        .clk                   (clk),
        .rst_n                 (rst_n),
        .mode_req              (mode_req),
        .llc_mapped_offset_req (llc_mapped_offset_req),
        .up_req_valid          (core_up_req_valid_w),
        .up_req_ready          (core_up_req_ready_w),
        .up_req_write          (core_up_req_write_w),
        .up_req_addr           (core_up_req_addr_w),
        .up_req_id             (core_up_req_id_w),
        .up_req_total_size     (core_up_req_total_size_w),
        .up_req_wdata          (core_up_req_wdata_w),
        .up_req_wstrb          (core_up_req_wstrb_w),
        .up_req_bypass         (core_up_req_bypass_w),
        .up_resp_valid         (core_up_resp_valid_w),
        .up_resp_ready         (core_up_resp_ready_w),
        .up_resp_rdata         (core_up_resp_rdata_w),
        .up_resp_id            (core_up_resp_id_w),
        .cache_req_valid       (cache_req_valid),
        .cache_req_ready       (cache_req_ready),
        .cache_req_write       (cache_req_write),
        .cache_req_addr        (cache_req_addr),
        .cache_req_id          (cache_req_id),
        .cache_req_size        (cache_req_size),
        .cache_req_wdata       (cache_req_wdata),
        .cache_req_wstrb       (cache_req_wstrb),
        .cache_resp_valid      (cache_resp_valid),
        .cache_resp_ready      (cache_resp_ready),
        .cache_resp_rdata      (cache_resp_rdata),
        .cache_resp_id         (cache_resp_id),
        .bypass_req_valid      (bypass_req_valid),
        .bypass_req_ready      (bypass_req_ready),
        .bypass_req_write      (bypass_req_write),
        .bypass_req_addr       (bypass_req_addr),
        .bypass_req_id         (bypass_req_id),
        .bypass_req_size       (bypass_req_size),
        .bypass_req_wdata      (bypass_req_wdata),
        .bypass_req_wstrb      (bypass_req_wstrb),
        .bypass_resp_valid     (bypass_resp_valid),
        .bypass_resp_ready     (bypass_resp_ready),
        .bypass_resp_rdata     (bypass_resp_rdata),
        .bypass_resp_id        (bypass_resp_id),
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

    integer idx;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rr_ptr_r <= 8'd0;
            inflight_valid_r <= 1'b0;
            inflight_is_write_r <= 1'b0;
            inflight_master_r <= 8'd0;
            inflight_id_r <= {ID_BITS{1'b0}};
            read_req_accepted_r <= {NUM_READ_MASTERS{1'b0}};
            read_req_accepted_id_r <= {(NUM_READ_MASTERS*ID_BITS){1'b0}};
            write_req_accepted_r <= {NUM_WRITE_MASTERS{1'b0}};
            for (idx = 0; idx < NUM_READ_MASTERS; idx = idx + 1) begin
                rd_q_valid[idx] <= 1'b0;
                rd_q_addr[idx] <= {ADDR_BITS{1'b0}};
                rd_q_size[idx] <= 8'd0;
                rd_q_id[idx] <= {ID_BITS{1'b0}};
                rd_q_bypass[idx] <= 1'b0;
                rd_resp_valid_r[idx] <= 1'b0;
                rd_resp_data_r[idx] <= {LINE_BITS{1'b0}};
                rd_resp_id_r[idx] <= {ID_BITS{1'b0}};
            end
            for (idx = 0; idx < NUM_WRITE_MASTERS; idx = idx + 1) begin
                wr_q_valid[idx] <= 1'b0;
                wr_q_addr[idx] <= {ADDR_BITS{1'b0}};
                wr_q_wdata[idx] <= {LINE_BITS{1'b0}};
                wr_q_wstrb[idx] <= {LINE_BYTES{1'b0}};
                wr_q_size[idx] <= 8'd0;
                wr_q_id[idx] <= {ID_BITS{1'b0}};
                wr_q_bypass[idx] <= 1'b0;
                wr_resp_valid_r[idx] <= 1'b0;
                wr_resp_id_r[idx] <= {ID_BITS{1'b0}};
                wr_resp_code_r[idx] <= WRITE_RESP_OKAY;
            end
        end else begin
            read_req_accepted_r <= {NUM_READ_MASTERS{1'b0}};
            read_req_accepted_id_r <= {(NUM_READ_MASTERS*ID_BITS){1'b0}};
            write_req_accepted_r <= {NUM_WRITE_MASTERS{1'b0}};

            for (idx = 0; idx < NUM_READ_MASTERS; idx = idx + 1) begin
                if (rd_resp_valid_r[idx] && read_resp_ready[idx]) begin
                    rd_resp_valid_r[idx] <= 1'b0;
                end
                if (read_req_valid[idx] && read_req_ready[idx]) begin
                    rd_q_valid[idx] <= 1'b1;
                    rd_q_addr[idx] <= read_req_addr[(idx * ADDR_BITS) +: ADDR_BITS];
                    rd_q_size[idx] <= read_req_total_size[(idx * 8) +: 8];
                    rd_q_id[idx] <= read_req_id[(idx * ID_BITS) +: ID_BITS];
                    rd_q_bypass[idx] <= read_req_bypass[idx];
                    read_req_accepted_r[idx] <= 1'b1;
                    read_req_accepted_id_r[(idx * ID_BITS) +: ID_BITS] <=
                        read_req_id[(idx * ID_BITS) +: ID_BITS];
                end
            end

            for (idx = 0; idx < NUM_WRITE_MASTERS; idx = idx + 1) begin
                if (wr_resp_valid_r[idx] && write_resp_ready[idx]) begin
                    wr_resp_valid_r[idx] <= 1'b0;
                end
                if (write_req_valid[idx] && write_req_ready[idx]) begin
                    wr_q_valid[idx] <= 1'b1;
                    wr_q_addr[idx] <= write_req_addr[(idx * ADDR_BITS) +: ADDR_BITS];
                    wr_q_wdata[idx] <= write_req_wdata[(idx * LINE_BITS) +: LINE_BITS];
                    wr_q_wstrb[idx] <= write_req_wstrb[(idx * LINE_BYTES) +: LINE_BYTES];
                    wr_q_size[idx] <= write_req_total_size[(idx * 8) +: 8];
                    wr_q_id[idx] <= write_req_id[(idx * ID_BITS) +: ID_BITS];
                    wr_q_bypass[idx] <= write_req_bypass[idx];
                    write_req_accepted_r[idx] <= 1'b1;
                end
            end

            if (core_up_req_valid_w && core_up_req_ready_w) begin
                inflight_valid_r <= 1'b1;
                inflight_is_write_r <= dispatch_is_write_w;
                inflight_master_r <= dispatch_master_w;
                inflight_id_r <= core_up_req_id_w;
                rr_ptr_r <= dispatch_slot_w[7:0] + 8'd1;
                if (dispatch_is_write_w) begin
                    wr_q_valid[dispatch_master_w] <= 1'b0;
                end else begin
                    rd_q_valid[dispatch_master_w] <= 1'b0;
                end
            end

            // Move the accepted core response back into the owning read/write
            // response slot and free the inflight marker.
            if (core_up_resp_valid_w && core_up_resp_ready_w && inflight_valid_r) begin
                if (inflight_is_write_r) begin
                    wr_resp_valid_r[inflight_master_r] <= 1'b1;
                    wr_resp_id_r[inflight_master_r] <= inflight_id_r;
                    wr_resp_code_r[inflight_master_r] <= WRITE_RESP_OKAY;
                end else begin
                    rd_resp_valid_r[inflight_master_r] <= 1'b1;
                    rd_resp_data_r[inflight_master_r] <= core_up_resp_rdata_w;
                    rd_resp_id_r[inflight_master_r] <= core_up_resp_id_w;
                end
                inflight_valid_r <= 1'b0;
            end
        end
    end

endmodule
