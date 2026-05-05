# axi_queue_ctrl 形式验证

该用例验证生产 RTL helper `axi_llc_axi_queue_ctrl.v` 与 C reference
`axi_bridge_queue_control()` 一致。

覆盖语义：

- issue queue / response queue 的 space 和 valid 判定。
- AXI `AR/AW/W` handshake 判定。
- read issue、write AW、write W queue 的 push/pop 判定。
- `W` queue 只有在 `W` handshake 且 `WLAST` 同时成立时才 pop。
