`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_axi_bypass_write_contract;

    localparam ADDR_BITS         = `AXI_LLC_ADDR_BITS;
    localparam ID_BITS           = `AXI_LLC_ID_BITS;
    localparam MODE_BITS         = `AXI_LLC_MODE_BITS;
    localparam LINE_BYTES        = `AXI_LLC_LINE_BYTES;
    localparam LINE_BITS         = `AXI_LLC_LINE_BITS;
    localparam LINE_OFFSET_BITS  = `AXI_LLC_LINE_OFFSET_BITS;
    localparam SET_COUNT         = 4;
    localparam SET_BITS          = 2;
    localparam WAY_COUNT         = 2;
    localparam WAY_BITS          = 1;
    localparam META_BITS         = `AXI_LLC_META_BITS;
    localparam LLC_SIZE_BYTES    = LINE_BYTES * SET_COUNT * WAY_COUNT;
    localparam WINDOW_BYTES      = LINE_BYTES * SET_COUNT;
    localparam WINDOW_WAYS       = 1;
    localparam NUM_READ_MASTERS  = 1;
    localparam NUM_WRITE_MASTERS = 1;
    localparam AXI_ID_BITS       = `AXI_LLC_AXI_ID_BITS;
    localparam AXI_DATA_BYTES    = `AXI_LLC_AXI_DATA_BYTES;
    localparam AXI_DATA_BITS     = `AXI_LLC_AXI_DATA_BITS;
    localparam AXI_STRB_BITS     = `AXI_LLC_AXI_STRB_BITS;
    localparam READ_RESP_BITS    = `AXI_LLC_READ_RESP_BITS;

    localparam [MODE_BITS-1:0] MODE_CACHE = 2'b01;
    localparam [1:0] AXI_BURST_INCR = 2'b01;
    localparam [2:0] AXI_SIZE_32B = 3'd5;
    localparam [1:0] AXI_RESP_OKAY = 2'b00;

    localparam [ADDR_BITS-1:0] BYPASS_ADDR = 32'h1000_0008;
    localparam [ID_BITS-1:0] WRITE_ID = 4'hA;

    reg                             clk;
    reg                             rst_n;
    reg  [MODE_BITS-1:0]            mode_req;
    reg  [ADDR_BITS-1:0]            llc_mapped_offset_req;
    reg  [NUM_READ_MASTERS-1:0]     read_req_valid;
    wire [NUM_READ_MASTERS-1:0]     read_req_ready;
    wire [NUM_READ_MASTERS-1:0]     read_req_accepted;
    wire [NUM_READ_MASTERS*ID_BITS-1:0] read_req_accepted_id;
    reg  [NUM_READ_MASTERS*ADDR_BITS-1:0] read_req_addr;
    reg  [NUM_READ_MASTERS*8-1:0]   read_req_total_size;
    reg  [NUM_READ_MASTERS*ID_BITS-1:0] read_req_id;
    reg  [NUM_READ_MASTERS-1:0]     read_req_bypass;
    wire [NUM_READ_MASTERS-1:0]     read_resp_valid;
    reg  [NUM_READ_MASTERS-1:0]     read_resp_ready;
    wire [NUM_READ_MASTERS*READ_RESP_BITS-1:0] read_resp_data;
    wire [NUM_READ_MASTERS*ID_BITS-1:0] read_resp_id;
    reg  [NUM_WRITE_MASTERS-1:0]    write_req_valid;
    wire [NUM_WRITE_MASTERS-1:0]    write_req_ready;
    wire [NUM_WRITE_MASTERS-1:0]    write_req_accepted;
    reg  [NUM_WRITE_MASTERS*ADDR_BITS-1:0] write_req_addr;
    reg  [NUM_WRITE_MASTERS*LINE_BITS-1:0] write_req_wdata;
    reg  [NUM_WRITE_MASTERS*LINE_BYTES-1:0] write_req_wstrb;
    reg  [NUM_WRITE_MASTERS*8-1:0]  write_req_total_size;
    reg  [NUM_WRITE_MASTERS*ID_BITS-1:0] write_req_id;
    reg  [NUM_WRITE_MASTERS-1:0]    write_req_bypass;
    wire [NUM_WRITE_MASTERS-1:0]    write_resp_valid;
    reg  [NUM_WRITE_MASTERS-1:0]    write_resp_ready;
    wire [NUM_WRITE_MASTERS*ID_BITS-1:0] write_resp_id;
    wire [NUM_WRITE_MASTERS*2-1:0]  write_resp_code;

    wire                            axi_awvalid;
    reg                             axi_awready;
    wire [AXI_ID_BITS-1:0]          axi_awid;
    wire [ADDR_BITS-1:0]            axi_awaddr;
    wire [7:0]                      axi_awlen;
    wire [2:0]                      axi_awsize;
    wire [1:0]                      axi_awburst;
    wire                            axi_wvalid;
    reg                             axi_wready;
    wire [AXI_DATA_BITS-1:0]        axi_wdata;
    wire [AXI_STRB_BITS-1:0]        axi_wstrb;
    wire                            axi_wlast;
    reg                             axi_bvalid;
    wire                            axi_bready;
    reg  [AXI_ID_BITS-1:0]          axi_bid;
    reg  [1:0]                      axi_bresp;
    wire                            axi_arvalid;
    reg                             axi_arready;
    wire [AXI_ID_BITS-1:0]          axi_arid;
    wire [ADDR_BITS-1:0]            axi_araddr;
    wire [7:0]                      axi_arlen;
    wire [2:0]                      axi_arsize;
    wire [1:0]                      axi_arburst;
    reg                             axi_rvalid;
    wire                            axi_rready;
    reg  [AXI_ID_BITS-1:0]          axi_rid;
    reg  [AXI_DATA_BITS-1:0]        axi_rdata;
    reg  [1:0]                      axi_rresp;
    reg                             axi_rlast;

    reg                             invalidate_line_valid;
    reg  [ADDR_BITS-1:0]            invalidate_line_addr;
    wire                            invalidate_line_accepted;
    reg                             invalidate_all_valid;
    wire                            invalidate_all_accepted;
    wire [MODE_BITS-1:0]            active_mode;
    wire [ADDR_BITS-1:0]            active_offset;
    wire                            reconfig_busy;
    wire [1:0]                      reconfig_state;
    wire                            config_error;

    integer                         aw_count;
    integer                         w_count;
    integer                         b_count;
    reg  [AXI_ID_BITS-1:0]          seen_awid;
    reg  [31:0]                     expected_word;
    reg  [AXI_DATA_BITS-1:0]        expected_axi_wdata;
    reg  [AXI_STRB_BITS-1:0]        expected_axi_wstrb;

    wire [ID_BITS-1:0]             write_resp_id_w;
    wire [1:0]                     write_resp_code_w;

    assign write_resp_id_w = write_resp_id[ID_BITS-1:0];
    assign write_resp_code_w = write_resp_code[1:0];

    always #5 clk = ~clk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_count <= 0;
            w_count <= 0;
            b_count <= 0;
        end else begin
            if (axi_awvalid && axi_awready) begin
                aw_count <= aw_count + 1;
            end
            if (axi_wvalid && axi_wready) begin
                w_count <= w_count + 1;
            end
            if (axi_bvalid && axi_bready) begin
                b_count <= b_count + 1;
            end
        end
    end

    axi_llc_subsystem #(
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
        .AXI_ID_BITS       (AXI_ID_BITS),
        .AXI_DATA_BYTES    (AXI_DATA_BYTES),
        .AXI_DATA_BITS     (AXI_DATA_BITS),
        .AXI_STRB_BITS     (AXI_STRB_BITS),
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
        .axi_awvalid           (axi_awvalid),
        .axi_awready           (axi_awready),
        .axi_awid              (axi_awid),
        .axi_awaddr            (axi_awaddr),
        .axi_awlen             (axi_awlen),
        .axi_awsize            (axi_awsize),
        .axi_awburst           (axi_awburst),
        .axi_wvalid            (axi_wvalid),
        .axi_wready            (axi_wready),
        .axi_wdata             (axi_wdata),
        .axi_wstrb             (axi_wstrb),
        .axi_wlast             (axi_wlast),
        .axi_bvalid            (axi_bvalid),
        .axi_bready            (axi_bready),
        .axi_bid               (axi_bid),
        .axi_bresp             (axi_bresp),
        .axi_arvalid           (axi_arvalid),
        .axi_arready           (axi_arready),
        .axi_arid              (axi_arid),
        .axi_araddr            (axi_araddr),
        .axi_arlen             (axi_arlen),
        .axi_arsize            (axi_arsize),
        .axi_arburst           (axi_arburst),
        .axi_rvalid            (axi_rvalid),
        .axi_rready            (axi_rready),
        .axi_rid               (axi_rid),
        .axi_rdata             (axi_rdata),
        .axi_rresp             (axi_rresp),
        .axi_rlast             (axi_rlast),
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
            $display("tb_axi_llc_subsystem_axi_bypass_write_contract FAIL: %0s", msg);
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
        integer timeout;
        begin
            timeout = 1000;
            while (((active_mode != MODE_CACHE) || reconfig_busy) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("mode=1 activate timeout");
            end
        end
    endtask

    task issue_bypass_write;
        integer timeout;
        begin
            write_req_addr[ADDR_BITS-1:0] = BYPASS_ADDR;
            write_req_total_size[7:0] = 8'd3;
            write_req_id[ID_BITS-1:0] = WRITE_ID;
            write_req_bypass[0] = 1'b1;
            write_req_wdata[31:0] = expected_word;
            write_req_wstrb[3:0] = 4'hF;
            write_req_valid[0] = 1'b1;
            timeout = 50;
            while (timeout > 0) begin
                @(posedge clk);
                if (write_req_valid[0] && write_req_ready[0]) begin
                    timeout = 0;
                end else begin
                    timeout = timeout - 1;
                end
            end
            if (!(write_req_valid[0] && write_req_ready[0])) begin
                fail_now("bypass write request handshake timeout");
            end
            #1;
            if (!write_req_accepted[0]) begin
                fail_now("bypass write accepted pulse missing");
            end
            @(negedge clk);
            write_req_valid[0] = 1'b0;
        end
    endtask

    task wait_aw_contract;
        integer timeout;
        begin
            timeout = 100;
            while (!axi_awvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("bypass write AW timeout");
            end
            if (axi_awaddr !== BYPASS_ADDR) begin
                fail_now("bypass write AW address mismatch");
            end
            if (axi_awlen !== 8'd0) begin
                fail_now("bypass write should use single-beat AW");
            end
            if (axi_awsize !== AXI_SIZE_32B) begin
                fail_now("bypass 4B write must use fixed downstream beat size");
            end
            if (axi_awburst !== AXI_BURST_INCR) begin
                fail_now("bypass write burst must be INCR");
            end
            seen_awid = axi_awid;
            axi_awready = 1'b1;
            @(posedge clk);
            axi_awready = 1'b0;
        end
    endtask

    task wait_w_contract;
        integer timeout;
        begin
            timeout = 100;
            while (!axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("bypass write W timeout");
            end
            if (!axi_wlast) begin
                fail_now("bypass write single beat must assert wlast");
            end
            if (axi_wdata !== expected_axi_wdata) begin
                fail_now("bypass write WDATA packing mismatch");
            end
            if (axi_wstrb !== expected_axi_wstrb) begin
                fail_now("bypass write WSTRB packing mismatch");
            end
            axi_wready = 1'b1;
            @(posedge clk);
            axi_wready = 1'b0;
        end
    endtask

    task drive_b_resp;
        integer timeout;
        begin
            axi_bid = seen_awid;
            axi_bresp = AXI_RESP_OKAY;
            axi_bvalid = 1'b1;
            timeout = 40;
            while (timeout > 0) begin
                @(posedge clk);
                if (axi_bvalid && axi_bready) begin
                    timeout = 0;
                end else begin
                    timeout = timeout - 1;
                end
            end
            if (!(axi_bvalid && axi_bready)) begin
                fail_now("bypass write B handshake timeout");
            end
            #1;
            axi_bvalid = 1'b0;
        end
    endtask

    task wait_write_resp;
        integer timeout;
        begin
            timeout = 100;
            while (!write_resp_valid[0] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("bypass write response timeout");
            end
            if (write_resp_id_w !== WRITE_ID) begin
                fail_now("bypass write response id mismatch");
            end
            if (write_resp_code_w !== AXI_RESP_OKAY) begin
                fail_now("bypass write response code mismatch");
            end
            @(posedge clk);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        mode_req = MODE_CACHE;
        llc_mapped_offset_req = {ADDR_BITS{1'b0}};
        read_req_valid = {NUM_READ_MASTERS{1'b0}};
        read_req_addr = {(NUM_READ_MASTERS*ADDR_BITS){1'b0}};
        read_req_total_size = {(NUM_READ_MASTERS*8){1'b0}};
        read_req_id = {(NUM_READ_MASTERS*ID_BITS){1'b0}};
        read_req_bypass = {NUM_READ_MASTERS{1'b0}};
        read_resp_ready = {NUM_READ_MASTERS{1'b1}};
        write_req_valid = {NUM_WRITE_MASTERS{1'b0}};
        write_req_addr = {(NUM_WRITE_MASTERS*ADDR_BITS){1'b0}};
        write_req_wdata = {(NUM_WRITE_MASTERS*LINE_BITS){1'b0}};
        write_req_wstrb = {(NUM_WRITE_MASTERS*LINE_BYTES){1'b0}};
        write_req_total_size = {(NUM_WRITE_MASTERS*8){1'b0}};
        write_req_id = {(NUM_WRITE_MASTERS*ID_BITS){1'b0}};
        write_req_bypass = {NUM_WRITE_MASTERS{1'b0}};
        write_resp_ready = {NUM_WRITE_MASTERS{1'b1}};
        axi_awready = 1'b0;
        axi_wready = 1'b0;
        axi_bvalid = 1'b0;
        axi_bid = {AXI_ID_BITS{1'b0}};
        axi_bresp = AXI_RESP_OKAY;
        axi_arready = 1'b0;
        axi_rvalid = 1'b0;
        axi_rid = {AXI_ID_BITS{1'b0}};
        axi_rdata = {AXI_DATA_BITS{1'b0}};
        axi_rresp = 2'b00;
        axi_rlast = 1'b0;
        invalidate_line_valid = 1'b0;
        invalidate_line_addr = {ADDR_BITS{1'b0}};
        invalidate_all_valid = 1'b0;
        expected_word = 32'hDEAD_BEEF;
        expected_axi_wdata = {AXI_DATA_BITS{1'b0}};
        expected_axi_wstrb = {AXI_STRB_BITS{1'b0}};
        expected_axi_wdata[31:0] = expected_word;
        expected_axi_wstrb[3:0] = 4'hF;

        wait_cycles(5);
        rst_n = 1'b1;
        wait_mode_cache_active();

        issue_bypass_write();
        wait_aw_contract();
        wait_w_contract();
        drive_b_resp();
        wait_write_resp();
        wait_cycles(1);

        if (aw_count !== 1) begin
            fail_now("bypass write should emit exactly one AW");
        end
        if (w_count !== 1) begin
            fail_now("bypass write should emit exactly one W");
        end
        if (b_count < 1) begin
            fail_now("bypass write should consume at least one B");
        end
        if (config_error) begin
            fail_now("config_error asserted unexpectedly");
        end

        $display("tb_axi_llc_subsystem_axi_bypass_write_contract PASS");
        $finish(0);
    end

endmodule
