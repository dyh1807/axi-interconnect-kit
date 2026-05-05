# dual_bridge_prod_width_bypass_cacheline_read_response

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

覆盖对象：

- RTL top：`rtl/src/axi_llc_axi_bridge_dual.v`
- 参数：64B line / 32B DDR beat / 64B read response / 1-bit lower AXI ID
- 请求源：`bypass_req_*`，用于分担 native top `MODE_OFF` direct-bypass 64B read
  response 的 production-width 覆盖，避免 formal 入口直接拉入完整 core/compat/store。

覆盖范围：

- 64B DDR bypass read 被接受后只向 DDR `AR` 发出，不误走 cache response、MMIO 或
  write channel。
- `ARADDR/ARLEN/ARSIZE/ARBURST` 为 64B cacheline / 2x256-bit beat 形状。
- 两拍 DDR `R` 都必须 `RREADY=1`，第一拍 `RLAST=0` 前不能提前 upstream response。
- 第二拍 `RLAST=1` 后 `bypass_resp_valid/id/data/code` 回收完整 512-bit cacheline。

运行：

```sh
formal/dual_bridge_prod_width_bypass_cacheline_read_response/run_hw_cbmc.sh
```

明确不覆盖：

- 不证明完整 native dual top 的 compat direct-bypass accept/slot 逻辑。
- 不证明实际 C++ 类和 RTL 在同一个 hw-cbmc harness 内端到端等价。
