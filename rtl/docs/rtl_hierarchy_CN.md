# RTL 层次与 IO 索引

这份文档只解决 3 个问题：

1. 现在 RTL 的推荐入口文件是哪一个
2. 顶层到子模块的层次关系是什么
3. 每一层各自持有哪些 IO

## 先看哪个文件

如果你第一次进入 `rtl/`，推荐按下面顺序打开：

1. `src/axi_llc_subsystem.v`
   - 最终对外顶层
   - 同时能看到上游自定义接口和下游 AXI 接口
2. `src/axi_llc_subsystem_compat.v`
   - 多 master 兼容层
   - 负责把上游多读/多写 master 收敛成单流核心
3. `src/axi_llc_subsystem_top.v`
   - 单流核心
   - 负责 mode 路由、mode 切换、shared store、mode1 cache、mode2 mapped window
4. `src/axi_llc_axi_bridge.v`
   - 内部 lower request 到 AXI4 五通道的翻译层

如果你只关心“RTL 对外长什么样”，只看 `axi_llc_subsystem.v` 就够了。  
如果你只关心“mode1/mode2 内部怎么走”，看 `axi_llc_subsystem_top.v`。  
如果你只关心“AXI 是怎么打包出来的”，看 `axi_llc_axi_bridge.v`。

## 主层次

```text
axi_llc_subsystem
|-- axi_llc_subsystem_compat
|   `-- axi_llc_subsystem_top
|       |-- axi_reconfig_ctrl
|       |-- llc_invalidate_sweep
|       |-- llc_valid_ram
|       |-- llc_repl_ram
|       |-- llc_data_store
|       |   |-- llc_data_store_generic
|       |   `-- llc_data_store_smic12
|       |-- llc_meta_store
|       |   |-- llc_meta_store_generic
|       |   `-- llc_meta_store_smic12
|       |-- llc_cache_ctrl
|       `-- llc_mapped_window_ctrl
`-- axi_llc_axi_bridge
```

## 各层职责

### `axi_llc_subsystem`

职责：

- 提供最终对外 RTL 边界
- 保留 C++ submodule 风格的上游多 master 自定义接口
- 保留下游单组 AXI4 master 接口
- 在内部串接：
  - `axi_llc_subsystem_compat`
  - `axi_llc_axi_bridge`

这里是定位顶层 IO 的第一入口。

### `axi_llc_subsystem_compat`

职责：

- 接收多 `read_masters[] / write_masters[]`
- 每个 master 保留单深度请求队列
- 维护独立 read/write response 槽位
- 对单流核心提供统一的 `up_req_* / up_resp_*`

这一层不负责 AXI，也不直接碰共享 store。

### `axi_llc_subsystem_top`

职责：

- 作为单流核心
- 统一决定：
  - `mode=0/3`
  - `mode=1`
  - `mode=2`
- 统一驱动：
  - `axi_reconfig_ctrl`
  - `llc_invalidate_sweep`
  - `llc_data_store`
  - `llc_meta_store`
  - `llc_valid_ram`
  - `llc_repl_ram`
  - `llc_cache_ctrl`
  - `llc_mapped_window_ctrl`
- 对外提供两类内部 lower 接口：
  - `cache_req_* / cache_resp_*`
  - `bypass_req_* / bypass_resp_*`

如果要看 mode 切换、valid sweep、mode1 cache 路径和 mode2 direct window，这里是主入口。

### `axi_llc_axi_bridge`

职责：

- 接收 `cache_*` 和 `bypass_*` 两类内部 lower 请求
- 统一仲裁成一组 AXI4 五通道事务
- 把 AXI `R/B` 响应再还原给 cache/bypass 两类上层路径

如果要看 `ARLEN/ARSIZE/AWLEN/AWSIZE`、beat 拼接和 AXI `id` 的当前位置，这里是主入口。

## IO 分层

### 对外顶层 `axi_llc_subsystem`

#### 控制面

- `mode_req`
- `llc_mapped_offset_req`
- `invalidate_line_valid`
- `invalidate_line_addr`
- `invalidate_all_valid`
- `active_mode`
- `active_offset`
- `reconfig_busy`
- `reconfig_state`
- `config_error`

#### 上游接口

读侧：

- `read_req_valid/ready/accepted/accepted_id`
- `read_req_addr`
- `read_req_total_size`
- `read_req_id`
- `read_req_bypass`
- `read_resp_valid/ready`
- `read_resp_data`
- `read_resp_id`

写侧：

- `write_req_valid/ready/accepted`
- `write_req_addr`
- `write_req_wdata`
- `write_req_wstrb`
- `write_req_total_size`
- `write_req_id`
- `write_req_bypass`
- `write_resp_valid/ready`
- `write_resp_id`
- `write_resp_code`

#### 下游 AXI

- `axi_aw*`
- `axi_w*`
- `axi_b*`
- `axi_ar*`
- `axi_r*`

### 单流核心 `axi_llc_subsystem_top`

#### 上游单流接口

- `up_req_*`
- `up_resp_*`

#### 内部 lower 接口

cache 路径：

- `cache_req_*`
- `cache_resp_*`

bypass 路径：

- `bypass_req_*`
- `bypass_resp_*`

#### 维护接口

- `invalidate_line_*`
- `invalidate_all_*`

## 文件分类

### 顶层与主要包装层

- `src/axi_llc_subsystem.v`
- `src/axi_llc_subsystem_compat.v`
- `src/axi_llc_subsystem_top.v`
- `src/axi_llc_axi_bridge.v`

### 控制与路径

- `src/axi_reconfig_ctrl.v`
- `src/llc_cache_ctrl.v`
- `src/llc_mapped_window_ctrl.v`
- `src/llc_invalidate_sweep.v`

### resident store

- `src/llc_valid_ram.v`
- `src/llc_repl_ram.v`
- `src/llc_data_store.v`
- `src/llc_data_store_generic.v`
- `src/llc_data_store_smic12.v`
- `src/llc_meta_store.v`
- `src/llc_meta_store_generic.v`
- `src/llc_meta_store_smic12.v`

### SMIC12 宏封装

- `src/llc_smic12_data_1024x128_bw.v`
- `src/llc_smic12_meta_1024x128.v`

## 当前阅读建议

如果想快速建立整体认知，可以按下面顺序：

1. 看 `axi_llc_subsystem.v` 的端口和两级实例化
2. 看 `axi_llc_subsystem_compat.v`，明确多 master 如何收敛成单流
3. 看 `axi_llc_subsystem_top.v`，明确 mode 路由和共享 store
4. 看 `llc_cache_ctrl.v` 和 `llc_mapped_window_ctrl.v`，理解 mode1 / mode2 差异
5. 看 `axi_llc_axi_bridge.v`，确认对外 AXI 打包方式

## 当前限制

- 这份索引只描述当前 RTL 实现和推荐入口
- 不替代 [rtl_microarch_CN.md](rtl_microarch_CN.md) 的详细语义说明
- 不替代 [rtl_verif_plan_CN.md](rtl_verif_plan_CN.md) 的验证范围说明
