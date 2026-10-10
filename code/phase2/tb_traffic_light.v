//==============================================================================
// tb_traffic_light.v  —  Testbench：交通灯状态周期与互锁自检
//   * 提速：T_GREEN=5, T_YELLOW=2 拍。
//   * 跑完整一个循环，逐状态检查：南北/东西同一时刻只亮一种灯，且另一方向为红。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_traffic_light;

    reg      clk;
    reg      rst_n;
    wire     red_ns, yellow_ns, green_ns;
    wire     red_ew, yellow_ew, green_ew;
    integer  err;

    always #10 clk = ~clk;

    traffic_light #(
        .T_GREEN(5),
        .T_YELLOW(2)
    ) u_dut (
        .clk(clk), .rst_n(rst_n),
        .red_ns(red_ns), .yellow_ns(yellow_ns), .green_ns(green_ns),
        .red_ew(red_ew), .yellow_ew(yellow_ew), .green_ew(green_ew)
    );

    initial begin
        clk   = 1'b0;
        rst_n = 1'b0;
        err   = 0;
        #25 rst_n = 1'b1;

        // 每方向互锁：恰好一种灯亮
        #40;
        if (red_ns + yellow_ns + green_ns != 1) begin err=err+1; $display("[TB] FAIL 互锁NS"); end
        if (red_ew + yellow_ew + green_ew != 1) begin err=err+1; $display("[TB] FAIL 互锁EW"); end
        if (!(green_ns && red_ew)) begin err=err+1; $display("[TB] FAIL 应为 NS绿/EW红"); end
        $display("[TB] NS_G: NS g=%b  EW r=%b", green_ns, red_ew);

        #20;
        if (red_ns + yellow_ns + green_ns != 1) begin err=err+1; $display("[TB] FAIL 互锁NS"); end
        if (!(yellow_ns && red_ew)) begin err=err+1; $display("[TB] FAIL 应为 NS黄/EW红"); end
        $display("[TB] NS_Y: NS y=%b  EW r=%b", yellow_ns, red_ew);

        #60;
        if (red_ns + yellow_ns + green_ns != 1) begin err=err+1; $display("[TB] FAIL 互锁NS"); end
        if (!(green_ew && red_ns)) begin err=err+1; $display("[TB] FAIL 应为 EW绿/NS红"); end
        $display("[TB] EW_G: EW g=%b  NS r=%b", green_ew, red_ns);

        #20;
        if (!(yellow_ew && red_ns)) begin err=err+1; $display("[TB] FAIL 应为 EW黄/NS红"); end
        $display("[TB] EW_Y: EW y=%b  NS r=%b", yellow_ew, red_ns);

        #20;
        if (!(green_ns && red_ew)) begin err=err+1; $display("[TB] FAIL 循环后应回到 NS绿/EW红"); end

        if (err == 0) $display("[TB] PASS: 交通灯周期完整且双向互锁");
        else          $display("[TB] FAIL: 共 %0d 处错误", err);

        $finish;
    end

endmodule

`default_nettype wire
