`timescale 1ns / 1ps
`include "axi_llc_params.vh"

// Compatibility layer between the C++-style multi-master external boundary
// and the internal RTL core.
//
// Responsibilities:
//   - Hold per-master queued upstream requests
//   - Return accepted / accepted_id / independent write responses
//   - Feed cacheable requests, mode1 bypass requests, and mapped-window
//     requests into axi_llc_subsystem_core
//   - Feed only mode0/3 and mode2-window-outside direct-bypass requests to
//     the lower bypass port without occupying a core slot
//   - Drain local queues before reconfiguration / invalidate-all reaches core
//
// This layer does not translate to AXI and does not own resident storage.
// It is also the first place where the single-flow core is relaxed:
// direct-bypass traffic from mode0/3 and mode2-window-outside can progress
// independently of the core path.
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
    parameter USE_SMIC12_STORES = 1,
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
    output                                  bypass_req_mode2_ddr_aligned,
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
    localparam integer READ_RESP_QUEUE_DEPTH = MAX_OUTSTANDING;
    localparam integer RD_SLOT_COUNT = NUM_READ_MASTERS * READ_FIFO_DEPTH;
    localparam integer WR_SLOT_COUNT = NUM_WRITE_MASTERS * WRITE_FIFO_DEPTH;
    localparam integer RD_RESP_SLOT_COUNT = NUM_READ_MASTERS * READ_RESP_QUEUE_DEPTH;
    localparam [1:0] WRITE_RESP_OKAY = 2'b00;
    localparam [MODE_BITS-1:0] MODE_OFF = {{(MODE_BITS-2){1'b0}}, 2'b00};
    localparam [MODE_BITS-1:0] MODE_CACHE =
        {{(MODE_BITS-2){1'b0}}, 2'b01};
    localparam [MODE_BITS-1:0] MODE_MAPPED =
        {{(MODE_BITS-2){1'b0}}, 2'b10};
    localparam integer DIRECT_SLOT_COUNT = MAX_OUTSTANDING;
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
    reg [7:0]                    rd_resp_q_head [0:NUM_READ_MASTERS-1];
    reg [7:0]                    rd_resp_q_tail [0:NUM_READ_MASTERS-1];
    reg [7:0]                    rd_resp_q_count [0:NUM_READ_MASTERS-1];
    reg [READ_RESP_BITS-1:0]     rd_resp_q_data [0:RD_RESP_SLOT_COUNT-1];
    reg [ID_BITS-1:0]            rd_resp_q_id [0:RD_RESP_SLOT_COUNT-1];
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
    reg [7:0]                    direct_rr_ptr_r;
    reg                          core_slot_valid_r [0:MAX_OUTSTANDING-1];
    reg                          core_slot_is_write_r [0:MAX_OUTSTANDING-1];
    reg [7:0]                    core_slot_master_r [0:MAX_OUTSTANDING-1];
    reg [ID_BITS-1:0]            core_slot_orig_id_r [0:MAX_OUTSTANDING-1];
    reg [ADDR_BITS-1:0]          core_slot_addr_r [0:MAX_OUTSTANDING-1];

    // Direct bypass slots. These requests own the lower bypass lifecycle
    // after leaving the FIFO or after handoff from the core. For mode1
    // bypass miss / write-through, compat can hold a pending-issue owner
    // (`issued=0`) before the lower handshake arrives.
    reg                          direct_slot_valid_r [0:DIRECT_SLOT_COUNT-1];
    reg                          direct_slot_issued_r [0:DIRECT_SLOT_COUNT-1];
    reg                          direct_slot_from_core_r [0:DIRECT_SLOT_COUNT-1];
    reg                          direct_slot_is_write_r [0:DIRECT_SLOT_COUNT-1];
    reg [7:0]                    direct_slot_master_r [0:DIRECT_SLOT_COUNT-1];
    reg [ID_BITS-1:0]            direct_slot_orig_id_r [0:DIRECT_SLOT_COUNT-1];
    reg [ADDR_BITS-1:0]          direct_slot_addr_r [0:DIRECT_SLOT_COUNT-1];
    reg [7:0]                    direct_slot_size_r [0:DIRECT_SLOT_COUNT-1];
    reg [LINE_BITS-1:0]          direct_slot_wdata_r [0:DIRECT_SLOT_COUNT-1];
    reg [LINE_BYTES-1:0]         direct_slot_wstrb_r [0:DIRECT_SLOT_COUNT-1];

    // Registered core request launch stage. This cuts the long
    // compat-arbitration -> core-routing -> valid/data-store input path.
    reg                          core_req_stage_valid_r;
    reg                          core_req_stage_is_write_r;
    reg [7:0]                    core_req_stage_master_r;
    reg [7:0]                    core_req_stage_slot_r;
    reg [7:0]                    core_req_stage_fifo_slot_r;
    reg [ID_BITS-1:0]            core_req_stage_orig_id_r;
    reg [ADDR_BITS-1:0]          core_req_stage_addr_r;
    reg [7:0]                    core_req_stage_size_r;
    reg [LINE_BITS-1:0]          core_req_stage_wdata_r;
    reg [LINE_BYTES-1:0]         core_req_stage_wstrb_r;
    reg                          core_req_stage_bypass_r;
    wire                         core_req_stage_pop_w;
    wire                         core_req_stage_can_push_w;

    // Single registered request presented to the core in the current cycle.
    wire                         core_up_req_valid_w;
    wire                         core_up_req_ready_w;
    wire                         core_up_req_write_w;
    wire [ADDR_BITS-1:0]         core_up_req_addr_w;
    wire [ID_BITS-1:0]           core_up_req_id_w;
    wire [7:0]                   core_up_req_total_size_w;
    wire [LINE_BITS-1:0]         core_up_req_wdata_w;
    wire [LINE_BYTES-1:0]        core_up_req_wstrb_w;
    wire                         core_up_req_bypass_w;
    wire                         core_up_resp_valid_w;
    wire                         core_up_resp_ready_w;
    wire [READ_RESP_BITS-1:0]    core_up_resp_rdata_w;
    wire [ID_BITS-1:0]           core_up_resp_id_w;
    wire [1:0]                   core_up_resp_code_w;
    wire [`AXI_LLC_MAX_OUTSTANDING-1:0] core_victim_line_valid_w;
    wire [(`AXI_LLC_MAX_OUTSTANDING*ADDR_BITS)-1:0] core_victim_line_addr_w;

    reg                          dispatch_found_w;
    reg                          dispatch_is_write_w;
    reg [7:0]                    dispatch_master_w;
    integer                      dispatch_fifo_slot_w;
    integer                      dispatch_slot_w;
    reg                          core_slot_free_found_w;
    reg [7:0]                    core_slot_free_w;
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

    reg                          direct_slot_free_found_w;
    reg [7:0]                    direct_slot_free_w;
    reg                          direct_dispatch_found_w;
    reg                          direct_dispatch_is_write_w;
    reg [7:0]                    direct_dispatch_master_w;
    integer                      direct_dispatch_fifo_slot_w;
    reg [7:0]                    direct_dispatch_slot_w;
    reg [ADDR_BITS-1:0]          direct_dispatch_addr_w;
    reg [ID_BITS-1:0]            direct_dispatch_id_w;
    reg [7:0]                    direct_dispatch_size_w;
    reg [LINE_BITS-1:0]          direct_dispatch_wdata_w;
    reg [LINE_BYTES-1:0]         direct_dispatch_wstrb_w;
    reg                          core_resp_match_w;
    reg [7:0]                    core_resp_slot_w;
    reg                          core_resp_is_write_w;
    reg [7:0]                    core_resp_master_w;
    reg [ID_BITS-1:0]            core_resp_orig_id_w;
    reg [ADDR_BITS-1:0]          core_resp_addr_w;
    reg                          core_resp_target_busy_w;
    reg                          direct_resp_match_w;
    reg [7:0]                    direct_resp_slot_w;
    reg                          direct_resp_is_write_w;
    reg [7:0]                    direct_resp_master_w;
    reg [ID_BITS-1:0]            direct_resp_orig_id_w;
    reg [ADDR_BITS-1:0]          direct_resp_addr_w;
    reg                          direct_resp_target_busy_w;
    reg                          direct_resp_conflict_w;
    wire                         direct_resp_accept_w;
    reg                          core_bypass_slot_found_w;
    reg [7:0]                    core_bypass_slot_w;
    reg                          direct_issue_found_w;
    reg [7:0]                    direct_issue_slot_w;
    wire                         core_bypass_resp_ready_w;
    wire                         core_bypass_req_ready_w;
    wire                         direct_bypass_req_valid_w;
    wire                         direct_bypass_req_handshake_w;
    wire                         core_bypass_handoff_w;

    // The core owns mode1 bypass semantics so resident lookup / write-hit
    // shadow update stay aligned with the C++ model. Compat keeps a separate
    // direct-bypass side path only for mode0/3 and mode2 window-outside
    // traffic, and owns the post-lookup lower lifecycle once a mode1 bypass
    // miss / write-through is handed off.
    wire                         core_bypass_req_valid_w;
    wire                         core_bypass_req_write_w;
    wire [ADDR_BITS-1:0]        core_bypass_req_addr_w;
    wire [ID_BITS-1:0]          core_bypass_req_id_w;
    wire [7:0]                  core_bypass_req_size_w;
    wire [LINE_BITS-1:0]        core_bypass_req_wdata_w;
    wire [LINE_BYTES-1:0]       core_bypass_req_wstrb_w;

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

    function integer next_rd_resp_ptr;
        input integer ptr_idx;
        begin
            if (ptr_idx == (READ_RESP_QUEUE_DEPTH - 1)) begin
                next_rd_resp_ptr = 0;
            end else begin
                next_rd_resp_ptr = ptr_idx + 1;
            end
        end
    endfunction

    function integer rd_resp_slot_index;
        input integer master_idx;
        input integer ptr_idx;
        begin
            rd_resp_slot_index = master_idx * READ_RESP_QUEUE_DEPTH + ptr_idx;
        end
    endfunction

    function request_is_mmio;
        input [ADDR_BITS-1:0] addr_value;
        input [7:0]           total_size_value;
        reg [ADDR_BITS:0]     end_value;
        reg [ADDR_BITS:0]     mmio_limit_value;
        begin
            end_value = {1'b0, addr_value} +
                        {{(ADDR_BITS-7){1'b0}}, total_size_value} +
                        {{ADDR_BITS{1'b0}}, 1'b1};
            mmio_limit_value = {1'b0, MMIO_BASE} + {1'b0, MMIO_SIZE};
            request_is_mmio = (addr_value >= MMIO_BASE) &&
                              (end_value <= mmio_limit_value);
        end
    endfunction

    function request_in_mapped_window;
        input [ADDR_BITS-1:0] offset_value;
        input [ADDR_BITS-1:0] addr_value;
        input [7:0]           total_size_value;
        reg [ADDR_BITS:0]     end_value;
        reg [ADDR_BITS:0]     base_value;
        reg [ADDR_BITS:0]     limit_value;
        begin
            base_value = {1'b0, offset_value};
            limit_value = {1'b0, offset_value} + WINDOW_BYTES;
            end_value = {1'b0, addr_value} +
                        {{(ADDR_BITS-7){1'b0}}, total_size_value} +
                        {{ADDR_BITS{1'b0}}, 1'b1};
            request_in_mapped_window =
                ({1'b0, addr_value} >= base_value) && (end_value <= limit_value);
        end
    endfunction

    function request_uses_direct_bypass;
        input [MODE_BITS-1:0] mode_value;
        input [ADDR_BITS-1:0] offset_value;
        input [ADDR_BITS-1:0] addr_value;
        input [7:0]           total_size_value;
        input                 bypass_value;
        begin
            request_uses_direct_bypass = 1'b1;
            if (mode_value == MODE_CACHE) begin
                // Mode1 bypass still enters the core so the core can perform
                // resident lookup and write-hit shadow update, matching the
                // current C++ AXI_LLC contract.
                request_uses_direct_bypass = 1'b0;
            end else if (mode_value == MODE_MAPPED) begin
                request_uses_direct_bypass =
                    !request_in_mapped_window(offset_value,
                                              addr_value,
                                              total_size_value);
            end else if (mode_value == MODE_OFF) begin
                request_uses_direct_bypass = 1'b1;
            end else begin
                request_uses_direct_bypass = 1'b1;
            end
        end
    endfunction

    function request_needs_mode2_ddr_aligned;
        input [MODE_BITS-1:0] mode_value;
        input [ADDR_BITS-1:0] offset_value;
        input [ADDR_BITS-1:0] addr_value;
        input [7:0]           total_size_value;
        begin
            request_needs_mode2_ddr_aligned =
                (mode_value == MODE_MAPPED) &&
                !request_in_mapped_window(offset_value,
                                          addr_value,
                                          total_size_value) &&
                !((addr_value >= MMIO_BASE) &&
                  (addr_value < (MMIO_BASE + MMIO_SIZE)));
        end
    endfunction

    function read_resp_has_room;
        input integer master_idx;
        begin
            read_resp_has_room = (!rd_resp_valid_r[master_idx] &&
                                  (rd_resp_q_count[master_idx] == 0)) ||
                                 (rd_resp_q_count[master_idx] < READ_RESP_QUEUE_DEPTH);
        end
    endfunction

    function core_path_line_hazard;
        input [ADDR_BITS-1:0] addr_value;
        integer depth_idx;
        begin
            core_path_line_hazard = 1'b0;
            for (depth_idx = 0; depth_idx < MAX_OUTSTANDING; depth_idx = depth_idx + 1) begin
                if (core_victim_line_valid_w[depth_idx] &&
                    ((core_victim_line_addr_w[(depth_idx * ADDR_BITS) +: ADDR_BITS] >>
                      LINE_OFFSET_BITS) == (addr_value >> LINE_OFFSET_BITS))) begin
                    core_path_line_hazard = 1'b1;
                end
            end
        end
    endfunction

    function dispatch_path_line_hazard;
        input [ADDR_BITS-1:0] addr_value;
        integer depth_idx;
        begin
            dispatch_path_line_hazard = core_path_line_hazard(addr_value);
            for (depth_idx = 0; depth_idx < MAX_OUTSTANDING; depth_idx = depth_idx + 1) begin
                if (core_slot_valid_r[depth_idx] &&
                    ((core_slot_addr_r[depth_idx] >> LINE_OFFSET_BITS) ==
                     (addr_value >> LINE_OFFSET_BITS))) begin
                    dispatch_path_line_hazard = 1'b1;
                end
            end
            if (core_req_stage_valid_r &&
                ((core_req_stage_addr_r >> LINE_OFFSET_BITS) ==
                 (addr_value >> LINE_OFFSET_BITS))) begin
                dispatch_path_line_hazard = 1'b1;
            end
        end
    endfunction

    function core_path_request;
        input [ADDR_BITS-1:0] addr_value;
        input [7:0]           size_value;
        input                 bypass_value;
        begin
            core_path_request = !request_uses_direct_bypass(active_mode,
                                                            active_offset,
                                                            addr_value,
                                                            size_value,
                                                            bypass_value);
        end
    endfunction

    function local_write_line_pending;
        input [ADDR_BITS-1:0] addr_value;
        integer depth_idx;
        begin
            local_write_line_pending = 1'b0;
            for (depth_idx = 0; depth_idx < NUM_WRITE_MASTERS; depth_idx = depth_idx + 1) begin
                if (write_req_valid[depth_idx] &&
                    ((write_req_addr[(depth_idx * ADDR_BITS) +: ADDR_BITS] >>
                      LINE_OFFSET_BITS) == (addr_value >> LINE_OFFSET_BITS))) begin
                    local_write_line_pending = 1'b1;
                end
                if (wr_resp_valid_r[depth_idx] &&
                    ((wr_resp_addr_r[depth_idx] >> LINE_OFFSET_BITS) ==
                     (addr_value >> LINE_OFFSET_BITS))) begin
                    local_write_line_pending = 1'b1;
                end
            end
            for (depth_idx = 0; depth_idx < WR_SLOT_COUNT; depth_idx = depth_idx + 1) begin
                if (wr_q_valid[depth_idx] &&
                    ((wr_q_addr[depth_idx] >> LINE_OFFSET_BITS) ==
                     (addr_value >> LINE_OFFSET_BITS))) begin
                    local_write_line_pending = 1'b1;
                end
            end
            for (depth_idx = 0; depth_idx < MAX_OUTSTANDING; depth_idx = depth_idx + 1) begin
                if (core_slot_valid_r[depth_idx] &&
                    core_slot_is_write_r[depth_idx] &&
                    ((core_slot_addr_r[depth_idx] >> LINE_OFFSET_BITS) ==
                     (addr_value >> LINE_OFFSET_BITS))) begin
                    local_write_line_pending = 1'b1;
                end
            end
            if (core_req_stage_valid_r &&
                core_req_stage_is_write_r &&
                ((core_req_stage_addr_r >> LINE_OFFSET_BITS) ==
                 (addr_value >> LINE_OFFSET_BITS))) begin
                local_write_line_pending = 1'b1;
            end
            for (depth_idx = 0; depth_idx < DIRECT_SLOT_COUNT; depth_idx = depth_idx + 1) begin
                if (direct_slot_valid_r[depth_idx] &&
                    direct_slot_is_write_r[depth_idx] &&
                    ((direct_slot_addr_r[depth_idx] >> LINE_OFFSET_BITS) ==
                     (addr_value >> LINE_OFFSET_BITS))) begin
                    local_write_line_pending = 1'b1;
                end
            end
        end
    endfunction

    function queued_core_read_line_pending;
        input [ADDR_BITS-1:0] addr_value;
        integer depth_idx;
        begin
            queued_core_read_line_pending = 1'b0;
            for (depth_idx = 0; depth_idx < RD_SLOT_COUNT; depth_idx = depth_idx + 1) begin
                if (rd_q_valid[depth_idx] &&
                    core_path_request(rd_q_addr[depth_idx],
                                      rd_q_size[depth_idx],
                                      rd_q_bypass[depth_idx]) &&
                    ((rd_q_addr[depth_idx] >> LINE_OFFSET_BITS) ==
                     (addr_value >> LINE_OFFSET_BITS))) begin
                    queued_core_read_line_pending = 1'b1;
                end
            end
        end
    endfunction

    function read_capture_line_hazard;
        input [ADDR_BITS-1:0] addr_value;
        begin
            read_capture_line_hazard = dispatch_path_line_hazard(addr_value) ||
                                       queued_core_read_line_pending(addr_value) ||
                                       local_write_line_pending(addr_value);
        end
    endfunction

    function read_master_response_busy;
        input integer master_idx;
        integer depth_idx;
        begin
            read_master_response_busy = 1'b0;
            if (rd_resp_valid_r[master_idx] || (rd_resp_q_count[master_idx] != 0)) begin
                read_master_response_busy = 1'b1;
            end
        end
    endfunction

    function read_non_dcache_core_path_master_busy;
        input integer master_idx;
        integer depth_idx;
        integer slot_value;
        begin
            read_non_dcache_core_path_master_busy = 1'b0;
            for (depth_idx = 0; depth_idx < READ_FIFO_DEPTH; depth_idx = depth_idx + 1) begin
                slot_value = rd_slot_index(master_idx, depth_idx);
                if (rd_q_valid[slot_value] &&
                    core_path_request(rd_q_addr[slot_value],
                                      rd_q_size[slot_value],
                                      rd_q_bypass[slot_value])) begin
                    read_non_dcache_core_path_master_busy = 1'b1;
                end
            end
            for (depth_idx = 0; depth_idx < MAX_OUTSTANDING; depth_idx = depth_idx + 1) begin
                if (core_slot_valid_r[depth_idx] &&
                    !core_slot_is_write_r[depth_idx] &&
                    (core_slot_master_r[depth_idx] == master_idx[7:0])) begin
                    read_non_dcache_core_path_master_busy = 1'b1;
                end
            end
            if (core_req_stage_valid_r &&
                !core_req_stage_is_write_r &&
                (core_req_stage_master_r == master_idx[7:0])) begin
                read_non_dcache_core_path_master_busy = 1'b1;
            end
            for (depth_idx = 0; depth_idx < DIRECT_SLOT_COUNT; depth_idx = depth_idx + 1) begin
                if (direct_slot_valid_r[depth_idx] &&
                    direct_slot_from_core_r[depth_idx] &&
                    !direct_slot_is_write_r[depth_idx] &&
                    (direct_slot_master_r[depth_idx] == master_idx[7:0])) begin
                    read_non_dcache_core_path_master_busy = 1'b1;
                end
            end
        end
    endfunction

    function read_id_conflict;
        input integer master_idx;
        input [ID_BITS-1:0] req_id_value;
        integer depth_idx;
        integer slot_value;
        integer direct_idx;
        integer resp_ptr;
        begin
            read_id_conflict = 1'b0;
            if (rd_resp_valid_r[master_idx] &&
                (rd_resp_id_r[master_idx] == req_id_value)) begin
                read_id_conflict = 1'b1;
            end
            for (depth_idx = 0; depth_idx < READ_FIFO_DEPTH; depth_idx = depth_idx + 1) begin
                slot_value = rd_slot_index(master_idx, depth_idx);
                if (rd_q_valid[slot_value] &&
                    (rd_q_id[slot_value] == req_id_value)) begin
                    read_id_conflict = 1'b1;
                end
            end
            for (depth_idx = 0; depth_idx < MAX_OUTSTANDING; depth_idx = depth_idx + 1) begin
                if (core_slot_valid_r[depth_idx] &&
                    !core_slot_is_write_r[depth_idx] &&
                    (core_slot_master_r[depth_idx] == master_idx[7:0]) &&
                    (core_slot_orig_id_r[depth_idx] == req_id_value)) begin
                    read_id_conflict = 1'b1;
                end
            end
            if (core_req_stage_valid_r &&
                !core_req_stage_is_write_r &&
                (core_req_stage_master_r == master_idx[7:0]) &&
                (core_req_stage_orig_id_r == req_id_value)) begin
                read_id_conflict = 1'b1;
            end
            for (depth_idx = 0;
                 depth_idx < READ_RESP_QUEUE_DEPTH;
                 depth_idx = depth_idx + 1) begin
                resp_ptr = rd_resp_q_head[master_idx] + depth_idx;
                if (resp_ptr >= READ_RESP_QUEUE_DEPTH) begin
                    resp_ptr = resp_ptr - READ_RESP_QUEUE_DEPTH;
                end
                slot_value = rd_resp_slot_index(master_idx, resp_ptr);
                if ((depth_idx < rd_resp_q_count[master_idx]) &&
                    (rd_resp_q_id[slot_value] == req_id_value)) begin
                    read_id_conflict = 1'b1;
                end
            end
            for (direct_idx = 0;
                 direct_idx < DIRECT_SLOT_COUNT;
                 direct_idx = direct_idx + 1) begin
                if (direct_slot_valid_r[direct_idx] &&
                    !direct_slot_is_write_r[direct_idx] &&
                    (direct_slot_master_r[direct_idx] == master_idx[7:0]) &&
                    (direct_slot_orig_id_r[direct_idx] == req_id_value)) begin
                    read_id_conflict = 1'b1;
                end
            end
        end
    endfunction

    function write_id_conflict;
        input integer master_idx;
        input [ID_BITS-1:0] req_id_value;
        integer depth_idx;
        integer slot_value;
        integer direct_idx;
        begin
            write_id_conflict = 1'b0;
            if (wr_resp_valid_r[master_idx] &&
                (wr_resp_id_r[master_idx] == req_id_value)) begin
                write_id_conflict = 1'b1;
            end
            for (depth_idx = 0; depth_idx < WRITE_FIFO_DEPTH; depth_idx = depth_idx + 1) begin
                slot_value = wr_slot_index(master_idx, depth_idx);
                if (wr_q_valid[slot_value] &&
                    (wr_q_id[slot_value] == req_id_value)) begin
                    write_id_conflict = 1'b1;
                end
            end
            for (depth_idx = 0; depth_idx < MAX_OUTSTANDING; depth_idx = depth_idx + 1) begin
                if (core_slot_valid_r[depth_idx] &&
                    core_slot_is_write_r[depth_idx] &&
                    (core_slot_master_r[depth_idx] == master_idx[7:0]) &&
                    (core_slot_orig_id_r[depth_idx] == req_id_value)) begin
                    write_id_conflict = 1'b1;
                end
            end
            if (core_req_stage_valid_r &&
                core_req_stage_is_write_r &&
                (core_req_stage_master_r == master_idx[7:0]) &&
                (core_req_stage_orig_id_r == req_id_value)) begin
                write_id_conflict = 1'b1;
            end
            for (direct_idx = 0;
                 direct_idx < DIRECT_SLOT_COUNT;
                 direct_idx = direct_idx + 1) begin
                if (direct_slot_valid_r[direct_idx] &&
                    direct_slot_is_write_r[direct_idx] &&
                    (direct_slot_master_r[direct_idx] == master_idx[7:0]) &&
                    (direct_slot_orig_id_r[direct_idx] == req_id_value)) begin
                    write_id_conflict = 1'b1;
                end
            end
        end
    endfunction

    assign target_read_resp_ready_w = 1'b0;
    assign target_write_resp_ready_w = 1'b0;
    assign core_req_stage_pop_w = core_req_stage_valid_r && core_up_req_ready_w;
    assign core_req_stage_can_push_w = !core_req_stage_valid_r ||
                                       core_req_stage_pop_w;
    assign core_up_req_valid_w = core_req_stage_valid_r;
    assign core_up_req_write_w = core_req_stage_is_write_r;
    assign core_up_req_addr_w = core_req_stage_addr_r;
    assign core_up_req_id_w = core_req_stage_slot_r[ID_BITS-1:0];
    assign core_up_req_total_size_w = core_req_stage_size_r;
    assign core_up_req_wdata_w = core_req_stage_wdata_r;
    assign core_up_req_wstrb_w = core_req_stage_wstrb_r;
    assign core_up_req_bypass_w = core_req_stage_bypass_r;
    assign core_up_resp_ready_w = core_resp_match_w && !core_resp_target_busy_w;
    assign direct_resp_accept_w = direct_resp_match_w &&
                                  !direct_resp_target_busy_w &&
                                  !direct_resp_conflict_w;

    always @(*) begin
        // Round-robin selection over all read and write queues.
        dispatch_found_w = 1'b0;
        dispatch_is_write_w = 1'b0;
        dispatch_master_w = 8'd0;
        dispatch_fifo_slot_w = 0;
        dispatch_slot_w = 0;
        total_read_outstanding_w = 0;
        total_write_outstanding_w = 0;
        rd_select_found_w = 1'b0;
        rd_select_master_w = 8'd0;
        wr_select_found_w = 1'b0;
        wr_select_master_w = 8'd0;
        compat_quiescent_w = 1'b1;
        line_write_hazard_w = 1'b0;
        accept_blocked_w = reconfig_busy || maintenance_pending_w;
        dcache_same_cycle_accept_w = 1'b0;
        core_mode_req_w = active_mode;
        core_offset_req_w = active_offset;
        core_invalidate_all_valid_w = 1'b0;
        core_invalidate_line_valid_w = 1'b0;
        core_slot_free_found_w = 1'b0;
        core_slot_free_w = 8'd0;
        direct_slot_free_found_w = 1'b0;
        direct_slot_free_w = 8'd0;
        direct_dispatch_found_w = 1'b0;
        direct_dispatch_is_write_w = 1'b0;
        direct_dispatch_master_w = 8'd0;
        direct_dispatch_fifo_slot_w = 0;
        direct_dispatch_slot_w = 8'd0;
        direct_dispatch_addr_w = {ADDR_BITS{1'b0}};
        direct_dispatch_id_w = {ID_BITS{1'b0}};
        direct_dispatch_size_w = 8'd0;
        direct_dispatch_wdata_w = {LINE_BITS{1'b0}};
        direct_dispatch_wstrb_w = {LINE_BYTES{1'b0}};
        core_resp_match_w = 1'b0;
        core_resp_slot_w = 8'd0;
        core_resp_is_write_w = 1'b0;
        core_resp_master_w = 8'd0;
        core_resp_orig_id_w = {ID_BITS{1'b0}};
        core_resp_addr_w = {ADDR_BITS{1'b0}};
        core_resp_target_busy_w = 1'b0;
        direct_resp_match_w = 1'b0;
        direct_resp_slot_w = 8'd0;
        direct_resp_is_write_w = 1'b0;
        direct_resp_master_w = 8'd0;
        direct_resp_orig_id_w = {ID_BITS{1'b0}};
        direct_resp_addr_w = {ADDR_BITS{1'b0}};
        direct_resp_target_busy_w = 1'b0;
        direct_resp_conflict_w = 1'b0;
        core_bypass_slot_found_w = 1'b0;
        core_bypass_slot_w = 8'd0;
        direct_issue_found_w = 1'b0;
        direct_issue_slot_w = 8'd0;

        for (flat_idx = 0; flat_idx < NUM_READ_MASTERS; flat_idx = flat_idx + 1) begin
            total_read_outstanding_w = total_read_outstanding_w + rd_q_count[flat_idx];
            total_read_outstanding_w = total_read_outstanding_w + rd_resp_q_count[flat_idx];
            if (rd_resp_valid_r[flat_idx]) begin
                total_read_outstanding_w = total_read_outstanding_w + 1;
            end
            if ((rd_q_count[flat_idx] != 0) ||
                (rd_resp_q_count[flat_idx] != 0) ||
                rd_resp_valid_r[flat_idx] ||
                read_req_ready_r[flat_idx]) begin
                compat_quiescent_w = 1'b0;
            end
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
        for (flat_idx = 0; flat_idx < MAX_OUTSTANDING; flat_idx = flat_idx + 1) begin
            if (!core_slot_free_found_w &&
                !core_slot_valid_r[flat_idx] &&
                !(core_req_stage_valid_r &&
                  (core_req_stage_slot_r == flat_idx[7:0]))) begin
                core_slot_free_found_w = 1'b1;
                core_slot_free_w = flat_idx[7:0];
            end
            if (core_slot_valid_r[flat_idx]) begin
                compat_quiescent_w = 1'b0;
                if (core_slot_is_write_r[flat_idx]) begin
                    total_write_outstanding_w = total_write_outstanding_w + 1;
                end else begin
                    total_read_outstanding_w = total_read_outstanding_w + 1;
                end
                if (invalidate_line_valid &&
                    core_slot_is_write_r[flat_idx] &&
                    ((core_slot_addr_r[flat_idx] >> LINE_OFFSET_BITS) ==
                     (invalidate_line_addr >> LINE_OFFSET_BITS))) begin
                    line_write_hazard_w = 1'b1;
                end
            end
        end
        if (core_bypass_req_valid_w &&
            (core_bypass_req_id_w < MAX_OUTSTANDING) &&
            core_slot_valid_r[core_bypass_req_id_w]) begin
            core_bypass_slot_found_w = 1'b1;
            core_bypass_slot_w = core_bypass_req_id_w;
        end
        for (flat_idx = 0; flat_idx < DIRECT_SLOT_COUNT; flat_idx = flat_idx + 1) begin
            if (!direct_slot_free_found_w && !direct_slot_valid_r[flat_idx]) begin
                direct_slot_free_found_w = 1'b1;
                direct_slot_free_w = flat_idx[7:0];
            end
            if (!direct_issue_found_w &&
                direct_slot_valid_r[flat_idx] &&
                !direct_slot_issued_r[flat_idx]) begin
                direct_issue_found_w = 1'b1;
                direct_issue_slot_w = flat_idx[7:0];
            end
            if (direct_slot_valid_r[flat_idx]) begin
                compat_quiescent_w = 1'b0;
                if (direct_slot_is_write_r[flat_idx]) begin
                    total_write_outstanding_w = total_write_outstanding_w + 1;
                end else begin
                    total_read_outstanding_w = total_read_outstanding_w + 1;
                end
                if (invalidate_line_valid &&
                    direct_slot_is_write_r[flat_idx] &&
                    ((direct_slot_addr_r[flat_idx] >> LINE_OFFSET_BITS) ==
                     (invalidate_line_addr >> LINE_OFFSET_BITS))) begin
                    line_write_hazard_w = 1'b1;
                end
            end
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
                    (request_uses_direct_bypass(active_mode,
                                               active_offset,
                                               read_req_addr[(next_port * ADDR_BITS) +: ADDR_BITS],
                                               read_req_total_size[(next_port * 8) +: 8],
                                               read_req_bypass[next_port]) ||
                     (!read_capture_line_hazard(
                          read_req_addr[(next_port * ADDR_BITS) +: ADDR_BITS]) &&
                      !read_master_response_busy(next_port) &&
                      ((next_port == MASTER_DCACHE_R) ||
                       !read_non_dcache_core_path_master_busy(next_port)))) &&
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
                    (total_write_outstanding_w < MAX_WRITE_OUTSTANDING) &&
                    (request_uses_direct_bypass(active_mode,
                                               active_offset,
                                               write_req_addr[(next_port * ADDR_BITS) +: ADDR_BITS],
                                               write_req_total_size[(next_port * 8) +: 8],
                                               write_req_bypass[next_port]) ||
                     !core_path_line_hazard(
                         write_req_addr[(next_port * ADDR_BITS) +: ADDR_BITS])) &&
                    !write_id_conflict(next_port,
                        write_req_id[(next_port * ID_BITS) +: ID_BITS])) begin
                    wr_select_found_w = 1'b1;
                    wr_select_master_w = next_port[7:0];
                end
            end
        end

        // Maintenance first drains compat-local queueing / inflight ownership,
        // then forwards into the core. invalidate_line shares this outer
        // compat-local quiescent gate with invalidate_all / reconfig; the
        // same-line local write hazard below is an additional filter, not the
        // only maintenance gate.
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
            (MASTER_DCACHE_R < NUM_READ_MASTERS) &&
            rd_select_found_w &&
            (rd_select_master_w == MASTER_DCACHE_R)) begin
            if (read_req_valid[rd_select_master_w]) begin
                dcache_same_cycle_accept_w = 1'b1;
            end
        end

        if (core_slot_free_found_w && core_req_stage_can_push_w) begin
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
                            if (!(core_req_stage_valid_r &&
                                  !core_req_stage_is_write_r &&
                                  (core_req_stage_master_r == next_port[7:0]) &&
                                  (core_req_stage_fifo_slot_r ==
                                   dispatch_fifo_slot_w[7:0])) &&
                                !request_uses_direct_bypass(active_mode,
                                                            active_offset,
                                                            rd_q_addr[dispatch_fifo_slot_w],
                                                            rd_q_size[dispatch_fifo_slot_w],
                                                            rd_q_bypass[dispatch_fifo_slot_w]) &&
                                !dispatch_path_line_hazard(
                                    rd_q_addr[dispatch_fifo_slot_w])) begin
                                dispatch_found_w = 1'b1;
                                dispatch_is_write_w = 1'b0;
                                dispatch_master_w = next_port[7:0];
                                dispatch_slot_w = next_port;
                            end
                        end
                    end else begin
                        flat_idx = next_port - NUM_READ_MASTERS;
                        if ((wr_q_count[flat_idx] != 0) &&
                            !wr_resp_valid_r[flat_idx]) begin
                            dispatch_fifo_slot_w = wr_slot_index(flat_idx,
                                                                 wr_q_head[flat_idx]);
                            if (!(core_req_stage_valid_r &&
                                  core_req_stage_is_write_r &&
                                  (core_req_stage_master_r == flat_idx[7:0]) &&
                                  (core_req_stage_fifo_slot_r ==
                                   dispatch_fifo_slot_w[7:0])) &&
                                !request_uses_direct_bypass(active_mode,
                                                            active_offset,
                                                            wr_q_addr[dispatch_fifo_slot_w],
                                                            wr_q_size[dispatch_fifo_slot_w],
                                                            wr_q_bypass[dispatch_fifo_slot_w]) &&
                                !dispatch_path_line_hazard(
                                    wr_q_addr[dispatch_fifo_slot_w])) begin
                                dispatch_found_w = 1'b1;
                                dispatch_is_write_w = 1'b1;
                                dispatch_master_w = flat_idx[7:0];
                                dispatch_slot_w = next_port;
                            end
                        end
                    end
                end
            end
        end

        if (direct_slot_free_found_w) begin
            for (rr_off = 0; rr_off < TOTAL_PORTS; rr_off = rr_off + 1) begin
                next_port = direct_rr_ptr_r + rr_off;
                if (next_port >= TOTAL_PORTS) begin
                    next_port = next_port - TOTAL_PORTS;
                end
                if (!direct_dispatch_found_w) begin
                    if (next_port < NUM_READ_MASTERS) begin
                        if (rd_q_count[next_port] != 0) begin
                            direct_dispatch_fifo_slot_w =
                                rd_slot_index(next_port, rd_q_head[next_port]);
                            if (request_uses_direct_bypass(active_mode,
                                                           active_offset,
                                                           rd_q_addr[direct_dispatch_fifo_slot_w],
                                                           rd_q_size[direct_dispatch_fifo_slot_w],
                                                           rd_q_bypass[direct_dispatch_fifo_slot_w])) begin
                                direct_dispatch_found_w = 1'b1;
                                direct_dispatch_is_write_w = 1'b0;
                                direct_dispatch_master_w = next_port[7:0];
                                direct_dispatch_slot_w = next_port[7:0];
                                direct_dispatch_addr_w =
                                    rd_q_addr[direct_dispatch_fifo_slot_w];
                                direct_dispatch_id_w =
                                    rd_q_id[direct_dispatch_fifo_slot_w];
                                direct_dispatch_size_w =
                                    rd_q_size[direct_dispatch_fifo_slot_w];
                                direct_dispatch_wdata_w = {LINE_BITS{1'b0}};
                                direct_dispatch_wstrb_w = {LINE_BYTES{1'b0}};
                            end
                        end
                    end else begin
                        flat_idx = next_port - NUM_READ_MASTERS;
                        if (wr_q_count[flat_idx] != 0) begin
                            direct_dispatch_fifo_slot_w =
                                wr_slot_index(flat_idx, wr_q_head[flat_idx]);
                            if (request_uses_direct_bypass(active_mode,
                                                           active_offset,
                                                           wr_q_addr[direct_dispatch_fifo_slot_w],
                                                           wr_q_size[direct_dispatch_fifo_slot_w],
                                                           wr_q_bypass[direct_dispatch_fifo_slot_w])) begin
                                direct_dispatch_found_w = 1'b1;
                                direct_dispatch_is_write_w = 1'b1;
                                direct_dispatch_master_w = flat_idx[7:0];
                                direct_dispatch_slot_w = next_port[7:0];
                                direct_dispatch_addr_w =
                                    wr_q_addr[direct_dispatch_fifo_slot_w];
                                direct_dispatch_id_w =
                                    wr_q_id[direct_dispatch_fifo_slot_w];
                                direct_dispatch_size_w =
                                    wr_q_size[direct_dispatch_fifo_slot_w];
                                direct_dispatch_wdata_w =
                                    wr_q_wdata[direct_dispatch_fifo_slot_w];
                                direct_dispatch_wstrb_w =
                                    wr_q_wstrb[direct_dispatch_fifo_slot_w];
                            end
                        end
                    end
                end
            end
        end

        if (core_up_resp_valid_w &&
            (core_up_resp_id_w < MAX_OUTSTANDING) &&
            core_slot_valid_r[core_up_resp_id_w]) begin
            core_resp_match_w = 1'b1;
            core_resp_slot_w = core_up_resp_id_w;
            core_resp_is_write_w = core_slot_is_write_r[core_up_resp_id_w];
            core_resp_master_w = core_slot_master_r[core_up_resp_id_w];
            core_resp_orig_id_w = core_slot_orig_id_r[core_up_resp_id_w];
            core_resp_addr_w = core_slot_addr_r[core_up_resp_id_w];
            if (core_slot_is_write_r[core_up_resp_id_w]) begin
                core_resp_target_busy_w =
                    wr_resp_valid_r[core_slot_master_r[core_up_resp_id_w]];
            end else begin
                core_resp_target_busy_w =
                    !read_resp_has_room(core_slot_master_r[core_up_resp_id_w]);
            end
        end

        if (bypass_resp_valid &&
            (bypass_resp_id < DIRECT_SLOT_COUNT) &&
            direct_slot_valid_r[bypass_resp_id] &&
            direct_slot_issued_r[bypass_resp_id]) begin
            direct_resp_match_w = 1'b1;
            direct_resp_slot_w = bypass_resp_id;
            direct_resp_is_write_w = direct_slot_is_write_r[bypass_resp_id];
            direct_resp_master_w = direct_slot_master_r[bypass_resp_id];
            direct_resp_orig_id_w = direct_slot_orig_id_r[bypass_resp_id];
            direct_resp_addr_w = direct_slot_addr_r[bypass_resp_id];
            if (direct_slot_is_write_r[bypass_resp_id]) begin
                direct_resp_target_busy_w =
                    wr_resp_valid_r[direct_slot_master_r[bypass_resp_id]];
            end else begin
                direct_resp_target_busy_w =
                    !read_resp_has_room(direct_slot_master_r[bypass_resp_id]);
            end
            if (core_resp_match_w &&
                (core_resp_is_write_w == direct_slot_is_write_r[bypass_resp_id]) &&
                (core_resp_master_w == direct_slot_master_r[bypass_resp_id])) begin
                direct_resp_conflict_w = 1'b1;
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
                                       !(core_req_stage_pop_w &&
                                         !core_req_stage_is_write_r &&
                                         (core_req_stage_master_r == flat_idx[7:0])) &&
                                       (request_uses_direct_bypass(active_mode,
                                                                  active_offset,
                                                                  read_req_addr[(flat_idx * ADDR_BITS) +: ADDR_BITS],
                                                                  read_req_total_size[(flat_idx * 8) +: 8],
                                                                  read_req_bypass[flat_idx]) ||
                                        (!read_capture_line_hazard(
                                             read_req_addr[(flat_idx * ADDR_BITS) +: ADDR_BITS]) &&
                                         !read_master_response_busy(flat_idx) &&
                                         ((flat_idx == MASTER_DCACHE_R) ||
                                          !read_non_dcache_core_path_master_busy(flat_idx)))) &&
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
                                        (total_write_outstanding_w < MAX_WRITE_OUTSTANDING) &&
                                        !(core_req_stage_pop_w &&
                                          core_req_stage_is_write_r &&
                                          (core_req_stage_master_r == flat_idx[7:0])) &&
                                        !write_id_conflict(flat_idx,
                                            write_req_id[(flat_idx * ID_BITS) +: ID_BITS]);
            write_resp_valid[flat_idx] = wr_resp_valid_r[flat_idx];
            write_resp_id[(flat_idx * ID_BITS) +: ID_BITS] =
                wr_resp_id_r[flat_idx];
            write_resp_code[(flat_idx * 2) +: 2] =
                wr_resp_code_r[flat_idx];
        end
    end

    assign core_bypass_req_ready_w = direct_slot_free_found_w &&
                                     core_bypass_slot_found_w;
    assign core_bypass_handoff_w = core_bypass_req_valid_w &&
                                   core_bypass_req_ready_w;
    assign direct_bypass_req_valid_w = direct_dispatch_found_w &&
                                       direct_slot_free_found_w &&
                                       !core_bypass_handoff_w &&
                                       !direct_issue_found_w;
    assign direct_bypass_req_handshake_w = direct_bypass_req_valid_w &&
                                           bypass_req_ready;

    assign bypass_req_valid = direct_issue_found_w || direct_bypass_req_valid_w;
    assign bypass_req_write = direct_issue_found_w ?
                              direct_slot_is_write_r[direct_issue_slot_w] :
                              direct_dispatch_is_write_w;
    assign bypass_req_addr = direct_issue_found_w ?
                             direct_slot_addr_r[direct_issue_slot_w] :
                             direct_dispatch_addr_w;
    assign bypass_req_id = direct_issue_found_w ?
                           direct_issue_slot_w[ID_BITS-1:0] :
                           direct_slot_free_w[ID_BITS-1:0];
    assign bypass_req_size = direct_issue_found_w ?
                             direct_slot_size_r[direct_issue_slot_w] :
                             direct_dispatch_size_w;
    assign bypass_req_mode2_ddr_aligned = direct_issue_found_w ?
                                          1'b0 :
                                          request_needs_mode2_ddr_aligned(active_mode,
                                                                          active_offset,
                                                                          direct_dispatch_addr_w,
                                                                          direct_dispatch_size_w);
    assign bypass_req_wdata = direct_issue_found_w ?
                              direct_slot_wdata_r[direct_issue_slot_w] :
                              direct_dispatch_wdata_w;
    assign bypass_req_wstrb = direct_issue_found_w ?
                              direct_slot_wstrb_r[direct_issue_slot_w] :
                              direct_dispatch_wstrb_w;
    assign bypass_resp_ready = core_bypass_resp_ready_w || direct_resp_accept_w;

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
        .bypass_req_valid      (core_bypass_req_valid_w),
        .bypass_req_ready      (core_bypass_req_ready_w),
        .bypass_req_write      (core_bypass_req_write_w),
        .bypass_req_addr       (core_bypass_req_addr_w),
        .bypass_req_id         (core_bypass_req_id_w),
        .bypass_req_size       (core_bypass_req_size_w),
        .bypass_req_wdata      (core_bypass_req_wdata_w),
        .bypass_req_wstrb      (core_bypass_req_wstrb_w),
        .bypass_resp_valid     (bypass_resp_valid),
        .bypass_resp_ready     (core_bypass_resp_ready_w),
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
        .config_error          (config_error),
        .victim_line_valid     (core_victim_line_valid_w),
        .victim_line_addr      (core_victim_line_addr_w)
    );

    integer idx;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rr_ptr_r <= 8'd0;
            direct_rr_ptr_r <= 8'd0;
            rd_capture_rr_r <= 8'd0;
            wr_capture_rr_r <= 8'd0;
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
                rd_resp_q_head[idx] <= 8'd0;
                rd_resp_q_tail[idx] <= 8'd0;
                rd_resp_q_count[idx] <= 8'd0;
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
            for (idx = 0; idx < RD_RESP_SLOT_COUNT; idx = idx + 1) begin
                rd_resp_q_data[idx] <= {READ_RESP_BITS{1'b0}};
                rd_resp_q_id[idx] <= {ID_BITS{1'b0}};
            end
            for (idx = 0; idx < MAX_OUTSTANDING; idx = idx + 1) begin
                core_slot_valid_r[idx] <= 1'b0;
                core_slot_is_write_r[idx] <= 1'b0;
                core_slot_master_r[idx] <= 8'd0;
                core_slot_orig_id_r[idx] <= {ID_BITS{1'b0}};
                core_slot_addr_r[idx] <= {ADDR_BITS{1'b0}};
            end
            for (idx = 0; idx < DIRECT_SLOT_COUNT; idx = idx + 1) begin
                direct_slot_valid_r[idx] <= 1'b0;
                direct_slot_issued_r[idx] <= 1'b0;
                direct_slot_from_core_r[idx] <= 1'b0;
                direct_slot_is_write_r[idx] <= 1'b0;
                direct_slot_master_r[idx] <= 8'd0;
                direct_slot_orig_id_r[idx] <= {ID_BITS{1'b0}};
                direct_slot_addr_r[idx] <= {ADDR_BITS{1'b0}};
                direct_slot_size_r[idx] <= 8'd0;
                direct_slot_wdata_r[idx] <= {LINE_BITS{1'b0}};
                direct_slot_wstrb_r[idx] <= {LINE_BYTES{1'b0}};
            end
            core_req_stage_valid_r <= 1'b0;
            core_req_stage_is_write_r <= 1'b0;
            core_req_stage_master_r <= 8'd0;
            core_req_stage_slot_r <= 8'd0;
            core_req_stage_fifo_slot_r <= 8'd0;
            core_req_stage_orig_id_r <= {ID_BITS{1'b0}};
            core_req_stage_addr_r <= {ADDR_BITS{1'b0}};
            core_req_stage_size_r <= 8'd0;
            core_req_stage_wdata_r <= {LINE_BITS{1'b0}};
            core_req_stage_wstrb_r <= {LINE_BYTES{1'b0}};
            core_req_stage_bypass_r <= 1'b0;
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
                    if (rd_resp_q_count[idx] != 0) begin
                        slot_idx = rd_resp_slot_index(idx, rd_resp_q_head[idx]);
                        rd_resp_valid_r[idx] <= 1'b1;
                        rd_resp_data_r[idx] <= rd_resp_q_data[slot_idx];
                        rd_resp_id_r[idx] <= rd_resp_q_id[slot_idx];
                        rd_resp_q_data[slot_idx] <= {READ_RESP_BITS{1'b0}};
                        rd_resp_q_id[slot_idx] <= {ID_BITS{1'b0}};
                        rd_resp_q_head[idx] <= next_rd_resp_ptr(rd_resp_q_head[idx]);
                        rd_resp_q_count[idx] <= rd_resp_q_count[idx] - 8'd1;
                    end else begin
                        rd_resp_valid_r[idx] <= 1'b0;
                    end
                end else if (!rd_resp_valid_r[idx] && (rd_resp_q_count[idx] != 0)) begin
                    slot_idx = rd_resp_slot_index(idx, rd_resp_q_head[idx]);
                    rd_resp_valid_r[idx] <= 1'b1;
                    rd_resp_data_r[idx] <= rd_resp_q_data[slot_idx];
                    rd_resp_id_r[idx] <= rd_resp_q_id[slot_idx];
                    rd_resp_q_data[slot_idx] <= {READ_RESP_BITS{1'b0}};
                    rd_resp_q_id[slot_idx] <= {ID_BITS{1'b0}};
                    rd_resp_q_head[idx] <= next_rd_resp_ptr(rd_resp_q_head[idx]);
                    rd_resp_q_count[idx] <= rd_resp_q_count[idx] - 8'd1;
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

            if (direct_bypass_req_handshake_w) begin
                direct_slot_valid_r[direct_slot_free_w] <= 1'b1;
                direct_slot_issued_r[direct_slot_free_w] <= 1'b1;
                direct_slot_from_core_r[direct_slot_free_w] <= 1'b0;
                direct_slot_is_write_r[direct_slot_free_w] <= direct_dispatch_is_write_w;
                direct_slot_master_r[direct_slot_free_w] <= direct_dispatch_master_w;
                direct_slot_orig_id_r[direct_slot_free_w] <= direct_dispatch_id_w;
                direct_slot_addr_r[direct_slot_free_w] <= direct_dispatch_addr_w;
                direct_slot_size_r[direct_slot_free_w] <= direct_dispatch_size_w;
                direct_slot_wdata_r[direct_slot_free_w] <= direct_dispatch_wdata_w;
                direct_slot_wstrb_r[direct_slot_free_w] <= direct_dispatch_wstrb_w;
                direct_rr_ptr_r <= direct_dispatch_slot_w + 8'd1;
                if (direct_dispatch_is_write_w) begin
                    wr_q_valid[direct_dispatch_fifo_slot_w] <= 1'b0;
                    wr_q_head[direct_dispatch_master_w] <=
                        next_wr_ptr(wr_q_head[direct_dispatch_master_w]);
                    wr_q_count[direct_dispatch_master_w] <=
                        wr_q_count[direct_dispatch_master_w] - 8'd1;
                end else begin
                    rd_q_valid[direct_dispatch_fifo_slot_w] <= 1'b0;
                    rd_q_head[direct_dispatch_master_w] <=
                        next_rd_ptr(rd_q_head[direct_dispatch_master_w]);
                    rd_q_count[direct_dispatch_master_w] <=
                        rd_q_count[direct_dispatch_master_w] - 8'd1;
                end
            end

            if (core_bypass_handoff_w) begin
                direct_slot_valid_r[direct_slot_free_w] <= 1'b1;
                direct_slot_issued_r[direct_slot_free_w] <= 1'b0;
                direct_slot_from_core_r[direct_slot_free_w] <= 1'b1;
                direct_slot_is_write_r[direct_slot_free_w] <=
                    core_bypass_req_write_w;
                direct_slot_master_r[direct_slot_free_w] <=
                    core_slot_master_r[core_bypass_slot_w];
                direct_slot_orig_id_r[direct_slot_free_w] <=
                    core_slot_orig_id_r[core_bypass_slot_w];
                direct_slot_addr_r[direct_slot_free_w] <=
                    core_slot_addr_r[core_bypass_slot_w];
                direct_slot_size_r[direct_slot_free_w] <=
                    core_bypass_req_size_w;
                direct_slot_wdata_r[direct_slot_free_w] <=
                    core_bypass_req_wdata_w;
                direct_slot_wstrb_r[direct_slot_free_w] <=
                    core_bypass_req_wstrb_w;
                core_slot_valid_r[core_bypass_slot_w] <= 1'b0;
                core_slot_is_write_r[core_bypass_slot_w] <= 1'b0;
                core_slot_master_r[core_bypass_slot_w] <= 8'd0;
                core_slot_orig_id_r[core_bypass_slot_w] <= {ID_BITS{1'b0}};
                core_slot_addr_r[core_bypass_slot_w] <= {ADDR_BITS{1'b0}};
            end

            if (direct_issue_found_w && bypass_req_ready) begin
                direct_slot_issued_r[direct_issue_slot_w] <= 1'b1;
            end

            if (core_req_stage_pop_w) begin
                core_req_stage_valid_r <= 1'b0;
                if (core_req_stage_is_write_r) begin
                    wr_q_valid[core_req_stage_fifo_slot_r] <= 1'b0;
                    wr_q_head[core_req_stage_master_r] <=
                        next_wr_ptr(wr_q_head[core_req_stage_master_r]);
                    wr_q_count[core_req_stage_master_r] <=
                        wr_q_count[core_req_stage_master_r] - 8'd1;
                end else begin
                    rd_q_valid[core_req_stage_fifo_slot_r] <= 1'b0;
                    rd_q_head[core_req_stage_master_r] <=
                        next_rd_ptr(rd_q_head[core_req_stage_master_r]);
                    rd_q_count[core_req_stage_master_r] <=
                        rd_q_count[core_req_stage_master_r] - 8'd1;
                end
                core_slot_valid_r[core_req_stage_slot_r[ID_BITS-1:0]] <= 1'b1;
                core_slot_is_write_r[core_req_stage_slot_r[ID_BITS-1:0]] <=
                    core_req_stage_is_write_r;
                core_slot_master_r[core_req_stage_slot_r[ID_BITS-1:0]] <=
                    core_req_stage_master_r;
                core_slot_orig_id_r[core_req_stage_slot_r[ID_BITS-1:0]] <=
                    core_req_stage_orig_id_r;
                core_slot_addr_r[core_req_stage_slot_r[ID_BITS-1:0]] <=
                    core_req_stage_addr_r;
            end

            if (dispatch_found_w && core_slot_free_found_w &&
                core_req_stage_can_push_w) begin
                core_req_stage_valid_r <= 1'b1;
                core_req_stage_is_write_r <= dispatch_is_write_w;
                core_req_stage_master_r <= dispatch_master_w;
                core_req_stage_slot_r <= core_slot_free_w;
                core_req_stage_fifo_slot_r <= dispatch_fifo_slot_w[7:0];
                core_req_stage_addr_r <= dispatch_is_write_w ?
                                         wr_q_addr[dispatch_fifo_slot_w] :
                                         rd_q_addr[dispatch_fifo_slot_w];
                core_req_stage_orig_id_r <= dispatch_is_write_w ?
                                            wr_q_id[dispatch_fifo_slot_w] :
                                            rd_q_id[dispatch_fifo_slot_w];
                core_req_stage_size_r <= dispatch_is_write_w ?
                                         wr_q_size[dispatch_fifo_slot_w] :
                                         rd_q_size[dispatch_fifo_slot_w];
                core_req_stage_wdata_r <= dispatch_is_write_w ?
                                          wr_q_wdata[dispatch_fifo_slot_w] :
                                          {LINE_BITS{1'b0}};
                core_req_stage_wstrb_r <= dispatch_is_write_w ?
                                          wr_q_wstrb[dispatch_fifo_slot_w] :
                                          {LINE_BYTES{1'b0}};
                core_req_stage_bypass_r <= dispatch_is_write_w ?
                                           wr_q_bypass[dispatch_fifo_slot_w] :
                                           rd_q_bypass[dispatch_fifo_slot_w];
                rr_ptr_r <= dispatch_slot_w[7:0] + 8'd1;
            end

            // Move the accepted core response back into the owning read/write
            // response slot or queue and free the internal core slot.
            if (core_resp_match_w && core_up_resp_ready_w) begin
                if (core_resp_is_write_w) begin
                    wr_resp_valid_r[core_resp_master_w] <= 1'b1;
                    wr_resp_id_r[core_resp_master_w] <= core_resp_orig_id_w;
                    wr_resp_code_r[core_resp_master_w] <= core_up_resp_code_w;
                    wr_resp_addr_r[core_resp_master_w] <= core_resp_addr_w;
                end else begin
                    if (!rd_resp_valid_r[core_resp_master_w] &&
                        (rd_resp_q_count[core_resp_master_w] == 0)) begin
                        rd_resp_valid_r[core_resp_master_w] <= 1'b1;
                        rd_resp_data_r[core_resp_master_w] <= core_up_resp_rdata_w;
                        rd_resp_id_r[core_resp_master_w] <= core_resp_orig_id_w;
                    end else begin
                        slot_idx = rd_resp_slot_index(core_resp_master_w,
                                                      rd_resp_q_tail[core_resp_master_w]);
                        rd_resp_q_data[slot_idx] <= core_up_resp_rdata_w;
                        rd_resp_q_id[slot_idx] <= core_resp_orig_id_w;
                        rd_resp_q_tail[core_resp_master_w] <=
                            next_rd_resp_ptr(rd_resp_q_tail[core_resp_master_w]);
                        rd_resp_q_count[core_resp_master_w] <=
                            rd_resp_q_count[core_resp_master_w] + 8'd1;
                    end
                end
                core_slot_valid_r[core_resp_slot_w] <= 1'b0;
                core_slot_is_write_r[core_resp_slot_w] <= 1'b0;
                core_slot_master_r[core_resp_slot_w] <= 8'd0;
                core_slot_orig_id_r[core_resp_slot_w] <= {ID_BITS{1'b0}};
                core_slot_addr_r[core_resp_slot_w] <= {ADDR_BITS{1'b0}};
            end

            if (direct_resp_accept_w) begin
                if (direct_resp_is_write_w) begin
                    wr_resp_valid_r[direct_resp_master_w] <= 1'b1;
                    wr_resp_id_r[direct_resp_master_w] <= direct_resp_orig_id_w;
                    wr_resp_code_r[direct_resp_master_w] <= bypass_resp_code;
                    wr_resp_addr_r[direct_resp_master_w] <= direct_resp_addr_w;
                end else begin
                    if (!rd_resp_valid_r[direct_resp_master_w] &&
                        (rd_resp_q_count[direct_resp_master_w] == 0)) begin
                        rd_resp_valid_r[direct_resp_master_w] <= 1'b1;
                        rd_resp_data_r[direct_resp_master_w] <= bypass_resp_rdata;
                        rd_resp_id_r[direct_resp_master_w] <= direct_resp_orig_id_w;
                    end else begin
                        slot_idx = rd_resp_slot_index(direct_resp_master_w,
                                                      rd_resp_q_tail[direct_resp_master_w]);
                        rd_resp_q_data[slot_idx] <= bypass_resp_rdata;
                        rd_resp_q_id[slot_idx] <= direct_resp_orig_id_w;
                        rd_resp_q_tail[direct_resp_master_w] <=
                            next_rd_resp_ptr(rd_resp_q_tail[direct_resp_master_w]);
                        rd_resp_q_count[direct_resp_master_w] <=
                            rd_resp_q_count[direct_resp_master_w] + 8'd1;
                    end
                end
                direct_slot_valid_r[direct_resp_slot_w] <= 1'b0;
                direct_slot_issued_r[direct_resp_slot_w] <= 1'b0;
                direct_slot_from_core_r[direct_resp_slot_w] <= 1'b0;
                direct_slot_is_write_r[direct_resp_slot_w] <= 1'b0;
                direct_slot_master_r[direct_resp_slot_w] <= 8'd0;
                direct_slot_orig_id_r[direct_resp_slot_w] <= {ID_BITS{1'b0}};
                direct_slot_addr_r[direct_resp_slot_w] <= {ADDR_BITS{1'b0}};
                direct_slot_size_r[direct_resp_slot_w] <= 8'd0;
                direct_slot_wdata_r[direct_resp_slot_w] <= {LINE_BITS{1'b0}};
                direct_slot_wstrb_r[direct_resp_slot_w] <= {LINE_BYTES{1'b0}};
            end
        end
    end

endmodule
