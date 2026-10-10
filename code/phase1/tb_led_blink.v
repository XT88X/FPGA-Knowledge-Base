//==============================================================================
// tb_led_blink.v  —  Testbench：led_blink 的行为仿真
// 说明：
//   * 产生 50 MHz 时钟（周期 20 ns）与上电复位脉冲。
//   * 为了在仿真里"几微秒"就看到 LED 翻转，这里把 BLINK_HZ 调大到
//     1,000,000（半周期=25 个时钟=500 ns）。上板时再用 BLINK_HZ=1。
//   * $dumpvars 生成 VCD 波形；always@(led) 打印每次翻转时间，
//     并在结束前判断是否至少发生 2 次翻转作为自检。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_led_blink;

    // 50 MHz 时钟：周期 20 ns
    localparam integer CLK_FREQ_HZ = 50_000_000;

    reg  clk   = 1'b0;
    reg  rst_n = 1'b0;
    wire led;

    // 时钟激励：每 10 ns 翻转 => 周期 20 ns
    always #10 clk = ~clk;

    // 例化被测模块 DUT（仿真提速：BLINK_HZ=1_000_000）
    led_blink #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BLINK_HZ   (1_000_000)
    ) u_dut (
        .clk   (clk),
        .rst_n (rst_n),
        .led   (led)
    );

    // 统计翻转次数
    integer toggle_cnt = 0;
    always @(led) begin
        toggle_cnt = toggle_cnt + 1;
        $display("[%0t ns] led -> %b (toggle #%0d)", $time, led, toggle_cnt);
    end

    initial begin
        $dumpfile("tb_led_blink.vcd");
        $dumpvars(0, tb_led_blink);

        // 复位保持 55 ns 后释放
        rst_n = 1'b0;
        #55;
        rst_n = 1'b1;

        // 跑足够长时间观察若干次翻转（每次翻转间隔 500 ns）
        #3000;

        if (toggle_cnt >= 2)
            $display("[TB] PASS: LED 已发生 %0d 次翻转", toggle_cnt);
        else
            $display("[TB] FAIL: LED 翻转次数过少 toggle_cnt=%0d", toggle_cnt);

        $finish;
    end

endmodule

`default_nettype wire
