//==============================================================================
// tb_pwm.v  —  Testbench：PWM 占空比/周期自检
//   PWM_BITS=8 -> 周期 256 个时钟；duty=128 -> 期望高电平约 128/256=50%。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_pwm;

    reg        clk = 1'b0;
    reg        rst_n = 1'b0;
    reg  [7:0] duty = 8'd128;
    wire       pwm_out;

    integer    k;
    integer    high_cnt;
    integer    pass_cnt, fail_cnt;

    always #10 clk = ~clk;

    pwm #(.PWM_BITS(8)) u_dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .duty    (duty),
        .pwm_out (pwm_out)
    );

    initial begin
        pass_cnt = 0; fail_cnt = 0;
        rst_n = 1'b0;
        for (k = 0; k < 20; k = k + 1) @(posedge clk);
        rst_n = 1'b1;
        for (k = 0; k < 400; k = k + 1) @(posedge clk);  // 稳定

        // 统计 2 个周期(512 拍)内高电平拍数
        high_cnt = 0;
        for (k = 0; k < 512; k = k + 1) begin
            @(posedge clk);
            if (pwm_out === 1'b1) high_cnt = high_cnt + 1;
        end
        $display("[CHK] high_cnt=%0d / 512 (expect ~256)", high_cnt);
        if (high_cnt >= 240 && high_cnt <= 272) begin
            pass_cnt = pass_cnt + 1;
            $display("[CHK] 占空比约 50%%  OK");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("[CHK] 占空比偏差过大  FAIL");
        end

        $display("========================================");
        $display("tb_pwm: PASS=%0d FAIL=%0d", pass_cnt, fail_cnt);
        $display("========================================");
        #1000;
        $finish;
    end

endmodule

`default_nettype wire
