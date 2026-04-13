`timescale 1ns / 1ps
`include "axi_llc_params.vh"

// Compatibility layer between the C++-style multi-master external boundary
// and the single-flow RTL core.
//
// Responsibilities:
//   - Hold per-master queued upstream requests
//   - Return accepted / accepted_id / independent write responses
//   - Serialize requests into axi_llc_subsystem_core
//   - Drain local queues before reconfiguration / invalidate-all reaches core
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
    parameter TABLE_READ_LATENCY = `AXI_LLC_TABLE_READ_LATENCY,
    parameter NUM_READ_MASTERS  = 4,
    parameter NUM_WRITE_MASTERS = 2,
    parameter READ_RESP_BYTES   = `AXI_LLC_READ_RESP_BYTES,
    parameter READ_RESP_BITS    = `AXI_LLC_READ_RESP_BITS
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
    output reg [NUM_READ_MASTERS*READ_RESP_BITS-1:0] read_resp_data,
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
    input      [READ_RESP_BITS-1:0]         cache_resp_rdata,
    input      [ID_BITS-1:0]                cache_resp_id,
    input      [1:0]                        cache_resp_code,
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
    input      [READ_RESP_BITS-1:0]         bypass_resp_rdata,
    input      [ID_BITS-1:0]                bypass_resp_id,
    input      [1:0]                        bypass_resp_code,
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
    localparam integer MAX_OUTSTANDING = `AXI_LLC_MAX_OUTSTANDING;
    localparam integer READ_FIFO_DEPTH = `AXI_LLC_MAX_READ_OUTSTANDING_PER_MASTER;
    localparam integer WRITE_FIFO_DEPTH = `AXI_LLC_MAX_WRITE_OUTSTANDING;
    localparam integer MAX_WRITE_OUTSTANDING = `AXI_LLC_MAX_WRITE_OUTSTANDING;
    localparam integer RD_SLOT_COUNT = NUM_READ_MASTERS * READ_FIFO_DEPTH;
    localparam integer WR_SLOT_COUNT = NUM_WRITE_MASTERS * WRITE_FIFO_DEPTH;
    localparam [1:0] WRITE_RESP_OKAY = 2'b00;
    localparam [MODE_BITS-1:0] MODE_MAPPED =
        {{(MODE_BITS-2){1'b0}}, 2'b10};
    localparam integer MASTER_DCACHE_R = 1;

    // Flattened per-master FIFOs so the module stays plain Verilog.
    reg [RD_SLOT_COUNT-1:0]      rd_q_valid;
    reg [ADDR_BITS-1:0]          rd_q_addr [0:RD_SLOT_COUNT-1];
    reg [7:0]                    rd_q_size [0:RD_SLOT_COUNT-1];
    reg [ID_BITS-1:0]            rd_q_id [0:RD_SLOT_COUNT-1];
    reg                          rd_q_bypass [0:RD_SLOT_COUNT-1];
    reg [7:0]                    rd_q_head [0:NUM_READ_MASTERS-1];
    reg [7:0]                    rd_q_tail [0:NUM_READ_MASTERS-1];
    reg [7:0]                    rd_q_count [0:NUM_READ_MASTERS-1];

    reg [WR_SLOT_COUNT-1:0]      wr_q_valid;
    reg [ADDR_BITS-1:0]          wr_q_addr [0:WR_SLOT_COUNT-1];
    reg [LINE_BITS-1:0]          wr_q_wdata [0:WR_SLOT_COUNT-1];
    reg [LINE_BYTES-1:0]         wr_q_wstrb [0:WR_SLOT_COUNT-1];
    reg [7:0]                    wr_q_size [0:WR_SLOT_COUNT-1];
    reg [ID_BITS-1:0]            wr_q_id [0:WR_SLOT_COUNT-1];
    reg                          wr_q_bypass [0:WR_SLOT_COUNT-1];
    reg [7:0]                    wr_q_head [0:NUM_WRITE_MASTERS-1];
    reg [7:0]                    wr_q_tail [0:NUM_WRITE_MASTERS-1];
    reg [7:0]                    wr_q_count [0:NUM_WRITE_MASTERS-1];

    reg                          rd_resp_valid_r [0:NUM_READ_MASTERS-1];
    reg [READ_RESP_BITS-1:0]     rd_resp_data_r [0:NUM_READ_MASTERS-1];
    reg [ID_BITS-1:0]            rd_resp_id_r [0:NUM_READ_MASTERS-1];
    reg [NUM_READ_MASTERS-1:0]   read_req_accepted_r;
    reg [NUM_READ_MASTERS*ID_BITS-1:0] read_req_accepted_id_r;

    reg                          wr_resp_valid_r [0:NUM_WRITE_MASTERS-1];
    reg [ID_BITS-1:0]            wr_resp_id_r [0:NUM_WRITE_MASTERS-1];
    reg [1:0]                    wr_resp_code_r [0:NUM_WRITE_MASTERS-1];
    reg [ADDR_BITS-1:0]          wr_resp_addr_r [0:NUM_WRITE_MASTERS-1];
    reg [NUM_WRITE_MASTERS-1:0]  write_req_accepted_r;
    reg [NUM_READ_MASTERS-1:0]   read_req_ready_r;
    reg [NUM_WRITE_MASTERS-1:0]  write_req_ready_r;
    reg [7:0]                    rd_capture_rr_r;
    reg [7:0]                    wr_capture_rr_r;

    reg [7:0]                    rr_ptr_r;
    reg                          inflight_valid_r;
    reg                          inflight_is_write_r;
    reg [7:0]                    inflight_master_r;
    reg [ID_BITS-1:0]            inflight_id_r;
    reg [ADDR_BITS-1:0]          inflight_addr_r;

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
    wire [READ_RESP_BITS-1:0]    core_up_resp_rdata_w;
    wire [ID_BITS-1:0]           core_up_resp_id_w;
    wire [1:0]                   core_up_resp_code_w;

    reg                          dispatch_found_w;
    reg                          dispatch_is_write_w;
    reg [7:0]                    dispatch_master_w;
    integer                      dispatch_fifo_slot_w;
    integer                      dispatch_slot_w;
    integer                      rr_off;
    integer                      flat_idx;
    integer                      next_port;
    integer                      slot_idx;
    integer                      total_read_outstanding_w;
    integer                      total_write_outstanding_w;
    reg                          rd_select_found_w;
    reg [7:0]                    rd_select_master_w;
    reg                          wr_select_found_w;
    reg [7:0]                    wr_select_master_w;
    reg                          compat_quiescent_w;
    reg                          line_write_hazard_w;
    reg                          accept_blocked_w;
    reg                          dcache_same_cycle_accept_w;
    reg [MODE_BITS-1:0]          core_mode_req_w;
    reg [ADDR_BITS-1:0]          core_offset_req_w;
    reg                          core_invalidate_all_valid_w;
    reg                          core_invalidate_line_valid_w;

    wire target_read_resp_ready_w;
    wire target_write_resp_ready_w;
    wire reconfig_req_pending_w;
    wire maintenance_pending_w;

    assign reconfig_req_pending_w =
        (mode_req != active_mode) ||
        ((mode_req == MODE_MAPPED) &&
         (llc_mapped_offset_req != active_offset));
    assign maintenance_pending_w =
        reconfig_req_pending_w || invalidate_all_valid || invalidate_line_valid;

    function integer rd_slot_index;
        input integer master_idx;
        input integer ptr_idx;
        begin
            rd_slot_index = master_idx * READ_FIFO_DEPTH + ptr_idx;
        end
    endfunction

    function integer wr_slot_index;
        input integer master_idx;
        input integer ptr_idx;
        begin
            wr_slot_index = master_idx * WRITE_FIFO_DEPTH + ptr_idx;
        end
    endfunction

    function integer next_rd_ptr;
        input integer ptr_idx;
        begin
            if (ptr_idx == (READ_FIFO_DEPTH - 1)) begin
                next_rd_ptr = 0;
            end else begin
                next_rd_ptr = ptr_idx + 1;
            end
        end
    endfunction

    function integer next_wr_ptr;
        input integer ptr_idx;
        begin
            if (ptr_idx == (WRITE_FIFO_DEPTH - 1)) begin
                next_wr_ptr = 0;
            end else begin
                next_wr_ptr = ptr_idx + 1;
            end
        end
    endfunction

    function read_id_conflict;
        input integer master_idx;
        input [ID_BITS-1:0] req_id_value;
        integer depth_idx;
        integer slot_value;
        begin
            read_id_conflict = 1'b0;
            if (rd_resp_valid_r[master_idx] &&
                (rd_resp_id_r[master_idx] == req_id_value)) begin
                read_id_conflict = 1'b1;
            end
            if (inflight_valid_r && !inflight_is_write_r &&
                (inflight_master_r == master_idx[7:0]) &&
                (inflight_id_r == req_id_value)) begin
                read_id_conflict = 1'b1;
            end
            for (depth_idx = 0; depth_idx < READ_FIFO_DEPTH; depth_idx = depth_idx + 1) begin
                slot_value = rd_slot_index(master_idx, depth_idx);
                if (rd_q_valid[slot_value] &&
                    (rd_q_id[slot_value] == req_id_value)) begin
                    read_id_conflict = 1'b1;
                end
            end
        end
    endfunction

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
        dispatch_fifo_slot_w = 0;
        dispatch_slot_w = 0;
        core_up_req_valid_w = 1'b0;
        core_up_req_write_w = 1'b0;
        core_up_req_addr_w = {ADDR_BITS{1'b0}};
        core_up_req_id_w = {ID_BITS{1'b0}};
        core_up_req_total_size_w = 8'd0;
        core_up_req_wdata_w = {LINE_BITS{1'b0}};
        core_up_req_wstrb_w = {LINE_BYTES{1'b0}};
        core_up_req_bypass_w = 1'b0;
        total_read_outstanding_w = 0;
        total_write_outstanding_w = 0;
        rd_select_found_w = 1'b0;
        rd_select_master_w = 8'd0;
        wr_select_found_w = 1'b0;
        wr_select_master_w = 8'd0;
        compat_quiescent_w = !inflight_valid_r;
        line_write_hazard_w = 1'b0;
        accept_blocked_w = reconfig_busy || maintenance_pending_w;
        dcache_same_cycle_accept_w = 1'b0;
        core_mode_req_w = active_mode;
        core_offset_req_w = active_offset;
        core_invalidate_all_valid_w = 1'b0;
        core_invalidate_line_valid_w = 1'b0;

        for (flat_idx = 0; flat_idx < NUM_READ_MASTERS; flat_idx = flat_idx + 1) begin
            total_read_outstanding_w = total_read_outstanding_w + rd_q_count[flat_idx];
            if (rd_resp_valid_r[flat_idx]) begin
                total_read_outstanding_w = total_read_outstanding_w + 1;
            end
            if ((rd_q_count[flat_idx] != 0) ||
                rd_resp_valid_r[flat_idx] ||
                read_req_ready_r[flat_idx]) begin
                compat_quiescent_w = 1'b0;
            end
        end
        if (inflight_valid_r && !inflight_is_write_r) begin
            total_read_outstanding_w = total_read_outstanding_w + 1;
        end
        for (flat_idx = 0; flat_idx < NUM_WRITE_MASTERS; flat_idx = flat_idx + 1) begin
            total_write_outstanding_w = total_write_outstanding_w + wr_q_count[flat_idx];
            if (wr_resp_valid_r[flat_idx]) begin
                total_write_outstanding_w = total_write_outstanding_w + 1;
            end
            if ((wr_q_count[flat_idx] != 0) ||
                wr_resp_valid_r[flat_idx] ||
                write_req_ready_r[flat_idx]) begin
                compat_quiescent_w = 1'b0;
            end
            if (invalidate_line_valid &&
                write_req_valid[flat_idx] &&
                ((write_req_addr[(flat_idx * ADDR_BITS) +: ADDR_BITS] >> LINE_OFFSET_BITS) ==
                 (invalidate_line_addr >> LINE_OFFSET_BITS))) begin
                line_write_hazard_w = 1'b1;
            end
            if (invalidate_line_valid &&
                wr_resp_valid_r[flat_idx] &&
                ((wr_resp_addr_r[flat_idx] >> LINE_OFFSET_BITS) ==
                 (invalidate_line_addr >> LINE_OFFSET_BITS))) begin
                line_write_hazard_w = 1'b1;
            end
        end
        if (inflight_valid_r && inflight_is_write_r) begin
            total_write_outstanding_w = total_write_outstanding_w + 1;
        end
        if (invalidate_line_valid &&
            inflight_valid_r &&
            inflight_is_write_r &&
            ((inflight_addr_r >> LINE_OFFSET_BITS) ==
             (invalidate_line_addr >> LINE_OFFSET_BITS))) begin
            line_write_hazard_w = 1'b1;
        end
        for (flat_idx = 0; flat_idx < WR_SLOT_COUNT; flat_idx = flat_idx + 1) begin
            if (invalidate_line_valid &&
                wr_q_valid[flat_idx] &&
                ((wr_q_addr[flat_idx] >> LINE_OFFSET_BITS) ==
                 (invalidate_line_addr >> LINE_OFFSET_BITS))) begin
                line_write_hazard_w = 1'b1;
            end
        end

        if ((read_req_ready_r == {NUM_READ_MASTERS{1'b0}}) && !accept_blocked_w) begin
            for (rr_off = 0; rr_off < NUM_READ_MASTERS; rr_off = rr_off + 1) begin
                next_port = rd_capture_rr_r + rr_off;
                if (next_port >= NUM_READ_MASTERS) begin
                    next_port = next_port - NUM_READ_MASTERS;
                end
                if (!rd_select_found_w &&
                    read_req_valid[next_port] &&
                    (rd_q_count[next_port] < READ_FIFO_DEPTH) &&
                    (total_read_outstanding_w < MAX_OUTSTANDING) &&
                    !read_id_conflict(next_port,
                        read_req_id[(next_port * ID_BITS) +: ID_BITS])) begin
                    rd_select_found_w = 1'b1;
                    rd_select_master_w = next_port[7:0];
                end
            end
        end

        if ((write_req_ready_r == {NUM_WRITE_MASTERS{1'b0}}) && !accept_blocked_w) begin
            for (rr_off = 0; rr_off < NUM_WRITE_MASTERS; rr_off = rr_off + 1) begin
                next_port = wr_capture_rr_r + rr_off;
                if (next_port >= NUM_WRITE_MASTERS) begin
                    next_port = next_port - NUM_WRITE_MASTERS;
                end
                if (!wr_select_found_w &&
                    write_req_valid[next_port] &&
                    (wr_q_count[next_port] < WRITE_FIFO_DEPTH) &&
                    (total_write_outstanding_w < MAX_WRITE_OUTSTANDING)) begin
                    wr_select_found_w = 1'b1;
                    wr_select_master_w = next_port[7:0];
                end
            end
        end

        // Match the C++ interconnect contract: reconfiguration / invalidate-all
        // first drains compat-local queueing, then the request is forwarded to
        // the core so the core only sees maintenance after the outer boundary is
        // already quiescent.
        if (maintenance_pending_w && compat_quiescent_w) begin
            core_mode_req_w = mode_req;
            core_offset_req_w = (mode_req == MODE_MAPPED) ?
                                llc_mapped_offset_req : active_offset;
            core_invalidate_all_valid_w = invalidate_all_valid;
            core_invalidate_line_valid_w = invalidate_line_valid &&
                                           !line_write_hazard_w;
        end

        // Keep the C++ dcache-read same-cycle accept behavior. Other read
        // masters still use ready-first sticky-grant semantics.
        if (!accept_blocked_w &&
            rd_select_found_w &&
            (rd_select_master_w == MASTER_DCACHE_R) &&
            read_req_valid[MASTER_DCACHE_R]) begin
            dcache_same_cycle_accept_w = 1'b1;
        end

        if (!inflight_valid_r) begin
            for (rr_off = 0; rr_off < TOTAL_PORTS; rr_off = rr_off + 1) begin
                next_port = rr_ptr_r + rr_off;
                if (next_port >= TOTAL_PORTS) begin
                    next_port = next_port - TOTAL_PORTS;
                end
                if (!dispatch_found_w) begin
                    if (next_port < NUM_READ_MASTERS) begin
                        if ((rd_q_count[next_port] != 0) &&
                            !rd_resp_valid_r[next_port]) begin
                            dispatch_fifo_slot_w = rd_slot_index(next_port,
                                                                 rd_q_head[next_port]);
                            dispatch_found_w = 1'b1;
                            dispatch_is_write_w = 1'b0;
                            dispatch_master_w = next_port[7:0];
                            dispatch_slot_w = next_port;
                            core_up_req_valid_w = 1'b1;
                            core_up_req_write_w = 1'b0;
                            core_up_req_addr_w = rd_q_addr[dispatch_fifo_slot_w];
                            core_up_req_id_w = rd_q_id[dispatch_fifo_slot_w];
                            core_up_req_total_size_w = rd_q_size[dispatch_fifo_slot_w];
                            core_up_req_wdata_w = {LINE_BITS{1'b0}};
                            core_up_req_wstrb_w = {LINE_BYTES{1'b0}};
                            core_up_req_bypass_w = rd_q_bypass[dispatch_fifo_slot_w];
                        end
                    end else begin
                        flat_idx = next_port - NUM_READ_MASTERS;
                        if ((wr_q_count[flat_idx] != 0) &&
                            !wr_resp_valid_r[flat_idx]) begin
                            dispatch_fifo_slot_w = wr_slot_index(flat_idx,
                                                                 wr_q_head[flat_idx]);
                            dispatch_found_w = 1'b1;
                            dispatch_is_write_w = 1'b1;
                            dispatch_master_w = flat_idx[7:0];
                            dispatch_slot_w = next_port;
                            core_up_req_valid_w = 1'b1;
                            core_up_req_write_w = 1'b1;
                            core_up_req_addr_w = wr_q_addr[dispatch_fifo_slot_w];
                            core_up_req_id_w = wr_q_id[dispatch_fifo_slot_w];
                            core_up_req_total_size_w = wr_q_size[dispatch_fifo_slot_w];
                            core_up_req_wdata_w = wr_q_wdata[dispatch_fifo_slot_w];
                            core_up_req_wstrb_w = wr_q_wstrb[dispatch_fifo_slot_w];
                            core_up_req_bypass_w = wr_q_bypass[dispatch_fifo_slot_w];
                        end
                    end
                end
            end
        end

        read_req_ready = {NUM_READ_MASTERS{1'b0}};
        read_req_accepted = read_req_accepted_r;
        read_req_accepted_id = read_req_accepted_id_r;
        read_resp_valid = {NUM_READ_MASTERS{1'b0}};
        read_resp_data = {(NUM_READ_MASTERS*READ_RESP_BITS){1'b0}};
        read_resp_id = {(NUM_READ_MASTERS*ID_BITS){1'b0}};
        for (flat_idx = 0; flat_idx < NUM_READ_MASTERS; flat_idx = flat_idx + 1) begin
            read_req_ready[flat_idx] = (read_req_ready_r[flat_idx] ||
                                       (dcache_same_cycle_accept_w &&
                                        (flat_idx == MASTER_DCACHE_R))) &&
                                       !accept_blocked_w &&
                                       (rd_q_count[flat_idx] < READ_FIFO_DEPTH) &&
                                       (total_read_outstanding_w < MAX_OUTSTANDING) &&
                                       !read_id_conflict(flat_idx,
                                           read_req_id[(flat_idx * ID_BITS) +: ID_BITS]);
            read_resp_valid[flat_idx] = rd_resp_valid_r[flat_idx];
            read_resp_data[(flat_idx * READ_RESP_BITS) +: READ_RESP_BITS] =
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
            write_req_ready[flat_idx] = write_req_ready_r[flat_idx] &&
                                        !accept_blocked_w &&
                                        (wr_q_count[flat_idx] < WRITE_FIFO_DEPTH) &&
                                        (total_write_outstanding_w < MAX_WRITE_OUTSTANDING);
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
        .USE_SMIC12_STORES(USE_SMIC12_STORES),
        .TABLE_READ_LATENCY(TABLE_READ_LATENCY),
        .READ_RESP_BYTES  (READ_RESP_BYTES),
        .READ_RESP_BITS   (READ_RESP_BITS)
    ) core (
        .clk                   (clk),
        .rst_n                 (rst_n),
        .mode_req              (core_mode_req_w),
        .llc_mapped_offset_req (core_offset_req_w),
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
        .up_resp_code          (core_up_resp_code_w),
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
        .cache_resp_code       (cache_resp_code),
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
        .bypass_resp_code      (bypass_resp_code),
        .invalidate_line_valid (core_invalidate_line_valid_w),
        .invalidate_line_addr  (invalidate_line_addr),
        .invalidate_line_accepted(invalidate_line_accepted),
        .invalidate_all_valid  (core_invalidate_all_valid_w),
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
            rd_capture_rr_r <= 8'd0;
            wr_capture_rr_r <= 8'd0;
            inflight_valid_r <= 1'b0;
            inflight_is_write_r <= 1'b0;
            inflight_master_r <= 8'd0;
            inflight_id_r <= {ID_BITS{1'b0}};
            inflight_addr_r <= {ADDR_BITS{1'b0}};
            read_req_accepted_r <= {NUM_READ_MASTERS{1'b0}};
            read_req_accepted_id_r <= {(NUM_READ_MASTERS*ID_BITS){1'b0}};
            write_req_accepted_r <= {NUM_WRITE_MASTERS{1'b0}};
            read_req_ready_r <= {NUM_READ_MASTERS{1'b0}};
            write_req_ready_r <= {NUM_WRITE_MASTERS{1'b0}};
            for (idx = 0; idx < NUM_READ_MASTERS; idx = idx + 1) begin
                rd_q_head[idx] <= 8'd0;
                rd_q_tail[idx] <= 8'd0;
                rd_q_count[idx] <= 8'd0;
                rd_resp_valid_r[idx] <= 1'b0;
                rd_resp_data_r[idx] <= {READ_RESP_BITS{1'b0}};
                rd_resp_id_r[idx] <= {ID_BITS{1'b0}};
            end
            for (idx = 0; idx < NUM_WRITE_MASTERS; idx = idx + 1) begin
                wr_q_head[idx] <= 8'd0;
                wr_q_tail[idx] <= 8'd0;
                wr_q_count[idx] <= 8'd0;
                wr_resp_valid_r[idx] <= 1'b0;
                wr_resp_id_r[idx] <= {ID_BITS{1'b0}};
                wr_resp_code_r[idx] <= WRITE_RESP_OKAY;
                wr_resp_addr_r[idx] <= {ADDR_BITS{1'b0}};
            end
            for (idx = 0; idx < RD_SLOT_COUNT; idx = idx + 1) begin
                rd_q_valid[idx] <= 1'b0;
                rd_q_addr[idx] <= {ADDR_BITS{1'b0}};
                rd_q_size[idx] <= 8'd0;
                rd_q_id[idx] <= {ID_BITS{1'b0}};
                rd_q_bypass[idx] <= 1'b0;
            end
            for (idx = 0; idx < WR_SLOT_COUNT; idx = idx + 1) begin
                wr_q_valid[idx] <= 1'b0;
                wr_q_addr[idx] <= {ADDR_BITS{1'b0}};
                wr_q_wdata[idx] <= {LINE_BITS{1'b0}};
                wr_q_wstrb[idx] <= {LINE_BYTES{1'b0}};
                wr_q_size[idx] <= 8'd0;
                wr_q_id[idx] <= {ID_BITS{1'b0}};
                wr_q_bypass[idx] <= 1'b0;
            end
        end else begin
            read_req_accepted_r <= {NUM_READ_MASTERS{1'b0}};
            read_req_accepted_id_r <= {(NUM_READ_MASTERS*ID_BITS){1'b0}};
            write_req_accepted_r <= {NUM_WRITE_MASTERS{1'b0}};

            if (accept_blocked_w) begin
                read_req_ready_r <= {NUM_READ_MASTERS{1'b0}};
                write_req_ready_r <= {NUM_WRITE_MASTERS{1'b0}};
            end

            for (idx = 0; idx < NUM_READ_MASTERS; idx = idx + 1) begin
                if (read_req_ready_r[idx] && !read_req_valid[idx]) begin
                    read_req_ready_r[idx] <= 1'b0;
                end
                if (rd_resp_valid_r[idx] && read_resp_ready[idx]) begin
                    rd_resp_valid_r[idx] <= 1'b0;
                end
                if (read_req_valid[idx] && read_req_ready[idx]) begin
                    slot_idx = rd_slot_index(idx, rd_q_tail[idx]);
                    rd_q_valid[slot_idx] <= 1'b1;
                    rd_q_addr[slot_idx] <= read_req_addr[(idx * ADDR_BITS) +: ADDR_BITS];
                    rd_q_size[slot_idx] <= read_req_total_size[(idx * 8) +: 8];
                    rd_q_id[slot_idx] <= read_req_id[(idx * ID_BITS) +: ID_BITS];
                    rd_q_bypass[slot_idx] <= read_req_bypass[idx];
                    rd_q_tail[idx] <= next_rd_ptr(rd_q_tail[idx]);
                    rd_q_count[idx] <= rd_q_count[idx] + 8'd1;
                    read_req_accepted_r[idx] <= 1'b1;
                    read_req_ready_r[idx] <= 1'b0;
                    rd_capture_rr_r <= idx[7:0] + 8'd1;
                    read_req_accepted_id_r[(idx * ID_BITS) +: ID_BITS] <=
                        read_req_id[(idx * ID_BITS) +: ID_BITS];
                end
            end

            for (idx = 0; idx < NUM_WRITE_MASTERS; idx = idx + 1) begin
                if (write_req_ready_r[idx] && !write_req_valid[idx]) begin
                    write_req_ready_r[idx] <= 1'b0;
                end
                if (wr_resp_valid_r[idx] && write_resp_ready[idx]) begin
                    wr_resp_valid_r[idx] <= 1'b0;
                end
                if (write_req_valid[idx] && write_req_ready[idx]) begin
                    slot_idx = wr_slot_index(idx, wr_q_tail[idx]);
                    wr_q_valid[slot_idx] <= 1'b1;
                    wr_q_addr[slot_idx] <= write_req_addr[(idx * ADDR_BITS) +: ADDR_BITS];
                    wr_q_wdata[slot_idx] <= write_req_wdata[(idx * LINE_BITS) +: LINE_BITS];
                    wr_q_wstrb[slot_idx] <= write_req_wstrb[(idx * LINE_BYTES) +: LINE_BYTES];
                    wr_q_size[slot_idx] <= write_req_total_size[(idx * 8) +: 8];
                    wr_q_id[slot_idx] <= write_req_id[(idx * ID_BITS) +: ID_BITS];
                    wr_q_bypass[slot_idx] <= write_req_bypass[idx];
                    wr_q_tail[idx] <= next_wr_ptr(wr_q_tail[idx]);
                    wr_q_count[idx] <= wr_q_count[idx] + 8'd1;
                    write_req_accepted_r[idx] <= 1'b1;
                    write_req_ready_r[idx] <= 1'b0;
                    wr_capture_rr_r <= idx[7:0] + 8'd1;
                end
            end

            if (!accept_blocked_w &&
                !dcache_same_cycle_accept_w &&
                (read_req_ready_r == {NUM_READ_MASTERS{1'b0}}) &&
                rd_select_found_w) begin
                read_req_ready_r[rd_select_master_w] <= 1'b1;
            end
            if (!accept_blocked_w && (write_req_ready_r == {NUM_WRITE_MASTERS{1'b0}}) &&
                wr_select_found_w) begin
                write_req_ready_r[wr_select_master_w] <= 1'b1;
            end

            if (core_up_req_valid_w && core_up_req_ready_w) begin
                inflight_valid_r <= 1'b1;
                inflight_is_write_r <= dispatch_is_write_w;
                inflight_master_r <= dispatch_master_w;
                inflight_id_r <= core_up_req_id_w;
                inflight_addr_r <= core_up_req_addr_w;
                rr_ptr_r <= dispatch_slot_w[7:0] + 8'd1;
                if (dispatch_is_write_w) begin
                    wr_q_valid[dispatch_fifo_slot_w] <= 1'b0;
                    wr_q_head[dispatch_master_w] <= next_wr_ptr(wr_q_head[dispatch_master_w]);
                    wr_q_count[dispatch_master_w] <= wr_q_count[dispatch_master_w] - 8'd1;
                end else begin
                    rd_q_valid[dispatch_fifo_slot_w] <= 1'b0;
                    rd_q_head[dispatch_master_w] <= next_rd_ptr(rd_q_head[dispatch_master_w]);
                    rd_q_count[dispatch_master_w] <= rd_q_count[dispatch_master_w] - 8'd1;
                end
            end

            // Move the accepted core response back into the owning read/write
            // response slot and free the inflight marker.
            if (core_up_resp_valid_w && core_up_resp_ready_w && inflight_valid_r) begin
                if (inflight_is_write_r) begin
                    wr_resp_valid_r[inflight_master_r] <= 1'b1;
                    wr_resp_id_r[inflight_master_r] <= inflight_id_r;
                    wr_resp_code_r[inflight_master_r] <= core_up_resp_code_w;
                    wr_resp_addr_r[inflight_master_r] <= inflight_addr_r;
                end else begin
                    rd_resp_valid_r[inflight_master_r] <= 1'b1;
                    rd_resp_data_r[inflight_master_r] <= core_up_resp_rdata_w;
                    rd_resp_id_r[inflight_master_r] <= core_up_resp_id_w;
                end
                inflight_valid_r <= 1'b0;
                inflight_addr_r <= {ADDR_BITS{1'b0}};
            end
        end
    end

endmodule
