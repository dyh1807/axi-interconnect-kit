module axi_read_pack_prod_width_formal_top(
    input  [63:0] current_data_0,
    input  [63:0] current_data_1,
    input  [63:0] current_data_2,
    input  [63:0] current_data_3,
    input  [63:0] current_data_4,
    input  [63:0] current_data_5,
    input  [63:0] current_data_6,
    input  [63:0] current_data_7,
    input  [63:0] beat_data_0,
    input  [63:0] beat_data_1,
    input  [63:0] beat_data_2,
    input  [63:0] beat_data_3,
    input  [31:0] req_addr,
    input  [31:0] issued_addr,
    input  [7:0]  beat_idx,
    input         mode2_ddr_aligned,
    output [63:0] merged_data_0,
    output [63:0] merged_data_1,
    output [63:0] merged_data_2,
    output [63:0] merged_data_3,
    output [63:0] merged_data_4,
    output [63:0] merged_data_5,
    output [63:0] merged_data_6,
    output [63:0] merged_data_7,
    output [63:0] final_data_0,
    output [63:0] final_data_1,
    output [63:0] final_data_2,
    output [63:0] final_data_3,
    output [63:0] final_data_4,
    output [63:0] final_data_5,
    output [63:0] final_data_6,
    output [63:0] final_data_7
);

    wire [511:0] current_data_w;
    wire [255:0] beat_data_w;
    wire [511:0] merged_data_w;
    wire [511:0] final_data_w;

    assign current_data_w = {
        current_data_7,
        current_data_6,
        current_data_5,
        current_data_4,
        current_data_3,
        current_data_2,
        current_data_1,
        current_data_0
    };
    assign beat_data_w = {
        beat_data_3,
        beat_data_2,
        beat_data_1,
        beat_data_0
    };

    assign merged_data_0 = merged_data_w[63:0];
    assign merged_data_1 = merged_data_w[127:64];
    assign merged_data_2 = merged_data_w[191:128];
    assign merged_data_3 = merged_data_w[255:192];
    assign merged_data_4 = merged_data_w[319:256];
    assign merged_data_5 = merged_data_w[383:320];
    assign merged_data_6 = merged_data_w[447:384];
    assign merged_data_7 = merged_data_w[511:448];

    assign final_data_0 = final_data_w[63:0];
    assign final_data_1 = final_data_w[127:64];
    assign final_data_2 = final_data_w[191:128];
    assign final_data_3 = final_data_w[255:192];
    assign final_data_4 = final_data_w[319:256];
    assign final_data_5 = final_data_w[383:320];
    assign final_data_6 = final_data_w[447:384];
    assign final_data_7 = final_data_w[511:448];

    axi_llc_axi_read_pack #(
        .ADDR_BITS(32),
        .READ_RESP_BYTES(64),
        .AXI_DATA_BYTES(32)
    ) dut (
        .current_data(current_data_w),
        .beat_data(beat_data_w),
        .req_addr(req_addr),
        .issued_addr(issued_addr),
        .beat_idx(beat_idx),
        .mode2_ddr_aligned(mode2_ddr_aligned),
        .merged_data(merged_data_w),
        .final_data(final_data_w)
    );

endmodule
