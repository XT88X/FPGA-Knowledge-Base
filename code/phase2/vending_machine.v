//==============================================================================
// vending_machine.v  —  可综合：自动售货机（三段式 FSM，Mealy）
// 目标器件：通用 Xilinx Artix-7 / Zynq（7 系列）
//
// 简化模型：商品 1.5 元，只接受 0.5 元 / 1 元投币脉冲。
//   金额状态：A0=0元, A05=0.5元, A10=1.0元
//   规则：
//     A0  +0.5 -> A05 ; +1.0 -> A10
//     A05 +0.5 -> A10 ; +1.0 -> 出货(0.5+1.0=1.5)，回 A0
//     A10 +0.5 -> 出货(1.0+0.5=1.5)，回 A0
//     A10 +1.0 -> 出货且找零0.5(1.0+1.0=2.0)，回 A0
//   输出 dispense / change_05 与当前输入有关 => Mealy 型。
//==============================================================================
`default_nettype none

module vending_machine (
    input  wire clk,
    input  wire rst_n,
    input  wire coin_05,    // 投入 0.5 元脉冲
    input  wire coin_10,    // 投入 1.0 元脉冲
    output reg  dispense,   // 出货
    output reg  change_05   // 找零 0.5 元
);

    localparam A0  = 2'd0;
    localparam A05 = 2'd1;
    localparam A10 = 2'd2;

    reg [1:0] state;
    reg [1:0] next;

    // 第一段：时序状态寄存器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= A0;
        else        state <= next;
    end

    // 第二段：组合次态逻辑
    always @(*) begin
        next = state;
        case (state)
            A0:  if (coin_10)      next = A10;
                 else if (coin_05) next = A05;
            A05: if (coin_10)      next = A0;   // 1.5 出货
                 else if (coin_05) next = A10;
            A10:                     next = A0;   // 1.5 或 2.0 出货
            default: next = A0;
        endcase
    end

    // 第三段：组合输出（Mealy）
    always @(*) begin
        dispense  = 1'b0;
        change_05 = 1'b0;
        case (state)
            A05: if (coin_10) dispense = 1'b1;          // 0.5+1.0=1.5
            A10: if (coin_05) dispense = 1'b1;        // 1.0+0.5=1.5
                 else if (coin_10) begin
                     dispense  = 1'b1;                  // 2.0
                     change_05 = 1'b1;                  // 找零 0.5
                 end
            default: ;
        endcase
    end

endmodule

`default_nettype wire
