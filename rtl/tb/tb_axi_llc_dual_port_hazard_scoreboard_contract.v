`timescale 1ns / 1ps

module tb_axi_llc_dual_port_hazard_scoreboard_contract;

    localparam LINE_TAG_BITS = 4;
    localparam HAZARD_AXI_ID_BITS = 4;

    reg clk;
    reg rst_n;

    reg  [LINE_TAG_BITS-1:0]      ddr_ar_line;
    reg  [LINE_TAG_BITS-1:0]      mmio_ar_line;
    reg  [LINE_TAG_BITS-1:0]      ddr_aw_line;
    reg  [LINE_TAG_BITS-1:0]      mmio_aw_line;
    reg  [HAZARD_AXI_ID_BITS-1:0] ddr_arid;
    reg  [HAZARD_AXI_ID_BITS-1:0] mmio_arid;
    reg  [HAZARD_AXI_ID_BITS-1:0] ddr_awid;
    reg  [HAZARD_AXI_ID_BITS-1:0] mmio_awid;
    reg  [HAZARD_AXI_ID_BITS-1:0] ddr_rid;
    reg  [HAZARD_AXI_ID_BITS-1:0] mmio_rid;
    reg  [HAZARD_AXI_ID_BITS-1:0] ddr_bid;
    reg  [HAZARD_AXI_ID_BITS-1:0] mmio_bid;
    reg                           ddr_ar_fire;
    reg                           mmio_ar_fire;
    reg                           ddr_aw_fire;
    reg                           mmio_aw_fire;
    reg                           ddr_r_fire;
    reg                           mmio_r_fire;
    reg                           ddr_b_fire;
    reg                           mmio_b_fire;

    wire ddr_ar_slot_hazard;
    wire mmio_ar_slot_hazard;
    wire ddr_aw_slot_hazard;
    wire mmio_aw_slot_hazard;
    wire ddr_aw_pending_read_hazard;
    wire mmio_aw_pending_read_hazard;
    wire ddr_ar_pending_write_hazard;
    wire mmio_ar_pending_write_hazard;

    always #5 clk = ~clk;

    task fail_now;
        input [8*180-1:0] msg;
        begin
            $display("tb_axi_llc_dual_port_hazard_scoreboard_contract FAIL: %0s", msg);
            $finish(1);
        end
    endtask

    task idle_inputs;
        begin
            ddr_ar_line = {LINE_TAG_BITS{1'b0}};
            mmio_ar_line = {LINE_TAG_BITS{1'b0}};
            ddr_aw_line = {LINE_TAG_BITS{1'b0}};
            mmio_aw_line = {LINE_TAG_BITS{1'b0}};
            ddr_arid = {HAZARD_AXI_ID_BITS{1'b0}};
            mmio_arid = {HAZARD_AXI_ID_BITS{1'b0}};
            ddr_awid = {HAZARD_AXI_ID_BITS{1'b0}};
            mmio_awid = {HAZARD_AXI_ID_BITS{1'b0}};
            ddr_rid = {HAZARD_AXI_ID_BITS{1'b0}};
            mmio_rid = {HAZARD_AXI_ID_BITS{1'b0}};
            ddr_bid = {HAZARD_AXI_ID_BITS{1'b0}};
            mmio_bid = {HAZARD_AXI_ID_BITS{1'b0}};
            ddr_ar_fire = 1'b0;
            mmio_ar_fire = 1'b0;
            ddr_aw_fire = 1'b0;
            mmio_aw_fire = 1'b0;
            ddr_r_fire = 1'b0;
            mmio_r_fire = 1'b0;
            ddr_b_fire = 1'b0;
            mmio_b_fire = 1'b0;
        end
    endtask

    task reset_dut;
        begin
            clk = 1'b0;
            rst_n = 1'b0;
            idle_inputs();
            repeat (4) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;
            @(negedge clk);
        end
    endtask

    task fire_ddr_ar;
        input [LINE_TAG_BITS-1:0] line;
        input [HAZARD_AXI_ID_BITS-1:0] id;
        begin
            idle_inputs();
            ddr_ar_line = line;
            ddr_arid = id;
            ddr_ar_fire = 1'b1;
            #1;
            if (ddr_ar_slot_hazard) begin
                fail_now("unexpected DDR AR slot hazard");
            end
            @(posedge clk);
            @(negedge clk);
            idle_inputs();
        end
    endtask

    task fire_mmio_ar;
        input [LINE_TAG_BITS-1:0] line;
        input [HAZARD_AXI_ID_BITS-1:0] id;
        begin
            idle_inputs();
            mmio_ar_line = line;
            mmio_arid = id;
            mmio_ar_fire = 1'b1;
            #1;
            if (mmio_ar_slot_hazard) begin
                fail_now("unexpected MMIO AR slot hazard");
            end
            @(posedge clk);
            @(negedge clk);
            idle_inputs();
        end
    endtask

    task fire_ddr_aw;
        input [LINE_TAG_BITS-1:0] line;
        input [HAZARD_AXI_ID_BITS-1:0] id;
        begin
            idle_inputs();
            ddr_aw_line = line;
            ddr_awid = id;
            ddr_aw_fire = 1'b1;
            #1;
            if (ddr_aw_slot_hazard) begin
                fail_now("unexpected DDR AW slot hazard");
            end
            @(posedge clk);
            @(negedge clk);
            idle_inputs();
        end
    endtask

    task fire_mmio_aw;
        input [LINE_TAG_BITS-1:0] line;
        input [HAZARD_AXI_ID_BITS-1:0] id;
        begin
            idle_inputs();
            mmio_aw_line = line;
            mmio_awid = id;
            mmio_aw_fire = 1'b1;
            #1;
            if (mmio_aw_slot_hazard) begin
                fail_now("unexpected MMIO AW slot hazard");
            end
            @(posedge clk);
            @(negedge clk);
            idle_inputs();
        end
    endtask

    task release_ddr_read;
        input [HAZARD_AXI_ID_BITS-1:0] id;
        begin
            idle_inputs();
            ddr_rid = id;
            ddr_r_fire = 1'b1;
            @(posedge clk);
            @(negedge clk);
            idle_inputs();
        end
    endtask

    task release_mmio_read;
        input [HAZARD_AXI_ID_BITS-1:0] id;
        begin
            idle_inputs();
            mmio_rid = id;
            mmio_r_fire = 1'b1;
            @(posedge clk);
            @(negedge clk);
            idle_inputs();
        end
    endtask

    task release_ddr_write;
        input [HAZARD_AXI_ID_BITS-1:0] id;
        begin
            idle_inputs();
            ddr_bid = id;
            ddr_b_fire = 1'b1;
            @(posedge clk);
            @(negedge clk);
            idle_inputs();
        end
    endtask

    task release_mmio_write;
        input [HAZARD_AXI_ID_BITS-1:0] id;
        begin
            idle_inputs();
            mmio_bid = id;
            mmio_b_fire = 1'b1;
            @(posedge clk);
            @(negedge clk);
            idle_inputs();
        end
    endtask

    task expect_read_hazards;
        input expect_ddr;
        input expect_mmio;
        begin
            #1;
            if (ddr_aw_pending_read_hazard !== expect_ddr) begin
                fail_now("DDR pending-read hazard mismatch");
            end
            if (mmio_aw_pending_read_hazard !== expect_mmio) begin
                fail_now("MMIO pending-read hazard mismatch");
            end
        end
    endtask

    task expect_write_hazards;
        input expect_ddr;
        input expect_mmio;
        begin
            #1;
            if (ddr_ar_pending_write_hazard !== expect_ddr) begin
                fail_now("DDR pending-write hazard mismatch");
            end
            if (mmio_ar_pending_write_hazard !== expect_mmio) begin
                fail_now("MMIO pending-write hazard mismatch");
            end
        end
    endtask

    task expect_read_slots_full;
        input expect_full;
        begin
            #1;
            if (ddr_ar_slot_hazard !== expect_full ||
                mmio_ar_slot_hazard !== expect_full) begin
                fail_now("read slot hazard mismatch");
            end
        end
    endtask

    task expect_write_slots_full;
        input expect_full;
        begin
            #1;
            if (ddr_aw_slot_hazard !== expect_full ||
                mmio_aw_slot_hazard !== expect_full) begin
                fail_now("write slot hazard mismatch");
            end
        end
    endtask

    task test_read_hazard_record_release;
        begin
            fire_ddr_ar(4'h1, 4'h2);

            idle_inputs();
            ddr_aw_line = 4'h1;
            mmio_aw_line = 4'h1;
            expect_read_hazards(1'b1, 1'b0);
            expect_read_slots_full(1'b0);

            release_ddr_read(4'h7);
            idle_inputs();
            ddr_aw_line = 4'h1;
            expect_read_hazards(1'b1, 1'b0);

            release_ddr_read(4'h2);
            idle_inputs();
            ddr_aw_line = 4'h1;
            expect_read_hazards(1'b0, 1'b0);
            expect_read_slots_full(1'b0);
        end
    endtask

    task test_dual_port_read_slots;
        begin
            fire_ddr_ar(4'h3, 4'h4);
            fire_mmio_ar(4'h5, 4'h6);

            idle_inputs();
            ddr_aw_line = 4'h3;
            mmio_aw_line = 4'h5;
            expect_read_hazards(1'b1, 1'b1);
            expect_read_slots_full(1'b1);

            release_ddr_read(4'h4);
            idle_inputs();
            ddr_aw_line = 4'h3;
            mmio_aw_line = 4'h5;
            expect_read_hazards(1'b0, 1'b1);
            expect_read_slots_full(1'b0);

            release_mmio_read(4'h6);
            idle_inputs();
            ddr_aw_line = 4'h3;
            mmio_aw_line = 4'h5;
            expect_read_hazards(1'b0, 1'b0);
        end
    endtask

    task test_write_hazard_record_release;
        begin
            fire_ddr_aw(4'h8, 4'h9);

            idle_inputs();
            ddr_ar_line = 4'h8;
            mmio_ar_line = 4'h8;
            expect_write_hazards(1'b1, 1'b0);
            expect_write_slots_full(1'b0);

            release_ddr_write(4'h1);
            idle_inputs();
            ddr_ar_line = 4'h8;
            expect_write_hazards(1'b1, 1'b0);

            release_ddr_write(4'h9);
            idle_inputs();
            ddr_ar_line = 4'h8;
            expect_write_hazards(1'b0, 1'b0);
            expect_write_slots_full(1'b0);
        end
    endtask

    task test_dual_port_write_slots;
        begin
            fire_ddr_aw(4'hA, 4'hB);
            fire_mmio_aw(4'hC, 4'hD);

            idle_inputs();
            ddr_ar_line = 4'hA;
            mmio_ar_line = 4'hC;
            expect_write_hazards(1'b1, 1'b1);
            expect_write_slots_full(1'b1);

            release_ddr_write(4'hB);
            idle_inputs();
            ddr_ar_line = 4'hA;
            mmio_ar_line = 4'hC;
            expect_write_hazards(1'b0, 1'b1);
            expect_write_slots_full(1'b0);

            release_mmio_write(4'hD);
            idle_inputs();
            ddr_ar_line = 4'hA;
            mmio_ar_line = 4'hC;
            expect_write_hazards(1'b0, 1'b0);
        end
    endtask

    axi_llc_dual_port_hazard_scoreboard #(
        .LINE_TAG_BITS(LINE_TAG_BITS),
        .HAZARD_AXI_ID_BITS(HAZARD_AXI_ID_BITS),
        .READ_HAZARD_COUNT(2),
        .WRITE_HAZARD_COUNT(2)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .ddr_ar_line(ddr_ar_line),
        .mmio_ar_line(mmio_ar_line),
        .ddr_aw_line(ddr_aw_line),
        .mmio_aw_line(mmio_aw_line),
        .ddr_arid(ddr_arid),
        .mmio_arid(mmio_arid),
        .ddr_awid(ddr_awid),
        .mmio_awid(mmio_awid),
        .ddr_rid(ddr_rid),
        .mmio_rid(mmio_rid),
        .ddr_bid(ddr_bid),
        .mmio_bid(mmio_bid),
        .ddr_ar_fire(ddr_ar_fire),
        .mmio_ar_fire(mmio_ar_fire),
        .ddr_aw_fire(ddr_aw_fire),
        .mmio_aw_fire(mmio_aw_fire),
        .ddr_r_fire(ddr_r_fire),
        .mmio_r_fire(mmio_r_fire),
        .ddr_b_fire(ddr_b_fire),
        .mmio_b_fire(mmio_b_fire),
        .ddr_ar_slot_hazard(ddr_ar_slot_hazard),
        .mmio_ar_slot_hazard(mmio_ar_slot_hazard),
        .ddr_aw_slot_hazard(ddr_aw_slot_hazard),
        .mmio_aw_slot_hazard(mmio_aw_slot_hazard),
        .ddr_aw_pending_read_hazard(ddr_aw_pending_read_hazard),
        .mmio_aw_pending_read_hazard(mmio_aw_pending_read_hazard),
        .ddr_ar_pending_write_hazard(ddr_ar_pending_write_hazard),
        .mmio_ar_pending_write_hazard(mmio_ar_pending_write_hazard)
    );

    initial begin
        reset_dut();
        expect_read_slots_full(1'b0);
        expect_write_slots_full(1'b0);

        test_read_hazard_record_release();
        test_dual_port_read_slots();
        test_write_hazard_record_release();
        test_dual_port_write_slots();

        $display("tb_axi_llc_dual_port_hazard_scoreboard_contract PASS");
        $finish;
    end

endmodule
