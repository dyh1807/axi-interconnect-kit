`timescale 1ns / 1ps

module tb_llc_invalidate_sweep;

    localparam SET_COUNT = 5;
    localparam SET_BITS  = 3;
    localparam WAY_COUNT = 4;

    reg clk;
    reg rst_n;
    reg start;

    wire                 busy;
    wire                 done;
    wire                 valid_wr_en;
    wire [SET_BITS-1:0]  valid_wr_set;
    wire [WAY_COUNT-1:0] valid_wr_mask;
    wire [WAY_COUNT-1:0] valid_wr_bits;

    integer observed_cycles;

    llc_invalidate_sweep #(
        .SET_COUNT(SET_COUNT),
        .SET_BITS (SET_BITS),
        .WAY_COUNT(WAY_COUNT)
    ) dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (start),
        .busy        (busy),
        .done        (done),
        .valid_wr_en (valid_wr_en),
        .valid_wr_set(valid_wr_set),
        .valid_wr_mask(valid_wr_mask),
        .valid_wr_bits(valid_wr_bits)
    );

    always #5 clk = ~clk;

    task expect_busy_cycle;
        input [SET_BITS-1:0] expect_set;
        begin
            if (!busy) begin
                $display("tb_llc_invalidate_sweep FAIL: expected busy at set %0d", expect_set);
                $finish;
            end
            if (!valid_wr_en) begin
                $display("tb_llc_invalidate_sweep FAIL: expected valid_wr_en at set %0d", expect_set);
                $finish;
            end
            if (done) begin
                $display("tb_llc_invalidate_sweep FAIL: done asserted while sweeping set %0d", expect_set);
                $finish;
            end
            if (valid_wr_set !== expect_set) begin
                $display("tb_llc_invalidate_sweep FAIL: expected set %0d got %0d", expect_set, valid_wr_set);
                $finish;
            end
            if (valid_wr_mask !== {WAY_COUNT{1'b1}}) begin
                $display("tb_llc_invalidate_sweep FAIL: expected wr_mask all ones");
                $finish;
            end
            if (valid_wr_bits !== {WAY_COUNT{1'b0}}) begin
                $display("tb_llc_invalidate_sweep FAIL: expected wr_bits all zeros");
                $finish;
            end
            observed_cycles = observed_cycles + 1;
        end
    endtask

    task expect_idle;
        input expect_done;
        begin
            if (busy) begin
                $display("tb_llc_invalidate_sweep FAIL: expected idle");
                $finish;
            end
            if (valid_wr_en) begin
                $display("tb_llc_invalidate_sweep FAIL: valid_wr_en asserted while idle");
                $finish;
            end
            if (done !== expect_done) begin
                $display("tb_llc_invalidate_sweep FAIL: expected done=%0d got %0d", expect_done, done);
                $finish;
            end
            if (valid_wr_set !== {SET_BITS{1'b0}}) begin
                $display("tb_llc_invalidate_sweep FAIL: expected set reset to zero while idle");
                $finish;
            end
            if (valid_wr_mask !== {WAY_COUNT{1'b1}}) begin
                $display("tb_llc_invalidate_sweep FAIL: expected wr_mask all ones while idle");
                $finish;
            end
            if (valid_wr_bits !== {WAY_COUNT{1'b0}}) begin
                $display("tb_llc_invalidate_sweep FAIL: expected wr_bits all zeros while idle");
                $finish;
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        start = 1'b0;
        observed_cycles = 0;

        repeat (2) @(posedge clk);
        #1;
        expect_idle(1'b0);

        rst_n = 1'b1;
        @(posedge clk);
        #1;
        expect_idle(1'b0);

        start = 1'b1;
        @(posedge clk);
        #1;
        expect_busy_cycle({SET_BITS{1'b0}});

        start = 1'b0;
        @(posedge clk);
        #1;
        expect_busy_cycle(3'd1);

        start = 1'b1;
        @(posedge clk);
        #1;
        expect_busy_cycle(3'd2);

        start = 1'b0;
        @(posedge clk);
        #1;
        expect_busy_cycle(3'd3);

        @(posedge clk);
        #1;
        expect_busy_cycle(3'd4);

        @(posedge clk);
        #1;
        expect_idle(1'b1);
        if (observed_cycles !== SET_COUNT) begin
            $display("tb_llc_invalidate_sweep FAIL: expected %0d sweep cycles got %0d", SET_COUNT, observed_cycles);
            $finish;
        end

        @(posedge clk);
        #1;
        expect_idle(1'b0);

        observed_cycles = 0;
        start = 1'b1;
        @(posedge clk);
        #1;
        expect_busy_cycle({SET_BITS{1'b0}});

        start = 1'b0;
        @(posedge clk);
        #1;
        expect_busy_cycle(3'd1);

        @(posedge clk);
        #1;
        expect_busy_cycle(3'd2);

        @(posedge clk);
        #1;
        expect_busy_cycle(3'd3);

        @(posedge clk);
        #1;
        expect_busy_cycle(3'd4);

        @(posedge clk);
        #1;
        expect_idle(1'b1);
        if (observed_cycles !== SET_COUNT) begin
            $display("tb_llc_invalidate_sweep FAIL: second sweep cycle count mismatch");
            $finish;
        end

        $display("tb_llc_invalidate_sweep PASS");
        $finish;
    end

endmodule
