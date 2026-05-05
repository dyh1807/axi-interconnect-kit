`timescale 1ns / 1ps

// FIFO head/tail/count update helper used by axi_llc_axi_bridge queues.
module axi_llc_axi_fifo_ptr #(
    parameter DEPTH = 32
) (
    input      [7:0] head,
    input      [7:0] tail,
    input      [7:0] count,
    input            push,
    input            pop,
    output     [7:0] next_head,
    output     [7:0] next_tail,
    output reg [7:0] next_count
);

    localparam [7:0] DEPTH_LAST = (DEPTH <= 1) ? 8'd0 : (DEPTH - 1);

    function [7:0] next_ptr;
        input [7:0] ptr_value;
        begin
            if (ptr_value == DEPTH_LAST) begin
                next_ptr = 8'd0;
            end else begin
                next_ptr = ptr_value + 8'd1;
            end
        end
    endfunction

    assign next_head = pop ? next_ptr(head) : head;
    assign next_tail = push ? next_ptr(tail) : tail;

    always @(*) begin
        if (push && !pop) begin
            next_count = count + 8'd1;
        end else if (!push && pop) begin
            next_count = count - 8'd1;
        end else begin
            next_count = count;
        end
    end

endmodule
