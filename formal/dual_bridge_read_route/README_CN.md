# Dual Bridge Read Route Formal Smoke

这个目录是直接绑定实际 RTL bridge 的最小 hw-cbmc smoke。状态：已通过，并已纳入
`formal/run_passed_hw_cbmc.sh`。Verilog wrapper 只负责约束未关注的端口、缩小参数和
实例化生产模块：

- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_axi_beat_shape.v`
- `rtl/src/axi_llc_axi_mode2_shape.v`
- `rtl/src/axi_llc_axi_fifo_ptr.v`
- `rtl/src/axi_llc_axi_queue_ctrl.v`
- `rtl/src/axi_llc_axi_write_pack.v`
- `rtl/src/axi_llc_axi_read_pack.v`
- `rtl/src/axi_llc_axi_read_resp_ctrl.v`
- `rtl/src/axi_llc_axi_pending_scan.v`
- `rtl/src/axi_llc_axi_issue_select.v`
- `rtl/src/axi_llc_axi_req_accept.v`
- `rtl/src/axi_llc_axi_resp_accept.v`
- `rtl/src/axi_llc_axi_resp_route.v`
- `rtl/src/axi_llc_axi_source_resp_mux.v`
- `rtl/src/axi_llc_dual_port_route_shape.v`
- `rtl/src/axi_llc_dual_port_req_steer.v`
- `rtl/src/axi_llc_dual_port_issue_gate.v`
- `rtl/src/axi_llc_dual_port_hazard_scoreboard.v`
- `rtl/src/axi_llc_dual_port_resp_mux.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

当前检查对象：

- cache read request 在 reset 后若属于 supported DDR/MMIO 范围，必须被实际
  `axi_llc_axi_bridge_dual.v` 接受。
- supported DDR read 被接受后，在 bounded timeframe 内只能在 DDR `AR` 口发出。
- supported MMIO 4B read 被接受后，在 bounded timeframe 内只能在 MMIO `AR` 口发出，且 `ARLEN=0`、
  `ARSIZE=2`。
- unsupported MMIO 大 read 不得被接受，也不得发出 DDR/MMIO `AR`。

当前状态：

- 该入口已用于暴露实际 `axi_llc_axi_bridge.v` 中 hw-cbmc 前端不友好的 variable
  part-select，并已推动生产 RTL 改成 shift/mask byte helper。
- 脚本会显式传入实际 bridge 当前实例化的生产 helper，避免因为缺少 helper module
  让验证结果失真；其中 `axi_llc_axi_pending_scan.v` 与
  `axi_llc_axi_issue_select.v`、`axi_llc_axi_mode2_shape.v`、
  `axi_llc_axi_fifo_ptr.v`、
  `axi_llc_axi_queue_ctrl.v`、
  `axi_llc_axi_write_pack.v`、
  `axi_llc_axi_read_pack.v`、
  `axi_llc_axi_read_resp_ctrl.v`、`axi_llc_axi_id_shape.v`、
  `axi_llc_axi_resp_route.v`、
  `axi_llc_axi_source_resp_mux.v`、`axi_llc_dual_port_hazard_match.v`、
  `axi_llc_dual_port_slot_hazard.v` 已纳入依赖。
- 2026-05-03 该入口补齐实际生产 helper 依赖后通过。生产 bridge pending 深度已改成
  可参数化默认值；生产默认仍为 32/32，该 formal top 显式缩到 1/1，并把
  line/data/response 宽度缩到 64-bit、外部 AXI ID 宽度缩到 1-bit。
- 该入口只覆盖 read-route/AR 归属；更完整的 write route、`R/B` response 回收、
  data packing 和多 outstanding 时序状态仍需后续补充。

运行方式：

```sh
formal/dual_bridge_read_route/run_hw_cbmc.sh
```

实现说明：

- `run_hw_cbmc.sh` 会在 `local_debug/hw_cbmc_dual_bridge_read_route/` 下生成
  preprocess 后的 RTL 文件。脚本只覆盖参数宏以缩小 formal 实例；被检查的 module
  body 仍来自实际生产 RTL 文件。
