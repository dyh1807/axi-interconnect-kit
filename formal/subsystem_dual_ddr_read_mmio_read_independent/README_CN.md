# subsystem_dual_ddr_read_mmio_read_independent

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

这个 formal 用例直接实例化实际生产 `rtl/src/axi_llc_subsystem_dual.v`，检查 native
dual top 在 `MODE_OFF` direct-bypass 场景下不会因为 DDR read 已经发出 `AR` 且未收到
`R` 而阻塞独立 MMIO read 发出。

覆盖点：

- DDR 4B read 必须最终被 upstream 接受并只向 DDR `AR` 发出。
- 不提供 DDR `R` response，使 DDR read 保持 outstanding。
- DDR read outstanding 后，4B MMIO read 仍必须最终被 upstream 接受并向 MMIO `AR`
  发出。
- DDR `AR` 和 MMIO `AR` 的地址、burst 形状均需匹配请求。
- 同一过程中不得误发 DDR/MMIO write channel。

明确不覆盖：

- 不验证 DDR/MMIO `R` response 回收；这些已由 response formal 和 RTL contract 分担。
- 不覆盖 cacheable LLC hit/miss 语义；本入口只验证 native dual top 的 direct-bypass
  DDR/MMIO 独立发射。
