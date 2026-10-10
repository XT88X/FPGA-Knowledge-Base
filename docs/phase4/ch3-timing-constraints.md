# 4.3 时序约束与分析

代码写对、能仿真，不代表上板能跑到目标频率。FPGA 里数据要在一个时钟周期内从一个触发器传到下一个触发器，晚到一点点就会采错。**时序约束 (XDC)** 就是告诉工具"时钟多快、外部数据什么时候到"，工具才能算出"能不能跑稳"。本节讲建立/保持时间、slack 公式、常用 XDC 约束，以及怎么读时序报告。

## 一、建立时间与保持时间

触发器要正确采样数据，数据必须在时钟沿前后保持稳定一段时间（见 `setup_hold_window.svg`）：

- **建立时间 setup**：采样沿**之前**，数据必须提前稳定的时间。数据到太晚 → 违反建立时间。
- **保持时间 hold**：采样沿**之后**，数据必须继续保持稳定的时间。数据变太早 → 违反保持时间。

**时钟不确定性 (clock uncertainty / jitter)**：时钟沿本身有抖动和偏斜，会"吃掉"一部分可用时间。

## 二、reg-to-reg 路径与 slack

最基本的时序路径是"触发器到触发器"（见 `reg_to_reg_slack.svg`）：

- **launch 沿**：发送触发器发出数据的时钟沿。
- **capture 沿**：捕获触发器采样的下一个时钟沿。
- 两沿间隔 = 一个时钟周期 `T`。

建立时间 slack（裕量）公式：

```
slack_setup = T周期 - ( t逻辑 + t走线 + t_setup + 时钟抖动 )
```

- `slack ≥ 0`：时间够，时序收敛。
- `slack < 0`：该路径在一个周期内走不完，要优化。

## 三、常用 XDC 约束（见 `code/phase4/ch3_timing_example.xdc`）

### 1. 主时钟 create_clock（必写）

```xdc
create_clock -period 20.000 -name clk_in1 [get_ports clk_in1]
```

50MHz → 周期 20ns。**没有这条，Vivado 根本不做 reg-to-reg 时序分析**。

### 2. 生成时钟 create_generated_clock

MMCM/PLL 输出的时钟由 IP 自动生成约束，一般不用手写；手写示例见 XDC 注释。综合后用 `report_clocks` 查看所有时钟及其关系。

### 3. 输入/输出延迟

```xdc
set_input_delay  -clock clk_in1 3.0 [get_ports data_in*]   ;# 外部数据相对时钟沿偏移
set_output_delay -clock clk_in1 2.0 [get_ports {led*}]
```

告诉工具外部器件数据什么时候到、要求什么时候送出，工具才能算 IO 路径。

### 4. 时序例外

- **set_false_path**：不需要检查时序的路径，如异步复位引脚。
- **set_multicycle_path**：允许多个周期到达的路径（如慢使能触发的逻辑）。
- **set_clock_groups**：完全异步、互不交互的时钟组，工具不分析它们之间的路径（异步 FIFO 两边常用）。

## 四、时序报告怎么读（Timing Summary）

跑完 Synthesis + Implementation 后，Vivado 的 Timing Summary 给四个关键数：

| 指标 | 含义 | 合格 |
|---|---|---|
| **WNS** (Worst Negative Slack) | 最坏建立时间裕量 | ≥ 0 |
| **TNS** (Total Negative Slack) | 所有违规路径建立裕量之和 | ≥ 0 |
| **WHS** (Worst Hold Slack) | 最坏保持时间裕量 | ≥ 0 |
| **THS** (Total Hold Slack) | 所有违规路径保持裕量之和 | ≥ 0 |

四项全部 ≥ 0（无红色）就是**时序收敛**。WNS 为负说明最快频率跑不到目标，要优化。

## 五、常见时序优化手段

见 `pipeline_timing.svg` 与本仓库 `pipeline_demo.v`：

1. **流水线 (Pipelining)**：在长组合链中间插寄存器，把长路径切成几段。本仓库 `pipeline_demo.v` 对比了 `((a+b)*c)+d` 的无流水线版和三级流水线版——每级延迟变短、易满足建立时间，代价是多一拍延迟。
2. **降低逻辑层级**：重写编码，减少一条路径上的 LUT 级数。
3. **Retiming**：让工具在寄存器间移动组合逻辑，平衡各路径延迟。
4. **约束 IO**：正确写 set_input_delay/set_output_delay。
5. **复制高扇出逻辑**：一个扇出极大的信号（如全局使能）复制多份，减少走线延迟。

## 六、本节代码

- `pipeline_demo.v`：参数化位宽，同一条运算路径的无流水线 vs 三级流水线实现；`tb_pipeline_demo.v` 校验两者功能等价（流水线晚一拍）。
- `ch3_timing_example.xdc`：充分注释的约束示例，时钟按 50MHz=20ns，IO 用占位并引用 `code/common/fpga_common.xdc`，不编造引脚。

> ⚠️ 时序报告必须在**真实 Vivado 综合 + 布局布线**后才有意义；本环境无 Vivado，无法真正跑 Timing Summary，以上 WNS/TNS 等指标需上板/装 Vivado 后验证。

## 七、官方手册（已核实，访问日期 2026-10-10）

- **UG903 Vivado Design Suite User Guide: Using Constraints (v2022.2)**：https://docs.amd.com/v/u/en-US/ug903-vivado-using-constraints （PDF：https://www.xilinx.com/support/documents/sw_manuals/xilinx2022_2/ug903-vivado-using-constraints.pdf ）
- **UG938 Design Analysis and Closure Techniques (v2020.2)**：https://www.xilinx.com/support/documents/sw_manuals/xilinx2020_2/ug938-vivado-design-analysis-closure-tutorial.pdf
- 时序收敛专题导航：https://www.xilinx.com/content/xilinx/en/support/documentation-navigation/design-hubs/dh0006-vivado-design-analysis-and-timing-closure-hub.html
