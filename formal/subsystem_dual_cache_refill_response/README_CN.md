# subsystem_dual_cache_refill_response

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

## 目标

验证生产 `rtl/src/axi_llc_subsystem_dual.v` 在 `MODE_CACHE` 下，空 cache 的 non-bypass DDR
read miss/refill 能在 DDR `R` 返回后产生 upstream `read_resp_valid/id/data`。

## 覆盖点

- read master 发起 cacheline read 到 `0x4000_0100`。
- 检查 miss/refill 发出 DDR `AR`，形状为单拍 8B smoke：`ARLEN=0`、`ARSIZE=3`。
- `AR` 握手后注入一拍 DDR `R`，检查 DUT 拉高 `RREADY`。
- 检查 upstream `read_resp_id=6` 且 `read_resp_data` 等于 DDR refill data。
- 同一过程中不得误发 DDR write 或 MMIO 通道。

## 运行

```bash
HW_CBMC_TIMEOUT_SEC=300 formal/subsystem_dual_cache_refill_response/run_hw_cbmc.sh
```
