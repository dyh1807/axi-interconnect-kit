`timescale 1ns / 1ps

module axi_llc_axi_queue_ctrl #(
    parameter READ_DEPTH  = 32,
    parameter WRITE_DEPTH = 32
) (
    input  [7:0] rd_issue_count,
    input  [7:0] wr_aw_count,
    input  [7:0] wr_w_count,
    input  [7:0] cache_rd_rsp_count,
    input  [7:0] bypass_rd_rsp_count,
    input  [7:0] cache_wr_rsp_count,
    input  [7:0] bypass_wr_rsp_count,
    input        accept_cache,
    input        accept_bypass,
    input        accept_write,
    input        rd_issue_valid,
    input        axi_arready,
    input        wr_aw_valid,
    input        axi_awready,
    input        wr_w_valid,
    input        axi_wready,
    input        axi_wlast,
    output       rd_issue_space,
    output       wr_aw_space,
    output       wr_w_space,
    output       cache_rd_rsp_valid,
    output       bypass_rd_rsp_valid,
    output       cache_wr_rsp_valid,
    output       bypass_wr_rsp_valid,
    output       cache_rd_rsp_space,
    output       bypass_rd_rsp_space,
    output       cache_wr_rsp_space,
    output       bypass_wr_rsp_space,
    output       rd_issue_handshake,
    output       wr_aw_handshake,
    output       wr_w_handshake,
    output       rd_issue_push,
    output       rd_issue_pop,
    output       wr_aw_push,
    output       wr_aw_pop,
    output       wr_w_push,
    output       wr_w_pop
);

    wire accept_any = accept_cache || accept_bypass;

    assign rd_issue_space = (rd_issue_count < READ_DEPTH);
    assign wr_aw_space = (wr_aw_count < WRITE_DEPTH);
    assign wr_w_space = (wr_w_count < WRITE_DEPTH);
    assign cache_rd_rsp_valid = (cache_rd_rsp_count != 8'd0);
    assign bypass_rd_rsp_valid = (bypass_rd_rsp_count != 8'd0);
    assign cache_wr_rsp_valid = (cache_wr_rsp_count != 8'd0);
    assign bypass_wr_rsp_valid = (bypass_wr_rsp_count != 8'd0);
    assign cache_rd_rsp_space = (cache_rd_rsp_count < READ_DEPTH);
    assign bypass_rd_rsp_space = (bypass_rd_rsp_count < READ_DEPTH);
    assign cache_wr_rsp_space = (cache_wr_rsp_count < WRITE_DEPTH);
    assign bypass_wr_rsp_space = (bypass_wr_rsp_count < WRITE_DEPTH);
    assign rd_issue_handshake = rd_issue_valid && axi_arready;
    assign wr_aw_handshake = wr_aw_valid && axi_awready;
    assign wr_w_handshake = wr_w_valid && axi_wready;
    assign rd_issue_push = accept_any && !accept_write;
    assign rd_issue_pop = rd_issue_handshake;
    assign wr_aw_push = accept_any && accept_write;
    assign wr_aw_pop = wr_aw_handshake;
    assign wr_w_push = accept_any && accept_write;
    assign wr_w_pop = wr_w_handshake && axi_wlast;

endmodule
