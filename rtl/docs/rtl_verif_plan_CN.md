# RTL 验证计划（第一阶段）

## 目标

第一阶段验证只覆盖已经实现的 RTL 语义边界，不假装覆盖完整 cache path。

## P0 单元级

### `tb_llc_data_store.v`

- set-row 读
- 按 way mask 写
- 不同 way 更新互不破坏

### `tb_llc_meta_store.v`

- meta row 的按 way mask 写
- 读回一致

### `tb_llc_valid_ram.v`

- 掩码写
- 同一 set 多次更新
- 未更新位保持

### `tb_llc_mapped_window_ctrl.v`

- window 内地址翻译
- direct set/way 计算
- invalid read 返回 0
- valid read 返回 resident line
- invalid partial write 走 zero-merge
- out-of-window 判定

### `tb_axi_reconfig_ctrl.v`

- `requested != active` 进入 `DRAIN`
- `global_quiescent` 后进入 `INV_SWEEP`
- `sweep_done` 后 `ACTIVATE`
- DRAIN 期间 target 收敛到最后一次请求值

## P1 子模块级 directed

### `tb_axi_llc_subsystem_directed.v`

覆盖：

- `mode=2` direct write/read
- `mode=2` invalid read=0
- `mode=0` bypass 路由
- `mode=1` cache 路由
- `mode=2 -> mode=0 -> mode=2` 后旧 valid 被 sweep 清除

## 当前限制

- 当前只覆盖第一阶段共享存储 + mode2 + reconfiguration 语义。
- 完整 `mode=1` cache datapath 仍未接入。
- 当前已在 `eda-10` 上确认 VCS 可用，并实际跑通：
  - `tb_llc_data_store`
  - `tb_llc_meta_store`
  - `tb_llc_valid_ram`
  - `tb_llc_mapped_window_ctrl`
  - `tb_axi_reconfig_ctrl`
  - `tb_axi_llc_subsystem_directed`
