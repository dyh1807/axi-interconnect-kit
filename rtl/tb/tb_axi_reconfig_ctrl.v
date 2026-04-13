`timescale 1ns / 1ps

module tb_axi_reconfig_ctrl;

    reg         clk;
    reg         rst_n;
    reg  [1:0]  req_mode;
    reg  [31:0] req_offset;
    reg         invalidate_all_valid;
    reg         global_quiescent;
    reg         sweep_busy;
    reg         sweep_done;

    wire        invalidate_all_accepted;
    wire [1:0]  active_mode;
    wire [31:0] active_offset;
    wire [1:0]  target_mode;
    wire [31:0] target_offset;
    wire        block_accepts;
    wire        busy;
    wire        sweep_start;
    wire [1:0]  state;

    axi_reconfig_ctrl dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .req_mode         (req_mode),
        .req_offset       (req_offset),
        .invalidate_all_valid(invalidate_all_valid),
        .global_quiescent (global_quiescent),
        .sweep_busy       (sweep_busy),
        .sweep_done       (sweep_done),
        .invalidate_all_accepted(invalidate_all_accepted),
        .active_mode      (active_mode),
        .active_offset    (active_offset),
        .target_mode      (target_mode),
        .target_offset    (target_offset),
        .block_accepts    (block_accepts),
        .busy             (busy),
        .sweep_start      (sweep_start),
        .state            (state)
    );

    always #5 clk = ~clk;

    task wait_state;
        input [1:0] expect_state;
        integer guard;
        begin
            guard = 0;
            while (state !== expect_state) begin
                @(posedge clk);
                guard = guard + 1;
                if (guard > 32) begin
                    $display("tb_axi_reconfig_ctrl FAIL: timeout waiting state=%0d current=%0d", expect_state, state);
                    $finish;
                end
            end
        end
    endtask

    task complete_sweep_once;
        integer guard;
        begin
            guard = 0;
            while (!sweep_start) begin
                @(posedge clk);
                guard = guard + 1;
                if (guard > 32) begin
                    $display("tb_axi_reconfig_ctrl FAIL: timeout waiting sweep_start");
                    $finish;
                end
            end
            sweep_busy <= 1'b1;
            @(posedge clk);
            sweep_busy <= 1'b0;
            sweep_done <= 1'b1;
            @(posedge clk);
            sweep_done <= 1'b0;
        end
    endtask

    initial begin
        clk              = 1'b0;
        rst_n            = 1'b0;
        req_mode         = 2'b01;
        req_offset       = 32'h0000_0000;
        invalidate_all_valid = 1'b0;
        global_quiescent = 1'b0;
        sweep_busy       = 1'b0;
        sweep_done       = 1'b0;

        repeat (2) @(posedge clk);
        rst_n <= 1'b1;

        complete_sweep_once();
        wait_state(2'b11);
        @(posedge clk);

        wait_state(2'b00);
        if (active_mode !== 2'b01 || active_offset !== 32'h0000_0000) begin
            $display("tb_axi_reconfig_ctrl FAIL: reset default mismatch");
            $finish;
        end

        req_mode   <= 2'b10;
        req_offset <= 32'h0000_1000;

        wait_state(2'b01);
        if (state !== 2'b01 || !block_accepts || !busy) begin
            $display("tb_axi_reconfig_ctrl FAIL: expected DRAIN");
            $finish;
        end

        req_mode   <= 2'b01;
        req_offset <= 32'h0000_2000;

        @(posedge clk);
        #1;
        if (target_mode !== 2'b01 || target_offset !== 32'h0000_2000) begin
            $display("tb_axi_reconfig_ctrl FAIL: target did not converge in DRAIN");
            $finish;
        end

        global_quiescent <= 1'b1;
        @(posedge clk);
        global_quiescent <= 1'b0;
        wait_state(2'b10);
        if (state !== 2'b10) begin
            $display("tb_axi_reconfig_ctrl FAIL: expected INV_SWEEP");
            $finish;
        end

        complete_sweep_once();
        wait_state(2'b11);
        if (state !== 2'b11) begin
            $display("tb_axi_reconfig_ctrl FAIL: expected ACTIVATE");
            $finish;
        end
        if (!invalidate_all_accepted) begin
            $display("tb_axi_reconfig_ctrl FAIL: invalidate_all_accepted should pulse on ACTIVATE");
            $finish;
        end

        wait_state(2'b00);
        if (state !== 2'b00 || active_mode !== 2'b01 || active_offset !== 32'h0000_2000) begin
            $display("tb_axi_reconfig_ctrl FAIL: activate result mismatch");
            $finish;
        end

        $display("tb_axi_reconfig_ctrl PASS");
        $finish;
    end

endmodule
