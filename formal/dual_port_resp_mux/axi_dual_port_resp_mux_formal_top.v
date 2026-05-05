module axi_dual_port_resp_mux_formal_top(
    input        ddr_resp_valid,
    input  [7:0] ddr_resp_rdata,
    input  [1:0] ddr_resp_id,
    input  [1:0] ddr_resp_code,
    input        mmio_resp_valid,
    input  [7:0] mmio_resp_rdata,
    input  [1:0] mmio_resp_id,
    input  [1:0] mmio_resp_code,
    input        resp_ready,
    output       ddr_resp_ready,
    output       mmio_resp_ready,
    output       resp_valid,
    output [7:0] resp_rdata,
    output [1:0] resp_id,
    output [1:0] resp_code,
    output       select_mmio
);

    axi_llc_dual_port_resp_mux #(
        .RESP_BITS(8),
        .ID_BITS(2)
    ) dut (
        .ddr_resp_valid(ddr_resp_valid),
        .ddr_resp_ready(ddr_resp_ready),
        .ddr_resp_rdata(ddr_resp_rdata),
        .ddr_resp_id(ddr_resp_id),
        .ddr_resp_code(ddr_resp_code),
        .mmio_resp_valid(mmio_resp_valid),
        .mmio_resp_ready(mmio_resp_ready),
        .mmio_resp_rdata(mmio_resp_rdata),
        .mmio_resp_id(mmio_resp_id),
        .mmio_resp_code(mmio_resp_code),
        .resp_valid(resp_valid),
        .resp_ready(resp_ready),
        .resp_rdata(resp_rdata),
        .resp_id(resp_id),
        .resp_code(resp_code),
        .select_mmio(select_mmio)
    );

endmodule
