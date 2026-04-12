`timescale 1ns / 1ps

module tb_axi_llc_subsystem_bypass_contract;

    localparam ADDR_BITS        = 32;
    localparam ID_BITS          = 4;
    localparam MODE_BITS        = 2;
    localparam LINE_BYTES       = 8;
    localparam LINE_BITS        = 64;
    localparam LINE_OFFSET_BITS = 3;
    localparam SET_COUNT        = 4;
    localparam SET_BITS         = 2;
    localparam WAY_COUNT        = 2;
    localparam WAY_BITS         = 1;
    localparam META_BITS        = 32;
    localparam DATA_ROW_BITS    = WAY_COUNT * LINE_BITS;
    localparam META_ROW_BITS    = WAY_COUNT * META_BITS;
    localparam TAG_BITS         = ADDR_BITS - SET_BITS - LINE_OFFSET_BITS;
    localparam META_TAG_BITS    = (TAG_BITS < (META_BITS - 1)) ? TAG_BITS : (META_BITS - 1);
    localparam MEM_DEPTH        = 16;

    localparam [MODE_BITS-1:0] MODE_CACHE  = 2'b01;

    localparam [7:0] FULL_SIZE = LINE_BYTES - 1;
    localparam [7:0] WORD_SIZE = 8'd3;

    localparam [ADDR_BITS-1:0] BYPASS_READ_HIT_ADDR   = 32'h0000_0010;
    localparam [ADDR_BITS-1:0] BYPASS_WRITE_HIT_ADDR  = 32'h0000_0018;
    localparam [ADDR_BITS-1:0] BYPASS_READ_MISS_ADDR  = 32'h0000_0020;
    localparam [ADDR_BITS-1:0] BYPASS_WRITE_MISS_ADDR = 32'h0000_0028;

    reg                       clk;
    reg                       rst_n;
    reg  [MODE_BITS-1:0]      mode_req;
    reg  [ADDR_BITS-1:0]      llc_mapped_offset_req;
    reg                       up_req_valid;
    wire                      up_req_ready;
    reg                       up_req_write;
    reg  [ADDR_BITS-1:0]      up_req_addr;
    reg  [ID_BITS-1:0]        up_req_id;
    reg  [7:0]                up_req_total_size;
    reg  [LINE_BITS-1:0]      up_req_wdata;
    reg  [LINE_BYTES-1:0]     up_req_wstrb;
    reg                       up_req_bypass;
    wire                      up_resp_valid;
    reg                       up_resp_ready;
    wire [LINE_BITS-1:0]      up_resp_rdata;
    wire [ID_BITS-1:0]        up_resp_id;
    wire                      cache_req_valid;
    reg                       cache_req_ready;
    wire                      cache_req_write;
    wire [ADDR_BITS-1:0]      cache_req_addr;
    wire [ID_BITS-1:0]        cache_req_id;
    wire [7:0]                cache_req_size;
    wire [LINE_BITS-1:0]      cache_req_wdata;
    wire [LINE_BYTES-1:0]     cache_req_wstrb;
    reg                       cache_resp_valid;
    wire                      cache_resp_ready;
    reg  [LINE_BITS-1:0]      cache_resp_rdata;
    reg  [ID_BITS-1:0]        cache_resp_id;
    wire                      bypass_req_valid;
    reg                       bypass_req_ready;
    wire                      bypass_req_write;
    wire [ADDR_BITS-1:0]      bypass_req_addr;
    wire [ID_BITS-1:0]        bypass_req_id;
    wire [7:0]                bypass_req_size;
    wire [LINE_BITS-1:0]      bypass_req_wdata;
    wire [LINE_BYTES-1:0]     bypass_req_wstrb;
    reg                       bypass_resp_valid;
    wire                      bypass_resp_ready;
    reg  [LINE_BITS-1:0]      bypass_resp_rdata;
    reg  [ID_BITS-1:0]        bypass_resp_id;
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

    reg  [LINE_BITS-1:0]      lower_mem [0:MEM_DEPTH-1];
    reg                       cache_resp_pending_r;
    reg  [LINE_BITS-1:0]      cache_resp_pending_data_r;
    reg  [ID_BITS-1:0]        cache_resp_pending_id_r;
    reg                       bypass_resp_pending_r;
    reg  [LINE_BITS-1:0]      bypass_resp_pending_data_r;
    reg  [ID_BITS-1:0]        bypass_resp_pending_id_r;

    integer                   cache_req_count;
    integer                   cache_read_count;
    integer                   cache_write_count;
    integer                   bypass_req_count;
    integer                   bypass_read_count;
    integer                   bypass_write_count;
    integer                   error_count;
    integer                   set_idx;
    integer                   way_idx;

    reg  [ADDR_BITS-1:0]      last_cache_addr;
    reg  [ID_BITS-1:0]        last_cache_id;
    reg                       last_cache_write;
    reg  [7:0]                last_cache_size;
    reg  [LINE_BITS-1:0]      last_cache_wdata;
    reg  [LINE_BYTES-1:0]     last_cache_wstrb;
    reg  [ADDR_BITS-1:0]      last_bypass_addr;
    reg  [ID_BITS-1:0]        last_bypass_id;
    reg                       last_bypass_write;
    reg  [7:0]                last_bypass_size;
    reg  [LINE_BITS-1:0]      last_bypass_wdata;
    reg  [LINE_BYTES-1:0]     last_bypass_wstrb;

    reg  [LINE_BITS-1:0]      tmp_resp_line;
    reg  [LINE_BITS-1:0]      tmp_expected_line;
    integer                   cache_read_before;
    integer                   cache_write_before;
    integer                   bypass_read_before;
    integer                   bypass_write_before;

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

    function [LINE_BITS-1:0] make_line;
        input [7:0] seed;
        integer byte_idx;
        begin
            make_line = {LINE_BITS{1'b0}};
            for (byte_idx = 0; byte_idx < LINE_BYTES; byte_idx = byte_idx + 1) begin
                make_line[(byte_idx * 8) +: 8] = seed + byte_idx[7:0];
            end
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

    function [LINE_BITS-1:0] extract_line_from_row;
        input [DATA_ROW_BITS-1:0] row_value;
        input integer             way_value;
        begin
            extract_line_from_row =
                row_value[(way_value * LINE_BITS) +: LINE_BITS];
        end
    endfunction

    function [META_BITS-1:0] extract_meta_from_row;
        input [META_ROW_BITS-1:0] row_value;
        input integer             way_value;
        begin
            extract_meta_from_row =
                row_value[(way_value * META_BITS) +: META_BITS];
        end
    endfunction

    function [TAG_BITS-1:0] meta_tag;
        input [META_BITS-1:0] meta_value;
        begin
            meta_tag = {TAG_BITS{1'b0}};
            meta_tag[META_TAG_BITS-1:0] = meta_value[META_TAG_BITS-1:0];
        end
    endfunction

    function meta_dirty;
        input [META_BITS-1:0] meta_value;
        begin
            meta_dirty = meta_value[META_TAG_BITS];
        end
    endfunction

    task fatal_now;
        input [8*160-1:0] msg;
        begin
            $display("tb_axi_llc_subsystem_bypass_contract FATAL: %0s", msg);
            $finish(1);
        end
    endtask

    task note_case;
        input [8*96-1:0] msg;
        begin
            $display("[bypass-contract] %0s", msg);
        end
    endtask

    task check_true;
        input                   cond;
        input [8*160-1:0]       msg;
        begin
            if (!cond) begin
                error_count = error_count + 1;
                $display("tb_axi_llc_subsystem_bypass_contract ERROR: %0s", msg);
            end
        end
    endtask

    task check_line_eq;
        input [LINE_BITS-1:0]   actual_value;
        input [LINE_BITS-1:0]   expected_value;
        input [8*160-1:0]       msg;
        begin
            if (actual_value !== expected_value) begin
                error_count = error_count + 1;
                $display("tb_axi_llc_subsystem_bypass_contract ERROR: %0s", msg);
                $display("  actual  = 0x%016h", actual_value);
                $display("  expect  = 0x%016h", expected_value);
            end
        end
    endtask

    task wait_active_config;
        input [MODE_BITS-1:0] exp_mode;
        input [ADDR_BITS-1:0] exp_offset;
        integer timeout;
        begin
            timeout = 0;
            while (((active_mode !== exp_mode) ||
                    (active_offset !== exp_offset) ||
                    reconfig_busy) && (timeout < 256)) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if ((active_mode !== exp_mode) ||
                (active_offset !== exp_offset) ||
                reconfig_busy) begin
                fatal_now("timeout waiting active config");
            end
            @(posedge clk);
        end
    endtask

    task clear_lower_mem;
        integer idx;
        begin
            for (idx = 0; idx < MEM_DEPTH; idx = idx + 1) begin
                lower_mem[idx] = {LINE_BITS{1'b0}};
            end
        end
    endtask

    task set_lower_line;
        input [ADDR_BITS-1:0] addr_value;
        input [LINE_BITS-1:0] line_value;
        begin
            lower_mem[mem_slot(addr_value)] = line_value;
        end
    endtask

    task clear_resident_arrays;
        integer sidx;
        begin
            for (sidx = 0; sidx < SET_COUNT; sidx = sidx + 1) begin
                dut.valid_ram.valid_mem[sidx] = {WAY_COUNT{1'b0}};
                dut.data_store.gen_generic.u_impl.row_mem[sidx] = {DATA_ROW_BITS{1'b0}};
                dut.meta_store.gen_generic.u_impl.row_mem[sidx] = {META_ROW_BITS{1'b0}};
            end
            @(negedge clk);
        end
    endtask

    task preload_resident_line;
        input [ADDR_BITS-1:0] addr_value;
        input integer         way_value;
        input [LINE_BITS-1:0] line_value;
        input                 dirty_value;
        reg   [SET_BITS-1:0]  set_value;
        reg   [DATA_ROW_BITS-1:0] data_row_value;
        reg   [META_ROW_BITS-1:0] meta_row_value;
        begin
            set_value = addr_set(addr_value);
            data_row_value = dut.data_store.gen_generic.u_impl.row_mem[set_value];
            meta_row_value = dut.meta_store.gen_generic.u_impl.row_mem[set_value];
            data_row_value[(way_value * LINE_BITS) +: LINE_BITS] = line_value;
            meta_row_value[(way_value * META_BITS) +: META_BITS] =
                make_meta(addr_value, dirty_value);
            dut.data_store.gen_generic.u_impl.row_mem[set_value] = data_row_value;
            dut.meta_store.gen_generic.u_impl.row_mem[set_value] = meta_row_value;
            dut.valid_ram.valid_mem[set_value][way_value] = 1'b1;
            @(negedge clk);
        end
    endtask

    task expect_resident_match_count;
        input [ADDR_BITS-1:0] addr_value;
        input integer         exp_count;
        input [8*160-1:0]     msg;
        reg   [SET_BITS-1:0]  set_value;
        reg   [TAG_BITS-1:0]  tag_value;
        reg   [WAY_COUNT-1:0] valid_bits_value;
        reg   [META_ROW_BITS-1:0] meta_row_value;
        integer local_count;
        integer local_way;
        reg [META_BITS-1:0] meta_value;
        begin
            set_value = addr_set(addr_value);
            tag_value = addr_tag(addr_value);
            valid_bits_value = dut.valid_ram.valid_mem[set_value];
            meta_row_value = dut.meta_store.gen_generic.u_impl.row_mem[set_value];
            local_count = 0;
            for (local_way = 0; local_way < WAY_COUNT; local_way = local_way + 1) begin
                meta_value = extract_meta_from_row(meta_row_value, local_way);
                if (valid_bits_value[local_way] && (meta_tag(meta_value) == tag_value)) begin
                    local_count = local_count + 1;
                end
            end
            if (local_count != exp_count) begin
                error_count = error_count + 1;
                $display("tb_axi_llc_subsystem_bypass_contract ERROR: %0s", msg);
                $display("  match_count actual=%0d expect=%0d", local_count, exp_count);
            end
        end
    endtask

    task expect_resident_line_way0;
        input [ADDR_BITS-1:0] addr_value;
        input [LINE_BITS-1:0] exp_line;
        input [8*160-1:0]     msg;
        reg   [SET_BITS-1:0]  set_value;
        reg   [DATA_ROW_BITS-1:0] data_row_value;
        reg   [LINE_BITS-1:0] line_value;
        begin
            set_value = addr_set(addr_value);
            data_row_value = dut.data_store.gen_generic.u_impl.row_mem[set_value];
            line_value = extract_line_from_row(data_row_value, 0);
            check_line_eq(line_value, exp_line, msg);
        end
    endtask

    task expect_resident_dirty_way0;
        input [ADDR_BITS-1:0] addr_value;
        input                 exp_dirty;
        input [8*160-1:0]     msg;
        reg   [SET_BITS-1:0]  set_value;
        reg   [META_ROW_BITS-1:0] meta_row_value;
        reg   [META_BITS-1:0] meta_value;
        begin
            set_value = addr_set(addr_value);
            meta_row_value = dut.meta_store.gen_generic.u_impl.row_mem[set_value];
            meta_value = extract_meta_from_row(meta_row_value, 0);
            if (meta_dirty(meta_value) !== exp_dirty) begin
                error_count = error_count + 1;
                $display("tb_axi_llc_subsystem_bypass_contract ERROR: %0s", msg);
                $display("  dirty actual=%0b expect=%0b", meta_dirty(meta_value), exp_dirty);
            end
        end
    endtask

    task capture_route_counters;
        begin
            cache_read_before = cache_read_count;
            cache_write_before = cache_write_count;
            bypass_read_before = bypass_read_count;
            bypass_write_before = bypass_write_count;
        end
    endtask

    task expect_route_deltas;
        input integer exp_cache_read_delta;
        input integer exp_cache_write_delta;
        input integer exp_bypass_read_delta;
        input integer exp_bypass_write_delta;
        input [8*160-1:0] msg;
        begin
            if ((cache_read_count - cache_read_before) != exp_cache_read_delta) begin
                error_count = error_count + 1;
                $display("tb_axi_llc_subsystem_bypass_contract ERROR: %0s", msg);
                $display("  cache_read_delta actual=%0d expect=%0d",
                         cache_read_count - cache_read_before,
                         exp_cache_read_delta);
            end
            if ((cache_write_count - cache_write_before) != exp_cache_write_delta) begin
                error_count = error_count + 1;
                $display("tb_axi_llc_subsystem_bypass_contract ERROR: %0s", msg);
                $display("  cache_write_delta actual=%0d expect=%0d",
                         cache_write_count - cache_write_before,
                         exp_cache_write_delta);
            end
            if ((bypass_read_count - bypass_read_before) != exp_bypass_read_delta) begin
                error_count = error_count + 1;
                $display("tb_axi_llc_subsystem_bypass_contract ERROR: %0s", msg);
                $display("  bypass_read_delta actual=%0d expect=%0d",
                         bypass_read_count - bypass_read_before,
                         exp_bypass_read_delta);
            end
            if ((bypass_write_count - bypass_write_before) != exp_bypass_write_delta) begin
                error_count = error_count + 1;
                $display("tb_axi_llc_subsystem_bypass_contract ERROR: %0s", msg);
                $display("  bypass_write_delta actual=%0d expect=%0d",
                         bypass_write_count - bypass_write_before,
                         exp_bypass_write_delta);
            end
        end
    endtask

    task issue_request;
        input                      write_value;
        input [ADDR_BITS-1:0]      addr_value;
        input [ID_BITS-1:0]        id_value;
        input [7:0]                total_size_value;
        input [LINE_BITS-1:0]      wdata_value;
        input [LINE_BYTES-1:0]     wstrb_value;
        input                      bypass_value;
        output [LINE_BITS-1:0]     resp_data_value;
        integer timeout;
        begin
            up_req_valid      = 1'b1;
            up_req_write      = write_value;
            up_req_addr       = addr_value;
            up_req_id         = id_value;
            up_req_total_size = total_size_value;
            up_req_wdata      = wdata_value;
            up_req_wstrb      = wstrb_value;
            up_req_bypass     = bypass_value;

            timeout = 0;
            while (!(up_req_valid && up_req_ready) && (timeout < 128)) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (!(up_req_valid && up_req_ready)) begin
                fatal_now("timeout waiting upstream request handshake");
            end

            @(negedge clk);
            up_req_valid      = 1'b0;
            up_req_write      = 1'b0;
            up_req_addr       = {ADDR_BITS{1'b0}};
            up_req_id         = {ID_BITS{1'b0}};
            up_req_total_size = 8'd0;
            up_req_wdata      = {LINE_BITS{1'b0}};
            up_req_wstrb      = {LINE_BYTES{1'b0}};
            up_req_bypass     = 1'b0;

            timeout = 0;
            while (!up_resp_valid && (timeout < 256)) begin
                @(posedge clk);
                #1;
                timeout = timeout + 1;
            end
            if (!up_resp_valid) begin
                $display("tb_axi_llc_subsystem_bypass_contract TIMEOUT:");
                $display("  active_mode=%0d active_offset=0x%08h reconfig_busy=%0b state=%0d",
                         active_mode, active_offset, reconfig_busy, reconfig_state);
                $display("  cache_counts rd=%0d wr=%0d  bypass_counts rd=%0d wr=%0d",
                         cache_read_count, cache_write_count,
                         bypass_read_count, bypass_write_count);
                $display("  last_cache  valid=%0b write=%0b addr=0x%08h id=0x%0h size=%0d",
                         cache_req_valid, last_cache_write, last_cache_addr,
                         last_cache_id, last_cache_size);
                $display("  last_bypass valid=%0b write=%0b addr=0x%08h id=0x%0h size=%0d",
                         bypass_req_valid, last_bypass_write, last_bypass_addr,
                         last_bypass_id, last_bypass_size);
                $display("  core_state=%0d req_write=%0b req_bypass=%0b req_id=0x%0h",
                         dut.cache_ctrl.state_r, dut.cache_ctrl.req_write_r,
                         dut.cache_ctrl.req_bypass_r, dut.cache_ctrl.req_id_r);
                $display("  bypass_if req_valid=%0b req_ready=%0b resp_valid=%0b resp_ready=%0b resp_id=0x%0h",
                         bypass_req_valid, bypass_req_ready,
                         bypass_resp_valid, bypass_resp_ready, bypass_resp_id);
                fatal_now("timeout waiting upstream response");
            end

            resp_data_value = up_resp_rdata;
            check_true((up_resp_id == id_value), "upstream response id mismatch");
            @(posedge clk);
        end
    endtask

    axi_llc_subsystem_core #(
        .ADDR_BITS        (ADDR_BITS),
        .ID_BITS          (ID_BITS),
        .MODE_BITS        (MODE_BITS),
        .LINE_BYTES       (LINE_BYTES),
        .LINE_BITS        (LINE_BITS),
        .LINE_OFFSET_BITS (LINE_OFFSET_BITS),
        .SET_COUNT        (SET_COUNT),
        .SET_BITS         (SET_BITS),
        .WAY_COUNT        (WAY_COUNT),
        .WAY_BITS         (WAY_BITS),
        .META_BITS        (META_BITS),
        .LLC_SIZE_BYTES   (SET_COUNT * WAY_COUNT * LINE_BYTES),
        .WINDOW_BYTES     (SET_COUNT * LINE_BYTES),
        .WINDOW_WAYS      (1),
        .RESET_MODE       (MODE_CACHE),
        .RESET_OFFSET     ({ADDR_BITS{1'b0}}),
        .USE_SMIC12_STORES(0)
    ) dut (
        .clk                   (clk),
        .rst_n                 (rst_n),
        .mode_req              (mode_req),
        .llc_mapped_offset_req (llc_mapped_offset_req),
        .up_req_valid          (up_req_valid),
        .up_req_ready          (up_req_ready),
        .up_req_write          (up_req_write),
        .up_req_addr           (up_req_addr),
        .up_req_id             (up_req_id),
        .up_req_total_size     (up_req_total_size),
        .up_req_wdata          (up_req_wdata),
        .up_req_wstrb          (up_req_wstrb),
        .up_req_bypass         (up_req_bypass),
        .up_resp_valid         (up_resp_valid),
        .up_resp_ready         (up_resp_ready),
        .up_resp_rdata         (up_resp_rdata),
        .up_resp_id            (up_resp_id),
        .cache_req_valid       (cache_req_valid),
        .cache_req_ready       (cache_req_ready),
        .cache_req_write       (cache_req_write),
        .cache_req_addr        (cache_req_addr),
        .cache_req_id          (cache_req_id),
        .cache_req_size        (cache_req_size),
        .cache_req_wdata       (cache_req_wdata),
        .cache_req_wstrb       (cache_req_wstrb),
        .cache_resp_valid      (cache_resp_valid),
        .cache_resp_ready      (cache_resp_ready),
        .cache_resp_rdata      (cache_resp_rdata),
        .cache_resp_id         (cache_resp_id),
        .bypass_req_valid      (bypass_req_valid),
        .bypass_req_ready      (bypass_req_ready),
        .bypass_req_write      (bypass_req_write),
        .bypass_req_addr       (bypass_req_addr),
        .bypass_req_id         (bypass_req_id),
        .bypass_req_size       (bypass_req_size),
        .bypass_req_wdata      (bypass_req_wdata),
        .bypass_req_wstrb      (bypass_req_wstrb),
        .bypass_resp_valid     (bypass_resp_valid),
        .bypass_resp_ready     (bypass_resp_ready),
        .bypass_resp_rdata     (bypass_resp_rdata),
        .bypass_resp_id        (bypass_resp_id),
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
            cache_resp_id <= {ID_BITS{1'b0}};
            bypass_resp_valid <= 1'b0;
            bypass_resp_rdata <= {LINE_BITS{1'b0}};
            bypass_resp_id <= {ID_BITS{1'b0}};
            cache_resp_pending_r <= 1'b0;
            cache_resp_pending_data_r <= {LINE_BITS{1'b0}};
            cache_resp_pending_id_r <= {ID_BITS{1'b0}};
            bypass_resp_pending_r <= 1'b0;
            bypass_resp_pending_data_r <= {LINE_BITS{1'b0}};
            bypass_resp_pending_id_r <= {ID_BITS{1'b0}};
            cache_req_count <= 0;
            cache_read_count <= 0;
            cache_write_count <= 0;
            bypass_req_count <= 0;
            bypass_read_count <= 0;
            bypass_write_count <= 0;
            last_cache_addr <= {ADDR_BITS{1'b0}};
            last_cache_id <= {ID_BITS{1'b0}};
            last_cache_write <= 1'b0;
            last_cache_size <= 8'd0;
            last_cache_wdata <= {LINE_BITS{1'b0}};
            last_cache_wstrb <= {LINE_BYTES{1'b0}};
            last_bypass_addr <= {ADDR_BITS{1'b0}};
            last_bypass_id <= {ID_BITS{1'b0}};
            last_bypass_write <= 1'b0;
            last_bypass_size <= 8'd0;
            last_bypass_wdata <= {LINE_BITS{1'b0}};
            last_bypass_wstrb <= {LINE_BYTES{1'b0}};
        end else begin
            cache_resp_valid <= 1'b0;
            bypass_resp_valid <= 1'b0;

            if (cache_req_valid && cache_req_ready) begin
                cache_req_count <= cache_req_count + 1;
                last_cache_addr <= cache_req_addr;
                last_cache_id <= cache_req_id;
                last_cache_write <= cache_req_write;
                last_cache_size <= cache_req_size;
                last_cache_wdata <= cache_req_wdata;
                last_cache_wstrb <= cache_req_wstrb;
                if (cache_req_write) begin
                    cache_write_count <= cache_write_count + 1;
                    lower_mem[mem_slot(cache_req_addr)] <=
                        merge_line(lower_mem[mem_slot(cache_req_addr)],
                                   cache_req_addr,
                                   cache_req_wdata,
                                   cache_req_wstrb);
                    cache_resp_pending_data_r <= {LINE_BITS{1'b0}};
                end else begin
                    cache_read_count <= cache_read_count + 1;
                    cache_resp_pending_data_r <= lower_mem[mem_slot(cache_req_addr)];
                end
                cache_resp_pending_id_r <= cache_req_id;
                cache_resp_pending_r <= 1'b1;
            end

            if (bypass_req_valid && bypass_req_ready) begin
                bypass_req_count <= bypass_req_count + 1;
                last_bypass_addr <= bypass_req_addr;
                last_bypass_id <= bypass_req_id;
                last_bypass_write <= bypass_req_write;
                last_bypass_size <= bypass_req_size;
                last_bypass_wdata <= bypass_req_wdata;
                last_bypass_wstrb <= bypass_req_wstrb;
                if (bypass_req_write) begin
                    bypass_write_count <= bypass_write_count + 1;
                    lower_mem[mem_slot(bypass_req_addr)] <=
                        merge_line(lower_mem[mem_slot(bypass_req_addr)],
                                   bypass_req_addr,
                                   bypass_req_wdata,
                                   bypass_req_wstrb);
                    bypass_resp_pending_data_r <= {LINE_BITS{1'b0}};
                end else begin
                    bypass_read_count <= bypass_read_count + 1;
                    bypass_resp_pending_data_r <= lower_mem[mem_slot(bypass_req_addr)];
                end
                bypass_resp_pending_id_r <= bypass_req_id;
                bypass_resp_pending_r <= 1'b1;
            end

            if (cache_resp_pending_r) begin
                cache_resp_valid <= 1'b1;
                cache_resp_rdata <= cache_resp_pending_data_r;
                cache_resp_id <= cache_resp_pending_id_r;
                if (cache_resp_ready) begin
                    cache_resp_pending_r <= 1'b0;
                end
            end

            if (bypass_resp_pending_r) begin
                bypass_resp_valid <= 1'b1;
                bypass_resp_rdata <= bypass_resp_pending_data_r;
                bypass_resp_id <= bypass_resp_pending_id_r;
                if (bypass_resp_ready) begin
                    bypass_resp_pending_r <= 1'b0;
                end
            end
        end
    end

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        mode_req = MODE_CACHE;
        llc_mapped_offset_req = {ADDR_BITS{1'b0}};
        up_req_valid = 1'b0;
        up_req_write = 1'b0;
        up_req_addr = {ADDR_BITS{1'b0}};
        up_req_id = {ID_BITS{1'b0}};
        up_req_total_size = 8'd0;
        up_req_wdata = {LINE_BITS{1'b0}};
        up_req_wstrb = {LINE_BYTES{1'b0}};
        up_req_bypass = 1'b0;
        up_resp_ready = 1'b1;
        cache_req_ready = 1'b1;
        bypass_req_ready = 1'b1;
        invalidate_line_valid = 1'b0;
        invalidate_line_addr = {ADDR_BITS{1'b0}};
        invalidate_all_valid = 1'b0;
        error_count = 0;
        tmp_resp_line = {LINE_BITS{1'b0}};
        tmp_expected_line = {LINE_BITS{1'b0}};

        clear_lower_mem();
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        wait_active_config(MODE_CACHE, {ADDR_BITS{1'b0}});
        clear_resident_arrays();
        clear_lower_mem();
        check_true(!config_error, "config_error should stay low");

        note_case("case1 bypass read hit should return resident data without lower bypass read");
        set_lower_line(BYPASS_READ_HIT_ADDR, 64'h1111_2222_3333_4444);
        preload_resident_line(BYPASS_READ_HIT_ADDR, 0, 64'hAAAA_BBBB_CCCC_DDDD, 1'b0);
        capture_route_counters();
        issue_request(1'b0, BYPASS_READ_HIT_ADDR, 4'h1, FULL_SIZE,
                      {LINE_BITS{1'b0}}, {LINE_BYTES{1'b0}}, 1'b1, tmp_resp_line);
        check_line_eq(tmp_resp_line, 64'hAAAA_BBBB_CCCC_DDDD,
                      "bypass read hit should return resident line");
        expect_route_deltas(0, 0, 0, 0,
                            "bypass read hit should not touch lower cache/bypass");

        note_case("case2 bypass write hit should update resident, stay clean, and write through");
        clear_resident_arrays();
        clear_lower_mem();
        set_lower_line(BYPASS_WRITE_HIT_ADDR, 64'hABAB_CDCD_EFEF_0101);
        preload_resident_line(BYPASS_WRITE_HIT_ADDR, 0, 64'h0102_0304_0506_0708, 1'b0);
        tmp_expected_line = 64'hCAFE_FEED_DEAD_BEEF;
        capture_route_counters();
        issue_request(1'b1, BYPASS_WRITE_HIT_ADDR, 4'h2, FULL_SIZE,
                      tmp_expected_line, 8'hFF, 1'b1, tmp_resp_line);
        check_line_eq(tmp_resp_line, {LINE_BITS{1'b0}},
                      "bypass write hit should return zero data");
        expect_route_deltas(0, 0, 0, 1,
                            "bypass write hit should only issue one lower bypass write");
        expect_resident_line_way0(BYPASS_WRITE_HIT_ADDR, tmp_expected_line,
                                  "bypass write hit should shadow-update resident line");
        expect_resident_dirty_way0(BYPASS_WRITE_HIT_ADDR, 1'b0,
                                   "bypass write hit must not set dirty");
        capture_route_counters();
        issue_request(1'b0, BYPASS_WRITE_HIT_ADDR, 4'h3, FULL_SIZE,
                      {LINE_BITS{1'b0}}, {LINE_BYTES{1'b0}}, 1'b1, tmp_resp_line);
        check_line_eq(tmp_resp_line, tmp_expected_line,
                      "bypass reread after write hit should observe updated resident line");
        expect_route_deltas(0, 0, 0, 0,
                            "bypass reread after write hit should not go lower");

        note_case("case3 bypass read miss should go lower and not install resident");
        clear_resident_arrays();
        clear_lower_mem();
        set_lower_line(BYPASS_READ_MISS_ADDR, 64'hDEAD_BEEF_0123_4567);
        capture_route_counters();
        issue_request(1'b0, BYPASS_READ_MISS_ADDR, 4'h4, FULL_SIZE,
                      {LINE_BITS{1'b0}}, {LINE_BYTES{1'b0}}, 1'b1, tmp_resp_line);
        check_line_eq(tmp_resp_line, 64'hDEAD_BEEF_0123_4567,
                      "bypass read miss should return lower bypass data");
        expect_route_deltas(0, 0, 1, 0,
                            "bypass read miss should issue one lower bypass read");
        expect_resident_match_count(BYPASS_READ_MISS_ADDR, 0,
                                    "bypass read miss must not install resident line");
        capture_route_counters();
        issue_request(1'b0, BYPASS_READ_MISS_ADDR, 4'h5, FULL_SIZE,
                      {LINE_BITS{1'b0}}, {LINE_BYTES{1'b0}}, 1'b1, tmp_resp_line);
        check_line_eq(tmp_resp_line, 64'hDEAD_BEEF_0123_4567,
                      "second bypass read miss should still return lower bypass data");
        expect_route_deltas(0, 0, 1, 0,
                            "second bypass read miss should still issue lower bypass read");
        expect_resident_match_count(BYPASS_READ_MISS_ADDR, 0,
                                    "repeated bypass read miss must still not install resident");

        note_case("case4 bypass write miss should write through only and not install resident");
        clear_resident_arrays();
        clear_lower_mem();
        set_lower_line(BYPASS_WRITE_MISS_ADDR, 64'h0011_2233_4455_6677);
        capture_route_counters();
        issue_request(1'b1, BYPASS_WRITE_MISS_ADDR, 4'h6, FULL_SIZE,
                      64'h8899_AABB_CCDD_EEFF, 8'hFF, 1'b1, tmp_resp_line);
        check_line_eq(tmp_resp_line, {LINE_BITS{1'b0}},
                      "bypass write miss should return zero data");
        expect_route_deltas(0, 0, 0, 1,
                            "bypass write miss should issue one lower bypass write");
        expect_resident_match_count(BYPASS_WRITE_MISS_ADDR, 0,
                                    "bypass write miss must not install resident line");
        capture_route_counters();
        issue_request(1'b0, BYPASS_WRITE_MISS_ADDR, 4'h7, FULL_SIZE,
                      {LINE_BITS{1'b0}}, {LINE_BYTES{1'b0}}, 1'b1, tmp_resp_line);
        check_line_eq(tmp_resp_line, 64'h8899_AABB_CCDD_EEFF,
                      "bypass reread after write miss should come from lower memory");
        expect_route_deltas(0, 0, 1, 0,
                            "bypass reread after write miss should issue lower bypass read");
        expect_resident_match_count(BYPASS_WRITE_MISS_ADDR, 0,
                                    "bypass reread after write miss must still not install resident");

        if (error_count == 0) begin
            $display("tb_axi_llc_subsystem_bypass_contract PASS");
            $finish(0);
        end else begin
            $display("tb_axi_llc_subsystem_bypass_contract FAIL errors=%0d", error_count);
            $finish(1);
        end
    end

endmodule
