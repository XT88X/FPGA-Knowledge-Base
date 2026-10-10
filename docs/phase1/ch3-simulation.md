# 1.3 仿真验证入门

## 为什么要仿真

上板下载一次要综合、实现、生成比特流，慢；而且硬件错了很难定位。
**仿真**是在电脑里用软件"模拟"电路的行为，让你在几分钟内看到任意信号的波形、提前抓 bug。
专业 FPGA 开发里，写 testbench 的时间往往不亚于写设计本身。

## Testbench 结构

Testbench（测试平台）是一个**没有输入输出端口**的顶层模块，它负责：
1. 例化被测设计（DUT, Design Under Test）；
2. 产生激励：时钟、复位、输入信号；
3. 把内部信号导出成波形（`$dumpvars`）；
4. 用 `$display` / 断言判断结果对不对。

```verilog
module tb_led_blink;
    reg clk=0, rst_n=0; wire led;
    always #10 clk = ~clk;              // 产生 50MHz 时钟(周期20ns)
    led_blink u_dut(.clk(clk),.rst_n(rst_n),.led(led));  // 例化DUT
    initial begin
        $dumpvars;                      // 导出波形
        #55 rst_n=1;  #3000; $finish;   // 复位后跑一段时间结束
    end
endmodule
```

## 时钟激励与复位

- 时钟：`always #10 clk = ~clk;` —— 每 10 ns 翻转，周期 20 ns = 50 MHz。
- 复位：先把 `rst_n=0` 保持几十 ns，再拉高，模拟真实上电复位顺序。
- **仿真提速技巧**：真实 1 Hz 翻转要等 25,000,000 个时钟才动一下，仿真里直接等到天荒地老。
  所以 testbench 例化时把 `BLINK_HZ` 调大（如 1,000,000），半周期只剩 25 个时钟，几微秒就能看到 LED 翻转。上板再改回 1。

## 波形查看与信号分析

Vivado Simulator 跑完会出波形窗口：把 `clk`、`rst_n`、`cnt`、`led` 加进去，
你应能看到 `cnt` 从 0 一路数上去、计满后 `led` 翻转、`cnt` 清零——这就验证了 1.2 的分频逻辑。

## 行为仿真 vs 时序仿真

- **行为仿真（Behavioral）**：只按 Verilog 语义模拟，不考虑门延迟和布线延迟，跑得快，用于验证功能对错。
- **时序仿真（Timing/Post-Route）**：把综合布局布线后的真实门延迟、线延迟加回去，最接近硬件真实行为，能发现建立/保持时间违例导致的亚稳态问题，但慢。

初学者先把行为仿真做对；等阶段 4 学时序约束后再用时序仿真把关。

## 进阶：PWM 呼吸灯

在闪烁基础上做 `breathing_led.v`：用一个高速计数器当 PWM 载波，让 `duty`（占空比）缓慢爬升再下降，
LED 平均亮度随之渐变，就是呼吸灯。配套 `tb_breathing_led.v` 观察 `duty` 与 `led` 高电平占比的关系。
