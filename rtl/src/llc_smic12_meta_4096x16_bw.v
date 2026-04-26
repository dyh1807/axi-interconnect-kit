`timescale 1ns / 1ps
`include "axi_llc_params.vh"

module llc_smic12_meta_4096x16_bw (
    input               clk,
    input               rst_n,
    input               me,
    input               we,
    input      [`AXI_LLC_META_SRAM_ADDR_BITS-1:0] addr,
    input      [`AXI_LLC_META_SRAM_BITS-1:0]      din,
    output     [`AXI_LLC_META_SRAM_BITS-1:0]      q
);

`ifdef SYNTHESIS
    sassls0c4l1p4096x16m16b1w1c1p0d0t0s2sdz1rw00 u_macro (
        .Q        (q),
        .ADR      (addr),
        .D        (din),
        .WEM      ({`AXI_LLC_META_SRAM_BITS{1'b1}}),
        .WE       (we),
        .ME       (me),
        .CLK      (clk),
        .TEST1    (1'b0),
        .TEST_RNM (1'b0),
        .RME      (1'b0),
        .RM       (4'b0000),
        .LS       (1'b0),
        .BC1      (1'b0),
        .BC2      (1'b0)
    );
`elsif AXI_LLC_USE_EXTERNAL_SRAM_MODELS
    sassls0c4l1p4096x16m16b1w1c1p0d0t0s2sdz1rw00 u_macro (
        .Q        (q),
        .ADR      (addr),
        .D        (din),
        .WEM      ({`AXI_LLC_META_SRAM_BITS{1'b1}}),
        .WE       (we),
        .ME       (me),
        .CLK      (clk),
        .TEST1    (1'b0),
        .TEST_RNM (1'b0),
        .RME      (1'b0),
        .RM       (4'b0000),
        .LS       (1'b0),
        .BC1      (1'b0),
        .BC2      (1'b0)
    );
`else
    reg [`AXI_LLC_META_SRAM_BITS-1:0] mem_r [0:`AXI_LLC_META_SRAM_DEPTH-1];
    reg [`AXI_LLC_META_SRAM_BITS-1:0] q_r;

    assign q = q_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q_r <= {`AXI_LLC_META_SRAM_BITS{1'b0}};
        end else begin
            if (me && !we) begin
                q_r <= mem_r[addr];
            end

            if (me && we) begin
                mem_r[addr] <= din;
            end
        end
    end
`endif

endmodule
