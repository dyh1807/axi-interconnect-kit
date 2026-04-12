`timescale 1ns / 1ps

module tb_axi_llc_subsystem_read_slice_contract;

    localparam ADDR_BITS        = 32;
    localparam ID_BITS          = 4;
    localparam MODE_BITS        = 2;
    localparam LINE_BYTES       = 8;
    localparam LINE_BITS        = 64;
    localparam LINE_OFFSET_BITS = 3;
    localparam SET_COUNT        = 4;
    localparam SET_BITS         = 2;
    localparam WAY_COUNT        = 4;
    localparam WAY_BITS         = 2;
    localparam META_BITS        = 24;
    localparam LLC_SIZE_BYTES   = LINE_BYTES * SET_COUNT * WAY_COUNT;
    localparam WINDOW_BYTES     = 64;
    localparam WINDOW_WAYS      = 2;
    localparam [MODE_BITS-1:0] MODE_OFF    = 2'b00;
    localparam [MODE_BITS-1:0] MODE_CACHE  = 2'b01;
    localparam [MODE_BITS-1:0] MODE_MAPPED = 2'b10;

    localparam [ADDR_BITS-1:0] CACHE_LINE_ADDR = 32'h0000_2000;
    localparam [ADDR_BITS-1:0] CACHE_READ_ADDR = 32'h0000_2004;
    localparam [ADDR_BITS-1:0] MAPPED_OFFSET   = 32'h0000_1000;
    localparam [ADDR_BITS-1:0] DIRECT_LINE_ADDR = 32'h0000_1000;
    localparam [ADDR_BITS-1:0] DIRECT_READ_ADDR = 32'h0000_1004;
    localparam [LINE_BITS-1:0] CACHE_LINE_DATA  = 64'hA1B2_C3D4_5566_7788;
    localparam [LINE_BITS-1:0] DIRECT_LINE_DATA = 64'hDEAD_BEEF_0123_4567;
    localparam [LINE_BITS-1:0] CACHE_PATCH_DATA = 64'h0000_0000_CAFE_FEED;
    localparam [LINE_BITS-1:0] DIRECT_PATCH_DATA = 64'h0000_0000_BAAD_F00D;
    localparam [LINE_BITS-1:0] SLICE_EXPECT_CACHE  = 64'h0000_0000_A1B2_C3D4;
    localparam [LINE_BITS-1:0] SLICE_EXPECT_DIRECT = 64'h0000_0000_DEAD_BEEF;
    localparam [LINE_BITS-1:0] SLICE_EXPECT_CACHE_PATCH  = 64'h0000_0000_CAFE_FEED;
    localparam [LINE_BITS-1:0] SLICE_EXPECT_DIRECT_PATCH = 64'h0000_0000_BAAD_F00D;

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

    reg                       cache_resp_pending_r;
    reg  [LINE_BITS-1:0]      cache_resp_pending_data_r;
    reg  [ID_BITS-1:0]        cache_resp_pending_id_r;
    reg  [LINE_BITS-1:0]      observed_rdata_r;

    integer                   cache_req_count;

    task fail_now;
        input [8*96-1:0] msg;
        begin
            $display("tb_axi_llc_subsystem_read_slice_contract FAIL: %0s", msg);
            $finish(1);
        end
    endtask

    task wait_idle_mode;
        input [MODE_BITS-1:0] expect_mode;
        input [ADDR_BITS-1:0] expect_offset;
        integer timeout;
        begin
            timeout = 0;
            while ((active_mode !== expect_mode) ||
                   ((expect_mode == MODE_MAPPED) &&
                    (active_offset !== expect_offset)) ||
                   reconfig_busy) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 200) begin
                    fail_now("timeout waiting active mode/offset");
                end
            end
            @(posedge clk);
            if ((active_mode !== expect_mode) ||
                ((expect_mode == MODE_MAPPED) &&
                 (active_offset !== expect_offset)) ||
                (reconfig_state !== 2'b00)) begin
                fail_now("active mode/offset mismatch after settle");
            end
        end
    endtask

    task issue_request;
        input                      is_write;
        input [ADDR_BITS-1:0]      addr_value;
        input [ID_BITS-1:0]        id_value;
        input [7:0]                total_size_value;
        input [LINE_BITS-1:0]      wdata_value;
        input [LINE_BYTES-1:0]     wstrb_value;
        integer                    timeout;
        begin
            up_req_valid      <= 1'b1;
            up_req_write      <= is_write;
            up_req_addr       <= addr_value;
            up_req_id         <= id_value;
            up_req_total_size <= total_size_value;
            up_req_wdata      <= wdata_value;
            up_req_wstrb      <= wstrb_value;
            up_req_bypass     <= 1'b0;

            timeout = 0;
            while (!up_req_ready) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 100) begin
                    fail_now("timeout waiting up_req_ready");
                end
            end

            @(posedge clk);
            up_req_valid      <= 1'b0;
            up_req_write      <= 1'b0;
            up_req_addr       <= {ADDR_BITS{1'b0}};
            up_req_id         <= {ID_BITS{1'b0}};
            up_req_total_size <= 8'd0;
            up_req_wdata      <= {LINE_BITS{1'b0}};
            up_req_wstrb      <= {LINE_BYTES{1'b0}};
        end
    endtask

    task wait_for_response;
        input [ID_BITS-1:0] expect_id;
        integer timeout;
        begin
            timeout = 0;
            while (!up_resp_valid) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 160) begin
                    fail_now("timeout waiting up_resp_valid");
                end
            end
            observed_rdata_r = up_resp_rdata;
            if (up_resp_id !== expect_id) begin
                fail_now("unexpected up_resp_id");
            end
            @(posedge clk);
            timeout = 0;
            while (up_resp_valid) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 32) begin
                    fail_now("response channel did not return idle");
                end
            end
        end
    endtask

    axi_llc_subsystem_top #(
        .ADDR_BITS        (ADDR_BITS),
        .RESET_MODE       (MODE_CACHE),
        .RESET_OFFSET     ({ADDR_BITS{1'b0}}),
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
        .WINDOW_WAYS      (WINDOW_WAYS),
        .MMIO_BASE        (32'hF000_0000),
        .MMIO_SIZE        (32'h0000_1000)
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

    always #5 clk = ~clk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cache_resp_valid <= 1'b0;
            cache_resp_rdata <= {LINE_BITS{1'b0}};
            cache_resp_id <= {ID_BITS{1'b0}};
            cache_resp_pending_r <= 1'b0;
            cache_resp_pending_data_r <= {LINE_BITS{1'b0}};
            cache_resp_pending_id_r <= {ID_BITS{1'b0}};
            cache_req_count <= 0;
        end else begin
            if (cache_resp_valid && cache_resp_ready) begin
                cache_resp_valid <= 1'b0;
                cache_resp_id <= {ID_BITS{1'b0}};
            end

            if (cache_resp_pending_r) begin
                cache_resp_valid <= 1'b1;
                cache_resp_rdata <= cache_resp_pending_data_r;
                cache_resp_id <= cache_resp_pending_id_r;
                cache_resp_pending_r <= 1'b0;
            end

            if (cache_req_valid && cache_req_ready) begin
                cache_req_count <= cache_req_count + 1;
                cache_resp_pending_r <= 1'b1;
                cache_resp_pending_id_r <= cache_req_id;
                if (cache_req_write) begin
                    cache_resp_pending_data_r <= {LINE_BITS{1'b0}};
                end else if (cache_req_addr == CACHE_LINE_ADDR) begin
                    cache_resp_pending_data_r <= CACHE_LINE_DATA;
                end else begin
                    cache_resp_pending_data_r <= {LINE_BITS{1'b0}};
                end
            end
        end
    end

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        mode_req = MODE_CACHE;
        llc_mapped_offset_req = {ADDR_BITS{1'b0}};
        up_req_valid = 1'b0;
        up_req_write = 1'b0;
        up_req_addr = {ADDR_BITS{1'b0}};
        up_req_id = {ID_BITS{1'b0}};
        up_req_total_size = 8'd0;
        up_req_wdata = {LINE_BITS{1'b0}};
        up_req_wstrb = {LINE_BYTES{1'b0}};
        up_req_bypass = 1'b0;
        up_resp_ready = 1'b1;
        cache_req_ready = 1'b1;
        cache_resp_valid = 1'b0;
        cache_resp_rdata = {LINE_BITS{1'b0}};
        cache_resp_id = {ID_BITS{1'b0}};
        bypass_req_ready = 1'b1;
        bypass_resp_valid = 1'b0;
        bypass_resp_rdata = {LINE_BITS{1'b0}};
        bypass_resp_id = {ID_BITS{1'b0}};
        invalidate_line_valid = 1'b0;
        invalidate_line_addr = {ADDR_BITS{1'b0}};
        invalidate_all_valid = 1'b0;
        cache_resp_pending_r = 1'b0;
        cache_resp_pending_data_r = {LINE_BITS{1'b0}};
        cache_resp_pending_id_r = {ID_BITS{1'b0}};
        observed_rdata_r = {LINE_BITS{1'b0}};
        cache_req_count = 0;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        wait_idle_mode(MODE_CACHE, {ADDR_BITS{1'b0}});

        issue_request(1'b0, CACHE_READ_ADDR, 4'h5, 8'd3, {LINE_BITS{1'b0}},
                      {LINE_BYTES{1'b0}});
        wait_for_response(4'h5);
        if (observed_rdata_r !== SLICE_EXPECT_CACHE) begin
            fail_now("mode1 refill response should slice by word offset");
        end
        if (cache_req_count !== 1) begin
            fail_now("mode1 first read should emit one refill");
        end

        issue_request(1'b0, CACHE_READ_ADDR, 4'h6, 8'd3, {LINE_BITS{1'b0}},
                      {LINE_BYTES{1'b0}});
        wait_for_response(4'h6);
        if (observed_rdata_r !== SLICE_EXPECT_CACHE) begin
            fail_now("mode1 hit response should slice by word offset");
        end
        if (cache_req_count !== 1) begin
            fail_now("mode1 hit must not emit second refill");
        end

        issue_request(1'b1, CACHE_READ_ADDR, 4'h9, 8'd3, CACHE_PATCH_DATA, 8'h0F);
        wait_for_response(4'h9);
        if (observed_rdata_r !== {LINE_BITS{1'b0}}) begin
            fail_now("mode1 unaligned write hit should return zero");
        end

        issue_request(1'b0, CACHE_READ_ADDR, 4'hA, 8'd3, {LINE_BITS{1'b0}},
                      {LINE_BYTES{1'b0}});
        wait_for_response(4'hA);
        if (observed_rdata_r !== SLICE_EXPECT_CACHE_PATCH) begin
            fail_now("mode1 unaligned write hit should merge at line offset");
        end

        mode_req = MODE_MAPPED;
        llc_mapped_offset_req = MAPPED_OFFSET;
        wait_idle_mode(MODE_MAPPED, MAPPED_OFFSET);

        issue_request(1'b1, DIRECT_LINE_ADDR, 4'h7, (LINE_BYTES - 1),
                      DIRECT_LINE_DATA, {LINE_BYTES{1'b1}});
        wait_for_response(4'h7);
        if (observed_rdata_r !== {LINE_BITS{1'b0}}) begin
            fail_now("mode2 direct full-line write should return zero");
        end

        issue_request(1'b0, DIRECT_READ_ADDR, 4'h8, 8'd3, {LINE_BITS{1'b0}},
                      {LINE_BYTES{1'b0}});
        wait_for_response(4'h8);
        if (observed_rdata_r !== SLICE_EXPECT_DIRECT) begin
            fail_now("mode2 direct read should slice by word offset");
        end

        issue_request(1'b1, DIRECT_READ_ADDR, 4'h9, 8'd3, DIRECT_PATCH_DATA, 8'h0F);
        wait_for_response(4'h9);
        if (observed_rdata_r !== {LINE_BITS{1'b0}}) begin
            fail_now("mode2 direct partial write should return zero");
        end

        issue_request(1'b0, DIRECT_READ_ADDR, 4'hA, 8'd3, {LINE_BITS{1'b0}},
                      {LINE_BYTES{1'b0}});
        wait_for_response(4'hA);
        if (observed_rdata_r !== SLICE_EXPECT_DIRECT_PATCH) begin
            fail_now("mode2 direct partial write should merge at line offset");
        end

        if (bypass_req_valid !== 1'b0) begin
            fail_now("mode2 in-window direct read should not use bypass");
        end

        $display("tb_axi_llc_subsystem_read_slice_contract PASS");
        $finish(0);
    end

endmodule
