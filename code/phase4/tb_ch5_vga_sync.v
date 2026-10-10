// tb_ch5_vga_sync.v — 校验行场同步时序区间
`timescale 1ns/1ps
module tb_ch5_vga_sync;
    reg clk = 0;
    reg rst_n = 0;
    wire hsync, vsync, video_on;
    wire [9:0] pixel_x, pixel_y;
    wire pxl_en;

    ch5_vga_sync u_dut (
        .clk(clk), .rst_n(rst_n), .hsync(hsync), .vsync(vsync),
        .video_on(video_on), .pixel_x(pixel_x), .pixel_y(pixel_y), .pxl_en(pxl_en)
    );

    always #10 clk = ~clk;

    integer i;
    integer hsync_low = 0, vsync_low = 0;
    integer max_x = 0, max_y = 0;
    initial begin
        rst_n = 0; #55; rst_n = 1;
        // 跑约 2 帧（800*525*2 个像素使能 ≈ 840000 个 25MHz 拍 = 420000 个 50MHz 拍）
        for (i = 0; i < 500000; i = i + 1) begin
            @(posedge clk);
            if (pxl_en) begin
                if (!hsync) hsync_low = hsync_low + 1;
                if (!vsync) vsync_low = vsync_low + 1;
                if (pixel_x > max_x) max_x = pixel_x;
                if (pixel_y > max_y) max_y = pixel_y;
            end
        end
        // 行总像素 800，场总行 525
        if (max_x == 799 && max_y == 524)
            $display("VGA_SYNC OK: max_x=%0d max_y=%0d", max_x, max_y);
        else
            $display("VGA_SYNC FAIL: max_x=%0d max_y=%0d", max_x, max_y);
        // 每帧同步脉冲：行 96 个像素 *2 帧，场 2 行*2；只做存在性检查
        if (hsync_low > 100 && vsync_low > 0)
            $display("VGA_SYNC OK: hsync_low=%0d vsync_low=%0d", hsync_low, vsync_low);
        else
            $display("VGA_SYNC FAIL: hsync_low=%0d vsync_low=%0d", hsync_low, vsync_low);
        $finish;
    end
endmodule
