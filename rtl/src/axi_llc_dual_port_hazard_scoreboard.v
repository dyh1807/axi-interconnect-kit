`timescale 1ns / 1ps

// Tracks external AXI AR/AW issue state for the native dual-port bridge.
//
// A read entry is created when AR fires and is released by the matching R-last.
// A write entry is created when AW fires and is released by the matching B.
// The issue gate consumes the generated slot/pending hazards to avoid same-line
// AR/AW ambiguity across each external AXI port.
module axi_llc_dual_port_hazard_scoreboard #(
    parameter LINE_TAG_BITS = 26,
    parameter HAZARD_AXI_ID_BITS = 6,
    parameter READ_HAZARD_COUNT = 2,
    parameter WRITE_HAZARD_COUNT = 2
) (
    input                          clk,
    input                          rst_n,

    input      [LINE_TAG_BITS-1:0] ddr_ar_line,
    input      [LINE_TAG_BITS-1:0] mmio_ar_line,
    input      [LINE_TAG_BITS-1:0] ddr_aw_line,
    input      [LINE_TAG_BITS-1:0] mmio_aw_line,

    input  [HAZARD_AXI_ID_BITS-1:0] ddr_arid,
    input  [HAZARD_AXI_ID_BITS-1:0] mmio_arid,
    input  [HAZARD_AXI_ID_BITS-1:0] ddr_awid,
    input  [HAZARD_AXI_ID_BITS-1:0] mmio_awid,
    input  [HAZARD_AXI_ID_BITS-1:0] ddr_rid,
    input  [HAZARD_AXI_ID_BITS-1:0] mmio_rid,
    input  [HAZARD_AXI_ID_BITS-1:0] ddr_bid,
    input  [HAZARD_AXI_ID_BITS-1:0] mmio_bid,

    input                          ddr_ar_fire,
    input                          mmio_ar_fire,
    input                          ddr_aw_fire,
    input                          mmio_aw_fire,
    input                          ddr_r_fire,
    input                          mmio_r_fire,
    input                          ddr_b_fire,
    input                          mmio_b_fire,

    output                         ddr_ar_slot_hazard,
    output                         mmio_ar_slot_hazard,
    output                         ddr_aw_slot_hazard,
    output                         mmio_aw_slot_hazard,
    output                         ddr_aw_pending_read_hazard,
    output                         mmio_aw_pending_read_hazard,
    output                         ddr_ar_pending_write_hazard,
    output                         mmio_ar_pending_write_hazard
);

    reg rd_hazard_valid_r [0:READ_HAZARD_COUNT-1];
    reg rd_hazard_port_r [0:READ_HAZARD_COUNT-1];
    reg [HAZARD_AXI_ID_BITS-1:0] rd_hazard_id_r [0:READ_HAZARD_COUNT-1];
    reg [LINE_TAG_BITS-1:0] rd_hazard_line_r [0:READ_HAZARD_COUNT-1];

    reg wr_hazard_valid_r [0:WRITE_HAZARD_COUNT-1];
    reg wr_hazard_port_r [0:WRITE_HAZARD_COUNT-1];
    reg [HAZARD_AXI_ID_BITS-1:0] wr_hazard_id_r [0:WRITE_HAZARD_COUNT-1];
    reg [LINE_TAG_BITS-1:0] wr_hazard_line_r [0:WRITE_HAZARD_COUNT-1];

    wire rd_ddr_aw_line_match_w [0:READ_HAZARD_COUNT-1];
    wire rd_mmio_aw_line_match_w [0:READ_HAZARD_COUNT-1];
    wire rd_ddr_rid_match_w [0:READ_HAZARD_COUNT-1];
    wire rd_mmio_rid_match_w [0:READ_HAZARD_COUNT-1];
    wire wr_ddr_ar_line_match_w [0:WRITE_HAZARD_COUNT-1];
    wire wr_mmio_ar_line_match_w [0:WRITE_HAZARD_COUNT-1];
    wire wr_ddr_bid_match_w [0:WRITE_HAZARD_COUNT-1];
    wire wr_mmio_bid_match_w [0:WRITE_HAZARD_COUNT-1];

    reg rd_free_found_w;
    reg rd_second_free_found_w;
    integer rd_free_index_w;
    integer rd_second_free_index_w;
    reg wr_free_found_w;
    reg wr_second_free_found_w;
    integer wr_free_index_w;
    integer wr_second_free_index_w;

    reg ddr_aw_pending_read_hazard_w;
    reg mmio_aw_pending_read_hazard_w;
    reg ddr_ar_pending_write_hazard_w;
    reg mmio_ar_pending_write_hazard_w;

    reg ddr_r_match_found_w;
    reg mmio_r_match_found_w;
    reg ddr_b_match_found_w;
    reg mmio_b_match_found_w;
    integer ddr_r_match_index_w;
    integer mmio_r_match_index_w;
    integer ddr_b_match_index_w;
    integer mmio_b_match_index_w;

    assign ddr_aw_pending_read_hazard = ddr_aw_pending_read_hazard_w;
    assign mmio_aw_pending_read_hazard = mmio_aw_pending_read_hazard_w;
    assign ddr_ar_pending_write_hazard = ddr_ar_pending_write_hazard_w;
    assign mmio_ar_pending_write_hazard = mmio_ar_pending_write_hazard_w;

    axi_llc_dual_port_slot_hazard read_slot_hazard (
        .first_free_found(rd_free_found_w),
        .second_free_found(rd_second_free_found_w),
        .primary_fire(ddr_ar_fire),
        .primary_slot_hazard(ddr_ar_slot_hazard),
        .secondary_slot_hazard(mmio_ar_slot_hazard)
    );

    axi_llc_dual_port_slot_hazard write_slot_hazard (
        .first_free_found(wr_free_found_w),
        .second_free_found(wr_second_free_found_w),
        .primary_fire(ddr_aw_fire),
        .primary_slot_hazard(ddr_aw_slot_hazard),
        .secondary_slot_hazard(mmio_aw_slot_hazard)
    );

    genvar hazard_gen_idx;
    generate
        for (hazard_gen_idx = 0;
             hazard_gen_idx < READ_HAZARD_COUNT;
             hazard_gen_idx = hazard_gen_idx + 1) begin : rd_match_gen
            axi_llc_dual_port_hazard_match #(
                .LINE_TAG_BITS(LINE_TAG_BITS),
                .HAZARD_AXI_ID_BITS(HAZARD_AXI_ID_BITS)
            ) match_entry (
                .entry_valid(rd_hazard_valid_r[hazard_gen_idx]),
                .entry_port(rd_hazard_port_r[hazard_gen_idx]),
                .entry_line(rd_hazard_line_r[hazard_gen_idx]),
                .entry_id(rd_hazard_id_r[hazard_gen_idx]),
                .ddr_line(ddr_aw_line),
                .mmio_line(mmio_aw_line),
                .ddr_id(ddr_rid),
                .mmio_id(mmio_rid),
                .ddr_line_match(rd_ddr_aw_line_match_w[hazard_gen_idx]),
                .mmio_line_match(rd_mmio_aw_line_match_w[hazard_gen_idx]),
                .ddr_id_match(rd_ddr_rid_match_w[hazard_gen_idx]),
                .mmio_id_match(rd_mmio_rid_match_w[hazard_gen_idx])
            );
        end
        for (hazard_gen_idx = 0;
             hazard_gen_idx < WRITE_HAZARD_COUNT;
             hazard_gen_idx = hazard_gen_idx + 1) begin : wr_match_gen
            axi_llc_dual_port_hazard_match #(
                .LINE_TAG_BITS(LINE_TAG_BITS),
                .HAZARD_AXI_ID_BITS(HAZARD_AXI_ID_BITS)
            ) match_entry (
                .entry_valid(wr_hazard_valid_r[hazard_gen_idx]),
                .entry_port(wr_hazard_port_r[hazard_gen_idx]),
                .entry_line(wr_hazard_line_r[hazard_gen_idx]),
                .entry_id(wr_hazard_id_r[hazard_gen_idx]),
                .ddr_line(ddr_ar_line),
                .mmio_line(mmio_ar_line),
                .ddr_id(ddr_bid),
                .mmio_id(mmio_bid),
                .ddr_line_match(wr_ddr_ar_line_match_w[hazard_gen_idx]),
                .mmio_line_match(wr_mmio_ar_line_match_w[hazard_gen_idx]),
                .ddr_id_match(wr_ddr_bid_match_w[hazard_gen_idx]),
                .mmio_id_match(wr_mmio_bid_match_w[hazard_gen_idx])
            );
        end
    endgenerate

    integer hazard_comb_idx;
    integer hazard_seq_idx;
    always @(*) begin
        rd_free_found_w = 1'b0;
        rd_second_free_found_w = 1'b0;
        rd_free_index_w = 0;
        rd_second_free_index_w = 0;
        wr_free_found_w = 1'b0;
        wr_second_free_found_w = 1'b0;
        wr_free_index_w = 0;
        wr_second_free_index_w = 0;

        ddr_aw_pending_read_hazard_w = 1'b0;
        mmio_aw_pending_read_hazard_w = 1'b0;
        ddr_ar_pending_write_hazard_w = 1'b0;
        mmio_ar_pending_write_hazard_w = 1'b0;

        ddr_r_match_found_w = 1'b0;
        mmio_r_match_found_w = 1'b0;
        ddr_b_match_found_w = 1'b0;
        mmio_b_match_found_w = 1'b0;
        ddr_r_match_index_w = 0;
        mmio_r_match_index_w = 0;
        ddr_b_match_index_w = 0;
        mmio_b_match_index_w = 0;

        for (hazard_comb_idx = 0; hazard_comb_idx < READ_HAZARD_COUNT; hazard_comb_idx = hazard_comb_idx + 1) begin
            if (!rd_free_found_w && !rd_hazard_valid_r[hazard_comb_idx]) begin
                rd_free_found_w = 1'b1;
                rd_free_index_w = hazard_comb_idx;
            end else if (rd_free_found_w && !rd_second_free_found_w &&
                         !rd_hazard_valid_r[hazard_comb_idx]) begin
                rd_second_free_found_w = 1'b1;
                rd_second_free_index_w = hazard_comb_idx;
            end

            if (rd_hazard_valid_r[hazard_comb_idx] &&
                rd_ddr_aw_line_match_w[hazard_comb_idx]) begin
                ddr_aw_pending_read_hazard_w = 1'b1;
            end
            if (rd_hazard_valid_r[hazard_comb_idx] &&
                rd_mmio_aw_line_match_w[hazard_comb_idx]) begin
                mmio_aw_pending_read_hazard_w = 1'b1;
            end

            if (!ddr_r_match_found_w &&
                rd_hazard_valid_r[hazard_comb_idx] &&
                rd_ddr_rid_match_w[hazard_comb_idx]) begin
                ddr_r_match_found_w = 1'b1;
                ddr_r_match_index_w = hazard_comb_idx;
            end
            if (!mmio_r_match_found_w &&
                rd_hazard_valid_r[hazard_comb_idx] &&
                rd_mmio_rid_match_w[hazard_comb_idx]) begin
                mmio_r_match_found_w = 1'b1;
                mmio_r_match_index_w = hazard_comb_idx;
            end
        end

        for (hazard_comb_idx = 0; hazard_comb_idx < WRITE_HAZARD_COUNT; hazard_comb_idx = hazard_comb_idx + 1) begin
            if (!wr_free_found_w && !wr_hazard_valid_r[hazard_comb_idx]) begin
                wr_free_found_w = 1'b1;
                wr_free_index_w = hazard_comb_idx;
            end else if (wr_free_found_w && !wr_second_free_found_w &&
                         !wr_hazard_valid_r[hazard_comb_idx]) begin
                wr_second_free_found_w = 1'b1;
                wr_second_free_index_w = hazard_comb_idx;
            end

            if (wr_hazard_valid_r[hazard_comb_idx] &&
                wr_ddr_ar_line_match_w[hazard_comb_idx]) begin
                ddr_ar_pending_write_hazard_w = 1'b1;
            end
            if (wr_hazard_valid_r[hazard_comb_idx] &&
                wr_mmio_ar_line_match_w[hazard_comb_idx]) begin
                mmio_ar_pending_write_hazard_w = 1'b1;
            end

            if (!ddr_b_match_found_w &&
                wr_hazard_valid_r[hazard_comb_idx] &&
                wr_ddr_bid_match_w[hazard_comb_idx]) begin
                ddr_b_match_found_w = 1'b1;
                ddr_b_match_index_w = hazard_comb_idx;
            end
            if (!mmio_b_match_found_w &&
                wr_hazard_valid_r[hazard_comb_idx] &&
                wr_mmio_bid_match_w[hazard_comb_idx]) begin
                mmio_b_match_found_w = 1'b1;
                mmio_b_match_index_w = hazard_comb_idx;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (hazard_seq_idx = 0; hazard_seq_idx < READ_HAZARD_COUNT; hazard_seq_idx = hazard_seq_idx + 1) begin
                rd_hazard_valid_r[hazard_seq_idx] <= 1'b0;
                rd_hazard_port_r[hazard_seq_idx] <= 1'b0;
                rd_hazard_id_r[hazard_seq_idx] <= {HAZARD_AXI_ID_BITS{1'b0}};
                rd_hazard_line_r[hazard_seq_idx] <= {LINE_TAG_BITS{1'b0}};
            end
            for (hazard_seq_idx = 0; hazard_seq_idx < WRITE_HAZARD_COUNT; hazard_seq_idx = hazard_seq_idx + 1) begin
                wr_hazard_valid_r[hazard_seq_idx] <= 1'b0;
                wr_hazard_port_r[hazard_seq_idx] <= 1'b0;
                wr_hazard_id_r[hazard_seq_idx] <= {HAZARD_AXI_ID_BITS{1'b0}};
                wr_hazard_line_r[hazard_seq_idx] <= {LINE_TAG_BITS{1'b0}};
            end
        end else begin
            if (ddr_r_fire && ddr_r_match_found_w) begin
                rd_hazard_valid_r[ddr_r_match_index_w] <= 1'b0;
            end
            if (mmio_r_fire && mmio_r_match_found_w) begin
                rd_hazard_valid_r[mmio_r_match_index_w] <= 1'b0;
            end
            if (ddr_b_fire && ddr_b_match_found_w) begin
                wr_hazard_valid_r[ddr_b_match_index_w] <= 1'b0;
            end
            if (mmio_b_fire && mmio_b_match_found_w) begin
                wr_hazard_valid_r[mmio_b_match_index_w] <= 1'b0;
            end

            if (ddr_ar_fire) begin
                rd_hazard_valid_r[rd_free_index_w] <= 1'b1;
                rd_hazard_port_r[rd_free_index_w] <= 1'b0;
                rd_hazard_id_r[rd_free_index_w] <= ddr_arid;
                rd_hazard_line_r[rd_free_index_w] <= ddr_ar_line;
            end
            if (mmio_ar_fire) begin
                rd_hazard_valid_r[ddr_ar_fire ? rd_second_free_index_w : rd_free_index_w] <= 1'b1;
                rd_hazard_port_r[ddr_ar_fire ? rd_second_free_index_w : rd_free_index_w] <= 1'b1;
                rd_hazard_id_r[ddr_ar_fire ? rd_second_free_index_w : rd_free_index_w] <= mmio_arid;
                rd_hazard_line_r[ddr_ar_fire ? rd_second_free_index_w : rd_free_index_w] <= mmio_ar_line;
            end
            if (ddr_aw_fire) begin
                wr_hazard_valid_r[wr_free_index_w] <= 1'b1;
                wr_hazard_port_r[wr_free_index_w] <= 1'b0;
                wr_hazard_id_r[wr_free_index_w] <= ddr_awid;
                wr_hazard_line_r[wr_free_index_w] <= ddr_aw_line;
            end
            if (mmio_aw_fire) begin
                wr_hazard_valid_r[ddr_aw_fire ? wr_second_free_index_w : wr_free_index_w] <= 1'b1;
                wr_hazard_port_r[ddr_aw_fire ? wr_second_free_index_w : wr_free_index_w] <= 1'b1;
                wr_hazard_id_r[ddr_aw_fire ? wr_second_free_index_w : wr_free_index_w] <= mmio_awid;
                wr_hazard_line_r[ddr_aw_fire ? wr_second_free_index_w : wr_free_index_w] <= mmio_aw_line;
            end
        end
    end

endmodule
