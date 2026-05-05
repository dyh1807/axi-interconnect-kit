# axi_read_resp_ctrl 形式验证

该用例验证生产 RTL helper `axi_llc_axi_read_resp_ctrl.v` 与 C reference `axi_bridge_read_resp_control()` 一致。

覆盖语义：

- `rd_last_beat` 在命中读 pending slot 且 beat 计数到达事务 beat 数，或 AXI R 通道声明 `rlast` 时置位。
- `next_resp_code` 保留历史错误码；当前 `rresp` 非 OKAY 时优先记录当前错误码。
- 未匹配到读 pending slot 时不会声明读事务完成。
