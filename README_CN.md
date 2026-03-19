# AXI Interconnect Kit（中文说明）

这是从原模拟器中抽离出的独立 AXI4 内存子系统。

## 范围

- 一套 AXI4 interconnect，对外提供简化上游端口：
  - `read_ports[4]`：`icache`、`dcache_r`、`uncore_lsu_r`、`extra_r`
  - `write_ports[2]`：`dcache_w`、`uncore_lsu_w`
- AXI4 router、SimDDR、MMIO bus、UART16550
- AXI4 路径上的可选共享统一 LLC

本仓库已经删除 AXI3 支持，现在是 AXI4-only。

## 拓扑

```text
读/写主设备
      |
      v
+----------------------+
| AXI_Interconnect     |
+----------------------+
      |
      v
+----------------------+
| AXI_LLC（可选）      |
+----------------------+
      |
      v
+----------------------+
| AXI_Router_AXI4      |
+----------------------+
    |            |
    | DDR区间    | MMIO区间
    v            v
+----------+   +---------------------+
| SimDDR   |   | MMIO_Bus + UART16550|
+----------+   +---------------------+
```

`AXI_Router_AXI4` 是显式层次：interconnect 负责仲裁和上游响应路由，
router 负责 AXI 侧地址译码。

## LLC 概要

`AXI_LLC` 位于 AXI4 interconnect 之后，建模共享统一缓存。

默认配置：

- `8MB`
- `64B` cache line
- `16-way`
- `4` 个 MSHR
- lookup latency `8`
- `PIPT`、`unified`、`NINE`
- 默认关闭 prefetch

当前语义：

- cacheable read 通过父模拟器提供的外部 SRAM 风格 `data/meta/repl` 表进行
  分配与回填。
- AXI4 interconnect 读前端支持 multiple outstanding：
  - 全局上限 `8`
  - 单个读 master 上限 `4`
- LLC 内部对 cacheable demand miss 的推进仍然更严格：
  - 同一个读 master 同时最多只能有一个由 LLC 正在处理的 cacheable miss
  - 其它 master 仍然可以继续占用剩余的全局读资源
  - bypass read 不受这个 same-master cacheable-miss 串行限制
- cacheable write 由 LLC 路径接管。
- cacheable 的 partial write miss 采用“先回填旧 line，再按字节 merge，最后以
  dirty line 安装”的语义，不会直接在全零 line 上 merge。
- `bypass read` 会先查 LLC：
  - hit 直接返回 resident line 最新值
  - miss 下发到下游且不分配 LLC
- `bypass write` 是 write-through maintenance：
  - hit 更新 resident line，但不设置 `DIRTY`
  - miss 直接下发到下游，不分配 LLC
- 子行写按 `addr % line_bytes` 合并。
- `invalidate_all` 通过 epoch 丢弃 stale refill install，但不会破坏原始
  demand miss 的响应返回。

### AXI4 写并发

当前 AXI4 写路径设计是：

- interconnect 前端最多接收 `MAX_WRITE_OUTSTANDING` 个 pending write。
- 非 LLC 路径可直接按 AXI ID 将 B 响应路由回上游。
- LLC 路径内部具备：
  - 按 master 划分的 pending write queue
  - 每个写 master 一个 active write context
  - 共享 lookup engine
  - 共享 victim writeback 资源
  - 共享下游 memory write port
- 同一个 master 的后继写，仍然要等前一个写响应槽被消费后才继续提升。

因此，`MAX_WRITE_OUTSTANDING` 表示的是 interconnect 前端的排队上界，
不是“interconnect 状态 + LLC 内部状态”合并后的总写状态上界。

这就是当前的 correctness 收尾边界。后续如果还要继续追性能，重点会是
进一步提高内部写资源并行度，而不是再回头修基本的一致性与顺序语义。

## 测试分层

- `P0`：纯组件级确定性单测
  - LLC 读写 hit/miss
  - bypass read/write
  - victim writeback
  - maintenance
  - stale refill 保护
  - write queue 边界
- `P1`：AXI4 + LLC + SimDDR 小型集成确定性回归
  - cacheable+bypass 共存
  - queued write
  - maintenance interlock
  - invalidate-all epoch 行为
- `P2`：固定种子混合压力
  - 混合一致性压力
  - refill / maintenance / writeback 竞争

已验证编译器：

- `qm` 环境默认工具链
- `/usr/bin/g++`
- `/workspace/S/daiyihao/miniconda3/envs/qm/bin/x86_64-conda-linux-gnu-c++`

## 接口文档

- [docs/interfaces.md](docs/interfaces.md)
- [docs/interfaces_CN.md](docs/interfaces_CN.md)

## 主要文件

```text
.
├── CMakeLists.txt
├── README.md / README_CN.md
├── axi_interconnect/
│   ├── include/
│   ├── AXI_Interconnect.cpp
│   ├── AXI_LLC.cpp
│   ├── AXI_Router_AXI4.cpp
│   ├── axi_interconnect_test.cpp
│   ├── axi_interconnect_llc_axi4_test.cpp
│   └── axi_llc_test.cpp
├── sim_ddr/
│   ├── include/
│   ├── SimDDR.cpp
│   └── sim_ddr_test.cpp
├── mmio/
│   ├── include/
│   ├── MMIO_Bus_AXI4.cpp
│   ├── UART16550_Device.cpp
│   └── mmio_router_axi4_test.cpp
└── demos/
    └── axi4_smoke.cpp
```

## 当前收尾结论

本仓库当前已经收敛到 AXI4-only 的 correctness 和回归覆盖闭环。父模拟器
层面的联调问题，应优先在主模拟器中单独定位，除非根因能够明确指回本子模块。
