//==============================================================================
// breathing_led.v  —  可综合：PWM 呼吸灯（占空比渐变）
// 原理：
//   1) pwm_cnt 自由计数（0 ~ 2^PWM_BITS-1），构成 PWM 载波周期。
//   2) led = (pwm_cnt < duty)：duty 越大，高电平占比越高 => 越亮。
//   3) duty 由一个更慢的计数器缓慢"爬升/下降"，形成呼吸效果。
// 例：PWM_BITS=8 => 占空比分辨率 1/256；SLOW_DIV=20 => 每 ~1M 个时钟改一次 duty。
//==============================================================================
`default_nettype none

module breathing_led #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer PWM_BITS    = 8,    // PWM 占空比分辨率位数
    parameter integer SLOW_DIV    = 20    // 占空比慢变化分频位数
)(
    input  wire clk,
    input  wire rst_n,
    output reg  led
);

    localparam integer PERIOD = (1 << PWM_BITS);  // PWM 周期 = 2^PWM_BITS

    reg [PWM_BITS-1:0] pwm_cnt;
    reg [PWM_BITS-1:0] duty;
    reg [SLOW_DIV-1:0] slow_cnt;
    reg                up;     // 1=占空比上升, 0=下降

    // 1) PWM 载波计数器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pwm_cnt <= {PWM_BITS{1'b0}};
        else
            pwm_cnt <= pwm_cnt + 1'b1;
    end

    // 2) 占空比缓慢升降（呼吸）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            duty     <= {PWM_BITS{1'b0}};
            slow_cnt <= {SLOW_DIV{1'b0}};
            up       <= 1'b1;
        end else begin
            slow_cnt <= slow_cnt + 1'b1;
            if (slow_cnt == {SLOW_DIV{1'b1}}) begin
                slow_cnt <= {SLOW_DIV{1'b0}};
                if (up) begin
                    duty <= duty + 1'b1;
                    if (duty == PERIOD-1) up <= 1'b0;   // 到顶转为下降
                end else begin
                    duty <= duty - 1'b1;
                    if (duty == {PWM_BITS{1'b0}}) up <= 1'b1; // 到底转为上升
                end
            end
        end
    end

    // 3) PWM 输出
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            led <= 1'b0;
        else
            led <= (pwm_cnt < duty);
    end

endmodule

`default_nettype wire
