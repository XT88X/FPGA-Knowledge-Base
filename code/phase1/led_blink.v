//==============================================================================
// led_blink.v  —  可综合：参数化 LED 闪烁
// 目标器件：通用 Xilinx Artix-7 / Zynq（7 系列）
//
// 原理：用一个计数器对系统时钟 clk 计数，计满"半周期"就翻转一次 led。
//   半周期时钟数 = CLK_FREQ_HZ / (2 * BLINK_HZ)
//   例：50 MHz 时钟、1 Hz 翻转亮灭 => 半周期 = 25,000,000 个时钟
//   计数器位宽 = ceil(log2(25,000,000)) = 25 bit（2^24=16.7M, 2^25=33.5M）
// 复位：rst_n 低电平异步复位（开发板按键/上电常用低有效复位）。
//==============================================================================
`default_nettype none

module led_blink #(
    parameter integer CLK_FREQ_HZ = 50_000_000,  // 板载系统时钟频率(Hz)
    parameter integer BLINK_HZ     = 1             // LED 亮灭翻转频率(Hz)
)(
    input  wire clk,        // 系统时钟
    input  wire rst_n,     // 异步低电平复位
    output reg  led        // 接板上 LED
);

    // 半个亮灭周期所需的时钟数
    localparam integer HALF_COUNT = CLK_FREQ_HZ / (2*BLINK_HZ);
    // 计数器位宽：保证能数到 HALF_COUNT-1（这里固定 25 bit 覆盖 50MHz->1Hz）
    localparam integer CNT_W = 25;

    reg [CNT_W-1:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= {CNT_W{1'b0}};
            led <= 1'b0;
        end else if (cnt >= HALF_COUNT - 1) begin
            cnt <= {CNT_W{1'b0}};   // 计满清零
            led <= ~led;            // 翻转 LED
        end else begin
            cnt <= cnt + 1'b1;
        end
    end

endmodule

`default_nettype wire
