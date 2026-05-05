module axi_source_resp_mux_formal_top(
    input         rd_valid,
    input  [15:0] rd_data,
    input  [2:0]  rd_id,
    input  [1:0]  rd_code,
    input         wr_valid,
    input  [2:0]  wr_id,
    input  [1:0]  wr_code,
    input         resp_ready,
    output        resp_valid,
    output        select_read,
    output [15:0] resp_data,
    output [2:0]  resp_id,
    output [1:0]  resp_code,
    output        rd_pop,
    output        wr_pop
);

    axi_llc_axi_source_resp_mux #(
        .DATA_BITS(16),
        .ID_BITS(3)
    ) dut (
        .rd_valid(rd_valid),
        .rd_data(rd_data),
        .rd_id(rd_id),
        .rd_code(rd_code),
        .wr_valid(wr_valid),
        .wr_id(wr_id),
        .wr_code(wr_code),
        .resp_ready(resp_ready),
        .resp_valid(resp_valid),
        .select_read(select_read),
        .resp_data(resp_data),
        .resp_id(resp_id),
        .resp_code(resp_code),
        .rd_pop(rd_pop),
        .wr_pop(wr_pop)
    );

endmodule
