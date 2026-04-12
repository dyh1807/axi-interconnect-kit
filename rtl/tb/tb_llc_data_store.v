`timescale 1ns / 1ps

module tb_llc_data_store;

    reg clk;
    reg rd_en;
    reg [1:0] rd_set;
    wire [255:0] rd_row;
    reg wr_en;
    reg [1:0] wr_set;
    reg [3:0] wr_way_mask;
    reg [255:0] wr_row;

    llc_data_store #(
        .SET_COUNT (4),
        .SET_BITS  (2),
        .WAY_COUNT (4),
        .LINE_BITS (64),
        .ROW_BITS  (256)
    ) dut (
        .clk        (clk),
        .rd_en      (rd_en),
        .rd_set     (rd_set),
        .rd_row     (rd_row),
        .wr_en      (wr_en),
        .wr_set     (wr_set),
        .wr_way_mask(wr_way_mask),
        .wr_row     (wr_row)
    );

    always #5 clk = ~clk;

    initial begin
        clk         = 1'b0;
        rd_en       = 1'b1;
        rd_set      = 2'b00;
        wr_en       = 1'b0;
        wr_set      = 2'b00;
        wr_way_mask = 4'b0000;
        wr_row      = 256'h0;

        @(posedge clk);
        wr_en       <= 1'b1;
        wr_set      <= 2'b10;
        wr_way_mask <= 4'b0010;
        wr_row      <= 256'h0;
        wr_row[127:64] <= 64'h1122_3344_5566_7788;

        @(posedge clk);
        wr_en  <= 1'b0;
        rd_set <= 2'b10;
        #1;
        if (rd_row[127:64] !== 64'h1122_3344_5566_7788) begin
            $display("tb_llc_data_store FAIL: write/read mismatch");
            $finish;
        end

        @(posedge clk);
        wr_en       <= 1'b1;
        wr_set      <= 2'b10;
        wr_way_mask <= 4'b1000;
        wr_row      <= 256'h0;
        wr_row[255:192] <= 64'hAABB_CCDD_EEFF_0011;

        @(posedge clk);
        wr_en  <= 1'b0;
        rd_set <= 2'b10;
        #1;
        if (rd_row[127:64] !== 64'h1122_3344_5566_7788 ||
            rd_row[255:192] !== 64'hAABB_CCDD_EEFF_0011) begin
            $display("tb_llc_data_store FAIL: masked row update mismatch");
            $finish;
        end

        $display("tb_llc_data_store PASS");
        $finish;
    end

endmodule
