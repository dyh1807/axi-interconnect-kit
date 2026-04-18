`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module tb_axi_llc_subsystem_equiv_replay;

    `include "equiv_case.vh"

    localparam ID_BITS = `AXI_LLC_ID_BITS;
    localparam MODE_BITS = `AXI_LLC_MODE_BITS;
    localparam ADDR_BITS = `AXI_LLC_ADDR_BITS;
    localparam LINE_BYTES = `AXI_LLC_LINE_BYTES;
    localparam LINE_BITS = `AXI_LLC_LINE_BITS;
    localparam AXI_ID_BITS = `AXI_LLC_AXI_ID_BITS;
    localparam AXI_DATA_BITS = `AXI_LLC_AXI_DATA_BITS;
    localparam AXI_STRB_BITS = `AXI_LLC_AXI_STRB_BITS;
    localparam READ_RESP_BITS = `AXI_LLC_READ_RESP_BITS;
    localparam NUM_READ_MASTERS = 4;
    localparam NUM_WRITE_MASTERS = 2;

    reg                                  clk;
    reg                                  rst_n;
    reg  [MODE_BITS-1:0]                 mode_req;
    reg  [ADDR_BITS-1:0]                 llc_mapped_offset_req;
    reg  [NUM_READ_MASTERS-1:0]          read_req_valid;
    wire [NUM_READ_MASTERS-1:0]          read_req_ready;
    wire [NUM_READ_MASTERS-1:0]          read_req_accepted;
    wire [NUM_READ_MASTERS*ID_BITS-1:0]  read_req_accepted_id;
    reg  [NUM_READ_MASTERS*ADDR_BITS-1:0] read_req_addr;
    reg  [NUM_READ_MASTERS*8-1:0]        read_req_total_size;
    reg  [NUM_READ_MASTERS*ID_BITS-1:0]  read_req_id;
    reg  [NUM_READ_MASTERS-1:0]          read_req_bypass;
    wire [NUM_READ_MASTERS-1:0]          read_resp_valid;
    reg  [NUM_READ_MASTERS-1:0]          read_resp_ready;
    wire [NUM_READ_MASTERS*READ_RESP_BITS-1:0] read_resp_data;
    wire [NUM_READ_MASTERS*ID_BITS-1:0]  read_resp_id;
    reg  [NUM_WRITE_MASTERS-1:0]         write_req_valid;
    wire [NUM_WRITE_MASTERS-1:0]         write_req_ready;
    wire [NUM_WRITE_MASTERS-1:0]         write_req_accepted;
    reg  [NUM_WRITE_MASTERS*ADDR_BITS-1:0] write_req_addr;
    reg  [NUM_WRITE_MASTERS*LINE_BITS-1:0] write_req_wdata;
    reg  [NUM_WRITE_MASTERS*LINE_BYTES-1:0] write_req_wstrb;
    reg  [NUM_WRITE_MASTERS*8-1:0]       write_req_total_size;
    reg  [NUM_WRITE_MASTERS*ID_BITS-1:0] write_req_id;
    reg  [NUM_WRITE_MASTERS-1:0]         write_req_bypass;
    wire [NUM_WRITE_MASTERS-1:0]         write_resp_valid;
    reg  [NUM_WRITE_MASTERS-1:0]         write_resp_ready;
    wire [NUM_WRITE_MASTERS*ID_BITS-1:0] write_resp_id;
    wire [NUM_WRITE_MASTERS*2-1:0]       write_resp_code;
    wire                                 axi_awvalid;
    reg                                  axi_awready;
    wire [AXI_ID_BITS-1:0]               axi_awid;
    wire [ADDR_BITS-1:0]                 axi_awaddr;
    wire [7:0]                           axi_awlen;
    wire [2:0]                           axi_awsize;
    wire [1:0]                           axi_awburst;
    wire                                 axi_wvalid;
    reg                                  axi_wready;
    wire [AXI_DATA_BITS-1:0]             axi_wdata;
    wire [AXI_STRB_BITS-1:0]             axi_wstrb;
    wire                                 axi_wlast;
    reg                                  axi_bvalid;
    wire                                 axi_bready;
    reg  [AXI_ID_BITS-1:0]               axi_bid;
    reg  [1:0]                           axi_bresp;
    wire                                 axi_arvalid;
    reg                                  axi_arready;
    wire [AXI_ID_BITS-1:0]               axi_arid;
    wire [ADDR_BITS-1:0]                 axi_araddr;
    wire [7:0]                           axi_arlen;
    wire [2:0]                           axi_arsize;
    wire [1:0]                           axi_arburst;
    reg                                  axi_rvalid;
    wire                                 axi_rready;
    reg  [AXI_ID_BITS-1:0]               axi_rid;
    reg  [AXI_DATA_BITS-1:0]             axi_rdata;
    reg  [1:0]                           axi_rresp;
    reg                                  axi_rlast;
    reg                                  invalidate_line_valid;
    reg  [ADDR_BITS-1:0]                 invalidate_line_addr;
    wire                                 invalidate_line_accepted;
    reg                                  invalidate_all_valid;
    wire                                 invalidate_all_accepted;
    wire [MODE_BITS-1:0]                 active_mode;
    wire [ADDR_BITS-1:0]                 active_offset;
    wire                                 reconfig_busy;
    wire [1:0]                           reconfig_state;
    wire                                 config_error;

    integer                              cycle_idx;
    integer                              trace_fd;
    reg [4095:0]                         trace_file;
    reg                                  prev_mode_valid;
    reg [MODE_BITS-1:0]                  prev_active_mode;
    reg [ADDR_BITS-1:0]                  prev_active_offset;
    integer                              m;

    function [31:0] hash_read_words;
        input [READ_RESP_BITS-1:0] data_value;
        integer idx;
        reg [31:0] h;
        reg [31:0] word;
        begin
            h = 32'h811c9dc5;
            for (idx = 0; idx < 8; idx = idx + 1) begin
                word = data_value[(idx * 32) +: 32];
                h = {h[26:0], h[31:27]} ^ word ^ idx[31:0];
            end
            hash_read_words = h;
        end
    endfunction

    function [31:0] hash_write_strobe;
        input [LINE_BYTES-1:0] strb_value;
        integer idx;
        reg [31:0] h;
        reg [3:0] nib;
        begin
            h = 32'h13579bdf;
            for (idx = 0; idx < 16; idx = idx + 1) begin
                nib = strb_value[(idx * 4) +: 4];
                h = {h[28:0], h[31:29]} ^ {28'd0, nib} ^ idx[31:0];
            end
            hash_write_strobe = h;
        end
    endfunction

    function [31:0] read_word0;
        input [READ_RESP_BITS-1:0] data_value;
        begin
            read_word0 = data_value[31:0];
        end
    endfunction

    function [31:0] read_word1;
        input [READ_RESP_BITS-1:0] data_value;
        begin
            read_word1 = data_value[63:32];
        end
    endfunction

    axi_llc_subsystem dut (
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

    always #5 clk = ~clk;

    always @(*) begin
        if (!rst_n || cycle_idx >= EQUIV_NUM_CYCLES) begin
            mode_req               = {MODE_BITS{1'b0}};
            llc_mapped_offset_req  = {ADDR_BITS{1'b0}};
            invalidate_all_valid   = 1'b0;
            invalidate_line_valid  = 1'b0;
            invalidate_line_addr   = {ADDR_BITS{1'b0}};
            read_req_valid         = {NUM_READ_MASTERS{1'b0}};
            read_req_addr          = {(NUM_READ_MASTERS*ADDR_BITS){1'b0}};
            read_req_total_size    = {(NUM_READ_MASTERS*8){1'b0}};
            read_req_id            = {(NUM_READ_MASTERS*ID_BITS){1'b0}};
            read_req_bypass        = {NUM_READ_MASTERS{1'b0}};
            read_resp_ready        = {NUM_READ_MASTERS{1'b0}};
            write_req_valid        = {NUM_WRITE_MASTERS{1'b0}};
            write_req_addr         = {(NUM_WRITE_MASTERS*ADDR_BITS){1'b0}};
            write_req_wdata        = {(NUM_WRITE_MASTERS*LINE_BITS){1'b0}};
            write_req_wstrb        = {(NUM_WRITE_MASTERS*LINE_BYTES){1'b0}};
            write_req_total_size   = {(NUM_WRITE_MASTERS*8){1'b0}};
            write_req_id           = {(NUM_WRITE_MASTERS*ID_BITS){1'b0}};
            write_req_bypass       = {NUM_WRITE_MASTERS{1'b0}};
            write_resp_ready       = {NUM_WRITE_MASTERS{1'b0}};
            axi_arready            = 1'b0;
            axi_awready            = 1'b0;
            axi_wready             = 1'b0;
            axi_bvalid             = 1'b0;
            axi_bid                = {AXI_ID_BITS{1'b0}};
            axi_bresp              = 2'b00;
            axi_rvalid             = 1'b0;
            axi_rid                = {AXI_ID_BITS{1'b0}};
            axi_rresp              = 2'b00;
            axi_rlast              = 1'b0;
            axi_rdata              = {AXI_DATA_BITS{1'b0}};
        end else begin
            mode_req               = stim_mode_req[cycle_idx];
            llc_mapped_offset_req  = stim_offset_req[cycle_idx];
            invalidate_all_valid   = stim_invalidate_all[cycle_idx];
            invalidate_line_valid  = stim_invalidate_line_valid[cycle_idx];
            invalidate_line_addr   = stim_invalidate_line_addr[cycle_idx];
            read_req_valid         = stim_read_req_valid[cycle_idx];
            read_req_addr          = stim_read_req_addr[cycle_idx];
            read_req_total_size    = stim_read_req_size[cycle_idx];
            read_req_id            = stim_read_req_id[cycle_idx];
            read_req_bypass        = stim_read_req_bypass[cycle_idx];
            read_resp_ready        = stim_read_resp_ready_mask[cycle_idx];
            write_req_valid        = stim_write_req_valid[cycle_idx];
            write_req_addr         = stim_write_req_addr[cycle_idx];
            write_req_wdata        = stim_write_req_wdata[cycle_idx];
            write_req_wstrb        = stim_write_req_wstrb[cycle_idx];
            write_req_total_size   = stim_write_req_size[cycle_idx];
            write_req_id           = stim_write_req_id[cycle_idx];
            write_req_bypass       = stim_write_req_bypass[cycle_idx];
            write_resp_ready       = stim_write_resp_ready_mask[cycle_idx];
            axi_arready            = stim_axi_arready[cycle_idx];
            axi_awready            = stim_axi_awready[cycle_idx];
            axi_wready             = stim_axi_wready[cycle_idx];
            axi_bvalid             = stim_axi_bvalid[cycle_idx];
            axi_bid                = stim_axi_bid[cycle_idx][AXI_ID_BITS-1:0];
            axi_bresp              = stim_axi_bresp[cycle_idx];
            axi_rvalid             = stim_axi_rvalid[cycle_idx];
            axi_rid                = stim_axi_rid[cycle_idx][AXI_ID_BITS-1:0];
            axi_rresp              = stim_axi_rresp[cycle_idx];
            axi_rlast              = stim_axi_rlast[cycle_idx];
            axi_rdata              = stim_axi_rdata[cycle_idx];
        end
    end

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        cycle_idx = 0;
        prev_mode_valid = 1'b0;
        prev_active_mode = {MODE_BITS{1'b0}};
        prev_active_offset = {ADDR_BITS{1'b0}};
        trace_file = "rtl_trace.txt";
        if (!$value$plusargs("trace_file=%s", trace_file)) begin
            trace_file = "rtl_trace.txt";
        end
        trace_fd = $fopen(trace_file, "w");
        if (trace_fd == 0) begin
            $display("tb_axi_llc_subsystem_equiv_replay FAIL: could not open trace file");
            $finish;
        end
        repeat (2) @(posedge clk);
        rst_n = 1'b1;
    end

    always @(negedge clk) begin
        if (rst_n && cycle_idx < EQUIV_NUM_CYCLES) begin
            for (m = 0; m < NUM_READ_MASTERS; m = m + 1) begin
                if (read_req_accepted[m]) begin
                    $fwrite(trace_fd,
                            "%0d READ_ACCEPT m=%0d id=%0d addr=0x%08x size=%0d bypass=%0d\n",
                            cycle_idx,
                            m,
                            read_req_id[(m*ID_BITS) +: ID_BITS],
                            read_req_addr[(m*ADDR_BITS) +: ADDR_BITS],
                            read_req_total_size[(m*8) +: 8],
                            read_req_bypass[m]);
                end
            end
            for (m = 0; m < NUM_WRITE_MASTERS; m = m + 1) begin
                if (write_req_accepted[m]) begin
                    $fwrite(trace_fd,
                            "%0d WRITE_ACCEPT m=%0d id=%0d addr=0x%08x size=%0d bypass=%0d data0=0x%08x strbhash=0x%08x\n",
                            cycle_idx,
                            m,
                            write_req_id[(m*ID_BITS) +: ID_BITS],
                            write_req_addr[(m*ADDR_BITS) +: ADDR_BITS],
                            write_req_total_size[(m*8) +: 8],
                            write_req_bypass[m],
                            write_req_wdata[(m*LINE_BITS) +: 32],
                            hash_write_strobe(write_req_wstrb[(m*LINE_BYTES) +: LINE_BYTES]));
                end
            end
            for (m = 0; m < NUM_READ_MASTERS; m = m + 1) begin
                if (read_resp_valid[m] && read_resp_ready[m]) begin
                    $fwrite(trace_fd,
                            "%0d READ_RESP m=%0d id=%0d hash=0x%08x d0=0x%08x d1=0x%08x\n",
                            cycle_idx,
                            m,
                            read_resp_id[(m*ID_BITS) +: ID_BITS],
                            hash_read_words(read_resp_data[(m*READ_RESP_BITS) +: READ_RESP_BITS]),
                            read_word0(read_resp_data[(m*READ_RESP_BITS) +: READ_RESP_BITS]),
                            read_word1(read_resp_data[(m*READ_RESP_BITS) +: READ_RESP_BITS]));
                end
            end
            for (m = 0; m < NUM_WRITE_MASTERS; m = m + 1) begin
                if (write_resp_valid[m] && write_resp_ready[m]) begin
                    $fwrite(trace_fd,
                            "%0d WRITE_RESP m=%0d id=%0d code=%0d\n",
                            cycle_idx,
                            m,
                            write_resp_id[(m*ID_BITS) +: ID_BITS],
                            write_resp_code[(m*2) +: 2]);
                end
            end
            if (invalidate_line_accepted) begin
                $fwrite(trace_fd,
                        "%0d MAINT_ACCEPT op=invalidate_line addr=0x%08x\n",
                        cycle_idx,
                        invalidate_line_addr);
            end
            if (invalidate_all_accepted) begin
                $fwrite(trace_fd, "%0d MAINT_ACCEPT op=invalidate_all\n", cycle_idx);
            end
            if (!prev_mode_valid ||
                active_mode != prev_active_mode ||
                active_offset != prev_active_offset) begin
                $fwrite(trace_fd,
                        "%0d MODE_ACTIVE mode=%0d offset=0x%08x\n",
                        cycle_idx,
                        active_mode,
                        active_offset);
                prev_mode_valid   <= 1'b1;
                prev_active_mode  <= active_mode;
                prev_active_offset <= active_offset;
            end
        end
    end

    always @(posedge clk) begin
        if (rst_n) begin
            if (cycle_idx >= EQUIV_NUM_CYCLES - 1) begin
                $fclose(trace_fd);
                $finish;
            end
            cycle_idx <= cycle_idx + 1;
        end
    end

endmodule
