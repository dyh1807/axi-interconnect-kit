# Dual Bridge Write Then Read Outstanding Formal

该入口直接实例化生产 `axi_llc_axi_bridge_dual.v` / `axi_llc_axi_bridge.v`，用小参数检查
DDR write outstanding 不会把不同 cacheline 的 DDR read 串行化。

参数：

- `BRIDGE_READ_PENDING_COUNT=1`
- `BRIDGE_WRITE_PENDING_COUNT=1`
- `LINE_BYTES=8`
- `DDR_AXI_DATA_BYTES=8`
- `DDR_AXI_ID_BITS=1`

覆盖范围：

- 第一笔 DDR write 发出 `AW/W` 后不返回任何 `B`，因此 write 保持 outstanding。
- 第二笔不同 line DDR read 在该 write outstanding 期间仍必须被 `cache_req_ready` 接受。
- 第二笔 read 必须继续发出 DDR `AR`，且不能误走 MMIO `AR`。
- 因为 `B` 输入固定为无效，该检查覆盖的是不同 line `AW/W -> AR` 不被错误串行化。

当前状态：

- 已通过，并已计入稳定 `formal/run_passed_hw_cbmc.sh`。

运行方式：

```sh
formal/dual_bridge_write_then_read_outstanding/run_hw_cbmc.sh
```
