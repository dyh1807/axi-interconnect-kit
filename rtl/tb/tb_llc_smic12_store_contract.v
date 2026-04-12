`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_llc_smic12_store_contract;

    localparam SET_COUNT = `AXI_LLC_SET_COUNT;
    localparam SET_BITS  = `AXI_LLC_SET_BITS;
    localparam WAY_COUNT = `AXI_LLC_WAY_COUNT;
    localparam LINE_BITS = `AXI_LLC_LINE_BITS;
    localparam META_BITS = `AXI_LLC_META_BITS;
    localparam DATA_ROW_BITS = WAY_COUNT * LINE_BITS;
    localparam META_ROW_BITS = WAY_COUNT * META_BITS;

    reg clk;
    reg rst_n;

    reg                      data_rd_en;
    reg  [SET_BITS-1:0]      data_rd_set;
    wire                     data_rd_valid_smic;
    wire [DATA_ROW_BITS-1:0] data_rd_row_smic;
    wire                     data_rd_valid_generic;
    wire [DATA_ROW_BITS-1:0] data_rd_row_generic;
    reg                      data_wr_en;
    reg  [SET_BITS-1:0]      data_wr_set;
    reg  [WAY_COUNT-1:0]     data_wr_way_mask;
    reg  [DATA_ROW_BITS-1:0] data_wr_row;
    wire                     data_busy_smic;
    wire                     data_busy_generic;

    reg                      meta_rd_en;
    reg  [SET_BITS-1:0]      meta_rd_set;
    wire                     meta_rd_valid_smic;
    wire [META_ROW_BITS-1:0] meta_rd_row_smic;
    wire                     meta_rd_valid_generic;
    wire [META_ROW_BITS-1:0] meta_rd_row_generic;
    reg                      meta_wr_en;
    reg  [SET_BITS-1:0]      meta_wr_set;
    reg  [WAY_COUNT-1:0]     meta_wr_way_mask;
    reg  [META_ROW_BITS-1:0] meta_wr_row;
    wire                     meta_busy_smic;
    wire                     meta_busy_generic;

    reg [DATA_ROW_BITS-1:0] expect_data_row;
    reg [META_ROW_BITS-1:0] expect_meta_row;
    reg [WAY_COUNT-1:0]     expect_data_way_mask;
    reg [WAY_COUNT-1:0]     expect_meta_way_mask;
    integer error_count;

    llc_data_store #(
        .SET_COUNT  (SET_COUNT),
        .SET_BITS   (SET_BITS),
        .WAY_COUNT  (WAY_COUNT),
        .LINE_BITS  (LINE_BITS),
        .ROW_BITS   (DATA_ROW_BITS),
        .USE_SMIC12 (1)
    ) u_data_smic (
        .clk         (clk),
        .rst_n       (rst_n),
        .rd_en       (data_rd_en),
        .rd_set      (data_rd_set),
        .rd_valid    (data_rd_valid_smic),
        .rd_row      (data_rd_row_smic),
        .wr_en       (data_wr_en),
        .wr_set      (data_wr_set),
        .wr_way_mask (data_wr_way_mask),
        .wr_row      (data_wr_row),
        .busy        (data_busy_smic)
    );

    llc_data_store #(
        .SET_COUNT  (SET_COUNT),
        .SET_BITS   (SET_BITS),
        .WAY_COUNT  (WAY_COUNT),
        .LINE_BITS  (LINE_BITS),
        .ROW_BITS   (DATA_ROW_BITS),
        .USE_SMIC12 (0)
    ) u_data_generic (
        .clk         (clk),
        .rst_n       (rst_n),
        .rd_en       (data_rd_en),
        .rd_set      (data_rd_set),
        .rd_valid    (data_rd_valid_generic),
        .rd_row      (data_rd_row_generic),
        .wr_en       (data_wr_en),
        .wr_set      (data_wr_set),
        .wr_way_mask (data_wr_way_mask),
        .wr_row      (data_wr_row),
        .busy        (data_busy_generic)
    );

    llc_meta_store #(
        .SET_COUNT  (SET_COUNT),
        .SET_BITS   (SET_BITS),
        .WAY_COUNT  (WAY_COUNT),
        .META_BITS  (META_BITS),
        .ROW_BITS   (META_ROW_BITS),
        .USE_SMIC12 (1)
    ) u_meta_smic (
        .clk         (clk),
        .rst_n       (rst_n),
        .rd_en       (meta_rd_en),
        .rd_set      (meta_rd_set),
        .rd_valid    (meta_rd_valid_smic),
        .rd_row      (meta_rd_row_smic),
        .wr_en       (meta_wr_en),
        .wr_set      (meta_wr_set),
        .wr_way_mask (meta_wr_way_mask),
        .wr_row      (meta_wr_row),
        .busy        (meta_busy_smic)
    );

    llc_meta_store #(
        .SET_COUNT  (SET_COUNT),
        .SET_BITS   (SET_BITS),
        .WAY_COUNT  (WAY_COUNT),
        .META_BITS  (META_BITS),
        .ROW_BITS   (META_ROW_BITS),
        .USE_SMIC12 (0)
    ) u_meta_generic (
        .clk         (clk),
        .rst_n       (rst_n),
        .rd_en       (meta_rd_en),
        .rd_set      (meta_rd_set),
        .rd_valid    (meta_rd_valid_generic),
        .rd_row      (meta_rd_row_generic),
        .wr_en       (meta_wr_en),
        .wr_set      (meta_wr_set),
        .wr_way_mask (meta_wr_way_mask),
        .wr_row      (meta_wr_row),
        .busy        (meta_busy_generic)
    );

    always #5 clk = ~clk;

    task record_error;
        input [8*96-1:0] reason;
        begin
            error_count = error_count + 1;
            $display("tb_llc_smic12_store_contract ERROR: %0s", reason);
        end
    endtask

    task drive_data_write;
        input [SET_BITS-1:0] set_idx;
        input [WAY_COUNT-1:0] way_mask;
        input [DATA_ROW_BITS-1:0] row_value;
        begin
            @(negedge clk);
            data_wr_set      = set_idx;
            data_wr_way_mask = way_mask;
            data_wr_row      = row_value;
            data_wr_en       = 1'b1;
            @(negedge clk);
            data_wr_en       = 1'b0;
            data_wr_way_mask = {WAY_COUNT{1'b0}};
            data_wr_row      = {DATA_ROW_BITS{1'b0}};
            #1;
            if (data_busy_smic !== 1'b0 || data_busy_generic !== 1'b0) begin
                record_error("data busy should stay low");
            end
        end
    endtask

    task drive_meta_write;
        input [SET_BITS-1:0] set_idx;
        input [WAY_COUNT-1:0] way_mask;
        input [META_ROW_BITS-1:0] row_value;
        begin
            @(negedge clk);
            meta_wr_set      = set_idx;
            meta_wr_way_mask = way_mask;
            meta_wr_row      = row_value;
            meta_wr_en       = 1'b1;
            @(posedge clk);
            #1;
            if (!meta_busy_smic || !meta_busy_generic) begin
                record_error("meta write should raise busy");
            end
            if (meta_busy_smic !== meta_busy_generic) begin
                record_error("meta busy mismatch during write");
            end
            @(negedge clk);
            meta_wr_en       = 1'b0;
            meta_wr_way_mask = {WAY_COUNT{1'b0}};
            meta_wr_row      = {META_ROW_BITS{1'b0}};
            @(posedge clk);
            #1;
            if (meta_busy_smic || meta_busy_generic) begin
                record_error("meta busy should clear after staged write");
            end
        end
    endtask

    task check_data_read;
        input [SET_BITS-1:0] set_idx;
        input [DATA_ROW_BITS-1:0] expect_row;
        input [WAY_COUNT-1:0] expect_way_mask;
        reg smic_seen;
        reg generic_seen;
        reg [1:0] smic_cycle;
        reg [1:0] generic_cycle;
        reg [DATA_ROW_BITS-1:0] smic_row;
        reg [DATA_ROW_BITS-1:0] generic_row;
        integer sample_idx;
        integer way_idx;
        begin
            smic_seen     = 1'b0;
            generic_seen  = 1'b0;
            smic_cycle    = 2'd0;
            generic_cycle = 2'd0;
            smic_row      = {DATA_ROW_BITS{1'b0}};
            generic_row   = {DATA_ROW_BITS{1'b0}};

            @(negedge clk);
            data_rd_set = set_idx;
            data_rd_en  = 1'b1;

            for (sample_idx = 0; sample_idx < 3; sample_idx = sample_idx + 1) begin
                @(posedge clk);
                #1;
                if (data_rd_valid_smic && !smic_seen) begin
                    smic_seen  = 1'b1;
                    smic_cycle = sample_idx[1:0];
                    smic_row   = data_rd_row_smic;
                end
                if (data_rd_valid_generic && !generic_seen) begin
                    generic_seen  = 1'b1;
                    generic_cycle = sample_idx[1:0];
                    generic_row   = data_rd_row_generic;
                end
                @(negedge clk);
                if (sample_idx == 0) begin
                    data_rd_en = 1'b0;
                end
            end

            if (!smic_seen) begin
                record_error("smic12 data read produced no valid");
            end
            if (!generic_seen) begin
                record_error("generic data read produced no valid");
            end
            for (way_idx = 0; way_idx < WAY_COUNT; way_idx = way_idx + 1) begin
                if (expect_way_mask[way_idx]) begin
                    if (smic_seen &&
                        (smic_row[(way_idx * LINE_BITS) +: LINE_BITS] !==
                         expect_row[(way_idx * LINE_BITS) +: LINE_BITS])) begin
                        record_error("smic12 data read row mismatch");
                    end
                    if (generic_seen &&
                        (generic_row[(way_idx * LINE_BITS) +: LINE_BITS] !==
                         expect_row[(way_idx * LINE_BITS) +: LINE_BITS])) begin
                        record_error("generic data read row mismatch");
                    end
                    if (smic_seen && generic_seen &&
                        (smic_row[(way_idx * LINE_BITS) +: LINE_BITS] !==
                         generic_row[(way_idx * LINE_BITS) +: LINE_BITS])) begin
                        record_error("data read payload mismatch");
                    end
                end
            end
            if (smic_seen && generic_seen && (smic_cycle !== generic_cycle)) begin
                record_error("data read valid latency differs from generic");
            end
        end
    endtask

    task check_meta_read;
        input [SET_BITS-1:0] set_idx;
        input [META_ROW_BITS-1:0] expect_row;
        input [WAY_COUNT-1:0] expect_way_mask;
        reg smic_seen;
        reg generic_seen;
        reg [1:0] smic_cycle;
        reg [1:0] generic_cycle;
        reg [META_ROW_BITS-1:0] smic_row;
        reg [META_ROW_BITS-1:0] generic_row;
        integer sample_idx;
        integer way_idx;
        begin
            smic_seen     = 1'b0;
            generic_seen  = 1'b0;
            smic_cycle    = 2'd0;
            generic_cycle = 2'd0;
            smic_row      = {META_ROW_BITS{1'b0}};
            generic_row   = {META_ROW_BITS{1'b0}};

            @(negedge clk);
            meta_rd_set = set_idx;
            meta_rd_en  = 1'b1;

            for (sample_idx = 0; sample_idx < 3; sample_idx = sample_idx + 1) begin
                @(posedge clk);
                #1;
                if (meta_rd_valid_smic && !smic_seen) begin
                    smic_seen  = 1'b1;
                    smic_cycle = sample_idx[1:0];
                    smic_row   = meta_rd_row_smic;
                end
                if (meta_rd_valid_generic && !generic_seen) begin
                    generic_seen  = 1'b1;
                    generic_cycle = sample_idx[1:0];
                    generic_row   = meta_rd_row_generic;
                end
                @(negedge clk);
                if (sample_idx == 0) begin
                    meta_rd_en = 1'b0;
                end
            end

            if (!smic_seen) begin
                record_error("smic12 meta read produced no valid");
            end
            if (!generic_seen) begin
                record_error("generic meta read produced no valid");
            end
            for (way_idx = 0; way_idx < WAY_COUNT; way_idx = way_idx + 1) begin
                if (expect_way_mask[way_idx]) begin
                    if (smic_seen &&
                        (smic_row[(way_idx * META_BITS) +: META_BITS] !==
                         expect_row[(way_idx * META_BITS) +: META_BITS])) begin
                        record_error("smic12 meta read row mismatch");
                    end
                    if (generic_seen &&
                        (generic_row[(way_idx * META_BITS) +: META_BITS] !==
                         expect_row[(way_idx * META_BITS) +: META_BITS])) begin
                        record_error("generic meta read row mismatch");
                    end
                    if (smic_seen && generic_seen &&
                        (smic_row[(way_idx * META_BITS) +: META_BITS] !==
                         generic_row[(way_idx * META_BITS) +: META_BITS])) begin
                        record_error("meta read payload mismatch");
                    end
                end
            end
            if (smic_seen && generic_seen && (smic_cycle !== generic_cycle)) begin
                record_error("meta read valid latency differs from generic");
            end
        end
    endtask

    initial begin
        clk              = 1'b0;
        rst_n            = 1'b0;
        data_rd_en       = 1'b0;
        data_rd_set      = {SET_BITS{1'b0}};
        data_wr_en       = 1'b0;
        data_wr_set      = {SET_BITS{1'b0}};
        data_wr_way_mask = {WAY_COUNT{1'b0}};
        data_wr_row      = {DATA_ROW_BITS{1'b0}};
        meta_rd_en       = 1'b0;
        meta_rd_set      = {SET_BITS{1'b0}};
        meta_wr_en       = 1'b0;
        meta_wr_set      = {SET_BITS{1'b0}};
        meta_wr_way_mask = {WAY_COUNT{1'b0}};
        meta_wr_row      = {META_ROW_BITS{1'b0}};
        expect_data_row  = {DATA_ROW_BITS{1'b0}};
        expect_meta_row  = {META_ROW_BITS{1'b0}};
        expect_data_way_mask = {WAY_COUNT{1'b0}};
        expect_meta_way_mask = {WAY_COUNT{1'b0}};
        error_count      = 0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        expect_data_row = {DATA_ROW_BITS{1'b0}};
        expect_data_way_mask = 16'h0084;
        expect_data_row[(2 * LINE_BITS) +: 64]        = 64'h1122_3344_5566_7788;
        expect_data_row[(7 * LINE_BITS) + 64 +: 64]  = 64'hAABB_CCDD_EEFF_0011;
        drive_data_write(13'd19, 16'h0084, expect_data_row);
        check_data_read(13'd19, expect_data_row, expect_data_way_mask);

        expect_data_row[(2 * LINE_BITS) + 128 +: 64] = 64'h0BAD_F00D_DEAD_BEEF;
        expect_data_row[(9 * LINE_BITS) +: 64]       = 64'hCAFE_BABE_0000_1357;
        expect_data_way_mask = 16'h0284;
        drive_data_write(13'd19, 16'h0204, expect_data_row);
        check_data_read(13'd19, expect_data_row, expect_data_way_mask);

        expect_meta_row = {META_ROW_BITS{1'b0}};
        expect_meta_way_mask = 16'h0021;
        expect_meta_row[(0 * META_BITS) +: META_BITS] = 24'h12_A5_7C;
        expect_meta_row[(5 * META_BITS) +: META_BITS] = 24'hE1_44_09;
        drive_meta_write(13'd37, 16'h0021, expect_meta_row);
        check_meta_read(13'd37, expect_meta_row, expect_meta_way_mask);

        expect_meta_row[(5 * META_BITS) +: META_BITS] = 24'h55_CC_33;
        expect_meta_row[(9 * META_BITS) +: META_BITS] = 24'h0F_0A_CE;
        expect_meta_way_mask = 16'h0221;
        drive_meta_write(13'd37, 16'h0220, expect_meta_row);
        check_meta_read(13'd37, expect_meta_row, expect_meta_way_mask);

        if (error_count != 0) begin
            $display("tb_llc_smic12_store_contract FAIL: %0d mismatches", error_count);
            $finish;
        end

        $display("tb_llc_smic12_store_contract PASS");
        $finish;
    end

endmodule
