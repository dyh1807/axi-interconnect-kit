`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_core_startup_idle_contract;

    localparam ADDR_BITS        = `AXI_LLC_ADDR_BITS;
    localparam ID_BITS          = `AXI_LLC_ID_BITS;
    localparam MODE_BITS        = `AXI_LLC_MODE_BITS;
    localparam LINE_BYTES       = 8;
    localparam LINE_BITS        = 64;
    localparam LINE_OFFSET_BITS = 3;
    localparam SET_COUNT        = 2;
    localparam SET_BITS         = 1;
    localparam WAY_COUNT        = 2;
    localparam WAY_BITS         = 1;
    localparam META_BITS        = 8;
    localparam LLC_SIZE_BYTES   = LINE_BYTES * SET_COUNT * WAY_COUNT;
    localparam WINDOW_BYTES     = LINE_BYTES * SET_COUNT;
    localparam WINDOW_WAYS      = 1;
    localparam READ_RESP_BYTES  = 8;
    localparam READ_RESP_BITS   = 64;
    localparam DATA_ROW_BITS    = WAY_COUNT * LINE_BITS;
    localparam META_ROW_BITS    = WAY_COUNT * META_BITS;

    localparam [MODE_BITS-1:0] MODE_CACHE = 2'b01;

    reg                         clk;
    reg                         rst_n;
    wire                        up_req_ready;
    wire                        up_resp_valid;
    wire [READ_RESP_BITS-1:0]   up_resp_rdata;
    wire [ID_BITS-1:0]          up_resp_id;
    wire [1:0]                  up_resp_code;
    wire                        cache_req_valid;
    reg                         cache_req_ready;
    wire                        cache_req_write;
    wire [ADDR_BITS-1:0]        cache_req_addr;
    wire [ID_BITS-1:0]          cache_req_id;
    wire [7:0]                  cache_req_size;
    wire [LINE_BITS-1:0]        cache_req_wdata;
    wire [LINE_BYTES-1:0]       cache_req_wstrb;
    wire                        cache_resp_ready;
    wire                        bypass_req_valid;
    reg                         bypass_req_ready;
    wire                        bypass_req_write;
    wire [ADDR_BITS-1:0]        bypass_req_addr;
    wire [ID_BITS-1:0]          bypass_req_id;
    wire [7:0]                  bypass_req_size;
    wire [LINE_BITS-1:0]        bypass_req_wdata;
    wire [LINE_BYTES-1:0]       bypass_req_wstrb;
    wire                        bypass_resp_ready;
    wire                        invalidate_line_accepted;
    wire                        invalidate_all_accepted;
    wire [MODE_BITS-1:0]        active_mode;
    wire [ADDR_BITS-1:0]        active_offset;
    wire                        reconfig_busy;
    wire [1:0]                  reconfig_state;
    wire                        config_error;
    wire [`AXI_LLC_MAX_OUTSTANDING-1:0] victim_line_valid;
    wire [(`AXI_LLC_MAX_OUTSTANDING*ADDR_BITS)-1:0] victim_line_addr;

    integer timeout;
    integer idx;

    always #5 clk = ~clk;

    task fail_now;
        input [8*160-1:0] msg;
        begin
            $display("tb_axi_llc_subsystem_core_startup_idle_contract FAIL: %0s", msg);
            $finish(1);
        end
    endtask

    task wait_startup_idle;
        begin
            timeout = 40;
            while (((active_mode !== MODE_CACHE) || reconfig_busy) &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("startup sweep did not settle to MODE_CACHE idle");
            end
        end
    endtask

    task check_idle_outputs;
        begin
            if (active_mode !== MODE_CACHE) begin
                fail_now("active mode changed away from MODE_CACHE");
            end
            if (active_offset !== {ADDR_BITS{1'b0}}) begin
                fail_now("active offset changed after reset");
            end
            if (reconfig_busy || reconfig_state !== 2'b00) begin
                fail_now("reconfig did not stay idle");
            end
            if (config_error) begin
                fail_now("config_error asserted for legal reset mode");
            end
            if (up_resp_valid || cache_req_valid || bypass_req_valid) begin
                fail_now("idle core emitted an unexpected request/response");
            end
            if (victim_line_valid !== {`AXI_LLC_MAX_OUTSTANDING{1'b0}}) begin
                fail_now("idle core reported a victim line");
            end
        end
    endtask

    axi_llc_subsystem_core #(
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
        .RESET_MODE(MODE_CACHE),
        .RESET_OFFSET({ADDR_BITS{1'b0}}),
        .USE_SMIC12_STORES(0),
        .TABLE_READ_LATENCY(1),
        .READ_RESP_BYTES(READ_RESP_BYTES),
        .READ_RESP_BITS(READ_RESP_BITS),
        .DATA_ROW_BITS(DATA_ROW_BITS),
        .META_ROW_BITS(META_ROW_BITS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .mode_req(MODE_CACHE),
        .llc_mapped_offset_req({ADDR_BITS{1'b0}}),
        .up_req_valid(1'b0),
        .up_req_ready(up_req_ready),
        .up_req_write(1'b0),
        .up_req_addr({ADDR_BITS{1'b0}}),
        .up_req_id({ID_BITS{1'b0}}),
        .up_req_total_size(8'd0),
        .up_req_wdata({LINE_BITS{1'b0}}),
        .up_req_wstrb({LINE_BYTES{1'b0}}),
        .up_req_bypass(1'b0),
        .up_resp_valid(up_resp_valid),
        .up_resp_ready(1'b1),
        .up_resp_rdata(up_resp_rdata),
        .up_resp_id(up_resp_id),
        .up_resp_code(up_resp_code),
        .cache_req_valid(cache_req_valid),
        .cache_req_ready(cache_req_ready),
        .cache_req_write(cache_req_write),
        .cache_req_addr(cache_req_addr),
        .cache_req_id(cache_req_id),
        .cache_req_size(cache_req_size),
        .cache_req_wdata(cache_req_wdata),
        .cache_req_wstrb(cache_req_wstrb),
        .cache_resp_valid(1'b0),
        .cache_resp_ready(cache_resp_ready),
        .cache_resp_rdata({READ_RESP_BITS{1'b0}}),
        .cache_resp_id({ID_BITS{1'b0}}),
        .cache_resp_code(2'b00),
        .bypass_req_valid(bypass_req_valid),
        .bypass_req_ready(bypass_req_ready),
        .bypass_req_write(bypass_req_write),
        .bypass_req_addr(bypass_req_addr),
        .bypass_req_id(bypass_req_id),
        .bypass_req_size(bypass_req_size),
        .bypass_req_wdata(bypass_req_wdata),
        .bypass_req_wstrb(bypass_req_wstrb),
        .bypass_resp_valid(1'b0),
        .bypass_resp_ready(bypass_resp_ready),
        .bypass_resp_rdata({READ_RESP_BITS{1'b0}}),
        .bypass_resp_id({ID_BITS{1'b0}}),
        .bypass_resp_code(2'b00),
        .invalidate_line_valid(1'b0),
        .invalidate_line_addr({ADDR_BITS{1'b0}}),
        .invalidate_line_accepted(invalidate_line_accepted),
        .invalidate_all_valid(1'b0),
        .invalidate_all_accepted(invalidate_all_accepted),
        .active_mode(active_mode),
        .active_offset(active_offset),
        .reconfig_busy(reconfig_busy),
        .reconfig_state(reconfig_state),
        .config_error(config_error),
        .victim_line_valid(victim_line_valid),
        .victim_line_addr(victim_line_addr)
    );

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        cache_req_ready = 1'b0;
        bypass_req_ready = 1'b0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        wait_startup_idle();

        for (idx = 0; idx < 8; idx = idx + 1) begin
            @(posedge clk);
            check_idle_outputs();
        end

        $display("tb_axi_llc_subsystem_core_startup_idle_contract PASS");
        $finish;
    end

endmodule
