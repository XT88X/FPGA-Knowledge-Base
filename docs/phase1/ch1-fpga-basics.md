# 1.1 FPGA 基础与环境搭建

## 什么是 FPGA

FPGA（Field Programmable Gate Array，现场可编程门阵列）是一种"硬件可重构"的数字集成电路。
和你写的软件不同——软件是在一颗固定的 CPU 上**一条一条串行执行指令**；而 FPGA 是把你写的
硬件描述（Verilog）直接"烧"成芯片内部真实存在的逻辑门、触发器和连线。你定义的每一块电路，
在芯片里都是一块**实实在在同时工作**的物理电路。

FPGA 内部主要由四类资源构成：

- **LUT（查找表）**：实现组合逻辑。本质是一个小 RAM，把真值表存进去，输入一进来就直接查表得到输出，等价于任意组合逻辑函数。
- **FF（触发器/寄存器）**：实现时序逻辑。在时钟沿保存一位状态，是"记忆"的基本单元。
- **BRAM（块存储器）**：成块的高速存储，可当 FIFO、缓存、查表 ROM 用。
- **可编程布线资源**：密密麻麻的开关矩阵，把 LUT、FF、BRAM 自由连起来，你写的模块之间的连线就落在这些布线上。

## 并行执行：FPGA 与 CPU 的本质区别

CPU 像一个"只有一个大厨的餐厅"：再忙也只能一口锅一口锅地炒菜，靠频率（GHz）硬堆吞吐。
FPGA 像"几百个厨师同时开火"：你例化几个模块，它们就在硅片上**各自独立、并行地运行**，
谁也不等谁。一个 50 MHz 的 FPGA 做并行数据搬运，延迟可以远低于 GHz 级 CPU，因为它没有指令取指、没有串行流水线、没有操作系统打扰。

> 记住一句话：**写 Verilog 不是在写"按顺序执行的程序"，而是在画"同时通电的电路图"。**
> 每个 `always` 块都是一块永远在通电工作的硬件，不是"被调用才运行的函数"。

## FPGA 开发全流程（7 步）

1. **设计输入**：用 Verilog 写 RTL（寄存器传输级）代码，描述你想要的电路。
2. **功能仿真（可选但强烈建议）**：写 testbench，在 Vivado Simulator 里先看波形，确认逻辑对。
3. **综合（Synthesis）**：Vivado 把你的 Verilog 翻译成门级电路（LUT/FF 网表）。
4. **实现（Implementation）**：先把网表映射到具体 LUT/FF（Translation/Mapping），再做布局布线（Place & Route），决定每个逻辑放在芯片哪个位置、用哪根线连。
5. **时序约束与分析**：告诉工具时钟频率，工具算出能否跑稳；建立/保持时间裕量要为正。
6. **生成比特流（Bitstream）**：把布局布线结果打包成一个 `.bit` 文件，描述"哪些开关接通、哪些 LUT 存什么真值表"。
7. **下载与调试**：通过 JTAG 下载线把比特流灌进 FPGA，硬件随即按你的电路工作；用 ILA（在线逻辑分析仪）抓真实信号。

## Vivado 安装与建空工程

- 下载 **AMD Vivado ML Standard**（免费、Artix-7/Zynq 无需 License），当前版本 2025.2。
- 安装时勾选 Artix-7 / Zynq-7000 支持包与 **Install Cable Drivers**。
- 新建工程：`Create Project -> RTL Project -> 选对芯片型号(如 XC7A10T fgg484) -> 先不加任何代码`，得到一个空工程，熟悉 Flow Navigator（Project Manager / Synthesis / Implementation / Program）。

## 开发板与通用板卡说明

本系统不绑定具体板卡。通用 Artix-7/Zynq 板一般提供：板载晶振（多为 50 MHz）、复位/用户按键、若干 LED、USB-UART、数码管、VGA 等。
具体引脚号以你板子的官方原理图/参考 XDC 为准，适配方法见 `docs/board-adaptation.md`，通用约束模板见 `code/common/fpga_common.xdc`。
没有开发板也没关系：Vivado 内置仿真器可以先把后面所有实验用 testbench 跑通。
