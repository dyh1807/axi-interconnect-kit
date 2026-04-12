`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_invalidate_line_contract;

    localparam ADDR_BITS        = `AXI_LLC_ADDR_BITS;
    localparam ID_BITS          = `AXI_LLC_ID_BITS;
    localparam MODE_BITS        = `AXI_LLC_MODE_BITS;
    localparam LINE_BYTES       = 8;
    localparam LINE_BITS        = LINE_BYTES * 8;
    localparam LINE_OFFSET_BITS = 3;
    localparam SET_COUNT        = 4;
    localparam SET_BITS         = 2;
    localparam WAY_COUNT        = 4;
    localparam WAY_BITS         = 2;
    localparam META_BITS        = `AXI_LLC_META_BITS;
    localparam LLC_SIZE_BYTES   = LINE_BYTES * SET_COUNT * WAY_COUNT;
    localparam WINDOW_WAYS      = 2;
    localparam WINDOW_BYTES     = LINE_BYTES * SET_COUNT * WINDOW_WAYS;
    localparam MEM_DEPTH        = 16;

    localparam [MODE_BITS-1:0] MODE_OFF    = 2'b00;
    localparam [MODE_BITS-1:0] MODE_CACHE  = 2'b01;
    localparam [MODE_BITS-1:0] MODE_MAPPED = 2'b10;

    localparam [ADDR_BITS-1:0] CACHE_ADDR_CLEAN = 32'h0000_0000;
    localparam [ADDR_BITS-1:0] CACHE_ADDR_DIRTY = 32'h0000_0008;
    localparam [ADDR_BITS-1:0] MAPPED_OFFSET    = 32'h0000_0100;
    localparam [ADDR_BITS-1:0] MAPPED_ADDR      = MAPPED_OFFSET + 32'h0000_0020;
    localparam [ADDR_BITS-1:0] MAPPED_ADDR_OUT  = MAPPED_OFFSET + WINDOW_BYTES;

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

    integer                   cache_read_count;
    integer                   cache_write_count;
    integer                   bypass_req_count;
    integer                   idx;

    reg  [LINE_BITS-1:0]      clean_line_init;
    reg  [LINE_BITS-1:0]      dirty_line_init;
    reg  [LINE_BITS-1:0]      dirty_patch_line;
    reg  [LINE_BITS-1:0]      dirty_line_after_write;
    reg  [LINE_BITS-1:0]      mapped_write_line;
    reg  [LINE_BITS-1:0]      resp_line;
    reg  [LINE_BYTES-1:0]     dirty_patch_strb;
    integer                   reads_before;
    integer                   writes_before;
    integer                   bypass_before;

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
            mem_index = addr_value[LINE_OFFSET_BITS + 3:LINE_OFFSET_BITS];
        end
    endfunction

    task fail_now;
        input [8*96-1:0] msg;
        begin
            $display("FAIL: %0s", msg);
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
            timeout = 200;
            while (((active_mode !== expect_mode) ||
                    ((expect_mode == MODE_MAPPED) &&
                     (active_offset !== expect_offset)) ||
                    reconfig_busy) &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("mode switch timeout");
            end
            if (config_error) begin
                fail_now("unexpected config_error");
            end
        end
    endtask

    task issue_request;
        input                      write_value;
        input [ADDR_BITS-1:0]      addr_value;
        input [7:0]                total_size_value;
        input [LINE_BITS-1:0]      wdata_value;
        input [LINE_BYTES-1:0]     wstrb_value;
        input                      bypass_value;
        integer timeout;
        begin
            up_req_valid      <= 1'b1;
            up_req_write      <= write_value;
            up_req_addr       <= addr_value;
            up_req_id         <= {ID_BITS{1'b0}};
            up_req_total_size <= total_size_value;
            up_req_wdata      <= wdata_value;
            up_req_wstrb      <= wstrb_value;
            up_req_bypass     <= bypass_value;

            timeout = 100;
            while (!up_req_ready) begin
                @(posedge clk);
                timeout = timeout - 1;
                if (timeout == 0) begin
                    fail_now("upstream request handshake timeout");
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
                if (timeout > 200) begin
                    fail_now("upstream response timeout");
                end
            end
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
        input [8*96-1:0]       msg;
        begin
            issue_request(1'b0,
                          addr_value,
                          LINE_BYTES - 1,
                          {LINE_BITS{1'b0}},
                          {LINE_BYTES{1'b0}},
                          1'b0);
            wait_for_response(resp_line);
            if (resp_line !== expect_value) begin
                fail_now(msg);
            end
        end
    endtask

    task do_write_expect_zero;
        input [ADDR_BITS-1:0]      addr_value;
        input [LINE_BITS-1:0]      write_value;
        input [LINE_BYTES-1:0]     write_strb;
        input [8*96-1:0]           msg;
        begin
            issue_request(1'b1,
                          addr_value,
                          LINE_BYTES - 1,
                          write_value,
                          write_strb,
                          1'b0);
            wait_for_response(resp_line);
            if (resp_line !== {LINE_BITS{1'b0}}) begin
                fail_now(msg);
            end
        end
    endtask

    task do_invalidate_line;
        input [ADDR_BITS-1:0] addr_value;
        integer timeout;
        begin
            invalidate_line_addr  <= addr_value;
            invalidate_line_valid <= 1'b1;
            timeout = 100;
            while (!invalidate_line_accepted) begin
                @(posedge clk);
                timeout = timeout - 1;
                if (timeout == 0) begin
                    fail_now("invalidate_line handshake timeout");
                end
            end
            @(posedge clk);
            invalidate_line_valid <= 1'b0;
            invalidate_line_addr  <= {ADDR_BITS{1'b0}};
        end
    endtask

    task expect_counter_delta;
        input integer read_before;
        input integer write_before;
        input integer bypass_count_before;
        input integer read_delta;
        input integer write_delta;
        input integer bypass_delta;
        input [8*96-1:0] msg;
        begin
            if ((cache_read_count - read_before) != read_delta) begin
                fail_now(msg);
            end
            if ((cache_write_count - write_before) != write_delta) begin
                fail_now(msg);
            end
            if ((bypass_req_count - bypass_count_before) != bypass_delta) begin
                fail_now(msg);
            end
        end
    endtask

    always #5 clk = ~clk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cache_resp_valid          <= 1'b0;
            cache_resp_rdata          <= {LINE_BITS{1'b0}};
            cache_resp_id             <= {ID_BITS{1'b0}};
            cache_resp_pending_r      <= 1'b0;
            cache_resp_pending_data_r <= {LINE_BITS{1'b0}};
            cache_resp_pending_id_r   <= {ID_BITS{1'b0}};
            bypass_resp_valid         <= 1'b0;
            bypass_resp_rdata         <= {LINE_BITS{1'b0}};
            bypass_resp_id            <= {ID_BITS{1'b0}};
            bypass_resp_pending_r     <= 1'b0;
            bypass_resp_pending_data_r<= {LINE_BITS{1'b0}};
            bypass_resp_pending_id_r  <= {ID_BITS{1'b0}};
            cache_read_count          <= 0;
            cache_write_count         <= 0;
            bypass_req_count          <= 0;
        end else begin
            if (cache_resp_valid && cache_resp_ready) begin
                cache_resp_valid <= 1'b0;
                cache_resp_id <= {ID_BITS{1'b0}};
            end
            if (bypass_resp_valid && bypass_resp_ready) begin
                bypass_resp_valid <= 1'b0;
                bypass_resp_id <= {ID_BITS{1'b0}};
            end

            if (cache_resp_pending_r) begin
                cache_resp_valid          <= 1'b1;
                cache_resp_rdata          <= cache_resp_pending_data_r;
                cache_resp_id             <= cache_resp_pending_id_r;
                cache_resp_pending_r      <= 1'b0;
            end

            if (bypass_resp_pending_r) begin
                bypass_resp_valid          <= 1'b1;
                bypass_resp_rdata          <= bypass_resp_pending_data_r;
                bypass_resp_id             <= bypass_resp_pending_id_r;
                bypass_resp_pending_r      <= 1'b0;
            end

            if (cache_req_valid && cache_req_ready) begin
                if (cache_req_write) begin
                    mem_model[mem_index(cache_req_addr)] <= cache_req_wdata;
                    cache_write_count <= cache_write_count + 1;
                    cache_resp_pending_r <= 1'b1;
                    cache_resp_pending_data_r <= {LINE_BITS{1'b0}};
                    cache_resp_pending_id_r <= cache_req_id;
                end else begin
                    cache_read_count <= cache_read_count + 1;
                    cache_resp_pending_r <= 1'b1;
                    cache_resp_pending_data_r <= mem_model[mem_index(cache_req_addr)];
                    cache_resp_pending_id_r <= cache_req_id;
                end
            end

            if (bypass_req_valid && bypass_req_ready) begin
                bypass_req_count <= bypass_req_count + 1;
                if (bypass_req_write) begin
                    bypass_resp_pending_r <= 1'b1;
                    bypass_resp_pending_data_r <= {LINE_BITS{1'b0}};
                    bypass_resp_pending_id_r <= bypass_req_id;
                end else begin
                    bypass_resp_pending_r <= 1'b1;
                    bypass_resp_pending_data_r <= 64'hB000_0000_0000_0000 ^
                                                  {32'h0, bypass_req_addr};
                    bypass_resp_pending_id_r <= bypass_req_id;
                end
            end
        end
    end

    axi_llc_subsystem_top #(
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
        .WINDOW_WAYS      (WINDOW_WAYS)
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
        clk = 1'b0;
        rst_n = 1'b0;
        mode_req = MODE_OFF;
        llc_mapped_offset_req = {ADDR_BITS{1'b0}};
        up_req_valid = 1'b0;
        up_req_write = 1'b0;
        up_req_addr = {ADDR_BITS{1'b0}};
        up_req_id = {ID_BITS{1'b0}};
        up_req_total_size = 8'd0;
        up_req_wdata = {LINE_BITS{1'b0}};
        up_req_wstrb = {LINE_BYTES{1'b0}};
        up_req_bypass = 1'b0;
        up_resp_ready = 1'b1;
        cache_req_ready = 1'b1;
        bypass_req_ready = 1'b1;
        cache_resp_valid = 1'b0;
        cache_resp_rdata = {LINE_BITS{1'b0}};
        cache_resp_id = {ID_BITS{1'b0}};
        bypass_resp_valid = 1'b0;
        bypass_resp_rdata = {LINE_BITS{1'b0}};
        bypass_resp_id = {ID_BITS{1'b0}};
        invalidate_line_valid = 1'b0;
        invalidate_line_addr = {ADDR_BITS{1'b0}};
        invalidate_all_valid = 1'b0;

        clean_line_init = make_line(8'h10);
        dirty_line_init = make_line(8'h40);
        dirty_patch_line = make_line(8'hA0);
        dirty_patch_strb = 8'h0F;
        dirty_line_after_write = merge_line(dirty_line_init,
                                            dirty_patch_line,
                                            dirty_patch_strb);
        mapped_write_line = make_line(8'hD0);

        for (idx = 0; idx < MEM_DEPTH; idx = idx + 1) begin
            mem_model[idx] = make_line(idx[7:0]);
        end
        mem_model[mem_index(CACHE_ADDR_CLEAN)] = clean_line_init;
        mem_model[mem_index(CACHE_ADDR_DIRTY)] = dirty_line_init;

        wait_cycles(5);
        rst_n = 1'b1;
        wait_cycles(5);

        mode_req = MODE_CACHE;
        llc_mapped_offset_req = {ADDR_BITS{1'b0}};
        wait_mode_active(MODE_CACHE, {ADDR_BITS{1'b0}});

        reads_before = cache_read_count;
        writes_before = cache_write_count;
        bypass_before = bypass_req_count;
        do_read_expect(CACHE_ADDR_CLEAN,
                       clean_line_init,
                       "mode1 clean fill returned wrong line");
        expect_counter_delta(reads_before,
                             writes_before,
                             bypass_before,
                             1,
                             0,
                             0,
                             "mode1 clean fill should cause one read miss");

        reads_before = cache_read_count;
        writes_before = cache_write_count;
        bypass_before = bypass_req_count;
        do_read_expect(CACHE_ADDR_CLEAN,
                       clean_line_init,
                       "mode1 clean second read returned wrong line");
        expect_counter_delta(reads_before,
                             writes_before,
                             bypass_before,
                             0,
                             0,
                             0,
                             "mode1 clean second read should hit");

        reads_before = cache_read_count;
        writes_before = cache_write_count;
        bypass_before = bypass_req_count;
        do_invalidate_line(CACHE_ADDR_CLEAN);
        expect_counter_delta(reads_before,
                             writes_before,
                             bypass_before,
                             0,
                             0,
                             0,
                             "mode1 clean invalidate should not issue external traffic");

        reads_before = cache_read_count;
        writes_before = cache_write_count;
        bypass_before = bypass_req_count;
        do_read_expect(CACHE_ADDR_CLEAN,
                       clean_line_init,
                       "mode1 clean read after invalidate returned wrong line");
        expect_counter_delta(reads_before,
                             writes_before,
                             bypass_before,
                             1,
                             0,
                             0,
                             "mode1 clean read after invalidate should miss again");

        reads_before = cache_read_count;
        writes_before = cache_write_count;
        bypass_before = bypass_req_count;
        do_read_expect(CACHE_ADDR_DIRTY,
                       dirty_line_init,
                       "mode1 dirty fill returned wrong line");
        expect_counter_delta(reads_before,
                             writes_before,
                             bypass_before,
                             1,
                             0,
                             0,
                             "mode1 dirty fill should cause one read miss");

        reads_before = cache_read_count;
        writes_before = cache_write_count;
        bypass_before = bypass_req_count;
        do_write_expect_zero(CACHE_ADDR_DIRTY,
                             dirty_patch_line,
                             dirty_patch_strb,
                             "mode1 dirty write should return zero");
        expect_counter_delta(reads_before,
                             writes_before,
                             bypass_before,
                             0,
                             0,
                             0,
                             "mode1 dirty write hit should not issue external traffic");

        reads_before = cache_read_count;
        writes_before = cache_write_count;
        bypass_before = bypass_req_count;
        do_read_expect(CACHE_ADDR_DIRTY,
                       dirty_line_after_write,
                       "mode1 dirty readback before invalidate wrong");
        expect_counter_delta(reads_before,
                             writes_before,
                             bypass_before,
                             0,
                             0,
                             0,
                             "mode1 dirty readback before invalidate should hit");

        reads_before = cache_read_count;
        writes_before = cache_write_count;
        bypass_before = bypass_req_count;
        do_invalidate_line(CACHE_ADDR_DIRTY);
        expect_counter_delta(reads_before,
                             writes_before,
                             bypass_before,
                             0,
                             0,
                             0,
                             "mode1 dirty invalidate should not issue external traffic");

        reads_before = cache_read_count;
        writes_before = cache_write_count;
        bypass_before = bypass_req_count;
        do_read_expect(CACHE_ADDR_DIRTY,
                       dirty_line_init,
                       "mode1 dirty read after invalidate should refill backing line");
        expect_counter_delta(reads_before,
                             writes_before,
                             bypass_before,
                             1,
                             0,
                             0,
                             "mode1 dirty read after invalidate should miss again");

        mode_req = MODE_MAPPED;
        llc_mapped_offset_req = MAPPED_OFFSET;
        wait_mode_active(MODE_MAPPED, MAPPED_OFFSET);

        reads_before = cache_read_count;
        writes_before = cache_write_count;
        bypass_before = bypass_req_count;
        do_write_expect_zero(MAPPED_ADDR,
                             mapped_write_line,
                             {LINE_BYTES{1'b1}},
                             "mode2 write should return zero");
        expect_counter_delta(reads_before,
                             writes_before,
                             bypass_before,
                             0,
                             0,
                             0,
                             "mode2 in-window write should stay local");

        reads_before = cache_read_count;
        writes_before = cache_write_count;
        bypass_before = bypass_req_count;
        do_read_expect(MAPPED_ADDR,
                       mapped_write_line,
                       "mode2 readback before invalidate wrong");
        expect_counter_delta(reads_before,
                             writes_before,
                             bypass_before,
                             0,
                             0,
                             0,
                             "mode2 in-window read should stay local");

        reads_before = cache_read_count;
        writes_before = cache_write_count;
        bypass_before = bypass_req_count;
        do_invalidate_line(MAPPED_ADDR);
        expect_counter_delta(reads_before,
                             writes_before,
                             bypass_before,
                             0,
                             0,
                             0,
                             "mode2 invalidate should stay local");

        reads_before = cache_read_count;
        writes_before = cache_write_count;
        bypass_before = bypass_req_count;
        do_read_expect(MAPPED_ADDR,
                       mapped_write_line,
                       "mode2 read after invalidate should preserve direct-mapped data");
        expect_counter_delta(reads_before,
                             writes_before,
                             bypass_before,
                             0,
                             0,
                             0,
                             "mode2 read after invalidate should stay local");

        reads_before = cache_read_count;
        writes_before = cache_write_count;
        bypass_before = bypass_req_count;
        do_invalidate_line(MAPPED_ADDR_OUT);
        expect_counter_delta(reads_before,
                             writes_before,
                             bypass_before,
                             0,
                             0,
                             0,
                             "mode2 out-of-window invalidate should be no-op accept");

        mode_req = MODE_OFF;
        llc_mapped_offset_req = {ADDR_BITS{1'b0}};
        wait_mode_active(MODE_OFF, {ADDR_BITS{1'b0}});

        reads_before = cache_read_count;
        writes_before = cache_write_count;
        bypass_before = bypass_req_count;
        do_invalidate_line(CACHE_ADDR_CLEAN);
        expect_counter_delta(reads_before,
                             writes_before,
                             bypass_before,
                             0,
                             0,
                             0,
                             "mode0 invalidate should be no-op accept");

        $display("PASS");
        $finish(0);
    end

endmodule
