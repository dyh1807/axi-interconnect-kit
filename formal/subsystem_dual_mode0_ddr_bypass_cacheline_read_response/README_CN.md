# subsystem_dual_mode0_ddr_bypass_cacheline_read_response

状态：新增 production-width actual native dual top smoke。

覆盖对象：

- RTL top：`rtl/src/axi_llc_subsystem_dual.v`
- 参数：64B line / 32B DDR beat / 64B read response / MODE_OFF direct-bypass
- 对应 C++ directed smoke：`axi_interconnect_dual_port_test` 中
  `mode0 DDR cacheline read 2-beat response`

覆盖范围：

- 64B DDR direct read 被接受后只向 DDR `AR` 发出，不误走 MMIO 或 write channel。
- `ARADDR/ARLEN/ARSIZE/ARBURST` 为 64B cacheline / 2x256-bit beat 形状。
- 两拍 DDR `R` 都必须 `RREADY=1`，第一拍 `RLAST=0` 前不能提前 upstream response。
- 第二拍 `RLAST=1` 后 upstream `read_resp_valid/id/data` 回收完整 512-bit cacheline。

运行：

```sh
formal/subsystem_dual_mode0_ddr_bypass_cacheline_read_response/run_hw_cbmc.sh
```

明确不覆盖：

- 不证明实际 C++ 类和 RTL 在同一个 hw-cbmc harness 内端到端等价；当前 hw-cbmc 前端
  无法解析项目 C++ 依赖的系统 C++ 标准库。
- 不覆盖 cacheable refill/dirty eviction；这些仍由其它 subsystem/cache_ctrl smoke 拆分覆盖。
