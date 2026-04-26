`timescale 1ns / 1ps

module llc_smic12_data_4096x256_sass_bw (
    input               clk,
    input               rst_n,
    input               me,
    input               we,
    input      [11:0]   addr,
    input      [255:0]  din,
    input      [255:0]  wem,
    output     [255:0]  q
);

`ifdef SYNTHESIS
    sassls0c4l1p4096x256m4b4w1c1p0d0t0s2sdz1rw00 u_macro (
        .Q        (q),
        .ADR      (addr),
        .D        (din),
        .WEM      (wem),
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
    sassls0c4l1p4096x256m4b4w1c1p0d0t0s2sdz1rw00 u_macro (
        .Q        (q),
        .ADR      (addr),
        .D        (din),
        .WEM      (wem),
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
    reg [255:0] mem_r [0:4095];
    reg [255:0] q_r;
    integer bit_idx;

    assign q = q_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q_r <= {256{1'b0}};
        end else begin
            if (me && !we) begin
                q_r <= mem_r[addr];
            end

            if (me && we) begin
                for (bit_idx = 0; bit_idx < 256; bit_idx = bit_idx + 1) begin
                    if (wem[bit_idx]) begin
                        mem_r[addr][bit_idx] <= din[bit_idx];
                    end
                end
            end
        end
    end
`endif

endmodule
