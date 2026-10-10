//==============================================================================
// shift_reg8.v  —  可综合：8 位移位寄存器（串入并出 SIPO，兼带串出）
// 目标器件：通用 Xilinx Artix-7 / Zynq（7 系列）
//
// 原理：每个时钟上升沿，把 sin 移入最低位，其余位右移：
//        q <= {q[WIDTH-2:0], sin}
//   * pout 是并行输出（8 位同时读出）= 串入并出(SIPO)；
//   * sout 是最高位 = 经过 WIDTH 级后的串行输出（并入串出/级联扩展用）。
//   异步低电平复位把 q 清 0。
//==============================================================================
`default_nettype none

module shift_reg8 #(
    parameter WIDTH = 8             // 移位位数
)(
    input  wire             clk,    // 系统时钟
    input  wire             rst_n, // 异步低电平复位
    input  wire             sin,   // 串行输入
    output wire [7:0] pout,       // 并行输出（与默认 WIDTH=8 一致）
    output wire       sout         // 串行输出（最高位）
);

    reg [WIDTH-1:0] q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q <= {WIDTH{1'b0}};
        else
            q <= {q[WIDTH-2:0], sin};
    end

    assign pout  = q;
    assign sout  = q[WIDTH-1];

endmodule

`default_nettype wire
