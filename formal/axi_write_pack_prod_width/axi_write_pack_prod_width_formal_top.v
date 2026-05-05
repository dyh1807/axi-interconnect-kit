module axi_write_pack_prod_width_formal_top(
    input  [63:0] line_data_0,
    input  [63:0] line_data_1,
    input  [63:0] line_data_2,
    input  [63:0] line_data_3,
    input  [63:0] line_data_4,
    input  [63:0] line_data_5,
    input  [63:0] line_data_6,
    input  [63:0] line_data_7,
    input  [63:0] line_strb,
    input  [31:0] req_addr,
    input  [31:0] issued_addr,
    input  [7:0]  beat_idx,
    input         mode2_ddr_aligned,
    output [63:0] axi_wdata_0,
    output [63:0] axi_wdata_1,
    output [63:0] axi_wdata_2,
    output [63:0] axi_wdata_3,
    output [31:0] axi_wstrb
);

    wire [511:0] line_data_w;
    wire [255:0] axi_wdata_w;

    assign line_data_w = {
        line_data_7,
        line_data_6,
        line_data_5,
        line_data_4,
        line_data_3,
        line_data_2,
        line_data_1,
        line_data_0
    };

    assign axi_wdata_0 = axi_wdata_w[63:0];
    assign axi_wdata_1 = axi_wdata_w[127:64];
    assign axi_wdata_2 = axi_wdata_w[191:128];
    assign axi_wdata_3 = axi_wdata_w[255:192];

    axi_llc_axi_write_pack #(
        .ADDR_BITS(32),
        .LINE_BYTES(64),
        .AXI_DATA_BYTES(32)
    ) dut (
        .line_data(line_data_w),
        .line_strb(line_strb),
        .req_addr(req_addr),
        .issued_addr(issued_addr),
        .beat_idx(beat_idx),
        .mode2_ddr_aligned(mode2_ddr_aligned),
        .axi_wdata(axi_wdata_w),
        .axi_wstrb(axi_wstrb)
    );

endmodule
