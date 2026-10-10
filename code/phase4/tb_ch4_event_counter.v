// tb_ch4_event_counter.v — 事件计数器自检：闸门内给定已知上升沿数，核对 count
`timescale 1ns/1ps
module tb_ch4_event_counter;
    reg clk = 0;
    reg rst_n = 0;
    reg sig_in = 0;
    reg gate = 0;
    reg latch = 0;
    reg clr = 0;
    wire [26:0] count;
    wire [26:0] latched;
    wire overflow;

    ch4_event_counter #(.CNT_WIDTH(27)) u_dut (
        .clk(clk), .rst_n(rst_n), .sig_in(sig_in), .gate(gate),
        .latch(latch), .clr(clr),
        .count(count), .latched(latched), .overflow(overflow)
    );

    always #10 clk = ~clk;

    integer edges = 0;
    integer i;
    reg [26:0] expect;
    initial begin
        rst_n = 0; sig_in = 0; gate = 0; latch = 0; clr = 0;
        #55; rst_n = 1;
        #20;

        // 闸门打开期间，让 sig_in 产生 10 个上升沿
        gate = 1;
        for (i = 0; i < 10; i = i + 1) begin
            @(posedge clk);
            sig_in = 1;
            @(posedge clk);
            sig_in = 0;
        end
        gate = 0;
        #20;

        // count 应约为 10（同步链路有 ±1~2 拍对齐误差）
        if (count >= 8 && count <= 12)
            $display("EVENT_CNTR OK: count=%0d (expect~10)", count);
        else
            $display("EVENT_CNTR FAIL: count=%0d", count);

        // latch 锁存
        @(posedge clk); latch = 1; @(posedge clk); latch = 0;
        if (latched == count)
            $display("EVENT_CNTR OK: latched=%0d", latched);
        else
            $display("EVENT_CNTR FAIL: latched=%0d count=%0d", latched, count);

        // clr 清零
        @(posedge clk); clr = 1; @(posedge clk); clr = 0;
        if (count == 27'd0)
            $display("EVENT_CNTR OK: cleared");
        else
            $display("EVENT_CNTR FAIL: not cleared count=%0d", count);
        $finish;
    end
endmodule
