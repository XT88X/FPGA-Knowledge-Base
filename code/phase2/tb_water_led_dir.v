//==============================================================================
// tb_water_led_dir.v  —  Testbench：双向流水灯方向切换自检
//   * 仿真提速：CLK_FREQ_HZ=10000, STEP_MS=1 => STEP_COUNT=10 个时钟/拍。
//   * 时钟周期 20ns，每拍 200ns；先跑 3 拍向左移位，再按键翻转方向。
//   * 先跑几拍确认向左移位；再给 key 一个按下脉冲，确认方向翻转成右移。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_water_led_dir;

    reg      clk;
    reg      rst_n;
    reg      key;
    wire [7:0] led;

    integer err;
    reg [7:0] prev;

    always #10 clk = ~clk;

    water_led_dir #(
        .CLK_FREQ_HZ(10000),
        .STEP_MS(1)
    ) u_dut (
        .clk  (clk),
        .rst_n(rst_n),
        .key  (key),
        .led  (led)
    );

    initial begin
        clk   = 1'b0;
        rst_n = 1'b0;
        key   = 1'b1;      // 默认松开
        err   = 0;
        prev  = 8'b0000_0001;

        #25 rst_n = 1'b1;

        // 跑 3 拍，应观察到 led 左移（1->2->4->8）
        #600;
        $display("[TB] after 3 steps left: led=%b", led);
        if (led != 8'b0000_1000) begin
            err = err + 1;
            $display("[TB] FAIL: 左移 3 拍后 led=%b expect=0000_1000", led);
        end

        // 按下按键（保持几个时钟让两级同步采到下降沿）
        key = 1'b0;
        #60;
        key = 1'b1;

        // 再跑 3 拍，应向右移回（8->4->2->1）
        #600;
        $display("[TB] after key + 3 steps right: led=%b", led);
        if (led != 8'b0000_0001) begin
            err = err + 1;
            $display("[TB] FAIL: 反向 3 拍后 led=%b expect=0000_0001", led);
        end

        if (err == 0) $display("[TB] PASS: 流水灯左右方向切换正确");
        else          $display("[TB] FAIL: 共 %0d 处错误", err);

        $finish;
    end

endmodule

`default_nettype wire
