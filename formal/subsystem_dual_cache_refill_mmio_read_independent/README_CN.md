# subsystem_dual_cache_refill_mmio_read_independent

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

这个 formal 用例直接实例化实际生产 `rtl/src/axi_llc_subsystem_dual.v`，在小参数
MODE_CACHE wrapper 中发起一笔 non-bypass DDR cacheline read，使其在空 cache 下触发
DDR refill `AR`。harness 将 `ddr_axi_arready` 固定为低来保持该 refill 请求在途，
随后发起 4B MMIO read，验证 MMIO `AR` 仍能独立发出。

覆盖点：

- DDR cacheable read 最终必须被 upstream 接受。
- DDR cache miss/refill 必须发出 DDR `AR`，且在 `DDR_ARREADY=0` 时保持。
- DDR refill `AR` 被 hold 时，4B MMIO read 仍必须被 upstream 接受。
- MMIO read 必须发出到 MMIO `AR`，且与 held DDR `AR` 同时存在。
- 同一过程中不得误发 DDR/MMIO write 通道。

明确不覆盖：

- 当前为小参数 8B line / 8B DDR beat smoke，不覆盖生产 64B/256-bit refill shape。
- 不驱动 DDR `R` 完成 refill，也不验证最终 cache fill/read response 数据。
