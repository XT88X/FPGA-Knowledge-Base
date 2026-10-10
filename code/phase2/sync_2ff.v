//==============================================================================
// sync_2ff.v  —  可综合：单 bit 异步输入两级触发器同步
// 目标器件：通用 Xilinx Artix-7 / Zynq（7 系列）
//
// 原理：异步输入在时钟沿附近变化时，第一级触发器可能进入亚稳态
//   （输出不确定、需一段时间才稳定）。两级触发器把信号再打一拍：
//   即使第一级亚稳，到第二级采样时通常已稳定，从而把亚稳态局限在
//   第一级、避免传播到后续逻辑。
//   q1 <= async_in; q2 <= q1; sync_out = q2;
//==============================================================================
`default_nettype none

module sync_2ff (
    input  wire clk,
    input  wire rst_n,
    input  wire async_in,   // 异步输入（跨时钟域/按键）
    output wire sync_out     // 同步后输出
);

    reg q1, q2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q1 <= 1'b0;
            q2 <= 1'b0;
        end else begin
            q1 <= async_in;
            q2 <= q1;
        end
    end

    assign sync_out = q2;

endmodule

`default_nettype wire
