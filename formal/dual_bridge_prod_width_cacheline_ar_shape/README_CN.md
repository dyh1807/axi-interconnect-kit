# dual_bridge_prod_width_cacheline_ar_shape

状态：已通过，并已计入 `formal/run_passed_hw_cbmc.sh`。

覆盖对象：

- RTL：`rtl/src/axi_llc_axi_bridge_dual.v`
- 参数：64B line / 32B DDR beat / 64B upstream response
- 路径：cache source 64B read，只经过实际 dual bridge 的 DDR 分流与 issue gate。

覆盖范围：

- 64B cacheline read 请求被接受后，必须在有界窗口内产生 DDR `AR`。
- `ARADDR/ARLEN/ARSIZE/ARBURST` 必须为 2x256-bit production-width 形状。
- 不得误发 MMIO `AR/AW/W`，也不得误发 DDR `AW/W`。

运行：

```sh
formal/dual_bridge_prod_width_cacheline_ar_shape/run_hw_cbmc.sh
```

明确不覆盖：

- 不覆盖 `R` beat merge 和 response 回收；对应 single bridge production-width
  已由 `formal/bridge_prod_width_cacheline_read_response` 覆盖，dual bridge 的完整
  production-width response proof 当前仍需要继续拆分。

验证结论：

- 该入口曾暴露 `axi_llc_dual_port_hazard_scoreboard` pending hazard 依赖隐式
  helper match 的工具/RTL 歧义：无 AW 的 cacheline read 可能被形式工具解释为存在
  pending write hazard，从而卡住 `AR`。
- 当前生产 RTL 已在 scoreboard 内对 pending/match 结果显式二次 gate
  `*_hazard_valid_r`，并补齐 dual bridge pending hazard wire 声明，修复后本入口通过。
