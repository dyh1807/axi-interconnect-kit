`timescale 1ns / 1ps

module tb_llc_repl_ram;

    reg clk;
    reg rst_n;
    reg rd_en;
    reg [1:0] rd_set;
    wire rd_valid;
    wire [1:0] rd_way;
    reg wr_en;
    reg [1:0] wr_set;
    reg [1:0] wr_way;

    llc_repl_ram #(
        .SET_COUNT (4),
        .SET_BITS  (2),
        .WAY_COUNT (4),
        .WAY_BITS  (2)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .rd_en   (rd_en),
        .rd_set  (rd_set),
        .rd_valid(rd_valid),
        .rd_way  (rd_way),
        .wr_en   (wr_en),
        .wr_set  (wr_set),
        .wr_way  (wr_way)
    );

    always #5 clk = ~clk;

    task expect_way;
        input expected_valid;
        input [1:0] expected_way;
        begin
            #1;
            if (rd_valid !== expected_valid) begin
                $display("tb_llc_repl_ram FAIL: expected_valid=%b got=%b",
                         expected_valid,
                         rd_valid);
                $finish;
            end
            if (expected_valid && (rd_way !== expected_way)) begin
                $display("tb_llc_repl_ram FAIL: expected_way=%0d got=%0d",
                         expected_way,
                         rd_way);
                $finish;
            end
        end
    endtask

    initial begin
        clk   = 1'b0;
        rst_n = 1'b0;
        rd_en = 1'b0;
        rd_set = 2'b00;
        wr_en = 1'b0;
        wr_set = 2'b00;
        wr_way = 2'b00;

        repeat (2) @(posedge clk);
        rst_n <= 1'b1;

        @(posedge clk);
        wr_en  <= 1'b1;
        wr_set <= 2'b01;
        wr_way <= 2'b10;

        @(posedge clk);
        wr_en  <= 1'b0;
        rd_en  <= 1'b1;
        rd_set <= 2'b01;

        @(posedge clk);
        rd_en <= 1'b0;
        expect_way(1'b1, 2'b10);

        @(posedge clk);
        wr_en  <= 1'b1;
        wr_set <= 2'b01;
        wr_way <= 2'b11;

        @(posedge clk);
        wr_en  <= 1'b0;
        rd_en  <= 1'b1;
        rd_set <= 2'b01;

        @(posedge clk);
        rd_en <= 1'b0;
        expect_way(1'b1, 2'b11);

        $display("tb_llc_repl_ram PASS");
        $finish;
    end

endmodule
