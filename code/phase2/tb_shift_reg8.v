//==============================================================================
// tb_shift_reg8.v  —  Testbench：移位寄存器串入并出自检
//   * 时钟每 10ns 一个上升沿；依次串行输入 8 位 1011_0100。
//   * 第 8 个时钟后并行输出 pout 应等于该字节；同时 sout 应等于最后移入位。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_shift_reg8;

    reg         clk;
    reg         rst_n;
    reg         sin;
    wire [7:0]  pout;
    wire        sout;

    integer i;
    integer err;
    reg [7:0] stim;

    shift_reg8 #(
        .WIDTH(8)
    ) u_dut (
        .clk  (clk),
        .rst_n(rst_n),
        .sin  (sin),
        .pout (pout),
        .sout (sout)
    );

    always #10 clk = ~clk;

    initial begin
        clk   = 1'b0;
        rst_n = 1'b0;
        sin   = 1'b0;
        err   = 0;
        stim  = 8'b1011_0100;

        #25 rst_n = 1'b1;

        // 逐位串行送入：先送最高位 bit7
        for (i = 0; i < 8; i = i + 1) begin
            sin = stim[7-i];
            #20;
            $display("[TB] step %0d: sin=%b pout=%b", i, sin, pout);
        end

        // 此时 pout 应为 1011_0100（先入高位逐步被挤到高位）
        if (pout != 8'b1011_0100) begin
            err = err + 1;
            $display("[TB] FAIL: pout=%b expect=1011_0100", pout);
        end
        if (sout != stim[7]) begin
            err = err + 1;
            $display("[TB] FAIL: sout=%b expect=%b", sout, stim[7]);
        end

        if (err == 0) $display("[TB] PASS: 移位寄存器串入并出正确");
        else          $display("[TB] FAIL: 共 %0d 处错误", err);

        $finish;
    end

endmodule

`default_nettype wire
