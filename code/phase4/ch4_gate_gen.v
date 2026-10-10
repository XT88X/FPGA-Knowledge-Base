//============================================================================
// ch4_gate_gen.v — 闸门发生器（可综合）
//   由系统时钟（默认 50MHz）产生一个精确的闸门窗口：
//     gate 高电平 GATE_TICKS 个时钟 -> 闸门窗口，允许被测脉冲计数；
//     随后 gate 低电平 HOLD_TICKS 个时钟 -> 保持/显示期；
//     如此循环。gate_done 在闸门落下的那一拍输出 1 拍脉冲，
//   作为"锁存 + 清零"的触发。
//   仿真加速：把 GATE_TICKS 改小（例如 100）即可把 1s 闸门压成几百纳秒。
//============================================================================
module ch4_gate_gen #(
    parameter integer CLK_FREQ_HZ = 50_000_000,  // 系统时钟频率
    parameter integer GATE_TICKS   = 50_000_000,  // 闸门高电平时钟数（默认 1s）
    parameter integer HOLD_TICKS   = 5_000_000    // 闸门关闭后的保持时钟数（默认 0.1s）
)(
    input  wire clk,
    input  wire rst_n,
    output reg  gate,        // 闸门：高电平期间允许事件计数
    output reg  gate_done    // 闸门结束的 1 拍脉冲
);
    localparam integer TOTAL = GATE_TICKS + HOLD_TICKS;

    reg [31:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt       <= 32'd0;
            gate      <= 1'b0;
            gate_done <= 1'b0;
        end else begin
            gate_done <= 1'b0;
            if (cnt == TOTAL - 1)
                cnt <= 32'd0;
            else
                cnt <= cnt + 1'b1;

            gate      <= (cnt < GATE_TICKS);
            // cnt 刚进入保持期（即闸门落下）的那一拍给出锁存脉冲
            if (cnt == GATE_TICKS)
                gate_done <= 1'b1;
        end
    end
endmodule
