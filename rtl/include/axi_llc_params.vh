`ifndef AXI_LLC_PARAMS_VH
`define AXI_LLC_PARAMS_VH

`define AXI_LLC_ADDR_BITS         32
`define AXI_LLC_ID_BITS           4
`define AXI_LLC_MODE_BITS         2
`define AXI_LLC_LINE_BYTES        64
`define AXI_LLC_LINE_BITS         512
`define AXI_LLC_LINE_OFFSET_BITS  6
`define AXI_LLC_SET_COUNT         8192
`define AXI_LLC_SET_BITS          13
`define AXI_LLC_WAY_COUNT         16
`define AXI_LLC_WAY_BITS          4
`define AXI_LLC_META_BITS         24
`define AXI_LLC_LLC_SIZE_BYTES    8388608
`define AXI_LLC_WINDOW_BYTES      4194304
`define AXI_LLC_WINDOW_WAYS       8
`define AXI_LLC_MMIO_BASE         32'h10000000
`define AXI_LLC_MMIO_SIZE         32'h00001000

`endif
