module axi_read_pack_single4_formal_top(
    input  [31:0] current_data,
    input  [31:0] beat_data,
    input  [7:0]  req_addr,
    input  [7:0]  issued_addr,
    input  [7:0]  beat_idx,
    input         mode2_ddr_aligned,
    output [31:0] merged_data,
    output [31:0] final_data
);

    axi_llc_axi_read_pack #(
        .ADDR_BITS(8),
        .READ_RESP_BYTES(4),
        .AXI_DATA_BYTES(4),
        .MODE2_EXTRACT_BYTES(4)
    ) dut (
        .current_data(current_data),
        .beat_data(beat_data),
        .req_addr(req_addr),
        .issued_addr(issued_addr),
        .beat_idx(beat_idx),
        .mode2_ddr_aligned(mode2_ddr_aligned),
        .merged_data(merged_data),
        .final_data(final_data)
    );

endmodule
