`timescale 1ns / 1ps
`include "axi_llc_params.vh"
`include "axi_llc_cache_cpp_trace_vectors.vh"

module tb_llc_cache_ctrl_cpp_trace_contract;

    localparam ADDR_BITS        = CPP_LLC_CACHE_ADDR_BITS;
    localparam ID_BITS          = CPP_LLC_CACHE_ID_BITS;
    localparam LINE_BYTES       = CPP_LLC_CACHE_LINE_BYTES;
    localparam LINE_BITS        = CPP_LLC_CACHE_LINE_BITS;
    localparam LINE_OFFSET_BITS = CPP_LLC_CACHE_LINE_OFFSET_BITS;
    localparam SET_COUNT        = CPP_LLC_CACHE_SET_COUNT;
    localparam SET_BITS         = CPP_LLC_CACHE_SET_BITS;
    localparam WAY_COUNT        = CPP_LLC_CACHE_WAY_COUNT;
    localparam WAY_BITS         = CPP_LLC_CACHE_WAY_BITS;
    localparam META_BITS        = CPP_LLC_CACHE_META_BITS;
    localparam READ_RESP_BYTES  = CPP_LLC_CACHE_LINE_BYTES;
    localparam READ_RESP_BITS   = CPP_LLC_CACHE_LINE_BITS;
    localparam DATA_ROW_BITS    = CPP_LLC_CACHE_DATA_ROW_BITS;
    localparam META_ROW_BITS    = CPP_LLC_CACHE_META_ROW_BITS;

    reg                       clk;
    reg                       rst_n;
    reg                       req_valid;
    reg                       req_write;
    reg [ADDR_BITS-1:0]       req_addr;
    reg [ID_BITS-1:0]         req_id;
    reg [7:0]                 req_total_size;
    reg [LINE_BITS-1:0]       req_wdata;
    reg [LINE_BYTES-1:0]      req_wstrb;
    reg                       invalidate_line_valid;
    reg [ADDR_BITS-1:0]       invalidate_line_addr;
    wire                      req_ready;
    wire                      invalidate_line_accepted;
    wire                      resp_valid;
    wire [READ_RESP_BITS-1:0] resp_rdata;
    wire [ID_BITS-1:0]        resp_id;
    wire [1:0]                resp_code;

    wire                      data_rd_en;
    wire [SET_BITS-1:0]       data_rd_set;
    reg                       data_rd_valid;
    reg [DATA_ROW_BITS-1:0]   data_rd_row;
    wire                      data_wr_en;
    wire [SET_BITS-1:0]       data_wr_set;
    wire [WAY_COUNT-1:0]      data_wr_way_mask;
    wire [DATA_ROW_BITS-1:0]  data_wr_row;
    wire                      meta_rd_en;
    wire [SET_BITS-1:0]       meta_rd_set;
    reg                       meta_rd_valid;
    reg [META_ROW_BITS-1:0]   meta_rd_row;
    wire                      meta_wr_en;
    wire [SET_BITS-1:0]       meta_wr_set;
    wire [WAY_COUNT-1:0]      meta_wr_way_mask;
    wire [META_ROW_BITS-1:0]  meta_wr_row;
    wire                      valid_rd_en;
    wire [SET_BITS-1:0]       valid_rd_set;
    reg                       valid_rd_valid;
    reg [WAY_COUNT-1:0]       valid_rd_bits;
    wire                      valid_wr_en;
    wire [SET_BITS-1:0]       valid_wr_set;
    wire [WAY_COUNT-1:0]      valid_wr_mask;
    wire [WAY_COUNT-1:0]      valid_wr_bits;
    wire                      repl_rd_en;
    wire [SET_BITS-1:0]       repl_rd_set;
    reg                       repl_rd_valid;
    reg [WAY_BITS-1:0]        repl_rd_way;
    wire                      repl_wr_en;
    wire [SET_BITS-1:0]       repl_wr_set;
    wire [WAY_BITS-1:0]       repl_wr_way;
    wire                      flush_busy;
    wire                      dirty_present;
    wire                      quiescent;
    wire [`AXI_LLC_MAX_OUTSTANDING-1:0] victim_line_valid;
    wire [(`AXI_LLC_MAX_OUTSTANDING*ADDR_BITS)-1:0] victim_line_addr;
    wire                      mem_req_valid;
    reg                       mem_req_ready;
    wire                      mem_req_write;
    wire [ADDR_BITS-1:0]      mem_req_addr;
    wire [ID_BITS-1:0]        mem_req_id;
    wire [LINE_BITS-1:0]      mem_req_wdata;
    wire [LINE_BYTES-1:0]     mem_req_wstrb;
    wire [7:0]                mem_req_size;
    reg                       mem_resp_valid;
    reg [READ_RESP_BITS-1:0]  mem_resp_rdata;
    reg [ID_BITS-1:0]         mem_resp_id;
    reg [1:0]                 mem_resp_code;
    wire                      mem_resp_ready;
    wire                      bypass_req_valid;
    wire                      bypass_req_write;
    wire [ADDR_BITS-1:0]      bypass_req_addr;
    wire [ID_BITS-1:0]        bypass_req_id;
    wire [7:0]                bypass_req_size;
    wire [LINE_BITS-1:0]      bypass_req_wdata;
    wire [LINE_BYTES-1:0]     bypass_req_wstrb;
    wire                      bypass_resp_ready;

    always #5 clk = ~clk;

    task fail_now;
        input [8*240-1:0] msg;
        begin
            $display("tb_llc_cache_ctrl_cpp_trace_contract FAIL: %0s", msg);
            $finish(1);
        end
    endtask

    task reset_dut;
        begin
            clk = 1'b0;
            rst_n = 1'b0;
            req_valid = 1'b0;
            req_write = 1'b0;
            req_addr = {ADDR_BITS{1'b0}};
            req_id = {ID_BITS{1'b0}};
            req_total_size = 8'd0;
            req_wdata = {LINE_BITS{1'b0}};
            req_wstrb = {LINE_BYTES{1'b0}};
            invalidate_line_valid = 1'b0;
            invalidate_line_addr = {ADDR_BITS{1'b0}};
            data_rd_valid = 1'b1;
            data_rd_row = {DATA_ROW_BITS{1'b0}};
            meta_rd_valid = 1'b1;
            meta_rd_row = {META_ROW_BITS{1'b0}};
            valid_rd_valid = 1'b1;
            valid_rd_bits = {WAY_COUNT{1'b0}};
            repl_rd_valid = 1'b1;
            repl_rd_way = {WAY_BITS{1'b0}};
            mem_req_ready = 1'b0;
            mem_resp_valid = 1'b0;
            mem_resp_rdata = {READ_RESP_BITS{1'b0}};
            mem_resp_id = {ID_BITS{1'b0}};
            mem_resp_code = 2'b00;
            repeat (5) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;
            @(negedge clk);
        end
    endtask

    task run_invalidate_line;
        integer timeout;
        begin
            reset_dut();

            @(negedge clk);
            invalidate_line_valid = 1'b1;
            invalidate_line_addr = CPP_LLC_INV_ADDR;
            data_rd_row = CPP_LLC_INV_DATA_RD_ROW;
            meta_rd_row = CPP_LLC_INV_META_RD_ROW;
            valid_rd_bits = CPP_LLC_INV_VALID_RD_BITS;
            repl_rd_way = CPP_LLC_INV_REPL_RD_WAY;
            #1;
            if (!invalidate_line_accepted) begin
                fail_now("C++ trace invalidate_line was not accepted");
            end
            if (!data_rd_en || !meta_rd_en || !valid_rd_en || !repl_rd_en) begin
                fail_now("C++ trace invalidate_line did not issue lookup");
            end
            if (data_rd_set != CPP_LLC_INV_SET ||
                meta_rd_set != CPP_LLC_INV_SET ||
                valid_rd_set != CPP_LLC_INV_SET ||
                repl_rd_set != CPP_LLC_INV_SET) begin
                fail_now("C++ trace invalidate_line lookup set mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            invalidate_line_valid = 1'b0;

            timeout = 20;
            while (!valid_wr_en && (timeout > 0)) begin
                if (data_wr_en || meta_wr_en || repl_wr_en) begin
                    fail_now("C++ trace invalidate_line updated non-valid table");
                end
                @(posedge clk);
                @(negedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace invalidate_line valid clear timeout");
            end
            #1;
            if (data_wr_en || meta_wr_en || repl_wr_en) begin
                fail_now("C++ trace invalidate_line should only clear valid table");
            end
            if (valid_wr_set != CPP_LLC_INV_VALID_WR_SET ||
                valid_wr_mask != CPP_LLC_INV_VALID_WR_MASK ||
                valid_wr_bits != CPP_LLC_INV_VALID_WR_BITS) begin
                fail_now("C++ trace invalidate_line valid clear mismatch");
            end
            if (resp_valid || mem_req_valid || bypass_req_valid) begin
                fail_now("C++ trace invalidate_line produced unexpected side effect");
            end
        end
    endtask

    task check_no_lower_side_effect;
        begin
            if (mem_req_valid || bypass_req_valid) begin
                fail_now("partial write hit unexpectedly issued mem/bypass request");
            end
            if (mem_resp_ready || bypass_resp_ready) begin
                fail_now("partial write hit unexpectedly accepted mem/bypass response");
            end
        end
    endtask

    task run_partial_write_hit;
        integer timeout;
        reg saw_lookup;
        reg saw_write;
        begin
            reset_dut();

            saw_lookup = 1'b0;
            saw_write = 1'b0;
            @(negedge clk);
            req_write = 1'b1;
            req_addr = CPP_LLC_PWH_REQ_ADDR;
            req_id = CPP_LLC_PWH_REQ_ID;
            req_total_size = CPP_LLC_PWH_REQ_SIZE;
            req_wdata = CPP_LLC_PWH_REQ_WDATA;
            req_wstrb = CPP_LLC_PWH_REQ_WSTRB;
            data_rd_row = CPP_LLC_PWH_DATA_RD_ROW;
            meta_rd_row = CPP_LLC_PWH_META_RD_ROW;
            valid_rd_bits = CPP_LLC_PWH_VALID_RD_BITS;
            repl_rd_way = CPP_LLC_PWH_REPL_RD_WAY;
            req_valid = 1'b1;
            #1;
            if (!req_ready) begin
                fail_now("C++ trace partial write hit request was not ready");
            end
            if (!data_rd_en || !meta_rd_en || !valid_rd_en || !repl_rd_en) begin
                fail_now("C++ trace partial write hit did not issue lookup");
            end
            if (data_rd_set != CPP_LLC_PWH_REQ_SET ||
                meta_rd_set != CPP_LLC_PWH_REQ_SET ||
                valid_rd_set != CPP_LLC_PWH_REQ_SET ||
                repl_rd_set != CPP_LLC_PWH_REQ_SET) begin
                fail_now("C++ trace partial write hit lookup set mismatch");
            end
            saw_lookup = 1'b1;
            check_no_lower_side_effect();

            @(posedge clk);
            @(negedge clk);
            req_valid = 1'b0;

            timeout = 20;
            while (!data_wr_en && (timeout > 0)) begin
                #1;
                check_no_lower_side_effect();
                @(posedge clk);
                @(negedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace partial write hit table write timeout");
            end
            #1;
            if (!meta_wr_en || !valid_wr_en || !repl_wr_en) begin
                fail_now("C++ trace partial write hit did not update all table rows");
            end
            if (data_wr_set != CPP_LLC_PWH_DATA_WR_SET ||
                data_wr_way_mask != CPP_LLC_PWH_DATA_WR_WAY_MASK ||
                data_wr_row != CPP_LLC_PWH_DATA_WR_ROW) begin
                fail_now("C++ trace partial write hit data write mismatch");
            end
            if (meta_wr_set != CPP_LLC_PWH_META_WR_SET ||
                meta_wr_way_mask != CPP_LLC_PWH_META_WR_WAY_MASK ||
                meta_wr_row != CPP_LLC_PWH_META_WR_ROW) begin
                fail_now("C++ trace partial write hit meta write mismatch");
            end
            if (valid_wr_set != CPP_LLC_PWH_VALID_WR_SET ||
                valid_wr_mask != CPP_LLC_PWH_VALID_WR_MASK ||
                valid_wr_bits != CPP_LLC_PWH_VALID_WR_BITS) begin
                fail_now("C++ trace partial write hit valid write mismatch");
            end
            if (repl_wr_set != CPP_LLC_PWH_REPL_WR_SET ||
                repl_wr_way != CPP_LLC_PWH_REPL_WR_WAY) begin
                fail_now("C++ trace partial write hit repl write mismatch");
            end
            check_no_lower_side_effect();
            saw_write = 1'b1;

            @(posedge clk);
            @(negedge clk);
            #1;
            if (!resp_valid) begin
                fail_now("C++ trace partial write hit response missing");
            end
            if (resp_id != CPP_LLC_PWH_RESP_ID ||
                resp_code != CPP_LLC_PWH_RESP_CODE) begin
                fail_now("C++ trace partial write hit response mismatch");
            end
            if (!saw_lookup || !saw_write) begin
                fail_now("C++ trace partial write hit internal coverage missing");
            end
        end
    endtask

    task run_read_miss_refill;
        integer timeout;
        begin
            reset_dut();

            @(negedge clk);
            req_write = 1'b0;
            req_addr = CPP_LLC_RMR_REQ_ADDR;
            req_id = CPP_LLC_RMR_REQ_ID;
            req_total_size = CPP_LLC_RMR_REQ_SIZE;
            req_wdata = {LINE_BITS{1'b0}};
            req_wstrb = {LINE_BYTES{1'b0}};
            data_rd_row = CPP_LLC_RMR_DATA_RD_ROW;
            meta_rd_row = CPP_LLC_RMR_META_RD_ROW;
            valid_rd_bits = CPP_LLC_RMR_VALID_RD_BITS;
            repl_rd_way = CPP_LLC_RMR_REPL_RD_WAY;
            req_valid = 1'b1;
            #1;
            if (!req_ready) begin
                fail_now("C++ trace read miss request was not ready");
            end
            if (!data_rd_en || !meta_rd_en || !valid_rd_en || !repl_rd_en) begin
                fail_now("C++ trace read miss did not issue lookup");
            end
            if (data_rd_set != CPP_LLC_RMR_REQ_SET ||
                meta_rd_set != CPP_LLC_RMR_REQ_SET ||
                valid_rd_set != CPP_LLC_RMR_REQ_SET ||
                repl_rd_set != CPP_LLC_RMR_REQ_SET) begin
                fail_now("C++ trace read miss lookup set mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            req_valid = 1'b0;

            timeout = 40;
            while (!mem_req_valid && (timeout > 0)) begin
                @(posedge clk);
                @(negedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace read miss refill request timeout");
            end
            #1;
            if (mem_req_write ||
                mem_req_addr != CPP_LLC_RMR_MEM_REQ_ADDR ||
                mem_req_id != CPP_LLC_RMR_MEM_REQ_ID ||
                mem_req_size != CPP_LLC_RMR_MEM_REQ_SIZE) begin
                fail_now("C++ trace read miss refill request mismatch");
            end
            if (bypass_req_valid) begin
                fail_now("C++ trace read miss incorrectly used bypass request");
            end
            mem_req_ready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mem_req_ready = 1'b0;

            mem_resp_id = CPP_LLC_RMR_MEM_REQ_ID;
            mem_resp_rdata = CPP_LLC_RMR_MEM_RESP_LINE;
            mem_resp_code = 2'b00;
            mem_resp_valid = 1'b1;
            #1;
            if (!mem_resp_ready) begin
                fail_now("C++ trace read miss refill response was not ready");
            end
            @(posedge clk);
            @(negedge clk);
            mem_resp_valid = 1'b0;

            timeout = 40;
            while (!data_wr_en && (timeout > 0)) begin
                @(posedge clk);
                @(negedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace read miss refill install timeout");
            end
            #1;
            if (!meta_wr_en || !valid_wr_en || !repl_wr_en) begin
                fail_now("C++ trace read miss did not update all refill rows");
            end
            if (data_wr_set != CPP_LLC_RMR_DATA_WR_SET ||
                data_wr_way_mask != CPP_LLC_RMR_DATA_WR_WAY_MASK ||
                data_wr_row != CPP_LLC_RMR_DATA_WR_ROW) begin
                fail_now("C++ trace read miss data install mismatch");
            end
            if (meta_wr_set != CPP_LLC_RMR_META_WR_SET ||
                meta_wr_way_mask != CPP_LLC_RMR_META_WR_WAY_MASK ||
                meta_wr_row != CPP_LLC_RMR_META_WR_ROW) begin
                fail_now("C++ trace read miss meta install mismatch");
            end
            if (valid_wr_set != CPP_LLC_RMR_VALID_WR_SET ||
                valid_wr_mask != CPP_LLC_RMR_VALID_WR_MASK ||
                valid_wr_bits != CPP_LLC_RMR_VALID_WR_BITS) begin
                fail_now("C++ trace read miss valid install mismatch");
            end
            if (repl_wr_set != CPP_LLC_RMR_REPL_WR_SET ||
                repl_wr_way != CPP_LLC_RMR_REPL_WR_WAY) begin
                fail_now("C++ trace read miss repl install mismatch");
            end

            @(posedge clk);
            @(negedge clk);
            #1;
            if (!resp_valid) begin
                fail_now("C++ trace read miss response missing");
            end
            if (resp_id != CPP_LLC_RMR_RESP_ID ||
                resp_code != CPP_LLC_RMR_RESP_CODE ||
                resp_rdata != CPP_LLC_RMR_RESP_RDATA) begin
                fail_now("C++ trace read miss response mismatch");
            end
        end
    endtask

    task run_partial_write_miss_refill;
        integer timeout;
        begin
            reset_dut();

            @(negedge clk);
            req_write = 1'b1;
            req_addr = CPP_LLC_PWM_REQ_ADDR;
            req_id = CPP_LLC_PWM_REQ_ID;
            req_total_size = CPP_LLC_PWM_REQ_SIZE;
            req_wdata = CPP_LLC_PWM_REQ_WDATA;
            req_wstrb = CPP_LLC_PWM_REQ_WSTRB;
            data_rd_row = CPP_LLC_PWM_DATA_RD_ROW;
            meta_rd_row = CPP_LLC_PWM_META_RD_ROW;
            valid_rd_bits = CPP_LLC_PWM_VALID_RD_BITS;
            repl_rd_way = CPP_LLC_PWM_REPL_RD_WAY;
            req_valid = 1'b1;
            #1;
            if (!req_ready) begin
                fail_now("C++ trace partial write miss request was not ready");
            end
            if (!data_rd_en || !meta_rd_en || !valid_rd_en || !repl_rd_en) begin
                fail_now("C++ trace partial write miss did not issue lookup");
            end
            if (data_rd_set != CPP_LLC_PWM_REQ_SET ||
                meta_rd_set != CPP_LLC_PWM_REQ_SET ||
                valid_rd_set != CPP_LLC_PWM_REQ_SET ||
                repl_rd_set != CPP_LLC_PWM_REQ_SET) begin
                fail_now("C++ trace partial write miss lookup set mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            req_valid = 1'b0;

            timeout = 40;
            while (!mem_req_valid && (timeout > 0)) begin
                @(posedge clk);
                @(negedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace partial write miss refill request timeout");
            end
            #1;
            if (mem_req_write ||
                mem_req_addr != CPP_LLC_PWM_MEM_REQ_ADDR ||
                mem_req_id != CPP_LLC_PWM_MEM_REQ_ID ||
                mem_req_size != CPP_LLC_PWM_MEM_REQ_SIZE) begin
                fail_now("C++ trace partial write miss refill request mismatch");
            end
            if (bypass_req_valid) begin
                fail_now("C++ trace partial write miss incorrectly used bypass request");
            end
            mem_req_ready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mem_req_ready = 1'b0;

            mem_resp_id = CPP_LLC_PWM_MEM_REQ_ID;
            mem_resp_rdata = CPP_LLC_PWM_MEM_RESP_LINE;
            mem_resp_code = 2'b00;
            mem_resp_valid = 1'b1;
            #1;
            if (!mem_resp_ready) begin
                fail_now("C++ trace partial write miss refill response was not ready");
            end
            @(posedge clk);
            @(negedge clk);
            mem_resp_valid = 1'b0;

            timeout = 40;
            while (!data_wr_en && (timeout > 0)) begin
                @(posedge clk);
                @(negedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace partial write miss refill install timeout");
            end
            #1;
            if (!meta_wr_en || !valid_wr_en || !repl_wr_en) begin
                fail_now("C++ trace partial write miss did not update all refill rows");
            end
            if (data_wr_set != CPP_LLC_PWM_DATA_WR_SET ||
                data_wr_way_mask != CPP_LLC_PWM_DATA_WR_WAY_MASK ||
                data_wr_row != CPP_LLC_PWM_DATA_WR_ROW) begin
                fail_now("C++ trace partial write miss data install mismatch");
            end
            if (meta_wr_set != CPP_LLC_PWM_META_WR_SET ||
                meta_wr_way_mask != CPP_LLC_PWM_META_WR_WAY_MASK ||
                meta_wr_row != CPP_LLC_PWM_META_WR_ROW) begin
                fail_now("C++ trace partial write miss meta install mismatch");
            end
            if (valid_wr_set != CPP_LLC_PWM_VALID_WR_SET ||
                valid_wr_mask != CPP_LLC_PWM_VALID_WR_MASK ||
                valid_wr_bits != CPP_LLC_PWM_VALID_WR_BITS) begin
                fail_now("C++ trace partial write miss valid install mismatch");
            end
            if (repl_wr_set != CPP_LLC_PWM_REPL_WR_SET ||
                repl_wr_way != CPP_LLC_PWM_REPL_WR_WAY) begin
                fail_now("C++ trace partial write miss repl install mismatch");
            end

            @(posedge clk);
            @(negedge clk);
            #1;
            if (!resp_valid) begin
                fail_now("C++ trace partial write miss response missing");
            end
            if (resp_id != CPP_LLC_PWM_RESP_ID ||
                resp_code != CPP_LLC_PWM_RESP_CODE) begin
                fail_now("C++ trace partial write miss response mismatch");
            end
        end
    endtask

    task run_dirty_victim_writeback;
        integer timeout;
        begin
            reset_dut();

            @(negedge clk);
            req_write = 1'b1;
            req_addr = CPP_LLC_DVW_REQ_ADDR;
            req_id = CPP_LLC_DVW_REQ_ID;
            req_total_size = CPP_LLC_DVW_REQ_SIZE;
            req_wdata = CPP_LLC_DVW_REQ_WDATA;
            req_wstrb = CPP_LLC_DVW_REQ_WSTRB;
            data_rd_row = CPP_LLC_DVW_DATA_RD_ROW;
            meta_rd_row = CPP_LLC_DVW_META_RD_ROW;
            valid_rd_bits = CPP_LLC_DVW_VALID_RD_BITS;
            repl_rd_way = CPP_LLC_DVW_REPL_RD_WAY;
            req_valid = 1'b1;
            #1;
            if (!req_ready) begin
                fail_now("C++ trace dirty victim request was not ready");
            end
            if (!data_rd_en || !meta_rd_en || !valid_rd_en || !repl_rd_en) begin
                fail_now("C++ trace dirty victim did not issue lookup");
            end
            if (data_rd_set != CPP_LLC_DVW_REQ_SET ||
                meta_rd_set != CPP_LLC_DVW_REQ_SET ||
                valid_rd_set != CPP_LLC_DVW_REQ_SET ||
                repl_rd_set != CPP_LLC_DVW_REQ_SET) begin
                fail_now("C++ trace dirty victim lookup set mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            req_valid = 1'b0;

            timeout = 40;
            while (!mem_req_valid && (timeout > 0)) begin
                if (data_wr_en || meta_wr_en) begin
                    fail_now("C++ trace dirty victim installed before writeback");
                end
                @(posedge clk);
                @(negedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace dirty victim writeback request timeout");
            end
            #1;
            if (!mem_req_write ||
                mem_req_addr != CPP_LLC_DVW_WB_REQ_ADDR ||
                mem_req_id != CPP_LLC_DVW_WB_REQ_ID ||
                mem_req_size != CPP_LLC_DVW_WB_REQ_SIZE ||
                mem_req_wdata != CPP_LLC_DVW_WB_REQ_DATA ||
                mem_req_wstrb != CPP_LLC_DVW_WB_REQ_STRB) begin
                fail_now("C++ trace dirty victim writeback request mismatch");
            end
            if (data_wr_en || meta_wr_en || valid_wr_en || repl_wr_en) begin
                fail_now("C++ trace dirty victim table update before writeback response");
            end
            mem_req_ready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mem_req_ready = 1'b0;

            mem_resp_id = CPP_LLC_DVW_WB_REQ_ID;
            mem_resp_rdata = {READ_RESP_BITS{1'b0}};
            mem_resp_code = 2'b00;
            mem_resp_valid = 1'b1;
            #1;
            if (!mem_resp_ready) begin
                fail_now("C++ trace dirty victim writeback response was not ready");
            end
            @(posedge clk);
            @(negedge clk);
            mem_resp_valid = 1'b0;

            timeout = 40;
            while (!data_wr_en && (timeout > 0)) begin
                @(posedge clk);
                @(negedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace dirty victim install timeout");
            end
            #1;
            if (!meta_wr_en || !valid_wr_en || !repl_wr_en) begin
                fail_now("C++ trace dirty victim did not update all install rows");
            end
            if (data_wr_set != CPP_LLC_DVW_DATA_WR_SET ||
                data_wr_way_mask != CPP_LLC_DVW_DATA_WR_WAY_MASK ||
                data_wr_row != CPP_LLC_DVW_DATA_WR_ROW) begin
                fail_now("C++ trace dirty victim data install mismatch");
            end
            if (meta_wr_set != CPP_LLC_DVW_META_WR_SET ||
                meta_wr_way_mask != CPP_LLC_DVW_META_WR_WAY_MASK ||
                meta_wr_row != CPP_LLC_DVW_META_WR_ROW) begin
                fail_now("C++ trace dirty victim meta install mismatch");
            end
            if (valid_wr_set != CPP_LLC_DVW_VALID_WR_SET ||
                valid_wr_mask != CPP_LLC_DVW_VALID_WR_MASK ||
                valid_wr_bits != CPP_LLC_DVW_VALID_WR_BITS) begin
                fail_now("C++ trace dirty victim valid install mismatch");
            end
            if (repl_wr_set != CPP_LLC_DVW_REPL_WR_SET ||
                repl_wr_way != CPP_LLC_DVW_REPL_WR_WAY) begin
                fail_now("C++ trace dirty victim repl install mismatch");
            end

            @(posedge clk);
            @(negedge clk);
            #1;
            if (!resp_valid) begin
                fail_now("C++ trace dirty victim response missing");
            end
            if (resp_id != CPP_LLC_DVW_RESP_ID ||
                resp_code != CPP_LLC_DVW_RESP_CODE) begin
                fail_now("C++ trace dirty victim response mismatch");
            end
        end
    endtask

    task run_dirty_partial_write_miss;
        integer timeout;
        begin
            reset_dut();

            @(negedge clk);
            req_write = 1'b1;
            req_addr = CPP_LLC_DVPW_REQ_ADDR;
            req_id = CPP_LLC_DVPW_REQ_ID;
            req_total_size = CPP_LLC_DVPW_REQ_SIZE;
            req_wdata = CPP_LLC_DVPW_REQ_WDATA;
            req_wstrb = CPP_LLC_DVPW_REQ_WSTRB;
            data_rd_row = CPP_LLC_DVPW_DATA_RD_ROW;
            meta_rd_row = CPP_LLC_DVPW_META_RD_ROW;
            valid_rd_bits = CPP_LLC_DVPW_VALID_RD_BITS;
            repl_rd_way = CPP_LLC_DVPW_REPL_RD_WAY;
            req_valid = 1'b1;
            #1;
            if (!req_ready) begin
                fail_now("C++ trace dirty partial request was not ready");
            end
            if (!data_rd_en || !meta_rd_en || !valid_rd_en || !repl_rd_en) begin
                fail_now("C++ trace dirty partial did not issue lookup");
            end
            if (data_rd_set != CPP_LLC_DVPW_REQ_SET ||
                meta_rd_set != CPP_LLC_DVPW_REQ_SET ||
                valid_rd_set != CPP_LLC_DVPW_REQ_SET ||
                repl_rd_set != CPP_LLC_DVPW_REQ_SET) begin
                fail_now("C++ trace dirty partial lookup set mismatch");
            end
            @(posedge clk);
            @(negedge clk);
            req_valid = 1'b0;

            timeout = 40;
            while (!mem_req_valid && (timeout > 0)) begin
                if (data_wr_en || meta_wr_en || valid_wr_en || repl_wr_en) begin
                    fail_now("C++ trace dirty partial installed before refill");
                end
                @(posedge clk);
                @(negedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace dirty partial refill request timeout");
            end
            #1;
            if (mem_req_write ||
                mem_req_addr != CPP_LLC_DVPW_REFILL_REQ_ADDR ||
                mem_req_id != CPP_LLC_DVPW_REFILL_REQ_ID ||
                mem_req_size != CPP_LLC_DVPW_REFILL_REQ_SIZE) begin
                fail_now("C++ trace dirty partial refill request mismatch");
            end
            mem_req_ready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mem_req_ready = 1'b0;

            mem_resp_id = CPP_LLC_DVPW_REFILL_REQ_ID;
            mem_resp_rdata = CPP_LLC_DVPW_REFILL_RESP_LINE;
            mem_resp_code = 2'b00;
            mem_resp_valid = 1'b1;
            #1;
            if (!mem_resp_ready) begin
                fail_now("C++ trace dirty partial refill response was not ready");
            end
            @(posedge clk);
            @(negedge clk);
            mem_resp_valid = 1'b0;

            timeout = 40;
            while (!data_wr_en && (timeout > 0)) begin
                @(posedge clk);
                @(negedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace dirty partial install timeout");
            end
            #1;
            if (!meta_wr_en || !valid_wr_en || !repl_wr_en) begin
                fail_now("C++ trace dirty partial did not update all install rows");
            end
            if (data_wr_set != CPP_LLC_DVPW_DATA_WR_SET ||
                data_wr_way_mask != CPP_LLC_DVPW_DATA_WR_WAY_MASK ||
                data_wr_row != CPP_LLC_DVPW_DATA_WR_ROW) begin
                fail_now("C++ trace dirty partial data install mismatch");
            end
            if (meta_wr_set != CPP_LLC_DVPW_META_WR_SET ||
                meta_wr_way_mask != CPP_LLC_DVPW_META_WR_WAY_MASK ||
                meta_wr_row != CPP_LLC_DVPW_META_WR_ROW) begin
                fail_now("C++ trace dirty partial meta install mismatch");
            end
            if (valid_wr_set != CPP_LLC_DVPW_VALID_WR_SET ||
                valid_wr_mask != CPP_LLC_DVPW_VALID_WR_MASK ||
                valid_wr_bits != CPP_LLC_DVPW_VALID_WR_BITS) begin
                fail_now("C++ trace dirty partial valid install mismatch");
            end
            if (repl_wr_set != CPP_LLC_DVPW_REPL_WR_SET ||
                repl_wr_way != CPP_LLC_DVPW_REPL_WR_WAY) begin
                fail_now("C++ trace dirty partial repl install mismatch");
            end

            timeout = 40;
            while (!mem_req_valid && (timeout > 0)) begin
                @(posedge clk);
                @(negedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0) begin
                fail_now("C++ trace dirty partial writeback request timeout");
            end
            #1;
            if (!mem_req_write ||
                mem_req_addr != CPP_LLC_DVPW_WB_REQ_ADDR ||
                mem_req_id != CPP_LLC_DVPW_WB_REQ_ID ||
                mem_req_size != CPP_LLC_DVPW_WB_REQ_SIZE ||
                mem_req_wdata != CPP_LLC_DVPW_WB_REQ_DATA ||
                mem_req_wstrb != CPP_LLC_DVPW_WB_REQ_STRB) begin
                fail_now("C++ trace dirty partial writeback request mismatch");
            end
            mem_req_ready = 1'b1;

            @(posedge clk);
            @(negedge clk);
            mem_req_ready = 1'b0;
            #1;
            if (!resp_valid) begin
                fail_now("C++ trace dirty partial response missing");
            end
            if (resp_id != CPP_LLC_DVPW_RESP_ID ||
                resp_code != CPP_LLC_DVPW_RESP_CODE) begin
                fail_now("C++ trace dirty partial response mismatch");
            end
        end
    endtask

    llc_cache_ctrl #(
        .ADDR_BITS        (ADDR_BITS),
        .ID_BITS          (ID_BITS),
        .LINE_BYTES       (LINE_BYTES),
        .LINE_BITS        (LINE_BITS),
        .LINE_OFFSET_BITS (LINE_OFFSET_BITS),
        .SET_COUNT        (SET_COUNT),
        .SET_BITS         (SET_BITS),
        .WAY_COUNT        (WAY_COUNT),
        .WAY_BITS         (WAY_BITS),
        .META_BITS        (META_BITS),
        .READ_RESP_BYTES  (READ_RESP_BYTES),
        .READ_RESP_BITS   (READ_RESP_BITS),
        .DATA_ROW_BITS    (DATA_ROW_BITS),
        .META_ROW_BITS    (META_ROW_BITS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(req_valid),
        .req_ready(req_ready),
        .req_write(req_write),
        .req_bypass(1'b0),
        .req_addr(req_addr),
        .req_id(req_id),
        .req_total_size(req_total_size),
        .req_wdata(req_wdata),
        .req_wstrb(req_wstrb),
        .resp_valid(resp_valid),
        .resp_ready(1'b1),
        .resp_rdata(resp_rdata),
        .resp_id(resp_id),
        .resp_code(resp_code),
        .invalidate_line_valid(invalidate_line_valid),
        .invalidate_line_addr(invalidate_line_addr),
        .invalidate_line_accepted(invalidate_line_accepted),
        .data_rd_en(data_rd_en),
        .data_rd_set(data_rd_set),
        .data_rd_valid(data_rd_valid),
        .data_rd_row(data_rd_row),
        .data_wr_en(data_wr_en),
        .data_wr_set(data_wr_set),
        .data_wr_way_mask(data_wr_way_mask),
        .data_wr_row(data_wr_row),
        .data_busy(1'b0),
        .meta_rd_en(meta_rd_en),
        .meta_rd_set(meta_rd_set),
        .meta_rd_valid(meta_rd_valid),
        .meta_rd_row(meta_rd_row),
        .meta_wr_en(meta_wr_en),
        .meta_wr_set(meta_wr_set),
        .meta_wr_way_mask(meta_wr_way_mask),
        .meta_wr_row(meta_wr_row),
        .meta_busy(1'b0),
        .valid_rd_en(valid_rd_en),
        .valid_rd_set(valid_rd_set),
        .valid_rd_valid(valid_rd_valid),
        .valid_rd_bits(valid_rd_bits),
        .valid_wr_en(valid_wr_en),
        .valid_wr_set(valid_wr_set),
        .valid_wr_mask(valid_wr_mask),
        .valid_wr_bits(valid_wr_bits),
        .repl_rd_en(repl_rd_en),
        .repl_rd_set(repl_rd_set),
        .repl_rd_valid(repl_rd_valid),
        .repl_rd_way(repl_rd_way),
        .repl_wr_en(repl_wr_en),
        .repl_wr_set(repl_wr_set),
        .repl_wr_way(repl_wr_way),
        .flush_start(1'b0),
        .flush_busy(flush_busy),
        .dirty_present(dirty_present),
        .quiescent(quiescent),
        .victim_line_valid(victim_line_valid),
        .victim_line_addr(victim_line_addr),
        .mem_req_valid(mem_req_valid),
        .mem_req_ready(mem_req_ready),
        .mem_req_write(mem_req_write),
        .mem_req_addr(mem_req_addr),
        .mem_req_id(mem_req_id),
        .mem_req_wdata(mem_req_wdata),
        .mem_req_wstrb(mem_req_wstrb),
        .mem_req_size(mem_req_size),
        .mem_resp_valid(mem_resp_valid),
        .mem_resp_ready(mem_resp_ready),
        .mem_resp_rdata(mem_resp_rdata),
        .mem_resp_id(mem_resp_id),
        .mem_resp_code(mem_resp_code),
        .bypass_req_valid(bypass_req_valid),
        .bypass_req_ready(1'b0),
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
        .bypass_resp_code(2'b00)
    );

    initial begin
        run_partial_write_hit();
        run_read_miss_refill();
        run_partial_write_miss_refill();
        run_dirty_victim_writeback();
        run_dirty_partial_write_miss();
        run_invalidate_line();
        $display("tb_llc_cache_ctrl_cpp_trace_contract PASS");
        $finish;
    end

endmodule
