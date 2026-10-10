# 4.1 IP 核调用与时钟管理

到了系统级开发，你会发现很多"轮子"不用自己造：官方把常用电路封装成**IP 核**，在 Vivado 里双击图形界面、填几个参数就能生成。本节先建立 IP 核的概念，再吃透时钟系统——PLL/MMCM 怎么把 50MHz 晶振变成你想要的多路时钟，以及为什么多路时钟必须走专用时钟网络。

## 一、IP 核是什么，分哪几类

IP（Intellectual Property）核就是"预先做好、验证过的电路模块"，按交付形式分三类：

| 类型 | 说明 | 在 Artix-7/Zynq 上的例子 |
|---|---|---|
| **软核 (Soft IP)** | 用 Verilog 描述、综合时映射到普通逻辑/LUT/BRAM，可综合 | FIFO、FIR 滤波器、UART、自定义外设 |
| **硬核 (Hard IP)** | 芯片里固化的硅电路，不能改但性能最高、最省资源 | Zynq 的 PS(ARM)、SerDes/GTP、PCle 块、ADC |
| **已加密核 (Encrypted/Netlist)** | 只给网表不给源码，授权后可综合，保护算法 | 部分高速接口、第三方算法核 |

Vivado 的 **IP Catalog** 里搜名字即可调用。本节用两个软核：**Clocking Wizard**（时钟）、后面 4.2 的 **Block Memory Generator / FIFO Generator**。

> 经验法则：**能用官方 IP 就别手写**。时钟、存储、高速接口这类对时序/抖动敏感的模块，手写纯 RTL 往往"功能对、时序挂"。但学习原理时手写纯 RTL 模型很有价值——本节代码就是"纯 RTL 行为模型"。

## 二、PLL / MMCM 锁相环原理

板上只有一颗晶振（如 50MHz），但系统里经常需要 100MHz、25MHz、甚至相位错开的多路时钟。**PLL（Phase-Locked Loop，锁相环）**就是干这个的。它由四部分组成（见 `pll_mmcm_internal.svg`）：

1. **PFD（鉴频鉴相器）**：比较输入时钟 `clk_in` 和反馈回来的时钟的相位差，输出"超前/滞后"脉冲。
2. **CP（电荷泵）+ LPF（环路滤波）**：把相位差脉冲转成一个平滑的直流控制电压。
3. **VCO（压控振荡器）**：控制电压越高，振荡越快，输出一个高频 `f_vco`。
4. **反馈分频 N**：把 VCO 频率 N 分频后送回 PFD。锁定后 `f_vco/N == f_in`，于是 `f_vco = N × f_in`。

在 VCO 之后再挂几路**输出分频（M/D0/D1…）**，就从一颗晶振倍频/分频出多路时钟：

```
f_vco = f_in × (反馈倍频)
f_out0 = f_vco / D0
f_out1 = f_vco / D1
```

**抖动 (jitter)**：VCO 输出沿不是绝对干净的，会有微小随机晃动。PLL 锁相后输出抖动远小于你自己用计数器"翻出来"的时钟。

**MMCM vs PLL**：Artix-7 里更常用的是 **MMCM（Mixed-Mode Clock Manager）**，它是 PLL 的增强版。MMCM 在 PLL 基础上多出**相位调整（Phase Adjust）**和更细的占空比/分频：可以对每路输出做 ±相位移动，用来补偿不同布线延迟、对齐多路时钟。PLL 只能倍频/分频，不能移相。

## 三、时钟树：为什么必须走 BUFG

晶振进来后，时钟路径是：`晶振引脚 → IBUF → MMCM/PLL → BUFG（全局时钟缓冲）→ 遍布全片的时钟树 → 每个触发器`（见 `clock_tree.svg`）。

关键概念：

- **时钟偏斜 (clock skew)**：同一个时钟到达不同触发器的时间差。走专用全局时钟网络(BUFG)时 skew 极小且可控。
- 如果你用普通逻辑布线去跑一个"计数器分频出来的时钟"，这条线上 skew 大、延迟不确定，时序几乎一定失败。

> 结论：**真实多路时钟上板必须用 Clocking Wizard(MMCM) IP + BUFG**；纯 RTL 计数器分频只用于仿真理解，或作为"单时钟域里的慢节拍使能"（推荐做法）。

## 四、多时钟域设计基础

一个芯片里有多个频率/相位的时钟，就划分出多个**时钟域 (Clock Domain, CDC 见 `multi_clock_domain.svg`)**。信号从一个时钟域直接跑到另一个时钟域，采样沿可能正好打在数据变化的不确定窗口上，产生**亚稳态 (metastability)**。

- 单 bit 控制信号跨域：用**两级触发器同步器**（阶段2 按键消抖已练过）。
- 多 bit 数据总线跨域：不能一位一位各自同步（各位到达时间不一致会采错），要用**异步 FIFO + 格雷码指针**——这是 4.2 的主题。

## 五、本节纯 RTL 代码（仅仿真/原理）

`code/phase4/clk_divider.v` 给了两个模块：

- **`clk_div_even`**：偶数分频，输出 50% 占空比的分频时钟（参数 `DIV` 必须为偶数）。
- **`clk_div_tick`**：使能分频，每 `DIV` 个时钟输出一个单周期 tick；下游逻辑仍跑在原时钟上，用 `if(tick)` 做慢动作。这是工程上更推荐的"伪分频"写法——不产生新时钟。

`code/phase4/multi_tick_led_top.v`：在**同一个 clk** 上挂三个不同分频系数的 tick，分别翻转 `led0/led1/led2`，实现三灯不同节奏闪烁。`tb_*.v` 内含自检。

> ⚠️ 这些是行为模型。真实上板要生成多路不同频率时钟时，按下一节用 Clocking Wizard IP 替换。

## 六、Vivado Clocking Wizard IP 上板步骤（可照做）

目标：输入 50MHz，生成 100MHz / 25MHz / 50MHz 三路时钟。

1. **打开 IP Catalog**：Flow Navigator → IP Catalog，搜索 `Clocking Wizard`，双击打开配置向导。
2. **Clocking Options 页**：
   - `Primitive` 选 `MMCM`（推荐；PLL 仅在资源紧张时用）。
   - `Input Clock Information`：Input Frequency 填你的板级晶振，如 `50MHz`，时钟类型选 `differential`/`single ended` 按板子。
   - 勾选 `Locked` 输出端口（锁定指示，建议在复位逻辑里等它拉高）。
3. **Output Clocks 页**：
   - `clk_out1` 填 `100MHz`，`clk_out2` 填 `25MHz`，`clk_out3` 填 `50MHz`；占空比先保持 50%。
   - 若需要移相，在对应输出的 `Phase` 里填度数（这是 MMCM 才有的能力）。
   - Vivado 会自动算出 VCO 频率和倍/分频系数，并提示是否在 MMCM 合法范围内（红色报错即超范围）。
4. **确认与生成**：OK → Generate。Vivado 生成 `clk_wiz.xci` 和例化模板。
5. **例化**：把生成的 `clk_wiz_0.veo` 模板复制进你的顶层，端口典型为：
   - 输入：`clk_in1`（接板级 50MHz 引脚）、`reset`（高有效复位，可接复位按键）。
   - 输出：`clk_out1/clk_out2/clk_out3`、`locked`。
6. **复位注意**：`locked` 拉高前时钟未稳定，下游应保持复位；通常 `rst_sys = ~locked | 外部复位`。

### XDC 时钟约束

主时钟约束（在你的约束文件里，`code/common/fpga_common.xdc` 是通用模板，按板子改引脚）：

```xdc
# 主时钟：50MHz 晶振接在引脚 xxx，周期 20ns
create_clock -period 20.000 -name clk_in1 [get_ports clk_in1]
```

Clocking Wizard IP 内部会自动为每路输出生成 **generated clock**（`create_generated_clock` 由 IP 自带约束给出），一般不用手写；综合后可用 `report_clocks` 确认所有时钟及它们的关系。

### 何时用纯 RTL，何时用 IP

| 场景 | 选择 |
|---|---|
| 单时钟域里做慢节拍（LED 闪烁、秒计数） | 纯 RTL 使能分频 `clk_div_tick`，最省资源 |
| 需要不同频率的真时钟域、低抖动、移相 | Clocking Wizard (MMCM) IP |
| 多时钟之间要跨域传数据 | IP 生成时钟 + 4.2 的异步 FIFO |

## 七、官方手册（已核实，访问日期 2026-10-10）

- **PG065 Clocking Wizard Product Guide (v6.0)**：https://docs.amd.com/v/u/en-US/pg065-clocking-wizard （产品介绍页：https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/clocking_wizard.html ）
- 通用约束写法见 4.3 的 **UG903**。

> 说明：Clocking Wizard(MMCM) 是 Xilinx 原语，本仓库纯 RTL 模型仅用于仿真理解原理；上板生成多路时钟必须在真实 Vivado 里调用 Clocking Wizard IP 并综合验证。
