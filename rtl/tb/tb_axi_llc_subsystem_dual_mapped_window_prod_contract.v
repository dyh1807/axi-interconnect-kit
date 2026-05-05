`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_dual_mapped_window_prod_contract;

    localparam ADDR_BITS         = `AXI_LLC_ADDR_BITS;
    localparam ID_BITS           = `AXI_LLC_ID_BITS;
    localparam SLOT_ID_BITS      = `AXI_LLC_SLOT_ID_BITS;
    localparam MODE_BITS         = `AXI_LLC_MODE_BITS;
    localparam LINE_BYTES        = `AXI_LLC_LINE_BYTES;
    localparam LINE_BITS         = `AXI_LLC_LINE_BITS;
    localparam LINE_OFFSET_BITS  = `AXI_LLC_LINE_OFFSET_BITS;
    localparam SET_COUNT         = 8192;
    localparam SET_BITS          = 13;
    localparam WAY_COUNT         = 16;
    localparam WAY_BITS          = 4;
    localparam META_BITS         = `AXI_LLC_META_BITS;
    localparam LLC_SIZE_BYTES    = LINE_BYTES * SET_COUNT * WAY_COUNT;
    localparam WINDOW_BYTES      = 32'h0040_0000;
    localparam WINDOW_WAYS       = 8;
    localparam NUM_READ_MASTERS  = 1;
    localparam NUM_WRITE_MASTERS = 1;
    localparam AXI_ID_BITS       = `AXI_LLC_AXI_ID_BITS;
    localparam DDR_DATA_BYTES    = `AXI_LLC_AXI_DATA_BYTES;
    localparam DDR_DATA_BITS     = `AXI_LLC_AXI_DATA_BITS;
    localparam DDR_STRB_BITS     = `AXI_LLC_AXI_STRB_BITS;
    localparam MMIO_DATA_BYTES   = 4;
    localparam MMIO_DATA_BITS    = 32;
    localparam MMIO_STRB_BITS    = 4;
    localparam READ_RESP_BYTES   = `AXI_LLC_READ_RESP_BYTES;
    localparam READ_RESP_BITS    = `AXI_LLC_READ_RESP_BITS;

    localparam [MODE_BITS-1:0] MODE_MAPPED = 2'b10;
    localparam [ADDR_BITS-1:0] WINDOW_OFFSET = 32'h3000_0000;
    localparam [ADDR_BITS-1:0] WINDOW_LAST_4B_ADDR = 32'h303f_fffc;
    localparam [ID_BITS-1:0] WRITE_ID = 4'h9;
    localparam [ID_BITS-1:0] READ_ID = 4'hA;
    localparam [31:0] PAYLOAD = 32'h5a3c_fffc;
    localparam [1:0] AXI_RESP_OKAY = 2'b00;

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

    always #5 clk = ~clk;

    axi_llc_subsystem_dual #(
        .ADDR_BITS          (ADDR_BITS),
        .ID_BITS            (ID_BITS),
        .SLOT_ID_BITS       (SLOT_ID_BITS),
        .MODE_BITS          (MODE_BITS),
        .LINE_BYTES         (LINE_BYTES),
        .LINE_BITS          (LINE_BITS),
        .LINE_OFFSET_BITS   (LINE_OFFSET_BITS),
        .SET_COUNT          (SET_COUNT),
        .SET_BITS           (SET_BITS),
        .WAY_COUNT          (WAY_COUNT),
        .WAY_BITS           (WAY_BITS),
        .META_BITS          (META_BITS),
        .LLC_SIZE_BYTES     (LLC_SIZE_BYTES),
        .WINDOW_BYTES       (WINDOW_BYTES),
        .WINDOW_WAYS        (WINDOW_WAYS),
        .RESET_MODE         (MODE_MAPPED),
        .RESET_OFFSET       (WINDOW_OFFSET),
        .USE_SMIC12_STORES  (0),
        .TABLE_READ_LATENCY (`AXI_LLC_TABLE_READ_LATENCY),
        .NUM_READ_MASTERS   (NUM_READ_MASTERS),
        .NUM_WRITE_MASTERS  (NUM_WRITE_MASTERS),
        .DDR_AXI_ID_BITS    (AXI_ID_BITS),
        .DDR_AXI_DATA_BYTES (DDR_DATA_BYTES),
        .DDR_AXI_DATA_BITS  (DDR_DATA_BITS),
        .DDR_AXI_STRB_BITS  (DDR_STRB_BITS),
        .MMIO_AXI_ID_BITS   (AXI_ID_BITS),
        .MMIO_AXI_DATA_BYTES(MMIO_DATA_BYTES),
        .MMIO_AXI_DATA_BITS (MMIO_DATA_BITS),
        .MMIO_AXI_STRB_BITS (MMIO_STRB_BITS),
        .READ_RESP_BYTES    (READ_RESP_BYTES),
        .READ_RESP_BITS     (READ_RESP_BITS)
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
        .ddr_axi_awvalid       (ddr_axi_awvalid),
        .ddr_axi_awready       (ddr_axi_awready),
        .ddr_axi_awid          (ddr_axi_awid),
        .ddr_axi_awaddr        (ddr_axi_awaddr),
        .ddr_axi_awlen         (ddr_axi_awlen),
        .ddr_axi_awsize        (ddr_axi_awsize),
        .ddr_axi_awburst       (ddr_axi_awburst),
        .ddr_axi_wvalid        (ddr_axi_wvalid),
        .ddr_axi_wready        (ddr_axi_wready),
        .ddr_axi_wdata         (ddr_axi_wdata),
        .ddr_axi_wstrb         (ddr_axi_wstrb),
        .ddr_axi_wlast         (ddr_axi_wlast),
        .ddr_axi_bvalid        (ddr_axi_bvalid),
        .ddr_axi_bready        (ddr_axi_bready),
        .ddr_axi_bid           (ddr_axi_bid),
        .ddr_axi_bresp         (ddr_axi_bresp),
        .ddr_axi_arvalid       (ddr_axi_arvalid),
        .ddr_axi_arready       (ddr_axi_arready),
        .ddr_axi_arid          (ddr_axi_arid),
        .ddr_axi_araddr        (ddr_axi_araddr),
        .ddr_axi_arlen         (ddr_axi_arlen),
        .ddr_axi_arsize        (ddr_axi_arsize),
        .ddr_axi_arburst       (ddr_axi_arburst),
        .ddr_axi_rvalid        (ddr_axi_rvalid),
        .ddr_axi_rready        (ddr_axi_rready),
        .ddr_axi_rid           (ddr_axi_rid),
        .ddr_axi_rdata         (ddr_axi_rdata),
        .ddr_axi_rresp         (ddr_axi_rresp),
        .ddr_axi_rlast         (ddr_axi_rlast),
        .mmio_axi_awvalid      (mmio_axi_awvalid),
        .mmio_axi_awready      (mmio_axi_awready),
        .mmio_axi_awid         (mmio_axi_awid),
        .mmio_axi_awaddr       (mmio_axi_awaddr),
        .mmio_axi_awlen        (mmio_axi_awlen),
        .mmio_axi_awsize       (mmio_axi_awsize),
        .mmio_axi_awburst      (mmio_axi_awburst),
        .mmio_axi_wvalid       (mmio_axi_wvalid),
        .mmio_axi_wready       (mmio_axi_wready),
        .mmio_axi_wdata        (mmio_axi_wdata),
        .mmio_axi_wstrb        (mmio_axi_wstrb),
        .mmio_axi_wlast        (mmio_axi_wlast),
        .mmio_axi_bvalid       (mmio_axi_bvalid),
        .mmio_axi_bready       (mmio_axi_bready),
        .mmio_axi_bid          (mmio_axi_bid),
        .mmio_axi_bresp        (mmio_axi_bresp),
        .mmio_axi_arvalid      (mmio_axi_arvalid),
        .mmio_axi_arready      (mmio_axi_arready),
        .mmio_axi_arid         (mmio_axi_arid),
        .mmio_axi_araddr       (mmio_axi_araddr),
        .mmio_axi_arlen        (mmio_axi_arlen),
        .mmio_axi_arsize       (mmio_axi_arsize),
        .mmio_axi_arburst      (mmio_axi_arburst),
        .mmio_axi_rvalid       (mmio_axi_rvalid),
        .mmio_axi_rready       (mmio_axi_rready),
        .mmio_axi_rid          (mmio_axi_rid),
        .mmio_axi_rdata        (mmio_axi_rdata),
        .mmio_axi_rresp        (mmio_axi_rresp),
        .mmio_axi_rlast        (mmio_axi_rlast),
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
        input [8*180-1:0] msg;
        begin
            $display("tb_axi_llc_subsystem_dual_mapped_window_prod_contract FAIL: %0s", msg);
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

    task check_no_external_activity;
        begin
            if (ddr_axi_arvalid || ddr_axi_awvalid || ddr_axi_wvalid ||
                mmio_axi_arvalid || mmio_axi_awvalid || mmio_axi_wvalid) begin
                fail_now("mapped-window local request escaped to external AXI");
            end
        end
    endtask

    task wait_mapped_active;
        integer timeout;
        begin
            timeout = 30000;
            while (((active_mode != MODE_MAPPED) ||
                    (active_offset != WINDOW_OFFSET) ||
                    reconfig_busy ||
                    config_error) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("production mapped-window startup timeout");
            end
        end
    endtask

    task issue_last_word_write;
        integer timeout;
        begin
            @(negedge clk);
            write_resp_ready = {NUM_WRITE_MASTERS{1'b0}};
            write_req_addr[ADDR_BITS-1:0] = WINDOW_LAST_4B_ADDR;
            write_req_total_size[7:0] = 8'd3;
            write_req_id[ID_BITS-1:0] = WRITE_ID;
            write_req_bypass[0] = 1'b0;
            write_req_wdata = {(NUM_WRITE_MASTERS*LINE_BITS){1'b0}};
            write_req_wdata[31:0] = PAYLOAD;
            write_req_wstrb = {(NUM_WRITE_MASTERS*LINE_BYTES){1'b0}};
            write_req_wstrb[3:0] = 4'hF;
            write_req_valid[0] = 1'b1;

            timeout = 120;
            while (timeout > 0) begin
                @(posedge clk);
                #1;
                check_no_external_activity();
                if (write_req_accepted[0]) begin
                    timeout = 0;
                end else begin
                    timeout = timeout - 1;
                end
            end
            if (!write_req_accepted[0]) begin
                fail_now("mapped-window last-word write accept timeout");
            end
            if (write_resp_valid[0]) begin
                fail_now("mapped-window write responded in accept cycle");
            end
            @(negedge clk);
            write_req_valid[0] = 1'b0;
        end
    endtask

    task wait_last_word_write_response;
        integer timeout;
        begin
            timeout = 1000;
            while (!write_resp_valid[0] && (timeout > 0)) begin
                @(posedge clk);
                #1;
                check_no_external_activity();
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("mapped-window last-word write response timeout");
            end
            if (write_resp_id[ID_BITS-1:0] != WRITE_ID ||
                write_resp_code[1:0] != AXI_RESP_OKAY) begin
                fail_now("mapped-window last-word write response mismatch");
            end
            write_resp_ready[0] = 1'b1;
            @(posedge clk);
            @(negedge clk);
            write_resp_ready[0] = 1'b0;
        end
    endtask

    task issue_last_word_read;
        integer timeout;
        begin
            @(negedge clk);
            read_resp_ready = {NUM_READ_MASTERS{1'b0}};
            read_req_addr[ADDR_BITS-1:0] = WINDOW_LAST_4B_ADDR;
            read_req_total_size[7:0] = 8'd3;
            read_req_id[ID_BITS-1:0] = READ_ID;
            read_req_bypass[0] = 1'b0;
            read_req_valid[0] = 1'b1;

            timeout = 120;
            while (timeout > 0) begin
                @(posedge clk);
                #1;
                check_no_external_activity();
                if (read_req_accepted[0]) begin
                    timeout = 0;
                end else begin
                    timeout = timeout - 1;
                end
            end
            if (!read_req_accepted[0] ||
                read_req_accepted_id[ID_BITS-1:0] != READ_ID) begin
                fail_now("mapped-window last-word read accept mismatch");
            end
            @(negedge clk);
            read_req_valid[0] = 1'b0;
        end
    endtask

    task wait_last_word_read_response;
        integer timeout;
        begin
            timeout = 1000;
            while (!read_resp_valid[0] && (timeout > 0)) begin
                @(posedge clk);
                #1;
                check_no_external_activity();
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("mapped-window last-word read response timeout");
            end
            if (read_resp_id[ID_BITS-1:0] != READ_ID ||
                read_resp_data[31:0] != PAYLOAD ||
                read_resp_data[READ_RESP_BITS-1:32] != {READ_RESP_BITS-32{1'b0}}) begin
                fail_now("mapped-window last-word read response mismatch");
            end
            read_resp_ready[0] = 1'b1;
            @(posedge clk);
            @(negedge clk);
            read_resp_ready[0] = 1'b0;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        mode_req = MODE_MAPPED;
        llc_mapped_offset_req = WINDOW_OFFSET;
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
        ddr_axi_awready = 1'b0;
        ddr_axi_wready = 1'b0;
        ddr_axi_bvalid = 1'b0;
        ddr_axi_bid = {AXI_ID_BITS{1'b0}};
        ddr_axi_bresp = AXI_RESP_OKAY;
        ddr_axi_arready = 1'b0;
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
        wait_mapped_active();
        check_no_external_activity();

        issue_last_word_write();
        wait_last_word_write_response();
        issue_last_word_read();
        wait_last_word_read_response();

        if (invalidate_line_accepted || invalidate_all_accepted) begin
            fail_now("unexpected maintenance accepted pulse");
        end

        $display("tb_axi_llc_subsystem_dual_mapped_window_prod_contract PASS");
        $finish(0);
    end

endmodule
