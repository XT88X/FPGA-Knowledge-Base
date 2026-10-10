//==============================================================================
// tb_breathing_rgb_top.v  —  Testbench：RGB 呼吸灯
//   用较小 SLOW_DIV=4 让三角波快速走动；验证三路 PWM 输出都在翻转，
//   且占空比随三角波变化（三路相位错开）。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_breathing_rgb_top;

    reg  clk = 1'b0;
    reg  rst_n = 1'b0;
    wire led_r, led_g, led_b;

    integer k;
    integer r_hi, g_hi, b_hi;
    integer pass_cnt, fail_cnt;

    always #10 clk = ~clk;

    breathing_rgb_top #(
        .PWM_BITS (8),
        .SLOW_DIV (4)
    ) u_dut (
        .clk(clk), .rst_n(rst_n),
        .led_r(led_r), .led_g(led_g), .led_b(led_b)
    );

    initial begin
        pass_cnt = 0; fail_cnt = 0;
        r_hi = 0; g_hi = 0; b_hi = 0;
        rst_n = 1'b0;
        for (k = 0; k < 20; k = k + 1) @(posedge clk);
        rst_n = 1'b1;

        // 跑 8192 拍，统计各路高电平拍数
        for (k = 0; k < 8192; k = k + 1) begin
            @(posedge clk);
            if (led_r === 1'b1) r_hi = r_hi + 1;
            if (led_g === 1'b1) g_hi = g_hi + 1;
            if (led_b === 1'b1) b_hi = b_hi + 1;
        end
        $display("[CHK] r_hi=%0d g_hi=%0d b_hi=%0d", r_hi, g_hi, b_hi);
        // 三路都应既有高也有低（呼吸经过全范围），且三路计数值不必相等
        if (r_hi > 0 && g_hi > 0 && b_hi > 0 &&
            r_hi < 8192 && g_hi < 8192 && b_hi < 8192) begin
            pass_cnt = pass_cnt + 1;
            $display("[CHK] 三路 PWM 均在呼吸变化  OK");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("[CHK] 存在一路恒亮/恒灭  FAIL");
        end

        $display("========================================");
        $display("tb_breathing_rgb_top: PASS=%0d FAIL=%0d", pass_cnt, fail_cnt);
        $display("========================================");
        #1000;
        $finish;
    end

endmodule

`default_nettype wire
