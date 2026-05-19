`timescale 1ns / 1ps

module axi_llc_payload_pool512_timing_probe (
    input  clk,
    output sink
);
    localparam SLOT_COUNT = 32;
    localparam SLOT_BITS = 5;
    localparam CHUNK_BITS = 512;

    reg [SLOT_BITS-1:0] wr_idx_r;
    reg [SLOT_BITS-1:0] rd_idx_r;
    reg [CHUNK_BITS-1:0] in_r;
    reg [CHUNK_BITS-1:0] pool_r [0:SLOT_COUNT-1];
    reg [CHUNK_BITS-1:0] out_r;
    reg sink_r;

    assign sink = sink_r;

    always @(posedge clk) begin
        pool_r[wr_idx_r] <= in_r;
        out_r <= pool_r[rd_idx_r];
        wr_idx_r <= wr_idx_r + {{(SLOT_BITS-1){1'b0}}, 1'b1};
        rd_idx_r <= rd_idx_r + {{(SLOT_BITS-2){1'b0}}, 2'b11};
        in_r <= {in_r[CHUNK_BITS-2:0], ^out_r};
        sink_r <= ^out_r ^ ^in_r;
    end
endmodule

module axi_llc_payload_pool_indirect_timing_probe (
    input  clk,
    output sink
);
    localparam QUEUE_DEPTH = 32;
    localparam POOL_COUNT = 32;
    localparam INDEX_BITS = 5;
    localparam DATA_BITS = 512;

    reg [INDEX_BITS-1:0] head_r;
    reg [INDEX_BITS-1:0] wr_idx_r;
    reg [INDEX_BITS-1:0] q_pool_idx_r [0:QUEUE_DEPTH-1];
    reg [DATA_BITS-1:0] pool_r [0:POOL_COUNT-1];
    reg [DATA_BITS-1:0] in_r;
    reg [DATA_BITS-1:0] out_r;
    reg sink_r;

    assign sink = sink_r;

    always @(posedge clk) begin
        q_pool_idx_r[head_r] <= wr_idx_r;
        pool_r[wr_idx_r] <= in_r;
        out_r <= pool_r[q_pool_idx_r[head_r]];
        head_r <= head_r + {{(INDEX_BITS-1){1'b0}}, 1'b1};
        wr_idx_r <= wr_idx_r + {{(INDEX_BITS-2){1'b0}}, 2'b11};
        in_r <= {in_r[DATA_BITS-2:0], ^out_r};
        sink_r <= ^out_r ^ ^in_r;
    end
endmodule

module axi_llc_payload_pool_indirect_staged_timing_probe (
    input  clk,
    output sink
);
    localparam QUEUE_DEPTH = 32;
    localparam POOL_COUNT = 32;
    localparam INDEX_BITS = 5;
    localparam DATA_BITS = 512;

    reg [INDEX_BITS-1:0] head_r;
    reg [INDEX_BITS-1:0] wr_idx_r;
    reg [INDEX_BITS-1:0] pool_idx_s1_r;
    reg [INDEX_BITS-1:0] q_pool_idx_r [0:QUEUE_DEPTH-1];
    reg [DATA_BITS-1:0] pool_r [0:POOL_COUNT-1];
    reg [DATA_BITS-1:0] in_r;
    reg [DATA_BITS-1:0] out_r;
    reg sink_r;

    assign sink = sink_r;

    always @(posedge clk) begin
        q_pool_idx_r[head_r] <= wr_idx_r;
        pool_r[wr_idx_r] <= in_r;
        pool_idx_s1_r <= q_pool_idx_r[head_r];
        out_r <= pool_r[pool_idx_s1_r];
        head_r <= head_r + {{(INDEX_BITS-1){1'b0}}, 1'b1};
        wr_idx_r <= wr_idx_r + {{(INDEX_BITS-2){1'b0}}, 2'b11};
        in_r <= {in_r[DATA_BITS-2:0], ^out_r};
        sink_r <= ^out_r ^ ^in_r;
    end
endmodule

module axi_llc_payload_pool64_timing_probe (
    input  clk,
    output sink
);
    localparam SLOT_COUNT = 32;
    localparam SLOT_BITS = 5;
    localparam CHUNK_BITS = 64;
    localparam CHUNK_COUNT = 8;
    localparam LINE_BITS = CHUNK_BITS * CHUNK_COUNT;

    reg [SLOT_BITS-1:0] wr_idx_r;
    reg [SLOT_BITS-1:0] rd_idx_r;
    reg [LINE_BITS-1:0] in_r;
    reg [CHUNK_BITS-1:0] pool_c0_r [0:SLOT_COUNT-1];
    reg [CHUNK_BITS-1:0] pool_c1_r [0:SLOT_COUNT-1];
    reg [CHUNK_BITS-1:0] pool_c2_r [0:SLOT_COUNT-1];
    reg [CHUNK_BITS-1:0] pool_c3_r [0:SLOT_COUNT-1];
    reg [CHUNK_BITS-1:0] pool_c4_r [0:SLOT_COUNT-1];
    reg [CHUNK_BITS-1:0] pool_c5_r [0:SLOT_COUNT-1];
    reg [CHUNK_BITS-1:0] pool_c6_r [0:SLOT_COUNT-1];
    reg [CHUNK_BITS-1:0] pool_c7_r [0:SLOT_COUNT-1];
    reg [LINE_BITS-1:0] out_r;
    reg sink_r;

    assign sink = sink_r;

    always @(posedge clk) begin
        pool_c0_r[wr_idx_r] <= in_r[63:0];
        pool_c1_r[wr_idx_r] <= in_r[127:64];
        pool_c2_r[wr_idx_r] <= in_r[191:128];
        pool_c3_r[wr_idx_r] <= in_r[255:192];
        pool_c4_r[wr_idx_r] <= in_r[319:256];
        pool_c5_r[wr_idx_r] <= in_r[383:320];
        pool_c6_r[wr_idx_r] <= in_r[447:384];
        pool_c7_r[wr_idx_r] <= in_r[511:448];

        out_r <= {
            pool_c7_r[rd_idx_r],
            pool_c6_r[rd_idx_r],
            pool_c5_r[rd_idx_r],
            pool_c4_r[rd_idx_r],
            pool_c3_r[rd_idx_r],
            pool_c2_r[rd_idx_r],
            pool_c1_r[rd_idx_r],
            pool_c0_r[rd_idx_r]
        };
        wr_idx_r <= wr_idx_r + {{(SLOT_BITS-1){1'b0}}, 1'b1};
        rd_idx_r <= rd_idx_r + {{(SLOT_BITS-2){1'b0}}, 2'b11};
        in_r <= {in_r[LINE_BITS-2:0], ^out_r};
        sink_r <= ^out_r ^ ^in_r;
    end
endmodule
