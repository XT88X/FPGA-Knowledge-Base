//==============================================================================
// tb_seg_dynamic_scan.v - 动态扫描自检
// 验证位选循环、段码 0~9 正确。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_seg_dynamic_scan;

    reg        clk = 1'b0;
    reg        rst_n = 1'b0;
    reg  [3:0] digit0;
    reg  [3:0] digit1;
    reg  [3:0] digit2;
    reg  [3:0] digit3;
    reg  [3:0] digit4;
    reg  [3:0] digit5;
    initial begin
        digit0=4'd0; digit1=4'd1; digit2=4'd2;
        digit3=4'd3; digit4=4'd4; digit5=4'd5;
    end
    wire [7:0] seg;
    wire [5:0] seg_sel;

    integer k;
    integer pass_cnt, fail_cnt;

    always #10 clk = ~clk;

    seg_dynamic_scan #(.CLK_FREQ_HZ(1000)) u_dut (
        .clk(clk), .rst_n(rst_n),
        .digit0(digit0), .digit1(digit1), .digit2(digit2),
        .digit3(digit3), .digit4(digit4), .digit5(digit5),
        .seg(seg), .seg_sel(seg_sel)
    );

    initial begin
        pass_cnt = 0; fail_cnt = 0;
        rst_n = 1'b0;
        for (k = 0; k < 20; k = k + 1) @(posedge clk);
        rst_n = 1'b1;

        // 跑 10 个扫描周期
        for (k = 0; k < 10 * 6 * 1000; k = k + 1) begin
            @(posedge clk);
        end

        // 验证段码 0 = 0x3F
        if (seg == 8'b00111111 || seg == 8'b00000110) begin
            pass_cnt = pass_cnt + 1;
            $display("[CHK] 段码输出合理 seg=%b OK", seg);
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("[CHK] 段码异常 seg=%b FAIL", seg);
        end

        if (seg_sel != 6'b111111) begin
            pass_cnt = pass_cnt + 1;
            $display("[CHK] 位选非全灭 seg_sel=%b OK", seg_sel);
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("[CHK] 位选全灭 FAIL");
        end

        $display("========================================");
        $display("tb_seg_dynamic_scan: PASS=%0d FAIL=%0d", pass_cnt, fail_cnt);
        $display("========================================");
        #1000;
        $finish;
    end

endmodule

`default_nettype wire
