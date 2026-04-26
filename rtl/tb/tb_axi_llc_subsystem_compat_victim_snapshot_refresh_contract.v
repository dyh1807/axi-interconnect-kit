`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_compat_victim_snapshot_refresh_contract;

    localparam ADDR_BITS         = `AXI_LLC_ADDR_BITS;
    localparam ID_BITS           = `AXI_LLC_ID_BITS;
    localparam MODE_BITS         = `AXI_LLC_MODE_BITS;
    localparam LINE_BYTES        = 8;
    localparam LINE_BITS         = 64;
    localparam LINE_OFFSET_BITS  = 3;
    localparam SET_COUNT         = 2;
    localparam SET_BITS          = 1;
    localparam WAY_COUNT         = 1;
    localparam WAY_BITS          = 1;
    localparam META_BITS         = `AXI_LLC_META_BITS;
    localparam LLC_SIZE_BYTES    = LINE_BYTES * SET_COUNT * WAY_COUNT;
    localparam WINDOW_BYTES      = LINE_BYTES * SET_COUNT;
    localparam WINDOW_WAYS       = 1;
    localparam NUM_READ_MASTERS  = 1;
    localparam NUM_WRITE_MASTERS = 1;
    localparam READ_RESP_BITS    = `AXI_LLC_READ_RESP_BITS;

    localparam [MODE_BITS-1:0] MODE_CACHE = 2'b01;
    localparam [ADDR_BITS-1:0] VICTIM_ADDR = 32'h0000_0000;
    localparam [ADDR_BITS-1:0] MISS_ADDR   = 32'h0000_0010;
    localparam [ID_BITS-1:0]   FILL_ID     = 4'h1;
    localparam [ID_BITS-1:0]   DIRTY_ID    = 4'h2;
    localparam [ID_BITS-1:0]   MISS_ID     = 4'h3;
    localparam [ID_BITS-1:0]   REFRESH_ID  = 4'h4;

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

    reg  [LINE_BITS-1:0]                  victim_line;
    reg  [LINE_BITS-1:0]                  dirty_line;
    reg  [LINE_BITS-1:0]                  refreshed_line;
    reg  [LINE_BITS-1:0]                  miss_line;
    reg  [ID_BITS-1:0]                    lower_miss_id;
    reg  [ID_BITS-1:0]                    lower_victim_fill_id;
    reg  [ID_BITS-1:0]                    lower_victim_wb_id;
    integer                               timeout;

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

    function [LINE_BITS-1:0] get_read_resp_line;
        input integer master;
        begin
            get_read_resp_line = read_resp_data[(master * READ_RESP_BITS) +: LINE_BITS];
        end
    endfunction

    task fail_now;
        input [8*160-1:0] msg;
        begin
            $display("tb_axi_llc_subsystem_compat_victim_snapshot_refresh_contract FAIL: %0s", msg);
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

    task wait_mode_cache_active;
        begin
            timeout = 100;
            while (((active_mode !== MODE_CACHE) || reconfig_busy) &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("mode=1 activate timeout");
            end
        end
    endtask

    task clear_inputs;
        begin
            read_req_valid = {NUM_READ_MASTERS{1'b0}};
            read_req_addr = {(NUM_READ_MASTERS * ADDR_BITS){1'b0}};
            read_req_total_size = {(NUM_READ_MASTERS * 8){1'b0}};
            read_req_id = {(NUM_READ_MASTERS * ID_BITS){1'b0}};
            read_req_bypass = {NUM_READ_MASTERS{1'b0}};
            write_req_valid = {NUM_WRITE_MASTERS{1'b0}};
            write_req_addr = {(NUM_WRITE_MASTERS * ADDR_BITS){1'b0}};
            write_req_wdata = {(NUM_WRITE_MASTERS * LINE_BITS){1'b0}};
            write_req_wstrb = {(NUM_WRITE_MASTERS * LINE_BYTES){1'b0}};
            write_req_total_size = {(NUM_WRITE_MASTERS * 8){1'b0}};
            write_req_id = {(NUM_WRITE_MASTERS * ID_BITS){1'b0}};
            write_req_bypass = {NUM_WRITE_MASTERS{1'b0}};
        end
    endtask

    task issue_read;
        input [ADDR_BITS-1:0] addr_value;
        input [ID_BITS-1:0]   id_value;
        begin
            @(negedge clk);
            read_req_valid[0] = 1'b1;
            read_req_addr[ADDR_BITS-1:0] = addr_value;
            read_req_total_size[7:0] = LINE_BYTES - 1;
            read_req_id[ID_BITS-1:0] = id_value;
            read_req_bypass[0] = 1'b0;
            timeout = 100;
            while ((read_req_accepted[0] !== 1'b1) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("read request not accepted");
            end
            @(negedge clk);
            read_req_valid[0] = 1'b0;
        end
    endtask

    task issue_write;
        input [ADDR_BITS-1:0]   addr_value;
        input [ID_BITS-1:0]     id_value;
        input [LINE_BITS-1:0]   line_value;
        input [LINE_BYTES-1:0]  strb_value;
        begin
            @(negedge clk);
            write_req_valid[0] = 1'b1;
            write_req_addr[ADDR_BITS-1:0] = addr_value;
            write_req_wdata[LINE_BITS-1:0] = line_value;
            write_req_wstrb[LINE_BYTES-1:0] = strb_value;
            write_req_total_size[7:0] = LINE_BYTES - 1;
            write_req_id[ID_BITS-1:0] = id_value;
            write_req_bypass[0] = 1'b0;
            timeout = 100;
            while ((write_req_accepted[0] !== 1'b1) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("write request not accepted");
            end
            @(negedge clk);
            write_req_valid[0] = 1'b0;
        end
    endtask

    task wait_cache_req;
        input                     expect_write;
        input [ADDR_BITS-1:0]     expect_addr;
        output [ID_BITS-1:0]      req_id_value;
        begin
            timeout = 100;
            while (!(cache_req_valid &&
                     cache_req_ready &&
                     (cache_req_write == expect_write) &&
                     (cache_req_addr == expect_addr)) &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("cache request timeout");
            end
            req_id_value = cache_req_id;
            @(posedge clk);
        end
    endtask

    task drive_cache_resp;
        input [ID_BITS-1:0]       resp_id_value;
        input [LINE_BITS-1:0]     line_value;
        begin
            @(negedge clk);
            cache_resp_valid = 1'b1;
            cache_resp_id = resp_id_value;
            cache_resp_code = 2'b00;
            cache_resp_rdata = pack_line(line_value);
            timeout = 100;
            while (!cache_resp_ready && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("cache response timeout");
            end
            @(posedge clk);
            @(negedge clk);
            cache_resp_valid = 1'b0;
            cache_resp_id = {ID_BITS{1'b0}};
            cache_resp_code = 2'b00;
            cache_resp_rdata = {READ_RESP_BITS{1'b0}};
        end
    endtask

    task wait_read_resp;
        input [ID_BITS-1:0]       expect_id;
        input [LINE_BITS-1:0]     expect_line;
        begin
            timeout = 200;
            while (!read_resp_valid[0] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("read response timeout");
            end
            if (get_read_resp_id(0) !== expect_id) begin
                fail_now("read response id mismatch");
            end
            if (get_read_resp_line(0) !== expect_line) begin
                fail_now("read response data mismatch");
            end
            @(posedge clk);
        end
    endtask

    task wait_write_resp;
        input [ID_BITS-1:0] expect_id;
        begin
            timeout = 200;
            while (!write_resp_valid[0] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("write response timeout");
            end
            if (write_resp_id[ID_BITS-1:0] !== expect_id) begin
                fail_now("write response id mismatch");
            end
            if (write_resp_code[1:0] !== 2'b00) begin
                fail_now("write response code mismatch");
            end
            @(posedge clk);
        end
    endtask

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
        .RESET_MODE        (MODE_CACHE),
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
        .cache_resp_code       (cache_resp_code),
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
        mode_req = MODE_CACHE;
        llc_mapped_offset_req = {ADDR_BITS{1'b0}};
        clear_inputs();
        read_resp_ready = {NUM_READ_MASTERS{1'b1}};
        write_resp_ready = {NUM_WRITE_MASTERS{1'b1}};
        cache_req_ready = 1'b1;
        cache_resp_valid = 1'b0;
        cache_resp_rdata = {READ_RESP_BITS{1'b0}};
        cache_resp_id = {ID_BITS{1'b0}};
        cache_resp_code = 2'b00;
        bypass_req_ready = 1'b1;
        bypass_resp_valid = 1'b0;
        bypass_resp_rdata = {READ_RESP_BITS{1'b0}};
        bypass_resp_id = {ID_BITS{1'b0}};
        bypass_resp_code = 2'b00;
        invalidate_line_valid = 1'b0;
        invalidate_line_addr = {ADDR_BITS{1'b0}};
        invalidate_all_valid = 1'b0;

        victim_line = make_line(8'h10);
        dirty_line = make_line(8'h90);
        refreshed_line = make_line(8'hC0);
        miss_line = make_line(8'h40);
        lower_miss_id = {ID_BITS{1'b0}};
        lower_victim_fill_id = {ID_BITS{1'b0}};
        lower_victim_wb_id = {ID_BITS{1'b0}};

        wait_cycles(5);
        rst_n = 1'b1;
        wait_cycles(5);
        wait_mode_cache_active();

        $display("STEP 1 fill victim line");
        issue_read(VICTIM_ADDR, FILL_ID);
        wait_cache_req(1'b0, VICTIM_ADDR, lower_victim_fill_id);
        drive_cache_resp(lower_victim_fill_id, victim_line);
        wait_read_resp(FILL_ID, victim_line);

        $display("STEP 2 dirty victim line");
        issue_write(VICTIM_ADDR, DIRTY_ID, dirty_line, {LINE_BYTES{1'b1}});
        wait_write_resp(DIRTY_ID);

        $display("STEP 3 issue read miss with dirty victim");
        issue_read(MISS_ADDR, MISS_ID);
        wait_cache_req(1'b0, MISS_ADDR, lower_miss_id);

        $display("STEP 4 victim-line write hit must still be accepted pre-refill");
        issue_write(VICTIM_ADDR, REFRESH_ID, refreshed_line, {LINE_BYTES{1'b1}});
        wait_write_resp(REFRESH_ID);

        $display("STEP 5 refill returns, miss response must not wait for victim writeback issue");
        @(negedge clk);
        cache_req_ready = 1'b0;
        drive_cache_resp(lower_miss_id, miss_line);
        wait_read_resp(MISS_ID, miss_line);

        $display("STEP 6 once lower writeback path unblocks, victim snapshot must use refreshed data");
        @(negedge clk);
        cache_req_ready = 1'b1;
        wait_cache_req(1'b1, VICTIM_ADDR, lower_victim_wb_id);
        if (cache_req_wdata !== refreshed_line) begin
            fail_now("victim writeback data did not refresh to latest write-hit snapshot");
        end
        drive_cache_resp(lower_victim_wb_id, {LINE_BITS{1'b0}});

        if (bypass_req_valid) begin
            fail_now("unexpected bypass activity");
        end

        $display("tb_axi_llc_subsystem_compat_victim_snapshot_refresh_contract PASS");
        $finish(0);
    end

endmodule
