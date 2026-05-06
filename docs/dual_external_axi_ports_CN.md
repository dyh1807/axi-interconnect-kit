# CPU Core 双外部 AXI 接口需求记录

本文档记录后续 C++ reference、RTL 和形式化 EC 需要共同满足的接口语义。

## 目标

CPU core 侧 AXI 对外接口拆分为两组：

- `axi0_ddr`：连接 SDRAM/DDR 地址空间。
- `axi1_mmio`：连接 MMIO 地址空间。

两组接口共享 core 侧 outstanding 资源计数：

- read outstanding 总上限为 32。
- write outstanding 总上限为 32。
- 读写 outstanding 相互独立，因此最多可以同时有 32 个读事务和 32 个写事务。

## 地址空间

- SDRAM/DDR 空间：`0x4000_0000` 及以上。
- LLC mapped-window 空间：`0x3000_0000` 到 `0x303f_ffff`，窗口大小 4MB。
- MMIO 空间：其它地址。

LLC mapped-window 的处理取决于 LLC 模式：

- LLC 地址映射模式时，`[offset, offset + 4MB)` 不属于 MMIO，由 LLC 本地映射处理。
- 非 LLC 地址映射模式时，`[offset, offset + 4MB)` 仍按普通地址分类；若地址低于 `0x4000_0000`，属于 MMIO。

默认 mapped-window offset 为 `0x3000_0000`。

当前阶段的验证范围补充：

- 当前 Linux bring-up 的唯一必须通过路径是 LLC on 模式，也就是 `AXI_SUBMODULE_MODE=1`；
  C++ reference 的性能/正确性回归优先服务这条路径。
- Offset 地址映射模式主要服务未来硬件启动初期，不作为当前 Linux bring-up 或性能回归
  的主验证路径。
- 其它 LLC runtime mode 暂不要求读路径完整跑通 Linux；但写路径仍必须保持地址分类、
  `wstrb` 移位和 backing-memory 更新语义正确，避免后续模式切换时遗留歧义。

## DDR/SDRAM AXI 口

DDR 口负责 `0x4000_0000` 及以上地址。对 AXI 接口本身，不区分 SDRAM 和 DDR：

- `0x4000_0000` 到 `0x7fff_ffff`：SDRAM。
- `0x8000_0000` 及以上：DDR。

DDR 口行为不再因 LLC runtime mode 不同而改变。

读请求：

- downstream beat 固定为 256 bits，也就是 32 bytes。
- 大于 256 bits 的读请求拆成多个 256-bit beat；当前 64B cacheline 是 2 beat，同属一笔 AXI transaction。
- 小于 256 bits 的读请求转换为 1 beat、256-bit 对齐读，返回完整 beat 后在 interconnect 内截取需要的字节。

写请求：

- downstream beat 固定为 256 bits，也就是 32 bytes。
- 大于 256 bits 的写请求拆成多个 256-bit beat；当前 64B cacheline 是 1 次 AW 握手加 2 次 W 握手。
- 小于 256 bits 的写请求转换为 1 beat、256-bit 对齐写，通过 32-bit `wstrb` 控制有效字节。

## MMIO AXI 口

MMIO 口负责非 DDR 且非 active mapped-LLC window 的地址：

- 排除 `0x4000_0000` 及以上。
- LLC 地址映射模式下，排除 `[offset, offset + 4MB)`。

MMIO 口只允许 32-bit、1 beat 读写。若上游尝试向 MMIO 口发起其它宽度事务，C++ reference 应显式拒绝或报错，RTL 也应具备等价约束。

## AR/AW 顺序约束

Interconnect/LLC 层必须附加以下控制逻辑：

- 同一地址/line 的 AR 发出后，在对应 R 返回前，不允许发出相同地址/line 的 AW。
- 同一地址/line 的 AW 发出后，在对应 B 返回前，不允许发出相同地址/line 的 AR。
- 禁止形成依赖顺序：已经发出 AR 和 AW 后，等待 B 返回、清 buffer，然后才接收 R。换言之，写响应不能成为同一地址未完成读响应的释放前提。
- `R` 通道不能因为上游 response channel 暂时不 ready、DDR/MMIO response mux 选择了另一侧、
  或同 line 写事务正在等待发射/等待 `B` 而被回压；外部 `R` 必须先被接收并缓存在
  interconnect/LLC 内部。之后是否立刻把 read response 送回上游，可以由内部 response
  queue / mux 仲裁决定。

这些约束用于规避 AXI 对 AR/AW 同地址未完成事务返回新值还是旧值没有规定的问题。

## RTL 架构决策

最终 RTL 不应把双外部 AXI 口实现成固定的 `single AXI -> router -> DDR/MMIO`
主路径。该做法可以作为 bring-up shim 使用，但不是长期最佳结构：

- 单发射 AXI 口会限制 DDR/MMIO 混合流量，无法在同一周期分别向两个外部口发出
  DDR 与 MMIO `AR/AW`。
- 单口 bridge 若先把请求统一改写成 256-bit beat，router 再反向改成 MMIO 32-bit
  beat，会丢失原始请求语义，增加 EC 和 corner case 风险。
- 同地址 `AR/AW` hazard gate、outstanding 资源分配和地址分类应尽量在同一调度层完成，
  不应依赖下游分流层补救。

因此长期实现目标是 native dual-port bridge/interconnect：在内部接受请求时保留原始
size/address 语义，按地址直接选择 `axi0_ddr` 或 `axi1_mmio`，并分别驱动两组 AXI
通道。当前可以保留一个 dual-port router 作为过渡 contract bench，用来验证双口
ID/response 归属与握手，但不把它作为性能最终路径。

## RTL 当前实现状态

当前 submodule RTL 已新增两层双口 bring-up 逻辑：

- `axi_llc_axi_dual_port_router.v`：过渡 shim，从既有单 AXI 口分流到 DDR/MMIO。
  该模块只用于快速 contract 验证，不作为最终性能路径。
- `axi_llc_axi_bridge_dual.v`：native dual-port lower bridge wrapper，在 lower
  request 层直接按地址选择 DDR/MMIO，不经过单 AXI 中间口。

`axi_llc_axi_bridge_dual.v` 当前语义：

- 地址 `>= 0x4000_0000` 走 DDR 口，保留 256-bit beat 和 cacheline multi-beat。
- 地址 `< 0x4000_0000` 走 MMIO 口，MMIO AXI data width 为 32-bit。
- MMIO 只接受 `total_size == 3` 的 4B 请求；其它 MMIO 大请求会 backpressure。
- DDR 与 MMIO 属于两个独立 bridge 实例，因此可以同周期分别接受/发射 DDR 与 MMIO
  请求，不存在 single-AXI-router 的发射瓶颈。

当前 RTL 状态：

- `axi_llc_subsystem_dual.v` 已作为 native 双外部 AXI 顶层候选接入；
  `axi_llc_subsystem.v` 仍保留为旧单 AXI 兼容顶层。
- 上游原始事务 ID 和内部 slot/MSHR/lower response ID 已通过 `SLOT_ID_BITS`
  解耦；当前 upstream ID 仍为 4-bit，内部 lower/source slot ID 为 6-bit。
  6-bit slot ID 支持 32 个 MSHR slot，并保留最高两个编码给 legacy demand/refill
  与 writeback/flush 响应 ID，避免 slot 30/31 与保留 ID 冲突。
- RTL 默认 read outstanding、write outstanding 和 bridge/core 预算已经扩到 32；
  读写预算彼此独立，最多允许 32 个读事务与 32 个写事务同时未完成。
- 双口地址分类和事务形状已经抽成生产 RTL 组合 helper
  `axi_llc_dual_port_route_shape.v`；native bridge 与 `hw-cbmc` formal smoke
  共同引用这份逻辑，避免 C/RTL EC 入口验证复制 spec。
- `axi_llc_axi_bridge_dual.v` 已在外部 AXI `AR/AW` issue 边界实现同 line
  read/write hazard gate：已发 `AR` 在 `R last` 前阻塞同 line `AW`，已发
  `AW` 在 `B` 前阻塞同 line `AR`，不同 line 不应被该 gate 串行化。
- `hw-cbmc` C++/RTL EC harness 尚未接入。

## EC 规划

后续形式化 EC 应以本文档为共同规格，比较 C++ reference 和 RTL 在以下方面的一致性：

- 地址分类结果：DDR、MMIO、mapped-LLC local。
- AR/AW/W/R/B 对外握手事件。
- outstanding 上限和 ID/response 归属。
- 小请求对齐、截取、`wstrb` 移位。
- 同地址 AR/AW hazard gate。

本阶段先收敛 C++ reference，再迁移 RTL native dual-port bridge，最后接入
`hw-cbmc` 进行 C++/RTL 等价性检查。

`hw-cbmc` 的模块/top 验证状态、已通过范围和后续拆分计划见
`formal/README_CN.md`。该文档是 formal 入口的总索引，避免把 VCS directed tests
误记为形式化已验证范围。

## C++ Reference 当前实现状态

截至本轮 C++ 修改，`AXI_Interconnect` 已经拆出两个 downstream AXI 口：

- `axi_ddr_io`：DDR/SDRAM 口。
- `axi_mmio_io`：MMIO 口。
- `axi_io` 暂时保留为 `axi_ddr_io` 的兼容别名，避免旧测试/旧调用点立刻失效。

当前实现策略：

- 地址 `>= CONFIG_AXI_KIT_DDR_BASE` 走 DDR 口；parent simulator profile 中该值为 `0x4000_0000`。
- active LLC mapped-window 仍优先走 LLC 本地映射。
- 其它地址走 MMIO 口，并只接受 32-bit、1 beat 事务；MMIO 大读写请求会 backpressure，
  不会被静默截断为 4B。
- DDR 口小于 32B 的请求对齐到 32B beat，读响应在 interconnect 内截取，写请求同步移位 `wdata/wstrb`。
- DDR 口 64B cacheline 维持 2 beat、同一 AXI transaction。
- 同 line AR/AW hazard gate 已加入，覆盖已发 AR、latched AR、pending R、latched AW、active W、pending B。
- LLC 外部写请求的 AXI ID 已统一使用 `sim_ddr::AXI_ID_WIDTH` 对应的 `kAxiIdMask`，
  不再保留旧的 3-bit `& 0x7` 截断；否则 6-bit SimDDR 会返回和 interconnect 内部
  active write context 不匹配的 `BID`。
- LLC mode 下外部 `BREADY` 只在当前 port 的 active write 已完成全部 `W` beat 且
  `BID` 匹配，或确有 victim writeback 的 ignored B 待丢弃时才拉高；避免把无法归属
  的 `B` 提前接收，保证 direct B response 与 LLC mem B response 的 owner 分离。

当前 C++ 已具备集成双外部 AXI 口的基本调度结构：

- `axi_ddr_io` 和 `axi_mmio_io` 已经拆开，地址分类和事务形状已经按双口语义运行。
- 地址分类/shape 的 C reference 已抽成 `include/axi_dual_port_route_shape.h`，生产
  `AXI_Interconnect` 和 `hw-cbmc` harness 共同引用这份 helper。
- AR/AW/W 调度已拆成 per-port issue/latch/state，例如 `ar_latched` 与
  `ar_latched_mmio`、`aw_latched` 与 `aw_latched_mmio`、`w_current` 与
  `w_current_mmio`。
- targeted test 已覆盖 DDR 与 MMIO 同周期发出 `AR`、同周期发出 `AW`、同周期发出
  `W`。这些同周期发射测试当前覆盖的是非 LLC 直连外部路径；LLC-on 路径的上游仍先
  进入 LLC core request stage；但 32-bit MMIO read 已经在 interconnect 层直接
  bypass 到 `axi_mmio_io`，不再占用 LLC core request stage。
- 32-bit MMIO write 同样已经在 interconnect 层直接 bypass 到 `axi_mmio_io`；
  该路径不会进入 LLC write context，也不会更新 LLC data/meta。direct write B
  response 按 upstream master/id 返回，LLC mem write B response 仍归属 LLC。
- targeted test 也覆盖同 line hazard 的两个方向：AR 发出后同 line AW 必须等待 R
  返回，AW/写事务发出后同 line AR 必须等待 B/写事务完成；不同 port/不同 line 的
  DDR 与 MMIO 流量不应被这些 hazard gate 串行化。
- read/write outstanding 仍维持全局共享上限；后续工作应把同等 native dual-port
  语义迁移到最终 RTL 顶层，并接入 EC harness。

当前 RTL 已开始承接同等语义：

- `axi_llc_subsystem_dual.v` 新增为 native 双外部 AXI 顶层候选；旧
  `axi_llc_subsystem.v` 仍保留为单 AXI 兼容顶层，避免打断既有 testbench。
- `axi_llc_subsystem_compat.v` 的 mode1 MMIO 分类已改为 direct lower bypass：
  32-bit MMIO read/write 不再进入 LLC core resident lookup，也不会更新 LLC
  data/meta。
- `SLOT_ID_BITS` 已加入 RTL 顶层/compat 连接，用于把 upstream request ID 与内部
  core slot / lower request ID 解耦；当前内部 slot 为 6-bit，outstanding 预算已扩到
  32。
- `tb_axi_llc_subsystem_dual_mmio_contract.v` 固化了 mode1 普通 MMIO 读写
  `*_bypass=0` 时也必须走 `mmio_axi_*`、不得驱动 `ddr_axi_*`、response 回到原
  upstream ID；同时覆盖 DDR cache refill `AR` 被 backpressure 保持时，MMIO
  read/write 仍可在独立 MMIO AXI 口发射和返回。
- `tb_axi_llc_axi_bridge_dual_contract.v` 已补充 native dual bridge 的同 line
  `AR/AW` hazard 合同：读未返回时同 line 写不能发 `AW/W`，写未回 `B` 时同
  line 读不能发 `AR`，不同 line 写仍可在读 pending 时继续发出。
- `tb_axi_llc_subsystem_dual_mmio_contract.v` 进一步覆盖 native dual top 集成路径：
  DDR bypass read 的 `AR` 已发且 `R` 未返回时，同 line DDR bypass write 可以进入
  pending 状态，但不得提前发 `AW/W`；`R` 返回后写事务继续发出并按原 upstream ID
  回包。该 bench 还覆盖 upstream read response ready 拉低时，外部 DDR `R` 仍先被
  `RREADY` 接收并缓存，同 line 写不等待 upstream read response 被消费。
- `tb_axi_llc_subsystem_dual_outstanding_contract.v` 覆盖 native dual top 在
  `MODE_OFF` direct-bypass 场景下的全局 shared outstanding 预算：DDR/MMIO
  两个外部口 read 合计最多 32、write 合计最多 32，且 read/write 预算相互独立。

## Simulator Reset PC 约束

原 simulator 复位 PC 为 `0x0000_0000`，并通过低地址 boot stub 跳到 `0x8000_0000`。在新地址图下，`0x0000_0000` 属于 MMIO 口，而 MMIO 口只支持 32-bit、1 beat，不适合继续承载 64B ICache line fill。

因此 parent simulator profile 当前显式定义：

- `RESET_PC = 0x8000_0000`

并同步修改 difftest/oracle，使 C++ DUT、reference 和 oracle 从同一 DDR/RAM 起点开始执行。低地址 boot stub 仍保留在 backing memory 中，但不再作为默认 AXI ICache 启动路径。

注意：低地址 boot stub 原本会设置 Linux boot ABI：

- `a0 = hartid = 0`
- `a1 = fdt = 0x83e0_0000`

当 `RESET_PC=0x8000_0000` 且加载 Linux image 时，simulator 需要显式向 DUT PRF、
difftest reference 和 oracle 灌入上述参数；否则 Linux 可能在缺少 FDT 参数的情况下
构造出不完整页表，导致 strict ITLB 语义下出现大量重复 page fault/低 IPC。

## 已完成的最小验证

已通过的 targeted tests：

- `axi_interconnect_dual_port_test`：32 passed, 0 failed。
  覆盖 DDR/MMIO 路由、MMIO 大读写阻塞、同 line AR/AW hazard gate、legacy LLC
  MMIO backing 读写、LLC-MMIO bypass，以及非 LLC-on 模式下的写路径地址分类、
  DDR 256-bit 对齐/`wstrb` 移位、mode2 mapped-window 写捕获和 mode3 bypass 写捕获。
  最新补充覆盖：同 line AR 等待 B、不同 port/不同 line DDR/MMIO 不串行、LLC mem
  侧 read/write request ready 受同 line R/B 约束；同 line 写在 2-beat DDR
  `R` 尚未全部接收前保持 blocked，但 `R last` 被 interconnect 缓存后即释放，
  不等待上游 read response consume；对称方向也覆盖同 line 读在 `B` 返回并缓存
  为上游 write response 后释放，不等待上游 write response consume。
  standalone dual-port test target 显式使用 32-entry read outstanding 和 32-entry
  write outstanding，并覆盖 read/write outstanding 共享口内预算、读写预算相互独立。
  LLC-on 下的 32-bit MMIO read 直接 bypass LLC core stage，并在 direct response
  待返回时 backpressure 同 master 的 LLC read response。
  LLC-on 下的 32-bit MMIO write 直接 bypass LLC core stage，并覆盖 direct B
  response 与 LLC mem B response 的 owner 分离。
- `axi_interconnect_llc_axi4_test`：29 passed, 0 failed。本轮在 standalone
  submodule CMake 下补齐 `PhysMemory.h` shim 后复测通过；同时覆盖 LLC bypass write
  hit/miss、mode2 DDR-aligned narrow/cross-beat write、mixed stress 和 invalidate epoch
  stress 中的 LLC mem write B response 归属。
- `ctest --test-dir build_dual_axi_scope_20260428 --output-on-failure`：2026-05-02
  结果为 21/21 passed, 0 failed。该轮覆盖 SimDDR、AXI interconnect 单口/32B/dual-port、
  LLC core、LLC+AXI4 integration 和 MMIO router 的 C++ regression。

已通过的 RTL VCS targeted tests：

- 2026-04-29 在 `eda-05` 上对 `rtl/flist/tb_*.f` 做全量 VCS regression：
  48 passed, 0 failed。该轮覆盖 `axi_llc_axi_beat_shape.v` 接入生产
  `axi_llc_axi_bridge.v`，以及 `axi_llc_dual_port_req_steer.v`、
  `axi_llc_dual_port_issue_gate.v`、`axi_llc_dual_port_hazard_scoreboard.v`、
  `axi_llc_dual_port_hazard_match.v`、`axi_llc_dual_port_slot_hazard.v`、
  `axi_llc_dual_port_resp_mux.v` 接入生产 `axi_llc_axi_bridge_dual.v` 后的状态。
- 2026-05-02 在 `eda-05` 上补跑 ID helper 接入后的 targeted VCS smoke：
  `tb_axi_llc_axi_bridge_dual_contract` 和 `tb_axi_llc_subsystem_dual_mmio_contract`
  均 passed。两份 compile log 均确认实际解析
  `src/axi_llc_axi_id_shape.v`，覆盖生产 bridge 与 native dual top 集成路径。
- 2026-05-02 在 `eda-05` 上补跑 scoreboard directed VCS contract：
  `tb_axi_llc_dual_port_hazard_scoreboard_contract` passed。该 bench 直接实例化生产
  `axi_llc_dual_port_hazard_scoreboard.v` 及其 match/slot helper，覆盖 `AR/AW`
  hazard entry 记录、错误 `RID/BID` 不释放、匹配 `R/B` 释放，以及 DDR/MMIO shared
  read/write slots 的基本占用/释放。
- `tb_axi_llc_axi_dual_port_router_contract`
- `tb_axi_llc_axi_bridge_dual_contract`：覆盖 native DDR/MMIO 双口分流、MMIO
  4B 形状约束、大 MMIO 阻塞，以及 native bridge 同 line `AR/AW` hazard gate。
  最新补充覆盖 DDR cache write 与 MMIO bypass write 同周期接受、双口 `AW/W`
  独立推进，以及 MMIO `B` 先于 DDR `B` 返回时仍分别回到 bypass/cache source。
  `test_cache_resp_mux_does_not_backpressure_external_r` 覆盖同一 cache response source
  同时有 DDR/MMIO read response 待回、且上游 `cache_resp_ready=0` 时，外部 DDR/MMIO
  `R` 仍会先被各自 bridge 通过 `RREADY` 接收并缓存；后续 response mux 再按 MMIO
  优先级把缓存结果送回上游。
  `test_cache_resp_mux_does_not_backpressure_external_b` 覆盖同一 cache response source
  的 DDR/MMIO write `B` 同时返回、且上游 `cache_resp_ready=0` 时，外部两个 `B`
  也会先被各自 bridge 通过 `BREADY` 接收并缓存，再由 response mux 顺序送回上游。
  其中 `test_rready_ignores_response_backpressure` 覆盖 same-line 写已被 read hazard
  阻塞、且上游 read response ready 拉低时，DDR `R` 两个 beat 仍必须被 `RREADY`
  接收，不允许把外部 `R` 接收依赖到 response mux / 上游 ready / 写侧完成。
  `test_bready_ignores_response_backpressure` 覆盖对称方向：same-line 读已被 write
  hazard 阻塞、且上游 write response ready 拉低时，DDR `B` 仍先被 `BREADY` 接收并
  缓存在 bridge 内部；bridge 层的外部 `AR` issue hazard 在 `B` fire 后释放，不等待
  上游 write response 被消费。
- `tb_axi_llc_subsystem_dual_mmio_contract`：覆盖 native dual top 的 MMIO 独立发射，
  以及 DDR bypass read/write 同 line hazard 在顶层集成路径上的闭环；同时覆盖
  upstream read response backpressure 不得反压外部 DDR `R` 接收。最新补充覆盖
  对称 write-then-read 场景：同 line read 在 write 完成前不会被 top/compat 接收，
  上游 write response ready 拉低时外部 DDR `B` 仍必须先被 `BREADY` 接收并缓存在
  subsystem 内部；当前 core-path 接收面会等 write response slot 被上游消费后，再
  接收并继续该 same-line read。
- `tb_axi_llc_subsystem_dual_outstanding_contract`：覆盖 native dual top 在 direct-bypass
  场景下的 DDR/MMIO shared read/write outstanding 预算和 read/write 预算独立性。
  最新补充覆盖 DDR/MMIO read 同时在途时乱序 `R` response 归属，以及 DDR/MMIO write
  同时在途时乱序 `B` response 归属；并覆盖 DDR/MMIO `R` 同时返回、上游
  `read_resp_ready=0` 时外部 `RREADY` 不被 top/compat response stall 反压，以及
  DDR/MMIO `B` 同时返回、上游 `write_resp_ready=0` 时外部 `BREADY` 不被 top/compat
  response stall 反压。
- `rtl/run_all_contracts.sh`：2026-05-03 在 `eda-05` 上完成当前 49 个
  `flist/tb_*.f` 的全量 VCS directed / contract regression，结果为
  49 passed / 0 failed；最新输出目录为
  `rtl/local_debug/vcs_all_contracts_after_formal_refactor_20260503_142220`。

已通过的 formal smoke：

- `formal/run_passed_hw_cbmc.sh`：只运行当前已收敛的 formal smoke；2026-05-04
  当前结果为 59 passed / 0 failed。
- `formal/axi_id_shape/run_hw_cbmc.sh`：使用父目录 `hw-cbmc` 软链接对 AXI ID
  width conversion 做生产 C helper / 生产 RTL helper 等价检查，覆盖 6->8、
  3->8、8->6、6->6 的 zero-extension/truncation 语义。该 RTL helper 已被实际
  `axi_llc_axi_bridge_dual.v` 用于 DDR/MMIO lower ID 与 hazard scoreboard 的
  ID 归一化边界。
- `formal/axi_beat_shape/run_hw_cbmc.sh`：使用父目录 `hw-cbmc` 软链接对 AXI beat
  shape 做生产 C helper / 生产 RTL helper 等价检查，覆盖 32B DDR beat 和 4B MMIO
  beat 的 `total_beats / axi_len / axi_size`。该 RTL helper 已被实际
  `axi_llc_axi_bridge.v` 用于驱动 `AR/AW` shape。
- `formal/axi_mode2_shape/run_hw_cbmc.sh`：验证生产 C helper 与生产
  `axi_llc_axi_mode2_shape.v` 的 mode2 aligned issue addr/size 逻辑一致；该 helper
  已被实际 `axi_llc_axi_bridge.v` 和 `axi_llc_axi_issue_select.v` 使用。
- `formal/axi_pending_scan/run_hw_cbmc.sh`：验证生产 C helper 与生产
  `axi_llc_axi_pending_scan.v` 的 pending slot/AXI ID/match/complete scan 控制一致；
  该 helper 已被实际 `axi_llc_axi_bridge.v` 用于 read/write pending 表扫描。
- `formal/axi_issue_select/run_hw_cbmc.sh`：验证生产 C helper 与生产
  `axi_llc_axi_issue_select.v` 的 queue-head issue select 控制一致；该 helper 已被实际
  `axi_llc_axi_bridge.v` 用于 `AR/AW/W` 发射边界。
- `formal/axi_fifo_ptr/run_hw_cbmc.sh`：验证生产 C helper 与生产
  `axi_llc_axi_fifo_ptr.v` 的 FIFO head/tail/count 更新逻辑一致；该 helper 已被实际
  `axi_llc_axi_bridge.v` 用于 issue queue 和 response queue 指针更新边界。
- `formal/axi_queue_ctrl/run_hw_cbmc.sh`：验证生产 C helper 与生产
  `axi_llc_axi_queue_ctrl.v` 的 queue space、valid、AXI handshake 和 push/pop
  控制一致；该 helper 已被实际 `axi_llc_axi_bridge.v` 用于 request accept 资源反馈、
  issue queue pop 和 response queue valid/space 控制。
- `formal/axi_write_pack/run_hw_cbmc.sh`：验证生产 C helper 与生产
  `axi_llc_axi_write_pack.v` 的 AXI `W` channel data/strobe 打包逻辑一致；该 helper
  已被实际 `axi_llc_axi_bridge.v` 用于普通 cacheline write 和 mode2 DDR-aligned
  write 的 `WDATA/WSTRB` 生成。
- `formal/axi_write_pack_prod_width/run_hw_cbmc.sh`：验证生产
  `axi_llc_axi_write_pack.v` 在 64B line / 32B DDR beat 参数下的组合逻辑，覆盖
  cacheline write 的低/高 32B beat 切分，以及 mode2 DDR-aligned write 的 256-bit
  `WDATA` / 32-bit `WSTRB` offset 移位。
- `formal/axi_read_pack/run_hw_cbmc.sh`：验证生产 C helper 与生产
  `axi_llc_axi_read_pack.v` 的 AXI `R` channel beat merge 与 mode2 aligned read
  extract 逻辑一致；该 helper 已被实际 `axi_llc_axi_bridge.v` 用于 read response
  buffer 聚合和 mode2 窗口提取。
- `formal/axi_read_pack_prod_width/run_hw_cbmc.sh`：验证生产
  `axi_llc_axi_read_pack.v` 在 64B response / 32B DDR beat 参数下的组合逻辑，覆盖
  cacheline read 的低/高 32B beat 合并，以及 mode2 DDR-aligned read 的 64B
  response 字节切片。
- `formal/bridge_prod_width_cacheline_aw_shape/run_hw_cbmc.sh`：直接实例化生产
  `axi_llc_axi_bridge.v`，在 64B line / 32B DDR beat 参数下覆盖 cacheline write
  的 `AWADDR/AWLEN/AWSIZE/AWBURST`。
- `formal/bridge_prod_width_cacheline_ar_shape/run_hw_cbmc.sh`：直接实例化生产
  `axi_llc_axi_bridge.v`，在 64B line / 32B DDR beat 参数下覆盖 cacheline read
  的 `ARADDR/ARLEN/ARSIZE/ARBURST`。
- `formal/bridge_prod_width_cacheline_write_shape/run_hw_cbmc.sh`：直接实例化生产
  `axi_llc_axi_bridge.v`，在 64B line / 32B DDR beat 参数下覆盖 cacheline write
  的两拍 256-bit `W` payload、`WSTRB` 和 `WLAST`。
- `formal/bridge_prod_width_cacheline_read_response/run_hw_cbmc.sh`：直接实例化生产
  `axi_llc_axi_bridge.v`，在 64B line / 32B DDR beat 参数下覆盖 cacheline read
  的两拍 256-bit `R` payload、`RREADY`、`RLAST` 前不回包和 512-bit response 回收。
- `formal/axi_read_resp_ctrl/run_hw_cbmc.sh`：验证生产 C helper 与生产
  `axi_llc_axi_read_resp_ctrl.v` 的 AXI `R` channel last-beat 判定和 response code
  累计逻辑一致；该 helper 已被实际 `axi_llc_axi_bridge.v` 用于 read response
  接收控制。
- `formal/axi_req_accept/run_hw_cbmc.sh`：验证生产 C helper 与生产
  `axi_llc_axi_req_accept.v` 的 source-side request accept 控制一致；该 helper 已被
  实际 `axi_llc_axi_bridge.v` 使用。该 smoke 固定 cache/bypass 接受优先级，以及
  read/write pending slot、AXI ID、issue queue 资源门控。
- `formal/axi_resp_accept/run_hw_cbmc.sh`：验证生产 C helper 与生产
  `axi_llc_axi_resp_accept.v` 的外部 AXI `R/B` response ready/accept 控制一致；
  该 helper 已被实际 `axi_llc_axi_bridge.v` 使用。该 smoke 固定 `RREADY` 不被
  upstream response ready 回压，以及 `BREADY` 受 write response queue 空间保护的
  语义边界。
- `formal/axi_source_resp_mux/run_hw_cbmc.sh`：验证生产 C helper 与生产
  `axi_llc_axi_source_resp_mux.v` 的 source-local response mux/pop 控制一致；该
  helper 已被实际 `axi_llc_axi_bridge.v` 用于 cache/bypass response 返回边界。
- `formal/axi_resp_route/run_hw_cbmc.sh`：验证生产 C helper 与生产
  `axi_llc_axi_resp_route.v` 的 response enqueue route 控制一致；该 helper 已被实际
  `axi_llc_axi_bridge.v` 用于 response owner 归属和 write response queue 空间门控。
- `formal/dual_port_req_steer/run_hw_cbmc.sh`：验证生产 C helper 与生产
  `axi_llc_dual_port_req_steer.v` 的请求分流/ready 合同一致；该 helper 已被实际
  `axi_llc_axi_bridge_dual.v` 用于 cache/bypass 两路 lower request 接受面。
- `formal/dual_port_issue_gate/run_hw_cbmc.sh`：验证生产 C helper 与生产
  `axi_llc_dual_port_issue_gate.v` 的单 port `AR/AW` 发射屏蔽合同一致，覆盖
  pending hazard 和同周期同 line `AR` 优先压住 `AW`；该 helper 已被实际
  `axi_llc_axi_bridge_dual.v` 用于 DDR/MMIO 两个外部口的 issue 边界。
- `formal/dual_port_hazard_match/run_hw_cbmc.sh`：验证生产 C helper 与生产
  `axi_llc_dual_port_hazard_match.v` 的 per-entry port/line/id match 组合逻辑一致；
  该 helper 已被实际 `axi_llc_dual_port_hazard_scoreboard.v` 用于同 line hazard
  状态比较。
- `formal/dual_port_slot_hazard/run_hw_cbmc.sh`：验证生产 C helper 与生产
  `axi_llc_dual_port_slot_hazard.v` 的 shared slot hazard 组合逻辑一致；secondary
  port 只有在 primary port 本周期实际 fire 且没有第二个空槽时才因 shared slot
  被阻塞，primary port 只是 valid 但未 fire 不得串行化 secondary port。
- `formal/dual_port_resp_mux/run_hw_cbmc.sh`：验证生产 C helper 与生产
  `axi_llc_dual_port_resp_mux.v` 的 DDR/MMIO response mux 与 ready 回压合同一致；
  该 helper 已被实际 `axi_llc_axi_bridge_dual.v` 用于 cache/bypass 两路 response
  合并。
- `formal/dual_port_route_shape/run_hw_cbmc.sh`：使用父目录 `hw-cbmc` 软链接对
  双口地址分类与 MMIO 支持边界做生产 C helper / 生产 RTL helper 等价检查，覆盖
  DDR/MMIO 端口选择、MMIO 4B 支持边界以及 helper 输出的 `axi_len/axi_size`。
  实际 AXI channel 形状仍由直接绑定 `axi_llc_axi_bridge_dual.v` /
  `axi_llc_axi_bridge.v` 的 bridge/top smoke 覆盖。

实验中的 formal 入口：

- `formal/dual_bridge_read_route/run_hw_cbmc.sh`：实例化实际
  `axi_llc_axi_bridge_dual.v` / `axi_llc_axi_bridge.v`，目标是检查 read request
  被接受后的 DDR/MMIO `AR` 归属。该入口当前已通过并纳入已通过 formal regression。
- `formal/dual_bridge_read_r_response/run_hw_cbmc.sh`：实例化实际
  `axi_llc_axi_bridge_dual.v` / `axi_llc_axi_bridge.v`，目标是检查 4B read request
  的外部 `R` response 接收、cache source response id/code/data 回收和单 beat data merge。
  该入口当前已通过并纳入已通过 formal regression。
- `formal/dual_bridge_write_route/run_hw_cbmc.sh`：实例化实际
  `axi_llc_axi_bridge_dual.v` / `axi_llc_axi_bridge.v`，目标是检查 4B write request
  被接受后的 DDR/MMIO `AW/W` 归属和基础 channel 形状。该入口当前已通过并纳入
  已通过 formal regression。
- `formal/dual_bridge_write_b_response/run_hw_cbmc.sh`：实例化实际
  `axi_llc_axi_bridge_dual.v` / `axi_llc_axi_bridge.v`，目标是检查 4B write request
  的外部 `B` response 接收与 cache source response id/code 回收。该入口当前已通过并纳入
  已通过 formal regression。
- `formal/dual_bridge_ddr_multibeat_read/run_hw_cbmc.sh`：实例化实际
  `axi_llc_axi_bridge_dual.v` / `axi_llc_axi_bridge.v`，以 16B line / 8B DDR beat 的
  同构 2-beat 参数覆盖 cacheline read 的 `ARLEN=1`、两拍 `R` 数据合并、`RLAST`
  前不回包和最终 id/code/data 回收。该入口当前已通过并纳入已通过 formal regression。
- `formal/dual_bridge_ddr_multibeat_write/run_hw_cbmc.sh`：实例化实际
  `axi_llc_axi_bridge_dual.v` / `axi_llc_axi_bridge.v`，以 16B line / 8B DDR beat 的
  同构 2-beat 参数覆盖 cacheline write 的 `AWLEN=1`、两拍 `W` 数据顺序、
  `WSTRB` 和 `WLAST`。该入口当前已通过并纳入已通过 formal regression。
- `formal/dual_bridge_same_line_read_blocks_write/run_hw_cbmc.sh`：实例化实际
  `axi_llc_axi_bridge_dual.v` / `axi_llc_axi_bridge.v`，覆盖 DDR read `AR` 发出后、
  对应 `R last` 接收前，同 line write 不得提前对外发出 `AW/W`；`R last` 后该
  write 必须继续发出。该入口当前已通过并纳入已通过 formal regression。
- `formal/dual_bridge_same_line_write_blocks_read/run_hw_cbmc.sh`：实例化实际
  `axi_llc_axi_bridge_dual.v` / `axi_llc_axi_bridge.v`，覆盖 DDR write `AW/W` 发出后、
  对应 `B` 接收前，同 line read 不得提前对外发出 `AR`；`B` 后该 read 必须继续
  发出。该入口当前已通过并纳入已通过 formal regression。
- `formal/dual_bridge_multi_read_outstanding/run_hw_cbmc.sh`：实例化实际
  `axi_llc_axi_bridge_dual.v` / `axi_llc_axi_bridge.v`，覆盖第一笔 DDR read 未收到
  `R` 前，第二笔不同 line DDR read 仍可被接受并发出 `AR`，且两笔 read 使用不同
  AXI ID。该入口当前已通过并纳入已通过 formal regression。
- `formal/dual_bridge_read_then_write_outstanding/run_hw_cbmc.sh`：实例化实际
  `axi_llc_axi_bridge_dual.v` / `axi_llc_axi_bridge.v`，覆盖 DDR read `AR` 已发出且
  未收到 `R` 时，不同 line DDR write 仍可被接受并发出 `AW/W`。该入口当前已通过并
  纳入已通过 formal regression。
- `formal/dual_bridge_write_then_read_outstanding/run_hw_cbmc.sh`：实例化实际
  `axi_llc_axi_bridge_dual.v` / `axi_llc_axi_bridge.v`，覆盖 DDR write `AW/W` 已发出且
  未收到 `B` 时，不同 line DDR read 仍可被接受并发出 `AR`。该入口当前已通过并
  纳入已通过 formal regression。
- `formal/dual_bridge_mode2_aligned_write/run_hw_cbmc.sh`：实例化实际
  `axi_llc_axi_bridge_dual.v` / `axi_llc_axi_bridge.v`，覆盖 bypass mode2 DDR-aligned
  4B write 的 `AWADDR/AWLEN/AWSIZE`、`WDATA/WSTRB` 移位和 `B` 回包。该入口当前已通过并
  纳入已通过 formal regression。
- `formal/dual_bridge_mode2_aligned_read/run_hw_cbmc.sh`：实例化实际
  `axi_llc_axi_bridge_dual.v` / `axi_llc_axi_bridge.v`，覆盖 bypass mode2 DDR-aligned
  4B read 的 `ARADDR/ARLEN/ARSIZE`、`RDATA` 截取和 `R` 回包。该入口当前已通过并纳入
  已通过 formal regression。
- 该实验暴露了 `axi_llc_axi_bridge.v` 中 variable indexed part-select 对 hw-cbmc
  前端不友好；生产 RTL 已改写为 shift/mask byte helper，并通过 RTL VCS 全量回归。
- 2026-04-29 重新探测时，脚本已补齐 req accept / resp accept / req steer /
  issue gate 的生产 RTL 依赖，但 `HW_CBMC_TIMEOUT_SEC=60` 仍停在实际
  `axi_llc_axi_bridge` type-check/转换阶段。
- 2026-05-03 短 timeout 探测已清除 helper 缺失和 bridge loop index assignment type
  冲突，并补齐 `axi_llc_axi_pending_scan.v` / `axi_llc_axi_issue_select.v` 依赖；
  后续又补齐 `axi_llc_axi_mode2_shape.v` / `axi_llc_axi_fifo_ptr.v` /
  `axi_llc_axi_queue_ctrl.v` /
  `axi_llc_axi_write_pack.v` /
  `axi_llc_axi_read_pack.v` /
  `axi_llc_axi_read_resp_ctrl.v` /
  `axi_llc_axi_resp_route.v` /
  `axi_llc_axi_source_resp_mux.v` 依赖；
  后续又把生产 bridge pending 深度改成可参数化默认值。生产默认仍为 32/32；
  该 formal top 显式缩到 1/1，并把 line/data/response 宽度缩到
  64-bit、外部 AXI ID 宽度缩到 1-bit，并补齐 `axi_llc_axi_id_shape.v`、
  `axi_llc_dual_port_hazard_match.v`、`axi_llc_dual_port_slot_hazard.v` 依赖后通过。
- `formal/dual_port_hazard_scoreboard/run_hw_cbmc.sh`：实例化生产
  `axi_llc_dual_port_hazard_scoreboard.v` 的小参数状态 smoke，目标是验证
  `AR/AW` scoreboard 的记录/释放。2026-05-03 将生产 RTL 默认参数缩到
  `READ_HAZARD_COUNT=2 / WRITE_HAZARD_COUNT=2` 以便 hw-cbmc generic 实例快速
  转换和求解；实际生产 bridge 实例仍显式覆盖为 64-entry。该入口当前已通过并纳入
  稳定 formal regression。
- `formal/subsystem_dual_mmio_read_route/run_hw_cbmc.sh`：直接实例化实际
  `axi_llc_subsystem_dual.v` 的 native dual top smoke，覆盖 4B MMIO read 被接受后
  只能向 MMIO `AR` 口发出，且 `ARADDR/ARLEN/ARSIZE/ARBURST` 正确、不误发 DDR
  `AR/AW/W`。该入口当前已通过并纳入稳定 formal regression。
- `formal/subsystem_dual_mmio_read_response/run_hw_cbmc.sh`：直接实例化实际
  `axi_llc_subsystem_dual.v` 的 native dual top smoke，覆盖 MMIO `R` 被接受后 upstream
  `read_resp_valid/id/data` 端到端回收正确。该入口当前已通过并纳入稳定 formal
  regression。
- `formal/subsystem_dual_mmio_write_route/run_hw_cbmc.sh`：直接实例化实际
  `axi_llc_subsystem_dual.v` 的 native dual top smoke，覆盖 4B MMIO write 被接受后
  只能向 MMIO `AW/W` 口发出，且 `AWADDR/AWLEN/AWSIZE/AWBURST`、
  `WDATA/WSTRB/WLAST` 正确、不误发 DDR `AR/AW/W` 或 MMIO `AR`。该入口当前已通过并
  纳入稳定 formal regression。
- `formal/subsystem_dual_mmio_write_response/run_hw_cbmc.sh`：直接实例化实际
  `axi_llc_subsystem_dual.v` 的 native dual top smoke，覆盖 MMIO `B` 被接受后
  upstream `write_resp_valid/id/code` 端到端回收正确。该入口当前已通过并纳入稳定
  formal regression。
- `formal/subsystem_dual_ddr_read_mmio_write_independent/run_hw_cbmc.sh`：直接实例化实际
  `axi_llc_subsystem_dual.v` 的 native dual top smoke，覆盖 DDR 4B read 未返回 `R`、
  MMIO 4B write 未返回 `B` 时，两笔 direct-bypass 请求仍可被接受并分别发向 DDR
  `AR` 与 MMIO `AW/W`。该入口当前已通过并纳入稳定 formal regression。
- `formal/subsystem_dual_cache_refill_mmio_read_independent/run_hw_cbmc.sh`：直接实例化实际
  `axi_llc_subsystem_dual.v` 的 native dual top smoke，覆盖 MODE_CACHE 下 DDR cache
  miss/refill `AR` 被 `DDR_ARREADY=0` hold 时，4B MMIO read 仍可被接受并发出
  MMIO `AR`。该入口当前已通过并纳入稳定 formal regression。
- `formal/subsystem_dual_cache_refill_mmio_write_independent/run_hw_cbmc.sh`：直接实例化实际
  `axi_llc_subsystem_dual.v` 的 native dual top smoke，覆盖 MODE_CACHE 下 DDR cache
  miss/refill `AR` 被 `DDR_ARREADY=0` hold 时，4B MMIO write 仍可被接受并发出
  MMIO `AW/W`。该入口当前已通过并纳入稳定 formal regression。
- `formal/subsystem_dual_cache_refill_response/run_hw_cbmc.sh`：直接实例化实际
  `axi_llc_subsystem_dual.v` 的 native dual top smoke，覆盖 MODE_CACHE 下 DDR cache
  miss/refill `AR` 握手、DDR `R` 接收、`RREADY` 以及 upstream `read_resp_valid/id/data`
  回收。该入口当前已通过并纳入稳定 formal regression。
- `formal/subsystem_dual_cache_fill_hit_response/run_hw_cbmc.sh`：直接实例化实际
  `axi_llc_subsystem_dual.v` 的 native dual top smoke，覆盖 MODE_CACHE 下第一次 DDR
  cache miss/refill 返回后，第二次同地址 read 命中已安装 cacheline，不再发出第二个
  DDR `AR`，并回收新的 upstream response ID/data。该入口当前已通过并纳入稳定 formal
  regression。
- `formal/subsystem_dual_cache_full_write_hit_response/run_hw_cbmc.sh`：直接实例化实际
  `axi_llc_subsystem_dual.v` 的 native dual top smoke，覆盖 MODE_CACHE 下空 cache 的
  full-line write miss 直接安装 dirty line、不误发 DDR/MMIO 外部访问，写响应后同地址
  read 命中并返回写入数据。该入口当前已通过并纳入稳定 formal regression。
- `formal/subsystem_dual_cache_dirty_evict_writeback/run_hw_cbmc.sh`：直接实例化实际
  `axi_llc_subsystem_dual.v` 的 native dual top smoke，覆盖 MODE_CACHE 下连续三笔
  full-line write miss 触发 dirty victim DDR writeback，`AW/W` 地址、数据、strobe、last
  形状正确，不误发 DDR `AR` 或 MMIO `AR/AW/W`，且未收到 DDR `B` 前不提前返回第三笔
  写响应。该入口当前已通过并纳入稳定 formal regression。
- `formal/subsystem_dual_cache_dirty_evict_b_response/run_hw_cbmc.sh`：直接实例化实际
  `axi_llc_subsystem_dual.v` 的 native dual top smoke，覆盖 dirty victim writeback 的
  DDR `B` 接收、`BREADY` 和第三笔 upstream write response 回收；该 response 只能在
  DDR `B` 被接受或同拍接受后返回。该入口当前已通过并纳入稳定 formal regression。
- `formal/subsystem_dual_cache_dirty_evict_post_b_hit/run_hw_cbmc.sh`：直接实例化实际
  `axi_llc_subsystem_dual.v` 的 native dual top smoke，覆盖 dirty victim writeback 的
  DDR `AW/W/B` 完成后，第三笔地址 read 命中新安装的 dirty line，不再发 DDR `AR` 或
  MMIO 访问，并回收正确的 read `id/data`。该入口当前已通过并纳入稳定 formal regression。
- `formal/cache_ctrl_dirty_evict_writeback/run_hw_cbmc.sh`：直接实例化实际
  `llc_cache_ctrl.v`，覆盖 valid+dirty 满 set 下 full-line write miss 先发 dirty
  victim writeback，writeback response 后安装新 dirty line 并返回 write response。
- `formal/cache_ctrl_partial_write_miss_refill/run_hw_cbmc.sh`：直接实例化实际
  `llc_cache_ctrl.v`，覆盖空 set 下 partial write miss 先发整行 refill read，返回后
  按 offset/`WSTRB` merge 并安装 valid+dirty line。
  该入口当前已通过并纳入稳定 formal regression。
- `formal/cache_ctrl_read_miss_refill_response/run_hw_cbmc.sh`：直接实例化实际
  `llc_cache_ctrl.v`，覆盖空 set 下 read miss 先发整行 refill read，返回后安装
  valid+clean line，并返回 upstream read id/code/data。该入口当前已通过并纳入稳定
  formal regression。
- `formal/cache_ctrl_partial_write_hit_merge/run_hw_cbmc.sh`：直接实例化实际
  `llc_cache_ctrl.v`，覆盖 clean line 命中 partial write 时不发外部 memory request，
  按 offset/`WSTRB` merge 写数据，meta 变 dirty，并返回 upstream write id/code。该入口
  当前已通过并纳入稳定 formal regression。

已通过的 simulator smoke tests：

Linux boot smoke 不能只按退出码、`Difftest: error` 或 `DEADLOCK` 判定通过；每轮
5M commit gate 都应同时记录并比较 `sim-time(cycle)`、`ipc`、commit/load/store
计数和关键 memory latency。对 deterministic boot quick gate，若本轮改动理论上不应
影响性能，则 cycle/IPC 应尽量一致；任何 cycle 上升或 IPC 下降都需要给出百分比和
原因，超过约 1% 或无法解释时按性能回归处理。

- `make default BUILD_DIR=build_dual_axi_default_20260428 -j8`
- `./build_dual_axi_default_20260428/simulator -c 1000 baremetal/sha-test.bin`
- `make large BUILD_DIR=build_dual_axi_large_20260428 -j8`
- `./build_dual_axi_large_20260428/simulator -c 1000 baremetal/sha-test.bin`
- `make large BUILD_DIR=build_dual_axi_large_bpu_20260428 EXTRA_CXXFLAGS=-DCONFIG_BPU -j8`
- `./build_dual_axi_large_bpu_20260428/simulator -c 1000 baremetal/sha-test.bin`
- `make large BUILD_DIR=build_dual_axi_bootargs_large_bpu_20260428 EXTRA_CXXFLAGS=-DCONFIG_BPU -j8`
- `AXI_SUBMODULE_MODE=1 AXI_SUBMODULE_OFFSET=0 ./build_dual_axi_bootargs_large_bpu_20260428/simulator -c 300000 ../img/linux.bin`
  - `sim-time(cycle)=120719`
  - `committed=300001`
  - `ipc=2.485118`
  - `DTLB req/grant/resp=0/0/0`
  - `ITLB req/grant/resp=0/0/0`
- `AXI_SUBMODULE_MODE=1 AXI_SUBMODULE_OFFSET=0 ./build_dual_axi_bootargs_large_bpu_20260428/simulator -c 5000000 ../img/linux.bin`
  - `sim-time(cycle)=2079429`
  - `committed=5000005`
  - `ipc=2.404509`
  - `DTLB req/grant/resp=458/499/409`
  - `ITLB req/grant/resp=32/42/15`
- `AXI_SUBMODULE_MODE=1 AXI_SUBMODULE_OFFSET=0 ./build_dual_axi_bootargs_large_bpu_20260428/simulator -c 10000 baremetal/sha-test.bin`
  - `sim-time(cycle)=14615`
  - `committed=10000`
  - `ipc=0.684229`
  - `DTLB req/grant/resp=0/0/0`
  - `ITLB req/grant/resp=0/0/0`
- `make default BUILD_DIR=build_dual_axi_bootargs_default_20260428 -j8`
- `AXI_SUBMODULE_MODE=1 AXI_SUBMODULE_OFFSET=0 ./build_dual_axi_bootargs_default_20260428/simulator -c 1000 baremetal/sha-test.bin`
  - `sim-time(cycle)=4702`
  - `committed=1000`
  - `ipc=0.212675`
  - `DTLB req/grant/resp=0/0/0`
  - `ITLB req/grant/resp=0/0/0`
- 2026-05-02 在本轮 C++ 语义修正后重新构建并复测：
  `make large BUILD_DIR=build_dual_axi_semantics_20260502 EXTRA_CXXFLAGS=-DCONFIG_BPU -j8`
- `AXI_SUBMODULE_MODE=1 AXI_SUBMODULE_OFFSET=0 ./build_dual_axi_semantics_20260502/simulator -c 300000 ../img/linux.bin`
  - `sim-time(cycle)=120719`
  - `committed=300001`
  - `ipc=2.485118`
  - `DTLB req/grant/resp=0/0/0`
  - `ITLB req/grant/resp=0/0/0`
- `AXI_SUBMODULE_MODE=1 AXI_SUBMODULE_OFFSET=0 ./build_dual_axi_semantics_20260502/simulator -c 5000000 ../img/linux.bin`
  - `sim-time(cycle)=2079429`
  - `committed=5000005`
  - `ipc=2.404509`
  - `DTLB req/grant/resp=458/499/409`
  - `ITLB req/grant/resp=32/42/15`

早期 smoke tests 均达到 `MAX_COMMIT_INST=1000` 后正常退出，日志中未出现 `Difftest: error`。
最新 300k/5M Linux、10k large+BPU SHA 与 1k default SHA smoke 分别达到目标 commit
数后正常退出，同样未匹配到 `Difftest: error` 或 `DEADLOCK`。

这些 simulator smoke tests 依赖父仓库的临时适配改动，只用于证明当前 submodule 行为
没有立即破坏父仓库启动路径；后续接到最新版 simulator 父仓库时，父仓库侧适配需要重新做，
不把这部分作为 submodule 的长期交付内容。
