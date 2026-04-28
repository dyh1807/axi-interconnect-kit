`timescale 1ns / 1ps

module tb_llc_meta_store;

    reg clk;
    reg rst_n;
    reg rd_en;
    reg [1:0] rd_set;
    wire rd_valid;
    wire [95:0] rd_row;
    reg wr_en;
    reg [1:0] wr_set;
    reg [3:0] wr_way_mask;
    reg [95:0] wr_row;
    wire busy;

    llc_meta_store #(
        .SET_COUNT (4),
        .SET_BITS  (2),
        .WAY_COUNT (4),
        .META_BITS (24),
        .ROW_BITS  (96)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .rd_en      (rd_en),
        .rd_set     (rd_set),
        .rd_valid   (rd_valid),
        .rd_row     (rd_row),
        .wr_en      (wr_en),
        .wr_set     (wr_set),
        .wr_way_mask(wr_way_mask),
        .wr_row     (wr_row),
        .busy       (busy)
    );

    always #5 clk = ~clk;

    task wait_read_valid;
        integer wait_cycles;
        reg seen;
        begin
            seen = 1'b0;
            for (wait_cycles = 0; wait_cycles < 16; wait_cycles = wait_cycles + 1) begin
                #1;
                if (rd_valid) begin
                    seen = 1'b1;
                    wait_cycles = 16;
                end else begin
                    @(posedge clk);
                end
            end
            if (!seen || busy) begin
                $display("tb_llc_meta_store FAIL: expected valid read after write");
                $finish;
            end
        end
    endtask

    initial begin
        clk         = 1'b0;
        rst_n       = 1'b0;
        rd_en       = 1'b0;
        rd_set      = 2'b00;
        wr_en       = 1'b0;
        wr_set      = 2'b00;
        wr_way_mask = 4'b0000;
        wr_row      = 96'h0;

        repeat (2) @(posedge clk);
        rst_n <= 1'b1;

        @(posedge clk);
        wr_en       <= 1'b1;
        wr_set      <= 2'b01;
        wr_way_mask <= 4'b0101;
        wr_row      <= 96'h0;
        wr_row[23:0]  <= 24'h00AA11;
        wr_row[71:48] <= 24'hBB22CC;

        @(posedge clk);
        wr_en  <= 1'b0;
        #1;
        if (!busy) begin
            $display("tb_llc_meta_store FAIL: expected busy during write staging");
            $finish;
        end

        @(posedge clk);
        rd_set <= 2'b01;
        rd_en  <= 1'b1;

        @(posedge clk);
        rd_en <= 1'b0;
        wait_read_valid();
        if (rd_row[23:0] !== 24'h00AA11 || rd_row[71:48] !== 24'hBB22CC) begin
            $display("tb_llc_meta_store FAIL: masked meta update mismatch");
            $finish;
        end

        $display("tb_llc_meta_store PASS");
        $finish;
    end

endmodule
