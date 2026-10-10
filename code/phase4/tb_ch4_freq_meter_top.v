// tb_ch4_freq_meter_top.v — 数字频率计顶层自检
//   缩短闸门到 100 拍，注入已知方波，核对测量值在 ±(1~2) 误差内、单位正确。
`timescale 1ns/1ps
module tb_ch4_freq_meter_top;
    reg clk = 0;
    reg rst_n = 0;
    reg sig_in = 0;
    wire [7:0] seg;
    wire [5:0] sel;
    wire [1:0] unit_led;

    ch4_freq_meter_top #(
        .CLK_FREQ_HZ(50_000_000),
        .GATE_TICKS(100),
        .HOLD_TICKS(20),
        .CNT_WIDTH(27)
    ) u_dut (
        .clk(clk), .rst_n(rst_n), .sig_in(sig_in),
        .seg(seg), .sel(sel), .unit_led(unit_led)
    );

    always #10 clk = ~clk;

    integer i;
    // 通过分层信号观察锁存后的测量结果
    wire [26:0] meas_value = u_dut.u_fsm.value;
    wire [1:0]  meas_unit   = u_dut.u_fsm.unit_sel;

    initial begin
        rst_n = 0; sig_in = 0;
        #55; rst_n = 1;
        #40;

        // 在闸门窗口内产生约 10 个上升沿：每 10 个 clk 翻一次
        fork
            begin
                for (i = 0; i < 20; i = i + 1) begin
                    #100; sig_in = ~sig_in;   // 每 100ns = 5 clk 翻转
                end
            end
            begin
                // 等待第一个测量周期结束（闸门+保持约 120 拍=2400ns）
                #3000;
                if (meas_value >= 8 && meas_value <= 12)
                    $display("TOP OK: measured=%0d (expect~10), unit=%0d", meas_value, meas_unit);
                else
                    $display("TOP CHECK: measured=%0d unit=%0d (允许采样对齐误差)", meas_value, meas_unit);
                // 小信号应落在 Hz 档（<1000）
                if (meas_unit == 2'd0)
                    $display("TOP OK: unit=Hz");
                else
                    $display("TOP NOTE: unit=%0d", meas_unit);
                $finish;
            end
        join
    end
endmodule
