# AXI Interconnect Kit 接口规格（中文）

本文档列出：

1. Interconnect 上游接口
2. AXI4 五通道信号

## 1) Interconnect 上游接口

定义位置：`axi_interconnect/include/AXI_Interconnect_IO.h`。

### 1.1 读请求（`ReadMasterReq_t`）

| 信号 | 位宽 | 相对 interconnect 方向 | 说明 |
|---|---:|---|---|
| `valid` | 1 | 输入 | 请求有效 |
| `ready` | 1 | 输出 | interconnect 接受请求 |
| `addr` | 32 | 输入 | 字节地址 |
| `total_size` | 8 | 输入 | 传输字节数减 1 |
| `id` | 4 | 输入 | 上游事务 ID |
| `bypass` | 1 | 输入 | 绕过 LLC 分配/所有权规则 |

### 1.2 读响应（`ReadMasterResp_t`）

| 信号 | 位宽 | 方向 | 说明 |
|---|---:|---|---|
| `valid` | 1 | 输出 | 响应有效 |
| `ready` | 1 | 输入 | 主设备接受响应 |
| `data` | 最多 256B | 输出 | 宽数据响应 |
| `id` | 4 | 输出 | 返回上游 ID |

### 1.3 写请求（`WriteMasterReq_t`）

| 信号 | 位宽 | 方向 | 说明 |
|---|---:|---|---|
| `valid` | 1 | 输入 | 请求有效 |
| `ready` | 1 | 输出 | interconnect 接受请求 |
| `addr` | 32 | 输入 | 字节地址 |
| `wdata` | 最多 64B | 输入 | 有界写数据 |
| `wstrb` | 最多 64 位 | 输入 | 字节写掩码 |
| `total_size` | 8 | 输入 | 传输字节数减 1 |
| `id` | 4 | 输入 | 上游事务 ID |
| `bypass` | 1 | 输入 | write-through maintenance / bypass 语义 |

### 1.4 写响应（`WriteMasterResp_t`）

| 信号 | 位宽 | 方向 | 说明 |
|---|---:|---|---|
| `valid` | 1 | 输出 | 响应有效 |
| `ready` | 1 | 输入 | 主设备接受响应 |
| `id` | 4 | 输出 | 返回上游 ID |
| `resp` | 2 | 输出 | AXI 响应码 |

## 2) AXI4 五通道信号

定义位置：`sim_ddr/include/SimDDR_IO.h`。

本项目 AXI4 约束：

- `ID`：4 位
- 下游 AXI4 通道数据位宽：`32-bit`

### 2.1 写地址通道（`AW`）

| 信号 | 位宽 | 方向（主->从） | 说明 |
|---|---:|---|---|
| `awvalid` | 1 | M->S | 地址有效 |
| `awready` | 1 | S->M | 地址就绪 |
| `awid` | 4 | M->S | 写事务 ID |
| `awaddr` | 32 | M->S | 字节地址 |
| `awlen` | 8 | M->S | 突发长度减 1 |
| `awsize` | 3 | M->S | `log2(bytes_per_beat)` |
| `awburst` | 2 | M->S | 突发类型 |

### 2.2 写数据通道（`W`）

| 信号 | 位宽 | 方向 | 说明 |
|---|---:|---|---|
| `wvalid` | 1 | M->S | 数据有效 |
| `wready` | 1 | S->M | 数据就绪 |
| `wdata` | 32 | M->S | 写数据 |
| `wstrb` | 4 | M->S | 字节写使能 |
| `wlast` | 1 | M->S | 最后一个 beat |

### 2.3 写响应通道（`B`）

| 信号 | 位宽 | 方向 | 说明 |
|---|---:|---|---|
| `bvalid` | 1 | S->M | 响应有效 |
| `bready` | 1 | M->S | 响应就绪 |
| `bid` | 4 | S->M | 响应 ID |
| `bresp` | 2 | S->M | 响应码 |

### 2.4 读地址通道（`AR`）

| 信号 | 位宽 | 方向 | 说明 |
|---|---:|---|---|
| `arvalid` | 1 | M->S | 地址有效 |
| `arready` | 1 | S->M | 地址就绪 |
| `arid` | 4 | M->S | 读事务 ID |
| `araddr` | 32 | M->S | 字节地址 |
| `arlen` | 8 | M->S | 突发长度减 1 |
| `arsize` | 3 | M->S | `log2(bytes_per_beat)` |
| `arburst` | 2 | M->S | 突发类型 |

### 2.5 读数据通道（`R`）

| 信号 | 位宽 | 方向 | 说明 |
|---|---:|---|---|
| `rvalid` | 1 | S->M | 数据有效 |
| `rready` | 1 | M->S | 数据就绪 |
| `rid` | 4 | S->M | 响应 ID |
| `rdata` | 32 | S->M | 读数据 |
| `rresp` | 2 | S->M | 响应码 |
| `rlast` | 1 | S->M | 最后一个 beat |
