`timescale 1ns / 1ps

module tb_axi_llc_subsystem_invalidate_all_contract;

    localparam ADDR_BITS        = 32;
    localparam ID_BITS          = 4;
    localparam MODE_BITS        = 2;
    localparam LINE_BYTES       = 8;
    localparam LINE_BITS        = 64;
    localparam LINE_OFFSET_BITS = 3;
    localparam SET_COUNT        = 4;
    localparam SET_BITS         = 2;
    localparam WAY_COUNT        = 4;
    localparam WAY_BITS         = 2;
    localparam META_BITS        = 24;
    localparam LLC_SIZE_BYTES   = LINE_BYTES * SET_COUNT * WAY_COUNT;
    localparam WINDOW_WAYS      = 2;
    localparam WINDOW_BYTES     = LINE_BYTES * SET_COUNT * WINDOW_WAYS;
    localparam MEM_DEPTH        = 64;
    localparam [7:0] FULL_SIZE  = 8'd7;

    localparam [MODE_BITS-1:0] MODE_OFF    = 2'b00;
    localparam [MODE_BITS-1:0] MODE_CACHE  = 2'b01;
    localparam [MODE_BITS-1:0] MODE_MAPPED = 2'b10;
    localparam [MODE_BITS-1:0] MODE_OFF3   = 2'b11;

    localparam [ADDR_BITS-1:0] CACHE_ADDR_DIRTY = 32'h0000_0000;
    localparam [ADDR_BITS-1:0] MAPPED_OFFSET    = 32'h0000_1000;
    localparam [ADDR_BITS-1:0] MAPPED_ADDR      = MAPPED_OFFSET + 32'h0000_0020;

    reg                       clk;
    reg                       rst_n;
    reg  [MODE_BITS-1:0]      mode_req;
    reg  [ADDR_BITS-1:0]      llc_mapped_offset_req;
    reg                       up_req_valid;
    wire                      up_req_ready;
    reg                       up_req_write;
    reg  [ADDR_BITS-1:0]      up_req_addr;
    reg  [ID_BITS-1:0]        up_req_id;
    reg  [7:0]                up_req_total_size;
    reg  [LINE_BITS-1:0]      up_req_wdata;
    reg  [LINE_BYTES-1:0]     up_req_wstrb;
    reg                       up_req_bypass;
    wire                      up_resp_valid;
    reg                       up_resp_ready;
    wire [LINE_BITS-1:0]      up_resp_rdata;
    wire [ID_BITS-1:0]        up_resp_id;
    wire                      cache_req_valid;
    reg                       cache_req_ready;
    wire                      cache_req_write;
    wire [ADDR_BITS-1:0]      cache_req_addr;
    wire [ID_BITS-1:0]        cache_req_id;
    wire [7:0]                cache_req_size;
    wire [LINE_BITS-1:0]      cache_req_wdata;
    wire [LINE_BYTES-1:0]     cache_req_wstrb;
    reg                       cache_resp_valid;
    wire                      cache_resp_ready;
    reg  [LINE_BITS-1:0]      cache_resp_rdata;
    reg  [ID_BITS-1:0]        cache_resp_id;
    wire                      bypass_req_valid;
    reg                       bypass_req_ready;
    wire                      bypass_req_write;
    wire [ADDR_BITS-1:0]      bypass_req_addr;
    wire [ID_BITS-1:0]        bypass_req_id;
    wire [7:0]                bypass_req_size;
    wire [LINE_BITS-1:0]      bypass_req_wdata;
    wire [LINE_BYTES-1:0]     bypass_req_wstrb;
    reg                       bypass_resp_valid;
    wire                      bypass_resp_ready;
    reg  [LINE_BITS-1:0]      bypass_resp_rdata;
    reg  [ID_BITS-1:0]        bypass_resp_id;
    reg                       invalidate_line_valid;
    reg  [ADDR_BITS-1:0]      invalidate_line_addr;
    wire                      invalidate_line_accepted;
    reg                       invalidate_all_valid;
    wire                      invalidate_all_accepted;
    wire [MODE_BITS-1:0]      active_mode;
    wire [ADDR_BITS-1:0]      active_offset;
    wire                      reconfig_busy;
    wire [1:0]                reconfig_state;
    wire                      config_error;

    reg  [LINE_BITS-1:0]      mem_model [0:MEM_DEPTH-1];
    reg                       cache_resp_pending_r;
    reg  [LINE_BITS-1:0]      cache_resp_pending_data_r;
    reg  [ID_BITS-1:0]        cache_resp_pending_id_r;
    reg                       bypass_resp_pending_r;
    reg  [LINE_BITS-1:0]      bypass_resp_pending_data_r;
    reg  [ID_BITS-1:0]        bypass_resp_pending_id_r;

    integer                   cycle_count;
    integer                   cache_req_count;
    integer                   cache_read_count;
    integer                   cache_write_count;
    integer                   bypass_req_count;
    integer                   invalidate_all_accept_count;
    integer                   sweep_start_count;
    integer                   sweep_done_count;
    integer                   capture_first_cache_write_cycle;
    integer                   capture_first_sweep_start_cycle;
    reg                       capture_after_invalidate_r;
    integer                   idx;

    integer                   reads_before;
    integer                   writes_before;
    integer                   bypass_before;
    integer                   sweeps_before;
    integer                   accepts_before;

    reg  [LINE_BITS-1:0]      dirty_line_init;
    reg  [LINE_BITS-1:0]      dirty_patch_line;
    reg  [LINE_BITS-1:0]      dirty_line_after_write;
    reg  [LINE_BYTES-1:0]     dirty_patch_strb;
    reg  [LINE_BITS-1:0]      mapped_line;
    reg  [LINE_BITS-1:0]      resp_line;

    function [LINE_BITS-1:0] make_line;
        input [7:0] seed;
        integer byte_idx;
        begin
            make_line = {LINE_BITS{1'b0}};
            for (byte_idx = 0; byte_idx < LINE_BYTES; byte_idx = byte_idx + 1) begin
                make_line[(byte_idx * 8) +: 8] = seed + byte_idx[7:0];
            end
        end
    endfunction

    function [LINE_BITS-1:0] merge_line;
        input [LINE_BITS-1:0]  base_line;
        input [LINE_BITS-1:0]  write_line;
        input [LINE_BYTES-1:0] write_strb;
        integer byte_idx;
        begin
            merge_line = base_line;
            for (byte_idx = 0; byte_idx < LINE_BYTES; byte_idx = byte_idx + 1) begin
                if (write_strb[byte_idx]) begin
                    merge_line[(byte_idx * 8) +: 8] = write_line[(byte_idx * 8) +: 8];
                end
            end
        end
    endfunction

    function integer mem_index;
        input [ADDR_BITS-1:0] addr_value;
        begin
            mem_index = addr_value[LINE_OFFSET_BITS + 5:LINE_OFFSET_BITS];
        end
    endfunction

    function [LINE_BITS-1:0] make_bypass_line;
        input [ADDR_BITS-1:0] addr_value;
        begin
            make_bypass_line = 64'hBADA_0000_0000_0000 ^ {32'h0, addr_value};
        end
    endfunction

    task fail_now;
        input [8*120-1:0] msg;
        begin
            $display("tb_axi_llc_subsystem_invalidate_all_contract FAIL: %0s", msg);
            $finish(1);
        end
    endtask

    task wait_cycles;
        input integer cycles;
        integer cycle_idx;
        begin
            for (cycle_idx = 0; cycle_idx < cycles; cycle_idx = cycle_idx + 1) begin
                @(posedge clk);
            end
        end
    endtask

    task wait_mode_active;
        input [MODE_BITS-1:0] expect_mode;
        input [ADDR_BITS-1:0] expect_offset;
        integer timeout;
        begin
            timeout = 0;
            while ((active_mode !== expect_mode) ||
                   (active_offset !== expect_offset) ||
                   reconfig_busy) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 400) begin
                    fail_now("timeout waiting active mode/offset");
                end
            end
            @(posedge clk);
            if ((active_mode !== expect_mode) ||
                (active_offset !== expect_offset) ||
                (reconfig_state !== 2'b00) ||
                config_error) begin
                fail_now("unexpected active mode/offset after settle");
            end
        end
    endtask

    task wait_upstream_idle;
        integer timeout;
        integer stable_cycles;
        begin
            timeout = 0;
            stable_cycles = 0;
            while (stable_cycles < 2) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (up_resp_valid === 1'b0) begin
                    stable_cycles = stable_cycles + 1;
                end else begin
                    stable_cycles = 0;
                end
                if (timeout > 200) begin
                    fail_now("timeout waiting upstream response channel idle");
                end
            end
        end
    endtask

    task issue_request;
        input                      is_write;
        input [ADDR_BITS-1:0]      addr_value;
        input [7:0]                total_size_value;
        input [LINE_BITS-1:0]      wdata_value;
        input [LINE_BYTES-1:0]     wstrb_value;
        input                      bypass_value;
        integer timeout;
        begin
            up_req_valid      <= 1'b1;
            up_req_write      <= is_write;
            up_req_addr       <= addr_value;
            up_req_id         <= {ID_BITS{1'b0}};
            up_req_total_size <= total_size_value;
            up_req_wdata      <= wdata_value;
            up_req_wstrb      <= wstrb_value;
            up_req_bypass     <= bypass_value;

            timeout = 0;
            while (!up_req_ready) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 200) begin
                    fail_now("timeout waiting up_req_ready");
                end
            end

            @(posedge clk);
            up_req_valid      <= 1'b0;
            up_req_write      <= 1'b0;
            up_req_addr       <= {ADDR_BITS{1'b0}};
            up_req_id         <= {ID_BITS{1'b0}};
            up_req_total_size <= 8'd0;
            up_req_wdata      <= {LINE_BITS{1'b0}};
            up_req_wstrb      <= {LINE_BYTES{1'b0}};
            up_req_bypass     <= 1'b0;
        end
    endtask

    task wait_for_response;
        output [LINE_BITS-1:0] resp_data;
        integer timeout;
        begin
            timeout = 0;
            while (!up_resp_valid) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 400) begin
                    fail_now("timeout waiting up_resp_valid");
                end
            end
            #1;
            resp_data = up_resp_rdata;
            @(posedge clk);
            timeout = 0;
            while (up_resp_valid) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 32) begin
                    fail_now("response channel did not return to idle");
                end
            end
        end
    endtask

    task do_read_expect;
        input [ADDR_BITS-1:0]  addr_value;
        input [LINE_BITS-1:0]  expect_value;
        input [8*120-1:0]      msg;
        begin
            issue_request(1'b0,
                          addr_value,
                          FULL_SIZE,
                          {LINE_BITS{1'b0}},
                          {LINE_BYTES{1'b0}},
                          1'b0);
            wait_for_response(resp_line);
            if (resp_line !== expect_value) begin
                fail_now(msg);
            end
        end
    endtask

    task do_read_expect_nonzero;
        input [ADDR_BITS-1:0]  addr_value;
        input [8*120-1:0]      msg;
        begin
            issue_request(1'b0,
                          addr_value,
                          FULL_SIZE,
                          {LINE_BITS{1'b0}},
                          {LINE_BYTES{1'b0}},
                          1'b0);
            wait_for_response(resp_line);
            if (resp_line === {LINE_BITS{1'b0}}) begin
                fail_now(msg);
            end
        end
    endtask

    task wait_for_direct_response;
        output [LINE_BITS-1:0] resp_data;
        integer timeout;
        begin
            timeout = 0;
            while (!dut.resp_pending_r) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 400) begin
                    fail_now("timeout waiting direct response latch");
                end
            end
            #1;
            resp_data = dut.resp_data_r;
            @(posedge clk);
            timeout = 0;
            while (dut.resp_pending_r) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 32) begin
                    fail_now("direct response latch did not return idle");
                end
            end
            wait_upstream_idle();
        end
    endtask

    task do_direct_read_expect;
        input [ADDR_BITS-1:0]  addr_value;
        input [LINE_BITS-1:0]  expect_value;
        input [8*120-1:0]      msg;
        begin
            issue_request(1'b0,
                          addr_value,
                          FULL_SIZE,
                          {LINE_BITS{1'b0}},
                          {LINE_BYTES{1'b0}},
                          1'b0);
            wait_for_direct_response(resp_line);
            if (resp_line !== expect_value) begin
                fail_now(msg);
            end
        end
    endtask

    task do_direct_read_expect_nonzero;
        input [ADDR_BITS-1:0]  addr_value;
        input [8*120-1:0]      msg;
        begin
            issue_request(1'b0,
                          addr_value,
                          FULL_SIZE,
                          {LINE_BITS{1'b0}},
                          {LINE_BYTES{1'b0}},
                          1'b0);
            wait_for_direct_response(resp_line);
            if (resp_line === {LINE_BITS{1'b0}}) begin
                fail_now(msg);
            end
        end
    endtask

    task do_write_expect_zero;
        input [ADDR_BITS-1:0]      addr_value;
        input [LINE_BITS-1:0]      write_value;
        input [LINE_BYTES-1:0]     write_strb;
        input [8*120-1:0]          msg;
        begin
            issue_request(1'b1,
                          addr_value,
                          FULL_SIZE,
                          write_value,
                          write_strb,
                          1'b0);
            wait_for_response(resp_line);
            if (resp_line !== {LINE_BITS{1'b0}}) begin
                fail_now(msg);
            end
        end
    endtask

    task do_write_ignore_response;
        input [ADDR_BITS-1:0]      addr_value;
        input [LINE_BITS-1:0]      write_value;
        input [LINE_BYTES-1:0]     write_strb;
        begin
            issue_request(1'b1,
                          addr_value,
                          FULL_SIZE,
                          write_value,
                          write_strb,
                          1'b0);
            wait_for_response(resp_line);
        end
    endtask

    task issue_invalidate_all;
        integer timeout;
        begin
            invalidate_all_valid <= 1'b1;
            timeout = 0;
            while (!(invalidate_all_valid && invalidate_all_accepted)) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 100) begin
                    fail_now("timeout waiting invalidate_all handshake");
                end
            end
            @(negedge clk);
            invalidate_all_valid <= 1'b0;
        end
    endtask

    task issue_invalidate_line_once;
        input [ADDR_BITS-1:0] addr_value;
        integer timeout;
        begin
            invalidate_line_valid <= 1'b1;
            invalidate_line_addr <= addr_value;
            timeout = 0;
            while (!invalidate_line_accepted) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 100) begin
                    fail_now("timeout waiting invalidate_line handshake");
                end
            end
            @(negedge clk);
            invalidate_line_valid <= 1'b0;
            invalidate_line_addr <= {ADDR_BITS{1'b0}};
        end
    endtask

    task hold_read_blocked_during_reconfig;
        input [ADDR_BITS-1:0] addr_value;
        integer timeout;
        integer saw_busy;
        begin
            saw_busy = 0;
            up_req_valid      <= 1'b1;
            up_req_write      <= 1'b0;
            up_req_addr       <= addr_value;
            up_req_id         <= {ID_BITS{1'b0}};
            up_req_total_size <= FULL_SIZE;
            up_req_wdata      <= {LINE_BITS{1'b0}};
            up_req_wstrb      <= {LINE_BYTES{1'b0}};
            up_req_bypass     <= 1'b0;

            timeout = 0;
            while (!saw_busy) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (reconfig_busy) begin
                    saw_busy = 1;
                    if (up_req_ready !== 1'b0) begin
                        fail_now("up_req_ready high while invalidate_all reconfig busy");
                    end
                end

                if (timeout > 400) begin
                    fail_now("timeout waiting blocked request busy window");
                end
            end
        end
    endtask

    task wait_held_read_accept;
        integer timeout;
        begin
            timeout = 0;
            while (up_req_ready !== 1'b1) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 400) begin
                    fail_now("timeout waiting held request acceptance");
                end
            end

            @(negedge clk);
            up_req_valid      <= 1'b0;
            up_req_addr       <= {ADDR_BITS{1'b0}};
            up_req_id         <= {ID_BITS{1'b0}};
            up_req_total_size <= 8'd0;
        end
    endtask

    always #5 clk = ~clk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cache_resp_valid              <= 1'b0;
            cache_resp_rdata              <= {LINE_BITS{1'b0}};
            cache_resp_id                 <= {ID_BITS{1'b0}};
            cache_resp_pending_r          <= 1'b0;
            cache_resp_pending_data_r     <= {LINE_BITS{1'b0}};
            cache_resp_pending_id_r       <= {ID_BITS{1'b0}};
            bypass_resp_valid             <= 1'b0;
            bypass_resp_rdata             <= {LINE_BITS{1'b0}};
            bypass_resp_id                <= {ID_BITS{1'b0}};
            bypass_resp_pending_r         <= 1'b0;
            bypass_resp_pending_data_r    <= {LINE_BITS{1'b0}};
            bypass_resp_pending_id_r      <= {ID_BITS{1'b0}};
            cycle_count                   <= 0;
            cache_req_count               <= 0;
            cache_read_count              <= 0;
            cache_write_count             <= 0;
            bypass_req_count              <= 0;
            invalidate_all_accept_count   <= 0;
            sweep_start_count             <= 0;
            sweep_done_count              <= 0;
            capture_first_cache_write_cycle <= -1;
            capture_first_sweep_start_cycle <= -1;
        end else begin
            cycle_count <= cycle_count + 1;

            if (invalidate_all_valid && invalidate_all_accepted) begin
                invalidate_all_accept_count <= invalidate_all_accept_count + 1;
            end

            if (dut.sweep_start_w) begin
                sweep_start_count <= sweep_start_count + 1;
                if (capture_after_invalidate_r &&
                    (capture_first_sweep_start_cycle < 0)) begin
                    capture_first_sweep_start_cycle <= cycle_count;
                end
            end

            if (dut.sweep_done_w) begin
                sweep_done_count <= sweep_done_count + 1;
            end

            if (cache_resp_valid && cache_resp_ready) begin
                cache_resp_valid <= 1'b0;
                cache_resp_id <= {ID_BITS{1'b0}};
            end
            if (bypass_resp_valid && bypass_resp_ready) begin
                bypass_resp_valid <= 1'b0;
                bypass_resp_id <= {ID_BITS{1'b0}};
            end

            if (cache_resp_pending_r) begin
                cache_resp_valid <= 1'b1;
                cache_resp_rdata <= cache_resp_pending_data_r;
                cache_resp_id <= cache_resp_pending_id_r;
                cache_resp_pending_r <= 1'b0;
            end

            if (bypass_resp_pending_r) begin
                bypass_resp_valid <= 1'b1;
                bypass_resp_rdata <= bypass_resp_pending_data_r;
                bypass_resp_id <= bypass_resp_pending_id_r;
                bypass_resp_pending_r <= 1'b0;
            end

            if (cache_req_valid && cache_req_ready) begin
                cache_req_count <= cache_req_count + 1;
                if (cache_req_write) begin
                    cache_write_count <= cache_write_count + 1;
                    mem_model[mem_index(cache_req_addr)] <= cache_req_wdata;
                    cache_resp_pending_r <= 1'b1;
                    cache_resp_pending_data_r <= {LINE_BITS{1'b0}};
                    cache_resp_pending_id_r <= cache_req_id;
                    if (capture_after_invalidate_r &&
                        (capture_first_cache_write_cycle < 0)) begin
                        capture_first_cache_write_cycle <= cycle_count;
                    end
                end else begin
                    cache_read_count <= cache_read_count + 1;
                    cache_resp_pending_r <= 1'b1;
                    cache_resp_pending_data_r <= mem_model[mem_index(cache_req_addr)];
                    cache_resp_pending_id_r <= cache_req_id;
                end
            end

            if (bypass_req_valid && bypass_req_ready) begin
                bypass_req_count <= bypass_req_count + 1;
                bypass_resp_pending_r <= 1'b1;
                bypass_resp_pending_id_r <= bypass_req_id;
                if (bypass_req_write) begin
                    bypass_resp_pending_data_r <= {LINE_BITS{1'b0}};
                end else begin
                    bypass_resp_pending_data_r <= make_bypass_line(bypass_req_addr);
                end
            end
        end
    end

    axi_llc_subsystem_core #(
        .ADDR_BITS        (ADDR_BITS),
        .RESET_MODE       (MODE_OFF),
        .MODE_BITS        (MODE_BITS),
        .LINE_BYTES       (LINE_BYTES),
        .LINE_BITS        (LINE_BITS),
        .LINE_OFFSET_BITS (LINE_OFFSET_BITS),
        .SET_COUNT        (SET_COUNT),
        .SET_BITS         (SET_BITS),
        .WAY_COUNT        (WAY_COUNT),
        .WAY_BITS         (WAY_BITS),
        .META_BITS        (META_BITS),
        .LLC_SIZE_BYTES   (LLC_SIZE_BYTES),
        .WINDOW_BYTES     (WINDOW_BYTES),
        .WINDOW_WAYS      (WINDOW_WAYS),
        .MMIO_BASE        (32'hF000_0000),
        .MMIO_SIZE        (32'h0000_1000),
        .USE_SMIC12_STORES(0)
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

    initial begin
        clk                   = 1'b0;
        rst_n                 = 1'b0;
        mode_req              = MODE_OFF;
        llc_mapped_offset_req = {ADDR_BITS{1'b0}};
        up_req_valid          = 1'b0;
        up_req_write          = 1'b0;
        up_req_addr           = {ADDR_BITS{1'b0}};
        up_req_id             = {ID_BITS{1'b0}};
        up_req_total_size     = 8'd0;
        up_req_wdata          = {LINE_BITS{1'b0}};
        up_req_wstrb          = {LINE_BYTES{1'b0}};
        up_req_bypass         = 1'b0;
        up_resp_ready         = 1'b1;
        cache_req_ready       = 1'b1;
        bypass_req_ready      = 1'b1;
        cache_resp_valid      = 1'b0;
        cache_resp_rdata      = {LINE_BITS{1'b0}};
        cache_resp_id         = {ID_BITS{1'b0}};
        bypass_resp_valid     = 1'b0;
        bypass_resp_rdata     = {LINE_BITS{1'b0}};
        bypass_resp_id        = {ID_BITS{1'b0}};
        invalidate_line_valid = 1'b0;
        invalidate_line_addr  = {ADDR_BITS{1'b0}};
        invalidate_all_valid  = 1'b0;
        capture_after_invalidate_r = 1'b0;

        dirty_line_init       = make_line(8'h20);
        dirty_patch_line      = make_line(8'hA0);
        dirty_patch_strb      = 8'b0000_1111;
        dirty_line_after_write = merge_line(dirty_line_init,
                                            dirty_patch_line,
                                            dirty_patch_strb);
        mapped_line           = make_line(8'h55);

        for (idx = 0; idx < MEM_DEPTH; idx = idx + 1) begin
            mem_model[idx] = make_line(idx[7:0]);
        end
        mem_model[mem_index(CACHE_ADDR_DIRTY)] = dirty_line_init;

        wait_cycles(5);
        rst_n = 1'b1;
        wait_mode_active(MODE_OFF, 32'h0000_0000);
        wait_upstream_idle();

        mode_req = MODE_CACHE;
        wait_mode_active(MODE_CACHE, 32'h0000_0000);
        wait_upstream_idle();

        do_read_expect(CACHE_ADDR_DIRTY,
                       dirty_line_init,
                       "mode1 initial read miss/refill mismatch");
        do_write_expect_zero(CACHE_ADDR_DIRTY,
                             dirty_patch_line,
                             dirty_patch_strb,
                             "mode1 dirty write response mismatch");

        reads_before = cache_read_count;
        writes_before = cache_write_count;
        sweeps_before = sweep_start_count;
        accepts_before = invalidate_all_accept_count;

        invalidate_all_valid = 1'b1;
        wait_cycles(1);
        hold_read_blocked_during_reconfig(CACHE_ADDR_DIRTY);
        wait_cycles(16);
        if ((invalidate_all_accept_count - accepts_before) != 0) begin
            fail_now("mode1 dirty invalidate_all should not accept");
        end
        if ((cache_write_count - writes_before) != 0) begin
            fail_now("mode1 dirty invalidate_all should not flush dirty line");
        end
        if ((sweep_start_count - sweeps_before) != 0) begin
            fail_now("mode1 dirty invalidate_all should not start sweep");
        end
        @(negedge clk);
        invalidate_all_valid = 1'b0;
        up_req_valid = 1'b0;
        up_req_write = 1'b0;
        up_req_addr = {ADDR_BITS{1'b0}};
        up_req_id = {ID_BITS{1'b0}};
        up_req_total_size = 8'd0;
        up_req_wdata = {LINE_BITS{1'b0}};
        up_req_wstrb = {LINE_BYTES{1'b0}};
        up_req_bypass = 1'b0;
        wait_upstream_idle();

        issue_invalidate_line_once(CACHE_ADDR_DIRTY);
        wait_upstream_idle();

        do_read_expect(CACHE_ADDR_DIRTY,
                       dirty_line_init,
                       "mode1 reread after invalidate_line mismatch");

        reads_before = cache_read_count;
        writes_before = cache_write_count;
        sweeps_before = sweep_start_count;
        accepts_before = invalidate_all_accept_count;
        invalidate_all_valid = 1'b1;
        while (!(invalidate_all_valid && invalidate_all_accepted)) begin
            @(posedge clk);
        end
        @(negedge clk);
        invalidate_all_valid = 1'b0;
        do_read_expect(CACHE_ADDR_DIRTY,
                       dirty_line_init,
                       "mode1 reread after clean invalidate_all mismatch");

        if ((invalidate_all_accept_count - accepts_before) != 1) begin
            fail_now("mode1 clean invalidate_all should accept exactly once");
        end
        if ((cache_write_count - writes_before) != 0) begin
            fail_now("mode1 clean invalidate_all should not flush dirty line");
        end
        if ((sweep_start_count - sweeps_before) != 1) begin
            fail_now("mode1 invalidate_all should trigger one sweep");
        end

        mode_req = MODE_MAPPED;
        llc_mapped_offset_req = MAPPED_OFFSET;
        wait_mode_active(MODE_MAPPED, MAPPED_OFFSET);
        wait_upstream_idle();

        do_write_ignore_response(MAPPED_ADDR,
                                 mapped_line,
                                 {LINE_BYTES{1'b1}});
        do_direct_read_expect_nonzero(
            MAPPED_ADDR,
            "mode2 written data should be visible before invalidate_all"
        );

        reads_before = cache_read_count;
        writes_before = cache_write_count;
        bypass_before = bypass_req_count;
        sweeps_before = sweep_start_count;
        accepts_before = invalidate_all_accept_count;

        issue_invalidate_all();
        wait_mode_active(MODE_MAPPED, MAPPED_OFFSET);
        wait_upstream_idle();

        if ((invalidate_all_accept_count - accepts_before) != 1) begin
            fail_now("mode2 invalidate_all should accept exactly once");
        end
        if ((cache_read_count - reads_before) != 0) begin
            fail_now("mode2 invalidate_all should not create cache reads");
        end
        if ((cache_write_count - writes_before) != 0) begin
            fail_now("mode2 invalidate_all should not create cache writes");
        end
        if ((bypass_req_count - bypass_before) != 0) begin
            fail_now("mode2 invalidate_all should not create bypass traffic");
        end
        if ((sweep_start_count - sweeps_before) != 1) begin
            fail_now("mode2 invalidate_all should trigger one sweep");
        end

        do_direct_read_expect(
            MAPPED_ADDR,
            {LINE_BITS{1'b0}},
            "mode2 invalidate_all should make mapped data invisible"
        );

        mode_req = MODE_OFF;
        wait_mode_active(MODE_OFF, MAPPED_OFFSET);
        wait_upstream_idle();

        reads_before = cache_read_count;
        writes_before = cache_write_count;
        bypass_before = bypass_req_count;
        accepts_before = invalidate_all_accept_count;
        issue_invalidate_all();
        wait_mode_active(MODE_OFF, MAPPED_OFFSET);
        wait_upstream_idle();
        if ((invalidate_all_accept_count - accepts_before) != 1) begin
            fail_now("mode0 invalidate_all should accept exactly once");
        end
        if ((cache_read_count - reads_before) != 0 ||
            (cache_write_count - writes_before) != 0 ||
            (bypass_req_count - bypass_before) != 0) begin
            fail_now("mode0 invalidate_all should not produce lower requests");
        end

        mode_req = MODE_OFF3;
        wait_mode_active(MODE_OFF3, MAPPED_OFFSET);
        wait_upstream_idle();

        reads_before = cache_read_count;
        writes_before = cache_write_count;
        bypass_before = bypass_req_count;
        accepts_before = invalidate_all_accept_count;
        issue_invalidate_all();
        wait_mode_active(MODE_OFF3, MAPPED_OFFSET);
        wait_upstream_idle();
        if ((invalidate_all_accept_count - accepts_before) != 1) begin
            fail_now("mode3 invalidate_all should accept exactly once");
        end
        if ((cache_read_count - reads_before) != 0 ||
            (cache_write_count - writes_before) != 0 ||
            (bypass_req_count - bypass_before) != 0) begin
            fail_now("mode3 invalidate_all should not produce lower requests");
        end

        sweeps_before = sweep_start_count;
        accepts_before = invalidate_all_accept_count;
        mode_req = MODE_CACHE;
        invalidate_all_valid = 1'b1;
        wait_cycles(1);
        while (!(invalidate_all_valid && invalidate_all_accepted)) begin
            @(posedge clk);
        end
        @(negedge clk);
        invalidate_all_valid = 1'b0;
        wait_mode_active(MODE_CACHE, MAPPED_OFFSET);
        wait_upstream_idle();

        if ((invalidate_all_accept_count - accepts_before) != 1) begin
            fail_now("simultaneous mode switch + invalidate_all should accept once");
        end
        if ((sweep_start_count - sweeps_before) != 1) begin
            fail_now("simultaneous mode switch + invalidate_all should run one sweep");
        end

        $display("tb_axi_llc_subsystem_invalidate_all_contract PASS");
        $finish(0);
    end

endmodule
