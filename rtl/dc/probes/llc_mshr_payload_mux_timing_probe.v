`timescale 1ns / 1ps

module llc_mshr_payload_mux_timing_probe (
    input  clk,
    output sink
);
    localparam ADDR_BITS = 32;
    localparam ID_BITS = 6;
    localparam LINE_BITS = 512;
    localparam LINE_BYTES = 64;
    localparam RESP_WORD_BITS = 32;
    localparam LINE_OFFSET_BITS = 6;
    localparam MSHR_COUNT = 32;

    reg [ID_BITS-1:0] issue_slot_r;
    reg [ID_BITS-1:0] commit_slot_r;
    reg               issue_write_r;
    reg               commit_is_write_r;
    reg               commit_need_refill_r;
    reg               state_mem_req_valid_r;
    reg [LINE_BITS-1:0] state_mem_req_wdata_r;
    reg [(MSHR_COUNT*ADDR_BITS)-1:0] mshr_addr_r;
    reg [(MSHR_COUNT*LINE_BITS)-1:0] mshr_victim_data_r;
    reg [(MSHR_COUNT*LINE_BITS)-1:0] mshr_refill_line_r;
    reg [(MSHR_COUNT*LINE_BITS)-1:0] mshr_wdata_r;
    reg [(MSHR_COUNT*LINE_BYTES)-1:0] mshr_wstrb_r;
    reg sink_r;

    assign sink = sink_r;

    function [ADDR_BITS-1:0] addr_at;
        input [(MSHR_COUNT*ADDR_BITS)-1:0] values;
        input [ID_BITS-1:0] slot;
        begin
            addr_at = values[(slot * ADDR_BITS) +: ADDR_BITS];
        end
    endfunction

    function [LINE_BITS-1:0] line_at;
        input [(MSHR_COUNT*LINE_BITS)-1:0] values;
        input [ID_BITS-1:0] slot;
        begin
            line_at = values[(slot * LINE_BITS) +: LINE_BITS];
        end
    endfunction

    function [LINE_BYTES-1:0] wstrb_at;
        input [(MSHR_COUNT*LINE_BYTES)-1:0] values;
        input [ID_BITS-1:0] slot;
        begin
            wstrb_at = values[(slot * LINE_BYTES) +: LINE_BYTES];
        end
    endfunction

    function [LINE_BITS-1:0] merge_line;
        input [LINE_BITS-1:0] base_line;
        input [ADDR_BITS-1:0] addr_value;
        input [LINE_BITS-1:0] write_data;
        input [LINE_BYTES-1:0] write_strobe;
        integer src_idx;
        integer line_off;
        integer dst_idx;
        begin
            merge_line = base_line;
            line_off = addr_value[LINE_OFFSET_BITS-1:0];
            for (dst_idx = 0; dst_idx < LINE_BYTES; dst_idx = dst_idx + 1) begin
                if (dst_idx >= line_off) begin
                    src_idx = dst_idx - line_off;
                    if ((src_idx < LINE_BYTES) && write_strobe[src_idx]) begin
                        merge_line[(dst_idx * 8) +: 8] =
                            write_data[(src_idx * 8) +: 8];
                    end
                end
            end
        end
    endfunction

    wire [ID_BITS-1:0] issue_slot_safe_w = {1'b0, issue_slot_r[4:0]};
    wire [ID_BITS-1:0] commit_slot_safe_w = {1'b0, commit_slot_r[4:0]};
    wire [LINE_BITS-1:0] issue_victim_data_w =
        line_at(mshr_victim_data_r, issue_slot_safe_w);
    wire [ADDR_BITS-1:0] commit_addr_w =
        addr_at(mshr_addr_r, commit_slot_safe_w);
    wire [LINE_BITS-1:0] commit_refill_line_w =
        line_at(mshr_refill_line_r, commit_slot_safe_w);
    wire [LINE_BITS-1:0] commit_wdata_w =
        line_at(mshr_wdata_r, commit_slot_safe_w);
    wire [LINE_BYTES-1:0] commit_wstrb_w =
        wstrb_at(mshr_wstrb_r, commit_slot_safe_w);
    wire [LINE_BITS-1:0] commit_merge_line_w =
        merge_line(commit_refill_line_w,
                   commit_addr_w,
                   commit_wdata_w,
                   commit_wstrb_w);

    wire [LINE_BITS-1:0] mem_req_wdata_w =
        state_mem_req_valid_r ? state_mem_req_wdata_r : issue_victim_data_w;
    wire [LINE_BITS-1:0] install_line_w =
        commit_is_write_r ? (commit_need_refill_r ? commit_merge_line_w
                                                  : commit_wdata_w)
                          : commit_refill_line_w;

    always @(posedge clk) begin
        issue_slot_r <= issue_slot_r + {{(ID_BITS-1){1'b0}}, 1'b1};
        commit_slot_r <= commit_slot_r + {{(ID_BITS-2){1'b0}}, 2'b11};
        issue_write_r <= issue_write_r ^ sink_r;
        commit_is_write_r <= commit_is_write_r ^ issue_write_r;
        commit_need_refill_r <= commit_need_refill_r ^ commit_is_write_r;
        state_mem_req_valid_r <= state_mem_req_valid_r ^ commit_need_refill_r;
        state_mem_req_wdata_r <= {state_mem_req_wdata_r[LINE_BITS-2:0],
                                  ^install_line_w};
        mshr_addr_r <= {mshr_addr_r[(MSHR_COUNT*ADDR_BITS)-2:0],
                        ^mem_req_wdata_w};
        mshr_victim_data_r <= {mshr_victim_data_r[(MSHR_COUNT*LINE_BITS)-2:0],
                               ^install_line_w};
        mshr_refill_line_r <= {mshr_refill_line_r[(MSHR_COUNT*LINE_BITS)-2:0],
                               ^mem_req_wdata_w};
        mshr_wdata_r <= {mshr_wdata_r[(MSHR_COUNT*LINE_BITS)-2:0],
                         ^commit_merge_line_w};
        mshr_wstrb_r <= {mshr_wstrb_r[(MSHR_COUNT*LINE_BYTES)-2:0],
                         ^commit_wdata_w};
        sink_r <= ^mem_req_wdata_w ^ ^install_line_w ^ issue_write_r;
    end
endmodule
