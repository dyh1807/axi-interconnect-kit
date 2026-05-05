# subsystem_core_dirty_evict_writeback

状态：实验入口，当前不纳入稳定 `formal/run_passed_hw_cbmc.sh`。

该入口是 actual `axi_llc_subsystem_core.v` 的 bounded formal smoke。Formal top 只缩小
cache 参数并 tie-off 外围端口，内部仍使用真实 `llc_cache_ctrl.v`、generic data/meta
store、valid/repl RAM 和 reconfig/mapped-window 控制。

覆盖场景：

- `MODE_CACHE` 下连续三笔同 set、不同 tag 的 full-line write。
- 前两笔 write miss 应安装 dirty line，并且不得发 lower cache/bypass request。
- 第三笔 write miss 在两路均 valid+dirty 后，必须先向 lower cache path 发 dirty victim
  writeback。
- dirty victim writeback 的地址、数据、strobe、size 必须正确，writeback response 后第三
  笔 upstream write response 的 id/code 必须正确。
- 该入口用于补齐 full dual top dirty-evict timeout 前的中间层真实生产路径覆盖。

运行：

```bash
formal/subsystem_core_dirty_evict_writeback/run_hw_cbmc.sh
```

当前实验结论：

- 该入口已经能完成 elaboration，但尚未通过。
- 当前失败点不是 production RTL 修改引入的问题；它暴露的是 core-alone formal top 中
  startup invalidate/reconfig 状态没有被证明稳定到 `MODE_CACHE/IDLE`，后续需要继续拆
  startup proof 或改用更接近 `axi_llc_subsystem_dual` 的外层 reset/warmup harness。
- 因此该入口暂时只作为 dirty-evict full-top timeout 前的定位材料，不计入稳定
  formal 回归。
