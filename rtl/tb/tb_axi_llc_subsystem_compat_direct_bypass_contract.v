`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_compat_direct_bypass_contract;

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

    localparam [MODE_BITS-1:0] MODE_OFF = 2'b00;
    localparam [ADDR_BITS-1:0] ADDR0 = 32'h1000_0000;
    localparam [ADDR_BITS-1:0] ADDR1 = 32'h1000_0008;

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
    wire                                  bypass_req_valid;
    reg                                   bypass_req_ready;
    wire                                  bypass_req_write;
    wire [ADDR_BITS-1:0]                  bypass_req_addr;
    wire [ID_BITS-1:0]                    bypass_req_id;
    wire [7:0]                            bypass_req_size;
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

    reg  [ID_BITS-1:0]                    lower_id0;
    reg  [ID_BITS-1:0]                    lower_id1;
    integer                               timeout;

    function [ID_BITS-1:0] get_accept_id;
        input integer master;
        begin
            get_accept_id = read_req_accepted_id[(master * ID_BITS) +: ID_BITS];
        end
    endfunction

    function [ID_BITS-1:0] get_resp_id;
        input integer master;
        begin
            get_resp_id = read_resp_id[(master * ID_BITS) +: ID_BITS];
        end
    endfunction

    function [LINE_BITS-1:0] get_resp_line;
        input integer master;
        begin
            get_resp_line = read_resp_data[(master * READ_RESP_BITS) +: LINE_BITS];
        end
    endfunction

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
            $display("tb_axi_llc_subsystem_compat_direct_bypass_contract FAIL: %0s", msg);
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

    task wait_idle_mode0;
        begin
            timeout = 100;
            while (((active_mode !== MODE_OFF) || reconfig_busy) &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("reset mode should settle to mode0 idle");
            end
        end
    endtask

    task clear_inputs;
        begin
            read_req_valid = {NUM_READ_MASTERS{1'b0}};
            read_req_addr = {(NUM_READ_MASTERS*ADDR_BITS){1'b0}};
            read_req_total_size = {(NUM_READ_MASTERS*8){1'b0}};
            read_req_id = {(NUM_READ_MASTERS*ID_BITS){1'b0}};
            read_req_bypass = {NUM_READ_MASTERS{1'b1}};
            write_req_valid = {NUM_WRITE_MASTERS{1'b0}};
            write_req_addr = {(NUM_WRITE_MASTERS*ADDR_BITS){1'b0}};
            write_req_wdata = {(NUM_WRITE_MASTERS*LINE_BITS){1'b0}};
            write_req_wstrb = {(NUM_WRITE_MASTERS*LINE_BYTES){1'b0}};
            write_req_total_size = {(NUM_WRITE_MASTERS*8){1'b0}};
            write_req_id = {(NUM_WRITE_MASTERS*ID_BITS){1'b0}};
            write_req_bypass = {NUM_WRITE_MASTERS{1'b0}};
        end
    endtask

    task issue_read_expect_accept;
        input integer master;
        input [ADDR_BITS-1:0] addr_value;
        input [ID_BITS-1:0] id_value;
        begin
            @(negedge clk);
            read_req_valid[master] = 1'b1;
            read_req_addr[(master * ADDR_BITS) +: ADDR_BITS] = addr_value;
            read_req_total_size[(master * 8) +: 8] = LINE_BYTES - 1;
            read_req_id[(master * ID_BITS) +: ID_BITS] = id_value;
            read_req_bypass[master] = 1'b1;
            timeout = 100;
            while ((read_req_accepted[master] !== 1'b1) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting accepted pulse");
            end
            if (get_accept_id(master) !== id_value) begin
                fail_now("accepted_id mismatch");
            end
            @(negedge clk);
            read_req_valid[master] = 1'b0;
        end
    endtask

    task issue_read_expect_blocked;
        input integer master;
        input [ADDR_BITS-1:0] addr_value;
        input [ID_BITS-1:0] id_value;
        begin
            @(negedge clk);
            read_req_valid[master] = 1'b1;
            read_req_addr[(master * ADDR_BITS) +: ADDR_BITS] = addr_value;
            read_req_total_size[(master * 8) +: 8] = LINE_BYTES - 1;
            read_req_id[(master * ID_BITS) +: ID_BITS] = id_value;
            read_req_bypass[master] = 1'b1;
            wait_cycles(8);
            if (read_req_accepted[master] !== 1'b0) begin
                fail_now("duplicate id should not be accepted");
            end
            if (read_req_ready[master] !== 1'b0) begin
                fail_now("duplicate id should not become ready");
            end
            @(negedge clk);
            read_req_valid[master] = 1'b0;
        end
    endtask

    task wait_bypass_request;
        input [ADDR_BITS-1:0] exp_addr;
        output [ID_BITS-1:0] lower_id_value;
        begin
            timeout = 100;
            while (!bypass_req_valid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting bypass request");
            end
            if (bypass_req_write !== 1'b0) begin
                fail_now("bypass read should not drive write");
            end
            if (bypass_req_addr !== exp_addr) begin
                fail_now("bypass request address mismatch");
            end
            lower_id_value = bypass_req_id;
            @(negedge clk);
            bypass_req_ready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            bypass_req_ready = 1'b0;
        end
    endtask

    task drive_bypass_resp_until_ready;
        input [ID_BITS-1:0] lower_id_value;
        input [LINE_BITS-1:0] line_value;
        begin
            @(negedge clk);
            bypass_resp_valid = 1'b1;
            bypass_resp_id = lower_id_value;
            bypass_resp_rdata = pack_line(line_value);
            bypass_resp_code = 2'b00;
            timeout = 100;
            while (!bypass_resp_ready && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting bypass_resp_ready");
            end
            @(posedge clk);
            @(negedge clk);
            bypass_resp_valid = 1'b0;
            bypass_resp_id = {ID_BITS{1'b0}};
            bypass_resp_rdata = {READ_RESP_BITS{1'b0}};
            bypass_resp_code = 2'b00;
        end
    endtask

    task expect_read_resp;
        input integer master;
        input [ID_BITS-1:0] exp_id;
        input [LINE_BITS-1:0] exp_line;
        begin
            timeout = 100;
            while (!read_resp_valid[master] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting read response");
            end
            if (get_resp_id(master) !== exp_id) begin
                fail_now("read response id mismatch");
            end
            if (get_resp_line(master) !== exp_line) begin
                fail_now("read response line mismatch");
            end
        end
    endtask

    always #5 clk = ~clk;

    axi_llc_subsystem_compat #(
        .ADDR_BITS         (ADDR_BITS),
        .ID_BITS           (ID_BITS),
        .MODE_BITS         (MODE_BITS),
        .LINE_BYTES        (LINE_BYTES),
        .LINE_BITS         (LINE_BITS),
        .LINE_OFFSET_BITS  (LINE_OFFSET_BITS),
        .SET_COUNT         (SET_COUNT),
        .SET_BITS          (SET_BITS),
        .WAY_COUNT         (WAY_COUNT),
        .WAY_BITS          (WAY_BITS),
        .META_BITS         (META_BITS),
        .LLC_SIZE_BYTES    (LLC_SIZE_BYTES),
        .WINDOW_BYTES      (WINDOW_BYTES),
        .WINDOW_WAYS       (WINDOW_WAYS),
        .RESET_MODE        (MODE_OFF),
        .NUM_READ_MASTERS  (NUM_READ_MASTERS),
        .NUM_WRITE_MASTERS (NUM_WRITE_MASTERS),
        .READ_RESP_BITS    (READ_RESP_BITS)
    ) dut (
        .clk                   (clk),
        .rst_n                 (rst_n),
        .mode_req              (mode_req),
        .llc_mapped_offset_req (llc_mapped_offset_req),
        .read_req_valid        (read_req_valid),
        .read_req_ready        (read_req_ready),
        .read_req_accepted     (read_req_accepted),
        .read_req_accepted_id  (read_req_accepted_id),
        .read_req_addr         (read_req_addr),
        .read_req_total_size   (read_req_total_size),
        .read_req_id           (read_req_id),
        .read_req_bypass       (read_req_bypass),
        .read_resp_valid       (read_resp_valid),
        .read_resp_ready       (read_resp_ready),
        .read_resp_data        (read_resp_data),
        .read_resp_id          (read_resp_id),
        .write_req_valid       (write_req_valid),
        .write_req_ready       (write_req_ready),
        .write_req_accepted    (write_req_accepted),
        .write_req_addr        (write_req_addr),
        .write_req_wdata       (write_req_wdata),
        .write_req_wstrb       (write_req_wstrb),
        .write_req_total_size  (write_req_total_size),
        .write_req_id          (write_req_id),
        .write_req_bypass      (write_req_bypass),
        .write_resp_valid      (write_resp_valid),
        .write_resp_ready      (write_resp_ready),
        .write_resp_id         (write_resp_id),
        .write_resp_code       (write_resp_code),
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
        .bypass_resp_code      (bypass_resp_code),
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
        read_resp_ready = {NUM_READ_MASTERS{1'b1}};
        write_resp_ready = {NUM_WRITE_MASTERS{1'b1}};
        cache_req_ready = 1'b1;
        cache_resp_valid = 1'b0;
        cache_resp_rdata = {READ_RESP_BITS{1'b0}};
        cache_resp_id = {ID_BITS{1'b0}};
        bypass_req_ready = 1'b0;
        bypass_resp_valid = 1'b0;
        bypass_resp_rdata = {READ_RESP_BITS{1'b0}};
        bypass_resp_id = {ID_BITS{1'b0}};
        bypass_resp_code = 2'b00;
        invalidate_line_valid = 1'b0;
        invalidate_line_addr = {ADDR_BITS{1'b0}};
        invalidate_all_valid = 1'b0;
        clear_inputs();

        wait_cycles(4);
        rst_n = 1'b1;
        wait_idle_mode0();
        if (config_error) begin
            fail_now("config_error should stay low");
        end
        if (cache_req_valid) begin
            fail_now("mode0 direct bypass bench should not use cache_req");
        end

        issue_read_expect_accept(0, ADDR0, 4'h1);
        wait_bypass_request(ADDR0, lower_id0);

        issue_read_expect_blocked(0, ADDR0 + 32'h20, 4'h1);

        read_resp_ready[0] = 1'b0;
        drive_bypass_resp_until_ready(lower_id0, 64'h1111_1111_1111_1111);
        if (!read_resp_valid[0]) begin
            fail_now("first response should occupy master0 response slot");
        end

        issue_read_expect_accept(0, ADDR1, 4'h2);
        wait_bypass_request(ADDR1, lower_id1);

        @(negedge clk);
        bypass_resp_valid = 1'b1;
        bypass_resp_id = lower_id1;
        bypass_resp_rdata = pack_line(64'h2222_2222_2222_2222);
        bypass_resp_code = 2'b00;
        wait_cycles(4);
        if (bypass_resp_ready !== 1'b0) begin
            fail_now("second lower response should stall while response slot is occupied");
        end
        read_resp_ready[0] = 1'b1;
        timeout = 20;
        while (read_resp_valid[0] && (timeout > 0)) begin
            @(posedge clk);
            timeout = timeout - 1;
        end
        if (timeout == 0) begin
            fail_now("first response should clear once master becomes ready");
        end
        read_resp_ready[0] = 1'b0;
        timeout = 20;
        while (!bypass_resp_ready && (timeout > 0)) begin
            @(posedge clk);
            timeout = timeout - 1;
        end
        if (timeout == 0) begin
            fail_now("second lower response should resume after slot is freed");
        end
        @(posedge clk);
        @(negedge clk);
        bypass_resp_valid = 1'b0;
        bypass_resp_id = {ID_BITS{1'b0}};
        bypass_resp_rdata = {READ_RESP_BITS{1'b0}};

        expect_read_resp(0, 4'h2, 64'h2222_2222_2222_2222);
        read_resp_ready[0] = 1'b1;
        @(posedge clk);

        $display("tb_axi_llc_subsystem_compat_direct_bypass_contract PASS");
        $finish(0);
    end

endmodule
