`timescale 1ns / 1ps

module axi_llc_axi_read_resp_ctrl (
    input         rd_match_found,
    input  [7:0]  rd_beats_done,
    input  [7:0]  rd_total_beats,
    input         axi_rlast,
    input  [1:0]  axi_rresp,
    input  [1:0]  current_resp_code,
    output        rd_last_beat,
    output [1:0]  next_resp_code
);

    localparam [1:0] RESP_OKAY = 2'b00;

    assign rd_last_beat =
        rd_match_found &&
        (((rd_beats_done + 8'd1) == rd_total_beats) || axi_rlast);
    assign next_resp_code =
        (axi_rresp != RESP_OKAY) ? axi_rresp : current_resp_code;

endmodule
