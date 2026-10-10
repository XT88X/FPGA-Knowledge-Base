//==============================================================================
// tb_uart_echo_top.v  —  Testbench：串口回显自检（内联，无 task）
//   在 rx_in 发一帧 8'hA5，等待 tx_out 出现回显帧，逐位比对应相同。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_uart_echo_top;

    localparam integer BIT_DIV = 434;

    reg        clk   = 1'b0;
    reg        rst_n = 1'b0;
    reg        rx_in = 1'b1;
    wire       tx_out;

    integer    k, j;
    reg [7:0]  dbus;
    reg [7:0]  echo;
    integer    pass_cnt, fail_cnt;

    always #10 clk = ~clk;

    uart_echo_top #(
        .CLK_FREQ_HZ(50_000_000),
        .BAUD_RATE  (115200)
    ) u_dut (
        .clk   (clk),
        .rst_n (rst_n),
        .rx_in (rx_in),
        .tx_out(tx_out)
    );

    initial begin
        pass_cnt = 0; fail_cnt = 0;
        rst_n = 1'b0;
        for (k = 0; k < 20; k = k + 1) @(posedge clk);
        rst_n = 1'b1;
        for (k = 0; k < 20; k = k + 1) @(posedge clk);

        // 1) 在 rx_in 发一帧 8'hA5
        dbus = 8'hA5;
        rx_in = 1'b0;
        for (k = 0; k < BIT_DIV; k = k + 1) @(posedge clk);
        for (j = 0; j < 8; j = j + 1) begin
            rx_in = dbus[j];
            for (k = 0; k < BIT_DIV; k = k + 1) @(posedge clk);
        end
        rx_in = 1'b1;
        for (k = 0; k < BIT_DIV; k = k + 1) @(posedge clk);

        // 2) 等待 tx_out 出现起始位（下降沿）
        k = 0;
        while (tx_out === 1'b1 && k < 20000) begin
            @(posedge clk); k = k + 1;
        end

        // 3) 在 tx_out 上采样回显帧
        for (k = 0; k < BIT_DIV/2; k = k + 1) @(posedge clk);
        if (tx_out === 1'b0)
            pass_cnt = pass_cnt + 1;
        else begin
            fail_cnt = fail_cnt + 1;
            $display("[CHK] echo start bit FAIL");
        end

        echo = 8'h00;
        for (j = 0; j < 8; j = j + 1) begin
            for (k = 0; k < BIT_DIV; k = k + 1) @(posedge clk);
            echo[j] = tx_out;
        end
        if (echo == 8'hA5) begin
            pass_cnt = pass_cnt + 1;
            $display("[CHK] echo byte = 8'hA5  OK");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("[CHK] echo byte = 8'h%0h (expect A5) FAIL", echo);
        end

        $display("========================================");
        $display("tb_uart_echo_top: PASS=%0d FAIL=%0d", pass_cnt, fail_cnt);
        $display("========================================");
        #1000;
        $finish;
    end

endmodule

`default_nettype wire
