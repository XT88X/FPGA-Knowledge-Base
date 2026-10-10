# 5.4 终极项目：自制 SoC 单片机

这是阶段 5 的收官之作——把前面所有零件攒成一颗**自己设计的单片机**：一颗 RV32I CPU + 片上 RAM + UART + GPIO + 定时器 + 中断控制器，全部用 Verilog 手写，跑裸机 C 程序。它就是一颗"软核 MCU"，和你用过的 STM32 在概念上是同一类东西。

## 5.4.1 顶层架构

`ch4_soc_top.v` 把以下模块连起来（见 `ch4_soc_block.svg`）：

| 模块 | 文件 | 职责 |
|---|---|---|
| RV32I 核 | `ch4_rv_core.v` | 取指/译码/执行/访存/写回，带简化 vectored 中断 |
| 片上 RAM 4KB | 顶层内 `ram` | von Neumann，取指与 LW/SW 共用，`$readmemh` 加载固件 |
| 地址译码 | `ch4_bus_mux.v` | 按地址片选外设、拼读数据 |
| UART | `ch4_uart.v` | 可综合 tx/rx，1 起始+8 数据+1 停止 |
| GPIO | `ch4_gpio.v` | 方向寄存器 + 数据寄存器，8 bit |
| 定时器 | `ch4_timer.v` | 自由计数，到 cmp 置中断标志 |
| 中断汇总 | 顶层内 | `INTF & INTE[0] -> CPU irq_i` |

## 5.4.2 完整地址映射表

32-bit 字节地址（见 `ch4_addr_map.svg`）：

| 地址 | 寄存器 | 读写 | 说明 |
|---|---|---|---|
| `0x0000_0000–0x0000_0FFF` | 片上 RAM | R/W | 4KB，取指+数据共用 |
| `0x2000_0000` | UART_DATA | W/R | 写=发字节；读=最近收到字节 |
| `0x2000_0004` | UART_STATUS | R | bit0=tx_ready, bit1=rx_avail |
| `0x2000_0010` | GPIO_DIR | R/W | bit=1 该脚为输出 |
| `0x2000_0014` | GPIO_OUT | R/W | 输出值 |
| `0x2000_0018` | GPIO_IN | R | 外部输入脚 |
| `0x2000_0020` | TIMER_CTRL | R/W | bit0=timer 使能 |
| `0x2000_0024` | TIMER_CMP | R/W | 周期匹配值 |
| `0x2000_0028` | TIMER_CNT | R | 当前计数值 |
| `0x2000_002C` | TIMER_CLR | W | 写任意值清中断标志 |
| `0x2000_0030` | INTE | R/W | bit0=定时器中断使能 |
| `0x2000_0034` | INTF | R/W1C | bit0=定时器中断标志，写 1 清零 |

## 5.4.3 中断与数据通路

教学版中断（见 `ch4_irq_datapath.svg`）：定时器 `cnt==cmp` 置 `INTF[0]`；若 `INTE[0]=1`，则 `irq_to_core=1`，CPU 下一拍取指跳到 `TRAP_VEC=0x100`，并把返回地址 `pc+4` 写入 `x5`。ISR 末尾 `jalr x0, x5, 0` 返回。**这是教学简化**——没有 Cause CSR、没有栈切换、没有特权级，只为讲清"中断=跳转到 ISR 再回来"。要做完整特权架构可替换为 5.1 的完整核。

数据通路：CPU 出 `dmem_addr` → `ch4_bus_mux` 译码片选 → 各外设；被读外设数据经 `m_rdata` 返回 CPU。

## 5.4.4 裸机软件

- `startup_ch4.s`：复位入口设栈、清 `.bss`、调 `main()`；`0x100` 中断向量调 C 层 `isr_timer()`。
- `ch4_link.ld`：RAM 起点 `0x00000000`、4KB、栈顶在 RAM 顶端。
- `ch4_main.c`：配置 GPIO 为输出、串口打印、启动定时器并使能中断；主循环轮询 `GPIO_IN` 镜像到 `GPIO_OUT`，按键按下打印 `'B'`。
- `ch4_firmware.hex`：手工汇编的教学镜像（由 `gen_fw.py` 生成），复位后打印 `"OK"`、配置 GPIO/定时器/中断、循环镜像 GPIO，ISR 在 `0x100` 翻转 LED 并清标志。

## 5.4.5 资源估算与上板步骤

资源估算方法（Vivado 综合后看 `Utilization` 报告，本仓库未综合）：
- 教学 RV 核 + 寄存器堆 ≈ 数百 LUT/FF；
- 4KB RAM 可映射为 BRAM（1 块 36Kb BRAM 足够）；
- UART/GPIO/Timer 各约几十 LUT。

上板步骤（见 `ch4_board_flow.svg`，待用户在 Vivado 完成）：
1. 新建 Vivado 工程，加入 `code/phase5/ch4_*.v`；
2. 写 `.xdc` 约束：`clk`、`tx_o`、`rx_i`、`gpio[7:0]` 引脚；
3. 把 `ch4_firmware.hex` 加入工程（`$readmemh` 加载）；
4. Synthesis → Implementation → Generate Bitstream → JTAG 下载；
5. 串口终端观察 `"OK"`，LED 按定时器周期闪烁。

## 5.4.6 "运行操作系统"作为进阶方向

任务里写的"在自制 SoC 上运行简单操作系统"是**进阶目标**，本仓库如实说明：
- 本 SoC 目前跑的是**裸机轮询 + 中断**程序，不是 OS；
- 想跑协作式调度器，可在 `main()` 的 while 循环里加任务切换；
- 想跑真正 RTOS（如开源 RT-Thread），需要完整 RV32I 特权指令、时钟节拍、内存保护与移植 BSP——这是后续工程，**本仓库未实现、未声称已跑 OS**。

官方参考（访问于 2026-10）：
- RT-Thread 官网：<https://www.rt-thread.org/index.html>
- RT-Thread GitHub：<https://github.com/RT-Thread/rt-thread>
- 开源软核 NEORV32（类单片机 SoC，自带 UART/GPIO/Timer/IRQ）：<https://github.com/stnolting/neorv32>

> 如实声明：本 SoC 仅做行为仿真与结构校验；真实综合、上板、跑 C、跑 OS 均需用户在 Vivado + RISC-V 交叉工具链环境完成。
