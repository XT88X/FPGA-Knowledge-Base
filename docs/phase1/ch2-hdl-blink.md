# 1.2 HDL 基础与第一个电路

## Verilog 模块结构

一个可综合的 Verilog 模块就像一颗芯片的外壳：有模块名、有对外端口（input/output）、内部是电路描述。基本骨架：

```verilog
module 模块名 #(参数)(
    input  wire clk,      // 输入
    input  wire rst_n,    // 输入
    output reg  led       // 输出
);
    // 内部信号与 always 块
endmodule
```

- `input wire`：输入信号；`output reg`：在 `always` 块里赋值的输出要声明为 `reg`（注意：`reg` 不一定真是触发器，只是"在过程块里被赋值的变量"）。
- 端口方向 `input/output/inout` 决定数据流向，综合后对应芯片引脚。

## always 块与时钟触发

时序逻辑的标准写法是**同步时序 always 块**：

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)      cnt <= 0;       // 异步复位
    else if (...)    cnt <= cnt + 1; // 时钟沿到来才更新
end
```

`@(posedge clk)` 表示"只在 clk 上升沿动作"——这会被综合成触发器，所有状态变化都发生在时钟沿，这就是时序电路的根基。**组合逻辑**用 `always @(*)` 或 `assign`；本阶段先把时序写对。

## 计数器与时钟分频原理

LED 以固定频率闪烁，本质是"数够 N 个时钟就翻转一次 LED"。

- 板载时钟 50 MHz，即每秒 50,000,000 个时钟沿。
- 想让 LED **每秒翻转一次**（亮 1 秒、灭 1 秒，周期 2 秒），那么两次翻转之间应隔
  `50,000,000 / 2 = 25,000,000` 个时钟。
- 所以计数器从 0 数到 `25,000,000 - 1`，计满就翻转 `led` 并清零。

**计数器位宽推导**：需要多少位才能数到 25,000,000？
位宽 W 要满足 `2^W >= 25,000,000`。
`2^24 = 16,777,216`（不够），`2^25 = 33,554,432`（够），所以 **W = 25 bit**。
代码里用 `reg [24:0] cnt`（共 25 位）。

> 通用公式：半周期计数 = `CLK_FREQ_HZ / (2 * BLINK_HZ)`；位宽 = `ceil(log2(半周期计数))`。
> 本仓库 `led_blink.v` 用参数 `CLK_FREQ_HZ / BLINK_HZ` 自动计算，换板子只需改参数。

## 顶层模块与引脚分配

写好的 `led_blink.v` 是一个可复用模块；真正上板要再写一个**顶层模块**把它的端口接到芯片引脚上。
引脚分配不写在 Verilog 里，而写在 **XDC 约束文件**里：`create_clock` 定时钟周期，`PACKAGE_PIN` 定引脚号，`IOSTANDARD` 定电平（一般 `LVCMOS33`）。模板见 `code/common/fpga_common.xdc`，按你板子替换引脚号。

## 第一个实验：LED 闪烁

可综合代码 `led_blink.v`（参数化时钟与翻转间隔，带异步复位）。配合 1.3 的 testbench，先仿真看计数器波形，再做引脚分配、全编译、下载到板上看到 LED 每秒闪一次。
