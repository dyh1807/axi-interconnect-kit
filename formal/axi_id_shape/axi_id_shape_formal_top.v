module axi_id_shape_formal_top(
    input      [7:0] id_in,
    output     [7:0] id_6_to_8,
    output     [7:0] id_3_to_8,
    output     [7:0] id_8_to_6,
    output     [7:0] id_6_to_6
);

    wire [5:0] id_8_to_6_w;
    wire [5:0] id_6_to_6_w;

    axi_llc_axi_id_shape #(
        .IN_ID_BITS(6),
        .OUT_ID_BITS(8)
    ) id_6_to_8_dut (
        .id_in(id_in[5:0]),
        .id_out(id_6_to_8)
    );

    axi_llc_axi_id_shape #(
        .IN_ID_BITS(3),
        .OUT_ID_BITS(8)
    ) id_3_to_8_dut (
        .id_in(id_in[2:0]),
        .id_out(id_3_to_8)
    );

    axi_llc_axi_id_shape #(
        .IN_ID_BITS(8),
        .OUT_ID_BITS(6)
    ) id_8_to_6_dut (
        .id_in(id_in),
        .id_out(id_8_to_6_w)
    );

    axi_llc_axi_id_shape #(
        .IN_ID_BITS(6),
        .OUT_ID_BITS(6)
    ) id_6_to_6_dut (
        .id_in(id_in[5:0]),
        .id_out(id_6_to_6_w)
    );

    assign id_8_to_6 = {2'b00, id_8_to_6_w};
    assign id_6_to_6 = {2'b00, id_6_to_6_w};

endmodule
