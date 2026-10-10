//==============================================================================
// tb_digital_clock_top.v - 电子钟顶层自检
// 验证时分秒计数、段选位选输出非全灭。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_digital_clock_top;

    reg        clk = 1'b0;
    reg        rst_n = 1'b0;
    reg        key_mode = 1'b1;
    reg        key_add = 1'b1;
    wire [7:0] seg;
    wire [5:0] seg_sel;

    integer k;
    integer pass_cnt, fail_cnt;

    always #10 clk = ~clk;

    digital_clock_top #(.CLK_FREQ_HZ(1001)) u_dut (
        .clk(clk), .rst_n(rst_n),
        .key_mode(key_mode), .key_add(key_add),
        .seg(seg), .seg_sel(seg_sel)
    );

    initial begin
        pass_cnt = 0; fail_cnt = 0;
        rst_n = 1'b0;
        for (k = 0; k < 30; k = k + 1) @(posedge clk);
        rst_n = 1'b1;

        // 跑 5 秒（加速）
        for (k = 0; k < 5 * 1001 + 500; k = k + 1) begin
            @(posedge clk);
        end

        $display("[CHK] sec=%0d min=%0d hour=%0d",
                 u_dut.sec, u_dut.min, u_dut.hour);

        if (u_dut.sec >= 5 && u_dut.sec <= 6) begin
            pass_cnt = pass_cnt + 1;
            $display("[CHK] 秒计数推进 OK");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("[CHK] 秒计数异常 FAIL");
        end

        if (seg_sel != 6'b111111) begin
            pass_cnt = pass_cnt + 1;
            $display("[CHK] 位选有输出 OK");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("[CHK] 位选全灭 FAIL");
        end

        $display("========================================");
        $display("tb_digital_clock_top: PASS=%0d FAIL=%0d", pass_cnt, fail_cnt);
        $display("========================================");
        #1000;
        $finish;
    end

endmodule

`default_nettype wire
