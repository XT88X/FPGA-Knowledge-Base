# 5.2 AXI 总线与外设挂载

上一节我们造了颗 CPU，但它怎么挂外设？真实 FPGA 里靠 **AXI 总线**。本节讲清 AXI 是什么、怎么握手，然后亲手写一个可综合的 AXI4-Lite GPIO 从机，再讲怎么在 Vivado 里把它打包、挂到总线、用 C 点灯。

## 5.2.1 AXI 协议族：三种接口别搞混

ARM 的 AMBA AXI 是 FPGA 事实标准。AMD/Xilinx 的 7 系列、Zynq 全都用它。它有三个变体：

| 接口 | 特点 | 典型用途 |
|---|---|---|
| **AXI4** | 支持突发传输（burst）、高性能 | 接 DDR、DMA、大块数据搬运 |
| **AXI4-Lite** | 单次传输、地址/数据各一拍、寄存器级 | 接 GPIO/UART/控制寄存器等低速外设 |
| **AXI4-Stream** | 无地址、数据流单向、背靠背 | 视频流、DMA 数据流、音频流 |

本节我们做的是 **AXI4-Lite 从机**——它最简单，就是"主机读/写几个内存映射寄存器"。

## 5.2.2 五个独立通道与 VALID/READY 握手

AXI4-Lite 把一次传输拆成**五个独立通道**，各走各的、允许并行：

- **AW（写地址通道）**：主机发写地址；
- **W（写数据通道）**：主机发写数据；
- **B（写响应通道）**：从机回写是否成功（OKAY/SLVERR）；
- **AR（读地址通道）**：主机发读地址；
- **R（读数据通道）**：从机回读数据 + 响应。

握手规则就一条：**VALID/READY 同时为高的那一拍，数据被采样**。驱动方把 `VALID` 拉高后必须保持，直到对方 `READY` 也拉高；`READY` 可以组合产生。写操作要 AW、W、B 三拍配合；读操作要 AR、R 两拍配合。通道结构见 `ch2_axi_channels.svg`，单次读写握手时序见 `ch2_axi_handshake.svg`。

> 关键纪律：**VALID 不等 READY 就一直保持**，不能提前撤销；READY 可以随时变。我们的 `ch2_axi_lite_gpio.v` 用一个小 FSM 严格满足这条。

## 5.2.3 寄存器映射（本外设）

`ch2_axi_lite_gpio.v` 把外部 `led_o[3:0]`、`sw_i[3:0]` 暴露成三个内存映射寄存器：

| 偏移 | 名称 | 属性 | 说明 |
|---|---|---|---|
| `0x00` | `GPIO_DATA` | R/W | 写 -> 驱动 `led_o`；读 -> 返回当前 `led_o` 锁存值 |
| `0x04` | `GPIO_INPUT` | R | 读 -> 返回 `sw_i`（按键/拨码开关） |
| `0x08` | `VERSION` | R | 固定 `0x20261010` |

写 FSM 要处理 **AW 与 W 同时或先后到达**：同时到就一拍写完；先到 AW 就锁地址等 W，先到 W 就锁数据等 AW，最后统一进 B 通道回 OKAY。读 FSM 更简单：AR 握手后下一拍出 R 数据。

## 5.2.4 地址译码与内存映射

总线上每个从机占一段地址。`ch2_addr_decode.v` 是手写的组合译码示例：取地址高位 `addr[31:26]` 与各基地址比较，产生 `cs_ram/cs_gpio/cs_uart/cs_error` 片选。真实 Vivado 工程里这步由 **AXI Interconnect（PG059）** 自动完成——你只要在地址编辑器里给每个从分配基地址和范围。示例映射见 `ch2_addr_map.svg`。

## 5.2.5 在 Vivado 里挂载自定义 AXI 外设

完整流程（AMD 官方手册见文末链接）：

1. 写好 `ch2_axi_lite_gpio.v`，端口按 AXI 命名规范（`S_AXI_*`）；
2. **Tools → Create and Package New IP → Create AXI4 Peripheral**，选 AXI4-Lite Slave，Vivado 生成模板；
3. 把你的 RTL 替换进模板，在**接口/地址编辑器**里确认寄存器；
4. 在 Block Design（IPI）里添加你的 IP + AXI Interconnect，连到 Zynq PS 或自建软核的主机口；
5. **Address Editor** 给外设分配基地址（如 `0x4000_0000`）；
6. 生成输出产品、加约束、下载。

## 5.2.6 用 C 控制 LED

裸机/BSP 下，把 LED 寄存器当成一个地址指针直接读写即可。Zynq standalone BSP 提供：

```c
#include "xil_io.h"
#define GPIO_BASE  0x40000000U
#define REG_DATA   (*(volatile uint32_t *)(GPIO_BASE + 0x00))
#define REG_INPUT  (*(volatile uint32_t *)(GPIO_BASE + 0x04))

int main(void) {
    Xil_Out32(GPIO_BASE + 0x00, 0x0A);   // 点亮 led = 1010
    while (1) {
        uint32_t sw = Xil_In32(GPIO_BASE + 0x04);  // 读拨码
        Xil_Out32(GPIO_BASE + 0x00, sw & 0xF);     // 用拨码控制 LED
    }
}
```

不用 BSP 时，等价的裸机指针写法是 `*(volatile uint32_t*)0x40000000 = 0x0A;`——和 5.1 里写 UART 寄存器一模一样。

## 5.2.7 验证与如实声明

`ch2_tb_axi_gpio.v` 内置 AXI 主端序列，断言：写 `GPIO_DATA=0b1010` 后 `led_o==1010` 且读回一致；读 `GPIO_INPUT` 跟随 `sw_i`；读 `VERSION==0x20261010`；AW/W 拆分到达仍正确完成写。

> 如实声明：本 AXI 从机为教学可综合 RTL，**未在 Vivado 真正综合、打包上板**；握手逻辑按 AXI4-Lite 规范实现并通过行为仿真断言。Vivado IPI 打包步骤需在装有 Vivado 的环境按官方手册完成。

## 官方参考（访问于 2026-10）

- AXI Reference Guide（UG1037）：<https://docs.amd.com/r/en-US/ug1037-vivado-axi-reference-guide>
- Creating and Packaging Custom IP（UG1118）：<https://docs.amd.com/r/en-US/ug1118-vivado-creating-packaging-custom-ip>
- Designing IP Subsystems Using IP Integrator（UG994）：<https://docs.amd.com/r/en-US/ug994-vivado-ip-subsystems>
- AXI Interconnect Product Guide（PG059）：<https://www.xilinx.com/support/documents/ip_documentation/axi_interconnect/v2_1/pg059-axi-interconnect.pdf>
