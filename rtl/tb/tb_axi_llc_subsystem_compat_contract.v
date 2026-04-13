`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_compat_contract;

    localparam ADDR_BITS        = `AXI_LLC_ADDR_BITS;
    localparam ID_BITS          = `AXI_LLC_ID_BITS;
    localparam MODE_BITS        = `AXI_LLC_MODE_BITS;
    localparam LINE_BYTES       = 8;
    localparam LINE_BITS        = 64;
    localparam LINE_OFFSET_BITS = 3;
    localparam SET_COUNT        = 4;
    localparam SET_BITS         = 2;
    localparam WAY_COUNT        = 4;
    localparam WAY_BITS         = 2;
    localparam META_BITS        = `AXI_LLC_META_BITS;
    localparam LLC_SIZE_BYTES   = LINE_BYTES * SET_COUNT * WAY_COUNT;
    localparam WINDOW_BYTES     = LINE_BYTES * SET_COUNT;
    localparam WINDOW_WAYS      = 2;
    localparam NUM_READ_MASTERS = 2;
    localparam NUM_WRITE_MASTERS = 2;
    localparam READ_RESP_BITS   = `AXI_LLC_READ_RESP_BITS;

    localparam [MODE_BITS-1:0] MODE_OFF    = 2'b00;
    localparam [MODE_BITS-1:0] MODE_CACHE  = 2'b01;
    localparam [MODE_BITS-1:0] MODE_MAPPED = 2'b10;

    localparam [1:0] WRITE_RESP_OKAY = 2'b00;
    localparam [1:0] WRITE_RESP_SLVERR = 2'b10;

    localparam [ADDR_BITS-1:0] CACHE_ADDR      = 32'h0000_0000;
    localparam [ADDR_BITS-1:0] BYPASS_READ_ADDR = 32'h0000_0080;
    localparam [ADDR_BITS-1:0] BYPASS_WRITE_ADDR = 32'h0000_00C0;
    localparam [ADDR_BITS-1:0] DIRECT_BASE     = 32'h0000_1000;
    localparam [ADDR_BITS-1:0] DIRECT_ADDR     = 32'h0000_1000;

    localparam [LINE_BITS-1:0] CACHE_LINE_DATA  = 64'h1122_3344_5566_7788;
    localparam [LINE_BITS-1:0] BYPASS_READ_DATA = 64'h8877_6655_4433_2211;
    localparam [LINE_BITS-1:0] DIRECT_LINE_DATA = 64'hCAFE_BABE_0BAD_F00D;
    localparam [LINE_BITS-1:0] BYPASS_WRITE_DATA = 64'h0123_4567_89AB_CDEF;

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

    integer                               cache_req_count;
    integer                               bypass_req_count;
    integer                               cache_count_before;
    integer                               bypass_count_before;
    reg  [ID_BITS-1:0]                    seen_lower_id;
    integer                               idx;

    function [ID_BITS-1:0] get_read_accept_id;
        input integer master;
        begin
            get_read_accept_id =
                read_req_accepted_id[(master * ID_BITS) +: ID_BITS];
        end
    endfunction

    function [ID_BITS-1:0] get_read_resp_id;
        input integer master;
        begin
            get_read_resp_id =
                read_resp_id[(master * ID_BITS) +: ID_BITS];
        end
    endfunction

    function [LINE_BITS-1:0] get_read_resp_data;
        input integer master;
        begin
            get_read_resp_data =
                read_resp_data[(master * READ_RESP_BITS) +: LINE_BITS];
        end
    endfunction

    function [READ_RESP_BITS-1:0] pack_read_resp_line;
        input [LINE_BITS-1:0] line_value;
        begin
            pack_read_resp_line = {READ_RESP_BITS{1'b0}};
            pack_read_resp_line[LINE_BITS-1:0] = line_value;
        end
    endfunction

    function [ID_BITS-1:0] get_write_resp_id;
        input integer master;
        begin
            get_write_resp_id =
                write_resp_id[(master * ID_BITS) +: ID_BITS];
        end
    endfunction

    function [1:0] get_write_resp_code;
        input integer master;
        begin
            get_write_resp_code =
                write_resp_code[(master * 2) +: 2];
        end
    endfunction

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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cache_req_count <= 0;
            bypass_req_count <= 0;
        end else begin
            if (cache_req_valid && cache_req_ready) begin
                cache_req_count <= cache_req_count + 1;
            end
            if (bypass_req_valid && bypass_req_ready) begin
                bypass_req_count <= bypass_req_count + 1;
            end
        end
    end

    task fail_now;
        input [8*128-1:0] msg;
        begin
            $display("tb_axi_llc_subsystem_compat_contract FAIL: %0s", msg);
            $finish(1);
        end
    endtask

    task clear_read_reqs;
        begin
            read_req_valid = {NUM_READ_MASTERS{1'b0}};
            read_req_addr = {(NUM_READ_MASTERS*ADDR_BITS){1'b0}};
            read_req_total_size = {(NUM_READ_MASTERS*8){1'b0}};
            read_req_id = {(NUM_READ_MASTERS*ID_BITS){1'b0}};
            read_req_bypass = {NUM_READ_MASTERS{1'b0}};
        end
    endtask

    task clear_write_reqs;
        begin
            write_req_valid = {NUM_WRITE_MASTERS{1'b0}};
            write_req_addr = {(NUM_WRITE_MASTERS*ADDR_BITS){1'b0}};
            write_req_wdata = {(NUM_WRITE_MASTERS*LINE_BITS){1'b0}};
            write_req_wstrb = {(NUM_WRITE_MASTERS*LINE_BYTES){1'b0}};
            write_req_total_size = {(NUM_WRITE_MASTERS*8){1'b0}};
            write_req_id = {(NUM_WRITE_MASTERS*ID_BITS){1'b0}};
            write_req_bypass = {NUM_WRITE_MASTERS{1'b0}};
        end
    endtask

    task wait_cycles;
        input integer cycles;
        integer i;
        begin
            for (i = 0; i < cycles; i = i + 1) begin
                @(posedge clk);
            end
        end
    endtask

    task wait_idle_mode;
        input [MODE_BITS-1:0] expect_mode;
        input [ADDR_BITS-1:0] expect_offset;
        integer timeout;
        begin
            timeout = 200;
            while (((active_mode !== expect_mode) ||
                    (active_offset !== expect_offset) ||
                    reconfig_busy) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting active mode/offset");
            end
            if (reconfig_state !== 2'b00) begin
                fail_now("reconfig state should return to idle");
            end
        end
    endtask

    task issue_read;
        input integer master;
        input [ADDR_BITS-1:0] addr_value;
        input [ID_BITS-1:0] id_value;
        input [7:0] size_value;
        input bypass_value;
        integer timeout;
        begin
            @(negedge clk);
            read_req_valid[master] = 1'b1;
            read_req_addr[(master * ADDR_BITS) +: ADDR_BITS] = addr_value;
            read_req_total_size[(master * 8) +: 8] = size_value;
            read_req_id[(master * ID_BITS) +: ID_BITS] = id_value;
            read_req_bypass[master] = bypass_value;
            timeout = 100;
            while (!read_req_ready[master] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting read_req_ready");
            end
            #1;
            timeout = 100;
            while ((read_req_accepted[master] !== 1'b1) && (timeout > 0)) begin
                @(posedge clk);
                #1;
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("read_req_accepted pulse missing");
            end
            if (get_read_accept_id(master) !== id_value) begin
                fail_now("read_req_accepted_id mismatch");
            end
            @(negedge clk);
            read_req_valid[master] = 1'b0;
            read_req_addr[(master * ADDR_BITS) +: ADDR_BITS] = {ADDR_BITS{1'b0}};
            read_req_total_size[(master * 8) +: 8] = 8'd0;
            read_req_id[(master * ID_BITS) +: ID_BITS] = {ID_BITS{1'b0}};
            read_req_bypass[master] = 1'b0;
            @(posedge clk);
            #1;
            if (read_req_accepted !== {NUM_READ_MASTERS{1'b0}}) begin
                fail_now("read_req_accepted should clear after one cycle");
            end
        end
    endtask

    task issue_write;
        input integer master;
        input [ADDR_BITS-1:0] addr_value;
        input [ID_BITS-1:0] id_value;
        input [7:0] size_value;
        input [LINE_BITS-1:0] data_value;
        input [LINE_BYTES-1:0] strb_value;
        input bypass_value;
        integer timeout;
        begin
            @(negedge clk);
            write_req_valid[master] = 1'b1;
            write_req_addr[(master * ADDR_BITS) +: ADDR_BITS] = addr_value;
            write_req_total_size[(master * 8) +: 8] = size_value;
            write_req_id[(master * ID_BITS) +: ID_BITS] = id_value;
            write_req_wdata[(master * LINE_BITS) +: LINE_BITS] = data_value;
            write_req_wstrb[(master * LINE_BYTES) +: LINE_BYTES] = strb_value;
            write_req_bypass[master] = bypass_value;
            timeout = 100;
            while (!write_req_ready[master] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting write_req_ready");
            end
            #1;
            timeout = 100;
            while ((write_req_accepted[master] !== 1'b1) && (timeout > 0)) begin
                @(posedge clk);
                #1;
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("write_req_accepted pulse missing");
            end
            @(negedge clk);
            write_req_valid[master] = 1'b0;
            write_req_addr[(master * ADDR_BITS) +: ADDR_BITS] = {ADDR_BITS{1'b0}};
            write_req_total_size[(master * 8) +: 8] = 8'd0;
            write_req_id[(master * ID_BITS) +: ID_BITS] = {ID_BITS{1'b0}};
            write_req_wdata[(master * LINE_BITS) +: LINE_BITS] = {LINE_BITS{1'b0}};
            write_req_wstrb[(master * LINE_BYTES) +: LINE_BYTES] = {LINE_BYTES{1'b0}};
            write_req_bypass[master] = 1'b0;
            @(posedge clk);
            #1;
            if (write_req_accepted !== {NUM_WRITE_MASTERS{1'b0}}) begin
                fail_now("write_req_accepted should clear after one cycle");
            end
        end
    endtask

    task issue_parallel_read_write;
        input integer read_master;
        input [ADDR_BITS-1:0] read_addr_value;
        input [ID_BITS-1:0] read_id_value;
        input [7:0] read_size_value;
        input read_bypass_value;
        input integer write_master;
        input [ADDR_BITS-1:0] write_addr_value;
        input [ID_BITS-1:0] write_id_value;
        input [7:0] write_size_value;
        input [LINE_BITS-1:0] write_data_value;
        input [LINE_BYTES-1:0] write_strb_value;
        input write_bypass_value;
        integer timeout;
        reg read_seen;
        reg write_seen;
        reg [ID_BITS-1:0] read_seen_accept_id;
        begin
            @(negedge clk);
            read_req_valid[read_master] = 1'b1;
            read_req_addr[(read_master * ADDR_BITS) +: ADDR_BITS] = read_addr_value;
            read_req_total_size[(read_master * 8) +: 8] = read_size_value;
            read_req_id[(read_master * ID_BITS) +: ID_BITS] = read_id_value;
            read_req_bypass[read_master] = read_bypass_value;
            write_req_valid[write_master] = 1'b1;
            write_req_addr[(write_master * ADDR_BITS) +: ADDR_BITS] = write_addr_value;
            write_req_total_size[(write_master * 8) +: 8] = write_size_value;
            write_req_id[(write_master * ID_BITS) +: ID_BITS] = write_id_value;
            write_req_wdata[(write_master * LINE_BITS) +: LINE_BITS] = write_data_value;
            write_req_wstrb[(write_master * LINE_BYTES) +: LINE_BYTES] = write_strb_value;
            write_req_bypass[write_master] = write_bypass_value;
            #1;
            timeout = 100;
            read_seen = (read_req_accepted[read_master] === 1'b1);
            write_seen = (write_req_accepted[write_master] === 1'b1);
            read_seen_accept_id = {ID_BITS{1'b0}};
            if (read_seen) begin
                read_seen_accept_id = get_read_accept_id(read_master);
            end
            while ((!read_seen || !write_seen) && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[read_master] === 1'b1) begin
                    read_seen = 1'b1;
                    read_seen_accept_id = get_read_accept_id(read_master);
                end
                if (write_req_accepted[write_master] === 1'b1) begin
                    write_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("parallel read/write accepted pulse missing");
            end
            if (read_seen_accept_id !== read_id_value) begin
                fail_now("parallel read accepted_id mismatch");
            end
            @(negedge clk);
            read_req_valid[read_master] = 1'b0;
            read_req_addr[(read_master * ADDR_BITS) +: ADDR_BITS] = {ADDR_BITS{1'b0}};
            read_req_total_size[(read_master * 8) +: 8] = 8'd0;
            read_req_id[(read_master * ID_BITS) +: ID_BITS] = {ID_BITS{1'b0}};
            read_req_bypass[read_master] = 1'b0;
            write_req_valid[write_master] = 1'b0;
            write_req_addr[(write_master * ADDR_BITS) +: ADDR_BITS] = {ADDR_BITS{1'b0}};
            write_req_total_size[(write_master * 8) +: 8] = 8'd0;
            write_req_id[(write_master * ID_BITS) +: ID_BITS] = {ID_BITS{1'b0}};
            write_req_wdata[(write_master * LINE_BITS) +: LINE_BITS] = {LINE_BITS{1'b0}};
            write_req_wstrb[(write_master * LINE_BYTES) +: LINE_BYTES] = {LINE_BYTES{1'b0}};
            write_req_bypass[write_master] = 1'b0;
            @(posedge clk);
            #1;
            if ((read_req_accepted !== {NUM_READ_MASTERS{1'b0}}) ||
                (write_req_accepted !== {NUM_WRITE_MASTERS{1'b0}})) begin
                fail_now("parallel accepted pulses should clear after one cycle");
            end
        end
    endtask

    task wait_for_cache_req;
        input exp_write;
        input [ADDR_BITS-1:0] exp_addr;
        output [ID_BITS-1:0] req_id_value;
        integer timeout;
        begin
            timeout = 100;
            while (!cache_req_valid && (timeout > 0)) begin
                if (bypass_req_valid) begin
                    fail_now("unexpected bypass request while waiting cache request");
                end
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting cache request");
            end
            if (bypass_req_valid !== 1'b0) begin
                fail_now("bypass request should stay low on cache route");
            end
            if (cache_req_write !== exp_write) begin
                fail_now("cache_req_write mismatch");
            end
            if (cache_req_addr !== exp_addr) begin
                fail_now("cache_req_addr mismatch");
            end
            req_id_value = cache_req_id;
            @(posedge clk);
        end
    endtask

    task wait_for_bypass_req;
        input exp_write;
        input [ADDR_BITS-1:0] exp_addr;
        output [ID_BITS-1:0] req_id_value;
        integer timeout;
        begin
            timeout = 100;
            while (!bypass_req_valid && (timeout > 0)) begin
                if (cache_req_valid) begin
                    fail_now("unexpected cache request while waiting bypass request");
                end
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting bypass request");
            end
            if (cache_req_valid !== 1'b0) begin
                fail_now("cache request should stay low on bypass route");
            end
            if (bypass_req_write !== exp_write) begin
                fail_now("bypass_req_write mismatch");
            end
            if (bypass_req_addr !== exp_addr) begin
                fail_now("bypass_req_addr mismatch");
            end
            req_id_value = bypass_req_id;
            @(posedge clk);
        end
    endtask

    task send_cache_resp;
        input [ID_BITS-1:0] resp_id_value;
        input [LINE_BITS-1:0] resp_data_value;
        begin
            @(negedge clk);
            cache_resp_valid = 1'b1;
            cache_resp_id = resp_id_value;
            cache_resp_rdata = pack_read_resp_line(resp_data_value);
            @(posedge clk);
            @(negedge clk);
            cache_resp_valid = 1'b0;
            cache_resp_id = {ID_BITS{1'b0}};
            cache_resp_rdata = {READ_RESP_BITS{1'b0}};
        end
    endtask

    task send_bypass_resp;
        input [ID_BITS-1:0] resp_id_value;
        input [LINE_BITS-1:0] resp_data_value;
        input [1:0]          resp_code_value;
        begin
            @(negedge clk);
            bypass_resp_valid = 1'b1;
            bypass_resp_id = resp_id_value;
            bypass_resp_rdata = pack_read_resp_line(resp_data_value);
            bypass_resp_code = resp_code_value;
            @(posedge clk);
            @(negedge clk);
            bypass_resp_valid = 1'b0;
            bypass_resp_id = {ID_BITS{1'b0}};
            bypass_resp_rdata = {READ_RESP_BITS{1'b0}};
            bypass_resp_code = 2'b00;
        end
    endtask

    task wait_for_read_resp;
        input integer master;
        input [ID_BITS-1:0] exp_id;
        input [LINE_BITS-1:0] exp_data;
        integer timeout;
        begin
            timeout = 100;
            while (!read_resp_valid[master] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting read response");
            end
            if (get_read_resp_id(master) !== exp_id) begin
                fail_now("read response id mismatch");
            end
            if (get_read_resp_data(master) !== exp_data) begin
                fail_now("read response data mismatch");
            end
            for (idx = 0; idx < NUM_READ_MASTERS; idx = idx + 1) begin
                if ((idx != master) && read_resp_valid[idx]) begin
                    fail_now("read response routed to wrong master slot");
                end
            end
            @(posedge clk);
            #1;
            if (read_resp_valid[master] !== 1'b0) begin
                fail_now("read response should clear after ready");
            end
        end
    endtask

    task wait_for_write_resp;
        input integer master;
        input [ID_BITS-1:0] exp_id;
        input [1:0] exp_code;
        integer timeout;
        begin
            timeout = 100;
            while (!write_resp_valid[master] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting write response");
            end
            if (get_write_resp_id(master) !== exp_id) begin
                fail_now("write response id mismatch");
            end
            if (get_write_resp_code(master) !== exp_code) begin
                fail_now("write response code mismatch");
            end
            for (idx = 0; idx < NUM_WRITE_MASTERS; idx = idx + 1) begin
                if ((idx != master) && write_resp_valid[idx]) begin
                    fail_now("write response routed to wrong master slot");
                end
            end
            @(posedge clk);
            #1;
            if (write_resp_valid[master] !== 1'b0) begin
                fail_now("write response should clear after ready");
            end
        end
    endtask

    task wait_for_read_resp_without_lower;
        input integer master;
        input [ID_BITS-1:0] exp_id;
        input [LINE_BITS-1:0] exp_data;
        input integer baseline_cache_count;
        input integer baseline_bypass_count;
        integer timeout;
        begin
            timeout = 100;
            while (!read_resp_valid[master] && (timeout > 0)) begin
                if ((cache_req_count != baseline_cache_count) ||
                    (bypass_req_count != baseline_bypass_count)) begin
                    fail_now("direct read should not touch lower interfaces");
                end
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting direct read response");
            end
            if ((cache_req_count != baseline_cache_count) ||
                (bypass_req_count != baseline_bypass_count)) begin
                fail_now("direct read changed lower request counts");
            end
            if (get_read_resp_id(master) !== exp_id) begin
                fail_now("direct read response id mismatch");
            end
            if (get_read_resp_data(master) !== exp_data) begin
                fail_now("direct read response data mismatch");
            end
            @(posedge clk);
        end
    endtask

    task wait_for_write_resp_without_lower;
        input integer master;
        input [ID_BITS-1:0] exp_id;
        input [1:0] exp_code;
        input integer baseline_cache_count;
        input integer baseline_bypass_count;
        integer timeout;
        begin
            timeout = 100;
            while (!write_resp_valid[master] && (timeout > 0)) begin
                if ((cache_req_count != baseline_cache_count) ||
                    (bypass_req_count != baseline_bypass_count)) begin
                    fail_now("direct write should not touch lower interfaces");
                end
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting direct write response");
            end
            if ((cache_req_count != baseline_cache_count) ||
                (bypass_req_count != baseline_bypass_count)) begin
                fail_now("direct write changed lower request counts");
            end
            if (get_write_resp_id(master) !== exp_id) begin
                fail_now("direct write response id mismatch");
            end
            if (get_write_resp_code(master) !== exp_code) begin
                fail_now("direct write response code mismatch");
            end
            @(posedge clk);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        mode_req = MODE_CACHE;
        llc_mapped_offset_req = {ADDR_BITS{1'b0}};
        cache_req_ready = 1'b1;
        cache_resp_valid = 1'b0;
        cache_resp_rdata = {READ_RESP_BITS{1'b0}};
        cache_resp_id = {ID_BITS{1'b0}};
        bypass_req_ready = 1'b1;
        bypass_resp_valid = 1'b0;
        bypass_resp_rdata = {READ_RESP_BITS{1'b0}};
        bypass_resp_id = {ID_BITS{1'b0}};
        bypass_resp_code = 2'b00;
        invalidate_line_valid = 1'b0;
        invalidate_line_addr = {ADDR_BITS{1'b0}};
        invalidate_all_valid = 1'b0;
        read_resp_ready = {NUM_READ_MASTERS{1'b1}};
        write_resp_ready = {NUM_WRITE_MASTERS{1'b1}};
        clear_read_reqs();
        clear_write_reqs();

        wait_cycles(4);
        rst_n = 1'b1;
        wait_idle_mode(MODE_CACHE, {ADDR_BITS{1'b0}});
        if (config_error) begin
            fail_now("config_error should stay low");
        end

        issue_read(0, CACHE_ADDR, 4'h3, LINE_BYTES-1, 1'b0);
        wait_for_cache_req(1'b0, CACHE_ADDR, seen_lower_id);
        if (cache_req_size !== (LINE_BYTES - 1)) begin
            fail_now("cache request size should be full line");
        end
        send_cache_resp(seen_lower_id, CACHE_LINE_DATA);
        wait_for_read_resp(0, 4'h3, CACHE_LINE_DATA);

        issue_parallel_read_write(1, BYPASS_READ_ADDR, 4'h5, LINE_BYTES-1, 1'b1,
                                  0, BYPASS_WRITE_ADDR, 4'h9, LINE_BYTES-1,
                                  BYPASS_WRITE_DATA, {LINE_BYTES{1'b1}}, 1'b1);
        wait_for_bypass_req(1'b0, BYPASS_READ_ADDR, seen_lower_id);
        if (bypass_req_size !== (LINE_BYTES - 1)) begin
            fail_now("bypass read size should preserve upstream size");
        end
        send_bypass_resp(seen_lower_id, BYPASS_READ_DATA, WRITE_RESP_OKAY);
        wait_for_read_resp(1, 4'h5, BYPASS_READ_DATA);

        wait_for_bypass_req(1'b1, BYPASS_WRITE_ADDR, seen_lower_id);
        if (bypass_req_size !== (LINE_BYTES - 1)) begin
            fail_now("bypass write size should preserve upstream size");
        end
        if (bypass_req_wdata !== BYPASS_WRITE_DATA) begin
            fail_now("bypass write data mismatch");
        end
        if (bypass_req_wstrb !== {LINE_BYTES{1'b1}}) begin
            fail_now("bypass write strobe mismatch");
        end
        send_bypass_resp(seen_lower_id, {LINE_BITS{1'b0}}, WRITE_RESP_SLVERR);
        wait_for_write_resp(0, 4'h9, WRITE_RESP_SLVERR);

        $display("tb_axi_llc_subsystem_compat_contract PASS");
        $finish(0);
    end

endmodule
