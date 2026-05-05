`timescale 1ns / 1ps

// Production helper for AXI ID width conversion. The native dual-port bridge
// uses this when feeding per-port AXI IDs into the shared hazard scoreboard, so
// formal checks exercise the same zero-extension/truncation logic as RTL.
module axi_llc_axi_id_shape #(
    parameter IN_ID_BITS  = 6,
    parameter OUT_ID_BITS = 6
) (
    input      [IN_ID_BITS-1:0]  id_in,
    output     [OUT_ID_BITS-1:0] id_out
);

    generate
        if (OUT_ID_BITS > IN_ID_BITS) begin : gen_widen
            assign id_out = {{(OUT_ID_BITS - IN_ID_BITS){1'b0}}, id_in};
        end else if (OUT_ID_BITS == IN_ID_BITS) begin : gen_same
            assign id_out = id_in;
        end else begin : gen_narrow
            assign id_out = id_in[OUT_ID_BITS-1:0];
        end
    endgenerate

endmodule
