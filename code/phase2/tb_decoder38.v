//==============================================================================
// tb_decoder38.v  —  Testbench：3-8 译码器穷举自检
//   * 生成时钟无关的纯组合激励：使能拉低 -> 拉高后 a 从 0 遍历到 7。
//   * 每步用期望值比对 y，错误即打印 FAIL；全部通过打印 PASS。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_decoder38;

    reg  [2:0] a;
    reg        en;
    wire [7:0] y;

    integer i;
    integer err;
    reg  [7:0] expect;

    decoder38 u_dut (
        .a  (a),
        .en (en),
        .y  (y)
    );

    initial begin
        a   = 3'd0;
        en  = 1'b0;
        err = 0;

        // 1) 关闭使能：全部输出应为 0
        #10 en = 1'b0; a = 3'd0; #10;
        if (y != 8'b0000_0000) begin
            err = err + 1;
            $display("[TB] FAIL: en=0 时 y=%b 应为 0", y);
        end

        // 2) 使能打开，a 从 0 穷举到 7
        en = 1'b1;
        for (i = 0; i < 8; i = i + 1) begin
            a = i[2:0];
            #10;
            expect = 8'b0000_0001 << i;
            if (y != expect) begin
                err = err + 1;
                $display("[TB] FAIL: a=%0d y=%b expect=%b", i, y, expect);
            end else begin
                $display("[TB] OK  : a=%0d -> y=%b", i, y);
            end
        end

        if (err == 0) $display("[TB] PASS: 3-8 译码器全部用例通过");
        else          $display("[TB] FAIL: 共 %0d 处错误", err);

        $finish;
    end

endmodule

`default_nettype wire
