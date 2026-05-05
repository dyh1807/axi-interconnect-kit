# Dual Bridge Read Then Write Outstanding Formal

该入口直接实例化生产 `axi_llc_axi_bridge_dual.v` / `axi_llc_axi_bridge.v`，用小参数检查
DDR read outstanding 不会把不同 cacheline 的 DDR write 串行化。

参数：

- `BRIDGE_READ_PENDING_COUNT=1`
- `BRIDGE_WRITE_PENDING_COUNT=1`
- `LINE_BYTES=8`
- `DDR_AXI_DATA_BYTES=8`
- `DDR_AXI_ID_BITS=1`

覆盖范围：

- 第一笔 DDR read 发出 `AR` 后不返回任何 `R`，因此 read 保持 outstanding。
- 第二笔不同 line DDR write 在该 read outstanding 期间仍必须被 `cache_req_ready` 接受。
- 第二笔 write 必须继续发出 DDR `AW/W`，且不能误走 MMIO `AW/W`。
- 因为 `R` 输入固定为无效，该检查覆盖的是不同 line `AR -> AW/W` 不被错误串行化。

当前状态：

- 已通过，并已计入稳定 `formal/run_passed_hw_cbmc.sh`。

运行方式：

```sh
formal/dual_bridge_read_then_write_outstanding/run_hw_cbmc.sh
```
