//==============================================================================
// tb_uart_tx.v  —  Testbench：UART 发送自检
// 1) 检测起始位下降沿后，逐位在每位中点采样；
// 2) 校验序列 = 起始0 + 8'hA5(LSB先出) + 停止1；
// 3) 相邻两位中点时间间隔应约等于 BIT_DIV=434 个系统时钟。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_uart_tx;

    localparam integer BIT_DIV = 434;

    reg        clk   = 1'b0;
    reg        rst_n = 1'b0;
    reg  [7:0] tx_data  = 8'h00;
    reg        tx_valid  = 1'b0;
    wire       tx_ready;
    wire       tx_out;

    integer    i;
    integer    k;
    reg [7:0]  recv;
    integer    pass_cnt;
    integer    fail_cnt;
    integer    t_last_sample;
    integer    period;

    always #10 clk = ~clk;   // 50MHz

    uart_tx #(
        .CLK_FREQ_HZ(50_000_000),
        .BAUD_RATE  (115200)
    ) u_dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .tx_data  (tx_data),
        .tx_valid (tx_valid),
        .tx_ready (tx_ready),
        .tx_out   (tx_out)
    );

    initial begin
        pass_cnt = 0; fail_cnt = 0;

        rst_n = 1'b0;
        for (k = 0; k < 20; k = k + 1) @(posedge clk);
        rst_n = 1'b1;
        for (k = 0; k < 20; k = k + 1) @(posedge clk);

        // 发起发送 8'hA5
        @(posedge clk);
        tx_data  = 8'hA5;
        tx_valid = 1'b1;
        @(posedge clk);
        tx_valid = 1'b0;

        // 等待起始位出现（tx_out 拉低）
        i = 0;
        while (tx_out === 1'b1 && i < 2000) begin
            @(posedge clk);
            i = i + 1;
        end

        // 到起始位中点
        for (k = 0; k < BIT_DIV/2; k = k + 1) @(posedge clk);
        t_last_sample = $time;
        if (tx_out === 1'b0) begin
            pass_cnt = pass_cnt + 1;
            $display("[CHK] start bit = 0  OK");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("[CHK] start bit != 0  FAIL, got %b", tx_out);
        end

        // 依次采样 8 个数据位（LSB 先出）
        recv = 8'h00;
        for (i = 0; i < 8; i = i + 1) begin
            for (k = 0; k < BIT_DIV; k = k + 1) @(posedge clk);
            period = $time - t_last_sample;
            t_last_sample = $time;
            recv[i] = tx_out;
            $display("[CHK] bit[%0d] = %b  (period=%0d ns)", i, tx_out, period);
        end
        if (recv == 8'hA5) begin
            pass_cnt = pass_cnt + 1;
            $display("[CHK] data byte = 8'hA5  OK");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("[CHK] data byte = 8'h%0h (expect A5)  FAIL", recv);
        end

        // 采样停止位
        for (k = 0; k < BIT_DIV; k = k + 1) @(posedge clk);
        if (tx_out === 1'b1) begin
            pass_cnt = pass_cnt + 1;
            $display("[CHK] stop bit = 1  OK");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("[CHK] stop bit != 1  FAIL");
        end

        $display("========================================");
        $display("tb_uart_tx: PASS=%0d FAIL=%0d", pass_cnt, fail_cnt);
        $display("========================================");
        #1000;
        $finish;
    end

endmodule

`default_nettype wire
