`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_compat_read_queue_contract;

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
    localparam READ_RESP_BYTES   = `AXI_LLC_READ_RESP_BYTES;
    localparam READ_RESP_BITS    = `AXI_LLC_READ_RESP_BITS;

    localparam [MODE_BITS-1:0] MODE_OFF = 2'b00;

    localparam [ADDR_BITS-1:0] M0_ADDR0 = 32'h0000_0080;
    localparam [ADDR_BITS-1:0] M0_ADDR1 = 32'h0000_0088;
    localparam [ADDR_BITS-1:0] M0_ADDR2 = 32'h0000_0090;
    localparam [ADDR_BITS-1:0] M0_DUP_ADDR = 32'h0000_0098;
    localparam [ADDR_BITS-1:0] M1_ADDR0 = 32'h0000_0180;
    localparam [ADDR_BITS-1:0] M1_ADDR1 = 32'h0000_0188;

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

    integer                               bypass_req_count;
    reg                                   seen_id2;
    reg                                   seen_id3;
    reg                                   seen_id4;
    reg                                   seen_id5;
    reg  [ADDR_BITS-1:0]                  first_addr;
    reg  [ID_BITS-1:0]                    first_id;

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

    function [READ_RESP_BITS-1:0] pack_read_resp_line;
        input [LINE_BITS-1:0] line_value;
        begin
            pack_read_resp_line = {READ_RESP_BITS{1'b0}};
            pack_read_resp_line[LINE_BITS-1:0] = line_value;
        end
    endfunction

    function [LINE_BITS-1:0] line_for_id;
        input [ID_BITS-1:0] id_value;
        begin
            case (id_value)
                4'h1: line_for_id = 64'h1111_1111_1111_1111;
                4'h2: line_for_id = 64'h2222_2222_2222_2222;
                4'h3: line_for_id = 64'h3333_3333_3333_3333;
                4'h4: line_for_id = 64'h4444_4444_4444_4444;
                4'h5: line_for_id = 64'h5555_5555_5555_5555;
                default: line_for_id = 64'hDEAD_BEEF_DEAD_BEEF;
            endcase
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
        .RESET_MODE        (MODE_OFF),
        .NUM_READ_MASTERS  (NUM_READ_MASTERS),
        .NUM_WRITE_MASTERS (NUM_WRITE_MASTERS),
        .READ_RESP_BYTES   (READ_RESP_BYTES),
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
            bypass_req_count <= 0;
        end else if (bypass_req_valid && bypass_req_ready) begin
            bypass_req_count <= bypass_req_count + 1;
        end
    end

    always @(posedge clk) begin
        if (rst_n && cache_req_valid) begin
            $display("tb_axi_llc_subsystem_compat_read_queue_contract FAIL: unexpected cache_req in mode0");
            $finish(1);
        end
    end

    task fail_now;
        input [8*128-1:0] msg;
        begin
            $display("tb_axi_llc_subsystem_compat_read_queue_contract FAIL: %0s", msg);
            $finish(1);
        end
    endtask

    task clear_read_inputs;
        begin
            read_req_valid = {NUM_READ_MASTERS{1'b0}};
            read_req_addr = {(NUM_READ_MASTERS * ADDR_BITS){1'b0}};
            read_req_total_size = {(NUM_READ_MASTERS * 8){1'b0}};
            read_req_id = {(NUM_READ_MASTERS * ID_BITS){1'b0}};
            read_req_bypass = {NUM_READ_MASTERS{1'b1}};
        end
    endtask

    task clear_write_inputs;
        begin
            write_req_valid = {NUM_WRITE_MASTERS{1'b0}};
            write_req_addr = {(NUM_WRITE_MASTERS * ADDR_BITS){1'b0}};
            write_req_wdata = {(NUM_WRITE_MASTERS * LINE_BITS){1'b0}};
            write_req_wstrb = {(NUM_WRITE_MASTERS * LINE_BYTES){1'b0}};
            write_req_total_size = {(NUM_WRITE_MASTERS * 8){1'b0}};
            write_req_id = {(NUM_WRITE_MASTERS * ID_BITS){1'b0}};
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
        integer timeout;
        begin
            timeout = 100;
            while (((active_mode !== expect_mode) || reconfig_busy) &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting reset mode");
            end
            if (active_offset !== {ADDR_BITS{1'b0}}) begin
                fail_now("reset offset should stay zero");
            end
            if (reconfig_state !== 2'b00) begin
                fail_now("reconfig state should return idle");
            end
        end
    endtask

    task enqueue_read_expect_accept;
        input integer master;
        input [ADDR_BITS-1:0] addr_value;
        input [ID_BITS-1:0] id_value;
        reg [NUM_READ_MASTERS-1:0] expected_accept;
        integer timeout;
        begin
            expected_accept = {NUM_READ_MASTERS{1'b0}};
            expected_accept[master] = 1'b1;
            @(negedge clk);
            read_req_valid[master] = 1'b1;
            read_req_addr[(master * ADDR_BITS) +: ADDR_BITS] = addr_value;
            read_req_total_size[(master * 8) +: 8] = LINE_BYTES - 1;
            read_req_id[(master * ID_BITS) +: ID_BITS] = id_value;
            read_req_bypass[master] = 1'b1;
            timeout = 20;
            while ((read_req_ready[master] !== 1'b1) && (timeout > 0)) begin
                @(negedge clk);
                #1;
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting read_req_ready for accepted enqueue");
            end
            @(posedge clk);
            #1;
            if (read_req_accepted !== expected_accept) begin
                fail_now("read accepted pulse should be one-hot");
            end
            if (get_accept_id(master) !== id_value) begin
                fail_now("accepted_id mismatch on accepted enqueue");
            end
            @(negedge clk);
            read_req_valid[master] = 1'b0;
            read_req_addr[(master * ADDR_BITS) +: ADDR_BITS] = {ADDR_BITS{1'b0}};
            read_req_total_size[(master * 8) +: 8] = 8'd0;
            read_req_id[(master * ID_BITS) +: ID_BITS] = {ID_BITS{1'b0}};
            read_req_bypass[master] = 1'b1;
        end
    endtask

    task enqueue_read_expect_reject;
        input integer master;
        input [ADDR_BITS-1:0] addr_value;
        input [ID_BITS-1:0] id_value;
        integer hold_cycles;
        begin
            @(negedge clk);
            read_req_valid[master] = 1'b1;
            read_req_addr[(master * ADDR_BITS) +: ADDR_BITS] = addr_value;
            read_req_total_size[(master * 8) +: 8] = LINE_BYTES - 1;
            read_req_id[(master * ID_BITS) +: ID_BITS] = id_value;
            read_req_bypass[master] = 1'b1;
            for (hold_cycles = 0; hold_cycles < 4; hold_cycles = hold_cycles + 1) begin
                #1;
                if (read_req_ready[master] !== 1'b0) begin
                    fail_now("duplicate read id should be rejected by ready");
                end
                @(posedge clk);
                #1;
                if (read_req_accepted !== {NUM_READ_MASTERS{1'b0}}) begin
                    fail_now("duplicate read id should not raise accepted pulse");
                end
                @(negedge clk);
            end
            read_req_valid[master] = 1'b0;
            read_req_addr[(master * ADDR_BITS) +: ADDR_BITS] = {ADDR_BITS{1'b0}};
            read_req_total_size[(master * 8) +: 8] = 8'd0;
            read_req_id[(master * ID_BITS) +: ID_BITS] = {ID_BITS{1'b0}};
            read_req_bypass[master] = 1'b1;
        end
    endtask

    task wait_no_accept_pulse;
        begin
            @(posedge clk);
            #1;
            if (read_req_accepted !== {NUM_READ_MASTERS{1'b0}}) begin
                fail_now("accepted pulse should clear after one cycle");
            end
        end
    endtask

    task wait_for_bypass_req_any;
        output [ADDR_BITS-1:0] addr_value;
        output [ID_BITS-1:0] id_value;
        integer timeout;
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
                fail_now("read queue bench should not emit bypass writes");
            end
            if (bypass_req_size !== (LINE_BYTES - 1)) begin
                fail_now("bypass read size should preserve upstream size");
            end
            addr_value = bypass_req_addr;
            id_value = bypass_req_id;
            @(posedge clk);
        end
    endtask

    task send_bypass_resp;
        input [ID_BITS-1:0] resp_id_value;
        input [LINE_BITS-1:0] resp_line_value;
        begin
            @(negedge clk);
            bypass_resp_valid = 1'b1;
            bypass_resp_id = resp_id_value;
            bypass_resp_rdata = pack_read_resp_line(resp_line_value);
            @(posedge clk);
            @(negedge clk);
            bypass_resp_valid = 1'b0;
            bypass_resp_id = {ID_BITS{1'b0}};
            bypass_resp_rdata = {READ_RESP_BITS{1'b0}};
        end
    endtask

    task wait_for_read_resp;
        input integer master;
        input [ID_BITS-1:0] exp_id;
        input [LINE_BITS-1:0] exp_line;
        integer timeout;
        integer other_master;
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
                fail_now("read response data mismatch");
            end
            for (other_master = 0; other_master < NUM_READ_MASTERS;
                 other_master = other_master + 1) begin
                if ((other_master != master) && read_resp_valid[other_master]) begin
                    fail_now("read response routed to wrong master");
                end
            end
            @(posedge clk);
            #1;
            if (read_resp_valid[master] !== 1'b0) begin
                fail_now("read response should clear after ready");
            end
        end
    endtask

    task service_and_check_followup;
        reg [ADDR_BITS-1:0] seen_addr;
        reg [ID_BITS-1:0]   seen_id;
        begin
            wait_for_bypass_req_any(seen_addr, seen_id);
            case (seen_id)
                4'h2: begin
                    if (seen_id2) begin
                        fail_now("id2 dispatched twice");
                    end
                    if (seen_addr !== M0_ADDR1) begin
                        fail_now("id2 address mismatch");
                    end
                    seen_id2 = 1'b1;
                    send_bypass_resp(seen_id, line_for_id(seen_id));
                    wait_for_read_resp(0, 4'h2, line_for_id(4'h2));
                end
                4'h3: begin
                    if (seen_id3) begin
                        fail_now("id3 dispatched twice");
                    end
                    if (seen_addr !== M0_ADDR2) begin
                        fail_now("id3 address mismatch");
                    end
                    seen_id3 = 1'b1;
                    send_bypass_resp(seen_id, line_for_id(seen_id));
                    wait_for_read_resp(0, 4'h3, line_for_id(4'h3));
                end
                4'h4: begin
                    if (seen_id4) begin
                        fail_now("id4 dispatched twice");
                    end
                    if (seen_addr !== M1_ADDR0) begin
                        fail_now("id4 address mismatch");
                    end
                    seen_id4 = 1'b1;
                    send_bypass_resp(seen_id, line_for_id(seen_id));
                    wait_for_read_resp(1, 4'h4, line_for_id(4'h4));
                end
                4'h5: begin
                    if (seen_id5) begin
                        fail_now("id5 dispatched twice");
                    end
                    if (seen_addr !== M1_ADDR1) begin
                        fail_now("id5 address mismatch");
                    end
                    seen_id5 = 1'b1;
                    send_bypass_resp(seen_id, line_for_id(seen_id));
                    wait_for_read_resp(1, 4'h5, line_for_id(4'h5));
                end
                default: begin
                    fail_now("unexpected queued request id");
                end
            endcase
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        mode_req = MODE_OFF;
        llc_mapped_offset_req = {ADDR_BITS{1'b0}};
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
        read_resp_ready = {NUM_READ_MASTERS{1'b1}};
        write_resp_ready = {NUM_WRITE_MASTERS{1'b1}};
        clear_read_inputs();
        clear_write_inputs();
        seen_id2 = 1'b0;
        seen_id3 = 1'b0;
        seen_id4 = 1'b0;
        seen_id5 = 1'b0;

        wait_cycles(4);
        rst_n = 1'b1;
        wait_idle_mode(MODE_OFF);
        if (config_error) begin
            fail_now("config_error should stay low");
        end

        enqueue_read_expect_accept(0, M0_ADDR0, 4'h1);
        wait_for_bypass_req_any(first_addr, first_id);
        if (first_addr !== M0_ADDR0) begin
            fail_now("first request address mismatch");
        end
        if (first_id !== 4'h1) begin
            fail_now("first bypass request id should track upstream id");
        end

        // Explicit same-master back-to-back enqueue coverage.
        enqueue_read_expect_accept(0, M0_ADDR1, 4'h2);
        enqueue_read_expect_accept(0, M0_ADDR2, 4'h3);

        // Duplicate id on the same master must be blocked until completion.
        enqueue_read_expect_reject(0, M0_DUP_ADDR, 4'h1);

        // Different master can build its own queue independently.
        enqueue_read_expect_accept(1, M1_ADDR0, 4'h4);
        enqueue_read_expect_accept(1, M1_ADDR1, 4'h5);
        wait_no_accept_pulse();

        if (bypass_req_count !== 1) begin
            fail_now("queued reads should not dispatch before inflight read completes");
        end

        send_bypass_resp(first_id, line_for_id(first_id));
        wait_for_read_resp(0, 4'h1, line_for_id(4'h1));

        service_and_check_followup();
        service_and_check_followup();
        service_and_check_followup();
        service_and_check_followup();

        if (!(seen_id2 && seen_id3 && seen_id4 && seen_id5)) begin
            fail_now("not all queued read ids were eventually serviced");
        end

        $display("tb_axi_llc_subsystem_compat_read_queue_contract PASS");
        $finish(0);
    end

endmodule
