`timescale 1ns / 1ps

module tb_axi_llc_subsystem_handshake_contract;

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

    integer cache_req_count;
    integer bypass_req_count;
    reg [31:0] last_cache_addr;
    reg [31:0] last_bypass_addr;
    reg        last_cache_write;
    reg        last_bypass_write;
    reg [63:0] last_cache_wdata;
    reg [63:0] last_bypass_wdata;
    reg [7:0]  last_cache_wstrb;
    reg [7:0]  last_bypass_wstrb;

    integer cache_before;
    integer bypass_before;

    axi_llc_subsystem_top #(
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

    task fail_now;
        input [1023:0] msg;
        begin
            $display("tb_axi_llc_subsystem_handshake_contract FAIL: %0s", msg);
            $finish;
        end
    endtask

    task wait_idle_mode;
        input [1:0]  expect_mode;
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
                    fail_now("timeout waiting active mode/offset");
                end
            end
            @(posedge clk);
            if ((active_mode !== expect_mode) ||
                (active_offset !== expect_offset) ||
                (reconfig_state !== 2'b00)) begin
                fail_now("active config mismatch after wait_idle_mode");
            end
        end
    endtask

    task drive_request;
        input        is_write;
        input [31:0] addr;
        input [7:0]  total_size;
        input [63:0] wdata;
        input [7:0]  wstrb;
        input        bypass;
        integer guard;
        begin
            up_req_valid  <= 1'b1;
            up_req_write  <= is_write;
            up_req_addr   <= addr;
            up_req_id     <= {ID_BITS{1'b0}};
            up_req_total_size <= total_size;
            up_req_wdata  <= wdata;
            up_req_wstrb  <= wstrb;
            up_req_bypass <= bypass;

            guard = 0;
            while (!up_req_ready) begin
                @(posedge clk);
                guard = guard + 1;
                if (guard > 128) begin
                    fail_now("timeout waiting up_req_ready");
                end
            end

            @(posedge clk);
            up_req_valid <= 1'b0;
            up_req_id    <= {ID_BITS{1'b0}};
            up_req_total_size <= 8'd0;
        end
    endtask

    task hold_new_request_blocked;
        input        is_write;
        input [31:0] addr;
        input [7:0]  total_size;
        input [63:0] wdata;
        input [7:0]  wstrb;
        input        bypass;
        input integer cycles;
        integer idx;
        begin
            up_req_valid  <= 1'b1;
            up_req_write  <= is_write;
            up_req_addr   <= addr;
            up_req_id     <= {ID_BITS{1'b0}};
            up_req_total_size <= total_size;
            up_req_wdata  <= wdata;
            up_req_wstrb  <= wstrb;
            up_req_bypass <= bypass;

            for (idx = 0; idx < cycles; idx = idx + 1) begin
                @(posedge clk);
                if (up_req_ready !== 1'b0) begin
                    fail_now("up_req_ready should stay low while request is blocked");
                end
            end

            up_req_valid <= 1'b0;
            up_req_id    <= {ID_BITS{1'b0}};
            up_req_total_size <= 8'd0;
        end
    endtask

    task wait_for_bypass_valid;
        input [31:0] exp_addr;
        input        exp_write;
        input [63:0] exp_wdata;
        input [7:0]  exp_wstrb;
        integer guard;
        begin
            guard = 0;
            while (!bypass_req_valid) begin
                @(posedge clk);
                guard = guard + 1;
                if (guard > 64) begin
                    fail_now("timeout waiting bypass_req_valid");
                end
            end

            if (cache_req_valid !== 1'b0) begin
                fail_now("cache_req_valid should be low on bypass route");
            end
            if ((bypass_req_addr !== exp_addr) ||
                (bypass_req_write !== exp_write) ||
                (bypass_req_wdata !== exp_wdata) ||
                (bypass_req_wstrb !== exp_wstrb)) begin
                fail_now("bypass request fields mismatch");
            end
        end
    endtask

    task hold_bypass_wait;
        input [31:0] exp_addr;
        input        exp_write;
        input [63:0] exp_wdata;
        input [7:0]  exp_wstrb;
        input integer cycles;
        integer idx;
        begin
            for (idx = 0; idx < cycles; idx = idx + 1) begin
                @(posedge clk);
                if (bypass_req_valid !== 1'b1) begin
                    fail_now("bypass_req_valid dropped while bypass_req_ready was low");
                end
                if (cache_req_valid !== 1'b0) begin
                    fail_now("cache_req_valid asserted during bypass stall");
                end
                if ((bypass_req_addr !== exp_addr) ||
                    (bypass_req_write !== exp_write) ||
                    (bypass_req_wdata !== exp_wdata) ||
                    (bypass_req_wstrb !== exp_wstrb)) begin
                    fail_now("bypass request fields changed during stall");
                end
            end
        end
    endtask

    task wait_for_cache_valid;
        input [31:0] exp_addr;
        input        exp_write;
        integer guard;
        begin
            guard = 0;
            while (!cache_req_valid) begin
                @(posedge clk);
                guard = guard + 1;
                if (guard > 128) begin
                    fail_now("timeout waiting cache_req_valid");
                end
            end

            if (bypass_req_valid !== 1'b0) begin
                fail_now("bypass_req_valid should be low on cache route");
            end
            if ((cache_req_addr !== exp_addr) ||
                (cache_req_write !== exp_write)) begin
                fail_now("cache request fields mismatch");
            end
        end
    endtask

    task hold_cache_wait;
        input [31:0] exp_addr;
        input        exp_write;
        input integer cycles;
        integer idx;
        begin
            for (idx = 0; idx < cycles; idx = idx + 1) begin
                @(posedge clk);
                if (cache_req_valid !== 1'b1) begin
                    fail_now("cache_req_valid dropped while cache_req_ready was low");
                end
                if (bypass_req_valid !== 1'b0) begin
                    fail_now("bypass_req_valid asserted during cache stall");
                end
                if ((cache_req_addr !== exp_addr) ||
                    (cache_req_write !== exp_write)) begin
                    fail_now("cache request fields changed during stall");
                end
            end
        end
    endtask

    task pulse_bypass_resp;
        input [63:0] data;
        integer guard;
        begin
            guard = 0;
            while (!bypass_resp_ready) begin
                @(posedge clk);
                guard = guard + 1;
                if (guard > 128) begin
                    fail_now("timeout waiting bypass_resp_ready");
                end
            end

            @(negedge clk);
            bypass_resp_rdata <= data;
            bypass_resp_id    <= {ID_BITS{1'b0}};
            bypass_resp_valid <= 1'b1;
            @(posedge clk);
            @(negedge clk);
            bypass_resp_valid <= 1'b0;
            bypass_resp_rdata <= 64'h0;
            bypass_resp_id    <= {ID_BITS{1'b0}};
        end
    endtask

    task pulse_cache_resp;
        input [63:0] data;
        integer guard;
        begin
            guard = 0;
            while (!cache_resp_ready) begin
                @(posedge clk);
                guard = guard + 1;
                if (guard > 128) begin
                    fail_now("timeout waiting cache_resp_ready");
                end
            end

            @(negedge clk);
            cache_resp_rdata <= data;
            cache_resp_id    <= {ID_BITS{1'b0}};
            cache_resp_valid <= 1'b1;
            @(posedge clk);
            @(negedge clk);
            cache_resp_valid <= 1'b0;
            cache_resp_rdata <= 64'h0;
            cache_resp_id    <= {ID_BITS{1'b0}};
        end
    endtask

    task wait_up_resp;
        input [63:0] exp_data;
        integer guard;
        begin
            guard = 0;
            while (!up_resp_valid) begin
                @(posedge clk);
                guard = guard + 1;
                if (guard > 128) begin
                    fail_now("timeout waiting up_resp_valid");
                end
            end

            if (up_resp_rdata !== exp_data) begin
                fail_now("up_resp_rdata mismatch");
            end
        end
    endtask

    task hold_up_resp_blocked;
        input [63:0] exp_data;
        input integer cycles;
        integer idx;
        begin
            for (idx = 0; idx < cycles; idx = idx + 1) begin
                @(posedge clk);
                if (up_resp_valid !== 1'b1) begin
                    fail_now("up_resp_valid dropped while up_resp_ready was low");
                end
                if (up_resp_rdata !== exp_data) begin
                    fail_now("up_resp_rdata changed while up_resp_ready was low");
                end
                if (up_req_ready !== 1'b0) begin
                    fail_now("up_req_ready should stay low while response is blocked");
                end
            end
        end
    endtask

    task wait_resp_clear;
        integer guard;
        begin
            guard = 0;
            while (up_resp_valid) begin
                @(posedge clk);
                guard = guard + 1;
                if (guard > 64) begin
                    fail_now("timeout waiting up_resp_valid to clear");
                end
            end
        end
    endtask

    task expect_route_deltas;
        input integer cache_delta;
        input integer bypass_delta;
        begin
            if ((cache_req_count - cache_before) != cache_delta) begin
                fail_now("unexpected cache request count delta");
            end
            if ((bypass_req_count - bypass_before) != bypass_delta) begin
                fail_now("unexpected bypass request count delta");
            end
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cache_req_count   <= 0;
            bypass_req_count  <= 0;
            last_cache_addr   <= 32'h0;
            last_bypass_addr  <= 32'h0;
            last_cache_write  <= 1'b0;
            last_bypass_write <= 1'b0;
            last_cache_wdata  <= 64'h0;
            last_bypass_wdata <= 64'h0;
            last_cache_wstrb  <= 8'h0;
            last_bypass_wstrb <= 8'h0;
        end else begin
            if (cache_req_valid && cache_req_ready) begin
                cache_req_count  <= cache_req_count + 1;
                last_cache_addr  <= cache_req_addr;
                last_cache_write <= cache_req_write;
                last_cache_wdata <= cache_req_wdata;
                last_cache_wstrb <= cache_req_wstrb;
            end

            if (bypass_req_valid && bypass_req_ready) begin
                bypass_req_count  <= bypass_req_count + 1;
                last_bypass_addr  <= bypass_req_addr;
                last_bypass_write <= bypass_req_write;
                last_bypass_wdata <= bypass_req_wdata;
                last_bypass_wstrb <= bypass_req_wstrb;
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
        invalidate_line_valid = 1'b0;
        invalidate_line_addr  = 32'h0;
        invalidate_all_valid  = 1'b0;
        up_resp_ready         = 1'b1;
        cache_req_ready       = 1'b1;
        cache_resp_valid      = 1'b0;
        cache_resp_rdata      = 64'h0;
        cache_resp_id         = {ID_BITS{1'b0}};
        bypass_req_ready      = 1'b1;
        bypass_resp_valid     = 1'b0;
        bypass_resp_rdata     = 64'h0;
        bypass_resp_id        = {ID_BITS{1'b0}};
        cache_before          = 0;
        bypass_before         = 0;

        repeat (2) @(posedge clk);
        rst_n <= 1'b1;

        wait_idle_mode(2'b00, 32'h0000_0000);
        if (config_error !== 1'b0) begin
            fail_now("config_error should be low after reset");
        end

        cache_before  = cache_req_count;
        bypass_before = bypass_req_count;
        bypass_req_ready <= 1'b0;
        drive_request(1'b1, 32'h0000_0120, 8'd7, 64'h1122_3344_5566_7788, 8'h3c, 1'b0);
        wait_for_bypass_valid(32'h0000_0120, 1'b1,
                              64'h1122_3344_5566_7788, 8'h3c);
        hold_bypass_wait(32'h0000_0120, 1'b1,
                         64'h1122_3344_5566_7788, 8'h3c, 2);
        hold_new_request_blocked(1'b0, 32'h0000_0130, 8'd7, 64'h0, 8'h00, 1'b0, 2);

        bypass_req_ready <= 1'b1;
        @(posedge clk);
        #1;
        expect_route_deltas(0, 1);
        if ((last_bypass_addr !== 32'h0000_0120) ||
            (last_bypass_write !== 1'b1) ||
            (last_bypass_wdata !== 64'h1122_3344_5566_7788) ||
            (last_bypass_wstrb !== 8'h3c)) begin
            fail_now("bypass write handshake metadata mismatch");
        end

        if (up_req_ready !== 1'b0) begin
            fail_now("up_req_ready should stay low while bypass response is outstanding");
        end

        up_resp_ready <= 1'b0;
        pulse_bypass_resp(64'hBEEF_BEEF_0000_0001);
        wait_up_resp(64'hBEEF_BEEF_0000_0001);
        hold_up_resp_blocked(64'hBEEF_BEEF_0000_0001, 2);
        up_resp_ready <= 1'b1;
        @(posedge clk);
        wait_resp_clear;

        mode_req <= 2'b01;
        wait_idle_mode(2'b01, 32'h0000_0000);

        cache_before  = cache_req_count;
        bypass_before = bypass_req_count;
        bypass_req_ready <= 1'b0;
        drive_request(1'b1, 32'h0000_0188, 8'd7, 64'hABCD_EF01_0203_0405, 8'hf0, 1'b1);
        wait_for_bypass_valid(32'h0000_0188, 1'b1,
                              64'hABCD_EF01_0203_0405, 8'hf0);
        hold_bypass_wait(32'h0000_0188, 1'b1,
                         64'hABCD_EF01_0203_0405, 8'hf0, 1);
        bypass_req_ready <= 1'b1;
        @(posedge clk);
        #1;
        expect_route_deltas(0, 1);
        if ((last_bypass_addr !== 32'h0000_0188) ||
            (last_bypass_write !== 1'b1) ||
            (last_bypass_wdata !== 64'hABCD_EF01_0203_0405) ||
            (last_bypass_wstrb !== 8'hf0)) begin
            fail_now("mode1 bypass metadata mismatch");
        end
        pulse_bypass_resp(64'hCAFE_0000_0000_1111);
        wait_up_resp(64'hCAFE_0000_0000_1111);
        @(posedge clk);
        wait_resp_clear;

        cache_before  = cache_req_count;
        bypass_before = bypass_req_count;
        cache_req_ready <= 1'b0;
        drive_request(1'b0, 32'h0000_002c, 8'd7, 64'h0, 8'h00, 1'b0);
        wait_for_cache_valid(32'h0000_0028, 1'b0);
        hold_cache_wait(32'h0000_0028, 1'b0, 2);
        hold_new_request_blocked(1'b0, 32'h0000_0034, 8'd7, 64'h0, 8'h00, 1'b0, 2);

        cache_req_ready <= 1'b1;
        @(posedge clk);
        #1;
        expect_route_deltas(1, 0);
        if ((last_cache_addr !== 32'h0000_0028) ||
            (last_cache_write !== 1'b0)) begin
            fail_now("cache read handshake metadata mismatch");
        end

        if (cache_resp_ready !== 1'b1) begin
            fail_now("cache_resp_ready should be high while refill response is pending");
        end
        if (up_req_ready !== 1'b0) begin
            fail_now("up_req_ready should stay low while cache miss is outstanding");
        end

        repeat (2) @(posedge clk);
        if (up_req_ready !== 1'b0) begin
            fail_now("up_req_ready should stay low until cache response returns");
        end

        pulse_cache_resp(64'h0123_4567_89ab_cdef);
        wait_up_resp(64'h0123_4567_89ab_cdef);
        @(posedge clk);
        wait_resp_clear;

        $display("tb_axi_llc_subsystem_handshake_contract PASS");
        $finish;
    end

endmodule
