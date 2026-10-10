// =============================================================================
// ch4_timer.v — 教学定时器（周期匹配 + 中断标志）
//
//   自由运行计数器 cnt；当 cnt 计到 cmp 且 timer 使能时：
//     * 置位 irq_flag（保持到写 TIMER_CLR 清零）；
//     * 产生一个周期的 irq 脉冲给中断汇总。
//   寄存器（由 SoC 地址译码驱动）：
//     we_ctrl : bit0 = timer 使能
//     we_cmp  : 写周期匹配值
//     we_clr  : 写任意值清零 irq_flag
//   读回：cnt 当前值（由 SoC 提供读口）。
// =============================================================================
module ch4_timer #(
    parameter [31:0] RESET_CMP = 32'd1000
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        we_ctrl,
    input  wire        we_cmp,
    input  wire        we_clr,
    input  wire [31:0] wdata,

    output reg  [31:0] cnt,
    output reg         irq_flag,
    output wire        irq_pulse      // 给中断汇总的脉冲
);

    reg [31:0] cmp;
    reg        timer_en;

    always @(posedge clk) begin
        if (!rst_n) begin
            cnt      <= 32'd0;
            cmp      <= RESET_CMP;
            timer_en <= 1'b0;
            irq_flag <= 1'b0;
        end else begin
            if (we_ctrl) timer_en <= wdata[0];
            if (we_cmp)  cmp      <= wdata;

            // 计数
            if (timer_en)
                cnt <= cnt + 1'b1;

            // 匹配：到 cmp 即置标志并回卷（教学：到 cmp 后清零重新计）
            if (timer_en && (cnt >= cmp)) begin
                irq_flag <= 1'b1;
                cnt      <= 32'd0;
            end

            // 软件清标志
            if (we_clr) irq_flag <= 1'b0;
        end
    end

    // 中断脉冲：flag 置起的那一个周期（供 SoC IRQ 汇总）
    assign irq_pulse = irq_flag & ~we_clr;

endmodule
