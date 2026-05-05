# subsystem_dual_ddr_read_mmio_write_independent

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

这个 formal 用例直接实例化实际生产 `rtl/src/axi_llc_subsystem_dual.v`，检查 native
dual top 在 `MODE_OFF` direct-bypass 场景下不会因为 DDR read 未返回 `R` 而阻塞
MMIO write 发出。

覆盖点：

- DDR 4B read 和 MMIO 4B write 都必须最终被 upstream 接受。
- 不提供任何 DDR `R` response 或 MMIO `B` response，仍要求两侧请求都能在有限窗口内
  发出。
- DDR read 只能向 DDR `AR` 发出，且 `ARADDR/ARLEN/ARSIZE/ARBURST` 正确。
- MMIO write 只能向 MMIO `AW/W` 发出，且 `AWADDR/AWLEN/AWSIZE/AWBURST`、
  `WDATA/WSTRB/WLAST` 正确。
- 同一过程中不得误发 DDR `AW/W`，也不得误发 MMIO `AR`。

明确不覆盖：

- 不验证 DDR `R` / MMIO `B` response 回收；该项已由 bridge-level response formal 和
  RTL contract 覆盖。
- 不覆盖 cacheable DDR refill 的 LLC hit/miss 语义；本入口只验证 native dual top 的
  direct-bypass DDR/MMIO 独立发射。
