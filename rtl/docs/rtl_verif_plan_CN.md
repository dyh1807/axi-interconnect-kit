# RTL 验证计划（第二阶段进行中）

## 目标

当前验证优先覆盖已经落地的共享存储、mode 控制、mode2 直映窗口，以及 mode1 最小 cache 语义。

## P0 单元级

### `tb_llc_data_store.v`

- 同步 set-row 读
- `rd_en -> rd_valid` 时序
- 按 way mask 写
- 不同 way 更新互不破坏

### `tb_llc_meta_store.v`

- meta row 的按 way mask 写
- 写阶段 `busy`
- 读回一致

### `tb_llc_valid_ram.v`

- 掩码写
- 同一 set 多次更新
- 未更新位保持
- reset 后清零

### `tb_llc_invalidate_sweep.v`

- `start -> busy -> done`
- 逐 set 顺序扫描
- `valid_wr_mask` 恒全 1
- `valid_wr_bits` 恒全 0
- busy 期间重复 `start` 被忽略

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
- `mode=2` 顺序读改写后再响应
- `mode=2` invalid read=0
- `mode=0` bypass 路由
- `mode=1` cache 路由
- `mode=2 -> mode=0 -> mode=2` 后旧 valid 被 sweep 清除

### `tb_axi_llc_subsystem_mode_contract.v`

覆盖：

- `mode=0/1/2/3` 基本路由合同
- `mode=2` invalid read 返回 0
- `mode=2` write/read 回读
- 切换后旧 mapped valid 不可见

### `tb_axi_llc_subsystem_handshake_contract.v`

覆盖：

- `up_req_ready` 回压
- `up_resp_ready=0` 时响应保持
- bypass 下游 `ready` 延迟
- cache 下游 `ready` 延迟
- `mode=1 + up_req_bypass=1`
- 读写属性透传

### `tb_axi_llc_subsystem_cache_contract.v`

覆盖：

- `mode=1` read miss -> refill -> respond
- 同地址第二次 read hit 不再发外部 `cache_req`
- write hit 更新 resident data
- full-line write miss 直接安装 dirty line
- partial write miss 先 refill 再 merge
- dirty victim writeback + refill

## 当前限制

- 当前 bench 仍以 directed contract 为主，`ready/valid` 背压与 mode1 cache 细节需要独立 bench 继续补强。
- 还没有覆盖与 C++ 原型完全对齐的接口字段。
- 当前已在 `eda-10` 上确认 VCS 可用，并实际跑通：
  - `tb_llc_data_store`
  - `tb_llc_meta_store`
  - `tb_llc_valid_ram`
  - `tb_llc_invalidate_sweep`
  - `tb_llc_mapped_window_ctrl`
  - `tb_axi_reconfig_ctrl`
  - `tb_axi_llc_subsystem_directed`
  - `tb_axi_llc_subsystem_handshake_contract`
  - `tb_axi_llc_subsystem_mode_contract`
  - `tb_axi_llc_subsystem_cache_contract`
