//==============================================================================
// tb_buzzer_music.v  —  Testbench：蜂鸣器音符频率自检
//   第一个音是 C4（分频 95419）：buzzer 每 95419 个时钟翻转一次。
//   测量两次翻转之间的时钟数，应约等于 95419（半周期）。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_buzzer_music;

    reg  clk = 1'b0;
    reg  rst_n = 1'b0;
    wire buzzer_out;

    integer k;
    integer edge_gap;
    integer pass_cnt, fail_cnt;
    reg     b_d;

    always #10 clk = ~clk;

    buzzer_music #(
        .CLK_FREQ_HZ(50_000_000),
        .DUR_DIV(4)
    ) u_dut (
        .clk(clk), .rst_n(rst_n), .buzzer_out(buzzer_out)
    );

    always @(posedge clk) b_d <= buzzer_out;
    wire rise = (buzzer_out === 1'b1 && b_d === 1'b0);

    initial begin
        pass_cnt = 0; fail_cnt = 0;
        rst_n = 1'b0;
        for (k = 0; k < 30; k = k + 1) @(posedge clk);
        rst_n = 1'b1;

        // 等到第一个上升沿
        k = 0;
        while (!rise && k < 3000000) begin @(posedge clk); k = k + 1; end
        // 再数到下一个上升沿，间隔应约 = 2*95419（整周期）
        edge_gap = 0;
        k = 0;
        while (!rise && k < 3000000) begin @(posedge clk); edge_gap = edge_gap + 1; k = k + 1; end

        $display("[CHK] buzzer 整周期 = %0d 个时钟 (expect ~190838)", edge_gap);
        if (edge_gap > 180000 && edge_gap < 202000) begin
            pass_cnt = pass_cnt + 1;
            $display("[CHK] C4 方波频率正确  OK");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("[CHK] 方波频率偏差过大  FAIL");
        end

        $display("========================================");
        $display("tb_buzzer_music: PASS=%0d FAIL=%0d", pass_cnt, fail_cnt);
        $display("========================================");
        #1000;
        $finish;
    end

endmodule

`default_nettype wire
