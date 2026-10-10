# 2.4 有限状态机 FSM

## 什么是状态机

**有限状态机(FSM)** 把一个时序系统拆成有限个**状态**，根据当前状态和输入决定**下一个状态**和**输出**。凡是"按步骤流转、有先后顺序"的控制逻辑（交通灯、售货机、串口收发、协议握手）都该用状态机写，而不是一堆嵌套 if。

## Moore 与 Mealy

- **Moore 型**：输出**只由当前状态**决定。输出画在状态里，更稳定（不会因输入毛刺立刻变），但输出比输入晚一拍。
- **Mealy 型**：输出由**当前状态 + 当前输入**共同决定。输出画在转移边上，响应更快、状态数更少，但对输入毛刺更敏感。

![Moore vs Mealy](../../../assets/phase2/moore-vs-mealy.svg)

交通灯是典型 Moore（灯色只取决于当前是哪个相位）；售货机的"出货/找零"取决于当前金额状态**和**刚投的币，是 Mealy。

## 三段式状态机标准写法

推荐把状态机拆成三段，清晰、易维护、易约束：

1. **第一段·时序状态寄存器**：`state <= next;`（时钟沿更新现态）。
2. **第二段·组合次态逻辑**：`always @(*) case(state)` 算 `next`。
3. **第三段·组合（或时序）输出**：根据 `state`（和输入）算输出。

```verilog
// 第一段
always @(posedge clk or negedge rst_n)
  if (!rst_n) state <= S0; else state <= next;
// 第二段
always @(*) begin
  next = state;
  case (state) ... endcase
end
// 第三段
always @(*) begin
  dispense = 1'b0; ...
end
```

## 状态编码与优化

- **二进制编码**：用最少触发器（n 状态需 log2(n) 位），但译码组合逻辑复杂。
- **独热编码(one-hot)**：每个状态一位，n 状态用 n 个触发器。FPGA 触发器资源充裕而 LUT 紧张，独热编码译码简单、速度快、毛刺少，是 FPGA 常用选择。
- 状态用 `localparam` 定义，不要用裸数字。

## 实例一：交通灯

`traffic_light.v` 是 Moore 状态机，4 个状态循环：

```
NS_G(南北绿/东西红) → NS_Y(南北黄/东西红)
→ EW_G(东西绿/南北红) → EW_Y(东西黄/南北红) → NS_G
```

每个状态维持 `T_GREEN` / `T_YELLOW` 拍后切换。输出做**互锁**：任一方向同一时刻只亮一种灯，另一方向必为红。

![交通灯状态转移图](../../../assets/phase2/traffic-fsm.svg)

`tb_traffic_light.v` 跑完整周期并逐状态断言互锁。

## 实例二：自动售货机

`vending_machine.v` 是三段式 Mealy 状态机。商品 1.5 元，只收 0.5/1 元：

- 金额状态：`A0 / A05 / A10`。
- `A05 + 投1.0` = 1.5 → 出货；`A10 + 投0.5` = 1.5 → 出货；`A10 + 投1.0` = 2.0 → 出货并找零 0.5。

![售货机状态转移图](../../../assets/phase2/vending-fsm.svg)

`tb_vending_machine.v` 覆盖三种投币组合与复位。

## 关键小结

- 三段式：状态寄存器 / 次态组合 / 输出组合。
- Moore 输出只看状态；Mealy 输出看状态+输入。
- FPGA 优先独热编码；状态用 localparam。

> 本仓库环境无 Vivado 工程，代码均通过结构校验；实际综合与上板看到交通灯/售货机效果需在 Vivado ML Standard（Artix-7/Zynq）中完成。
