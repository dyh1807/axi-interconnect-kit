`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_dual_cpp_perf_contract;

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

    localparam [MODE_BITS-1:0] MODE_OFF = 2'b00;
    localparam [MODE_BITS-1:0] MODE_CACHE = 2'b01;
    localparam [1:0] AXI_RESP_OKAY = 2'b00;
    localparam PORT_DDR = 0;
    localparam PORT_MMIO = 1;
    localparam integer NON_HIT_MAX_EXTRA_CYCLES = 6;
    localparam integer LLC_MISS_MAX_EXTRA_CYCLES = 8;

`include "axi_dual_cpp_perf_vectors.vh"

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
    integer                            perf_failures;
    integer                            perf_exact_non_hit;
    integer                            perf_max_extra_cycles;

    always #5 clk = ~clk;

    task fail_now;
        input [8*240-1:0] msg;
        begin
            $display("tb_axi_llc_subsystem_dual_cpp_perf_contract FAIL: %0s", msg);
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
            repeat (4) @(posedge clk);
            @(negedge clk);
        end
    endtask

    task drive_read_req;
        input integer master;
        input [31:0] addr;
        input [7:0] size;
        input [3:0] id;
        begin
            read_req_valid[master] = 1'b1;
            read_req_addr[(master * ADDR_BITS) +: ADDR_BITS] = addr;
            read_req_total_size[(master * 8) +: 8] = size;
            read_req_id[(master * ID_BITS) +: ID_BITS] = id;
            read_req_bypass[master] = 1'b0;
        end
    endtask

    task drive_write_req;
        input integer master;
        input [31:0] addr;
        input [7:0] size;
        input [3:0] id;
        input [511:0] data;
        input [63:0] strobe;
        begin
            write_req_valid[master] = 1'b1;
            write_req_addr[(master * ADDR_BITS) +: ADDR_BITS] = addr;
            write_req_total_size[(master * 8) +: 8] = size;
            write_req_id[(master * ID_BITS) +: ID_BITS] = id;
            write_req_wdata[(master * LINE_BITS) +: LINE_BITS] = data;
            write_req_wstrb[(master * LINE_BYTES) +: LINE_BYTES] = strobe[LINE_BYTES-1:0];
            write_req_bypass[master] = 1'b0;
        end
    endtask

    task expect_cycle_with_max;
        input [8*160-1:0] label;
        input integer observed;
        input integer expected;
        input integer max_extra_cycles;
        integer extra;
        begin
            if (expected >= 0) begin
                if (observed < 0) begin
                    $display("tb_axi_llc_subsystem_dual_cpp_perf_contract MISMATCH: %0s expected_cycle=%0d observed_cycle=%0d missing_event=1",
                             label, expected, observed);
                    perf_failures = perf_failures + 1;
                end else if (perf_exact_non_hit && observed !== expected) begin
                    $display("tb_axi_llc_subsystem_dual_cpp_perf_contract MISMATCH: %0s expected_cycle=%0d observed_cycle=%0d",
                             label, expected, observed);
                    perf_failures = perf_failures + 1;
                end else if (!perf_exact_non_hit) begin
                    extra = observed - expected;
                    if (extra > max_extra_cycles) begin
                        $display("tb_axi_llc_subsystem_dual_cpp_perf_contract MISMATCH: %0s expected_cycle=%0d observed_cycle=%0d max_extra=%0d",
                                 label, expected, observed, max_extra_cycles);
                        perf_failures = perf_failures + 1;
                    end else if (extra > 0) begin
                        if (extra > perf_max_extra_cycles) begin
                            perf_max_extra_cycles = extra;
                        end
                        $display("tb_axi_llc_subsystem_dual_cpp_perf_contract DELTA_ACCEPTED: %0s expected_cycle=%0d observed_cycle=%0d extra=%0d max_extra=%0d",
                                 label, expected, observed, extra,
                                 max_extra_cycles);
                    end
                end
            end
        end
    endtask

    task expect_cycle;
        input [8*160-1:0] label;
        input integer observed;
        input integer expected;
        begin
            expect_cycle_with_max(label, observed, expected,
                                  NON_HIT_MAX_EXTRA_CYCLES);
        end
    endtask

    task expect_exact_cycle;
        input [8*160-1:0] label;
        input integer observed;
        input integer expected;
        begin
            if (observed !== expected) begin
                $display("tb_axi_llc_subsystem_dual_cpp_perf_contract MISMATCH: %0s expected_cycle=%0d observed_cycle=%0d",
                         label, expected, observed);
                perf_failures = perf_failures + 1;
            end
        end
    endtask

    task enter_mode_cache;
        integer timeout;
        begin
            @(negedge clk);
            mode_req = MODE_CACHE;
            timeout = 6000;
            while (((active_mode != MODE_CACHE) || reconfig_busy) &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("mode-cache transition did not settle");
            end
            repeat (4) @(posedge clk);
            @(negedge clk);
        end
    endtask

    task prefill_llc_hit_line;
        integer timeout;
        integer master;
        reg [AXI_ID_BITS-1:0] fill_arid;
        begin
            master = CPP_PERF_LLC_HIT_READ64_MASTER;
            @(negedge clk);
            clear_read_inputs();
            clear_write_inputs();
            clear_lower_inputs();
            read_resp_ready = {NUM_READ_MASTERS{1'b1}};
            drive_read_req(master,
                           CPP_PERF_LLC_HIT_READ64_REQ_ADDR,
                           CPP_PERF_LLC_HIT_READ64_REQ_SIZE,
                           CPP_PERF_LLC_HIT_READ64_FILL_REQ_ID);

            timeout = 240;
            while (!ddr_axi_arvalid && (timeout > 0)) begin
                @(posedge clk);
                #1;
                if (mmio_axi_arvalid || mmio_axi_awvalid || mmio_axi_wvalid ||
                    ddr_axi_awvalid || ddr_axi_wvalid) begin
                    fail_now("LLC hit prefill leaked to wrong AXI channel");
                end
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("LLC hit prefill AR timeout");
            end
            #1;
            fill_arid = ddr_axi_arid;
            @(posedge clk);
            @(negedge clk);
            clear_read_inputs();
            clear_lower_inputs();
            read_resp_ready = {NUM_READ_MASTERS{1'b1}};

            ddr_axi_rvalid = 1'b1;
            ddr_axi_rid = fill_arid;
            ddr_axi_rdata = 256'h1111_0007_1111_0006_1111_0005_1111_0004_1111_0003_1111_0002_1111_0001_1111_0000;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b0;
            #1;
            if (!ddr_axi_rready) begin
                fail_now("LLC hit prefill first R beat backpressured");
            end
            @(posedge clk);
            @(negedge clk);
            clear_lower_inputs();
            read_resp_ready = {NUM_READ_MASTERS{1'b1}};

            ddr_axi_rvalid = 1'b1;
            ddr_axi_rid = fill_arid;
            ddr_axi_rdata = 256'h2222_0007_2222_0006_2222_0005_2222_0004_2222_0003_2222_0002_2222_0001_2222_0000;
            ddr_axi_rresp = AXI_RESP_OKAY;
            ddr_axi_rlast = 1'b1;
            #1;
            if (!ddr_axi_rready) begin
                fail_now("LLC hit prefill second R beat backpressured");
            end
            @(posedge clk);
            @(negedge clk);
            clear_lower_inputs();
            read_resp_ready = {NUM_READ_MASTERS{1'b1}};

            timeout = 240;
            while (!read_resp_valid[master] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("LLC hit prefill response timeout");
            end
            #1;
            if (read_resp_id[(master * ID_BITS) +: ID_BITS] !=
                CPP_PERF_LLC_HIT_READ64_FILL_REQ_ID) begin
                fail_now("LLC hit prefill response id mismatch");
            end
            @(posedge clk);
            repeat (12) @(posedge clk);
            @(negedge clk);
        end
    endtask

    task run_llc_hit_perf_scenario;
        integer cycle;
        integer master;
        integer obs_ready;
        integer obs_resp;
        integer obs_external;
        reg request_active;
        begin
            reset_dut();
            enter_mode_cache();
            prefill_llc_hit_line();

            master = CPP_PERF_LLC_HIT_READ64_MASTER;
            obs_ready = -1;
            obs_resp = -1;
            obs_external = -1;
            request_active = 1'b1;

            for (cycle = 0; cycle < 80; cycle = cycle + 1) begin
                @(negedge clk);
                clear_read_inputs();
                clear_write_inputs();
                clear_lower_inputs();
                read_resp_ready = {NUM_READ_MASTERS{1'b1}};
                write_resp_ready = {NUM_WRITE_MASTERS{1'b1}};

                if (request_active) begin
                    drive_read_req(master,
                                   CPP_PERF_LLC_HIT_READ64_REQ_ADDR,
                                   CPP_PERF_LLC_HIT_READ64_REQ_SIZE,
                                   CPP_PERF_LLC_HIT_READ64_REQ_ID);
                end

                #1;
                if (request_active && read_req_ready[master] &&
                    obs_ready < 0) begin
                    obs_ready = cycle;
                    request_active = 1'b0;
                end
                if ((ddr_axi_arvalid || ddr_axi_awvalid || ddr_axi_wvalid ||
                     mmio_axi_arvalid || mmio_axi_awvalid || mmio_axi_wvalid) &&
                    obs_external < 0) begin
                    obs_external = cycle;
                end
                if (read_resp_valid[master] &&
                    read_resp_ready[master] &&
                    read_resp_id[(master * ID_BITS) +: ID_BITS] ==
                        CPP_PERF_LLC_HIT_READ64_REQ_ID &&
                    obs_resp < 0) begin
                    obs_resp = cycle;
                end

                @(posedge clk);
            end

            expect_exact_cycle("LLC_HIT_READ64 ready",
                               obs_ready,
                               CPP_PERF_LLC_HIT_READ64_REQ_READY_CYCLE);
            expect_exact_cycle("LLC_HIT_READ64 resp",
                               obs_resp,
                               CPP_PERF_LLC_HIT_READ64_RESP_CYCLE);
            if (CPP_PERF_LLC_HIT_READ64_NO_EXTERNAL != 1) begin
                fail_now("C++ LLC hit expected to issue external AXI");
            end
            expect_exact_cycle("LLC_HIT_READ64 external",
                               obs_external,
                               CPP_PERF_LLC_HIT_READ64_EXTERNAL_CYCLE);
            $display("PERF LLC_HIT_READ64 CHECKED ready=%0d resp=%0d external=%0d",
                     obs_ready, obs_resp, obs_external);
        end
    endtask

    task run_llc_write_hit_perf_scenario;
        integer cycle;
        integer master;
        integer obs_ready;
        integer obs_resp;
        integer obs_external;
        reg request_active;
        reg request_accepted;
        begin
            reset_dut();
            enter_mode_cache();
            prefill_llc_hit_line();

            master = CPP_PERF_LLC_HIT_WRITE64_MASTER;
            obs_ready = -1;
            obs_resp = -1;
            obs_external = -1;
            request_active = 1'b1;
            request_accepted = 1'b0;

            for (cycle = 0; cycle < 80; cycle = cycle + 1) begin
                @(negedge clk);
                clear_read_inputs();
                clear_write_inputs();
                clear_lower_inputs();
                read_resp_ready = {NUM_READ_MASTERS{1'b1}};
                write_resp_ready = {NUM_WRITE_MASTERS{1'b1}};

                if (request_active && !request_accepted) begin
                    drive_write_req(master,
                                    CPP_PERF_LLC_HIT_WRITE64_REQ_ADDR,
                                    CPP_PERF_LLC_HIT_WRITE64_REQ_SIZE,
                                    CPP_PERF_LLC_HIT_WRITE64_REQ_ID,
                                    CPP_PERF_LLC_HIT_WRITE64_REQ_WDATA,
                                    CPP_PERF_LLC_HIT_WRITE64_REQ_WSTRB);
                end

                #1;
                if (request_active && write_req_ready[master] &&
                    obs_ready < 0) begin
                    obs_ready = cycle;
                end
                if (write_req_accepted[master]) begin
                    request_accepted = 1'b1;
                    request_active = 1'b0;
                end
                if ((ddr_axi_arvalid || ddr_axi_awvalid || ddr_axi_wvalid ||
                     mmio_axi_arvalid || mmio_axi_awvalid || mmio_axi_wvalid) &&
                    obs_external < 0) begin
                    obs_external = cycle;
                end
                if (write_resp_valid[master] &&
                    write_resp_ready[master] &&
                    write_resp_id[(master * ID_BITS) +: ID_BITS] ==
                        CPP_PERF_LLC_HIT_WRITE64_REQ_ID &&
                    obs_resp < 0) begin
                    obs_resp = cycle;
                end

                @(posedge clk);
            end

            expect_exact_cycle("LLC_HIT_WRITE64 ready",
                               obs_ready,
                               CPP_PERF_LLC_HIT_WRITE64_REQ_READY_CYCLE);
            expect_exact_cycle("LLC_HIT_WRITE64 resp",
                               obs_resp,
                               CPP_PERF_LLC_HIT_WRITE64_RESP_CYCLE);
            if (CPP_PERF_LLC_HIT_WRITE64_NO_EXTERNAL != 1) begin
                fail_now("C++ LLC write hit expected to issue external AXI");
            end
            expect_exact_cycle("LLC_HIT_WRITE64 external",
                               obs_external,
                               CPP_PERF_LLC_HIT_WRITE64_EXTERNAL_CYCLE);
            $display("PERF LLC_HIT_WRITE64 CHECKED ready=%0d resp=%0d external=%0d",
                     obs_ready, obs_resp, obs_external);
        end
    endtask

    task run_llc_miss_perf_scenario;
        integer cycle;
        integer master;
        integer obs_ready;
        integer obs_ar;
        integer obs_r0;
        integer obs_r1;
        integer obs_resp;
        integer ddr_r_due0;
        integer ddr_r_due1;
        integer ddr_r_count;
        reg request_active;
        reg ar_done;
        reg [AXI_ID_BITS-1:0] ddr_rid;
        begin
            reset_dut();
            enter_mode_cache();

            master = CPP_PERF_LLC_MISS_READ64_MASTER;
            obs_ready = -1;
            obs_ar = -1;
            obs_r0 = -1;
            obs_r1 = -1;
            obs_resp = -1;
            ddr_r_due0 = -1;
            ddr_r_due1 = -1;
            ddr_r_count = 0;
            request_active = 1'b1;
            ar_done = 1'b0;
            ddr_rid = {AXI_ID_BITS{1'b0}};

            for (cycle = 0; cycle < 120; cycle = cycle + 1) begin
                @(negedge clk);
                clear_read_inputs();
                clear_write_inputs();
                clear_lower_inputs();
                read_resp_ready = {NUM_READ_MASTERS{1'b1}};
                write_resp_ready = {NUM_WRITE_MASTERS{1'b1}};

                if (request_active) begin
                    drive_read_req(master,
                                   CPP_PERF_LLC_MISS_READ64_REQ_ADDR,
                                   CPP_PERF_LLC_MISS_READ64_REQ_SIZE,
                                   CPP_PERF_LLC_MISS_READ64_REQ_ID);
                end

                if (ddr_r_due0 == cycle) begin
                    ddr_axi_rvalid = 1'b1;
                    ddr_axi_rid = ddr_rid;
                    ddr_axi_rdata = 256'h1111_0007_1111_0006_1111_0005_1111_0004_1111_0003_1111_0002_1111_0001_1111_0000;
                    ddr_axi_rresp = AXI_RESP_OKAY;
                    ddr_axi_rlast = 1'b0;
                end else if (ddr_r_due1 == cycle) begin
                    ddr_axi_rvalid = 1'b1;
                    ddr_axi_rid = ddr_rid;
                    ddr_axi_rdata = 256'h2222_0007_2222_0006_2222_0005_2222_0004_2222_0003_2222_0002_2222_0001_2222_0000;
                    ddr_axi_rresp = AXI_RESP_OKAY;
                    ddr_axi_rlast = 1'b1;
                end

                #1;

                if (request_active && read_req_ready[master] &&
                    obs_ready < 0) begin
                    obs_ready = cycle;
                    request_active = 1'b0;
                end

                if (ddr_axi_arvalid && ddr_axi_arready && !ar_done) begin
                    obs_ar = cycle;
                    ar_done = 1'b1;
                    ddr_rid = ddr_axi_arid;
                    if (ddr_axi_arlen != (CPP_PERF_LLC_MISS_READ64_BEATS - 1)) begin
                        fail_now("LLC miss AR beat count mismatch");
                    end
                    ddr_r_due0 = cycle + CPP_PERF_READ_LATENCY;
                    if (CPP_PERF_LLC_MISS_READ64_BEATS > 1) begin
                        ddr_r_due1 = cycle + CPP_PERF_READ_LATENCY + 1;
                    end
                end else if (ddr_axi_arvalid && ddr_axi_arready) begin
                    fail_now("unexpected second DDR AR in LLC miss perf scenario");
                end

                if (mmio_axi_arvalid || ddr_axi_awvalid || ddr_axi_wvalid ||
                    mmio_axi_awvalid || mmio_axi_wvalid) begin
                    fail_now("LLC clean read miss issued unexpected external channel");
                end

                if (ddr_axi_rvalid) begin
                    if (!ddr_axi_rready) begin
                        fail_now("LLC miss lower R beat was backpressured");
                    end
                    if (ddr_r_count == 0) begin
                        obs_r0 = cycle;
                    end else if (ddr_r_count == 1) begin
                        obs_r1 = cycle;
                    end else begin
                        fail_now("unexpected extra DDR R beat in LLC miss perf scenario");
                    end
                    ddr_r_count = ddr_r_count + 1;
                end

                if (read_resp_valid[master] &&
                    read_resp_ready[master] &&
                    read_resp_id[(master * ID_BITS) +: ID_BITS] ==
                        CPP_PERF_LLC_MISS_READ64_REQ_ID &&
                    obs_resp < 0) begin
                    obs_resp = cycle;
                end

                @(posedge clk);
            end

            expect_cycle_with_max("LLC_MISS_READ64 ready",
                                  obs_ready,
                                  CPP_PERF_LLC_MISS_READ64_REQ_READY_CYCLE,
                                  LLC_MISS_MAX_EXTRA_CYCLES);
            expect_cycle_with_max("LLC_MISS_READ64 ar",
                                  obs_ar,
                                  CPP_PERF_LLC_MISS_READ64_AR_CYCLE,
                                  LLC_MISS_MAX_EXTRA_CYCLES);
            expect_cycle_with_max("LLC_MISS_READ64 r0",
                                  obs_r0,
                                  CPP_PERF_LLC_MISS_READ64_R0_CYCLE,
                                  LLC_MISS_MAX_EXTRA_CYCLES);
            expect_cycle_with_max("LLC_MISS_READ64 r1",
                                  obs_r1,
                                  CPP_PERF_LLC_MISS_READ64_R1_CYCLE,
                                  LLC_MISS_MAX_EXTRA_CYCLES);
            expect_cycle_with_max("LLC_MISS_READ64 resp",
                                  obs_resp,
                                  CPP_PERF_LLC_MISS_READ64_RESP_CYCLE,
                                  LLC_MISS_MAX_EXTRA_CYCLES);
            $display("PERF LLC_MISS_READ64 CHECKED ready=%0d ar=%0d r0=%0d r1=%0d resp=%0d",
                     obs_ready, obs_ar, obs_r0, obs_r1, obs_resp);
        end
    endtask

    task run_perf_scenario;
        input [8*120-1:0] scenario_name;
        input has_rd0;
        input integer rd0_master;
        input integer rd0_port;
        input [31:0] rd0_addr;
        input [7:0] rd0_size;
        input [3:0] rd0_id;
        input integer rd0_beats;
        input integer exp_rd0_ready;
        input integer exp_rd0_ar;
        input integer exp_rd0_r0;
        input integer exp_rd0_r1;
        input integer exp_rd0_resp;
        input has_rd1;
        input integer rd1_master;
        input integer rd1_port;
        input [31:0] rd1_addr;
        input [7:0] rd1_size;
        input [3:0] rd1_id;
        input integer rd1_beats;
        input integer exp_rd1_ready;
        input integer exp_rd1_ar;
        input integer exp_rd1_r0;
        input integer exp_rd1_r1;
        input integer exp_rd1_resp;
        input has_wr0;
        input integer wr0_master;
        input integer wr0_port;
        input [31:0] wr0_addr;
        input [7:0] wr0_size;
        input [3:0] wr0_id;
        input [511:0] wr0_data;
        input [63:0] wr0_strobe;
        input integer wr0_beats;
        input integer exp_wr0_ready;
        input integer exp_wr0_aw;
        input integer exp_wr0_w0;
        input integer exp_wr0_w1;
        input integer exp_wr0_b;
        input integer exp_wr0_resp;
        input has_wr1;
        input integer wr1_master;
        input integer wr1_port;
        input [31:0] wr1_addr;
        input [7:0] wr1_size;
        input [3:0] wr1_id;
        input [511:0] wr1_data;
        input [63:0] wr1_strobe;
        input integer wr1_beats;
        input integer exp_wr1_ready;
        input integer exp_wr1_aw;
        input integer exp_wr1_w0;
        input integer exp_wr1_w1;
        input integer exp_wr1_b;
        input integer exp_wr1_resp;
        integer cycle;
        integer obs_rd0_ready;
        integer obs_rd0_ar;
        integer obs_rd0_r0;
        integer obs_rd0_r1;
        integer obs_rd0_resp;
        integer obs_rd1_ready;
        integer obs_rd1_ar;
        integer obs_rd1_r0;
        integer obs_rd1_r1;
        integer obs_rd1_resp;
        integer obs_wr0_ready;
        integer obs_wr0_aw;
        integer obs_wr0_w0;
        integer obs_wr0_w1;
        integer obs_wr0_b;
        integer obs_wr0_resp;
        integer obs_wr1_ready;
        integer obs_wr1_aw;
        integer obs_wr1_w0;
        integer obs_wr1_w1;
        integer obs_wr1_b;
        integer obs_wr1_resp;
        reg rd0_ar_done;
        reg rd1_ar_done;
        reg wr0_aw_done;
        reg wr1_aw_done;
        integer rd0_r_count;
        integer rd1_r_count;
        integer wr0_w_count;
        integer wr1_w_count;
        integer ddr_r_due0;
        integer ddr_r_due1;
        integer mmio_r_due0;
        integer mmio_r_due1;
        integer ddr_b_due;
        integer mmio_b_due;
        integer ddr_r_owner;
        integer mmio_r_owner;
        integer ddr_b_owner;
        integer mmio_b_owner;
        reg [AXI_ID_BITS-1:0] ddr_rid;
        reg [AXI_ID_BITS-1:0] mmio_rid;
        reg [AXI_ID_BITS-1:0] ddr_bid;
        reg [AXI_ID_BITS-1:0] mmio_bid;
        integer ddr_r_beats;
        integer mmio_r_beats;
        reg [DDR_DATA_BITS-1:0] ddr_rdata0;
        reg [DDR_DATA_BITS-1:0] ddr_rdata1;
        begin
            reset_dut();
            obs_rd0_ready = -1; obs_rd0_ar = -1; obs_rd0_r0 = -1; obs_rd0_r1 = -1; obs_rd0_resp = -1;
            obs_rd1_ready = -1; obs_rd1_ar = -1; obs_rd1_r0 = -1; obs_rd1_r1 = -1; obs_rd1_resp = -1;
            obs_wr0_ready = -1; obs_wr0_aw = -1; obs_wr0_w0 = -1; obs_wr0_w1 = -1; obs_wr0_b = -1; obs_wr0_resp = -1;
            obs_wr1_ready = -1; obs_wr1_aw = -1; obs_wr1_w0 = -1; obs_wr1_w1 = -1; obs_wr1_b = -1; obs_wr1_resp = -1;
            rd0_ar_done = 1'b0; rd1_ar_done = 1'b0; wr0_aw_done = 1'b0; wr1_aw_done = 1'b0;
            rd0_r_count = 0; rd1_r_count = 0; wr0_w_count = 0; wr1_w_count = 0;
            ddr_r_due0 = -1; ddr_r_due1 = -1; mmio_r_due0 = -1; mmio_r_due1 = -1;
            ddr_b_due = -1; mmio_b_due = -1;
            ddr_r_owner = -1; mmio_r_owner = -1; ddr_b_owner = -1; mmio_b_owner = -1;
            ddr_rid = {AXI_ID_BITS{1'b0}}; mmio_rid = {AXI_ID_BITS{1'b0}};
            ddr_bid = {AXI_ID_BITS{1'b0}}; mmio_bid = {AXI_ID_BITS{1'b0}};
            ddr_r_beats = 0; mmio_r_beats = 0;
            ddr_rdata0 = 256'h1111_0007_1111_0006_1111_0005_1111_0004_1111_0003_1111_0002_1111_0001_1111_0000;
            ddr_rdata1 = 256'h2222_0007_2222_0006_2222_0005_2222_0004_2222_0003_2222_0002_2222_0001_2222_0000;

            for (cycle = 0; cycle < 80; cycle = cycle + 1) begin
                @(negedge clk);
                clear_read_inputs();
                clear_write_inputs();
                clear_lower_inputs();
                read_resp_ready = {NUM_READ_MASTERS{1'b1}};
                write_resp_ready = {NUM_WRITE_MASTERS{1'b1}};

                if (has_rd0 && !rd0_ar_done) begin
                    drive_read_req(rd0_master, rd0_addr, rd0_size, rd0_id);
                end
                if (has_rd1 && !rd1_ar_done) begin
                    drive_read_req(rd1_master, rd1_addr, rd1_size, rd1_id);
                end
                if (has_wr0 && !wr0_aw_done) begin
                    drive_write_req(wr0_master, wr0_addr, wr0_size, wr0_id,
                                    wr0_data, wr0_strobe);
                end
                if (has_wr1 && !wr1_aw_done) begin
                    drive_write_req(wr1_master, wr1_addr, wr1_size, wr1_id,
                                    wr1_data, wr1_strobe);
                end

                if (ddr_r_due0 == cycle) begin
                    ddr_axi_rvalid = 1'b1;
                    ddr_axi_rid = ddr_rid;
                    ddr_axi_rdata = ddr_rdata0;
                    ddr_axi_rlast = (ddr_r_beats == 1);
                end else if (ddr_r_due1 == cycle) begin
                    ddr_axi_rvalid = 1'b1;
                    ddr_axi_rid = ddr_rid;
                    ddr_axi_rdata = ddr_rdata1;
                    ddr_axi_rlast = 1'b1;
                end
                if (mmio_r_due0 == cycle) begin
                    mmio_axi_rvalid = 1'b1;
                    mmio_axi_rid = mmio_rid;
                    mmio_axi_rdata = 32'h3333_0000;
                    mmio_axi_rlast = 1'b1;
                end
                if (ddr_b_due == cycle) begin
                    ddr_axi_bvalid = 1'b1;
                    ddr_axi_bid = ddr_bid;
                end
                if (mmio_b_due == cycle) begin
                    mmio_axi_bvalid = 1'b1;
                    mmio_axi_bid = mmio_bid;
                end

                #1;

                if (has_rd0 && !rd0_ar_done && read_req_ready[rd0_master] && obs_rd0_ready < 0) obs_rd0_ready = cycle;
                if (has_rd1 && !rd1_ar_done && read_req_ready[rd1_master] && obs_rd1_ready < 0) obs_rd1_ready = cycle;
                if (has_wr0 && !wr0_aw_done && write_req_ready[wr0_master] && obs_wr0_ready < 0) obs_wr0_ready = cycle;
                if (has_wr1 && !wr1_aw_done && write_req_ready[wr1_master] && obs_wr1_ready < 0) obs_wr1_ready = cycle;

                if (ddr_axi_arvalid && ddr_axi_arready) begin
                    if (has_rd0 && rd0_port == PORT_DDR && !rd0_ar_done) begin
                        obs_rd0_ar = cycle;
                        rd0_ar_done = 1'b1;
                        ddr_r_owner = 0;
                        ddr_rid = ddr_axi_arid;
                        ddr_r_beats = rd0_beats;
                    end else if (has_rd1 && rd1_port == PORT_DDR && !rd1_ar_done) begin
                        obs_rd1_ar = cycle;
                        rd1_ar_done = 1'b1;
                        ddr_r_owner = 1;
                        ddr_rid = ddr_axi_arid;
                        ddr_r_beats = rd1_beats;
                    end else begin
                        fail_now("unexpected DDR AR in perf scenario");
                    end
                    ddr_r_due0 = cycle + CPP_PERF_READ_LATENCY;
                    if (ddr_r_beats > 1) ddr_r_due1 = cycle + CPP_PERF_READ_LATENCY + 1;
                end
                if (mmio_axi_arvalid && mmio_axi_arready) begin
                    if (has_rd0 && rd0_port == PORT_MMIO && !rd0_ar_done) begin
                        obs_rd0_ar = cycle;
                        rd0_ar_done = 1'b1;
                        mmio_r_owner = 0;
                        mmio_rid = mmio_axi_arid;
                        mmio_r_beats = rd0_beats;
                    end else if (has_rd1 && rd1_port == PORT_MMIO && !rd1_ar_done) begin
                        obs_rd1_ar = cycle;
                        rd1_ar_done = 1'b1;
                        mmio_r_owner = 1;
                        mmio_rid = mmio_axi_arid;
                        mmio_r_beats = rd1_beats;
                    end else begin
                        fail_now("unexpected MMIO AR in perf scenario");
                    end
                    mmio_r_due0 = cycle + CPP_PERF_READ_LATENCY;
                    if (mmio_r_beats > 1) mmio_r_due1 = cycle + CPP_PERF_READ_LATENCY + 1;
                end

                if (ddr_axi_awvalid && ddr_axi_awready) begin
                    if (has_wr0 && wr0_port == PORT_DDR && !wr0_aw_done) begin
                        obs_wr0_aw = cycle;
                        wr0_aw_done = 1'b1;
                        ddr_b_owner = 0;
                    end else if (has_wr1 && wr1_port == PORT_DDR && !wr1_aw_done) begin
                        obs_wr1_aw = cycle;
                        wr1_aw_done = 1'b1;
                        ddr_b_owner = 1;
                    end else begin
                        fail_now("unexpected DDR AW in perf scenario");
                    end
                    ddr_bid = ddr_axi_awid;
                end
                if (mmio_axi_awvalid && mmio_axi_awready) begin
                    if (has_wr0 && wr0_port == PORT_MMIO && !wr0_aw_done) begin
                        obs_wr0_aw = cycle;
                        wr0_aw_done = 1'b1;
                        mmio_b_owner = 0;
                    end else if (has_wr1 && wr1_port == PORT_MMIO && !wr1_aw_done) begin
                        obs_wr1_aw = cycle;
                        wr1_aw_done = 1'b1;
                        mmio_b_owner = 1;
                    end else begin
                        fail_now("unexpected MMIO AW in perf scenario");
                    end
                    mmio_bid = mmio_axi_awid;
                end

                if (ddr_axi_wvalid && ddr_axi_wready) begin
                    if (ddr_b_owner == 0) begin
                        if (wr0_w_count == 0) obs_wr0_w0 = cycle;
                        if (wr0_w_count == 1) obs_wr0_w1 = cycle;
                        wr0_w_count = wr0_w_count + 1;
                    end else if (ddr_b_owner == 1) begin
                        if (wr1_w_count == 0) obs_wr1_w0 = cycle;
                        if (wr1_w_count == 1) obs_wr1_w1 = cycle;
                        wr1_w_count = wr1_w_count + 1;
                    end else begin
                        fail_now("unexpected DDR W in perf scenario");
                    end
                    if (ddr_axi_wlast) ddr_b_due = cycle + CPP_PERF_WRITE_RESP_LATENCY;
                end
                if (mmio_axi_wvalid && mmio_axi_wready) begin
                    if (mmio_b_owner == 0) begin
                        if (wr0_w_count == 0) obs_wr0_w0 = cycle;
                        if (wr0_w_count == 1) obs_wr0_w1 = cycle;
                        wr0_w_count = wr0_w_count + 1;
                    end else if (mmio_b_owner == 1) begin
                        if (wr1_w_count == 0) obs_wr1_w0 = cycle;
                        if (wr1_w_count == 1) obs_wr1_w1 = cycle;
                        wr1_w_count = wr1_w_count + 1;
                    end else begin
                        fail_now("unexpected MMIO W in perf scenario");
                    end
                    if (mmio_axi_wlast) mmio_b_due = cycle + CPP_PERF_WRITE_RESP_LATENCY;
                end

                if (ddr_axi_rvalid && ddr_axi_rready) begin
                    if (ddr_r_owner == 0) begin
                        if (rd0_r_count == 0) obs_rd0_r0 = cycle;
                        if (rd0_r_count == 1) obs_rd0_r1 = cycle;
                        rd0_r_count = rd0_r_count + 1;
                    end else if (ddr_r_owner == 1) begin
                        if (rd1_r_count == 0) obs_rd1_r0 = cycle;
                        if (rd1_r_count == 1) obs_rd1_r1 = cycle;
                        rd1_r_count = rd1_r_count + 1;
                    end else begin
                        fail_now("unexpected DDR R in perf scenario");
                    end
                end
                if (mmio_axi_rvalid && mmio_axi_rready) begin
                    if (mmio_r_owner == 0) begin
                        if (rd0_r_count == 0) obs_rd0_r0 = cycle;
                        if (rd0_r_count == 1) obs_rd0_r1 = cycle;
                        rd0_r_count = rd0_r_count + 1;
                    end else if (mmio_r_owner == 1) begin
                        if (rd1_r_count == 0) obs_rd1_r0 = cycle;
                        if (rd1_r_count == 1) obs_rd1_r1 = cycle;
                        rd1_r_count = rd1_r_count + 1;
                    end else begin
                        fail_now("unexpected MMIO R in perf scenario");
                    end
                end

                if (ddr_axi_bvalid && ddr_axi_bready) begin
                    if (ddr_b_owner == 0) obs_wr0_b = cycle;
                    else if (ddr_b_owner == 1) obs_wr1_b = cycle;
                    else fail_now("unexpected DDR B in perf scenario");
                end
                if (mmio_axi_bvalid && mmio_axi_bready) begin
                    if (mmio_b_owner == 0) obs_wr0_b = cycle;
                    else if (mmio_b_owner == 1) obs_wr1_b = cycle;
                    else fail_now("unexpected MMIO B in perf scenario");
                end

                if (has_rd0 && read_resp_valid[rd0_master] &&
                    read_resp_ready[rd0_master] &&
                    read_resp_id[(rd0_master * ID_BITS) +: ID_BITS] == rd0_id &&
                    obs_rd0_resp < 0) obs_rd0_resp = cycle;
                if (has_rd1 && read_resp_valid[rd1_master] &&
                    read_resp_ready[rd1_master] &&
                    read_resp_id[(rd1_master * ID_BITS) +: ID_BITS] == rd1_id &&
                    obs_rd1_resp < 0) obs_rd1_resp = cycle;
                if (has_wr0 && write_resp_valid[wr0_master] &&
                    write_resp_ready[wr0_master] &&
                    write_resp_id[(wr0_master * ID_BITS) +: ID_BITS] == wr0_id &&
                    obs_wr0_resp < 0) obs_wr0_resp = cycle;
                if (has_wr1 && write_resp_valid[wr1_master] &&
                    write_resp_ready[wr1_master] &&
                    write_resp_id[(wr1_master * ID_BITS) +: ID_BITS] == wr1_id &&
                    obs_wr1_resp < 0) obs_wr1_resp = cycle;

                @(posedge clk);
            end

            expect_cycle({scenario_name, " rd0 ready"}, obs_rd0_ready, exp_rd0_ready);
            expect_cycle({scenario_name, " rd0 ar"}, obs_rd0_ar, exp_rd0_ar);
            expect_cycle({scenario_name, " rd0 r0"}, obs_rd0_r0, exp_rd0_r0);
            expect_cycle({scenario_name, " rd0 r1"}, obs_rd0_r1, exp_rd0_r1);
            expect_cycle({scenario_name, " rd0 resp"}, obs_rd0_resp, exp_rd0_resp);
            expect_cycle({scenario_name, " rd1 ready"}, obs_rd1_ready, exp_rd1_ready);
            expect_cycle({scenario_name, " rd1 ar"}, obs_rd1_ar, exp_rd1_ar);
            expect_cycle({scenario_name, " rd1 r0"}, obs_rd1_r0, exp_rd1_r0);
            expect_cycle({scenario_name, " rd1 r1"}, obs_rd1_r1, exp_rd1_r1);
            expect_cycle({scenario_name, " rd1 resp"}, obs_rd1_resp, exp_rd1_resp);
            expect_cycle({scenario_name, " wr0 ready"}, obs_wr0_ready, exp_wr0_ready);
            expect_cycle({scenario_name, " wr0 aw"}, obs_wr0_aw, exp_wr0_aw);
            expect_cycle({scenario_name, " wr0 w0"}, obs_wr0_w0, exp_wr0_w0);
            expect_cycle({scenario_name, " wr0 w1"}, obs_wr0_w1, exp_wr0_w1);
            expect_cycle({scenario_name, " wr0 b"}, obs_wr0_b, exp_wr0_b);
            expect_cycle({scenario_name, " wr0 resp"}, obs_wr0_resp, exp_wr0_resp);
            expect_cycle({scenario_name, " wr1 ready"}, obs_wr1_ready, exp_wr1_ready);
            expect_cycle({scenario_name, " wr1 aw"}, obs_wr1_aw, exp_wr1_aw);
            expect_cycle({scenario_name, " wr1 w0"}, obs_wr1_w0, exp_wr1_w0);
            expect_cycle({scenario_name, " wr1 w1"}, obs_wr1_w1, exp_wr1_w1);
            expect_cycle({scenario_name, " wr1 b"}, obs_wr1_b, exp_wr1_b);
            expect_cycle({scenario_name, " wr1 resp"}, obs_wr1_resp, exp_wr1_resp);
            $display("PERF %0s CHECKED", scenario_name);
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
        perf_failures = 0;
        perf_exact_non_hit = $test$plusargs("CPP_PERF_EXACT_NON_HIT");
        perf_max_extra_cycles = 0;
        if ($test$plusargs("LLC_HIT_ONLY")) begin
            perf_exact_non_hit = 1;
            run_llc_hit_perf_scenario();
            run_llc_write_hit_perf_scenario();
            if (perf_failures != 0) begin
                $display("tb_axi_llc_subsystem_dual_cpp_perf_contract FAIL: llc_hit_mismatches=%0d",
                         perf_failures);
                $finish(1);
            end
            $display("tb_axi_llc_subsystem_dual_cpp_perf_contract PASS LLC_HIT_ONLY");
            $finish;
        end
        if ($test$plusargs("LLC_MISS_ONLY")) begin
            run_llc_miss_perf_scenario();
            if (perf_failures != 0) begin
                $display("tb_axi_llc_subsystem_dual_cpp_perf_contract FAIL: llc_miss_mismatches=%0d",
                         perf_failures);
                $finish(1);
            end
            $display("tb_axi_llc_subsystem_dual_cpp_perf_contract PASS LLC_MISS_ONLY max_extra_observed=%0d max_extra_allowed=%0d",
                     perf_max_extra_cycles, LLC_MISS_MAX_EXTRA_CYCLES);
            $finish;
        end

        run_llc_miss_perf_scenario();

        run_perf_scenario("READ64_DDR",
                          1'b1,
                          CPP_PERF_READ64_DDR_MASTER,
                          CPP_PERF_READ64_DDR_PORT,
                          CPP_PERF_READ64_DDR_REQ_ADDR,
                          CPP_PERF_READ64_DDR_REQ_SIZE,
                          CPP_PERF_READ64_DDR_REQ_ID,
                          CPP_PERF_READ64_DDR_BEATS,
                          CPP_PERF_READ64_DDR_REQ_READY_CYCLE,
                          CPP_PERF_READ64_DDR_AR_CYCLE,
                          CPP_PERF_READ64_DDR_R0_CYCLE,
                          CPP_PERF_READ64_DDR_R1_CYCLE,
                          CPP_PERF_READ64_DDR_RESP_CYCLE,
                          1'b0, 0, 0, 32'h0, 8'h0, 4'h0, 0, -1, -1, -1, -1, -1,
                          1'b0, 0, 0, 32'h0, 8'h0, 4'h0, 512'h0, 64'h0, 0, -1, -1, -1, -1, -1, -1,
                          1'b0, 0, 0, 32'h0, 8'h0, 4'h0, 512'h0, 64'h0, 0, -1, -1, -1, -1, -1, -1);

        run_perf_scenario("READ32_DDR",
                          1'b1,
                          CPP_PERF_READ32_DDR_MASTER,
                          CPP_PERF_READ32_DDR_PORT,
                          CPP_PERF_READ32_DDR_REQ_ADDR,
                          CPP_PERF_READ32_DDR_REQ_SIZE,
                          CPP_PERF_READ32_DDR_REQ_ID,
                          CPP_PERF_READ32_DDR_BEATS,
                          CPP_PERF_READ32_DDR_REQ_READY_CYCLE,
                          CPP_PERF_READ32_DDR_AR_CYCLE,
                          CPP_PERF_READ32_DDR_R0_CYCLE,
                          CPP_PERF_READ32_DDR_R1_CYCLE,
                          CPP_PERF_READ32_DDR_RESP_CYCLE,
                          1'b0, 0, 0, 32'h0, 8'h0, 4'h0, 0, -1, -1, -1, -1, -1,
                          1'b0, 0, 0, 32'h0, 8'h0, 4'h0, 512'h0, 64'h0, 0, -1, -1, -1, -1, -1, -1,
                          1'b0, 0, 0, 32'h0, 8'h0, 4'h0, 512'h0, 64'h0, 0, -1, -1, -1, -1, -1, -1);

        run_perf_scenario("READ32_MMIO",
                          1'b1,
                          CPP_PERF_READ32_MMIO_MASTER,
                          CPP_PERF_READ32_MMIO_PORT,
                          CPP_PERF_READ32_MMIO_REQ_ADDR,
                          CPP_PERF_READ32_MMIO_REQ_SIZE,
                          CPP_PERF_READ32_MMIO_REQ_ID,
                          CPP_PERF_READ32_MMIO_BEATS,
                          CPP_PERF_READ32_MMIO_REQ_READY_CYCLE,
                          CPP_PERF_READ32_MMIO_AR_CYCLE,
                          CPP_PERF_READ32_MMIO_R0_CYCLE,
                          CPP_PERF_READ32_MMIO_R1_CYCLE,
                          CPP_PERF_READ32_MMIO_RESP_CYCLE,
                          1'b0, 0, 0, 32'h0, 8'h0, 4'h0, 0, -1, -1, -1, -1, -1,
                          1'b0, 0, 0, 32'h0, 8'h0, 4'h0, 512'h0, 64'h0, 0, -1, -1, -1, -1, -1, -1,
                          1'b0, 0, 0, 32'h0, 8'h0, 4'h0, 512'h0, 64'h0, 0, -1, -1, -1, -1, -1, -1);

        run_perf_scenario("WRITE64_DDR",
                          1'b0, 0, 0, 32'h0, 8'h0, 4'h0, 0, -1, -1, -1, -1, -1,
                          1'b0, 0, 0, 32'h0, 8'h0, 4'h0, 0, -1, -1, -1, -1, -1,
                          1'b1,
                          CPP_PERF_WRITE64_DDR_MASTER,
                          CPP_PERF_WRITE64_DDR_PORT,
                          CPP_PERF_WRITE64_DDR_REQ_ADDR,
                          CPP_PERF_WRITE64_DDR_REQ_SIZE,
                          CPP_PERF_WRITE64_DDR_REQ_ID,
                          CPP_PERF_WRITE64_DDR_REQ_WDATA,
                          CPP_PERF_WRITE64_DDR_REQ_WSTRB,
                          CPP_PERF_WRITE64_DDR_BEATS,
                          CPP_PERF_WRITE64_DDR_REQ_READY_CYCLE,
                          CPP_PERF_WRITE64_DDR_AW_CYCLE,
                          CPP_PERF_WRITE64_DDR_W0_CYCLE,
                          CPP_PERF_WRITE64_DDR_W1_CYCLE,
                          CPP_PERF_WRITE64_DDR_B_CYCLE,
                          CPP_PERF_WRITE64_DDR_RESP_CYCLE,
                          1'b0, 0, 0, 32'h0, 8'h0, 4'h0, 512'h0, 64'h0, 0, -1, -1, -1, -1, -1, -1);

        run_perf_scenario("WRITE32_MMIO",
                          1'b0, 0, 0, 32'h0, 8'h0, 4'h0, 0, -1, -1, -1, -1, -1,
                          1'b0, 0, 0, 32'h0, 8'h0, 4'h0, 0, -1, -1, -1, -1, -1,
                          1'b1,
                          CPP_PERF_WRITE32_MMIO_MASTER,
                          CPP_PERF_WRITE32_MMIO_PORT,
                          CPP_PERF_WRITE32_MMIO_REQ_ADDR,
                          CPP_PERF_WRITE32_MMIO_REQ_SIZE,
                          CPP_PERF_WRITE32_MMIO_REQ_ID,
                          CPP_PERF_WRITE32_MMIO_REQ_WDATA,
                          CPP_PERF_WRITE32_MMIO_REQ_WSTRB,
                          CPP_PERF_WRITE32_MMIO_BEATS,
                          CPP_PERF_WRITE32_MMIO_REQ_READY_CYCLE,
                          CPP_PERF_WRITE32_MMIO_AW_CYCLE,
                          CPP_PERF_WRITE32_MMIO_W0_CYCLE,
                          CPP_PERF_WRITE32_MMIO_W1_CYCLE,
                          CPP_PERF_WRITE32_MMIO_B_CYCLE,
                          CPP_PERF_WRITE32_MMIO_RESP_CYCLE,
                          1'b0, 0, 0, 32'h0, 8'h0, 4'h0, 512'h0, 64'h0, 0, -1, -1, -1, -1, -1, -1);

        run_perf_scenario("OVERLAP_READ",
                          1'b1,
                          CPP_PERF_OVERLAP_READ_DDR_MASTER,
                          CPP_PERF_OVERLAP_READ_DDR_PORT,
                          CPP_PERF_OVERLAP_READ_DDR_REQ_ADDR,
                          CPP_PERF_OVERLAP_READ_DDR_REQ_SIZE,
                          CPP_PERF_OVERLAP_READ_DDR_REQ_ID,
                          CPP_PERF_OVERLAP_READ_DDR_BEATS,
                          CPP_PERF_OVERLAP_READ_DDR_REQ_READY_CYCLE,
                          CPP_PERF_OVERLAP_READ_DDR_AR_CYCLE,
                          CPP_PERF_OVERLAP_READ_DDR_R0_CYCLE,
                          CPP_PERF_OVERLAP_READ_DDR_R1_CYCLE,
                          CPP_PERF_OVERLAP_READ_DDR_RESP_CYCLE,
                          1'b1,
                          CPP_PERF_OVERLAP_READ_MMIO_MASTER,
                          CPP_PERF_OVERLAP_READ_MMIO_PORT,
                          CPP_PERF_OVERLAP_READ_MMIO_REQ_ADDR,
                          CPP_PERF_OVERLAP_READ_MMIO_REQ_SIZE,
                          CPP_PERF_OVERLAP_READ_MMIO_REQ_ID,
                          CPP_PERF_OVERLAP_READ_MMIO_BEATS,
                          CPP_PERF_OVERLAP_READ_MMIO_REQ_READY_CYCLE,
                          CPP_PERF_OVERLAP_READ_MMIO_AR_CYCLE,
                          CPP_PERF_OVERLAP_READ_MMIO_R0_CYCLE,
                          CPP_PERF_OVERLAP_READ_MMIO_R1_CYCLE,
                          CPP_PERF_OVERLAP_READ_MMIO_RESP_CYCLE,
                          1'b0, 0, 0, 32'h0, 8'h0, 4'h0, 512'h0, 64'h0, 0, -1, -1, -1, -1, -1, -1,
                          1'b0, 0, 0, 32'h0, 8'h0, 4'h0, 512'h0, 64'h0, 0, -1, -1, -1, -1, -1, -1);

        run_perf_scenario("OVERLAP_WRITE",
                          1'b0, 0, 0, 32'h0, 8'h0, 4'h0, 0, -1, -1, -1, -1, -1,
                          1'b0, 0, 0, 32'h0, 8'h0, 4'h0, 0, -1, -1, -1, -1, -1,
                          1'b1,
                          CPP_PERF_OVERLAP_WRITE_DDR_MASTER,
                          CPP_PERF_OVERLAP_WRITE_DDR_PORT,
                          CPP_PERF_OVERLAP_WRITE_DDR_REQ_ADDR,
                          CPP_PERF_OVERLAP_WRITE_DDR_REQ_SIZE,
                          CPP_PERF_OVERLAP_WRITE_DDR_REQ_ID,
                          CPP_PERF_OVERLAP_WRITE_DDR_REQ_WDATA,
                          CPP_PERF_OVERLAP_WRITE_DDR_REQ_WSTRB,
                          CPP_PERF_OVERLAP_WRITE_DDR_BEATS,
                          CPP_PERF_OVERLAP_WRITE_DDR_REQ_READY_CYCLE,
                          CPP_PERF_OVERLAP_WRITE_DDR_AW_CYCLE,
                          CPP_PERF_OVERLAP_WRITE_DDR_W0_CYCLE,
                          CPP_PERF_OVERLAP_WRITE_DDR_W1_CYCLE,
                          CPP_PERF_OVERLAP_WRITE_DDR_B_CYCLE,
                          CPP_PERF_OVERLAP_WRITE_DDR_RESP_CYCLE,
                          1'b1,
                          CPP_PERF_OVERLAP_WRITE_MMIO_MASTER,
                          CPP_PERF_OVERLAP_WRITE_MMIO_PORT,
                          CPP_PERF_OVERLAP_WRITE_MMIO_REQ_ADDR,
                          CPP_PERF_OVERLAP_WRITE_MMIO_REQ_SIZE,
                          CPP_PERF_OVERLAP_WRITE_MMIO_REQ_ID,
                          CPP_PERF_OVERLAP_WRITE_MMIO_REQ_WDATA,
                          CPP_PERF_OVERLAP_WRITE_MMIO_REQ_WSTRB,
                          CPP_PERF_OVERLAP_WRITE_MMIO_BEATS,
                          CPP_PERF_OVERLAP_WRITE_MMIO_REQ_READY_CYCLE,
                          CPP_PERF_OVERLAP_WRITE_MMIO_AW_CYCLE,
                          CPP_PERF_OVERLAP_WRITE_MMIO_W0_CYCLE,
                          CPP_PERF_OVERLAP_WRITE_MMIO_W1_CYCLE,
                          CPP_PERF_OVERLAP_WRITE_MMIO_B_CYCLE,
                          CPP_PERF_OVERLAP_WRITE_MMIO_RESP_CYCLE);

        if (perf_failures != 0) begin
            $display("tb_axi_llc_subsystem_dual_cpp_perf_contract FAIL: mismatches=%0d",
                     perf_failures);
            $finish(1);
        end
        if (perf_exact_non_hit) begin
            $display("tb_axi_llc_subsystem_dual_cpp_perf_contract PASS EXACT_NON_HIT");
        end else begin
            $display("tb_axi_llc_subsystem_dual_cpp_perf_contract PASS bounded_non_hit max_extra_observed=%0d direct_max_extra_allowed=%0d llc_miss_max_extra_allowed=%0d",
                     perf_max_extra_cycles, NON_HIT_MAX_EXTRA_CYCLES,
                     LLC_MISS_MAX_EXTRA_CYCLES);
        end
        $finish;
    end

endmodule
