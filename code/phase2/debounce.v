//==============================================================================
// debounce.v  —  可综合：机械按键延时消抖（计数窗口法）
// 目标器件：通用 Xilinx Artix-7 / Zynq（7 系列）
//
// 原理：机械按键按下/松开时会在高低电平间抖动约 5~20ms。
//   只有当输入 key_in 与当前稳定输出 key_out 不一致、且这种不一致
//   连续保持 HOLD_MS 不抖动，才更新输出。
//   计数：HOLD_CNT = CLK_FREQ_HZ * HOLD_MS / 1000
//   例：50MHz、20ms => 50,000,000*0.02 = 1,000,000，需 20 bit。
//   key_in 低有效（按下为 0），复位后 key_out 默认高电平(松开)。
//==============================================================================
`default_nettype none

module debounce #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer HOLD_MS     = 20
)(
    input  wire clk,
    input  wire rst_n,
    input  wire key_in,     // 原始按键，低有效
    output reg  key_out    // 消抖后稳定信号，低有效
);

    localparam integer HOLD_CNT = CLK_FREQ_HZ * HOLD_MS / 1000;  // 1,000,000
    localparam integer CNT_W     = 20;                            // 2^20=1.05M

    reg [CNT_W-1:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt     <= {CNT_W{1'b0}};
            key_out <= 1'b1;            // 默认松开
        end else if (key_in == key_out) begin
            // 输入与当前输出一致：抖动回到原态，计数清零
            cnt <= {CNT_W{1'b0}};
        end else if (cnt >= HOLD_CNT - 1) begin
            // 输入稳定保持够久：采纳并更新
            cnt     <= {CNT_W{1'b0}};
            key_out <= key_in;
        end else begin
            cnt <= cnt + 1'b1;
        end
    end

endmodule

`default_nettype wire
