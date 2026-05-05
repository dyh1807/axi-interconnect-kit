`timescale 1ns / 1ps

// Computes shared scoreboard slot hazards for an ordered pair of external ports.
//
// The secondary port needs a second free entry only when the primary port
// actually fires in the same cycle. A merely-valid primary request may still be
// held by downstream AXI ready, and must not unnecessarily serialize the
// secondary port.
module axi_llc_dual_port_slot_hazard (
    input  first_free_found,
    input  second_free_found,
    input  primary_fire,
    output primary_slot_hazard,
    output secondary_slot_hazard
);

    assign primary_slot_hazard = !first_free_found;
    assign secondary_slot_hazard =
        !first_free_found || (primary_fire && !second_free_found);

endmodule
