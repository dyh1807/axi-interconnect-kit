`timescale 1ns / 1ps

module llc_mshr_pending_scan_timing_probe (
    input  clk,
    output sink
);
    localparam ADDR_BITS = 32;
    localparam ID_BITS = 6;
    localparam LINE_OFFSET_BITS = 6;
    localparam MSHR_COUNT = 32;

    reg [ADDR_BITS-1:0] req_addr_r;
    reg [ID_BITS-1:0] req_id_r;
    reg [ADDR_BITS-1:0] invalidate_line_addr_r;
    reg [MSHR_COUNT-1:0] mshr_valid_r;
    reg [MSHR_COUNT-1:0] mshr_is_write_r;
    reg [MSHR_COUNT-1:0] mshr_committed_r;
    reg [MSHR_COUNT-1:0] mshr_victim_dirty_r;
    reg [MSHR_COUNT-1:0] mshr_wb_done_r;
    reg [MSHR_COUNT-1:0] mshr_wb_issued_r;
    reg [MSHR_COUNT-1:0] mshr_refill_valid_r;
    reg [MSHR_COUNT-1:0] mshr_need_refill_r;
    reg [(MSHR_COUNT*ADDR_BITS)-1:0] mshr_addr_r;
    reg [(MSHR_COUNT*ADDR_BITS)-1:0] mshr_victim_addr_r;

    wire req_line_mshr_pending_w;
    wire req_victim_line_pending_w;
    wire req_master_mshr_pending_w;
    wire mshr_any_valid_w;
    wire invalidate_line_mshr_pending_w;
    wire invalidate_line_victim_pending_w;
    wire [MSHR_COUNT-1:0] victim_line_valid_w;
    wire [(MSHR_COUNT*ADDR_BITS)-1:0] victim_line_addr_w;

    reg sink_r;
    assign sink = sink_r;

    llc_mshr_pending_scan #(
        .ADDR_BITS(ADDR_BITS),
        .ID_BITS(ID_BITS),
        .LINE_OFFSET_BITS(LINE_OFFSET_BITS),
        .MSHR_COUNT(MSHR_COUNT)
    ) dut (
        .req_addr(req_addr_r),
        .req_id(req_id_r),
        .invalidate_line_addr(invalidate_line_addr_r),
        .mshr_valid(mshr_valid_r),
        .mshr_is_write(mshr_is_write_r),
        .mshr_committed(mshr_committed_r),
        .mshr_victim_dirty(mshr_victim_dirty_r),
        .mshr_wb_done(mshr_wb_done_r),
        .mshr_wb_issued(mshr_wb_issued_r),
        .mshr_refill_valid(mshr_refill_valid_r),
        .mshr_need_refill(mshr_need_refill_r),
        .mshr_addr(mshr_addr_r),
        .mshr_victim_addr(mshr_victim_addr_r),
        .req_line_mshr_pending(req_line_mshr_pending_w),
        .req_victim_line_pending(req_victim_line_pending_w),
        .req_master_mshr_pending(req_master_mshr_pending_w),
        .mshr_any_valid(mshr_any_valid_w),
        .invalidate_line_mshr_pending(invalidate_line_mshr_pending_w),
        .invalidate_line_victim_pending(invalidate_line_victim_pending_w),
        .victim_line_valid(victim_line_valid_w),
        .victim_line_addr(victim_line_addr_w)
    );

    always @(posedge clk) begin
        req_addr_r <= {req_addr_r[30:0],
                       req_line_mshr_pending_w ^ req_victim_line_pending_w};
        invalidate_line_addr_r <= {invalidate_line_addr_r[30:0],
                                   invalidate_line_mshr_pending_w ^
                                   invalidate_line_victim_pending_w};
        req_id_r <= req_id_r + {{(ID_BITS-1){1'b0}}, 1'b1};
        mshr_valid_r <= {mshr_valid_r[MSHR_COUNT-2:0], mshr_any_valid_w};
        mshr_is_write_r <= {mshr_is_write_r[MSHR_COUNT-2:0],
                            req_master_mshr_pending_w};
        mshr_committed_r <= {mshr_committed_r[MSHR_COUNT-2:0],
                             req_line_mshr_pending_w};
        mshr_victim_dirty_r <= {mshr_victim_dirty_r[MSHR_COUNT-2:0],
                                req_victim_line_pending_w};
        mshr_wb_done_r <= {mshr_wb_done_r[MSHR_COUNT-2:0],
                           invalidate_line_mshr_pending_w};
        mshr_wb_issued_r <= {mshr_wb_issued_r[MSHR_COUNT-2:0],
                             invalidate_line_victim_pending_w};
        mshr_refill_valid_r <= {mshr_refill_valid_r[MSHR_COUNT-2:0],
                                ^victim_line_valid_w};
        mshr_need_refill_r <= {mshr_need_refill_r[MSHR_COUNT-2:0],
                               ^victim_line_addr_w};
        mshr_addr_r <= {mshr_addr_r[(MSHR_COUNT*ADDR_BITS)-2:0],
                        req_master_mshr_pending_w};
        mshr_victim_addr_r <= {mshr_victim_addr_r[(MSHR_COUNT*ADDR_BITS)-2:0],
                               mshr_any_valid_w};
        sink_r <= req_line_mshr_pending_w ^
                  req_victim_line_pending_w ^
                  req_master_mshr_pending_w ^
                  mshr_any_valid_w ^
                  invalidate_line_mshr_pending_w ^
                  invalidate_line_victim_pending_w ^
                  ^victim_line_valid_w ^
                  ^victim_line_addr_w;
    end
endmodule
