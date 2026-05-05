# axi_write_pack_prod_width

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

该 smoke 直接验证生产 `rtl/src/axi_llc_axi_write_pack.v` 在 64B line / 32B DDR beat
参数下的组合逻辑：

- 普通 cacheline write：`beat_idx=0/1` 时从 64B line 中切出对应 32B beat。
- mode2 DDR-aligned write：`req_addr=issued_addr+offset`，`offset` 覆盖 0 到 28，
  输出 256-bit `WDATA` 和 32-bit `WSTRB` 必须按 offset 从 source line 取字节并移位。

这是 helper 级生产宽度 EC，不实例化完整 bridge 状态机；完整 actual bridge 生产宽度
bounded smoke 仍保留为更重的后续项。
