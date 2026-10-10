//==============================================================================
// key_toggle.v  —  可综合：按一下切换一次 LED（内部复用 debounce）
// 目标器件：通用 Xilinx Artix-7 / Zynq（7 系列）
//
// 链路：原始按键 -> debounce 消抖 -> 打一拍做下降沿检测 -> led 翻转。
//   key 低有效；按下(同步消抖后的下降沿)触发一次 led 翻转。
//==============================================================================
`default_nettype none

module key_toggle #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer HOLD_MS      = 20
)(
    input  wire clk,
    input  wire rst_n,
    input  wire key_in,
    output reg  led
);

    wire key_db;       // 消抖后、低有效
    reg  key_db_d;     // 打一拍做边沿检测

    debounce #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .HOLD_MS(HOLD_MS)
    ) u_debounce (
        .clk    (clk),
        .rst_n  (rst_n),
        .key_in (key_in),
        .key_out(key_db)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) key_db_d <= 1'b1;
        else        key_db_d <= key_db;
    end

    wire key_fell = key_db_d & ~key_db;   // 消抖后下降沿 = 一次有效按下

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) led <= 1'b0;
        else if (key_fell) led <= ~led;
    end

endmodule

`default_nettype wire
