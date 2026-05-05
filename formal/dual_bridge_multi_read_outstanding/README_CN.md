# Dual Bridge Multi Read Outstanding Formal

该入口直接实例化生产 `axi_llc_axi_bridge_dual.v` / `axi_llc_axi_bridge.v`，用小参数检查
不同 cacheline 的两笔 DDR read 不会被串行化。

参数：

- `BRIDGE_READ_PENDING_COUNT=2`
- `BRIDGE_WRITE_PENDING_COUNT=1`
- `LINE_BYTES=8`
- `DDR_AXI_DATA_BYTES=8`
- `DDR_AXI_ID_BITS=1`

覆盖范围：

- 第一笔 DDR read 在未收到任何 `R` response 前保持 outstanding。
- 第二笔不同 line DDR read 在第一笔仍 outstanding 时仍可被 `cache_req_ready` 接受。
- 两笔 read 都必须发出 DDR `AR`，且不能误走 MMIO `AR`。
- 两笔 outstanding read 使用 1-bit AXI ID 空间中的两个不同 ID。

当前状态：

- 已通过，并已计入稳定 `formal/run_passed_hw_cbmc.sh`。

运行方式：

```sh
formal/dual_bridge_multi_read_outstanding/run_hw_cbmc.sh
```
