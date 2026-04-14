`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_compat_non_dcache_bypass_master_contract;

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
    localparam NUM_READ_MASTERS  = 3;
    localparam NUM_WRITE_MASTERS = 1;
    localparam READ_RESP_BITS    = `AXI_LLC_READ_RESP_BITS;

    localparam [MODE_BITS-1:0] MODE_CACHE = 2'b01;
    localparam [1:0] RESP_OKAY = 2'b00;
    localparam integer TEST_MASTER = 0;

    localparam [ADDR_BITS-1:0] ADDR0 = 32'h1000_0000;
    localparam [ADDR_BITS-1:0] ADDR1 = 32'h1000_0020;
    localparam [ID_BITS-1:0] FIRST_ID = 4'h2;
    localparam [ID_BITS-1:0] SECOND_ID = 4'h6;

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

    integer timeout;
    reg [ID_BITS-1:0] first_lower_id;

    function [READ_RESP_BITS-1:0] pack_line;
        input [LINE_BITS-1:0] line_value;
        begin
            pack_line = {READ_RESP_BITS{1'b0}};
            pack_line[LINE_BITS-1:0] = line_value;
        end
    endfunction

    task fail_now;
        input [8*160-1:0] msg;
        begin
            $display("tb_axi_llc_subsystem_compat_non_dcache_bypass_master_contract FAIL: %0s", msg);
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

    task issue_read_hold;
        input integer master;
        input [ADDR_BITS-1:0] addr_value;
        input [ID_BITS-1:0] id_value;
        begin
            @(negedge clk);
            read_req_valid[master] = 1'b1;
            read_req_addr[(master * ADDR_BITS) +: ADDR_BITS] = addr_value;
            read_req_total_size[(master * 8) +: 8] = 8'd3;
            read_req_id[(master * ID_BITS) +: ID_BITS] = id_value;
            read_req_bypass[master] = 1'b1;
        end
    endtask

    task drop_read;
        input integer master;
        begin
            @(negedge clk);
            read_req_valid[master] = 1'b0;
        end
    endtask

    task issue_read_expect_accept;
        input integer master;
        input [ADDR_BITS-1:0] addr_value;
        input [ID_BITS-1:0] id_value;
        begin
            issue_read_hold(master, addr_value, id_value);
            timeout = 200;
            while ((read_req_accepted[master] !== 1'b1) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting read accepted");
            end
            drop_read(master);
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
        bypass_req_ready = 1'b1;
        bypass_resp_valid = 1'b0;
        bypass_resp_rdata = {READ_RESP_BITS{1'b0}};
        bypass_resp_id = {ID_BITS{1'b0}};
        bypass_resp_code = RESP_OKAY;
        invalidate_line_valid = 1'b0;
        invalidate_line_addr = {ADDR_BITS{1'b0}};
        invalidate_all_valid = 1'b0;
        first_lower_id = {ID_BITS{1'b0}};

        wait_cycles(4);
        rst_n = 1'b1;
        wait_active_cache();

        issue_read_expect_accept(TEST_MASTER, ADDR0, FIRST_ID);
        timeout = 200;
        while ((bypass_req_valid !== 1'b1) && (timeout > 0)) begin
            @(posedge clk);
            timeout = timeout - 1;
        end
        if (timeout == 0) begin
            fail_now("timeout waiting first bypass issue");
        end
        if (bypass_req_write !== 1'b0) begin
            fail_now("first request should be bypass read");
        end
        if (bypass_req_addr !== ADDR0) begin
            fail_now("unexpected first bypass address");
        end
        first_lower_id = bypass_req_id;
        wait_cycles(2);

        issue_read_hold(TEST_MASTER, ADDR1, SECOND_ID);
        wait_cycles(8);
        if (read_req_accepted[TEST_MASTER] !== 1'b0) begin
            fail_now("non-dcache same-master second bypass read should stay blocked");
        end
        if (read_req_ready[TEST_MASTER] !== 1'b0) begin
            fail_now("non-dcache same-master second bypass read should not become ready");
        end

        @(negedge clk);
        bypass_resp_valid = 1'b1;
        bypass_resp_id = first_lower_id;
        bypass_resp_rdata = pack_line(64'hCAFE_BABE_1122_3344);
        bypass_resp_code = RESP_OKAY;
        timeout = 100;
        while ((bypass_resp_ready !== 1'b1) && (timeout > 0)) begin
            @(posedge clk);
            timeout = timeout - 1;
        end
        if (timeout == 0) begin
            fail_now("timeout waiting first bypass response ready");
        end
        @(negedge clk);
        bypass_resp_valid = 1'b0;

        timeout = 100;
        while ((read_resp_valid[TEST_MASTER] !== 1'b1) && (timeout > 0)) begin
            @(posedge clk);
            timeout = timeout - 1;
        end
        if (timeout == 0) begin
            fail_now("timeout waiting first upstream read response");
        end
        timeout = 100;
        while ((read_resp_valid[TEST_MASTER] !== 1'b0) && (timeout > 0)) begin
            @(posedge clk);
            timeout = timeout - 1;
        end
        if (timeout == 0) begin
            fail_now("first upstream read response should retire before second response");
        end

        timeout = 200;
        while ((read_req_accepted[TEST_MASTER] !== 1'b1) && (timeout > 0)) begin
            @(posedge clk);
            timeout = timeout - 1;
        end
        if (timeout == 0) begin
            fail_now("second bypass read should accept after first retires");
        end
        drop_read(TEST_MASTER);

        timeout = 200;
        while ((bypass_req_valid !== 1'b1) && (timeout > 0)) begin
            @(posedge clk);
            timeout = timeout - 1;
        end
        if (timeout == 0) begin
            fail_now("timeout waiting second bypass issue");
        end
        if (bypass_req_addr !== ADDR1) begin
            fail_now("unexpected second bypass address");
        end

        $display("tb_axi_llc_subsystem_compat_non_dcache_bypass_master_contract PASS");
        $finish(0);
    end

endmodule
