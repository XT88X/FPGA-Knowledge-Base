// tb_ch4_gate_gen.v — 闸门发生器自检
`timescale 1ns/1ps
module tb_ch4_gate_gen;
    reg clk = 0;
    reg rst_n = 0;
    wire gate;
    wire gate_done;

    // 把闸门压到 100 拍、保持 20 拍，加速仿真
    ch4_gate_gen #(
        .CLK_FREQ_HZ(50_000_000),
        .GATE_TICKS(100),
        .HOLD_TICKS(20)
    ) u_dut (
        .clk(clk), .rst_n(rst_n), .gate(gate), .gate_done(gate_done)
    );

    always #10 clk = ~clk;

    integer high_cnt = 0;
    integer done_cnt = 0;
    integer i;
    initial begin
        rst_n = 0;
        #55;
        rst_n = 1;
        // 跑约 2 个完整周期（120*2=240 拍）
        for (i = 0; i < 300; i = i + 1) begin
            @(posedge clk);
            if (gate) high_cnt = high_cnt + 1;
            if (gate_done) done_cnt = done_cnt + 1;
        end
        // 每个周期 gate 应高 100 拍；跑了约 2.5 个周期，高电平计数应在 200~300
        if (high_cnt >= 200 && high_cnt <= 300)
            $display("GATE_GEN OK: high_cnt=%0d", high_cnt);
        else
            $display("GATE_GEN FAIL: high_cnt=%0d", high_cnt);
        // gate_done 每个周期 1 拍，应出现 2~3 次
        if (done_cnt >= 2 && done_cnt <= 3)
            $display("GATE_GEN OK: done_cnt=%0d", done_cnt);
        else
            $display("GATE_GEN FAIL: done_cnt=%0d", done_cnt);
        $finish;
    end
endmodule
