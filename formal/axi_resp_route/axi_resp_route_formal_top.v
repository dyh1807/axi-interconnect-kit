module axi_resp_route_formal_top(
    input  rd_complete_found,
    input  rd_complete_from_cache,
    input  cache_rd_rsp_space,
    input  bypass_rd_rsp_space,
    input  wr_match_from_cache,
    input  cache_wr_rsp_space,
    input  bypass_wr_rsp_space,
    input  wr_resp_accept,
    output rd_complete_rsp_space,
    output rd_complete_push,
    output cache_rd_rsp_push,
    output bypass_rd_rsp_push,
    output wr_match_rsp_space,
    output cache_wr_rsp_push,
    output bypass_wr_rsp_push
);

    axi_llc_axi_resp_route dut (
        .rd_complete_found(rd_complete_found),
        .rd_complete_from_cache(rd_complete_from_cache),
        .cache_rd_rsp_space(cache_rd_rsp_space),
        .bypass_rd_rsp_space(bypass_rd_rsp_space),
        .wr_match_from_cache(wr_match_from_cache),
        .cache_wr_rsp_space(cache_wr_rsp_space),
        .bypass_wr_rsp_space(bypass_wr_rsp_space),
        .wr_resp_accept(wr_resp_accept),
        .rd_complete_rsp_space(rd_complete_rsp_space),
        .rd_complete_push(rd_complete_push),
        .cache_rd_rsp_push(cache_rd_rsp_push),
        .bypass_rd_rsp_push(bypass_rd_rsp_push),
        .wr_match_rsp_space(wr_match_rsp_space),
        .cache_wr_rsp_push(cache_wr_rsp_push),
        .bypass_wr_rsp_push(bypass_wr_rsp_push)
    );

endmodule
