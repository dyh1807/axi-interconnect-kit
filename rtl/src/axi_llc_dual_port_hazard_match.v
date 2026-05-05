`timescale 1ns / 1ps

// Combinational match primitive for one hazard scoreboard entry.
//
// The state owner is axi_llc_dual_port_hazard_scoreboard; this helper only
// centralizes the per-entry port/line/id comparisons so the production logic
// can be formally checked without instantiating the whole scoreboard state.
module axi_llc_dual_port_hazard_match #(
    parameter LINE_TAG_BITS = 26,
    parameter HAZARD_AXI_ID_BITS = 6
) (
    input                          entry_valid,
    input                          entry_port,
    input      [LINE_TAG_BITS-1:0] entry_line,
    input  [HAZARD_AXI_ID_BITS-1:0] entry_id,

    input      [LINE_TAG_BITS-1:0] ddr_line,
    input      [LINE_TAG_BITS-1:0] mmio_line,
    input  [HAZARD_AXI_ID_BITS-1:0] ddr_id,
    input  [HAZARD_AXI_ID_BITS-1:0] mmio_id,

    output                         ddr_line_match,
    output                         mmio_line_match,
    output                         ddr_id_match,
    output                         mmio_id_match
);

    assign ddr_line_match =
        entry_valid && !entry_port && (entry_line == ddr_line);
    assign mmio_line_match =
        entry_valid && entry_port && (entry_line == mmio_line);
    assign ddr_id_match =
        entry_valid && !entry_port && (entry_id == ddr_id);
    assign mmio_id_match =
        entry_valid && entry_port && (entry_id == mmio_id);

endmodule
