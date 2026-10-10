// tb_ch5_lfsr.v — 伪随机自检：非零、每拍变化、不卡死
`timescale 1ns/1ps
module tb_ch5_lfsr;
    reg clk = 0;
    reg rst_n = 0;
    reg en = 0;
    wire [7:0] rng;

    ch5_lfsr u_dut (.clk(clk), .rst_n(rst_n), .en(en), .rng(rng));
    always #10 clk = ~clk;

    integer i;
    integer changes = 0;
    reg [7:0] prev;
    initial begin
        rst_n = 0; #55; rst_n = 1; prev = rng; #10;
        for (i = 0; i < 32; i = i + 1) begin
            @(posedge clk); en = 1;
            @(posedge clk); en = 0;
            #2;
            if (rng !== prev) changes = changes + 1;
            prev = rng;
        end
        if (rng !== 8'h00 && changes > 20)
            $display("LFSR OK: changes=%0d final=%0h", changes, rng);
        else
            $display("LFSR FAIL: changes=%0d final=%0h", changes, rng);
        $finish;
    end
endmodule
