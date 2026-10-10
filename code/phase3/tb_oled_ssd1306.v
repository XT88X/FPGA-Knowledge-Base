//==============================================================================
// tb_oled_ssd1306.v  —  Testbench：SSD1306 控制器自检
// 1) 捕获初始化阶段第一个 SPI 字节：应为 dc=0 且数据=0xAE（display off）；
// 2) 初始化结束后发 char_wr，校验写字符过程中出现 dc=1（数据）事务。
// 注意：SCLK 在 tb 里降到 100kHz 以缩短仿真时间。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_oled_ssd1306;

    reg        clk = 1'b0;
    reg        rst_n = 1'b0;
    reg  [6:0] char_col = 7'd0;
    reg  [2:0] char_page = 3'd0;
    reg  [7:0] char_code = 8'h30;
    reg        char_wr = 1'b0;
    wire       busy;
    wire       oled_cs_n;
    wire       oled_dc;
    wire       oled_sclk;
    wire       oled_mosi;

    integer    k;
    reg        sclk_d;
    wire       sclk_rise = (oled_sclk === 1'b1 && sclk_d === 1'b0);
    reg [7:0]  byte_buf;
    integer    bit_cnt;
    reg        dc_seen_data;
    integer    pass_cnt, fail_cnt;

    always #10 clk = ~clk;

    oled_ssd1306 #(
        .CLK_FREQ_HZ(50_000_000),
        .SCLK_HZ    (100_000)
    ) u_dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .char_col (char_col),
        .char_page(char_page),
        .char_code(char_code),
        .char_wr  (char_wr),
        .busy     (busy),
        .oled_cs_n(oled_cs_n),
        .oled_dc  (oled_dc),
        .oled_sclk(oled_sclk),
        .oled_mosi(oled_mosi)
    );

    always @(posedge clk) sclk_d <= oled_sclk;

    initial begin
        pass_cnt = 0; fail_cnt = 0;
        dc_seen_data = 1'b0;
        byte_buf = 8'h00;
        bit_cnt = 0;

        rst_n = 1'b0;
        for (k = 0; k < 30; k = k + 1) @(posedge clk);
        rst_n = 1'b1;

        // ---- 捕获第一个 SPI 字节 ----
        // 等 cs_n 拉低
        k = 0;
        while (oled_cs_n === 1'b1 && k < 500000) begin @(posedge clk); k = k + 1; end
        // 在 cs_n=0 期间收 8 个 sclk 上升沿
        bit_cnt = 0;
        byte_buf = 8'h00;
        k = 0;
        while (bit_cnt < 8 && k < 500000) begin
            @(posedge clk);
            if (sclk_rise) begin
                byte_buf = {byte_buf[6:0], oled_mosi};
                bit_cnt = bit_cnt + 1;
            end
            k = k + 1;
        end
        $display("[CHK] first init byte = 8'h%0h, dc=%b", byte_buf, oled_dc);
        if (byte_buf == 8'hAE && oled_dc === 1'b0) begin
            pass_cnt = pass_cnt + 1;
            $display("[CHK] 首条命令 0xAE(display off), dc=0  OK");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("[CHK] 首条命令应为 0xAE, dc=0, 实际 8'h%0h dc=%b  FAIL",
                     byte_buf, oled_dc);
        end

        // ---- 等初始化完成（busy 变低）----
        k = 0;
        while (busy === 1'b1 && k < 5000000) begin @(posedge clk); k = k + 1; end
        $display("[CHK] init done, busy=%b", busy);

        // ---- 写一个字符，监测是否出现 dc=1 的数据字节 ----
        char_col  = 7'd0;
        char_page = 3'd0;
        char_code = 8'h31;   // '1'
        @(posedge clk);
        char_wr = 1'b1;
        @(posedge clk);
        char_wr = 1'b0;

        // 监测直到 busy 重新变低（写完）
        k = 0;
        dc_seen_data = 1'b0;
        for (k = 0; k < 5000000; k = k + 1) begin
            @(posedge clk);
            if (oled_cs_n === 1'b0 && oled_dc === 1'b1) dc_seen_data = 1'b1;
            if (busy === 1'b0 && k > 100) k = 5000000;   // 等价提前退出
        end
        if (dc_seen_data) begin
            pass_cnt = pass_cnt + 1;
            $display("[CHK] 写字符过程中出现 dc=1(数据)  OK");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("[CHK] 写字符未出现 dc=1 数据事务  FAIL");
        end

        $display("========================================");
        $display("tb_oled_ssd1306: PASS=%0d FAIL=%0d", pass_cnt, fail_cnt);
        $display("========================================");
        #1000;
        $finish;
    end

endmodule

`default_nettype wire
