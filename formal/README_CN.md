# hw-cbmc Formal 验证状态与规划

本文档只记录 `hw-cbmc` 相关的形式化验证状态。VCS directed/regression 测试状态见
`rtl/docs/rtl_verif_plan_CN.md`。

## 原则

- 放进 `hw-cbmc` 的 C/RTL 必须来自实际生产路径，不能为了验证单独重写等价 spec。
- wrapper 只能做端口约束、复位/ready 固定、未关注端口 tie-off、以及暴露观测信号。
- 如果工具前端不支持某种 RTL 写法，优先重构生产 RTL 为等价且更前端友好的写法；
  不用 formal-only RTL 替身掩盖问题。
- 已通过状态只统计默认脚本可在默认 timeout 内返回 `VERIFICATION SUCCESSFUL` 的入口。

## 稳定回归入口

只运行当前已收敛的 formal smoke：

```sh
formal/run_passed_hw_cbmc.sh
```

该入口当前默认设置 `HW_CBMC_TIMEOUT_SEC=600`，只包含已能返回
`VERIFICATION SUCCESSFUL` 的项目。2026-05-05 当前 stable manifest 为 74 项；
其中前 71 项已有 split-run 证据：
`local_debug/run_passed_hw_cbmc_manifest71_20260505_144134.log` 完成前 20 项，
并在第 21 项本体已 `VERIFICATION SUCCESSFUL` 后因旧 240s wrapper timeout 退出；
`local_debug/run_passed_hw_cbmc_tail_manifest71_from21_20260505_151021.log`
从第 21 项继续跑并通过 51/51。新增第 72 项
`formal/dual_bridge_prod_width_bypass_cacheline_read_response` 的 targeted log 为
`local_debug/hw_cbmc_dual_bridge_prod_width_bypass_cacheline_read_response_20260505_154112.log`；
新增第 73 项 `formal/dual_bridge_prod_helper_read_issue_shape` 的 targeted log 为
`local_debug/hw_cbmc_dual_bridge_prod_helper_read_issue_shape_20260505_215117.log`；
新增第 74 项 `formal/dual_bridge_prod_helper_write_issue_shape` 的 targeted log 为
`local_debug/hw_cbmc_dual_bridge_prod_helper_write_issue_shape_20260505_220230.log`。
当前 `formal/*/run_hw_cbmc.sh` 共有 76 个入口，未纳入 stable manifest 的 2 个入口
已明确归类为 experimental/non-stable，见下方“非稳定实验入口”。它们不作为当前生产
RTL 失败结论，也不应在未收敛前加入 `formal/run_passed_hw_cbmc.sh`。

## 已通过

### `formal/axi_id_shape`

状态：已通过。

运行：

```sh
formal/axi_id_shape/run_hw_cbmc.sh
```

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_id_shape.v`
- 消费者：`rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- 6-bit AXI ID zero-extend 到 8-bit 时不得截断高于 bit2 的 ID。
- 3-bit AXI ID zero-extend 到 8-bit 时只保留低 3 bit。
- 8-bit AXI ID resize 到 6-bit 时只保留低 6 bit。
- 6-bit 到 6-bit 保持不变。

明确不覆盖：

- 不验证完整 bridge 的 lower ID 分配策略是否与 C++ trace 逐 bit 相同。
- 不验证 response slot ownership；这需要后续绑定实际 bridge 状态表或拆出生产
  response-owner helper。

### `formal/axi_beat_shape`

状态：已通过。

运行：

```sh
formal/axi_beat_shape/run_hw_cbmc.sh
```

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_beat_shape.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- 32B beat 的 `total_size -> total_beats / axi_len / axi_size`。
- 4B beat 的 `total_size -> total_beats / axi_len / axi_size`。
- 这份 RTL helper 已经被生产 `axi_llc_axi_bridge.v` 用于驱动 `AR/AW` 的 `len/size`
  以及 accept 时记录的 `total_beats`。

### `formal/axi_mode2_shape`

状态：已通过。

运行：

```sh
formal/axi_mode2_shape/run_hw_cbmc.sh
```

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_mode2_shape.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`
- 消费者：`rtl/src/axi_llc_axi_issue_select.v`

覆盖范围：

- 判断 mode2 DDR-aligned 请求是否可以落在单个 AXI beat 内。
- 单 beat 请求按 AXI data bytes 对齐，issue size 为 `AXI_DATA_BYTES-1`。
- 跨 beat/line 请求按 cacheline bytes 对齐，issue size 为 `LINE_BYTES-1`。
- 小参数实例覆盖 8-bit addr / 8B line / 4B AXI beat。

### `formal/axi_pending_scan`

状态：已通过。

运行：

```sh
formal/axi_pending_scan/run_hw_cbmc.sh
```

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_pending_scan.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- pending slot 中首个空闲 entry 的优先级选择。
- 当前已占用 AXI ID mask 下首个空闲 AXI ID 的选择。
- 外部 `RID/BID` 到 pending slot 的首个匹配选择。
- read complete queue 中首个 complete slot 的选择。

### `formal/axi_issue_select`

状态：已通过。

运行：

```sh
formal/axi_issue_select/run_hw_cbmc.sh
```

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_issue_select.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- queue 非空、slot valid、ready-to-issue 且未 done 时才允许 `AR/AW/W` 发射。
- cache source 不允许产生 mode2 DDR aligned 地址修正。
- bypass mode2 DDR aligned 时，issue addr/size 按 32B beat 或 64B line 对齐。
- AXI ID、W beat index 和 total beats 来自当前 queue-head slot。

### `formal/axi_fifo_ptr`

状态：已通过。

运行：

```sh
formal/axi_fifo_ptr/run_hw_cbmc.sh
```

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_fifo_ptr.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- push-only 推进 tail，count 加 1。
- pop-only 推进 head，count 减 1。
- push 与 pop 同拍发生时 head/tail 同时推进，count 保持不变。
- 无 push/pop 时 head/tail/count 保持不变。

### `formal/axi_queue_ctrl`

状态：已通过。

运行：

```sh
formal/axi_queue_ctrl/run_hw_cbmc.sh
```

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_queue_ctrl.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- issue queue / response queue 的 space 和 valid 判定。
- AXI `AR/AW/W` handshake 判定。
- read issue、write AW、write W queue 的 push/pop 判定。
- `W` queue 只有在 `W` handshake 且 `WLAST` 同时成立时才 pop。

### `formal/axi_write_pack`

状态：已通过。

运行：

```sh
formal/axi_write_pack/run_hw_cbmc.sh
```

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_write_pack.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- 普通 cacheline write 按 beat index 从 line data/strb 切出当前 AXI beat。
- mode2 DDR-aligned write 按 `req_addr - issued_addr` 把窄写数据移入 256-bit beat。
- `WSTRB` 与 `WDATA` 使用同一 byte 映射，不允许二次地址移位。
- 小参数实例覆盖 8B line / 4B AXI beat，用于保持状态空间可快速求解。

### `formal/axi_write_pack_prod_width`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/axi_write_pack_prod_width/run_hw_cbmc.sh
```

实际生产对象：

- RTL helper：`rtl/src/axi_llc_axi_write_pack.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- 生产宽度参数 64B line / 32B DDR beat。
- 普通 cacheline write 在 `beat_idx=0/1` 时分别切出低/高 32B beat。
- mode2 DDR-aligned write 在 `offset=0..28` 时，把 source line 字节和 strobe
  移入 256-bit `WDATA` / 32-bit `WSTRB`。
- 该入口是 helper 级 EC，不实例化完整 bridge 状态机。

### `formal/axi_read_pack`

状态：已通过。

运行：

```sh
formal/axi_read_pack/run_hw_cbmc.sh
```

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_read_pack.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- 普通 read 按 beat index 把 AXI `RDATA` 合并到 read response buffer。
- 非 mode2 aligned read 的最终返回数据等于合并后的 buffer。
- mode2 DDR-aligned read 按 `req_addr - issued_addr` 从合并 buffer 中提取返回窗口。
- 小参数实例覆盖 8B response / 4B AXI beat，用于保持状态空间可快速求解。

### `formal/axi_read_pack_prod_width`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/axi_read_pack_prod_width/run_hw_cbmc.sh
```

实际生产对象：

- RTL helper：`rtl/src/axi_llc_axi_read_pack.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- 生产宽度参数 64B response / 32B DDR beat。
- 普通 cacheline read 在 `beat_idx=0/1` 时分别合并低/高 32B beat。
- mode2 DDR-aligned read 在 `offset=0..28` 时，从 64B merged buffer 做字节切片。
- 该入口是 helper 级生产宽度检查，不实例化完整 bridge 状态机。

### `formal/axi_read_resp_ctrl`

状态：已通过。

运行：

```sh
formal/axi_read_resp_ctrl/run_hw_cbmc.sh
```

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_read_resp_ctrl.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- 匹配读 pending slot 且 beat 计数到达事务 beat 数时声明 `rd_last_beat`。
- AXI `RLAST` 可以提前声明读事务最后一个 beat。
- 当前 `RRESP` 非 OKAY 时优先记录当前错误码，否则保留历史错误码。
- 未匹配读 pending slot 时不会声明读事务完成。

### `formal/axi_req_accept`

状态：已通过。

运行：

```sh
formal/axi_req_accept/run_hw_cbmc.sh
```

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_req_accept.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- cache source 对 bypass source 的接受优先级。
- read request 只有在 read pending slot、AXI read ID 和 read issue queue 都有资源时接受。
- write request 只有在 write pending slot、AXI write ID、AW issue queue 和 W issue queue
  都有资源时接受。
- 接受后记录的 slot、AXI ID 和 total beats 来自对应 read/write 资源与对应 source。

### `formal/axi_resp_accept`

状态：已通过。

运行：

```sh
formal/axi_resp_accept/run_hw_cbmc.sh
```

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_resp_accept.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- `RREADY` 只取决于是否找到匹配 read slot，不被 upstream cache/bypass
  `resp_ready` 回压。
- `rd_resp_accept` 等价于 `RVALID && read slot match`。
- `BREADY` 需要匹配 write slot 且对应 source-local write response queue 有空间。
- `wr_resp_accept` 等价于 `BVALID && BREADY`。

### `formal/axi_source_resp_mux`

状态：已通过。

运行：

```sh
formal/axi_source_resp_mux/run_hw_cbmc.sh
```

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_source_resp_mux.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- source-local read response valid 时优先返回 read response。
- 没有 read response 且 write response valid 时返回 write response，rdata 为 0。
- `rd_pop` / `wr_pop` 只在对应 source 的 `resp_ready` 允许时产生。
- 同一拍不会同时 pop read response 和 write response。

### `formal/axi_resp_route`

状态：已通过。

运行：

```sh
formal/axi_resp_route/run_hw_cbmc.sh
```

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_axi_resp_route.v`
- 消费者：`rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- completed read 根据 pending slot owner 进入 cache/bypass read response queue。
- read response queue 没有空间时不得 dequeue completed read slot。
- write `B` response 根据 pending slot owner 进入 cache/bypass write response queue。
- `wr_match_rsp_space` 选择对应 owner 的 write response queue 空间，并反馈到
  `axi_llc_axi_resp_accept.v` 的 `BREADY` 门控。

### `formal/dual_port_route_shape`

状态：已通过。

运行：

```sh
formal/dual_port_route_shape/run_hw_cbmc.sh
```

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_dual_port_route_shape.v`

覆盖范围：

- `addr >= 0x4000_0000` 走 DDR port。
- `addr < 0x4000_0000` 走 MMIO port。
- MMIO 只支持 4B 请求，即 `total_size == 3`。
- DDR 侧 `axi_len` 按 32B/256-bit beat 向上取整，MMIO 侧 `axi_len=0`。
- DDR 侧 `axi_size=5`，MMIO 侧 `axi_size=2`。

明确不覆盖：

- 不覆盖时序状态、AXI handshake、outstanding、同 line AR/AW hazard。

### `formal/dual_port_req_steer`

状态：已通过。

运行：

```sh
formal/dual_port_req_steer/run_hw_cbmc.sh
```

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_dual_port_req_steer.v`
- 消费者：`rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- DDR 请求只驱动 DDR valid，并从 DDR ready 回传 upstream ready。
- supported MMIO 请求只驱动 MMIO valid，并从 MMIO ready 回传 upstream ready。
- unsupported MMIO 请求不驱动下游 valid，且 upstream ready 为 0。
- 同一请求不会同时驱动 DDR/MMIO 两个下游 valid。

### `formal/dual_port_issue_gate`

状态：已通过。

运行：

```sh
formal/dual_port_issue_gate/run_hw_cbmc.sh
```

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_dual_port_issue_gate.v`
- 消费者：`rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- `AR` 存在 slot/pending-write hazard 时不发出。
- `AW` 存在 slot/pending-read hazard 时不发出。
- 同周期同 line 的 `AR/AW` 同时可发时，`AR` 优先，`AW` 被屏蔽。
- 不同 line 时，只要没有已有 hazard，`AR/AW` 可在同周期各自发出。

### `formal/dual_port_hazard_match`

状态：已通过。

运行：

```sh
formal/dual_port_hazard_match/run_hw_cbmc.sh
```

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_dual_port_hazard_match.v`
- 消费者：`rtl/src/axi_llc_dual_port_hazard_scoreboard.v`

覆盖范围：

- DDR line/id match 只对 DDR port entry 生效。
- MMIO line/id match 只对 MMIO port entry 生效。
- invalid entry 不产生任何 match。

### `formal/dual_port_slot_hazard`

状态：已通过。

运行：

```sh
formal/dual_port_slot_hazard/run_hw_cbmc.sh
```

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_dual_port_slot_hazard.v`
- 消费者：`rtl/src/axi_llc_dual_port_hazard_scoreboard.v`

覆盖范围：

- primary port 没有第一个空槽时必须报告 slot hazard。
- secondary port 只有在没有第一个空槽，或 primary port 本周期实际 fire 且没有第二个空槽时，才报告 slot hazard。
- primary port 只是 valid 但没有 fire 时，不应因为“可能占用第一个空槽”而阻塞 secondary port。

### `formal/dual_port_resp_mux`

状态：已通过。

运行：

```sh
formal/dual_port_resp_mux/run_hw_cbmc.sh
```

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL helper：`rtl/src/axi_llc_dual_port_resp_mux.v`
- 消费者：`rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- MMIO response valid 时优先选择 MMIO。
- MMIO 不 valid 时选择 DDR。
- selected port 才收到 upstream `resp_ready`。
- non-selected port 被 backpressure。

## 已通过的 production-width actual bridge smoke

### `formal/bridge_prod_width_cacheline_aw_shape`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/bridge_prod_width_cacheline_aw_shape/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- 直接实例化实际生产 bridge，参数为 64B line / 32B DDR beat / 64B read response buffer。
- 64B cacheline write 被接受后，在 bounded timeframe 内产生 `AW`。
- `AWADDR` 保持 64B-aligned cacheline 地址。
- `AWLEN=1`，`AWSIZE=5`，`AWBURST=INCR`。

明确不覆盖：

- 不验证 `B` response 回收；该项由 `formal/dual_bridge_write_b_response` 覆盖。

### `formal/bridge_prod_width_cacheline_write_shape`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/bridge_prod_width_cacheline_write_shape/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- 直接实例化实际生产 bridge，参数为 64B line / 32B DDR beat / 64B read response buffer。
- 64B cacheline write 被接受后，在 bounded timeframe 内产生 2 个 256-bit `W` beat。
- 第一拍 `WLAST=0`，第二拍 `WLAST=1`。
- 两拍 `WSTRB` 均为 32-bit 全 1。
- 固定 512-bit payload 被拆成低 256-bit beat 和高 256-bit beat。

明确不覆盖：

- 不验证 `B` response 回收；该项由 `formal/dual_bridge_write_b_response` 覆盖。

### `formal/bridge_prod_width_cacheline_read_response`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/bridge_prod_width_cacheline_read_response/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- 直接实例化实际生产 bridge，参数为 64B line / 32B DDR beat / 64B read response buffer。
- 64B cacheline read 被接受后，在 bounded timeframe 内产生 `AR`。
- 外部 `R` 通道接收两拍 256-bit beat。
- 第一拍 `RLAST=0` 前不得提前产生 upstream read response。
- 第二拍 `RLAST=1` 后返回 512-bit response，并校验 upstream id/code/data。

### `formal/bridge_prod_width_cacheline_ar_shape`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/bridge_prod_width_cacheline_ar_shape/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_axi_bridge.v`

覆盖范围：

- 直接实例化实际生产 bridge，参数为 64B line / 32B DDR beat / 64B read response buffer。
- 64B cacheline read 被接受后，在 bounded timeframe 内产生 `AR`。
- `ARADDR` 保持 64B-aligned cacheline 地址。
- `ARLEN=1`，`ARSIZE=5`，`ARBURST=INCR`。

明确不覆盖：

- 该入口只验证 `AR` 地址通道。512-bit response merge 和 `R` response 回收已由
  `formal/bridge_prod_width_cacheline_read_response` 覆盖；组合层读打包仍由
  `formal/axi_read_pack_prod_width` 覆盖。

### `formal/dual_bridge_prod_width_cacheline_ar_shape`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/dual_bridge_prod_width_cacheline_ar_shape/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- 直接实例化实际 production dual bridge，参数为 64B line / 32B DDR beat。
- cache source 64B read 被接受后，必须在 bounded timeframe 内产生 DDR `AR`。
- `ARADDR/ARLEN/ARSIZE/ARBURST` 保持 2x256-bit production-width 形状。
- 不得误发 MMIO `AR/AW/W` 或 DDR `AW/W`。

明确不覆盖：

- 不验证 dual bridge production-width `R` response 的 512-bit merge；cache-source
  merge 已由 `formal/dual_bridge_prod_width_cacheline_read_response` 覆盖，
  bypass-source merge 已由
  `formal/dual_bridge_prod_width_bypass_cacheline_read_response` 分担覆盖。

### `formal/dual_bridge_prod_helper_read_issue_shape`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/dual_bridge_prod_helper_read_issue_shape/run_hw_cbmc.sh
```

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL：实际 `rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- nondet DDR/MMIO bypass read request 经过实际 dual bridge route/issue 后，外部
  `ARADDR/ARLEN/ARSIZE/ARBURST` 必须匹配生产 C helper
  `axi_bridge_downstream_read_issue_shape()`。
- DDR case 使用 `bypass_req_mode2_ddr_aligned=1`，覆盖 mode0/direct DDR 侧固定
  256-bit aligned read issue shape。
- MMIO case 覆盖 4B supported 和非 4B unsupported；unsupported 必须
  `bypass_req_ready=0` 且不发外部 `AR/AW`。

明确不覆盖：

- 不覆盖 write issue shape、`R` response merge/route，也不宣称完整 C++ class 与
  RTL top 端到端等价。它是 production-helper/actual-RTL EC 的一个可控切片。

### `formal/dual_bridge_prod_helper_write_issue_shape`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/dual_bridge_prod_helper_write_issue_shape/run_hw_cbmc.sh
```

实际生产对象：

- C helper：`include/axi_dual_port_route_shape.h`
- RTL：实际 `rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- nondet DDR/MMIO bypass write request 经过实际 dual bridge route/issue 后，外部
  `AWADDR/AWLEN/AWSIZE/AWBURST` 必须匹配生产 C helper
  `axi_bridge_downstream_write_issue_shape()`。
- DDR case 使用 `bypass_req_mode2_ddr_aligned=1`，覆盖 mode0/direct DDR 侧固定
  256-bit aligned write issue shape。
- MMIO case 覆盖 4B supported 和非 4B unsupported；unsupported 必须
  `bypass_req_ready=0` 且不发外部 `AR/AW`。

明确不覆盖：

- 不覆盖 write data/strobe payload、unsupported `WVALID` no-escape、`B` response
  route，也不宣称完整 C++ class 与 RTL top 端到端等价。它是
  production-helper/actual-RTL EC 的一个可控切片。

### `formal/dual_bridge_prod_width_cacheline_read_response`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/dual_bridge_prod_width_cacheline_read_response/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- 直接实例化实际 production dual bridge，参数为 64B line / 32B DDR beat /
  64B upstream response。
- cache source 64B read 只向 DDR `AR` 发出，不误走 MMIO 或 write channel。
- 两拍 DDR `R` 被 `RREADY` 接收，第一拍 `RLAST=0` 前不提前回包。
- 第二拍 `RLAST=1` 后 upstream response 的 `id/code/512-bit data` 完整回收。

明确不覆盖：

- 不实例化完整 `axi_llc_subsystem_dual.v`；native top production-width direct proof
  仍因 typecheck/展开过重保留为实验入口。
- 不把实际 C++ 类编入同一个 hw-cbmc harness；当前前端不能解析项目依赖的系统
  C++ 标准库。

### `formal/dual_bridge_prod_width_bypass_cacheline_read_response`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/dual_bridge_prod_width_bypass_cacheline_read_response/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- 直接实例化实际 production dual bridge，参数为 64B line / 32B DDR beat /
  64B upstream response。
- bypass source 64B read 用于分担 native top `MODE_OFF` direct-bypass 64B read
  response 的 production-width 覆盖，不拉入完整 core/compat/store。
- 两拍 DDR `R` 都必须 `RREADY=1`，第一拍 `RLAST=0` 前不能提前 upstream response。
- 第二拍 `RLAST=1` 后 `bypass_resp_valid/id/data/code` 回收完整 512-bit cacheline。

明确不覆盖：

- 不证明完整 native dual top 的 compat direct-bypass accept/slot 逻辑。
- 不证明实际 C++ 类和 RTL 在同一个 hw-cbmc harness 内端到端等价。

## 已通过的 native dual subsystem bounded smoke

### `formal/subsystem_dual_mmio_read_route`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/subsystem_dual_mmio_read_route/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_subsystem_dual.v`
- `rtl/src/axi_llc_subsystem_compat.v`
- `rtl/src/axi_llc_subsystem_core.v`
- `rtl/src/llc_cache_ctrl.v`
- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- 直接实例化 native dual top，formal top 只缩小参数、tie-off 未关注端口并暴露观测信号。
- 4B MMIO read 最终必须被 upstream 接受。
- accepted id 必须保持原始 request id。
- 被接受后的请求最终只能在 MMIO `AR` 口发出。
- MMIO `ARADDR` 等于原始地址，`ARLEN=0`，`ARSIZE=2`，`ARBURST=INCR`。
- 同一过程中不得误发 DDR `AR/AW/W`。
- unsupported MMIO 大 read 必须在 top 接受面保持 `read_req_ready=0`，不得产生
  `read_req_accepted`，也不得发出 DDR/MMIO `AR`。

明确不覆盖：

- 不把 reset 后 reconfig/active-mode 收敛作为本入口证明目标；该项已由
  `rtl/tb/tb_axi_llc_subsystem_core_startup_idle_contract.v` 通过 VCS directed
  contract 覆盖。
- 不验证 `R` response 回收、MMIO write route、cacheable DDR refill/hit/miss 路径。
- 为绕开 hw-cbmc 对 0 次复制拼接的前端限制，该 formal 参数将 `MODE_BITS` 扩为 3；
  被验证逻辑仍来自实际生产 RTL。

### `formal/subsystem_dual_mmio_read_response`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/subsystem_dual_mmio_read_response/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_subsystem_dual.v`
- `rtl/src/axi_llc_subsystem_compat.v`
- `rtl/src/axi_llc_subsystem_core.v`
- `rtl/src/llc_cache_ctrl.v`
- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- 直接实例化 native dual top，formal top 只缩小参数、tie-off 未关注端口并暴露观测信号。
- 4B MMIO read 最终必须被 upstream 接受，并发出到 MMIO `AR`。
- formal harness 在 `AR` 发出后注入一拍 MMIO `R` response。
- `R` 被接受后，upstream 必须看到 `read_resp_valid`。
- `read_resp_id` 必须等于原始 request id。
- `read_resp_data[31:0]` 必须等于 MMIO `RDATA`。
- 同一过程中不得误发 DDR `AR/AW/W`。

明确不覆盖：

- 不覆盖 cacheable DDR refill 或 LLC hit/miss 语义。

### `formal/subsystem_dual_mmio_write_route`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/subsystem_dual_mmio_write_route/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_subsystem_dual.v`
- `rtl/src/axi_llc_subsystem_compat.v`
- `rtl/src/axi_llc_subsystem_core.v`
- `rtl/src/llc_cache_ctrl.v`
- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- 直接实例化 native dual top，formal top 只缩小参数、tie-off 未关注端口并暴露观测信号。
- 4B MMIO write 最终必须被 upstream 接受。
- 被接受后的请求最终只能在 MMIO `AW/W` 口发出。
- MMIO `AWADDR` 等于原始地址，`AWLEN=0`，`AWSIZE=2`，`AWBURST=INCR`。
- MMIO `WDATA/WSTRB/WLAST` 必须与原始 32-bit write 请求一致。
- 同一过程中不得误发 DDR `AR/AW/W`，也不得误发 MMIO `AR`。
- unsupported MMIO 大 write 必须在 top 接受面保持 `write_req_ready=0`，不得产生
  `write_req_accepted`，也不得发出 DDR/MMIO `AW/W`。

明确不覆盖：

- 不把 reset 后 reconfig/active-mode 收敛作为本入口证明目标；该项已由
  `rtl/tb/tb_axi_llc_subsystem_core_startup_idle_contract.v` 通过 VCS directed
  contract 覆盖。

### `formal/subsystem_dual_mmio_write_response`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/subsystem_dual_mmio_write_response/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_subsystem_dual.v`
- `rtl/src/axi_llc_subsystem_compat.v`
- `rtl/src/axi_llc_subsystem_core.v`
- `rtl/src/llc_cache_ctrl.v`
- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- 直接实例化 native dual top，formal top 只缩小参数、tie-off 未关注端口并暴露观测信号。
- 4B MMIO write 最终必须被 upstream 接受，并发出到 MMIO `AW/W`。
- formal harness 在 `AW/W` 发出后注入一拍 MMIO `B` response。
- `B` 被接受后，upstream 必须看到 `write_resp_valid`。
- `write_resp_id` 必须等于原始 request id。
- `write_resp_code` 必须等于 MMIO `BRESP`。
- 同一过程中不得误发 DDR `AR/AW/W`。

明确不覆盖：

- 不覆盖 cacheable DDR writeback/refill 语义。
- 不覆盖多 outstanding `B` response 重排；该项继续由 bridge/route-level formal 覆盖。

### `formal/subsystem_dual_ddr_read_mmio_write_independent`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/subsystem_dual_ddr_read_mmio_write_independent/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_subsystem_dual.v`
- `rtl/src/axi_llc_subsystem_compat.v`
- `rtl/src/axi_llc_subsystem_core.v`
- `rtl/src/llc_cache_ctrl.v`
- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- 直接实例化 native dual top，formal top 只缩小参数、tie-off 未关注端口并暴露观测信号。
- 在 `MODE_OFF` direct-bypass 场景下同时驱动 DDR 4B read 与 MMIO 4B write。
- 不提供 DDR `R` 或 MMIO `B` response，仍要求两笔 upstream 请求都被接受。
- DDR read 必须发出到 DDR `AR`，且 `ARADDR/ARLEN/ARSIZE/ARBURST` 正确。
- MMIO write 必须发出到 MMIO `AW/W`，且 `AWADDR/AWLEN/AWSIZE/AWBURST`、
  `WDATA/WSTRB/WLAST` 正确。
- 同一过程中不得误发 DDR `AW/W`，也不得误发 MMIO `AR`。

明确不覆盖：

- 不验证 DDR `R` / MMIO `B` response 回收；该项已由 bridge-level response formal 和
  RTL contract 覆盖。
- 不覆盖 cacheable DDR refill 的 LLC hit/miss 语义；本入口只验证 native dual top 的
  direct-bypass DDR/MMIO 独立发射。

### `formal/subsystem_dual_cache_refill_mmio_read_independent`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/subsystem_dual_cache_refill_mmio_read_independent/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_subsystem_dual.v`
- `rtl/src/axi_llc_subsystem_compat.v`
- `rtl/src/axi_llc_subsystem_core.v`
- `rtl/src/llc_cache_ctrl.v`
- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- 直接实例化 native dual top，formal top 只缩小参数、tie-off 未关注端口并暴露观测信号。
- MODE_CACHE 下 non-bypass DDR cacheline read 最终必须被 upstream 接受。
- 空 cache 下 DDR cache read miss/refill 必须发出 DDR `AR`。
- `DDR_ARREADY=0` 时 DDR refill `AR` 必须保持。
- held DDR refill `AR` 存在时，4B MMIO read 仍必须被 upstream 接受并发出 MMIO `AR`。
- 同一过程中不得误发 DDR/MMIO write 通道。

明确不覆盖：

- 小参数 8B line / 8B DDR beat smoke 不覆盖生产 64B/256-bit refill shape。

### `formal/subsystem_dual_cache_refill_mmio_write_independent`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/subsystem_dual_cache_refill_mmio_write_independent/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_subsystem_dual.v`
- `rtl/src/axi_llc_subsystem_compat.v`
- `rtl/src/axi_llc_subsystem_core.v`
- `rtl/src/llc_cache_ctrl.v`
- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- 直接实例化 native dual top，formal top 只缩小参数、tie-off 未关注端口并暴露观测信号。
- MODE_CACHE 下 non-bypass DDR cacheline read 最终必须被 upstream 接受。
- 空 cache 下 DDR cache read miss/refill 必须发出 DDR `AR`。
- `DDR_ARREADY=0` 时 DDR refill `AR` 必须保持。
- held DDR refill `AR` 存在时，4B MMIO write 仍必须被 upstream 接受并发出 MMIO
  `AW/W`。
- 检查 MMIO `AWADDR/AWLEN/AWSIZE/AWBURST`、`WDATA/WSTRB/WLAST` 形状。
- 同一过程中不得误发 DDR write 通道或 MMIO `AR`。

明确不覆盖：

- 小参数 8B line / 8B DDR beat smoke 不覆盖生产 64B/256-bit refill shape。

### `formal/subsystem_dual_cache_refill_response`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/subsystem_dual_cache_refill_response/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_subsystem_dual.v`
- `rtl/src/axi_llc_subsystem_compat.v`
- `rtl/src/axi_llc_subsystem_core.v`
- `rtl/src/llc_cache_ctrl.v`
- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- 直接实例化 native dual top，formal top 只缩小参数、tie-off 未关注端口并暴露观测信号。
- MODE_CACHE 下 non-bypass DDR cacheline read 最终必须被 upstream 接受。
- 空 cache 下 DDR cache read miss/refill 必须发出 DDR `AR`。
- DDR `AR` 握手后注入单拍 DDR `R`，DUT 必须拉高 `RREADY`。
- refill 返回后 upstream 必须看到 `read_resp_valid`。
- `read_resp_id` 必须等于原始 request id，`read_resp_data` 必须等于注入的 DDR refill data。
- 同一过程中不得误发 DDR write 或 MMIO 通道。

明确不覆盖：

- 小参数 8B line / 8B DDR beat smoke 不覆盖生产 64B/256-bit refill response shape。
- 不覆盖 refill 完成后再次同地址 read 的 hit 语义；该项由
  `formal/subsystem_dual_cache_fill_hit_response` 覆盖。

### `formal/subsystem_dual_cache_fill_hit_response`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/subsystem_dual_cache_fill_hit_response/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_subsystem_dual.v`
- `rtl/src/axi_llc_subsystem_compat.v`
- `rtl/src/axi_llc_subsystem_core.v`
- `rtl/src/llc_cache_ctrl.v`
- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- 直接实例化 native dual top，formal top 只缩小参数、tie-off 未关注端口并暴露观测信号。
- MODE_CACHE 下第一次 non-bypass DDR cacheline read 对空 cache 产生 miss/refill。
- DDR `AR` 握手后注入单拍 DDR `R`，DUT 必须拉高 `RREADY`。
- 第一次 upstream `read_resp_valid/id/data` 必须回收注入的 refill data。
- 第二次同地址 read 必须返回相同 data 和新的 upstream ID。
- 第一次响应后不得再次发出 DDR `AR`，从而证明该第二次读走已安装 cacheline。
- 同一过程中不得误发 DDR write 或 MMIO 通道。

明确不覆盖：

- 小参数 8B line / 8B DDR beat smoke 不覆盖生产 64B/256-bit refill hit shape。
- 不覆盖 dirty victim/writeback；后续仍需单独 bounded 或 RTL contract 场景。

### `formal/subsystem_dual_cache_full_write_hit_response`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/subsystem_dual_cache_full_write_hit_response/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_subsystem_dual.v`
- `rtl/src/axi_llc_subsystem_compat.v`
- `rtl/src/axi_llc_subsystem_core.v`
- `rtl/src/llc_cache_ctrl.v`
- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- 直接实例化 native dual top，formal top 只缩小参数、tie-off 未关注端口并暴露观测信号。
- MODE_CACHE 下 full-line write miss 可以在空 cache 中直接安装 dirty line。
- full-line write miss 不得先发 DDR refill `AR`，也不得误发 DDR write 或 MMIO 通道。
- upstream write response 的 `id/code` 必须保持原始 request 语义。
- 写响应返回后，同地址 read 必须命中并返回刚写入的数据和新的 upstream ID。

明确不覆盖：

- 小参数 8B line / 8B DDR beat smoke 不覆盖生产 64B/256-bit full-line write shape。
- 不覆盖 dirty victim eviction/writeback；该语义已由
  `formal/cache_ctrl_dirty_evict_writeback` 在生产 `llc_cache_ctrl.v` 边界覆盖；完整
  `axi_llc_subsystem_dual.v` 层已由
  `formal/subsystem_dual_cache_dirty_evict_writeback` 补充 dirty victim DDR `AW/W` split
  proof，并由 `formal/subsystem_dual_cache_dirty_evict_b_response` 补充 DDR `B` 后
  upstream response split proof；B 后新 dirty line read-hit 已由
  `formal/subsystem_dual_cache_dirty_evict_post_b_hit` 覆盖。

### `formal/subsystem_dual_mode0_ddr_bypass_align`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/subsystem_dual_mode0_ddr_bypass_align/run_hw_cbmc.sh
```

实际生产对象：

- C/C++ helper：`include/axi_dual_port_route_shape.h`
- C++ 消费者：`axi_interconnect/AXI_Interconnect.cpp`
- RTL top：`rtl/src/axi_llc_subsystem_dual.v`

覆盖范围：

- 直接实例化 native dual top，formal top 只缩小参数、tie-off 未关注端口并暴露观测信号。
- MODE_OFF/direct-bypass 下 DDR read 覆盖 4B 未对齐 offset 0..4 与 8B 对齐两类请求，
  必须对齐到 DDR beat 地址。
- MODE_OFF/direct-bypass 下未对齐 4B DDR write 必须对齐到 DDR beat 地址。
- `AR/AW LEN/SIZE`、write payload/strobe byte lane 和 `WLAST` 必须与生产 C++ helper 一致。
- 同一过程中不得误发 MMIO 通道。

### `formal/subsystem_dual_mode0_ddr_bypass_read_response`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/subsystem_dual_mode0_ddr_bypass_read_response/run_hw_cbmc.sh
```

实际生产对象：

- C/C++ helper：`include/axi_dual_port_route_shape.h`
- C++ 消费者：`axi_interconnect/AXI_Interconnect.cpp`
- RTL top：`rtl/src/axi_llc_subsystem_dual.v`

覆盖范围：

- 直接实例化 native dual top，formal top 只缩小参数、tie-off 未关注端口并暴露观测信号。
- MODE_OFF/direct-bypass 下未对齐 4B DDR read 必须对齐到 DDR beat 地址。
- DDR `R` 返回后必须保持 `RREADY` 可接收，并按原始地址到 issued 地址的 byte offset
  截取 aligned beat 中的数据。
- upstream `read_resp_valid/id/data` 必须与生产 C++ read-pack helper 一致。
- 同一过程中不得误发 MMIO 或写通道。

### `formal/subsystem_dual_mode0_ddr_bypass_read_response_8b`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/subsystem_dual_mode0_ddr_bypass_read_response_8b/run_hw_cbmc.sh
```

实际生产对象：

- C/C++ helper：`include/axi_dual_port_route_shape.h`
- C++ 消费者：`axi_interconnect/AXI_Interconnect.cpp`
- RTL top：`rtl/src/axi_llc_subsystem_dual.v`

覆盖范围：

- 复用 `formal/subsystem_dual_mode0_ddr_bypass_read_response` 的 production RTL top 和
  C helper 对比 harness，但请求固定为 8B 对齐 DDR read。
- DDR `AR` shape、`RREADY`、DDR `RDATA` 回收到 upstream `read_resp_valid/id/data`
  必须与生产 C++ helper 一致。
- 同一过程中不得误发 MMIO 或写通道。

### `formal/subsystem_dual_cache_dirty_evict_writeback`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/subsystem_dual_cache_dirty_evict_writeback/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_subsystem_dual.v`
- `rtl/src/axi_llc_subsystem_compat.v`
- `rtl/src/axi_llc_subsystem_core.v`
- `rtl/src/llc_cache_ctrl.v`
- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- 直接实例化 native dual top，formal top 只缩小参数、tie-off 未关注端口并暴露观测信号。
- MODE_CACHE 下连续三笔 full-line write miss：前两笔写入同一 set 的两个 way，第三笔
  同 set 不同 tag 必须触发 dirty victim writeback。
- dirty victim writeback 必须走 DDR `AW/W`，不得误发 DDR `AR` 或 MMIO `AR/AW/W`。
- DDR writeback 的 `AWADDR/AWLEN/AWSIZE/AWBURST` 与 `WDATA/WSTRB/WLAST` 必须对应
  被替换的 dirty line。
- 在未提供 DDR `B` 前，第三笔 upstream write response 不得提前返回。

明确不覆盖：

- 该入口刻意不驱动 DDR `B`，因此不在完整 subsystem 层证明 B 后安装新 dirty line
  并返回第三笔 write response。
- B 后 upstream response split 已由 `formal/subsystem_dual_cache_dirty_evict_b_response`
  在完整 native dual top 边界覆盖。
- B 后新 dirty line read-hit 已由
  `formal/subsystem_dual_cache_dirty_evict_post_b_hit` 在完整 native dual top 边界覆盖；
  更细的安装状态更新仍由 `formal/cache_ctrl_dirty_evict_writeback` 在生产
  `llc_cache_ctrl.v` 边界覆盖。
- 小参数 8B line / 8B DDR beat smoke 不覆盖生产 64B/256-bit AXI payload；生产宽度
  payload 由 `bridge_prod_width_cacheline_*` 覆盖。

### `formal/subsystem_dual_cache_dirty_evict_b_response`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/subsystem_dual_cache_dirty_evict_b_response/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_subsystem_dual.v`
- `rtl/src/axi_llc_subsystem_compat.v`
- `rtl/src/axi_llc_subsystem_core.v`
- `rtl/src/llc_cache_ctrl.v`
- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- 直接复用 native dual top dirty-evict formal wrapper，formal top 只缩小参数、tie-off
  未关注端口并暴露观测信号。
- MODE_CACHE 下连续三笔 full-line write miss 触发 dirty victim DDR writeback。
- DDR `AW/W` 被接受后，匹配 `BID` 的 DDR `B` 到达时，完整 native dual top 必须拉高
  `BREADY`。
- 第三笔 upstream write response 只能在 DDR `B` 已被接受或同拍接受后返回，且
  `write_resp_id/code` 必须正确。
- 同一过程中不得误发 DDR `AR` 或 MMIO `AR/AW/W`。

明确不覆盖：

- 小参数 8B line / 8B DDR beat smoke 不覆盖生产 64B/256-bit AXI payload；生产宽度
  payload 由 `bridge_prod_width_cacheline_*` 覆盖。
- B 后新 dirty line read-hit 已由
  `formal/subsystem_dual_cache_dirty_evict_post_b_hit` 在完整 native dual top 边界覆盖；
  更细的安装状态更新仍由 `formal/cache_ctrl_dirty_evict_writeback` 在生产
  `llc_cache_ctrl.v` 边界覆盖。
- 不覆盖任意长 `B` 延迟公平性，也不覆盖实际 C++ reference 与实际 RTL top 的端到端 EC。

### `formal/subsystem_dual_cache_dirty_evict_post_b_hit`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/subsystem_dual_cache_dirty_evict_post_b_hit/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_subsystem_dual.v`
- `rtl/src/axi_llc_subsystem_compat.v`
- `rtl/src/axi_llc_subsystem_core.v`
- `rtl/src/llc_cache_ctrl.v`
- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

覆盖范围：

- 直接实例化 native dual top，formal top 只缩小参数、tie-off 未关注端口并暴露观测信号。
- MODE_CACHE 下连续三笔 full-line write miss 触发 dirty victim DDR writeback。
- dirty victim DDR `AW/W/B` 完成并返回第三笔 upstream write response 后，再对第三笔地址发起 read。
- 该 read 必须命中新安装的 dirty line，不得再发 DDR `AR` 或 MMIO 访问。
- read response 的 `id/data` 必须对应第三笔写入的新 line。

明确不覆盖：

- 小参数 8B line / 8B DDR beat smoke 不覆盖生产 64B/256-bit AXI payload；生产宽度
  payload 由 `bridge_prod_width_cacheline_*` 覆盖。
- 不覆盖任意长 `B` 延迟公平性。
- 不覆盖实际 C++ reference 与实际 RTL top 的端到端 EC。

### `formal/cache_ctrl_dirty_evict_writeback`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/cache_ctrl_dirty_evict_writeback/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/llc_cache_ctrl.v`
- 消费者：`rtl/src/axi_llc_subsystem_core.v`

覆盖范围：

- 直接实例化生产 cache-control FSM，formal top 只提供 data/meta/valid/repl 环境行。
- 同一 set 两个 way 均 valid+dirty，replacement way 指向 way0。
- 第三个同 set 不同 tag 的 full-line write miss 必须先发 dirty victim writeback。
- writeback `mem_req` 的 write/address/data/strobe/size 必须对应被替换的 dirty line。
- writeback response 被接收后，才允许安装新 dirty line 并返回 upstream write response。
- 安装阶段必须同时更新 data/meta/valid，并推进 replacement way。

明确不覆盖：

- 不实例化完整 native dual top 和 DDR AXI bridge；完整 subsystem dirty-evict harness
  当前 300s 内未收敛，后续需要继续拆小。
- DDR AXI `AW/W/B` channel 形状由 existing `dual_bridge_*` 与 production-width bridge
  smoke 覆盖。

### `formal/cache_ctrl_partial_write_miss_refill`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/cache_ctrl_partial_write_miss_refill/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/llc_cache_ctrl.v`
- 消费者：`rtl/src/axi_llc_subsystem_core.v`

覆盖范围：

- 直接实例化生产 cache-control FSM，formal top 只提供空 set store 环境和固定 refill
  data。
- partial write miss 不能直接安装写数据，必须先发整行 refill read。
- refill `mem_req` 必须是 read，地址 line-aligned，size 为整行。
- refill response 被接收后，按 request offset 和 `WSTRB` merge 写数据并安装 dirty line。
- 安装阶段必须同时更新 data/meta/valid，推进 replacement way，并返回 upstream write
  response。

明确不覆盖：

- 不实例化完整 native dual top 和 DDR AXI bridge。
- dirty victim/writeback 由 `formal/cache_ctrl_dirty_evict_writeback` 覆盖。

### `formal/cache_ctrl_read_miss_refill_response`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/cache_ctrl_read_miss_refill_response/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/llc_cache_ctrl.v`
- 消费者：`rtl/src/axi_llc_subsystem_core.v`

覆盖范围：

- 直接实例化生产 cache-control FSM，formal top 只提供空 set store 环境和固定 refill
  data。
- read miss 必须先发整行 refill read，地址 line-aligned，size 为整行。
- refill response 被接收后，必须把 refill line 安装成 valid+clean line。
- 安装阶段必须同时更新 data/meta/valid，推进 replacement way，并返回 upstream read
  response。
- upstream read response 的 id/code/data 必须与请求和 refill line 一致。

明确不覆盖：

- 不实例化完整 native dual top 和 DDR AXI bridge。
- dirty victim/writeback 由 `formal/cache_ctrl_dirty_evict_writeback` 覆盖。
- partial write miss merge 由 `formal/cache_ctrl_partial_write_miss_refill` 覆盖。

### `formal/cache_ctrl_partial_write_hit_merge`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/cache_ctrl_partial_write_hit_merge/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/llc_cache_ctrl.v`
- 消费者：`rtl/src/axi_llc_subsystem_core.v`

覆盖范围：

- 直接实例化生产 cache-control FSM，formal top 只提供一个命中的 clean line 环境。
- partial write hit 不得发外部 memory request。
- data store 写回必须只更新命中 way，并按 request offset 和 `WSTRB` merge 写数据。
- meta store 必须把命中 way 从 clean 更新为 dirty，valid/replacement 同步更新。
- upstream write response 的 id/code 必须保持正确。

明确不覆盖：

- 不实例化完整 native dual top 和 DDR AXI bridge。
- partial write miss refill/merge 由 `formal/cache_ctrl_partial_write_miss_refill` 覆盖。

## 已通过的 actual bridge bounded smoke

### `formal/dual_bridge_read_route`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/dual_bridge_read_route/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_dual_port_route_shape.v`
- `rtl/src/axi_llc_dual_port_req_steer.v`
- `rtl/src/axi_llc_dual_port_issue_gate.v`
- `rtl/src/axi_llc_dual_port_hazard_scoreboard.v`
- `rtl/src/axi_llc_dual_port_resp_mux.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

目标覆盖范围：

- reset 后 cache read request 若属于 supported DDR/MMIO 范围，必须被实际
  `axi_llc_axi_bridge_dual.v` 接受。
- supported DDR read 被接受后，在 bounded timeframe 内只能在 DDR `AR` 口发出。
- supported MMIO 4B read 被接受后，在 bounded timeframe 内只能在 MMIO `AR` 口发出，且 `ARLEN=0`、
  `ARSIZE=2`。
- unsupported MMIO 大 read 不得被接受，也不得发出 DDR/MMIO `AR`。

当前进展：

- 该入口使用实际生产 `axi_llc_axi_bridge.v` 和 `axi_llc_axi_bridge_dual.v` module
  body；wrapper 只做 tie-off、参数缩小和输出观测。
- 生产 bridge pending 深度已改成可参数化默认值。生产默认宏仍为 32/32；该 formal
  top 显式缩到 1/1，把 line/data/response 宽度缩到 64-bit，并把外部 AXI ID 宽度缩到
  1-bit，以避免 route smoke 被无关 ID 搜索状态空间拖慢。
- 2026-05-03 该入口补齐 `axi_llc_axi_id_shape.v`、
  `axi_llc_dual_port_hazard_match.v`、`axi_llc_dual_port_slot_hazard.v` 等实际生产
  依赖后，在默认 timeout 内通过。

后续缺口：

- 该入口只覆盖 actual bridge 的 read-route/AR 归属，不覆盖 write route、
  `R/B` response 回收、data packing 或多 outstanding 时序状态。write route 已由
  `formal/dual_bridge_write_route` 单独覆盖基础 AW/W 归属，4B read `R` response 基础回收
  已由 `formal/dual_bridge_read_r_response` 单独覆盖，同构 2-beat DDR read 已由
  `formal/dual_bridge_ddr_multibeat_read` 单独覆盖。

### `formal/dual_bridge_read_r_response`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/dual_bridge_read_r_response/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_dual_port_route_shape.v`
- `rtl/src/axi_llc_dual_port_req_steer.v`
- `rtl/src/axi_llc_dual_port_issue_gate.v`
- `rtl/src/axi_llc_dual_port_hazard_scoreboard.v`
- `rtl/src/axi_llc_dual_port_resp_mux.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

目标覆盖范围：

- reset 后 4B cache read 被接受后，正确 DDR/MMIO 端口必须发出 `AR`。
- 按实际 `ARID` 在对应端口注入 `RVALID/RID/RDATA/RRESP/RLAST` 后，只有对应端口
  `RREADY` 拉高。
- `R` 被接收后，cache source 必须看到 `cache_resp_valid`。
- `cache_resp_id/cache_resp_code` 必须等于原始 cache request id 和外部 `RRESP`。
- 单 beat `RDATA` merge 必须把 DDR 64-bit 或 MMIO 32-bit 数据放入 64-bit
  `cache_resp_rdata`。

当前进展：

- 该入口使用实际生产 `axi_llc_axi_bridge.v` 和 `axi_llc_axi_bridge_dual.v` module
  body；wrapper 只做 tie-off、参数缩小、`R` 注入和输出观测。
- 2026-05-03 该入口在默认 timeout 内通过，并已纳入稳定 formal smoke。

后续缺口：

- 该入口只覆盖单笔 4B read 的 `R` 回收，不覆盖 DDR 64B multi-beat cacheline read
  或多 outstanding interleaving。DDR cacheline 2-beat read 的同构小参数覆盖由
  `formal/dual_bridge_ddr_multibeat_read` 补充，mode2 aligned read slice 由
  `formal/dual_bridge_mode2_aligned_read` 补充，多 outstanding issue 语义由
  `formal/dual_bridge_multi_read_outstanding` 及两个 read/write mixed outstanding 入口补充。

### `formal/dual_bridge_write_route`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/dual_bridge_write_route/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_dual_port_route_shape.v`
- `rtl/src/axi_llc_dual_port_req_steer.v`
- `rtl/src/axi_llc_dual_port_issue_gate.v`
- `rtl/src/axi_llc_dual_port_hazard_scoreboard.v`
- `rtl/src/axi_llc_dual_port_resp_mux.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

目标覆盖范围：

- reset 后 4B cache write request 若属于 supported DDR/MMIO 范围，必须被实际
  `axi_llc_axi_bridge_dual.v` 接受。
- supported DDR 4B write 被接受后，在 bounded timeframe 内只能在 DDR `AW/W` 口发出。
- supported MMIO 4B write 被接受后，在 bounded timeframe 内只能在 MMIO `AW/W` 口发出，
  且 `AWLEN=0`、`AWSIZE=2`、`WSTRB=4'hf`、`WLAST=1`。
- unsupported MMIO 大 write 不得被接受，也不得发出 DDR/MMIO `AW/W`。
- 小参数 DDR wrapper 使用 64-bit beat，因此 DDR 侧该 smoke 固定检查
  `AWLEN=0`、`AWSIZE=3`、`WSTRB=8'h0f`、`WLAST=1`。

当前进展：

- 该入口使用实际生产 `axi_llc_axi_bridge.v` 和 `axi_llc_axi_bridge_dual.v` module
  body；wrapper 只做 tie-off、参数缩小和输出观测。
- 生产 bridge pending 深度显式缩到 1/1，把 line/data/response 宽度缩到 64-bit，
  外部 AXI ID 宽度缩到 1-bit，以避免 write route smoke 被无关 outstanding/ID 状态拖慢。
- 2026-05-03 该入口在默认 timeout 内通过，并已纳入稳定 formal smoke。
- 2026-05-04 该入口扩展为同时覆盖 unsupported MMIO 大 write 的 ready=0 和
  下游 DDR/MMIO `AW/W` 不发射；目标运行结果 `0/66 failed`。

后续缺口：

- 该入口只覆盖基础 write route、unsupported MMIO 大 write 阻断和单 beat AW/W
  形状，不覆盖 `B` response 回收、
  多 beat DDR 64B cacheline write、data payload 内容或多 outstanding interleaving。
  `B` response 基础回收已由 `formal/dual_bridge_write_b_response` 单独覆盖，同构
  2-beat DDR write 由 `formal/dual_bridge_ddr_multibeat_write` 单独覆盖，多 outstanding
  issue 语义由 read-read 及 read/write mixed outstanding 入口补充。

### `formal/dual_bridge_write_b_response`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/dual_bridge_write_b_response/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_dual_port_route_shape.v`
- `rtl/src/axi_llc_dual_port_req_steer.v`
- `rtl/src/axi_llc_dual_port_issue_gate.v`
- `rtl/src/axi_llc_dual_port_hazard_scoreboard.v`
- `rtl/src/axi_llc_dual_port_resp_mux.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

目标覆盖范围：

- reset 后 4B cache write 被接受后，正确 DDR/MMIO 端口必须发出 `AW/W`。
- 按实际 `AWID` 在对应端口注入 `BVALID/BID/BRESP` 后，只有对应端口 `BREADY` 拉高。
- `B` 被接收后，cache source 必须看到 `cache_resp_valid`。
- `cache_resp_id/cache_resp_code` 必须等于原始 cache request id 和外部 `BRESP`。

当前进展：

- 该入口使用实际生产 `axi_llc_axi_bridge.v` 和 `axi_llc_axi_bridge_dual.v` module
  body；wrapper 只做 tie-off、参数缩小、`B` 注入和输出观测。
- 2026-05-03 该入口在默认 timeout 内通过，并已纳入稳定 formal smoke。

后续缺口：

- 该入口只覆盖单笔 4B write 的 `B` 回收，不覆盖 DDR 64B multi-beat write、
  data payload 内容或多 outstanding interleaving。DDR cacheline 2-beat write 的
  同构小参数覆盖由 `formal/dual_bridge_ddr_multibeat_write` 补充，read/write mixed
  outstanding 由两个 mixed outstanding 入口补充。

### `formal/dual_bridge_ddr_multibeat_read`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/dual_bridge_ddr_multibeat_read/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_dual_port_route_shape.v`
- `rtl/src/axi_llc_dual_port_req_steer.v`
- `rtl/src/axi_llc_dual_port_issue_gate.v`
- `rtl/src/axi_llc_dual_port_hazard_scoreboard.v`
- `rtl/src/axi_llc_dual_port_resp_mux.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

目标覆盖范围：

- 使用实际 bridge/dual-bridge module body，wrapper 只缩小参数、tie-off 和暴露观测信号。
- 16B line / 8B DDR beat 保持与生产 64B line / 32B beat 相同的 2-beat transaction
  结构。
- DDR cacheline read 被接受后必须发出 `ARLEN=1 / ARSIZE=3`。
- 第一拍 `R` 且 `RLAST=0` 时不得产生 cache response。
- 第二拍 `R` 且 `RLAST=1` 后必须返回原 request id、累计 response code，并按低/高
  64-bit 顺序合并两拍数据。

明确不覆盖：

- 该 smoke 不是生产 512-bit/256-bit 宽度实例；生产宽度仍由 VCS contract 覆盖，
  后续如有必要再补生产宽度 bounded formal。
- 不覆盖多 outstanding interleaving。

### `formal/dual_bridge_ddr_multibeat_write`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/dual_bridge_ddr_multibeat_write/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_dual_port_route_shape.v`
- `rtl/src/axi_llc_dual_port_req_steer.v`
- `rtl/src/axi_llc_dual_port_issue_gate.v`
- `rtl/src/axi_llc_dual_port_hazard_scoreboard.v`
- `rtl/src/axi_llc_dual_port_resp_mux.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

目标覆盖范围：

- 使用实际 bridge/dual-bridge module body，wrapper 只缩小参数、tie-off 和暴露观测信号。
- 16B line / 8B DDR beat 保持与生产 64B line / 32B beat 相同的 2-beat transaction
  结构。
- DDR cacheline write 被接受后必须发出 `AWLEN=1 / AWSIZE=3`。
- `W` 通道必须按低 64-bit、再高 64-bit 的顺序发出；第一拍 `WLAST=0`，第二拍
  `WLAST=1`，两拍 `WSTRB=8'hff`。

明确不覆盖：

- `B` response 回收由 `formal/dual_bridge_write_b_response` 覆盖。
- 该 smoke 不是生产 512-bit/256-bit 宽度实例；生产宽度仍由 VCS contract 覆盖，
  后续如有必要再补生产宽度 bounded formal。
- 不覆盖多 outstanding interleaving。

### `formal/dual_bridge_same_line_read_blocks_write`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/dual_bridge_same_line_read_blocks_write/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_dual_port_route_shape.v`
- `rtl/src/axi_llc_dual_port_req_steer.v`
- `rtl/src/axi_llc_dual_port_issue_gate.v`
- `rtl/src/axi_llc_dual_port_hazard_scoreboard.v`
- `rtl/src/axi_llc_dual_port_resp_mux.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

目标覆盖范围：

- 使用实际 bridge/dual-bridge module body，wrapper 只缩小参数、tie-off 和暴露观测信号。
- DDR read `AR` 发出后，在对应 `R last` 被外部 `RREADY` 接收前，同 line DDR write
  可以被内部接受，但不得对外发出 `AW/W`。
- 写请求被接受的同一组合周期也检查不能提前发出 `AW/W`。
- `R last` 被接收后，同 line write 必须继续发出 `AW/W`，且不误走 MMIO 口。

明确不覆盖：

- 不覆盖多 outstanding interleaving。

### `formal/dual_bridge_same_line_write_blocks_read`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/dual_bridge_same_line_write_blocks_read/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_dual_port_route_shape.v`
- `rtl/src/axi_llc_dual_port_req_steer.v`
- `rtl/src/axi_llc_dual_port_issue_gate.v`
- `rtl/src/axi_llc_dual_port_hazard_scoreboard.v`
- `rtl/src/axi_llc_dual_port_resp_mux.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

目标覆盖范围：

- 使用实际 bridge/dual-bridge module body，wrapper 只缩小参数、tie-off 和暴露观测信号。
- DDR write `AW/W` 发出后，在对应 `B` 被外部 `BREADY` 接收前，同 line DDR read
  可以被内部接受，但不得对外发出 `AR`。
- read 请求被接受的同一组合周期也检查不能提前发出 `AR`。
- `B` 被接收后，同 line read 必须继续发出 `AR`，且不误走 MMIO 口。

明确不覆盖：

- 不覆盖多 outstanding interleaving。

### `formal/dual_bridge_multi_read_outstanding`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/dual_bridge_multi_read_outstanding/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_dual_port_route_shape.v`
- `rtl/src/axi_llc_dual_port_req_steer.v`
- `rtl/src/axi_llc_dual_port_issue_gate.v`
- `rtl/src/axi_llc_dual_port_hazard_scoreboard.v`
- `rtl/src/axi_llc_dual_port_resp_mux.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

目标覆盖范围：

- 使用实际 bridge/dual-bridge module body，wrapper 只缩小参数、tie-off 和暴露观测信号。
- 第一笔 DDR read 未收到任何 `R` response 时，第二笔不同 line DDR read 仍可被接受。
- 两笔不同 line DDR read 都必须发出 `AR`，且不误走 MMIO 口。
- 两笔 outstanding read 使用不同 AXI ID。

明确不覆盖：

- 不覆盖 read/write 混合 outstanding interleaving；该项已由
  `formal/dual_bridge_read_then_write_outstanding` 和
  `formal/dual_bridge_write_then_read_outstanding` 分别覆盖两个方向。
- 不覆盖 out-of-order `R/B` response 回收。

### `formal/dual_bridge_read_then_write_outstanding`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/dual_bridge_read_then_write_outstanding/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_dual_port_route_shape.v`
- `rtl/src/axi_llc_dual_port_req_steer.v`
- `rtl/src/axi_llc_dual_port_issue_gate.v`
- `rtl/src/axi_llc_dual_port_hazard_scoreboard.v`
- `rtl/src/axi_llc_dual_port_resp_mux.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

目标覆盖范围：

- 使用实际 bridge/dual-bridge module body，wrapper 只缩小参数、tie-off 和暴露观测信号。
- 第一笔 DDR read 发出 `AR` 后不返回任何 `R`，因此 read 保持 outstanding。
- 第二笔不同 line DDR write 在该 read outstanding 期间仍可被接受。
- 第二笔 write 必须继续发出 DDR `AW/W`，且不误走 MMIO 口。

明确不覆盖：

- 不覆盖生产 64B/256-bit 宽度端到端实例。
- 不覆盖 response 回收；该入口只固定 mixed outstanding 的 issue/accept 语义。

### `formal/dual_bridge_write_then_read_outstanding`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/dual_bridge_write_then_read_outstanding/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_dual_port_route_shape.v`
- `rtl/src/axi_llc_dual_port_req_steer.v`
- `rtl/src/axi_llc_dual_port_issue_gate.v`
- `rtl/src/axi_llc_dual_port_hazard_scoreboard.v`
- `rtl/src/axi_llc_dual_port_resp_mux.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

目标覆盖范围：

- 使用实际 bridge/dual-bridge module body，wrapper 只缩小参数、tie-off 和暴露观测信号。
- 第一笔 DDR write 发出 `AW/W` 后不返回任何 `B`，因此 write 保持 outstanding。
- 第二笔不同 line DDR read 在该 write outstanding 期间仍可被接受。
- 第二笔 read 必须继续发出 DDR `AR`，且不误走 MMIO 口。

明确不覆盖：

- 不覆盖生产 64B/256-bit 宽度端到端实例。
- 不覆盖 response 回收；该入口只固定 mixed outstanding 的 issue/accept 语义。

### `formal/dual_bridge_mode2_aligned_write`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/dual_bridge_mode2_aligned_write/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_axi_write_pack.v`
- `rtl/src/axi_llc_dual_port_route_shape.v`
- `rtl/src/axi_llc_dual_port_req_steer.v`
- `rtl/src/axi_llc_dual_port_issue_gate.v`
- `rtl/src/axi_llc_dual_port_hazard_scoreboard.v`
- `rtl/src/axi_llc_dual_port_resp_mux.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

目标覆盖范围：

- 使用实际 bridge/dual-bridge module body，wrapper 只缩小参数、tie-off 和暴露观测信号。
- bypass mode2 DDR-aligned 4B write 从 `req_addr=issue_addr+2` 对齐到 8B DDR beat。
- `AWADDR=issue_addr`、`AWLEN=0`、`AWSIZE=3`，且不误走 MMIO。
- `WDATA/WSTRB` 必须按 `req_addr - issue_addr` 移位。
- DDR `B` 返回后，write response 回到 bypass source 的原 ID/code。

明确不覆盖：

- 该 smoke 使用 8B line / 8B DDR beat 小参数，不是生产 64B/32B 宽度实例。
- 不覆盖多 outstanding interleaving。

### `formal/dual_bridge_mode2_aligned_read`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/dual_bridge_mode2_aligned_read/run_hw_cbmc.sh
```

实际生产对象：

- `rtl/src/axi_llc_axi_bridge.v`
- `rtl/src/axi_llc_axi_read_pack.v`
- `rtl/src/axi_llc_dual_port_route_shape.v`
- `rtl/src/axi_llc_dual_port_req_steer.v`
- `rtl/src/axi_llc_dual_port_issue_gate.v`
- `rtl/src/axi_llc_dual_port_hazard_scoreboard.v`
- `rtl/src/axi_llc_dual_port_resp_mux.v`
- `rtl/src/axi_llc_axi_bridge_dual.v`

目标覆盖范围：

- 使用实际 bridge/dual-bridge module body，wrapper 只缩小参数、tie-off 和暴露观测信号。
- bypass mode2 DDR-aligned 4B read 从 `req_addr=issue_addr+2` 对齐到 8B DDR beat。
- `ARADDR=issue_addr`、`ARLEN=0`、`ARSIZE=3`，且不误走 MMIO。
- DDR `RDATA` 必须按 `req_addr - issue_addr` 截取后返回到 bypass response。
- DDR `R` 返回后，read response 回到 bypass source 的原 ID/code。

明确不覆盖：

- 该 smoke 使用 8B line / 8B DDR beat 小参数，不是生产 64B/32B 宽度实例。
- 不覆盖多 outstanding interleaving。

### `formal/dual_port_hazard_scoreboard`

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

运行：

```sh
formal/dual_port_hazard_scoreboard/run_hw_cbmc.sh
```

实际生产对象：

- RTL helper：`rtl/src/axi_llc_dual_port_hazard_scoreboard.v`
- per-entry match helper：`rtl/src/axi_llc_dual_port_hazard_match.v`
- slot hazard helper：`rtl/src/axi_llc_dual_port_slot_hazard.v`
- 消费者：`rtl/src/axi_llc_axi_bridge_dual.v`

目标覆盖范围：

- `AR` fire 后，同 port 同 line `AW` 看到 pending-read hazard。
- 匹配 `R last` fire 后，read hazard 释放。
- `AW` fire 后，同 port 同 line `AR` 看到 pending-write hazard。
- 匹配 `B` fire 后，write hazard 释放。
- DDR/MMIO 同拍各发一笔 `AR` 时，在小参数实例中占满 read scoreboard。

当前进展：

- 生产 RTL 已抽出该 helper，并由 `axi_llc_axi_bridge_dual.v` 实际使用；内部
  per-entry match 已继续抽成 `axi_llc_dual_port_hazard_match.v`，并由
  `formal/dual_port_hazard_match` 稳定覆盖；slot hazard 已继续抽成
  `axi_llc_dual_port_slot_hazard.v`，并由 `formal/dual_port_slot_hazard` 稳定覆盖。
- VCS 全量 RTL regression 已通过；2026-05-02 进一步新增并通过
  `tb_axi_llc_dual_port_hazard_scoreboard_contract`，用 directed VCS 直接覆盖生产
  scoreboard 的 entry 记录、错误 `RID/BID` 不释放、匹配 `R/B` 释放，以及 DDR/MMIO
  shared read/write slots 基本占用/释放。
- 2026-05-03 将生产 RTL 默认参数缩到
  `READ_HAZARD_COUNT=2 / WRITE_HAZARD_COUNT=2`，用于让 hw-cbmc 的未参数化
  generic 实例快速完成转换和求解。实际生产 bridge 实例仍在
  `axi_llc_axi_bridge_dual.v` 中显式覆盖为 64-entry，不受默认参数变化影响。
- 2026-05-03 该入口已在默认 `HW_CBMC_TIMEOUT_SEC=60` 内通过，并已纳入稳定
  formal smoke。

## 待验证

### P0：native bridge 读写发射合同

对象：

- `rtl/src/axi_llc_axi_bridge_dual.v`
- `rtl/src/axi_llc_axi_bridge.v`

目标：

- DDR/MMIO read route。
- DDR/MMIO write route。
- MMIO 4B-only 支持边界。
- DDR 64B cacheline -> 2 beat。
- MMIO 4B -> 1 beat / 32-bit。

推荐拆分：

- `dual_bridge_read_route`：read AR 已收敛并纳入稳定 regression。
- `dual_bridge_read_r_response`：4B read `R` response 回收已收敛并纳入稳定 regression。
- `dual_bridge_write_route`：4B write AW/W 和 unsupported MMIO 大 write 阻断已收敛并纳入稳定 regression。
- `dual_bridge_write_b_response`：4B write `B` response 回收已收敛并纳入稳定 regression。
- `dual_bridge_ddr_multibeat_read`：同构 2-beat DDR cacheline read 已收敛并纳入稳定 regression。
- `dual_bridge_ddr_multibeat_write`：同构 2-beat DDR cacheline write 已收敛并纳入稳定 regression。
- `dual_bridge_same_line_read_blocks_write`：同 line read pending 期间阻塞 write `AW/W`
  已收敛并纳入稳定 regression。
- `dual_bridge_same_line_write_blocks_read`：同 line write pending 期间阻塞 read `AR`
  已收敛并纳入稳定 regression。
- `dual_bridge_multi_read_outstanding`：不同 line DDR read-read 不串行化、并使用不同
  AXI ID，已收敛并纳入稳定 regression。
- `dual_bridge_read_then_write_outstanding`：read pending 期间不同 line DDR write
  不串行化，已收敛并纳入稳定 regression。
- `dual_bridge_write_then_read_outstanding`：write pending 期间不同 line DDR read
  不串行化，已收敛并纳入稳定 regression。
- `dual_bridge_mode2_aligned_write`：bypass mode2 aligned write 的 DDR beat 对齐、
  `WDATA/WSTRB` 移位和 `B` 回包已收敛并纳入稳定 regression。
- `dual_bridge_mode2_aligned_read`：bypass mode2 aligned read 的 DDR beat 对齐、
  `RDATA` 截取和 `R` 回包已收敛并纳入稳定 regression。
- `bridge_prod_width_cacheline_aw_shape`：actual bridge 生产宽度 64B cacheline
  write `AW` 地址通道形状已收敛并纳入稳定 regression。
- `bridge_prod_width_cacheline_ar_shape`：actual bridge 生产宽度 64B cacheline
  read `AR` 地址通道形状已收敛并纳入稳定 regression。
- `bridge_prod_width_cacheline_write_shape`：actual bridge 生产宽度 64B cacheline
  write 两拍 256-bit `W` payload、`WSTRB` 和 `WLAST` 已收敛并纳入稳定 regression。
- `bridge_prod_width_cacheline_read_response`：actual bridge 生产宽度 64B cacheline
  read 两拍 256-bit `R` payload 和 512-bit response 回收已收敛并纳入稳定 regression。
- `dual_bridge_prod_width_cacheline_ar_shape`：actual dual bridge 生产宽度 64B cacheline
  read 的 DDR `AR` 非空发射和地址通道形状已收敛并纳入稳定 regression。
- `dual_bridge_prod_width_cacheline_read_response`：actual dual bridge 生产宽度 cache
  source 64B cacheline read 的两拍 DDR `R` merge 和 512-bit response 回收已收敛并
  纳入稳定 regression。
- `dual_bridge_prod_width_bypass_cacheline_read_response`：actual dual bridge 生产宽度
  bypass source 64B cacheline read 的两拍 DDR `R` merge 和 512-bit response 回收已收敛
  并纳入稳定 regression。
- unsupported MMIO 大 read/write 不接受分别已由 `dual_bridge_read_route` 与
  `dual_bridge_write_route` 覆盖。

### P0：同 line AR/AW hazard gate

对象：

- `rtl/src/axi_llc_axi_bridge_dual.v`

目标：

- 已发 `AR` 在 `R last` 前阻塞同 line `AW`。
- 已发 `AW` 在 `B` 前阻塞同 line `AR`。
- 不同 line 不应被该 gate 串行化。
- 同周期同 line `AR/AW` 选择 read priority，不能同时发出。

建议：

- 先固定为小 ID/小 outstanding 的参数化实例，降低状态空间。
- 只暴露外部 AXI `AR/AW/R/B` 事件，不纳入完整 LLC core。

### P1：C++ reference 与 RTL route/shape EC 扩展

对象：

- C++：`include/axi_dual_port_route_shape.h`
- RTL：`rtl/src/axi_llc_dual_port_route_shape.v`

目标：

- `formal/axi_beat_shape` 已覆盖生产 C helper 与生产 RTL helper 的 beat shape 一致性。
- mode2 address alignment、write data/strobe shift、read slice 已经由生产 helper
  和 actual bridge 小参数 smoke 覆盖。
- helper 级生产宽度 64B/256-bit 复核已覆盖 write/read pack；actual bridge
  生产宽度 cacheline `AR/AW` 地址通道已覆盖；不同 line read-read 和 read/write mixed
  outstanding 已由 actual bridge 小参数 smoke 覆盖。后续仍需补 actual bridge
  生产宽度完整 payload/response 端到端 bounded smoke。

### P1：top-level native dual port 子系统

对象：

- `rtl/src/axi_llc_subsystem_dual.v`

目标：

- MMIO read/write direct bypass 已由 `formal/subsystem_dual_mmio_read_route` 和
  `formal/subsystem_dual_mmio_write_route` 覆盖；这两个入口同时覆盖 top 接受面对
  unsupported MMIO 大 read/write 的阻断。MMIO read/write response 端到端回收已由
  `formal/subsystem_dual_mmio_read_response` 和 `formal/subsystem_dual_mmio_write_response`
  覆盖。
- DDR direct read 与 MMIO direct write 的独立发射已由
  `formal/subsystem_dual_ddr_read_mmio_write_independent` 覆盖。
- MODE_OFF/direct-bypass 下 4B/8B DDR read issue shape、4B write beat 对齐和
  write data/strobe 移位已由 `formal/subsystem_dual_mode0_ddr_bypass_align` 覆盖；
  4B read response slice 已由 `formal/subsystem_dual_mode0_ddr_bypass_read_response`
  覆盖，8B read response 已由
  `formal/subsystem_dual_mode0_ddr_bypass_read_response_8b` 覆盖。
- DDR cache refill 与 MMIO read/write 的独立发射已由
  `formal/subsystem_dual_cache_refill_mmio_read_independent` 和
  `formal/subsystem_dual_cache_refill_mmio_write_independent` 覆盖。
- DDR cache refill 的 DDR `R` 接收与 upstream `read_resp_valid/id/data` 回收已由
  `formal/subsystem_dual_cache_refill_response` 覆盖。
- DDR cache fill 后同地址 read hit 且不再发第二个 DDR `AR` 已由
  `formal/subsystem_dual_cache_fill_hit_response` 覆盖。
- DDR bypass read/write same-line hazard 在顶层闭环。

建议：

- 不直接从完整 top 起步；先把 `axi_llc_subsystem_dual.v` 中的可组合/小状态边界抽出来。
- 每个 harness 只覆盖一个合同，例如 MMIO direct read、MMIO direct write、DDR bypass
  read/write hazard。

### P2：LLC core/cache 语义

对象：

- `rtl/src/axi_llc_subsystem_core.v`
- `rtl/src/llc_cache_ctrl.v`
- data/meta/valid/repl store wrappers

目标：

- read miss/refill/hit。
- write hit/miss/dirty victim。
- invalidate_line / invalidate_all。
- data/meta fixed latency 语义。

建议：

- 暂不直接用 hw-cbmc 绑定完整 core。
- 优先使用 VCS directed tests 保持覆盖；后续如要 formal，先抽小状态子模块或针对
  store wrapper 做局部 invariant。

## 非稳定实验入口

以下入口保留为定位材料，不计入 `formal/run_passed_hw_cbmc.sh`：

- `formal/subsystem_dual_mode0_ddr_bypass_cacheline_read_response`

  该入口直接实例化实际 `axi_llc_subsystem_dual.v`，覆盖目标是 MODE_OFF/direct-bypass
  64B read response 的 native top production-width 路径。当前失败模式是 300s timeout
  停在 `Type-checking Verilog::axi_llc_subsystem_dual`，尚未进入 harness/BMC；根因更像
  monolithic native top 拉入 compat/core/store/bridge 后超出 hw-cbmc frontend 展开成本。
  bridge-level `dual_bridge_prod_width_bypass_cacheline_read_response` 已覆盖 64B bypass
  read 的 DDR `AR`、两拍 `RREADY/RLAST`、512-bit merge 与 response 回收；VCS trace
  contract 也覆盖 actual C++ trace 到 actual RTL subsystem 的 MODE_OFF DDR 64B read/write。
  若后续必须补 native-top formal，应优先把 compat direct-bypass accept/slot/owner 逻辑拆成
  生产子模块再证明，不应把该 monolithic top 入口直接加入 stable manifest。

- `formal/subsystem_core_dirty_evict_writeback`

  该入口直接实例化实际 `axi_llc_subsystem_core.v`，覆盖目标是 core-alone dirty victim
  writeback。当前本地复跑 log
  `local_debug/hw_cbmc_subsystem_core_dirty_evict_writeback_current_20260505_173851.log`
  仍为 `VERIFICATION FAILED`；失败集中在 startup/reconfig idle 前置条件和 dirty-evict
  进度断言混在同一 harness，而不是生产 RTL 明确失败。startup/reconfig idle 已由
  `tb_axi_llc_subsystem_core_startup_idle_contract.v` 直接验证实际 core 并通过；dirty victim
  主链路已由 `cache_ctrl` 与 `subsystem_dual_cache_dirty_evict_*` 稳定 proof 分担覆盖。
  后续若继续推进 core-alone formal，应拆成“startup 已稳定后两路 dirty fill”、
  “dirty writeback issue”和“dirty writeback response”小入口。

## 暂不作为当前 hw-cbmc 目标

### 完整 `axi_llc_subsystem.v`

原因：

- 这是旧单 AXI 兼容顶层，当前双外部 AXI 需求的最终目标不是它。
- 可继续用 VCS regression 防回归，不优先投入 hw-cbmc。

### 完整 Linux/性能路径

原因：

- hw-cbmc 不适合直接证明 Linux boot、CoreMark/Dhrystone 性能不退化。
- 这部分继续依赖 simulator regression、IPC/周期数对比和 directed random tests。

### 完整 C++ `AXI_Interconnect` 类

原因：

- 当前 C++ reference 是周期级类模型，直接放入 hw-cbmc 状态空间过大。
- 应优先把硬件可实现的决策逻辑抽成小的生产 helper，再与 RTL helper 或 RTL 子模块
  做 EC。

## 后续推进顺序

1. 继续把实际 bridge 的 route/issue 组合层抽成生产子模块，但必须让生产 bridge 使用
   该子模块。
2. 继续拆 actual bridge 生产宽度 64B/256-bit 小范围 bounded 复核；当前 `AR/AW`
   地址通道与 cacheline write 的 `W` payload 窗口已收敛，后续优先补可控的 production
   width `R` merge/response 窗口或 mode2 read/write 地址通道窗口。
3. 继续在 `axi_llc_subsystem_dual.v` 层补小范围 harness；MMIO read/write direct route
   与 response 端到端回收、DDR-read/MMIO-write 独立发射、DDR cache-refill/MMIO-read
  和 DDR cache-refill/MMIO-write 独立发射、DDR cache-refill response 回收、cache
  fill 后同地址 hit、full-line write miss 后同地址 hit、dirty victim writeback DDR
  `AW/W` split proof、`B -> upstream write response` split proof 和 B 后新 dirty line
  read-hit proof 已通过；
  read miss/refill response、partial write miss/refill merge、partial write hit merge
  已先在生产 `llc_cache_ctrl.v` 边界收敛。下一步优先补完整 subsystem 的 production-width
  cacheable 场景，或实际 C++/RTL top EC。
