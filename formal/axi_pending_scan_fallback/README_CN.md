# AXI Pending Scan Fallback Formal Smoke

状态：已通过，并已纳入稳定 `formal/run_passed_hw_cbmc.sh`。

该入口复用 `formal/axi_pending_scan` 中的 fallback harness，验证实际生产
`axi_llc_axi_pending_scan.v` 在 `ENTRY_COUNT > AXI_ID_COUNT` 时的 tracked-ID 分支。
当前生产 bridge 使用 slot-ID mode；保留该证明是为了覆盖 helper 的 fallback generate
分支，避免后续参数变化时遗留未验证逻辑。

运行：

```sh
formal/axi_pending_scan_fallback/run_hw_cbmc.sh
```
