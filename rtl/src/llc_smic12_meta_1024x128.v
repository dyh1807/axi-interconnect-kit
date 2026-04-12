`timescale 1ns / 1ps

module llc_smic12_meta_1024x128 (
    input               clk,
    input               rst_n,
    input               me,
    input               we,
    input      [9:0]    addr,
    input      [127:0]  din,
    output     [127:0]  q
);

`ifdef AXI_LLC_USE_EXTERNAL_SRAM_MODELS
    sassls0c4l1p1024x128m4b1w0c0p0d0t0s2sdz0rw00__1 u_macro (
        .Q        (q),
        .VDD      (1'b1),
        .VSS      (1'b0),
        .ADR      (addr),
        .D        (din),
        .WE       (we),
        .ME       (me),
        .CLK      (clk),
        .TEST1    (1'b0),
        .TEST_RNM (1'b0),
        .RME      (1'b0),
        .RM       (4'b0000)
    );
`else
    reg [127:0] mem_r [0:1023];
    reg [127:0] q_r;

    assign q = q_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q_r <= {128{1'b0}};
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
