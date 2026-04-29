`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_dual_mmio_contract;

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
    localparam DDR_DATA_BITS     = `AXI_LLC_AXI_DATA_BITS;
    localparam DDR_STRB_BITS     = `AXI_LLC_AXI_STRB_BITS;
    localparam MMIO_DATA_BITS    = 32;
    localparam MMIO_STRB_BITS    = 4;
    localparam READ_RESP_BITS    = `AXI_LLC_READ_RESP_BITS;

    localparam [MODE_BITS-1:0] MODE_CACHE = 2'b01;
    localparam [ADDR_BITS-1:0] MMIO_READ_ADDR = `AXI_LLC_MMIO_BASE + 32'h0000_000C;
    localparam [ADDR_BITS-1:0] MMIO_WRITE_ADDR = `AXI_LLC_MMIO_BASE + 32'h0000_0008;
    localparam [ID_BITS-1:0] READ_ID = 4'h9;
    localparam [ID_BITS-1:0] WRITE_ID = 4'hA;
    localparam [1:0] AXI_RESP_OKAY = 2'b00;
    localparam [1:0] AXI_RESP_SLVERR = 2'b10;
    localparam [1:0] AXI_BURST_INCR = 2'b01;
    localparam [2:0] AXI_SIZE_32 = 3'd2;

    reg                              clk;
    reg                              rst_n;
    reg  [MODE_BITS-1:0]             mode_req;
    reg  [ADDR_BITS-1:0]             llc_mapped_offset_req;
    reg  [NUM_READ_MASTERS-1:0]      read_req_valid;
    wire [NUM_READ_MASTERS-1:0]      read_req_ready;
    wire [NUM_READ_MASTERS-1:0]      read_req_accepted;
    wire [NUM_READ_MASTERS*ID_BITS-1:0] read_req_accepted_id;
    reg  [NUM_READ_MASTERS*ADDR_BITS-1:0] read_req_addr;
    reg  [NUM_READ_MASTERS*8-1:0]    read_req_total_size;
    reg  [NUM_READ_MASTERS*ID_BITS-1:0] read_req_id;
    reg  [NUM_READ_MASTERS-1:0]      read_req_bypass;
    wire [NUM_READ_MASTERS-1:0]      read_resp_valid;
    reg  [NUM_READ_MASTERS-1:0]      read_resp_ready;
    wire [NUM_READ_MASTERS*READ_RESP_BITS-1:0] read_resp_data;
    wire [NUM_READ_MASTERS*ID_BITS-1:0] read_resp_id;
    reg  [NUM_WRITE_MASTERS-1:0]     write_req_valid;
    wire [NUM_WRITE_MASTERS-1:0]     write_req_ready;
    wire [NUM_WRITE_MASTERS-1:0]     write_req_accepted;
    reg  [NUM_WRITE_MASTERS*ADDR_BITS-1:0] write_req_addr;
    reg  [NUM_WRITE_MASTERS*LINE_BITS-1:0] write_req_wdata;
    reg  [NUM_WRITE_MASTERS*LINE_BYTES-1:0] write_req_wstrb;
    reg  [NUM_WRITE_MASTERS*8-1:0]   write_req_total_size;
    reg  [NUM_WRITE_MASTERS*ID_BITS-1:0] write_req_id;
    reg  [NUM_WRITE_MASTERS-1:0]     write_req_bypass;
    wire [NUM_WRITE_MASTERS-1:0]     write_resp_valid;
    reg  [NUM_WRITE_MASTERS-1:0]     write_resp_ready;
    wire [NUM_WRITE_MASTERS*ID_BITS-1:0] write_resp_id;
    wire [NUM_WRITE_MASTERS*2-1:0]   write_resp_code;

    wire                             ddr_axi_awvalid;
    reg                              ddr_axi_awready;
    wire [AXI_ID_BITS-1:0]           ddr_axi_awid;
    wire [ADDR_BITS-1:0]             ddr_axi_awaddr;
    wire [7:0]                       ddr_axi_awlen;
    wire [2:0]                       ddr_axi_awsize;
    wire [1:0]                       ddr_axi_awburst;
    wire                             ddr_axi_wvalid;
    reg                              ddr_axi_wready;
    wire [DDR_DATA_BITS-1:0]         ddr_axi_wdata;
    wire [DDR_STRB_BITS-1:0]         ddr_axi_wstrb;
    wire                             ddr_axi_wlast;
    reg                              ddr_axi_bvalid;
    wire                             ddr_axi_bready;
    reg  [AXI_ID_BITS-1:0]           ddr_axi_bid;
    reg  [1:0]                       ddr_axi_bresp;
    wire                             ddr_axi_arvalid;
    reg                              ddr_axi_arready;
    wire [AXI_ID_BITS-1:0]           ddr_axi_arid;
    wire [ADDR_BITS-1:0]             ddr_axi_araddr;
    wire [7:0]                       ddr_axi_arlen;
    wire [2:0]                       ddr_axi_arsize;
    wire [1:0]                       ddr_axi_arburst;
    reg                              ddr_axi_rvalid;
    wire                             ddr_axi_rready;
    reg  [AXI_ID_BITS-1:0]           ddr_axi_rid;
    reg  [DDR_DATA_BITS-1:0]         ddr_axi_rdata;
    reg  [1:0]                       ddr_axi_rresp;
    reg                              ddr_axi_rlast;

    wire                             mmio_axi_awvalid;
    reg                              mmio_axi_awready;
    wire [AXI_ID_BITS-1:0]           mmio_axi_awid;
    wire [ADDR_BITS-1:0]             mmio_axi_awaddr;
    wire [7:0]                       mmio_axi_awlen;
    wire [2:0]                       mmio_axi_awsize;
    wire [1:0]                       mmio_axi_awburst;
    wire                             mmio_axi_wvalid;
    reg                              mmio_axi_wready;
    wire [MMIO_DATA_BITS-1:0]        mmio_axi_wdata;
    wire [MMIO_STRB_BITS-1:0]        mmio_axi_wstrb;
    wire                             mmio_axi_wlast;
    reg                              mmio_axi_bvalid;
    wire                             mmio_axi_bready;
    reg  [AXI_ID_BITS-1:0]           mmio_axi_bid;
    reg  [1:0]                       mmio_axi_bresp;
    wire                             mmio_axi_arvalid;
    reg                              mmio_axi_arready;
    wire [AXI_ID_BITS-1:0]           mmio_axi_arid;
    wire [ADDR_BITS-1:0]             mmio_axi_araddr;
    wire [7:0]                       mmio_axi_arlen;
    wire [2:0]                       mmio_axi_arsize;
    wire [1:0]                       mmio_axi_arburst;
    reg                              mmio_axi_rvalid;
    wire                             mmio_axi_rready;
    reg  [AXI_ID_BITS-1:0]           mmio_axi_rid;
    reg  [MMIO_DATA_BITS-1:0]        mmio_axi_rdata;
    reg  [1:0]                       mmio_axi_rresp;
    reg                              mmio_axi_rlast;

    reg                              invalidate_line_valid;
    reg  [ADDR_BITS-1:0]             invalidate_line_addr;
    wire                             invalidate_line_accepted;
    reg                              invalidate_all_valid;
    wire                             invalidate_all_accepted;
    wire [MODE_BITS-1:0]             active_mode;
    wire [ADDR_BITS-1:0]             active_offset;
    wire                             reconfig_busy;
    wire [1:0]                       reconfig_state;
    wire                             config_error;

    reg [AXI_ID_BITS-1:0]            seen_mmio_arid;
    reg [AXI_ID_BITS-1:0]            seen_mmio_awid;
    wire [ID_BITS-1:0]               read_resp_id_w;
    wire [ID_BITS-1:0]               write_resp_id_w;
    wire [1:0]                       write_resp_code_w;

    assign read_resp_id_w = read_resp_id[ID_BITS-1:0];
    assign write_resp_id_w = write_resp_id[ID_BITS-1:0];
    assign write_resp_code_w = write_resp_code[1:0];

    always #5 clk = ~clk;

    task fail_now;
        input [8*180-1:0] msg;
        begin
            $display("tb_axi_llc_subsystem_dual_mmio_contract FAIL: %0s", msg);
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

    task check_no_ddr_activity;
        begin
            if (ddr_axi_arvalid || ddr_axi_awvalid || ddr_axi_wvalid) begin
                fail_now("MMIO request leaked to DDR AXI port");
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

    task issue_mmio_read;
        integer timeout;
        begin
            read_req_addr[ADDR_BITS-1:0] = MMIO_READ_ADDR;
            read_req_total_size[7:0] = 8'd3;
            read_req_id[ID_BITS-1:0] = READ_ID;
            read_req_bypass[0] = 1'b0;
            read_req_valid[0] = 1'b1;
            timeout = 80;
            while (timeout > 0) begin
                @(posedge clk);
                if (read_req_valid[0] && read_req_ready[0]) begin
                    timeout = 0;
                end else begin
                    timeout = timeout - 1;
                end
            end
            if (!(read_req_valid[0] && read_req_ready[0])) begin
                fail_now("MMIO read request handshake timeout");
            end
            #1;
            if (!read_req_accepted[0] || read_req_accepted_id[ID_BITS-1:0] != READ_ID) begin
                fail_now("MMIO read accepted metadata mismatch");
            end
            @(negedge clk);
            read_req_valid[0] = 1'b0;
        end
    endtask

    task wait_mmio_ar;
        integer timeout;
        begin
            timeout = 100;
            while (!mmio_axi_arvalid && (timeout > 0)) begin
                check_no_ddr_activity();
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("MMIO AR timeout");
            end
            check_no_ddr_activity();
            if (mmio_axi_araddr != MMIO_READ_ADDR ||
                mmio_axi_arlen != 8'd0 ||
                mmio_axi_arsize != AXI_SIZE_32 ||
                mmio_axi_arburst != AXI_BURST_INCR) begin
                fail_now("MMIO AR shape mismatch");
            end
            seen_mmio_arid = mmio_axi_arid;
            mmio_axi_arready = 1'b1;
            @(posedge clk);
            mmio_axi_arready = 1'b0;
            @(negedge clk);
        end
    endtask

    task drive_mmio_r;
        integer timeout;
        begin
            @(negedge clk);
            mmio_axi_rid = seen_mmio_arid;
            mmio_axi_rdata = 32'hA5A5_1234;
            mmio_axi_rresp = AXI_RESP_OKAY;
            mmio_axi_rlast = 1'b1;
            mmio_axi_rvalid = 1'b1;
            timeout = 40;
            while (!mmio_axi_rready && (timeout > 0)) begin
                @(negedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("MMIO R handshake timeout");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_rvalid = 1'b0;
            mmio_axi_rlast = 1'b0;
        end
    endtask

    task wait_mmio_read_resp;
        integer timeout;
        begin
            timeout = 100;
            while (!read_resp_valid[0] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("MMIO read response timeout");
            end
            if (read_resp_id_w != READ_ID ||
                read_resp_data[31:0] != 32'hA5A5_1234) begin
                fail_now("MMIO read response mismatch");
            end
            @(posedge clk);
        end
    endtask

    task issue_mmio_write;
        integer timeout;
        begin
            write_req_addr[ADDR_BITS-1:0] = MMIO_WRITE_ADDR;
            write_req_total_size[7:0] = 8'd3;
            write_req_id[ID_BITS-1:0] = WRITE_ID;
            write_req_bypass[0] = 1'b0;
            write_req_wdata[31:0] = 32'hDEAD_BEEF;
            write_req_wstrb[3:0] = 4'hF;
            write_req_valid[0] = 1'b1;
            timeout = 80;
            while (timeout > 0) begin
                @(posedge clk);
                if (write_req_valid[0] && write_req_ready[0]) begin
                    timeout = 0;
                end else begin
                    timeout = timeout - 1;
                end
            end
            if (!(write_req_valid[0] && write_req_ready[0])) begin
                fail_now("MMIO write request handshake timeout");
            end
            #1;
            if (!write_req_accepted[0]) begin
                fail_now("MMIO write accepted pulse missing");
            end
            @(negedge clk);
            write_req_valid[0] = 1'b0;
        end
    endtask

    task wait_mmio_aw_w;
        integer timeout;
        begin
            timeout = 100;
            while (!mmio_axi_awvalid && (timeout > 0)) begin
                check_no_ddr_activity();
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("MMIO AW timeout");
            end
            check_no_ddr_activity();
            if (mmio_axi_awaddr != MMIO_WRITE_ADDR ||
                mmio_axi_awlen != 8'd0 ||
                mmio_axi_awsize != AXI_SIZE_32 ||
                mmio_axi_awburst != AXI_BURST_INCR) begin
                fail_now("MMIO AW shape mismatch");
            end
            seen_mmio_awid = mmio_axi_awid;
            mmio_axi_awready = 1'b1;
            @(posedge clk);
            mmio_axi_awready = 1'b0;

            timeout = 100;
            while (!mmio_axi_wvalid && (timeout > 0)) begin
                check_no_ddr_activity();
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("MMIO W timeout");
            end
            check_no_ddr_activity();
            if (mmio_axi_wdata != 32'hDEAD_BEEF ||
                mmio_axi_wstrb != 4'hF ||
                !mmio_axi_wlast) begin
                fail_now("MMIO W shape mismatch");
            end
            mmio_axi_wready = 1'b1;
            @(posedge clk);
            mmio_axi_wready = 1'b0;
            @(negedge clk);
        end
    endtask

    task drive_mmio_b;
        integer timeout;
        begin
            @(negedge clk);
            mmio_axi_bid = seen_mmio_awid;
            mmio_axi_bresp = AXI_RESP_SLVERR;
            mmio_axi_bvalid = 1'b1;
            timeout = 40;
            while (!mmio_axi_bready && (timeout > 0)) begin
                @(negedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("MMIO B handshake timeout");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_bvalid = 1'b0;
        end
    endtask

    task wait_mmio_write_resp;
        integer timeout;
        begin
            timeout = 100;
            while (!write_resp_valid[0] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("MMIO write response timeout");
            end
            if (write_resp_id_w != WRITE_ID ||
                write_resp_code_w != AXI_RESP_SLVERR) begin
                fail_now("MMIO write response mismatch");
            end
            @(posedge clk);
        end
    endtask

    axi_llc_subsystem_dual #(
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
        .DDR_AXI_ID_BITS   (AXI_ID_BITS),
        .MMIO_AXI_ID_BITS  (AXI_ID_BITS),
        .READ_RESP_BITS    (READ_RESP_BITS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .mode_req(mode_req),
        .llc_mapped_offset_req(llc_mapped_offset_req),
        .read_req_valid(read_req_valid),
        .read_req_ready(read_req_ready),
        .read_req_accepted(read_req_accepted),
        .read_req_accepted_id(read_req_accepted_id),
        .read_req_addr(read_req_addr),
        .read_req_total_size(read_req_total_size),
        .read_req_id(read_req_id),
        .read_req_bypass(read_req_bypass),
        .read_resp_valid(read_resp_valid),
        .read_resp_ready(read_resp_ready),
        .read_resp_data(read_resp_data),
        .read_resp_id(read_resp_id),
        .write_req_valid(write_req_valid),
        .write_req_ready(write_req_ready),
        .write_req_accepted(write_req_accepted),
        .write_req_addr(write_req_addr),
        .write_req_wdata(write_req_wdata),
        .write_req_wstrb(write_req_wstrb),
        .write_req_total_size(write_req_total_size),
        .write_req_id(write_req_id),
        .write_req_bypass(write_req_bypass),
        .write_resp_valid(write_resp_valid),
        .write_resp_ready(write_resp_ready),
        .write_resp_id(write_resp_id),
        .write_resp_code(write_resp_code),
        .ddr_axi_awvalid(ddr_axi_awvalid),
        .ddr_axi_awready(ddr_axi_awready),
        .ddr_axi_awid(ddr_axi_awid),
        .ddr_axi_awaddr(ddr_axi_awaddr),
        .ddr_axi_awlen(ddr_axi_awlen),
        .ddr_axi_awsize(ddr_axi_awsize),
        .ddr_axi_awburst(ddr_axi_awburst),
        .ddr_axi_wvalid(ddr_axi_wvalid),
        .ddr_axi_wready(ddr_axi_wready),
        .ddr_axi_wdata(ddr_axi_wdata),
        .ddr_axi_wstrb(ddr_axi_wstrb),
        .ddr_axi_wlast(ddr_axi_wlast),
        .ddr_axi_bvalid(ddr_axi_bvalid),
        .ddr_axi_bready(ddr_axi_bready),
        .ddr_axi_bid(ddr_axi_bid),
        .ddr_axi_bresp(ddr_axi_bresp),
        .ddr_axi_arvalid(ddr_axi_arvalid),
        .ddr_axi_arready(ddr_axi_arready),
        .ddr_axi_arid(ddr_axi_arid),
        .ddr_axi_araddr(ddr_axi_araddr),
        .ddr_axi_arlen(ddr_axi_arlen),
        .ddr_axi_arsize(ddr_axi_arsize),
        .ddr_axi_arburst(ddr_axi_arburst),
        .ddr_axi_rvalid(ddr_axi_rvalid),
        .ddr_axi_rready(ddr_axi_rready),
        .ddr_axi_rid(ddr_axi_rid),
        .ddr_axi_rdata(ddr_axi_rdata),
        .ddr_axi_rresp(ddr_axi_rresp),
        .ddr_axi_rlast(ddr_axi_rlast),
        .mmio_axi_awvalid(mmio_axi_awvalid),
        .mmio_axi_awready(mmio_axi_awready),
        .mmio_axi_awid(mmio_axi_awid),
        .mmio_axi_awaddr(mmio_axi_awaddr),
        .mmio_axi_awlen(mmio_axi_awlen),
        .mmio_axi_awsize(mmio_axi_awsize),
        .mmio_axi_awburst(mmio_axi_awburst),
        .mmio_axi_wvalid(mmio_axi_wvalid),
        .mmio_axi_wready(mmio_axi_wready),
        .mmio_axi_wdata(mmio_axi_wdata),
        .mmio_axi_wstrb(mmio_axi_wstrb),
        .mmio_axi_wlast(mmio_axi_wlast),
        .mmio_axi_bvalid(mmio_axi_bvalid),
        .mmio_axi_bready(mmio_axi_bready),
        .mmio_axi_bid(mmio_axi_bid),
        .mmio_axi_bresp(mmio_axi_bresp),
        .mmio_axi_arvalid(mmio_axi_arvalid),
        .mmio_axi_arready(mmio_axi_arready),
        .mmio_axi_arid(mmio_axi_arid),
        .mmio_axi_araddr(mmio_axi_araddr),
        .mmio_axi_arlen(mmio_axi_arlen),
        .mmio_axi_arsize(mmio_axi_arsize),
        .mmio_axi_arburst(mmio_axi_arburst),
        .mmio_axi_rvalid(mmio_axi_rvalid),
        .mmio_axi_rready(mmio_axi_rready),
        .mmio_axi_rid(mmio_axi_rid),
        .mmio_axi_rdata(mmio_axi_rdata),
        .mmio_axi_rresp(mmio_axi_rresp),
        .mmio_axi_rlast(mmio_axi_rlast),
        .invalidate_line_valid(invalidate_line_valid),
        .invalidate_line_addr(invalidate_line_addr),
        .invalidate_line_accepted(invalidate_line_accepted),
        .invalidate_all_valid(invalidate_all_valid),
        .invalidate_all_accepted(invalidate_all_accepted),
        .active_mode(active_mode),
        .active_offset(active_offset),
        .reconfig_busy(reconfig_busy),
        .reconfig_state(reconfig_state),
        .config_error(config_error)
    );

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
        ddr_axi_awready = 1'b1;
        ddr_axi_wready = 1'b1;
        ddr_axi_bvalid = 1'b0;
        ddr_axi_bid = {AXI_ID_BITS{1'b0}};
        ddr_axi_bresp = AXI_RESP_OKAY;
        ddr_axi_arready = 1'b1;
        ddr_axi_rvalid = 1'b0;
        ddr_axi_rid = {AXI_ID_BITS{1'b0}};
        ddr_axi_rdata = {DDR_DATA_BITS{1'b0}};
        ddr_axi_rresp = AXI_RESP_OKAY;
        ddr_axi_rlast = 1'b0;
        mmio_axi_awready = 1'b0;
        mmio_axi_wready = 1'b0;
        mmio_axi_bvalid = 1'b0;
        mmio_axi_bid = {AXI_ID_BITS{1'b0}};
        mmio_axi_bresp = AXI_RESP_OKAY;
        mmio_axi_arready = 1'b0;
        mmio_axi_rvalid = 1'b0;
        mmio_axi_rid = {AXI_ID_BITS{1'b0}};
        mmio_axi_rdata = {MMIO_DATA_BITS{1'b0}};
        mmio_axi_rresp = AXI_RESP_OKAY;
        mmio_axi_rlast = 1'b0;
        invalidate_line_valid = 1'b0;
        invalidate_line_addr = {ADDR_BITS{1'b0}};
        invalidate_all_valid = 1'b0;

        wait_cycles(5);
        rst_n = 1'b1;
        wait_mode_cache_active();

        issue_mmio_read();
        wait_mmio_ar();
        drive_mmio_r();
        wait_mmio_read_resp();

        issue_mmio_write();
        wait_mmio_aw_w();
        drive_mmio_b();
        wait_mmio_write_resp();

        if (config_error) begin
            fail_now("config_error asserted unexpectedly");
        end

        $display("tb_axi_llc_subsystem_dual_mmio_contract PASS");
        $finish(0);
    end

endmodule
