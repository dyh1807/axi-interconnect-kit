`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_id_contract;

    localparam ADDR_BITS        = `AXI_LLC_ADDR_BITS;
    localparam ID_BITS          = `AXI_LLC_ID_BITS;
    localparam MODE_BITS        = `AXI_LLC_MODE_BITS;
    localparam LINE_BYTES       = `AXI_LLC_LINE_BYTES;
    localparam LINE_BITS        = `AXI_LLC_LINE_BITS;
    localparam LINE_OFFSET_BITS = `AXI_LLC_LINE_OFFSET_BITS;
    localparam SET_COUNT        = 2;
    localparam SET_BITS         = 1;
    localparam WAY_COUNT        = 2;
    localparam WAY_BITS         = 1;
    localparam META_BITS        = `AXI_LLC_META_BITS;
    localparam LLC_SIZE_BYTES   = LINE_BYTES * SET_COUNT * WAY_COUNT;
    localparam WINDOW_BYTES     = LINE_BYTES * SET_COUNT;
    localparam WINDOW_WAYS      = 1;

    localparam [MODE_BITS-1:0] MODE_OFF    = 2'b00;
    localparam [MODE_BITS-1:0] MODE_CACHE  = 2'b01;
    localparam [MODE_BITS-1:0] MODE_MAPPED = 2'b10;

    localparam [ADDR_BITS-1:0] CACHE_ADDR  = 32'h0000_0000;
    localparam [ADDR_BITS-1:0] BYPASS_ADDR = 32'h0000_0120;
    localparam [ADDR_BITS-1:0] DIRECT_BASE = 32'h0000_1000;
    localparam [ADDR_BITS-1:0] DIRECT_ADDR = 32'h0000_1040;

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
    wire [LINE_BITS-1:0]      up_resp_rdata;
    wire [ID_BITS-1:0]        up_resp_id;
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
    reg  [LINE_BITS-1:0]      cache_resp_rdata;
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
    reg  [LINE_BITS-1:0]      bypass_resp_rdata;
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

    integer                   cache_req_count;
    integer                   bypass_req_count;
    reg  [ID_BITS-1:0]        last_cache_req_id;
    reg  [ID_BITS-1:0]        last_bypass_req_id;
    reg  [ADDR_BITS-1:0]      last_cache_req_addr;
    reg  [ADDR_BITS-1:0]      last_bypass_req_addr;
    reg  [7:0]                last_cache_req_size;
    reg  [7:0]                last_bypass_req_size;
    reg  [LINE_BITS-1:0]      resp_line_tmp;
    reg  [ID_BITS-1:0]        resp_id_tmp;
    integer                   count_before;

    always #5 clk = ~clk;

    axi_llc_subsystem_top #(
        .ADDR_BITS        (ADDR_BITS),
        .ID_BITS          (ID_BITS),
        .MODE_BITS        (MODE_BITS),
        .LINE_BYTES       (LINE_BYTES),
        .LINE_BITS        (LINE_BITS),
        .LINE_OFFSET_BITS (LINE_OFFSET_BITS),
        .SET_COUNT        (SET_COUNT),
        .SET_BITS         (SET_BITS),
        .WAY_COUNT        (WAY_COUNT),
        .WAY_BITS         (WAY_BITS),
        .META_BITS        (META_BITS),
        .LLC_SIZE_BYTES   (LLC_SIZE_BYTES),
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
        .up_req_id             (up_req_id),
        .up_req_total_size     (up_req_total_size),
        .up_req_wdata          (up_req_wdata),
        .up_req_wstrb          (up_req_wstrb),
        .up_req_bypass         (up_req_bypass),
        .up_resp_valid         (up_resp_valid),
        .up_resp_ready         (up_resp_ready),
        .up_resp_rdata         (up_resp_rdata),
        .up_resp_id            (up_resp_id),
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
            cache_req_count    <= 0;
            bypass_req_count   <= 0;
            last_cache_req_id  <= {ID_BITS{1'b0}};
            last_bypass_req_id <= {ID_BITS{1'b0}};
            last_cache_req_addr <= {ADDR_BITS{1'b0}};
            last_bypass_req_addr <= {ADDR_BITS{1'b0}};
            last_cache_req_size <= 8'd0;
            last_bypass_req_size <= 8'd0;
        end else begin
            if (cache_req_valid && cache_req_ready) begin
                cache_req_count    <= cache_req_count + 1;
                last_cache_req_id  <= cache_req_id;
                last_cache_req_addr <= cache_req_addr;
                last_cache_req_size <= cache_req_size;
            end
            if (bypass_req_valid && bypass_req_ready) begin
                bypass_req_count    <= bypass_req_count + 1;
                last_bypass_req_id  <= bypass_req_id;
                last_bypass_req_addr <= bypass_req_addr;
                last_bypass_req_size <= bypass_req_size;
            end
        end
    end

    task fail_now;
        input [8*128-1:0] msg;
        begin
            $display("tb_axi_llc_subsystem_id_contract FAIL: %0s", msg);
            $finish(1);
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
            timeout = 100;
            while (((active_mode !== expect_mode) ||
                    (active_offset !== expect_offset) ||
                    reconfig_busy) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting for requested mode");
            end
            if (reconfig_state !== 2'b00) begin
                fail_now("reconfig_state should return to idle");
            end
        end
    endtask

    task issue_request;
        input                      req_write_value;
        input [ADDR_BITS-1:0]      req_addr_value;
        input [ID_BITS-1:0]        req_id_value;
        input [7:0]                req_total_size_value;
        input [LINE_BITS-1:0]      req_wdata_value;
        input [LINE_BYTES-1:0]     req_wstrb_value;
        input                      req_bypass_value;
        integer timeout;
        reg     handshake_seen;
        begin
            up_req_write      = req_write_value;
            up_req_addr       = req_addr_value;
            up_req_id         = req_id_value;
            up_req_total_size = req_total_size_value;
            up_req_wdata      = req_wdata_value;
            up_req_wstrb      = req_wstrb_value;
            up_req_bypass     = req_bypass_value;
            up_req_valid      = 1'b1;
            timeout = 100;
            handshake_seen = 1'b0;
            while (!handshake_seen && (timeout > 0)) begin
                @(posedge clk);
                if (up_req_valid && up_req_ready) begin
                    handshake_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting for upstream request handshake");
            end
            @(negedge clk);
            up_req_valid      = 1'b0;
            up_req_write      = 1'b0;
            up_req_addr       = {ADDR_BITS{1'b0}};
            up_req_id         = {ID_BITS{1'b0}};
            up_req_total_size = 8'd0;
            up_req_wdata      = {LINE_BITS{1'b0}};
            up_req_wstrb      = {LINE_BYTES{1'b0}};
            up_req_bypass     = 1'b0;
        end
    endtask

    task wait_for_cache_request;
        input integer           start_count;
        input [ADDR_BITS-1:0] expect_addr;
        input [ID_BITS-1:0]   expect_id;
        integer timeout;
        begin
            timeout = 100;
            while ((cache_req_count == start_count) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting for cache lower request");
            end
            #1;
            if (last_cache_req_addr !== expect_addr) begin
                fail_now("cache lower request address mismatch");
            end
            if (last_cache_req_id !== expect_id) begin
                fail_now("cache lower request id mismatch");
            end
            if (last_cache_req_size !== 8'd63) begin
                fail_now("cache lower request size mismatch");
            end
        end
    endtask

    task wait_for_bypass_request;
        input integer           start_count;
        input [ADDR_BITS-1:0] expect_addr;
        input [ID_BITS-1:0]   expect_id;
        integer timeout;
        begin
            timeout = 100;
            while ((bypass_req_count == start_count) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting for bypass lower request");
            end
            #1;
            if (last_bypass_req_addr !== expect_addr) begin
                fail_now("bypass lower request address mismatch");
            end
            if (last_bypass_req_id !== expect_id) begin
                fail_now("bypass lower request id mismatch");
            end
            if (last_bypass_req_size !== 8'd7) begin
                fail_now("bypass lower request size mismatch");
            end
        end
    endtask

    task hold_wrong_cache_response;
        input [ID_BITS-1:0]   wrong_id;
        input [LINE_BITS-1:0] resp_data;
        input integer         cycles;
        integer i;
        begin
            cache_resp_valid = 1'b1;
            cache_resp_id    = wrong_id;
            cache_resp_rdata = resp_data;
            for (i = 0; i < cycles; i = i + 1) begin
                @(posedge clk);
                #1;
                if (cache_resp_ready !== 1'b0) begin
                    fail_now("cache wrong-id response should not be consumed");
                end
                if (up_resp_valid !== 1'b0) begin
                    fail_now("cache wrong-id response leaked to upstream");
                end
            end
            cache_resp_valid = 1'b0;
            cache_resp_id    = {ID_BITS{1'b0}};
            cache_resp_rdata = {LINE_BITS{1'b0}};
        end
    endtask

    task hold_wrong_bypass_response;
        input [ID_BITS-1:0]   wrong_id;
        input [LINE_BITS-1:0] resp_data;
        input integer         cycles;
        integer i;
        begin
            bypass_resp_valid = 1'b1;
            bypass_resp_id    = wrong_id;
            bypass_resp_rdata = resp_data;
            for (i = 0; i < cycles; i = i + 1) begin
                @(posedge clk);
                #1;
                if (bypass_resp_ready !== 1'b0) begin
                    fail_now("bypass wrong-id response should not be consumed");
                end
                if (up_resp_valid !== 1'b0) begin
                    fail_now("bypass wrong-id response leaked to upstream");
                end
            end
            bypass_resp_valid = 1'b0;
            bypass_resp_id    = {ID_BITS{1'b0}};
            bypass_resp_rdata = {LINE_BITS{1'b0}};
        end
    endtask

    task send_cache_response;
        input [ID_BITS-1:0]   resp_id_value;
        input [LINE_BITS-1:0] resp_data_value;
        integer timeout;
        begin
            cache_resp_valid = 1'b1;
            cache_resp_id    = resp_id_value;
            cache_resp_rdata = resp_data_value;
            timeout = 20;
            while ((cache_resp_ready !== 1'b1) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting for cache response consume");
            end
            @(posedge clk);
            cache_resp_valid = 1'b0;
            cache_resp_id    = {ID_BITS{1'b0}};
            cache_resp_rdata = {LINE_BITS{1'b0}};
        end
    endtask

    task send_bypass_response;
        input [ID_BITS-1:0]   resp_id_value;
        input [LINE_BITS-1:0] resp_data_value;
        integer timeout;
        begin
            bypass_resp_valid = 1'b1;
            bypass_resp_id    = resp_id_value;
            bypass_resp_rdata = resp_data_value;
            timeout = 20;
            while ((bypass_resp_ready !== 1'b1) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting for bypass response consume");
            end
            @(posedge clk);
            bypass_resp_valid = 1'b0;
            bypass_resp_id    = {ID_BITS{1'b0}};
            bypass_resp_rdata = {LINE_BITS{1'b0}};
        end
    endtask

    task wait_for_upstream_response;
        input [ID_BITS-1:0]   expect_id;
        input [LINE_BITS-1:0] expect_data;
        integer timeout;
        begin
            timeout = 100;
            while (!up_resp_valid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting for upstream response");
            end
            resp_line_tmp = up_resp_rdata;
            resp_id_tmp   = up_resp_id;
            if (resp_id_tmp !== expect_id) begin
                fail_now("upstream response id mismatch");
            end
            if (resp_line_tmp !== expect_data) begin
                fail_now("upstream response data mismatch");
            end
            @(posedge clk);
        end
    endtask

    initial begin
        clk                   = 1'b0;
        rst_n                 = 1'b0;
        mode_req              = MODE_CACHE;
        llc_mapped_offset_req = {ADDR_BITS{1'b0}};
        up_req_valid          = 1'b0;
        up_req_write          = 1'b0;
        up_req_addr           = {ADDR_BITS{1'b0}};
        up_req_id             = {ID_BITS{1'b0}};
        up_req_total_size     = 8'd0;
        up_req_wdata          = {LINE_BITS{1'b0}};
        up_req_wstrb          = {LINE_BYTES{1'b0}};
        up_req_bypass         = 1'b0;
        up_resp_ready         = 1'b1;
        cache_req_ready       = 1'b1;
        cache_resp_valid      = 1'b0;
        cache_resp_rdata      = {LINE_BITS{1'b0}};
        cache_resp_id         = {ID_BITS{1'b0}};
        bypass_req_ready      = 1'b1;
        bypass_resp_valid     = 1'b0;
        bypass_resp_rdata     = {LINE_BITS{1'b0}};
        bypass_resp_id        = {ID_BITS{1'b0}};
        invalidate_line_valid = 1'b0;
        invalidate_line_addr  = {ADDR_BITS{1'b0}};
        invalidate_all_valid  = 1'b0;

        wait_cycles(5);
        rst_n = 1'b1;

        wait_idle_mode(MODE_CACHE, 32'h0000_0000);
        if (config_error !== 1'b0) begin
            fail_now("config_error should stay low after reset");
        end

        mode_req              = MODE_MAPPED;
        llc_mapped_offset_req = DIRECT_BASE;
        wait_idle_mode(MODE_MAPPED, DIRECT_BASE);

        $display("STEP direct id contract");
        count_before = cache_req_count + bypass_req_count;
        issue_request(1'b1, DIRECT_ADDR, 4'h5, 8'd7,
                      64'hA5A5_5A5A_1234_5678, {LINE_BYTES{1'b1}}, 1'b0);
        wait_for_upstream_response(4'h5, {LINE_BITS{1'b0}});
        if ((cache_req_count + bypass_req_count) !== count_before) begin
            fail_now("direct write should not create lower traffic");
        end

        count_before = cache_req_count + bypass_req_count;
        issue_request(1'b0, DIRECT_ADDR, 4'hA, 8'd7, {LINE_BITS{1'b0}}, {LINE_BYTES{1'b0}}, 1'b0);
        wait_for_upstream_response(4'hA, 64'hA5A5_5A5A_1234_5678);
        if ((cache_req_count + bypass_req_count) !== count_before) begin
            fail_now("direct read should not create lower traffic");
        end

        mode_req = MODE_OFF;
        wait_idle_mode(MODE_OFF, DIRECT_BASE);

        $display("STEP bypass id contract");
        count_before = bypass_req_count;
        issue_request(1'b0, BYPASS_ADDR, 4'h9, 8'd7, {LINE_BITS{1'b0}}, {LINE_BYTES{1'b0}}, 1'b0);
        wait_for_bypass_request(count_before, BYPASS_ADDR, 4'h9);
        hold_wrong_bypass_response(4'h8, 64'hDEAD_BEEF_0000_0001, 2);
        send_bypass_response(4'h9, 64'hDEAD_BEEF_0000_0002);
        wait_for_upstream_response(4'h9, 64'hDEAD_BEEF_0000_0002);

        mode_req              = MODE_CACHE;
        llc_mapped_offset_req = {ADDR_BITS{1'b0}};
        wait_idle_mode(MODE_CACHE, DIRECT_BASE);

        $display("STEP cache id contract");
        count_before = cache_req_count;
        issue_request(1'b0, CACHE_ADDR, 4'h3, 8'd7, {LINE_BITS{1'b0}}, {LINE_BYTES{1'b0}}, 1'b0);
        wait_for_cache_request(count_before, CACHE_ADDR, 4'h3);
        hold_wrong_cache_response(4'h2, 64'hCAFE_F00D_CAFE_F00D, 2);
        send_cache_response(4'h3, 64'h1122_3344_5566_7788);
        wait_for_upstream_response(4'h3, 64'h1122_3344_5566_7788);

        count_before = cache_req_count;
        issue_request(1'b0, CACHE_ADDR, 4'h4, 8'd7, {LINE_BITS{1'b0}}, {LINE_BYTES{1'b0}}, 1'b0);
        wait_for_upstream_response(4'h4, 64'h1122_3344_5566_7788);
        if (cache_req_count !== count_before) begin
            fail_now("cache hit should not create a new lower request");
        end

        if (last_cache_req_id !== 4'h3) begin
            fail_now("cache lower request id tracking mismatch");
        end
        if (last_bypass_req_id !== 4'h9) begin
            fail_now("bypass lower request id tracking mismatch");
        end

        $display("tb_axi_llc_subsystem_id_contract PASS");
        $finish(0);
    end

endmodule
