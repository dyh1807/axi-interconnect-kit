`timescale 1ns / 1ps

// Computes which pending read-miss MSHR entries must snapshot a write-hit line
// as their dirty victim. llc_cache_ctrl still owns and updates the registers.
module llc_mshr_write_hit_scan #(
    parameter ADDR_BITS        = 32,
    parameter SET_BITS         = 12,
    parameter WAY_BITS         = 5,
    parameter LINE_OFFSET_BITS = 6,
    parameter MSHR_COUNT       = 32
) (
    input                              enable,
    input      [ADDR_BITS-1:0]         req_addr,
    input      [SET_BITS-1:0]          req_set,
    input      [WAY_BITS-1:0]          hit_way,

    input      [MSHR_COUNT-1:0]        mshr_valid,
    input      [MSHR_COUNT-1:0]        mshr_is_write,
    input      [MSHR_COUNT-1:0]        mshr_wb_issued,
    input      [MSHR_COUNT-1:0]        mshr_refill_valid,
    input      [(MSHR_COUNT*ADDR_BITS)-1:0] mshr_addr,
    input      [(MSHR_COUNT*SET_BITS)-1:0]  mshr_set,
    input      [(MSHR_COUNT*WAY_BITS)-1:0]  mshr_way,

    output reg [MSHR_COUNT-1:0]        update_mask
);

    integer scan_idx;

    function [ADDR_BITS-1:0] mshr_addr_at;
        input integer slot;
        begin
            mshr_addr_at = mshr_addr[(slot * ADDR_BITS) +: ADDR_BITS];
        end
    endfunction

    function [SET_BITS-1:0] mshr_set_at;
        input integer slot;
        begin
            mshr_set_at = mshr_set[(slot * SET_BITS) +: SET_BITS];
        end
    endfunction

    function [WAY_BITS-1:0] mshr_way_at;
        input integer slot;
        begin
            mshr_way_at = mshr_way[(slot * WAY_BITS) +: WAY_BITS];
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

    always @(*) begin
        update_mask = {MSHR_COUNT{1'b0}};
        if (enable) begin
            for (scan_idx = 0; scan_idx < MSHR_COUNT; scan_idx = scan_idx + 1) begin
                if (mshr_valid[scan_idx] &&
                    !mshr_is_write[scan_idx] &&
                    !mshr_refill_valid[scan_idx] &&
                    !mshr_wb_issued[scan_idx] &&
                    (mshr_set_at(scan_idx) == req_set) &&
                    (mshr_way_at(scan_idx) == hit_way) &&
                    !same_line_addr(mshr_addr_at(scan_idx), req_addr)) begin
                    update_mask[scan_idx] = 1'b1;
                end
            end
        end
    end

endmodule
