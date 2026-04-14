`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_compat_bypass_pending_issue_contract;

    localparam ADDR_BITS         = `AXI_LLC_ADDR_BITS;
    localparam ID_BITS           = `AXI_LLC_ID_BITS;
    localparam MODE_BITS         = `AXI_LLC_MODE_BITS;
    localparam LINE_BYTES        = 8;
    localparam LINE_BITS         = 64;
    localparam LINE_OFFSET_BITS  = 3;
    localparam SET_COUNT         = 4;
    localparam SET_BITS          = 2;
    localparam WAY_COUNT         = 4;
    localparam WAY_BITS          = 2;
    localparam META_BITS         = `AXI_LLC_META_BITS;
    localparam LLC_SIZE_BYTES    = LINE_BYTES * SET_COUNT * WAY_COUNT;
    localparam WINDOW_BYTES      = LINE_BYTES * SET_COUNT;
    localparam WINDOW_WAYS       = 2;
    localparam NUM_READ_MASTERS  = 2;
    localparam NUM_WRITE_MASTERS = 1;
    localparam READ_RESP_BITS    = `AXI_LLC_READ_RESP_BITS;

    localparam [MODE_BITS-1:0] MODE_CACHE = 2'b01;
    localparam [1:0] RESP_OKAY = 2'b00;
    localparam integer CACHE_MASTER = 0;
    localparam integer BYPASS_READ_MASTER = 1;
    localparam integer BYPASS_WRITE_MASTER = 0;

    localparam [ADDR_BITS-1:0] BYPASS_READ_ADDR = 32'h1000_0000;
    localparam [ADDR_BITS-1:0] CACHE_ADDR0 = 32'h0000_0040;
    localparam [ADDR_BITS-1:0] WRITE_THROUGH_ADDR = 32'h0000_0080;
    localparam [ADDR_BITS-1:0] CACHE_ADDR1 = 32'h0000_00C0;

    localparam [ID_BITS-1:0] BYPASS_READ_ID = 4'h3;
    localparam [ID_BITS-1:0] CACHE_READ_ID0 = 4'h5;
    localparam [ID_BITS-1:0] INSTALL_READ_ID = 4'h7;
    localparam [ID_BITS-1:0] BYPASS_WRITE_ID = 4'h9;
    localparam [ID_BITS-1:0] CACHE_READ_ID1 = 4'hB;

    reg                                   clk;
    reg                                   rst_n;
    reg  [MODE_BITS-1:0]                  mode_req;
    reg  [ADDR_BITS-1:0]                  llc_mapped_offset_req;
    reg  [NUM_READ_MASTERS-1:0]           read_req_valid;
    wire [NUM_READ_MASTERS-1:0]           read_req_ready;
    wire [NUM_READ_MASTERS-1:0]           read_req_accepted;
    wire [NUM_READ_MASTERS*ID_BITS-1:0]   read_req_accepted_id;
    reg  [NUM_READ_MASTERS*ADDR_BITS-1:0] read_req_addr;
    reg  [NUM_READ_MASTERS*8-1:0]         read_req_total_size;
    reg  [NUM_READ_MASTERS*ID_BITS-1:0]   read_req_id;
    reg  [NUM_READ_MASTERS-1:0]           read_req_bypass;
    wire [NUM_READ_MASTERS-1:0]           read_resp_valid;
    reg  [NUM_READ_MASTERS-1:0]           read_resp_ready;
    wire [NUM_READ_MASTERS*READ_RESP_BITS-1:0] read_resp_data;
    wire [NUM_READ_MASTERS*ID_BITS-1:0]   read_resp_id;
    reg  [NUM_WRITE_MASTERS-1:0]          write_req_valid;
    wire [NUM_WRITE_MASTERS-1:0]          write_req_ready;
    wire [NUM_WRITE_MASTERS-1:0]          write_req_accepted;
    reg  [NUM_WRITE_MASTERS*ADDR_BITS-1:0] write_req_addr;
    reg  [NUM_WRITE_MASTERS*LINE_BITS-1:0] write_req_wdata;
    reg  [NUM_WRITE_MASTERS*LINE_BYTES-1:0] write_req_wstrb;
    reg  [NUM_WRITE_MASTERS*8-1:0]        write_req_total_size;
    reg  [NUM_WRITE_MASTERS*ID_BITS-1:0]  write_req_id;
    reg  [NUM_WRITE_MASTERS-1:0]          write_req_bypass;
    wire [NUM_WRITE_MASTERS-1:0]          write_resp_valid;
    reg  [NUM_WRITE_MASTERS-1:0]          write_resp_ready;
    wire [NUM_WRITE_MASTERS*ID_BITS-1:0]  write_resp_id;
    wire [NUM_WRITE_MASTERS*2-1:0]        write_resp_code;
    wire                                  cache_req_valid;
    reg                                   cache_req_ready;
    wire                                  cache_req_write;
    wire [ADDR_BITS-1:0]                  cache_req_addr;
    wire [ID_BITS-1:0]                    cache_req_id;
    wire [7:0]                            cache_req_size;
    wire [LINE_BITS-1:0]                  cache_req_wdata;
    wire [LINE_BYTES-1:0]                 cache_req_wstrb;
    reg                                   cache_resp_valid;
    wire                                  cache_resp_ready;
    reg  [READ_RESP_BITS-1:0]             cache_resp_rdata;
    reg  [ID_BITS-1:0]                    cache_resp_id;
    reg  [1:0]                            cache_resp_code;
    wire                                  bypass_req_valid;
    reg                                   bypass_req_ready;
    wire                                  bypass_req_write;
    wire [ADDR_BITS-1:0]                  bypass_req_addr;
    wire [ID_BITS-1:0]                    bypass_req_id;
    wire [7:0]                            bypass_req_size;
    wire                                  bypass_req_mode2_ddr_aligned;
    wire [LINE_BITS-1:0]                  bypass_req_wdata;
    wire [LINE_BYTES-1:0]                 bypass_req_wstrb;
    reg                                   bypass_resp_valid;
    wire                                  bypass_resp_ready;
    reg  [READ_RESP_BITS-1:0]             bypass_resp_rdata;
    reg  [ID_BITS-1:0]                    bypass_resp_id;
    reg  [1:0]                            bypass_resp_code;
    reg                                   invalidate_line_valid;
    reg  [ADDR_BITS-1:0]                  invalidate_line_addr;
    wire                                  invalidate_line_accepted;
    reg                                   invalidate_all_valid;
    wire                                  invalidate_all_accepted;
    wire [MODE_BITS-1:0]                  active_mode;
    wire [ADDR_BITS-1:0]                  active_offset;
    wire                                  reconfig_busy;
    wire [1:0]                            reconfig_state;
    wire                                  config_error;

    integer                               timeout;
    reg  [ID_BITS-1:0]                    observed_cache_req_id;
    reg  [ID_BITS-1:0]                    observed_bypass_req_id;

    function [READ_RESP_BITS-1:0] pack_line;
        input [LINE_BITS-1:0] line_value;
        begin
            pack_line = {READ_RESP_BITS{1'b0}};
            pack_line[LINE_BITS-1:0] = line_value;
        end
    endfunction

    function [ID_BITS-1:0] get_read_resp_id;
        input integer master;
        begin
            get_read_resp_id = read_resp_id[(master * ID_BITS) +: ID_BITS];
        end
    endfunction

    task fail_now;
        input [8*160-1:0] msg;
        begin
            $display("tb_axi_llc_subsystem_compat_bypass_pending_issue_contract FAIL: %0s", msg);
            $finish(1);
        end
    endtask

    task wait_cycles;
        input integer cycles;
        integer idx;
        begin
            for (idx = 0; idx < cycles; idx = idx + 1) begin
                @(posedge clk);
            end
        end
    endtask

    task clear_inputs;
        begin
            read_req_valid = {NUM_READ_MASTERS{1'b0}};
            read_req_addr = {(NUM_READ_MASTERS*ADDR_BITS){1'b0}};
            read_req_total_size = {(NUM_READ_MASTERS*8){1'b0}};
            read_req_id = {(NUM_READ_MASTERS*ID_BITS){1'b0}};
            read_req_bypass = {NUM_READ_MASTERS{1'b0}};
            write_req_valid = {NUM_WRITE_MASTERS{1'b0}};
            write_req_addr = {(NUM_WRITE_MASTERS*ADDR_BITS){1'b0}};
            write_req_wdata = {(NUM_WRITE_MASTERS*LINE_BITS){1'b0}};
            write_req_wstrb = {(NUM_WRITE_MASTERS*LINE_BYTES){1'b0}};
            write_req_total_size = {(NUM_WRITE_MASTERS*8){1'b0}};
            write_req_id = {(NUM_WRITE_MASTERS*ID_BITS){1'b0}};
            write_req_bypass = {NUM_WRITE_MASTERS{1'b0}};
        end
    endtask

    task wait_active_cache;
        begin
            timeout = 200;
            while (((active_mode !== MODE_CACHE) || reconfig_busy) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("mode1 should become active");
            end
        end
    endtask

    task issue_read_expect_accept;
        input integer master;
        input [ADDR_BITS-1:0] addr_value;
        input [ID_BITS-1:0] id_value;
        input bypass_value;
        input [7:0] size_value;
        begin
            @(negedge clk);
            read_req_valid[master] = 1'b1;
            read_req_addr[(master * ADDR_BITS) +: ADDR_BITS] = addr_value;
            read_req_total_size[(master * 8) +: 8] = size_value;
            read_req_id[(master * ID_BITS) +: ID_BITS] = id_value;
            read_req_bypass[master] = bypass_value;
            timeout = 200;
            while ((read_req_accepted[master] !== 1'b1) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting read accepted");
            end
            @(negedge clk);
            read_req_valid[master] = 1'b0;
        end
    endtask

    task issue_write_expect_accept;
        input integer master;
        input [ADDR_BITS-1:0] addr_value;
        input [ID_BITS-1:0] id_value;
        input bypass_value;
        input [7:0] size_value;
        input [LINE_BITS-1:0] wdata_value;
        input [LINE_BYTES-1:0] wstrb_value;
        begin
            @(negedge clk);
            write_req_valid[master] = 1'b1;
            write_req_addr[(master * ADDR_BITS) +: ADDR_BITS] = addr_value;
            write_req_total_size[(master * 8) +: 8] = size_value;
            write_req_id[(master * ID_BITS) +: ID_BITS] = id_value;
            write_req_bypass[master] = bypass_value;
            write_req_wdata[(master * LINE_BITS) +: LINE_BITS] = wdata_value;
            write_req_wstrb[(master * LINE_BYTES) +: LINE_BYTES] = wstrb_value;
            timeout = 200;
            while ((write_req_accepted[master] !== 1'b1) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting write accepted");
            end
            @(negedge clk);
            write_req_valid[master] = 1'b0;
        end
    endtask

    task wait_for_bypass_req;
        input expect_write;
        input [ADDR_BITS-1:0] expect_addr;
        begin
            timeout = 200;
            while ((bypass_req_valid !== 1'b1) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting bypass_req_valid");
            end
            if (bypass_req_write !== expect_write) begin
                fail_now("unexpected bypass_req_write");
            end
            if (bypass_req_addr !== expect_addr) begin
                fail_now("unexpected bypass_req_addr");
            end
            if (bypass_req_mode2_ddr_aligned !== 1'b0) begin
                fail_now("mode1 bypass should not assert mode2 aligned flag");
            end
            observed_bypass_req_id = bypass_req_id;
        end
    endtask

    task wait_for_cache_req;
        input expect_write;
        input [ADDR_BITS-1:0] expect_addr;
        begin
            timeout = 200;
            while ((cache_req_valid !== 1'b1) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting cache_req_valid");
            end
            if (cache_req_write !== expect_write) begin
                fail_now("unexpected cache_req_write");
            end
            if (cache_req_addr !== expect_addr) begin
                fail_now("unexpected cache_req_addr");
            end
            observed_cache_req_id = cache_req_id;
        end
    endtask

    task respond_cache_read;
        input [ID_BITS-1:0] id_value;
        input [LINE_BITS-1:0] line_value;
        begin
            @(negedge clk);
            cache_resp_valid = 1'b1;
            cache_resp_id = id_value;
            cache_resp_rdata = pack_line(line_value);
            cache_resp_code = RESP_OKAY;
            timeout = 100;
            while ((cache_resp_ready !== 1'b1) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting cache_resp_ready");
            end
            @(negedge clk);
            cache_resp_valid = 1'b0;
        end
    endtask

    task respond_bypass_read;
        input [ID_BITS-1:0] id_value;
        input [LINE_BITS-1:0] line_value;
        begin
            @(negedge clk);
            bypass_resp_valid = 1'b1;
            bypass_resp_id = id_value;
            bypass_resp_rdata = pack_line(line_value);
            bypass_resp_code = RESP_OKAY;
            timeout = 100;
            while ((bypass_resp_ready !== 1'b1) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting bypass_resp_ready(read)");
            end
            @(negedge clk);
            bypass_resp_valid = 1'b0;
        end
    endtask

    task respond_bypass_write;
        input [ID_BITS-1:0] id_value;
        begin
            @(negedge clk);
            bypass_resp_valid = 1'b1;
            bypass_resp_id = id_value;
            bypass_resp_rdata = {READ_RESP_BITS{1'b0}};
            bypass_resp_code = RESP_OKAY;
            timeout = 100;
            while ((bypass_resp_ready !== 1'b1) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting bypass_resp_ready(write)");
            end
            @(negedge clk);
            bypass_resp_valid = 1'b0;
        end
    endtask

    task expect_read_response;
        input integer master;
        input [ID_BITS-1:0] id_value;
        begin
            timeout = 200;
            while ((read_resp_valid[master] !== 1'b1) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting read response");
            end
            if (get_read_resp_id(master) !== id_value) begin
                fail_now("read response id mismatch");
            end
            @(posedge clk);
        end
    endtask

    task expect_write_response;
        input integer master;
        input [ID_BITS-1:0] id_value;
        begin
            timeout = 200;
            while ((write_resp_valid[master] !== 1'b1) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting write response");
            end
            if (write_resp_id[(master * ID_BITS) +: ID_BITS] !== id_value) begin
                fail_now("write response id mismatch");
            end
            if (write_resp_code[(master * 2) +: 2] !== RESP_OKAY) begin
                fail_now("write response code mismatch");
            end
            @(posedge clk);
        end
    endtask

    axi_llc_subsystem_compat #(
        .ADDR_BITS(ADDR_BITS),
        .ID_BITS(ID_BITS),
        .MODE_BITS(MODE_BITS),
        .LINE_BYTES(LINE_BYTES),
        .LINE_BITS(LINE_BITS),
        .LINE_OFFSET_BITS(LINE_OFFSET_BITS),
        .SET_COUNT(SET_COUNT),
        .SET_BITS(SET_BITS),
        .WAY_COUNT(WAY_COUNT),
        .WAY_BITS(WAY_BITS),
        .META_BITS(META_BITS),
        .LLC_SIZE_BYTES(LLC_SIZE_BYTES),
        .WINDOW_BYTES(WINDOW_BYTES),
        .WINDOW_WAYS(WINDOW_WAYS),
        .NUM_READ_MASTERS(NUM_READ_MASTERS),
        .NUM_WRITE_MASTERS(NUM_WRITE_MASTERS),
        .READ_RESP_BITS(READ_RESP_BITS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .mode_req(mode_req),
        .llc_mapped_offset_req(llc_mapped_offset_req),
        .read_req_valid(read_req_valid),
        .read_req_ready(read_req_ready),
        .read_req_accepted(read_req_accepted),
        .read_req_accepted_id(read_req_accepted_id),
        .read_req_addr(read_req_addr),
        .read_req_total_size(read_req_total_size),
        .read_req_id(read_req_id),
        .read_req_bypass(read_req_bypass),
        .read_resp_valid(read_resp_valid),
        .read_resp_ready(read_resp_ready),
        .read_resp_data(read_resp_data),
        .read_resp_id(read_resp_id),
        .write_req_valid(write_req_valid),
        .write_req_ready(write_req_ready),
        .write_req_accepted(write_req_accepted),
        .write_req_addr(write_req_addr),
        .write_req_wdata(write_req_wdata),
        .write_req_wstrb(write_req_wstrb),
        .write_req_total_size(write_req_total_size),
        .write_req_id(write_req_id),
        .write_req_bypass(write_req_bypass),
        .write_resp_valid(write_resp_valid),
        .write_resp_ready(write_resp_ready),
        .write_resp_id(write_resp_id),
        .write_resp_code(write_resp_code),
        .cache_req_valid(cache_req_valid),
        .cache_req_ready(cache_req_ready),
        .cache_req_write(cache_req_write),
        .cache_req_addr(cache_req_addr),
        .cache_req_id(cache_req_id),
        .cache_req_size(cache_req_size),
        .cache_req_wdata(cache_req_wdata),
        .cache_req_wstrb(cache_req_wstrb),
        .cache_resp_valid(cache_resp_valid),
        .cache_resp_ready(cache_resp_ready),
        .cache_resp_rdata(cache_resp_rdata),
        .cache_resp_id(cache_resp_id),
        .cache_resp_code(cache_resp_code),
        .bypass_req_valid(bypass_req_valid),
        .bypass_req_ready(bypass_req_ready),
        .bypass_req_write(bypass_req_write),
        .bypass_req_addr(bypass_req_addr),
        .bypass_req_id(bypass_req_id),
        .bypass_req_size(bypass_req_size),
        .bypass_req_mode2_ddr_aligned(bypass_req_mode2_ddr_aligned),
        .bypass_req_wdata(bypass_req_wdata),
        .bypass_req_wstrb(bypass_req_wstrb),
        .bypass_resp_valid(bypass_resp_valid),
        .bypass_resp_ready(bypass_resp_ready),
        .bypass_resp_rdata(bypass_resp_rdata),
        .bypass_resp_id(bypass_resp_id),
        .bypass_resp_code(bypass_resp_code),
        .invalidate_line_valid(invalidate_line_valid),
        .invalidate_line_addr(invalidate_line_addr),
        .invalidate_line_accepted(invalidate_line_accepted),
        .invalidate_all_valid(invalidate_all_valid),
        .invalidate_all_accepted(invalidate_all_accepted),
        .active_mode(active_mode),
        .active_offset(active_offset),
        .reconfig_busy(reconfig_busy),
        .reconfig_state(reconfig_state),
        .config_error(config_error)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 1'b0;
        mode_req = MODE_CACHE;
        llc_mapped_offset_req = {ADDR_BITS{1'b0}};
        clear_inputs();
        read_resp_ready = {NUM_READ_MASTERS{1'b1}};
        write_resp_ready = {NUM_WRITE_MASTERS{1'b1}};
        cache_req_ready = 1'b0;
        cache_resp_valid = 1'b0;
        cache_resp_rdata = {READ_RESP_BITS{1'b0}};
        cache_resp_id = {ID_BITS{1'b0}};
        cache_resp_code = RESP_OKAY;
        bypass_req_ready = 1'b0;
        bypass_resp_valid = 1'b0;
        bypass_resp_rdata = {READ_RESP_BITS{1'b0}};
        bypass_resp_id = {ID_BITS{1'b0}};
        bypass_resp_code = RESP_OKAY;
        invalidate_line_valid = 1'b0;
        invalidate_line_addr = {ADDR_BITS{1'b0}};
        invalidate_all_valid = 1'b0;
        observed_cache_req_id = {ID_BITS{1'b0}};
        observed_bypass_req_id = {ID_BITS{1'b0}};

        wait_cycles(4);
        rst_n = 1'b1;
        wait_active_cache();

        // Case 1: bypass read miss ownership is handed to compat before lower
        // ready, so a later cache miss can still progress.
        issue_read_expect_accept(BYPASS_READ_MASTER,
                                 BYPASS_READ_ADDR,
                                 BYPASS_READ_ID,
                                 1'b1,
                                 8'd3);
        wait_for_bypass_req(1'b0, BYPASS_READ_ADDR);
        if (bypass_req_ready !== 1'b0) begin
            fail_now("bypass lower ready should still be low in pending-issue case");
        end

        issue_read_expect_accept(CACHE_MASTER,
                                 CACHE_ADDR0,
                                 CACHE_READ_ID0,
                                 1'b0,
                                 8'd3);
        wait_for_cache_req(1'b0, CACHE_ADDR0);

        cache_req_ready = 1'b1;
        @(posedge clk);
        cache_req_ready = 1'b0;
        respond_cache_read(observed_cache_req_id, 64'h1122_3344_5566_7788);
        expect_read_response(CACHE_MASTER, CACHE_READ_ID0);

        bypass_req_ready = 1'b1;
        @(posedge clk);
        bypass_req_ready = 1'b0;
        respond_bypass_read(observed_bypass_req_id, 64'h8877_6655_4433_2211);
        expect_read_response(BYPASS_READ_MASTER, BYPASS_READ_ID);

        // Install a resident line first so the next bypass write is a
        // write-through hit.
        cache_req_ready = 1'b1;
        issue_read_expect_accept(CACHE_MASTER,
                                 WRITE_THROUGH_ADDR,
                                 INSTALL_READ_ID,
                                 1'b0,
                                 LINE_BYTES - 1);
        wait_for_cache_req(1'b0, WRITE_THROUGH_ADDR);
        @(posedge clk);
        cache_req_ready = 1'b0;
        respond_cache_read(observed_cache_req_id, 64'h0102_0304_0506_0708);
        expect_read_response(CACHE_MASTER, INSTALL_READ_ID);

        // Case 2: bypass write-through also releases the core before lower
        // ready, so a later cache miss still reaches the cache lower port.
        issue_write_expect_accept(BYPASS_WRITE_MASTER,
                                  WRITE_THROUGH_ADDR,
                                  BYPASS_WRITE_ID,
                                  1'b1,
                                  8'd3,
                                  64'h0000_0000_DEAD_BEEF,
                                  8'h0F);
        wait_for_bypass_req(1'b1, WRITE_THROUGH_ADDR);
        if (bypass_req_wstrb !== 8'h0F) begin
            fail_now("unexpected bypass write-through wstrb");
        end

        issue_read_expect_accept(CACHE_MASTER,
                                 CACHE_ADDR1,
                                 CACHE_READ_ID1,
                                 1'b0,
                                 8'd3);
        wait_for_cache_req(1'b0, CACHE_ADDR1);

        cache_req_ready = 1'b1;
        @(posedge clk);
        cache_req_ready = 1'b0;
        respond_cache_read(observed_cache_req_id, 64'hA1A2_A3A4_A5A6_A7A8);
        expect_read_response(CACHE_MASTER, CACHE_READ_ID1);

        bypass_req_ready = 1'b1;
        @(posedge clk);
        bypass_req_ready = 1'b0;
        respond_bypass_write(observed_bypass_req_id);
        expect_write_response(BYPASS_WRITE_MASTER, BYPASS_WRITE_ID);

        $display("tb_axi_llc_subsystem_compat_bypass_pending_issue_contract PASS");
        $finish(0);
    end

endmodule
