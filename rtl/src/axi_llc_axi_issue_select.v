`timescale 1ns / 1ps

// Queue-head issue selector used by axi_llc_axi_bridge for AR/AW/W issue.
module axi_llc_axi_issue_select #(
    parameter ADDR_BITS      = 32,
    parameter AXI_ID_BITS    = 6,
    parameter LINE_BYTES     = 64,
    parameter AXI_DATA_BYTES = 32
) (
    input                       queue_has_entry,
    input                       slot_valid,
    input                       slot_from_cache,
    input                       slot_mode2_ddr_aligned,
    input                       ready_to_issue,
    input                       issue_done,
    input      [ADDR_BITS-1:0]  slot_addr,
    input      [7:0]            slot_size,
    input      [AXI_ID_BITS-1:0] slot_axi_id,
    input      [7:0]            slot_beat_idx,
    input      [7:0]            slot_total_beats,
    output                      issue_valid,
    output                      issue_mode2_ddr_aligned,
    output     [ADDR_BITS-1:0]  issue_addr,
    output     [7:0]            issue_size,
    output     [AXI_ID_BITS-1:0] issue_axi_id,
    output     [7:0]            issue_beat_idx,
    output     [7:0]            issue_total_beats
);

    wire                      unused_mode2_single_axi_beat_w;
    wire [ADDR_BITS-1:0]      mode2_issue_addr_w;
    wire [7:0]                mode2_issue_size_w;

    axi_llc_axi_mode2_shape #(
        .ADDR_BITS(ADDR_BITS),
        .LINE_BYTES(LINE_BYTES),
        .AXI_DATA_BYTES(AXI_DATA_BYTES)
    ) mode2_shape (
        .addr(slot_addr),
        .total_size(slot_size),
        .single_axi_beat(unused_mode2_single_axi_beat_w),
        .issue_addr(mode2_issue_addr_w),
        .issue_size(mode2_issue_size_w)
    );

    assign issue_valid =
        queue_has_entry && slot_valid && ready_to_issue && !issue_done;
    assign issue_mode2_ddr_aligned =
        !slot_from_cache && slot_mode2_ddr_aligned;
    assign issue_addr = issue_mode2_ddr_aligned ?
                        mode2_issue_addr_w :
                        slot_addr;
    assign issue_size = issue_mode2_ddr_aligned ?
                        mode2_issue_size_w :
                        slot_size;
    assign issue_axi_id = slot_axi_id;
    assign issue_beat_idx = slot_beat_idx;
    assign issue_total_beats = slot_total_beats;

endmodule
