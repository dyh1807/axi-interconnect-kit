`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_mode_contract;

    localparam ID_BITS = 4;
    localparam READ_RESP_BITS = `AXI_LLC_READ_RESP_BITS;

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
    wire [READ_RESP_BITS-1:0] up_resp_rdata;
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
    reg  [READ_RESP_BITS-1:0] cache_resp_rdata;
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
    reg  [READ_RESP_BITS-1:0] bypass_resp_rdata;
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
    reg [63:0] tmp_rdata;
    reg [63:0] cache_next_data;
    reg [63:0] bypass_next_data;
    reg        cache_resp_pending;
    reg        bypass_resp_pending;
    reg [ID_BITS-1:0] cache_next_id;
    reg [ID_BITS-1:0] bypass_next_id;
    wire [63:0] up_resp_line;

    assign up_resp_line = up_resp_rdata[63:0];

    function [63:0] make_cache_data;
        input [31:0] addr;
        begin
            make_cache_data = 64'hCA00_0000_0000_0000 ^ {32'h0, addr};
        end
    endfunction

    function [63:0] make_bypass_data;
        input [31:0] addr;
        begin
            make_bypass_data = 64'hB0F0_0000_0000_0000 ^ {32'h0, addr};
        end
    endfunction

    function [READ_RESP_BITS-1:0] pack_read_resp_line;
        input [63:0] line_value;
        begin
            pack_read_resp_line = {READ_RESP_BITS{1'b0}};
            pack_read_resp_line[63:0] = line_value;
        end
    endfunction

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
        .WINDOW_WAYS      (2),
        .READ_RESP_BITS   (READ_RESP_BITS)
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
            $display("tb_axi_llc_subsystem_mode_contract FAIL: %0s", msg);
            $finish;
        end
    endtask

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

    task do_request;
        input        is_write;
        input [31:0] addr;
        input [7:0]  total_size;
        input [63:0] wdata;
        input [7:0]  wstrb;
        input        bypass;
        output [63:0] rdata;
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
                if (guard > 64) begin
                    fail_now("timeout waiting up_req_ready");
                end
            end

            @(posedge clk);
            up_req_valid <= 1'b0;
            up_req_id    <= {ID_BITS{1'b0}};
            up_req_total_size <= 8'd0;

            guard = 0;
            while (!up_resp_valid) begin
                @(posedge clk);
                guard = guard + 1;
                if (guard > 128) begin
                    fail_now("timeout waiting up_resp_valid");
                end
            end

            rdata = up_resp_line;
            @(posedge clk);
        end
    endtask

    task expect_route_delta;
        input integer cache_before;
        input integer bypass_before;
        input integer exp_cache_delta;
        input integer exp_bypass_delta;
        begin
            if ((cache_req_count - cache_before) != exp_cache_delta) begin
                fail_now("unexpected cache route count delta");
            end
            if ((bypass_req_count - bypass_before) != exp_bypass_delta) begin
                fail_now("unexpected bypass route count delta");
            end
        end
    endtask

    task expect_last_cache;
        input [31:0] exp_addr;
        input        exp_write;
        begin
            if ((last_cache_addr !== exp_addr) || (last_cache_write !== exp_write)) begin
                fail_now("cache route metadata mismatch");
            end
        end
    endtask

    task expect_last_bypass;
        input [31:0] exp_addr;
        input        exp_write;
        begin
            if ((last_bypass_addr !== exp_addr) || (last_bypass_write !== exp_write)) begin
                fail_now("bypass route metadata mismatch");
            end
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cache_req_count      <= 0;
            bypass_req_count     <= 0;
            last_cache_addr      <= 32'h0;
            last_bypass_addr     <= 32'h0;
            last_cache_write     <= 1'b0;
            last_bypass_write    <= 1'b0;
            cache_resp_pending   <= 1'b0;
            bypass_resp_pending  <= 1'b0;
            cache_resp_valid     <= 1'b0;
            bypass_resp_valid    <= 1'b0;
            cache_resp_rdata     <= {READ_RESP_BITS{1'b0}};
            bypass_resp_rdata    <= {READ_RESP_BITS{1'b0}};
            cache_next_data      <= 64'h0;
            bypass_next_data     <= 64'h0;
            cache_resp_id        <= {ID_BITS{1'b0}};
            bypass_resp_id       <= {ID_BITS{1'b0}};
            cache_next_id        <= {ID_BITS{1'b0}};
            bypass_next_id       <= {ID_BITS{1'b0}};
        end else begin
            cache_resp_valid  <= 1'b0;
            bypass_resp_valid <= 1'b0;
            cache_resp_id     <= {ID_BITS{1'b0}};
            bypass_resp_id    <= {ID_BITS{1'b0}};

            if (cache_req_valid && cache_req_ready) begin
                cache_req_count   <= cache_req_count + 1;
                last_cache_addr   <= cache_req_addr;
                last_cache_write  <= cache_req_write;
                cache_next_data   <= make_cache_data(cache_req_addr);
                cache_next_id     <= cache_req_id;
                cache_resp_pending <= 1'b1;
            end

            if (bypass_req_valid && bypass_req_ready) begin
                bypass_req_count    <= bypass_req_count + 1;
                last_bypass_addr    <= bypass_req_addr;
                last_bypass_write   <= bypass_req_write;
                bypass_next_data    <= make_bypass_data(bypass_req_addr);
                bypass_next_id      <= bypass_req_id;
                bypass_resp_pending <= 1'b1;
            end

            if (cache_resp_pending) begin
                cache_resp_valid   <= 1'b1;
                cache_resp_rdata   <= pack_read_resp_line(cache_next_data);
                cache_resp_id      <= cache_next_id;
                cache_resp_pending <= 1'b0;
            end

            if (bypass_resp_pending) begin
                bypass_resp_valid   <= 1'b1;
                bypass_resp_rdata   <= pack_read_resp_line(bypass_next_data);
                bypass_resp_id      <= bypass_next_id;
                bypass_resp_pending <= 1'b0;
            end
        end
    end

    initial begin
        integer cache_before;
        integer bypass_before;

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
        up_req_wstrb          = 8'h00;
        up_req_bypass         = 1'b0;
        invalidate_line_valid = 1'b0;
        invalidate_line_addr  = 32'h0;
        invalidate_all_valid  = 1'b0;
        up_resp_ready         = 1'b1;
        cache_req_ready       = 1'b1;
        bypass_req_ready      = 1'b1;
        tmp_rdata             = 64'h0;
        cache_resp_id         = {ID_BITS{1'b0}};
        bypass_resp_id        = {ID_BITS{1'b0}};
        cache_next_id         = {ID_BITS{1'b0}};
        bypass_next_id        = {ID_BITS{1'b0}};

        repeat (2) @(posedge clk);
        rst_n <= 1'b1;

        mode_req              <= 2'b10;
        llc_mapped_offset_req <= 32'h0000_1000;
        wait_idle_mode(2'b10, 32'h0000_1000);
        if (config_error) begin
            fail_now("aligned mapped offset flagged config_error");
        end

        cache_before  = cache_req_count;
        bypass_before = bypass_req_count;
        do_request(1'b0, 32'h0000_1000, 8'd7, 64'h0, 8'h00, 1'b0, tmp_rdata);
        expect_route_delta(cache_before, bypass_before, 0, 0);
        if (tmp_rdata !== 64'h0) begin
            fail_now("mode2 invalid read must return zero");
        end

        cache_before  = cache_req_count;
        bypass_before = bypass_req_count;
        do_request(1'b1, 32'h0000_1000, 8'd7, 64'h1122_3344_5566_7788, 8'hFF, 1'b0, tmp_rdata);
        expect_route_delta(cache_before, bypass_before, 0, 0);
        if (tmp_rdata !== 64'h0) begin
            fail_now("mode2 direct write response must be zero");
        end

        cache_before  = cache_req_count;
        bypass_before = bypass_req_count;
        do_request(1'b0, 32'h0000_1000, 8'd7, 64'h0, 8'h00, 1'b0, tmp_rdata);
        expect_route_delta(cache_before, bypass_before, 0, 0);
        if (tmp_rdata !== 64'h1122_3344_5566_7788) begin
            fail_now("mode2 write then read mismatch");
        end

        cache_before  = cache_req_count;
        bypass_before = bypass_req_count;
        do_request(1'b0, 32'h0000_1040, 8'd7, 64'h0, 8'h00, 1'b0, tmp_rdata);
        expect_route_delta(cache_before, bypass_before, 0, 1);
        expect_last_bypass(32'h0000_1040, 1'b0);
        if (tmp_rdata !== make_bypass_data(32'h0000_1040)) begin
            fail_now("mode2 out-of-window request must return bypass data");
        end

        mode_req              <= 2'b01;
        llc_mapped_offset_req <= 32'h0000_1000;
        wait_idle_mode(2'b01, 32'h0000_1000);

        cache_before  = cache_req_count;
        bypass_before = bypass_req_count;
        do_request(1'b0, 32'h0000_2000, 8'd7, 64'h0, 8'h00, 1'b0, tmp_rdata);
        expect_route_delta(cache_before, bypass_before, 1, 0);
        expect_last_cache(32'h0000_2000, 1'b0);
        if (tmp_rdata !== make_cache_data(32'h0000_2000)) begin
            fail_now("mode1 non-bypass request must use cache port");
        end

        mode_req              <= 2'b10;
        llc_mapped_offset_req <= 32'h0000_1000;
        wait_idle_mode(2'b10, 32'h0000_1000);

        cache_before  = cache_req_count;
        bypass_before = bypass_req_count;
        do_request(1'b0, 32'h0000_1000, 8'd7, 64'h0, 8'h00, 1'b0, tmp_rdata);
        expect_route_delta(cache_before, bypass_before, 0, 0);
        if (tmp_rdata !== 64'h0) begin
            fail_now("mode switch must hide old mapped valid state");
        end

        mode_req              <= 2'b00;
        llc_mapped_offset_req <= 32'h0000_1000;
        wait_idle_mode(2'b00, 32'h0000_1000);

        cache_before  = cache_req_count;
        bypass_before = bypass_req_count;
        do_request(1'b0, 32'h0000_3000, 8'd7, 64'h0, 8'h00, 1'b0, tmp_rdata);
        expect_route_delta(cache_before, bypass_before, 0, 1);
        expect_last_bypass(32'h0000_3000, 1'b0);
        if (tmp_rdata !== make_bypass_data(32'h0000_3000)) begin
            fail_now("mode0 request must use bypass port");
        end

        mode_req              <= 2'b11;
        llc_mapped_offset_req <= 32'h0000_1000;
        wait_idle_mode(2'b11, 32'h0000_1000);

        cache_before  = cache_req_count;
        bypass_before = bypass_req_count;
        do_request(1'b0, 32'h0000_4000, 8'd7, 64'h0, 8'h00, 1'b0, tmp_rdata);
        expect_route_delta(cache_before, bypass_before, 0, 1);
        expect_last_bypass(32'h0000_4000, 1'b0);
        if (tmp_rdata !== make_bypass_data(32'h0000_4000)) begin
            fail_now("mode3 request must use bypass port");
        end

        $display("tb_axi_llc_subsystem_mode_contract PASS");
        $finish;
    end

endmodule
