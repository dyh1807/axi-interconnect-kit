module axi_read_resp_ctrl_formal_top(
    input        rd_match_found,
    input  [7:0] rd_beats_done,
    input  [7:0] rd_total_beats,
    input        axi_rlast,
    input  [1:0] axi_rresp,
    input  [1:0] current_resp_code,
    output       rd_last_beat,
    output [1:0] next_resp_code
);

    axi_llc_axi_read_resp_ctrl dut (
        .rd_match_found(rd_match_found),
        .rd_beats_done(rd_beats_done),
        .rd_total_beats(rd_total_beats),
        .axi_rlast(axi_rlast),
        .axi_rresp(axi_rresp),
        .current_resp_code(current_resp_code),
        .rd_last_beat(rd_last_beat),
        .next_resp_code(next_resp_code)
    );

endmodule
