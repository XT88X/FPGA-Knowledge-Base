//==============================================================================
// water_led_dir.v  —  可综合：按键控制双向流水灯
// 目标器件：通用 Xilinx Artix-7 / Zynq（7 系列）
//
// 本章为简化示例，对外部按键 key 做"内置两级同步 + 下降沿检测"：
//   * key 低有效（按下为 0）。
//   * key_s1/key_s2 两级触发器把异步按键同步到时钟域（跨域初处理，
//     完整消抖见 2.3）。
//   * 检测同步后信号的下降沿（按下瞬间）翻转方向 dir。
//   * dir=0 循环左移，dir=1 循环右移。
//==============================================================================
`default_nettype none

module water_led_dir #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer STEP_MS      = 250
)(
    input  wire      clk,
    input  wire      rst_n,
    input  wire      key,     // 异步按键，低有效
    output reg [7:0] led
);

    localparam integer STEP_COUNT = CLK_FREQ_HZ * STEP_MS / 1000;
    localparam integer CNT_W      = 24;

    reg [CNT_W-1:0] cnt;
    reg             key_s1, key_s2;   // 两级同步
    reg             key_s2_d;          // 打一拍做边沿检测
    reg             dir;               // 0=左移 1=右移

    // 两级同步
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_s1 <= 1'b1;
            key_s2 <= 1'b1;
        end else begin
            key_s1 <= key;
            key_s2 <= key_s1;
        end
    end

    // 边沿检测
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) key_s2_d <= 1'b1;
        else        key_s2_d <= key_s2;
    end

    wire key_fell = key_s2_d & ~key_s2;   // 同步后下降沿 = 按下

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) dir <= 1'b0;
        else if (key_fell) dir <= ~dir;
    end

    // 流水移位
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= {CNT_W{1'b0}};
            led <= 8'b0000_0001;
        end else if (cnt >= STEP_COUNT - 1) begin
            cnt <= {CNT_W{1'b0}};
            if (dir == 1'b0)
                led <= {led[6:0], led[7]};   // 左移
            else
                led <= {led[0], led[7:1]};   // 右移
        end else begin
            cnt <= cnt + 1'b1;
        end
    end

endmodule

`default_nettype wire
