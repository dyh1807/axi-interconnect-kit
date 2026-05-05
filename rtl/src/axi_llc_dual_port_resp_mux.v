`timescale 1ns / 1ps

// Mux one response stream from the native DDR/MMIO bridge ports back to its
// upstream source. MMIO has priority when both ports present a response; the
// non-selected port is backpressured.
module axi_llc_dual_port_resp_mux #(
    parameter RESP_BITS = 2048,
    parameter ID_BITS = 6
) (
    input                         ddr_resp_valid,
    output                        ddr_resp_ready,
    input      [RESP_BITS-1:0]    ddr_resp_rdata,
    input      [ID_BITS-1:0]      ddr_resp_id,
    input      [1:0]              ddr_resp_code,

    input                         mmio_resp_valid,
    output                        mmio_resp_ready,
    input      [RESP_BITS-1:0]    mmio_resp_rdata,
    input      [ID_BITS-1:0]      mmio_resp_id,
    input      [1:0]              mmio_resp_code,

    output                        resp_valid,
    input                         resp_ready,
    output     [RESP_BITS-1:0]    resp_rdata,
    output     [ID_BITS-1:0]      resp_id,
    output     [1:0]              resp_code,
    output                        select_mmio
);

    assign select_mmio = mmio_resp_valid;
    assign resp_valid = select_mmio ? mmio_resp_valid : ddr_resp_valid;
    assign resp_rdata = select_mmio ? mmio_resp_rdata : ddr_resp_rdata;
    assign resp_id = select_mmio ? mmio_resp_id : ddr_resp_id;
    assign resp_code = select_mmio ? mmio_resp_code : ddr_resp_code;
    assign mmio_resp_ready = select_mmio && resp_ready;
    assign ddr_resp_ready = (!select_mmio) && resp_ready;

endmodule
