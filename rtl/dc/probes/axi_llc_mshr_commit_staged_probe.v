`timescale 1ns / 1ps

// DC-only probe for the current staged MSHR commit datapath:
// cycle N captures the selected payload, cycle N+1 merges the captured payload.
module axi_llc_mshr_commit_staged_probe #(
    parameter MSHR_COUNT = 32,
    parameter ADDR_BITS = 32,
    parameter LINE_BYTES = 64,
    parameter LINE_BITS = 512,
    parameter SLOT_BITS = 5
) (
    input                         clk,
    input                         rst_n,
    input      [SLOT_BITS-1:0]     slot_i,
    input      [MSHR_COUNT*LINE_BITS-1:0] refill_line_i,
    input      [MSHR_COUNT*LINE_BITS-1:0] wdata_i,
    input      [MSHR_COUNT*LINE_BYTES-1:0] wstrb_i,
    input      [MSHR_COUNT*ADDR_BITS-1:0] addr_i,
    input      [MSHR_COUNT-1:0]    need_refill_i,
    input      [MSHR_COUNT-1:0]    is_write_i,
    output reg [LINE_BITS-1:0]     install_line_o,
    output reg                    install_dirty_o
);

    integer idx;

    reg [LINE_BITS-1:0] refill_line_r [0:MSHR_COUNT-1];
    reg [LINE_BITS-1:0] wdata_r [0:MSHR_COUNT-1];
    reg [LINE_BYTES-1:0] wstrb_r [0:MSHR_COUNT-1];
    reg [ADDR_BITS-1:0] addr_r [0:MSHR_COUNT-1];
    reg need_refill_r [0:MSHR_COUNT-1];
    reg is_write_r [0:MSHR_COUNT-1];

    reg [LINE_BITS-1:0] refill_line_payload_r;
    reg [LINE_BITS-1:0] wdata_payload_r;
    reg [LINE_BYTES-1:0] wstrb_payload_r;
    reg [ADDR_BITS-1:0] addr_payload_r;
    reg need_refill_payload_r;
    reg is_write_payload_r;

    function [LINE_BITS-1:0] merge_line;
        input [LINE_BITS-1:0] old_line;
        input [ADDR_BITS-1:0] addr;
        input [LINE_BITS-1:0] write_line;
        input [LINE_BYTES-1:0] strb;
        integer b;
        reg [LINE_BITS-1:0] merged;
        begin
            merged = old_line;
            for (b = 0; b < LINE_BYTES; b = b + 1) begin
                if (strb[b]) begin
                    merged[8*b +: 8] = write_line[8*b +: 8] ^ addr[7:0];
                end
            end
            merge_line = merged;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            install_line_o <= {LINE_BITS{1'b0}};
            install_dirty_o <= 1'b0;
            refill_line_payload_r <= {LINE_BITS{1'b0}};
            wdata_payload_r <= {LINE_BITS{1'b0}};
            wstrb_payload_r <= {LINE_BYTES{1'b0}};
            addr_payload_r <= {ADDR_BITS{1'b0}};
            need_refill_payload_r <= 1'b0;
            is_write_payload_r <= 1'b0;
            for (idx = 0; idx < MSHR_COUNT; idx = idx + 1) begin
                refill_line_r[idx] <= {LINE_BITS{1'b0}};
                wdata_r[idx] <= {LINE_BITS{1'b0}};
                wstrb_r[idx] <= {LINE_BYTES{1'b0}};
                addr_r[idx] <= {ADDR_BITS{1'b0}};
                need_refill_r[idx] <= 1'b0;
                is_write_r[idx] <= 1'b0;
            end
        end else begin
            for (idx = 0; idx < MSHR_COUNT; idx = idx + 1) begin
                refill_line_r[idx] <= refill_line_i[idx*LINE_BITS +: LINE_BITS];
                wdata_r[idx] <= wdata_i[idx*LINE_BITS +: LINE_BITS];
                wstrb_r[idx] <= wstrb_i[idx*LINE_BYTES +: LINE_BYTES];
                addr_r[idx] <= addr_i[idx*ADDR_BITS +: ADDR_BITS];
                need_refill_r[idx] <= need_refill_i[idx];
                is_write_r[idx] <= is_write_i[idx];
            end

            refill_line_payload_r <= refill_line_r[slot_i];
            wdata_payload_r <= wdata_r[slot_i];
            wstrb_payload_r <= wstrb_r[slot_i];
            addr_payload_r <= addr_r[slot_i];
            need_refill_payload_r <= need_refill_r[slot_i];
            is_write_payload_r <= is_write_r[slot_i];

            if (is_write_payload_r) begin
                if (need_refill_payload_r) begin
                    install_line_o <= merge_line(refill_line_payload_r,
                                                 addr_payload_r,
                                                 wdata_payload_r,
                                                 wstrb_payload_r);
                end else begin
                    install_line_o <= wdata_payload_r;
                end
                install_dirty_o <= 1'b1;
            end else begin
                install_line_o <= refill_line_payload_r;
                install_dirty_o <= 1'b0;
            end
        end
    end

endmodule
