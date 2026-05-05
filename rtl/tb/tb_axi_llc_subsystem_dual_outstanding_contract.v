`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_dual_outstanding_contract;

    localparam ADDR_BITS          = `AXI_LLC_ADDR_BITS;
    localparam ID_BITS            = `AXI_LLC_ID_BITS;
    localparam SLOT_ID_BITS       = `AXI_LLC_SLOT_ID_BITS;
    localparam MODE_BITS          = `AXI_LLC_MODE_BITS;
    localparam LINE_BYTES         = `AXI_LLC_LINE_BYTES;
    localparam LINE_BITS          = `AXI_LLC_LINE_BITS;
    localparam LINE_OFFSET_BITS   = `AXI_LLC_LINE_OFFSET_BITS;
    localparam SET_COUNT          = 4;
    localparam SET_BITS           = 2;
    localparam WAY_COUNT          = 2;
    localparam WAY_BITS           = 1;
    localparam META_BITS          = `AXI_LLC_META_BITS;
    localparam LLC_SIZE_BYTES     = LINE_BYTES * SET_COUNT * WAY_COUNT;
    localparam WINDOW_BYTES       = LINE_BYTES * SET_COUNT;
    localparam WINDOW_WAYS        = 1;
    localparam NUM_READ_MASTERS   = 3;
    localparam NUM_WRITE_MASTERS  = 3;
    localparam AXI_ID_BITS        = `AXI_LLC_AXI_ID_BITS;
    localparam DDR_DATA_BITS      = `AXI_LLC_AXI_DATA_BITS;
    localparam DDR_STRB_BITS      = `AXI_LLC_AXI_STRB_BITS;
    localparam MMIO_DATA_BITS     = 32;
    localparam MMIO_STRB_BITS     = 4;
    localparam READ_RESP_BITS     = `AXI_LLC_READ_RESP_BITS;
    localparam integer LIMIT      = `AXI_LLC_MAX_OUTSTANDING;

    localparam [MODE_BITS-1:0] MODE_OFF = 2'b00;
    localparam [ADDR_BITS-1:0] DDR_BASE_ADDR = 32'h4000_0000;
    localparam [ADDR_BITS-1:0] MMIO_BASE_ADDR = `AXI_LLC_MMIO_BASE;
    localparam [1:0] AXI_RESP_OKAY = 2'b00;

    reg                                clk;
    reg                                rst_n;
    reg  [MODE_BITS-1:0]               mode_req;
    reg  [ADDR_BITS-1:0]               llc_mapped_offset_req;
    reg  [NUM_READ_MASTERS-1:0]        read_req_valid;
    wire [NUM_READ_MASTERS-1:0]        read_req_ready;
    wire [NUM_READ_MASTERS-1:0]        read_req_accepted;
    wire [NUM_READ_MASTERS*ID_BITS-1:0] read_req_accepted_id;
    reg  [NUM_READ_MASTERS*ADDR_BITS-1:0] read_req_addr;
    reg  [NUM_READ_MASTERS*8-1:0]      read_req_total_size;
    reg  [NUM_READ_MASTERS*ID_BITS-1:0] read_req_id;
    reg  [NUM_READ_MASTERS-1:0]        read_req_bypass;
    wire [NUM_READ_MASTERS-1:0]        read_resp_valid;
    reg  [NUM_READ_MASTERS-1:0]        read_resp_ready;
    wire [NUM_READ_MASTERS*READ_RESP_BITS-1:0] read_resp_data;
    wire [NUM_READ_MASTERS*ID_BITS-1:0] read_resp_id;
    reg  [NUM_WRITE_MASTERS-1:0]       write_req_valid;
    wire [NUM_WRITE_MASTERS-1:0]       write_req_ready;
    wire [NUM_WRITE_MASTERS-1:0]       write_req_accepted;
    reg  [NUM_WRITE_MASTERS*ADDR_BITS-1:0] write_req_addr;
    reg  [NUM_WRITE_MASTERS*LINE_BITS-1:0] write_req_wdata;
    reg  [NUM_WRITE_MASTERS*LINE_BYTES-1:0] write_req_wstrb;
    reg  [NUM_WRITE_MASTERS*8-1:0]     write_req_total_size;
    reg  [NUM_WRITE_MASTERS*ID_BITS-1:0] write_req_id;
    reg  [NUM_WRITE_MASTERS-1:0]       write_req_bypass;
    wire [NUM_WRITE_MASTERS-1:0]       write_resp_valid;
    reg  [NUM_WRITE_MASTERS-1:0]       write_resp_ready;
    wire [NUM_WRITE_MASTERS*ID_BITS-1:0] write_resp_id;
    wire [NUM_WRITE_MASTERS*2-1:0]     write_resp_code;

    wire                               ddr_axi_awvalid;
    reg                                ddr_axi_awready;
    wire [AXI_ID_BITS-1:0]             ddr_axi_awid;
    wire [ADDR_BITS-1:0]               ddr_axi_awaddr;
    wire [7:0]                         ddr_axi_awlen;
    wire [2:0]                         ddr_axi_awsize;
    wire [1:0]                         ddr_axi_awburst;
    wire                               ddr_axi_wvalid;
    reg                                ddr_axi_wready;
    wire [DDR_DATA_BITS-1:0]           ddr_axi_wdata;
    wire [DDR_STRB_BITS-1:0]           ddr_axi_wstrb;
    wire                               ddr_axi_wlast;
    reg                                ddr_axi_bvalid;
    wire                               ddr_axi_bready;
    reg  [AXI_ID_BITS-1:0]             ddr_axi_bid;
    reg  [1:0]                         ddr_axi_bresp;
    wire                               ddr_axi_arvalid;
    reg                                ddr_axi_arready;
    wire [AXI_ID_BITS-1:0]             ddr_axi_arid;
    wire [ADDR_BITS-1:0]               ddr_axi_araddr;
    wire [7:0]                         ddr_axi_arlen;
    wire [2:0]                         ddr_axi_arsize;
    wire [1:0]                         ddr_axi_arburst;
    reg                                ddr_axi_rvalid;
    wire                               ddr_axi_rready;
    reg  [AXI_ID_BITS-1:0]             ddr_axi_rid;
    reg  [DDR_DATA_BITS-1:0]           ddr_axi_rdata;
    reg  [1:0]                         ddr_axi_rresp;
    reg                                ddr_axi_rlast;

    wire                               mmio_axi_awvalid;
    reg                                mmio_axi_awready;
    wire [AXI_ID_BITS-1:0]             mmio_axi_awid;
    wire [ADDR_BITS-1:0]               mmio_axi_awaddr;
    wire [7:0]                         mmio_axi_awlen;
    wire [2:0]                         mmio_axi_awsize;
    wire [1:0]                         mmio_axi_awburst;
    wire                               mmio_axi_wvalid;
    reg                                mmio_axi_wready;
    wire [MMIO_DATA_BITS-1:0]          mmio_axi_wdata;
    wire [MMIO_STRB_BITS-1:0]          mmio_axi_wstrb;
    wire                               mmio_axi_wlast;
    reg                                mmio_axi_bvalid;
    wire                               mmio_axi_bready;
    reg  [AXI_ID_BITS-1:0]             mmio_axi_bid;
    reg  [1:0]                         mmio_axi_bresp;
    wire                               mmio_axi_arvalid;
    reg                                mmio_axi_arready;
    wire [AXI_ID_BITS-1:0]             mmio_axi_arid;
    wire [ADDR_BITS-1:0]               mmio_axi_araddr;
    wire [7:0]                         mmio_axi_arlen;
    wire [2:0]                         mmio_axi_arsize;
    wire [1:0]                         mmio_axi_arburst;
    reg                                mmio_axi_rvalid;
    wire                               mmio_axi_rready;
    reg  [AXI_ID_BITS-1:0]             mmio_axi_rid;
    reg  [MMIO_DATA_BITS-1:0]          mmio_axi_rdata;
    reg  [1:0]                         mmio_axi_rresp;
    reg                                mmio_axi_rlast;

    reg                                invalidate_line_valid;
    reg  [ADDR_BITS-1:0]               invalidate_line_addr;
    wire                               invalidate_line_accepted;
    reg                                invalidate_all_valid;
    wire                               invalidate_all_accepted;
    wire [MODE_BITS-1:0]               active_mode;
    wire [ADDR_BITS-1:0]               active_offset;
    wire                               reconfig_busy;
    wire [1:0]                         reconfig_state;
    wire                               config_error;

    integer                            ddr_ar_count;
    integer                            mmio_ar_count;
    integer                            ddr_aw_count;
    integer                            mmio_aw_count;
    integer                            ddr_w_count;
    integer                            mmio_w_count;
    integer                            idx;
    reg  [AXI_ID_BITS-1:0]             seen_ddr_arid;
    reg  [AXI_ID_BITS-1:0]             seen_mmio_arid;
    reg  [AXI_ID_BITS-1:0]             seen_ddr_awid;
    reg  [AXI_ID_BITS-1:0]             seen_mmio_awid;

    always #5 clk = ~clk;

    task fail_now;
        input [8*220-1:0] msg;
        begin
            $display("tb_axi_llc_subsystem_dual_outstanding_contract FAIL: %0s", msg);
            $finish(1);
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ddr_ar_count <= 0;
            mmio_ar_count <= 0;
            ddr_aw_count <= 0;
            mmio_aw_count <= 0;
            ddr_w_count <= 0;
            mmio_w_count <= 0;
        end else begin
            if (ddr_axi_arvalid && ddr_axi_arready) begin
                ddr_ar_count <= ddr_ar_count + 1;
            end
            if (mmio_axi_arvalid && mmio_axi_arready) begin
                mmio_ar_count <= mmio_ar_count + 1;
            end
            if (ddr_axi_awvalid && ddr_axi_awready) begin
                ddr_aw_count <= ddr_aw_count + 1;
            end
            if (mmio_axi_awvalid && mmio_axi_awready) begin
                mmio_aw_count <= mmio_aw_count + 1;
            end
            if (ddr_axi_wvalid && ddr_axi_wready) begin
                ddr_w_count <= ddr_w_count + 1;
            end
            if (mmio_axi_wvalid && mmio_axi_wready) begin
                mmio_w_count <= mmio_w_count + 1;
            end
        end
    end

    function [ADDR_BITS-1:0] read_addr_for_index;
        input integer index;
        begin
            if ((index % 2) == 0) begin
                read_addr_for_index = DDR_BASE_ADDR + (index * LINE_BYTES);
            end else begin
                read_addr_for_index = MMIO_BASE_ADDR + ((index % 8) * 4);
            end
        end
    endfunction

    function [ADDR_BITS-1:0] write_addr_for_index;
        input integer index;
        begin
            if ((index % 2) == 0) begin
                write_addr_for_index = DDR_BASE_ADDR + 32'h0001_0000 +
                                       (index * LINE_BYTES);
            end else begin
                write_addr_for_index = MMIO_BASE_ADDR + 32'h0000_0080 +
                                       ((index % 8) * 4);
            end
        end
    endfunction

    task clear_read_inputs;
        begin
            read_req_valid = {NUM_READ_MASTERS{1'b0}};
            read_req_addr = {(NUM_READ_MASTERS*ADDR_BITS){1'b0}};
            read_req_total_size = {(NUM_READ_MASTERS*8){1'b0}};
            read_req_id = {(NUM_READ_MASTERS*ID_BITS){1'b0}};
            read_req_bypass = {NUM_READ_MASTERS{1'b0}};
        end
    endtask

    task clear_write_inputs;
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

    task clear_lower_inputs;
        begin
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
            mmio_axi_awready = 1'b1;
            mmio_axi_wready = 1'b1;
            mmio_axi_bvalid = 1'b0;
            mmio_axi_bid = {AXI_ID_BITS{1'b0}};
            mmio_axi_bresp = AXI_RESP_OKAY;
            mmio_axi_arready = 1'b1;
            mmio_axi_rvalid = 1'b0;
            mmio_axi_rid = {AXI_ID_BITS{1'b0}};
            mmio_axi_rdata = {MMIO_DATA_BITS{1'b0}};
            mmio_axi_rresp = AXI_RESP_OKAY;
            mmio_axi_rlast = 1'b0;
        end
    endtask

    task reset_dut;
        integer timeout;
        begin
            clk = 1'b0;
            rst_n = 1'b0;
            mode_req = MODE_OFF;
            llc_mapped_offset_req = 32'h3000_0000;
            read_resp_ready = {NUM_READ_MASTERS{1'b0}};
            write_resp_ready = {NUM_WRITE_MASTERS{1'b0}};
            clear_read_inputs();
            clear_write_inputs();
            clear_lower_inputs();
            invalidate_line_valid = 1'b0;
            invalidate_line_addr = {ADDR_BITS{1'b0}};
            invalidate_all_valid = 1'b0;
            seen_ddr_arid = {AXI_ID_BITS{1'b0}};
            seen_mmio_arid = {AXI_ID_BITS{1'b0}};
            seen_ddr_awid = {AXI_ID_BITS{1'b0}};
            seen_mmio_awid = {AXI_ID_BITS{1'b0}};
            repeat (5) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;
            timeout = 1000;
            while (((active_mode != MODE_OFF) || reconfig_busy) &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("mode-off reset did not settle");
            end
        end
    endtask

    task issue_read;
        input integer master;
        input [ADDR_BITS-1:0] addr;
        input [ID_BITS-1:0] id_value;
        integer timeout;
        begin
            @(negedge clk);
            read_req_addr[(master * ADDR_BITS) +: ADDR_BITS] = addr;
            read_req_total_size[(master * 8) +: 8] = 8'd3;
            read_req_id[(master * ID_BITS) +: ID_BITS] = id_value;
            read_req_bypass[master] = 1'b1;
            read_req_valid[master] = 1'b1;
            timeout = 120;
            while (timeout > 0) begin
                @(posedge clk);
                if (read_req_valid[master] && read_req_ready[master]) begin
                    timeout = 0;
                end else begin
                    timeout = timeout - 1;
                end
            end
            if (!(read_req_valid[master] && read_req_ready[master])) begin
                fail_now("read request accept timeout");
            end
            #1;
            if (!read_req_accepted[master] ||
                read_req_accepted_id[(master * ID_BITS) +: ID_BITS] != id_value) begin
                fail_now("read accepted metadata mismatch");
            end
            @(negedge clk);
            read_req_valid[master] = 1'b0;
            read_req_bypass[master] = 1'b0;
        end
    endtask

    task issue_write;
        input integer master;
        input [ADDR_BITS-1:0] addr;
        input [ID_BITS-1:0] id_value;
        integer timeout;
        begin
            @(negedge clk);
            write_req_addr[(master * ADDR_BITS) +: ADDR_BITS] = addr;
            write_req_total_size[(master * 8) +: 8] = 8'd3;
            write_req_id[(master * ID_BITS) +: ID_BITS] = id_value;
            write_req_bypass[master] = 1'b1;
            write_req_wdata[(master * LINE_BITS) +: LINE_BITS] = {LINE_BITS{1'b0}};
            write_req_wdata[(master * LINE_BITS) +: 32] = 32'h6000_0000 + id_value;
            write_req_wstrb[(master * LINE_BYTES) +: LINE_BYTES] = {LINE_BYTES{1'b0}};
            write_req_wstrb[(master * LINE_BYTES) +: 4] = 4'hF;
            write_req_valid[master] = 1'b1;
            timeout = 120;
            while (timeout > 0) begin
                @(posedge clk);
                if (write_req_valid[master] && write_req_ready[master]) begin
                    timeout = 0;
                end else begin
                    timeout = timeout - 1;
                end
            end
            if (!(write_req_valid[master] && write_req_ready[master])) begin
                fail_now("write request accept timeout");
            end
            #1;
            if (!write_req_accepted[master]) begin
                fail_now("write accepted pulse missing");
            end
            @(negedge clk);
            write_req_valid[master] = 1'b0;
            write_req_bypass[master] = 1'b0;
        end
    endtask

    task expect_read_blocked;
        input integer master;
        input [ADDR_BITS-1:0] addr;
        input [ID_BITS-1:0] id_value;
        integer cycles;
        begin
            @(negedge clk);
            read_req_addr[(master * ADDR_BITS) +: ADDR_BITS] = addr;
            read_req_total_size[(master * 8) +: 8] = 8'd3;
            read_req_id[(master * ID_BITS) +: ID_BITS] = id_value;
            read_req_bypass[master] = 1'b1;
            read_req_valid[master] = 1'b1;
            for (cycles = 0; cycles < 8; cycles = cycles + 1) begin
                @(posedge clk);
                #1;
                if (read_req_ready[master]) begin
                    fail_now("33rd read was accepted or became ready");
                end
            end
            @(negedge clk);
            read_req_valid[master] = 1'b0;
            read_req_bypass[master] = 1'b0;
        end
    endtask

    task expect_write_blocked;
        input integer master;
        input [ADDR_BITS-1:0] addr;
        input [ID_BITS-1:0] id_value;
        integer cycles;
        begin
            @(negedge clk);
            write_req_addr[(master * ADDR_BITS) +: ADDR_BITS] = addr;
            write_req_total_size[(master * 8) +: 8] = 8'd3;
            write_req_id[(master * ID_BITS) +: ID_BITS] = id_value;
            write_req_bypass[master] = 1'b1;
            write_req_wdata[(master * LINE_BITS) +: LINE_BITS] = {LINE_BITS{1'b0}};
            write_req_wstrb[(master * LINE_BYTES) +: LINE_BYTES] = {LINE_BYTES{1'b0}};
            write_req_wstrb[(master * LINE_BYTES) +: 4] = 4'hF;
            write_req_valid[master] = 1'b1;
            for (cycles = 0; cycles < 8; cycles = cycles + 1) begin
                @(posedge clk);
                #1;
                if (write_req_ready[master]) begin
                    fail_now("33rd write was accepted or became ready");
                end
            end
            @(negedge clk);
            write_req_valid[master] = 1'b0;
            write_req_bypass[master] = 1'b0;
        end
    endtask

    task wait_counts;
        input integer exp_ddr_ar;
        input integer exp_mmio_ar;
        input integer exp_ddr_aw;
        input integer exp_mmio_aw;
        input integer exp_ddr_w;
        input integer exp_mmio_w;
        integer timeout;
        begin
            timeout = 400;
            while (((ddr_ar_count < exp_ddr_ar) ||
                    (mmio_ar_count < exp_mmio_ar) ||
                    (ddr_aw_count < exp_ddr_aw) ||
                    (mmio_aw_count < exp_mmio_aw) ||
                    (ddr_w_count < exp_ddr_w) ||
                    (mmio_w_count < exp_mmio_w)) &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if ((ddr_ar_count != exp_ddr_ar) ||
                (mmio_ar_count != exp_mmio_ar) ||
                (ddr_aw_count != exp_ddr_aw) ||
                (mmio_aw_count != exp_mmio_aw) ||
                (ddr_w_count != exp_ddr_w) ||
                (mmio_w_count != exp_mmio_w)) begin
                fail_now("AXI issued-count mismatch");
            end
        end
    endtask

    task fill_shared_reads;
        begin
            for (idx = 0; idx < LIMIT; idx = idx + 1) begin
                issue_read(idx % 2, read_addr_for_index(idx), idx >> 1);
            end
            wait_counts(LIMIT / 2, LIMIT / 2, 0, 0, 0, 0);
        end
    endtask

    task fill_shared_writes;
        begin
            for (idx = 0; idx < LIMIT; idx = idx + 1) begin
                issue_write(idx % 2, write_addr_for_index(idx), idx >> 1);
            end
            wait_counts(0, 0, LIMIT / 2, LIMIT / 2, LIMIT / 2, LIMIT / 2);
        end
    endtask

    task test_read_response_owner;
        integer timeout;
        begin
            reset_dut();
            ddr_axi_arready = 1'b0;
            mmio_axi_arready = 1'b0;

            issue_read(0, DDR_BASE_ADDR + 32'h0007_0000, 4'h3);
            issue_read(1, MMIO_BASE_ADDR + 32'h0000_0120, 4'h4);

            timeout = 160;
            while (!(ddr_axi_arvalid && mmio_axi_arvalid) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("DDR/MMIO read AR overlap timeout");
            end
            if (ddr_axi_araddr != DDR_BASE_ADDR + 32'h0007_0000 ||
                ddr_axi_arlen != 8'd0 ||
                ddr_axi_arsize != 3'd5 ||
                ddr_axi_arburst != 2'b01) begin
                fail_now("DDR owner-test AR shape mismatch");
            end
            if (mmio_axi_araddr != MMIO_BASE_ADDR + 32'h0000_0120 ||
                mmio_axi_arlen != 8'd0 ||
                mmio_axi_arsize != 3'd2 ||
                mmio_axi_arburst != 2'b01) begin
                fail_now("MMIO owner-test AR shape mismatch");
            end
            seen_ddr_arid = ddr_axi_arid;
            seen_mmio_arid = mmio_axi_arid;
            ddr_axi_arready = 1'b1;
            mmio_axi_arready = 1'b1;
            @(posedge clk);
            ddr_axi_arready = 1'b0;
            mmio_axi_arready = 1'b0;

            @(negedge clk);
            mmio_axi_rid = seen_mmio_arid;
            mmio_axi_rdata = 32'hA5A5_0120;
            mmio_axi_rresp = AXI_RESP_OKAY;
            mmio_axi_rlast = 1'b1;
            mmio_axi_rvalid = 1'b1;
            timeout = 80;
            while (!mmio_axi_rready && (timeout > 0)) begin
                @(negedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("MMIO owner-test R handshake timeout");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_rvalid = 1'b0;

            timeout = 120;
            while (!read_resp_valid[1] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("MMIO owner-test read response timeout");
            end
            if (read_resp_valid[0]) begin
                fail_now("DDR read response asserted before DDR R");
            end
            if (read_resp_id[(1 * ID_BITS) +: ID_BITS] != 4'h4 ||
                read_resp_data[(1 * READ_RESP_BITS) +: 32] != 32'hA5A5_0120) begin
                fail_now("MMIO owner-test read response mismatch");
            end
            read_resp_ready[1] = 1'b1;
            @(posedge clk);
            read_resp_ready[1] = 1'b0;

            @(negedge clk);
            ddr_axi_rid = seen_ddr_arid;
            ddr_axi_rdata = {DDR_DATA_BITS{1'b0}};
            ddr_axi_rdata[31:0] = 32'hD00D_0700;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b1;
            ddr_axi_rvalid = 1'b1;
            timeout = 80;
            while (!ddr_axi_rready && (timeout > 0)) begin
                @(negedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("DDR owner-test R handshake timeout");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;

            timeout = 120;
            while (!read_resp_valid[0] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("DDR owner-test read response timeout");
            end
            if (read_resp_id[ID_BITS-1:0] != 4'h3 ||
                read_resp_data[31:0] != 32'hD00D_0700) begin
                fail_now("DDR owner-test read response mismatch");
            end
            read_resp_ready[0] = 1'b1;
            @(posedge clk);
            read_resp_ready[0] = 1'b0;
        end
    endtask

    task test_write_response_owner;
        integer timeout;
        begin
            reset_dut();
            ddr_axi_awready = 1'b0;
            ddr_axi_wready = 1'b0;
            mmio_axi_awready = 1'b0;
            mmio_axi_wready = 1'b0;

            issue_write(0, DDR_BASE_ADDR + 32'h0006_0000, 4'h1);
            issue_write(1, MMIO_BASE_ADDR + 32'h0000_0100, 4'h2);

            timeout = 160;
            while (!(ddr_axi_awvalid && mmio_axi_awvalid) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("DDR/MMIO write AW overlap timeout");
            end
            if (ddr_axi_awaddr != DDR_BASE_ADDR + 32'h0006_0000 ||
                ddr_axi_awlen != 8'd0 ||
                ddr_axi_awsize != 3'd5 ||
                ddr_axi_awburst != 2'b01) begin
                fail_now("DDR owner-test AW shape mismatch");
            end
            if (mmio_axi_awaddr != MMIO_BASE_ADDR + 32'h0000_0100 ||
                mmio_axi_awlen != 8'd0 ||
                mmio_axi_awsize != 3'd2 ||
                mmio_axi_awburst != 2'b01) begin
                fail_now("MMIO owner-test AW shape mismatch");
            end
            seen_ddr_awid = ddr_axi_awid;
            seen_mmio_awid = mmio_axi_awid;
            ddr_axi_awready = 1'b1;
            mmio_axi_awready = 1'b1;
            @(posedge clk);
            ddr_axi_awready = 1'b0;
            mmio_axi_awready = 1'b0;

            timeout = 160;
            while (!(ddr_axi_wvalid && mmio_axi_wvalid) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("DDR/MMIO write W overlap timeout");
            end
            if (!ddr_axi_wlast ||
                ddr_axi_wdata[31:0] != (32'h6000_0000 + 4'h1) ||
                ddr_axi_wstrb[3:0] != 4'hF) begin
                fail_now("DDR owner-test W shape mismatch");
            end
            if (!mmio_axi_wlast ||
                mmio_axi_wdata != (32'h6000_0000 + 4'h2) ||
                mmio_axi_wstrb != 4'hF) begin
                fail_now("MMIO owner-test W shape mismatch");
            end
            ddr_axi_wready = 1'b1;
            mmio_axi_wready = 1'b1;
            @(posedge clk);
            ddr_axi_wready = 1'b0;
            mmio_axi_wready = 1'b0;

            @(negedge clk);
            mmio_axi_bid = seen_mmio_awid;
            mmio_axi_bresp = 2'b10;
            mmio_axi_bvalid = 1'b1;
            timeout = 80;
            while (!mmio_axi_bready && (timeout > 0)) begin
                @(negedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("MMIO owner-test B handshake timeout");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_bvalid = 1'b0;

            timeout = 120;
            while (!write_resp_valid[1] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("MMIO owner-test response timeout");
            end
            if (write_resp_valid[0]) begin
                fail_now("DDR master response asserted before DDR B");
            end
            if (write_resp_id[(1 * ID_BITS) +: ID_BITS] != 4'h2 ||
                write_resp_code[(1 * 2) +: 2] != 2'b10) begin
                fail_now("MMIO owner-test response mismatch");
            end
            write_resp_ready[1] = 1'b1;
            @(posedge clk);
            write_resp_ready[1] = 1'b0;

            @(negedge clk);
            ddr_axi_bid = seen_ddr_awid;
            ddr_axi_bresp = AXI_RESP_OKAY;
            ddr_axi_bvalid = 1'b1;
            timeout = 80;
            while (!ddr_axi_bready && (timeout > 0)) begin
                @(negedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("DDR owner-test B handshake timeout");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_bvalid = 1'b0;

            timeout = 120;
            while (!write_resp_valid[0] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("DDR owner-test response timeout");
            end
            if (write_resp_id[ID_BITS-1:0] != 4'h1 ||
                write_resp_code[1:0] != AXI_RESP_OKAY) begin
                fail_now("DDR owner-test response mismatch");
            end
            write_resp_ready[0] = 1'b1;
            @(posedge clk);
            write_resp_ready[0] = 1'b0;
        end
    endtask

    task test_simultaneous_read_responses_stall_safe;
        integer timeout;
        begin
            reset_dut();
            ddr_axi_arready = 1'b0;
            mmio_axi_arready = 1'b0;

            issue_read(0, DDR_BASE_ADDR + 32'h0008_0000, 4'h5);
            issue_read(1, MMIO_BASE_ADDR + 32'h0000_0140, 4'h6);

            timeout = 160;
            while (!(ddr_axi_arvalid && mmio_axi_arvalid) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("simultaneous response read AR overlap timeout");
            end
            seen_ddr_arid = ddr_axi_arid;
            seen_mmio_arid = mmio_axi_arid;
            ddr_axi_arready = 1'b1;
            mmio_axi_arready = 1'b1;
            @(posedge clk);
            ddr_axi_arready = 1'b0;
            mmio_axi_arready = 1'b0;

            @(negedge clk);
            ddr_axi_rid = seen_ddr_arid;
            ddr_axi_rdata = {DDR_DATA_BITS{1'b0}};
            ddr_axi_rdata[31:0] = 32'hD00D_0800;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b1;
            ddr_axi_rvalid = 1'b1;
            mmio_axi_rid = seen_mmio_arid;
            mmio_axi_rdata = 32'hA5A5_0140;
            mmio_axi_rresp = AXI_RESP_OKAY;
            mmio_axi_rlast = 1'b1;
            mmio_axi_rvalid = 1'b1;
            #1;
            if (!ddr_axi_rready) begin
                fail_now("DDR R was backpressured by top read response stall");
            end
            if (!mmio_axi_rready) begin
                fail_now("MMIO R was backpressured by top read response stall");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;
            ddr_axi_rlast = 1'b0;
            mmio_axi_rvalid = 1'b0;
            mmio_axi_rlast = 1'b0;

            timeout = 160;
            while ((!read_resp_valid[0] || !read_resp_valid[1]) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("simultaneous read responses were not buffered");
            end
            if (read_resp_id[ID_BITS-1:0] != 4'h5 ||
                read_resp_data[31:0] != 32'hD00D_0800) begin
                fail_now("buffered DDR read response mismatch after simultaneous R");
            end
            if (read_resp_id[(1 * ID_BITS) +: ID_BITS] != 4'h6 ||
                read_resp_data[(1 * READ_RESP_BITS) +: 32] != 32'hA5A5_0140) begin
                fail_now("buffered MMIO read response mismatch after simultaneous R");
            end
            read_resp_ready[0] = 1'b1;
            read_resp_ready[1] = 1'b1;
            @(posedge clk);
            read_resp_ready[0] = 1'b0;
            read_resp_ready[1] = 1'b0;
        end
    endtask

    task test_simultaneous_write_responses_stall_safe;
        integer timeout;
        begin
            reset_dut();
            ddr_axi_awready = 1'b0;
            ddr_axi_wready = 1'b0;
            mmio_axi_awready = 1'b0;
            mmio_axi_wready = 1'b0;

            issue_write(0, DDR_BASE_ADDR + 32'h0009_0000, 4'h7);
            issue_write(1, MMIO_BASE_ADDR + 32'h0000_0180, 4'h8);

            timeout = 160;
            while (!(ddr_axi_awvalid && mmio_axi_awvalid) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("simultaneous response write AW overlap timeout");
            end
            seen_ddr_awid = ddr_axi_awid;
            seen_mmio_awid = mmio_axi_awid;
            ddr_axi_awready = 1'b1;
            mmio_axi_awready = 1'b1;
            @(posedge clk);
            ddr_axi_awready = 1'b0;
            mmio_axi_awready = 1'b0;

            timeout = 160;
            while (!(ddr_axi_wvalid && mmio_axi_wvalid) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("simultaneous response write W overlap timeout");
            end
            ddr_axi_wready = 1'b1;
            mmio_axi_wready = 1'b1;
            @(posedge clk);
            ddr_axi_wready = 1'b0;
            mmio_axi_wready = 1'b0;

            @(negedge clk);
            ddr_axi_bid = seen_ddr_awid;
            ddr_axi_bresp = AXI_RESP_OKAY;
            ddr_axi_bvalid = 1'b1;
            mmio_axi_bid = seen_mmio_awid;
            mmio_axi_bresp = 2'b10;
            mmio_axi_bvalid = 1'b1;
            #1;
            if (!ddr_axi_bready) begin
                fail_now("DDR B was backpressured by top write response stall");
            end
            if (!mmio_axi_bready) begin
                fail_now("MMIO B was backpressured by top write response stall");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_bvalid = 1'b0;
            mmio_axi_bvalid = 1'b0;

            timeout = 160;
            while ((!write_resp_valid[0] || !write_resp_valid[1]) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("simultaneous write responses were not buffered");
            end
            if (write_resp_id[ID_BITS-1:0] != 4'h7 ||
                write_resp_code[1:0] != AXI_RESP_OKAY) begin
                fail_now("buffered DDR write response mismatch after simultaneous B");
            end
            if (write_resp_id[(1 * ID_BITS) +: ID_BITS] != 4'h8 ||
                write_resp_code[(1 * 2) +: 2] != 2'b10) begin
                fail_now("buffered MMIO write response mismatch after simultaneous B");
            end
            write_resp_ready[0] = 1'b1;
            write_resp_ready[1] = 1'b1;
            @(posedge clk);
            write_resp_ready[0] = 1'b0;
            write_resp_ready[1] = 1'b0;
        end
    endtask

    task test_read_budget_blocks_read_not_write;
        begin
            reset_dut();
            fill_shared_reads();
            expect_read_blocked(2, DDR_BASE_ADDR + 32'h0002_0000, 4'h0);
            for (idx = 0; idx < LIMIT; idx = idx + 1) begin
                issue_write(idx % 2, write_addr_for_index(idx), idx >> 1);
            end
            expect_write_blocked(2, DDR_BASE_ADDR + 32'h0003_0000, 4'h0);
        end
    endtask

    task test_write_budget_blocks_write_not_read;
        begin
            reset_dut();
            fill_shared_writes();
            expect_write_blocked(2, DDR_BASE_ADDR + 32'h0004_0000, 4'h0);
            for (idx = 0; idx < LIMIT; idx = idx + 1) begin
                issue_read(idx % 2, read_addr_for_index(idx), idx >> 1);
            end
            expect_read_blocked(2, DDR_BASE_ADDR + 32'h0005_0000, 4'h0);
        end
    endtask

    axi_llc_subsystem_dual #(
        .ADDR_BITS         (ADDR_BITS),
        .ID_BITS           (ID_BITS),
        .SLOT_ID_BITS      (SLOT_ID_BITS),
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
        .RESET_OFFSET      (32'h3000_0000),
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
        test_read_response_owner();
        test_write_response_owner();
        test_simultaneous_read_responses_stall_safe();
        test_simultaneous_write_responses_stall_safe();
        test_read_budget_blocks_read_not_write();
        test_write_budget_blocks_write_not_read();

        if (config_error) begin
            fail_now("config_error asserted unexpectedly");
        end

        $display("tb_axi_llc_subsystem_dual_outstanding_contract PASS");
        $finish(0);
    end

endmodule
