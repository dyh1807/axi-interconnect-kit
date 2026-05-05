module axi_dual_port_issue_gate_formal_top(
    input        bridge_arvalid,
    input        axi_arready,
    input  [1:0] ar_line,
    input        ar_slot_hazard,
    input        ar_pending_write_hazard,
    input        bridge_awvalid,
    input        axi_awready,
    input  [1:0] aw_line,
    input        aw_slot_hazard,
    input        aw_pending_read_hazard,
    output       bridge_arready,
    output       axi_arvalid,
    output       bridge_awready,
    output       axi_awvalid,
    output       ar_hazard,
    output       ar_would_issue,
    output       aw_same_cycle_read_hazard,
    output       aw_hazard,
    output       ar_fire,
    output       aw_fire
);

    axi_llc_dual_port_issue_gate #(
        .LINE_TAG_BITS(2)
    ) dut (
        .bridge_arvalid(bridge_arvalid),
        .bridge_arready(bridge_arready),
        .axi_arvalid(axi_arvalid),
        .axi_arready(axi_arready),
        .ar_line(ar_line),
        .ar_slot_hazard(ar_slot_hazard),
        .ar_pending_write_hazard(ar_pending_write_hazard),
        .bridge_awvalid(bridge_awvalid),
        .bridge_awready(bridge_awready),
        .axi_awvalid(axi_awvalid),
        .axi_awready(axi_awready),
        .aw_line(aw_line),
        .aw_slot_hazard(aw_slot_hazard),
        .aw_pending_read_hazard(aw_pending_read_hazard),
        .ar_hazard(ar_hazard),
        .ar_would_issue(ar_would_issue),
        .aw_same_cycle_read_hazard(aw_same_cycle_read_hazard),
        .aw_hazard(aw_hazard),
        .ar_fire(ar_fire),
        .aw_fire(aw_fire)
    );

endmodule
