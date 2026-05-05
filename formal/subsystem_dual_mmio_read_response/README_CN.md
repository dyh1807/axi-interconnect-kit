# subsystem_dual_mmio_read_response

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

这个 bounded formal smoke 直接实例化实际生产 `rtl/src/axi_llc_subsystem_dual.v`，验证
native dual top 的 MMIO read response 端到端闭环。

覆盖点：

- 4B MMIO read 最终被 upstream 接受，并发出到 MMIO `AR`。
- formal harness 在 `AR` 发出后注入一拍 MMIO `R` response。
- `R` response 被接受后，upstream 必须看到 `read_resp_valid`。
- upstream `read_resp_id` 必须等于原始 request id。
- upstream `read_resp_data[31:0]` 必须等于 MMIO `RDATA`。
- 同一过程中不得误发 DDR `AR/AW/W`。

明确不覆盖：

- 不验证 MMIO write `B` response；该项后续应补单独 native dual top smoke。
- 不覆盖 cacheable DDR refill 或 LLC hit/miss 语义。
