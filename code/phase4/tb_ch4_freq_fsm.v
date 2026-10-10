// tb_ch4_freq_fsm.v — 量程/单位自动切换自检
//   直接喂 raw_count，触发 gate_done，核对 unit_sel 与 freq_value。
`timescale 1ns/1ps
module tb_ch4_freq_fsm;
    reg clk = 0;
    reg rst_n = 0;
    reg gate_done = 0;
    reg [26:0] raw_count = 0;
    wire latch;
    wire clr;
    wire [26:0] freq_value;
    wire [1:0] unit_sel;
    wire [23:0] bcd_digits;
    wire update_stb;

    ch4_freq_fsm #(.CNT_WIDTH(27)) u_dut (
        .clk(clk), .rst_n(rst_n), .gate_done(gate_done), .raw_count(raw_count),
        .latch(latch), .clr(clr), .freq_value(freq_value), .unit_sel(unit_sel),
        .bcd_digits(bcd_digits), .update_stb(update_stb)
    );

    always #10 clk = ~clk;

    initial begin
        rst_n = 0; gate_done = 0; raw_count = 27'd0;
        #55; rst_n = 1; #20;

        // 999 Hz -> Hz
        @(posedge clk); raw_count = 27'd999;
        @(posedge clk); gate_done = 1;
        @(posedge clk); gate_done = 0;
        #80;
        if (unit_sel == 2'd0 && freq_value == 27'd999)
            $display("FREQ_FSM OK: 999 -> Hz value=%0d", freq_value);
        else
            $display("FREQ_FSM FAIL: 999 got unit=%0d value=%0d", unit_sel, freq_value);

        // 1000 Hz -> kHz
        @(posedge clk); raw_count = 27'd1000;
        @(posedge clk); gate_done = 1;
        @(posedge clk); gate_done = 0;
        #80;
        if (unit_sel == 2'd1 && freq_value == 27'd1)
            $display("FREQ_FSM OK: 1000 -> kHz value=%0d", freq_value);
        else
            $display("FREQ_FSM FAIL: 1000 got unit=%0d value=%0d", unit_sel, freq_value);

        // 12_345_000 Hz -> MHz
        @(posedge clk); raw_count = 27'd12_345_000;
        @(posedge clk); gate_done = 1;
        @(posedge clk); gate_done = 0;
        #80;
        if (unit_sel == 2'd2 && freq_value == 27'd12)
            $display("FREQ_FSM OK: 12.345MHz -> MHz value=%0d bcd=%0h", freq_value, bcd_digits);
        else
            $display("FREQ_FSM FAIL: 12345000 got unit=%0d value=%0d", unit_sel, freq_value);

        // 1_000_000 Hz -> MHz 边界
        @(posedge clk); raw_count = 27'd1_000_000;
        @(posedge clk); gate_done = 1;
        @(posedge clk); gate_done = 0;
        #80;
        if (unit_sel == 2'd2 && freq_value == 27'd1)
            $display("FREQ_FSM OK: 1e6 -> MHz value=%0d", freq_value);
        else
            $display("FREQ_FSM FAIL: 1e6 got unit=%0d value=%0d", unit_sel, freq_value);

        $finish;
    end
endmodule
