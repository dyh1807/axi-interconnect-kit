module axi_mode2_shape_single4_formal_top(
    input  [7:0] addr,
    input  [7:0] total_size,
    output       single_axi_beat,
    output [7:0] issue_addr,
    output [7:0] issue_size
);

    axi_llc_axi_mode2_shape #(
        .ADDR_BITS(8),
        .LINE_BYTES(4),
        .AXI_DATA_BYTES(4)
    ) dut (
        .addr(addr),
        .total_size(total_size),
        .single_axi_beat(single_axi_beat),
        .issue_addr(issue_addr),
        .issue_size(issue_size)
    );

endmodule
