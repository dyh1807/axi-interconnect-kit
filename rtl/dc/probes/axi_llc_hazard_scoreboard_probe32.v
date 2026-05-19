`timescale 1ns / 1ps

// DC-only wrapper for the smaller shared-outstanding candidate scoreboard:
// 32 read entries and 32 write entries.
module axi_llc_hazard_scoreboard_probe32 (
    input         clk,
    input         rst_n,
    input  [25:0] ddr_ar_line,
    input  [25:0] mmio_ar_line,
    input  [25:0] ddr_aw_line,
    input  [25:0] mmio_aw_line,
    input  [5:0]  ddr_arid,
    input  [5:0]  mmio_arid,
    input  [5:0]  ddr_awid,
    input  [5:0]  mmio_awid,
    input  [5:0]  ddr_rid,
    input  [5:0]  mmio_rid,
    input  [5:0]  ddr_bid,
    input  [5:0]  mmio_bid,
    input         ddr_ar_fire,
    input         mmio_ar_fire,
    input         ddr_aw_fire,
    input         mmio_aw_fire,
    input         ddr_r_fire,
    input         mmio_r_fire,
    input         ddr_b_fire,
    input         mmio_b_fire,
    output        ddr_ar_slot_hazard,
    output        mmio_ar_slot_hazard,
    output        ddr_aw_slot_hazard,
    output        mmio_aw_slot_hazard,
    output        ddr_aw_pending_read_hazard,
    output        mmio_aw_pending_read_hazard,
    output        ddr_ar_pending_write_hazard,
    output        mmio_ar_pending_write_hazard
);

    axi_llc_dual_port_hazard_scoreboard #(
        .LINE_TAG_BITS(26),
        .HAZARD_AXI_ID_BITS(6),
        .READ_HAZARD_COUNT(32),
        .WRITE_HAZARD_COUNT(32)
    ) u_scoreboard (
        .clk(clk),
        .rst_n(rst_n),
        .ddr_ar_line(ddr_ar_line),
        .mmio_ar_line(mmio_ar_line),
        .ddr_aw_line(ddr_aw_line),
        .mmio_aw_line(mmio_aw_line),
        .ddr_arid(ddr_arid),
        .mmio_arid(mmio_arid),
        .ddr_awid(ddr_awid),
        .mmio_awid(mmio_awid),
        .ddr_rid(ddr_rid),
        .mmio_rid(mmio_rid),
        .ddr_bid(ddr_bid),
        .mmio_bid(mmio_bid),
        .ddr_ar_fire(ddr_ar_fire),
        .mmio_ar_fire(mmio_ar_fire),
        .ddr_aw_fire(ddr_aw_fire),
        .mmio_aw_fire(mmio_aw_fire),
        .ddr_r_fire(ddr_r_fire),
        .mmio_r_fire(mmio_r_fire),
        .ddr_b_fire(ddr_b_fire),
        .mmio_b_fire(mmio_b_fire),
        .ddr_ar_slot_hazard(ddr_ar_slot_hazard),
        .mmio_ar_slot_hazard(mmio_ar_slot_hazard),
        .ddr_aw_slot_hazard(ddr_aw_slot_hazard),
        .mmio_aw_slot_hazard(mmio_aw_slot_hazard),
        .ddr_aw_pending_read_hazard(ddr_aw_pending_read_hazard),
        .mmio_aw_pending_read_hazard(mmio_aw_pending_read_hazard),
        .ddr_ar_pending_write_hazard(ddr_ar_pending_write_hazard),
        .mmio_ar_pending_write_hazard(mmio_ar_pending_write_hazard)
    );

endmodule
