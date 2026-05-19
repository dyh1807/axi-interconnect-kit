`timescale 1ns / 1ps

// Pending slot scan primitive for axi_llc_axi_bridge.
//
// This helper centralizes first-free slot, response ID match, and first-complete
// slot scan over a bridge pending table. When the AXI ID space can cover every
// pending slot, the bridge uses the slot index itself as the AXI ID; that avoids
// an extra first-free-ID scan and a priority match over stored IDs.
module axi_llc_axi_pending_scan #(
    parameter ENTRY_COUNT = 4,
    parameter AXI_ID_BITS = 2
) (
    input      [ENTRY_COUNT-1:0]                    entry_valid,
    input      [ENTRY_COUNT-1:0]                    entry_complete,
    input      [(ENTRY_COUNT*AXI_ID_BITS)-1:0]      entry_axi_id,
    input      [AXI_ID_BITS-1:0]                    match_axi_id,

    output reg                                      free_found,
    output reg [7:0]                                free_slot,
    output reg                                      axi_id_found,
    output reg [AXI_ID_BITS-1:0]                    axi_id,
    output reg                                      match_found,
    output reg [7:0]                                match_slot,
    output reg                                      complete_found,
    output reg [7:0]                                complete_slot
);

    localparam integer AXI_ID_COUNT = (1 << AXI_ID_BITS);

    function [7:0] scan_slot_to_u8;
        input integer value;
        begin
            scan_slot_to_u8 = value;
        end
    endfunction

    function [AXI_ID_BITS-1:0] scan_id_to_axi_id;
        input integer value;
        begin
            scan_id_to_axi_id = value;
        end
    endfunction

    generate
        if (AXI_ID_COUNT >= ENTRY_COUNT) begin : gen_slot_id_mode
            wire [ENTRY_COUNT-1:0] free_candidate_w;
            wire [ENTRY_COUNT-1:0] match_candidate_w;
            wire [ENTRY_COUNT-1:0] complete_candidate_w;
            integer scan_idx;
            genvar entry_gen_idx;

            assign free_candidate_w = ~entry_valid;
            assign complete_candidate_w = entry_valid & entry_complete;

            for (entry_gen_idx = 0;
                 entry_gen_idx < ENTRY_COUNT;
                 entry_gen_idx = entry_gen_idx + 1) begin : gen_match
                localparam [AXI_ID_BITS-1:0] SLOT_AXI_ID =
                    entry_gen_idx[AXI_ID_BITS-1:0];
                assign match_candidate_w[entry_gen_idx] =
                    entry_valid[entry_gen_idx] && (match_axi_id == SLOT_AXI_ID);
            end

            always @(*) begin
                free_found = 1'b0;
                free_slot = 8'd0;
                axi_id_found = 1'b0;
                axi_id = {AXI_ID_BITS{1'b0}};
                match_found = 1'b0;
                match_slot = 8'd0;
                complete_found = 1'b0;
                complete_slot = 8'd0;

                for (scan_idx = 0; scan_idx < ENTRY_COUNT; scan_idx = scan_idx + 1) begin
                    if (!free_found && free_candidate_w[scan_idx]) begin
                        free_found = 1'b1;
                        free_slot = scan_slot_to_u8(scan_idx);
                    end
                    if (!match_found && match_candidate_w[scan_idx]) begin
                        match_found = 1'b1;
                        match_slot = scan_slot_to_u8(scan_idx);
                    end
                    if (!complete_found && complete_candidate_w[scan_idx]) begin
                        complete_found = 1'b1;
                        complete_slot = scan_slot_to_u8(scan_idx);
                    end
                end

                axi_id_found = free_found;
                axi_id = free_slot;
            end
        end else begin : gen_tracked_id_mode
            wire [ENTRY_COUNT-1:0] free_candidate_w;
            wire [ENTRY_COUNT-1:0] match_candidate_w;
            wire [ENTRY_COUNT-1:0] complete_candidate_w;
            wire [AXI_ID_COUNT-1:0] axi_id_used_w;
            wire [AXI_ID_BITS-1:0] entry_axi_id_w [0:ENTRY_COUNT-1];
            wire [ENTRY_COUNT-1:0] axi_id_hit_w [0:AXI_ID_COUNT-1];
            integer scan_idx;
            integer id_idx;
            genvar entry_gen_idx;
            genvar id_gen_idx;
            genvar id_entry_gen_idx;

            assign free_candidate_w = ~entry_valid;
            assign complete_candidate_w = entry_valid & entry_complete;

            for (entry_gen_idx = 0;
                 entry_gen_idx < ENTRY_COUNT;
                 entry_gen_idx = entry_gen_idx + 1) begin : gen_entry
                assign entry_axi_id_w[entry_gen_idx] =
                    entry_axi_id[(entry_gen_idx * AXI_ID_BITS) +: AXI_ID_BITS];
                assign match_candidate_w[entry_gen_idx] =
                    entry_valid[entry_gen_idx] &&
                    (entry_axi_id_w[entry_gen_idx] == match_axi_id);
            end

            for (id_gen_idx = 0;
                 id_gen_idx < AXI_ID_COUNT;
                 id_gen_idx = id_gen_idx + 1) begin : gen_axi_id_used
                localparam [AXI_ID_BITS-1:0] AXI_ID_VALUE =
                    id_gen_idx[AXI_ID_BITS-1:0];
                for (id_entry_gen_idx = 0;
                     id_entry_gen_idx < ENTRY_COUNT;
                     id_entry_gen_idx = id_entry_gen_idx + 1) begin : gen_entry_hit
                    assign axi_id_hit_w[id_gen_idx][id_entry_gen_idx] =
                        entry_valid[id_entry_gen_idx] &&
                        (entry_axi_id_w[id_entry_gen_idx] == AXI_ID_VALUE);
                end
                assign axi_id_used_w[id_gen_idx] = |axi_id_hit_w[id_gen_idx];
            end

            always @(*) begin
                free_found = 1'b0;
                free_slot = 8'd0;
                axi_id_found = 1'b0;
                axi_id = {AXI_ID_BITS{1'b0}};
                match_found = 1'b0;
                match_slot = 8'd0;
                complete_found = 1'b0;
                complete_slot = 8'd0;

                for (scan_idx = 0; scan_idx < ENTRY_COUNT; scan_idx = scan_idx + 1) begin
                    if (!free_found && free_candidate_w[scan_idx]) begin
                        free_found = 1'b1;
                        free_slot = scan_slot_to_u8(scan_idx);
                    end
                    if (!match_found && match_candidate_w[scan_idx]) begin
                        match_found = 1'b1;
                        match_slot = scan_slot_to_u8(scan_idx);
                    end
                    if (!complete_found && complete_candidate_w[scan_idx]) begin
                        complete_found = 1'b1;
                        complete_slot = scan_slot_to_u8(scan_idx);
                    end
                end

                for (id_idx = 0; id_idx < AXI_ID_COUNT; id_idx = id_idx + 1) begin
                    if (!axi_id_found && !axi_id_used_w[id_idx]) begin
                        axi_id_found = 1'b1;
                        axi_id = scan_id_to_axi_id(id_idx);
                    end
                end
            end
        end
    endgenerate

endmodule
