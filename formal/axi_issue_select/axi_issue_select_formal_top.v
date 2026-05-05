module axi_issue_select_formal_top(
    input         queue_has_entry,
    input         slot_valid,
    input         slot_from_cache,
    input         slot_mode2_ddr_aligned,
    input         ready_to_issue,
    input         issue_done,
    input  [31:0] slot_addr,
    input  [7:0]  slot_size,
    input  [2:0]  slot_axi_id,
    input  [7:0]  slot_beat_idx,
    input  [7:0]  slot_total_beats,
    output        issue_valid,
    output        issue_mode2_ddr_aligned,
    output [31:0] issue_addr,
    output [7:0]  issue_size,
    output [2:0]  issue_axi_id,
    output [7:0]  issue_beat_idx,
    output [7:0]  issue_total_beats
);

    axi_llc_axi_issue_select #(
        .ADDR_BITS(32),
        .AXI_ID_BITS(3),
        .LINE_BYTES(64),
        .AXI_DATA_BYTES(32)
    ) dut (
        .queue_has_entry(queue_has_entry),
        .slot_valid(slot_valid),
        .slot_from_cache(slot_from_cache),
        .slot_mode2_ddr_aligned(slot_mode2_ddr_aligned),
        .ready_to_issue(ready_to_issue),
        .issue_done(issue_done),
        .slot_addr(slot_addr),
        .slot_size(slot_size),
        .slot_axi_id(slot_axi_id),
        .slot_beat_idx(slot_beat_idx),
        .slot_total_beats(slot_total_beats),
        .issue_valid(issue_valid),
        .issue_mode2_ddr_aligned(issue_mode2_ddr_aligned),
        .issue_addr(issue_addr),
        .issue_size(issue_size),
        .issue_axi_id(issue_axi_id),
        .issue_beat_idx(issue_beat_idx),
        .issue_total_beats(issue_total_beats)
    );

endmodule
