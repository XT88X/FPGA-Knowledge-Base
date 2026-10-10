//==============================================================================
// tb_breathing_led.v  —  Testbench：呼吸灯 PWM 仿真
// 观察点：duty 是否在缓慢单调上升/下降，led 的高电平占比是否随之变化。
// 仿真提速：把 SLOW_DIV 调小（=2），让 duty 在几微秒内就走完整轮呼吸。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_breathing_led;

    reg  clk   = 1'b0;
    reg  rst_n = 1'b0;
    wire led;

    always #10 clk = ~clk;   // 50 MHz

    breathing_led #(
        .PWM_BITS (8),
        .SLOW_DIV (2)         // 仿真提速：每 4 个时钟就更新一次 duty
    ) u_dut (
        .clk   (clk),
        .rst_n (rst_n),
        .led   (led)
    );

    // 每隔 500 ns 打印一次内部状态（hierarchical 引用）
    initial begin
        $dumpfile("tb_breathing_led.vcd");
        $dumpvars(0, tb_breathing_led);

        rst_n = 1'b0;
        #55;
        rst_n = 1'b1;

        forever begin
            #500;
            $display("[%0t ns] duty=0x%0h led=%b",
                     $time, u_dut.duty, led);
        end
    end

    // 总仿真时长 20 us 后结束
    initial begin
        #20000;
        $display("[TB] breathing_led 仿真结束");
        $finish;
    end

endmodule

`default_nettype wire
