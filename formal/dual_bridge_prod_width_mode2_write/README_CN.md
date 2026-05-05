# dual_bridge_prod_width_mode2_write

状态：实验入口，当前不纳入稳定 `formal/run_passed_hw_cbmc.sh`。

这个 bounded formal smoke 实例化实际生产 `axi_llc_axi_bridge_dual.v` 和
`axi_llc_axi_bridge.v`，但不把 line/data width 缩到 8B；它使用接近生产的
64B line / 32B DDR beat 参数，验证 bypass mode2 DDR-aligned 4B write：

- bypass mode2 write 在 DDR 地址上被 DDR bridge 接受，不误走 MMIO。
- 4B write 从 `req_addr=issue_addr+offset` 对齐成 32B DDR beat，`AWADDR` 为
  `issue_addr`，`AWLEN=0`，`AWSIZE=5`。
- `offset` 覆盖 0 到 28，`WDATA/WSTRB` 必须按 offset 移入 256-bit beat。
- DDR `B` 返回后，write response 回到 bypass source 的原 ID/code。

当前仍把 pending 深度、外部 AXI ID 宽度和 read response buffer 宽度缩小，以避免该
smoke 被 multi-outstanding/ID/read-response 状态空间主导；multi-outstanding 另列为
后续验证项。

当前实验结论：

- 未缩小默认 AXI ID / read response 宏时，240s timeout 停在实际 bridge 展开阶段。
- 缩小 AXI ID / read response 宏后可以进入 SAT，但 240s timeout，规模约
  57.7M variables / 163M clauses。
- 因此生产宽度 data packing 先由 `formal/axi_write_pack_prod_width` 这类 helper
  级 EC 覆盖，完整 actual bridge 生产宽度需要继续拆分或作为长跑实验处理。
