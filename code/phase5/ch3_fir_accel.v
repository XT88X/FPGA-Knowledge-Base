// =============================================================================
// ch3_fir_accel.v — 转置结构 FIR 滤波器（教学可综合版）
//
//   差分方程：y[n] = sum_{k=0..TAPS-1} c[k] * x[n-k]
//
//   采用"转置(transposed)"直接型：所有乘法器同时看到当前输入 x[n]，
//   寄存器放在加法反馈链上（而不是在输入上做延迟链）。
//   递推关系（r 为各级求和寄存器）：
//       r[TAPS-2]_next = c[TAPS-1] * x
//       r[k]_next      = c[k+1] * x + r[k+1]
//       y              = c[0] * x + r[0]
//   好处：每条加法链都贴着寄存器，关键路径短，容易跑高频——
//   这就是 5.3 讲的"流水线分级"在 DSP 里的典型形态。
//
//   与向量 MAC 的区别：MAC 是"一条向量算完出一个点积"；FIR 是"每来一个采样点
//   就出一个滤波后采样点"，流式吞吐 = 1 采样点/拍（流水线填满后）。
// =============================================================================
module ch3_fir_accel #(
    parameter TAPS = 4          // 抽头数（系数个数）
)(
    input  wire         clk,
    input  wire         rst_n,

    // 输入采样流（简单版：永远 ready，无背压）
    input  wire         s_valid,
    output wire         s_ready,
    input  wire [15:0]  s_x,

    // 输出滤波采样流
    output reg          m_valid,
    output reg  [31:0]  m_y
);

    // 固定系数（教学示例：全 1 -> 4 点滑动平均，便于手算 golden）
    // y[n] = x[n] + x[n-1] + x[n-2] + x[n-3]
    reg signed [15:0] coeff [0:3];
    integer ci;
    initial begin
        for (ci = 0; ci < TAPS; ci = ci + 1) coeff[ci] = 16'sd1;
    end

    // r[0..TAPS-2]：求和反馈链寄存器（TAPS=4 时为 r0,r1,r2）
    reg signed [31:0] r_chain [0:2];
    reg        v_chain [0:2];
    integer j;

    assign s_ready = 1'b1;

    always @(posedge clk) begin
        if (!rst_n) begin
            for (j = 0; j < TAPS-1; j = j + 1) begin
                r_chain[j] <= 32'sd0;
                v_chain[j] <= 1'b0;
            end
            m_valid <= 1'b0;
            m_y     <= 32'd0;
        end else begin
            // 最深一级：c[last]*x，无反馈
            r_chain[TAPS-2] <= s_valid * (s_x * coeff[TAPS-1]);
            v_chain[TAPS-2] <= s_valid;
            // 中间各级：c[k+1]*x + 上一级旧值
            for (j = TAPS-3; j >= 0; j = j - 1) begin
                r_chain[j] <= r_chain[j+1] + s_valid * (s_x * coeff[j+1]);
                v_chain[j] <= v_chain[j+1];
            end
            // 输出：c[0]*x + r[0]
            m_valid <= v_chain[0];
            m_y     <= (s_valid ? (s_x * coeff[0]) : 32'sd0) + r_chain[0];
        end
    end

endmodule
