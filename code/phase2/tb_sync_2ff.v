//==============================================================================
// tb_sync_2ff.v  —  Testbench：两级触发器同步演示
//   * 先复位；再让异步输入变 1，等待 3 个时钟后 sync_out 应稳定为 1。
//   * 再让异步输入变 0（期间注入一次 X 模拟亚稳态），最终 sync_out 应稳定为 0。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_sync_2ff;

    reg      clk;
    reg      rst_n;
    reg      async_in;
    wire     sync_out;
    integer  err;

    always #10 clk = ~clk;

    sync_2ff u_dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .async_in (async_in),
        .sync_out (sync_out)
    );

    initial begin
        clk      = 1'b0;
        rst_n    = 1'b0;
        async_in = 1'b0;
        err      = 0;

        #25 rst_n = 1'b1;

        // 异步输入拉高（故意在时钟沿附近变化，模拟跨域）
        async_in = 1'b1;
        #60;                       // 3 个时钟，两级同步应已采到
        $display("[TB] async_in=1, sync_out=%b", sync_out);
        if (sync_out != 1'b1) begin
            err = err + 1;
            $display("[TB] FAIL: sync_out=%b 应为 1", sync_out);
        end

        // 注入 X 模拟第一级亚稳态，随后拉低
        async_in = 1'bx;
        #15;
        async_in = 1'b0;
        #60;
        $display("[TB] async_in=0, sync_out=%b", sync_out);
        if (sync_out != 1'b0) begin
            err = err + 1;
            $display("[TB] FAIL: sync_out=%b 应为 0", sync_out);
        end

        if (err == 0) $display("[TB] PASS: 两级同步输出在两拍后跟随异步输入");
        else          $display("[TB] FAIL: 共 %0d 处错误", err);

        $finish;
    end

endmodule

`default_nettype wire
