`timescale 1ns / 1ps

// AXI W channel data/strobe packing helper used by axi_llc_axi_bridge.
module axi_llc_axi_write_pack #(
    parameter ADDR_BITS = 32,
    parameter LINE_BYTES = 64,
    parameter AXI_DATA_BYTES = 32,
    parameter SINGLE_BEAT_ONLY = 0
) (
    input  [(LINE_BYTES*8)-1:0]     line_data,
    input  [LINE_BYTES-1:0]         line_strb,
    input  [ADDR_BITS-1:0]          req_addr,
    input  [ADDR_BITS-1:0]          issued_addr,
    input  [7:0]                    beat_idx,
    input                           mode2_ddr_aligned,
    output reg [(AXI_DATA_BYTES*8)-1:0] axi_wdata,
    output reg [AXI_DATA_BYTES-1:0] axi_wstrb
);

    localparam integer AXI_DATA_BITS = AXI_DATA_BYTES * 8;
    localparam integer LINE_BITS = LINE_BYTES * 8;
    localparam integer SPECIAL_4B_SINGLE_BEAT =
        SINGLE_BEAT_ONLY && (LINE_BYTES == AXI_DATA_BYTES) && (AXI_DATA_BYTES == 4);
    localparam integer SPECIAL_64B_32B =
        (LINE_BYTES == 64) && (AXI_DATA_BYTES == 32);

    wire [5:0] byte_off_w;

    assign byte_off_w = req_addr[5:0] - issued_addr[5:0];

    generate
        if (SPECIAL_4B_SINGLE_BEAT) begin : gen_4b_single_beat
            always @(*) begin
                axi_wdata = {AXI_DATA_BITS{1'b0}};
                axi_wstrb = {AXI_DATA_BYTES{1'b0}};

                if (!mode2_ddr_aligned || (byte_off_w == 6'd0)) begin
                    axi_wdata = line_data[31:0];
                    axi_wstrb = line_strb[3:0];
                end else begin
                    case (byte_off_w)
                        6'd1: begin
                            axi_wdata = {line_data[23:0], 8'h00};
                            axi_wstrb = {line_strb[2:0], 1'b0};
                        end
                        6'd2: begin
                            axi_wdata = {line_data[15:0], 16'h0000};
                            axi_wstrb = {line_strb[1:0], 2'b00};
                        end
                        6'd3: begin
                            axi_wdata = {line_data[7:0], 24'h000000};
                            axi_wstrb = {line_strb[0], 3'b000};
                        end
                        default: begin
                            axi_wdata = {AXI_DATA_BITS{1'b0}};
                            axi_wstrb = {AXI_DATA_BYTES{1'b0}};
                        end
                    endcase
                end
            end
        end else if (SPECIAL_64B_32B) begin : gen_64b_32b_pack
            always @(*) begin
                axi_wdata = {AXI_DATA_BITS{1'b0}};
                axi_wstrb = {AXI_DATA_BYTES{1'b0}};

                if (!mode2_ddr_aligned) begin
                    if (beat_idx == 8'd0) begin
                        axi_wdata = line_data[255:0];
                        axi_wstrb = line_strb[31:0];
                    end else if (beat_idx == 8'd1) begin
                        axi_wdata = line_data[511:256];
                        axi_wstrb = line_strb[63:32];
                    end
                end else if (beat_idx == 8'd0) begin
                    // Mode2 production writes issue req/issued in the same 64B line.
                    case (byte_off_w)
                        6'd0: begin
                            axi_wdata = line_data[255:0];
                            axi_wstrb = line_strb[31:0];
                        end
                        6'd1: begin
                            axi_wdata = {line_data[247:0], 8'h00};
                            axi_wstrb = {line_strb[30:0], 1'b0};
                        end
                        6'd2: begin
                            axi_wdata = {line_data[239:0], 16'h0000};
                            axi_wstrb = {line_strb[29:0], 2'b00};
                        end
                        6'd3: begin
                            axi_wdata = {line_data[231:0], 24'h000000};
                            axi_wstrb = {line_strb[28:0], 3'b000};
                        end
                        6'd4: begin
                            axi_wdata = {line_data[223:0], 32'h00000000};
                            axi_wstrb = {line_strb[27:0], 4'b0000};
                        end
                        6'd5: begin
                            axi_wdata = {line_data[215:0], 40'h0000000000};
                            axi_wstrb = {line_strb[26:0], 5'b00000};
                        end
                        6'd6: begin
                            axi_wdata = {line_data[207:0], 48'h000000000000};
                            axi_wstrb = {line_strb[25:0], 6'b000000};
                        end
                        6'd7: begin
                            axi_wdata = {line_data[199:0], 56'h00000000000000};
                            axi_wstrb = {line_strb[24:0], 7'b0000000};
                        end
                        6'd8: begin
                            axi_wdata = {line_data[191:0], 64'h0000000000000000};
                            axi_wstrb = {line_strb[23:0], 8'b00000000};
                        end
                        6'd9: begin
                            axi_wdata = {line_data[183:0], 72'h000000000000000000};
                            axi_wstrb = {line_strb[22:0], 9'b000000000};
                        end
                        6'd10: begin
                            axi_wdata = {line_data[175:0], 80'h00000000000000000000};
                            axi_wstrb = {line_strb[21:0], 10'b0000000000};
                        end
                        6'd11: begin
                            axi_wdata = {line_data[167:0], 88'h0000000000000000000000};
                            axi_wstrb = {line_strb[20:0], 11'b00000000000};
                        end
                        6'd12: begin
                            axi_wdata = {line_data[159:0], 96'h000000000000000000000000};
                            axi_wstrb = {line_strb[19:0], 12'b000000000000};
                        end
                        6'd13: begin
                            axi_wdata = {line_data[151:0], 104'h00000000000000000000000000};
                            axi_wstrb = {line_strb[18:0], 13'b0000000000000};
                        end
                        6'd14: begin
                            axi_wdata = {line_data[143:0], 112'h0000000000000000000000000000};
                            axi_wstrb = {line_strb[17:0], 14'b00000000000000};
                        end
                        6'd15: begin
                            axi_wdata = {line_data[135:0], 120'h000000000000000000000000000000};
                            axi_wstrb = {line_strb[16:0], 15'b000000000000000};
                        end
                        6'd16: begin
                            axi_wdata = {line_data[127:0], 128'h00000000000000000000000000000000};
                            axi_wstrb = {line_strb[15:0], 16'b0000000000000000};
                        end
                        6'd17: begin
                            axi_wdata = {line_data[119:0], 136'h0000000000000000000000000000000000};
                            axi_wstrb = {line_strb[14:0], 17'b00000000000000000};
                        end
                        6'd18: begin
                            axi_wdata = {line_data[111:0], 144'h000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[13:0], 18'b000000000000000000};
                        end
                        6'd19: begin
                            axi_wdata = {line_data[103:0], 152'h00000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[12:0], 19'b0000000000000000000};
                        end
                        6'd20: begin
                            axi_wdata = {line_data[95:0], 160'h0000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[11:0], 20'b00000000000000000000};
                        end
                        6'd21: begin
                            axi_wdata = {line_data[87:0], 168'h000000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[10:0], 21'b000000000000000000000};
                        end
                        6'd22: begin
                            axi_wdata = {line_data[79:0], 176'h00000000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[9:0], 22'b0000000000000000000000};
                        end
                        6'd23: begin
                            axi_wdata = {line_data[71:0], 184'h0000000000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[8:0], 23'b00000000000000000000000};
                        end
                        6'd24: begin
                            axi_wdata = {line_data[63:0], 192'h000000000000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[7:0], 24'b000000000000000000000000};
                        end
                        6'd25: begin
                            axi_wdata = {line_data[55:0], 200'h00000000000000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[6:0], 25'b0000000000000000000000000};
                        end
                        6'd26: begin
                            axi_wdata = {line_data[47:0], 208'h0000000000000000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[5:0], 26'b00000000000000000000000000};
                        end
                        6'd27: begin
                            axi_wdata = {line_data[39:0], 216'h000000000000000000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[4:0], 27'b000000000000000000000000000};
                        end
                        6'd28: begin
                            axi_wdata = {line_data[31:0], 224'h00000000000000000000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[3:0], 28'b0000000000000000000000000000};
                        end
                        6'd29: begin
                            axi_wdata = {line_data[23:0], 232'h0000000000000000000000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[2:0], 29'b00000000000000000000000000000};
                        end
                        6'd30: begin
                            axi_wdata = {line_data[15:0], 240'h000000000000000000000000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[1:0], 30'b000000000000000000000000000000};
                        end
                        6'd31: begin
                            axi_wdata = {line_data[7:0], 248'h00000000000000000000000000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[0:0], 31'b0000000000000000000000000000000};
                        end
                        default: begin
                            axi_wdata = {AXI_DATA_BITS{1'b0}};
                            axi_wstrb = {AXI_DATA_BYTES{1'b0}};
                        end
                    endcase
                end else if (beat_idx == 8'd1) begin
                    case (byte_off_w)
                        6'd0: begin
                            axi_wdata = line_data[511:256];
                            axi_wstrb = line_strb[63:32];
                        end
                        6'd1: begin
                            axi_wdata = line_data[503:248];
                            axi_wstrb = line_strb[62:31];
                        end
                        6'd2: begin
                            axi_wdata = line_data[495:240];
                            axi_wstrb = line_strb[61:30];
                        end
                        6'd3: begin
                            axi_wdata = line_data[487:232];
                            axi_wstrb = line_strb[60:29];
                        end
                        6'd4: begin
                            axi_wdata = line_data[479:224];
                            axi_wstrb = line_strb[59:28];
                        end
                        6'd5: begin
                            axi_wdata = line_data[471:216];
                            axi_wstrb = line_strb[58:27];
                        end
                        6'd6: begin
                            axi_wdata = line_data[463:208];
                            axi_wstrb = line_strb[57:26];
                        end
                        6'd7: begin
                            axi_wdata = line_data[455:200];
                            axi_wstrb = line_strb[56:25];
                        end
                        6'd8: begin
                            axi_wdata = line_data[447:192];
                            axi_wstrb = line_strb[55:24];
                        end
                        6'd9: begin
                            axi_wdata = line_data[439:184];
                            axi_wstrb = line_strb[54:23];
                        end
                        6'd10: begin
                            axi_wdata = line_data[431:176];
                            axi_wstrb = line_strb[53:22];
                        end
                        6'd11: begin
                            axi_wdata = line_data[423:168];
                            axi_wstrb = line_strb[52:21];
                        end
                        6'd12: begin
                            axi_wdata = line_data[415:160];
                            axi_wstrb = line_strb[51:20];
                        end
                        6'd13: begin
                            axi_wdata = line_data[407:152];
                            axi_wstrb = line_strb[50:19];
                        end
                        6'd14: begin
                            axi_wdata = line_data[399:144];
                            axi_wstrb = line_strb[49:18];
                        end
                        6'd15: begin
                            axi_wdata = line_data[391:136];
                            axi_wstrb = line_strb[48:17];
                        end
                        6'd16: begin
                            axi_wdata = line_data[383:128];
                            axi_wstrb = line_strb[47:16];
                        end
                        6'd17: begin
                            axi_wdata = line_data[375:120];
                            axi_wstrb = line_strb[46:15];
                        end
                        6'd18: begin
                            axi_wdata = line_data[367:112];
                            axi_wstrb = line_strb[45:14];
                        end
                        6'd19: begin
                            axi_wdata = line_data[359:104];
                            axi_wstrb = line_strb[44:13];
                        end
                        6'd20: begin
                            axi_wdata = line_data[351:96];
                            axi_wstrb = line_strb[43:12];
                        end
                        6'd21: begin
                            axi_wdata = line_data[343:88];
                            axi_wstrb = line_strb[42:11];
                        end
                        6'd22: begin
                            axi_wdata = line_data[335:80];
                            axi_wstrb = line_strb[41:10];
                        end
                        6'd23: begin
                            axi_wdata = line_data[327:72];
                            axi_wstrb = line_strb[40:9];
                        end
                        6'd24: begin
                            axi_wdata = line_data[319:64];
                            axi_wstrb = line_strb[39:8];
                        end
                        6'd25: begin
                            axi_wdata = line_data[311:56];
                            axi_wstrb = line_strb[38:7];
                        end
                        6'd26: begin
                            axi_wdata = line_data[303:48];
                            axi_wstrb = line_strb[37:6];
                        end
                        6'd27: begin
                            axi_wdata = line_data[295:40];
                            axi_wstrb = line_strb[36:5];
                        end
                        6'd28: begin
                            axi_wdata = line_data[287:32];
                            axi_wstrb = line_strb[35:4];
                        end
                        6'd29: begin
                            axi_wdata = line_data[279:24];
                            axi_wstrb = line_strb[34:3];
                        end
                        6'd30: begin
                            axi_wdata = line_data[271:16];
                            axi_wstrb = line_strb[33:2];
                        end
                        6'd31: begin
                            axi_wdata = line_data[263:8];
                            axi_wstrb = line_strb[32:1];
                        end
                        6'd32: begin
                            axi_wdata = line_data[255:0];
                            axi_wstrb = line_strb[31:0];
                        end
                        6'd33: begin
                            axi_wdata = {line_data[247:0], 8'h00};
                            axi_wstrb = {line_strb[30:0], 1'b0};
                        end
                        6'd34: begin
                            axi_wdata = {line_data[239:0], 16'h0000};
                            axi_wstrb = {line_strb[29:0], 2'b00};
                        end
                        6'd35: begin
                            axi_wdata = {line_data[231:0], 24'h000000};
                            axi_wstrb = {line_strb[28:0], 3'b000};
                        end
                        6'd36: begin
                            axi_wdata = {line_data[223:0], 32'h00000000};
                            axi_wstrb = {line_strb[27:0], 4'b0000};
                        end
                        6'd37: begin
                            axi_wdata = {line_data[215:0], 40'h0000000000};
                            axi_wstrb = {line_strb[26:0], 5'b00000};
                        end
                        6'd38: begin
                            axi_wdata = {line_data[207:0], 48'h000000000000};
                            axi_wstrb = {line_strb[25:0], 6'b000000};
                        end
                        6'd39: begin
                            axi_wdata = {line_data[199:0], 56'h00000000000000};
                            axi_wstrb = {line_strb[24:0], 7'b0000000};
                        end
                        6'd40: begin
                            axi_wdata = {line_data[191:0], 64'h0000000000000000};
                            axi_wstrb = {line_strb[23:0], 8'b00000000};
                        end
                        6'd41: begin
                            axi_wdata = {line_data[183:0], 72'h000000000000000000};
                            axi_wstrb = {line_strb[22:0], 9'b000000000};
                        end
                        6'd42: begin
                            axi_wdata = {line_data[175:0], 80'h00000000000000000000};
                            axi_wstrb = {line_strb[21:0], 10'b0000000000};
                        end
                        6'd43: begin
                            axi_wdata = {line_data[167:0], 88'h0000000000000000000000};
                            axi_wstrb = {line_strb[20:0], 11'b00000000000};
                        end
                        6'd44: begin
                            axi_wdata = {line_data[159:0], 96'h000000000000000000000000};
                            axi_wstrb = {line_strb[19:0], 12'b000000000000};
                        end
                        6'd45: begin
                            axi_wdata = {line_data[151:0], 104'h00000000000000000000000000};
                            axi_wstrb = {line_strb[18:0], 13'b0000000000000};
                        end
                        6'd46: begin
                            axi_wdata = {line_data[143:0], 112'h0000000000000000000000000000};
                            axi_wstrb = {line_strb[17:0], 14'b00000000000000};
                        end
                        6'd47: begin
                            axi_wdata = {line_data[135:0], 120'h000000000000000000000000000000};
                            axi_wstrb = {line_strb[16:0], 15'b000000000000000};
                        end
                        6'd48: begin
                            axi_wdata = {line_data[127:0], 128'h00000000000000000000000000000000};
                            axi_wstrb = {line_strb[15:0], 16'b0000000000000000};
                        end
                        6'd49: begin
                            axi_wdata = {line_data[119:0], 136'h0000000000000000000000000000000000};
                            axi_wstrb = {line_strb[14:0], 17'b00000000000000000};
                        end
                        6'd50: begin
                            axi_wdata = {line_data[111:0], 144'h000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[13:0], 18'b000000000000000000};
                        end
                        6'd51: begin
                            axi_wdata = {line_data[103:0], 152'h00000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[12:0], 19'b0000000000000000000};
                        end
                        6'd52: begin
                            axi_wdata = {line_data[95:0], 160'h0000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[11:0], 20'b00000000000000000000};
                        end
                        6'd53: begin
                            axi_wdata = {line_data[87:0], 168'h000000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[10:0], 21'b000000000000000000000};
                        end
                        6'd54: begin
                            axi_wdata = {line_data[79:0], 176'h00000000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[9:0], 22'b0000000000000000000000};
                        end
                        6'd55: begin
                            axi_wdata = {line_data[71:0], 184'h0000000000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[8:0], 23'b00000000000000000000000};
                        end
                        6'd56: begin
                            axi_wdata = {line_data[63:0], 192'h000000000000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[7:0], 24'b000000000000000000000000};
                        end
                        6'd57: begin
                            axi_wdata = {line_data[55:0], 200'h00000000000000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[6:0], 25'b0000000000000000000000000};
                        end
                        6'd58: begin
                            axi_wdata = {line_data[47:0], 208'h0000000000000000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[5:0], 26'b00000000000000000000000000};
                        end
                        6'd59: begin
                            axi_wdata = {line_data[39:0], 216'h000000000000000000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[4:0], 27'b000000000000000000000000000};
                        end
                        6'd60: begin
                            axi_wdata = {line_data[31:0], 224'h00000000000000000000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[3:0], 28'b0000000000000000000000000000};
                        end
                        6'd61: begin
                            axi_wdata = {line_data[23:0], 232'h0000000000000000000000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[2:0], 29'b00000000000000000000000000000};
                        end
                        6'd62: begin
                            axi_wdata = {line_data[15:0], 240'h000000000000000000000000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[1:0], 30'b000000000000000000000000000000};
                        end
                        6'd63: begin
                            axi_wdata = {line_data[7:0], 248'h00000000000000000000000000000000000000000000000000000000000000};
                            axi_wstrb = {line_strb[0:0], 31'b0000000000000000000000000000000};
                        end
                    endcase
                end
            end
        end else begin : gen_generic_pack
            integer byte_idx;
            integer dst_byte;
            integer src_byte;
            integer byte_off;

            always @(*) begin
                axi_wdata = {AXI_DATA_BITS{1'b0}};
                axi_wstrb = {AXI_DATA_BYTES{1'b0}};
                byte_off = req_addr - issued_addr;

                for (byte_idx = 0; byte_idx < AXI_DATA_BYTES; byte_idx = byte_idx + 1) begin
                    dst_byte = beat_idx * AXI_DATA_BYTES + byte_idx;
                    src_byte = mode2_ddr_aligned ? (dst_byte - byte_off) : dst_byte;
                    if ((src_byte >= 0) && (src_byte < LINE_BYTES)) begin
                        axi_wdata[(byte_idx * 8) +: 8] =
                            line_data[(src_byte * 8) +: 8];
                        axi_wstrb[byte_idx] = line_strb[src_byte];
                    end
                end
            end
        end
    endgenerate

endmodule
