`timescale 1ns / 1ps

// Combinational MSHR hazard/pending scan for llc_cache_ctrl.
//
// The owning state remains in llc_cache_ctrl. This helper only scans packed
// MSHR snapshots and reports same-line hazards plus the exported victim-line
// scoreboard, keeping the production RTL path identical to the verified path.
module llc_mshr_pending_scan #(
    parameter ADDR_BITS        = 32,
    parameter ID_BITS          = 6,
    parameter LINE_OFFSET_BITS = 6,
    parameter MSHR_COUNT       = 32
) (
    input      [ADDR_BITS-1:0]              req_addr,
    input      [ID_BITS-1:0]                req_id,
    input      [ADDR_BITS-1:0]              invalidate_line_addr,

    input      [MSHR_COUNT-1:0]             mshr_valid,
    input      [MSHR_COUNT-1:0]             mshr_is_write,
    input      [MSHR_COUNT-1:0]             mshr_committed,
    input      [MSHR_COUNT-1:0]             mshr_victim_dirty,
    input      [MSHR_COUNT-1:0]             mshr_wb_done,
    input      [MSHR_COUNT-1:0]             mshr_wb_issued,
    input      [MSHR_COUNT-1:0]             mshr_refill_valid,
    input      [MSHR_COUNT-1:0]             mshr_need_refill,
    input      [(MSHR_COUNT*ADDR_BITS)-1:0] mshr_addr,
    input      [(MSHR_COUNT*ADDR_BITS)-1:0] mshr_victim_addr,

    output reg                              req_line_mshr_pending,
    output reg                              req_victim_line_pending,
    output reg                              req_master_mshr_pending,
    output reg                              mshr_any_valid,
    output reg                              invalidate_line_mshr_pending,
    output reg                              invalidate_line_victim_pending,
    output reg [MSHR_COUNT-1:0]             victim_line_valid,
    output reg [(MSHR_COUNT*ADDR_BITS)-1:0] victim_line_addr
);

    localparam [ID_BITS+1:0] MSHR_COUNT_ID = MSHR_COUNT;

    integer scan_idx;

    function [ADDR_BITS-1:0] mshr_addr_at;
        input integer slot;
        begin
            mshr_addr_at = mshr_addr[(slot * ADDR_BITS) +: ADDR_BITS];
        end
    endfunction

    function [ADDR_BITS-1:0] mshr_victim_addr_at;
        input integer slot;
        begin
            mshr_victim_addr_at =
                mshr_victim_addr[(slot * ADDR_BITS) +: ADDR_BITS];
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

    function victim_hazard_active;
        input is_write_value;
        input victim_dirty_value;
        input victim_wb_done_value;
        input victim_wb_issued_value;
        input refill_valid_value;
        input need_refill_value;
        begin
            if (!victim_dirty_value) begin
                victim_hazard_active = 1'b0;
            end else if (!need_refill_value) begin
                victim_hazard_active = 1'b1;
            end else if (is_write_value) begin
                victim_hazard_active = 1'b1;
            end else begin
                victim_hazard_active = refill_valid_value ||
                                       victim_wb_done_value ||
                                       victim_wb_issued_value;
            end
        end
    endfunction

    always @(*) begin
        req_line_mshr_pending = 1'b0;
        req_victim_line_pending = 1'b0;
        req_master_mshr_pending = 1'b0;
        mshr_any_valid = 1'b0;
        invalidate_line_mshr_pending = 1'b0;
        invalidate_line_victim_pending = 1'b0;
        victim_line_valid = {MSHR_COUNT{1'b0}};
        victim_line_addr = {(MSHR_COUNT*ADDR_BITS){1'b0}};

        if ({2'b00, req_id} < MSHR_COUNT_ID) begin
            if (mshr_valid[req_id]) begin
                req_master_mshr_pending = 1'b1;
            end
        end

        for (scan_idx = 0; scan_idx < MSHR_COUNT; scan_idx = scan_idx + 1) begin
            if (mshr_valid[scan_idx]) begin
                mshr_any_valid = 1'b1;
            end

            if (mshr_valid[scan_idx] &&
                !mshr_committed[scan_idx] &&
                same_line_addr(mshr_addr_at(scan_idx), req_addr)) begin
                req_line_mshr_pending = 1'b1;
            end

            if (mshr_valid[scan_idx] &&
                victim_hazard_active(
                    mshr_is_write[scan_idx],
                    mshr_victim_dirty[scan_idx],
                    mshr_wb_done[scan_idx],
                    mshr_wb_issued[scan_idx],
                    mshr_refill_valid[scan_idx],
                    mshr_need_refill[scan_idx])) begin
                victim_line_valid[scan_idx] = 1'b1;
                victim_line_addr[(scan_idx * ADDR_BITS) +: ADDR_BITS] =
                    line_align_addr(mshr_victim_addr_at(scan_idx));

                if (same_line_addr(mshr_victim_addr_at(scan_idx), req_addr)) begin
                    req_victim_line_pending = 1'b1;
                end
            end

            if (mshr_valid[scan_idx] &&
                !mshr_committed[scan_idx] &&
                same_line_addr(mshr_addr_at(scan_idx),
                               invalidate_line_addr)) begin
                invalidate_line_mshr_pending = 1'b1;
            end

            if (mshr_valid[scan_idx] &&
                mshr_victim_dirty[scan_idx] &&
                same_line_addr(mshr_victim_addr_at(scan_idx),
                               invalidate_line_addr)) begin
                invalidate_line_victim_pending = 1'b1;
            end
        end
    end

endmodule
