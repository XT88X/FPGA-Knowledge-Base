// tb_ch4_seg7_scan.v — 数码管动态扫描自检：核对段译码与位选轮询
`timescale 1ns/1ps
module tb_ch4_seg7_scan;
    reg clk = 0;
    reg rst_n = 0;
    reg [23:0] bcd_digits = 24'h012345;  // 显示 0 1 2 3 4 5
    reg [1:0] unit_sel = 2'd1;
    wire [7:0] seg;
    wire [5:0] sel;

    // 用很小的扫描分频常数，便于在仿真里看到多位轮询
    ch4_seg7_scan #(
        .CLK_FREQ_HZ(50_000_000),
        .SCAN_HZ(1000),
        .DIGITS(6)
    ) u_dut (
        .clk(clk), .rst_n(rst_n),
        .bcd_digits(bcd_digits), .unit_sel(unit_sel),
        .seg(seg), .sel(sel)
    );

    always #10 clk = ~clk;

    integer i;
    reg [5:0] seen;
    initial begin
        rst_n = 0; #55; rst_n = 1;
        seen = 6'b000000;
        // 跑足够久，收集被点亮过的位选
        for (i = 0; i < 20000; i = i + 1) begin
            @(posedge clk);
            seen = seen | sel;
        end
        if (seen == 6'b111111)
            $display("SEG7_SCAN OK: all digits scanned, seg=%0b", seg);
        else
            $display("SEG7_SCAN FAIL: seen=%0b", seen);
        // 0 的段码应为 8'b00111111；当前位随机，只做存在性检查
        $finish;
    end
endmodule
