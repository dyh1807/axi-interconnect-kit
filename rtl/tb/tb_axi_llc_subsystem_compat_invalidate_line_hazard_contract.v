`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_compat_invalidate_line_hazard_contract;

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

    localparam [MODE_BITS-1:0] MODE_CACHE = 2'b01;
    localparam [ADDR_BITS-1:0] LINE_ADDR  = 32'h0000_03C0;
    localparam [ADDR_BITS-1:0] WRITE_ADDR0 = LINE_ADDR + 32'h4;
    localparam [ADDR_BITS-1:0] WRITE_ADDR1 = LINE_ADDR + 32'h4;
    localparam [ID_BITS-1:0]   WRITE_ID0   = 4'h5;
    localparam [ID_BITS-1:0]   WRITE_ID1   = 4'h6;

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
    integer                               cache_req_count;
    integer                               bypass_req_count;
    reg                                   last_req_is_cache;
    reg                                   last_req_is_write;
    reg  [ADDR_BITS-1:0]                  last_req_addr;
    reg  [ID_BITS-1:0]                    last_req_id;

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
            cache_req_count <= 0;
            bypass_req_count <= 0;
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
        .RESET_MODE        (MODE_CACHE),
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
            $display("tb_axi_llc_subsystem_compat_invalidate_line_hazard_contract FAIL: %0s", msg);
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

    task wait_mode_cache_active;
        integer timeout;
        begin
            timeout = 200;
            while (((active_mode !== MODE_CACHE) || reconfig_busy) &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting mode=1 active");
            end
            if (active_offset !== {ADDR_BITS{1'b0}}) begin
                fail_now("active offset should stay zero");
            end
            if (reconfig_state !== 2'b00) begin
                fail_now("reconfig state should settle back to idle");
            end
        end
    endtask

    task issue_write_expect_accept;
        input [ADDR_BITS-1:0]  addr_value;
        input [ID_BITS-1:0]    id_value;
        input [LINE_BITS-1:0]  data_value;
        input [LINE_BYTES-1:0] strb_value;
        integer timeout;
        reg accepted_seen;
        begin
            @(negedge clk);
            write_req_valid[0] = 1'b1;
            write_req_addr[ADDR_BITS-1:0] = addr_value;
            write_req_total_size[7:0] = LINE_BYTES - 1;
            write_req_id[ID_BITS-1:0] = id_value;
            write_req_wdata[LINE_BITS-1:0] = data_value;
            write_req_wstrb[LINE_BYTES-1:0] = strb_value;
            write_req_bypass[0] = 1'b0;
            timeout = 100;
            while (!write_req_ready[0] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting write_req_ready");
            end
            #1;
            accepted_seen = (write_req_accepted[0] === 1'b1);
            timeout = 100;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[0] === 1'b1) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("write_req_accepted pulse missing");
            end
            @(negedge clk);
            write_req_valid[0] = 1'b0;
            write_req_addr[ADDR_BITS-1:0] = {ADDR_BITS{1'b0}};
            write_req_total_size[7:0] = 8'd0;
            write_req_id[ID_BITS-1:0] = {ID_BITS{1'b0}};
            write_req_wdata[LINE_BITS-1:0] = {LINE_BITS{1'b0}};
            write_req_wstrb[LINE_BYTES-1:0] = {LINE_BYTES{1'b0}};
            write_req_bypass[0] = 1'b0;
            @(posedge clk);
            #1;
            if (write_req_accepted !== {NUM_WRITE_MASTERS{1'b0}}) begin
                fail_now("write_req_accepted should clear after one cycle");
            end
        end
    endtask

    task wait_for_lower_req_count;
        input integer         expect_count;
        input                 exp_is_cache;
        input                 exp_is_write;
        input [ADDR_BITS-1:0] exp_addr;
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
        end
    endtask

    task hold_invalidate_line_expect_reject;
        input integer         hold_cycles;
        input [8*160-1:0]     msg;
        integer idx;
        begin
            @(negedge clk);
            invalidate_line_valid = 1'b1;
            invalidate_line_addr = LINE_ADDR;
            #1;
            if (invalidate_line_accepted !== 1'b0) begin
                fail_now(msg);
            end
            for (idx = 0; idx < hold_cycles; idx = idx + 1) begin
                @(negedge clk);
                #1;
                if (invalidate_line_accepted !== 1'b0) begin
                    fail_now(msg);
                end
            end
            @(negedge clk);
            invalidate_line_valid = 1'b0;
            invalidate_line_addr = {ADDR_BITS{1'b0}};
        end
    endtask

    task send_cache_write_resp;
        input [ID_BITS-1:0] resp_id_value;
        begin
            @(negedge clk);
            cache_resp_valid = 1'b1;
            cache_resp_id = resp_id_value;
            cache_resp_rdata = {READ_RESP_BITS{1'b0}};
            cache_resp_code = 2'b00;
            @(posedge clk);
            @(negedge clk);
            cache_resp_valid = 1'b0;
            cache_resp_id = {ID_BITS{1'b0}};
            cache_resp_rdata = {READ_RESP_BITS{1'b0}};
            cache_resp_code = 2'b00;
        end
    endtask

    task wait_for_held_write_resp;
        input [ID_BITS-1:0] exp_id;
        integer timeout;
        begin
            timeout = 100;
            while (!write_resp_valid[0] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting held write response");
            end
            if (get_write_resp_id(0) !== exp_id) begin
                fail_now("held write response id mismatch");
            end
            if (get_write_resp_code(0) !== 2'b00) begin
                fail_now("held write response code mismatch");
            end
            if (write_resp_ready[0] !== 1'b0) begin
                fail_now("held write response phase requires write_resp_ready low");
            end
        end
    endtask

    task consume_held_write_resp;
        input [ID_BITS-1:0] exp_id;
        begin
            if (!write_resp_valid[0]) begin
                fail_now("cannot consume missing held write response");
            end
            if (get_write_resp_id(0) !== exp_id) begin
                fail_now("held write response id changed before consume");
            end
            @(negedge clk);
            write_resp_ready[0] = 1'b1;
            @(posedge clk);
            #1;
            if (write_resp_valid[0] !== 1'b0) begin
                fail_now("held write response should clear after consume");
            end
        end
    endtask

    task wait_for_write_resp_and_drain;
        input [ID_BITS-1:0] exp_id;
        integer timeout;
        begin
            timeout = 100;
            while (!write_resp_valid[0] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting drained write response");
            end
            if (get_write_resp_id(0) !== exp_id) begin
                fail_now("drained write response id mismatch");
            end
            if (get_write_resp_code(0) !== 2'b00) begin
                fail_now("drained write response code mismatch");
            end
            @(negedge clk);
            write_resp_ready[0] = 1'b1;
            @(posedge clk);
            #1;
            if (write_resp_valid[0] !== 1'b0) begin
                fail_now("drained write response should clear after ready");
            end
        end
    endtask

    task issue_invalidate_line_expect_accept;
        integer timeout;
        begin
            @(negedge clk);
            invalidate_line_valid = 1'b1;
            invalidate_line_addr = LINE_ADDR;
            timeout = 100;
            while (!invalidate_line_accepted && (timeout > 0)) begin
                @(negedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("invalidate_line should accept after write hazard drains");
            end
            @(negedge clk);
            invalidate_line_valid = 1'b0;
            invalidate_line_addr = {ADDR_BITS{1'b0}};
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        mode_req = MODE_CACHE;
        llc_mapped_offset_req = {ADDR_BITS{1'b0}};
        clear_read_inputs();
        clear_write_inputs();
        read_resp_ready = {NUM_READ_MASTERS{1'b1}};
        write_resp_ready = {NUM_WRITE_MASTERS{1'b0}};
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

        wait_cycles(4);
        rst_n = 1'b1;
        wait_mode_cache_active();

        issue_write_expect_accept(WRITE_ADDR0,
                                  WRITE_ID0,
                                  64'hAAAA_AAAA_5555_5555,
                                  8'h0F);
        wait_for_lower_req_count(1, 1'b1, 1'b0, LINE_ADDR);

        issue_write_expect_accept(WRITE_ADDR1,
                                  WRITE_ID1,
                                  64'h1234_5678_9ABC_DEF0,
                                  8'hFF);

        hold_invalidate_line_expect_reject(
            4,
            "same-line invalidate accepted while write was inflight"
        );

        send_cache_write_resp(last_req_id);
        wait_for_held_write_resp(WRITE_ID0);

        hold_invalidate_line_expect_reject(
            6,
            "same-line invalidate accepted while same-line write stayed queued"
        );

        consume_held_write_resp(WRITE_ID0);
        wait_cycles(10);
        if (write_resp_valid[0] !== 1'b0) begin
            fail_now("second same-line write should drain before final invalidate");
        end
        issue_invalidate_line_expect_accept();

        if (cache_req_count != 1) begin
            fail_now("expected exactly one cache lower request from the first partial miss");
        end
        if (bypass_req_count != 0) begin
            fail_now("write hazard bench should not emit bypass requests");
        end
        if (config_error) begin
            fail_now("config_error asserted unexpectedly");
        end

        $display("tb_axi_llc_subsystem_compat_invalidate_line_hazard_contract PASS");
        $finish(0);
    end

endmodule
