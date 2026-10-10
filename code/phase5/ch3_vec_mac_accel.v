// =============================================================================
// ch3_vec_mac_accel.v — 向量点积（乘加）硬件加速器（教学可综合版）
//
//   功能：对一路 AXI-Stream 风格的输入流做向量点积
//             result = sum( a[i] * b[i] )   i = 0 .. N-1
//
//   设计要点（对应 5.3 讲解）：
//     * 并行度 LANES=4：每个输入拍同时送入 4 对 (a,b)，内部 4 个乘法器并行算；
//     * 流水线 2 级：第 1 级寄存乘积，第 2 级寄存累加和，提高 fmax；
//     * valid/ready 反压：下游不 ready 时 s_ready 拉低，上游停发；
//     * s_keep[3:0]：最后一拍不足 LANES 个有效元素时，用 keep 掩码屏蔽无效车道，
//       从而自然支持"N 不能被 4 整除"的任意长度向量；
//     * s_last=1：标记向量结束，流水线排空后在主通道吐出最终累加结果，
//       随后累加器自动清零，准备下一条向量。
//
//   接口（valid/ready 流式，AXI-Stream 概念，非完整 AXI4-Stream）：
//     从通道(输入)：s_valid / s_ready / s_a[63:0](4x16) / s_b[63:0] /
//                   s_keep[3:0] / s_last
//     主通道(输出)：m_valid / m_ready / m_data[31:0]
//
//   注意：端口位宽在端口声明里写死为数字字面量（[15:0]/[63:0]/[31:0]），
//         内部仍可用参数 LANES 做 generate 展开——这是本仓库结构校验脚本的要求。
// =============================================================================
module ch3_vec_mac_accel #(
    parameter LANES      = 4,    // 并行车道数（=每拍处理的元素对数）
    parameter DATA_W     = 16,   // 操作数位宽
    parameter ACC_W      = 32    // 累加器位宽
)(
    input  wire         clk,
    input  wire         rst_n,   // 同步低电平复位

    // ---- 从通道：输入向量流 ----
    input  wire         s_valid,
    output wire         s_ready,
    input  wire [63:0]  s_a,     // 4 个 16-bit a：{a3,a2,a1,a0}
    input  wire [63:0]  s_b,     // 4 个 16-bit b：{b3,b2,b1,b0}
    input  wire [3:0]   s_keep,  // 每拍有效车道掩码（1=该车道参与累加）
    input  wire         s_last, // 本拍是向量最后一拍

    // ---- 主通道：输出点积结果 ----
    output reg          m_valid,
    input  wire         m_ready,
    output reg  [31:0]  m_data
);

    // ---- 把打包向量拆成 4 个车道（generate 展开，体现"并行度"）----
    wire [15:0] a_lane [0:3];
    wire [15:0] b_lane [0:3];
    genvar g;
    generate
        for (g = 0; g < LANES; g = g + 1) begin : lane_unpack
            assign a_lane[g] = s_a[g*16 +: 16];
            assign b_lane[g] = s_b[g*16 +: 16];
        end
    endgenerate

    // ---- 第 0 级（组合）：每车道乘积，无效车道置 0 ----
    reg  [31:0] prod [0:3];
    reg  [31:0] sum_beat0;
    integer k;
    always @(*) begin
        sum_beat0 = 32'd0;
        for (k = 0; k < LANES; k = k + 1) begin
            prod[k] = s_keep[k] ? (a_lane[k] * b_lane[k]) : 32'd0;
            sum_beat0 = sum_beat0 + prod[k];
        end
    end

    // ---- 反压：结果未被下游取走时，停止接收新输入 ----
    wire result_outstanding = m_valid;
    assign s_ready = ~result_outstanding;
    wire   accepted = s_valid & s_ready;

    // ---- 流水线第 1 级：寄存"本拍部分和"与 last ----
    reg [31:0] sum_beat1;
    reg        last1;
    always @(posedge clk) begin
        if (!rst_n) begin
            sum_beat1 <= 32'd0;
            last1     <= 1'b0;
        end else if (accepted) begin
            sum_beat1 <= sum_beat0;
            last1     <= s_last;
        end
    end

    // ---- 流水线第 2 级：累加器 ----
    //   正常：acc <= acc + sum_beat1；
    //   当 last2=1 且结果被取走(m_valid&m_ready)后，acc 清零，开始下一条向量。
    reg [31:0] acc;
    reg        last2;
    always @(posedge clk) begin
        if (!rst_n) begin
            acc   <= 32'd0;
            last2 <= 1'b0;
        end else begin
            last2 <= last1;
            if (m_valid & m_ready)
                acc <= 32'd0;            // 上一条向量结果已取走，清零准备下一条
            else
                acc <= acc + sum_beat1;  // 累加本拍部分和
        end
    end

    // ---- 结果输出：last2 到达即吐出最终点积 ----
    always @(posedge clk) begin
        if (!rst_n) begin
            m_valid <= 1'b0;
            m_data  <= 32'd0;
        end else if (last2 & ~m_valid) begin
            m_valid <= 1'b1;
            m_data  <= acc;             // 排空后：acc 即整条向量的点积
        end else if (m_valid & m_ready) begin
            m_valid <= 1'b0;            // 下游取走，撤销有效
        end
    end

endmodule
