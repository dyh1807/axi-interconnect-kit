`timescale 1ns / 1ps

module tb_axi_llc_subsystem_size_contract;

    localparam ADDR_BITS        = 32;
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

    localparam [ADDR_BITS-1:0] MAPPED_OFFSET = 32'h0000_1000;
    localparam [ADDR_BITS-1:0] CACHE_ADDR_A  = 32'h0000_2000;
    localparam [ADDR_BITS-1:0] CACHE_ADDR_B  = 32'h0000_2008;

    reg                       clk;
    reg                       rst_n;
    reg  [MODE_BITS-1:0]      mode_req;
    reg  [ADDR_BITS-1:0]      llc_mapped_offset_req;
    reg                       up_req_valid;
    wire                      up_req_ready;
    reg                       up_req_write;
    reg  [ADDR_BITS-1:0]      up_req_addr;
    reg  [7:0]                up_req_total_size;
    reg  [LINE_BITS-1:0]      up_req_wdata;
    reg  [LINE_BYTES-1:0]     up_req_wstrb;
    reg                       up_req_bypass;
    wire                      up_resp_valid;
    reg                       up_resp_ready;
    wire [LINE_BITS-1:0]      up_resp_rdata;
    wire                      cache_req_valid;
    reg                       cache_req_ready;
    wire                      cache_req_write;
    wire [ADDR_BITS-1:0]      cache_req_addr;
    wire [7:0]                cache_req_size;
    wire [LINE_BITS-1:0]      cache_req_wdata;
    wire [LINE_BYTES-1:0]     cache_req_wstrb;
    reg                       cache_resp_valid;
    wire                      cache_resp_ready;
    reg  [LINE_BITS-1:0]      cache_resp_rdata;
    wire                      bypass_req_valid;
    reg                       bypass_req_ready;
    wire                      bypass_req_write;
    wire [ADDR_BITS-1:0]      bypass_req_addr;
    wire [7:0]                bypass_req_size;
    wire [LINE_BITS-1:0]      bypass_req_wdata;
    wire [LINE_BYTES-1:0]     bypass_req_wstrb;
    reg                       bypass_resp_valid;
    wire                      bypass_resp_ready;
    reg  [LINE_BITS-1:0]      bypass_resp_rdata;
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
    reg                       bypass_resp_pending_r;
    reg  [LINE_BITS-1:0]      bypass_resp_pending_data_r;

    integer                   cache_req_count;
    integer                   cache_read_count;
    integer                   cache_write_count;
    integer                   bypass_req_count;
    reg                       last_cache_write;
    reg  [ADDR_BITS-1:0]      last_cache_addr;
    reg  [7:0]                last_cache_size;
    reg                       last_bypass_write;
    reg  [ADDR_BITS-1:0]      last_bypass_addr;
    reg  [7:0]                last_bypass_size;
    reg  [LINE_BITS-1:0]      tmp_rdata;

    function [ADDR_BITS-1:0] line_align_addr;
        input [ADDR_BITS-1:0] addr_value;
        begin
            line_align_addr = {addr_value[ADDR_BITS-1:LINE_OFFSET_BITS],
                               {LINE_OFFSET_BITS{1'b0}}};
        end
    endfunction

    function [LINE_BITS-1:0] make_cache_line;
        input [ADDR_BITS-1:0] addr_value;
        integer byte_idx;
        begin
            make_cache_line = {LINE_BITS{1'b0}};
            for (byte_idx = 0; byte_idx < LINE_BYTES; byte_idx = byte_idx + 1) begin
                make_cache_line[(byte_idx * 8) +: 8] = addr_value[7:0] + byte_idx[7:0];
            end
        end
    endfunction

    function [LINE_BITS-1:0] make_bypass_line;
        input [ADDR_BITS-1:0] addr_value;
        begin
            make_bypass_line = 64'hB1A5_5500_0000_0000 ^ {32'h0, addr_value};
        end
    endfunction

    task fail_now;
        input [8*96-1:0] msg;
        begin
            $display("tb_axi_llc_subsystem_size_contract FAIL: %0s", msg);
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
        input [7:0]                total_size_value;
        input [LINE_BITS-1:0]      wdata_value;
        input [LINE_BYTES-1:0]     wstrb_value;
        input                      bypass_value;
        integer                    timeout;
        begin
            up_req_valid      <= 1'b1;
            up_req_write      <= is_write;
            up_req_addr       <= addr_value;
            up_req_total_size <= total_size_value;
            up_req_wdata      <= wdata_value;
            up_req_wstrb      <= wstrb_value;
            up_req_bypass     <= bypass_value;

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
            up_req_total_size <= 8'd0;
            up_req_wdata      <= {LINE_BITS{1'b0}};
            up_req_wstrb      <= {LINE_BYTES{1'b0}};
            up_req_bypass     <= 1'b0;
        end
    endtask

    task wait_for_response;
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
            tmp_rdata = up_resp_rdata;
            @(posedge clk);
            timeout = 0;
            while (up_resp_valid) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 32) begin
                    fail_now("response channel did not return to idle");
                end
            end
        end
    endtask

    axi_llc_subsystem_top #(
        .ADDR_BITS        (ADDR_BITS),
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
        .up_req_total_size     (up_req_total_size),
        .up_req_wdata          (up_req_wdata),
        .up_req_wstrb          (up_req_wstrb),
        .up_req_bypass         (up_req_bypass),
        .up_resp_valid         (up_resp_valid),
        .up_resp_ready         (up_resp_ready),
        .up_resp_rdata         (up_resp_rdata),
        .cache_req_valid       (cache_req_valid),
        .cache_req_ready       (cache_req_ready),
        .cache_req_write       (cache_req_write),
        .cache_req_addr        (cache_req_addr),
        .cache_req_size        (cache_req_size),
        .cache_req_wdata       (cache_req_wdata),
        .cache_req_wstrb       (cache_req_wstrb),
        .cache_resp_valid      (cache_resp_valid),
        .cache_resp_ready      (cache_resp_ready),
        .cache_resp_rdata      (cache_resp_rdata),
        .bypass_req_valid      (bypass_req_valid),
        .bypass_req_ready      (bypass_req_ready),
        .bypass_req_write      (bypass_req_write),
        .bypass_req_addr       (bypass_req_addr),
        .bypass_req_size       (bypass_req_size),
        .bypass_req_wdata      (bypass_req_wdata),
        .bypass_req_wstrb      (bypass_req_wstrb),
        .bypass_resp_valid     (bypass_resp_valid),
        .bypass_resp_ready     (bypass_resp_ready),
        .bypass_resp_rdata     (bypass_resp_rdata),
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
            bypass_resp_valid <= 1'b0;
            bypass_resp_rdata <= {LINE_BITS{1'b0}};
            cache_resp_pending_r <= 1'b0;
            cache_resp_pending_data_r <= {LINE_BITS{1'b0}};
            bypass_resp_pending_r <= 1'b0;
            bypass_resp_pending_data_r <= {LINE_BITS{1'b0}};
            cache_req_count <= 0;
            cache_read_count <= 0;
            cache_write_count <= 0;
            bypass_req_count <= 0;
            last_cache_write <= 1'b0;
            last_cache_addr <= {ADDR_BITS{1'b0}};
            last_cache_size <= 8'd0;
            last_bypass_write <= 1'b0;
            last_bypass_addr <= {ADDR_BITS{1'b0}};
            last_bypass_size <= 8'd0;
        end else begin
            if (cache_resp_valid && cache_resp_ready) begin
                cache_resp_valid <= 1'b0;
            end
            if (bypass_resp_valid && bypass_resp_ready) begin
                bypass_resp_valid <= 1'b0;
            end

            if (cache_resp_pending_r) begin
                cache_resp_valid <= 1'b1;
                cache_resp_rdata <= cache_resp_pending_data_r;
                cache_resp_pending_r <= 1'b0;
            end
            if (bypass_resp_pending_r) begin
                bypass_resp_valid <= 1'b1;
                bypass_resp_rdata <= bypass_resp_pending_data_r;
                bypass_resp_pending_r <= 1'b0;
            end

            if (cache_req_valid && cache_req_ready) begin
                cache_req_count <= cache_req_count + 1;
                last_cache_write <= cache_req_write;
                last_cache_addr <= cache_req_addr;
                last_cache_size <= cache_req_size;
                cache_resp_pending_r <= 1'b1;
                if (cache_req_write) begin
                    cache_write_count <= cache_write_count + 1;
                    cache_resp_pending_data_r <= {LINE_BITS{1'b0}};
                end else begin
                    cache_read_count <= cache_read_count + 1;
                    cache_resp_pending_data_r <= make_cache_line(cache_req_addr);
                end
            end

            if (bypass_req_valid && bypass_req_ready) begin
                bypass_req_count <= bypass_req_count + 1;
                last_bypass_write <= bypass_req_write;
                last_bypass_addr <= bypass_req_addr;
                last_bypass_size <= bypass_req_size;
                bypass_resp_pending_r <= 1'b1;
                bypass_resp_pending_data_r <= make_bypass_line(bypass_req_addr);
            end
        end
    end

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        mode_req = MODE_OFF;
        llc_mapped_offset_req = {ADDR_BITS{1'b0}};
        up_req_valid = 1'b0;
        up_req_write = 1'b0;
        up_req_addr = {ADDR_BITS{1'b0}};
        up_req_total_size = 8'd0;
        up_req_wdata = {LINE_BITS{1'b0}};
        up_req_wstrb = {LINE_BYTES{1'b0}};
        up_req_bypass = 1'b0;
        up_resp_ready = 1'b1;
        cache_req_ready = 1'b1;
        cache_resp_valid = 1'b0;
        cache_resp_rdata = {LINE_BITS{1'b0}};
        bypass_req_ready = 1'b1;
        bypass_resp_valid = 1'b0;
        bypass_resp_rdata = {LINE_BITS{1'b0}};
        invalidate_line_valid = 1'b0;
        invalidate_line_addr = {ADDR_BITS{1'b0}};
        invalidate_all_valid = 1'b0;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        if (config_error !== 1'b0) begin
            fail_now("config_error should stay low");
        end

        mode_req = MODE_MAPPED;
        llc_mapped_offset_req = MAPPED_OFFSET;
        wait_idle_mode(MODE_MAPPED, MAPPED_OFFSET);

        issue_request(1'b0,
                      MAPPED_OFFSET + 32'h0000_0038,
                      8'd7,
                      {LINE_BITS{1'b0}},
                      {LINE_BYTES{1'b0}},
                      1'b0);
        wait_for_response;
        if (tmp_rdata !== {LINE_BITS{1'b0}}) begin
            fail_now("mode2 in-window invalid read should return zero");
        end
        if ((cache_req_count !== 0) || (bypass_req_count !== 0)) begin
            fail_now("mode2 fully in-window request should stay on direct path");
        end

        issue_request(1'b0,
                      MAPPED_OFFSET + 32'h0000_0039,
                      8'd7,
                      {LINE_BITS{1'b0}},
                      {LINE_BYTES{1'b0}},
                      1'b0);
        wait_for_response;
        if (tmp_rdata !== make_bypass_line(MAPPED_OFFSET + 32'h0000_0039)) begin
            fail_now("cross-window request should return bypass data");
        end
        if (cache_req_count !== 0) begin
            fail_now("cross-window request must not route to cache");
        end
        if (bypass_req_count !== 1) begin
            fail_now("cross-window request should emit exactly one bypass request");
        end
        if (last_bypass_addr !== (MAPPED_OFFSET + 32'h0000_0039)) begin
            fail_now("bypass address mismatch on cross-window request");
        end
        if (last_bypass_size !== 8'd7) begin
            fail_now("bypass size should equal upstream total_size");
        end

        mode_req = MODE_CACHE;
        llc_mapped_offset_req = {ADDR_BITS{1'b0}};
        wait_idle_mode(MODE_CACHE, 32'h0000_0000);

        issue_request(1'b0,
                      CACHE_ADDR_A,
                      8'd3,
                      {LINE_BITS{1'b0}},
                      {LINE_BYTES{1'b0}},
                      1'b0);
        wait_for_response;
        if (tmp_rdata !== make_cache_line(line_align_addr(CACHE_ADDR_A))) begin
            fail_now("mode1 read miss response mismatch");
        end
        if (cache_req_count !== 1) begin
            fail_now("mode1 first read miss should emit one cache request");
        end
        if (cache_read_count !== 1) begin
            fail_now("mode1 first miss should emit one cache read");
        end
        if (cache_write_count !== 0) begin
            fail_now("mode1 first miss should not emit writeback");
        end
        if (last_cache_write !== 1'b0) begin
            fail_now("mode1 miss request should be read");
        end
        if (last_cache_addr !== line_align_addr(CACHE_ADDR_A)) begin
            fail_now("mode1 miss request address should be line aligned");
        end
        if (last_cache_size !== (LINE_BYTES - 1)) begin
            fail_now("mode1 miss request size should be line_bytes-1");
        end

        issue_request(1'b1,
                      CACHE_ADDR_B,
                      8'd7,
                      64'h1122_3344_5566_7788,
                      {LINE_BYTES{1'b1}},
                      1'b0);
        wait_for_response;
        if (tmp_rdata !== {LINE_BITS{1'b0}}) begin
            fail_now("full-line write miss should return zero");
        end
        repeat (12) @(posedge clk);
        if (cache_req_count !== 1) begin
            fail_now("full-line write miss should not emit external refill read");
        end
        if (cache_read_count !== 1) begin
            fail_now("full-line write miss changed read request count");
        end
        if (cache_write_count !== 0) begin
            fail_now("full-line write miss should not emit external write");
        end
        if (bypass_req_count !== 1) begin
            fail_now("full-line write miss should not use bypass path");
        end

        $display("tb_axi_llc_subsystem_size_contract PASS");
        $finish(0);
    end

endmodule
