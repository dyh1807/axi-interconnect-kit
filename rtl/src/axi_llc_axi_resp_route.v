`timescale 1ns / 1ps

// Response enqueue routing for axi_llc_axi_bridge. It chooses the source-local
// response queue for completed reads and accepted write responses.
module axi_llc_axi_resp_route (
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

    assign rd_complete_rsp_space =
        rd_complete_from_cache ? cache_rd_rsp_space : bypass_rd_rsp_space;
    assign rd_complete_push = rd_complete_found && rd_complete_rsp_space;
    assign cache_rd_rsp_push = rd_complete_push && rd_complete_from_cache;
    assign bypass_rd_rsp_push = rd_complete_push && !rd_complete_from_cache;

    assign wr_match_rsp_space =
        wr_match_from_cache ? cache_wr_rsp_space : bypass_wr_rsp_space;
    assign cache_wr_rsp_push = wr_resp_accept && wr_match_from_cache;
    assign bypass_wr_rsp_push = wr_resp_accept && !wr_match_from_cache;

endmodule
