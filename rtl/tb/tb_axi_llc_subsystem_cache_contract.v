`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_cache_contract;

    localparam ADDR_BITS        = `AXI_LLC_ADDR_BITS;
    localparam MODE_BITS        = `AXI_LLC_MODE_BITS;
    localparam LINE_BYTES       = `AXI_LLC_LINE_BYTES;
    localparam LINE_BITS        = `AXI_LLC_LINE_BITS;
    localparam LINE_OFFSET_BITS = `AXI_LLC_LINE_OFFSET_BITS;
    localparam SET_COUNT        = 2;
    localparam SET_BITS         = 1;
    localparam WAY_COUNT        = 2;
    localparam WAY_BITS         = 1;
    localparam META_BITS        = `AXI_LLC_META_BITS;
    localparam WINDOW_BYTES     = LINE_BYTES * SET_COUNT;
    localparam WINDOW_WAYS      = 1;
    localparam MEM_DEPTH        = 8;
    localparam [MODE_BITS-1:0] MODE_CACHE = 2'b01;

    localparam [ADDR_BITS-1:0] ADDR_A = 32'h0000_0000;
    localparam [ADDR_BITS-1:0] ADDR_B = 32'h0000_0080;
    localparam [ADDR_BITS-1:0] ADDR_C = 32'h0000_0100;
    localparam [ADDR_BITS-1:0] ADDR_E = 32'h0000_0040;

    reg                       clk;
    reg                       rst_n;
    reg  [MODE_BITS-1:0]      mode_req;
    reg  [ADDR_BITS-1:0]      llc_mapped_offset_req;
    reg                       up_req_valid;
    wire                      up_req_ready;
    reg                       up_req_write;
    reg  [ADDR_BITS-1:0]      up_req_addr;
    reg  [7:0]                up_req_total_size;
    reg  [LINE_BITS-1:0]      up_req_wdata;
    reg  [LINE_BYTES-1:0]     up_req_wstrb;
    reg                       up_req_bypass;
    wire                      up_resp_valid;
    reg                       up_resp_ready;
    wire [LINE_BITS-1:0]      up_resp_rdata;
    wire                      cache_req_valid;
    reg                       cache_req_ready;
    wire                      cache_req_write;
    wire [ADDR_BITS-1:0]      cache_req_addr;
    wire [7:0]                cache_req_size;
    wire [LINE_BITS-1:0]      cache_req_wdata;
    wire [LINE_BYTES-1:0]     cache_req_wstrb;
    reg                       cache_resp_valid;
    wire                      cache_resp_ready;
    reg  [LINE_BITS-1:0]      cache_resp_rdata;
    wire                      bypass_req_valid;
    reg                       bypass_req_ready;
    wire                      bypass_req_write;
    wire [ADDR_BITS-1:0]      bypass_req_addr;
    wire [7:0]                bypass_req_size;
    wire [LINE_BITS-1:0]      bypass_req_wdata;
    wire [LINE_BYTES-1:0]     bypass_req_wstrb;
    reg                       bypass_resp_valid;
    wire                      bypass_resp_ready;
    reg  [LINE_BITS-1:0]      bypass_resp_rdata;
    wire [MODE_BITS-1:0]      active_mode;
    wire [ADDR_BITS-1:0]      active_offset;
    wire                      reconfig_busy;
    wire [1:0]                reconfig_state;
    wire                      config_error;
    reg                       invalidate_line_valid;
    reg  [ADDR_BITS-1:0]      invalidate_line_addr;
    wire                      invalidate_line_accepted;
    reg                       invalidate_all_valid;
    wire                      invalidate_all_accepted;

    reg  [LINE_BITS-1:0]      mem_model [0:MEM_DEPTH-1];
    reg                       mem_resp_pending_r;
    reg  [LINE_BITS-1:0]      mem_resp_pending_data_r;

    reg                       req_log_write [0:31];
    reg  [ADDR_BITS-1:0]      req_log_addr [0:31];
    reg  [LINE_BITS-1:0]      req_log_wdata [0:31];
    integer                   req_log_count;
    integer                   mem_read_count;
    integer                   mem_write_count;
    integer                   idx;

    reg  [LINE_BITS-1:0]      line_a_init;
    reg  [LINE_BITS-1:0]      line_a_after_hit_write;
    reg  [LINE_BITS-1:0]      line_b_write;
    reg  [LINE_BITS-1:0]      line_c_init;
    reg  [LINE_BITS-1:0]      line_e_init;
    reg  [LINE_BITS-1:0]      line_e_write_patch;
    reg  [LINE_BITS-1:0]      line_e_after_partial_miss;
    reg  [LINE_BITS-1:0]      line_tmp;
    reg  [LINE_BYTES-1:0]     strb_hit;
    reg  [LINE_BYTES-1:0]     strb_partial_miss;
    integer                   log_base;
    integer                   read_base;
    integer                   write_base;
    integer                   step_id;

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

    function integer line_index;
        input [ADDR_BITS-1:0] addr_value;
        begin
            line_index = addr_value[LINE_OFFSET_BITS + 2:LINE_OFFSET_BITS];
        end
    endfunction

    task fail;
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

    task wait_mode_cache_active;
        integer timeout;
        begin
            timeout = 100;
            while (((active_mode != MODE_CACHE) || reconfig_busy) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail("mode=1 activate timeout");
            end
        end
    endtask

    task issue_request;
        input                      write_value;
        input [ADDR_BITS-1:0]      addr_value;
        input [7:0]                total_size_value;
        input [LINE_BITS-1:0]      wdata_value;
        input [LINE_BYTES-1:0]     wstrb_value;
        integer timeout;
        begin
            up_req_write  = write_value;
            up_req_addr   = addr_value;
            up_req_total_size = total_size_value;
            up_req_wdata  = wdata_value;
            up_req_wstrb  = wstrb_value;
            up_req_bypass = 1'b0;
            up_req_valid  = 1'b1;
            timeout = 100;
            while (timeout > 0) begin
                @(posedge clk);
                if (up_req_valid && up_req_ready) begin
                    timeout = 0;
                end else begin
                    timeout = timeout - 1;
                end
            end
            if (!(up_req_valid && up_req_ready)) begin
                fail("upstream request handshake timeout");
            end
            @(negedge clk);
            up_req_valid = 1'b0;
            up_req_write = 1'b0;
            up_req_addr  = {ADDR_BITS{1'b0}};
            up_req_total_size = 8'd0;
            up_req_wdata = {LINE_BITS{1'b0}};
            up_req_wstrb = {LINE_BYTES{1'b0}};
        end
    endtask

    task wait_for_response;
        output [LINE_BITS-1:0] resp_data;
        integer timeout;
        begin
            timeout = 100;
            while (!up_resp_valid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                $display("step_id=%0d req_log_count=%0d mem_reads=%0d mem_writes=%0d",
                         step_id, req_log_count, mem_read_count, mem_write_count);
                fail("upstream response timeout");
            end
            #1;
            resp_data = up_resp_rdata;
            @(posedge clk);
        end
    endtask

    task expect_read_response;
        input [LINE_BITS-1:0] expected;
        input [8*96-1:0]      msg;
        begin
            wait_for_response(line_tmp);
            if (line_tmp !== expected) begin
                fail(msg);
            end
        end
    endtask

    task expect_write_response_zero;
        input [8*96-1:0] msg;
        begin
            wait_for_response(line_tmp);
            if (line_tmp !== {LINE_BITS{1'b0}}) begin
                fail(msg);
            end
        end
    endtask

    always #5 clk = ~clk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cache_resp_valid <= 1'b0;
            cache_resp_rdata <= {LINE_BITS{1'b0}};
            mem_resp_pending_r <= 1'b0;
            mem_resp_pending_data_r <= {LINE_BITS{1'b0}};
            req_log_count <= 0;
            mem_read_count <= 0;
            mem_write_count <= 0;
        end else begin
            if (cache_resp_valid && cache_resp_ready) begin
                cache_resp_valid <= 1'b0;
            end

            if (mem_resp_pending_r) begin
                cache_resp_valid <= 1'b1;
                cache_resp_rdata <= mem_resp_pending_data_r;
                mem_resp_pending_r <= 1'b0;
            end

            if (cache_req_valid && cache_req_ready) begin
                req_log_write[req_log_count] <= cache_req_write;
                req_log_addr[req_log_count] <= cache_req_addr;
                req_log_wdata[req_log_count] <= cache_req_wdata;
                req_log_count <= req_log_count + 1;

                if (cache_req_write) begin
                    mem_model[line_index(cache_req_addr)] <= cache_req_wdata;
                    mem_write_count <= mem_write_count + 1;
                    mem_resp_pending_data_r <= {LINE_BITS{1'b0}};
                end else begin
                    mem_read_count <= mem_read_count + 1;
                    mem_resp_pending_data_r <= mem_model[line_index(cache_req_addr)];
                end
                mem_resp_pending_r <= 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        if (rst_n && bypass_req_valid) begin
            fail("mode=1 cache bench observed unexpected bypass request");
        end
    end

    axi_llc_subsystem_top #(
        .ADDR_BITS        (ADDR_BITS),
        .MODE_BITS        (MODE_BITS),
        .LINE_BYTES       (LINE_BYTES),
        .LINE_BITS        (LINE_BITS),
        .LINE_OFFSET_BITS (LINE_OFFSET_BITS),
        .SET_COUNT        (SET_COUNT),
        .SET_BITS         (SET_BITS),
        .WAY_COUNT        (WAY_COUNT),
        .WAY_BITS         (WAY_BITS),
        .META_BITS        (META_BITS),
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
        .up_req_total_size     (up_req_total_size),
        .up_req_wdata          (up_req_wdata),
        .up_req_wstrb          (up_req_wstrb),
        .up_req_bypass         (up_req_bypass),
        .up_resp_valid         (up_resp_valid),
        .up_resp_ready         (up_resp_ready),
        .up_resp_rdata         (up_resp_rdata),
        .cache_req_valid       (cache_req_valid),
        .cache_req_ready       (cache_req_ready),
        .cache_req_write       (cache_req_write),
        .cache_req_addr        (cache_req_addr),
        .cache_req_size        (cache_req_size),
        .cache_req_wdata       (cache_req_wdata),
        .cache_req_wstrb       (cache_req_wstrb),
        .cache_resp_valid      (cache_resp_valid),
        .cache_resp_ready      (cache_resp_ready),
        .cache_resp_rdata      (cache_resp_rdata),
        .bypass_req_valid      (bypass_req_valid),
        .bypass_req_ready      (bypass_req_ready),
        .bypass_req_write      (bypass_req_write),
        .bypass_req_addr       (bypass_req_addr),
        .bypass_req_size       (bypass_req_size),
        .bypass_req_wdata      (bypass_req_wdata),
        .bypass_req_wstrb      (bypass_req_wstrb),
        .bypass_resp_valid     (bypass_resp_valid),
        .bypass_resp_ready     (bypass_resp_ready),
        .bypass_resp_rdata     (bypass_resp_rdata),
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
        up_req_total_size = 8'd0;
        up_req_wdata = {LINE_BITS{1'b0}};
        up_req_wstrb = {LINE_BYTES{1'b0}};
        up_req_bypass = 1'b0;
        invalidate_line_valid = 1'b0;
        invalidate_line_addr = {ADDR_BITS{1'b0}};
        invalidate_all_valid = 1'b0;
        up_resp_ready = 1'b1;
        cache_req_ready = 1'b1;
        cache_resp_valid = 1'b0;
        cache_resp_rdata = {LINE_BITS{1'b0}};
        bypass_req_ready = 1'b1;
        bypass_resp_valid = 1'b0;
        bypass_resp_rdata = {LINE_BITS{1'b0}};
        mem_resp_pending_r = 1'b0;
        mem_resp_pending_data_r = {LINE_BITS{1'b0}};
        req_log_count = 0;
        mem_read_count = 0;
        mem_write_count = 0;
        step_id = 0;
        strb_hit = 64'h0000_0000_0000_00FF;
        strb_partial_miss = 64'h0000_0000_00F0_000F;

        for (idx = 0; idx < MEM_DEPTH; idx = idx + 1) begin
            mem_model[idx] = {LINE_BITS{1'b0}};
        end

        line_a_init = make_line(8'h10);
        line_b_write = make_line(8'h80);
        line_c_init = make_line(8'h40);
        line_e_init = make_line(8'h60);
        line_e_write_patch = make_line(8'hC0);
        line_a_after_hit_write = merge_line(line_a_init, make_line(8'hA0), strb_hit);
        line_e_after_partial_miss = merge_line(line_e_init, line_e_write_patch,
                                               strb_partial_miss);

        mem_model[line_index(ADDR_A)] = line_a_init;
        mem_model[line_index(ADDR_C)] = line_c_init;
        mem_model[line_index(ADDR_E)] = line_e_init;

        wait_cycles(4);
        rst_n = 1'b1;

        wait_mode_cache_active();
        if (config_error) begin
            fail("unexpected config_error in mode=1");
        end

        step_id = 1;
        $display("STEP 1 read miss refill");
        log_base = req_log_count;
        read_base = mem_read_count;
        write_base = mem_write_count;
        issue_request(1'b0, ADDR_A, LINE_BYTES-1, {LINE_BITS{1'b0}}, {LINE_BYTES{1'b0}});
        expect_read_response(line_a_init, "read miss refill response mismatch");
        if (req_log_count != (log_base + 1)) begin
            fail("read miss should emit exactly one external request");
        end
        if (req_log_write[log_base] !== 1'b0) begin
            fail("read miss should emit external read");
        end
        if (req_log_addr[log_base] !== ADDR_A) begin
            fail("read miss external read address mismatch");
        end
        if (mem_read_count != (read_base + 1)) begin
            fail("read miss should increment external read count");
        end
        if (mem_write_count != write_base) begin
            fail("read miss should not emit external write");
        end

        step_id = 2;
        $display("STEP 2 second read hit");
        log_base = req_log_count;
        read_base = mem_read_count;
        write_base = mem_write_count;
        issue_request(1'b0, ADDR_A, LINE_BYTES-1, {LINE_BITS{1'b0}}, {LINE_BYTES{1'b0}});
        expect_read_response(line_a_init, "second read hit response mismatch");
        if (req_log_count != log_base) begin
            fail("second read hit should not emit external request");
        end
        if ((mem_read_count != read_base) || (mem_write_count != write_base)) begin
            fail("second read hit changed external traffic counters");
        end

        step_id = 3;
        $display("STEP 3 write hit update");
        log_base = req_log_count;
        read_base = mem_read_count;
        write_base = mem_write_count;
        issue_request(1'b1, ADDR_A, LINE_BYTES-1, make_line(8'hA0), strb_hit);
        expect_write_response_zero("write hit response should be zero");
        if (req_log_count != log_base) begin
            fail("write hit should not emit external request");
        end
        if ((mem_read_count != read_base) || (mem_write_count != write_base)) begin
            fail("write hit changed external traffic counters");
        end

        step_id = 4;
        $display("STEP 4 read back write-hit data");
        log_base = req_log_count;
        issue_request(1'b0, ADDR_A, LINE_BYTES-1, {LINE_BITS{1'b0}}, {LINE_BYTES{1'b0}});
        expect_read_response(line_a_after_hit_write, "write hit data not resident");
        if (req_log_count != log_base) begin
            fail("post write-hit read should stay resident");
        end

        step_id = 5;
        $display("STEP 5 full-line write miss install");
        log_base = req_log_count;
        read_base = mem_read_count;
        write_base = mem_write_count;
        issue_request(1'b1, ADDR_B, LINE_BYTES-1, line_b_write, {LINE_BYTES{1'b1}});
        expect_write_response_zero("full-line write miss response should be zero");
        if (req_log_count != log_base) begin
            fail("full-line write miss should install without external refill");
        end
        if ((mem_read_count != read_base) || (mem_write_count != write_base)) begin
            fail("full-line write miss changed external traffic counters");
        end

        step_id = 6;
        $display("STEP 6 read back full-line write miss");
        log_base = req_log_count;
        issue_request(1'b0, ADDR_B, LINE_BYTES-1, {LINE_BITS{1'b0}}, {LINE_BYTES{1'b0}});
        expect_read_response(line_b_write, "full-line write miss line not resident");
        if (req_log_count != log_base) begin
            fail("read after full-line write miss should be resident");
        end

        step_id = 7;
        $display("STEP 7 partial write miss refill+merge");
        log_base = req_log_count;
        read_base = mem_read_count;
        write_base = mem_write_count;
        issue_request(1'b1, ADDR_E, 8'd3, line_e_write_patch, strb_partial_miss);
        expect_write_response_zero("partial write miss response should be zero");
        if (req_log_count != (log_base + 1)) begin
            fail("partial write miss should emit exactly one refill read");
        end
        if (req_log_write[log_base] !== 1'b0) begin
            fail("partial write miss should emit external read");
        end
        if (req_log_addr[log_base] !== ADDR_E) begin
            fail("partial write miss refill address mismatch");
        end
        if (mem_read_count != (read_base + 1)) begin
            fail("partial write miss should increment external read count");
        end
        if (mem_write_count != write_base) begin
            fail("partial write miss should not emit external write");
        end

        step_id = 8;
        $display("STEP 8 read back partial write miss");
        log_base = req_log_count;
        issue_request(1'b0, ADDR_E, LINE_BYTES-1, {LINE_BITS{1'b0}}, {LINE_BYTES{1'b0}});
        expect_read_response(line_e_after_partial_miss,
                             "partial write miss merged data mismatch");
        if (req_log_count != log_base) begin
            fail("post partial write miss read should stay resident");
        end

        step_id = 9;
        $display("STEP 9 dirty victim writeback + refill");
        log_base = req_log_count;
        read_base = mem_read_count;
        write_base = mem_write_count;
        issue_request(1'b0, ADDR_C, LINE_BYTES-1, {LINE_BITS{1'b0}}, {LINE_BYTES{1'b0}});
        expect_read_response(line_c_init, "dirty victim refill response mismatch");
        if (req_log_count != (log_base + 2)) begin
            fail("dirty victim path should emit writeback then refill");
        end
        if (req_log_write[log_base] !== 1'b1) begin
            fail("dirty victim first external request should be writeback");
        end
        if (req_log_addr[log_base] !== ADDR_A) begin
            fail("dirty victim writeback address mismatch");
        end
        if (req_log_wdata[log_base] !== line_a_after_hit_write) begin
            fail("dirty victim writeback data mismatch");
        end
        if (req_log_write[log_base + 1] !== 1'b0) begin
            fail("dirty victim second external request should be refill read");
        end
        if (req_log_addr[log_base + 1] !== ADDR_C) begin
            fail("dirty victim refill address mismatch");
        end
        if (mem_write_count != (write_base + 1)) begin
            fail("dirty victim should increment external write count");
        end
        if (mem_read_count != (read_base + 1)) begin
            fail("dirty victim should increment external read count");
        end
        if (mem_model[line_index(ADDR_A)] !== line_a_after_hit_write) begin
            fail("dirty victim writeback did not update backing memory");
        end

        $display("PASS");
        $finish;
    end

endmodule
