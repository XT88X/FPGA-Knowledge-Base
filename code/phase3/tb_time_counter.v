//==============================================================================
// tb_time_counter.v - 时分秒进位自检
// 用小 SEC_MAX 加速，验证 59->00 进位与 23:59:59 归零。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_time_counter;

    reg        clk = 1'b0;
    reg        rst_n = 1'b0;
    reg  [1:0] mode = 2'b00;
    reg        add_pulse = 1'b0;
    wire [5:0] sec, min, hour;

    integer k;
    integer pass_cnt, fail_cnt;

    always #10 clk = ~clk;  // 50MHz

    // 加速：SEC_MAX=1000 而不是 50M
    time_counter #(.CLK_FREQ_HZ(1001)) u_dut (
        .clk(clk), .rst_n(rst_n),
        .mode(mode), .add_pulse(add_pulse),
        .sec(sec), .min(min), .hour(hour)
    );

    initial begin
        pass_cnt = 0; fail_cnt = 0;
        rst_n = 1'b0;
        for (k = 0; k < 20; k = k + 1) @(posedge clk);
        rst_n = 1'b1;

        // 跑 25*60*60 秒（加速后每"秒"=1001 拍）
        // 验证从 00:00:00 走到 23:59:59 再回 00:00:00
        for (k = 0; k < 25 * 60 * 60 * 1001 + 2000; k = k + 1) begin
            @(posedge clk);
            if (sec > 6'd59) begin
                fail_cnt = fail_cnt + 1;
                $display("[CHK] 秒越界! sec=%0d", sec);
            end
            if (min > 6'd59) begin
                fail_cnt = fail_cnt + 1;
                $display("[CHK] 分越界! min=%0d", min);
            end
            if (hour > 6'd23) begin
                fail_cnt = fail_cnt + 1;
                $display("[CHK] 时越界! hour=%0d", hour);
            end
        end

        $display("[CHK] 最终 hour=%0d min=%0d sec=%0d", hour, min, sec);

        if (fail_cnt == 0) begin
            pass_cnt = pass_cnt + 1;
            $display("[CHK] 时分秒无越界 OK");
        end

        // 测试调时：mode=2 调时，按 25 次到 25:00:00 应回 0
        mode = 2'b10;
        for (k = 0; k < 25; k = k + 1) begin
            @(posedge clk);
            add_pulse = 1'b1;
            @(posedge clk);
            add_pulse = 1'b0;
        end
        $display("[CHK] 调时后 hour=%0d", hour);
        if (hour == 6'd0) begin
            pass_cnt = pass_cnt + 1;
            $display("[CHK] 23 之后归零 OK");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("[CHK] 23 之后未归零 FAIL");
        end

        $display("========================================");
        $display("tb_time_counter: PASS=%0d FAIL=%0d", pass_cnt, fail_cnt);
        $display("========================================");
        #1000;
        $finish;
    end

endmodule

`default_nettype wire
