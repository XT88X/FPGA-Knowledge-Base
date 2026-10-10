//============================================================================
// ch4_event_counter.v — 闸门内事件计数器（可综合）
//   在 gate 高电平期间，对 sig_in 的上升沿计数。
//   被测信号先经过 2 级触发器同步（跨时钟域基本处理），再做边沿检测。
//   latch 脉冲把当前计数值打入 latched 寄存器；clr 脉冲清零。
//
//   说明（教学实现的精度边界）：
//     本模块用系统时钟采样被测信号边沿，可综合、易仿真；
//     对接近系统时钟频率（如 50MHz）的被测信号，采样法会丢边沿。
//     工业级做法是用被测信号本身做异步计数器、闸门结束后再跨域读取，
//     本仓库在 md 中给出思路，RTL 以教学可验证为准。
//============================================================================
module ch4_event_counter #(
    parameter integer CNT_WIDTH = 27   // 2^27 ≈ 1.34e8 > 50MHz×1s
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  sig_in,    // 被测方波
    input  wire                  gate,      // 闸门：高电平期间允许计数
    input  wire                  latch,     // 锁存脉冲：count -> latched
    input  wire                  clr,        // 清零脉冲
    output reg  [26:0]         count,     // 当前计数值
    output reg  [26:0]         latched,   // 锁存的上一次结果
    output reg                  overflow  // 计满溢出标志
);
    reg sync1, sync2, sync3;
    wire rise = sync2 & ~sync3;   // 同步后的上升沿

    // 2 拍同步 + 1 拍用于边沿检测
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync1 <= 1'b0;
            sync2 <= 1'b0;
            sync3 <= 1'b0;
        end else begin
            sync1 <= sig_in;
            sync2 <= sync1;
            sync3 <= sync2;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count    <= {CNT_WIDTH{1'b0}};
            latched  <= {CNT_WIDTH{1'b0}};
            overflow <= 1'b0;
        end else begin
            if (clr) begin
                count    <= {CNT_WIDTH{1'b0}};
                overflow <= 1'b0;
            end else if (gate && rise) begin
                if (count == {CNT_WIDTH{1'b1}})
                    overflow <= 1'b1;
                else
                    count <= count + 1'b1;
            end
            if (latch)
                latched <= count;
        end
    end
endmodule
