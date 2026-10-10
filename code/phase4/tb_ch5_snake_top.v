// tb_ch5_snake_top.v — 顶层冒烟自检：缩短帧分频，检查行场同步与 RGB 输出活动
`timescale 1ns/1ps
module tb_ch5_snake_top;
    reg clk = 0;
    reg rst_n = 0;
    reg [3:0] btn = 4'b0000;
    wire hsync, vsync;
    wire [3:0] vga_r, vga_g, vga_b;

    // FRAME_DIV 调小到 50，便于仿真里看到多次游戏步进
    ch5_snake_top #(.FRAME_DIV(50)) u_dut (
        .clk(clk), .rst_n(rst_n), .btn(btn),
        .hsync(hsync), .vsync(vsync),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b)
    );
    always #10 clk = ~clk;

    integer i;
    integer h_toggle = 0;
    integer rgb_active = 0;
    reg last_h;
    initial begin
        rst_n = 0; #55; rst_n = 1; #20;
        last_h = hsync;
        for (i = 0; i < 200000; i = i + 1) begin
            @(posedge clk);
            if (hsync !== last_h) h_toggle = h_toggle + 1;
            last_h = hsync;
            if (vga_r || vga_g || vga_b) rgb_active = rgb_active + 1;
            // 中途按右键
            if (i == 50000) btn = 4'b0001;
        end
        if (h_toggle > 100)
            $display("SNAKE_TOP OK: hsync toggles=%0d", h_toggle);
        else
            $display("SNAKE_TOP FAIL: hsync toggles=%0d", h_toggle);
        if (rgb_active > 0)
            $display("SNAKE_TOP OK: rgb active pixels=%0d", rgb_active);
        else
            $display("SNAKE_TOP FAIL: no rgb activity");
        $finish;
    end
endmodule
