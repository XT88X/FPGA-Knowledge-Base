// =============================================================================
// ch1_riscv_regfile.v — 教学型 RV32I 32x32 寄存器堆
//   * 32 个 32-bit 通用寄存器 x0..x31
//   * x0 硬连线恒为 0（写 x0 丢弃，读 x0 恒 0）
//   * 组合读（组合读出 ra/rs1），时钟沿同步写（rd）
//   * 同步低电平复位（rst_n）
// 说明：这是"单周期 RISC-V"教学数据通路的标准做法——读用组合逻辑，
//       写用时钟沿，综合后对应分布式 RAM / 触发器堆。
// =============================================================================
module ch1_riscv_regfile #(
    parameter WIDTH = 32              // 数据位宽（RV32I 固定 32）
)(
    input  wire               clk,
    input  wire               rst_n,  // 同步低电平复位
    // 读端口 1（rs1）
    input  wire [4:0]         raddr1,
    output wire [WIDTH-1:0]   rdata1,
    // 读端口 2（rs2）
    input  wire [4:0]         raddr2,
    output wire [WIDTH-1:0]   rdata2,
    // 写端口（rd）
    input  wire               we,
    input  wire [4:0]         waddr,
    input  wire [WIDTH-1:0]   wdata
);

    // 32 个寄存器；x0 单独恒零，其余用数组
    reg [WIDTH-1:0] rf [1:31];
    integer i;

    // ---- 组合读：x0 恒 0，其余按地址取 ----
    assign rdata1 = (raddr1 == 5'd0) ? {WIDTH{1'b0}} : rf[raddr1];
    assign rdata2 = (raddr2 == 5'd0) ? {WIDTH{1'b0}} : rf[raddr2];

    // ---- 同步写 + 同步复位 ----
    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 1; i < 32; i = i + 1) rf[i] <= {WIDTH{1'b0}};
        end else if (we && (waddr != 5'd0)) begin
            rf[waddr] <= wdata;   // 写 x0 自动丢弃
        end
    end

endmodule
