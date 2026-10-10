//==============================================================================
// pwm.v  —  可综合：参数位宽 PWM 发生器（端口固定 8 位，内部参数化）
//   cnt 自由计数 0 ~ 2^PWM_BITS-1；pwm_out = (cnt < duty)。
//   占空比 = duty / 2^PWM_BITS；周期 = 2^PWM_BITS 个系统时钟。
//==============================================================================
`default_nettype none

module pwm #(
    parameter integer PWM_BITS = 8
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  duty,    // 占空比 0..255
    output reg         pwm_out
);

    reg [7:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cnt <= 8'd0;
        else
            cnt <= cnt + 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pwm_out <= 1'b0;
        else
            pwm_out <= (cnt < duty);
    end

endmodule

`default_nettype wire
