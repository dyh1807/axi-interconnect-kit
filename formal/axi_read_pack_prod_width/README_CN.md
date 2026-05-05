# AXI Read Pack Production Width Formal

该入口直接验证生产 RTL helper `rtl/src/axi_llc_axi_read_pack.v` 在生产宽度下的
AXI `R` channel beat merge 与 mode2 aligned read extract 逻辑。

参数：

- `READ_RESP_BYTES=64`
- `AXI_DATA_BYTES=32`
- `ADDR_BITS=32`

覆盖范围：

- 普通 64B cacheline read 的 2 个 256-bit `RDATA` beat 合并位置。
- 非 mode2 read 的 `final_data == merged_data`。
- mode2 DDR-aligned read 的 `req_addr - issued_addr` 字节偏移切片。
- offset=0 的 mode2 read 明确退化为低 256-bit beat 原样返回。

当前状态：

- 已通过，并已计入稳定 `formal/run_passed_hw_cbmc.sh`。

运行方式：

```sh
formal/axi_read_pack_prod_width/run_hw_cbmc.sh
```
