`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module axi_reconfig_ctrl #(
    parameter MODE_BITS    = `AXI_LLC_MODE_BITS,
    parameter ADDR_BITS    = `AXI_LLC_ADDR_BITS,
    parameter RESET_MODE   = {{(`AXI_LLC_MODE_BITS-2){1'b0}}, 2'b01},
    parameter RESET_OFFSET = {`AXI_LLC_ADDR_BITS{1'b0}}
) (
    input                        clk,
    input                        rst_n,
    input      [MODE_BITS-1:0]   req_mode,
    input      [ADDR_BITS-1:0]   req_offset,
    input                        invalidate_all_valid,
    input                        global_quiescent,
    input                        sweep_busy,
    input                        sweep_done,
    output                       invalidate_all_accepted,
    output     [MODE_BITS-1:0]   active_mode,
    output     [ADDR_BITS-1:0]   active_offset,
    output     [MODE_BITS-1:0]   target_mode,
    output     [ADDR_BITS-1:0]   target_offset,
    output                       block_accepts,
    output                       busy,
    output reg                   sweep_start,
    output reg [1:0]             state
);

    localparam [1:0] RCFG_IDLE      = 2'b00;
    localparam [1:0] RCFG_DRAIN     = 2'b01;
    localparam [1:0] RCFG_INV_SWEEP = 2'b10;
    localparam [1:0] RCFG_ACTIVATE  = 2'b11;

    reg [MODE_BITS-1:0] active_mode_r;
    reg [ADDR_BITS-1:0] active_offset_r;
    reg [MODE_BITS-1:0] target_mode_r;
    reg [ADDR_BITS-1:0] target_offset_r;
    reg                 sweep_started_r;
    reg                 invalidate_all_pending_r;

    reg [1:0]           next_state;
    reg [MODE_BITS-1:0] next_active_mode;
    reg [ADDR_BITS-1:0] next_active_offset;
    reg [MODE_BITS-1:0] next_target_mode;
    reg [ADDR_BITS-1:0] next_target_offset;
    reg                 next_sweep_started;
    reg                 next_invalidate_all_pending;
    reg                 invalidate_all_accepted_r;

    assign active_mode   = active_mode_r;
    assign active_offset = active_offset_r;
    assign target_mode   = target_mode_r;
    assign target_offset = target_offset_r;
    assign busy          = (state != RCFG_IDLE);
    assign block_accepts = (state != RCFG_IDLE);
    assign invalidate_all_accepted = invalidate_all_accepted_r;

    always @(*) begin
        next_state         = state;
        next_active_mode   = active_mode_r;
        next_active_offset = active_offset_r;
        next_target_mode   = target_mode_r;
        next_target_offset = target_offset_r;
        next_sweep_started = sweep_started_r;
        next_invalidate_all_pending = invalidate_all_pending_r;
        sweep_start        = 1'b0;
        invalidate_all_accepted_r = 1'b0;

        case (state)
            RCFG_IDLE: begin
                if (invalidate_all_valid) begin
                    next_invalidate_all_pending = 1'b1;
                end

                if ((req_mode != active_mode_r) ||
                    (req_offset != active_offset_r) ||
                    invalidate_all_valid) begin
                    next_target_mode   = req_mode;
                    next_target_offset = req_offset;
                    next_state         = RCFG_DRAIN;
                end
            end

            RCFG_DRAIN: begin
                next_target_mode   = req_mode;
                next_target_offset = req_offset;

                if (invalidate_all_valid && !invalidate_all_pending_r) begin
                    next_invalidate_all_pending = 1'b1;
                end

                if ((req_mode == active_mode_r) &&
                    (req_offset == active_offset_r) &&
                    !invalidate_all_pending_r) begin
                    next_state = RCFG_IDLE;
                end else if (global_quiescent) begin
                    next_state         = RCFG_INV_SWEEP;
                    next_sweep_started = 1'b0;
                end
            end

            RCFG_INV_SWEEP: begin
                next_target_mode   = req_mode;
                next_target_offset = req_offset;

                if (invalidate_all_valid && !invalidate_all_pending_r && !sweep_done) begin
                    next_invalidate_all_pending = 1'b1;
                end

                if (!sweep_busy && !sweep_started_r) begin
                    sweep_start        = 1'b1;
                    next_sweep_started = 1'b1;
                end

                if (sweep_done) begin
                    next_state         = RCFG_ACTIVATE;
                    next_sweep_started = 1'b0;
                    next_invalidate_all_pending = 1'b0;
                end
            end

            RCFG_ACTIVATE: begin
                invalidate_all_accepted_r = 1'b1;
                next_active_mode   = target_mode_r;
                next_active_offset = target_offset_r;
                next_state         = RCFG_IDLE;
                next_invalidate_all_pending = 1'b0;
            end

            default: begin
                next_state = RCFG_IDLE;
                next_invalidate_all_pending = 1'b0;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= RCFG_IDLE;
            active_mode_r   <= RESET_MODE;
            active_offset_r <= RESET_OFFSET;
            target_mode_r   <= RESET_MODE;
            target_offset_r <= RESET_OFFSET;
            sweep_started_r <= 1'b0;
            invalidate_all_pending_r <= 1'b0;
        end else begin
            state           <= next_state;
            active_mode_r   <= next_active_mode;
            active_offset_r <= next_active_offset;
            target_mode_r   <= next_target_mode;
            target_offset_r <= next_target_offset;
            sweep_started_r <= next_sweep_started;
            invalidate_all_pending_r <= next_invalidate_all_pending;
        end
    end

endmodule
