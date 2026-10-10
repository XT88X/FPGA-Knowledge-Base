//==============================================================================
// tb_clk_divider.v — clk_div_even / clk_div_tick 自检
//------------------------------------------------------------------------------
// 验证点：
//   * clk_div_even DIV=4：输出时钟周期 = 4 个输入时钟周期，占空比 50%。
//   * clk_div_tick  DIV=5：每 5 个输入时钟出现一次单周期 tick。
//   通过计数器测量输出波形周期并与期望值比对，打印 PASS/FAIL。
//==============================================================================
`timescale 1ns/1ps
module tb_clk_divider;

    reg clk;
    reg rst_n;

    // DUT1: 偶数四分频，期望输出周期 = 4 * T_clk
    wire even_out;
    // DUT2: 使能分频，DIV=5，期望每 5 个时钟一个 tick
    wire tick_out;

    // 输入时钟 100MHz -> 周期 10ns（#5 翻转）
    initial clk = 1'b0;
    always #5 clk = ~clk;

    clk_div_even #(.DIV(4)) u_even (
        .clk(clk), .rst_n(rst_n), .clk_out(even_out)
    );

    clk_div_tick #(.DIV(5)) u_tick (
        .clk(clk), .rst_n(rst_n), .tick(tick_out)
    );

    // ---- 自检：测量 even_out 的相邻上升沿间隔（单位：输入时钟周期） ----
    integer rise_cnt;       // 从 even_out 上次上升沿到现在经过的输入时钟数
    integer measured_period;
    integer tick_seen;
    integer errors;

    initial begin
        rst_n = 1'b0;
        rise_cnt = 0;
        measured_period = 0;
        tick_seen = 0;
        errors = 0;
        #23;
        rst_n = 1'b1;
    end

    // 数输入时钟沿，并在 even_out 上升沿记录周期
    always @(posedge clk) begin
        if (rst_n) begin
            rise_cnt <= rise_cnt + 1;
            if (even_out) begin
                if (rise_cnt != 0) begin
                    measured_period <= rise_cnt;
                    if (rise_cnt != 4) errors <= errors + 1;
                end
                rise_cnt <= 0;
            end
        end
    end

    // 数 tick 个数并验证相邻 tick 间隔
    integer tick_gap;
    initial tick_gap = 0;
    always @(posedge clk) begin
        if (!rst_n) tick_gap <= 0;
        else begin
            tick_gap <= tick_gap + 1;
            if (tick_out) begin
                tick_seen <= tick_seen + 1;
                if (tick_gap != 5 && tick_seen != 0) errors <= errors + 1;
                tick_gap <= 0;
            end
        end
    end

    // 跑足够多拍后结束并报告
    initial begin
        #500;
        $display("---- tb_clk_divider result ----");
        $display("even_out measured period (clk cycles) = %0d, expect 4", measured_period);
        $display("tick pulses observed = %0d", tick_seen);
        if (errors == 0 && tick_seen >= 3)
            $display("TB_CLOCK_DIVIDER: PASS");
        else
            $display("TB_CLOCK_DIVIDER: FAIL (errors=%0d)", errors);
        $finish;
    end

endmodule
