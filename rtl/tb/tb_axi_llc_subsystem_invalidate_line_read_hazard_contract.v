`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_invalidate_line_read_hazard_contract;

    localparam ADDR_BITS        = `AXI_LLC_ADDR_BITS;
    localparam ID_BITS          = `AXI_LLC_ID_BITS;
    localparam MODE_BITS        = `AXI_LLC_MODE_BITS;
    localparam LINE_BYTES       = 8;
    localparam LINE_BITS        = LINE_BYTES * 8;
    localparam LINE_OFFSET_BITS = 3;
    localparam SET_COUNT        = 2;
    localparam SET_BITS         = 1;
    localparam WAY_COUNT        = 1;
    localparam WAY_BITS         = 1;
    localparam META_BITS        = `AXI_LLC_META_BITS;
    localparam LLC_SIZE_BYTES   = LINE_BYTES * SET_COUNT * WAY_COUNT;
    localparam WINDOW_WAYS      = 1;
    localparam WINDOW_BYTES     = LINE_BYTES * SET_COUNT * WINDOW_WAYS;
    localparam TABLE_READ_LATENCY = 2;
    localparam READ_RESP_BYTES  = `AXI_LLC_READ_RESP_BYTES;
    localparam READ_RESP_BITS   = `AXI_LLC_READ_RESP_BITS;

    localparam [MODE_BITS-1:0] MODE_CACHE = 2'b01;
    localparam [ADDR_BITS-1:0] LOOKUP_ADDR = 32'h0000_0020;
    localparam [ADDR_BITS-1:0] VICTIM_ADDR = 32'h0000_0000;
    localparam [ADDR_BITS-1:0] MISS_ADDR   = 32'h0000_0010;
    localparam [ID_BITS-1:0]   LOOKUP_REQ_ID = 4'h1;
    localparam [ID_BITS-1:0]   FILL_REQ_ID   = 4'h2;
    localparam [ID_BITS-1:0]   WRITE_REQ_ID  = 4'h3;
    localparam [ID_BITS-1:0]   MISS_REQ_ID   = 4'h4;

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
    wire [READ_RESP_BITS-1:0] up_resp_rdata;
    wire [ID_BITS-1:0]        up_resp_id;
    wire [1:0]                up_resp_code;
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
    reg  [READ_RESP_BITS-1:0] cache_resp_rdata;
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
    reg  [READ_RESP_BITS-1:0] bypass_resp_rdata;
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

    reg  [LINE_BITS-1:0]      lookup_line;
    reg  [LINE_BITS-1:0]      victim_line;
    reg  [LINE_BITS-1:0]      miss_line;
    reg  [LINE_BITS-1:0]      write_patch_line;
    reg  [LINE_BITS-1:0]      victim_dirty_line;
    reg  [LINE_BITS-1:0]      observed_line;
    reg  [ID_BITS-1:0]        lower_req_id;
    reg  [LINE_BYTES-1:0]     write_patch_strb;

    always #5 clk = ~clk;

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
        input [LINE_BITS-1:0]  patch_line;
        input [LINE_BYTES-1:0] patch_strb;
        integer byte_idx;
        begin
            merge_line = base_line;
            for (byte_idx = 0; byte_idx < LINE_BYTES; byte_idx = byte_idx + 1) begin
                if (patch_strb[byte_idx]) begin
                    merge_line[(byte_idx * 8) +: 8] = patch_line[(byte_idx * 8) +: 8];
                end
            end
        end
    endfunction

    function [READ_RESP_BITS-1:0] pack_resp_line;
        input [LINE_BITS-1:0] line_value;
        begin
            pack_resp_line = {READ_RESP_BITS{1'b0}};
            pack_resp_line[LINE_BITS-1:0] = line_value;
        end
    endfunction

    function [ADDR_BITS-1:0] line_addr;
        input [ADDR_BITS-1:0] addr_value;
        begin
            line_addr = {addr_value[ADDR_BITS-1:LINE_OFFSET_BITS],
                         {LINE_OFFSET_BITS{1'b0}}};
        end
    endfunction

    task fail_now;
        input [8*160-1:0] msg;
        begin
            $display("tb_axi_llc_subsystem_invalidate_line_read_hazard_contract FAIL: %0s", msg);
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
        integer timeout;
        begin
            timeout = 200;
            while (((active_mode !== expect_mode) || reconfig_busy) &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("mode activation timeout");
            end
            if (config_error) begin
                fail_now("unexpected config_error");
            end
        end
    endtask

    task issue_request;
        input                      write_value;
        input [ADDR_BITS-1:0]      addr_value;
        input [ID_BITS-1:0]        req_id_value;
        input [LINE_BITS-1:0]      wdata_value;
        input [LINE_BYTES-1:0]     wstrb_value;
        integer timeout;
        begin
            up_req_valid      <= 1'b1;
            up_req_write      <= write_value;
            up_req_addr       <= addr_value;
            up_req_id         <= req_id_value;
            up_req_total_size <= LINE_BYTES - 1;
            up_req_wdata      <= wdata_value;
            up_req_wstrb      <= wstrb_value;
            up_req_bypass     <= 1'b0;

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

    task wait_cache_req;
        input                      expect_write;
        input [ADDR_BITS-1:0]      expect_addr;
        output [ID_BITS-1:0]       req_id_value;
        integer timeout;
        begin
            timeout = 100;
            while (!(cache_req_valid &&
                     cache_req_ready &&
                     (cache_req_write == expect_write) &&
                     (cache_req_addr == line_addr(expect_addr)))) begin
                @(posedge clk);
                timeout = timeout - 1;
                if (timeout == 0) begin
                    fail_now("cache request timeout");
                end
            end
            req_id_value = cache_req_id;
            @(posedge clk);
        end
    endtask

    task drive_cache_resp;
        input [ID_BITS-1:0]        resp_id_value;
        input [LINE_BITS-1:0]      line_value;
        integer timeout;
        begin
            cache_resp_valid <= 1'b1;
            cache_resp_id    <= resp_id_value;
            cache_resp_rdata <= pack_resp_line(line_value);
            timeout = 50;
            while (!cache_resp_ready) begin
                @(posedge clk);
                timeout = timeout - 1;
                if (timeout == 0) begin
                    fail_now("cache response handshake timeout");
                end
            end
            @(posedge clk);
            cache_resp_valid <= 1'b0;
            cache_resp_id    <= {ID_BITS{1'b0}};
            cache_resp_rdata <= {READ_RESP_BITS{1'b0}};
        end
    endtask

    task wait_read_response;
        input [ID_BITS-1:0]        expect_id;
        input [LINE_BITS-1:0]      expect_line;
        integer timeout;
        begin
            timeout = 200;
            while (!up_resp_valid) begin
                @(posedge clk);
                timeout = timeout - 1;
                if (timeout == 0) begin
                    fail_now("read response timeout");
                end
            end
            if (up_resp_id !== expect_id) begin
                fail_now("unexpected read response id");
            end
            if (up_resp_rdata[LINE_BITS-1:0] !== expect_line) begin
                fail_now("unexpected read response data");
            end
            @(posedge clk);
        end
    endtask

    task wait_write_response;
        input [ID_BITS-1:0] expect_id;
        integer timeout;
        begin
            timeout = 200;
            while (!up_resp_valid) begin
                @(posedge clk);
                timeout = timeout - 1;
                if (timeout == 0) begin
                    fail_now("write response timeout");
                end
            end
            if (up_resp_id !== expect_id) begin
                fail_now("unexpected write response id");
            end
            if (up_resp_code !== 2'b00) begin
                fail_now("unexpected write response code");
            end
            @(posedge clk);
        end
    endtask

    task hold_invalidate_blocked_until_cache_req;
        input                      expect_write;
        input [ADDR_BITS-1:0]      watch_addr;
        input [ADDR_BITS-1:0]      invalidate_addr_value;
        output [ID_BITS-1:0]       req_id_value;
        integer timeout;
        integer tail_cycles;
        begin
            invalidate_line_valid <= 1'b1;
            invalidate_line_addr  <= invalidate_addr_value;
            timeout = 100;
            while (!(cache_req_valid &&
                     cache_req_ready &&
                     (cache_req_write == expect_write) &&
                     (cache_req_addr == line_addr(watch_addr)))) begin
                @(posedge clk);
                if (invalidate_line_accepted) begin
                    fail_now("invalidate_line accepted while watched request still pending");
                end
                timeout = timeout - 1;
                if (timeout == 0) begin
                    fail_now("watched cache request timeout");
                end
            end
            req_id_value = cache_req_id;
            for (tail_cycles = 0; tail_cycles < 4; tail_cycles = tail_cycles + 1) begin
                @(posedge clk);
                if (invalidate_line_accepted) begin
                    fail_now("invalidate_line accepted before read-side hazard retired");
                end
            end
            invalidate_line_valid <= 1'b0;
            invalidate_line_addr  <= {ADDR_BITS{1'b0}};
            @(posedge clk);
        end
    endtask

    task do_invalidate_accept;
        input [ADDR_BITS-1:0] invalidate_addr_value;
        integer timeout;
        begin
            invalidate_line_valid <= 1'b1;
            invalidate_line_addr  <= invalidate_addr_value;
            timeout = 100;
            while (!invalidate_line_accepted) begin
                @(posedge clk);
                timeout = timeout - 1;
                if (timeout == 0) begin
                    fail_now("invalidate_line did not get accepted");
                end
            end
            @(posedge clk);
            invalidate_line_valid <= 1'b0;
            invalidate_line_addr  <= {ADDR_BITS{1'b0}};
        end
    endtask

    axi_llc_subsystem_core #(
        .ADDR_BITS          (ADDR_BITS),
        .ID_BITS            (ID_BITS),
        .MODE_BITS          (MODE_BITS),
        .LINE_BYTES         (LINE_BYTES),
        .LINE_BITS          (LINE_BITS),
        .LINE_OFFSET_BITS   (LINE_OFFSET_BITS),
        .SET_COUNT          (SET_COUNT),
        .SET_BITS           (SET_BITS),
        .WAY_COUNT          (WAY_COUNT),
        .WAY_BITS           (WAY_BITS),
        .META_BITS          (META_BITS),
        .LLC_SIZE_BYTES     (LLC_SIZE_BYTES),
        .WINDOW_BYTES       (WINDOW_BYTES),
        .WINDOW_WAYS        (WINDOW_WAYS),
        .RESET_MODE         (MODE_CACHE),
        .TABLE_READ_LATENCY (TABLE_READ_LATENCY),
        .READ_RESP_BYTES    (READ_RESP_BYTES),
        .READ_RESP_BITS     (READ_RESP_BITS)
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
        .up_resp_code          (up_resp_code),
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
        mode_req = MODE_CACHE;
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
        cache_resp_valid = 1'b0;
        cache_resp_rdata = {READ_RESP_BITS{1'b0}};
        cache_resp_id = {ID_BITS{1'b0}};
        bypass_req_ready = 1'b1;
        bypass_resp_valid = 1'b0;
        bypass_resp_rdata = {READ_RESP_BITS{1'b0}};
        bypass_resp_id = {ID_BITS{1'b0}};
        invalidate_line_valid = 1'b0;
        invalidate_line_addr = {ADDR_BITS{1'b0}};
        invalidate_all_valid = 1'b0;

        lookup_line = make_line(8'h20);
        victim_line = make_line(8'h40);
        miss_line = make_line(8'h60);
        write_patch_line = make_line(8'hA0);
        write_patch_strb = 8'h0F;
        victim_dirty_line = merge_line(victim_line, write_patch_line,
                                       write_patch_strb);
        observed_line = {LINE_BITS{1'b0}};
        lower_req_id = {ID_BITS{1'b0}};

        wait_cycles(5);
        rst_n = 1'b1;
        wait_cycles(5);
        wait_mode_active(MODE_CACHE);

        // Scenario 1: invalidate_line must stay blocked from lookup through the
        // full lifetime of a same-line read miss/refill.
        issue_request(1'b0, LOOKUP_ADDR, LOOKUP_REQ_ID,
                      {LINE_BITS{1'b0}}, {LINE_BYTES{1'b0}});
        hold_invalidate_blocked_until_cache_req(1'b0, LOOKUP_ADDR,
                                                LOOKUP_ADDR, lower_req_id);
        drive_cache_resp(lower_req_id, lookup_line);
        wait_read_response(LOOKUP_REQ_ID, lookup_line);
        do_invalidate_accept(LOOKUP_ADDR);

        // Fill one line, then dirty it with a write hit.
        issue_request(1'b0, VICTIM_ADDR, FILL_REQ_ID,
                      {LINE_BITS{1'b0}}, {LINE_BYTES{1'b0}});
        wait_cache_req(1'b0, VICTIM_ADDR, lower_req_id);
        drive_cache_resp(lower_req_id, victim_line);
        wait_read_response(FILL_REQ_ID, victim_line);

        issue_request(1'b1, VICTIM_ADDR + 32'h4, WRITE_REQ_ID,
                      write_patch_line, write_patch_strb);
        wait_write_response(WRITE_REQ_ID);

        // Scenario 2: same-line invalidate must stay blocked while a pending
        // read miss still owns the dirty victim line for writeback.
        issue_request(1'b0, MISS_ADDR, MISS_REQ_ID,
                      {LINE_BITS{1'b0}}, {LINE_BYTES{1'b0}});
        hold_invalidate_blocked_until_cache_req(1'b1, VICTIM_ADDR,
                                                VICTIM_ADDR, lower_req_id);
        drive_cache_resp(lower_req_id, {LINE_BITS{1'b0}});
        wait_cache_req(1'b0, MISS_ADDR, lower_req_id);
        drive_cache_resp(lower_req_id, miss_line);
        wait_read_response(MISS_REQ_ID, miss_line);
        do_invalidate_accept(VICTIM_ADDR);

        if (bypass_req_valid) begin
            fail_now("unexpected bypass activity");
        end

        $display("tb_axi_llc_subsystem_invalidate_line_read_hazard_contract PASS");
        $finish(0);
    end

endmodule
