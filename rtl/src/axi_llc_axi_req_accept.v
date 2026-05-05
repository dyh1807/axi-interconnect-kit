`timescale 1ns / 1ps

// Source-side request acceptance control for axi_llc_axi_bridge.
//
// The cache source has priority over bypass when both are valid, matching the
// existing bridge contract. A request is accepted only when the corresponding
// pending slot, AXI ID, and issue queue space are available.
module axi_llc_axi_req_accept #(
    parameter AXI_ID_BITS = 6
) (
    input                         cache_req_valid,
    input                         cache_req_write,
    input      [7:0]              cache_total_beats,
    input                         bypass_req_valid,
    input                         bypass_req_write,
    input      [7:0]              bypass_total_beats,

    input                         rd_free_found,
    input      [7:0]              rd_free_slot,
    input                         rd_axi_id_found,
    input      [AXI_ID_BITS-1:0]  rd_axi_id,
    input                         rd_issue_space,

    input                         wr_free_found,
    input      [7:0]              wr_free_slot,
    input                         wr_axi_id_found,
    input      [AXI_ID_BITS-1:0]  wr_axi_id,
    input                         wr_aw_space,
    input                         wr_w_space,

    output reg                    accept_cache,
    output reg                    accept_bypass,
    output reg                    accept_write,
    output reg [7:0]              accept_slot,
    output reg [AXI_ID_BITS-1:0]  accept_axi_id,
    output reg [7:0]              accept_total_beats
);

    always @(*) begin
        accept_cache = 1'b0;
        accept_bypass = 1'b0;
        accept_write = 1'b0;
        accept_slot = 8'd0;
        accept_axi_id = {AXI_ID_BITS{1'b0}};
        accept_total_beats = 8'd0;

        if (cache_req_valid) begin
            if (cache_req_write) begin
                if (wr_free_found && wr_axi_id_found && wr_aw_space && wr_w_space) begin
                    accept_cache = 1'b1;
                    accept_write = 1'b1;
                    accept_slot = wr_free_slot;
                    accept_axi_id = wr_axi_id;
                    accept_total_beats = cache_total_beats;
                end
            end else if (rd_free_found && rd_axi_id_found && rd_issue_space) begin
                accept_cache = 1'b1;
                accept_write = 1'b0;
                accept_slot = rd_free_slot;
                accept_axi_id = rd_axi_id;
                accept_total_beats = cache_total_beats;
            end
        end else if (bypass_req_valid) begin
            if (bypass_req_write) begin
                if (wr_free_found && wr_axi_id_found && wr_aw_space && wr_w_space) begin
                    accept_bypass = 1'b1;
                    accept_write = 1'b1;
                    accept_slot = wr_free_slot;
                    accept_axi_id = wr_axi_id;
                    accept_total_beats = bypass_total_beats;
                end
            end else if (rd_free_found && rd_axi_id_found && rd_issue_space) begin
                accept_bypass = 1'b1;
                accept_write = 1'b0;
                accept_slot = rd_free_slot;
                accept_axi_id = rd_axi_id;
                accept_total_beats = bypass_total_beats;
            end
        end
    end

endmodule
