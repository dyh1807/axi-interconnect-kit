module axi_fifo_ptr_formal_top(
    input  [7:0] head,
    input  [7:0] tail,
    input  [7:0] count,
    input        push,
    input        pop,
    output [7:0] next_head,
    output [7:0] next_tail,
    output [7:0] next_count
);

    axi_llc_axi_fifo_ptr #(
        .DEPTH(4)
    ) dut (
        .head(head),
        .tail(tail),
        .count(count),
        .push(push),
        .pop(pop),
        .next_head(next_head),
        .next_tail(next_tail),
        .next_count(next_count)
    );

endmodule
