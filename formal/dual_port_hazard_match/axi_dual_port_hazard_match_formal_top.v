module axi_dual_port_hazard_match_formal_top(
    input        entry_valid,
    input        entry_port,
    input  [1:0] entry_line,
    input  [1:0] entry_id,
    input  [1:0] ddr_line,
    input  [1:0] mmio_line,
    input  [1:0] ddr_id,
    input  [1:0] mmio_id,
    output       ddr_line_match,
    output       mmio_line_match,
    output       ddr_id_match,
    output       mmio_id_match
);

    axi_llc_dual_port_hazard_match #(
        .LINE_TAG_BITS(2),
        .HAZARD_AXI_ID_BITS(2)
    ) dut (
        .entry_valid(entry_valid),
        .entry_port(entry_port),
        .entry_line(entry_line),
        .entry_id(entry_id),
        .ddr_line(ddr_line),
        .mmio_line(mmio_line),
        .ddr_id(ddr_id),
        .mmio_id(mmio_id),
        .ddr_line_match(ddr_line_match),
        .mmio_line_match(mmio_line_match),
        .ddr_id_match(ddr_id_match),
        .mmio_id_match(mmio_id_match)
    );

endmodule
