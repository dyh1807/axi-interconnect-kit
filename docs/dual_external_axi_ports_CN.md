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

## EC 规划

后续形式化 EC 应以本文档为共同规格，比较 C++ reference 和 RTL 在以下方面的一致性：

- 地址分类结果：DDR、MMIO、mapped-LLC local。
- AR/AW/W/R/B 对外握手事件。
- outstanding 上限和 ID/response 归属。
- 小请求对齐、截取、`wstrb` 移位。
- 同地址 AR/AW hazard gate。

本阶段先收敛 C++ reference，再迁移 RTL，最后接入 `hw-cbmc` 进行 C++/RTL 等价性检查。

## C++ Reference 当前实现状态

截至本轮 C++ 修改，`AXI_Interconnect` 已经拆出两个 downstream AXI 口：

- `axi_ddr_io`：DDR/SDRAM 口。
- `axi_mmio_io`：MMIO 口。
- `axi_io` 暂时保留为 `axi_ddr_io` 的兼容别名，避免旧测试/旧调用点立刻失效。

当前实现策略：

- 地址 `>= CONFIG_AXI_KIT_DDR_BASE` 走 DDR 口；parent simulator profile 中该值为 `0x4000_0000`。
- active LLC mapped-window 仍优先走 LLC 本地映射。
- 其它地址走 MMIO 口，并强制为 32-bit、1 beat 事务。
- DDR 口小于 32B 的请求对齐到 32B beat，读响应在 interconnect 内截取，写请求同步移位 `wdata/wstrb`。
- DDR 口 64B cacheline 维持 2 beat、同一 AXI transaction。
- 同 line AR/AW hazard gate 已加入，覆盖已发 AR、latched AR、pending R、latched AW、active W、pending B。

## Simulator Reset PC 约束

原 simulator 复位 PC 为 `0x0000_0000`，并通过低地址 boot stub 跳到 `0x8000_0000`。在新地址图下，`0x0000_0000` 属于 MMIO 口，而 MMIO 口只支持 32-bit、1 beat，不适合继续承载 64B ICache line fill。

因此 parent simulator profile 当前显式定义：

- `RESET_PC = 0x8000_0000`

并同步修改 difftest/oracle，使 C++ DUT、reference 和 oracle 从同一 DDR/RAM 起点开始执行。低地址 boot stub 仍保留在 backing memory 中，但不再作为默认 AXI ICache 启动路径。

## 已完成的最小验证

已通过的 targeted tests：

- `axi_interconnect_dual_port_test`：3 passed, 0 failed。
- `axi_interconnect_llc_axi4_test`：29 passed, 0 failed。

已通过的 simulator smoke tests：

- `make default BUILD_DIR=build_dual_axi_default_20260428 -j8`
- `./build_dual_axi_default_20260428/simulator -c 1000 baremetal/sha-test.bin`
- `make large BUILD_DIR=build_dual_axi_large_20260428 -j8`
- `./build_dual_axi_large_20260428/simulator -c 1000 baremetal/sha-test.bin`
- `make large BUILD_DIR=build_dual_axi_large_bpu_20260428 EXTRA_CXXFLAGS=-DCONFIG_BPU -j8`
- `./build_dual_axi_large_bpu_20260428/simulator -c 1000 baremetal/sha-test.bin`

以上 smoke tests 均达到 `MAX_COMMIT_INST=1000` 后正常退出，日志中未出现 `Difftest: error`。
