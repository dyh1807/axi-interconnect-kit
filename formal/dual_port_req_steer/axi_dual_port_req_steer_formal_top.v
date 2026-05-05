module axi_dual_port_req_steer_formal_top(
    input  req_valid,
    input  req_to_ddr,
    input  req_supported,
    input  ddr_req_ready,
    input  mmio_req_ready,
    output ddr_req_valid,
    output mmio_req_valid,
    output req_ready
);

    axi_llc_dual_port_req_steer dut (
        .req_valid(req_valid),
        .req_to_ddr(req_to_ddr),
        .req_supported(req_supported),
        .ddr_req_valid(ddr_req_valid),
        .ddr_req_ready(ddr_req_ready),
        .mmio_req_valid(mmio_req_valid),
        .mmio_req_ready(mmio_req_ready),
        .req_ready(req_ready)
    );

endmodule
