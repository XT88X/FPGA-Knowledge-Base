//==============================================================================
// clk_divider.v — 纯 RTL 整数分频（仅用于行为仿真与原理理解）
//------------------------------------------------------------------------------
// 说明：
//   本文件给出两种最常见的"由高频系统时钟得到低频时序"的纯 RTL 写法：
//     1) clk_div_even —— 偶数分频，输出 50% 占空比的分频时钟（DIV 必须为偶数）。
//     2) clk_div_tick —— 使能分频，每 DIV 个输入时钟产生一个单周期高电平 tick，
//                        下游逻辑仍跑在原始时钟上，用 if(tick) 做"慢动作"。
//
// 【重要】这是行为模型，仅供仿真理解原理。
//   - 真实多路时钟/低抖动时钟在 Artix-7/Zynq 上必须用 Clocking Wizard(MMCM/PLL)
//     IP 生成（见本章文档）。纯 RTL 计数器分频会累积抖动、走普通布线资源，
//     不能当作芯片级时钟树。
//   - 推荐工程做法：慢节拍优先用"使能分频(clk_div_tick)+原时钟"，
//     即单时钟设计里给逻辑打拍，而不是真的生成一个新时钟。
//==============================================================================

// 1) 偶数分频，50% 占空比
module clk_div_even #(
    parameter DIV = 4   // 分频系数，必须为偶数且 >= 2（4 -> 四分频）
)(
    input  wire clk,
    input  wire rst_n,   // 异步低电平复位
    output reg  clk_out  // 50% 占空比分频输出
);
    localparam HALF = DIV / 2;          // 半周期计数
    reg [25:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt     <= 26'd0;
            clk_out <= 1'b0;
        end else if (cnt == HALF - 1) begin
            cnt     <= cnt + 26'd1;
            clk_out <= ~clk_out;          // 到半周期翻转一次
        end else if (cnt == DIV - 1) begin
            cnt     <= 26'd0;
            clk_out <= ~clk_out;          // 到整周期再翻转一次 -> 50% 占空比
        end else begin
            cnt     <= cnt + 26'd1;
        end
    end
endmodule


// 2) 使能分频：每 DIV 个时钟输出一个单周期 tick（任意整数 DIV 都可用）
module clk_div_tick #(
    parameter DIV = 5    // 分频系数，任意整数 >= 1（5 -> 每 5 个时钟一个 tick）
)(
    input  wire clk,
    input  wire rst_n,
    output reg  tick     // 单周期高电平使能脉冲
);
    reg [25:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt  <= 26'd0;
            tick <= 1'b0;
        end else begin
            tick <= 1'b0;                 // 默认拉低，保证单周期
            if (cnt == DIV - 1) begin
                cnt  <= 26'd0;
                tick <= 1'b1;
            end else begin
                cnt  <= cnt + 26'd1;
            end
        end
    end
endmodule
