# subsystem_dual_mmio_read_route

状态：已通过，并已纳入 `formal/run_passed_hw_cbmc.sh`。

该 bounded formal smoke 直接实例化实际生产 `axi_llc_subsystem_dual.v`，验证 native
dual top 的最小 MMIO direct-bypass read 集成路径：

- `RESET_MODE=MODE_OFF`，避免该 smoke 被 LLC resident lookup / store 状态空间主导。
- 参数缩成 1 个 read master / 1 个 write master、小 line、小 outstanding、generic store。
- formal 入口将 `MODE_BITS` 扩成 3，仅用于绕开 hw-cbmc 对 0 次复制拼接的前端限制。
- 4B MMIO read 被 upstream 接受后，必须最终在 MMIO `AR` 口发出。
- `ARADDR` 等于原始 MMIO 地址，`ARLEN=0`，`ARSIZE=2`，`ARBURST=INCR`。
- 同一过程中不得驱动 DDR `AR/AW/W`。
- unsupported MMIO 大 read 必须保持 upstream `read_req_ready=0`，不得产生
  `read_req_accepted`，也不得驱动 DDR/MMIO `AR`。
- 该入口用 `request_seen` / `accepted_seen` / `seen_ar` 防止 vacuity；reset 后
  reconfig/active-mode 收敛不作为本入口目标，后续应拆独立 reconfig smoke 覆盖。

该入口不验证 `R` response 回收、不验证 mode1 cacheable 路径，也不验证完整 Linux/image
行为；这些仍由 VCS contract 和 simulator regression 覆盖。
