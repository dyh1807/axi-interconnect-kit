module axi_write_pack_formal_top(
    input  [63:0] line_data,
    input  [7:0]  line_strb,
    input  [7:0]  req_addr,
    input  [7:0]  issued_addr,
    input  [7:0]  beat_idx,
    input         mode2_ddr_aligned,
    output [31:0] axi_wdata,
    output [3:0]  axi_wstrb
);

    axi_llc_axi_write_pack #(
        .ADDR_BITS(8),
        .LINE_BYTES(8),
        .AXI_DATA_BYTES(4)
    ) dut (
        .line_data(line_data),
        .line_strb(line_strb),
        .req_addr(req_addr),
        .issued_addr(issued_addr),
        .beat_idx(beat_idx),
        .mode2_ddr_aligned(mode2_ddr_aligned),
        .axi_wdata(axi_wdata),
        .axi_wstrb(axi_wstrb)
    );

endmodule
