# 5.1 RISC-V 软核入门

到这里你已经会写状态机、会调 IP、会用 BRAM。下一步是把前面所有知识攒起来——**亲手造一颗 CPU**。本节我们不追求高性能，而是做一颗"能跑 C 程序、能从串口打印"的教学型 RISC-V 软核，把"指令到底是怎么被执行的"这件事彻底讲透。

## 5.1.1 CPU 到底在干什么

一颗通用 CPU 反复做同一件事——**取一条指令、译码它、执行它、把结果写回去**，然后 PC 指向下一条，周而复始。经典五级流水线把这件事拆成五拍：

1. **取指 IF**：PC 给出地址，从指令存储器读出 32-bit 指令；
2. **译码 ID**：把指令拆成 opcode / rd / rs1 / rs2 / 立即数，从寄存器堆读出操作数；
3. **执行 EX**：ALU 做加减/比较/算地址；
4. **访存 MEM**：需要时读/写数据存储器；
5. **写回 WB**：把结果写回寄存器堆。

配套的核心部件：

- **PC（程序计数器）**：存当前指令地址，每拍 +4（或被分支/跳转改写）；
- **寄存器堆（Regfile）**：32 个 32-bit 通用寄存器 `x0..x31`，其中 `x0` 硬连线恒为 0（写它无效、读它为 0）；
- **ALU**：做算术/逻辑/比较；
- **存储器总线**：指令口 + 数据口（本教学核合并成一条 von Neumann 总线）。

> 教学取舍：真实 CPU 是五级流水线、乱序执行；我们把它**压平成单周期**——一个时钟拍完成"取指→译码→执行→访存→写回"全部动作。这样你看一眼数据通路就知道每条指令在哪一拍被算出来，理解优先于性能。

## 5.1.2 RISC-V RV32I 与六种指令格式

RISC-V 的指令定长 32-bit（基础整数指令集 RV32I），低 7 位是 `opcode`。它只有**六种指令格式**，这正是 RISC-V "精简"的精髓——格式少，译码简单：

| 格式 | 用途 | 典型指令 |
|---|---|---|
| **R** | 寄存器-寄存器运算 | `ADD/SUB/AND/OR/XOR/SLT/SLTU` |
| **I** | 立即数运算 / 加载 / 跳转寄存器 | `ADDI/ANDI/ORI/XORI/SLTI/SLTIU`、`LW`、`JALR` |
| **S** | 存储 | `SW` |
| **B** | 分支（条件跳转） | `BEQ/BNE` |
| **U** | 高位立即数 | `LUI/AUIPC` |
| **J** | 无条件跳转 | `JAL` |

六种格式的位段排布见配套图 `ch1_rv32i_formats.svg`。本教学核实现的指令子集：

- **立即数运算**：`ADDI / ANDI / ORI / XORI / SLTI / SLTIU`
- **寄存器运算**：`ADD / SUB / AND / OR / XOR / SLT / SLTU`
- **访存**：`LW / SW`（按字）
- **控制流**：`BEQ / BNE / JAL / JALR`
- **高位立即数**：`LUI / AUIPC`

> 这套子集够写循环、累加、查表、串口打印。乘除、移位、原子指令等留到后续扩展。

## 5.1.3 数据通路与控制器怎么搭

本仓库代码 `code/phase5/ch1_riscv_*.v` 分成四块：

- `ch1_riscv_regfile.v`：32×32 寄存器堆，组合读、时钟沿同步写，`x0` 恒零；
- `ch1_riscv_alu.v`：组合 ALU，支持 ADD/SUB/AND/OR/XOR/SLT/SLTU，输出 `zero`；
- `ch1_riscv_core.v`：单周期核心——PC 寄存器、立即数生成、控制器（按 opcode/funct3 选 ALU 操作数与写回来源）、下一条 PC 计算；
- `ch1_riscv_soc.v`：把核心 + 4KB 统一 RAM + 内存映射 UART 寄存器拼成最小 SoC。

**写回来源**由控制器选择：`LW` 取数据存储器读出值；`LUI` 取高位立即数；`JAL/JALR` 取 `PC+4`；其余取 ALU 结果。**下一条 PC**：分支成立取 `PC+imm_b`，`JAL` 取 `PC+imm_j`，`JALR` 取 `(rs1+imm_i)&~1`，否则 `PC+4`。数据通路框图见 `ch1_cpu_datapath.svg`。

## 5.1.4 最小 SoC 内存映射

`ch1_riscv_soc.v` 的地址空间：

| 地址区间 | 部件 | 说明 |
|---|---|---|
| `0x0000_0000 ~ 0x0000_0FFF` | 片上统一 RAM（4KB） | 取指与 `LW/SW` 都走这里；上电 `$readmemh("ch1_firmware.hex")` 加载固件 |
| `0x1000_0000` | UART 数据寄存器 | 写一个字节 = "打印一个字符"（本核只做字符打印寄存器，完整 UART 发送器在 5.4 集成） |

SoC 框图见 `ch1_soc_block.svg`。

## 5.1.5 验证：机器码 + 断言

`ch1_firmware.hex` 是手工汇编的一小段程序：用循环求 `1+2+...+10`，把结果 `0x37(=55)` 存到 `RAM[0]`，再通过 UART 寄存器打印两个字符 `'5'`。`ch1_tb_riscv_soc.v` 跑完后断言：

- `RAM[0] == 0x0000_0037`；
- UART 恰好打印两个 `0x35('5')`。

机器码与汇编一一对应（hex 文件内有注释）。这就是"没有工具链时怎么验证 CPU"的办法：手工编码 + 行为仿真断言。

## 5.1.6 跑 C 程序：Hello World

要跑真正的 C，需要 RISC-V 交叉工具链。推荐 **xPack GNU RISC-V Embedded GCC**（预编译二进制，免自己编译）：

- 官方文档/下载：<https://xpack-dev-tools.github.io/riscv-none-elf-gcc-xpack/docs/install/>（访问于 2026-10）
- GitHub 发布页：<https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack>（访问于 2026-10）

最小 C 工程三件套（本仓库 `code/phase5/`）：

- `ch1_link.ld`：链接脚本，RAM 起点 `0x00000000`、栈顶 `0x1000`；
- `ch1_startup.S`：设栈、清 `.bss`、调 `main()`；
- `ch1_hello.c`：裸机 `putchar` 直写 `0x1000_0000` UART 寄存器，打印 `Hello, RISC-V softcore!`。

构建与转 mem 的命令（**本环境未安装工具链，以下命令与预期已给出、未在本机构建**）：

```bash
riscv-none-elf-gcc -march=rv32i -mabi=ilp32 -O2 \
    -T ch1_link.ld -nostdlib -o ch1_hello.elf ch1_startup.S ch1_hello.c
riscv-none-elf-objcopy -O verilog ch1_hello.elf ch1_firmware.hex
# 再把 ch1_firmware.hex 放进工程，$readmemh 加载
```

> 说明：本教学核是 von Neumann 统一 RAM、无中断、无缓存；`printf` 这类库函数需要自己实现底层 `putchar`，我们直接用寄存器写。

## 5.1.7 上板流程与开源核参考

上板步骤：①把 `ch1_riscv_soc.v` 各文件加入 Vivado 工程；②写顶层把 `uart_tx_data/uart_tx_valid` 接到阶段 3 写过的 UART 发送模块；③加时钟约束与引脚约束；④综合、实现、生成比特流下载；⑤打开串口终端看 `Hello`。

真实项目不必从零写核，可参考开源软核（理解后再裁剪）：

- **PicoRV32**（Claire Wolf / YosysHQ）：极小 RV32I/E/M/C 核，~750–2000 LUT——<https://github.com/YosysHQ/picorv32>（访问于 2026-10）
- **NEORV32**（Stephan Nolting）：类单片机 SoC，自带 UART/GPIO/定时器——<https://github.com/stnolting/neorv32>（数据手册 <https://stnolting.github.io/neorv32/>，访问于 2026-10）
- RISC-V 非特权指令集官方规范：<https://docs.riscv.org/reference/isa/unpriv/unpriv-index.html>（访问于 2026-10）

> 如实声明：本教学核未在 Vivado 真正综合上板，也未用工具链真实构建/运行 C；上述上板与 C 构建命令为流程与预期，需在装有 Vivado + xPack 工具链的环境完成。
