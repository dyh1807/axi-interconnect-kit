`timescale 1ns / 1ps
`include "axi_llc_params.vh"

`define AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(_OFF) \
    _OFF: begin \
        for (merge_byte_idx = 7'd0; \
             merge_byte_idx < (7'd64 - {1'b0, _OFF}); \
             merge_byte_idx = merge_byte_idx + 7'd1) begin \
            if (write_strb_in[merge_byte_idx[5:0]]) begin \
                write_line_out[((merge_byte_idx[5:0] + _OFF) * 8) +: 8] = \
                    write_data_in[(merge_byte_idx[5:0] * 8) +: 8]; \
            end \
        end \
    end

`define AXI_LLC_MAPPED_WINDOW_MERGE64_CASES \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd0) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd1) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd2) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd3) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd4) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd5) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd6) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd7) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd8) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd9) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd10) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd11) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd12) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd13) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd14) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd15) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd16) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd17) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd18) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd19) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd20) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd21) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd22) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd23) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd24) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd25) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd26) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd27) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd28) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd29) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd30) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd31) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd32) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd33) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd34) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd35) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd36) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd37) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd38) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd39) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd40) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd41) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd42) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd43) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd44) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd45) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd46) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd47) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd48) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd49) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd50) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd51) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd52) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd53) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd54) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd55) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd56) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd57) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd58) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd59) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd60) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd61) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd62) \
    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASE(6'd63)

module llc_mapped_window_ctrl #(
    parameter ADDR_BITS        = `AXI_LLC_ADDR_BITS,
    parameter LINE_BYTES       = `AXI_LLC_LINE_BYTES,
    parameter LINE_BITS        = `AXI_LLC_LINE_BITS,
    parameter LINE_OFFSET_BITS = `AXI_LLC_LINE_OFFSET_BITS,
    parameter SET_COUNT        = `AXI_LLC_SET_COUNT,
    parameter SET_BITS         = `AXI_LLC_SET_BITS,
    parameter WAY_COUNT        = `AXI_LLC_WAY_COUNT,
    parameter WAY_BITS         = `AXI_LLC_WAY_BITS,
    parameter WINDOW_BYTES     = `AXI_LLC_WINDOW_BYTES,
    parameter WINDOW_WAYS      = `AXI_LLC_WINDOW_WAYS
) (
    input      [ADDR_BITS-1:0]  req_addr,
    input      [7:0]            req_total_size,
    input      [ADDR_BITS-1:0]  window_offset,
    input      [WAY_COUNT*LINE_BITS-1:0] row_data_in,
    input      [WAY_COUNT-1:0]           valid_bits_in,
    input      [LINE_BITS-1:0]  write_data_in,
    input      [LINE_BYTES-1:0] write_strb_in,
    output reg                  in_window,
    output reg                  offset_aligned,
    output reg                  mapped_way_legal,
    output reg [ADDR_BITS-1:0]  local_addr,
    output reg [SET_BITS-1:0]   direct_set,
    output reg [WAY_BITS-1:0]   direct_way,
    output reg                  line_valid_out,
    output reg [LINE_BITS-1:0]  read_line_out,
    output reg [LINE_BITS-1:0]  write_line_out,
    output reg                  next_valid_bit_out
);

    localparam [ADDR_BITS-1:0] WINDOW_BYTES_C = WINDOW_BYTES;
    localparam integer SPECIAL_64B_LINE =
        (LINE_BYTES == 64) && (LINE_BITS == 512) && (LINE_OFFSET_BITS == 6);
    localparam integer SPECIAL_64B_16WAY_WINDOW =
        SPECIAL_64B_LINE && (WAY_COUNT == 16) && (WAY_BITS == 4) &&
        (WINDOW_WAYS == 8);

    reg [SET_BITS + WAY_BITS - 1:0] line_idx;
    reg [ADDR_BITS:0] req_end;
    integer byte_idx;
    integer line_off;
    integer dst_idx;
    integer way_sel_idx;
    reg [6:0] merge_byte_idx;

    generate
        if (SPECIAL_64B_16WAY_WINDOW) begin : gen_64b_16way_write_merge
            always @(*) begin
                offset_aligned = (window_offset[LINE_OFFSET_BITS-1:0] == {LINE_OFFSET_BITS{1'b0}});

                if (req_addr >= window_offset) begin
                    local_addr = req_addr - window_offset;
                    req_end = {1'b0, (req_addr - window_offset)} + { {(ADDR_BITS-7){1'b0}}, req_total_size } + 1'b1;
                    in_window  = (req_end <= {1'b0, WINDOW_BYTES_C});
                end else begin
                    local_addr = {ADDR_BITS{1'b0}};
                    req_end = {(ADDR_BITS+1){1'b0}};
                    in_window  = 1'b0;
                end

                line_idx         = local_addr >> LINE_OFFSET_BITS;
                direct_set       = line_idx[SET_BITS-1:0];
                direct_way       = line_idx[SET_BITS + WAY_BITS - 1:SET_BITS];
                mapped_way_legal = !direct_way[3];
                line_valid_out   = 1'b0;
                read_line_out    = {LINE_BITS{1'b0}};

                if (mapped_way_legal) begin
                    case (direct_way[2:0])
                        3'd0: begin
                            line_valid_out = valid_bits_in[0];
                            if (valid_bits_in[0]) begin
                                read_line_out = row_data_in[511:0];
                            end
                        end
                        3'd1: begin
                            line_valid_out = valid_bits_in[1];
                            if (valid_bits_in[1]) begin
                                read_line_out = row_data_in[1023:512];
                            end
                        end
                        3'd2: begin
                            line_valid_out = valid_bits_in[2];
                            if (valid_bits_in[2]) begin
                                read_line_out = row_data_in[1535:1024];
                            end
                        end
                        3'd3: begin
                            line_valid_out = valid_bits_in[3];
                            if (valid_bits_in[3]) begin
                                read_line_out = row_data_in[2047:1536];
                            end
                        end
                        3'd4: begin
                            line_valid_out = valid_bits_in[4];
                            if (valid_bits_in[4]) begin
                                read_line_out = row_data_in[2559:2048];
                            end
                        end
                        3'd5: begin
                            line_valid_out = valid_bits_in[5];
                            if (valid_bits_in[5]) begin
                                read_line_out = row_data_in[3071:2560];
                            end
                        end
                        3'd6: begin
                            line_valid_out = valid_bits_in[6];
                            if (valid_bits_in[6]) begin
                                read_line_out = row_data_in[3583:3072];
                            end
                        end
                        3'd7: begin
                            line_valid_out = valid_bits_in[7];
                            if (valid_bits_in[7]) begin
                                read_line_out = row_data_in[4095:3584];
                            end
                        end
                    endcase
                end

                write_line_out     = read_line_out;
                next_valid_bit_out = 1'b1;

                case (local_addr[5:0])
                    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASES
                endcase
            end
        end else if (SPECIAL_64B_LINE) begin : gen_64b_write_merge
            always @(*) begin
                offset_aligned = (window_offset[LINE_OFFSET_BITS-1:0] == {LINE_OFFSET_BITS{1'b0}});

                if (req_addr >= window_offset) begin
                    local_addr = req_addr - window_offset;
                    req_end = {1'b0, (req_addr - window_offset)} + { {(ADDR_BITS-7){1'b0}}, req_total_size } + 1'b1;
                    in_window  = (req_end <= {1'b0, WINDOW_BYTES_C});
                end else begin
                    local_addr = {ADDR_BITS{1'b0}};
                    req_end = {(ADDR_BITS+1){1'b0}};
                    in_window  = 1'b0;
                end

                line_idx         = local_addr >> LINE_OFFSET_BITS;
                direct_set       = line_idx[SET_BITS-1:0];
                direct_way       = line_idx[SET_BITS + WAY_BITS - 1:SET_BITS];
                mapped_way_legal = (direct_way < WINDOW_WAYS);
                line_valid_out   = 1'b0;
                read_line_out    = {LINE_BITS{1'b0}};
                for (way_sel_idx = 0; way_sel_idx < WAY_COUNT; way_sel_idx = way_sel_idx + 1) begin
                    if (mapped_way_legal && (direct_way == way_sel_idx[WAY_BITS-1:0])) begin
                        line_valid_out = valid_bits_in[way_sel_idx];
                        if (valid_bits_in[way_sel_idx]) begin
                            read_line_out = row_data_in[(way_sel_idx * LINE_BITS) +: LINE_BITS];
                        end
                    end
                end

                write_line_out     = read_line_out;
                next_valid_bit_out = 1'b1;

                case (local_addr[5:0])
                    `AXI_LLC_MAPPED_WINDOW_MERGE64_CASES
                endcase
            end
        end else begin : gen_generic_write_merge
            always @(*) begin
                offset_aligned = (window_offset[LINE_OFFSET_BITS-1:0] == {LINE_OFFSET_BITS{1'b0}});

                if (req_addr >= window_offset) begin
                    local_addr = req_addr - window_offset;
                    req_end = {1'b0, (req_addr - window_offset)} + { {(ADDR_BITS-7){1'b0}}, req_total_size } + 1'b1;
                    in_window  = (req_end <= {1'b0, WINDOW_BYTES_C});
                end else begin
                    local_addr = {ADDR_BITS{1'b0}};
                    req_end = {(ADDR_BITS+1){1'b0}};
                    in_window  = 1'b0;
                end

                line_idx         = local_addr >> LINE_OFFSET_BITS;
                direct_set       = line_idx[SET_BITS-1:0];
                direct_way       = line_idx[SET_BITS + WAY_BITS - 1:SET_BITS];
                mapped_way_legal = (direct_way < WINDOW_WAYS);
                line_valid_out   = 1'b0;
                read_line_out    = {LINE_BITS{1'b0}};
                for (way_sel_idx = 0; way_sel_idx < WAY_COUNT; way_sel_idx = way_sel_idx + 1) begin
                    if (mapped_way_legal && (direct_way == way_sel_idx[WAY_BITS-1:0])) begin
                        line_valid_out = valid_bits_in[way_sel_idx];
                        if (valid_bits_in[way_sel_idx]) begin
                            read_line_out = row_data_in[(way_sel_idx * LINE_BITS) +: LINE_BITS];
                        end
                    end
                end

                write_line_out     = read_line_out;
                next_valid_bit_out = 1'b1;
                line_off           = local_addr[LINE_OFFSET_BITS-1:0];

                for (dst_idx = 0; dst_idx < LINE_BYTES; dst_idx = dst_idx + 1) begin
                    for (byte_idx = 0; byte_idx < LINE_BYTES; byte_idx = byte_idx + 1) begin
                        if (write_strb_in[byte_idx] &&
                            ((line_off + byte_idx) == dst_idx)) begin
                            write_line_out[(dst_idx * 8) +: 8] =
                                write_data_in[(byte_idx * 8) +: 8];
                        end
                    end
                end
            end
        end
    endgenerate

endmodule

`undef AXI_LLC_MAPPED_WINDOW_MERGE64_CASES
`undef AXI_LLC_MAPPED_WINDOW_MERGE64_CASE
