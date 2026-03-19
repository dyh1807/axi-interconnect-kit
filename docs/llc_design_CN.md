# AXI_LLC 详细设计说明（中文）

本文档描述 `axi-interconnect-kit` 当前 AXI4-only 版本中的 `AXI_LLC` 设计与语义边界。

## 1. 术语约定

- `upstream`：连接到 `AXI_Interconnect::read_ports[]` / `write_ports[]` 的请求来源，以及返回给这些 master 的响应路径。
- `downstream`：位于 interconnect 之下、面向 DDR 或 MMIO 的路径，包括 `AXI_Router_AXI4`、`SimDDR` 与 MMIO 设备。
- `cacheable`：由 LLC 接管一致性与驻留所有权的请求。
- `bypass`：不在 LLC 中分配所有权的请求。读请求允许命中 resident line；写请求采用 write-through maintenance 语义。

## 2. 拓扑位置与职责

当前子模块的主拓扑是：

```text
upstream read/write masters
          |
          v
 +----------------------+
 | AXI_Interconnect     |
 +----------------------+
          |
          v
 +----------------------+
 | AXI_LLC (optional)   |
 +----------------------+
          |
          v
 +----------------------+
 | AXI_Router_AXI4      |
 +----------------------+
      |             |
      | DDR range   | MMIO range
      v             v
 +----------+   +---------------------+
 | SimDDR   |   | MMIO_Bus + UART16550|
 +----------+   +---------------------+
```

`AXI_Interconnect` 负责：

- upstream 读写端口仲裁
- read outstanding / write pending 管理
- LLC 维护接口的接入
- AXI4 channel 组织与响应回送

`AXI_LLC` 负责：

- shared unified cache 的 hit/miss 判定
- cacheable read / write 的驻留与替换
- bypass read / write 的语义分流
- dirty victim writeback
- `invalidate_line` / `invalidate_all` maintenance

## 3. 组织方式

### 3.1 地址与容量

当前默认配置：

- capacity: `8MB`
- line size: `64B`
- associativity: `16-way`
- lookup latency: `8`
- MSHR: `4`

容量、line size、way 数、MSHR 数都由 `AXI_LLCConfig` 提供，属于运行时配置而不是模板常量。

### 3.2 表结构

当前 LLC 采用外置 SRAM 风格查表接口，逻辑上分为三类表：

- `data` 表：每个 way 的整条 cache line 数据
- `meta` 表：`tag + flags`
- `repl` 表：每个 set 的替换状态

`meta.flags` 当前定义：

- `VALID`
- `DIRTY`
- `PREFETCH`

### 3.3 寻址方式

当前设计采用 `PIPT`：

- lookup / resident ownership / replacement 都基于物理地址 line 粒度
- 不依赖虚地址别名语义

## 4. 替换策略

当前 `repl` 表维护的是每个 set 的“下一个 victim way”，实现上是简单 round-robin：

- hit 后：`repl_next_way = (hit_way + 1) % ways`
- miss/install 后：`repl_next_way = (installed_way + 1) % ways`

因此这不是 LRU / PLRU，而是低复杂度、确定性的 round-robin 近似策略。

优点：

- 状态极小
- 单元测试容易做 reviewer-visible 的确定性断言

局限：

- 性能上不如更复杂的替换策略
- 未来若要继续优化，可把 `repl` 表升级为 tree-PLRU 或更细的 replacement state，而不需要改 upstream/downstream 接口

## 5. 读请求语义

### 5.1 cacheable read

流程：

1. upstream read 被 interconnect 捕获
2. LLC 发起 `data/meta/repl` lookup
3. hit：直接从 resident line 返回
4. miss：分配 read MSHR，向 downstream 发起整 line refill
5. refill 返回后安装 line，再返回 upstream read response

当前并发边界：

- AXI4 interconnect 读侧支持 multiple outstanding
- 但 LLC 对 cacheable demand miss 更保守：
  - 同一 read master 同时最多一个被 LLC actively owned 的 cacheable demand miss
  - 不同 master 之间仍可共享全局读资源

### 5.2 bypass read

语义不是“完全绕过 LLC 可见性”，而是：

- hit resident line：直接返回 LLC 中最新值
- miss：下发 downstream，不分配 LLC line

这样可以避免 bypass read 在同地址上读到 stale memory，而 resident line 中已经有更新值。

## 6. 写请求语义

### 6.1 cacheable write

cacheable write 始终由 LLC 接管，不会绕开 LLC 直接下发。

#### full-line write miss

如果请求覆盖整条 line：

- 不需要先 refill 旧 line
- 可直接构造新 line
- 若 victim dirty，则先写回 victim，再安装新 line

#### sub-line write miss

如果请求小于 `cache line`：

- 先对旧 line 发起 refill
- refill 返回后按 `wstrb` 和 `addr % line_bytes` 做 byte merge
- 以 `DIRTY` line 安装到 LLC
- 不能直接在全零 line 上 merge

这条语义是当前 round4 review 后显式补强和回归覆盖的重点。

### 6.2 bypass write

当前 bypass write 采用 write-through maintenance 语义：

- hit resident line：
  - 更新 resident line 数据
  - 不设置 `DIRTY`
- miss：
  - 直接下发 downstream
  - 不分配 LLC line

这种语义适合 uncacheable / maintenance 风格写入，避免无意义占用 LLC 容量。

## 7. dirty line 与 victim writeback

当前 LLC 支持 dirty resident line。

当 install 新 line 需要覆盖 dirty victim 时：

1. 先把 victim line 整条写回 downstream memory
2. 收到 downstream write response 后
3. 再安装新 line / 完成 pending write 或 refill commit

这条顺序在当前组件测试和 AXI4+LLC+SimDDR 集成测试里都有覆盖，包括：

- dirty victim writeback 地址正确
- dirty victim writeback 数据正确
- partial write miss + dirty victim 的交错

## 8. 多 master 读写竞争

### 8.1 读侧

interconnect 读侧支持多个 outstanding，并带：

- 全局 read outstanding 上限
- per-read-master 上限

LLC 内部则进一步限制 cacheable demand miss 的同 master 并行度，以降低状态机复杂度。

### 8.2 写侧

当前实现已经不是“单一写入口串行捕获”：

- interconnect upstream 侧可接收多个 pending write
- LLC 内部维护：
  - per-write-master pending queue
  - 每个写 master 一个 active write context
  - 共享 lookup engine
  - 共享 victim writeback 资源
  - 共享 downstream memory write port

因此当前是：

- 多 active write context
- 但共享执行资源仍会限制真正的并发推进深度

### 8.3 same-master 顺序

同一 write master 的后继写不能越过前一个尚未消费的 write response slot。

目的：

- 保证 same-master 可见顺序更保守
- 避免 response ID / resp slot 交错导致的歧义

## 9. maintenance 语义

### 9.1 `invalidate_line`

`invalidate_line` 是 line 精确维护，不是 set 级或全局维护。

接受条件较严格；若目标 line 与以下状态冲突，则拒绝：

- inflight miss
- active write context
- queued write
- write lookup
- victim writeback
- same-cycle upstream write accept/capture 冲突

调用方必须保持请求，直到看到 `invalidate_line_accepted` 脉冲。

### 9.2 `invalidate_all`

当前 `invalidate_all` 采用保守 barrier 语义：

- 调用方必须保持请求，直到看到 `invalidate_all_accepted`
- pending 期间：
  - 阻止新的 upstream LLC 请求进入
  - 允许已捕获的 clean LLC-path work 排空
- 只有在不存在以下 hazard 时才接受：
  - dirty resident line
  - dirty victim writeback
  - write-side hazard

### 9.3 stale refill 保护

`invalidate_all` 被接受后会推进一个 epoch。

旧 epoch 的 clean refill install 在返回时会被丢弃，不允许 stale line 因为延迟返回而重新复活到 LLC 中。

## 10. corner cases 与当前已覆盖点

当前测试面已显式覆盖这些 corner cases：

- cacheable partial write miss 保留未触及字节
- partial write miss + dirty victim writeback
- bypass read 命中 resident line 时返回最新值
- bypass write hit 更新 resident line 但不置 dirty
- bypass write miss 不分配 LLC
- `invalidate_line` 不误伤同 set 其它 way
- `invalidate_line` 与 same-cycle upstream write accept/capture 互锁
- `invalidate_all` busy pulse 不是 silent accept
- `invalidate_all` hold-until-accept 合同
- `invalidate_all` 接受后 stale refill 不会重新安装
- victim writeback + maintenance + demand miss 三方交错

## 11. 当前阶段边界

当前 AXI4-only 版本的目标是 correctness-first：

- 机制已经覆盖 shared LLC 的主要正确性语义
- 维护合同可以被外部观察与回归验证
- 测试面已覆盖 P0 / P1 / P2 当前阶段需要的 deterministic 与 fixed-seed 场景

仍属于未来性能阶段、而非当前 correctness blocker 的事项包括：

- 更激进的 replacement policy
- 更深的写执行资源并行
- 更复杂的 prefetch 策略

