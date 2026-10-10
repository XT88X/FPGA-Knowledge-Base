//==============================================================================
// mux4.v  —  可综合：参数位宽 4 选 1 多路选择器（MUX）
// 目标器件：通用 Xilinx Artix-7 / Zynq（7 系列）
//
// 原理：sel[1:0] 从 d0~d3 中选一路输出 y。位宽 WIDTH 参数化，
//   既可选 1 位（做位选/通道选择），也可一次选多位（如 8 位段码、
//   多位数码管动态扫描时把对应位的段码切出来）。
//==============================================================================
`default_nettype none

module mux4 #(
    parameter WIDTH = 8            // 数据位宽
)(
    input  wire [7:0] d0,    // 选择输入 0
    input  wire [7:0] d1,    // 选择输入 1
    input  wire [7:0] d2,    // 选择输入 2
    input  wire [7:0] d3,    // 选择输入 3
    input  wire [1:0] sel,   // 选择信号
    output reg  [7:0] y       // 选中的那一路
);

    always @(*) begin
        case (sel)
            2'd0:    y = d0;
            2'd1:    y = d1;
            2'd2:    y = d2;
            default: y = d3;
        endcase
    end

endmodule

`default_nettype wire
