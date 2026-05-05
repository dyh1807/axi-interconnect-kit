# subsystem_dual_ddr_write_mmio_read_independent

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

这个 formal 用例直接实例化实际生产 `rtl/src/axi_llc_subsystem_dual.v`，检查 native
dual top 在 `MODE_OFF` direct-bypass 场景下不会因为 DDR write 已经发出 `AW/W` 且
未收到 `B` 而阻塞独立 MMIO read 发出。

覆盖点：

- DDR 4B write 必须最终被 upstream 接受。
- DDR write 必须只向 DDR `AW/W` 发出，且 `AWADDR/AWLEN/AWSIZE/AWBURST`、
  `WDATA/WSTRB/WLAST` 正确。
- 不提供 DDR `B` response，使 DDR write 保持 outstanding。
- DDR write outstanding 后，4B MMIO read 仍必须最终被 upstream 接受并向 MMIO `AR`
  发出。
- 同一过程中不得误发 DDR `AR`，也不得误发 MMIO `AW/W`。

明确不覆盖：

- 不验证 DDR `B` / MMIO `R` response 回收；这些已由 response formal 和 RTL contract
  分担。
- 不覆盖 cacheable LLC hit/miss 语义；本入口只验证 native dual top 的 direct-bypass
  DDR/MMIO 独立发射。
