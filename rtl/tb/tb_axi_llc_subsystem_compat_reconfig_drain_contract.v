`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_compat_reconfig_drain_contract;

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
    localparam NUM_READ_MASTERS  = 1;
    localparam NUM_WRITE_MASTERS = 1;
    localparam READ_RESP_BYTES   = `AXI_LLC_READ_RESP_BYTES;
    localparam READ_RESP_BITS    = `AXI_LLC_READ_RESP_BITS;

    localparam [MODE_BITS-1:0] MODE_OFF   = 2'b00;
    localparam [MODE_BITS-1:0] MODE_CACHE = 2'b01;

    localparam [ADDR_BITS-1:0] READ_ADDR0 = 32'h0000_0080;
    localparam [ADDR_BITS-1:0] READ_ADDR1 = 32'h0000_0088;
    localparam [ID_BITS-1:0]   READ_ID0   = 4'h1;
    localparam [ID_BITS-1:0]   READ_ID1   = 4'h2;
    localparam [LINE_BITS-1:0] RESP_LINE0 = 64'h1111_1111_1111_1111;
    localparam [LINE_BITS-1:0] RESP_LINE1 = 64'h2222_2222_2222_2222;

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

    integer                               lower_req_count;
    integer                               bypass_req_count;
    integer                               cache_req_count;
    integer                               invalidate_all_accept_count;
    reg                                   last_req_is_cache;
    reg                                   last_req_is_write;
    reg  [ADDR_BITS-1:0]                  last_req_addr;
    reg  [ID_BITS-1:0]                    last_req_id;
    reg  [ID_BITS-1:0]                    first_lower_bypass_id;
    reg  [ID_BITS-1:0]                    second_lower_bypass_id;

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

    always #5 clk = ~clk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lower_req_count <= 0;
            bypass_req_count <= 0;
            cache_req_count <= 0;
            invalidate_all_accept_count <= 0;
            last_req_is_cache <= 1'b0;
            last_req_is_write <= 1'b0;
            last_req_addr <= {ADDR_BITS{1'b0}};
            last_req_id <= {ID_BITS{1'b0}};
        end else begin
            if (cache_req_valid && cache_req_ready) begin
                lower_req_count <= lower_req_count + 1;
                cache_req_count <= cache_req_count + 1;
                last_req_is_cache <= 1'b1;
                last_req_is_write <= cache_req_write;
                last_req_addr <= cache_req_addr;
                last_req_id <= cache_req_id;
            end
            if (bypass_req_valid && bypass_req_ready) begin
                lower_req_count <= lower_req_count + 1;
                bypass_req_count <= bypass_req_count + 1;
                last_req_is_cache <= 1'b0;
                last_req_is_write <= bypass_req_write;
                last_req_addr <= bypass_req_addr;
                last_req_id <= bypass_req_id;
            end
            if (invalidate_all_accepted) begin
                invalidate_all_accept_count <= invalidate_all_accept_count + 1;
            end
        end
    end

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

    task fail_now;
        input [8*160-1:0] msg;
        begin
            $display("tb_axi_llc_subsystem_compat_reconfig_drain_contract FAIL: %0s", msg);
            $finish(1);
        end
    endtask

    task clear_read_inputs;
        begin
            read_req_valid = {NUM_READ_MASTERS{1'b0}};
            read_req_addr = {(NUM_READ_MASTERS * ADDR_BITS){1'b0}};
            read_req_total_size = {(NUM_READ_MASTERS * 8){1'b0}};
            read_req_id = {(NUM_READ_MASTERS * ID_BITS){1'b0}};
            read_req_bypass = {NUM_READ_MASTERS{1'b0}};
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
        integer idx;
        begin
            for (idx = 0; idx < cycles; idx = idx + 1) begin
                @(posedge clk);
            end
        end
    endtask

    task wait_idle_mode;
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
                fail_now("timeout waiting active mode idle");
            end
            if (active_offset !== {ADDR_BITS{1'b0}}) begin
                fail_now("mapped offset should stay zero in this bench");
            end
            if (reconfig_state !== 2'b00) begin
                fail_now("reconfig state should settle back to idle");
            end
        end
    endtask

    task enqueue_read_expect_accept;
        input [ADDR_BITS-1:0] addr_value;
        input [ID_BITS-1:0]   id_value;
        integer timeout;
        reg accepted_seen;
        begin
            @(negedge clk);
            read_req_valid[0] = 1'b1;
            read_req_addr[ADDR_BITS-1:0] = addr_value;
            read_req_total_size[7:0] = LINE_BYTES - 1;
            read_req_id[ID_BITS-1:0] = id_value;
            read_req_bypass[0] = 1'b0;
            timeout = 100;
            while (!read_req_ready[0] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting read_req_ready");
            end
            #1;
            accepted_seen = (read_req_accepted[0] === 1'b1);
            timeout = 100;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[0] === 1'b1) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("read_req_accepted pulse missing");
            end
            if (get_read_accept_id(0) !== id_value) begin
                fail_now("read_req_accepted_id mismatch");
            end
            @(negedge clk);
            read_req_valid[0] = 1'b0;
            read_req_addr[ADDR_BITS-1:0] = {ADDR_BITS{1'b0}};
            read_req_total_size[7:0] = 8'd0;
            read_req_id[ID_BITS-1:0] = {ID_BITS{1'b0}};
            read_req_bypass[0] = 1'b0;
            @(posedge clk);
            #1;
            if (read_req_accepted !== {NUM_READ_MASTERS{1'b0}}) begin
                fail_now("read_req_accepted should clear after one cycle");
            end
        end
    endtask

    task wait_for_lower_req_count;
        input integer         expect_count;
        input                 exp_is_cache;
        input                 exp_is_write;
        input [ADDR_BITS-1:0] exp_addr;
        output [ID_BITS-1:0]  observed_id;
        integer timeout;
        begin
            timeout = 200;
            while ((lower_req_count < expect_count) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting lower request count");
            end
            if (last_req_is_cache !== exp_is_cache) begin
                fail_now("lower request route mismatch");
            end
            if (last_req_is_write !== exp_is_write) begin
                fail_now("lower request direction mismatch");
            end
            if (last_req_addr !== exp_addr) begin
                fail_now("lower request address mismatch");
            end
            observed_id = last_req_id;
        end
    endtask

    task send_bypass_resp;
        input [ID_BITS-1:0]   resp_id_value;
        input [LINE_BITS-1:0] resp_data_value;
        begin
            @(negedge clk);
            bypass_resp_valid = 1'b1;
            bypass_resp_id = resp_id_value;
            bypass_resp_rdata = pack_read_resp_line(resp_data_value);
            bypass_resp_code = 2'b00;
            @(posedge clk);
            @(negedge clk);
            bypass_resp_valid = 1'b0;
            bypass_resp_id = {ID_BITS{1'b0}};
            bypass_resp_rdata = {READ_RESP_BITS{1'b0}};
            bypass_resp_code = 2'b00;
        end
    endtask

    task wait_for_held_read_resp;
        input [ID_BITS-1:0]   exp_id;
        input [LINE_BITS-1:0] exp_data;
        integer timeout;
        begin
            timeout = 100;
            while (!read_resp_valid[0] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting held read response");
            end
            if (get_read_resp_id(0) !== exp_id) begin
                fail_now("held read response id mismatch");
            end
            if (get_read_resp_data(0) !== exp_data) begin
                fail_now("held read response data mismatch");
            end
            if (read_resp_ready[0] !== 1'b0) begin
                fail_now("held response phase requires read_resp_ready low");
            end
        end
    endtask

    task consume_held_read_resp;
        input [ID_BITS-1:0]   exp_id;
        input [LINE_BITS-1:0] exp_data;
        begin
            if (!read_resp_valid[0]) begin
                fail_now("cannot consume missing held read response");
            end
            if (get_read_resp_id(0) !== exp_id) begin
                fail_now("held read response id changed before consume");
            end
            if (get_read_resp_data(0) !== exp_data) begin
                fail_now("held read response data changed before consume");
            end
            @(negedge clk);
            read_resp_ready[0] = 1'b1;
            @(posedge clk);
            #1;
            if (read_resp_valid[0] !== 1'b0) begin
                fail_now("held read response should clear after consume");
            end
        end
    endtask

    task wait_for_read_resp_and_drain;
        input [ID_BITS-1:0]   exp_id;
        input [LINE_BITS-1:0] exp_data;
        integer timeout;
        begin
            timeout = 100;
            while (!read_resp_valid[0] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting drained read response");
            end
            if (get_read_resp_id(0) !== exp_id) begin
                fail_now("drained read response id mismatch");
            end
            if (get_read_resp_data(0) !== exp_data) begin
                fail_now("drained read response data mismatch");
            end
            @(posedge clk);
            #1;
            if (read_resp_valid[0] !== 1'b0) begin
                fail_now("drained read response should clear after ready");
            end
        end
    endtask

    task assert_old_mode_hold;
        input integer hold_cycles;
        integer idx;
        begin
            for (idx = 0; idx < hold_cycles; idx = idx + 1) begin
                @(posedge clk);
                #1;
                if (active_mode !== MODE_OFF) begin
                    fail_now("active_mode switched before compat queue drained");
                end
                if (invalidate_all_accepted) begin
                    fail_now("invalidate_all accepted before compat queue drained");
                end
                if (cache_req_count != 0) begin
                    fail_now("queued mode0 read rerouted to cache before drain");
                end
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        mode_req = MODE_OFF;
        llc_mapped_offset_req = {ADDR_BITS{1'b0}};
        read_resp_ready = {NUM_READ_MASTERS{1'b0}};
        write_resp_ready = {NUM_WRITE_MASTERS{1'b1}};
        clear_read_inputs();
        clear_write_inputs();
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
        first_lower_bypass_id = {ID_BITS{1'b0}};
        second_lower_bypass_id = {ID_BITS{1'b0}};

        wait_cycles(4);
        rst_n = 1'b1;
        wait_idle_mode(MODE_OFF);
        invalidate_all_accept_count = 0;

        enqueue_read_expect_accept(READ_ADDR0, READ_ID0);
        wait_for_lower_req_count(1, 1'b0, 1'b0, READ_ADDR0, first_lower_bypass_id);

        enqueue_read_expect_accept(READ_ADDR1, READ_ID1);

        mode_req = MODE_CACHE;
        assert_old_mode_hold(4);

        send_bypass_resp(first_lower_bypass_id, RESP_LINE0);
        wait_for_held_read_resp(READ_ID0, RESP_LINE0);
        assert_old_mode_hold(8);

        consume_held_read_resp(READ_ID0, RESP_LINE0);
        wait_for_lower_req_count(2, 1'b0, 1'b0, READ_ADDR1, second_lower_bypass_id);
        if (active_mode !== MODE_OFF) begin
            fail_now("queued read must dispatch before mode switch becomes visible");
        end

        send_bypass_resp(second_lower_bypass_id, RESP_LINE1);
        wait_for_read_resp_and_drain(READ_ID1, RESP_LINE1);

        wait_idle_mode(MODE_CACHE);
        if (invalidate_all_accept_count != 1) begin
            fail_now("mode switch should accept exactly one invalidate_all after drain");
        end
        if (cache_req_count != 0) begin
            fail_now("drained mode0 queue should never issue cache request");
        end
        if (bypass_req_count != 2) begin
            fail_now("both queued reads should drain through bypass");
        end
        if (config_error) begin
            fail_now("config_error asserted unexpectedly");
        end

        $display("tb_axi_llc_subsystem_compat_reconfig_drain_contract PASS");
        $finish(0);
    end

endmodule
