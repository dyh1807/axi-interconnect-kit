module axi_req_accept_formal_top(
    input        cache_req_valid,
    input        cache_req_write,
    input  [7:0] cache_total_beats,
    input        bypass_req_valid,
    input        bypass_req_write,
    input  [7:0] bypass_total_beats,
    input        rd_free_found,
    input  [7:0] rd_free_slot,
    input        rd_axi_id_found,
    input  [2:0] rd_axi_id,
    input        rd_issue_space,
    input        wr_free_found,
    input  [7:0] wr_free_slot,
    input        wr_axi_id_found,
    input  [2:0] wr_axi_id,
    input        wr_aw_space,
    input        wr_w_space,
    output       accept_cache,
    output       accept_bypass,
    output       accept_write,
    output [7:0] accept_slot,
    output [2:0] accept_axi_id,
    output [7:0] accept_total_beats
);

    axi_llc_axi_req_accept #(
        .AXI_ID_BITS(3)
    ) dut (
        .cache_req_valid(cache_req_valid),
        .cache_req_write(cache_req_write),
        .cache_total_beats(cache_total_beats),
        .bypass_req_valid(bypass_req_valid),
        .bypass_req_write(bypass_req_write),
        .bypass_total_beats(bypass_total_beats),
        .rd_free_found(rd_free_found),
        .rd_free_slot(rd_free_slot),
        .rd_axi_id_found(rd_axi_id_found),
        .rd_axi_id(rd_axi_id),
        .rd_issue_space(rd_issue_space),
        .wr_free_found(wr_free_found),
        .wr_free_slot(wr_free_slot),
        .wr_axi_id_found(wr_axi_id_found),
        .wr_axi_id(wr_axi_id),
        .wr_aw_space(wr_aw_space),
        .wr_w_space(wr_w_space),
        .accept_cache(accept_cache),
        .accept_bypass(accept_bypass),
        .accept_write(accept_write),
        .accept_slot(accept_slot),
        .accept_axi_id(accept_axi_id),
        .accept_total_beats(accept_total_beats)
    );

endmodule
