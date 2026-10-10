//==============================================================================
// breathing_rgb_top.v - RGB breathing LED
//==============================================================================
`default_nettype none

module breathing_rgb_top #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer PWM_BITS     = 8,
    parameter integer SLOW_DIV     = 20
)(
    input  wire clk,
    input  wire rst_n,
    output reg  led_r,
    output reg  led_g,
    output reg  led_b
);

    localparam integer PERIOD = (1 << PWM_BITS);

    reg [PWM_BITS-1:0] pwm_cnt;
    reg [PWM_BITS-1:0] duty;
    reg [SLOW_DIV-1:0] slow_cnt;
    reg                up;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pwm_cnt <= {PWM_BITS{1'b0}};
        else
            pwm_cnt <= pwm_cnt + 1'b1;
    end

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
                    if (duty == PERIOD-1) up <= 1'b0;
                end else begin
                    duty <= duty - 1'b1;
                    if (duty == {PWM_BITS{1'b0}}) up <= 1'b1;
                end
            end
        end
    end

    pwm #(.PWM_BITS(PWM_BITS)) u_r (
        .clk(clk), .rst_n(rst_n), .duty(duty),        .pwm_out(led_r)
    );
    pwm #(.PWM_BITS(PWM_BITS)) u_g (
        .clk(clk), .rst_n(rst_n), .duty(duty + 8'd85), .pwm_out(led_g)
    );
    pwm #(.PWM_BITS(PWM_BITS)) u_b (
        .clk(clk), .rst_n(rst_n), .duty(duty + 8'd170), .pwm_out(led_b)
    );

endmodule

`default_nettype wire
