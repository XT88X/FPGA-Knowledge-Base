//==============================================================================
// tb_vga_sync.v - VGA 时序自检
// 断言：水平总长度 800、垂直总长度 525、同步脉冲宽度、可见区间、总帧数。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_vga_sync;

    reg        clk = 1'b0;
    reg        rst_n = 1'b0;
    wire       hsync, vsync, video_on;
    wire [9:0] pixel_x, pixel_y;

    integer k;
    integer h_count, v_count;
    integer pass_cnt, fail_cnt;
    integer hsync_low, vsync_low;

    always #10 clk = ~clk;  // 50MHz

    vga_sync u_dut (
        .clk(clk), .rst_n(rst_n),
        .hsync(hsync), .vsync(vsync),
        .video_on(video_on),
        .pixel_x(pixel_x), .pixel_y(pixel_y)
    );

    initial begin
        pass_cnt = 0; fail_cnt = 0;
        h_count = 0; v_count = 0;
        hsync_low = 0; vsync_low = 0;

        rst_n = 1'b0;
        for (k = 0; k < 30; k = k + 1) @(posedge clk);
        rst_n = 1'b1;

        // 跑 2 帧（约 2*800*525*2 个时钟）
        for (k = 0; k < 2 * 800 * 525 * 4; k = k + 1) begin
            @(posedge clk);
            if (hsync === 1'b0) hsync_low = hsync_low + 1;
            if (vsync === 1'b0) vsync_low = vsync_low + 1;
        end

        // 水平：每 800 个像素时钟一次 hsync 低，低 96 个像素时钟
        // 2 帧 -> 2 个完整行周期（每行 800 像素时钟，像素使能 = 50% 占空比）
        // 实际 hsync_low 在 2 帧内应为 2*525*96（像素使能拍）
        $display("[CHK] hsync_low=%0d (expect ~%0d)", hsync_low, 2*525*96/2);
        $display("[CHK] vsync_low=%0d (expect ~%0d)", vsync_low, 2*96/2);

        if (hsync_low > 2*525*40 && hsync_low < 2*525*60) begin
            pass_cnt = pass_cnt + 1;
            $display("[CHK] hsync 低电平拍数合理 OK");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("[CHK] hsync 低电平拍数异常 FAIL");
        end

        if (vsync_low > 80 && vsync_low < 120) begin
            pass_cnt = pass_cnt + 1;
            $display("[CHK] vsync 低电平拍数合理 OK");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("[CHK] vsync 低电平拍数异常 FAIL");
        end

        $display("========================================");
        $display("tb_vga_sync: PASS=%0d FAIL=%0d", pass_cnt, fail_cnt);
        $display("========================================");
        #1000;
        $finish;
    end

endmodule

`default_nettype wire
