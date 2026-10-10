//==============================================================================
// tb_key_toggle.v  —  Testbench：按一下切换一次 LED
//   * 提速：CLK_FREQ_HZ=1000, HOLD_MS=1（消抖窗口 10 拍）。
//   * 模拟一次带抖动的按下->松开，断言 led 恰好翻转一次。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_key_toggle;

    reg      clk;
    reg      rst_n;
    reg      key_in;
    wire     led;
    integer  trans;
    integer  err;

    always #10 clk = ~clk;

    key_toggle #(
        .CLK_FREQ_HZ(1000),
        .HOLD_MS(1)
    ) u_dut (
        .clk    (clk),
        .rst_n  (rst_n),
        .key_in (key_in),
        .led    (led)
    );

    always @(led) trans = trans + 1;

    initial begin
        clk    = 1'b0;
        rst_n  = 1'b0;
        key_in = 1'b1;
        trans  = 0;
        err    = 0;

        #25 rst_n = 1'b1;

        // 抖动按下
        key_in = 1'b0; #20;
        key_in = 1'b1; #20;
        key_in = 1'b0; #20;
        // 稳定按下 30 拍
        key_in = 1'b0; #600;
        // 松开（带抖动）
        key_in = 1'b1; #20;
        key_in = 1'b0; #20;
        key_in = 1'b1;
        // 稳定松开
        #600;

        $display("[TB] led=%b, 翻转次数=%0d", led, trans);
        if (trans != 1) begin
            err = err + 1;
            $display("[TB] FAIL: led 应翻转 1 次，实际 %0d 次", trans);
        end
        if (led != 1'b1) begin
            err = err + 1;
            $display("[TB] FAIL: 一次按下后 led 应为 1，实际 %b", led);
        end

        if (err == 0) $display("[TB] PASS: 按一下切换一次 LED");
        else          $display("[TB] FAIL: 共 %0d 处错误", err);

        $finish;
    end

endmodule

`default_nettype wire
