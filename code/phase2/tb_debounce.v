//==============================================================================
// tb_debounce.v  —  Testbench：消抖模块（带抖动波形）自检
//   * 仿真提速：CLK_FREQ_HZ=1000, HOLD_MS=1 => HOLD_CNT=10 个时钟。
//   * 制造一段"按下抖动"：快速来回跳变若干拍，再稳定保持低电平。
//   * 断言 key_out 在整个按下过程中只翻转一次（抖动期间不翻转）。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_debounce;

    reg      clk;
    reg      rst_n;
    reg      key_in;
    wire     key_out;

    integer  trans;
    integer  err;

    always #10 clk = ~clk;

    debounce #(
        .CLK_FREQ_HZ(1000),
        .HOLD_MS(1)
    ) u_dut (
        .clk    (clk),
        .rst_n  (rst_n),
        .key_in (key_in),
        .key_out(key_out)
    );

    // 统计 key_out 翻转次数
    always @(key_out) begin
        trans = trans + 1;
        $display("[%0t ns] key_out -> %b", $time, key_out);
    end

    initial begin
        clk    = 1'b0;
        rst_n  = 1'b0;
        key_in = 1'b1;
        trans  = 0;
        err    = 0;

        #25 rst_n = 1'b1;

        // --- 按下抖动：快速来回 5 次（每次持续 1 拍，不够 10 拍窗口）---
        key_in = 1'b0; #20;
        key_in = 1'b1; #20;
        key_in = 1'b0; #20;
        key_in = 1'b1; #20;
        key_in = 1'b0; #20;

        // 稳定保持低电平 30 拍（>10 拍窗口）：应被采纳，key_out 翻转为 0
        key_in = 1'b0; #600;

        // --- 松开抖动 ---
        key_in = 1'b1; #20;
        key_in = 1'b0; #20;
        key_in = 1'b1; #20;
        key_in = 1'b0; #20;
        key_in = 1'b1; #20;

        // 稳定保持高电平 30 拍：key_out 翻回 1
        key_in = 1'b1; #600;

        // 期望：key_out 共翻转 2 次（按下稳定一次、松开稳定一次）
        if (trans != 2) begin
            err = err + 1;
            $display("[TB] FAIL: key_out 翻转 %0d 次，期望 2 次（抖动不应引起额外翻转）", trans);
        end
        if (key_out != 1'b1) begin
            err = err + 1;
            $display("[TB] FAIL: 结束时 key_out=%b 应为 1(松开)", key_out);
        end

        if (err == 0) $display("[TB] PASS: 消抖模块在抖动波形下只输出稳定单次翻转");
        else          $display("[TB] FAIL: 共 %0d 处错误", err);

        $finish;
    end

endmodule

`default_nettype wire
