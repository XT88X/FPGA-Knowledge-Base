//==============================================================================
// tb_spi_master.v  —  Testbench：SPI 主机自检
// 1) CPOL=0/CPHA=0 下，cs_n 传输期间拉低；
// 2) 一帧 sclk 应恰好产生 8 个有效脉冲；
// 3) 在 sclk 上升沿采样 mosi，MSB 先出，重组应等于 0xA5。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_spi_master;

    reg        clk = 1'b0;
    reg        rst_n = 1'b0;
    reg  [7:0] tx_data = 8'h00;
    reg        tx_valid = 1'b0;
    wire       tx_ready;
    wire       sclk;
    wire       mosi;
    wire       miso;
    wire [7:0] rx_data;
    wire       cs_n;

    integer    k, j;
    reg [7:0]  sampled;
    integer    rise_cnt;
    integer    pass_cnt, fail_cnt;
    reg        sclk_d;

    always #10 clk = ~clk;   // 50MHz

    assign miso = 1'b0;

    spi_master #(
        .CLK_FREQ_HZ(50_000_000),
        .SCLK_HZ    (100_000),
        .CPOL       (1'b0),
        .CPHA       (1'b0)
    ) u_dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .tx_data  (tx_data),
        .tx_valid (tx_valid),
        .tx_ready (tx_ready),
        .sclk     (sclk),
        .mosi     (mosi),
        .miso     (miso),
        .rx_data  (rx_data),
        .cs_n     (cs_n)
    );

    // 记录 sclk 上升沿
    always @(posedge clk) begin
        sclk_d <= sclk;
    end
    wire sclk_rise = (sclk === 1'b1 && sclk_d === 1'b0);

    initial begin
        pass_cnt = 0; fail_cnt = 0;
        rst_n = 1'b0;
        for (k = 0; k < 30; k = k + 1) @(posedge clk);
        rst_n = 1'b1;
        for (k = 0; k < 30; k = k + 1) @(posedge clk);

        // 发起发送 0xA5
        @(posedge clk);
        tx_data  = 8'hA5;
        tx_valid = 1'b1;
        @(posedge clk);
        tx_valid = 1'b0;

        // 监测整个传输：cs_n 应在低电平期间出现 8 个 sclk 上升沿，并在上升沿采样 mosi
        sampled  = 8'h00;
        rise_cnt = 0;
        // 等到 cs_n 拉低
        k = 0;
        while (cs_n === 1'b1 && k < 20000) begin @(posedge clk); k = k + 1; end

        // 在 cs_n=0 期间逐时钟监测
        k = 0;
        while (cs_n === 1'b0 && k < 200000) begin
            @(posedge clk);
            if (sclk_rise) begin
                rise_cnt = rise_cnt + 1;
                sampled  = {sampled[6:0], mosi};   // MSB 先入
            end
            k = k + 1;
        end

        $display("[CHK] rise_cnt=%0d sampled=8'h%0h", rise_cnt, sampled);
        if (rise_cnt == 8) begin
            pass_cnt = pass_cnt + 1;
            $display("[CHK] 8 个 sclk 脉冲  OK");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("[CHK] sclk 脉冲数=%0d (expect 8)  FAIL", rise_cnt);
        end
        if (sampled == 8'hA5) begin
            pass_cnt = pass_cnt + 1;
            $display("[CHK] MOSI 字节 = 8'hA5  OK");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("[CHK] MOSI 字节 = 8'h%0h (expect A5)  FAIL", sampled);
        end

        $display("========================================");
        $display("tb_spi_master: PASS=%0d FAIL=%0d", pass_cnt, fail_cnt);
        $display("========================================");
        #1000;
        $finish;
    end

endmodule

`default_nettype wire
