# RTL 验证计划

## 目标

当前验证优先覆盖已经落地的共享存储、mode 控制、mode2 直映窗口，以及 mode1 最小 cache 语义。
当前也覆盖“上游自定义接口 -> 单组 AXI4”的打包合同。

## P0 单元级

### `tb_llc_data_store.v`

- 同步 set-row 读
- 默认 `TABLE_READ_LATENCY=1` 的 `rd_en -> rd_valid` 时序
- 按 way mask 写
- 不同 way 更新互不破坏

### `tb_llc_meta_store.v`

- meta row 的按 way mask 写
- 写阶段 `busy`
- 读回一致

### `tb_llc_valid_ram.v`

- 掩码写
- 同一 set 多次更新
- 未更新位保持
- 通过显式写零替代整表 reset 假设

### `tb_llc_repl_ram.v`

- 默认 `TABLE_READ_LATENCY=1` 的 `rd_en -> rd_valid` 时序
- 写后读回一致

### `tb_llc_invalidate_sweep.v`

- `start -> busy -> done`
- 逐 set 顺序扫描
- `valid_wr_mask` 恒全 1
- `valid_wr_bits` 恒全 0
- busy 期间重复 `start` 被忽略

### `tb_llc_mapped_window_ctrl.v`

- window 内地址翻译
- `addr + total_size` 整体判窗
- direct set/way 计算
- invalid read 返回 0
- valid read 返回 resident line
- invalid partial write 走 zero-merge
- out-of-window 判定

### `tb_axi_reconfig_ctrl.v`

- `requested != active` 进入 `DRAIN`
- `global_quiescent` 后进入 `INV_SWEEP`
- `sweep_done` 后 `ACTIVATE`
- DRAIN 期间 target 收敛到最后一次请求值

## P1 子模块级 directed

### `tb_axi_llc_subsystem_directed.v`

覆盖：

- `mode=2` direct write/read
- `mode=2` 顺序读改写后再响应
- `mode=2` invalid read=0
- `mode=0` bypass 路由
- `mode=1` cache 路由
- `mode=2 -> mode=0 -> mode=2` 后旧 valid 被 sweep 清除

### `tb_axi_llc_subsystem_mode_contract.v`

覆盖：

- `mode=0/1/2/3` 基本路由合同
- `mode=2` invalid read 返回 0
- `mode=2` write/read 回读
- 切换后旧 mapped valid 不可见

### `tb_axi_llc_subsystem_handshake_contract.v`

覆盖：

- `up_req_ready` 回压
- `up_resp_ready=0` 时响应保持
- bypass 下游 `ready` 延迟
- cache 下游 `ready` 延迟
- `mode=1 + up_req_bypass=1`
- 读写属性透传
- 现有 simple responder 对 `id` 端口做透传，不因新增 `id` 接口破坏原合同

### `tb_axi_llc_subsystem_cache_contract.v`

覆盖：

- `mode=1` read miss -> refill -> respond
- 同地址第二次 read hit 不再发外部 `cache_req`
- write hit 更新 resident data
- full-line write miss 直接安装 dirty line
- partial write miss 先 refill 再 merge
- dirty victim refill + writeback
- simple memory model 回传 `cache_req_id`，避免新增 `id` 接口破坏 mode1 主路径

### `tb_axi_llc_subsystem_invalidate_line_contract.v`

覆盖：

- `mode=1` invalidate_line 后同地址重新 miss
- `mode=2` invalidate_line 为 no-op，同地址 direct-window resident data 保持可见
- LLC_OFF / window 外 no-op accept

### `tb_axi_llc_subsystem_size_contract.v`

覆盖：

- mode2 只有整体落窗才 direct
- 跨窗请求走 bypass
- `bypass_req_size` 透传
- `cache_req_size` 对 cache miss 为 line_bytes-1
- simple responder 回传 `cache_req_id / bypass_req_id`

### `tb_axi_llc_subsystem_read_slice_contract.v`

覆盖：

- `mode=1` read miss 的 refill 响应按地址 word offset 切片
- `mode=1` 同地址 read hit 继续按同一 word offset 切片
- `mode=1` unaligned write hit 在 line offset 处 merge，再按同一 word offset 回读
- `mode=2` direct-window resident read 按地址 word offset 切片
- `mode=2` unaligned partial write 在 line offset 处 merge，再按同一 word offset 回读
- 上述场景不允许退化成“无条件回整条 line”

### `tb_axi_llc_subsystem_bypass_contract.v`

覆盖：

- `mode=1 + up_req_bypass=1` 的 bypass read hit 不触发 lower bypass read，直接返回 resident 数据
- bypass read miss 只触发 lower bypass read，且不安装 resident
- bypass write hit 更新 resident shadow line、保持 clean、同时发 lower bypass write
- bypass write miss 只发 lower bypass write，不安装 resident

说明：

- 该 bench 使用 generic store 的层次化预装载来制造 resident 命中场景，因此只用于 `USE_SMIC12_STORES=0` 的合同验证。
- 这是对 bypass 合同的独立验证；如果 bypass 请求仍然被硬送到 lower bypass，或者 bypass write hit 不能完成 write-through 回包，该 bench 会直接报错。

### `tb_axi_llc_subsystem_axi_mode1_multiflow_contract.v`

覆盖：

- `mode=1` cache miss read 在途时，另一个 read master 的 bypass read 仍可继续下发第二笔 AXI AR
- bypass read 的上游 response 可先于 cache miss refill 返回
- `mode=1 bypass miss / write-through` 在 lower ready 被故意拉低时，后续 cache miss 仍可继续推进到
  cache lower 路径
- reset 后的独立场景中，cache miss read 在途时，另一个 write master 的 bypass write 仍可继续下发 AXI AW/W/B
- bypass write 的上游 response 可先于 cache miss refill 返回
- 两类 lower AXI 事务使用不同 `axi_id`

说明：

- 该 bench 直接在最终顶层 `axi_llc_subsystem.v` 上验证多 master 非单流合同。
- 旧的 `tb_axi_llc_subsystem_compat_contract.v` /
  `tb_axi_llc_subsystem_compat_read_queue_contract.v`
  假定 bypass lower id 直接等于 upstream id，且 queued bypass 不会在前一笔完成前继续发射；
  当前实现已不再满足这两条旧合同，因此改由本 bench 与下面的
  `tb_axi_llc_subsystem_compat_direct_bypass_contract.v` 共同替换。

### `tb_axi_llc_subsystem_axi_cache_multiread_contract.v`

覆盖：

- 不同 read master 的两笔 cacheable read miss 都能在 `mode=1` 下进入 core/read-miss slot
- lower AXI 在看到任何 `R` 之前，已经发出两笔对应的 `AR`
- 两笔 read response 最终都按原始 master / `req_id` 回到上游

### `tb_axi_llc_subsystem_axi_same_master_multiread_contract.v`

覆盖：

- `MASTER_DCACHE_R` 同一 master 的两笔 cacheable read miss 都能发出各自的 AXI `AR`
- lower `R` 返回后，两笔 response 会通过 compat 的 per-master read response queue 依次回到前台 response slot
- 同一 master 的 `req_id` 在 read response 回到上游时保持不变

### `tb_axi_llc_subsystem_compat_same_line_hol_contract.v`

覆盖：

- same-line blocked cacheable request 在接受面就会被 backpressure 挡住，
  不会先被 accept 到 compat FIFO
- 其它 master 上不相关 line 的 cacheable miss 仍可继续进入 core / lower
- same-line hazard 消失后，原先被挡住的请求仍会继续推进并正常回包

### `tb_axi_llc_subsystem_compat_read_accept_contract.v`

覆盖：

- same-line blocked cacheable read 不会被 compat 提前 accept
- 非 `MASTER_DCACHE_R` 的 master 在已有 core-path read 未退休时，不会继续 accept
  新的 cacheable read
- 非 `MASTER_DCACHE_R` 的 master 在已有 core-origin `mode=1 bypass read` 未退休时，也不会继续
  accept 第二笔 same-master bypass read
- 当该 master 的前台 read response slot / response queue 仍忙时，不会继续 accept
  新的 cacheable read

### `tb_axi_llc_subsystem_compat_direct_bypass_contract.v`

覆盖：

- direct-bypass read 的 `accepted / accepted_id`
- direct-bypass slot / response 槽在 flight 时，同一 master 的重复 `req_id` 被拒绝
- 当 master response 槽被占用时，lower bypass completion 会停在 `bypass_resp_ready=0`
- 槽位释放后，挂起 completion 能继续前进并回到正确 master / `req_id`

### `tb_axi_llc_subsystem_compat_reconfig_drain_contract.v`

覆盖：

- compat 层在 mode change / `invalidate_all` 时先排空本地 queue / inflight / response slot
- drain 期间旧模式下已经入队的请求仍按旧模式继续下发
- `invalidate_all_accepted` 只能在 compat 本地排空后出现

### `tb_axi_llc_subsystem_compat_invalidate_line_hazard_contract.v`

覆盖：

- `invalidate_line` 在 compat-local queue / inflight / response slot 未排空时，不能被 accepted
- 其中 same-line write inflight / queue / response slot 仍是显式覆盖的局部 hazard
- 只有 compat-local drain 完成后，`invalidate_line` 才允许继续前推

### `tb_axi_llc_subsystem_compat_pending_direct_maintenance_contract.v`

覆盖：

- `mode=1 bypass read miss` 已 handoff 到 compat pending-issue direct slot、但 lower 仍未 ready 时，
  unrelated `invalidate_line` 也不能被 accepted
- 同样条件下，`invalidate_all` 也不能被 accepted
- 只有 pending direct slot 退休后，maintenance 请求才允许继续前推

### `tb_axi_llc_subsystem_invalidate_line_read_hazard_contract.v`

覆盖：

- `invalidate_line` 在 same-line lookup 仍未结束时不能被 accepted
- `invalidate_line` 在 same-line read miss / refill 仍挂起时不能被 accepted
- `invalidate_line` 在 pending dirty victim 仍归属该 line 时不能被 accepted
- 上述 read-side hazard 清空后，`invalidate_line` 才允许被 accepted

### `tb_axi_llc_subsystem_compat_write_victim_multiflow_contract.v`

覆盖：

- dirty-victim 的 full-line cacheable write miss 会先发 victim writeback
- victim writeback 在途时，另一条不相关 cache miss 仍能继续进入 lower cache 路径
- write miss 与后续 read miss 最终都能正确回包

### `tb_axi_llc_subsystem_compat_victim_line_hazard_contract.v`

覆盖：

- pending dirty victim 仍归属某条 line 时，victim-line read 在 compat 接受面不会被提前吞入
- victim hazard 清空后，该 victim line 会重新变得可访问

### `tb_axi_llc_subsystem_read_master_timing_contract.v`

覆盖：

- `MASTER_DCACHE_R` 保留 same-cycle accept
- `MASTER_ICACHE` 仍保持 ready-first
- 上游 `accepted / accepted_id`、下游 AXI `AR`、以及最终 read response 的闭环一致性

### `tb_axi_llc_axi_dual_port_router_contract.v`

覆盖过渡 dual-port router shim：

- DDR 地址走 DDR AXI 口，保持 256-bit beat 和 multi-beat burst 形状。
- MMIO 地址走 MMIO AXI 口，并改写成 32-bit、1 beat。
- DDR/MMIO read response 可以乱序返回，仍按 AXI ID 回到单口 upstream。
- DDR/MMIO write response 分别按 `BID` 回到单口 upstream。

该 bench 的目标是先钉住双端口握手/ID 归属，不把 single-port router 作为最终性能路径。

### `tb_axi_llc_axi_bridge_dual_contract.v`

覆盖 native dual-port lower bridge wrapper：

- lower request 层直接按地址分流，不经过单 AXI 中间口。
- DDR cache read 与 MMIO bypass read 可以同周期都被接受，并分别发出 DDR/MMIO `AR`。
- DDR cache write 与 MMIO bypass write 可以同周期都被接受，并分别发出 DDR/MMIO `AW`；
  `AW` 接收后两侧 `W` 可独立推进。
- DDR 口保持 256-bit beat / multi-beat cacheline 形状。
- MMIO 口为 32-bit / 1 beat。
- 大于 4B 的 MMIO 请求会被 backpressure 挡住。
- MMIO write `B` 可先于 DDR write `B` 返回，并仍回到 bypass source；DDR write `B`
  随后回到 cache source。
- 同一 cache response source 同时有 DDR/MMIO read response 待回、且上游
  `cache_resp_ready=0` 时，外部 DDR/MMIO `R` 仍必须先被各自 bridge 用 `RREADY`
  接收并缓存；之后 response mux 再按 MMIO 优先级把缓存结果送回上游。
- 同一 cache response source 同时有 DDR/MMIO write `B` 待回、且上游
  `cache_resp_ready=0` 时，外部 DDR/MMIO `B` 仍必须先被各自 bridge 用 `BREADY`
  接收并缓存；之后 response mux 再按 MMIO 优先级把缓存结果送回上游。
- native bridge 外部 `AR/AW` 同 line hazard gate：读未返回前同 line 写不得发
  `AW/W`，写未完成前同 line 读不得发 `AR`，不同 line 不被该 gate 串行化。
- same-line 写已被 read hazard 挡住、且上游 read response ready 拉低时，DDR `R`
  两个 beat 仍必须被 `RREADY` 接收；该合同防止出现“等 response mux / 上游 ready /
  写侧完成后才接收外部 `R`”的依赖顺序。
- same-line 读已被 write hazard 挡住、且上游 write response ready 拉低时，DDR `B`
  仍必须被 `BREADY` 接收并缓存；bridge 层外部 `AR` issue hazard 在 `B` fire 后释放，
  不等待上游 write response 被消费。

当前该 bench 尚未覆盖全局 32-entry shared outstanding 计数；该预算由上游
compat/top 层约束。

### `tb_axi_llc_dual_port_hazard_scoreboard_contract.v`

覆盖生产 `axi_llc_dual_port_hazard_scoreboard.v` 的状态记录/释放合同：

- DDR `AR` fire 后，同 port 同 line `AW` 必须看到 pending-read hazard。
- 错误 `RID` 不释放 entry；匹配 `RID` 的 `R` fire 后释放 read hazard。
- DDR/MMIO read entries 可以同时占用 shared read scoreboard，并按 port/id 分别释放。
- DDR `AW` fire 后，同 port 同 line `AR` 必须看到 pending-write hazard。
- 错误 `BID` 不释放 entry；匹配 `BID` 的 `B` fire 后释放 write hazard。
- DDR/MMIO write entries 可以同时占用 shared write scoreboard，并按 port/id 分别释放。

该 bench 直接实例化生产 scoreboard 及其生产组合 helper
`axi_llc_dual_port_hazard_match.v` / `axi_llc_dual_port_slot_hazard.v`，用于补足
`hw-cbmc` 完整 scoreboard 状态 harness 暂时无法收敛的覆盖缺口。

### `tb_axi_llc_subsystem_dual_mmio_contract.v`

覆盖 native dual-port subsystem top：

- mode1 普通 MMIO 读写请求即使上游 `*_bypass=0`，也直接走 lower bypass 到 MMIO AXI 口。
- MMIO 读写不得驱动 DDR AXI 口。
- MMIO AXI 口保持 32-bit / 1 beat 形状。
- native dual top 的 hw-cbmc smoke 已覆盖 unsupported MMIO 大 read/write 在接受面被阻断，
  不会逃逸到 DDR/MMIO AXI。
- MMIO read/write response 必须回到原 upstream ID。
- DDR cache refill `AR` 被下游 backpressure 保持时，MMIO read/write 仍能在独立
  MMIO AXI 口发射和返回。
- DDR bypass read `AR` 已发且 `R` 未返回时，同 line DDR bypass write 不得提前发出
  `AW/W`；`R` 返回后该写事务必须继续完成并按原 upstream ID 回包。
- upstream read response ready 被拉低时，DDR `R` 仍必须先被 `RREADY` 接收并缓存；
  同 line 写只等待外部 `R` 接收完成，不得形成“等写 B 后才收 R”的依赖顺序。

### `tb_axi_llc_subsystem_dual_outstanding_contract.v`

覆盖 native dual-port subsystem top 在 `MODE_OFF` direct-bypass 场景下的 shared
outstanding 合同：

- DDR/MMIO 两个外部口共享 read outstanding 总预算 32。
- DDR/MMIO 两个外部口共享 write outstanding 总预算 32。
- read/write outstanding 预算相互独立，因此 read 满 32 时仍可接受 32 个 write，
  write 满 32 时也仍可接受 32 个 read。
- 第 33 个 read/write 必须被 backpressure 挡住。
- DDR read 与 MMIO read 同时在途时，MMIO `R` 可先返回并只唤醒对应 read master；
  DDR `R` 后返回时只唤醒原 DDR read master。
- DDR write 与 MMIO write 同时在途时，MMIO `B` 可先返回并只唤醒对应 write master；
  DDR `B` 后返回时只唤醒原 DDR write master。
- DDR/MMIO `R` 同时返回且上游 `read_resp_ready=0` 时，外部 `RREADY` 不被
  top/compat response stall 反压，两个 response 都能进入内部 buffer 并回到正确 master。
- DDR/MMIO `B` 同时返回且上游 `write_resp_ready=0` 时，外部 `BREADY` 不被
  top/compat response stall 反压，两个 response 都能进入内部 buffer 并回到正确 master。

### `tb_axi_llc_subsystem_axi_cache_refill_contract.v`

覆盖：

- 对外顶层 `axi_llc_subsystem.v` 的 `mode=1` cache refill 只使用单组 AXI4 读通道
- 64B refill 对应 `AR len=1 / size=5 / burst=INCR`
- 两个 32B `R` beat 组回 1 个 64B line
- cache refill 期间不得误触发 `AW/W/B`

## Formal Smoke

`hw-cbmc` 的总状态矩阵见 `formal/README_CN.md`。本节只保留 RTL 验证计划中的简要入口说明。

当前稳定入口：

```sh
formal/run_passed_hw_cbmc.sh
```

该入口只包含已通过并可完成的 formal smoke。2026-05-04 当前结果为
59 passed / 0 failed。

### `formal/axi_id_shape`

覆盖生产 `axi_llc_axi_id_shape.v`：

- 6-bit AXI ID zero-extend 到 8-bit 时不得截断高于 bit2 的 ID
- 3-bit AXI ID zero-extend 到 8-bit 时只保留低 3 bit
- 8-bit AXI ID resize 到 6-bit 时只保留低 6 bit
- 6-bit 到 6-bit 保持不变

检查对象是生产 C helper `include/axi_dual_port_route_shape.h` 与生产 RTL helper
`rtl/src/axi_llc_axi_id_shape.v`。该 RTL helper 已被生产
`axi_llc_axi_bridge_dual.v` 用于 DDR/MMIO lower ID 与 hazard scoreboard 的 ID
归一化边界。

运行方式：

```sh
formal/axi_id_shape/run_hw_cbmc.sh
```

### `formal/axi_beat_shape`

覆盖生产 `axi_llc_axi_beat_shape.v`：

- 32B beat 的 `total_size -> total_beats / axi_len / axi_size`
- 4B beat 的 `total_size -> total_beats / axi_len / axi_size`

该 helper 已被生产 `axi_llc_axi_bridge.v` 用于驱动 `AR/AW` 的 `len/size` 和记录
`total_beats`。

运行方式：

```sh
formal/axi_beat_shape/run_hw_cbmc.sh
```

### `formal/axi_mode2_shape`

覆盖生产 C helper 与生产 `axi_llc_axi_mode2_shape.v`：

- 判断 mode2 DDR-aligned 请求是否可以落在单个 AXI beat 内
- 单 beat 请求按 AXI data bytes 对齐，issue size 为 `AXI_DATA_BYTES-1`
- 跨 beat/line 请求按 cacheline bytes 对齐，issue size 为 `LINE_BYTES-1`

该 helper 已被生产 `axi_llc_axi_bridge.v` 和 `axi_llc_axi_issue_select.v` 用于
mode2 aligned issue addr/size 边界。

运行方式：

```sh
formal/axi_mode2_shape/run_hw_cbmc.sh
```

### `formal/axi_pending_scan`

覆盖生产 C helper 与生产 `axi_llc_axi_pending_scan.v`：

- pending slot 中首个空闲 entry 的优先级选择
- 当前已占用 AXI ID mask 下首个空闲 AXI ID 的选择
- 外部 `RID/BID` 到 pending slot 的首个匹配选择
- read complete queue 中首个 complete slot 的选择

该 helper 已被生产 `axi_llc_axi_bridge.v` 用于 read/write pending slot、AXI ID
分配、response match 和 completed read dequeue 的组合扫描边界。

运行方式：

```sh
formal/axi_pending_scan/run_hw_cbmc.sh
```

### `formal/axi_issue_select`

覆盖生产 C helper 与生产 `axi_llc_axi_issue_select.v`：

- queue 非空、slot valid、ready-to-issue 且未 done 时才允许 `AR/AW/W` 发射
- cache source 不允许产生 mode2 DDR aligned 地址修正
- bypass mode2 DDR aligned 时，issue addr/size 按 32B beat 或 64B line 对齐
- AXI ID、W beat index 和 total beats 来自当前 queue-head slot

该 helper 已被生产 `axi_llc_axi_bridge.v` 用于 read `AR`、write `AW` 和 write
`W` 的 queue-head issue select 边界。

运行方式：

```sh
formal/axi_issue_select/run_hw_cbmc.sh
```

### `formal/axi_fifo_ptr`

覆盖生产 C helper 与生产 `axi_llc_axi_fifo_ptr.v`：

- push-only 推进 tail，count 加 1
- pop-only 推进 head，count 减 1
- push/pop 同拍时 head/tail 同时推进，count 保持不变
- 无 push/pop 时 head/tail/count 保持不变

该 helper 已被生产 `axi_llc_axi_bridge.v` 用于 read issue、write AW、write W、
cache/bypass read response、cache/bypass write response FIFO 的 head/tail/count
更新边界。

运行方式：

```sh
formal/axi_fifo_ptr/run_hw_cbmc.sh
```

### `formal/axi_queue_ctrl`

覆盖生产 C helper 与生产 `axi_llc_axi_queue_ctrl.v`：

- issue queue / response queue 的 space 和 valid 判定
- AXI `AR/AW/W` handshake 判定
- read issue、write AW、write W queue 的 push/pop 判定
- `W` queue 只有在 `W` handshake 且 `WLAST` 同时成立时才 pop

该 helper 已被生产 `axi_llc_axi_bridge.v` 用于 request accept 资源反馈、issue
queue pop、response queue valid/space 和 queue push/pop 控制。

运行方式：

```sh
formal/axi_queue_ctrl/run_hw_cbmc.sh
```

### `formal/axi_write_pack`

覆盖生产 C helper 与生产 `axi_llc_axi_write_pack.v`：

- 普通 cacheline write 按 beat index 从 line data/strb 切出当前 AXI beat
- mode2 DDR-aligned write 按 `req_addr - issued_addr` 把窄写数据移入 256-bit beat
- `WSTRB` 与 `WDATA` 使用同一 byte 映射，不允许二次地址移位

该 helper 已被生产 `axi_llc_axi_bridge.v` 用于 AXI `W` channel data/strobe 打包。

运行方式：

```sh
formal/axi_write_pack/run_hw_cbmc.sh
```

### `formal/axi_write_pack_prod_width`

覆盖生产 `axi_llc_axi_write_pack.v` 在 64B line / 32B DDR beat 参数下的组合逻辑：

- 普通 cacheline write 在 `beat_idx=0/1` 时分别切出低/高 32B beat
- mode2 DDR-aligned write 在 `offset=0..28` 时生成 256-bit `WDATA` 和 32-bit `WSTRB`
- 该入口是 helper 级生产宽度 EC，不实例化完整 bridge 状态机

运行方式：

```sh
formal/axi_write_pack_prod_width/run_hw_cbmc.sh
```

### `formal/axi_read_pack`

覆盖生产 C helper 与生产 `axi_llc_axi_read_pack.v`：

- 普通 read 按 beat index 把 AXI `RDATA` 合并到 read response buffer
- 非 mode2 aligned read 的最终返回数据等于合并后的 buffer
- mode2 DDR-aligned read 按 `req_addr - issued_addr` 从合并 buffer 中提取返回窗口

该 helper 已被生产 `axi_llc_axi_bridge.v` 用于 AXI `R` channel beat merge 和
mode2 aligned read extract。

运行方式：

```sh
formal/axi_read_pack/run_hw_cbmc.sh
```

### `formal/axi_read_pack_prod_width`

覆盖生产 `axi_llc_axi_read_pack.v` 在 64B response / 32B DDR beat 参数下的组合逻辑：

- 普通 cacheline read 在 `beat_idx=0/1` 时分别合并低/高 32B beat
- mode2 DDR-aligned read 在 `offset=0..28` 时从 merged buffer 做 64B 字节切片
- 该入口是 helper 级生产宽度检查，不实例化完整 bridge 状态机

运行方式：

```sh
formal/axi_read_pack_prod_width/run_hw_cbmc.sh
```

### `formal/bridge_prod_width_cacheline_aw_shape`

直接实例化生产 `axi_llc_axi_bridge.v`，在 64B line / 32B DDR beat / 64B response
buffer 参数下覆盖 64B cacheline write 的 `AWADDR/AWLEN/AWSIZE/AWBURST`。

运行方式：

```sh
formal/bridge_prod_width_cacheline_aw_shape/run_hw_cbmc.sh
```

### `formal/bridge_prod_width_cacheline_ar_shape`

直接实例化生产 `axi_llc_axi_bridge.v`，在 64B line / 32B DDR beat / 64B response
buffer 参数下覆盖 64B cacheline read 的 `ARADDR/ARLEN/ARSIZE/ARBURST`。

运行方式：

```sh
formal/bridge_prod_width_cacheline_ar_shape/run_hw_cbmc.sh
```

### `formal/bridge_prod_width_cacheline_write_shape`

直接实例化生产 `axi_llc_axi_bridge.v`，在 64B line / 32B DDR beat / 64B response
buffer 参数下覆盖 64B cacheline write 的两拍 256-bit `W` payload、`WSTRB` 和
`WLAST`。

运行方式：

```sh
formal/bridge_prod_width_cacheline_write_shape/run_hw_cbmc.sh
```

### `formal/bridge_prod_width_cacheline_read_response`

直接实例化生产 `axi_llc_axi_bridge.v`，在 64B line / 32B DDR beat / 64B response
buffer 参数下覆盖 64B cacheline read 的两拍 256-bit `R` payload、`RREADY`、`RLAST`
前不回包和 512-bit response id/code/data 回收。

运行方式：

```sh
formal/bridge_prod_width_cacheline_read_response/run_hw_cbmc.sh
```

### `formal/axi_read_resp_ctrl`

覆盖生产 C helper 与生产 `axi_llc_axi_read_resp_ctrl.v`：

- 匹配读 pending slot 且 beat 计数到达事务 beat 数时声明 `rd_last_beat`
- AXI `RLAST` 可以提前声明读事务最后一个 beat
- 当前 `RRESP` 非 OKAY 时优先记录当前错误码，否则保留历史错误码
- 未匹配读 pending slot 时不会声明读事务完成

该 helper 已被生产 `axi_llc_axi_bridge.v` 用于 AXI `R` response 接收后的
last-beat 判定和 response code 累计。

运行方式：

```sh
formal/axi_read_resp_ctrl/run_hw_cbmc.sh
```

### `formal/axi_req_accept`

覆盖生产 C helper 与生产 `axi_llc_axi_req_accept.v`：

- cache source 对 bypass source 的接受优先级
- read request 只有在 read pending slot、AXI read ID 和 read issue queue 都有资源时接受
- write request 只有在 write pending slot、AXI write ID、AW issue queue 和 W issue queue
  都有资源时接受
- 接受后记录的 slot、AXI ID 和 total beats 来自对应 read/write 资源与对应 source

该 helper 已被生产 `axi_llc_axi_bridge.v` 用于 source-side request accept 边界。
它把原先 full bridge 中较难直接形式化的接受组合逻辑拆成可快速求解的生产子模块。

运行方式：

```sh
formal/axi_req_accept/run_hw_cbmc.sh
```

### `formal/axi_resp_accept`

覆盖生产 C helper 与生产 `axi_llc_axi_resp_accept.v`：

- `RREADY` 只取决于是否找到匹配 read slot，不被 upstream cache/bypass response
  ready 回压
- `rd_resp_accept` 等价于 `RVALID && read slot match`
- `BREADY` 需要匹配 write slot 且对应 source-local write response queue 有空间
- `wr_resp_accept` 等价于 `BVALID && BREADY`

该 helper 已被生产 `axi_llc_axi_bridge.v` 用于外部 AXI `R/B` 接收边界。它与
VCS 中的 response-stall contract 共同覆盖“不允许外部 `R` 因上游 response stall
被回压”的需求；`B` 通道仍保留 response queue 空间保护。

运行方式：

```sh
formal/axi_resp_accept/run_hw_cbmc.sh
```

### `formal/axi_source_resp_mux`

覆盖生产 C helper 与生产 `axi_llc_axi_source_resp_mux.v`：

- read response valid 时优先返回 read response
- 没有 read response 且 write response valid 时返回 write response，rdata 为 0
- `rd_pop` / `wr_pop` 只在对应 source 的 `resp_ready` 允许时产生
- 同一拍不会同时 pop read response 和 write response

该 helper 已被生产 `axi_llc_axi_bridge.v` 用于 cache/bypass source-local response
返回和 response queue pop 边界。

运行方式：

```sh
formal/axi_source_resp_mux/run_hw_cbmc.sh
```

### `formal/axi_resp_route`

覆盖生产 C helper 与生产 `axi_llc_axi_resp_route.v`：

- completed read 根据 pending slot owner 进入 cache/bypass read response queue
- read response queue 没有空间时不得 dequeue completed read slot
- write `B` response 根据 pending slot owner 进入 cache/bypass write response queue
- `wr_match_rsp_space` 选择对应 owner 的 write response queue 空间，并反馈到
  `axi_llc_axi_resp_accept.v` 的 `BREADY` 门控

该 helper 已被生产 `axi_llc_axi_bridge.v` 用于 response enqueue route 和 write
response queue 空间门控边界。

运行方式：

```sh
formal/axi_resp_route/run_hw_cbmc.sh
```

### `formal/dual_port_req_steer`

覆盖生产 C helper 与生产 `axi_llc_dual_port_req_steer.v`：

- DDR 请求只驱动 DDR valid，并从 DDR ready 回传 upstream ready
- supported MMIO 请求只驱动 MMIO valid，并从 MMIO ready 回传 upstream ready
- unsupported MMIO 请求不驱动下游 valid，且 upstream ready 为 0
- 单个请求不会同时驱动 DDR/MMIO 两个下游 valid

该 helper 已被生产 `axi_llc_axi_bridge_dual.v` 用于 cache/bypass 两路 lower request
接受面。

运行方式：

```sh
formal/dual_port_req_steer/run_hw_cbmc.sh
```

### `formal/dual_port_issue_gate`

覆盖生产 C helper 与生产 `axi_llc_dual_port_issue_gate.v`：

- `AR` 存在 slot/pending-write hazard 时不能发出
- `AW` 存在 slot/pending-read hazard 时不能发出
- 同周期同 line 的 `AR/AW` 同时可发时，`AR` 优先，`AW` 被屏蔽
- 不同 line 时，只要没有已有 hazard，`AR/AW` 可在同周期各自发出

该 helper 已被生产 `axi_llc_axi_bridge_dual.v` 用于 DDR/MMIO 两个外部口的 issue
边界。

运行方式：

```sh
formal/dual_port_issue_gate/run_hw_cbmc.sh
```

### `formal/dual_port_hazard_match`

覆盖生产 C helper 与生产 `axi_llc_dual_port_hazard_match.v`：

- DDR line/id match 只对 DDR port entry 生效
- MMIO line/id match 只对 MMIO port entry 生效
- invalid entry 不产生任何 match

该 helper 已被生产 `axi_llc_dual_port_hazard_scoreboard.v` 用于每个 scoreboard
entry 的 line/id 比较，是同 line `AR/AW` hazard 状态逻辑的组合基元。

运行方式：

```sh
formal/dual_port_hazard_match/run_hw_cbmc.sh
```

### `formal/dual_port_slot_hazard`

覆盖生产 C helper 与生产 `axi_llc_dual_port_slot_hazard.v`：

- primary port 没有第一个空槽时必须报告 slot hazard
- secondary port 只有在没有第一个空槽，或 primary port 本周期实际 fire 且没有第二个空槽时，才报告 slot hazard
- primary port 只是 valid 但没有 fire 时，不得因为预测占槽而阻塞 secondary port

该 helper 已被生产 `axi_llc_dual_port_hazard_scoreboard.v` 用于 read/write 两组
scoreboard 的 DDR/MMIO shared slot hazard 计算。

运行方式：

```sh
formal/dual_port_slot_hazard/run_hw_cbmc.sh
```

### `formal/dual_port_resp_mux`

覆盖生产 C helper 与生产 `axi_llc_dual_port_resp_mux.v`：

- MMIO response valid 时优先选择 MMIO
- MMIO 不 valid 时选择 DDR
- selected port 才收到 upstream `resp_ready`
- non-selected port 被 backpressure

该 helper 已被生产 `axi_llc_axi_bridge_dual.v` 用于 cache/bypass 两路 response 合并。

运行方式：

```sh
formal/dual_port_resp_mux/run_hw_cbmc.sh
```

### `formal/dual_port_hazard_scoreboard`

目标覆盖生产 `axi_llc_dual_port_hazard_scoreboard.v`：

- `AR` fire 后，同 port 同 line `AW` 看到 pending-read hazard
- 匹配 `R last` fire 后，read hazard 释放
- `AW` fire 后，同 port 同 line `AR` 看到 pending-write hazard
- 匹配 `B` fire 后，write hazard 释放
- DDR/MMIO 同拍各发一笔 `AR` 时，在小参数实例中占满 read scoreboard

该 helper 已被生产 `axi_llc_axi_bridge_dual.v` 用于同 line `AR/AW` hazard 状态记录。
scoreboard 内部 per-entry match 已抽成生产 `axi_llc_dual_port_hazard_match.v`，并由
`formal/dual_port_hazard_match` 稳定覆盖；slot hazard 已抽成生产
`axi_llc_dual_port_slot_hazard.v`，并由 `formal/dual_port_slot_hazard` 稳定覆盖。

当前状态：

- 生产 RTL 已接入，VCS 全量 RTL regression 已通过。
- 2026-05-02 已新增并通过
  `tb_axi_llc_dual_port_hazard_scoreboard_contract` VCS directed test，直接覆盖生产
  scoreboard 的 `AR/AW` 记录、错误 `RID/BID` 不释放、匹配 `R/B` 释放，以及
  DDR/MMIO shared slots 的基本占用/释放。
- 2026-05-03 将生产 RTL 默认参数缩到
  `READ_HAZARD_COUNT=2 / WRITE_HAZARD_COUNT=2`，用于让 hw-cbmc 的未参数化
  generic 实例快速完成转换和求解。实际生产 bridge 实例仍在
  `axi_llc_axi_bridge_dual.v` 中显式覆盖为 64-entry，不受默认参数变化影响。
- 2026-05-03 该入口已在默认 `HW_CBMC_TIMEOUT_SEC=60` 内通过，并已纳入稳定
  formal regression。

运行方式：

```sh
formal/dual_port_hazard_scoreboard/run_hw_cbmc.sh
```

### `formal/dual_port_route_shape`

覆盖：

- `addr >= 0x4000_0000` 走 DDR port，低地址走 MMIO port
- MMIO 只支持 4B 请求
- DDR/MMIO helper 输出的 `axi_len/axi_size` 与生产 C helper 一致

检查对象是生产 C helper `include/axi_dual_port_route_shape.h` 与生产 RTL 组合
helper `axi_llc_dual_port_route_shape.v`，不是独立复制的 formal-only spec。
实际 AXI channel 形状仍由直接绑定 bridge/top 的 sequential smoke 覆盖。

运行方式：

```sh
formal/dual_port_route_shape/run_hw_cbmc.sh
```

当前这是 production helper smoke，用于固定 `hw-cbmc` 工具链与 harness 写法；后续
需要把 bounded sequential bridge harness 接入同一目录结构。

### `formal/dual_bridge_read_route`

直接实例化生产 `axi_llc_axi_bridge_dual.v` / `axi_llc_axi_bridge.v`，目标是覆盖 reset
后 cache read 被接受后一拍的 DDR/MMIO `AR` 归属，以及 unsupported MMIO 大 read
不能被接受。

当前状态：

- 该入口已通过，并已纳入 `formal/run_passed_hw_cbmc.sh`。
- `run_hw_cbmc.sh` 会生成覆盖小参数宏后的 preprocess RTL，module body 仍来自生产 RTL。
- 首轮实验暴露了 `axi_llc_axi_bridge.v` 中 variable indexed part-select 对 hw-cbmc
  前端不友好；生产 RTL 已改写为 shift/mask byte helper，VCS 全量 RTL 回归已通过。
- 2026-04-29 使用 `HW_CBMC_TIMEOUT_SEC=60` 重新探测时，脚本已补齐 req accept /
  resp accept / req steer / issue gate / hazard scoreboard / resp mux 生产依赖，但仍在实际
  `axi_llc_axi_bridge` type-check/转换阶段超时，未进入求解。
- 2026-05-02 短 timeout 探测已通过拆分生产 bridge 的组合/时序 loop index 清除
  hw-cbmc conflicting assignment type 转换错误；当时仍在实际 bridge 转换阶段超时。
- 2026-05-03 后续短 timeout 探测已补齐 `axi_llc_axi_pending_scan.v` 与
  `axi_llc_axi_issue_select.v` / `axi_llc_axi_fifo_ptr.v` /
  `axi_llc_axi_mode2_shape.v` /
  `axi_llc_axi_queue_ctrl.v` /
  `axi_llc_axi_write_pack.v` /
  `axi_llc_axi_read_pack.v` /
  `axi_llc_axi_read_resp_ctrl.v` /
  `axi_llc_axi_resp_route.v` /
  `axi_llc_axi_source_resp_mux.v` 依赖；当时完整 bridge 仍在实际 bridge 转换阶段超时。
- 2026-05-03 继续把生产 bridge pending 深度改成可参数化默认值。生产默认仍为
  32/32；该 formal top 显式缩到 1/1，并把 line/data/response 宽度缩到
  64-bit，小参数外部 AXI ID 宽度缩到 1-bit。补齐 `axi_llc_axi_id_shape.v`、
  `axi_llc_dual_port_hazard_match.v`、`axi_llc_dual_port_slot_hazard.v` 依赖并按
  hw-cbmc timeframe 语义在保持 request valid 的帧采样 AR 后，该入口在默认 timeout
  内通过。
- 该入口只覆盖 actual bridge read-route/AR 归属；write route 已由
  `formal/dual_bridge_write_route` 单独覆盖基础 AW/W 归属，4B write `B` response
  基础回收已由 `formal/dual_bridge_write_b_response` 覆盖，4B read `R` response
  基础回收已由 `formal/dual_bridge_read_r_response` 覆盖。同构 2-beat DDR
  cacheline read/write 已由 `formal/dual_bridge_ddr_multibeat_read` 和
  `formal/dual_bridge_ddr_multibeat_write` 覆盖；mode2 aligned data packing/slicing
  已由 `formal/dual_bridge_mode2_aligned_write` 和
  `formal/dual_bridge_mode2_aligned_read` 覆盖；生产宽度 write/read pack 已由
  `formal/axi_write_pack_prod_width` 和 `formal/axi_read_pack_prod_width` 覆盖；
  actual bridge 生产宽度 cacheline `AR/AW` 地址通道已由
  `formal/bridge_prod_width_cacheline_ar_shape` 和
  `formal/bridge_prod_width_cacheline_aw_shape` 覆盖，生产宽度 cacheline write 的
  两拍 256-bit `W` payload 已由 `formal/bridge_prod_width_cacheline_write_shape`
  覆盖，生产宽度 cacheline read 的两拍 256-bit `R` payload 和 512-bit response
  回收已由 `formal/bridge_prod_width_cacheline_read_response` 覆盖；
  不同 line read-read outstanding 已由 `formal/dual_bridge_multi_read_outstanding`
  覆盖，read/write 混合多 outstanding 已由
  `formal/dual_bridge_read_then_write_outstanding` 和
  `formal/dual_bridge_write_then_read_outstanding` 覆盖。same-line read pending 期间
  阻塞后续 write `AW/W` 已由 `formal/dual_bridge_same_line_read_blocks_write` 覆盖；
  same-line write pending 期间阻塞后续 read `AR` 已由
  `formal/dual_bridge_same_line_write_blocks_read` 覆盖。

### `formal/dual_bridge_read_r_response`

直接实例化生产 `axi_llc_axi_bridge_dual.v` / `axi_llc_axi_bridge.v`，目标是覆盖 4B
cache read 的外部 `R` response 接收与 cache source response 回收。

当前状态：

- 该入口已通过，并已纳入 `formal/run_passed_hw_cbmc.sh`。
- `run_hw_cbmc.sh` 会生成覆盖小参数宏后的 preprocess RTL，module body 仍来自生产 RTL。
- 小参数实例把 DDR beat 缩到 64-bit、pending 深度缩到 1/1、外部 AXI ID 缩到 1-bit。
- 覆盖对应 DDR/MMIO 端口 `RVALID/RID/RDATA/RRESP/RLAST` 注入后，只有正确端口
  `RREADY` 拉高；`cache_resp_id/cache_resp_code/cache_resp_rdata` 回到原始 request id、
  外部 `RRESP` 和单 beat `RDATA` merge 结果。
- 该入口只覆盖单笔 4B read 的 `R` 回收；DDR 64B multi-beat read、mode2 aligned read
  slice 和多 outstanding interleaving 由其它独立入口补充；同构 2-beat DDR cacheline read
  已由 `formal/dual_bridge_ddr_multibeat_read` 补充，read/write mixed outstanding 已由
  `formal/dual_bridge_read_then_write_outstanding` 和
  `formal/dual_bridge_write_then_read_outstanding` 补充。

### `formal/dual_bridge_write_route`

直接实例化生产 `axi_llc_axi_bridge_dual.v` / `axi_llc_axi_bridge.v`，目标是覆盖 reset
后 4B cache write 被接受后的 DDR/MMIO `AW/W` 归属、基础 channel 形状，以及
unsupported MMIO 大 write 不被接受且不逃逸到下游 AXI 口。

当前状态：

- 该入口已通过，并已纳入 `formal/run_passed_hw_cbmc.sh`。
- `run_hw_cbmc.sh` 会生成覆盖小参数宏后的 preprocess RTL，module body 仍来自生产 RTL。
- 小参数实例把 DDR beat 缩到 64-bit、pending 深度缩到 1/1、外部 AXI ID 缩到 1-bit。
- 覆盖 DDR 地址只发 DDR `AW/W`，MMIO 地址只发 MMIO `AW/W`；MMIO 侧固定
  `AWLEN=0 / AWSIZE=2 / WSTRB=4'hf / WLAST=1`。
- 2026-05-04 已补 unsupported MMIO 大 write：upstream ready 必须为 0，且 DDR/MMIO
  `AW/W` 均不得发射。
- 该入口只覆盖 4B 单 beat write route 和 unsupported MMIO 大 write 阻断；`B`
  response 基础回收已由
  `formal/dual_bridge_write_b_response` 覆盖，同构 2-beat DDR cacheline write 已由
  `formal/dual_bridge_ddr_multibeat_write` 补充；生产宽度复核和多 outstanding
  interleaving 仍需后续补充。

### `formal/dual_bridge_write_b_response`

直接实例化生产 `axi_llc_axi_bridge_dual.v` / `axi_llc_axi_bridge.v`，目标是覆盖 4B
cache write 的外部 `B` response 接收与 cache source response 回收。

当前状态：

- 该入口已通过，并已纳入 `formal/run_passed_hw_cbmc.sh`。
- `run_hw_cbmc.sh` 会生成覆盖小参数宏后的 preprocess RTL，module body 仍来自生产 RTL。
- 小参数实例把 DDR beat 缩到 64-bit、pending 深度缩到 1/1、外部 AXI ID 缩到 1-bit。
- 覆盖对应 DDR/MMIO 端口 `BVALID/BID/BRESP` 注入后，只有正确端口 `BREADY` 拉高；
  `cache_resp_id/cache_resp_code` 回到原始 cache request id 与外部 `BRESP`。
- 该入口只覆盖单笔 4B write 的 `B` 回收；多 beat DDR 64B write、data payload 内容和
  多 outstanding interleaving 由其它独立入口补充；同构 2-beat DDR cacheline write 已由
  `formal/dual_bridge_ddr_multibeat_write` 补充，read/write mixed outstanding 已由
  `formal/dual_bridge_read_then_write_outstanding` 和
  `formal/dual_bridge_write_then_read_outstanding` 补充。

### `tb_axi_llc_subsystem_axi_bypass_read_contract.v`

覆盖：

- bypass 4B read 在对外顶层只发 single-beat `AR`
- `arlen=0 / arsize=5 / arburst=INCR`
- 只消费 1 个 `R` beat
- 上游 `read_resp_id` 保持原始事务 `id`
- `RDATA` 仍按单个 32B beat 返回，使用方只消费低几个字节

### `tb_axi_llc_subsystem_axi_bypass_write_contract.v`

覆盖：

- bypass 4B write 必须经过单组 AXI 的 `AW/W/B`
- `awlen=0 / awsize=5 / awburst=INCR`
- `W` 数据与 `WSTRB` 采用低地址连续打包，不再按地址低位二次移位
- `B` 回来后生成 write response

### `tb_axi_llc_subsystem_axi_mode2_aligned_read_contract.v`

覆盖：

- `mode=2` 窗口外非 MMIO 4B read 会发 32B 对齐单 beat `AR`
- `mode=2` 窗口外跨 32B 的 8B read 会退回 64B line / `ARLEN=1`
- 对齐读取后的返回数据会按原始地址低位重新抽取到低字节
- 起始地址命中 MMIO 区间的请求保持原始 `ARADDR`
- 起始地址命中 MMIO、但请求尾部越过 MMIO 末端时，仍保持 MMIO passthrough
- 当前 MMIO 分类规则按请求起始地址冻结，不支持跨 MMIO / 非 MMIO 边界的单次请求

### `tb_axi_llc_subsystem_axi_mode2_aligned_write_contract.v`

覆盖：

- `mode=2` 窗口外非 MMIO 4B write 会发 32B 对齐单 beat `AW/W`
- `mode=2` 窗口外跨 32B 的 8B write 会退回 64B line / 2 beat
- 对齐写的 `WDATA/WSTRB` 会按原始地址低位平移
- 起始地址命中 MMIO 区间的请求保持原始 `AWADDR`
- 起始地址命中 MMIO、但请求尾部越过 MMIO 末端时，仍保持 MMIO passthrough
- 当前 MMIO 分类规则按请求起始地址冻结，不支持跨 MMIO / 非 MMIO 边界的单次请求

### `tb_axi_llc_subsystem_mode1_bypass_resident_contract.v`

覆盖：

- `mode=1 bypass read hit` 必须返回 resident 数据，且不触发 lower AXI `AR`
- `mode=1 bypass write hit` 必须 shadow-update resident，并继续 lower write-through
- dirty resident 上的 `mode=1 bypass read` 必须优先返回 resident 数据

### `tb_axi_llc_subsystem_axi_mode1_multiflow_contract.v`

当前除“cache 先发，bypass 后发”之外，还覆盖反向顺序：

- bypass read miss 已在 lower flight 时，后续 cache miss 仍能继续发 AXI `AR`
- bypass write-through 已在 lower flight 时，后续 cache miss 仍能继续发 AXI `AR`

### `tb_axi_llc_subsystem_invalidate_all_contract.v`

覆盖：

- mode1 下 dirty line 存在时外部 `invalidate_all` 不会被接受，也不会主动 flush
- mode1 下 clean resident 状态时，`invalidate_all` 经过 drain 后触发 valid sweep
- mode1 invalidate 后同地址重新 miss
- mode2 下外部 `invalidate_all` 后 direct-window resident data 不再可见
- mode 切换与 `invalidate_all` 同时出现时只做一轮维护流程
- clean reread 过程继续通过 `id` 接口回传响应

### `tb_axi_llc_subsystem_id_contract.v`

覆盖：

- cache / direct / bypass 三条路径的 request id 下传与 response id 回传
- invalidate_all 期间不误接收新 id
- mode1 lower-memory request id 的基本合同
  当前 cache miss 验证的是内部 line-memory mem-id，不要求等于上游 `up_req_id`

### `tb_llc_smic12_store_contract.v`

覆盖：

- `USE_SMIC12=1` 下 data/meta shared store 的读写往返
- 显式通用数组实现与默认 SMIC12 宏封装实现的接口合同一致
- 显式带入外部 `.mv` 的功能仿真 smoke

## 当前限制

- 当前 bench 仍以 directed contract 为主，更大规模的 randomized / long-run backpressure 还没有接入。
- lower AXI 多 outstanding / remap 已经有独立 bridge-local contract bench；当前验证重点转到：
  - bridge 的 `req_id -> axi_id -> req_id` 回路由
  - write `axi_id` 在 `B` 后即可复用
  - top/compat 侧旧合同在新 bridge 下不回归
- 当前已在 `eda-10` 上确认 VCS 可用，并实际跑通：
  - `tb_llc_data_store`
  - `tb_llc_meta_store`
  - `tb_llc_valid_ram`
  - `tb_llc_repl_ram`
  - `tb_llc_invalidate_sweep`
  - `tb_llc_mapped_window_ctrl`
  - `tb_axi_reconfig_ctrl`
  - `tb_axi_llc_axi_bridge_read_outstanding_contract`
  - `tb_axi_llc_axi_bridge_write_outstanding_contract`
  - `tb_axi_llc_axi_bridge_32_outstanding_contract`
  - `tb_axi_llc_axi_bridge_write_id_reuse_contract`
  - `tb_axi_llc_subsystem_directed`
  - `tb_axi_llc_subsystem_handshake_contract`
  - `tb_axi_llc_subsystem_mode_contract`
  - `tb_axi_llc_subsystem_cache_contract`
  - `tb_axi_llc_subsystem_invalidate_line_contract`
  - `tb_axi_llc_subsystem_invalidate_line_read_hazard_contract`
  - `tb_axi_llc_subsystem_compat_write_victim_multiflow_contract`
  - `tb_axi_llc_subsystem_compat_victim_line_hazard_contract`
  - `tb_axi_llc_subsystem_size_contract`
  - `tb_axi_llc_subsystem_invalidate_all_contract`
  - `tb_axi_llc_subsystem_id_contract`
  - `tb_axi_llc_subsystem_axi_cache_refill_contract`
  - `tb_axi_llc_subsystem_axi_bypass_read_contract`
  - `tb_axi_llc_subsystem_axi_bypass_write_contract`
  - `tb_axi_llc_subsystem_axi_mode1_multiflow_contract`
  - `tb_axi_llc_subsystem_compat_direct_bypass_contract`
  - `tb_axi_llc_subsystem_compat_reconfig_drain_contract`
  - `tb_axi_llc_subsystem_compat_invalidate_line_hazard_contract`
  - `tb_axi_llc_subsystem_read_master_timing_contract`
  - `tb_axi_llc_subsystem_compat_reconfig_drain_contract`
  - `tb_axi_llc_subsystem_compat_invalidate_line_hazard_contract`
  - `tb_axi_llc_subsystem_read_master_timing_contract`
  - `tb_llc_smic12_store_contract`
- 2026-04-29 在 `eda-05` 上使用当前 RTL 与 `rtl/flist/tb_*.f` 做全量 VCS regression：
  48 passed / 0 failed。该轮覆盖 `axi_llc_axi_beat_shape.v` 接入生产
  `axi_llc_axi_bridge.v`，以及 `axi_llc_dual_port_req_steer.v`、
  `axi_llc_dual_port_issue_gate.v`、`axi_llc_dual_port_hazard_scoreboard.v`、
  `axi_llc_dual_port_hazard_match.v`、`axi_llc_dual_port_slot_hazard.v`、
  `axi_llc_dual_port_resp_mux.v` 接入生产 `axi_llc_axi_bridge_dual.v` 后的状态。
- 2026-05-02 在 `eda-05` 上补跑 ID helper 接入后的 targeted VCS smoke：
  `tb_axi_llc_axi_bridge_dual_contract` 和 `tb_axi_llc_subsystem_dual_mmio_contract`
  均 passed。两份 compile log 均确认实际解析
  `src/axi_llc_axi_id_shape.v`，覆盖生产 bridge 与 native dual top 集成路径。
- 2026-05-02 继续扩展并复跑 `tb_axi_llc_axi_bridge_dual_contract`：新增覆盖
  DDR cache write + MMIO bypass write 同周期接受、双口 `AW/W` 独立推进、MMIO `B`
  先返回 bypass source、DDR `B` 后返回 cache source；随后继续补充上游 write response
  stall 时外部 DDR `B` 仍先被接收并缓存在 bridge 内部；bridge 层的外部 `AR` issue
  hazard 在 `B` fire 后释放；并补充同一 cache response source 的 DDR/MMIO read response
  同时返回、上游 `cache_resp_ready=0` 时外部 `R` 不被 response mux/upstream stall
  反压；以及同一 source 的 DDR/MMIO write `B` 同时返回时外部 `B` 不被 response
  mux/upstream stall 反压。该轮在 `eda-05` 上 passed。
- 2026-05-02 继续扩展并复跑 `tb_axi_llc_subsystem_dual_outstanding_contract`：新增覆盖
  native dual top 中 DDR/MMIO read 同时在途时乱序 `R` response 归属，以及 DDR/MMIO
  write 同时在途时乱序 `B` response 归属；随后继续补充 DDR/MMIO `R` 同时返回时
  外部 `RREADY` 不被 top/compat response stall 反压，以及 DDR/MMIO `B` 同时返回时
  外部 `BREADY` 不被 top/compat response stall 反压。该轮在 `eda-05` 上 passed。
- 2026-05-02 继续扩展并复跑 `tb_axi_llc_subsystem_dual_mmio_contract`：新增覆盖
  native dual top 的对称 write-then-read 同 line 场景。同 line read 在 write 完成前
  不会被 top/compat 接收；上游 write response ready 拉低时，外部 DDR `B` 仍必须先被
  `BREADY` 接收并缓存；当前 core-path 接收面会等 write response slot 被上游消费后，
  再接收并继续该 same-line read。该轮在 `eda-05` 上 passed。
- 2026-05-02 在 `eda-05` 上补跑 scoreboard directed VCS contract：
  `tb_axi_llc_dual_port_hazard_scoreboard_contract` passed。compile log 确认实际解析
  `src/axi_llc_dual_port_slot_hazard.v`、`src/axi_llc_dual_port_hazard_match.v` 和
  `src/axi_llc_dual_port_hazard_scoreboard.v`。
- native dual-AXI 相关 RTL contract 已增加统一入口：
  `rtl/run_dual_axi_contracts.sh`。该脚本运行 bridge dual、native dual top MMIO、
  native dual top outstanding/owner、hazard scoreboard 四个 VCS contract，并用
  `PASS/FAIL` 日志标记判定结果，避免 VCS `$finish(1)` 返回码不可靠导致误判。
  2026-05-03 在 `eda-05` 上运行结果为 4 passed / 0 failed，最新输出目录为
  `rtl/local_debug/vcs_dual_axi_contracts_after_formal_refactor_20260503_142159`。
- 全量 RTL directed / contract regression 已增加统一入口：
  `rtl/run_all_contracts.sh`。该脚本按 `flist/tb_*.f` 排序编译并运行当前 49 个
  testbench，扫描 `FAIL`，并兼容 `<test> PASS` 与旧 bench 的独立 `PASS` marker。
  2026-05-03 在 `eda-05` 上运行结果为 49 passed / 0 failed，输出目录为
  `rtl/local_debug/vcs_all_contracts_after_formal_refactor_20260503_142220`。
