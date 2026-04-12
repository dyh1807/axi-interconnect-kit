`timescale 1ns / 1ps

module tb_axi_llc_subsystem_directed;

    localparam ID_BITS = 4;

    reg         clk;
    reg         rst_n;
    reg  [1:0]  mode_req;
    reg  [31:0] llc_mapped_offset_req;
    reg         up_req_valid;
    wire        up_req_ready;
    reg         up_req_write;
    reg  [31:0] up_req_addr;
    reg  [ID_BITS-1:0] up_req_id;
    reg  [7:0]  up_req_total_size;
    reg  [63:0] up_req_wdata;
    reg  [7:0]  up_req_wstrb;
    reg         up_req_bypass;
    wire        up_resp_valid;
    reg         up_resp_ready;
    wire [63:0] up_resp_rdata;
    wire [ID_BITS-1:0] up_resp_id;
    wire        cache_req_valid;
    reg         cache_req_ready;
    wire        cache_req_write;
    wire [31:0] cache_req_addr;
    wire [ID_BITS-1:0] cache_req_id;
    wire [7:0]  cache_req_size;
    wire [63:0] cache_req_wdata;
    wire [7:0]  cache_req_wstrb;
    reg         cache_resp_valid;
    wire        cache_resp_ready;
    reg  [63:0] cache_resp_rdata;
    reg  [ID_BITS-1:0] cache_resp_id;
    wire        bypass_req_valid;
    reg         bypass_req_ready;
    wire        bypass_req_write;
    wire [31:0] bypass_req_addr;
    wire [ID_BITS-1:0] bypass_req_id;
    wire [7:0]  bypass_req_size;
    wire [63:0] bypass_req_wdata;
    wire [7:0]  bypass_req_wstrb;
    reg         bypass_resp_valid;
    wire        bypass_resp_ready;
    reg  [63:0] bypass_resp_rdata;
    reg  [ID_BITS-1:0] bypass_resp_id;
    wire [1:0]  active_mode;
    wire [31:0] active_offset;
    wire        reconfig_busy;
    wire [1:0]  reconfig_state;
    wire        config_error;
    reg         invalidate_line_valid;
    reg  [31:0] invalidate_line_addr;
    wire        invalidate_line_accepted;
    reg         invalidate_all_valid;
    wire        invalidate_all_accepted;

    reg [63:0] tmp_rdata;
    reg [63:0] bypass_next_data;
    reg [63:0] cache_next_data;
    reg        bypass_resp_pending;
    reg        cache_resp_pending;
    reg [ID_BITS-1:0] bypass_next_id;
    reg [ID_BITS-1:0] cache_next_id;

    axi_llc_subsystem_core #(
        .ADDR_BITS        (32),
        .RESET_MODE       (2'b00),
        .MODE_BITS        (2),
        .LINE_BYTES       (8),
        .LINE_BITS        (64),
        .LINE_OFFSET_BITS (3),
        .SET_COUNT        (4),
        .SET_BITS         (2),
        .WAY_COUNT        (4),
        .WAY_BITS         (2),
        .LLC_SIZE_BYTES   (128),
        .WINDOW_BYTES     (64),
        .WINDOW_WAYS      (2)
    ) dut (
        .clk                   (clk),
        .rst_n                 (rst_n),
        .mode_req              (mode_req),
        .llc_mapped_offset_req (llc_mapped_offset_req),
        .up_req_valid          (up_req_valid),
        .up_req_ready          (up_req_ready),
        .up_req_write          (up_req_write),
        .up_req_addr           (up_req_addr),
        .up_req_id             (up_req_id),
        .up_req_total_size     (up_req_total_size),
        .up_req_wdata          (up_req_wdata),
        .up_req_wstrb          (up_req_wstrb),
        .up_req_bypass         (up_req_bypass),
        .up_resp_valid         (up_resp_valid),
        .up_resp_ready         (up_resp_ready),
        .up_resp_rdata         (up_resp_rdata),
        .up_resp_id            (up_resp_id),
        .cache_req_valid       (cache_req_valid),
        .cache_req_ready       (cache_req_ready),
        .cache_req_write       (cache_req_write),
        .cache_req_addr        (cache_req_addr),
        .cache_req_id          (cache_req_id),
        .cache_req_size        (cache_req_size),
        .cache_req_wdata       (cache_req_wdata),
        .cache_req_wstrb       (cache_req_wstrb),
        .cache_resp_valid      (cache_resp_valid),
        .cache_resp_ready      (cache_resp_ready),
        .cache_resp_rdata      (cache_resp_rdata),
        .cache_resp_id         (cache_resp_id),
        .bypass_req_valid      (bypass_req_valid),
        .bypass_req_ready      (bypass_req_ready),
        .bypass_req_write      (bypass_req_write),
        .bypass_req_addr       (bypass_req_addr),
        .bypass_req_id         (bypass_req_id),
        .bypass_req_size       (bypass_req_size),
        .bypass_req_wdata      (bypass_req_wdata),
        .bypass_req_wstrb      (bypass_req_wstrb),
        .bypass_resp_valid     (bypass_resp_valid),
        .bypass_resp_ready     (bypass_resp_ready),
        .bypass_resp_rdata     (bypass_resp_rdata),
        .bypass_resp_id        (bypass_resp_id),
        .invalidate_line_valid (invalidate_line_valid),
        .invalidate_line_addr  (invalidate_line_addr),
        .invalidate_line_accepted(invalidate_line_accepted),
        .invalidate_all_valid  (invalidate_all_valid),
        .invalidate_all_accepted(invalidate_all_accepted),
        .active_mode           (active_mode),
        .active_offset         (active_offset),
        .reconfig_busy         (reconfig_busy),
        .reconfig_state        (reconfig_state),
        .config_error          (config_error)
    );

    always #5 clk = ~clk;

    task wait_idle_mode;
        input [1:0] expect_mode;
        input [31:0] expect_offset;
        integer guard;
        begin
            guard = 0;
            while ((active_mode !== expect_mode) ||
                   (active_offset !== expect_offset) ||
                   reconfig_busy) begin
                @(posedge clk);
                guard = guard + 1;
                if (guard > 128) begin
                    $display("tb_axi_llc_subsystem_directed FAIL: timeout waiting mode=%0d offset=%h active_mode=%0d active_offset=%h busy=%b",
                             expect_mode, expect_offset, active_mode, active_offset, reconfig_busy);
                    $finish;
                end
            end
            @(posedge clk);
            if (active_mode !== expect_mode || active_offset !== expect_offset) begin
                $display("tb_axi_llc_subsystem_directed FAIL: bad active config mode=%0d offset=%h", active_mode, active_offset);
                $finish;
            end
        end
    endtask

    task do_request;
        input        is_write;
        input [31:0] addr;
        input [7:0]  total_size;
        input [63:0] wdata;
        input [7:0]  wstrb;
        input        bypass;
        output [63:0] rdata;
        begin
            up_req_valid  <= 1'b1;
            up_req_write  <= is_write;
            up_req_addr   <= addr;
            up_req_id     <= {ID_BITS{1'b0}};
            up_req_total_size <= total_size;
            up_req_wdata  <= wdata;
            up_req_wstrb  <= wstrb;
            up_req_bypass <= bypass;

            while (!up_req_ready) begin
                @(posedge clk);
            end
            @(posedge clk);
            up_req_valid <= 1'b0;
            up_req_id    <= {ID_BITS{1'b0}};
            up_req_total_size <= 8'd0;

            while (!up_resp_valid) begin
                @(posedge clk);
            end
            rdata = up_resp_rdata;
            @(posedge clk);
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bypass_resp_valid   <= 1'b0;
            cache_resp_valid    <= 1'b0;
            bypass_resp_pending <= 1'b0;
            cache_resp_pending  <= 1'b0;
            bypass_resp_rdata   <= 64'h0;
            cache_resp_rdata    <= 64'h0;
            bypass_resp_id      <= {ID_BITS{1'b0}};
            cache_resp_id       <= {ID_BITS{1'b0}};
            bypass_next_id      <= {ID_BITS{1'b0}};
            cache_next_id       <= {ID_BITS{1'b0}};
        end else begin
            if (bypass_req_valid && bypass_req_ready) begin
                bypass_resp_pending <= 1'b1;
                bypass_next_data    <= 64'hB0F0_0000_0000_0000;
                bypass_next_id      <= bypass_req_id;
            end

            if (cache_req_valid && cache_req_ready) begin
                cache_resp_pending <= 1'b1;
                cache_next_data    <= 64'hCA00_0000_0000_0000;
                cache_next_id      <= cache_req_id;
            end

            bypass_resp_valid <= 1'b0;
            cache_resp_valid  <= 1'b0;
            bypass_resp_id    <= {ID_BITS{1'b0}};
            cache_resp_id     <= {ID_BITS{1'b0}};

            if (bypass_resp_pending) begin
                bypass_resp_valid   <= 1'b1;
                bypass_resp_rdata   <= bypass_next_data;
                bypass_resp_id      <= bypass_next_id;
                bypass_resp_pending <= 1'b0;
            end

            if (cache_resp_pending) begin
                cache_resp_valid   <= 1'b1;
                cache_resp_rdata   <= cache_next_data;
                cache_resp_id      <= cache_next_id;
                cache_resp_pending <= 1'b0;
            end
        end
    end

    initial begin
        clk                   = 1'b0;
        rst_n                 = 1'b0;
        mode_req              = 2'b00;
        llc_mapped_offset_req = 32'h0000_0000;
        up_req_valid          = 1'b0;
        up_req_write          = 1'b0;
        up_req_addr           = 32'h0;
        up_req_id             = {ID_BITS{1'b0}};
        up_req_total_size     = 8'd0;
        up_req_wdata          = 64'h0;
        up_req_wstrb          = 8'h0;
        up_req_bypass         = 1'b0;
        up_resp_ready         = 1'b1;
        cache_req_ready       = 1'b1;
        bypass_req_ready      = 1'b1;
        cache_resp_valid      = 1'b0;
        cache_resp_rdata      = 64'h0;
        cache_resp_id         = {ID_BITS{1'b0}};
        bypass_resp_valid     = 1'b0;
        bypass_resp_rdata     = 64'h0;
        bypass_resp_id        = {ID_BITS{1'b0}};
        bypass_resp_pending   = 1'b0;
        cache_resp_pending    = 1'b0;
        bypass_next_data      = 64'h0;
        cache_next_data       = 64'h0;
        bypass_next_id        = {ID_BITS{1'b0}};
        cache_next_id         = {ID_BITS{1'b0}};
        tmp_rdata             = 64'h0;
        invalidate_line_valid = 1'b0;
        invalidate_line_addr  = 32'h0;
        invalidate_all_valid  = 1'b0;

        repeat (2) @(posedge clk);
        rst_n <= 1'b1;

        mode_req              <= 2'b10;
        llc_mapped_offset_req <= 32'h0000_1000;
        wait_idle_mode(2'b10, 32'h0000_1000);

        do_request(1'b0, 32'h0000_1000, 8'd7, 64'h0, 8'h00, 1'b0, tmp_rdata);
        if (tmp_rdata !== 64'h0) begin
            $display("tb_axi_llc_subsystem_directed FAIL: invalid direct read should return zero");
            $finish;
        end

        do_request(1'b1, 32'h0000_1000, 8'd7, 64'h1122_3344_5566_7788, 8'hFF, 1'b0, tmp_rdata);
        do_request(1'b0, 32'h0000_1000, 8'd7, 64'h0, 8'h00, 1'b0, tmp_rdata);
        if (tmp_rdata !== 64'h1122_3344_5566_7788) begin
            $display("tb_axi_llc_subsystem_directed FAIL: direct write/read mismatch");
            $finish;
        end

        mode_req              <= 2'b00;
        llc_mapped_offset_req <= 32'h0000_1000;
        wait_idle_mode(2'b00, 32'h0000_1000);
        do_request(1'b0, 32'h0000_3000, 8'd7, 64'h0, 8'h00, 1'b0, tmp_rdata);
        if (tmp_rdata !== 64'hB0F0_0000_0000_0000) begin
            $display("tb_axi_llc_subsystem_directed FAIL: mode0 should route to bypass");
            $finish;
        end

        mode_req              <= 2'b01;
        llc_mapped_offset_req <= 32'h0000_1000;
        wait_idle_mode(2'b01, 32'h0000_1000);
        do_request(1'b0, 32'h0000_4000, 8'd7, 64'h0, 8'h00, 1'b0, tmp_rdata);
        if (tmp_rdata !== 64'hCA00_0000_0000_0000) begin
            $display("tb_axi_llc_subsystem_directed FAIL: mode1 should route to cache path");
            $finish;
        end

        mode_req              <= 2'b10;
        llc_mapped_offset_req <= 32'h0000_1000;
        wait_idle_mode(2'b10, 32'h0000_1000);
        do_request(1'b0, 32'h0000_1000, 8'd7, 64'h0, 8'h00, 1'b0, tmp_rdata);
        if (tmp_rdata !== 64'h0) begin
            $display("tb_axi_llc_subsystem_directed FAIL: sweep should clear old valid on mode switch");
            $finish;
        end

        mode_req              <= 2'b10;
        llc_mapped_offset_req <= 32'h0000_1004;
        @(posedge clk);
        if (!config_error) begin
            $display("tb_axi_llc_subsystem_directed FAIL: misaligned offset should be rejected");
            $finish;
        end

        $display("tb_axi_llc_subsystem_directed PASS");
        $finish;
    end

endmodule
