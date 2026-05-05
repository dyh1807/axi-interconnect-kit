# Dual-Port Route Formal Smoke

这个目录是后续 C++ reference 与 RTL EC 的最小可运行入口，当前把 C harness
绑定到生产 C helper `include/axi_dual_port_route_shape.h`，并对比生产 RTL 组合 helper
`rtl/src/axi_llc_dual_port_route_shape.v`，但不直接等价完整
`axi_llc_subsystem_dual.v`。

当前检查对象：

- `addr >= 0x4000_0000` 必须走 DDR port。
- `addr < 0x4000_0000` 必须走 MMIO port。
- MMIO 只支持 4B 请求，即 `total_size == 3`。
- DDR 侧 `axi_len` 必须按 32B/256-bit beat 向上取整，MMIO 侧 `axi_len=0`。
- DDR 侧 `axi_size=5`，MMIO 侧 `axi_size=2`。

运行方式：

```sh
formal/dual_port_route_shape/run_hw_cbmc.sh
```

默认使用父目录软链接：

```text
../../hw-cbmc/src/hw-cbmc/hw-cbmc
```

也可以显式指定：

```sh
HW_CBMC=/path/to/hw-cbmc formal/dual_port_route_shape/run_hw_cbmc.sh
```

当前边界：

- 这是 production helper smoke，用于固定 `hw-cbmc` 命令、C harness 与 Verilog
  module 连接方式，并确保形式化入口比较生产 C helper 与生产 RTL helper，而不是
  验证一份复制出来的 spec。
- 该入口证明 route helper 的 `ddr/mmio/supported/axi_len/axi_size` 与生产 C helper
  一致；但 RTL bridge 的 `AR/AW` 长度/size 仍来自实际 `axi_llc_axi_bridge`
  数据通路，后续仍需要直接绑定 bridge/top 做 bounded sequential harness。
- 下一步应针对 `axi_llc_axi_bridge_dual.v` 写 bounded sequential harness，逐项覆盖
  外部 `AR/AW/W/R/B` 事件与同 line hazard。
