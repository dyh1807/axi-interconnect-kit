# AXI Interconnect Kit（中文说明）

这是从原模拟器中抽离出的独立 AXI 子系统，可单独编译运行。

## 组件组成

- AXI4 路径：`interconnect + AXI4 router + SimDDR + MMIO bus + UART16550`
- AXI3 路径：`interconnect + AXI3 router + SimDDR + MMIO bus + UART16550`
- 上游 CPU 简化主设备端口：
  - 读主设备 `4` 个（`icache` / `dcache_r` / `mmu` / `extra_r`）
  - 写主设备 `2` 个（`dcache_w` / `extra_w`）

## 命名选择：为什么叫 `interconnect`

`bridge` 通常表示点到点协议转换。  
本项目承担的是多主设备仲裁、地址路由和响应分发，更准确的名字是 `interconnect`。

## 连接拓扑（READ 路径）

```
读主设备（4个）
  M0 icache, M1 dcache_r, M2 mmu, M3 extra_r
            |
            v
   +----------------------+
   | AXI_Interconnect     |  （上游简化接口 -> AXI总线）
   +----------------------+
            |
            v
   +----------------------+
   | AXI_Router_AXI4/AXI3 |  （按地址选择目标）
   +----------------------+
        |            |
        | DDR区间    | MMIO区间
        v            v
 +-------------+  +---------------------+
 | SimDDR      |  | MMIO_Bus + UART16550|
 | (slave #0)  |  | (slave #1)          |
 +-------------+  +---------------------+
```

这里的 `AXI_Router_AXI4/AXI3` 是明确的独立层，不是 `interconnect` 内部细节：
- `AXI_Interconnect`：负责多主设备仲裁、上游请求/响应调度。
- `AXI_Router_AXI4/AXI3`：负责 AXI 侧地址译码与目标从设备路径选择。

## 连接拓扑（WRITE 路径）

```
写主设备（2个）
  M0 dcache_w, M1 extra_w
            |
            v
   +----------------------+
   | AXI_Interconnect     |  （AW/W/B 调度与响应路由）
   +----------------------+
            |
            v
   +----------------------+
   | AXI_Router_AXI4/AXI3 |  （AW/W/B 目标选择）
   +----------------------+
        |            |
        | DDR区间    | MMIO区间
        v            v
 +-------------+  +---------------------+
 | SimDDR      |  | MMIO_Bus + UART16550|
 | (slave #0)  |  | (slave #1)          |
 +-------------+  +---------------------+
```

写路径（`AW/W/B`）同样分层：
- `AXI_Interconnect` 负责上游写端口仲裁和写响应分发。
- `AXI_Router_AXI4/AXI3` 按地址映射选择 DDR 或 MMIO 目标。

## 接口信号文档

详细信号列表见：

- `docs/interfaces.md`（英文）
- `docs/interfaces_CN.md`（中文）

内容包括：

- Interconnect 上游接口（`read_ports[4]`、`write_ports[2]`）
- AXI3 五通道信号（`AW/W/B/AR/R`，256-bit 数据）
- AXI4 五通道信号（`AW/W/B/AR/R`，32-bit 数据）

## 项目目录树与文件职责

```text
.
├── CMakeLists.txt
├── Makefile
├── README.md / README_CN.md
├── include/
├── axi_interconnect/
│   ├── include/
│   ├── AXI_Interconnect.cpp
│   ├── AXI_Interconnect_AXI3.cpp
│   ├── AXI_Router_AXI4.cpp
│   ├── AXI_Router_AXI3.cpp
│   ├── axi_interconnect_test.cpp
│   └── axi_interconnect_axi3_test.cpp
├── sim_ddr/
│   ├── include/
│   ├── SimDDR.cpp
│   ├── SimDDR_AXI3.cpp
│   ├── sim_ddr_test.cpp
│   └── sim_ddr_axi3_test.cpp
├── mmio/
│   ├── include/
│   ├── MMIO_Bus_AXI4.cpp
│   ├── MMIO_Bus_AXI3.cpp
│   ├── UART16550_Device.cpp
│   ├── mmio_router_axi4_test.cpp
│   └── mmio_router_axi3_test.cpp
├── demos/
│   ├── axi4_smoke.cpp
│   ├── axi3_smoke.cpp
│   └── single_cycle/
│       ├── include/
│       ├── src/
│       └── third_party/softfloat/softfloat.a
├── docs/
└── .codex/skills/
```

顶层文件：
- `CMakeLists.txt`：定义库/测试/demo 目标与构建开关。
- `Makefile`：对 CMake 构建流程的便捷封装入口。
- `README.md` / `README_CN.md`：英文/中文说明文档。
- `.gitignore`：忽略构建产物和生成文件。

`include/`：
- `include/axi_interconnect_compat.h`：给父项目接入使用的兼容辅助定义。
- `include/axi_mmio_map.h`：DDR/MMIO 地址映射常量定义。

`axi_interconnect/`：
- `axi_interconnect/include/AXI_Interconnect.h`：AXI4 interconnect 类与接口定义。
- `axi_interconnect/include/AXI_Interconnect_AXI3.h`：AXI3 interconnect 类与接口定义。
- `axi_interconnect/include/AXI_Interconnect_IO.h`：上游简化读写端口结构定义。
- `axi_interconnect/include/AXI_Router_AXI4.h`：AXI4 router 接口定义。
- `axi_interconnect/include/AXI_Router_AXI3.h`：AXI3 router 接口定义。
- `axi_interconnect/AXI_Interconnect.cpp`：AXI4 仲裁/请求调度/响应分发实现。
- `axi_interconnect/AXI_Interconnect_AXI3.cpp`：AXI3 仲裁/请求调度/响应分发实现。
- `axi_interconnect/AXI_Router_AXI4.cpp`：AXI4 DDR/MMIO 地址译码与转发实现。
- `axi_interconnect/AXI_Router_AXI3.cpp`：AXI3 DDR/MMIO 地址译码与转发实现。
- `axi_interconnect/axi_interconnect_test.cpp`：AXI4 interconnect 单元与压力测试。
- `axi_interconnect/axi_interconnect_axi3_test.cpp`：AXI3 interconnect 单元与压力测试。

`sim_ddr/`：
- `sim_ddr/include/SimDDR.h`：AXI4 SimDDR 接口定义。
- `sim_ddr/include/SimDDR_AXI3.h`：AXI3 SimDDR 接口定义。
- `sim_ddr/include/SimDDR_IO.h`：AXI4 IO bundle 定义。
- `sim_ddr/include/SimDDR_AXI3_IO.h`：AXI3 IO bundle 定义。
- `sim_ddr/SimDDR.cpp`：AXI4 内存后端行为实现。
- `sim_ddr/SimDDR_AXI3.cpp`：AXI3 内存后端行为实现。
- `sim_ddr/sim_ddr_test.cpp`：AXI4 SimDDR 测试。
- `sim_ddr/sim_ddr_axi3_test.cpp`：AXI3 SimDDR 测试。

`mmio/`：
- `mmio/include/MMIO_Device.h`：MMIO 设备抽象基类。
- `mmio/include/MMIO_Bus_AXI4.h`：AXI4 MMIO 总线接口定义。
- `mmio/include/MMIO_Bus_AXI3.h`：AXI3 MMIO 总线接口定义。
- `mmio/include/UART16550_Device.h`：UART16550 设备接口定义。
- `mmio/MMIO_Bus_AXI4.cpp`：AXI4 MMIO 总线实现。
- `mmio/MMIO_Bus_AXI3.cpp`：AXI3 MMIO 总线实现。
- `mmio/UART16550_Device.cpp`：UART16550 设备模型实现。
- `mmio/mmio_router_axi4_test.cpp`：AXI4 router+MMIO 集成测试。
- `mmio/mmio_router_axi3_test.cpp`：AXI3 router+MMIO 集成测试。

`demos/`：
- `demos/axi4_smoke.cpp`：AXI4 最小冒烟示例。
- `demos/axi3_smoke.cpp`：AXI3 最小冒烟示例。
- `demos/single_cycle/include/config.h`：单周期示例本地配置与常量。
- `demos/single_cycle/include/RISCV.h`：RV32 指令/类型/辅助定义。
- `demos/single_cycle/include/CSR.h`：CSR 常量与定义。
- `demos/single_cycle/include/single_cycle_cpu.h`：单周期 CPU 类声明。
- `demos/single_cycle/include/sc_axi4_sim_api.h`：单周期示例的 AXI 仿真 API。
- `demos/single_cycle/include/softfloat.h`：softfloat 函数声明。
- `demos/single_cycle/include/softfloat_types.h`：softfloat 类型定义。
- `demos/single_cycle/src/main.cpp`：单周期示例入口。
- `demos/single_cycle/src/single_cycle_cpu.cpp`：单周期 CPU 实现。
- `demos/single_cycle/src/sc_axi4_sim_api.cpp`：AXI 内存/MMIO 胶水逻辑与运行时实现。
- `demos/single_cycle/third_party/softfloat/softfloat.a`：预编译 softfloat 静态库。

`docs/`：
- `docs/interfaces.md`：英文接口信号详表（上游端口 + AXI3/AXI4 通道）。
- `docs/interfaces_CN.md`：中文接口信号详表。

`.codex/skills/`：
- `.codex/skills/axi-kit-dev/SKILL.md`：本仓库开发流程技能文档。
- `.codex/skills/axi-kit-verify/SKILL.md`：本仓库验证/回归流程技能文档。

说明：
- `build/` 为构建生成目录，不属于源码职责范畴。


## 推荐阅读路径

如果是第一次阅读这个仓库，建议按以下顺序快速建立全局认知：

1. 先读本 README 的架构和拓扑（READ/WRITE 两张 ASCII 图）。
2. 再读 `docs/interfaces.md` / `docs/interfaces_CN.md` 的信号字典。
3. 按一条完整数据路径串读源码：
   - `axi_interconnect/include/AXI_Interconnect_IO.h`
   - `axi_interconnect/AXI_Interconnect.cpp`（或 `AXI_Interconnect_AXI3.cpp`）
   - `axi_interconnect/AXI_Router_AXI4.cpp`（或 `AXI_Router_AXI3.cpp`）
   - `sim_ddr/SimDDR.cpp` + `mmio/MMIO_Bus_AXI4.cpp`
4. 再读测试，确认预期行为与边界：
   - `axi_interconnect/axi_interconnect_test.cpp`
   - `mmio/mmio_router_axi4_test.cpp`
5. 最后看可运行示例：
   - `demos/axi4_smoke.cpp`、`demos/axi3_smoke.cpp`
   - `demos/single_cycle/src/main.cpp`

经验建议：
- 优先从 AXI4 路径理解，再对照 AXI3 差异。


## 构建

```bash
cmake -S . -B build
cmake --build build -j
```

或：

```bash
make -j
```

## 测试

```bash
cd build
ctest --output-on-failure
```

当前测试项：

- `sim_ddr_test`
- `axi_interconnect_test`
- `mmio_router_axi4_test`
- `sim_ddr_axi3_test`
- `axi_interconnect_axi3_test`
- `mmio_router_axi3_test`

## Demo

```bash
./build/axi4_smoke_demo
./build/axi3_smoke_demo
```

Demo 用途：
- `axi4_smoke_demo`：AXI4 路径单读主设备冒烟测试，检查请求被接收、AR 通道发出、读响应返回。
- `axi3_smoke_demo`：AXI3 路径同类冒烟测试，覆盖带 ID 的读路径握手与响应闭环。

## 单周期 RV32 Case

源码组织：

```text
demos/single_cycle/
  include/                # 单周期本地头文件/API/配置
  src/                    # 运行时与 CPU 模型
  third_party/softfloat/  # 预编译 softfloat 静态库
```

构建目标：

```bash
cmake -S . -B build
cmake --build build -j --target single_cycle_axi4_demo
```

延迟说明：
- `single_cycle_axi4_demo` 使用单独的 AXI4+SimDDR 库变体，默认
  `AXI_KIT_SINGLE_CYCLE_DDR_LATENCY=8`（避免 demo 运行过慢）。
- 可通过 CMake 参数覆盖，例如：
  `cmake -S . -B build -DAXI_KIT_SINGLE_CYCLE_DDR_LATENCY=16`

运行示例（使用父仓库中的程序镜像）：

```bash
./build/single_cycle_axi4_demo ../baremetal/new_dhrystone/dhrystone.bin
./build/single_cycle_axi4_demo ../baremetal/new_coremark/coremark.bin
./build/single_cycle_axi4_demo ../baremetal/linux.bin --max-inst 20000000
```

该 case 保持“模拟器逻辑”和“互连/内存子系统”分离，并且所有内存相关访问都通过 AXI 上游主设备端口发起（不是直接读写内存数组）：
- `fetch` -> 读主设备 `M0 (icache)`
- `load` + `amo read` -> 读主设备 `M1 (dcache_r)`
- `ptw/va2pa` 页表访问 -> 读主设备 `M2 (mmu)`
- `store` + `amo writeback`（含 UART MMIO 写）-> 写主设备 `M0 (dcache_w)`

在该单周期 case 中保留但未使用的端口：
- 读主设备 `M3 (extra_r)`
- 写主设备 `M1 (extra_w)`

## 回接到父仓库

父仓库可将此项目作为外部依赖，包含以下目录：

- `include/`
- `axi_interconnect/include/`
- `sim_ddr/include/`
- `mmio/include/`

并按需要链接：

- `axi_kit_axi4`
- `axi_kit_axi3`

## Git Submodule 使用流程

如果要在其他仓库中以 submodule 方式接入本项目：

```bash
# 在父仓库根目录执行
git submodule add git@github.com:dyh1807/axi-interconnect-kit.git axi-interconnect-kit
git commit -m "chore(submodule): add axi-interconnect-kit"
```

上述命令作用：
- 在父仓库写入 `.gitmodules`（记录 submodule 的 URL 与路径）
- 在父仓库记录 `axi-interconnect-kit` 的固定提交指针

克隆父仓库并初始化 submodule：

```bash
git clone --recurse-submodules <parent-repo-url>
# 如果父仓库已克隆：
git submodule update --init --recursive
```

上述命令作用：
- 按父仓库锁定的提交，检出对应 submodule 内容

将 submodule 更新到远端最新分支（例如 `main`）：

```bash
cd axi-interconnect-kit
git fetch origin
git checkout main
git pull --ff-only origin main
cd ..
git add axi-interconnect-kit
git commit -m "chore(submodule): bump axi-interconnect-kit"
```

上述命令作用：
- 更新 submodule 工作树到新提交
- 同步更新父仓库中的 submodule 指针

将 submodule 固定到指定提交：

```bash
cd axi-interconnect-kit
git checkout <commit-sha>
cd ..
git add axi-interconnect-kit
git commit -m "chore(submodule): pin axi-interconnect-kit to <sha>"
```

常用维护命令：

```bash
git submodule status
git submodule sync --recursive
git submodule foreach --recursive 'git status --short --branch'
```

命令说明：
- `git submodule status`：查看每个 submodule 当前检出的提交 SHA
- `git submodule sync --recursive`：根据 `.gitmodules` 刷新 URL/路径配置
- `git submodule foreach ...`：在每个 submodule 中执行命令，便于批量检查状态
