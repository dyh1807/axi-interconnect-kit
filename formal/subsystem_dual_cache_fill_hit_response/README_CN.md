# subsystem_dual_cache_fill_hit_response

## 目标

验证真实 `axi_llc_subsystem_dual` 在 `MODE_CACHE` 下的 cache fill 后命中语义：

- 第一次 DDR/SDRAM cacheable read 对空 cache 产生 miss/refill。
- lower DDR 返回一拍 cacheline 后，subsystem 返回上游 read response。
- 第二次同地址 read 应命中刚安装的 cacheline。
- 第二次同地址 read 不应再次发出 DDR `AR`。

## 覆盖点

- 使用实际生产 RTL，而不是根据理解单独重写的 formal-only 模型。
- 检查 refill `AR` 地址、`len/size/burst`。
- 检查 refill `R` 到上游 `read_resp` 的数据/ID 保持。
- 检查第二次同地址 read 的响应 ID/数据。
- 检查第一次 refill `AR` 被接收之后不会出现第二个 DDR `AR`。
- 检查该场景不会错误路由到 DDR write 或 MMIO 通道。

## 当前状态

- 单项验证：已通过。
- 稳定回归：已加入 `formal/run_passed_hw_cbmc.sh`。
