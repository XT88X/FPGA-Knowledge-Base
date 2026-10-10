// =============================================================================
// ch4_gpio.v — 教学 GPIO（方向寄存器 + 数据寄存器，8 bit）
//
//   寄存器（由 SoC 地址译码驱动 we_*）：
//     dir_reg  : bit=1 该脚为输出
//     out_reg  : 输出值
//   外部脚：
//     gpio_o  : 实际输出（dir=1 的脚）
//     gpio_i  : 外部输入
//   读回：{ dir_reg, out_reg, gpio_i } 由 SoC 拼接。
// =============================================================================
module ch4_gpio #(
    parameter WIDTH = 8
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        we_dir,
    input  wire        we_out,
    input  wire [31:0] wdata,

    input  wire [7:0]  gpio_i,     // 外部输入脚
    output wire [7:0]  gpio_o,     // 输出值
    output reg  [7:0]  dir_reg,
    output reg  [7:0]  out_reg
);

    // 实际输出脚 = 方向为 1 的位取 out_reg
    assign gpio_o = out_reg & dir_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            dir_reg <= 8'h00;
            out_reg <= 8'h00;
        end else begin
            if (we_dir) dir_reg <= wdata[7:0];
            if (we_out) out_reg <= wdata[7:0];
        end
    end

endmodule
