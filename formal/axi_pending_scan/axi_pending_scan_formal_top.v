module axi_pending_scan_formal_top(
    input  [3:0] entry_valid,
    input  [3:0] entry_complete,
    input  [7:0] entry_axi_id,
    input  [1:0] match_axi_id,
    output       free_found,
    output [7:0] free_slot,
    output       axi_id_found,
    output [1:0] axi_id,
    output       match_found,
    output [7:0] match_slot,
    output       complete_found,
    output [7:0] complete_slot
);

    axi_llc_axi_pending_scan #(
        .ENTRY_COUNT(4),
        .AXI_ID_BITS(2)
    ) dut (
        .entry_valid(entry_valid),
        .entry_complete(entry_complete),
        .entry_axi_id(entry_axi_id),
        .match_axi_id(match_axi_id),
        .free_found(free_found),
        .free_slot(free_slot),
        .axi_id_found(axi_id_found),
        .axi_id(axi_id),
        .match_found(match_found),
        .match_slot(match_slot),
        .complete_found(complete_found),
        .complete_slot(complete_slot)
    );

endmodule
