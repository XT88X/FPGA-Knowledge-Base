//==============================================================================
// tb_uart_rx.v  —  Testbench：UART 接收自检（不使用 task，全部内联）
// 1) 在 rx_in 喂入 8N1 帧 8'hA5（LSB 先出），断言 rx_data==8'hA5、frame_err==0；
// 2) 再喂一帧"停止位=0"的坏帧，断言 frame_err==1。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_uart_rx;

    localparam integer BIT_DIV = 434;

    reg        clk     = 1'b0;
    reg        rst_n   = 1'b0;
    reg        rx_in   = 1'b1;
    wire [7:0] rx_data;
    wire       rx_valid;
    wire       frame_err;

    integer    k;
    integer    j;
    reg [7:0]  dbus;
    reg [7:0]  expected;
    integer    pass_cnt;
    integer    fail_cnt;

    always #10 clk = ~clk;

    uart_rx #(
        .CLK_FREQ_HZ(50_000_000),
        .BAUD_RATE  (115200)
    ) u_dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .rx_in     (rx_in),
        .rx_data   (rx_data),
        .rx_valid  (rx_valid),
        .frame_err (frame_err)
    );

    initial begin
        pass_cnt = 0; fail_cnt = 0;
        rst_n = 1'b0;
        for (k = 0; k < 20; k = k + 1) @(posedge clk);
        rst_n = 1'b1;
        for (k = 0; k < 20; k = k + 1) @(posedge clk);

        // ---- 正常帧：8'hA5，正常停止位 ----
        dbus = 8'hA5;
        rx_in = 1'b0;                                  // 起始位
        for (k = 0; k < BIT_DIV; k = k + 1) @(posedge clk);
        for (j = 0; j < 8; j = j + 1) begin           // 数据位 LSB 先出
            rx_in = dbus[j];
            for (k = 0; k < BIT_DIV; k = k + 1) @(posedge clk);
        end
        rx_in = 1'b1;                                  // 停止位
        for (k = 0; k < BIT_DIV; k = k + 1) @(posedge clk);
        rx_in = 1'b1;

        k = 0;
        while (rx_valid !== 1'b1 && k < 3000) begin
            @(posedge clk); k = k + 1;
        end
        expected = 8'hA5;
        if (rx_data === expected && frame_err === 1'b0) begin
            pass_cnt = pass_cnt + 1;
            $display("[CHK] good frame: rx_data=8'h%0h frame_err=0  OK", rx_data);
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("[CHK] good frame: rx_data=8'h%0h frame_err=%b  FAIL",
                     rx_data, frame_err);
        end
        for (k = 0; k < 500; k = k + 1) @(posedge clk);

        // ---- 坏帧：停止位为 0 ----
        dbus = 8'h55;
        rx_in = 1'b0;
        for (k = 0; k < BIT_DIV; k = k + 1) @(posedge clk);
        for (j = 0; j < 8; j = j + 1) begin
            rx_in = dbus[j];
            for (k = 0; k < BIT_DIV; k = k + 1) @(posedge clk);
        end
        rx_in = 1'b0;                                  // 错误停止位
        for (k = 0; k < BIT_DIV; k = k + 1) @(posedge clk);
        rx_in = 1'b1;

        k = 0;
        while (rx_valid !== 1'b1 && k < 3000) begin
            @(posedge clk); k = k + 1;
        end
        if (frame_err === 1'b1) begin
            pass_cnt = pass_cnt + 1;
            $display("[CHK] bad frame: frame_err=1  OK");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("[CHK] bad frame: frame_err=0  FAIL");
        end

        $display("========================================");
        $display("tb_uart_rx: PASS=%0d FAIL=%0d", pass_cnt, fail_cnt);
        $display("========================================");
        #1000;
        $finish;
    end

endmodule

`default_nettype wire
