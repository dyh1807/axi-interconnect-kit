`timescale 1ns / 1ps

module tb_llc_valid_ram;

    reg clk;
    reg rd_en;
    reg [1:0] rd_set;
    wire [3:0] rd_bits;
    reg wr_en;
    reg [1:0] wr_set;
    reg [3:0] wr_mask;
    reg [3:0] wr_bits;

    llc_valid_ram #(
        .SET_COUNT (4),
        .SET_BITS  (2),
        .WAY_COUNT (4)
    ) dut (
        .clk     (clk),
        .rd_en   (rd_en),
        .rd_set  (rd_set),
        .rd_bits (rd_bits),
        .wr_en   (wr_en),
        .wr_set  (wr_set),
        .wr_mask (wr_mask),
        .wr_bits (wr_bits)
    );

    always #5 clk = ~clk;

    task expect_bits;
        input [3:0] expected;
        begin
            #1;
            if (rd_bits !== expected) begin
                $display("tb_llc_valid_ram FAIL: expected=%b got=%b", expected, rd_bits);
                $finish;
            end
        end
    endtask

    initial begin
        clk    = 1'b0;
        rd_en  = 1'b1;
        rd_set = 2'b00;
        wr_en  = 1'b0;
        wr_set = 2'b00;
        wr_mask = 4'b0000;
        wr_bits = 4'b0000;

        @(posedge clk);
        wr_en   <= 1'b1;
        wr_set  <= 2'b01;
        wr_mask <= 4'b1111;
        wr_bits <= 4'b0101;

        @(posedge clk);
        wr_en   <= 1'b0;
        rd_set  <= 2'b01;
        expect_bits(4'b0101);

        @(posedge clk);
        wr_en   <= 1'b1;
        wr_set  <= 2'b01;
        wr_mask <= 4'b0010;
        wr_bits <= 4'b0010;

        @(posedge clk);
        wr_en   <= 1'b0;
        rd_set  <= 2'b01;
        expect_bits(4'b0111);

        @(posedge clk);
        wr_en   <= 1'b1;
        wr_set  <= 2'b01;
        wr_mask <= 4'b0101;
        wr_bits <= 4'b0001;

        @(posedge clk);
        wr_en   <= 1'b0;
        rd_set  <= 2'b01;
        expect_bits(4'b0011);

        $display("tb_llc_valid_ram PASS");
        $finish;
    end

endmodule
