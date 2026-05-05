`timescale 1ns / 1ps

// External AXI response acceptance control for axi_llc_axi_bridge.
//
// Read responses are accepted as soon as their AXI ID matches a pending read
// slot. The assembled read line is pushed into the source-local response queue
// one cycle later, so upstream cache/bypass response ready does not backpressure
// AXI R.
//
// Write responses are accepted only when the matching source-local write
// response queue has space, because B carries the final write completion itself.
module axi_llc_axi_resp_accept (
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

    assign axi_rready = rd_match_found;
    assign rd_resp_accept = axi_rvalid && rd_match_found;
    assign axi_bready = wr_match_found && wr_match_rsp_space;
    assign wr_resp_accept = axi_bvalid && wr_match_found && wr_match_rsp_space;

endmodule
