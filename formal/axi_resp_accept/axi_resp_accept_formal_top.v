module axi_resp_accept_formal_top(
    input  axi_rvalid,
    input  rd_match_found,
    output axi_rready,
    output rd_resp_accept,
    input  axi_bvalid,
    input  wr_match_found,
    input  wr_match_rsp_space,
    output axi_bready,
    output wr_resp_accept
);

    axi_llc_axi_resp_accept dut (
        .axi_rvalid(axi_rvalid),
        .rd_match_found(rd_match_found),
        .axi_rready(axi_rready),
        .rd_resp_accept(rd_resp_accept),
        .axi_bvalid(axi_bvalid),
        .wr_match_found(wr_match_found),
        .wr_match_rsp_space(wr_match_rsp_space),
        .axi_bready(axi_bready),
        .wr_resp_accept(wr_resp_accept)
    );

endmodule
