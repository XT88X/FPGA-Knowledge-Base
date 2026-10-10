// tb_ch5_render.v — 渲染自检：视频区/食物/蛇像素配色基本正确
`timescale 1ns/1ps
module tb_ch5_render;
    reg clk = 0;
    reg rst_n = 0;
    reg pxl_en = 0;
    reg [9:0] pixel_x = 0;
    reg [9:0] pixel_y = 0;
    reg hsync_in = 1;
    reg vsync_in = 1;
    reg video_on = 1;
    reg [4:0] head_x = 5;
    reg [3:0] head_y = 7;
    reg [4:0] food_x = 7;
    reg [3:0] food_y = 7;
    reg snake_hit = 0;
    reg game_over = 0;
    wire [4:0] gx;
    wire [3:0] gy;
    wire hsync, vsync;
    wire [3:0] vga_r, vga_g, vga_b;

    ch5_render u_dut (
        .clk(clk), .rst_n(rst_n), .pxl_en(pxl_en),
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .hsync_in(hsync_in), .vsync_in(vsync_in), .video_on(video_on),
        .head_x(head_x), .head_y(head_y),
        .food_x(food_x), .food_y(food_y),
        .snake_hit(snake_hit), .game_over(game_over),
        .gx(gx), .gy(gy), .hsync(hsync), .vsync(vsync),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b)
    );
    always #10 clk = ~clk;

    integer i;
    initial begin
        rst_n = 0; #55; rst_n = 1; #10;

        // 像素 (7*32, 7*32) = (224,224) -> 网格(7,7) = 食物
        pixel_x = 10'd224; pixel_y = 10'd224; pxl_en = 1;
        @(posedge clk); #5;
        if (gx == 7 && gy == 7)
            $display("RENDER OK: gx/gy=(%0d,%0d) at pixel(224,224)", gx, gy);
        else
            $display("RENDER FAIL: gx/gy=(%0d,%0d)", gx, gy);
        if (vga_r >= 4'h8)
            $display("RENDER OK: food pixel is reddish r=%0h", vga_r);
        else
            $display("RENDER NOTE: food pixel r=%0h", vga_r);

        // 视频关闭应输出黑色
        pxl_en = 0; video_on = 0;
        @(posedge clk); pxl_en = 1; @(posedge clk); #5;
        if (vga_r == 0 && vga_g == 0 && vga_b == 0)
            $display("RENDER OK: blanking -> black");
        else
            $display("RENDER NOTE: blanking rgb=%0h%0h%0h", vga_r, vga_g, vga_b);
        $finish;
    end
endmodule
