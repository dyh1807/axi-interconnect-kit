module axi_beat_shape_formal_top(
    input      [7:0] total_size,
    output     [7:0] total_beats_32b,
    output     [7:0] axi_len_32b,
    output     [2:0] axi_size_32b,
    output     [7:0] total_beats_4b,
    output     [7:0] axi_len_4b,
    output     [2:0] axi_size_4b
);

    axi_llc_axi_beat_shape #(
        .AXI_DATA_BYTES(32)
    ) shape_32b (
        .total_size(total_size),
        .total_beats(total_beats_32b),
        .axi_len(axi_len_32b),
        .axi_size(axi_size_32b)
    );

    axi_llc_axi_beat_shape #(
        .AXI_DATA_BYTES(4)
    ) shape_4b (
        .total_size(total_size),
        .total_beats(total_beats_4b),
        .axi_len(axi_len_4b),
        .axi_size(axi_size_4b)
    );

endmodule
