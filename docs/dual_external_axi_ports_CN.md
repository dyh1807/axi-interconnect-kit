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

当前 RTL 尚未完成：

- 最终 `axi_llc_subsystem` 顶层还没有切到双外部 AXI 口。
- 全局 read/write outstanding 32-entry 共享计数尚未接入；当前仍受底层 bridge 既有
  per-port outstanding 限制约束。
- 同地址 `AR/AW` hazard gate 尚未在 native dual bridge 层统一实现。
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

当前 C++ 已具备集成双外部 AXI 口的基本调度结构：

- `axi_ddr_io` 和 `axi_mmio_io` 已经拆开，地址分类和事务形状已经按双口语义运行。
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
- `tb_axi_llc_subsystem_dual_mmio_contract.v` 固化了 mode1 普通 MMIO 读写
  `*_bypass=0` 时也必须走 `mmio_axi_*`、不得驱动 `ddr_axi_*`、response 回到原
  upstream ID。

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

- `axi_interconnect_dual_port_test`：30 passed, 0 failed。
  覆盖 DDR/MMIO 路由、MMIO 大读写阻塞、同 line AR/AW hazard gate、legacy LLC
  MMIO backing 读写、LLC-MMIO bypass，以及非 LLC-on 模式下的写路径地址分类、
  DDR 256-bit 对齐/`wstrb` 移位、mode2 mapped-window 写捕获和 mode3 bypass 写捕获。
  最新补充覆盖：同 line AR 等待 B、不同 port/不同 line DDR/MMIO 不串行、LLC mem
  侧 read/write request ready 受同 line R/B 约束。
  standalone dual-port test target 显式使用 32-entry read outstanding 和 32-entry
  write outstanding，并覆盖 read/write outstanding 共享口内预算、读写预算相互独立。
  LLC-on 下的 32-bit MMIO read 直接 bypass LLC core stage，并在 direct response
  待返回时 backpressure 同 master 的 LLC read response。
  LLC-on 下的 32-bit MMIO write 直接 bypass LLC core stage，并覆盖 direct B
  response 与 LLC mem B response 的 owner 分离。
- `axi_interconnect_llc_axi4_test`：历史版本 29 passed, 0 failed；本轮未在 standalone
  submodule CMake 下复测，因为该 test env 链接 `SimDDR.cpp`，仍依赖父仓库
  `PhysMemory.h`。

已通过的 RTL VCS targeted tests：

- `tb_axi_llc_axi_dual_port_router_contract`
- `tb_axi_llc_axi_bridge_dual_contract`

已通过的 simulator smoke tests：

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

早期 smoke tests 均达到 `MAX_COMMIT_INST=1000` 后正常退出，日志中未出现 `Difftest: error`。
最新 300k/5M Linux、10k large+BPU SHA 与 1k default SHA smoke 分别达到目标 commit
数后正常退出，同样未匹配到 `Difftest: error` 或 `DEADLOCK`。

这些 simulator smoke tests 依赖父仓库的临时适配改动，只用于证明当前 submodule 行为
没有立即破坏父仓库启动路径；后续接到最新版 simulator 父仓库时，父仓库侧适配需要重新做，
不把这部分作为 submodule 的长期交付内容。
