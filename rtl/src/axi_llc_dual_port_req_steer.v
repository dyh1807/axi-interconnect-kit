`timescale 1ns / 1ps

// Steer one lower-memory request stream to the native DDR/MMIO bridge port.
//
// The route decision is computed by axi_llc_dual_port_route_shape. This helper
// keeps the valid/ready contract in one production module so RTL tests and
// formal smoke cover the same logic used by axi_llc_axi_bridge_dual.
module axi_llc_dual_port_req_steer (
    input  req_valid,
    input  req_to_ddr,
    input  req_supported,
    output ddr_req_valid,
    input  ddr_req_ready,
    output mmio_req_valid,
    input  mmio_req_ready,
    output req_ready
);

    assign ddr_req_valid = req_valid && req_to_ddr;
    assign mmio_req_valid = req_valid && !req_to_ddr && req_supported;
    assign req_ready = req_to_ddr ? ddr_req_ready :
                       (req_supported && mmio_req_ready);

endmodule
