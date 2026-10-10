// =============================================================================
// ch1_riscv_alu.v — 教学型 RV32I ALU
//   支持：ADD / SUB / AND / OR / XOR / SLT(有符号比较) / SLTU(无符号比较)
//   全部组合逻辑输出，无时钟（纯组合运算单元）。
//   alu_op 编码（localparam，大写）：
//     4'd0 ADD, 4'd1 SUB, 4'd2 AND, 4'd3 OR,
//     4'd4 XOR, 4'd5 SLT, 4'd6 SLTU
// =============================================================================
module ch1_riscv_alu #(
    parameter WIDTH = 32
)(
    input  wire [WIDTH-1:0]  a,
    input  wire [WIDTH-1:0]  b,
    input  wire [3:0]        alu_op,
    output reg  [WIDTH-1:0]  y,
    output wire              zero      // 结果是否为 0（供 BEQ/BNE 使用）
);

    localparam ALU_ADD  = 4'd0;
    localparam ALU_SUB  = 4'd1;
    localparam ALU_AND  = 4'd2;
    localparam ALU_OR   = 4'd3;
    localparam ALU_XOR  = 4'd4;
    localparam ALU_SLT  = 4'd5;
    localparam ALU_SLTU = 4'd6;

    wire signed [WIDTH-1:0] sa = a;
    wire signed [WIDTH-1:0] sb = b;

    always @(*) begin
        case (alu_op)
            ALU_ADD : y = a + b;
            ALU_SUB : y = a - b;
            ALU_AND : y = a & b;
            ALU_OR  : y = a | b;
            ALU_XOR : y = a ^ b;
            ALU_SLT : y = (sa < sb) ? 32'd1 : 32'd0;   // 有符号比较
            ALU_SLTU: y = (a < b)   ? 32'd1 : 32'd0;  // 无符号比较
            default : y = {WIDTH{1'b0}};
        endcase
    end

    assign zero = (y == {WIDTH{1'b0}});

endmodule
