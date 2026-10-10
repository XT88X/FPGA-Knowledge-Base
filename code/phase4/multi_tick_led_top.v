//==============================================================================
// multi_tick_led_top.v — 用不同频率"时钟使能"驱动不同 LED 闪烁（纯 RTL 模型）
//------------------------------------------------------------------------------
// 设计意图：
//   不真正生成多个时钟，而是在同一个 clk 上用三个分频系数不同的 tick，
//   分别翻转 led0/led1/led2 -> 三盏灯以三种不同节奏闪烁。
//
//   led0: 每 DIV0 个时钟翻转一次（最快）
//   led1: 每 DIV1 个时钟翻转一次
//   led2: 每 DIV2 个时钟翻转一次（最慢）
//
// 【上板替换】真实多路不同频率时钟请用 Clocking Wizard(MMCM) IP 生成多个 clk
// 再分别驱动；本模块是"单时钟 + 多使能"的可综合替代，也是工程上更推荐的写法。
//==============================================================================
module multi_tick_led_top #(
    parameter DIV0 = 12500000,   // 50MHz 下约 0.25s 翻转一次
    parameter DIV1 = 25000000,   // 约 0.5s
    parameter DIV2 = 50000000    // 约 1.0s
)(
    input  wire clk,
    input  wire rst_n,
    output wire led0,
    output wire led1,
    output wire led2
);
    wire tick0, tick1, tick2;
    reg  l0, l1, l2;

    clk_div_tick #(.DIV(DIV0)) u_tick0 (.clk(clk), .rst_n(rst_n), .tick(tick0));
    clk_div_tick #(.DIV(DIV1)) u_tick1 (.clk(clk), .rst_n(rst_n), .tick(tick1));
    clk_div_tick #(.DIV(DIV2)) u_tick2 (.clk(clk), .rst_n(rst_n), .tick(tick2));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin l0 <= 1'b0; l1 <= 1'b0; l2 <= 1'b0; end
        else begin
            if (tick0) l0 <= ~l0;
            if (tick1) l1 <= ~l1;
            if (tick2) l2 <= ~l2;
        end
    end

    assign led0 = l0;
    assign led1 = l1;
    assign led2 = l2;

endmodule
