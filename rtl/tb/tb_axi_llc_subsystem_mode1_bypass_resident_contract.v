`timescale 1ns / 1ps

module tb_axi_llc_subsystem_mode1_bypass_resident_contract;

    localparam ADDR_BITS         = 32;
    localparam ID_BITS           = 4;
    localparam MODE_BITS         = 2;
    localparam LINE_BYTES        = 8;
    localparam LINE_BITS         = 64;
    localparam LINE_OFFSET_BITS  = 3;
    localparam SET_COUNT         = 4;
    localparam SET_BITS          = 2;
    localparam WAY_COUNT         = 2;
    localparam WAY_BITS          = 1;
    localparam META_BITS         = 32;
    localparam LLC_SIZE_BYTES    = LINE_BYTES * SET_COUNT * WAY_COUNT;
    localparam WINDOW_BYTES      = LINE_BYTES * SET_COUNT;
    localparam WINDOW_WAYS       = 1;
    localparam NUM_READ_MASTERS  = 1;
    localparam NUM_WRITE_MASTERS = 1;
    localparam AXI_ID_BITS       = 2;
    localparam AXI_DATA_BYTES    = 8;
    localparam AXI_DATA_BITS     = 64;
    localparam AXI_STRB_BITS     = 8;
    localparam READ_RESP_BYTES   = LINE_BYTES;
    localparam READ_RESP_BITS    = LINE_BITS;
    localparam TAG_BITS          = ADDR_BITS - SET_BITS - LINE_OFFSET_BITS;
    localparam META_TAG_BITS     = (TAG_BITS < (META_BITS - 1)) ? TAG_BITS : (META_BITS - 1);

    localparam [MODE_BITS-1:0] MODE_CACHE = 2'b01;
    localparam [1:0] AXI_RESP_OKAY = 2'b00;

    localparam [ADDR_BITS-1:0] BYPASS_READ_HIT_ADDR   = 32'h0000_0010;
    localparam [ADDR_BITS-1:0] BYPASS_WRITE_HIT_ADDR  = 32'h0000_0018;
    localparam [ADDR_BITS-1:0] DIRTY_BYPASS_READ_ADDR = 32'h0000_0020;

    reg                                   clk;
    reg                                   rst_n;
    reg  [MODE_BITS-1:0]                  mode_req;
    reg  [ADDR_BITS-1:0]                  llc_mapped_offset_req;
    reg  [NUM_READ_MASTERS-1:0]           read_req_valid;
    wire [NUM_READ_MASTERS-1:0]           read_req_ready;
    wire [NUM_READ_MASTERS-1:0]           read_req_accepted;
    wire [NUM_READ_MASTERS*ID_BITS-1:0]   read_req_accepted_id;
    reg  [NUM_READ_MASTERS*ADDR_BITS-1:0] read_req_addr;
    reg  [NUM_READ_MASTERS*8-1:0]         read_req_total_size;
    reg  [NUM_READ_MASTERS*ID_BITS-1:0]   read_req_id;
    reg  [NUM_READ_MASTERS-1:0]           read_req_bypass;
    wire [NUM_READ_MASTERS-1:0]           read_resp_valid;
    reg  [NUM_READ_MASTERS-1:0]           read_resp_ready;
    wire [NUM_READ_MASTERS*READ_RESP_BITS-1:0] read_resp_data;
    wire [NUM_READ_MASTERS*ID_BITS-1:0]   read_resp_id;
    reg  [NUM_WRITE_MASTERS-1:0]          write_req_valid;
    wire [NUM_WRITE_MASTERS-1:0]          write_req_ready;
    wire [NUM_WRITE_MASTERS-1:0]          write_req_accepted;
    reg  [NUM_WRITE_MASTERS*ADDR_BITS-1:0] write_req_addr;
    reg  [NUM_WRITE_MASTERS*LINE_BITS-1:0] write_req_wdata;
    reg  [NUM_WRITE_MASTERS*LINE_BYTES-1:0] write_req_wstrb;
    reg  [NUM_WRITE_MASTERS*8-1:0]        write_req_total_size;
    reg  [NUM_WRITE_MASTERS*ID_BITS-1:0]  write_req_id;
    reg  [NUM_WRITE_MASTERS-1:0]          write_req_bypass;
    wire [NUM_WRITE_MASTERS-1:0]          write_resp_valid;
    reg  [NUM_WRITE_MASTERS-1:0]          write_resp_ready;
    wire [NUM_WRITE_MASTERS*ID_BITS-1:0]  write_resp_id;
    wire [NUM_WRITE_MASTERS*2-1:0]        write_resp_code;

    wire                                  axi_awvalid;
    reg                                   axi_awready;
    wire [AXI_ID_BITS-1:0]                axi_awid;
    wire [ADDR_BITS-1:0]                  axi_awaddr;
    wire [7:0]                            axi_awlen;
    wire [2:0]                            axi_awsize;
    wire [1:0]                            axi_awburst;
    wire                                  axi_wvalid;
    reg                                   axi_wready;
    wire [AXI_DATA_BITS-1:0]              axi_wdata;
    wire [AXI_STRB_BITS-1:0]              axi_wstrb;
    wire                                  axi_wlast;
    reg                                   axi_bvalid;
    wire                                  axi_bready;
    reg  [AXI_ID_BITS-1:0]                axi_bid;
    reg  [1:0]                            axi_bresp;
    wire                                  axi_arvalid;
    reg                                   axi_arready;
    wire [AXI_ID_BITS-1:0]                axi_arid;
    wire [ADDR_BITS-1:0]                  axi_araddr;
    wire [7:0]                            axi_arlen;
    wire [2:0]                            axi_arsize;
    wire [1:0]                            axi_arburst;
    reg                                   axi_rvalid;
    wire                                  axi_rready;
    reg  [AXI_ID_BITS-1:0]                axi_rid;
    reg  [AXI_DATA_BITS-1:0]              axi_rdata;
    reg  [1:0]                            axi_rresp;
    reg                                   axi_rlast;

    reg                                   invalidate_line_valid;
    reg  [ADDR_BITS-1:0]                  invalidate_line_addr;
    wire                                  invalidate_line_accepted;
    reg                                   invalidate_all_valid;
    wire                                  invalidate_all_accepted;
    wire [MODE_BITS-1:0]                  active_mode;
    wire [ADDR_BITS-1:0]                  active_offset;
    wire                                  reconfig_busy;
    wire [1:0]                            reconfig_state;
    wire                                  config_error;

    reg  [LINE_BITS-1:0]                  lower_mem [0:15];
    reg                                   b_pending_valid_r;
    reg  [AXI_ID_BITS-1:0]                b_pending_id_r;
    reg                                   r_pending_valid_r;
    reg  [AXI_ID_BITS-1:0]                r_pending_id_r;
    reg  [AXI_DATA_BITS-1:0]              r_pending_data_r;
    reg  [ADDR_BITS-1:0]                  aw_addr_pending_r;
    reg  [AXI_ID_BITS-1:0]                aw_id_pending_r;
    reg                                   aw_pending_valid_r;
    integer                               ar_count;
    integer                               aw_count;
    integer                               w_count;
    integer                               error_count;
    integer                               timeout;
    integer                               idx;

    reg  [LINE_BITS-1:0]                  tmp_resp_line;
    integer                               ar_before;
    integer                               aw_before;
    integer                               w_before;

    function integer mem_slot;
        input [ADDR_BITS-1:0] addr_value;
        begin
            mem_slot = addr_value[LINE_OFFSET_BITS + 3:LINE_OFFSET_BITS];
        end
    endfunction

    function [SET_BITS-1:0] addr_set;
        input [ADDR_BITS-1:0] addr_value;
        begin
            addr_set = addr_value[LINE_OFFSET_BITS + SET_BITS - 1:LINE_OFFSET_BITS];
        end
    endfunction

    function [TAG_BITS-1:0] addr_tag;
        input [ADDR_BITS-1:0] addr_value;
        begin
            addr_tag = addr_value[ADDR_BITS-1:LINE_OFFSET_BITS + SET_BITS];
        end
    endfunction

    function [META_BITS-1:0] make_meta;
        input [ADDR_BITS-1:0] addr_value;
        input                 dirty_value;
        reg   [TAG_BITS-1:0]  tag_value;
        begin
            tag_value = addr_tag(addr_value);
            make_meta = {META_BITS{1'b0}};
            make_meta[META_TAG_BITS-1:0] = tag_value[META_TAG_BITS-1:0];
            make_meta[META_TAG_BITS] = dirty_value;
        end
    endfunction

    function [LINE_BITS-1:0] merge_line;
        input [LINE_BITS-1:0]  base_line;
        input [ADDR_BITS-1:0]  addr_value;
        input [LINE_BITS-1:0]  write_line;
        input [LINE_BYTES-1:0] write_strb;
        integer byte_idx;
        integer line_off;
        integer dst_idx;
        begin
            merge_line = base_line;
            line_off = addr_value[LINE_OFFSET_BITS-1:0];
            for (byte_idx = 0; byte_idx < LINE_BYTES; byte_idx = byte_idx + 1) begin
                dst_idx = line_off + byte_idx;
                if (write_strb[byte_idx] && (dst_idx < LINE_BYTES)) begin
                    merge_line[(dst_idx * 8) +: 8] = write_line[(byte_idx * 8) +: 8];
                end
            end
        end
    endfunction

    task fail_now;
        input [8*160-1:0] msg;
        begin
            $display("tb_axi_llc_subsystem_mode1_bypass_resident_contract FAIL: %0s", msg);
            $finish(1);
        end
    endtask

    task check_true;
        input cond;
        input [8*160-1:0] msg;
        begin
            if (!cond) begin
                error_count = error_count + 1;
                $display("tb_axi_llc_subsystem_mode1_bypass_resident_contract ERROR: %0s", msg);
            end
        end
    endtask

    task check_line_eq;
        input [LINE_BITS-1:0] actual_value;
        input [LINE_BITS-1:0] expected_value;
        input [8*160-1:0] msg;
        begin
            if (actual_value !== expected_value) begin
                error_count = error_count + 1;
                $display("tb_axi_llc_subsystem_mode1_bypass_resident_contract ERROR: %0s", msg);
                $display("  actual = 0x%016h", actual_value);
                $display("  expect = 0x%016h", expected_value);
            end
        end
    endtask

    task wait_cycles;
        input integer cycles;
        integer local_idx;
        begin
            for (local_idx = 0; local_idx < cycles; local_idx = local_idx + 1) begin
                @(posedge clk);
            end
        end
    endtask

    task wait_mode_cache_active;
        begin
            timeout = 200;
            while (((active_mode !== MODE_CACHE) || reconfig_busy) &&
                   (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("mode1 activate timeout");
            end
        end
    endtask

    task clear_inputs;
        begin
            read_req_valid = {NUM_READ_MASTERS{1'b0}};
            read_req_addr = {(NUM_READ_MASTERS*ADDR_BITS){1'b0}};
            read_req_total_size = {(NUM_READ_MASTERS*8){1'b0}};
            read_req_id = {(NUM_READ_MASTERS*ID_BITS){1'b0}};
            read_req_bypass = {NUM_READ_MASTERS{1'b0}};
            write_req_valid = {NUM_WRITE_MASTERS{1'b0}};
            write_req_addr = {(NUM_WRITE_MASTERS*ADDR_BITS){1'b0}};
            write_req_wdata = {(NUM_WRITE_MASTERS*LINE_BITS){1'b0}};
            write_req_wstrb = {(NUM_WRITE_MASTERS*LINE_BYTES){1'b0}};
            write_req_total_size = {(NUM_WRITE_MASTERS*8){1'b0}};
            write_req_id = {(NUM_WRITE_MASTERS*ID_BITS){1'b0}};
            write_req_bypass = {NUM_WRITE_MASTERS{1'b0}};
        end
    endtask

    task clear_lower_mem;
        begin
            for (idx = 0; idx < 16; idx = idx + 1) begin
                lower_mem[idx] = {LINE_BITS{1'b0}};
            end
        end
    endtask

    task clear_resident_arrays;
        integer set_idx;
        integer way_idx;
        begin
            for (set_idx = 0; set_idx < SET_COUNT; set_idx = set_idx + 1) begin
                dut.compat.core.valid_ram.valid_mem[set_idx] = {WAY_COUNT{1'b0}};
                dut.compat.core.data_store.gen_generic.u_impl.row_mem[set_idx] =
                    {WAY_COUNT*LINE_BITS{1'b0}};
                dut.compat.core.meta_store.gen_generic.u_impl.row_mem[set_idx] =
                    {WAY_COUNT*META_BITS{1'b0}};
                dut.compat.core.repl_ram.repl_mem[set_idx] = {WAY_BITS{1'b0}};
                for (way_idx = 0; way_idx < WAY_COUNT; way_idx = way_idx + 1) begin
                    dut.compat.core.valid_ram.valid_mem[set_idx][way_idx] = 1'b0;
                end
            end
        end
    endtask

    task preload_resident_line;
        input [ADDR_BITS-1:0] addr_value;
        input integer         way_value;
        input [LINE_BITS-1:0] line_value;
        input                 dirty_value;
        integer set_value;
        begin
            set_value = addr_set(addr_value);
            dut.compat.core.valid_ram.valid_mem[set_value][way_value] = 1'b1;
            dut.compat.core.data_store.gen_generic.u_impl.row_mem[set_value]
                [(way_value * LINE_BITS) +: LINE_BITS] = line_value;
            dut.compat.core.meta_store.gen_generic.u_impl.row_mem[set_value]
                [(way_value * META_BITS) +: META_BITS] = make_meta(addr_value, dirty_value);
            dut.compat.core.repl_ram.repl_mem[set_value] = way_value[WAY_BITS-1:0];
        end
    endtask

    task expect_resident_line_way0;
        input [ADDR_BITS-1:0] addr_value;
        input [LINE_BITS-1:0] exp_line;
        input [8*160-1:0] msg;
        integer set_value;
        reg [LINE_BITS-1:0] actual_line;
        begin
            set_value = addr_set(addr_value);
            actual_line = dut.compat.core.data_store.gen_generic.u_impl.row_mem[set_value][0 +: LINE_BITS];
            check_line_eq(actual_line, exp_line, msg);
        end
    endtask

    task expect_resident_dirty_way0;
        input [ADDR_BITS-1:0] addr_value;
        input                 exp_dirty;
        input [8*160-1:0] msg;
        integer set_value;
        reg [META_BITS-1:0] actual_meta;
        begin
            set_value = addr_set(addr_value);
            actual_meta = dut.compat.core.meta_store.gen_generic.u_impl.row_mem[set_value][0 +: META_BITS];
            check_true(actual_meta[META_TAG_BITS] === exp_dirty, msg);
        end
    endtask

    task capture_axi_counts;
        begin
            ar_before = ar_count;
            aw_before = aw_count;
            w_before = w_count;
        end
    endtask

    task expect_axi_deltas;
        input integer exp_ar;
        input integer exp_aw;
        input integer exp_w;
        input [8*160-1:0] msg;
        begin
            check_true((ar_count - ar_before) == exp_ar, msg);
            check_true((aw_count - aw_before) == exp_aw, msg);
            check_true((w_count - w_before) == exp_w, msg);
        end
    endtask

    task issue_read;
        input [ADDR_BITS-1:0] addr_value;
        input [ID_BITS-1:0]   id_value;
        input                 bypass_value;
        output [LINE_BITS-1:0] resp_line;
        begin
            @(negedge clk);
            read_req_valid[0] = 1'b1;
            read_req_addr[0 +: ADDR_BITS] = addr_value;
            read_req_total_size[0 +: 8] = LINE_BYTES - 1;
            read_req_id[0 +: ID_BITS] = id_value;
            read_req_bypass[0] = bypass_value;
            timeout = 100;
            while ((read_req_accepted[0] !== 1'b1) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting read accepted");
            end
            @(negedge clk);
            read_req_valid[0] = 1'b0;

            timeout = 200;
            while (!read_resp_valid[0] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting read response");
            end
            if (read_resp_id[0 +: ID_BITS] !== id_value) begin
                fail_now("read response id mismatch");
            end
            resp_line = read_resp_data[0 +: LINE_BITS];
            @(posedge clk);
        end
    endtask

    task issue_write;
        input [ADDR_BITS-1:0] addr_value;
        input [ID_BITS-1:0]   id_value;
        input [LINE_BITS-1:0] wdata_value;
        input [LINE_BYTES-1:0] wstrb_value;
        input                 bypass_value;
        begin
            @(negedge clk);
            write_req_valid[0] = 1'b1;
            write_req_addr[0 +: ADDR_BITS] = addr_value;
            write_req_total_size[0 +: 8] = LINE_BYTES - 1;
            write_req_id[0 +: ID_BITS] = id_value;
            write_req_wdata[0 +: LINE_BITS] = wdata_value;
            write_req_wstrb[0 +: LINE_BYTES] = wstrb_value;
            write_req_bypass[0] = bypass_value;
            timeout = 100;
            while ((write_req_accepted[0] !== 1'b1) && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting write accepted");
            end
            @(negedge clk);
            write_req_valid[0] = 1'b0;

            timeout = 200;
            while (!write_resp_valid[0] && (timeout > 0)) begin
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("timeout waiting write response");
            end
            if (write_resp_id[0 +: ID_BITS] !== id_value) begin
                fail_now("write response id mismatch");
            end
            if (write_resp_code[0 +: 2] !== AXI_RESP_OKAY) begin
                fail_now("write response code mismatch");
            end
            @(posedge clk);
        end
    endtask

    always #5 clk = ~clk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ar_count <= 0;
            aw_count <= 0;
            w_count <= 0;
            aw_pending_valid_r <= 1'b0;
            aw_addr_pending_r <= {ADDR_BITS{1'b0}};
            aw_id_pending_r <= {AXI_ID_BITS{1'b0}};
            b_pending_valid_r <= 1'b0;
            b_pending_id_r <= {AXI_ID_BITS{1'b0}};
            r_pending_valid_r <= 1'b0;
            r_pending_id_r <= {AXI_ID_BITS{1'b0}};
            r_pending_data_r <= {AXI_DATA_BITS{1'b0}};
        end else begin
            if (axi_arvalid && axi_arready) begin
                ar_count <= ar_count + 1;
                r_pending_valid_r <= 1'b1;
                r_pending_id_r <= axi_arid;
                r_pending_data_r <= lower_mem[mem_slot(axi_araddr)];
            end
            if (axi_awvalid && axi_awready) begin
                aw_count <= aw_count + 1;
                aw_pending_valid_r <= 1'b1;
                aw_addr_pending_r <= axi_awaddr;
                aw_id_pending_r <= axi_awid;
            end
            if (axi_wvalid && axi_wready) begin
                w_count <= w_count + 1;
                if (aw_pending_valid_r) begin
                    for (idx = 0; idx < AXI_DATA_BYTES; idx = idx + 1) begin
                        if (axi_wstrb[idx]) begin
                            lower_mem[mem_slot(aw_addr_pending_r)][(idx * 8) +: 8] <=
                                axi_wdata[(idx * 8) +: 8];
                        end
                    end
                    b_pending_valid_r <= 1'b1;
                    b_pending_id_r <= aw_id_pending_r;
                    aw_pending_valid_r <= 1'b0;
                end
            end
            if (axi_bvalid && axi_bready) begin
                b_pending_valid_r <= 1'b0;
                b_pending_id_r <= {AXI_ID_BITS{1'b0}};
            end
            if (axi_rvalid && axi_rready) begin
                r_pending_valid_r <= 1'b0;
                r_pending_id_r <= {AXI_ID_BITS{1'b0}};
                r_pending_data_r <= {AXI_DATA_BITS{1'b0}};
            end
        end
    end

    always @(*) begin
        axi_bvalid = b_pending_valid_r;
        axi_bid = b_pending_id_r;
        axi_bresp = AXI_RESP_OKAY;
        axi_rvalid = r_pending_valid_r;
        axi_rid = r_pending_id_r;
        axi_rdata = r_pending_data_r;
        axi_rresp = AXI_RESP_OKAY;
        axi_rlast = 1'b1;
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
        .READ_RESP_BYTES   (READ_RESP_BYTES),
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

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        mode_req = MODE_CACHE;
        llc_mapped_offset_req = {ADDR_BITS{1'b0}};
        read_resp_ready = {NUM_READ_MASTERS{1'b1}};
        write_resp_ready = {NUM_WRITE_MASTERS{1'b1}};
        axi_awready = 1'b1;
        axi_wready = 1'b1;
        axi_arready = 1'b1;
        invalidate_line_valid = 1'b0;
        invalidate_line_addr = {ADDR_BITS{1'b0}};
        invalidate_all_valid = 1'b0;
        error_count = 0;
        tmp_resp_line = {LINE_BITS{1'b0}};
        clear_inputs();
        clear_lower_mem();
        wait_cycles(4);
        rst_n = 1'b1;
        wait_mode_cache_active();
        clear_resident_arrays();
        clear_lower_mem();
        check_true(!config_error, "config_error should stay low");

        // Case 1: mode1 bypass read hit must return resident data and not go AXI.
        lower_mem[mem_slot(BYPASS_READ_HIT_ADDR)] = 64'h1111_2222_3333_4444;
        preload_resident_line(BYPASS_READ_HIT_ADDR, 0,
                              64'hAAAA_BBBB_CCCC_DDDD, 1'b0);
        capture_axi_counts();
        issue_read(BYPASS_READ_HIT_ADDR, 4'h1, 1'b1, tmp_resp_line);
        check_line_eq(tmp_resp_line, 64'hAAAA_BBBB_CCCC_DDDD,
                      "mode1 bypass read hit should return resident line");
        expect_axi_deltas(0, 0, 0,
                          "mode1 bypass read hit should not touch lower AXI");

        // Case 2: mode1 bypass write hit must shadow-update resident and write-through.
        clear_resident_arrays();
        clear_lower_mem();
        lower_mem[mem_slot(BYPASS_WRITE_HIT_ADDR)] = 64'hABAB_CDCD_EFEF_0101;
        preload_resident_line(BYPASS_WRITE_HIT_ADDR, 0,
                              64'h0102_0304_0506_0708, 1'b0);
        capture_axi_counts();
        issue_write(BYPASS_WRITE_HIT_ADDR, 4'h2,
                    64'hCAFE_FEED_DEAD_BEEF, 8'hFF, 1'b1);
        expect_axi_deltas(0, 1, 1,
                          "mode1 bypass write hit should issue exactly one lower write");
        expect_resident_line_way0(BYPASS_WRITE_HIT_ADDR,
                                  64'hCAFE_FEED_DEAD_BEEF,
                                  "mode1 bypass write hit should shadow-update resident line");
        expect_resident_dirty_way0(BYPASS_WRITE_HIT_ADDR, 1'b0,
                                   "mode1 bypass write hit must keep clean resident clean");
        check_line_eq(lower_mem[mem_slot(BYPASS_WRITE_HIT_ADDR)],
                      64'hCAFE_FEED_DEAD_BEEF,
                      "mode1 bypass write hit should write-through lower memory");
        capture_axi_counts();
        issue_read(BYPASS_WRITE_HIT_ADDR, 4'h3, 1'b0, tmp_resp_line);
        check_line_eq(tmp_resp_line, 64'hCAFE_FEED_DEAD_BEEF,
                      "non-bypass read after bypass write hit should see updated resident");
        expect_axi_deltas(0, 0, 0,
                          "non-bypass reread after bypass write hit should stay resident");

        // Case 3: dirty resident + bypass read must still return resident data.
        clear_resident_arrays();
        clear_lower_mem();
        lower_mem[mem_slot(DIRTY_BYPASS_READ_ADDR)] = 64'h0101_0202_0303_0404;
        preload_resident_line(DIRTY_BYPASS_READ_ADDR, 0,
                              64'hDEAD_BEEF_1234_5678, 1'b1);
        capture_axi_counts();
        issue_read(DIRTY_BYPASS_READ_ADDR, 4'h4, 1'b1, tmp_resp_line);
        check_line_eq(tmp_resp_line, 64'hDEAD_BEEF_1234_5678,
                      "dirty resident bypass read should return resident line");
        expect_axi_deltas(0, 0, 0,
                          "dirty resident bypass read should not touch lower AXI");
        expect_resident_dirty_way0(DIRTY_BYPASS_READ_ADDR, 1'b1,
                                   "dirty resident bypass read must preserve dirty bit");

        if (error_count == 0) begin
            $display("tb_axi_llc_subsystem_mode1_bypass_resident_contract PASS");
            $finish(0);
        end else begin
            $display("tb_axi_llc_subsystem_mode1_bypass_resident_contract FAIL errors=%0d",
                     error_count);
            $finish(1);
        end
    end

endmodule
