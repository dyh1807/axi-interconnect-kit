`timescale 1ns / 1ps

// Gate one external AXI port's AR/AW issue boundary for same-line read/write
// ordering. AR has same-cycle priority over AW for the same line so a write
// cannot be issued before the read response that defines its ordering point.
module axi_llc_dual_port_issue_gate #(
    parameter LINE_TAG_BITS = 26
) (
    input                          bridge_arvalid,
    output                         bridge_arready,
    output                         axi_arvalid,
    input                          axi_arready,
    input      [LINE_TAG_BITS-1:0] ar_line,
    input                          ar_slot_hazard,
    input                          ar_pending_write_hazard,

    input                          bridge_awvalid,
    output                         bridge_awready,
    output                         axi_awvalid,
    input                          axi_awready,
    input      [LINE_TAG_BITS-1:0] aw_line,
    input                          aw_slot_hazard,
    input                          aw_pending_read_hazard,

    output                         ar_hazard,
    output                         ar_would_issue,
    output                         aw_same_cycle_read_hazard,
    output                         aw_hazard,
    output                         ar_fire,
    output                         aw_fire
);

    assign ar_hazard = ar_slot_hazard || ar_pending_write_hazard;
    assign ar_would_issue = bridge_arvalid && !ar_hazard;
    assign aw_same_cycle_read_hazard =
        ar_would_issue && (ar_line == aw_line);
    assign aw_hazard =
        aw_slot_hazard || aw_pending_read_hazard ||
        aw_same_cycle_read_hazard;

    assign bridge_arready = axi_arready && !ar_hazard;
    assign axi_arvalid = bridge_arvalid && !ar_hazard;
    assign bridge_awready = axi_awready && !aw_hazard;
    assign axi_awvalid = bridge_awvalid && !aw_hazard;

    assign ar_fire = axi_arvalid && axi_arready;
    assign aw_fire = axi_awvalid && axi_awready;

endmodule
