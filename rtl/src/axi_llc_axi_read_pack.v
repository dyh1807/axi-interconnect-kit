`timescale 1ns / 1ps

// AXI R channel beat merge and optional mode2 aligned read extraction helper.
module axi_llc_axi_read_pack #(
    parameter ADDR_BITS = 32,
    parameter READ_RESP_BYTES = 64,
    parameter AXI_DATA_BYTES = 32,
    parameter MODE2_EXTRACT_BYTES = READ_RESP_BYTES
) (
    input  [(READ_RESP_BYTES*8)-1:0] current_data,
    input  [(AXI_DATA_BYTES*8)-1:0]  beat_data,
    input  [ADDR_BITS-1:0]           req_addr,
    input  [ADDR_BITS-1:0]           issued_addr,
    input  [7:0]                     beat_idx,
    input                            mode2_ddr_aligned,
    output reg [(READ_RESP_BYTES*8)-1:0] merged_data,
    output reg [(READ_RESP_BYTES*8)-1:0] final_data
);

    localparam integer READ_RESP_BITS = READ_RESP_BYTES * 8;
    localparam integer AXI_DATA_BITS = AXI_DATA_BYTES * 8;
    localparam         SPECIAL_64B_32B =
        (READ_RESP_BYTES == 64) &&
        (AXI_DATA_BYTES == 32) &&
        (MODE2_EXTRACT_BYTES == 64);
    wire [5:0] byte_off_w;

    assign byte_off_w = req_addr[5:0] - issued_addr[5:0];

    generate
        if (SPECIAL_64B_32B) begin : gen_64b_32b_two_beat
            reg [READ_RESP_BITS-1:0] merged_next;

            always @(*) begin
                merged_next = current_data;

                if (beat_idx == 8'd0) begin
                    merged_next[255:0] = beat_data[255:0];
                end else if (beat_idx == 8'd1) begin
                    merged_next[511:256] = beat_data[255:0];
                end
                merged_data = merged_next;

                if (!mode2_ddr_aligned) begin
                    final_data = merged_next;
                end else begin
                    case (byte_off_w)
                        6'd0:  final_data = merged_next;
                        6'd1:  final_data = {{8{1'b0}}, merged_next[511:8]};
                        6'd2:  final_data = {{16{1'b0}}, merged_next[511:16]};
                        6'd3:  final_data = {{24{1'b0}}, merged_next[511:24]};
                        6'd4:  final_data = {{32{1'b0}}, merged_next[511:32]};
                        6'd5:  final_data = {{40{1'b0}}, merged_next[511:40]};
                        6'd6:  final_data = {{48{1'b0}}, merged_next[511:48]};
                        6'd7:  final_data = {{56{1'b0}}, merged_next[511:56]};
                        6'd8:  final_data = {{64{1'b0}}, merged_next[511:64]};
                        6'd9:  final_data = {{72{1'b0}}, merged_next[511:72]};
                        6'd10: final_data = {{80{1'b0}}, merged_next[511:80]};
                        6'd11: final_data = {{88{1'b0}}, merged_next[511:88]};
                        6'd12: final_data = {{96{1'b0}}, merged_next[511:96]};
                        6'd13: final_data = {{104{1'b0}}, merged_next[511:104]};
                        6'd14: final_data = {{112{1'b0}}, merged_next[511:112]};
                        6'd15: final_data = {{120{1'b0}}, merged_next[511:120]};
                        6'd16: final_data = {{128{1'b0}}, merged_next[511:128]};
                        6'd17: final_data = {{136{1'b0}}, merged_next[511:136]};
                        6'd18: final_data = {{144{1'b0}}, merged_next[511:144]};
                        6'd19: final_data = {{152{1'b0}}, merged_next[511:152]};
                        6'd20: final_data = {{160{1'b0}}, merged_next[511:160]};
                        6'd21: final_data = {{168{1'b0}}, merged_next[511:168]};
                        6'd22: final_data = {{176{1'b0}}, merged_next[511:176]};
                        6'd23: final_data = {{184{1'b0}}, merged_next[511:184]};
                        6'd24: final_data = {{192{1'b0}}, merged_next[511:192]};
                        6'd25: final_data = {{200{1'b0}}, merged_next[511:200]};
                        6'd26: final_data = {{208{1'b0}}, merged_next[511:208]};
                        6'd27: final_data = {{216{1'b0}}, merged_next[511:216]};
                        6'd28: final_data = {{224{1'b0}}, merged_next[511:224]};
                        6'd29: final_data = {{232{1'b0}}, merged_next[511:232]};
                        6'd30: final_data = {{240{1'b0}}, merged_next[511:240]};
                        6'd31: final_data = {{248{1'b0}}, merged_next[511:248]};
                        6'd32: final_data = {{256{1'b0}}, merged_next[511:256]};
                        6'd33: final_data = {{264{1'b0}}, merged_next[511:264]};
                        6'd34: final_data = {{272{1'b0}}, merged_next[511:272]};
                        6'd35: final_data = {{280{1'b0}}, merged_next[511:280]};
                        6'd36: final_data = {{288{1'b0}}, merged_next[511:288]};
                        6'd37: final_data = {{296{1'b0}}, merged_next[511:296]};
                        6'd38: final_data = {{304{1'b0}}, merged_next[511:304]};
                        6'd39: final_data = {{312{1'b0}}, merged_next[511:312]};
                        6'd40: final_data = {{320{1'b0}}, merged_next[511:320]};
                        6'd41: final_data = {{328{1'b0}}, merged_next[511:328]};
                        6'd42: final_data = {{336{1'b0}}, merged_next[511:336]};
                        6'd43: final_data = {{344{1'b0}}, merged_next[511:344]};
                        6'd44: final_data = {{352{1'b0}}, merged_next[511:352]};
                        6'd45: final_data = {{360{1'b0}}, merged_next[511:360]};
                        6'd46: final_data = {{368{1'b0}}, merged_next[511:368]};
                        6'd47: final_data = {{376{1'b0}}, merged_next[511:376]};
                        6'd48: final_data = {{384{1'b0}}, merged_next[511:384]};
                        6'd49: final_data = {{392{1'b0}}, merged_next[511:392]};
                        6'd50: final_data = {{400{1'b0}}, merged_next[511:400]};
                        6'd51: final_data = {{408{1'b0}}, merged_next[511:408]};
                        6'd52: final_data = {{416{1'b0}}, merged_next[511:416]};
                        6'd53: final_data = {{424{1'b0}}, merged_next[511:424]};
                        6'd54: final_data = {{432{1'b0}}, merged_next[511:432]};
                        6'd55: final_data = {{440{1'b0}}, merged_next[511:440]};
                        6'd56: final_data = {{448{1'b0}}, merged_next[511:448]};
                        6'd57: final_data = {{456{1'b0}}, merged_next[511:456]};
                        6'd58: final_data = {{464{1'b0}}, merged_next[511:464]};
                        6'd59: final_data = {{472{1'b0}}, merged_next[511:472]};
                        6'd60: final_data = {{480{1'b0}}, merged_next[511:480]};
                        6'd61: final_data = {{488{1'b0}}, merged_next[511:488]};
                        6'd62: final_data = {{496{1'b0}}, merged_next[511:496]};
                        6'd63: final_data = {{504{1'b0}}, merged_next[511:504]};
                        default: final_data = {READ_RESP_BITS{1'b0}};
                    endcase
                end
            end
        end else if ((READ_RESP_BYTES == AXI_DATA_BYTES) &&
            (AXI_DATA_BYTES == 4) &&
            (MODE2_EXTRACT_BYTES == 4)) begin : gen_4b_single_beat
            reg [READ_RESP_BITS-1:0] merged_next;

            always @(*) begin
                merged_next = current_data;

                if (beat_idx == 8'd0) begin
                    merged_next[31:0] = beat_data[31:0];
                end
                merged_data = merged_next;

                if (!mode2_ddr_aligned || (byte_off_w == 6'd0)) begin
                    final_data = merged_next;
                end else begin
                    case (byte_off_w)
                        6'd1: final_data = {8'h00, merged_next[31:8]};
                        6'd2: final_data = {16'h0000, merged_next[31:16]};
                        6'd3: final_data = {24'h000000, merged_next[31:24]};
                        default: final_data = {READ_RESP_BITS{1'b0}};
                    endcase
                end
            end
        end else if (READ_RESP_BYTES == AXI_DATA_BYTES) begin : gen_single_beat
            reg [READ_RESP_BITS-1:0] merged_next;
            integer dst_byte;
            integer src_byte;

            always @(*) begin
                merged_next = current_data;
                final_data = {READ_RESP_BITS{1'b0}};

                if (beat_idx == 8'd0) begin
                    merged_next[READ_RESP_BITS-1:0] =
                        beat_data[READ_RESP_BITS-1:0];
                end
                merged_data = merged_next;

                if (!mode2_ddr_aligned) begin
                    final_data = merged_next;
                end else begin
                    for (dst_byte = 0;
                         dst_byte < MODE2_EXTRACT_BYTES;
                         dst_byte = dst_byte + 1) begin
                        src_byte = byte_off_w + dst_byte;
                        if (src_byte < READ_RESP_BYTES) begin
                            final_data[(dst_byte * 8) +: 8] =
                                merged_next[(src_byte * 8) +: 8];
                        end
                    end
                end
            end
        end else if (READ_RESP_BYTES == (2 * AXI_DATA_BYTES)) begin : gen_two_beat
            reg [READ_RESP_BITS-1:0] merged_next;
            integer dst_byte;
            integer src_byte;

            always @(*) begin
                merged_next = current_data;
                final_data = {READ_RESP_BITS{1'b0}};

                if (beat_idx == 8'd0) begin
                    merged_next[AXI_DATA_BITS-1:0] = beat_data;
                end else if (beat_idx == 8'd1) begin
                    merged_next[AXI_DATA_BITS +: AXI_DATA_BITS] = beat_data;
                end
                merged_data = merged_next;

                if (!mode2_ddr_aligned) begin
                    final_data = merged_next;
                end else begin
                    for (dst_byte = 0;
                         dst_byte < MODE2_EXTRACT_BYTES;
                         dst_byte = dst_byte + 1) begin
                        src_byte = byte_off_w + dst_byte;
                        if (src_byte < READ_RESP_BYTES) begin
                            final_data[(dst_byte * 8) +: 8] =
                                merged_next[(src_byte * 8) +: 8];
                        end
                    end
                end
            end
        end else begin : gen_generic
            integer byte_idx;
            integer dst_byte;
            integer src_byte;
            reg [READ_RESP_BITS-1:0] merged_next;

            always @(*) begin
                merged_next = current_data;
                final_data = {READ_RESP_BITS{1'b0}};

                for (byte_idx = 0;
                     byte_idx < AXI_DATA_BYTES;
                     byte_idx = byte_idx + 1) begin
                    dst_byte = beat_idx * AXI_DATA_BYTES + byte_idx;
                    if (dst_byte < READ_RESP_BYTES) begin
                        merged_next[(dst_byte * 8) +: 8] =
                            beat_data[(byte_idx * 8) +: 8];
                    end
                end
                merged_data = merged_next;

                if (!mode2_ddr_aligned) begin
                    final_data = merged_next;
                end else begin
                    for (dst_byte = 0;
                         dst_byte < MODE2_EXTRACT_BYTES;
                         dst_byte = dst_byte + 1) begin
                        src_byte = byte_off_w + dst_byte;
                        if (src_byte < READ_RESP_BYTES) begin
                            final_data[(dst_byte * 8) +: 8] =
                                merged_next[(src_byte * 8) +: 8];
                        end
                    end
                end
            end
        end
    endgenerate

endmodule
