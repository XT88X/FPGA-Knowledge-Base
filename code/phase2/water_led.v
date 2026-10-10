//==============================================================================
// water_led.v  —  可综合：8 位流水灯（跑马灯）
// 目标器件：通用 Xilinx Artix-7 / Zynq（7 系列）
//
// 原理：用一个"节拍计数器"每 STEP_MS 产生一次移位：
//   节拍数 = CLK_FREQ_HZ * STEP_MS / 1000
//   例：50MHz、250ms => 50,000,000*0.25 = 12,500,000 个时钟
//   位宽 = ceil(log2(12,500,000)) = 24 bit（2^24=16.7M）。
//   led 初始 8'b0000_0001，每拍循环左移一位：{led[6:0], led[7]}。
//==============================================================================
`default_nettype none

module water_led #(
    parameter integer CLK_FREQ_HZ = 50_000_000,  // 系统时钟(Hz)
    parameter integer STEP_MS      = 250           // 每步间隔(ms)
)(
    input  wire      clk,
    input  wire      rst_n,
    output reg [7:0] led
);

    localparam integer STEP_COUNT = CLK_FREQ_HZ * STEP_MS / 1000;
    localparam integer CNT_W      = 24;          // 覆盖 12.5M

    reg [CNT_W-1:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= {CNT_W{1'b0}};
            led <= 8'b0000_0001;
        end else if (cnt >= STEP_COUNT - 1) begin
            cnt <= {CNT_W{1'b0}};
            led <= {led[6:0], led[7]};   // 循环左移
        end else begin
            cnt <= cnt + 1'b1;
        end
    end

endmodule

`default_nettype wire
