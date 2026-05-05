# dual_bridge_prod_width_cacheline_read_response

状态：新增 actual dual bridge production-width smoke。

覆盖对象：

- RTL：`rtl/src/axi_llc_axi_bridge_dual.v`
- 参数：64B line / 32B DDR beat / 64B upstream response
- 对应 C++ directed smoke：`axi_interconnect_dual_port_test` 中
  `mode0 DDR cacheline read 2-beat response`

覆盖范围：

- 64B cacheline read 只向 DDR `AR` 发出，不误走 MMIO 或 write channel。
- `ARADDR/ARLEN/ARSIZE/ARBURST` 为生产宽度 2x256-bit beat 形状。
- 两拍 DDR `R` 被 `RREADY` 接收，第一拍 `RLAST=0` 不提前回包。
- 第二拍 `RLAST=1` 后 upstream response 的 id/code/512-bit data 完整回收。

运行：

```sh
formal/dual_bridge_prod_width_cacheline_read_response/run_hw_cbmc.sh
```

明确不覆盖：

- 不实例化完整 `axi_llc_subsystem_dual.v`；该 top 的 production-width direct proof 当前
  因 typecheck/展开过重保留为实验入口。
- 不把实际 C++ 类编入同一个 hw-cbmc harness；当前 hw-cbmc C++ 前端不能解析项目依赖的
  系统 C++ 标准库。
