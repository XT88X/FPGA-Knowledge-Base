//==============================================================================
// tb_multi_tick_led_top.v — 三灯不同节奏自检
//------------------------------------------------------------------------------
// 把分频系数改小（4/6/8）便于仿真：
//   led0 每 4 个时钟翻转，led1 每 6 个，led2 每 8 个。
// 用寄存器保存上一拍电平做上升沿检测，测量两次翻转间隔并与期望值比对。
//==============================================================================
`timescale 1ns/1ps
module tb_multi_tick_led_top;

    reg clk;
    reg rst_n;
    wire led0, led1, led2;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    multi_tick_led_top #(
        .DIV0(4),
        .DIV1(6),
        .DIV2(8)
    ) u_top (
        .clk(clk), .rst_n(rst_n),
        .led0(led0), .led1(led1), .led2(led2)
    );

    integer c0, c1, c2;      // 距上次上升沿的时钟数
    integer errors;
    integer flips0, flips1, flips2;
    reg     d0, d1, d2;      // 上一拍电平

    initial begin
        rst_n = 1'b0;
        c0 = 0; c1 = 0; c2 = 0;
        errors = 0;
        flips0 = 0; flips1 = 0; flips2 = 0;
        d0 = 0; d1 = 0; d2 = 0;
        #23;
        rst_n = 1'b1;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            c0 <= 0; c1 <= 0; c2 <= 0;
            d0 <= 0; d1 <= 0; d2 <= 0;
        end else begin
            c0 <= c0 + 1;
            c1 <= c1 + 1;
            c2 <= c2 + 1;

            // led0 上升沿
            if (led0 && !d0) begin
                flips0 <= flips0 + 1;
                if (flips0 != 0 && c0 != 4) errors <= errors + 1;
                c0 <= 0;
            end
            // led1 上升沿
            if (led1 && !d1) begin
                flips1 <= flips1 + 1;
                if (flips1 != 0 && c1 != 6) errors <= errors + 1;
                c1 <= 0;
            end
            // led2 上升沿
            if (led2 && !d2) begin
                flips2 <= flips2 + 1;
                if (flips2 != 0 && c2 != 8) errors <= errors + 1;
                c2 <= 0;
            end

            d0 <= led0;
            d1 <= led1;
            d2 <= led2;
        end
    end

    initial begin
        #400;
        $display("---- tb_multi_tick_led_top ----");
        $display("flips0=%0d flips1=%0d flips2=%0d errors=%0d",
                 flips0, flips1, flips2, errors);
        if (flips0 >= 4 && flips1 >= 3 && flips2 >= 2 && errors == 0)
            $display("TB_MULTI_LED: PASS");
        else
            $display("TB_MULTI_LED: FAIL");
        $finish;
    end

endmodule
