`timescale 1ns / 1ps

// Source-local response mux for cache/bypass response queues in
// axi_llc_axi_bridge. Read responses take priority over write responses.
module axi_llc_axi_source_resp_mux #(
    parameter DATA_BITS = 512,
    parameter ID_BITS   = 4
) (
    input                       rd_valid,
    input      [DATA_BITS-1:0]  rd_data,
    input      [ID_BITS-1:0]    rd_id,
    input      [1:0]            rd_code,
    input                       wr_valid,
    input      [ID_BITS-1:0]    wr_id,
    input      [1:0]            wr_code,
    input                       resp_ready,
    output                      resp_valid,
    output                      select_read,
    output     [DATA_BITS-1:0]  resp_data,
    output     [ID_BITS-1:0]    resp_id,
    output     [1:0]            resp_code,
    output                      rd_pop,
    output                      wr_pop
);

    assign select_read = rd_valid;
    assign resp_valid = rd_valid || wr_valid;
    assign resp_data = select_read ? rd_data : {DATA_BITS{1'b0}};
    assign resp_id = select_read ? rd_id : wr_id;
    assign resp_code = select_read ? rd_code : wr_code;
    assign rd_pop = resp_valid && resp_ready && select_read;
    assign wr_pop = resp_valid && resp_ready && !select_read && wr_valid;

endmodule
