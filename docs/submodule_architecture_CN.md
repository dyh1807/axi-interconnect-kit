# AXI/LLC Submodule 架构与接口规格

本文档是当前 submodule 的入口级说明，覆盖 C++ golden reference、RTL 主线 top、
地址映射、双外部 AXI 口、维护约束、SRAM macro 和验证边界。

## 当前主线

当前工作主线不是旧的“单 AXI 口再接外部 router”，而是 integrated dual external
AXI port：

- 上游仍是 CPU core 侧的简化多 master read/write 接口。
- 下游直接拆成 DDR/SDRAM AXI 口和 MMIO AXI 口。
- DDR/SDRAM 口固定按 256-bit beat 发请求。
- MMIO 口只允许 32-bit / 1 beat read/write。
- 读 outstanding 和写 outstanding 各自共享全局预算；读写预算相互独立。
- C++ reference 和 RTL 都应沿用同一套地址分类、issue shape、ready/response
  约束，不允许为了验证另写一套模型。

旧单 AXI 口与 `AXI_Router_AXI4` 仍保留用于历史测试、demo 或 bring-up，但不作为当前
性能/时序主线。

## 总体结构

### C++ reference

```text
CPU-side request sources
  read_ports[0]  ICache
  read_ports[1]  DCache read
  read_ports[2]  Uncore LSU read
  read_ports[3]  Extra read
  write_ports[0] DCache write
  write_ports[1] Uncore LSU write
        |
        v
+------------------------------+
| AXI_Interconnect             |
| - upstream arbitration        |
| - shared R/W outstanding      |
| - LLC/runtime mode control    |
| - DDR/MMIO route + AXI shape  |
+------------------------------+
        |                                  |
        | cacheable / mapped-window path   | direct DDR/MMIO path
        v                                  v
+------------------------------+    +-------------------------------+
| AXI_LLC                      |    | AXI channel state             |
| - data/meta/valid/repl model |    | - axi_ddr_io                  |
| - MSHR/refill/writeback      |    | - axi_mmio_io                 |
| - invalidate_line/all        |    | - axi_io legacy alias to DDR  |
+------------------------------+    +-------------------------------+
        |                                  |
        +------------------+---------------+
                           |
              +------------+------------+
              |                         |
              v                         v
       DDR/SDRAM AXI              MMIO AXI
       256-bit beat               32-bit beat
```

### RTL

```text
axi_llc_subsystem_dual
|-- axi_llc_subsystem_compat
|   |-- request capture / accepted pulse / ID bookkeeping
|   |-- shared read/write outstanding slots
|   |-- direct-bypass slots and response queues
|   `-- axi_llc_subsystem_core
|       |-- axi_reconfig_ctrl
|       |-- llc_valid_ram        (regfile bit table)
|       |-- llc_repl_ram         (regfile replacement table)
|       |-- llc_data_store       (SMIC12 SRAM or generic fallback)
|       |-- llc_meta_store       (SMIC12 SRAM or generic fallback)
|       |-- llc_cache_ctrl       (mode1 cache)
|       `-- llc_mapped_window_ctrl (mode2 local window)
`-- axi_llc_axi_bridge_dual
    |-- DDR-side axi_llc_axi_bridge  (256-bit beat)
    |-- MMIO-side axi_llc_axi_bridge (32-bit beat)
    |-- response mux
    `-- AR/AW same-line hazard scoreboard
```

当前 RTL signoff top 是 `rtl/src/axi_llc_subsystem_dual.v`。旧
`rtl/src/axi_llc_subsystem.v` 是单 AXI 口兼容 top。

## 地址空间

| 区间 | 归属 | 说明 |
|---|---|---|
| `addr >= 0x4000_0000` | DDR/SDRAM AXI 口 | AXI 口不区分 SDRAM 与 DDR；系统级可在更下游再分。 |
| `0x3000_0000..0x303f_ffff` | mode2 LLC mapped window | 4MB local LLC storage window，offset 默认按需求使用 `0x3000_0000`。 |
| 其它地址 | MMIO AXI 口 | 在 mode2 地址映射模式下，mapped window 不属于 MMIO；非 mapped-window 地址按 route helper 分类。 |

实现备注：

- RTL `DDR_BASE` 默认 `32'h4000_0000`。
- C++ standalone 默认值可由 build/config 覆盖；dual-port 测试和父仓库集成应使用
  `CONFIG_AXI_KIT_DDR_BASE=0x40000000`。
- 当前 C++ route helper 和 RTL route helper 都以 `addr >= DDR_BASE` 选择 DDR 口；
  mapped-window 命中时先进入本地 LLC window，不下发 DDR/MMIO AXI。

## 上游接口

上游接口是简化的 CPU-side request/response bundle，不是 AXI 五通道。

| 类别 | 数量 | 主要信号 | 说明 |
|---|---:|---|---|
| read master | 4 | `valid/ready/accepted/accepted_id/addr/total_size/id/bypass` | `total_size = bytes - 1`，read response 最大 256B。 |
| write master | 2 | `valid/ready/accepted/addr/wdata/wstrb/total_size/id/bypass` | 写 payload 当前最大 64B。 |
| read response | 4 | `valid/ready/data/id` | `data` 宽度为 2048-bit，用低字节承载实际返回数据。 |
| write response | 2 | `valid/ready/id/resp` | `resp` 使用 AXI response code。 |

Master 编号：

| read master | 编号 |
|---|---:|
| ICache | 0 |
| DCache read | 1 |
| Uncore LSU read | 2 |
| Extra read | 3 |

| write master | 编号 |
|---|---:|
| DCache write | 0 |
| Uncore LSU write | 1 |

## 下游双 AXI 口

### DDR/SDRAM 口

- 数据宽度：256-bit (`32B`)。
- `AR/AW` 固定使用 256-bit beat size，`ARSIZE/AWSIZE=5`。
- 小于等于 32B 的 DDR read/write 使用 1 beat，对齐到 32B 边界后切片或用
  32-bit `WSTRB` 控制字节。
- 64B cacheline read/write 使用同一 transaction 的 2 beat，`ARLEN/AWLEN=1`。
- 当前 cacheline 上限是 64B；如果未来引入更大 line，需要同步扩展 C++ helper、
  RTL pack/merge、trace 和 formal。

### MMIO 口

- 数据宽度：32-bit (`4B`)。
- 只允许 `total_size == 3` 的 4B read/write。
- `ARLEN/AWLEN=0`，`ARSIZE/AWSIZE=2`，`BURST=INCR`。
- 不支持 MMIO cacheline 或 sub-word/over-4B burst 逃逸到外部 MMIO 口；相关 unsupported
  行为由 C++ tests、RTL contract 和 formal helper 覆盖。

## Outstanding 和 ID 规则

当前 dual-port profile 的目标配置：

- 读 outstanding 全局最多 32。
- 写 outstanding 全局最多 32。
- 读和写预算相互独立，因此可以同时存在 32 个 read outstanding 和 32 个 write outstanding。
- DDR 和 MMIO 两个外部口共享上面的读/写预算，不是每个口各自再给 32。
- AXI ID 当前使用 6-bit；C++ 中 `axi_ddr_io` / `axi_mmio_io` 共享同一套 ID 分配语义，
  RTL 由 compat/top 层维护全局预算，bridge 内部保留 per-port local pending 结构。
- 上游 `id` 是 CPU-side transaction ID；RTL 内部 `SLOT_ID_BITS`/AXI ID 是 lower issue
  bookkeeping，不能把二者混为同一个命名空间。

Standalone CMake 默认值可能较保守；需要跑 dual-port profile 时应显式使用：

```text
AXI_KIT_MAX_OUTSTANDING=32
AXI_KIT_MAX_READ_OUTSTANDING_PER_MASTER=32
AXI_KIT_MAX_WRITE_OUTSTANDING=32
AXI_KIT_SIM_DDR_BEAT_BYTES=32
AXI_KIT_DDR_BASE=0x40000000
```

RTL 对应默认值在 `rtl/include/axi_llc_params.vh`：

```text
AXI_LLC_MAX_OUTSTANDING=32
AXI_LLC_MAX_READ_OUTSTANDING_PER_MASTER=32
AXI_LLC_MAX_WRITE_OUTSTANDING=32
AXI_LLC_AXI_ID_BITS=6
AXI_LLC_AXI_DATA_BYTES=32
```

## AR/AW 顺序和 response ready 约束

这些约束是设计语义的一部分，不是单纯 testbench 假设：

1. Interconnect/LLC 已经向某个 line 发出 `AR` 后，在对应 `R` 最后一拍返回之前，不得向
   同一 line 发出 `AW`。
2. Interconnect/LLC 已经向某个 line 发出 `AW` 后，在对应 `B` 返回之前，不得向同一
   line 发出 `AR`。
3. 不允许形成“`AR` 与 `AW` 都已发出，随后等 `B` 返回后清 buffer，最后才接收 `R`”的
   依赖顺序。外部 `RREADY/BREADY` 不能被 held upstream response 或 pending maintenance
   错误回压。
4. DDR 和 MMIO 是不同地址域；不同 line、不同端口的请求不应因无关端口 response stall
   被退化成全局串行。

RTL 中 `axi_llc_axi_bridge_dual.v` 的 same-line hazard scoreboard 覆盖外部 AXI
`AR/AW` issue 边界；C++ 中对应逻辑由 dual-port route/issue/response 状态机和 helper
测试覆盖。

## LLC mode 与 maintenance

| mode | 名称 | 行为 |
|---:|---|---|
| `0` | LLC_OFF | 请求强制走 bypass/direct 下游路径，不新分配 LLC line。 |
| `1` | LLC_ON | 正常 cache path；cacheable 请求可 hit/miss/refill/install。 |
| `2` | mapped-window | `[offset, offset + 4MB)` 命中本地 direct-mapped LLC window；窗口外请求强制 bypass。 |
| `3` | LLC_OFF alias | 与 mode0 同类处理。 |

Maintenance 约束：

- `invalidate_all_valid` / `invalidate_line_valid` 必须保持到对应 `*_accepted`。
- `invalidate_all` 只在系统 quiescent 且不存在 dirty resident line、dirty victim
  writeback、写侧 hazard 时接受。
- `invalidate_line` 是目标 line 维护；同 line read/write/refill/writeback/handoff
  hazard 未清空时不能接受。
- mode/offset 变化遵循 `block new accepts -> drain old work -> valid-sweep -> activate`。

## SRAM 与时序模型

RTL 当前默认：

- `USE_SMIC12_STORES=1`。
- data store 使用 SMIC12 `4096x256 SASS` macro。
- meta store 使用 SMIC12 `4096x16 SASS` macro。
- `TABLE_READ_LATENCY=3`，用于给 SRAM Q 到 consumer/capture 留出多周期结构空间。
- valid/repl 表保持 regfile，不应为了规避 shared-server OOM 而改成 SRAM macro。

综合要求：

- full DC signoff 使用 SMIC12 `9T20` RVT/LVT 标准单元。
- data/meta SRAM `.db` 必须作为 link library 加载。
- 产物必须保留 reports、QoR、timing、area、constraint、power、DDC、netlist、DB、
  SDC、SDF、SPF。
- 详见 `rtl/dc/README_CN.md` 和 `docs/dual_axi_goal_audit_20260506_CN.md`。

## 验证分层

当前验证不是声明完整端到端形式 EC 已完成，而是按层分解：

- C++ unit/integration tests：验证 reference 自身语义和 dual-port issue shape。
- C++ trace -> RTL replay：用实际 `AXI_Interconnect` 生成 trace，再由实际 RTL
  contract testbench 消费。
- RTL VCS contracts：覆盖 top/compat/core/bridge 的 directed 行为。
- hw-cbmc stable manifest：覆盖生产 helper 和若干 actual RTL bounded smoke。
- Linux quick perf/difftest：large + `CONFIG_BPU` 的 300k/5M gate，检查功能和
  cycles/IPC 是否退化。
- DC/timing：使用 9T20 + SMIC12 SRAM 的 full/top 1GHz signoff。

当前短期 EC directed/category gate 已冻结；不再开放式追加同类手写 case。真正仍 open
的是长期端到端 C++/RTL 形式 EC、full DC/timing signoff、以及 production 路径变化后的
长期 Linux/image 回归。

## 推荐阅读顺序

1. 本文档。
2. `README_CN.md` 或 `README.md`。
3. `docs/interfaces_CN.md`。
4. `rtl/README_CN.md`。
5. `docs/dual_external_axi_ports_CN.md`。
6. `docs/dual_axi_ec_closure_plan_CN.md`。
7. `docs/formal_table_oracle_cutpoints_CN.md`。
8. `rtl/dc/README_CN.md`。
