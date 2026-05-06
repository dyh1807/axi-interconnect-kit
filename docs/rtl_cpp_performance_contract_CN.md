# RTL / C++ 性能周期对齐检查

更新时间：2026-05-07 CST。

本文档记录等待 full DC 期间新增的 testbench-only performance diagnostic。该检查不修改
production C++/RTL，不进入当前正在综合的 `rtl/flist/axi_llc_rtl.f`，也不作为默认
`rtl/run_all_contracts.sh` 的一部分。

## 目标

功能等价只能说明协议行为、ID、数据和约束正确，不能保证 RTL 实际周期数达到 C++
模拟器预测。该 diagnostic 用实际 `AXI_Interconnect` C++ comb/seq 路径生成关键事件周期，
再由实际 RTL top `axi_llc_subsystem_dual.v` 在 testbench 中 replay 同类 microbench，
比较这些事件的 cycle：

- upstream request ready。
- DDR/MMIO `AR/AW/W` 发射。
- DDR/MMIO `R/B` 返回被接收。
- upstream read/write response fire。

## 文件

- C++ generator：`axi_interconnect/axi_interconnect_dual_port_perf_vectors_test.cpp`
- CMake target：`axi_interconnect_dual_port_perf_vectors`
- 生成头文件：`rtl/include/axi_dual_cpp_perf_vectors.vh`
- RTL diagnostic TB：`rtl/tb/tb_axi_llc_subsystem_dual_cpp_perf_contract.v`
- 手动 flist：`rtl/flist/perf_axi_llc_subsystem_dual_cpp_perf_contract.f`
- 手动运行脚本：`rtl/run_cpp_perf_contract.sh`

该 flist 故意不命名为 `tb_*.f`，避免被 `rtl/run_all_contracts.sh` 自动纳入默认功能回归。
原因是当前检查已经发现 RTL/C++ cycle mismatch，尚未决定是修改 C++ cycle model、
优化 RTL latency，还是把差异记录为可接受固定成本。

## 运行

生成 C++ expected cycle header：

```sh
cmake --build build_dual_axi_scope_20260428 --target axi_interconnect_dual_port_perf_vectors -j8
./build_dual_axi_scope_20260428/axi_interconnect_dual_port_perf_vectors \
  rtl/include/axi_dual_cpp_perf_vectors.vh
```

运行 RTL diagnostic：

```sh
cd rtl
source /centos7/eda-tools/eda-software/synopsys/source-scripts/bash_eda10
OUT_DIR=local_debug/vcs_cpp_perf_contract_20260507_manual_eda10 \
  ./run_cpp_perf_contract.sh
```

最近一次运行：

- C++ generator：通过，生成 `rtl/include/axi_dual_cpp_perf_vectors.vh`。
- VCS compile：通过。
- RTL/C++ perf compare：失败，`mismatches=29`。
- 日志：`rtl/local_debug/vcs_cpp_perf_contract_20260507_manual_eda10/run.log`

## 当前结果

当前 microbench 只覆盖 MODE_OFF direct DDR/MMIO 路径，不覆盖 LLC hit/miss/refill 或
maintenance。结果已经足以说明：RTL 的实际周期行为并不等于当前 C++ 模拟器的 direct
path 周期预测。

| 场景 | 事件 | C++ cycle | RTL cycle | 差异 |
| --- | --- | --- | --- | --- |
| READ64_DDR | `AR` | 0 | 2 | +2 |
| READ64_DDR | `R0/R1` | 2/3 | 4/5 | +2/+2 |
| READ64_DDR | upstream response | 4 | 8 | +4 |
| WRITE64_DDR | request ready | 0 | 1 | +1 |
| WRITE64_DDR | `AW/W0/W1/B` | 2/3/4/6 | 3/4/5/7 | +1 |
| WRITE64_DDR | upstream response | 7 | 9 | +2 |
| OVERLAP_READ DDR | `AR/R0/R1/response` | 0/2/3/4 | 2/4/5/8 | +2/+2/+2/+4 |
| OVERLAP_READ MMIO | ready/`AR/R0/response` | 0/1/3/4 | 2/4/6/9 | +2/+3/+3/+5 |
| OVERLAP_WRITE DDR | ready/`AW/W0/W1/B/response` | 0/2/3/4/6/7 | 1/3/4/5/7/9 | +1/+1/+1/+1/+1/+2 |
| OVERLAP_WRITE MMIO | ready/`AW/W0/B/response` | 2/4/5/7/8 | 3/5/6/8/10 | +1/+1/+1/+1/+2 |

该差异不是 reset 后 warm-up 造成的；TB 已在 reset settle 后增加 idle warm-up，结果不变。

## 结论

当前功能 EC 可以继续作为 correctness 证据，但不能声称 RTL 性能已经达到 C++ 模拟器
预测。至少在 direct DDR/MMIO microbench 上，RTL 比 C++ 多出 1-5 cycle，尤其 read
response 侧比 C++ 更慢。

短期不应为了这个 diagnostic 立即修改 production RTL，因为当前 full DC 正在跑；修改会
废掉正在等待的 DC signoff 口径。更合理的下一步是在 DC 出结果后做二选一：

- 如果这些 pipeline/response buffering latency 是硬件必要成本，则把 C++ cycle model
  显式对齐 RTL，并重新跑 Linux 300k/5M 检查 IPC/cycles 变化。
- 如果这些 latency 不应存在，则基于该 diagnostic 优化 RTL direct path，再重新跑功能
  EC、performance diagnostic、Linux gate 和 DC。

## 后续扩展

当前 diagnostic 只验证 direct path。后续如果要形成真正 performance contract，还需要
继续添加：

- MODE_CACHE read hit latency。
- MODE_CACHE read miss/refill latency。
- dirty victim writeback latency。
- same-line hazard blocked cycle。
- 32 read outstanding / 32 write outstanding 的 steady-state issue throughput。
- maintenance pending 对 DDR/MMIO lower response 的额外 stall cycle。

这些扩展仍应保持 testbench-only，直到明确要改 production C++/RTL cycle model。
