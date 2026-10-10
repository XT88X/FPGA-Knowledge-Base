//==============================================================================
// tb_vending_machine.v  —  Testbench：售货机投币/出货/找零/复位自检
//   * 场景A：0.5+0.5+0.5=1.5 -> 出货一次。
//   * 复位后场景B：1.0+0.5=1.5 -> 出货一次，无找零。
//   * 复位后场景C：1.0+1.0=2.0 -> 出货一次且找零 0.5。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_vending_machine;

    reg      clk;
    reg      rst_n;
    reg      coin_05;
    reg      coin_10;
    wire     dispense;
    wire     change_05;
    integer  err;

    always #10 clk = ~clk;

    vending_machine u_dut (
        .clk(clk), .rst_n(rst_n),
        .coin_05(coin_05), .coin_10(coin_10),
        .dispense(dispense), .change_05(change_05)
    );

    initial begin
        clk=1'b0; rst_n=1'b0; coin_05=1'b0; coin_10=1'b0; err=0;
        #25 rst_n=1'b1;

        // 场景A：三次 0.5（每次脉冲：保持 20ns 高，再 20ns 低）
        coin_05=1'b1; #20; coin_05=1'b0; #20;
        coin_05=1'b1; #20; coin_05=1'b0; #20;
        coin_05=1'b1; #20; coin_05=1'b0; #20;
        #20;
        if (!dispense) begin err=err+1; $display("[TB] FAIL A: 1.5 应出货"); end
        if (change_05) begin err=err+1; $display("[TB] FAIL A: 不应找零"); end
        $display("[TB] 场景A(0.5*3): dispense=%b change=%b", dispense, change_05);

        // 复位 -> 场景B：1.0 + 0.5
        rst_n=1'b0; #20; rst_n=1'b1; #20;
        coin_10=1'b1; #20; coin_10=1'b0; #20;
        coin_05=1'b1; #20; coin_05=1'b0; #20;
        #20;
        if (!dispense) begin err=err+1; $display("[TB] FAIL B: 应出货"); end
        if (change_05) begin err=err+1; $display("[TB] FAIL B: 不应找零"); end
        $display("[TB] 场景B(1.0+0.5): dispense=%b change=%b", dispense, change_05);

        // 复位 -> 场景C：1.0 + 1.0 = 2.0 找零 0.5
        rst_n=1'b0; #20; rst_n=1'b1; #20;
        coin_10=1'b1; #20; coin_10=1'b0; #20;
        coin_10=1'b1; #20; coin_10=1'b0; #20;
        #20;
        if (!dispense) begin err=err+1; $display("[TB] FAIL C: 应出货"); end
        if (!change_05) begin err=err+1; $display("[TB] FAIL C: 应找零0.5"); end
        $display("[TB] 场景C(1.0*2): dispense=%b change=%b", dispense, change_05);

        if (err==0) $display("[TB] PASS: 售货机投币/出货/找零/复位全部正确");
        else         $display("[TB] FAIL: 共 %0d 处错误", err);

        $finish;
    end

endmodule

`default_nettype wire
