module axi_dual_port_slot_hazard_formal_top(
    input  first_free_found,
    input  second_free_found,
    input  primary_fire,
    output primary_slot_hazard,
    output secondary_slot_hazard
);

    axi_llc_dual_port_slot_hazard dut (
        .first_free_found(first_free_found),
        .second_free_found(second_free_found),
        .primary_fire(primary_fire),
        .primary_slot_hazard(primary_slot_hazard),
        .secondary_slot_hazard(secondary_slot_hazard)
    );

endmodule
