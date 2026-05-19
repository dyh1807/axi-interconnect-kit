`timescale 1ns / 1ps

// Priority select scan for MSHR issue and commit candidates.
module llc_mshr_select_scan #(
    parameter ID_BITS    = 6,
    parameter MSHR_COUNT = 32
) (
    input      [MSHR_COUNT-1:0] mshr_valid,
    input      [MSHR_COUNT-1:0] mshr_committed,
    input      [MSHR_COUNT-1:0] mshr_victim_dirty,
    input      [MSHR_COUNT-1:0] mshr_wb_done,
    input      [MSHR_COUNT-1:0] mshr_wb_issued,
    input      [MSHR_COUNT-1:0] mshr_refill_issued,
    input      [MSHR_COUNT-1:0] mshr_refill_valid,
    input      [MSHR_COUNT-1:0] mshr_need_refill,

    output reg                  issue_found,
    output reg                  issue_write,
    output reg [ID_BITS-1:0]    issue_slot,
    output reg                  commit_found,
    output reg [ID_BITS-1:0]    commit_slot
);

    integer issue_idx;
    integer commit_idx;

    always @(*) begin
        issue_found = 1'b0;
        issue_write = 1'b0;
        issue_slot = {ID_BITS{1'b0}};
        for (issue_idx = 0; issue_idx < MSHR_COUNT; issue_idx = issue_idx + 1) begin
            if (!issue_found && mshr_valid[issue_idx]) begin
                if (!mshr_committed[issue_idx] &&
                    mshr_need_refill[issue_idx] &&
                    !mshr_refill_issued[issue_idx] &&
                    !mshr_refill_valid[issue_idx]) begin
                    issue_found = 1'b1;
                    issue_write = 1'b0;
                    issue_slot = issue_idx[ID_BITS-1:0];
                end else if (mshr_victim_dirty[issue_idx] &&
                             !mshr_wb_done[issue_idx] &&
                             !mshr_wb_issued[issue_idx] &&
                             (!mshr_need_refill[issue_idx] ||
                              mshr_refill_valid[issue_idx])) begin
                    issue_found = 1'b1;
                    issue_write = 1'b1;
                    issue_slot = issue_idx[ID_BITS-1:0];
                end
            end
        end

        commit_found = 1'b0;
        commit_slot = {ID_BITS{1'b0}};
        for (commit_idx = 0; commit_idx < MSHR_COUNT; commit_idx = commit_idx + 1) begin
            if (!commit_found &&
                mshr_valid[commit_idx] &&
                !mshr_committed[commit_idx] &&
                ((mshr_need_refill[commit_idx] &&
                  mshr_refill_valid[commit_idx]) ||
                 (!mshr_need_refill[commit_idx] &&
                  (!mshr_victim_dirty[commit_idx] ||
                   mshr_wb_done[commit_idx])))) begin
                commit_found = 1'b1;
                commit_slot = commit_idx[ID_BITS-1:0];
            end
        end
    end

endmodule
