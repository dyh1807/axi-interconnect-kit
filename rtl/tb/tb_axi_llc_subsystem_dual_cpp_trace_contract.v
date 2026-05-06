`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_dual_cpp_trace_contract;

    localparam ADDR_BITS          = `AXI_LLC_ADDR_BITS;
    localparam ID_BITS            = `AXI_LLC_ID_BITS;
    localparam SLOT_ID_BITS       = `AXI_LLC_SLOT_ID_BITS;
    localparam MODE_BITS          = `AXI_LLC_MODE_BITS;
    localparam LINE_BYTES         = `AXI_LLC_LINE_BYTES;
    localparam LINE_BITS          = `AXI_LLC_LINE_BITS;
    localparam LINE_OFFSET_BITS   = `AXI_LLC_LINE_OFFSET_BITS;
    localparam SET_COUNT          = 2048;
    localparam SET_BITS           = 11;
    localparam WAY_COUNT          = 2;
    localparam WAY_BITS           = 1;
    localparam META_BITS          = `AXI_LLC_META_BITS;
    localparam LLC_SIZE_BYTES     = LINE_BYTES * SET_COUNT * WAY_COUNT;
    localparam WINDOW_BYTES       = LINE_BYTES * SET_COUNT;
    localparam WINDOW_WAYS        = 1;
    localparam NUM_READ_MASTERS   = 4;
    localparam NUM_WRITE_MASTERS  = 2;
    localparam AXI_ID_BITS        = `AXI_LLC_AXI_ID_BITS;
    localparam DDR_DATA_BITS      = `AXI_LLC_AXI_DATA_BITS;
    localparam DDR_STRB_BITS      = `AXI_LLC_AXI_STRB_BITS;
    localparam MMIO_DATA_BITS     = 32;
    localparam MMIO_STRB_BITS     = 4;
    localparam READ_RESP_BITS     = `AXI_LLC_READ_RESP_BITS;

    localparam READ_MASTER        = 1;
    localparam WRITE_MASTER       = 0;
    localparam [MODE_BITS-1:0] MODE_OFF = 2'b00;
    localparam [MODE_BITS-1:0] MODE_CACHE = 2'b01;
    localparam [MODE_BITS-1:0] MODE_MAPPED = 2'b10;
    localparam [1:0] AXI_RESP_OKAY = 2'b00;

`include "axi_dual_cpp_trace_vectors.vh"

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

    reg [AXI_ID_BITS-1:0]              seen_ddr_arid;
    reg [AXI_ID_BITS-1:0]              seen_ddr_awid;
    reg [AXI_ID_BITS-1:0]              seen_mmio_arid;
    reg [AXI_ID_BITS-1:0]              seen_mmio_awid;

    always #5 clk = ~clk;

    task fail_now;
        input [8*240-1:0] msg;
        begin
            $display("tb_axi_llc_subsystem_dual_cpp_trace_contract FAIL: %0s", msg);
            $finish(1);
        end
    endtask

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
            read_resp_ready = {NUM_READ_MASTERS{1'b1}};
            write_resp_ready = {NUM_WRITE_MASTERS{1'b1}};
            clear_read_inputs();
            clear_write_inputs();
            clear_lower_inputs();
            invalidate_line_valid = 1'b0;
            invalidate_line_addr = {ADDR_BITS{1'b0}};
            invalidate_all_valid = 1'b0;
            seen_ddr_arid = {AXI_ID_BITS{1'b0}};
            seen_ddr_awid = {AXI_ID_BITS{1'b0}};
            seen_mmio_arid = {AXI_ID_BITS{1'b0}};
            seen_mmio_awid = {AXI_ID_BITS{1'b0}};
            repeat (5) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;
            timeout = 6000;
            while (((active_mode != MODE_OFF) || reconfig_busy) &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("mode-off reset did not settle");
            end
            @(negedge clk);
        end
    endtask

    task enter_mode;
        input [MODE_BITS-1:0] target_mode;
        integer timeout;
        begin
            @(negedge clk);
            mode_req = target_mode;
            timeout = 6000;
            while (((active_mode != target_mode) || reconfig_busy) &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("requested mode did not settle");
            end
            @(negedge clk);
        end
    endtask

    task expect_no_mmio_activity;
        begin
            if (mmio_axi_arvalid || mmio_axi_awvalid || mmio_axi_wvalid) begin
                fail_now("MODE_OFF DDR trace leaked to MMIO AXI port");
            end
        end
    endtask

    task expect_no_ddr_activity;
        begin
            if (ddr_axi_arvalid || ddr_axi_awvalid || ddr_axi_wvalid) begin
                fail_now("MODE_OFF MMIO trace leaked to DDR AXI port");
            end
        end
    endtask

    task issue_read_and_check;
        input [MODE_BITS-1:0] start_mode;
        input [31:0] req_addr;
        input [7:0] req_size;
        input [3:0] req_id;
        input [31:0] exp_araddr;
        input [7:0] exp_arlen;
        input [2:0] exp_arsize;
        input [1:0] exp_arburst;
        input [5:0] exp_arid;
        input integer beat_count;
        input [255:0] rbeat0;
        input [255:0] rbeat1;
        input [3:0] exp_resp_id;
        input [2047:0] exp_resp_data;
        integer timeout;
        reg accepted_seen;
        reg [ID_BITS-1:0] accepted_id_seen;
        begin
            reset_dut();
            if (start_mode != MODE_OFF) begin
                enter_mode(start_mode);
            end
            @(negedge clk);
            ddr_axi_arready = 1'b0;
            accepted_seen = 1'b0;
            accepted_id_seen = {ID_BITS{1'b0}};
            read_req_addr[(READ_MASTER * ADDR_BITS) +: ADDR_BITS] = req_addr;
            read_req_total_size[(READ_MASTER * 8) +: 8] = req_size;
            read_req_id[(READ_MASTER * ID_BITS) +: ID_BITS] = req_id;
            read_req_bypass[READ_MASTER] = 1'b0;
            read_req_valid[READ_MASTER] = 1'b1;

            #1;
            if (read_req_accepted[READ_MASTER]) begin
                accepted_seen = 1'b1;
                accepted_id_seen =
                    read_req_accepted_id[(READ_MASTER * ID_BITS) +: ID_BITS];
            end
            timeout = 80;
            while (!ddr_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[READ_MASTER]) begin
                    accepted_seen = 1'b1;
                    accepted_id_seen =
                        read_req_accepted_id[(READ_MASTER * ID_BITS) +: ID_BITS];
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace read did not issue DDR AR");
            end
            #1;
            expect_no_mmio_activity();
            if (ddr_axi_araddr != exp_araddr ||
                ddr_axi_arlen != exp_arlen ||
                ddr_axi_arsize != exp_arsize ||
                ddr_axi_arburst != exp_arburst ||
                ddr_axi_arid != exp_arid) begin
                fail_now("C++ trace read AR mismatch");
            end
            seen_ddr_arid = ddr_axi_arid;
            ddr_axi_arready = 1'b1;
            @(posedge clk);
            #1;
            if (read_req_accepted[READ_MASTER]) begin
                accepted_seen = 1'b1;
                accepted_id_seen =
                    read_req_accepted_id[(READ_MASTER * ID_BITS) +: ID_BITS];
            end
            if (!accepted_seen || accepted_id_seen != req_id) begin
                fail_now("C++ trace read accepted metadata mismatch");
            end
            @(negedge clk);
            read_req_valid[READ_MASTER] = 1'b0;
            read_req_bypass[READ_MASTER] = 1'b0;

            ddr_axi_rid = seen_ddr_arid;
            ddr_axi_rdata = rbeat0;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = (beat_count == 1);
            ddr_axi_rvalid = 1'b1;
            #1;
            if (!ddr_axi_rready) begin
                fail_now("C++ trace read first R beat was backpressured");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;
            ddr_axi_rlast = 1'b0;
            if ((beat_count == 2) && read_resp_valid[READ_MASTER]) begin
                fail_now("C++ trace read responded before final R beat");
            end

            if (beat_count == 2) begin
                ddr_axi_rid = seen_ddr_arid;
                ddr_axi_rdata = rbeat1;
                ddr_axi_rresp = AXI_RESP_OKAY;
                ddr_axi_rlast = 1'b1;
                ddr_axi_rvalid = 1'b1;
                #1;
                if (!ddr_axi_rready) begin
                    fail_now("C++ trace read second R beat was backpressured");
                end
                @(posedge clk);
                @(negedge clk);
                ddr_axi_rvalid = 1'b0;
                ddr_axi_rlast = 1'b0;
            end

            timeout = 120;
            while (!read_resp_valid[READ_MASTER] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace read response timeout");
            end
            #1;
            if (read_resp_id[(READ_MASTER * ID_BITS) +: ID_BITS] != exp_resp_id ||
                read_resp_data[(READ_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    exp_resp_data) begin
                fail_now("C++ trace read response mismatch");
            end
        end
    endtask

    task issue_write_and_check;
        input [MODE_BITS-1:0] start_mode;
        input [31:0] req_addr;
        input [7:0] req_size;
        input [3:0] req_id;
        input [511:0] req_wdata;
        input [63:0] req_wstrb;
        input [31:0] exp_awaddr;
        input [7:0] exp_awlen;
        input [2:0] exp_awsize;
        input [1:0] exp_awburst;
        input [5:0] exp_awid;
        input integer beat_count;
        input [255:0] wbeat0;
        input [31:0] wstrb0;
        input wlast0;
        input [255:0] wbeat1;
        input [31:0] wstrb1;
        input wlast1;
        input [3:0] exp_resp_id;
        input [1:0] exp_resp_code;
        integer timeout;
        reg accepted_seen;
        begin
            reset_dut();
            if (start_mode != MODE_OFF) begin
                enter_mode(start_mode);
            end
            @(negedge clk);
            ddr_axi_awready = 1'b0;
            ddr_axi_wready = 1'b0;
            accepted_seen = 1'b0;
            write_req_addr[(WRITE_MASTER * ADDR_BITS) +: ADDR_BITS] = req_addr;
            write_req_total_size[(WRITE_MASTER * 8) +: 8] = req_size;
            write_req_id[(WRITE_MASTER * ID_BITS) +: ID_BITS] = req_id;
            write_req_wdata[(WRITE_MASTER * LINE_BITS) +: LINE_BITS] = req_wdata;
            write_req_wstrb[(WRITE_MASTER * LINE_BYTES) +: LINE_BYTES] = req_wstrb[LINE_BYTES-1:0];
            write_req_bypass[WRITE_MASTER] = 1'b0;
            write_req_valid[WRITE_MASTER] = 1'b1;

            #1;
            if (write_req_accepted[WRITE_MASTER]) begin
                accepted_seen = 1'b1;
            end
            timeout = 80;
            while (!ddr_axi_awvalid && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[WRITE_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace write did not issue DDR AW");
            end
            #1;
            expect_no_mmio_activity();
            if (ddr_axi_awaddr != exp_awaddr ||
                ddr_axi_awlen != exp_awlen ||
                ddr_axi_awsize != exp_awsize ||
                ddr_axi_awburst != exp_awburst ||
                ddr_axi_awid != exp_awid) begin
                fail_now("C++ trace write AW mismatch");
            end
            seen_ddr_awid = ddr_axi_awid;
            ddr_axi_awready = 1'b1;
            @(posedge clk);
            #1;
            if (write_req_accepted[WRITE_MASTER]) begin
                accepted_seen = 1'b1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace write accepted pulse missing");
            end
            @(negedge clk);
            write_req_valid[WRITE_MASTER] = 1'b0;
            write_req_bypass[WRITE_MASTER] = 1'b0;

            timeout = 80;
            while (!ddr_axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace write first W timeout");
            end
            #1;
            if (ddr_axi_wdata != wbeat0 ||
                ddr_axi_wstrb != wstrb0 ||
                ddr_axi_wlast != wlast0) begin
                fail_now("C++ trace write first W mismatch");
            end
            ddr_axi_wready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_wready = 1'b0;

            if (beat_count == 2) begin
                timeout = 80;
                while (!ddr_axi_wvalid && (timeout > 0)) begin
                    @(posedge clk);
                    timeout = timeout - 1;
                end
                if (timeout == 0) begin
                    fail_now("C++ trace write second W timeout");
                end
                #1;
                if (ddr_axi_wdata != wbeat1 ||
                    ddr_axi_wstrb != wstrb1 ||
                    ddr_axi_wlast != wlast1) begin
                    fail_now("C++ trace write second W mismatch");
                end
                ddr_axi_wready = 1'b1;
                @(posedge clk);
                @(negedge clk);
                ddr_axi_wready = 1'b0;
            end

            ddr_axi_bid = seen_ddr_awid;
            ddr_axi_bresp = AXI_RESP_OKAY;
            ddr_axi_bvalid = 1'b1;
            timeout = 80;
            while (!ddr_axi_bready && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace write B was backpressured");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_bvalid = 1'b0;

            timeout = 120;
            while (!write_resp_valid[WRITE_MASTER] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace write response timeout");
            end
            #1;
            if (write_resp_id[(WRITE_MASTER * ID_BITS) +: ID_BITS] != exp_resp_id ||
                write_resp_code[(WRITE_MASTER * 2) +: 2] != exp_resp_code) begin
                fail_now("C++ trace write response mismatch");
            end
        end
    endtask

    task issue_mmio_read_and_check;
        input [MODE_BITS-1:0] start_mode;
        input [31:0] req_addr;
        input [7:0] req_size;
        input [3:0] req_id;
        input [31:0] exp_araddr;
        input [7:0] exp_arlen;
        input [2:0] exp_arsize;
        input [1:0] exp_arburst;
        input [5:0] exp_arid;
        input [255:0] rbeat0;
        input [3:0] exp_resp_id;
        input [2047:0] exp_resp_data;
        integer timeout;
        reg accepted_seen;
        reg [ID_BITS-1:0] accepted_id_seen;
        begin
            reset_dut();
            if (start_mode != MODE_OFF) begin
                enter_mode(start_mode);
            end
            @(negedge clk);
            mmio_axi_arready = 1'b0;
            accepted_seen = 1'b0;
            accepted_id_seen = {ID_BITS{1'b0}};
            read_req_addr[(READ_MASTER * ADDR_BITS) +: ADDR_BITS] = req_addr;
            read_req_total_size[(READ_MASTER * 8) +: 8] = req_size;
            read_req_id[(READ_MASTER * ID_BITS) +: ID_BITS] = req_id;
            read_req_bypass[READ_MASTER] = 1'b0;
            read_req_valid[READ_MASTER] = 1'b1;

            #1;
            if (read_req_accepted[READ_MASTER]) begin
                accepted_seen = 1'b1;
                accepted_id_seen =
                    read_req_accepted_id[(READ_MASTER * ID_BITS) +: ID_BITS];
            end
            timeout = 80;
            while (!mmio_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[READ_MASTER]) begin
                    accepted_seen = 1'b1;
                    accepted_id_seen =
                        read_req_accepted_id[(READ_MASTER * ID_BITS) +: ID_BITS];
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace MMIO read did not issue MMIO AR");
            end
            #1;
            expect_no_ddr_activity();
            if (mmio_axi_araddr != exp_araddr ||
                mmio_axi_arlen != exp_arlen ||
                mmio_axi_arsize != exp_arsize ||
                mmio_axi_arburst != exp_arburst ||
                mmio_axi_arid != exp_arid) begin
                fail_now("C++ trace MMIO read AR mismatch");
            end
            seen_mmio_arid = mmio_axi_arid;
            mmio_axi_arready = 1'b1;
            @(posedge clk);
            #1;
            if (read_req_accepted[READ_MASTER]) begin
                accepted_seen = 1'b1;
                accepted_id_seen =
                    read_req_accepted_id[(READ_MASTER * ID_BITS) +: ID_BITS];
            end
            if (!accepted_seen || accepted_id_seen != req_id) begin
                fail_now("C++ trace MMIO read accepted metadata mismatch");
            end
            @(negedge clk);
            read_req_valid[READ_MASTER] = 1'b0;
            read_req_bypass[READ_MASTER] = 1'b0;

            mmio_axi_rid = seen_mmio_arid;
            mmio_axi_rdata = rbeat0[MMIO_DATA_BITS-1:0];
            mmio_axi_rresp = AXI_RESP_OKAY;
            mmio_axi_rlast = 1'b1;
            mmio_axi_rvalid = 1'b1;
            #1;
            if (!mmio_axi_rready) begin
                fail_now("C++ trace MMIO read R was backpressured");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_rvalid = 1'b0;
            mmio_axi_rlast = 1'b0;

            timeout = 120;
            while (!read_resp_valid[READ_MASTER] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace MMIO read response timeout");
            end
            #1;
            if (read_resp_id[(READ_MASTER * ID_BITS) +: ID_BITS] != exp_resp_id ||
                read_resp_data[(READ_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    exp_resp_data) begin
                fail_now("C++ trace MMIO read response mismatch");
            end
        end
    endtask

    task issue_mmio_write_and_check;
        input [MODE_BITS-1:0] start_mode;
        input [31:0] req_addr;
        input [7:0] req_size;
        input [3:0] req_id;
        input [511:0] req_wdata;
        input [63:0] req_wstrb;
        input [31:0] exp_awaddr;
        input [7:0] exp_awlen;
        input [2:0] exp_awsize;
        input [1:0] exp_awburst;
        input [5:0] exp_awid;
        input [255:0] wbeat0;
        input [31:0] wstrb0;
        input wlast0;
        input [3:0] exp_resp_id;
        input [1:0] exp_resp_code;
        integer timeout;
        reg accepted_seen;
        begin
            reset_dut();
            if (start_mode != MODE_OFF) begin
                enter_mode(start_mode);
            end
            @(negedge clk);
            mmio_axi_awready = 1'b0;
            mmio_axi_wready = 1'b0;
            accepted_seen = 1'b0;
            write_req_addr[(WRITE_MASTER * ADDR_BITS) +: ADDR_BITS] = req_addr;
            write_req_total_size[(WRITE_MASTER * 8) +: 8] = req_size;
            write_req_id[(WRITE_MASTER * ID_BITS) +: ID_BITS] = req_id;
            write_req_wdata[(WRITE_MASTER * LINE_BITS) +: LINE_BITS] = req_wdata;
            write_req_wstrb[(WRITE_MASTER * LINE_BYTES) +: LINE_BYTES] = req_wstrb[LINE_BYTES-1:0];
            write_req_bypass[WRITE_MASTER] = 1'b0;
            write_req_valid[WRITE_MASTER] = 1'b1;

            #1;
            if (write_req_accepted[WRITE_MASTER]) begin
                accepted_seen = 1'b1;
            end
            timeout = 80;
            while (!mmio_axi_awvalid && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[WRITE_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace MMIO write did not issue MMIO AW");
            end
            #1;
            expect_no_ddr_activity();
            if (mmio_axi_awaddr != exp_awaddr ||
                mmio_axi_awlen != exp_awlen ||
                mmio_axi_awsize != exp_awsize ||
                mmio_axi_awburst != exp_awburst ||
                mmio_axi_awid != exp_awid) begin
                fail_now("C++ trace MMIO write AW mismatch");
            end
            seen_mmio_awid = mmio_axi_awid;
            mmio_axi_awready = 1'b1;
            @(posedge clk);
            #1;
            if (write_req_accepted[WRITE_MASTER]) begin
                accepted_seen = 1'b1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace MMIO write accepted pulse missing");
            end
            @(negedge clk);
            write_req_valid[WRITE_MASTER] = 1'b0;
            write_req_bypass[WRITE_MASTER] = 1'b0;

            timeout = 80;
            while (!mmio_axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace MMIO write W timeout");
            end
            #1;
            expect_no_ddr_activity();
            if (mmio_axi_wdata != wbeat0[MMIO_DATA_BITS-1:0] ||
                mmio_axi_wstrb != wstrb0[MMIO_STRB_BITS-1:0] ||
                mmio_axi_wlast != wlast0) begin
                fail_now("C++ trace MMIO write W mismatch");
            end
            mmio_axi_wready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_wready = 1'b0;

            mmio_axi_bid = seen_mmio_awid;
            mmio_axi_bresp = AXI_RESP_OKAY;
            mmio_axi_bvalid = 1'b1;
            timeout = 80;
            while (!mmio_axi_bready && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace MMIO write B was backpressured");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_bvalid = 1'b0;

            timeout = 120;
            while (!write_resp_valid[WRITE_MASTER] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace MMIO write response timeout");
            end
            #1;
            if (write_resp_id[(WRITE_MASTER * ID_BITS) +: ID_BITS] != exp_resp_id ||
                write_resp_code[(WRITE_MASTER * 2) +: 2] != exp_resp_code) begin
                fail_now("C++ trace MMIO write response mismatch");
            end
        end
    endtask

    task issue_unsupported_mmio_read_and_check;
        input [MODE_BITS-1:0] start_mode;
        input [31:0] req_addr;
        input [7:0] req_size;
        input [3:0] req_id;
        input exp_req_ready;
        integer cycles;
        begin
            reset_dut();
            if (start_mode != MODE_OFF) begin
                enter_mode(start_mode);
            end
            @(negedge clk);
            read_req_addr[(READ_MASTER * ADDR_BITS) +: ADDR_BITS] = req_addr;
            read_req_total_size[(READ_MASTER * 8) +: 8] = req_size;
            read_req_id[(READ_MASTER * ID_BITS) +: ID_BITS] = req_id;
            read_req_bypass[READ_MASTER] = 1'b0;
            read_req_valid[READ_MASTER] = 1'b1;

            for (cycles = 0; cycles < 5; cycles = cycles + 1) begin
                #1;
                if (read_req_ready[READ_MASTER] !== exp_req_ready) begin
                    fail_now("C++ trace unsupported MMIO read ready mismatch");
                end
                if (read_req_accepted[READ_MASTER]) begin
                    fail_now("C++ trace unsupported MMIO read was accepted");
                end
                if (ddr_axi_arvalid || mmio_axi_arvalid ||
                    ddr_axi_awvalid || mmio_axi_awvalid ||
                    ddr_axi_wvalid || mmio_axi_wvalid) begin
                    fail_now("C++ trace unsupported MMIO read escaped to AXI");
                end
                @(posedge clk);
                @(negedge clk);
            end
            read_req_valid[READ_MASTER] = 1'b0;
        end
    endtask

    task issue_unsupported_mmio_write_and_check;
        input [MODE_BITS-1:0] start_mode;
        input [31:0] req_addr;
        input [7:0] req_size;
        input [3:0] req_id;
        input [511:0] req_wdata;
        input [63:0] req_wstrb;
        input exp_req_ready;
        integer cycles;
        begin
            reset_dut();
            if (start_mode != MODE_OFF) begin
                enter_mode(start_mode);
            end
            @(negedge clk);
            write_req_addr[(WRITE_MASTER * ADDR_BITS) +: ADDR_BITS] = req_addr;
            write_req_total_size[(WRITE_MASTER * 8) +: 8] = req_size;
            write_req_id[(WRITE_MASTER * ID_BITS) +: ID_BITS] = req_id;
            write_req_wdata[(WRITE_MASTER * LINE_BITS) +: LINE_BITS] = req_wdata;
            write_req_wstrb[(WRITE_MASTER * LINE_BYTES) +: LINE_BYTES] = req_wstrb[LINE_BYTES-1:0];
            write_req_bypass[WRITE_MASTER] = 1'b0;
            write_req_valid[WRITE_MASTER] = 1'b1;

            for (cycles = 0; cycles < 5; cycles = cycles + 1) begin
                #1;
                if (write_req_ready[WRITE_MASTER] !== exp_req_ready) begin
                    fail_now("C++ trace unsupported MMIO write ready mismatch");
                end
                if (write_req_accepted[WRITE_MASTER]) begin
                    fail_now("C++ trace unsupported MMIO write was accepted");
                end
                if (ddr_axi_arvalid || mmio_axi_arvalid ||
                    ddr_axi_awvalid || mmio_axi_awvalid ||
                    ddr_axi_wvalid || mmio_axi_wvalid) begin
                    fail_now("C++ trace unsupported MMIO write escaped to AXI");
                end
                @(posedge clk);
                @(negedge clk);
            end
            write_req_valid[WRITE_MASTER] = 1'b0;
        end
    endtask

    task issue_invalidate_all_blocked_read_and_check;
        input [31:0] req_addr;
        input [7:0] req_size;
        input [3:0] req_id;
        input exp_req_ready;
        integer cycles;
        begin
            reset_dut();
            enter_mode(MODE_CACHE);
            @(negedge clk);
            invalidate_all_valid = 1'b1;
            read_req_addr[(READ_MASTER * ADDR_BITS) +: ADDR_BITS] = req_addr;
            read_req_total_size[(READ_MASTER * 8) +: 8] = req_size;
            read_req_id[(READ_MASTER * ID_BITS) +: ID_BITS] = req_id;
            read_req_bypass[READ_MASTER] = 1'b0;
            read_req_valid[READ_MASTER] = 1'b1;

            for (cycles = 0; cycles < 5; cycles = cycles + 1) begin
                #1;
                if (read_req_ready[READ_MASTER] !== exp_req_ready) begin
                    fail_now("C++ trace invalidate-all read ready mismatch");
                end
                if (read_req_accepted[READ_MASTER]) begin
                    fail_now("C++ trace invalidate-all read was accepted");
                end
                if (ddr_axi_arvalid || mmio_axi_arvalid ||
                    ddr_axi_awvalid || mmio_axi_awvalid ||
                    ddr_axi_wvalid || mmio_axi_wvalid) begin
                    fail_now("C++ trace invalidate-all read escaped to AXI");
                end
                @(posedge clk);
                @(negedge clk);
            end
            read_req_valid[READ_MASTER] = 1'b0;
            invalidate_all_valid = 1'b0;
        end
    endtask

    task issue_invalidate_all_blocked_write_and_check;
        input [31:0] req_addr;
        input [7:0] req_size;
        input [3:0] req_id;
        input [511:0] req_wdata;
        input [63:0] req_wstrb;
        input exp_req_ready;
        integer cycles;
        begin
            reset_dut();
            enter_mode(MODE_CACHE);
            @(negedge clk);
            invalidate_all_valid = 1'b1;
            write_req_addr[(WRITE_MASTER * ADDR_BITS) +: ADDR_BITS] = req_addr;
            write_req_total_size[(WRITE_MASTER * 8) +: 8] = req_size;
            write_req_id[(WRITE_MASTER * ID_BITS) +: ID_BITS] = req_id;
            write_req_wdata[(WRITE_MASTER * LINE_BITS) +: LINE_BITS] = req_wdata;
            write_req_wstrb[(WRITE_MASTER * LINE_BYTES) +: LINE_BYTES] = req_wstrb[LINE_BYTES-1:0];
            write_req_bypass[WRITE_MASTER] = 1'b0;
            write_req_valid[WRITE_MASTER] = 1'b1;

            for (cycles = 0; cycles < 5; cycles = cycles + 1) begin
                #1;
                if (write_req_ready[WRITE_MASTER] !== exp_req_ready) begin
                    fail_now("C++ trace invalidate-all write ready mismatch");
                end
                if (write_req_accepted[WRITE_MASTER]) begin
                    fail_now("C++ trace invalidate-all write was accepted");
                end
                if (ddr_axi_arvalid || mmio_axi_arvalid ||
                    ddr_axi_awvalid || mmio_axi_awvalid ||
                    ddr_axi_wvalid || mmio_axi_wvalid) begin
                    fail_now("C++ trace invalidate-all write escaped to AXI");
                end
                @(posedge clk);
                @(negedge clk);
            end
            write_req_valid[WRITE_MASTER] = 1'b0;
            invalidate_all_valid = 1'b0;
        end
    endtask

    task issue_invalidate_all_recovery_mmio_read_and_check;
        input [31:0] req_addr;
        input [7:0] req_size;
        input [3:0] req_id;
        input [31:0] exp_araddr;
        input [7:0] exp_arlen;
        input [2:0] exp_arsize;
        input [1:0] exp_arburst;
        input [5:0] exp_arid;
        input [255:0] rbeat0;
        input [3:0] exp_resp_id;
        input [2047:0] exp_resp_data;
        integer timeout;
        reg accepted_seen;
        reg [ID_BITS-1:0] accepted_id_seen;
        begin
            reset_dut();
            enter_mode(MODE_CACHE);
            @(negedge clk);
            invalidate_all_valid = 1'b1;
            timeout = 10000;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (invalidate_all_accepted) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace invalidate-all recovery accept timeout");
            end
            @(negedge clk);
            invalidate_all_valid = 1'b0;

            timeout = 10000;
            while (reconfig_busy && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace invalidate-all recovery did not settle");
            end

            @(negedge clk);
            mmio_axi_arready = 1'b0;
            accepted_seen = 1'b0;
            accepted_id_seen = {ID_BITS{1'b0}};
            read_req_addr[(READ_MASTER * ADDR_BITS) +: ADDR_BITS] = req_addr;
            read_req_total_size[(READ_MASTER * 8) +: 8] = req_size;
            read_req_id[(READ_MASTER * ID_BITS) +: ID_BITS] = req_id;
            read_req_bypass[READ_MASTER] = 1'b0;
            read_req_valid[READ_MASTER] = 1'b1;

            #1;
            if (read_req_accepted[READ_MASTER]) begin
                accepted_seen = 1'b1;
                accepted_id_seen =
                    read_req_accepted_id[(READ_MASTER * ID_BITS) +: ID_BITS];
            end
            timeout = 80;
            while (!mmio_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[READ_MASTER]) begin
                    accepted_seen = 1'b1;
                    accepted_id_seen =
                        read_req_accepted_id[(READ_MASTER * ID_BITS) +: ID_BITS];
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace invalidate-all recovery did not issue MMIO AR");
            end
            #1;
            expect_no_ddr_activity();
            if (mmio_axi_araddr != exp_araddr ||
                mmio_axi_arlen != exp_arlen ||
                mmio_axi_arsize != exp_arsize ||
                mmio_axi_arburst != exp_arburst ||
                mmio_axi_arid != exp_arid) begin
                fail_now("C++ trace invalidate-all recovery MMIO AR mismatch");
            end
            seen_mmio_arid = mmio_axi_arid;
            mmio_axi_arready = 1'b1;
            @(posedge clk);
            #1;
            if (read_req_accepted[READ_MASTER]) begin
                accepted_seen = 1'b1;
                accepted_id_seen =
                    read_req_accepted_id[(READ_MASTER * ID_BITS) +: ID_BITS];
            end
            if (!accepted_seen || accepted_id_seen != req_id) begin
                fail_now("C++ trace invalidate-all recovery accepted metadata mismatch");
            end
            @(negedge clk);
            read_req_valid[READ_MASTER] = 1'b0;
            read_req_bypass[READ_MASTER] = 1'b0;

            mmio_axi_rid = seen_mmio_arid;
            mmio_axi_rdata = rbeat0[MMIO_DATA_BITS-1:0];
            mmio_axi_rresp = AXI_RESP_OKAY;
            mmio_axi_rlast = 1'b1;
            mmio_axi_rvalid = 1'b1;
            #1;
            if (!mmio_axi_rready) begin
                fail_now("C++ trace invalidate-all recovery R was backpressured");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_rvalid = 1'b0;
            mmio_axi_rlast = 1'b0;

            timeout = 120;
            while (!read_resp_valid[READ_MASTER] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace invalidate-all recovery response timeout");
            end
            #1;
            if (read_resp_id[(READ_MASTER * ID_BITS) +: ID_BITS] != exp_resp_id ||
                read_resp_data[(READ_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    exp_resp_data) begin
                fail_now("C++ trace invalidate-all recovery response mismatch");
            end
        end
    endtask

    task issue_invalidate_all_pending_mmio_read_and_check;
        input [31:0] req_addr;
        input [7:0] req_size;
        input [3:0] req_id;
        input [31:0] exp_araddr;
        input [7:0] exp_arlen;
        input [2:0] exp_arsize;
        input [1:0] exp_arburst;
        input [5:0] exp_arid;
        input [255:0] rbeat0;
        input [3:0] exp_resp_id;
        input [2047:0] exp_resp_data;
        integer timeout;
        reg accepted_seen;
        reg [ID_BITS-1:0] accepted_id_seen;
        begin
            reset_dut();
            enter_mode(MODE_CACHE);
            @(negedge clk);
            read_resp_ready = {NUM_READ_MASTERS{1'b0}};
            mmio_axi_arready = 1'b0;
            accepted_seen = 1'b0;
            accepted_id_seen = {ID_BITS{1'b0}};
            read_req_addr[(READ_MASTER * ADDR_BITS) +: ADDR_BITS] = req_addr;
            read_req_total_size[(READ_MASTER * 8) +: 8] = req_size;
            read_req_id[(READ_MASTER * ID_BITS) +: ID_BITS] = req_id;
            read_req_bypass[READ_MASTER] = 1'b0;
            read_req_valid[READ_MASTER] = 1'b1;

            #1;
            if (read_req_accepted[READ_MASTER]) begin
                accepted_seen = 1'b1;
                accepted_id_seen =
                    read_req_accepted_id[(READ_MASTER * ID_BITS) +: ID_BITS];
            end
            timeout = 80;
            while (!mmio_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[READ_MASTER]) begin
                    accepted_seen = 1'b1;
                    accepted_id_seen =
                        read_req_accepted_id[(READ_MASTER * ID_BITS) +: ID_BITS];
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace pending invalidate-all did not issue MMIO AR");
            end
            #1;
            expect_no_ddr_activity();
            if (mmio_axi_araddr != exp_araddr ||
                mmio_axi_arlen != exp_arlen ||
                mmio_axi_arsize != exp_arsize ||
                mmio_axi_arburst != exp_arburst ||
                mmio_axi_arid != exp_arid) begin
                fail_now("C++ trace pending invalidate-all MMIO AR mismatch");
            end
            seen_mmio_arid = mmio_axi_arid;
            mmio_axi_arready = 1'b1;
            @(posedge clk);
            #1;
            if (read_req_accepted[READ_MASTER]) begin
                accepted_seen = 1'b1;
                accepted_id_seen =
                    read_req_accepted_id[(READ_MASTER * ID_BITS) +: ID_BITS];
            end
            if (!accepted_seen || accepted_id_seen != req_id) begin
                fail_now("C++ trace pending invalidate-all accepted metadata mismatch");
            end
            @(negedge clk);
            read_req_valid[READ_MASTER] = 1'b0;
            read_req_bypass[READ_MASTER] = 1'b0;

            invalidate_all_valid = 1'b1;
            repeat (4) begin
                @(posedge clk);
                #1;
                if (invalidate_all_accepted) begin
                    fail_now("invalidate_all accepted while MMIO read pending");
                end
            end

            @(negedge clk);
            mmio_axi_rid = seen_mmio_arid;
            mmio_axi_rdata = rbeat0[MMIO_DATA_BITS-1:0];
            mmio_axi_rresp = AXI_RESP_OKAY;
            mmio_axi_rlast = 1'b1;
            mmio_axi_rvalid = 1'b1;
            #1;
            if (!mmio_axi_rready) begin
                fail_now("C++ trace pending invalidate-all R was backpressured");
            end
            if (invalidate_all_accepted) begin
                fail_now("invalidate_all accepted in MMIO R handshake cycle");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_rvalid = 1'b0;
            mmio_axi_rlast = 1'b0;

            timeout = 120;
            while (!read_resp_valid[READ_MASTER] && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (invalidate_all_accepted) begin
                    fail_now("invalidate_all accepted before held response");
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace pending invalidate-all response timeout");
            end
            #1;
            if (read_resp_id[(READ_MASTER * ID_BITS) +: ID_BITS] != exp_resp_id ||
                read_resp_data[(READ_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    exp_resp_data) begin
                fail_now("C++ trace pending invalidate-all response mismatch");
            end
            repeat (4) begin
                @(posedge clk);
                #1;
                if (invalidate_all_accepted) begin
                    fail_now("invalidate_all accepted while response held");
                end
            end

            @(negedge clk);
            read_resp_ready[READ_MASTER] = 1'b1;
            #1;
            if (read_resp_id[(READ_MASTER * ID_BITS) +: ID_BITS] != exp_resp_id ||
                read_resp_data[(READ_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    exp_resp_data) begin
                fail_now("C++ trace pending invalidate-all retire response mismatch");
            end
            if (invalidate_all_accepted) begin
                fail_now("invalidate_all accepted before response retire edge");
            end
            @(posedge clk);
            @(negedge clk);
            read_resp_ready[READ_MASTER] = 1'b0;

            timeout = 10000;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (invalidate_all_accepted) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("invalidate_all did not accept after MMIO read retired");
            end
            @(negedge clk);
            invalidate_all_valid = 1'b0;
        end
    endtask

    task issue_invalidate_all_pending_mmio_write_and_check;
        input [31:0] req_addr;
        input [7:0] req_size;
        input [3:0] req_id;
        input [511:0] req_wdata;
        input [63:0] req_wstrb;
        input [31:0] exp_awaddr;
        input [7:0] exp_awlen;
        input [2:0] exp_awsize;
        input [1:0] exp_awburst;
        input [5:0] exp_awid;
        input integer beat_count;
        input [255:0] wbeat0;
        input [31:0] wstrb0;
        input wlast0;
        input [255:0] wbeat1;
        input [31:0] wstrb1;
        input wlast1;
        input [3:0] exp_resp_id;
        input [1:0] exp_resp_code;
        integer timeout;
        reg accepted_seen;
        begin
            reset_dut();
            enter_mode(MODE_CACHE);
            @(negedge clk);
            write_resp_ready = {NUM_WRITE_MASTERS{1'b0}};
            mmio_axi_awready = 1'b0;
            mmio_axi_wready = 1'b0;
            accepted_seen = 1'b0;
            write_req_addr[(WRITE_MASTER * ADDR_BITS) +: ADDR_BITS] = req_addr;
            write_req_total_size[(WRITE_MASTER * 8) +: 8] = req_size;
            write_req_id[(WRITE_MASTER * ID_BITS) +: ID_BITS] = req_id;
            write_req_wdata[(WRITE_MASTER * LINE_BITS) +: LINE_BITS] = req_wdata;
            write_req_wstrb[(WRITE_MASTER * LINE_BYTES) +: LINE_BYTES] =
                req_wstrb[LINE_BYTES-1:0];
            write_req_bypass[WRITE_MASTER] = 1'b0;
            write_req_valid[WRITE_MASTER] = 1'b1;

            #1;
            if (write_req_accepted[WRITE_MASTER]) begin
                accepted_seen = 1'b1;
            end
            timeout = 80;
            while (!mmio_axi_awvalid && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[WRITE_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace pending invalidate-all did not issue MMIO AW");
            end
            #1;
            expect_no_ddr_activity();
            if (mmio_axi_awaddr != exp_awaddr ||
                mmio_axi_awlen != exp_awlen ||
                mmio_axi_awsize != exp_awsize ||
                mmio_axi_awburst != exp_awburst ||
                mmio_axi_awid != exp_awid) begin
                fail_now("C++ trace pending invalidate-all MMIO AW mismatch");
            end
            seen_mmio_awid = mmio_axi_awid;
            mmio_axi_awready = 1'b1;
            @(posedge clk);
            #1;
            if (write_req_accepted[WRITE_MASTER]) begin
                accepted_seen = 1'b1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace pending invalidate-all write accepted pulse missing");
            end
            @(negedge clk);
            write_req_valid[WRITE_MASTER] = 1'b0;
            write_req_bypass[WRITE_MASTER] = 1'b0;
            mmio_axi_awready = 1'b0;

            timeout = 80;
            while (!mmio_axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace pending invalidate-all first W timeout");
            end
            #1;
            expect_no_ddr_activity();
            if (mmio_axi_wdata != wbeat0[MMIO_DATA_BITS-1:0] ||
                mmio_axi_wstrb != wstrb0[MMIO_STRB_BITS-1:0] ||
                mmio_axi_wlast != wlast0) begin
                fail_now("C++ trace pending invalidate-all first W mismatch");
            end
            mmio_axi_wready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_wready = 1'b0;

            if (beat_count == 2) begin
                timeout = 80;
                while (!mmio_axi_wvalid && (timeout > 0)) begin
                    @(posedge clk);
                    timeout = timeout - 1;
                end
                if (timeout == 0) begin
                    fail_now("C++ trace pending invalidate-all second W timeout");
                end
                #1;
                expect_no_ddr_activity();
                if (mmio_axi_wdata != wbeat1[MMIO_DATA_BITS-1:0] ||
                    mmio_axi_wstrb != wstrb1[MMIO_STRB_BITS-1:0] ||
                    mmio_axi_wlast != wlast1) begin
                    fail_now("C++ trace pending invalidate-all second W mismatch");
                end
                mmio_axi_wready = 1'b1;
                @(posedge clk);
                @(negedge clk);
                mmio_axi_wready = 1'b0;
            end

            invalidate_all_valid = 1'b1;
            repeat (4) begin
                @(posedge clk);
                #1;
                if (invalidate_all_accepted) begin
                    fail_now("invalidate_all accepted while MMIO write pending");
                end
            end

            @(negedge clk);
            mmio_axi_bid = seen_mmio_awid;
            mmio_axi_bresp = AXI_RESP_OKAY;
            mmio_axi_bvalid = 1'b1;
            #1;
            if (!mmio_axi_bready) begin
                fail_now("C++ trace pending invalidate-all B was backpressured");
            end
            if (invalidate_all_accepted) begin
                fail_now("invalidate_all accepted in MMIO B handshake cycle");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_bvalid = 1'b0;

            timeout = 120;
            while (!write_resp_valid[WRITE_MASTER] && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (invalidate_all_accepted) begin
                    fail_now("invalidate_all accepted before held write response");
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace pending invalidate-all write response timeout");
            end
            #1;
            if (write_resp_id[(WRITE_MASTER * ID_BITS) +: ID_BITS] != exp_resp_id ||
                write_resp_code[(WRITE_MASTER * 2) +: 2] != exp_resp_code) begin
                fail_now("C++ trace pending invalidate-all write response mismatch");
            end
            repeat (4) begin
                @(posedge clk);
                #1;
                if (invalidate_all_accepted) begin
                    fail_now("invalidate_all accepted while write response held");
                end
            end

            @(negedge clk);
            write_resp_ready[WRITE_MASTER] = 1'b1;
            #1;
            if (write_resp_id[(WRITE_MASTER * ID_BITS) +: ID_BITS] != exp_resp_id ||
                write_resp_code[(WRITE_MASTER * 2) +: 2] != exp_resp_code) begin
                fail_now("C++ trace pending invalidate-all retire write response mismatch");
            end
            if (invalidate_all_accepted) begin
                fail_now("invalidate_all accepted before write response retire edge");
            end
            @(posedge clk);
            @(negedge clk);
            write_resp_ready[WRITE_MASTER] = 1'b0;

            timeout = 10000;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (invalidate_all_accepted) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("invalidate_all did not accept after MMIO write retired");
            end
            @(negedge clk);
            invalidate_all_valid = 1'b0;
        end
    endtask

    task issue_invalidate_all_pending_mmio_rw_and_check;
        integer timeout;
        reg accepted_seen;
        reg [ID_BITS-1:0] accepted_id_seen;
        begin
            reset_dut();
            enter_mode(MODE_CACHE);
            @(negedge clk);
            read_resp_ready = {NUM_READ_MASTERS{1'b0}};
            write_resp_ready = {NUM_WRITE_MASTERS{1'b0}};
            mmio_axi_arready = 1'b0;
            mmio_axi_awready = 1'b0;
            mmio_axi_wready = 1'b0;

            accepted_seen = 1'b0;
            accepted_id_seen = {ID_BITS{1'b0}};
            read_req_addr[(READ_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_READ_REQ_ADDR;
            read_req_total_size[(READ_MASTER * 8) +: 8] =
                CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_READ_REQ_SIZE;
            read_req_id[(READ_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_READ_REQ_ID;
            read_req_bypass[READ_MASTER] = 1'b0;
            read_req_valid[READ_MASTER] = 1'b1;

            timeout = 80;
            while (!mmio_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[READ_MASTER]) begin
                    accepted_seen = 1'b1;
                    accepted_id_seen =
                        read_req_accepted_id[(READ_MASTER * ID_BITS) +: ID_BITS];
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace pending invalidate-all RW MMIO AR timeout");
            end
            #1;
            expect_no_ddr_activity();
            if (mmio_axi_araddr != CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_READ_ARADDR ||
                mmio_axi_arlen != CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_READ_ARLEN ||
                mmio_axi_arsize != CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_READ_ARSIZE ||
                mmio_axi_arburst != CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_READ_ARBURST ||
                mmio_axi_arid != CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_READ_ARID) begin
                fail_now("C++ trace pending invalidate-all RW MMIO AR mismatch");
            end
            seen_mmio_arid = mmio_axi_arid;
            mmio_axi_arready = 1'b1;
            @(posedge clk);
            #1;
            if (read_req_accepted[READ_MASTER]) begin
                accepted_seen = 1'b1;
                accepted_id_seen =
                    read_req_accepted_id[(READ_MASTER * ID_BITS) +: ID_BITS];
            end
            if (!accepted_seen ||
                accepted_id_seen != CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_READ_REQ_ID) begin
                fail_now("C++ trace pending invalidate-all RW read accept mismatch");
            end
            @(negedge clk);
            read_req_valid[READ_MASTER] = 1'b0;
            read_req_bypass[READ_MASTER] = 1'b0;
            mmio_axi_arready = 1'b0;

            accepted_seen = 1'b0;
            write_req_addr[(WRITE_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_WRITE_REQ_ADDR;
            write_req_total_size[(WRITE_MASTER * 8) +: 8] =
                CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_WRITE_REQ_SIZE;
            write_req_id[(WRITE_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_WRITE_REQ_ID;
            write_req_wdata[(WRITE_MASTER * LINE_BITS) +: LINE_BITS] =
                CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_WRITE_REQ_WDATA;
            write_req_wstrb[(WRITE_MASTER * LINE_BYTES) +: LINE_BYTES] =
                CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_WRITE_REQ_WSTRB[LINE_BYTES-1:0];
            write_req_bypass[WRITE_MASTER] = 1'b0;
            write_req_valid[WRITE_MASTER] = 1'b1;

            timeout = 80;
            while (!mmio_axi_awvalid && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[WRITE_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace pending invalidate-all RW MMIO AW timeout");
            end
            #1;
            expect_no_ddr_activity();
            if (mmio_axi_awaddr != CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_WRITE_AWADDR ||
                mmio_axi_awlen != CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_WRITE_AWLEN ||
                mmio_axi_awsize != CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_WRITE_AWSIZE ||
                mmio_axi_awburst != CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_WRITE_AWBURST ||
                mmio_axi_awid != CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_WRITE_AWID) begin
                fail_now("C++ trace pending invalidate-all RW MMIO AW mismatch");
            end
            seen_mmio_awid = mmio_axi_awid;
            mmio_axi_awready = 1'b1;
            @(posedge clk);
            #1;
            if (write_req_accepted[WRITE_MASTER]) begin
                accepted_seen = 1'b1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace pending invalidate-all RW write accept missing");
            end
            @(negedge clk);
            write_req_valid[WRITE_MASTER] = 1'b0;
            write_req_bypass[WRITE_MASTER] = 1'b0;
            mmio_axi_awready = 1'b0;

            timeout = 80;
            while (!mmio_axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace pending invalidate-all RW MMIO W timeout");
            end
            #1;
            expect_no_ddr_activity();
            if (mmio_axi_wdata !=
                    CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_WRITE_WBEAT0[MMIO_DATA_BITS-1:0] ||
                mmio_axi_wstrb !=
                    CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_WRITE_WSTRB0[MMIO_STRB_BITS-1:0] ||
                mmio_axi_wlast != CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_WRITE_WLAST0) begin
                fail_now("C++ trace pending invalidate-all RW MMIO W mismatch");
            end
            mmio_axi_wready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_wready = 1'b0;

            invalidate_all_valid = 1'b1;
            repeat (4) begin
                @(posedge clk);
                #1;
                if (invalidate_all_accepted !==
                    !CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_BLOCKED_BEFORE_RESP) begin
                    fail_now("C++ trace pending invalidate-all RW early accept mismatch");
                end
            end

            @(negedge clk);
            mmio_axi_rid = seen_mmio_arid;
            mmio_axi_rdata =
                CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_READ_RBEAT0[MMIO_DATA_BITS-1:0];
            mmio_axi_rresp = AXI_RESP_OKAY;
            mmio_axi_rlast = 1'b1;
            mmio_axi_rvalid = 1'b1;
            mmio_axi_bid = seen_mmio_awid;
            mmio_axi_bresp = AXI_RESP_OKAY;
            mmio_axi_bvalid = 1'b1;
            #1;
            if (mmio_axi_rready !== CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_RREADY_PENDING ||
                mmio_axi_bready !== CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_BREADY_PENDING ||
                invalidate_all_accepted) begin
                fail_now("C++ trace pending invalidate-all RW R/B handshake mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_rvalid = 1'b0;
            mmio_axi_rlast = 1'b0;
            mmio_axi_bvalid = 1'b0;

            timeout = 160;
            while ((!(read_resp_valid[READ_MASTER] && write_resp_valid[WRITE_MASTER])) &&
                   (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (invalidate_all_accepted) begin
                    fail_now("invalidate_all accepted before both RW responses held");
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace pending invalidate-all RW response timeout");
            end
            #1;
            if (read_resp_id[(READ_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_READ_RESP_ID ||
                read_resp_data[(READ_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_READ_RESP_DATA ||
                write_resp_id[(WRITE_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_WRITE_RESP_ID ||
                write_resp_code[(WRITE_MASTER * 2) +: 2] !=
                    CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_WRITE_RESP_CODE ||
                invalidate_all_accepted !==
                    !CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_BLOCKED_BOTH_HELD) begin
                fail_now("C++ trace pending invalidate-all RW held response mismatch");
            end

            @(negedge clk);
            read_resp_ready[READ_MASTER] = 1'b1;
            #1;
            if (read_resp_id[(READ_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_READ_RESP_ID ||
                read_resp_data[(READ_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_READ_RESP_DATA ||
                invalidate_all_accepted) begin
                fail_now("C++ trace pending invalidate-all RW read retire mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            read_resp_ready[READ_MASTER] = 1'b0;
            #1;
            if (!write_resp_valid[WRITE_MASTER] ||
                invalidate_all_accepted !==
                    !CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_BLOCKED_AFTER_READ_RETIRE) begin
                fail_now("C++ trace pending invalidate-all RW write held mismatch");
            end

            @(negedge clk);
            write_resp_ready[WRITE_MASTER] = 1'b1;
            #1;
            if (write_resp_id[(WRITE_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_WRITE_RESP_ID ||
                write_resp_code[(WRITE_MASTER * 2) +: 2] !=
                    CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_WRITE_RESP_CODE ||
                invalidate_all_accepted) begin
                fail_now("C++ trace pending invalidate-all RW write retire mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            write_resp_ready[WRITE_MASTER] = 1'b0;

            timeout = 10000;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (invalidate_all_accepted) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (accepted_seen !==
                CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_RW_ACCEPTED_AFTER_BOTH_RETIRE) begin
                fail_now("C++ trace pending invalidate-all RW final accept mismatch");
            end
            @(negedge clk);
            invalidate_all_valid = 1'b0;
        end
    endtask

    task issue_invalidate_all_pre_ar_mmio_read_and_check;
        input [31:0] req_addr;
        input [7:0] req_size;
        input [3:0] req_id;
        input [31:0] exp_araddr;
        input [7:0] exp_arlen;
        input [2:0] exp_arsize;
        input [1:0] exp_arburst;
        input [5:0] exp_arid;
        input [255:0] rbeat0;
        input [3:0] exp_resp_id;
        input [2047:0] exp_resp_data;
        integer timeout;
        reg accepted_seen;
        reg [ID_BITS-1:0] accepted_id_seen;
        begin
            reset_dut();
            enter_mode(MODE_CACHE);
            @(negedge clk);
            read_resp_ready = {NUM_READ_MASTERS{1'b0}};
            mmio_axi_arready = 1'b0;
            accepted_seen = 1'b0;
            accepted_id_seen = {ID_BITS{1'b0}};
            read_req_addr[(READ_MASTER * ADDR_BITS) +: ADDR_BITS] = req_addr;
            read_req_total_size[(READ_MASTER * 8) +: 8] = req_size;
            read_req_id[(READ_MASTER * ID_BITS) +: ID_BITS] = req_id;
            read_req_bypass[READ_MASTER] = 1'b0;
            read_req_valid[READ_MASTER] = 1'b1;

            timeout = 80;
            while (!mmio_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[READ_MASTER]) begin
                    accepted_seen = 1'b1;
                    accepted_id_seen =
                        read_req_accepted_id[(READ_MASTER * ID_BITS) +: ID_BITS];
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace pre-AR invalidate-all did not issue MMIO AR");
            end
            #1;
            expect_no_ddr_activity();
            if (mmio_axi_araddr != exp_araddr ||
                mmio_axi_arlen != exp_arlen ||
                mmio_axi_arsize != exp_arsize ||
                mmio_axi_arburst != exp_arburst ||
                mmio_axi_arid != exp_arid) begin
                fail_now("C++ trace pre-AR invalidate-all MMIO AR mismatch");
            end
            seen_mmio_arid = mmio_axi_arid;

            invalidate_all_valid = 1'b1;
            repeat (4) begin
                @(posedge clk);
                #1;
                if (!mmio_axi_arvalid ||
                    mmio_axi_araddr != exp_araddr ||
                    mmio_axi_arid != exp_arid) begin
                    fail_now("C++ trace pre-AR invalidate-all AR not held");
                end
                if (invalidate_all_accepted) begin
                    fail_now("invalidate_all accepted while MMIO AR pending");
                end
            end

            @(negedge clk);
            mmio_axi_arready = 1'b1;
            #1;
            if (!mmio_axi_arvalid) begin
                fail_now("C++ trace pre-AR invalidate-all AR missing at handshake");
            end
            if (invalidate_all_accepted) begin
                fail_now("invalidate_all accepted in MMIO AR handshake cycle");
            end
            @(posedge clk);
            #1;
            if (read_req_accepted[READ_MASTER]) begin
                accepted_seen = 1'b1;
                accepted_id_seen =
                    read_req_accepted_id[(READ_MASTER * ID_BITS) +: ID_BITS];
            end
            if (!accepted_seen || accepted_id_seen != req_id) begin
                fail_now("C++ trace pre-AR invalidate-all accepted metadata mismatch");
            end
            @(negedge clk);
            mmio_axi_arready = 1'b0;
            read_req_valid[READ_MASTER] = 1'b0;
            read_req_bypass[READ_MASTER] = 1'b0;

            repeat (4) begin
                @(posedge clk);
                #1;
                if (invalidate_all_accepted) begin
                    fail_now("invalidate_all accepted after AR before MMIO R");
                end
            end

            @(negedge clk);
            mmio_axi_rid = seen_mmio_arid;
            mmio_axi_rdata = rbeat0[MMIO_DATA_BITS-1:0];
            mmio_axi_rresp = AXI_RESP_OKAY;
            mmio_axi_rlast = 1'b1;
            mmio_axi_rvalid = 1'b1;
            #1;
            if (!mmio_axi_rready) begin
                fail_now("C++ trace pre-AR invalidate-all R was backpressured");
            end
            if (invalidate_all_accepted) begin
                fail_now("invalidate_all accepted in pre-AR MMIO R handshake cycle");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_rvalid = 1'b0;
            mmio_axi_rlast = 1'b0;

            timeout = 120;
            while (!read_resp_valid[READ_MASTER] && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (invalidate_all_accepted) begin
                    fail_now("invalidate_all accepted before pre-AR held response");
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace pre-AR invalidate-all response timeout");
            end
            #1;
            if (read_resp_id[(READ_MASTER * ID_BITS) +: ID_BITS] != exp_resp_id ||
                read_resp_data[(READ_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    exp_resp_data) begin
                fail_now("C++ trace pre-AR invalidate-all response mismatch");
            end

            @(negedge clk);
            read_resp_ready[READ_MASTER] = 1'b1;
            #1;
            if (read_resp_id[(READ_MASTER * ID_BITS) +: ID_BITS] != exp_resp_id ||
                read_resp_data[(READ_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    exp_resp_data) begin
                fail_now("C++ trace pre-AR invalidate-all retire response mismatch");
            end
            if (invalidate_all_accepted) begin
                fail_now("invalidate_all accepted before pre-AR response retire edge");
            end
            @(posedge clk);
            @(negedge clk);
            read_resp_ready[READ_MASTER] = 1'b0;

            timeout = 10000;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (invalidate_all_accepted) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("invalidate_all did not accept after pre-AR read retired");
            end
            @(negedge clk);
            invalidate_all_valid = 1'b0;
        end
    endtask

    task issue_invalidate_all_pre_aw_w_mmio_write_and_check;
        input [31:0] req_addr;
        input [7:0] req_size;
        input [3:0] req_id;
        input [511:0] req_wdata;
        input [63:0] req_wstrb;
        input [31:0] exp_awaddr;
        input [7:0] exp_awlen;
        input [2:0] exp_awsize;
        input [1:0] exp_awburst;
        input [5:0] exp_awid;
        input integer beat_count;
        input [255:0] wbeat0;
        input [31:0] wstrb0;
        input wlast0;
        input [255:0] wbeat1;
        input [31:0] wstrb1;
        input wlast1;
        input [3:0] exp_resp_id;
        input [1:0] exp_resp_code;
        integer timeout;
        reg accepted_seen;
        begin
            reset_dut();
            enter_mode(MODE_CACHE);
            @(negedge clk);
            write_resp_ready = {NUM_WRITE_MASTERS{1'b0}};
            mmio_axi_awready = 1'b0;
            mmio_axi_wready = 1'b0;
            accepted_seen = 1'b0;
            write_req_addr[(WRITE_MASTER * ADDR_BITS) +: ADDR_BITS] = req_addr;
            write_req_total_size[(WRITE_MASTER * 8) +: 8] = req_size;
            write_req_id[(WRITE_MASTER * ID_BITS) +: ID_BITS] = req_id;
            write_req_wdata[(WRITE_MASTER * LINE_BITS) +: LINE_BITS] = req_wdata;
            write_req_wstrb[(WRITE_MASTER * LINE_BYTES) +: LINE_BYTES] =
                req_wstrb[LINE_BYTES-1:0];
            write_req_bypass[WRITE_MASTER] = 1'b0;
            write_req_valid[WRITE_MASTER] = 1'b1;

            timeout = 80;
            while (!mmio_axi_awvalid && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[WRITE_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace pre-AW invalidate-all did not issue MMIO AW");
            end
            #1;
            expect_no_ddr_activity();
            if (mmio_axi_awaddr != exp_awaddr ||
                mmio_axi_awlen != exp_awlen ||
                mmio_axi_awsize != exp_awsize ||
                mmio_axi_awburst != exp_awburst ||
                mmio_axi_awid != exp_awid) begin
                fail_now("C++ trace pre-AW invalidate-all MMIO AW mismatch");
            end
            seen_mmio_awid = mmio_axi_awid;

            invalidate_all_valid = 1'b1;
            repeat (4) begin
                @(posedge clk);
                #1;
                if (!mmio_axi_awvalid ||
                    mmio_axi_awaddr != exp_awaddr ||
                    mmio_axi_awid != exp_awid) begin
                    fail_now("C++ trace pre-AW invalidate-all AW not held");
                end
                if (invalidate_all_accepted) begin
                    fail_now("invalidate_all accepted while MMIO AW pending");
                end
            end

            @(negedge clk);
            mmio_axi_awready = 1'b1;
            #1;
            if (!mmio_axi_awvalid) begin
                fail_now("C++ trace pre-AW invalidate-all AW missing at handshake");
            end
            if (invalidate_all_accepted) begin
                fail_now("invalidate_all accepted in MMIO AW handshake cycle");
            end
            @(posedge clk);
            #1;
            if (write_req_accepted[WRITE_MASTER]) begin
                accepted_seen = 1'b1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace pre-AW invalidate-all write accepted pulse missing");
            end
            @(negedge clk);
            mmio_axi_awready = 1'b0;
            write_req_valid[WRITE_MASTER] = 1'b0;
            write_req_bypass[WRITE_MASTER] = 1'b0;

            timeout = 80;
            while (!mmio_axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (invalidate_all_accepted) begin
                    fail_now("invalidate_all accepted before pre-W valid");
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace pre-W invalidate-all first W timeout");
            end
            #1;
            expect_no_ddr_activity();
            if (mmio_axi_wdata != wbeat0[MMIO_DATA_BITS-1:0] ||
                mmio_axi_wstrb != wstrb0[MMIO_STRB_BITS-1:0] ||
                mmio_axi_wlast != wlast0) begin
                fail_now("C++ trace pre-W invalidate-all first W mismatch");
            end
            repeat (4) begin
                @(posedge clk);
                #1;
                if (!mmio_axi_wvalid) begin
                    fail_now("C++ trace pre-W invalidate-all W not held");
                end
                if (invalidate_all_accepted) begin
                    fail_now("invalidate_all accepted while MMIO W pending");
                end
            end

            @(negedge clk);
            mmio_axi_wready = 1'b1;
            #1;
            if (!mmio_axi_wvalid) begin
                fail_now("C++ trace pre-W invalidate-all W missing at handshake");
            end
            if (invalidate_all_accepted) begin
                fail_now("invalidate_all accepted in MMIO W handshake cycle");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_wready = 1'b0;

            if (beat_count == 2) begin
                timeout = 80;
                while (!mmio_axi_wvalid && (timeout > 0)) begin
                    @(posedge clk);
                    timeout = timeout - 1;
                end
                if (timeout == 0) begin
                    fail_now("C++ trace pre-W invalidate-all second W timeout");
                end
                #1;
                expect_no_ddr_activity();
                if (mmio_axi_wdata != wbeat1[MMIO_DATA_BITS-1:0] ||
                    mmio_axi_wstrb != wstrb1[MMIO_STRB_BITS-1:0] ||
                    mmio_axi_wlast != wlast1) begin
                    fail_now("C++ trace pre-W invalidate-all second W mismatch");
                end
                mmio_axi_wready = 1'b1;
                #1;
                if (invalidate_all_accepted) begin
                    fail_now("invalidate_all accepted in second MMIO W handshake cycle");
                end
                @(posedge clk);
                @(negedge clk);
                mmio_axi_wready = 1'b0;
            end

            repeat (4) begin
                @(posedge clk);
                #1;
                if (invalidate_all_accepted) begin
                    fail_now("invalidate_all accepted after W before MMIO B");
                end
            end

            @(negedge clk);
            mmio_axi_bid = seen_mmio_awid;
            mmio_axi_bresp = AXI_RESP_OKAY;
            mmio_axi_bvalid = 1'b1;
            #1;
            if (!mmio_axi_bready) begin
                fail_now("C++ trace pre-AW invalidate-all B was backpressured");
            end
            if (invalidate_all_accepted) begin
                fail_now("invalidate_all accepted in pre-AW MMIO B handshake cycle");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_bvalid = 1'b0;

            timeout = 120;
            while (!write_resp_valid[WRITE_MASTER] && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (invalidate_all_accepted) begin
                    fail_now("invalidate_all accepted before pre-AW held write response");
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace pre-AW invalidate-all write response timeout");
            end
            #1;
            if (write_resp_id[(WRITE_MASTER * ID_BITS) +: ID_BITS] != exp_resp_id ||
                write_resp_code[(WRITE_MASTER * 2) +: 2] != exp_resp_code) begin
                fail_now("C++ trace pre-AW invalidate-all write response mismatch");
            end

            @(negedge clk);
            write_resp_ready[WRITE_MASTER] = 1'b1;
            #1;
            if (write_resp_id[(WRITE_MASTER * ID_BITS) +: ID_BITS] != exp_resp_id ||
                write_resp_code[(WRITE_MASTER * 2) +: 2] != exp_resp_code) begin
                fail_now("C++ trace pre-AW invalidate-all retire response mismatch");
            end
            if (invalidate_all_accepted) begin
                fail_now("invalidate_all accepted before pre-AW response retire edge");
            end
            @(posedge clk);
            @(negedge clk);
            write_resp_ready[WRITE_MASTER] = 1'b0;

            timeout = 10000;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (invalidate_all_accepted) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("invalidate_all did not accept after pre-AW write retired");
            end
            @(negedge clk);
            invalidate_all_valid = 1'b0;
        end
    endtask

    task issue_mode1_to_mode2_mmio_read_and_check;
        input [31:0] req_addr;
        input [7:0] req_size;
        input [3:0] req_id;
        input [31:0] exp_araddr;
        input [7:0] exp_arlen;
        input [2:0] exp_arsize;
        input [1:0] exp_arburst;
        input [5:0] exp_arid;
        input [255:0] rbeat0;
        input [3:0] exp_resp_id;
        input [2047:0] exp_resp_data;
        integer timeout;
        reg accepted_seen;
        reg [ID_BITS-1:0] accepted_id_seen;
        begin
            reset_dut();
            enter_mode(MODE_CACHE);
            enter_mode(MODE_MAPPED);

            @(negedge clk);
            mmio_axi_arready = 1'b0;
            accepted_seen = 1'b0;
            accepted_id_seen = {ID_BITS{1'b0}};
            read_req_addr[(READ_MASTER * ADDR_BITS) +: ADDR_BITS] = req_addr;
            read_req_total_size[(READ_MASTER * 8) +: 8] = req_size;
            read_req_id[(READ_MASTER * ID_BITS) +: ID_BITS] = req_id;
            read_req_bypass[READ_MASTER] = 1'b0;
            read_req_valid[READ_MASTER] = 1'b1;

            #1;
            if (read_req_accepted[READ_MASTER]) begin
                accepted_seen = 1'b1;
                accepted_id_seen =
                    read_req_accepted_id[(READ_MASTER * ID_BITS) +: ID_BITS];
            end
            timeout = 80;
            while (!mmio_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[READ_MASTER]) begin
                    accepted_seen = 1'b1;
                    accepted_id_seen =
                        read_req_accepted_id[(READ_MASTER * ID_BITS) +: ID_BITS];
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace mode1-to-mode2 MMIO read did not issue AR");
            end
            #1;
            expect_no_ddr_activity();
            if (mmio_axi_araddr != exp_araddr ||
                mmio_axi_arlen != exp_arlen ||
                mmio_axi_arsize != exp_arsize ||
                mmio_axi_arburst != exp_arburst ||
                mmio_axi_arid != exp_arid) begin
                fail_now("C++ trace mode1-to-mode2 MMIO read AR mismatch");
            end
            seen_mmio_arid = mmio_axi_arid;
            mmio_axi_arready = 1'b1;
            @(posedge clk);
            #1;
            if (read_req_accepted[READ_MASTER]) begin
                accepted_seen = 1'b1;
                accepted_id_seen =
                    read_req_accepted_id[(READ_MASTER * ID_BITS) +: ID_BITS];
            end
            if (!accepted_seen || accepted_id_seen != req_id) begin
                fail_now("C++ trace mode1-to-mode2 accepted metadata mismatch");
            end
            @(negedge clk);
            read_req_valid[READ_MASTER] = 1'b0;
            read_req_bypass[READ_MASTER] = 1'b0;

            mmio_axi_rid = seen_mmio_arid;
            mmio_axi_rdata = rbeat0[MMIO_DATA_BITS-1:0];
            mmio_axi_rresp = AXI_RESP_OKAY;
            mmio_axi_rlast = 1'b1;
            mmio_axi_rvalid = 1'b1;
            #1;
            if (!mmio_axi_rready) begin
                fail_now("C++ trace mode1-to-mode2 MMIO read R was backpressured");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_rvalid = 1'b0;
            mmio_axi_rlast = 1'b0;

            timeout = 120;
            while (!read_resp_valid[READ_MASTER] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace mode1-to-mode2 MMIO response timeout");
            end
            #1;
            if (read_resp_id[(READ_MASTER * ID_BITS) +: ID_BITS] != exp_resp_id ||
                read_resp_data[(READ_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    exp_resp_data) begin
                fail_now("C++ trace mode1-to-mode2 MMIO response mismatch");
            end
        end
    endtask

    task issue_overlapped_read_and_check;
        integer timeout;
        reg accepted_seen;
        begin
            reset_dut();
            @(negedge clk);
            read_resp_ready = {NUM_READ_MASTERS{1'b0}};
            ddr_axi_arready = 1'b0;
            mmio_axi_arready = 1'b0;

            read_req_addr[(CPP_MODE0_OVERLAP_READ_DDR_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE0_OVERLAP_READ_DDR_REQ_ADDR;
            read_req_total_size[(CPP_MODE0_OVERLAP_READ_DDR_MASTER * 8) +: 8] =
                CPP_MODE0_OVERLAP_READ_DDR_REQ_SIZE;
            read_req_id[(CPP_MODE0_OVERLAP_READ_DDR_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE0_OVERLAP_READ_DDR_REQ_ID;
            read_req_bypass[CPP_MODE0_OVERLAP_READ_DDR_MASTER] = 1'b0;
            read_req_valid[CPP_MODE0_OVERLAP_READ_DDR_MASTER] = 1'b1;
            timeout = 80;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[CPP_MODE0_OVERLAP_READ_DDR_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace overlapped DDR read accept timeout");
            end
            read_req_valid[CPP_MODE0_OVERLAP_READ_DDR_MASTER] = 1'b0;
            @(negedge clk);
            timeout = 80;
            while (!ddr_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace overlapped DDR read AR timeout");
            end
            #1;
            if (ddr_axi_araddr != CPP_MODE0_OVERLAP_READ_DDR_ARADDR ||
                ddr_axi_arlen != CPP_MODE0_OVERLAP_READ_DDR_ARLEN ||
                ddr_axi_arsize != CPP_MODE0_OVERLAP_READ_DDR_ARSIZE ||
                ddr_axi_arburst != CPP_MODE0_OVERLAP_READ_DDR_ARBURST ||
                ddr_axi_arid != CPP_MODE0_OVERLAP_READ_DDR_ARID ||
                mmio_axi_arvalid) begin
                fail_now("C++ trace overlapped DDR read AR mismatch");
            end
            seen_ddr_arid = ddr_axi_arid;
            ddr_axi_arready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_arready = 1'b0;

            read_req_addr[(CPP_MODE0_OVERLAP_READ_MMIO_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE0_OVERLAP_READ_MMIO_REQ_ADDR;
            read_req_total_size[(CPP_MODE0_OVERLAP_READ_MMIO_MASTER * 8) +: 8] =
                CPP_MODE0_OVERLAP_READ_MMIO_REQ_SIZE;
            read_req_id[(CPP_MODE0_OVERLAP_READ_MMIO_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE0_OVERLAP_READ_MMIO_REQ_ID;
            read_req_bypass[CPP_MODE0_OVERLAP_READ_MMIO_MASTER] = 1'b0;
            read_req_valid[CPP_MODE0_OVERLAP_READ_MMIO_MASTER] = 1'b1;
            timeout = 80;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[CPP_MODE0_OVERLAP_READ_MMIO_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace overlapped MMIO read accept timeout");
            end
            read_req_valid[CPP_MODE0_OVERLAP_READ_MMIO_MASTER] = 1'b0;
            @(negedge clk);
            timeout = 80;
            while (!mmio_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace overlapped MMIO read AR timeout");
            end
            #1;
            if (mmio_axi_araddr != CPP_MODE0_OVERLAP_READ_MMIO_ARADDR ||
                mmio_axi_arlen != CPP_MODE0_OVERLAP_READ_MMIO_ARLEN ||
                mmio_axi_arsize != CPP_MODE0_OVERLAP_READ_MMIO_ARSIZE ||
                mmio_axi_arburst != CPP_MODE0_OVERLAP_READ_MMIO_ARBURST ||
                mmio_axi_arid != CPP_MODE0_OVERLAP_READ_MMIO_ARID ||
                ddr_axi_arvalid) begin
                fail_now("C++ trace overlapped MMIO read AR mismatch");
            end
            seen_mmio_arid = mmio_axi_arid;
            mmio_axi_arready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_arready = 1'b0;

            mmio_axi_rid = seen_mmio_arid;
            mmio_axi_rdata = CPP_MODE0_OVERLAP_READ_MMIO_RBEAT0[MMIO_DATA_BITS-1:0];
            mmio_axi_rresp = AXI_RESP_OKAY;
            mmio_axi_rlast = 1'b1;
            mmio_axi_rvalid = 1'b1;
            #1;
            if (mmio_axi_rready !== CPP_MODE0_OVERLAP_READ_MMIO_RREADY_STALLED) begin
                fail_now("C++ trace overlapped MMIO RREADY stalled mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_rvalid = 1'b0;
            timeout = 80;
            while (!read_resp_valid[CPP_MODE0_OVERLAP_READ_MMIO_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0 ||
                read_resp_valid[CPP_MODE0_OVERLAP_READ_DDR_MASTER]) begin
                fail_now("C++ trace overlapped MMIO read response owner mismatch");
            end

            @(negedge clk);
            ddr_axi_rid = seen_ddr_arid;
            ddr_axi_rdata = CPP_MODE0_OVERLAP_READ_DDR_RBEAT0;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b1;
            ddr_axi_rvalid = 1'b1;
            #1;
            if (ddr_axi_rready !== CPP_MODE0_OVERLAP_READ_DDR_RREADY_STALLED) begin
                fail_now("C++ trace overlapped DDR RREADY stalled mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;

            #1;
            if (read_resp_id[(CPP_MODE0_OVERLAP_READ_MMIO_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE0_OVERLAP_READ_MMIO_RESP_ID ||
                read_resp_data[(CPP_MODE0_OVERLAP_READ_MMIO_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    CPP_MODE0_OVERLAP_READ_MMIO_RESP_DATA) begin
                fail_now("C++ trace overlapped MMIO read response payload mismatch");
            end
            read_resp_ready[CPP_MODE0_OVERLAP_READ_MMIO_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
            read_resp_ready[CPP_MODE0_OVERLAP_READ_MMIO_MASTER] = 1'b0;

            timeout = 120;
            while (!read_resp_valid[CPP_MODE0_OVERLAP_READ_DDR_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace overlapped DDR read response timeout");
            end
            #1;
            if (read_resp_id[(CPP_MODE0_OVERLAP_READ_DDR_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE0_OVERLAP_READ_DDR_RESP_ID ||
                read_resp_data[(CPP_MODE0_OVERLAP_READ_DDR_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    CPP_MODE0_OVERLAP_READ_DDR_RESP_DATA) begin
                fail_now("C++ trace overlapped DDR read response payload mismatch");
            end
            read_resp_ready[CPP_MODE0_OVERLAP_READ_DDR_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task issue_overlapped_read64_and_check;
        integer timeout;
        reg accepted_seen;
        begin
            reset_dut();
            @(negedge clk);
            read_resp_ready = {NUM_READ_MASTERS{1'b0}};
            ddr_axi_arready = 1'b0;
            mmio_axi_arready = 1'b0;

            read_req_addr[(CPP_MODE0_OVERLAP_READ64_DDR_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE0_OVERLAP_READ64_DDR_REQ_ADDR;
            read_req_total_size[(CPP_MODE0_OVERLAP_READ64_DDR_MASTER * 8) +: 8] =
                CPP_MODE0_OVERLAP_READ64_DDR_REQ_SIZE;
            read_req_id[(CPP_MODE0_OVERLAP_READ64_DDR_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE0_OVERLAP_READ64_DDR_REQ_ID;
            read_req_bypass[CPP_MODE0_OVERLAP_READ64_DDR_MASTER] = 1'b0;
            read_req_valid[CPP_MODE0_OVERLAP_READ64_DDR_MASTER] = 1'b1;
            timeout = 80;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[CPP_MODE0_OVERLAP_READ64_DDR_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace overlapped read64 DDR accept timeout");
            end
            read_req_valid[CPP_MODE0_OVERLAP_READ64_DDR_MASTER] = 1'b0;
            @(negedge clk);
            timeout = 80;
            while (!ddr_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace overlapped read64 DDR AR timeout");
            end
            #1;
            if (ddr_axi_araddr != CPP_MODE0_OVERLAP_READ64_DDR_ARADDR ||
                ddr_axi_arlen != CPP_MODE0_OVERLAP_READ64_DDR_ARLEN ||
                ddr_axi_arsize != CPP_MODE0_OVERLAP_READ64_DDR_ARSIZE ||
                ddr_axi_arburst != CPP_MODE0_OVERLAP_READ64_DDR_ARBURST ||
                ddr_axi_arid != CPP_MODE0_OVERLAP_READ64_DDR_ARID ||
                mmio_axi_arvalid) begin
                fail_now("C++ trace overlapped read64 DDR AR mismatch");
            end
            seen_ddr_arid = ddr_axi_arid;
            ddr_axi_arready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_arready = 1'b0;

            read_req_addr[(CPP_MODE0_OVERLAP_READ64_MMIO_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE0_OVERLAP_READ64_MMIO_REQ_ADDR;
            read_req_total_size[(CPP_MODE0_OVERLAP_READ64_MMIO_MASTER * 8) +: 8] =
                CPP_MODE0_OVERLAP_READ64_MMIO_REQ_SIZE;
            read_req_id[(CPP_MODE0_OVERLAP_READ64_MMIO_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE0_OVERLAP_READ64_MMIO_REQ_ID;
            read_req_bypass[CPP_MODE0_OVERLAP_READ64_MMIO_MASTER] = 1'b0;
            read_req_valid[CPP_MODE0_OVERLAP_READ64_MMIO_MASTER] = 1'b1;
            timeout = 80;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[CPP_MODE0_OVERLAP_READ64_MMIO_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace overlapped read64 MMIO accept timeout");
            end
            read_req_valid[CPP_MODE0_OVERLAP_READ64_MMIO_MASTER] = 1'b0;
            @(negedge clk);
            timeout = 80;
            while (!mmio_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace overlapped read64 MMIO AR timeout");
            end
            #1;
            if (mmio_axi_araddr != CPP_MODE0_OVERLAP_READ64_MMIO_ARADDR ||
                mmio_axi_arlen != CPP_MODE0_OVERLAP_READ64_MMIO_ARLEN ||
                mmio_axi_arsize != CPP_MODE0_OVERLAP_READ64_MMIO_ARSIZE ||
                mmio_axi_arburst != CPP_MODE0_OVERLAP_READ64_MMIO_ARBURST ||
                mmio_axi_arid != CPP_MODE0_OVERLAP_READ64_MMIO_ARID ||
                ddr_axi_arvalid) begin
                fail_now("C++ trace overlapped read64 MMIO AR mismatch");
            end
            seen_mmio_arid = mmio_axi_arid;
            mmio_axi_arready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_arready = 1'b0;

            mmio_axi_rid = seen_mmio_arid;
            mmio_axi_rdata = CPP_MODE0_OVERLAP_READ64_MMIO_RBEAT0[MMIO_DATA_BITS-1:0];
            mmio_axi_rresp = AXI_RESP_OKAY;
            mmio_axi_rlast = 1'b1;
            mmio_axi_rvalid = 1'b1;
            #1;
            if (mmio_axi_rready !== CPP_MODE0_OVERLAP_READ64_MMIO_RREADY_STALLED) begin
                fail_now("C++ trace overlapped read64 MMIO RREADY stalled mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_rvalid = 1'b0;
            timeout = 80;
            while (!read_resp_valid[CPP_MODE0_OVERLAP_READ64_MMIO_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0 ||
                read_resp_valid[CPP_MODE0_OVERLAP_READ64_DDR_MASTER]) begin
                fail_now("C++ trace overlapped read64 MMIO response owner mismatch");
            end

            @(negedge clk);
            ddr_axi_rid = seen_ddr_arid;
            ddr_axi_rdata = CPP_MODE0_OVERLAP_READ64_DDR_RBEAT0;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b0;
            ddr_axi_rvalid = 1'b1;
            #1;
            if (ddr_axi_rready !== CPP_MODE0_OVERLAP_READ64_DDR_RREADY_STALLED) begin
                fail_now("C++ trace overlapped read64 DDR RREADY beat0 mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;
            #1;
            if (read_resp_valid[CPP_MODE0_OVERLAP_READ64_DDR_MASTER]) begin
                fail_now("C++ trace overlapped read64 DDR response before last beat");
            end

            ddr_axi_rid = seen_ddr_arid;
            ddr_axi_rdata = CPP_MODE0_OVERLAP_READ64_DDR_RBEAT1;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b1;
            ddr_axi_rvalid = 1'b1;
            #1;
            if (ddr_axi_rready !== CPP_MODE0_OVERLAP_READ64_DDR_RREADY_STALLED) begin
                fail_now("C++ trace overlapped read64 DDR RREADY beat1 mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;
            ddr_axi_rlast = 1'b0;

            #1;
            if (read_resp_id[(CPP_MODE0_OVERLAP_READ64_MMIO_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE0_OVERLAP_READ64_MMIO_RESP_ID ||
                read_resp_data[(CPP_MODE0_OVERLAP_READ64_MMIO_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    CPP_MODE0_OVERLAP_READ64_MMIO_RESP_DATA) begin
                fail_now("C++ trace overlapped read64 MMIO response payload mismatch");
            end
            read_resp_ready[CPP_MODE0_OVERLAP_READ64_MMIO_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
            read_resp_ready[CPP_MODE0_OVERLAP_READ64_MMIO_MASTER] = 1'b0;

            timeout = 120;
            while (!read_resp_valid[CPP_MODE0_OVERLAP_READ64_DDR_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace overlapped read64 DDR response timeout");
            end
            #1;
            if (read_resp_id[(CPP_MODE0_OVERLAP_READ64_DDR_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE0_OVERLAP_READ64_DDR_RESP_ID ||
                read_resp_data[(CPP_MODE0_OVERLAP_READ64_DDR_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    CPP_MODE0_OVERLAP_READ64_DDR_RESP_DATA) begin
                fail_now("C++ trace overlapped read64 DDR response payload mismatch");
            end
            read_resp_ready[CPP_MODE0_OVERLAP_READ64_DDR_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task issue_mode1_cache_mmio_overlap_read_and_check;
        integer timeout;
        reg accepted_seen;
        begin
            reset_dut();
            enter_mode(MODE_CACHE);
            @(negedge clk);
            read_resp_ready = {NUM_READ_MASTERS{1'b0}};
            ddr_axi_arready = 1'b0;
            mmio_axi_arready = 1'b0;

            read_req_addr[(CPP_MODE1_CACHE_OVERLAP_READ_DDR_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_CACHE_OVERLAP_READ_DDR_REQ_ADDR;
            read_req_total_size[(CPP_MODE1_CACHE_OVERLAP_READ_DDR_MASTER * 8) +: 8] =
                CPP_MODE1_CACHE_OVERLAP_READ_DDR_REQ_SIZE;
            read_req_id[(CPP_MODE1_CACHE_OVERLAP_READ_DDR_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_CACHE_OVERLAP_READ_DDR_REQ_ID;
            read_req_bypass[CPP_MODE1_CACHE_OVERLAP_READ_DDR_MASTER] = 1'b0;
            read_req_valid[CPP_MODE1_CACHE_OVERLAP_READ_DDR_MASTER] = 1'b1;
            timeout = 160;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[CPP_MODE1_CACHE_OVERLAP_READ_DDR_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace mode1 cache overlap read accept timeout");
            end
            read_req_valid[CPP_MODE1_CACHE_OVERLAP_READ_DDR_MASTER] = 1'b0;
            @(negedge clk);
            timeout = 240;
            while (!ddr_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace mode1 cache overlap DDR refill AR timeout");
            end
            #1;
            if (ddr_axi_araddr != CPP_MODE1_CACHE_OVERLAP_READ_DDR_ARADDR ||
                ddr_axi_arlen != CPP_MODE1_CACHE_OVERLAP_READ_DDR_ARLEN ||
                ddr_axi_arsize != CPP_MODE1_CACHE_OVERLAP_READ_DDR_ARSIZE ||
                ddr_axi_arburst != CPP_MODE1_CACHE_OVERLAP_READ_DDR_ARBURST ||
                ddr_axi_arid != CPP_MODE1_CACHE_OVERLAP_READ_DDR_ARID ||
                mmio_axi_arvalid) begin
                fail_now("C++ trace mode1 cache overlap DDR refill AR mismatch");
            end
            seen_ddr_arid = ddr_axi_arid;
            ddr_axi_arready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_arready = 1'b0;
            ddr_axi_rvalid = 1'b0;
            ddr_axi_rlast = 1'b0;
            ddr_axi_rdata = {DDR_DATA_BITS{1'b0}};

            read_req_addr[(CPP_MODE1_CACHE_OVERLAP_READ_MMIO_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_CACHE_OVERLAP_READ_MMIO_REQ_ADDR;
            read_req_total_size[(CPP_MODE1_CACHE_OVERLAP_READ_MMIO_MASTER * 8) +: 8] =
                CPP_MODE1_CACHE_OVERLAP_READ_MMIO_REQ_SIZE;
            read_req_id[(CPP_MODE1_CACHE_OVERLAP_READ_MMIO_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_CACHE_OVERLAP_READ_MMIO_REQ_ID;
            read_req_bypass[CPP_MODE1_CACHE_OVERLAP_READ_MMIO_MASTER] = 1'b0;
            read_req_valid[CPP_MODE1_CACHE_OVERLAP_READ_MMIO_MASTER] = 1'b1;
            timeout = 160;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[CPP_MODE1_CACHE_OVERLAP_READ_MMIO_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace mode1 cache overlap MMIO read accept timeout");
            end
            read_req_valid[CPP_MODE1_CACHE_OVERLAP_READ_MMIO_MASTER] = 1'b0;
            @(negedge clk);
            timeout = 120;
            while (!mmio_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace mode1 cache overlap MMIO AR timeout");
            end
            #1;
            if (mmio_axi_araddr != CPP_MODE1_CACHE_OVERLAP_READ_MMIO_ARADDR ||
                mmio_axi_arlen != CPP_MODE1_CACHE_OVERLAP_READ_MMIO_ARLEN ||
                mmio_axi_arsize != CPP_MODE1_CACHE_OVERLAP_READ_MMIO_ARSIZE ||
                mmio_axi_arburst != CPP_MODE1_CACHE_OVERLAP_READ_MMIO_ARBURST ||
                mmio_axi_arid != CPP_MODE1_CACHE_OVERLAP_READ_MMIO_ARID ||
                ddr_axi_arvalid) begin
                fail_now("C++ trace mode1 cache overlap MMIO AR mismatch");
            end
            seen_mmio_arid = mmio_axi_arid;
            mmio_axi_arready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_arready = 1'b0;

            mmio_axi_rid = seen_mmio_arid;
            mmio_axi_rdata = CPP_MODE1_CACHE_OVERLAP_READ_MMIO_RBEAT0[MMIO_DATA_BITS-1:0];
            mmio_axi_rresp = AXI_RESP_OKAY;
            mmio_axi_rlast = 1'b1;
            mmio_axi_rvalid = 1'b1;
            #1;
            if (mmio_axi_rready !== CPP_MODE1_CACHE_OVERLAP_READ_MMIO_RREADY_STALLED) begin
                fail_now("C++ trace mode1 cache overlap MMIO RREADY stalled mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_rvalid = 1'b0;

            timeout = 120;
            while (!read_resp_valid[CPP_MODE1_CACHE_OVERLAP_READ_MMIO_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0 ||
                read_resp_valid[CPP_MODE1_CACHE_OVERLAP_READ_DDR_MASTER]) begin
                fail_now("C++ trace mode1 cache overlap MMIO response owner mismatch");
            end

            @(negedge clk);
            ddr_axi_rid = seen_ddr_arid;
            ddr_axi_rdata = CPP_MODE1_CACHE_OVERLAP_READ_DDR_RBEAT0;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b0;
            ddr_axi_rvalid = 1'b1;
            #1;
            if (ddr_axi_rready !== CPP_MODE1_CACHE_OVERLAP_READ_DDR_RREADY_STALLED) begin
                fail_now("C++ trace mode1 cache overlap DDR RREADY beat0 mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;

            ddr_axi_rid = seen_ddr_arid;
            ddr_axi_rdata = CPP_MODE1_CACHE_OVERLAP_READ_DDR_RBEAT1;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b1;
            ddr_axi_rvalid = 1'b1;
            #1;
            if (ddr_axi_rready !== CPP_MODE1_CACHE_OVERLAP_READ_DDR_RREADY_STALLED) begin
                fail_now("C++ trace mode1 cache overlap DDR RREADY beat1 mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;
            ddr_axi_rlast = 1'b0;

            #1;
            if (read_resp_id[(CPP_MODE1_CACHE_OVERLAP_READ_MMIO_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE1_CACHE_OVERLAP_READ_MMIO_RESP_ID ||
                read_resp_data[(CPP_MODE1_CACHE_OVERLAP_READ_MMIO_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    CPP_MODE1_CACHE_OVERLAP_READ_MMIO_RESP_DATA) begin
                fail_now("C++ trace mode1 cache overlap MMIO response payload mismatch");
            end
            read_resp_ready[CPP_MODE1_CACHE_OVERLAP_READ_MMIO_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
            read_resp_ready[CPP_MODE1_CACHE_OVERLAP_READ_MMIO_MASTER] = 1'b0;

            timeout = 240;
            while (!read_resp_valid[CPP_MODE1_CACHE_OVERLAP_READ_DDR_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace mode1 cache overlap DDR response timeout");
            end
            #1;
            if (read_resp_id[(CPP_MODE1_CACHE_OVERLAP_READ_DDR_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE1_CACHE_OVERLAP_READ_DDR_RESP_ID ||
                read_resp_data[(CPP_MODE1_CACHE_OVERLAP_READ_DDR_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    CPP_MODE1_CACHE_OVERLAP_READ_DDR_RESP_DATA) begin
                fail_now("C++ trace mode1 cache overlap DDR response payload mismatch");
            end
            read_resp_ready[CPP_MODE1_CACHE_OVERLAP_READ_DDR_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task issue_mode1_cache_write_miss_mmio_write_and_check;
        integer timeout;
        reg accepted_seen;
        begin
            reset_dut();
            enter_mode(MODE_CACHE);
            @(negedge clk);
            write_resp_ready = {NUM_WRITE_MASTERS{1'b0}};
            ddr_axi_arready = 1'b0;
            ddr_axi_awready = 1'b0;
            ddr_axi_wready = 1'b0;
            mmio_axi_awready = 1'b0;
            mmio_axi_wready = 1'b0;

            write_req_addr[(CPP_MODE1_CACHE_WRITE_MISS_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_CACHE_WRITE_MISS_REQ_ADDR;
            write_req_total_size[(CPP_MODE1_CACHE_WRITE_MISS_MASTER * 8) +: 8] =
                CPP_MODE1_CACHE_WRITE_MISS_REQ_SIZE;
            write_req_id[(CPP_MODE1_CACHE_WRITE_MISS_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_CACHE_WRITE_MISS_REQ_ID;
            write_req_wdata[(CPP_MODE1_CACHE_WRITE_MISS_MASTER * LINE_BITS) +: LINE_BITS] =
                CPP_MODE1_CACHE_WRITE_MISS_REQ_WDATA;
            write_req_wstrb[(CPP_MODE1_CACHE_WRITE_MISS_MASTER * LINE_BYTES) +: LINE_BYTES] =
                CPP_MODE1_CACHE_WRITE_MISS_REQ_WSTRB[LINE_BYTES-1:0];
            write_req_bypass[CPP_MODE1_CACHE_WRITE_MISS_MASTER] = 1'b0;
            write_req_valid[CPP_MODE1_CACHE_WRITE_MISS_MASTER] = 1'b1;
            timeout = 180;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[CPP_MODE1_CACHE_WRITE_MISS_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace mode1 cache write miss accept timeout");
            end
            write_req_valid[CPP_MODE1_CACHE_WRITE_MISS_MASTER] = 1'b0;
            @(negedge clk);

            timeout = 260;
            while (!ddr_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace mode1 cache write miss refill AR timeout");
            end
            #1;
            if (ddr_axi_araddr != CPP_MODE1_CACHE_WRITE_MISS_REFILL_ARADDR ||
                ddr_axi_arlen != CPP_MODE1_CACHE_WRITE_MISS_REFILL_ARLEN ||
                ddr_axi_arsize != CPP_MODE1_CACHE_WRITE_MISS_REFILL_ARSIZE ||
                ddr_axi_arburst != CPP_MODE1_CACHE_WRITE_MISS_REFILL_ARBURST ||
                ddr_axi_arid != CPP_MODE1_CACHE_WRITE_MISS_REFILL_ARID ||
                mmio_axi_arvalid || ddr_axi_awvalid || ddr_axi_wvalid) begin
                fail_now("C++ trace mode1 cache write miss refill AR mismatch");
            end
            seen_ddr_arid = ddr_axi_arid;
            ddr_axi_arready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_arready = 1'b0;

            write_req_addr[(CPP_MODE1_CACHE_WRITE_MISS_MMIO_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_CACHE_WRITE_MISS_MMIO_REQ_ADDR;
            write_req_total_size[(CPP_MODE1_CACHE_WRITE_MISS_MMIO_MASTER * 8) +: 8] =
                CPP_MODE1_CACHE_WRITE_MISS_MMIO_REQ_SIZE;
            write_req_id[(CPP_MODE1_CACHE_WRITE_MISS_MMIO_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_CACHE_WRITE_MISS_MMIO_REQ_ID;
            write_req_wdata[(CPP_MODE1_CACHE_WRITE_MISS_MMIO_MASTER * LINE_BITS) +: LINE_BITS] =
                CPP_MODE1_CACHE_WRITE_MISS_MMIO_REQ_WDATA;
            write_req_wstrb[(CPP_MODE1_CACHE_WRITE_MISS_MMIO_MASTER * LINE_BYTES) +: LINE_BYTES] =
                CPP_MODE1_CACHE_WRITE_MISS_MMIO_REQ_WSTRB[LINE_BYTES-1:0];
            write_req_bypass[CPP_MODE1_CACHE_WRITE_MISS_MMIO_MASTER] = 1'b0;
            write_req_valid[CPP_MODE1_CACHE_WRITE_MISS_MMIO_MASTER] = 1'b1;
            timeout = 180;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[CPP_MODE1_CACHE_WRITE_MISS_MMIO_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace mode1 cache write miss MMIO write accept timeout");
            end
            write_req_valid[CPP_MODE1_CACHE_WRITE_MISS_MMIO_MASTER] = 1'b0;
            @(negedge clk);

            timeout = 140;
            while (!mmio_axi_awvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace mode1 cache write miss MMIO AW timeout");
            end
            #1;
            if (mmio_axi_awaddr != CPP_MODE1_CACHE_WRITE_MISS_MMIO_AWADDR ||
                mmio_axi_awlen != CPP_MODE1_CACHE_WRITE_MISS_MMIO_AWLEN ||
                mmio_axi_awsize != CPP_MODE1_CACHE_WRITE_MISS_MMIO_AWSIZE ||
                mmio_axi_awburst != CPP_MODE1_CACHE_WRITE_MISS_MMIO_AWBURST ||
                mmio_axi_awid != CPP_MODE1_CACHE_WRITE_MISS_MMIO_AWID ||
                ddr_axi_awvalid) begin
                fail_now("C++ trace mode1 cache write miss MMIO AW mismatch");
            end
            seen_mmio_awid = mmio_axi_awid;
            mmio_axi_awready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_awready = 1'b0;

            timeout = 140;
            while (!mmio_axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace mode1 cache write miss MMIO W timeout");
            end
            #1;
            if (mmio_axi_wdata !=
                    CPP_MODE1_CACHE_WRITE_MISS_MMIO_WBEAT0[MMIO_DATA_BITS-1:0] ||
                mmio_axi_wstrb !=
                    CPP_MODE1_CACHE_WRITE_MISS_MMIO_WSTRB0[MMIO_STRB_BITS-1:0] ||
                mmio_axi_wlast != CPP_MODE1_CACHE_WRITE_MISS_MMIO_WLAST0 ||
                ddr_axi_wvalid) begin
                fail_now("C++ trace mode1 cache write miss MMIO W mismatch");
            end
            mmio_axi_wready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_wready = 1'b0;

            mmio_axi_bid = seen_mmio_awid;
            mmio_axi_bresp = AXI_RESP_OKAY;
            mmio_axi_bvalid = 1'b1;
            #1;
            if (mmio_axi_bready !==
                    CPP_MODE1_CACHE_WRITE_MISS_MMIO_BREADY_STALLED) begin
                fail_now("C++ trace mode1 cache write miss MMIO BREADY mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_bvalid = 1'b0;

            timeout = 140;
            while (!write_resp_valid[CPP_MODE1_CACHE_WRITE_MISS_MMIO_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0 ||
                write_resp_valid[CPP_MODE1_CACHE_WRITE_MISS_MASTER]) begin
                fail_now("C++ trace mode1 cache write miss MMIO response owner mismatch");
            end

            @(negedge clk);
            ddr_axi_rid = seen_ddr_arid;
            ddr_axi_rdata = CPP_MODE1_CACHE_WRITE_MISS_REFILL_RBEAT0;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b0;
            ddr_axi_rvalid = 1'b1;
            #1;
            if (ddr_axi_rready !==
                    CPP_MODE1_CACHE_WRITE_MISS_REFILL_RREADY_STALLED) begin
                fail_now("C++ trace mode1 cache write miss refill RREADY beat0 mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;

            ddr_axi_rid = seen_ddr_arid;
            ddr_axi_rdata = CPP_MODE1_CACHE_WRITE_MISS_REFILL_RBEAT1;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b1;
            ddr_axi_rvalid = 1'b1;
            #1;
            if (ddr_axi_rready !==
                    CPP_MODE1_CACHE_WRITE_MISS_REFILL_RREADY_STALLED) begin
                fail_now("C++ trace mode1 cache write miss refill RREADY beat1 mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;
            ddr_axi_rlast = 1'b0;

            #1;
            if (write_resp_id[(CPP_MODE1_CACHE_WRITE_MISS_MMIO_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE1_CACHE_WRITE_MISS_MMIO_RESP_ID ||
                write_resp_code[(CPP_MODE1_CACHE_WRITE_MISS_MMIO_MASTER * 2) +: 2] !=
                    CPP_MODE1_CACHE_WRITE_MISS_MMIO_RESP_CODE) begin
                fail_now("C++ trace mode1 cache write miss MMIO response payload mismatch");
            end
            write_resp_ready[CPP_MODE1_CACHE_WRITE_MISS_MMIO_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
            write_resp_ready[CPP_MODE1_CACHE_WRITE_MISS_MMIO_MASTER] = 1'b0;

            timeout = 260;
            while (!write_resp_valid[CPP_MODE1_CACHE_WRITE_MISS_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace mode1 cache write miss response timeout");
            end
            #1;
            if (write_resp_id[(CPP_MODE1_CACHE_WRITE_MISS_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE1_CACHE_WRITE_MISS_RESP_ID ||
                write_resp_code[(CPP_MODE1_CACHE_WRITE_MISS_MASTER * 2) +: 2] !=
                    CPP_MODE1_CACHE_WRITE_MISS_RESP_CODE) begin
                fail_now("C++ trace mode1 cache write miss response payload mismatch");
            end
            write_resp_ready[CPP_MODE1_CACHE_WRITE_MISS_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task issue_mode1_invalidate_all_cache_mmio_write_and_check;
        integer timeout;
        reg accepted_seen;
        begin
            reset_dut();
            enter_mode(MODE_CACHE);
            @(negedge clk);
            write_resp_ready = {NUM_WRITE_MASTERS{1'b0}};
            ddr_axi_arready = 1'b0;
            ddr_axi_awready = 1'b0;
            ddr_axi_wready = 1'b0;
            mmio_axi_awready = 1'b0;
            mmio_axi_wready = 1'b0;
            invalidate_all_valid = 1'b0;

            write_req_addr[(CPP_MODE1_INVALL_CACHE_MMIO_WRITE_CACHE_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_INVALL_CACHE_MMIO_WRITE_CACHE_REQ_ADDR;
            write_req_total_size[(CPP_MODE1_INVALL_CACHE_MMIO_WRITE_CACHE_MASTER * 8) +: 8] =
                CPP_MODE1_INVALL_CACHE_MMIO_WRITE_CACHE_REQ_SIZE;
            write_req_id[(CPP_MODE1_INVALL_CACHE_MMIO_WRITE_CACHE_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_INVALL_CACHE_MMIO_WRITE_CACHE_REQ_ID;
            write_req_wdata[(CPP_MODE1_INVALL_CACHE_MMIO_WRITE_CACHE_MASTER * LINE_BITS) +: LINE_BITS] =
                CPP_MODE1_INVALL_CACHE_MMIO_WRITE_CACHE_REQ_WDATA;
            write_req_wstrb[(CPP_MODE1_INVALL_CACHE_MMIO_WRITE_CACHE_MASTER * LINE_BYTES) +: LINE_BYTES] =
                CPP_MODE1_INVALL_CACHE_MMIO_WRITE_CACHE_REQ_WSTRB[LINE_BYTES-1:0];
            write_req_bypass[CPP_MODE1_INVALL_CACHE_MMIO_WRITE_CACHE_MASTER] = 1'b0;
            write_req_valid[CPP_MODE1_INVALL_CACHE_MMIO_WRITE_CACHE_MASTER] = 1'b1;
            timeout = 180;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[CPP_MODE1_INVALL_CACHE_MMIO_WRITE_CACHE_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace invall cache/MMIO write cache accept timeout");
            end
            write_req_valid[CPP_MODE1_INVALL_CACHE_MMIO_WRITE_CACHE_MASTER] = 1'b0;
            @(negedge clk);

            timeout = 260;
            while (!ddr_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace invall cache/MMIO write refill AR timeout");
            end
            #1;
            if (ddr_axi_araddr != CPP_MODE1_INVALL_CACHE_MMIO_WRITE_REFILL_ARADDR ||
                ddr_axi_arlen != CPP_MODE1_INVALL_CACHE_MMIO_WRITE_REFILL_ARLEN ||
                ddr_axi_arsize != CPP_MODE1_INVALL_CACHE_MMIO_WRITE_REFILL_ARSIZE ||
                ddr_axi_arburst != CPP_MODE1_INVALL_CACHE_MMIO_WRITE_REFILL_ARBURST ||
                ddr_axi_arid != CPP_MODE1_INVALL_CACHE_MMIO_WRITE_REFILL_ARID ||
                mmio_axi_arvalid || ddr_axi_awvalid || ddr_axi_wvalid) begin
                fail_now("C++ trace invall cache/MMIO write refill AR mismatch");
            end
            seen_ddr_arid = ddr_axi_arid;
            ddr_axi_arready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_arready = 1'b0;

            write_req_addr[(CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_REQ_ADDR;
            write_req_total_size[(CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_MASTER * 8) +: 8] =
                CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_REQ_SIZE;
            write_req_id[(CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_REQ_ID;
            write_req_wdata[(CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_MASTER * LINE_BITS) +: LINE_BITS] =
                CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_REQ_WDATA;
            write_req_wstrb[(CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_MASTER * LINE_BYTES) +: LINE_BYTES] =
                CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_REQ_WSTRB[LINE_BYTES-1:0];
            write_req_bypass[CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_MASTER] = 1'b0;
            write_req_valid[CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_MASTER] = 1'b1;
            timeout = 180;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace invall cache/MMIO write MMIO accept timeout");
            end
            write_req_valid[CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_MASTER] = 1'b0;
            @(negedge clk);

            timeout = 140;
            while (!mmio_axi_awvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace invall cache/MMIO write MMIO AW timeout");
            end
            #1;
            if (mmio_axi_awaddr != CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_AWADDR ||
                mmio_axi_awlen != CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_AWLEN ||
                mmio_axi_awsize != CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_AWSIZE ||
                mmio_axi_awburst != CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_AWBURST ||
                mmio_axi_awid != CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_AWID ||
                ddr_axi_awvalid) begin
                fail_now("C++ trace invall cache/MMIO write MMIO AW mismatch");
            end
            seen_mmio_awid = mmio_axi_awid;
            mmio_axi_awready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_awready = 1'b0;

            timeout = 140;
            while (!mmio_axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace invall cache/MMIO write MMIO W timeout");
            end
            #1;
            if (mmio_axi_wdata !=
                    CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_WBEAT0[MMIO_DATA_BITS-1:0] ||
                mmio_axi_wstrb !=
                    CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_WSTRB0[MMIO_STRB_BITS-1:0] ||
                mmio_axi_wlast != CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_WLAST0 ||
                ddr_axi_wvalid) begin
                fail_now("C++ trace invall cache/MMIO write MMIO W mismatch");
            end
            mmio_axi_wready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_wready = 1'b0;

            invalidate_all_valid = 1'b1;
            mmio_axi_bid = seen_mmio_awid;
            mmio_axi_bresp = AXI_RESP_OKAY;
            mmio_axi_bvalid = 1'b1;
            #1;
            if (mmio_axi_bready !== CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_BREADY_STALLED ||
                mmio_axi_bready !== CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_BREADY_PENDING ||
                invalidate_all_accepted) begin
                fail_now("C++ trace invall cache/MMIO write MMIO B mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_bvalid = 1'b0;

            timeout = 140;
            while (!write_resp_valid[CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_MASTER] &&
                   (timeout > 0)) begin
                #1;
                if (invalidate_all_accepted) begin
                    fail_now("C++ trace invall cache/MMIO write accepted before MMIO response");
                end
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0 ||
                write_resp_valid[CPP_MODE1_INVALL_CACHE_MMIO_WRITE_CACHE_MASTER]) begin
                fail_now("C++ trace invall cache/MMIO write MMIO response owner mismatch");
            end
            #1;
            if (write_resp_id[(CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_RESP_ID ||
                write_resp_code[(CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_MASTER * 2) +: 2] !=
                    CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_RESP_CODE ||
                invalidate_all_accepted !==
                    !CPP_MODE1_INVALL_CACHE_MMIO_WRITE_BLOCKED_MMIO_HELD) begin
                fail_now("C++ trace invall cache/MMIO write MMIO response hold mismatch");
            end

            @(negedge clk);
            ddr_axi_rid = seen_ddr_arid;
            ddr_axi_rdata = CPP_MODE1_INVALL_CACHE_MMIO_WRITE_REFILL_RBEAT0;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b0;
            ddr_axi_rvalid = 1'b1;
            #1;
            if (ddr_axi_rready !== CPP_MODE1_INVALL_CACHE_MMIO_WRITE_REFILL_RREADY_STALLED ||
                ddr_axi_rready !== CPP_MODE1_INVALL_CACHE_MMIO_WRITE_DDR_RREADY_MMIO_HELD ||
                invalidate_all_accepted) begin
                fail_now("C++ trace invall cache/MMIO write refill R beat0 mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;

            ddr_axi_rid = seen_ddr_arid;
            ddr_axi_rdata = CPP_MODE1_INVALL_CACHE_MMIO_WRITE_REFILL_RBEAT1;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b1;
            ddr_axi_rvalid = 1'b1;
            #1;
            if (ddr_axi_rready !== CPP_MODE1_INVALL_CACHE_MMIO_WRITE_REFILL_RREADY_STALLED ||
                ddr_axi_rready !== CPP_MODE1_INVALL_CACHE_MMIO_WRITE_DDR_RREADY_MMIO_HELD ||
                invalidate_all_accepted) begin
                fail_now("C++ trace invall cache/MMIO write refill R beat1 mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;
            ddr_axi_rlast = 1'b0;

            timeout = 260;
            while (!write_resp_valid[CPP_MODE1_INVALL_CACHE_MMIO_WRITE_CACHE_MASTER] &&
                   (timeout > 0)) begin
                #1;
                if (!write_resp_valid[CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_MASTER] ||
                    invalidate_all_accepted) begin
                    fail_now("C++ trace invall cache/MMIO write response drain ordering mismatch");
                end
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace invall cache/MMIO write cache response timeout");
            end
            #1;
            if (write_resp_id[(CPP_MODE1_INVALL_CACHE_MMIO_WRITE_CACHE_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE1_INVALL_CACHE_MMIO_WRITE_CACHE_RESP_ID ||
                write_resp_code[(CPP_MODE1_INVALL_CACHE_MMIO_WRITE_CACHE_MASTER * 2) +: 2] !=
                    CPP_MODE1_INVALL_CACHE_MMIO_WRITE_CACHE_RESP_CODE ||
                invalidate_all_accepted !==
                    !CPP_MODE1_INVALL_CACHE_MMIO_WRITE_BLOCKED_CACHE_HELD) begin
                fail_now("C++ trace invall cache/MMIO write cache response hold mismatch");
            end

            write_resp_ready[CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_MASTER] = 1'b1;
            #1;
            if (invalidate_all_accepted) begin
                fail_now("C++ trace invall cache/MMIO write accepted before MMIO retire");
            end
            @(posedge clk);
            @(negedge clk);
            write_resp_ready[CPP_MODE1_INVALL_CACHE_MMIO_WRITE_MMIO_MASTER] = 1'b0;

            write_resp_ready[CPP_MODE1_INVALL_CACHE_MMIO_WRITE_CACHE_MASTER] = 1'b1;
            #1;
            if (invalidate_all_accepted) begin
                fail_now("C++ trace invall cache/MMIO write accepted before cache retire");
            end
            @(posedge clk);
            @(negedge clk);
            write_resp_ready[CPP_MODE1_INVALL_CACHE_MMIO_WRITE_CACHE_MASTER] = 1'b0;

            if (CPP_MODE1_INVALL_CACHE_MMIO_WRITE_ACCEPTED_AFTER_RETIRE) begin
                timeout = 10000;
                accepted_seen = 1'b0;
                while (!accepted_seen && (timeout > 0)) begin
                    #1;
                    if (invalidate_all_accepted) begin
                        accepted_seen = 1'b1;
                    end
                    @(posedge clk);
                    timeout = timeout - 1;
                end
                if (!accepted_seen) begin
                    fail_now("C++ trace invall cache/MMIO write final accept timeout");
                end
            end else begin
                timeout = 64;
                while (timeout > 0) begin
                    #1;
                    if (invalidate_all_accepted) begin
                        fail_now("C++ trace invall cache/MMIO write accepted despite dirty line");
                    end
                    @(posedge clk);
                    timeout = timeout - 1;
                end
            end
            @(negedge clk);
            invalidate_all_valid = 1'b0;
        end
    endtask

    task issue_mode1_invalidate_all_cache_mmio_rw_and_check;
        integer timeout;
        reg accepted_seen;
        begin
            reset_dut();
            enter_mode(MODE_CACHE);
            @(negedge clk);
            read_resp_ready = {NUM_READ_MASTERS{1'b0}};
            write_resp_ready = {NUM_WRITE_MASTERS{1'b0}};
            ddr_axi_arready = 1'b0;
            mmio_axi_arready = 1'b0;
            mmio_axi_awready = 1'b0;
            mmio_axi_wready = 1'b0;
            invalidate_all_valid = 1'b0;

            read_req_addr[(CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_REQ_ADDR;
            read_req_total_size[(CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_MASTER * 8) +: 8] =
                CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_REQ_SIZE;
            read_req_id[(CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_REQ_ID;
            read_req_bypass[CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_MASTER] = 1'b0;
            read_req_valid[CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_MASTER] = 1'b1;
            timeout = 180;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace invall cache/MMIO RW cache read accept timeout");
            end
            read_req_valid[CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_MASTER] = 1'b0;
            @(negedge clk);

            timeout = 240;
            while (!ddr_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace invall cache/MMIO RW DDR refill AR timeout");
            end
            #1;
            if (ddr_axi_araddr != CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_ARADDR ||
                ddr_axi_arlen != CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_ARLEN ||
                ddr_axi_arsize != CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_ARSIZE ||
                ddr_axi_arburst != CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_ARBURST ||
                ddr_axi_arid != CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_ARID ||
                mmio_axi_arvalid) begin
                fail_now("C++ trace invall cache/MMIO RW DDR refill AR mismatch");
            end
            seen_ddr_arid = ddr_axi_arid;
            ddr_axi_arready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_arready = 1'b0;

            read_req_addr[(CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_REQ_ADDR;
            read_req_total_size[(CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_MASTER * 8) +: 8] =
                CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_REQ_SIZE;
            read_req_id[(CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_REQ_ID;
            read_req_bypass[CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_MASTER] = 1'b0;
            read_req_valid[CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_MASTER] = 1'b1;
            timeout = 180;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace invall cache/MMIO RW MMIO read accept timeout");
            end
            read_req_valid[CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_MASTER] = 1'b0;
            @(negedge clk);

            timeout = 160;
            while (!mmio_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace invall cache/MMIO RW MMIO AR timeout");
            end
            #1;
            if (mmio_axi_araddr != CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_ARADDR ||
                mmio_axi_arlen != CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_ARLEN ||
                mmio_axi_arsize != CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_ARSIZE ||
                mmio_axi_arburst != CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_ARBURST ||
                mmio_axi_arid != CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_ARID ||
                ddr_axi_arvalid) begin
                fail_now("C++ trace invall cache/MMIO RW MMIO AR mismatch");
            end
            seen_mmio_arid = mmio_axi_arid;
            mmio_axi_arready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_arready = 1'b0;

            write_req_addr[(CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_REQ_ADDR;
            write_req_total_size[(CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_MASTER * 8) +: 8] =
                CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_REQ_SIZE;
            write_req_id[(CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_REQ_ID;
            write_req_wdata[(CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_MASTER * LINE_BITS) +: LINE_BITS] =
                CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_REQ_WDATA;
            write_req_wstrb[(CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_MASTER * LINE_BYTES) +: LINE_BYTES] =
                CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_REQ_WSTRB[LINE_BYTES-1:0];
            write_req_bypass[CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_MASTER] = 1'b0;
            write_req_valid[CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_MASTER] = 1'b1;
            timeout = 180;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace invall cache/MMIO RW MMIO write accept timeout");
            end
            write_req_valid[CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_MASTER] = 1'b0;
            @(negedge clk);

            timeout = 140;
            while (!mmio_axi_awvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace invall cache/MMIO RW MMIO AW timeout");
            end
            #1;
            if (mmio_axi_awaddr != CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_AWADDR ||
                mmio_axi_awlen != CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_AWLEN ||
                mmio_axi_awsize != CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_AWSIZE ||
                mmio_axi_awburst != CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_AWBURST ||
                mmio_axi_awid != CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_AWID ||
                ddr_axi_awvalid) begin
                fail_now("C++ trace invall cache/MMIO RW MMIO AW mismatch");
            end
            seen_mmio_awid = mmio_axi_awid;
            mmio_axi_awready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_awready = 1'b0;

            timeout = 140;
            while (!mmio_axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace invall cache/MMIO RW MMIO W timeout");
            end
            #1;
            if (mmio_axi_wdata !=
                    CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_WBEAT0[MMIO_DATA_BITS-1:0] ||
                mmio_axi_wstrb !=
                    CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_WSTRB0[MMIO_STRB_BITS-1:0] ||
                mmio_axi_wlast != CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_WLAST0 ||
                ddr_axi_wvalid) begin
                fail_now("C++ trace invall cache/MMIO RW MMIO W mismatch");
            end
            mmio_axi_wready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_wready = 1'b0;

            invalidate_all_valid = 1'b1;
            mmio_axi_rid = seen_mmio_arid;
            mmio_axi_rdata = CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_RBEAT0[MMIO_DATA_BITS-1:0];
            mmio_axi_rresp = AXI_RESP_OKAY;
            mmio_axi_rlast = 1'b1;
            mmio_axi_rvalid = 1'b1;
            mmio_axi_bid = seen_mmio_awid;
            mmio_axi_bresp = AXI_RESP_OKAY;
            mmio_axi_bvalid = 1'b1;
            #1;
            if (mmio_axi_rready !== CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_RREADY_STALLED ||
                mmio_axi_rready !== CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_RREADY_PENDING ||
                mmio_axi_bready !== CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_BREADY_STALLED ||
                mmio_axi_bready !== CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_BREADY_PENDING ||
                invalidate_all_accepted) begin
                fail_now("C++ trace invall cache/MMIO RW MMIO R/B mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_rvalid = 1'b0;
            mmio_axi_rlast = 1'b0;
            mmio_axi_bvalid = 1'b0;

            timeout = 180;
            while ((!read_resp_valid[CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_MASTER] ||
                    !write_resp_valid[CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_MASTER]) &&
                   (timeout > 0)) begin
                #1;
                if (invalidate_all_accepted) begin
                    fail_now("C++ trace invall cache/MMIO RW accepted before MMIO responses");
                end
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0 ||
                read_resp_valid[CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_MASTER]) begin
                fail_now("C++ trace invall cache/MMIO RW MMIO response owner mismatch");
            end
            #1;
            if (read_resp_id[(CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_RESP_ID ||
                read_resp_data[(CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_RESP_DATA ||
                write_resp_id[(CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_RESP_ID ||
                write_resp_code[(CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_MASTER * 2) +: 2] !=
                    CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_RESP_CODE ||
                invalidate_all_accepted !==
                    !CPP_MODE1_INVALL_CACHE_MMIO_RW_BLOCKED_MMIO_HELD) begin
                fail_now("C++ trace invall cache/MMIO RW held MMIO response mismatch");
            end

            @(negedge clk);
            ddr_axi_rid = seen_ddr_arid;
            ddr_axi_rdata = CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_RBEAT0;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b0;
            ddr_axi_rvalid = 1'b1;
            #1;
            if (ddr_axi_rready !== CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_RREADY_STALLED ||
                ddr_axi_rready !== CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_RREADY_MMIO_HELD ||
                invalidate_all_accepted) begin
                fail_now("C++ trace invall cache/MMIO RW DDR R beat0 mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;

            ddr_axi_rid = seen_ddr_arid;
            ddr_axi_rdata = CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_RBEAT1;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b1;
            ddr_axi_rvalid = 1'b1;
            #1;
            if (ddr_axi_rready !== CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_RREADY_STALLED ||
                ddr_axi_rready !== CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_RREADY_MMIO_HELD ||
                invalidate_all_accepted) begin
                fail_now("C++ trace invall cache/MMIO RW DDR R beat1 mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;
            ddr_axi_rlast = 1'b0;

            timeout = 260;
            while (!read_resp_valid[CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_MASTER] &&
                   (timeout > 0)) begin
                #1;
                if (!read_resp_valid[CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_MASTER] ||
                    !write_resp_valid[CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_MASTER] ||
                    invalidate_all_accepted) begin
                    fail_now("C++ trace invall cache/MMIO RW response drain ordering mismatch");
                end
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace invall cache/MMIO RW cache response timeout");
            end
            #1;
            if (read_resp_id[(CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_RESP_ID ||
                read_resp_data[(CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_RESP_DATA ||
                invalidate_all_accepted !==
                    !CPP_MODE1_INVALL_CACHE_MMIO_RW_BLOCKED_CACHE_HELD) begin
                fail_now("C++ trace invall cache/MMIO RW cache response hold mismatch");
            end

            read_resp_ready[CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_MASTER] = 1'b1;
            #1;
            if (invalidate_all_accepted) begin
                fail_now("C++ trace invall cache/MMIO RW accepted before MMIO read retire");
            end
            @(posedge clk);
            @(negedge clk);
            read_resp_ready[CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_READ_MASTER] = 1'b0;

            write_resp_ready[CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_MASTER] = 1'b1;
            #1;
            if (invalidate_all_accepted) begin
                fail_now("C++ trace invall cache/MMIO RW accepted before MMIO write retire");
            end
            @(posedge clk);
            @(negedge clk);
            write_resp_ready[CPP_MODE1_INVALL_CACHE_MMIO_RW_MMIO_WRITE_MASTER] = 1'b0;

            read_resp_ready[CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_MASTER] = 1'b1;
            #1;
            if (invalidate_all_accepted) begin
                fail_now("C++ trace invall cache/MMIO RW accepted before cache retire");
            end
            @(posedge clk);
            @(negedge clk);
            read_resp_ready[CPP_MODE1_INVALL_CACHE_MMIO_RW_DDR_MASTER] = 1'b0;

            timeout = 10000;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                #1;
                if (invalidate_all_accepted) begin
                    accepted_seen = 1'b1;
                end
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (accepted_seen !==
                CPP_MODE1_INVALL_CACHE_MMIO_RW_ACCEPTED_AFTER_RETIRE) begin
                fail_now("C++ trace invall cache/MMIO RW final accept mismatch");
            end
            @(negedge clk);
            invalidate_all_valid = 1'b0;
        end
    endtask

    task issue_mode1_invalidate_line_pending_read_and_check;
        integer timeout;
        reg accepted_seen;
        begin
            reset_dut();
            enter_mode(MODE_CACHE);
            @(negedge clk);
            read_resp_ready = {NUM_READ_MASTERS{1'b0}};
            ddr_axi_arready = 1'b0;

            read_req_addr[(CPP_MODE1_INVALIDATE_LINE_PENDING_READ_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_INVALIDATE_LINE_PENDING_READ_REQ_ADDR;
            read_req_total_size[(CPP_MODE1_INVALIDATE_LINE_PENDING_READ_MASTER * 8) +: 8] =
                CPP_MODE1_INVALIDATE_LINE_PENDING_READ_REQ_SIZE;
            read_req_id[(CPP_MODE1_INVALIDATE_LINE_PENDING_READ_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_INVALIDATE_LINE_PENDING_READ_REQ_ID;
            read_req_bypass[CPP_MODE1_INVALIDATE_LINE_PENDING_READ_MASTER] = 1'b0;
            read_req_valid[CPP_MODE1_INVALIDATE_LINE_PENDING_READ_MASTER] = 1'b1;
            timeout = 180;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[CPP_MODE1_INVALIDATE_LINE_PENDING_READ_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace invalidate-line pending read accept timeout");
            end
            read_req_valid[CPP_MODE1_INVALIDATE_LINE_PENDING_READ_MASTER] = 1'b0;
            @(negedge clk);

            timeout = 240;
            while (!ddr_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace invalidate-line pending read AR timeout");
            end
            #1;
            if (ddr_axi_araddr != CPP_MODE1_INVALIDATE_LINE_PENDING_READ_ARADDR ||
                ddr_axi_arlen != CPP_MODE1_INVALIDATE_LINE_PENDING_READ_ARLEN ||
                ddr_axi_arsize != CPP_MODE1_INVALIDATE_LINE_PENDING_READ_ARSIZE ||
                ddr_axi_arburst != CPP_MODE1_INVALIDATE_LINE_PENDING_READ_ARBURST ||
                ddr_axi_arid != CPP_MODE1_INVALIDATE_LINE_PENDING_READ_ARID ||
                mmio_axi_arvalid) begin
                fail_now("C++ trace invalidate-line pending read AR mismatch");
            end
            seen_ddr_arid = ddr_axi_arid;
            ddr_axi_arready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_arready = 1'b0;

            invalidate_line_addr = CPP_MODE1_INVALIDATE_LINE_PENDING_READ_INVALIDATE_ADDR;
            invalidate_line_valid = 1'b1;
            repeat (3) begin
                #1;
                if (invalidate_line_accepted !==
                    !CPP_MODE1_INVALIDATE_LINE_PENDING_READ_BLOCKED_BEFORE_R) begin
                    fail_now("C++ trace invalidate-line pending read early accept mismatch");
                end
                @(posedge clk);
                @(negedge clk);
            end

            ddr_axi_rid = seen_ddr_arid;
            ddr_axi_rdata = CPP_MODE1_INVALIDATE_LINE_PENDING_READ_RBEAT0;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b0;
            ddr_axi_rvalid = 1'b1;
            #1;
            if (ddr_axi_rready !== CPP_MODE1_INVALIDATE_LINE_PENDING_READ_RREADY_PENDING ||
                invalidate_line_accepted) begin
                fail_now("C++ trace invalidate-line pending read R beat0 mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;

            ddr_axi_rid = seen_ddr_arid;
            ddr_axi_rdata = CPP_MODE1_INVALIDATE_LINE_PENDING_READ_RBEAT1;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b1;
            ddr_axi_rvalid = 1'b1;
            #1;
            if (ddr_axi_rready !== CPP_MODE1_INVALIDATE_LINE_PENDING_READ_RREADY_PENDING ||
                invalidate_line_accepted) begin
                fail_now("C++ trace invalidate-line pending read R beat1 mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;
            ddr_axi_rlast = 1'b0;

            timeout = 240;
            while (!read_resp_valid[CPP_MODE1_INVALIDATE_LINE_PENDING_READ_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace invalidate-line pending read response timeout");
            end
            #1;
            if (read_resp_id[(CPP_MODE1_INVALIDATE_LINE_PENDING_READ_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE1_INVALIDATE_LINE_PENDING_READ_RESP_ID ||
                read_resp_data[(CPP_MODE1_INVALIDATE_LINE_PENDING_READ_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    CPP_MODE1_INVALIDATE_LINE_PENDING_READ_RESP_DATA) begin
                fail_now("C++ trace invalidate-line pending read response mismatch");
            end
            if (invalidate_line_accepted !==
                !CPP_MODE1_INVALIDATE_LINE_PENDING_READ_BLOCKED_WHILE_RESP_HELD) begin
                fail_now("C++ trace invalidate-line held response accept mismatch");
            end
            read_resp_ready[CPP_MODE1_INVALIDATE_LINE_PENDING_READ_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
            read_resp_ready[CPP_MODE1_INVALIDATE_LINE_PENDING_READ_MASTER] = 1'b0;

            if (CPP_MODE1_INVALIDATE_LINE_PENDING_READ_BLOCKED_WHILE_RESP_HELD) begin
                timeout = 240;
                accepted_seen = 1'b0;
                while (!accepted_seen && (timeout > 0)) begin
                    #1;
                    if (invalidate_line_accepted) begin
                        accepted_seen = 1'b1;
                    end
                    @(posedge clk);
                    timeout = timeout - 1;
                end
                if (accepted_seen !==
                    CPP_MODE1_INVALIDATE_LINE_PENDING_READ_ACCEPTED_AFTER_RETIRE) begin
                    fail_now("C++ trace invalidate-line final accept mismatch");
                end
            end
            @(negedge clk);
            invalidate_line_valid = 1'b0;
            invalidate_line_addr = {ADDR_BITS{1'b0}};
        end
    endtask

    task issue_mode1_invalidate_line_cache_mmio_read_and_check;
        integer timeout;
        reg accepted_seen;
        begin
            reset_dut();
            enter_mode(MODE_CACHE);
            @(negedge clk);
            read_resp_ready = {NUM_READ_MASTERS{1'b0}};
            ddr_axi_arready = 1'b0;
            mmio_axi_arready = 1'b0;
            invalidate_line_valid = 1'b0;

            read_req_addr[(CPP_MODE1_INVLINE_CACHE_MMIO_DDR_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_INVLINE_CACHE_MMIO_DDR_REQ_ADDR;
            read_req_total_size[(CPP_MODE1_INVLINE_CACHE_MMIO_DDR_MASTER * 8) +: 8] =
                CPP_MODE1_INVLINE_CACHE_MMIO_DDR_REQ_SIZE;
            read_req_id[(CPP_MODE1_INVLINE_CACHE_MMIO_DDR_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_INVLINE_CACHE_MMIO_DDR_REQ_ID;
            read_req_bypass[CPP_MODE1_INVLINE_CACHE_MMIO_DDR_MASTER] = 1'b0;
            read_req_valid[CPP_MODE1_INVLINE_CACHE_MMIO_DDR_MASTER] = 1'b1;
            timeout = 180;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[CPP_MODE1_INVLINE_CACHE_MMIO_DDR_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace invline cache/MMIO cache read accept timeout");
            end
            read_req_valid[CPP_MODE1_INVLINE_CACHE_MMIO_DDR_MASTER] = 1'b0;
            @(negedge clk);

            timeout = 240;
            while (!ddr_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace invline cache/MMIO DDR refill AR timeout");
            end
            #1;
            if (ddr_axi_araddr != CPP_MODE1_INVLINE_CACHE_MMIO_DDR_ARADDR ||
                ddr_axi_arlen != CPP_MODE1_INVLINE_CACHE_MMIO_DDR_ARLEN ||
                ddr_axi_arsize != CPP_MODE1_INVLINE_CACHE_MMIO_DDR_ARSIZE ||
                ddr_axi_arburst != CPP_MODE1_INVLINE_CACHE_MMIO_DDR_ARBURST ||
                ddr_axi_arid != CPP_MODE1_INVLINE_CACHE_MMIO_DDR_ARID ||
                mmio_axi_arvalid) begin
                fail_now("C++ trace invline cache/MMIO DDR refill AR mismatch");
            end
            seen_ddr_arid = ddr_axi_arid;
            ddr_axi_arready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_arready = 1'b0;

            read_req_addr[(CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_REQ_ADDR;
            read_req_total_size[(CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_MASTER * 8) +: 8] =
                CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_REQ_SIZE;
            read_req_id[(CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_REQ_ID;
            read_req_bypass[CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_MASTER] = 1'b0;
            read_req_valid[CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_MASTER] = 1'b1;
            timeout = 180;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace invline cache/MMIO MMIO read accept timeout");
            end
            read_req_valid[CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_MASTER] = 1'b0;
            @(negedge clk);

            timeout = 160;
            while (!mmio_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace invline cache/MMIO MMIO AR timeout");
            end
            #1;
            if (mmio_axi_araddr != CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_ARADDR ||
                mmio_axi_arlen != CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_ARLEN ||
                mmio_axi_arsize != CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_ARSIZE ||
                mmio_axi_arburst != CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_ARBURST ||
                mmio_axi_arid != CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_ARID ||
                ddr_axi_arvalid) begin
                fail_now("C++ trace invline cache/MMIO MMIO AR mismatch");
            end
            seen_mmio_arid = mmio_axi_arid;
            mmio_axi_arready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_arready = 1'b0;

            invalidate_line_addr = CPP_MODE1_INVLINE_CACHE_MMIO_READ_INVALIDATE_ADDR;
            invalidate_line_valid = 1'b1;
            mmio_axi_rid = seen_mmio_arid;
            mmio_axi_rdata = CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_RBEAT0[MMIO_DATA_BITS-1:0];
            mmio_axi_rresp = AXI_RESP_OKAY;
            mmio_axi_rlast = 1'b1;
            mmio_axi_rvalid = 1'b1;
            #1;
            if (mmio_axi_rready !== CPP_MODE1_INVLINE_CACHE_MMIO_READ_MMIO_RREADY_PENDING ||
                invalidate_line_accepted) begin
                fail_now("C++ trace invline cache/MMIO MMIO R or accept mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_rvalid = 1'b0;
            mmio_axi_rlast = 1'b0;

            timeout = 160;
            while (!read_resp_valid[CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_MASTER] &&
                   (timeout > 0)) begin
                #1;
                if (invalidate_line_accepted) begin
                    fail_now("C++ trace invline cache/MMIO accepted before MMIO response");
                end
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0 ||
                read_resp_valid[CPP_MODE1_INVLINE_CACHE_MMIO_DDR_MASTER]) begin
                fail_now("C++ trace invline cache/MMIO MMIO response owner mismatch");
            end
            #1;
            if (read_resp_id[(CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_RESP_ID ||
                read_resp_data[(CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_RESP_DATA ||
                invalidate_line_accepted !==
                    !CPP_MODE1_INVLINE_CACHE_MMIO_READ_BLOCKED_MMIO_HELD) begin
                fail_now("C++ trace invline cache/MMIO MMIO response hold mismatch");
            end

            @(negedge clk);
            ddr_axi_rid = seen_ddr_arid;
            ddr_axi_rdata = CPP_MODE1_INVLINE_CACHE_MMIO_DDR_RBEAT0;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b0;
            ddr_axi_rvalid = 1'b1;
            #1;
            if (ddr_axi_rready !== CPP_MODE1_INVLINE_CACHE_MMIO_READ_DDR_RREADY_MMIO_HELD ||
                invalidate_line_accepted) begin
                fail_now("C++ trace invline cache/MMIO DDR R beat0 mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;

            ddr_axi_rid = seen_ddr_arid;
            ddr_axi_rdata = CPP_MODE1_INVLINE_CACHE_MMIO_DDR_RBEAT1;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b1;
            ddr_axi_rvalid = 1'b1;
            #1;
            if (ddr_axi_rready !== CPP_MODE1_INVLINE_CACHE_MMIO_READ_DDR_RREADY_MMIO_HELD ||
                invalidate_line_accepted) begin
                fail_now("C++ trace invline cache/MMIO DDR R beat1 mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;
            ddr_axi_rlast = 1'b0;

            timeout = 240;
            while (!read_resp_valid[CPP_MODE1_INVLINE_CACHE_MMIO_DDR_MASTER] &&
                   (timeout > 0)) begin
                #1;
                if (!read_resp_valid[CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_MASTER] ||
                    invalidate_line_accepted) begin
                    fail_now("C++ trace invline cache/MMIO response drain ordering mismatch");
                end
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace invline cache/MMIO DDR response timeout");
            end
            #1;
            if (read_resp_id[(CPP_MODE1_INVLINE_CACHE_MMIO_DDR_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE1_INVLINE_CACHE_MMIO_DDR_RESP_ID ||
                read_resp_data[(CPP_MODE1_INVLINE_CACHE_MMIO_DDR_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    CPP_MODE1_INVLINE_CACHE_MMIO_DDR_RESP_DATA ||
                invalidate_line_accepted !==
                    !CPP_MODE1_INVLINE_CACHE_MMIO_READ_BLOCKED_CACHE_HELD) begin
                fail_now("C++ trace invline cache/MMIO DDR response hold mismatch");
            end

            read_resp_ready[CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_MASTER] = 1'b1;
            #1;
            if (invalidate_line_accepted) begin
                fail_now("C++ trace invline cache/MMIO accepted before MMIO retire");
            end
            @(posedge clk);
            @(negedge clk);
            read_resp_ready[CPP_MODE1_INVLINE_CACHE_MMIO_MMIO_MASTER] = 1'b0;

            read_resp_ready[CPP_MODE1_INVLINE_CACHE_MMIO_DDR_MASTER] = 1'b1;
            #1;
            if (invalidate_line_accepted) begin
                fail_now("C++ trace invline cache/MMIO accepted before cache retire");
            end
            @(posedge clk);
            @(negedge clk);
            read_resp_ready[CPP_MODE1_INVLINE_CACHE_MMIO_DDR_MASTER] = 1'b0;

            timeout = 10000;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                #1;
                if (invalidate_line_accepted) begin
                    accepted_seen = 1'b1;
                end
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (accepted_seen !==
                CPP_MODE1_INVLINE_CACHE_MMIO_READ_ACCEPTED_AFTER_RETIRE) begin
                fail_now("C++ trace invline cache/MMIO final accept mismatch");
            end
            @(negedge clk);
            invalidate_line_valid = 1'b0;
            invalidate_line_addr = {ADDR_BITS{1'b0}};
        end
    endtask

    task issue_mode1_same_line_read_pending_write_and_check;
        integer timeout;
        reg accepted_seen;
        begin
            reset_dut();
            enter_mode(MODE_CACHE);
            @(negedge clk);
            read_resp_ready = {NUM_READ_MASTERS{1'b0}};
            write_resp_ready = {NUM_WRITE_MASTERS{1'b0}};
            ddr_axi_arready = 1'b0;

            read_req_addr[(CPP_MODE1_SAME_LINE_READ_PENDING_READ_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_SAME_LINE_READ_PENDING_READ_REQ_ADDR;
            read_req_total_size[(CPP_MODE1_SAME_LINE_READ_PENDING_READ_MASTER * 8) +: 8] =
                CPP_MODE1_SAME_LINE_READ_PENDING_READ_REQ_SIZE;
            read_req_id[(CPP_MODE1_SAME_LINE_READ_PENDING_READ_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_SAME_LINE_READ_PENDING_READ_REQ_ID;
            read_req_bypass[CPP_MODE1_SAME_LINE_READ_PENDING_READ_MASTER] = 1'b0;
            read_req_valid[CPP_MODE1_SAME_LINE_READ_PENDING_READ_MASTER] = 1'b1;
            timeout = 180;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[CPP_MODE1_SAME_LINE_READ_PENDING_READ_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace same-line pending read accept timeout");
            end
            read_req_valid[CPP_MODE1_SAME_LINE_READ_PENDING_READ_MASTER] = 1'b0;
            @(negedge clk);

            timeout = 240;
            while (!ddr_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace same-line pending read AR timeout");
            end
            #1;
            if (ddr_axi_araddr != CPP_MODE1_SAME_LINE_READ_PENDING_READ_ARADDR ||
                ddr_axi_arlen != CPP_MODE1_SAME_LINE_READ_PENDING_READ_ARLEN ||
                ddr_axi_arsize != CPP_MODE1_SAME_LINE_READ_PENDING_READ_ARSIZE ||
                ddr_axi_arburst != CPP_MODE1_SAME_LINE_READ_PENDING_READ_ARBURST ||
                ddr_axi_arid != CPP_MODE1_SAME_LINE_READ_PENDING_READ_ARID ||
                mmio_axi_arvalid || ddr_axi_awvalid || ddr_axi_wvalid ||
                mmio_axi_awvalid || mmio_axi_wvalid) begin
                fail_now("C++ trace same-line pending read AR mismatch");
            end
            ddr_axi_arready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_arready = 1'b0;

            write_req_addr[(CPP_MODE1_SAME_LINE_READ_PENDING_WRITE_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_SAME_LINE_READ_PENDING_WRITE_REQ_ADDR;
            write_req_total_size[(CPP_MODE1_SAME_LINE_READ_PENDING_WRITE_MASTER * 8) +: 8] =
                CPP_MODE1_SAME_LINE_READ_PENDING_WRITE_REQ_SIZE;
            write_req_id[(CPP_MODE1_SAME_LINE_READ_PENDING_WRITE_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_SAME_LINE_READ_PENDING_WRITE_REQ_ID;
            write_req_wdata[(CPP_MODE1_SAME_LINE_READ_PENDING_WRITE_MASTER * LINE_BITS) +: LINE_BITS] =
                CPP_MODE1_SAME_LINE_READ_PENDING_WRITE_REQ_WDATA;
            write_req_wstrb[(CPP_MODE1_SAME_LINE_READ_PENDING_WRITE_MASTER * LINE_BYTES) +: LINE_BYTES] =
                CPP_MODE1_SAME_LINE_READ_PENDING_WRITE_REQ_WSTRB[LINE_BYTES-1:0];
            write_req_bypass[CPP_MODE1_SAME_LINE_READ_PENDING_WRITE_MASTER] = 1'b0;
            write_req_valid[CPP_MODE1_SAME_LINE_READ_PENDING_WRITE_MASTER] = 1'b1;
            #1;
            if (write_req_ready[CPP_MODE1_SAME_LINE_READ_PENDING_WRITE_MASTER] !==
                    CPP_MODE1_SAME_LINE_READ_PENDING_WRITE_REQ_READY ||
                write_req_accepted[CPP_MODE1_SAME_LINE_READ_PENDING_WRITE_MASTER] !==
                    CPP_MODE1_SAME_LINE_READ_PENDING_WRITE_ACCEPTED_WHILE_READ_PENDING ||
                !CPP_MODE1_SAME_LINE_READ_PENDING_WRITE_NO_EXTERNAL_ISSUE_WHILE_READ_PENDING ||
                ddr_axi_awvalid || ddr_axi_wvalid || ddr_axi_arvalid ||
                mmio_axi_awvalid || mmio_axi_wvalid || mmio_axi_arvalid) begin
                fail_now("C++ trace same-line pending read write mismatch");
            end
            @(negedge clk);
            write_req_valid[CPP_MODE1_SAME_LINE_READ_PENDING_WRITE_MASTER] = 1'b0;
        end
    endtask

    task issue_mode1_same_line_mmio_read_pending_write_and_check;
        integer timeout;
        reg accepted_seen;
        begin
            reset_dut();
            enter_mode(MODE_CACHE);
            @(negedge clk);
            read_resp_ready = {NUM_READ_MASTERS{1'b0}};
            write_resp_ready = {NUM_WRITE_MASTERS{1'b0}};
            mmio_axi_arready = 1'b0;

            read_req_addr[(CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_READ_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_READ_REQ_ADDR;
            read_req_total_size[(CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_READ_MASTER * 8) +: 8] =
                CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_READ_REQ_SIZE;
            read_req_id[(CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_READ_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_READ_REQ_ID;
            read_req_bypass[CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_READ_MASTER] = 1'b0;
            read_req_valid[CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_READ_MASTER] = 1'b1;

            timeout = 160;
            accepted_seen = 1'b0;
            while (!mmio_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_READ_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace same-line MMIO pending read AR timeout");
            end
            #1;
            if (mmio_axi_araddr != CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_READ_ARADDR ||
                mmio_axi_arlen != CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_READ_ARLEN ||
                mmio_axi_arsize != CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_READ_ARSIZE ||
                mmio_axi_arburst != CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_READ_ARBURST ||
                mmio_axi_arid != CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_READ_ARID ||
                ddr_axi_arvalid || ddr_axi_awvalid || ddr_axi_wvalid ||
                mmio_axi_awvalid || mmio_axi_wvalid) begin
                fail_now("C++ trace same-line MMIO pending read AR mismatch");
            end
            mmio_axi_arready = 1'b1;
            @(posedge clk);
            #1;
            if (read_req_accepted[CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_READ_MASTER]) begin
                accepted_seen = 1'b1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace same-line MMIO pending read accept missing");
            end
            @(negedge clk);
            read_req_valid[CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_READ_MASTER] = 1'b0;
            read_req_bypass[CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_READ_MASTER] = 1'b0;
            mmio_axi_arready = 1'b0;

            write_req_addr[(CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_WRITE_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_WRITE_REQ_ADDR;
            write_req_total_size[(CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_WRITE_MASTER * 8) +: 8] =
                CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_WRITE_REQ_SIZE;
            write_req_id[(CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_WRITE_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_WRITE_REQ_ID;
            write_req_wdata[(CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_WRITE_MASTER * LINE_BITS) +: LINE_BITS] =
                CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_WRITE_REQ_WDATA;
            write_req_wstrb[(CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_WRITE_MASTER * LINE_BYTES) +: LINE_BYTES] =
                CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_WRITE_REQ_WSTRB[LINE_BYTES-1:0];
            write_req_bypass[CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_WRITE_MASTER] = 1'b0;
            write_req_valid[CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_WRITE_MASTER] = 1'b1;
            accepted_seen = 1'b0;
            #1;
            if (write_req_accepted[CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_WRITE_MASTER]) begin
                accepted_seen = 1'b1;
            end
            if (!CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_WRITE_NO_EXTERNAL_ISSUE_WHILE_READ_PENDING ||
                ddr_axi_awvalid || ddr_axi_wvalid || ddr_axi_arvalid ||
                mmio_axi_awvalid || mmio_axi_wvalid || mmio_axi_arvalid) begin
                $display("same-line MMIO pending write external issue mismatch: accepted=%0b ddr_aw=%0b ddr_w=%0b ddr_ar=%0b mmio_aw=%0b mmio_w=%0b mmio_ar=%0b",
                         accepted_seen,
                         ddr_axi_awvalid, ddr_axi_wvalid, ddr_axi_arvalid,
                         mmio_axi_awvalid, mmio_axi_wvalid, mmio_axi_arvalid);
                fail_now("C++ trace same-line MMIO pending read write mismatch");
            end
            repeat (4) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_WRITE_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                if (!CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_WRITE_NO_EXTERNAL_ISSUE_WHILE_READ_PENDING ||
                    ddr_axi_awvalid || ddr_axi_wvalid || ddr_axi_arvalid ||
                    mmio_axi_awvalid || mmio_axi_wvalid || mmio_axi_arvalid) begin
                    fail_now("C++ trace same-line MMIO pending write issued before R");
                end
                @(negedge clk);
                if (accepted_seen) begin
                    write_req_valid[CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_WRITE_MASTER] = 1'b0;
                end
            end
            if (accepted_seen !==
                CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_WRITE_ACCEPTED_WHILE_READ_PENDING) begin
                $display("same-line MMIO pending write accept mismatch: accepted_seen=%0b expected=%0b",
                         accepted_seen,
                         CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_WRITE_ACCEPTED_WHILE_READ_PENDING);
                fail_now("C++ trace same-line MMIO pending write accept mismatch");
            end
            write_req_valid[CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_WRITE_MASTER] = 1'b0;
            write_req_bypass[CPP_MODE1_SAME_LINE_MMIO_READ_PENDING_WRITE_MASTER] = 1'b0;
        end
    endtask

    task issue_mode1_same_line_mmio_write_pending_read_and_check;
        integer timeout;
        reg accepted_seen;
        begin
            reset_dut();
            enter_mode(MODE_CACHE);
            @(negedge clk);
            read_resp_ready = {NUM_READ_MASTERS{1'b0}};
            write_resp_ready = {NUM_WRITE_MASTERS{1'b0}};
            mmio_axi_awready = 1'b0;
            mmio_axi_wready = 1'b0;

            write_req_addr[(CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_REQ_ADDR;
            write_req_total_size[(CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_MASTER * 8) +: 8] =
                CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_REQ_SIZE;
            write_req_id[(CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_REQ_ID;
            write_req_wdata[(CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_MASTER * LINE_BITS) +: LINE_BITS] =
                CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_REQ_WDATA;
            write_req_wstrb[(CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_MASTER * LINE_BYTES) +: LINE_BYTES] =
                CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_REQ_WSTRB[LINE_BYTES-1:0];
            write_req_bypass[CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_MASTER] = 1'b0;
            write_req_valid[CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_MASTER] = 1'b1;

            timeout = 160;
            accepted_seen = 1'b0;
            while (!mmio_axi_awvalid && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace same-line MMIO pending write AW timeout");
            end
            #1;
            expect_no_ddr_activity();
            if (mmio_axi_awaddr != CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_AWADDR ||
                mmio_axi_awlen != CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_AWLEN ||
                mmio_axi_awsize != CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_AWSIZE ||
                mmio_axi_awburst != CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_AWBURST ||
                mmio_axi_awid != CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_AWID ||
                mmio_axi_arvalid || mmio_axi_wvalid) begin
                fail_now("C++ trace same-line MMIO pending write AW mismatch");
            end
            seen_mmio_awid = mmio_axi_awid;
            mmio_axi_awready = 1'b1;
            @(posedge clk);
            #1;
            if (write_req_accepted[CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_MASTER]) begin
                accepted_seen = 1'b1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace same-line MMIO pending write accept missing");
            end
            @(negedge clk);
            write_req_valid[CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_MASTER] = 1'b0;
            write_req_bypass[CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_MASTER] = 1'b0;
            mmio_axi_awready = 1'b0;

            timeout = 160;
            while (!mmio_axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace same-line MMIO pending write W timeout");
            end
            #1;
            expect_no_ddr_activity();
            if (mmio_axi_wdata !=
                    CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_WBEAT0[MMIO_DATA_BITS-1:0] ||
                mmio_axi_wstrb !=
                    CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_WSTRB0[MMIO_STRB_BITS-1:0] ||
                mmio_axi_wlast != CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_WRITE_WLAST0 ||
                mmio_axi_awvalid || mmio_axi_arvalid) begin
                fail_now("C++ trace same-line MMIO pending write W mismatch");
            end
            mmio_axi_wready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_wready = 1'b0;

            read_req_addr[(CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_READ_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_READ_REQ_ADDR;
            read_req_total_size[(CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_READ_MASTER * 8) +: 8] =
                CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_READ_REQ_SIZE;
            read_req_id[(CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_READ_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_READ_REQ_ID;
            read_req_bypass[CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_READ_MASTER] = 1'b0;
            read_req_valid[CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_READ_MASTER] = 1'b1;
            accepted_seen = 1'b0;
            #1;
            if (read_req_accepted[CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_READ_MASTER]) begin
                accepted_seen = 1'b1;
            end
            if (!CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_READ_NO_EXTERNAL_ISSUE_WHILE_WRITE_PENDING ||
                ddr_axi_arvalid || ddr_axi_awvalid || ddr_axi_wvalid ||
                mmio_axi_arvalid || mmio_axi_awvalid || mmio_axi_wvalid) begin
                $display("same-line MMIO pending read external issue mismatch: accepted=%0b ddr_ar=%0b ddr_aw=%0b ddr_w=%0b mmio_ar=%0b mmio_aw=%0b mmio_w=%0b",
                         accepted_seen,
                         ddr_axi_arvalid, ddr_axi_awvalid, ddr_axi_wvalid,
                         mmio_axi_arvalid, mmio_axi_awvalid, mmio_axi_wvalid);
                fail_now("C++ trace same-line MMIO pending write read mismatch");
            end
            repeat (4) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_READ_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                if (!CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_READ_NO_EXTERNAL_ISSUE_WHILE_WRITE_PENDING ||
                    ddr_axi_arvalid || ddr_axi_awvalid || ddr_axi_wvalid ||
                    mmio_axi_arvalid || mmio_axi_awvalid || mmio_axi_wvalid) begin
                    fail_now("C++ trace same-line MMIO pending read issued before B");
                end
                @(negedge clk);
                if (accepted_seen) begin
                    read_req_valid[CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_READ_MASTER] = 1'b0;
                end
            end
            if (accepted_seen !==
                CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_READ_ACCEPTED_WHILE_WRITE_PENDING) begin
                $display("same-line MMIO pending read accept mismatch: accepted_seen=%0b expected=%0b",
                         accepted_seen,
                         CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_READ_ACCEPTED_WHILE_WRITE_PENDING);
                fail_now("C++ trace same-line MMIO pending read accept mismatch");
            end
            read_req_valid[CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_READ_MASTER] = 1'b0;
            read_req_bypass[CPP_MODE1_SAME_LINE_MMIO_WRITE_PENDING_READ_MASTER] = 1'b0;
        end
    endtask

    task issue_mode0_same_line_write_pending_read_and_check;
        integer timeout;
        reg accepted_seen;
        begin
            reset_dut();
            @(negedge clk);
            ddr_axi_awready = 1'b0;
            ddr_axi_wready = 1'b0;

            write_req_addr[(CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_REQ_ADDR;
            write_req_total_size[(CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_MASTER * 8) +: 8] =
                CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_REQ_SIZE;
            write_req_id[(CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_REQ_ID;
            write_req_wdata[(CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_MASTER * LINE_BITS) +: LINE_BITS] =
                CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_REQ_WDATA;
            write_req_wstrb[(CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_MASTER * LINE_BYTES) +: LINE_BYTES] =
                CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_REQ_WSTRB[LINE_BYTES-1:0];
            write_req_bypass[CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_MASTER] = 1'b0;
            write_req_valid[CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_MASTER] = 1'b1;

            accepted_seen = 1'b0;
            timeout = 100;
            while (!ddr_axi_awvalid && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace same-line pending write AW timeout");
            end
            #1;
            if (ddr_axi_awaddr != CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_AWADDR ||
                ddr_axi_awlen != CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_AWLEN ||
                ddr_axi_awsize != CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_AWSIZE ||
                ddr_axi_awburst != CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_AWBURST ||
                ddr_axi_awid != CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_AWID ||
                mmio_axi_awvalid || mmio_axi_wvalid || mmio_axi_arvalid ||
                ddr_axi_arvalid) begin
                fail_now("C++ trace same-line pending write AW mismatch");
            end
            seen_ddr_awid = ddr_axi_awid;
            ddr_axi_awready = 1'b1;
            @(posedge clk);
            #1;
            if (write_req_accepted[CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_MASTER]) begin
                accepted_seen = 1'b1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace same-line pending write accepted missing");
            end
            @(negedge clk);
            write_req_valid[CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_MASTER] = 1'b0;
            write_req_bypass[CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_MASTER] = 1'b0;
            ddr_axi_awready = 1'b0;

            timeout = 100;
            while (!ddr_axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace same-line pending write W timeout");
            end
            #1;
            if (ddr_axi_wdata != CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_WBEAT0 ||
                ddr_axi_wstrb != CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_WSTRB0 ||
                ddr_axi_wlast != CPP_MODE0_SAME_LINE_WRITE_PENDING_WRITE_WLAST0 ||
                ddr_axi_awvalid || mmio_axi_awvalid || mmio_axi_wvalid ||
                mmio_axi_arvalid || ddr_axi_arvalid) begin
                fail_now("C++ trace same-line pending write W mismatch");
            end
            ddr_axi_wready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_wready = 1'b0;

            read_req_addr[(CPP_MODE0_SAME_LINE_WRITE_PENDING_READ_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE0_SAME_LINE_WRITE_PENDING_READ_REQ_ADDR;
            read_req_total_size[(CPP_MODE0_SAME_LINE_WRITE_PENDING_READ_MASTER * 8) +: 8] =
                CPP_MODE0_SAME_LINE_WRITE_PENDING_READ_REQ_SIZE;
            read_req_id[(CPP_MODE0_SAME_LINE_WRITE_PENDING_READ_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE0_SAME_LINE_WRITE_PENDING_READ_REQ_ID;
            read_req_bypass[CPP_MODE0_SAME_LINE_WRITE_PENDING_READ_MASTER] = 1'b0;
            read_req_valid[CPP_MODE0_SAME_LINE_WRITE_PENDING_READ_MASTER] = 1'b1;
            #1;
            if (read_req_ready[CPP_MODE0_SAME_LINE_WRITE_PENDING_READ_MASTER] !==
                    CPP_MODE0_SAME_LINE_WRITE_PENDING_READ_REQ_READY ||
                read_req_accepted[CPP_MODE0_SAME_LINE_WRITE_PENDING_READ_MASTER] !==
                    CPP_MODE0_SAME_LINE_WRITE_PENDING_READ_ACCEPTED_WHILE_WRITE_PENDING ||
                !CPP_MODE0_SAME_LINE_WRITE_PENDING_READ_NO_EXTERNAL_ISSUE_WHILE_WRITE_PENDING ||
                ddr_axi_arvalid || ddr_axi_awvalid || ddr_axi_wvalid ||
                mmio_axi_arvalid || mmio_axi_awvalid || mmio_axi_wvalid) begin
                fail_now("C++ trace same-line pending write read mismatch");
            end
            @(negedge clk);
            read_req_valid[CPP_MODE0_SAME_LINE_WRITE_PENDING_READ_MASTER] = 1'b0;
        end
    endtask

    task issue_mode1_invalidate_all_cache_mmio_read_and_check;
        integer timeout;
        reg accepted_seen;
        begin
            reset_dut();
            enter_mode(MODE_CACHE);
            @(negedge clk);
            read_resp_ready = {NUM_READ_MASTERS{1'b0}};
            ddr_axi_arready = 1'b0;
            mmio_axi_arready = 1'b0;
            invalidate_all_valid = 1'b0;

            read_req_addr[(CPP_MODE1_INVALL_CACHE_MMIO_DDR_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_INVALL_CACHE_MMIO_DDR_REQ_ADDR;
            read_req_total_size[(CPP_MODE1_INVALL_CACHE_MMIO_DDR_MASTER * 8) +: 8] =
                CPP_MODE1_INVALL_CACHE_MMIO_DDR_REQ_SIZE;
            read_req_id[(CPP_MODE1_INVALL_CACHE_MMIO_DDR_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_INVALL_CACHE_MMIO_DDR_REQ_ID;
            read_req_bypass[CPP_MODE1_INVALL_CACHE_MMIO_DDR_MASTER] = 1'b0;
            read_req_valid[CPP_MODE1_INVALL_CACHE_MMIO_DDR_MASTER] = 1'b1;
            timeout = 180;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[CPP_MODE1_INVALL_CACHE_MMIO_DDR_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace invall cache/MMIO cache read accept timeout");
            end
            read_req_valid[CPP_MODE1_INVALL_CACHE_MMIO_DDR_MASTER] = 1'b0;
            @(negedge clk);

            timeout = 240;
            while (!ddr_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace invall cache/MMIO DDR refill AR timeout");
            end
            #1;
            if (ddr_axi_araddr != CPP_MODE1_INVALL_CACHE_MMIO_DDR_ARADDR ||
                ddr_axi_arlen != CPP_MODE1_INVALL_CACHE_MMIO_DDR_ARLEN ||
                ddr_axi_arsize != CPP_MODE1_INVALL_CACHE_MMIO_DDR_ARSIZE ||
                ddr_axi_arburst != CPP_MODE1_INVALL_CACHE_MMIO_DDR_ARBURST ||
                ddr_axi_arid != CPP_MODE1_INVALL_CACHE_MMIO_DDR_ARID ||
                mmio_axi_arvalid) begin
                fail_now("C++ trace invall cache/MMIO DDR refill AR mismatch");
            end
            seen_ddr_arid = ddr_axi_arid;
            ddr_axi_arready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_arready = 1'b0;
            #1;
            if (ddr_axi_arvalid) begin
                fail_now("C++ trace invall cache/MMIO duplicate DDR refill AR");
            end

            read_req_addr[(CPP_MODE1_INVALL_CACHE_MMIO_MMIO_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_INVALL_CACHE_MMIO_MMIO_REQ_ADDR;
            read_req_total_size[(CPP_MODE1_INVALL_CACHE_MMIO_MMIO_MASTER * 8) +: 8] =
                CPP_MODE1_INVALL_CACHE_MMIO_MMIO_REQ_SIZE;
            read_req_id[(CPP_MODE1_INVALL_CACHE_MMIO_MMIO_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_INVALL_CACHE_MMIO_MMIO_REQ_ID;
            read_req_bypass[CPP_MODE1_INVALL_CACHE_MMIO_MMIO_MASTER] = 1'b0;
            read_req_valid[CPP_MODE1_INVALL_CACHE_MMIO_MMIO_MASTER] = 1'b1;
            timeout = 180;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[CPP_MODE1_INVALL_CACHE_MMIO_MMIO_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace invall cache/MMIO MMIO read accept timeout");
            end
            read_req_valid[CPP_MODE1_INVALL_CACHE_MMIO_MMIO_MASTER] = 1'b0;
            @(negedge clk);

            timeout = 160;
            while (!mmio_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace invall cache/MMIO MMIO AR timeout");
            end
            #1;
            if (mmio_axi_araddr != CPP_MODE1_INVALL_CACHE_MMIO_MMIO_ARADDR ||
                mmio_axi_arlen != CPP_MODE1_INVALL_CACHE_MMIO_MMIO_ARLEN ||
                mmio_axi_arsize != CPP_MODE1_INVALL_CACHE_MMIO_MMIO_ARSIZE ||
                mmio_axi_arburst != CPP_MODE1_INVALL_CACHE_MMIO_MMIO_ARBURST ||
                mmio_axi_arid != CPP_MODE1_INVALL_CACHE_MMIO_MMIO_ARID ||
                ddr_axi_arvalid) begin
                fail_now("C++ trace invall cache/MMIO MMIO AR mismatch");
            end
            seen_mmio_arid = mmio_axi_arid;
            mmio_axi_arready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_arready = 1'b0;

            invalidate_all_valid = 1'b1;
            mmio_axi_rid = seen_mmio_arid;
            mmio_axi_rdata = CPP_MODE1_INVALL_CACHE_MMIO_MMIO_RBEAT0[MMIO_DATA_BITS-1:0];
            mmio_axi_rresp = AXI_RESP_OKAY;
            mmio_axi_rlast = 1'b1;
            mmio_axi_rvalid = 1'b1;
            #1;
            if (mmio_axi_rready !== CPP_MODE1_INVALL_CACHE_MMIO_READ_MMIO_RREADY_PENDING ||
                invalidate_all_accepted) begin
                fail_now("C++ trace invall cache/MMIO MMIO R or accept mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_rvalid = 1'b0;
            mmio_axi_rlast = 1'b0;

            timeout = 160;
            while (!read_resp_valid[CPP_MODE1_INVALL_CACHE_MMIO_MMIO_MASTER] &&
                   (timeout > 0)) begin
                #1;
                if (invalidate_all_accepted) begin
                    fail_now("C++ trace invall cache/MMIO accepted before MMIO response");
                end
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0 ||
                read_resp_valid[CPP_MODE1_INVALL_CACHE_MMIO_DDR_MASTER]) begin
                fail_now("C++ trace invall cache/MMIO MMIO response owner mismatch");
            end
            #1;
            if (read_resp_id[(CPP_MODE1_INVALL_CACHE_MMIO_MMIO_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE1_INVALL_CACHE_MMIO_MMIO_RESP_ID ||
                read_resp_data[(CPP_MODE1_INVALL_CACHE_MMIO_MMIO_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    CPP_MODE1_INVALL_CACHE_MMIO_MMIO_RESP_DATA ||
                invalidate_all_accepted !==
                    !CPP_MODE1_INVALL_CACHE_MMIO_READ_BLOCKED_MMIO_HELD) begin
                fail_now("C++ trace invall cache/MMIO MMIO response hold mismatch");
            end

            @(negedge clk);
            ddr_axi_rid = seen_ddr_arid;
            ddr_axi_rdata = CPP_MODE1_INVALL_CACHE_MMIO_DDR_RBEAT0;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b0;
            ddr_axi_rvalid = 1'b1;
            #1;
            if (ddr_axi_rready !== CPP_MODE1_INVALL_CACHE_MMIO_READ_DDR_RREADY_MMIO_HELD ||
                invalidate_all_accepted) begin
                fail_now("C++ trace invall cache/MMIO DDR R beat0 mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;

            ddr_axi_rid = seen_ddr_arid;
            ddr_axi_rdata = CPP_MODE1_INVALL_CACHE_MMIO_DDR_RBEAT1;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b1;
            ddr_axi_rvalid = 1'b1;
            #1;
            if (ddr_axi_rready !== CPP_MODE1_INVALL_CACHE_MMIO_READ_DDR_RREADY_MMIO_HELD ||
                invalidate_all_accepted) begin
                fail_now("C++ trace invall cache/MMIO DDR R beat1 mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;
            ddr_axi_rlast = 1'b0;

            timeout = 240;
            while (!read_resp_valid[CPP_MODE1_INVALL_CACHE_MMIO_DDR_MASTER] &&
                   (timeout > 0)) begin
                #1;
                if (!read_resp_valid[CPP_MODE1_INVALL_CACHE_MMIO_MMIO_MASTER] ||
                    invalidate_all_accepted) begin
                    fail_now("C++ trace invall cache/MMIO response drain ordering mismatch");
                end
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace invall cache/MMIO DDR response timeout");
            end
            #1;
            if (read_resp_id[(CPP_MODE1_INVALL_CACHE_MMIO_DDR_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE1_INVALL_CACHE_MMIO_DDR_RESP_ID ||
                read_resp_data[(CPP_MODE1_INVALL_CACHE_MMIO_DDR_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    CPP_MODE1_INVALL_CACHE_MMIO_DDR_RESP_DATA ||
                invalidate_all_accepted !==
                    !CPP_MODE1_INVALL_CACHE_MMIO_READ_BLOCKED_CACHE_HELD) begin
                fail_now("C++ trace invall cache/MMIO DDR response hold mismatch");
            end

            read_resp_ready[CPP_MODE1_INVALL_CACHE_MMIO_MMIO_MASTER] = 1'b1;
            #1;
            if (invalidate_all_accepted) begin
                fail_now("C++ trace invall cache/MMIO accepted before MMIO retire");
            end
            @(posedge clk);
            @(negedge clk);
            read_resp_ready[CPP_MODE1_INVALL_CACHE_MMIO_MMIO_MASTER] = 1'b0;

            read_resp_ready[CPP_MODE1_INVALL_CACHE_MMIO_DDR_MASTER] = 1'b1;
            #1;
            if (invalidate_all_accepted) begin
                fail_now("C++ trace invall cache/MMIO accepted before cache retire");
            end
            @(posedge clk);
            @(negedge clk);
            read_resp_ready[CPP_MODE1_INVALL_CACHE_MMIO_DDR_MASTER] = 1'b0;

            timeout = 10000;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                #1;
                if (invalidate_all_accepted) begin
                    accepted_seen = 1'b1;
                end
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (accepted_seen !==
                CPP_MODE1_INVALL_CACHE_MMIO_READ_ACCEPTED_AFTER_RETIRE) begin
                fail_now("C++ trace invall cache/MMIO final accept mismatch");
            end
            @(negedge clk);
            invalidate_all_valid = 1'b0;
        end
    endtask

    task issue_mode1_dirty_victim_setup_write_and_check;
        input [31:0] req_addr;
        input [7:0] req_size;
        input [3:0] req_id;
        input [511:0] req_wdata;
        input [63:0] req_wstrb;
        input [3:0] exp_resp_id;
        input [1:0] exp_resp_code;
        integer timeout;
        reg accepted_seen;
        begin
            @(negedge clk);
            write_resp_ready[CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER] = 1'b0;
            write_req_addr[(CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER * ADDR_BITS) +: ADDR_BITS] =
                req_addr;
            write_req_total_size[(CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER * 8) +: 8] =
                req_size;
            write_req_id[(CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER * ID_BITS) +: ID_BITS] =
                req_id;
            write_req_wdata[(CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER * LINE_BITS) +: LINE_BITS] =
                req_wdata;
            write_req_wstrb[(CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER * LINE_BYTES) +: LINE_BYTES] =
                req_wstrb[LINE_BYTES-1:0];
            write_req_bypass[CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER] = 1'b0;
            write_req_valid[CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER] = 1'b1;

            timeout = 200;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                if (ddr_axi_arvalid || ddr_axi_awvalid || ddr_axi_wvalid ||
                    mmio_axi_arvalid || mmio_axi_awvalid || mmio_axi_wvalid) begin
                    fail_now("C++ trace dirty-victim setup escaped to external AXI");
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace dirty-victim setup write accept timeout");
            end
            write_req_valid[CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER] = 1'b0;
            @(negedge clk);

            timeout = 260;
            while (!write_resp_valid[CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (ddr_axi_arvalid || ddr_axi_awvalid || ddr_axi_wvalid ||
                    mmio_axi_arvalid || mmio_axi_awvalid || mmio_axi_wvalid) begin
                    fail_now("C++ trace dirty-victim setup response escaped to external AXI");
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace dirty-victim setup write response timeout");
            end
            #1;
            if (write_resp_id[(CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER * ID_BITS) +: ID_BITS] !=
                    exp_resp_id ||
                write_resp_code[(CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER * 2) +: 2] !=
                    exp_resp_code) begin
                fail_now("C++ trace dirty-victim setup write response mismatch");
            end
            write_resp_ready[CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
            write_resp_ready[CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER] = 1'b0;
        end
    endtask

    task issue_mode1_dirty_victim_mmio_write_and_check;
        integer timeout;
        reg accepted_seen;
        begin
            reset_dut();
            enter_mode(MODE_CACHE);
            issue_mode1_dirty_victim_setup_write_and_check(
                CPP_MODE1_DIRTY_VICTIM_SETUP0_REQ_ADDR,
                CPP_MODE1_DIRTY_VICTIM_SETUP0_REQ_SIZE,
                CPP_MODE1_DIRTY_VICTIM_SETUP0_REQ_ID,
                CPP_MODE1_DIRTY_VICTIM_SETUP0_REQ_WDATA,
                CPP_MODE1_DIRTY_VICTIM_SETUP0_REQ_WSTRB,
                CPP_MODE1_DIRTY_VICTIM_SETUP0_RESP_ID,
                CPP_MODE1_DIRTY_VICTIM_SETUP0_RESP_CODE);
            issue_mode1_dirty_victim_setup_write_and_check(
                CPP_MODE1_DIRTY_VICTIM_SETUP1_REQ_ADDR,
                CPP_MODE1_DIRTY_VICTIM_SETUP1_REQ_SIZE,
                CPP_MODE1_DIRTY_VICTIM_SETUP1_REQ_ID,
                CPP_MODE1_DIRTY_VICTIM_SETUP1_REQ_WDATA,
                CPP_MODE1_DIRTY_VICTIM_SETUP1_REQ_WSTRB,
                CPP_MODE1_DIRTY_VICTIM_SETUP1_RESP_ID,
                CPP_MODE1_DIRTY_VICTIM_SETUP1_RESP_CODE);

            @(negedge clk);
            write_resp_ready = {NUM_WRITE_MASTERS{1'b0}};
            ddr_axi_awready = 1'b0;
            ddr_axi_wready = 1'b0;
            mmio_axi_awready = 1'b0;
            mmio_axi_wready = 1'b0;

            write_req_addr[(CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_DIRTY_VICTIM_CACHE_WRITE_REQ_ADDR;
            write_req_total_size[(CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER * 8) +: 8] =
                CPP_MODE1_DIRTY_VICTIM_CACHE_WRITE_REQ_SIZE;
            write_req_id[(CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_DIRTY_VICTIM_CACHE_WRITE_REQ_ID;
            write_req_wdata[(CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER * LINE_BITS) +: LINE_BITS] =
                CPP_MODE1_DIRTY_VICTIM_CACHE_WRITE_REQ_WDATA;
            write_req_wstrb[(CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER * LINE_BYTES) +: LINE_BYTES] =
                CPP_MODE1_DIRTY_VICTIM_CACHE_WRITE_REQ_WSTRB[LINE_BYTES-1:0];
            write_req_bypass[CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER] = 1'b0;
            write_req_valid[CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER] = 1'b1;

            timeout = 260;
            accepted_seen = 1'b0;
            while (!ddr_axi_awvalid && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace dirty-victim writeback AW timeout");
            end
            if (!accepted_seen && write_req_accepted[CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER]) begin
                accepted_seen = 1'b1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace dirty-victim cache write accept missing");
            end
            #1;
            if (ddr_axi_awaddr != CPP_MODE1_DIRTY_VICTIM_WB_AWADDR ||
                ddr_axi_awlen != CPP_MODE1_DIRTY_VICTIM_WB_AWLEN ||
                ddr_axi_awsize != CPP_MODE1_DIRTY_VICTIM_WB_AWSIZE ||
                ddr_axi_awburst != CPP_MODE1_DIRTY_VICTIM_WB_AWBURST ||
                ddr_axi_awid != CPP_MODE1_DIRTY_VICTIM_WB_AWID ||
                mmio_axi_awvalid) begin
                fail_now("C++ trace dirty-victim writeback AW mismatch");
            end
            seen_ddr_awid = ddr_axi_awid;
            ddr_axi_awready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            write_req_valid[CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER] = 1'b0;
            ddr_axi_awready = 1'b0;

            timeout = 140;
            while (!ddr_axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace dirty-victim writeback W0 timeout");
            end
            #1;
            if (ddr_axi_wdata != CPP_MODE1_DIRTY_VICTIM_WB_WBEAT0 ||
                ddr_axi_wstrb != CPP_MODE1_DIRTY_VICTIM_WB_WSTRB0 ||
                ddr_axi_wlast != CPP_MODE1_DIRTY_VICTIM_WB_WLAST0) begin
                fail_now("C++ trace dirty-victim writeback W0 mismatch");
            end
            ddr_axi_wready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_wready = 1'b0;

            timeout = 140;
            while (!ddr_axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace dirty-victim writeback W1 timeout");
            end
            #1;
            if (ddr_axi_wdata != CPP_MODE1_DIRTY_VICTIM_WB_WBEAT1 ||
                ddr_axi_wstrb != CPP_MODE1_DIRTY_VICTIM_WB_WSTRB1 ||
                ddr_axi_wlast != CPP_MODE1_DIRTY_VICTIM_WB_WLAST1) begin
                fail_now("C++ trace dirty-victim writeback W1 mismatch");
            end
            ddr_axi_wready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_wready = 1'b0;

            write_req_addr[(CPP_MODE1_DIRTY_VICTIM_MMIO_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE1_DIRTY_VICTIM_MMIO_REQ_ADDR;
            write_req_total_size[(CPP_MODE1_DIRTY_VICTIM_MMIO_MASTER * 8) +: 8] =
                CPP_MODE1_DIRTY_VICTIM_MMIO_REQ_SIZE;
            write_req_id[(CPP_MODE1_DIRTY_VICTIM_MMIO_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE1_DIRTY_VICTIM_MMIO_REQ_ID;
            write_req_wdata[(CPP_MODE1_DIRTY_VICTIM_MMIO_MASTER * LINE_BITS) +: LINE_BITS] =
                CPP_MODE1_DIRTY_VICTIM_MMIO_REQ_WDATA;
            write_req_wstrb[(CPP_MODE1_DIRTY_VICTIM_MMIO_MASTER * LINE_BYTES) +: LINE_BYTES] =
                CPP_MODE1_DIRTY_VICTIM_MMIO_REQ_WSTRB[LINE_BYTES-1:0];
            write_req_bypass[CPP_MODE1_DIRTY_VICTIM_MMIO_MASTER] = 1'b0;
            write_req_valid[CPP_MODE1_DIRTY_VICTIM_MMIO_MASTER] = 1'b1;

            timeout = 180;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[CPP_MODE1_DIRTY_VICTIM_MMIO_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace dirty-victim MMIO write accept timeout");
            end
            write_req_valid[CPP_MODE1_DIRTY_VICTIM_MMIO_MASTER] = 1'b0;
            @(negedge clk);

            timeout = 140;
            while (!mmio_axi_awvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace dirty-victim MMIO AW timeout");
            end
            #1;
            if (mmio_axi_awaddr != CPP_MODE1_DIRTY_VICTIM_MMIO_AWADDR ||
                mmio_axi_awlen != CPP_MODE1_DIRTY_VICTIM_MMIO_AWLEN ||
                mmio_axi_awsize != CPP_MODE1_DIRTY_VICTIM_MMIO_AWSIZE ||
                mmio_axi_awburst != CPP_MODE1_DIRTY_VICTIM_MMIO_AWBURST ||
                mmio_axi_awid != CPP_MODE1_DIRTY_VICTIM_MMIO_AWID ||
                ddr_axi_awvalid) begin
                fail_now("C++ trace dirty-victim MMIO AW mismatch");
            end
            seen_mmio_awid = mmio_axi_awid;
            mmio_axi_awready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_awready = 1'b0;

            timeout = 140;
            while (!mmio_axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace dirty-victim MMIO W timeout");
            end
            #1;
            if (mmio_axi_wdata != CPP_MODE1_DIRTY_VICTIM_MMIO_WBEAT0[MMIO_DATA_BITS-1:0] ||
                mmio_axi_wstrb != CPP_MODE1_DIRTY_VICTIM_MMIO_WSTRB0[MMIO_STRB_BITS-1:0] ||
                mmio_axi_wlast != CPP_MODE1_DIRTY_VICTIM_MMIO_WLAST0 ||
                ddr_axi_wvalid) begin
                fail_now("C++ trace dirty-victim MMIO W mismatch");
            end
            mmio_axi_wready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_wready = 1'b0;

            invalidate_all_valid = 1'b1;
            mmio_axi_bid = seen_mmio_awid;
            mmio_axi_bresp = AXI_RESP_OKAY;
            mmio_axi_bvalid = 1'b1;
            #1;
            if (mmio_axi_bready !== CPP_MODE1_DIRTY_VICTIM_MMIO_BREADY_STALLED ||
                invalidate_all_accepted) begin
                fail_now("C++ trace dirty-victim MMIO BREADY mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_bvalid = 1'b0;

            timeout = 160;
            while (!write_resp_valid[CPP_MODE1_DIRTY_VICTIM_MMIO_MASTER] &&
                   (timeout > 0)) begin
                #1;
                if (invalidate_all_accepted) begin
                    fail_now("C++ trace dirty-victim accepted before MMIO response");
                end
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0 ||
                write_resp_valid[CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER]) begin
                fail_now("C++ trace dirty-victim MMIO/cache response owner mismatch");
            end
            #1;
            if (invalidate_all_accepted !==
                    !CPP_MODE1_DIRTY_VICTIM_INVALL_BLOCKED_MMIO_HELD) begin
                fail_now("C++ trace dirty-victim MMIO held invalidate mismatch");
            end

            ddr_axi_bid = seen_ddr_awid;
            ddr_axi_bresp = AXI_RESP_OKAY;
            ddr_axi_bvalid = 1'b1;
            #1;
            if (ddr_axi_bready !== CPP_MODE1_DIRTY_VICTIM_WB_BREADY_STALLED ||
                invalidate_all_accepted) begin
                fail_now("C++ trace dirty-victim DDR BREADY mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_bvalid = 1'b0;

            #1;
            if (write_resp_id[(CPP_MODE1_DIRTY_VICTIM_MMIO_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE1_DIRTY_VICTIM_MMIO_RESP_ID ||
                write_resp_code[(CPP_MODE1_DIRTY_VICTIM_MMIO_MASTER * 2) +: 2] !=
                    CPP_MODE1_DIRTY_VICTIM_MMIO_RESP_CODE ||
                invalidate_all_accepted) begin
                fail_now("C++ trace dirty-victim MMIO response payload mismatch");
            end
            write_resp_ready[CPP_MODE1_DIRTY_VICTIM_MMIO_MASTER] = 1'b1;
            #1;
            if (invalidate_all_accepted) begin
                fail_now("C++ trace dirty-victim accepted before MMIO retire");
            end
            @(posedge clk);
            @(negedge clk);
            write_resp_ready[CPP_MODE1_DIRTY_VICTIM_MMIO_MASTER] = 1'b0;

            timeout = 260;
            while (!write_resp_valid[CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER] &&
                   (timeout > 0)) begin
                #1;
                if (invalidate_all_accepted) begin
                    fail_now("C++ trace dirty-victim accepted before cache response");
                end
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace dirty-victim cache response timeout");
            end
            #1;
            if (write_resp_id[(CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE1_DIRTY_VICTIM_CACHE_WRITE_RESP_ID ||
                write_resp_code[(CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER * 2) +: 2] !=
                    CPP_MODE1_DIRTY_VICTIM_CACHE_WRITE_RESP_CODE ||
                invalidate_all_accepted !==
                    !CPP_MODE1_DIRTY_VICTIM_INVALL_BLOCKED_CACHE_HELD) begin
                fail_now("C++ trace dirty-victim cache response payload mismatch");
            end
            write_resp_ready[CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER] = 1'b1;
            #1;
            if (invalidate_all_accepted) begin
                fail_now("C++ trace dirty-victim accepted before cache retire");
            end
            @(posedge clk);
            @(negedge clk);
            write_resp_ready[CPP_MODE1_DIRTY_VICTIM_CACHE_MASTER] = 1'b0;

            timeout = 32;
            while (timeout > 0) begin
                #1;
                if (invalidate_all_accepted !==
                    CPP_MODE1_DIRTY_VICTIM_INVALL_ACCEPTED_AFTER_RETIRE) begin
                    fail_now("C++ trace dirty-victim final invalidate mismatch");
                end
                @(posedge clk);
                timeout = timeout - 1;
            end
            invalidate_all_valid = 1'b0;
        end
    endtask

    task issue_mode2_mapped_local_write_read_case;
        input integer case_id;
        input integer write_master;
        input integer read_master;
        input [31:0] exp_write_req_addr;
        input [7:0] exp_write_req_size;
        input [3:0] exp_write_req_id;
        input [511:0] exp_write_req_wdata;
        input [63:0] exp_write_req_wstrb;
        input [3:0] exp_write_resp_id;
        input [1:0] exp_write_resp_code;
        input [31:0] exp_read_req_addr;
        input [7:0] exp_read_req_size;
        input [3:0] exp_read_req_id;
        input [3:0] exp_read_resp_id;
        input [2047:0] exp_read_resp_data;
        integer timeout;
        reg accepted_seen;
        begin
            reset_dut();
            enter_mode(MODE_MAPPED);

            @(negedge clk);
            write_resp_ready = {NUM_WRITE_MASTERS{1'b0}};
            write_req_addr[(write_master * ADDR_BITS) +: ADDR_BITS] =
                exp_write_req_addr;
            write_req_total_size[(write_master * 8) +: 8] =
                exp_write_req_size;
            write_req_id[(write_master * ID_BITS) +: ID_BITS] =
                exp_write_req_id;
            write_req_wdata[(write_master * LINE_BITS) +: LINE_BITS] =
                exp_write_req_wdata;
            write_req_wstrb[(write_master * LINE_BYTES) +: LINE_BYTES] =
                exp_write_req_wstrb[LINE_BYTES-1:0];
            write_req_bypass[write_master] = 1'b0;
            write_req_valid[write_master] = 1'b1;

            timeout = 260;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[write_master]) begin
                    accepted_seen = 1'b1;
                end
                if (ddr_axi_arvalid || ddr_axi_awvalid || ddr_axi_wvalid ||
                    mmio_axi_arvalid || mmio_axi_awvalid || mmio_axi_wvalid) begin
                    fail_now("C++ trace mode2 mapped local write escaped to external AXI");
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace mode2 mapped local write accept timeout");
            end
            write_req_valid[write_master] = 1'b0;
            @(negedge clk);

            timeout = 360;
            while (!write_resp_valid[write_master] &&
                   (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (ddr_axi_arvalid || ddr_axi_awvalid || ddr_axi_wvalid ||
                    mmio_axi_arvalid || mmio_axi_awvalid || mmio_axi_wvalid) begin
                    fail_now("C++ trace mode2 mapped local write response escaped to external AXI");
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace mode2 mapped local write response timeout");
            end
            #1;
            if (write_resp_id[(write_master * ID_BITS) +: ID_BITS] !=
                    exp_write_resp_id ||
                write_resp_code[(write_master * 2) +: 2] !=
                    exp_write_resp_code) begin
                fail_now("C++ trace mode2 mapped local write response mismatch");
            end
            write_resp_ready[write_master] = 1'b1;
            @(posedge clk);
            @(negedge clk);
            write_resp_ready[write_master] = 1'b0;

            read_resp_ready = {NUM_READ_MASTERS{1'b0}};
            read_req_addr[(read_master * ADDR_BITS) +: ADDR_BITS] =
                exp_read_req_addr;
            read_req_total_size[(read_master * 8) +: 8] =
                exp_read_req_size;
            read_req_id[(read_master * ID_BITS) +: ID_BITS] =
                exp_read_req_id;
            read_req_bypass[read_master] = 1'b0;
            read_req_valid[read_master] = 1'b1;

            timeout = 260;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[read_master]) begin
                    accepted_seen = 1'b1;
                end
                if (ddr_axi_arvalid || ddr_axi_awvalid || ddr_axi_wvalid ||
                    mmio_axi_arvalid || mmio_axi_awvalid || mmio_axi_wvalid) begin
                    fail_now("C++ trace mode2 mapped local read escaped to external AXI");
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace mode2 mapped local read accept timeout");
            end
            read_req_valid[read_master] = 1'b0;
            @(negedge clk);

            timeout = 360;
            while (!read_resp_valid[read_master] &&
                   (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (ddr_axi_arvalid || ddr_axi_awvalid || ddr_axi_wvalid ||
                    mmio_axi_arvalid || mmio_axi_awvalid || mmio_axi_wvalid) begin
                    fail_now("C++ trace mode2 mapped local read response escaped to external AXI");
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace mode2 mapped local read response timeout");
            end
            #1;
            if (read_resp_id[(read_master * ID_BITS) +: ID_BITS] !=
                    exp_read_resp_id ||
                read_resp_data[(read_master * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    exp_read_resp_data) begin
                fail_now("C++ trace mode2 mapped local read response mismatch");
            end
            read_resp_ready[read_master] = 1'b1;
            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task issue_mode2_mapped_local_write_read_and_check;
        begin
            issue_mode2_mapped_local_write_read_case(
                0,
                CPP_MODE2_MAPPED_LOCAL_WRITE_MASTER,
                CPP_MODE2_MAPPED_LOCAL_READ_MASTER,
                CPP_MODE2_MAPPED_LOCAL_WRITE_REQ_ADDR,
                CPP_MODE2_MAPPED_LOCAL_WRITE_REQ_SIZE,
                CPP_MODE2_MAPPED_LOCAL_WRITE_REQ_ID,
                CPP_MODE2_MAPPED_LOCAL_WRITE_REQ_WDATA,
                CPP_MODE2_MAPPED_LOCAL_WRITE_REQ_WSTRB,
                CPP_MODE2_MAPPED_LOCAL_WRITE_RESP_ID,
                CPP_MODE2_MAPPED_LOCAL_WRITE_RESP_CODE,
                CPP_MODE2_MAPPED_LOCAL_READ_REQ_ADDR,
                CPP_MODE2_MAPPED_LOCAL_READ_REQ_SIZE,
                CPP_MODE2_MAPPED_LOCAL_READ_REQ_ID,
                CPP_MODE2_MAPPED_LOCAL_READ_RESP_ID,
                CPP_MODE2_MAPPED_LOCAL_READ_RESP_DATA);

            issue_mode2_mapped_local_write_read_case(
                1,
                CPP_MODE2_MAPPED_LOW_BOUNDARY_WRITE_MASTER,
                CPP_MODE2_MAPPED_LOW_BOUNDARY_READ_MASTER,
                CPP_MODE2_MAPPED_LOW_BOUNDARY_WRITE_REQ_ADDR,
                CPP_MODE2_MAPPED_LOW_BOUNDARY_WRITE_REQ_SIZE,
                CPP_MODE2_MAPPED_LOW_BOUNDARY_WRITE_REQ_ID,
                CPP_MODE2_MAPPED_LOW_BOUNDARY_WRITE_REQ_WDATA,
                CPP_MODE2_MAPPED_LOW_BOUNDARY_WRITE_REQ_WSTRB,
                CPP_MODE2_MAPPED_LOW_BOUNDARY_WRITE_RESP_ID,
                CPP_MODE2_MAPPED_LOW_BOUNDARY_WRITE_RESP_CODE,
                CPP_MODE2_MAPPED_LOW_BOUNDARY_READ_REQ_ADDR,
                CPP_MODE2_MAPPED_LOW_BOUNDARY_READ_REQ_SIZE,
                CPP_MODE2_MAPPED_LOW_BOUNDARY_READ_REQ_ID,
                CPP_MODE2_MAPPED_LOW_BOUNDARY_READ_RESP_ID,
                CPP_MODE2_MAPPED_LOW_BOUNDARY_READ_RESP_DATA);

            issue_mode2_mapped_local_write_read_case(
                2,
                CPP_MODE2_MAPPED_CONTRACT_LIMIT_WRITE_MASTER,
                CPP_MODE2_MAPPED_CONTRACT_LIMIT_READ_MASTER,
                CPP_MODE2_MAPPED_CONTRACT_LIMIT_WRITE_REQ_ADDR,
                CPP_MODE2_MAPPED_CONTRACT_LIMIT_WRITE_REQ_SIZE,
                CPP_MODE2_MAPPED_CONTRACT_LIMIT_WRITE_REQ_ID,
                CPP_MODE2_MAPPED_CONTRACT_LIMIT_WRITE_REQ_WDATA,
                CPP_MODE2_MAPPED_CONTRACT_LIMIT_WRITE_REQ_WSTRB,
                CPP_MODE2_MAPPED_CONTRACT_LIMIT_WRITE_RESP_ID,
                CPP_MODE2_MAPPED_CONTRACT_LIMIT_WRITE_RESP_CODE,
                CPP_MODE2_MAPPED_CONTRACT_LIMIT_READ_REQ_ADDR,
                CPP_MODE2_MAPPED_CONTRACT_LIMIT_READ_REQ_SIZE,
                CPP_MODE2_MAPPED_CONTRACT_LIMIT_READ_REQ_ID,
                CPP_MODE2_MAPPED_CONTRACT_LIMIT_READ_RESP_ID,
                CPP_MODE2_MAPPED_CONTRACT_LIMIT_READ_RESP_DATA);
        end
    endtask

    task issue_same_master_read_order_and_check;
        integer timeout;
        reg accepted_seen;
        reg [AXI_ID_BITS-1:0] older_arid;
        reg [AXI_ID_BITS-1:0] newer_arid;
        begin
            reset_dut();
            @(negedge clk);
            read_resp_ready = {NUM_READ_MASTERS{1'b0}};
            ddr_axi_arready = 1'b0;

            read_req_addr[(CPP_MODE0_SAME_MASTER_READ0_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE0_SAME_MASTER_READ0_REQ_ADDR;
            read_req_total_size[(CPP_MODE0_SAME_MASTER_READ0_MASTER * 8) +: 8] =
                CPP_MODE0_SAME_MASTER_READ0_REQ_SIZE;
            read_req_id[(CPP_MODE0_SAME_MASTER_READ0_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE0_SAME_MASTER_READ0_REQ_ID;
            read_req_bypass[CPP_MODE0_SAME_MASTER_READ0_MASTER] = 1'b0;
            read_req_valid[CPP_MODE0_SAME_MASTER_READ0_MASTER] = 1'b1;
            timeout = 80;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[CPP_MODE0_SAME_MASTER_READ0_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace same-master older read accept timeout");
            end
            read_req_valid[CPP_MODE0_SAME_MASTER_READ0_MASTER] = 1'b0;
            @(negedge clk);
            timeout = 80;
            while (!ddr_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace same-master older read AR timeout");
            end
            #1;
            if (ddr_axi_araddr != CPP_MODE0_SAME_MASTER_READ0_ARADDR ||
                ddr_axi_arlen != CPP_MODE0_SAME_MASTER_READ0_ARLEN ||
                ddr_axi_arsize != CPP_MODE0_SAME_MASTER_READ0_ARSIZE ||
                ddr_axi_arburst != CPP_MODE0_SAME_MASTER_READ0_ARBURST ||
                ddr_axi_arid != CPP_MODE0_SAME_MASTER_READ0_ARID ||
                mmio_axi_arvalid) begin
                fail_now("C++ trace same-master older read AR mismatch");
            end
            older_arid = ddr_axi_arid;
            ddr_axi_arready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_arready = 1'b0;

            read_req_addr[(CPP_MODE0_SAME_MASTER_READ1_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE0_SAME_MASTER_READ1_REQ_ADDR;
            read_req_total_size[(CPP_MODE0_SAME_MASTER_READ1_MASTER * 8) +: 8] =
                CPP_MODE0_SAME_MASTER_READ1_REQ_SIZE;
            read_req_id[(CPP_MODE0_SAME_MASTER_READ1_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE0_SAME_MASTER_READ1_REQ_ID;
            read_req_bypass[CPP_MODE0_SAME_MASTER_READ1_MASTER] = 1'b0;
            read_req_valid[CPP_MODE0_SAME_MASTER_READ1_MASTER] = 1'b1;
            timeout = 80;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[CPP_MODE0_SAME_MASTER_READ1_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace same-master newer read accept timeout");
            end
            read_req_valid[CPP_MODE0_SAME_MASTER_READ1_MASTER] = 1'b0;
            @(negedge clk);
            timeout = 80;
            while (!ddr_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace same-master newer read AR timeout");
            end
            #1;
            if (ddr_axi_araddr != CPP_MODE0_SAME_MASTER_READ1_ARADDR ||
                ddr_axi_arlen != CPP_MODE0_SAME_MASTER_READ1_ARLEN ||
                ddr_axi_arsize != CPP_MODE0_SAME_MASTER_READ1_ARSIZE ||
                ddr_axi_arburst != CPP_MODE0_SAME_MASTER_READ1_ARBURST ||
                ddr_axi_arid != CPP_MODE0_SAME_MASTER_READ1_ARID ||
                mmio_axi_arvalid) begin
                fail_now("C++ trace same-master newer read AR mismatch");
            end
            newer_arid = ddr_axi_arid;
            if (older_arid == newer_arid) begin
                fail_now("C++ trace same-master reads reused AXI ID");
            end
            ddr_axi_arready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_arready = 1'b0;

            ddr_axi_rid = newer_arid;
            ddr_axi_rdata = CPP_MODE0_SAME_MASTER_READ1_RBEAT0;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b1;
            ddr_axi_rvalid = 1'b1;
            #1;
            if (ddr_axi_rready !== CPP_MODE0_SAME_MASTER_READ1_RREADY_STALLED) begin
                fail_now("C++ trace same-master newer RREADY stalled mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;

            timeout = 80;
            while (!read_resp_valid[CPP_MODE0_SAME_MASTER_READ1_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace same-master newer response timeout");
            end
            #1;
            if (read_resp_id[(CPP_MODE0_SAME_MASTER_READ1_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE0_SAME_MASTER_READ1_RESP_ID ||
                read_resp_data[(CPP_MODE0_SAME_MASTER_READ1_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    CPP_MODE0_SAME_MASTER_READ1_RESP_DATA) begin
                fail_now("C++ trace same-master newer response payload mismatch");
            end

            ddr_axi_rid = older_arid;
            ddr_axi_rdata = CPP_MODE0_SAME_MASTER_READ0_RBEAT0;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b1;
            ddr_axi_rvalid = 1'b1;
            #1;
            if (ddr_axi_rready !== CPP_MODE0_SAME_MASTER_READ0_RREADY_STALLED) begin
                fail_now("C++ trace same-master older RREADY stalled mismatch");
            end
            if (read_resp_id[(CPP_MODE0_SAME_MASTER_READ1_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE0_SAME_MASTER_READ1_RESP_ID ||
                read_resp_data[(CPP_MODE0_SAME_MASTER_READ1_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    CPP_MODE0_SAME_MASTER_READ1_RESP_DATA) begin
                fail_now("C++ trace same-master held response changed before older R edge");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;

            #1;
            if (read_resp_id[(CPP_MODE0_SAME_MASTER_READ1_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE0_SAME_MASTER_READ1_RESP_ID ||
                read_resp_data[(CPP_MODE0_SAME_MASTER_READ1_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    CPP_MODE0_SAME_MASTER_READ1_RESP_DATA) begin
                fail_now("C++ trace same-master held response changed after older R");
            end
            read_resp_ready[CPP_MODE0_SAME_MASTER_READ1_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
            read_resp_ready[CPP_MODE0_SAME_MASTER_READ1_MASTER] = 1'b0;

            timeout = 120;
            while (!read_resp_valid[CPP_MODE0_SAME_MASTER_READ0_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace same-master older response timeout");
            end
            #1;
            if (read_resp_id[(CPP_MODE0_SAME_MASTER_READ0_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE0_SAME_MASTER_READ0_RESP_ID ||
                read_resp_data[(CPP_MODE0_SAME_MASTER_READ0_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    CPP_MODE0_SAME_MASTER_READ0_RESP_DATA) begin
                fail_now("C++ trace same-master older response payload mismatch");
            end
            read_resp_ready[CPP_MODE0_SAME_MASTER_READ0_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task issue_same_master_write_issue_one;
        input integer master;
        input [31:0] req_addr;
        input [7:0] req_size;
        input [3:0] req_id;
        input [511:0] req_wdata;
        input [63:0] req_wstrb;
        input [31:0] exp_awaddr;
        input [7:0] exp_awlen;
        input [2:0] exp_awsize;
        input [1:0] exp_awburst;
        input [5:0] exp_awid;
        input [255:0] exp_wbeat0;
        input [31:0] exp_wstrb0;
        input exp_wlast0;
        output [AXI_ID_BITS-1:0] seen_awid_out;
        integer timeout;
        reg accepted_seen;
        begin
            @(negedge clk);
            ddr_axi_awready = 1'b0;
            ddr_axi_wready = 1'b0;
            write_req_addr[(master * ADDR_BITS) +: ADDR_BITS] = req_addr;
            write_req_total_size[(master * 8) +: 8] = req_size;
            write_req_id[(master * ID_BITS) +: ID_BITS] = req_id;
            write_req_wdata[(master * LINE_BITS) +: LINE_BITS] = req_wdata;
            write_req_wstrb[(master * LINE_BYTES) +: LINE_BYTES] = req_wstrb[LINE_BYTES-1:0];
            write_req_bypass[master] = 1'b0;
            write_req_valid[master] = 1'b1;
            timeout = 80;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[master]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace same-master write accept timeout");
            end
            write_req_valid[master] = 1'b0;
            write_req_bypass[master] = 1'b0;

            @(negedge clk);
            timeout = 80;
            while (!ddr_axi_awvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace same-master write AW timeout");
            end
            #1;
            if (ddr_axi_awaddr != exp_awaddr ||
                ddr_axi_awlen != exp_awlen ||
                ddr_axi_awsize != exp_awsize ||
                ddr_axi_awburst != exp_awburst ||
                ddr_axi_awid != exp_awid ||
                mmio_axi_awvalid) begin
                fail_now("C++ trace same-master write AW mismatch");
            end
            seen_awid_out = ddr_axi_awid;
            ddr_axi_awready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_awready = 1'b0;

            timeout = 80;
            while (!ddr_axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace same-master write W timeout");
            end
            #1;
            if (ddr_axi_wdata != exp_wbeat0 ||
                ddr_axi_wstrb != exp_wstrb0 ||
                ddr_axi_wlast != exp_wlast0 ||
                mmio_axi_wvalid) begin
                fail_now("C++ trace same-master write W mismatch");
            end
            ddr_axi_wready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_wready = 1'b0;
        end
    endtask

    task issue_same_master_write_order_and_check;
        integer timeout;
        reg [AXI_ID_BITS-1:0] older_awid;
        reg [AXI_ID_BITS-1:0] newer_awid;
        begin
            reset_dut();
            write_resp_ready = {NUM_WRITE_MASTERS{1'b0}};
            issue_same_master_write_issue_one(
                CPP_MODE0_SAME_MASTER_WRITE0_MASTER,
                CPP_MODE0_SAME_MASTER_WRITE0_REQ_ADDR,
                CPP_MODE0_SAME_MASTER_WRITE0_REQ_SIZE,
                CPP_MODE0_SAME_MASTER_WRITE0_REQ_ID,
                CPP_MODE0_SAME_MASTER_WRITE0_REQ_WDATA,
                CPP_MODE0_SAME_MASTER_WRITE0_REQ_WSTRB,
                CPP_MODE0_SAME_MASTER_WRITE0_AWADDR,
                CPP_MODE0_SAME_MASTER_WRITE0_AWLEN,
                CPP_MODE0_SAME_MASTER_WRITE0_AWSIZE,
                CPP_MODE0_SAME_MASTER_WRITE0_AWBURST,
                CPP_MODE0_SAME_MASTER_WRITE0_AWID,
                CPP_MODE0_SAME_MASTER_WRITE0_WBEAT0,
                CPP_MODE0_SAME_MASTER_WRITE0_WSTRB0,
                CPP_MODE0_SAME_MASTER_WRITE0_WLAST0,
                older_awid);
            issue_same_master_write_issue_one(
                CPP_MODE0_SAME_MASTER_WRITE1_MASTER,
                CPP_MODE0_SAME_MASTER_WRITE1_REQ_ADDR,
                CPP_MODE0_SAME_MASTER_WRITE1_REQ_SIZE,
                CPP_MODE0_SAME_MASTER_WRITE1_REQ_ID,
                CPP_MODE0_SAME_MASTER_WRITE1_REQ_WDATA,
                CPP_MODE0_SAME_MASTER_WRITE1_REQ_WSTRB,
                CPP_MODE0_SAME_MASTER_WRITE1_AWADDR,
                CPP_MODE0_SAME_MASTER_WRITE1_AWLEN,
                CPP_MODE0_SAME_MASTER_WRITE1_AWSIZE,
                CPP_MODE0_SAME_MASTER_WRITE1_AWBURST,
                CPP_MODE0_SAME_MASTER_WRITE1_AWID,
                CPP_MODE0_SAME_MASTER_WRITE1_WBEAT0,
                CPP_MODE0_SAME_MASTER_WRITE1_WSTRB0,
                CPP_MODE0_SAME_MASTER_WRITE1_WLAST0,
                newer_awid);
            if (older_awid == newer_awid) begin
                fail_now("C++ trace same-master writes reused AXI ID");
            end

            ddr_axi_bid = newer_awid;
            ddr_axi_bresp = AXI_RESP_OKAY;
            ddr_axi_bvalid = 1'b1;
            #1;
            if (ddr_axi_bready !== CPP_MODE0_SAME_MASTER_WRITE1_BREADY_STALLED) begin
                fail_now("C++ trace same-master newer BREADY stalled mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_bvalid = 1'b0;

            timeout = 80;
            while (!write_resp_valid[CPP_MODE0_SAME_MASTER_WRITE1_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace same-master newer write response timeout");
            end
            #1;
            if (write_resp_id[(CPP_MODE0_SAME_MASTER_WRITE1_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE0_SAME_MASTER_WRITE1_RESP_ID ||
                write_resp_code[(CPP_MODE0_SAME_MASTER_WRITE1_MASTER * 2) +: 2] !=
                    CPP_MODE0_SAME_MASTER_WRITE1_RESP_CODE) begin
                fail_now("C++ trace same-master newer write response payload mismatch");
            end

            ddr_axi_bid = older_awid;
            ddr_axi_bresp = AXI_RESP_OKAY;
            ddr_axi_bvalid = 1'b1;
            #1;
            if (ddr_axi_bready !== CPP_MODE0_SAME_MASTER_WRITE0_BREADY_STALLED) begin
                fail_now("C++ trace same-master older BREADY stalled mismatch");
            end
            if (write_resp_id[(CPP_MODE0_SAME_MASTER_WRITE1_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE0_SAME_MASTER_WRITE1_RESP_ID ||
                write_resp_code[(CPP_MODE0_SAME_MASTER_WRITE1_MASTER * 2) +: 2] !=
                    CPP_MODE0_SAME_MASTER_WRITE1_RESP_CODE) begin
                fail_now("C++ trace same-master held write response changed before older B edge");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_bvalid = 1'b0;

            #1;
            if (write_resp_id[(CPP_MODE0_SAME_MASTER_WRITE1_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE0_SAME_MASTER_WRITE1_RESP_ID ||
                write_resp_code[(CPP_MODE0_SAME_MASTER_WRITE1_MASTER * 2) +: 2] !=
                    CPP_MODE0_SAME_MASTER_WRITE1_RESP_CODE) begin
                fail_now("C++ trace same-master held write response changed after older B");
            end
            write_resp_ready[CPP_MODE0_SAME_MASTER_WRITE1_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
            write_resp_ready[CPP_MODE0_SAME_MASTER_WRITE1_MASTER] = 1'b0;

            timeout = 120;
            while (!write_resp_valid[CPP_MODE0_SAME_MASTER_WRITE0_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace same-master older write response timeout");
            end
            #1;
            if (write_resp_id[(CPP_MODE0_SAME_MASTER_WRITE0_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE0_SAME_MASTER_WRITE0_RESP_ID ||
                write_resp_code[(CPP_MODE0_SAME_MASTER_WRITE0_MASTER * 2) +: 2] !=
                    CPP_MODE0_SAME_MASTER_WRITE0_RESP_CODE) begin
                fail_now("C++ trace same-master older write response payload mismatch");
            end
            write_resp_ready[CPP_MODE0_SAME_MASTER_WRITE0_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
            write_resp_ready[CPP_MODE0_SAME_MASTER_WRITE0_MASTER] = 1'b0;
        end
    endtask

    task issue_read_reuse_and_check;
        integer timeout;
        reg accepted_seen;
        reg [AXI_ID_BITS-1:0] first_arid;
        begin
            reset_dut();
            @(negedge clk);
            read_resp_ready = {NUM_READ_MASTERS{1'b0}};
            ddr_axi_arready = 1'b0;

            read_req_addr[(CPP_MODE0_READ_REUSE0_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE0_READ_REUSE0_REQ_ADDR;
            read_req_total_size[(CPP_MODE0_READ_REUSE0_MASTER * 8) +: 8] =
                CPP_MODE0_READ_REUSE0_REQ_SIZE;
            read_req_id[(CPP_MODE0_READ_REUSE0_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE0_READ_REUSE0_REQ_ID;
            read_req_valid[CPP_MODE0_READ_REUSE0_MASTER] = 1'b1;
            timeout = 80;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[CPP_MODE0_READ_REUSE0_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace read-reuse first accept timeout");
            end
            read_req_valid[CPP_MODE0_READ_REUSE0_MASTER] = 1'b0;
            @(negedge clk);
            timeout = 80;
            while (!ddr_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace read-reuse first AR timeout");
            end
            #1;
            if (ddr_axi_araddr != CPP_MODE0_READ_REUSE0_ARADDR ||
                ddr_axi_arlen != CPP_MODE0_READ_REUSE0_ARLEN ||
                ddr_axi_arsize != CPP_MODE0_READ_REUSE0_ARSIZE ||
                ddr_axi_arburst != CPP_MODE0_READ_REUSE0_ARBURST ||
                ddr_axi_arid != CPP_MODE0_READ_REUSE0_ARID ||
                mmio_axi_arvalid) begin
                fail_now("C++ trace read-reuse first AR mismatch");
            end
            first_arid = ddr_axi_arid;
            ddr_axi_arready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_arready = 1'b0;

            ddr_axi_rid = first_arid;
            ddr_axi_rdata = CPP_MODE0_READ_REUSE0_RBEAT0;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b1;
            ddr_axi_rvalid = 1'b1;
            #1;
            if (ddr_axi_rready !== CPP_MODE0_READ_REUSE0_RREADY) begin
                fail_now("C++ trace read-reuse first RREADY mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;

            timeout = 120;
            while (!read_resp_valid[CPP_MODE0_READ_REUSE0_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace read-reuse first response timeout");
            end
            #1;
            if (read_resp_id[(CPP_MODE0_READ_REUSE0_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE0_READ_REUSE0_RESP_ID ||
                read_resp_data[(CPP_MODE0_READ_REUSE0_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    CPP_MODE0_READ_REUSE0_RESP_DATA) begin
                fail_now("C++ trace read-reuse first response mismatch");
            end
            read_resp_ready[CPP_MODE0_READ_REUSE0_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
            read_resp_ready[CPP_MODE0_READ_REUSE0_MASTER] = 1'b0;

            read_req_addr[(CPP_MODE0_READ_REUSE1_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE0_READ_REUSE1_REQ_ADDR;
            read_req_total_size[(CPP_MODE0_READ_REUSE1_MASTER * 8) +: 8] =
                CPP_MODE0_READ_REUSE1_REQ_SIZE;
            read_req_id[(CPP_MODE0_READ_REUSE1_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE0_READ_REUSE1_REQ_ID;
            read_req_valid[CPP_MODE0_READ_REUSE1_MASTER] = 1'b1;
            timeout = 80;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[CPP_MODE0_READ_REUSE1_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace read-reuse second accept timeout");
            end
            read_req_valid[CPP_MODE0_READ_REUSE1_MASTER] = 1'b0;
            @(negedge clk);
            timeout = 80;
            while (!ddr_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace read-reuse second AR timeout");
            end
            #1;
            if (ddr_axi_araddr != CPP_MODE0_READ_REUSE1_ARADDR ||
                ddr_axi_arlen != CPP_MODE0_READ_REUSE1_ARLEN ||
                ddr_axi_arsize != CPP_MODE0_READ_REUSE1_ARSIZE ||
                ddr_axi_arburst != CPP_MODE0_READ_REUSE1_ARBURST ||
                ddr_axi_arid != CPP_MODE0_READ_REUSE1_ARID ||
                ddr_axi_arid != first_arid ||
                mmio_axi_arvalid) begin
                fail_now("C++ trace read-reuse second AR/reused ID mismatch");
            end
            ddr_axi_arready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_arready = 1'b0;

            ddr_axi_rid = ddr_axi_arid;
            ddr_axi_rdata = CPP_MODE0_READ_REUSE1_RBEAT0;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b1;
            ddr_axi_rvalid = 1'b1;
            #1;
            if (ddr_axi_rready !== CPP_MODE0_READ_REUSE1_RREADY) begin
                fail_now("C++ trace read-reuse second RREADY mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;

            timeout = 120;
            while (!read_resp_valid[CPP_MODE0_READ_REUSE1_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace read-reuse second response timeout");
            end
            #1;
            if (read_resp_id[(CPP_MODE0_READ_REUSE1_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE0_READ_REUSE1_RESP_ID ||
                read_resp_data[(CPP_MODE0_READ_REUSE1_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    CPP_MODE0_READ_REUSE1_RESP_DATA) begin
                fail_now("C++ trace read-reuse second response mismatch");
            end
            read_resp_ready[CPP_MODE0_READ_REUSE1_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task issue_read_budget_release_and_check;
        integer timeout;
        integer fill_idx;
        integer fill_master;
        reg [31:0] fill_addr;
        reg [ID_BITS-1:0] fill_id;
        reg accepted_seen;
        begin
            reset_dut();
            @(negedge clk);
            read_resp_ready = {NUM_READ_MASTERS{1'b0}};
            ddr_axi_arready = 1'b1;

            for (fill_idx = 0; fill_idx < CPP_MODE0_READ_BUDGET_LIMIT;
                 fill_idx = fill_idx + 1) begin
                fill_master = fill_idx % NUM_READ_MASTERS;
                fill_addr = CPP_MODE0_READ_BUDGET_FILL_BASE +
                            (fill_idx * CPP_MODE0_READ_BUDGET_FILL_STRIDE);
                fill_id = fill_idx / NUM_READ_MASTERS;
                @(negedge clk);
                read_req_addr[(fill_master * ADDR_BITS) +: ADDR_BITS] = fill_addr;
                read_req_total_size[(fill_master * 8) +: 8] =
                    CPP_MODE0_READ_BUDGET_FILL_REQ_SIZE;
                read_req_id[(fill_master * ID_BITS) +: ID_BITS] = fill_id;
                read_req_bypass[fill_master] = 1'b0;
                read_req_valid[fill_master] = 1'b1;
                timeout = 120;
                accepted_seen = 1'b0;
                while (!accepted_seen && (timeout > 0)) begin
                    @(posedge clk);
                    #1;
                    if (read_req_accepted[fill_master]) begin
                        accepted_seen = 1'b1;
                    end
                    timeout = timeout - 1;
                end
                if (!accepted_seen) begin
                    fail_now("C++ trace read-budget fill accept timeout");
                end
                read_req_valid[fill_master] = 1'b0;
                read_req_bypass[fill_master] = 1'b0;
            end

            clear_read_inputs();
            repeat (2) begin
                @(posedge clk);
                @(negedge clk);
            end

            @(negedge clk);
            read_req_addr[(CPP_MODE0_READ_BUDGET_BLOCKED_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE0_READ_BUDGET_BLOCKED_ADDR;
            read_req_total_size[(CPP_MODE0_READ_BUDGET_BLOCKED_MASTER * 8) +: 8] =
                CPP_MODE0_READ_BUDGET_FILL_REQ_SIZE;
            read_req_id[(CPP_MODE0_READ_BUDGET_BLOCKED_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE0_READ_BUDGET_BLOCKED_ID;
            read_req_bypass[CPP_MODE0_READ_BUDGET_BLOCKED_MASTER] = 1'b0;
            read_req_valid[CPP_MODE0_READ_BUDGET_BLOCKED_MASTER] = 1'b1;
            repeat (4) begin
                #1;
                if (read_req_ready[CPP_MODE0_READ_BUDGET_BLOCKED_MASTER] !==
                    CPP_MODE0_READ_BUDGET_BLOCKED_READY) begin
                    fail_now("C++ trace read-budget blocked ready mismatch");
                end
                if (read_req_accepted[CPP_MODE0_READ_BUDGET_BLOCKED_MASTER] ||
                    ddr_axi_arvalid || mmio_axi_arvalid) begin
                    fail_now("C++ trace read-budget blocked request escaped");
                end
                @(posedge clk);
                @(negedge clk);
            end
            read_req_valid[CPP_MODE0_READ_BUDGET_BLOCKED_MASTER] = 1'b0;
            read_req_bypass[CPP_MODE0_READ_BUDGET_BLOCKED_MASTER] = 1'b0;

            ddr_axi_rid = CPP_MODE0_READ_BUDGET_RELEASE_ARID;
            ddr_axi_rdata = CPP_MODE0_READ_BUDGET_RELEASE_RBEAT0;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b1;
            ddr_axi_rvalid = 1'b1;
            #1;
            if (ddr_axi_rready !== CPP_MODE0_READ_BUDGET_RELEASE_RREADY) begin
                fail_now("C++ trace read-budget release RREADY mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;
            ddr_axi_rlast = 1'b0;

            timeout = 120;
            while (!read_resp_valid[CPP_MODE0_READ_BUDGET_RELEASE_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace read-budget release response timeout");
            end
            #1;
            if (read_resp_id[(CPP_MODE0_READ_BUDGET_RELEASE_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE0_READ_BUDGET_RELEASE_RESP_ID ||
                read_resp_data[(CPP_MODE0_READ_BUDGET_RELEASE_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    CPP_MODE0_READ_BUDGET_RELEASE_RESP_DATA) begin
                fail_now("C++ trace read-budget release response mismatch");
            end
            read_resp_ready[CPP_MODE0_READ_BUDGET_RELEASE_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
            read_resp_ready[CPP_MODE0_READ_BUDGET_RELEASE_MASTER] = 1'b0;

            ddr_axi_arready = 1'b0;
            read_req_addr[(CPP_MODE0_READ_BUDGET_AFTER_RELEASE_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE0_READ_BUDGET_AFTER_RELEASE_REQ_ADDR;
            read_req_total_size[(CPP_MODE0_READ_BUDGET_AFTER_RELEASE_MASTER * 8) +: 8] =
                CPP_MODE0_READ_BUDGET_AFTER_RELEASE_REQ_SIZE;
            read_req_id[(CPP_MODE0_READ_BUDGET_AFTER_RELEASE_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE0_READ_BUDGET_AFTER_RELEASE_REQ_ID;
            read_req_bypass[CPP_MODE0_READ_BUDGET_AFTER_RELEASE_MASTER] = 1'b0;
            read_req_valid[CPP_MODE0_READ_BUDGET_AFTER_RELEASE_MASTER] = 1'b1;
            timeout = 120;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (read_req_accepted[CPP_MODE0_READ_BUDGET_AFTER_RELEASE_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace read-budget after-release accept timeout");
            end
            read_req_valid[CPP_MODE0_READ_BUDGET_AFTER_RELEASE_MASTER] = 1'b0;
            read_req_bypass[CPP_MODE0_READ_BUDGET_AFTER_RELEASE_MASTER] = 1'b0;

            timeout = 80;
            while (!ddr_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace read-budget after-release AR timeout");
            end
            #1;
            if (ddr_axi_araddr != CPP_MODE0_READ_BUDGET_AFTER_RELEASE_ARADDR ||
                ddr_axi_arlen != CPP_MODE0_READ_BUDGET_AFTER_RELEASE_ARLEN ||
                ddr_axi_arsize != CPP_MODE0_READ_BUDGET_AFTER_RELEASE_ARSIZE ||
                ddr_axi_arburst != CPP_MODE0_READ_BUDGET_AFTER_RELEASE_ARBURST ||
                ddr_axi_arid != CPP_MODE0_READ_BUDGET_AFTER_RELEASE_ARID ||
                ddr_axi_arid != CPP_MODE0_READ_BUDGET_RELEASE_ARID ||
                mmio_axi_arvalid) begin
                fail_now("C++ trace read-budget after-release AR mismatch");
            end
            ddr_axi_arready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_arready = 1'b0;

            ddr_axi_rid = CPP_MODE0_READ_BUDGET_AFTER_RELEASE_ARID;
            ddr_axi_rdata = CPP_MODE0_READ_BUDGET_AFTER_RELEASE_RBEAT0;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b1;
            ddr_axi_rvalid = 1'b1;
            #1;
            if (!ddr_axi_rready) begin
                fail_now("C++ trace read-budget after-release R was backpressured");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_rvalid = 1'b0;

            timeout = 120;
            while (!read_resp_valid[CPP_MODE0_READ_BUDGET_AFTER_RELEASE_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace read-budget after-release response timeout");
            end
            #1;
            if (read_resp_id[(CPP_MODE0_READ_BUDGET_AFTER_RELEASE_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE0_READ_BUDGET_AFTER_RELEASE_RESP_ID ||
                read_resp_data[(CPP_MODE0_READ_BUDGET_AFTER_RELEASE_MASTER * READ_RESP_BITS) +: READ_RESP_BITS] !=
                    CPP_MODE0_READ_BUDGET_AFTER_RELEASE_RESP_DATA) begin
                fail_now("C++ trace read-budget after-release response mismatch");
            end
            read_resp_ready[CPP_MODE0_READ_BUDGET_AFTER_RELEASE_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task issue_write_reuse_one;
        input integer master;
        input [31:0] req_addr;
        input [7:0] req_size;
        input [3:0] req_id;
        input [511:0] req_wdata;
        input [63:0] req_wstrb;
        input [31:0] exp_awaddr;
        input [7:0] exp_awlen;
        input [2:0] exp_awsize;
        input [1:0] exp_awburst;
        input [5:0] exp_awid;
        input [255:0] exp_wbeat0;
        input [31:0] exp_wstrb0;
        input exp_wlast0;
        input exp_bready;
        input [3:0] exp_resp_id;
        input [1:0] exp_resp_code;
        output [AXI_ID_BITS-1:0] seen_awid_out;
        integer timeout;
        reg accepted_seen;
        begin
            @(negedge clk);
            ddr_axi_awready = 1'b0;
            ddr_axi_wready = 1'b0;
            write_req_addr[(master * ADDR_BITS) +: ADDR_BITS] = req_addr;
            write_req_total_size[(master * 8) +: 8] = req_size;
            write_req_id[(master * ID_BITS) +: ID_BITS] = req_id;
            write_req_wdata[(master * LINE_BITS) +: LINE_BITS] = req_wdata;
            write_req_wstrb[(master * LINE_BYTES) +: LINE_BYTES] = req_wstrb[LINE_BYTES-1:0];
            write_req_bypass[master] = 1'b0;
            write_req_valid[master] = 1'b1;
            timeout = 80;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[master]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace write-reuse accept timeout");
            end
            write_req_valid[master] = 1'b0;
            write_req_bypass[master] = 1'b0;

            @(negedge clk);
            timeout = 80;
            while (!ddr_axi_awvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace write-reuse AW timeout");
            end
            #1;
            if (ddr_axi_awaddr != exp_awaddr ||
                ddr_axi_awlen != exp_awlen ||
                ddr_axi_awsize != exp_awsize ||
                ddr_axi_awburst != exp_awburst ||
                ddr_axi_awid != exp_awid ||
                mmio_axi_awvalid) begin
                fail_now("C++ trace write-reuse AW mismatch");
            end
            seen_awid_out = ddr_axi_awid;
            ddr_axi_awready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_awready = 1'b0;

            timeout = 80;
            while (!ddr_axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace write-reuse W timeout");
            end
            #1;
            if (ddr_axi_wdata != exp_wbeat0 ||
                ddr_axi_wstrb != exp_wstrb0 ||
                ddr_axi_wlast != exp_wlast0 ||
                mmio_axi_wvalid) begin
                fail_now("C++ trace write-reuse W mismatch");
            end
            ddr_axi_wready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_wready = 1'b0;

            ddr_axi_bid = seen_awid_out;
            ddr_axi_bresp = AXI_RESP_OKAY;
            ddr_axi_bvalid = 1'b1;
            #1;
            if (ddr_axi_bready !== exp_bready) begin
                fail_now("C++ trace write-reuse BREADY mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_bvalid = 1'b0;

            timeout = 120;
            while (!write_resp_valid[master] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace write-reuse response timeout");
            end
            #1;
            if (write_resp_id[(master * ID_BITS) +: ID_BITS] != exp_resp_id ||
                write_resp_code[(master * 2) +: 2] != exp_resp_code) begin
                fail_now("C++ trace write-reuse response mismatch");
            end
            write_resp_ready[master] = 1'b1;
            @(posedge clk);
            @(negedge clk);
            write_resp_ready[master] = 1'b0;
        end
    endtask

    task issue_write_reuse_and_check;
        reg [AXI_ID_BITS-1:0] first_awid;
        reg [AXI_ID_BITS-1:0] second_awid;
        begin
            reset_dut();
            write_resp_ready = {NUM_WRITE_MASTERS{1'b0}};
            issue_write_reuse_one(CPP_MODE0_WRITE_REUSE0_MASTER,
                                  CPP_MODE0_WRITE_REUSE0_REQ_ADDR,
                                  CPP_MODE0_WRITE_REUSE0_REQ_SIZE,
                                  CPP_MODE0_WRITE_REUSE0_REQ_ID,
                                  CPP_MODE0_WRITE_REUSE0_REQ_WDATA,
                                  CPP_MODE0_WRITE_REUSE0_REQ_WSTRB,
                                  CPP_MODE0_WRITE_REUSE0_AWADDR,
                                  CPP_MODE0_WRITE_REUSE0_AWLEN,
                                  CPP_MODE0_WRITE_REUSE0_AWSIZE,
                                  CPP_MODE0_WRITE_REUSE0_AWBURST,
                                  CPP_MODE0_WRITE_REUSE0_AWID,
                                  CPP_MODE0_WRITE_REUSE0_WBEAT0,
                                  CPP_MODE0_WRITE_REUSE0_WSTRB0,
                                  CPP_MODE0_WRITE_REUSE0_WLAST0,
                                  CPP_MODE0_WRITE_REUSE0_BREADY,
                                  CPP_MODE0_WRITE_REUSE0_RESP_ID,
                                  CPP_MODE0_WRITE_REUSE0_RESP_CODE,
                                  first_awid);
            issue_write_reuse_one(CPP_MODE0_WRITE_REUSE1_MASTER,
                                  CPP_MODE0_WRITE_REUSE1_REQ_ADDR,
                                  CPP_MODE0_WRITE_REUSE1_REQ_SIZE,
                                  CPP_MODE0_WRITE_REUSE1_REQ_ID,
                                  CPP_MODE0_WRITE_REUSE1_REQ_WDATA,
                                  CPP_MODE0_WRITE_REUSE1_REQ_WSTRB,
                                  CPP_MODE0_WRITE_REUSE1_AWADDR,
                                  CPP_MODE0_WRITE_REUSE1_AWLEN,
                                  CPP_MODE0_WRITE_REUSE1_AWSIZE,
                                  CPP_MODE0_WRITE_REUSE1_AWBURST,
                                  CPP_MODE0_WRITE_REUSE1_AWID,
                                  CPP_MODE0_WRITE_REUSE1_WBEAT0,
                                  CPP_MODE0_WRITE_REUSE1_WSTRB0,
                                  CPP_MODE0_WRITE_REUSE1_WLAST0,
                                  CPP_MODE0_WRITE_REUSE1_BREADY,
                                  CPP_MODE0_WRITE_REUSE1_RESP_ID,
                                  CPP_MODE0_WRITE_REUSE1_RESP_CODE,
                                  second_awid);
            if (second_awid != first_awid) begin
                fail_now("C++ trace write-reuse did not reuse released AWID");
            end
        end
    endtask

    task issue_write_budget_release_and_check;
        integer timeout;
        integer fill_idx;
        integer fill_master;
        reg [31:0] fill_addr;
        reg [ID_BITS-1:0] fill_id;
        reg [LINE_BITS-1:0] fill_wdata;
        reg accepted_seen;
        begin
            reset_dut();
            @(negedge clk);
            write_resp_ready = {NUM_WRITE_MASTERS{1'b0}};
            ddr_axi_awready = 1'b1;
            ddr_axi_wready = 1'b1;

            for (fill_idx = 0; fill_idx < CPP_MODE0_WRITE_BUDGET_LIMIT;
                 fill_idx = fill_idx + 1) begin
                fill_master = fill_idx % NUM_WRITE_MASTERS;
                fill_addr = CPP_MODE0_WRITE_BUDGET_FILL_BASE +
                            (fill_idx * CPP_MODE0_WRITE_BUDGET_FILL_STRIDE);
                fill_id = fill_idx / NUM_WRITE_MASTERS;
                fill_wdata = {LINE_BITS{1'b0}};
                fill_wdata[31:0] = 32'h88000000 + fill_idx;

                @(negedge clk);
                write_req_addr[(fill_master * ADDR_BITS) +: ADDR_BITS] = fill_addr;
                write_req_total_size[(fill_master * 8) +: 8] =
                    CPP_MODE0_WRITE_BUDGET_FILL_REQ_SIZE;
                write_req_id[(fill_master * ID_BITS) +: ID_BITS] = fill_id;
                write_req_wdata[(fill_master * LINE_BITS) +: LINE_BITS] = fill_wdata;
                write_req_wstrb[(fill_master * LINE_BYTES) +: LINE_BYTES] =
                    {{(LINE_BYTES-4){1'b0}}, 4'hf};
                write_req_bypass[fill_master] = 1'b0;
                write_req_valid[fill_master] = 1'b1;
                timeout = 120;
                accepted_seen = 1'b0;
                while (!accepted_seen && (timeout > 0)) begin
                    @(posedge clk);
                    #1;
                    if (write_req_accepted[fill_master]) begin
                        accepted_seen = 1'b1;
                    end
                    timeout = timeout - 1;
                end
                if (!accepted_seen) begin
                    fail_now("C++ trace write-budget fill accept timeout");
                end
                write_req_valid[fill_master] = 1'b0;
                write_req_bypass[fill_master] = 1'b0;

                @(posedge clk);
                @(negedge clk);
            end

            clear_write_inputs();
            repeat (8) begin
                @(posedge clk);
                @(negedge clk);
            end

            @(negedge clk);
            write_req_addr[(CPP_MODE0_WRITE_BUDGET_BLOCKED_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE0_WRITE_BUDGET_BLOCKED_ADDR;
            write_req_total_size[(CPP_MODE0_WRITE_BUDGET_BLOCKED_MASTER * 8) +: 8] =
                CPP_MODE0_WRITE_BUDGET_FILL_REQ_SIZE;
            write_req_id[(CPP_MODE0_WRITE_BUDGET_BLOCKED_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE0_WRITE_BUDGET_BLOCKED_ID;
            write_req_wdata[(CPP_MODE0_WRITE_BUDGET_BLOCKED_MASTER * LINE_BITS) +: LINE_BITS] =
                CPP_MODE0_WRITE_BUDGET_BLOCKED_WDATA;
            write_req_wstrb[(CPP_MODE0_WRITE_BUDGET_BLOCKED_MASTER * LINE_BYTES) +: LINE_BYTES] =
                CPP_MODE0_WRITE_BUDGET_BLOCKED_WSTRB[LINE_BYTES-1:0];
            write_req_bypass[CPP_MODE0_WRITE_BUDGET_BLOCKED_MASTER] = 1'b0;
            write_req_valid[CPP_MODE0_WRITE_BUDGET_BLOCKED_MASTER] = 1'b1;
            repeat (4) begin
                #1;
                if (write_req_ready[CPP_MODE0_WRITE_BUDGET_BLOCKED_MASTER] !==
                    CPP_MODE0_WRITE_BUDGET_BLOCKED_READY) begin
                    fail_now("C++ trace write-budget blocked ready mismatch");
                end
                if (write_req_accepted[CPP_MODE0_WRITE_BUDGET_BLOCKED_MASTER] ||
                    ddr_axi_awvalid || mmio_axi_awvalid ||
                    ddr_axi_wvalid || mmio_axi_wvalid) begin
                    fail_now("C++ trace write-budget blocked request escaped");
                end
                @(posedge clk);
                @(negedge clk);
            end
            write_req_valid[CPP_MODE0_WRITE_BUDGET_BLOCKED_MASTER] = 1'b0;
            write_req_bypass[CPP_MODE0_WRITE_BUDGET_BLOCKED_MASTER] = 1'b0;

            ddr_axi_bid = CPP_MODE0_WRITE_BUDGET_RELEASE_AWID;
            ddr_axi_bresp = AXI_RESP_OKAY;
            ddr_axi_bvalid = 1'b1;
            #1;
            if (ddr_axi_bready !== CPP_MODE0_WRITE_BUDGET_RELEASE_BREADY) begin
                fail_now("C++ trace write-budget release BREADY mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_bvalid = 1'b0;

            timeout = 120;
            while (!write_resp_valid[CPP_MODE0_WRITE_BUDGET_RELEASE_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace write-budget release response timeout");
            end
            #1;
            if (write_resp_id[(CPP_MODE0_WRITE_BUDGET_RELEASE_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE0_WRITE_BUDGET_RELEASE_RESP_ID ||
                write_resp_code[(CPP_MODE0_WRITE_BUDGET_RELEASE_MASTER * 2) +: 2] !=
                    CPP_MODE0_WRITE_BUDGET_RELEASE_RESP_CODE) begin
                fail_now("C++ trace write-budget release response mismatch");
            end
            write_resp_ready[CPP_MODE0_WRITE_BUDGET_RELEASE_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
            write_resp_ready[CPP_MODE0_WRITE_BUDGET_RELEASE_MASTER] = 1'b0;

            ddr_axi_awready = 1'b0;
            ddr_axi_wready = 1'b0;
            write_req_addr[(CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_REQ_ADDR;
            write_req_total_size[(CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_MASTER * 8) +: 8] =
                CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_REQ_SIZE;
            write_req_id[(CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_REQ_ID;
            write_req_wdata[(CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_MASTER * LINE_BITS) +: LINE_BITS] =
                CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_REQ_WDATA;
            write_req_wstrb[(CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_MASTER * LINE_BYTES) +: LINE_BYTES] =
                CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_REQ_WSTRB[LINE_BYTES-1:0];
            write_req_bypass[CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_MASTER] = 1'b0;
            write_req_valid[CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_MASTER] = 1'b1;
            timeout = 120;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace write-budget after-release accept timeout");
            end
            write_req_valid[CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_MASTER] = 1'b0;
            write_req_bypass[CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_MASTER] = 1'b0;

            timeout = 80;
            while (!ddr_axi_awvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace write-budget after-release AW timeout");
            end
            #1;
            if (ddr_axi_awaddr != CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_AWADDR ||
                ddr_axi_awlen != CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_AWLEN ||
                ddr_axi_awsize != CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_AWSIZE ||
                ddr_axi_awburst != CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_AWBURST ||
                ddr_axi_awid != CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_AWID ||
                ddr_axi_awid != CPP_MODE0_WRITE_BUDGET_RELEASE_AWID ||
                mmio_axi_awvalid) begin
                fail_now("C++ trace write-budget after-release AW mismatch");
            end
            ddr_axi_awready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_awready = 1'b0;

            timeout = 80;
            while (!ddr_axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace write-budget after-release W timeout");
            end
            #1;
            if (ddr_axi_wdata != CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_WBEAT0 ||
                ddr_axi_wstrb != CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_WSTRB0 ||
                ddr_axi_wlast != CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_WLAST0 ||
                mmio_axi_wvalid) begin
                fail_now("C++ trace write-budget after-release W mismatch");
            end
            ddr_axi_wready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_wready = 1'b0;

            ddr_axi_bid = CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_AWID;
            ddr_axi_bresp = AXI_RESP_OKAY;
            ddr_axi_bvalid = 1'b1;
            #1;
            if (!ddr_axi_bready) begin
                fail_now("C++ trace write-budget after-release B was backpressured");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_bvalid = 1'b0;

            timeout = 120;
            while (!write_resp_valid[CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace write-budget after-release response timeout");
            end
            #1;
            if (write_resp_id[(CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_RESP_ID ||
                write_resp_code[(CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_MASTER * 2) +: 2] !=
                    CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_RESP_CODE) begin
                fail_now("C++ trace write-budget after-release response mismatch");
            end
            write_resp_ready[CPP_MODE0_WRITE_BUDGET_AFTER_RELEASE_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task issue_overlapped_write_and_check;
        integer timeout;
        reg accepted_seen;
        begin
            reset_dut();
            @(negedge clk);
            write_resp_ready = {NUM_WRITE_MASTERS{1'b0}};
            ddr_axi_awready = 1'b0;
            ddr_axi_wready = 1'b0;
            mmio_axi_awready = 1'b0;
            mmio_axi_wready = 1'b0;

            write_req_addr[(CPP_MODE0_OVERLAP_WRITE_DDR_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE0_OVERLAP_WRITE_DDR_REQ_ADDR;
            write_req_total_size[(CPP_MODE0_OVERLAP_WRITE_DDR_MASTER * 8) +: 8] =
                CPP_MODE0_OVERLAP_WRITE_DDR_REQ_SIZE;
            write_req_id[(CPP_MODE0_OVERLAP_WRITE_DDR_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE0_OVERLAP_WRITE_DDR_REQ_ID;
            write_req_wdata[(CPP_MODE0_OVERLAP_WRITE_DDR_MASTER * LINE_BITS) +: LINE_BITS] =
                CPP_MODE0_OVERLAP_WRITE_DDR_REQ_WDATA;
            write_req_wstrb[(CPP_MODE0_OVERLAP_WRITE_DDR_MASTER * LINE_BYTES) +: LINE_BYTES] =
                CPP_MODE0_OVERLAP_WRITE_DDR_REQ_WSTRB[LINE_BYTES-1:0];
            write_req_valid[CPP_MODE0_OVERLAP_WRITE_DDR_MASTER] = 1'b1;
            timeout = 80;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[CPP_MODE0_OVERLAP_WRITE_DDR_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace overlapped DDR write accept timeout");
            end
            write_req_valid[CPP_MODE0_OVERLAP_WRITE_DDR_MASTER] = 1'b0;
            @(negedge clk);
            timeout = 80;
            while (!ddr_axi_awvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace overlapped DDR write AW timeout");
            end
            #1;
            if (ddr_axi_awaddr != CPP_MODE0_OVERLAP_WRITE_DDR_AWADDR ||
                ddr_axi_awlen != CPP_MODE0_OVERLAP_WRITE_DDR_AWLEN ||
                ddr_axi_awsize != CPP_MODE0_OVERLAP_WRITE_DDR_AWSIZE ||
                ddr_axi_awburst != CPP_MODE0_OVERLAP_WRITE_DDR_AWBURST ||
                ddr_axi_awid != CPP_MODE0_OVERLAP_WRITE_DDR_AWID ||
                mmio_axi_awvalid) begin
                fail_now("C++ trace overlapped DDR write AW mismatch");
            end
            seen_ddr_awid = ddr_axi_awid;
            ddr_axi_awready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_awready = 1'b0;
            timeout = 80;
            while (!ddr_axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace overlapped DDR write W timeout");
            end
            #1;
            if (ddr_axi_wdata != CPP_MODE0_OVERLAP_WRITE_DDR_WBEAT0 ||
                ddr_axi_wstrb != CPP_MODE0_OVERLAP_WRITE_DDR_WSTRB0 ||
                ddr_axi_wlast != CPP_MODE0_OVERLAP_WRITE_DDR_WLAST0) begin
                fail_now("C++ trace overlapped DDR write W mismatch");
            end
            ddr_axi_wready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_wready = 1'b0;

            write_req_addr[(CPP_MODE0_OVERLAP_WRITE_MMIO_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE0_OVERLAP_WRITE_MMIO_REQ_ADDR;
            write_req_total_size[(CPP_MODE0_OVERLAP_WRITE_MMIO_MASTER * 8) +: 8] =
                CPP_MODE0_OVERLAP_WRITE_MMIO_REQ_SIZE;
            write_req_id[(CPP_MODE0_OVERLAP_WRITE_MMIO_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE0_OVERLAP_WRITE_MMIO_REQ_ID;
            write_req_wdata[(CPP_MODE0_OVERLAP_WRITE_MMIO_MASTER * LINE_BITS) +: LINE_BITS] =
                CPP_MODE0_OVERLAP_WRITE_MMIO_REQ_WDATA;
            write_req_wstrb[(CPP_MODE0_OVERLAP_WRITE_MMIO_MASTER * LINE_BYTES) +: LINE_BYTES] =
                CPP_MODE0_OVERLAP_WRITE_MMIO_REQ_WSTRB[LINE_BYTES-1:0];
            write_req_valid[CPP_MODE0_OVERLAP_WRITE_MMIO_MASTER] = 1'b1;
            timeout = 80;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[CPP_MODE0_OVERLAP_WRITE_MMIO_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace overlapped MMIO write accept timeout");
            end
            write_req_valid[CPP_MODE0_OVERLAP_WRITE_MMIO_MASTER] = 1'b0;
            @(negedge clk);
            timeout = 80;
            while (!mmio_axi_awvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace overlapped MMIO write AW timeout");
            end
            #1;
            if (mmio_axi_awaddr != CPP_MODE0_OVERLAP_WRITE_MMIO_AWADDR ||
                mmio_axi_awlen != CPP_MODE0_OVERLAP_WRITE_MMIO_AWLEN ||
                mmio_axi_awsize != CPP_MODE0_OVERLAP_WRITE_MMIO_AWSIZE ||
                mmio_axi_awburst != CPP_MODE0_OVERLAP_WRITE_MMIO_AWBURST ||
                mmio_axi_awid != CPP_MODE0_OVERLAP_WRITE_MMIO_AWID ||
                ddr_axi_awvalid) begin
                fail_now("C++ trace overlapped MMIO write AW mismatch");
            end
            seen_mmio_awid = mmio_axi_awid;
            mmio_axi_awready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_awready = 1'b0;
            timeout = 80;
            while (!mmio_axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace overlapped MMIO write W timeout");
            end
            #1;
            if (mmio_axi_wdata != CPP_MODE0_OVERLAP_WRITE_MMIO_WBEAT0[MMIO_DATA_BITS-1:0] ||
                mmio_axi_wstrb != CPP_MODE0_OVERLAP_WRITE_MMIO_WSTRB0[MMIO_STRB_BITS-1:0] ||
                mmio_axi_wlast != CPP_MODE0_OVERLAP_WRITE_MMIO_WLAST0) begin
                fail_now("C++ trace overlapped MMIO write W mismatch");
            end
            mmio_axi_wready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_wready = 1'b0;

            mmio_axi_bid = seen_mmio_awid;
            mmio_axi_bresp = AXI_RESP_OKAY;
            mmio_axi_bvalid = 1'b1;
            #1;
            if (mmio_axi_bready !== CPP_MODE0_OVERLAP_WRITE_MMIO_BREADY_STALLED) begin
                fail_now("C++ trace overlapped MMIO BREADY stalled mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_bvalid = 1'b0;
            timeout = 80;
            while (!write_resp_valid[CPP_MODE0_OVERLAP_WRITE_MMIO_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0 ||
                write_resp_valid[CPP_MODE0_OVERLAP_WRITE_DDR_MASTER]) begin
                fail_now("C++ trace overlapped MMIO write response owner mismatch");
            end

            @(negedge clk);
            ddr_axi_bid = seen_ddr_awid;
            ddr_axi_bresp = AXI_RESP_OKAY;
            ddr_axi_bvalid = 1'b1;
            #1;
            if (ddr_axi_bready !== CPP_MODE0_OVERLAP_WRITE_DDR_BREADY_STALLED) begin
                fail_now("C++ trace overlapped DDR BREADY stalled mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_bvalid = 1'b0;
            #1;
            if (write_resp_id[(CPP_MODE0_OVERLAP_WRITE_MMIO_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE0_OVERLAP_WRITE_MMIO_RESP_ID ||
                write_resp_code[(CPP_MODE0_OVERLAP_WRITE_MMIO_MASTER * 2) +: 2] !=
                    CPP_MODE0_OVERLAP_WRITE_MMIO_RESP_CODE) begin
                fail_now("C++ trace overlapped MMIO write response payload mismatch");
            end
            write_resp_ready[CPP_MODE0_OVERLAP_WRITE_MMIO_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
            write_resp_ready[CPP_MODE0_OVERLAP_WRITE_MMIO_MASTER] = 1'b0;

            timeout = 120;
            while (!write_resp_valid[CPP_MODE0_OVERLAP_WRITE_DDR_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace overlapped DDR write response timeout");
            end
            #1;
            if (write_resp_id[(CPP_MODE0_OVERLAP_WRITE_DDR_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE0_OVERLAP_WRITE_DDR_RESP_ID ||
                write_resp_code[(CPP_MODE0_OVERLAP_WRITE_DDR_MASTER * 2) +: 2] !=
                    CPP_MODE0_OVERLAP_WRITE_DDR_RESP_CODE) begin
                fail_now("C++ trace overlapped DDR write response payload mismatch");
            end
            write_resp_ready[CPP_MODE0_OVERLAP_WRITE_DDR_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task issue_overlapped_write64_and_check;
        integer timeout;
        reg accepted_seen;
        begin
            reset_dut();
            @(negedge clk);
            write_resp_ready = {NUM_WRITE_MASTERS{1'b0}};
            ddr_axi_awready = 1'b0;
            ddr_axi_wready = 1'b0;
            mmio_axi_awready = 1'b0;
            mmio_axi_wready = 1'b0;

            write_req_addr[(CPP_MODE0_OVERLAP_WRITE64_DDR_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE0_OVERLAP_WRITE64_DDR_REQ_ADDR;
            write_req_total_size[(CPP_MODE0_OVERLAP_WRITE64_DDR_MASTER * 8) +: 8] =
                CPP_MODE0_OVERLAP_WRITE64_DDR_REQ_SIZE;
            write_req_id[(CPP_MODE0_OVERLAP_WRITE64_DDR_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE0_OVERLAP_WRITE64_DDR_REQ_ID;
            write_req_wdata[(CPP_MODE0_OVERLAP_WRITE64_DDR_MASTER * LINE_BITS) +: LINE_BITS] =
                CPP_MODE0_OVERLAP_WRITE64_DDR_REQ_WDATA;
            write_req_wstrb[(CPP_MODE0_OVERLAP_WRITE64_DDR_MASTER * LINE_BYTES) +: LINE_BYTES] =
                CPP_MODE0_OVERLAP_WRITE64_DDR_REQ_WSTRB[LINE_BYTES-1:0];
            write_req_valid[CPP_MODE0_OVERLAP_WRITE64_DDR_MASTER] = 1'b1;
            timeout = 80;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[CPP_MODE0_OVERLAP_WRITE64_DDR_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace overlapped write64 DDR accept timeout");
            end
            write_req_valid[CPP_MODE0_OVERLAP_WRITE64_DDR_MASTER] = 1'b0;
            @(negedge clk);
            timeout = 80;
            while (!ddr_axi_awvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace overlapped write64 DDR AW timeout");
            end
            #1;
            if (ddr_axi_awaddr != CPP_MODE0_OVERLAP_WRITE64_DDR_AWADDR ||
                ddr_axi_awlen != CPP_MODE0_OVERLAP_WRITE64_DDR_AWLEN ||
                ddr_axi_awsize != CPP_MODE0_OVERLAP_WRITE64_DDR_AWSIZE ||
                ddr_axi_awburst != CPP_MODE0_OVERLAP_WRITE64_DDR_AWBURST ||
                ddr_axi_awid != CPP_MODE0_OVERLAP_WRITE64_DDR_AWID ||
                mmio_axi_awvalid) begin
                fail_now("C++ trace overlapped write64 DDR AW mismatch");
            end
            seen_ddr_awid = ddr_axi_awid;
            ddr_axi_awready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            ddr_axi_awready = 1'b0;

            timeout = 80;
            while (!ddr_axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace overlapped write64 DDR W beat0 timeout");
            end
            #1;
            if (ddr_axi_wdata != CPP_MODE0_OVERLAP_WRITE64_DDR_WBEAT0 ||
                ddr_axi_wstrb != CPP_MODE0_OVERLAP_WRITE64_DDR_WSTRB0 ||
                ddr_axi_wlast != CPP_MODE0_OVERLAP_WRITE64_DDR_WLAST0) begin
                fail_now("C++ trace overlapped write64 DDR W beat0 mismatch");
            end
            ddr_axi_wready = 1'b1;
            @(posedge clk);
            @(negedge clk);

            timeout = 80;
            while (!ddr_axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace overlapped write64 DDR W beat1 timeout");
            end
            #1;
            if (ddr_axi_wdata != CPP_MODE0_OVERLAP_WRITE64_DDR_WBEAT1 ||
                ddr_axi_wstrb != CPP_MODE0_OVERLAP_WRITE64_DDR_WSTRB1 ||
                ddr_axi_wlast != CPP_MODE0_OVERLAP_WRITE64_DDR_WLAST1) begin
                fail_now("C++ trace overlapped write64 DDR W beat1 mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_wready = 1'b0;

            write_req_addr[(CPP_MODE0_OVERLAP_WRITE64_MMIO_MASTER * ADDR_BITS) +: ADDR_BITS] =
                CPP_MODE0_OVERLAP_WRITE64_MMIO_REQ_ADDR;
            write_req_total_size[(CPP_MODE0_OVERLAP_WRITE64_MMIO_MASTER * 8) +: 8] =
                CPP_MODE0_OVERLAP_WRITE64_MMIO_REQ_SIZE;
            write_req_id[(CPP_MODE0_OVERLAP_WRITE64_MMIO_MASTER * ID_BITS) +: ID_BITS] =
                CPP_MODE0_OVERLAP_WRITE64_MMIO_REQ_ID;
            write_req_wdata[(CPP_MODE0_OVERLAP_WRITE64_MMIO_MASTER * LINE_BITS) +: LINE_BITS] =
                CPP_MODE0_OVERLAP_WRITE64_MMIO_REQ_WDATA;
            write_req_wstrb[(CPP_MODE0_OVERLAP_WRITE64_MMIO_MASTER * LINE_BYTES) +: LINE_BYTES] =
                CPP_MODE0_OVERLAP_WRITE64_MMIO_REQ_WSTRB[LINE_BYTES-1:0];
            write_req_valid[CPP_MODE0_OVERLAP_WRITE64_MMIO_MASTER] = 1'b1;
            timeout = 80;
            accepted_seen = 1'b0;
            while (!accepted_seen && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (write_req_accepted[CPP_MODE0_OVERLAP_WRITE64_MMIO_MASTER]) begin
                    accepted_seen = 1'b1;
                end
                timeout = timeout - 1;
            end
            if (!accepted_seen) begin
                fail_now("C++ trace overlapped write64 MMIO accept timeout");
            end
            write_req_valid[CPP_MODE0_OVERLAP_WRITE64_MMIO_MASTER] = 1'b0;
            @(negedge clk);
            timeout = 80;
            while (!mmio_axi_awvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace overlapped write64 MMIO AW timeout");
            end
            #1;
            if (mmio_axi_awaddr != CPP_MODE0_OVERLAP_WRITE64_MMIO_AWADDR ||
                mmio_axi_awlen != CPP_MODE0_OVERLAP_WRITE64_MMIO_AWLEN ||
                mmio_axi_awsize != CPP_MODE0_OVERLAP_WRITE64_MMIO_AWSIZE ||
                mmio_axi_awburst != CPP_MODE0_OVERLAP_WRITE64_MMIO_AWBURST ||
                mmio_axi_awid != CPP_MODE0_OVERLAP_WRITE64_MMIO_AWID ||
                ddr_axi_awvalid) begin
                fail_now("C++ trace overlapped write64 MMIO AW mismatch");
            end
            seen_mmio_awid = mmio_axi_awid;
            mmio_axi_awready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_awready = 1'b0;

            timeout = 80;
            while (!mmio_axi_wvalid && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace overlapped write64 MMIO W timeout");
            end
            #1;
            if (mmio_axi_wdata != CPP_MODE0_OVERLAP_WRITE64_MMIO_WBEAT0[MMIO_DATA_BITS-1:0] ||
                mmio_axi_wstrb != CPP_MODE0_OVERLAP_WRITE64_MMIO_WSTRB0[MMIO_STRB_BITS-1:0] ||
                mmio_axi_wlast != CPP_MODE0_OVERLAP_WRITE64_MMIO_WLAST0) begin
                fail_now("C++ trace overlapped write64 MMIO W mismatch");
            end
            mmio_axi_wready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mmio_axi_wready = 1'b0;

            mmio_axi_bid = seen_mmio_awid;
            mmio_axi_bresp = AXI_RESP_OKAY;
            mmio_axi_bvalid = 1'b1;
            #1;
            if (mmio_axi_bready !== CPP_MODE0_OVERLAP_WRITE64_MMIO_BREADY_STALLED) begin
                fail_now("C++ trace overlapped write64 MMIO BREADY stalled mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            mmio_axi_bvalid = 1'b0;
            timeout = 80;
            while (!write_resp_valid[CPP_MODE0_OVERLAP_WRITE64_MMIO_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0 ||
                write_resp_valid[CPP_MODE0_OVERLAP_WRITE64_DDR_MASTER]) begin
                fail_now("C++ trace overlapped write64 MMIO response owner mismatch");
            end

            @(negedge clk);
            ddr_axi_bid = seen_ddr_awid;
            ddr_axi_bresp = AXI_RESP_OKAY;
            ddr_axi_bvalid = 1'b1;
            #1;
            if (ddr_axi_bready !== CPP_MODE0_OVERLAP_WRITE64_DDR_BREADY_STALLED) begin
                fail_now("C++ trace overlapped write64 DDR BREADY stalled mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            ddr_axi_bvalid = 1'b0;
            #1;
            if (write_resp_id[(CPP_MODE0_OVERLAP_WRITE64_MMIO_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE0_OVERLAP_WRITE64_MMIO_RESP_ID ||
                write_resp_code[(CPP_MODE0_OVERLAP_WRITE64_MMIO_MASTER * 2) +: 2] !=
                    CPP_MODE0_OVERLAP_WRITE64_MMIO_RESP_CODE) begin
                fail_now("C++ trace overlapped write64 MMIO response payload mismatch");
            end
            write_resp_ready[CPP_MODE0_OVERLAP_WRITE64_MMIO_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
            write_resp_ready[CPP_MODE0_OVERLAP_WRITE64_MMIO_MASTER] = 1'b0;

            timeout = 120;
            while (!write_resp_valid[CPP_MODE0_OVERLAP_WRITE64_DDR_MASTER] &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace overlapped write64 DDR response timeout");
            end
            #1;
            if (write_resp_id[(CPP_MODE0_OVERLAP_WRITE64_DDR_MASTER * ID_BITS) +: ID_BITS] !=
                    CPP_MODE0_OVERLAP_WRITE64_DDR_RESP_ID ||
                write_resp_code[(CPP_MODE0_OVERLAP_WRITE64_DDR_MASTER * 2) +: 2] !=
                    CPP_MODE0_OVERLAP_WRITE64_DDR_RESP_CODE) begin
                fail_now("C++ trace overlapped write64 DDR response payload mismatch");
            end
            write_resp_ready[CPP_MODE0_OVERLAP_WRITE64_DDR_MASTER] = 1'b1;
            @(posedge clk);
            @(negedge clk);
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
        .USE_SMIC12_STORES (0),
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
        issue_read_and_check(MODE_OFF,
                             CPP_MODE0_DDR_READ1_REQ_ADDR,
                             CPP_MODE0_DDR_READ1_REQ_SIZE,
                             CPP_MODE0_DDR_READ1_REQ_ID,
                             CPP_MODE0_DDR_READ1_ARADDR,
                             CPP_MODE0_DDR_READ1_ARLEN,
                             CPP_MODE0_DDR_READ1_ARSIZE,
                             CPP_MODE0_DDR_READ1_ARBURST,
                             CPP_MODE0_DDR_READ1_ARID,
                             CPP_MODE0_DDR_READ1_BEATS,
                             CPP_MODE0_DDR_READ1_RBEAT0,
                             {DDR_DATA_BITS{1'b0}},
                             CPP_MODE0_DDR_READ1_RESP_ID,
                             CPP_MODE0_DDR_READ1_RESP_DATA);

        issue_read_and_check(MODE_OFF,
                             CPP_MODE0_DDR_READ2_REQ_ADDR,
                             CPP_MODE0_DDR_READ2_REQ_SIZE,
                             CPP_MODE0_DDR_READ2_REQ_ID,
                             CPP_MODE0_DDR_READ2_ARADDR,
                             CPP_MODE0_DDR_READ2_ARLEN,
                             CPP_MODE0_DDR_READ2_ARSIZE,
                             CPP_MODE0_DDR_READ2_ARBURST,
                             CPP_MODE0_DDR_READ2_ARID,
                             CPP_MODE0_DDR_READ2_BEATS,
                             CPP_MODE0_DDR_READ2_RBEAT0,
                             {DDR_DATA_BITS{1'b0}},
                             CPP_MODE0_DDR_READ2_RESP_ID,
                             CPP_MODE0_DDR_READ2_RESP_DATA);

        issue_read_and_check(MODE_OFF,
                             CPP_MODE0_DDR_READ4_REQ_ADDR,
                             CPP_MODE0_DDR_READ4_REQ_SIZE,
                             CPP_MODE0_DDR_READ4_REQ_ID,
                             CPP_MODE0_DDR_READ4_ARADDR,
                             CPP_MODE0_DDR_READ4_ARLEN,
                             CPP_MODE0_DDR_READ4_ARSIZE,
                             CPP_MODE0_DDR_READ4_ARBURST,
                             CPP_MODE0_DDR_READ4_ARID,
                             CPP_MODE0_DDR_READ4_BEATS,
                             CPP_MODE0_DDR_READ4_RBEAT0,
                             {DDR_DATA_BITS{1'b0}},
                             CPP_MODE0_DDR_READ4_RESP_ID,
                             CPP_MODE0_DDR_READ4_RESP_DATA);

        issue_read_and_check(MODE_OFF,
                             CPP_MODE0_DDR_READ8_REQ_ADDR,
                             CPP_MODE0_DDR_READ8_REQ_SIZE,
                             CPP_MODE0_DDR_READ8_REQ_ID,
                             CPP_MODE0_DDR_READ8_ARADDR,
                             CPP_MODE0_DDR_READ8_ARLEN,
                             CPP_MODE0_DDR_READ8_ARSIZE,
                             CPP_MODE0_DDR_READ8_ARBURST,
                             CPP_MODE0_DDR_READ8_ARID,
                             CPP_MODE0_DDR_READ8_BEATS,
                             CPP_MODE0_DDR_READ8_RBEAT0,
                             {DDR_DATA_BITS{1'b0}},
                             CPP_MODE0_DDR_READ8_RESP_ID,
                             CPP_MODE0_DDR_READ8_RESP_DATA);

        issue_read_and_check(MODE_OFF,
                             CPP_MODE0_DDR_READ16_REQ_ADDR,
                             CPP_MODE0_DDR_READ16_REQ_SIZE,
                             CPP_MODE0_DDR_READ16_REQ_ID,
                             CPP_MODE0_DDR_READ16_ARADDR,
                             CPP_MODE0_DDR_READ16_ARLEN,
                             CPP_MODE0_DDR_READ16_ARSIZE,
                             CPP_MODE0_DDR_READ16_ARBURST,
                             CPP_MODE0_DDR_READ16_ARID,
                             CPP_MODE0_DDR_READ16_BEATS,
                             CPP_MODE0_DDR_READ16_RBEAT0,
                             {DDR_DATA_BITS{1'b0}},
                             CPP_MODE0_DDR_READ16_RESP_ID,
                             CPP_MODE0_DDR_READ16_RESP_DATA);

        issue_read_and_check(MODE_OFF,
                             CPP_MODE0_DDR_READ32_REQ_ADDR,
                             CPP_MODE0_DDR_READ32_REQ_SIZE,
                             CPP_MODE0_DDR_READ32_REQ_ID,
                             CPP_MODE0_DDR_READ32_ARADDR,
                             CPP_MODE0_DDR_READ32_ARLEN,
                             CPP_MODE0_DDR_READ32_ARSIZE,
                             CPP_MODE0_DDR_READ32_ARBURST,
                             CPP_MODE0_DDR_READ32_ARID,
                             CPP_MODE0_DDR_READ32_BEATS,
                             CPP_MODE0_DDR_READ32_RBEAT0,
                             {DDR_DATA_BITS{1'b0}},
                             CPP_MODE0_DDR_READ32_RESP_ID,
                             CPP_MODE0_DDR_READ32_RESP_DATA);

        issue_read_and_check(MODE_OFF,
                             CPP_MODE0_DDR_READ64_REQ_ADDR,
                             CPP_MODE0_DDR_READ64_REQ_SIZE,
                             CPP_MODE0_DDR_READ64_REQ_ID,
                             CPP_MODE0_DDR_READ64_ARADDR,
                             CPP_MODE0_DDR_READ64_ARLEN,
                             CPP_MODE0_DDR_READ64_ARSIZE,
                             CPP_MODE0_DDR_READ64_ARBURST,
                             CPP_MODE0_DDR_READ64_ARID,
                             CPP_MODE0_DDR_READ64_BEATS,
                             CPP_MODE0_DDR_READ64_RBEAT0,
                             CPP_MODE0_DDR_READ64_RBEAT1,
                             CPP_MODE0_DDR_READ64_RESP_ID,
                             CPP_MODE0_DDR_READ64_RESP_DATA);

        issue_write_and_check(MODE_OFF,
                              CPP_MODE0_DDR_WRITE1_REQ_ADDR,
                              CPP_MODE0_DDR_WRITE1_REQ_SIZE,
                              CPP_MODE0_DDR_WRITE1_REQ_ID,
                              CPP_MODE0_DDR_WRITE1_REQ_WDATA,
                              CPP_MODE0_DDR_WRITE1_REQ_WSTRB,
                              CPP_MODE0_DDR_WRITE1_AWADDR,
                              CPP_MODE0_DDR_WRITE1_AWLEN,
                              CPP_MODE0_DDR_WRITE1_AWSIZE,
                              CPP_MODE0_DDR_WRITE1_AWBURST,
                              CPP_MODE0_DDR_WRITE1_AWID,
                              CPP_MODE0_DDR_WRITE1_BEATS,
                              CPP_MODE0_DDR_WRITE1_WBEAT0,
                              CPP_MODE0_DDR_WRITE1_WSTRB0,
                              CPP_MODE0_DDR_WRITE1_WLAST0,
                              {DDR_DATA_BITS{1'b0}},
                              {DDR_STRB_BITS{1'b0}},
                              1'b0,
                              CPP_MODE0_DDR_WRITE1_RESP_ID,
                              CPP_MODE0_DDR_WRITE1_RESP_CODE);

        issue_write_and_check(MODE_OFF,
                              CPP_MODE0_DDR_WRITE2_REQ_ADDR,
                              CPP_MODE0_DDR_WRITE2_REQ_SIZE,
                              CPP_MODE0_DDR_WRITE2_REQ_ID,
                              CPP_MODE0_DDR_WRITE2_REQ_WDATA,
                              CPP_MODE0_DDR_WRITE2_REQ_WSTRB,
                              CPP_MODE0_DDR_WRITE2_AWADDR,
                              CPP_MODE0_DDR_WRITE2_AWLEN,
                              CPP_MODE0_DDR_WRITE2_AWSIZE,
                              CPP_MODE0_DDR_WRITE2_AWBURST,
                              CPP_MODE0_DDR_WRITE2_AWID,
                              CPP_MODE0_DDR_WRITE2_BEATS,
                              CPP_MODE0_DDR_WRITE2_WBEAT0,
                              CPP_MODE0_DDR_WRITE2_WSTRB0,
                              CPP_MODE0_DDR_WRITE2_WLAST0,
                              {DDR_DATA_BITS{1'b0}},
                              {DDR_STRB_BITS{1'b0}},
                              1'b0,
                              CPP_MODE0_DDR_WRITE2_RESP_ID,
                              CPP_MODE0_DDR_WRITE2_RESP_CODE);

        issue_write_and_check(MODE_OFF,
                              CPP_MODE0_DDR_WRITE4_REQ_ADDR,
                              CPP_MODE0_DDR_WRITE4_REQ_SIZE,
                              CPP_MODE0_DDR_WRITE4_REQ_ID,
                              CPP_MODE0_DDR_WRITE4_REQ_WDATA,
                              CPP_MODE0_DDR_WRITE4_REQ_WSTRB,
                              CPP_MODE0_DDR_WRITE4_AWADDR,
                              CPP_MODE0_DDR_WRITE4_AWLEN,
                              CPP_MODE0_DDR_WRITE4_AWSIZE,
                              CPP_MODE0_DDR_WRITE4_AWBURST,
                              CPP_MODE0_DDR_WRITE4_AWID,
                              CPP_MODE0_DDR_WRITE4_BEATS,
                              CPP_MODE0_DDR_WRITE4_WBEAT0,
                              CPP_MODE0_DDR_WRITE4_WSTRB0,
                              CPP_MODE0_DDR_WRITE4_WLAST0,
                              {DDR_DATA_BITS{1'b0}},
                              {DDR_STRB_BITS{1'b0}},
                              1'b0,
                              CPP_MODE0_DDR_WRITE4_RESP_ID,
                              CPP_MODE0_DDR_WRITE4_RESP_CODE);

        issue_write_and_check(MODE_OFF,
                              CPP_MODE0_DDR_WRITE8_REQ_ADDR,
                              CPP_MODE0_DDR_WRITE8_REQ_SIZE,
                              CPP_MODE0_DDR_WRITE8_REQ_ID,
                              CPP_MODE0_DDR_WRITE8_REQ_WDATA,
                              CPP_MODE0_DDR_WRITE8_REQ_WSTRB,
                              CPP_MODE0_DDR_WRITE8_AWADDR,
                              CPP_MODE0_DDR_WRITE8_AWLEN,
                              CPP_MODE0_DDR_WRITE8_AWSIZE,
                              CPP_MODE0_DDR_WRITE8_AWBURST,
                              CPP_MODE0_DDR_WRITE8_AWID,
                              CPP_MODE0_DDR_WRITE8_BEATS,
                              CPP_MODE0_DDR_WRITE8_WBEAT0,
                              CPP_MODE0_DDR_WRITE8_WSTRB0,
                              CPP_MODE0_DDR_WRITE8_WLAST0,
                              {DDR_DATA_BITS{1'b0}},
                              {DDR_STRB_BITS{1'b0}},
                              1'b0,
                              CPP_MODE0_DDR_WRITE8_RESP_ID,
                              CPP_MODE0_DDR_WRITE8_RESP_CODE);

        issue_write_and_check(MODE_OFF,
                              CPP_MODE0_DDR_WRITE16_REQ_ADDR,
                              CPP_MODE0_DDR_WRITE16_REQ_SIZE,
                              CPP_MODE0_DDR_WRITE16_REQ_ID,
                              CPP_MODE0_DDR_WRITE16_REQ_WDATA,
                              CPP_MODE0_DDR_WRITE16_REQ_WSTRB,
                              CPP_MODE0_DDR_WRITE16_AWADDR,
                              CPP_MODE0_DDR_WRITE16_AWLEN,
                              CPP_MODE0_DDR_WRITE16_AWSIZE,
                              CPP_MODE0_DDR_WRITE16_AWBURST,
                              CPP_MODE0_DDR_WRITE16_AWID,
                              CPP_MODE0_DDR_WRITE16_BEATS,
                              CPP_MODE0_DDR_WRITE16_WBEAT0,
                              CPP_MODE0_DDR_WRITE16_WSTRB0,
                              CPP_MODE0_DDR_WRITE16_WLAST0,
                              {DDR_DATA_BITS{1'b0}},
                              {DDR_STRB_BITS{1'b0}},
                              1'b0,
                              CPP_MODE0_DDR_WRITE16_RESP_ID,
                              CPP_MODE0_DDR_WRITE16_RESP_CODE);

        issue_write_and_check(MODE_OFF,
                              CPP_MODE0_DDR_WRITE32_REQ_ADDR,
                              CPP_MODE0_DDR_WRITE32_REQ_SIZE,
                              CPP_MODE0_DDR_WRITE32_REQ_ID,
                              CPP_MODE0_DDR_WRITE32_REQ_WDATA,
                              CPP_MODE0_DDR_WRITE32_REQ_WSTRB,
                              CPP_MODE0_DDR_WRITE32_AWADDR,
                              CPP_MODE0_DDR_WRITE32_AWLEN,
                              CPP_MODE0_DDR_WRITE32_AWSIZE,
                              CPP_MODE0_DDR_WRITE32_AWBURST,
                              CPP_MODE0_DDR_WRITE32_AWID,
                              CPP_MODE0_DDR_WRITE32_BEATS,
                              CPP_MODE0_DDR_WRITE32_WBEAT0,
                              CPP_MODE0_DDR_WRITE32_WSTRB0,
                              CPP_MODE0_DDR_WRITE32_WLAST0,
                              {DDR_DATA_BITS{1'b0}},
                              {DDR_STRB_BITS{1'b0}},
                              1'b0,
                              CPP_MODE0_DDR_WRITE32_RESP_ID,
                              CPP_MODE0_DDR_WRITE32_RESP_CODE);

        issue_write_and_check(MODE_OFF,
                              CPP_MODE0_DDR_WRITE64_REQ_ADDR,
                              CPP_MODE0_DDR_WRITE64_REQ_SIZE,
                              CPP_MODE0_DDR_WRITE64_REQ_ID,
                              CPP_MODE0_DDR_WRITE64_REQ_WDATA,
                              CPP_MODE0_DDR_WRITE64_REQ_WSTRB,
                              CPP_MODE0_DDR_WRITE64_AWADDR,
                              CPP_MODE0_DDR_WRITE64_AWLEN,
                              CPP_MODE0_DDR_WRITE64_AWSIZE,
                              CPP_MODE0_DDR_WRITE64_AWBURST,
                              CPP_MODE0_DDR_WRITE64_AWID,
                              CPP_MODE0_DDR_WRITE64_BEATS,
                              CPP_MODE0_DDR_WRITE64_WBEAT0,
                              CPP_MODE0_DDR_WRITE64_WSTRB0,
                              CPP_MODE0_DDR_WRITE64_WLAST0,
                              CPP_MODE0_DDR_WRITE64_WBEAT1,
                              CPP_MODE0_DDR_WRITE64_WSTRB1,
                              CPP_MODE0_DDR_WRITE64_WLAST1,
                              CPP_MODE0_DDR_WRITE64_RESP_ID,
                              CPP_MODE0_DDR_WRITE64_RESP_CODE);

        issue_mmio_read_and_check(MODE_OFF,
                                  CPP_MODE0_MMIO_READ4_REQ_ADDR,
                                  CPP_MODE0_MMIO_READ4_REQ_SIZE,
                                  CPP_MODE0_MMIO_READ4_REQ_ID,
                                  CPP_MODE0_MMIO_READ4_ARADDR,
                                  CPP_MODE0_MMIO_READ4_ARLEN,
                                  CPP_MODE0_MMIO_READ4_ARSIZE,
                                  CPP_MODE0_MMIO_READ4_ARBURST,
                                  CPP_MODE0_MMIO_READ4_ARID,
                                  CPP_MODE0_MMIO_READ4_RBEAT0,
                                  CPP_MODE0_MMIO_READ4_RESP_ID,
                                  CPP_MODE0_MMIO_READ4_RESP_DATA);

        issue_mmio_write_and_check(MODE_OFF,
                                   CPP_MODE0_MMIO_WRITE4_REQ_ADDR,
                                   CPP_MODE0_MMIO_WRITE4_REQ_SIZE,
                                   CPP_MODE0_MMIO_WRITE4_REQ_ID,
                                   CPP_MODE0_MMIO_WRITE4_REQ_WDATA,
                                   CPP_MODE0_MMIO_WRITE4_REQ_WSTRB,
                                   CPP_MODE0_MMIO_WRITE4_AWADDR,
                                   CPP_MODE0_MMIO_WRITE4_AWLEN,
                                   CPP_MODE0_MMIO_WRITE4_AWSIZE,
                                   CPP_MODE0_MMIO_WRITE4_AWBURST,
                                   CPP_MODE0_MMIO_WRITE4_AWID,
                                   CPP_MODE0_MMIO_WRITE4_WBEAT0,
                                   CPP_MODE0_MMIO_WRITE4_WSTRB0,
                                   CPP_MODE0_MMIO_WRITE4_WLAST0,
                                   CPP_MODE0_MMIO_WRITE4_RESP_ID,
                                   CPP_MODE0_MMIO_WRITE4_RESP_CODE);

        issue_unsupported_mmio_read_and_check(
            MODE_OFF,
            CPP_MODE0_MMIO_READ8_UNSUPPORTED_REQ_ADDR,
            CPP_MODE0_MMIO_READ8_UNSUPPORTED_REQ_SIZE,
            CPP_MODE0_MMIO_READ8_UNSUPPORTED_REQ_ID,
            CPP_MODE0_MMIO_READ8_UNSUPPORTED_REQ_READY);

        issue_unsupported_mmio_write_and_check(
            MODE_OFF,
            CPP_MODE0_MMIO_WRITE8_UNSUPPORTED_REQ_ADDR,
            CPP_MODE0_MMIO_WRITE8_UNSUPPORTED_REQ_SIZE,
            CPP_MODE0_MMIO_WRITE8_UNSUPPORTED_REQ_ID,
            CPP_MODE0_MMIO_WRITE8_UNSUPPORTED_REQ_WDATA,
            CPP_MODE0_MMIO_WRITE8_UNSUPPORTED_REQ_WSTRB,
            CPP_MODE0_MMIO_WRITE8_UNSUPPORTED_REQ_READY);

        issue_overlapped_read_and_check();
        issue_overlapped_read64_and_check();
        issue_same_master_read_order_and_check();
        issue_same_master_write_order_and_check();
        issue_read_reuse_and_check();
        issue_read_budget_release_and_check();
        issue_overlapped_write_and_check();
        issue_overlapped_write64_and_check();
        issue_write_reuse_and_check();
        issue_write_budget_release_and_check();
        issue_mode0_same_line_write_pending_read_and_check();

        issue_mmio_read_and_check(MODE_CACHE,
                                  CPP_MODE1_MMIO_READ4_REQ_ADDR,
                                  CPP_MODE1_MMIO_READ4_REQ_SIZE,
                                  CPP_MODE1_MMIO_READ4_REQ_ID,
                                  CPP_MODE1_MMIO_READ4_ARADDR,
                                  CPP_MODE1_MMIO_READ4_ARLEN,
                                  CPP_MODE1_MMIO_READ4_ARSIZE,
                                  CPP_MODE1_MMIO_READ4_ARBURST,
                                  CPP_MODE1_MMIO_READ4_ARID,
                                  CPP_MODE1_MMIO_READ4_RBEAT0,
                                  CPP_MODE1_MMIO_READ4_RESP_ID,
                                  CPP_MODE1_MMIO_READ4_RESP_DATA);

        issue_mmio_write_and_check(MODE_CACHE,
                                   CPP_MODE1_MMIO_WRITE4_REQ_ADDR,
                                   CPP_MODE1_MMIO_WRITE4_REQ_SIZE,
                                   CPP_MODE1_MMIO_WRITE4_REQ_ID,
                                   CPP_MODE1_MMIO_WRITE4_REQ_WDATA,
                                   CPP_MODE1_MMIO_WRITE4_REQ_WSTRB,
                                   CPP_MODE1_MMIO_WRITE4_AWADDR,
                                   CPP_MODE1_MMIO_WRITE4_AWLEN,
                                   CPP_MODE1_MMIO_WRITE4_AWSIZE,
                                   CPP_MODE1_MMIO_WRITE4_AWBURST,
                                   CPP_MODE1_MMIO_WRITE4_AWID,
                                   CPP_MODE1_MMIO_WRITE4_WBEAT0,
                                   CPP_MODE1_MMIO_WRITE4_WSTRB0,
                                   CPP_MODE1_MMIO_WRITE4_WLAST0,
                                   CPP_MODE1_MMIO_WRITE4_RESP_ID,
                                   CPP_MODE1_MMIO_WRITE4_RESP_CODE);

        issue_mode1_cache_mmio_overlap_read_and_check();
        issue_mode1_invalidate_line_pending_read_and_check();
        issue_mode1_invalidate_line_cache_mmio_read_and_check();
        issue_mode1_same_line_read_pending_write_and_check();
        issue_mode1_same_line_mmio_read_pending_write_and_check();
        issue_mode1_same_line_mmio_write_pending_read_and_check();
        issue_mode1_invalidate_all_cache_mmio_read_and_check();
        issue_mode1_cache_write_miss_mmio_write_and_check();
        issue_mode1_invalidate_all_cache_mmio_write_and_check();
        issue_mode1_invalidate_all_cache_mmio_rw_and_check();
        issue_mode1_dirty_victim_mmio_write_and_check();
        issue_mode2_mapped_local_write_read_and_check();
        issue_mmio_read_and_check(MODE_MAPPED,
                                  CPP_MODE2_MMIO_BELOW_READ4_REQ_ADDR,
                                  CPP_MODE2_MMIO_BELOW_READ4_REQ_SIZE,
                                  CPP_MODE2_MMIO_BELOW_READ4_REQ_ID,
                                  CPP_MODE2_MMIO_BELOW_READ4_ARADDR,
                                  CPP_MODE2_MMIO_BELOW_READ4_ARLEN,
                                  CPP_MODE2_MMIO_BELOW_READ4_ARSIZE,
                                  CPP_MODE2_MMIO_BELOW_READ4_ARBURST,
                                  CPP_MODE2_MMIO_BELOW_READ4_ARID,
                                  CPP_MODE2_MMIO_BELOW_READ4_RBEAT0,
                                  CPP_MODE2_MMIO_BELOW_READ4_RESP_ID,
                                  CPP_MODE2_MMIO_BELOW_READ4_RESP_DATA);
        issue_mmio_write_and_check(MODE_MAPPED,
                                   CPP_MODE2_MMIO_BELOW_WRITE4_REQ_ADDR,
                                   CPP_MODE2_MMIO_BELOW_WRITE4_REQ_SIZE,
                                   CPP_MODE2_MMIO_BELOW_WRITE4_REQ_ID,
                                   CPP_MODE2_MMIO_BELOW_WRITE4_REQ_WDATA,
                                   CPP_MODE2_MMIO_BELOW_WRITE4_REQ_WSTRB,
                                   CPP_MODE2_MMIO_BELOW_WRITE4_AWADDR,
                                   CPP_MODE2_MMIO_BELOW_WRITE4_AWLEN,
                                   CPP_MODE2_MMIO_BELOW_WRITE4_AWSIZE,
                                   CPP_MODE2_MMIO_BELOW_WRITE4_AWBURST,
                                   CPP_MODE2_MMIO_BELOW_WRITE4_AWID,
                                   CPP_MODE2_MMIO_BELOW_WRITE4_WBEAT0,
                                   CPP_MODE2_MMIO_BELOW_WRITE4_WSTRB0,
                                   CPP_MODE2_MMIO_BELOW_WRITE4_WLAST0,
                                   CPP_MODE2_MMIO_BELOW_WRITE4_RESP_ID,
                                   CPP_MODE2_MMIO_BELOW_WRITE4_RESP_CODE);
        issue_mmio_read_and_check(MODE_MAPPED,
                                  CPP_MODE2_MMIO_ABOVE_READ4_REQ_ADDR,
                                  CPP_MODE2_MMIO_ABOVE_READ4_REQ_SIZE,
                                  CPP_MODE2_MMIO_ABOVE_READ4_REQ_ID,
                                  CPP_MODE2_MMIO_ABOVE_READ4_ARADDR,
                                  CPP_MODE2_MMIO_ABOVE_READ4_ARLEN,
                                  CPP_MODE2_MMIO_ABOVE_READ4_ARSIZE,
                                  CPP_MODE2_MMIO_ABOVE_READ4_ARBURST,
                                  CPP_MODE2_MMIO_ABOVE_READ4_ARID,
                                  CPP_MODE2_MMIO_ABOVE_READ4_RBEAT0,
                                  CPP_MODE2_MMIO_ABOVE_READ4_RESP_ID,
                                  CPP_MODE2_MMIO_ABOVE_READ4_RESP_DATA);
        issue_mmio_write_and_check(MODE_MAPPED,
                                   CPP_MODE2_MMIO_ABOVE_WRITE4_REQ_ADDR,
                                   CPP_MODE2_MMIO_ABOVE_WRITE4_REQ_SIZE,
                                   CPP_MODE2_MMIO_ABOVE_WRITE4_REQ_ID,
                                   CPP_MODE2_MMIO_ABOVE_WRITE4_REQ_WDATA,
                                   CPP_MODE2_MMIO_ABOVE_WRITE4_REQ_WSTRB,
                                   CPP_MODE2_MMIO_ABOVE_WRITE4_AWADDR,
                                   CPP_MODE2_MMIO_ABOVE_WRITE4_AWLEN,
                                   CPP_MODE2_MMIO_ABOVE_WRITE4_AWSIZE,
                                   CPP_MODE2_MMIO_ABOVE_WRITE4_AWBURST,
                                   CPP_MODE2_MMIO_ABOVE_WRITE4_AWID,
                                   CPP_MODE2_MMIO_ABOVE_WRITE4_WBEAT0,
                                   CPP_MODE2_MMIO_ABOVE_WRITE4_WSTRB0,
                                   CPP_MODE2_MMIO_ABOVE_WRITE4_WLAST0,
                                   CPP_MODE2_MMIO_ABOVE_WRITE4_RESP_ID,
                                   CPP_MODE2_MMIO_ABOVE_WRITE4_RESP_CODE);
        issue_unsupported_mmio_read_and_check(
            MODE_MAPPED,
            CPP_MODE2_MAPPED_CROSS_READ8_UNSUPPORTED_REQ_ADDR,
            CPP_MODE2_MAPPED_CROSS_READ8_UNSUPPORTED_REQ_SIZE,
            CPP_MODE2_MAPPED_CROSS_READ8_UNSUPPORTED_REQ_ID,
            CPP_MODE2_MAPPED_CROSS_READ8_UNSUPPORTED_REQ_READY);
        issue_unsupported_mmio_write_and_check(
            MODE_MAPPED,
            CPP_MODE2_MAPPED_CROSS_WRITE8_UNSUPPORTED_REQ_ADDR,
            CPP_MODE2_MAPPED_CROSS_WRITE8_UNSUPPORTED_REQ_SIZE,
            CPP_MODE2_MAPPED_CROSS_WRITE8_UNSUPPORTED_REQ_ID,
            CPP_MODE2_MAPPED_CROSS_WRITE8_UNSUPPORTED_REQ_WDATA,
            CPP_MODE2_MAPPED_CROSS_WRITE8_UNSUPPORTED_REQ_WSTRB,
            CPP_MODE2_MAPPED_CROSS_WRITE8_UNSUPPORTED_REQ_READY);
        issue_invalidate_all_blocked_read_and_check(
            CPP_MODE1_INVALIDATE_ALL_READ_BLOCKED_REQ_ADDR,
            CPP_MODE1_INVALIDATE_ALL_READ_BLOCKED_REQ_SIZE,
            CPP_MODE1_INVALIDATE_ALL_READ_BLOCKED_REQ_ID,
            CPP_MODE1_INVALIDATE_ALL_READ_BLOCKED_REQ_READY);
        issue_invalidate_all_blocked_write_and_check(
            CPP_MODE1_INVALIDATE_ALL_WRITE_BLOCKED_REQ_ADDR,
            CPP_MODE1_INVALIDATE_ALL_WRITE_BLOCKED_REQ_SIZE,
            CPP_MODE1_INVALIDATE_ALL_WRITE_BLOCKED_REQ_ID,
            CPP_MODE1_INVALIDATE_ALL_WRITE_BLOCKED_REQ_WDATA,
            CPP_MODE1_INVALIDATE_ALL_WRITE_BLOCKED_REQ_WSTRB,
            CPP_MODE1_INVALIDATE_ALL_WRITE_BLOCKED_REQ_READY);
        issue_invalidate_all_recovery_mmio_read_and_check(
            CPP_MODE1_INVALIDATE_ALL_RECOVERY_MMIO_READ_REQ_ADDR,
            CPP_MODE1_INVALIDATE_ALL_RECOVERY_MMIO_READ_REQ_SIZE,
            CPP_MODE1_INVALIDATE_ALL_RECOVERY_MMIO_READ_REQ_ID,
            CPP_MODE1_INVALIDATE_ALL_RECOVERY_MMIO_READ_ARADDR,
            CPP_MODE1_INVALIDATE_ALL_RECOVERY_MMIO_READ_ARLEN,
            CPP_MODE1_INVALIDATE_ALL_RECOVERY_MMIO_READ_ARSIZE,
            CPP_MODE1_INVALIDATE_ALL_RECOVERY_MMIO_READ_ARBURST,
            CPP_MODE1_INVALIDATE_ALL_RECOVERY_MMIO_READ_ARID,
            CPP_MODE1_INVALIDATE_ALL_RECOVERY_MMIO_READ_RBEAT0,
            CPP_MODE1_INVALIDATE_ALL_RECOVERY_MMIO_READ_RESP_ID,
            CPP_MODE1_INVALIDATE_ALL_RECOVERY_MMIO_READ_RESP_DATA);
        issue_invalidate_all_pending_mmio_read_and_check(
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_READ_REQ_ADDR,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_READ_REQ_SIZE,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_READ_REQ_ID,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_READ_ARADDR,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_READ_ARLEN,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_READ_ARSIZE,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_READ_ARBURST,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_READ_ARID,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_READ_RBEAT0,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_READ_RESP_ID,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_READ_RESP_DATA);
        issue_invalidate_all_pending_mmio_write_and_check(
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_WRITE_REQ_ADDR,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_WRITE_REQ_SIZE,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_WRITE_REQ_ID,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_WRITE_REQ_WDATA,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_WRITE_REQ_WSTRB,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_WRITE_AWADDR,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_WRITE_AWLEN,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_WRITE_AWSIZE,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_WRITE_AWBURST,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_WRITE_AWID,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_WRITE_BEATS,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_WRITE_WBEAT0,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_WRITE_WSTRB0,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_WRITE_WLAST0,
            {DDR_DATA_BITS{1'b0}},
            {DDR_STRB_BITS{1'b0}},
            1'b0,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_WRITE_RESP_ID,
            CPP_MODE1_INVALIDATE_ALL_PENDING_MMIO_WRITE_RESP_CODE);
        issue_invalidate_all_pending_mmio_rw_and_check();
        issue_invalidate_all_pre_ar_mmio_read_and_check(
            CPP_MODE1_INVALIDATE_ALL_PRE_AR_MMIO_READ_REQ_ADDR,
            CPP_MODE1_INVALIDATE_ALL_PRE_AR_MMIO_READ_REQ_SIZE,
            CPP_MODE1_INVALIDATE_ALL_PRE_AR_MMIO_READ_REQ_ID,
            CPP_MODE1_INVALIDATE_ALL_PRE_AR_MMIO_READ_ARADDR,
            CPP_MODE1_INVALIDATE_ALL_PRE_AR_MMIO_READ_ARLEN,
            CPP_MODE1_INVALIDATE_ALL_PRE_AR_MMIO_READ_ARSIZE,
            CPP_MODE1_INVALIDATE_ALL_PRE_AR_MMIO_READ_ARBURST,
            CPP_MODE1_INVALIDATE_ALL_PRE_AR_MMIO_READ_ARID,
            CPP_MODE1_INVALIDATE_ALL_PRE_AR_MMIO_READ_RBEAT0,
            CPP_MODE1_INVALIDATE_ALL_PRE_AR_MMIO_READ_RESP_ID,
            CPP_MODE1_INVALIDATE_ALL_PRE_AR_MMIO_READ_RESP_DATA);
        issue_invalidate_all_pre_aw_w_mmio_write_and_check(
            CPP_MODE1_INVALIDATE_ALL_PRE_AW_W_MMIO_WRITE_REQ_ADDR,
            CPP_MODE1_INVALIDATE_ALL_PRE_AW_W_MMIO_WRITE_REQ_SIZE,
            CPP_MODE1_INVALIDATE_ALL_PRE_AW_W_MMIO_WRITE_REQ_ID,
            CPP_MODE1_INVALIDATE_ALL_PRE_AW_W_MMIO_WRITE_REQ_WDATA,
            CPP_MODE1_INVALIDATE_ALL_PRE_AW_W_MMIO_WRITE_REQ_WSTRB,
            CPP_MODE1_INVALIDATE_ALL_PRE_AW_W_MMIO_WRITE_AWADDR,
            CPP_MODE1_INVALIDATE_ALL_PRE_AW_W_MMIO_WRITE_AWLEN,
            CPP_MODE1_INVALIDATE_ALL_PRE_AW_W_MMIO_WRITE_AWSIZE,
            CPP_MODE1_INVALIDATE_ALL_PRE_AW_W_MMIO_WRITE_AWBURST,
            CPP_MODE1_INVALIDATE_ALL_PRE_AW_W_MMIO_WRITE_AWID,
            CPP_MODE1_INVALIDATE_ALL_PRE_AW_W_MMIO_WRITE_BEATS,
            CPP_MODE1_INVALIDATE_ALL_PRE_AW_W_MMIO_WRITE_WBEAT0,
            CPP_MODE1_INVALIDATE_ALL_PRE_AW_W_MMIO_WRITE_WSTRB0,
            CPP_MODE1_INVALIDATE_ALL_PRE_AW_W_MMIO_WRITE_WLAST0,
            {DDR_DATA_BITS{1'b0}},
            {DDR_STRB_BITS{1'b0}},
            1'b0,
            CPP_MODE1_INVALIDATE_ALL_PRE_AW_W_MMIO_WRITE_RESP_ID,
            CPP_MODE1_INVALIDATE_ALL_PRE_AW_W_MMIO_WRITE_RESP_CODE);
        issue_mode1_to_mode2_mmio_read_and_check(
            CPP_MODE1_TO_MODE2_MMIO_ABOVE_READ4_REQ_ADDR,
            CPP_MODE1_TO_MODE2_MMIO_ABOVE_READ4_REQ_SIZE,
            CPP_MODE1_TO_MODE2_MMIO_ABOVE_READ4_REQ_ID,
            CPP_MODE1_TO_MODE2_MMIO_ABOVE_READ4_ARADDR,
            CPP_MODE1_TO_MODE2_MMIO_ABOVE_READ4_ARLEN,
            CPP_MODE1_TO_MODE2_MMIO_ABOVE_READ4_ARSIZE,
            CPP_MODE1_TO_MODE2_MMIO_ABOVE_READ4_ARBURST,
            CPP_MODE1_TO_MODE2_MMIO_ABOVE_READ4_ARID,
            CPP_MODE1_TO_MODE2_MMIO_ABOVE_READ4_RBEAT0,
            CPP_MODE1_TO_MODE2_MMIO_ABOVE_READ4_RESP_ID,
            CPP_MODE1_TO_MODE2_MMIO_ABOVE_READ4_RESP_DATA);

        $display("tb_axi_llc_subsystem_dual_cpp_trace_contract PASS");
        $finish(0);
    end

endmodule
