# subsystem_dual_cache_refill_mmio_write_independent

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

## 目标

验证生产 `rtl/src/axi_llc_subsystem_dual.v` 在 `MODE_CACHE` 下，当 DDR 侧 cache refill `AR` 已经发出但被 `ddr_axi_arready=0` 持续 hold 时，MMIO 侧 4B write 仍可独立发出 `AW/W`，不会被 DDR refill 阻塞。

## 覆盖点

- DDR read master 1 发起非 bypass cacheline read 到 `0x4000_0100`。
- DDR `AR` 被 hold 后，write master 0 发起 4B MMIO write 到 `0x1000_0008`。
- 形式化检查 MMIO `AW/W` 能在 DDR `AR` 仍 valid 时出现。
- 检查 MMIO 写形状：`AWLEN=0`、`AWSIZE=2`、`AWBURST=INCR`、`WDATA=0xdeadbeef`、`WSTRB=0xf`、`WLAST=1`。
- 检查该场景不产生 DDR `AW/W` 或 MMIO `AR` 泄漏。

## 运行

```bash
HW_CBMC_TIMEOUT_SEC=300 formal/subsystem_dual_cache_refill_mmio_write_independent/run_hw_cbmc.sh
```
