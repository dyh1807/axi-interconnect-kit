`timescale 1ns / 1ps

// Shared combinational route/shape helper for the native dual external AXI
// path. Keeping this logic in one production module lets RTL and formal smoke
// check the same address classification rules instead of duplicated specs.
module axi_llc_dual_port_route_shape #(
    parameter ADDR_BITS = 32,
    parameter [ADDR_BITS-1:0] DDR_BASE = 32'h4000_0000
) (
    input      [ADDR_BITS-1:0] addr,
    input      [7:0]           total_size,
    output                     ddr_port,
    output                     mmio_port,
    output                     supported,
    output     [7:0]           axi_len,
    output     [2:0]           axi_size
);

    localparam [2:0] AXI_SIZE_32B_BEAT  = 3'd2;
    localparam [2:0] AXI_SIZE_256B_BEAT = 3'd5;

    wire [8:0] bytes_w;
    wire [8:0] beats_w;
    wire ddr_addr_w;

    assign ddr_addr_w = (addr >= DDR_BASE);
    assign bytes_w = {1'b0, total_size} + 9'd1;
    assign beats_w = (bytes_w + 9'd31) >> 5;
    assign ddr_port = ddr_addr_w;
    assign mmio_port = !ddr_addr_w;
    assign supported = ddr_addr_w || (total_size == 8'd3);
    assign axi_len = ddr_addr_w ? (beats_w[7:0] - 8'd1) : 8'd0;
    assign axi_size = ddr_addr_w ? AXI_SIZE_256B_BEAT : AXI_SIZE_32B_BEAT;

endmodule
