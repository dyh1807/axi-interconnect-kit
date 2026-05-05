module axi_dual_port_route_shape_formal_top(
    input      [31:0] addr,
    input      [7:0]  total_size,
    output            ddr_port,
    output            mmio_port,
    output            supported,
    output     [7:0]  axi_len,
    output     [2:0]  axi_size
);

    axi_llc_dual_port_route_shape #(
        .ADDR_BITS(32),
        .DDR_BASE(32'h4000_0000)
    ) dut (
        .addr(addr),
        .total_size(total_size),
        .ddr_port(ddr_port),
        .mmio_port(mmio_port),
        .supported(supported),
        .axi_len(axi_len),
        .axi_size(axi_size)
    );

endmodule
