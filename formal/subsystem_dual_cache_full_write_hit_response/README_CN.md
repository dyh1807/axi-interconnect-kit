# subsystem_dual_cache_full_write_hit_response

## 目标

验证真实 `axi_llc_subsystem_dual` 在 `MODE_CACHE` 下的 full-line write miss 基础语义：

- 空 cache 下 full-line write miss 可以直接安装 dirty line。
- full-line write miss 不需要先发 DDR refill `AR`。
- 写响应返回后，同地址 read 应命中并返回刚写入的数据。

## 覆盖点

- 使用实际生产 RTL，而不是根据理解单独重写的 formal-only 模型。
- 检查 full-line write 的 upstream `write_resp_valid/id/code`。
- 检查后续同地址 read 的 upstream `read_resp_valid/id/data`。
- 检查该过程中不得误发 DDR `AR/AW/W` 或 MMIO `AR/AW/W`。

## 当前状态

- 单项验证：已通过，`VERIFICATION SUCCESSFUL`，22 个断言 0 failed。
- 稳定回归：已加入 `formal/run_passed_hw_cbmc.sh`。
