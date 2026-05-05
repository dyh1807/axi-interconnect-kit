# subsystem_dual_mode0_ddr_bypass_read_response_8b

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

该入口复用 `formal/subsystem_dual_mode0_ddr_bypass_read_response` 的实际生产
`axi_llc_subsystem_dual.v` top 和 C++ 共用 helper 对比 harness，但将请求固定为
MODE_OFF/direct-bypass 下 8B 对齐 DDR read。

覆盖范围：

- 8B DDR direct read 必须以单个 8B beat 发出，`ARADDR/ARLEN/ARSIZE/ARBURST`
  与生产 C helper 一致。
- DDR `R` 返回后，upstream `read_resp_valid/id/data` 必须与
  `axi_bridge_read_pack64` 的结果一致。
- 不得误发 DDR write 或 MMIO read/write。

运行：

```sh
formal/subsystem_dual_mode0_ddr_bypass_read_response_8b/run_hw_cbmc.sh
```
