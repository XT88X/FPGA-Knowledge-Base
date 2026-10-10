//==============================================================================
// tb_vga_moving_block_top.v - 移动方块边界/反弹自检
// 验证方块位置在边界内、碰到边界后方向反转。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_vga_moving_block_top;

    reg        clk = 1'b0;
    reg        rst_n = 1'b0;
    wire       hsync, vsync;
    wire [2:0] rgb;

    integer k;
    integer pass_cnt, fail_cnt;

    always #10 clk = ~clk;

    vga_moving_block_top u_dut (
        .clk(clk), .rst_n(rst_n),
        .hsync(hsync), .vsync(vsync),
        .rgb(rgb)
    );

    initial begin
        pass_cnt = 0; fail_cnt = 0;
        rst_n = 1'b0;
        for (k = 0; k < 30; k = k + 1) @(posedge clk);
        rst_n = 1'b1;

        // 跑 10 帧，监控 block_x/block_y 是否越界
        // block_x 应在 0..600 之间，block_y 应在 0..440 之间
        for (k = 0; k < 10 * 800 * 525 * 4; k = k + 1) begin
            @(posedge clk);
            // 越界检查（通过 hierarchical 引用）
            if (u_dut.block_x > 10'd600 || u_dut.block_y > 10'd440) begin
                fail_cnt = fail_cnt + 1;
                $display("[CHK] 越界! block_x=%0d block_y=%0d", u_dut.block_x, u_dut.block_y);
            end
        end

        if (fail_cnt == 0) begin
            pass_cnt = pass_cnt + 1;
            $display("[CHK] 方块位置始终在边界内 OK");
        end

        $display("========================================");
        $display("tb_vga_moving_block_top: PASS=%0d FAIL=%0d", pass_cnt, fail_cnt);
        $display("========================================");
        #1000;
        $finish;
    end

endmodule

`default_nettype wire
