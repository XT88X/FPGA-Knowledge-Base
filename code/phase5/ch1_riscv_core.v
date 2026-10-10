// =============================================================================
// ch1_riscv_core.v — 教学型单周期 RV32I 处理器核心
//   数据通路：PC -> 取指 -> 译码(立即数/寄存器) -> 执行(ALU) -> 访存 -> 写回
//   本核把五级流水线"压平"成一个时钟一拍完成（单周期），便于教学理解；
//   上板可综合（组合取指/访存读 + 时钟沿写回）。
//
//   支持指令（RV32I 子集，教学够用）：
//     LUI, AUIPC
//     ADDI, ANDI, ORI, XORI, SLTI, SLTIU      （I 型立即数运算）
//     ADD, SUB, AND, OR, XOR, SLT, SLTU       （R 型寄存器运算）
//     LW                                       （加载字）
//     SW                                       （存字）
//     BEQ, BNE                                 （分支）
//     JAL, JALR                                （跳转）
//
//   与存储器解耦：本核只暴露"指令读口"和"数据读写口"，由 SoC 拼接 RAM/外设。
// =============================================================================
module ch1_riscv_core #(
    parameter WIDTH = 32,
    parameter [WIDTH-1:0] RESET_VECTOR = 32'h0000_0000
)(
    input  wire               clk,
    input  wire               rst_n,        // 同步低电平复位

    // ---- 指令口（组合读：本拍给地址，本拍拿到指令）----
    output wire [WIDTH-1:0]   imem_addr,
    input  wire [WIDTH-1:0]   imem_rdata,

    // ---- 数据口（组合读 / 时钟沿写）----
    output wire [WIDTH-1:0]   dmem_addr,
    output wire [WIDTH-1:0]   dmem_wdata,
    output wire               dmem_we,
    input  wire [WIDTH-1:0]   dmem_rdata,

    // ---- 调试观察口 ----
    output wire [WIDTH-1:0]   dbg_pc,
    output wire [WIDTH-1:0]   dbg_instr
);

    // ---- 指令字段拆分 ----
    wire [6:0]  opcode = imem_rdata[6:0];
    wire [4:0]  rd     = imem_rdata[11:7];
    wire [2:0]  funct3 = imem_rdata[14:12];
    wire [4:0]  rs1    = imem_rdata[19:15];
    wire [4:0]  rs2    = imem_rdata[24:20];
    wire [6:0]  funct7 = imem_rdata[31:25];

    // ---- 操作码（opcode[6:0]）----
    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_OPIMM  = 7'b0010011;
    localparam OP_OP     = 7'b0110011;

    // ---- ALU 操作编码 ----
    localparam ALU_ADD  = 4'd0;
    localparam ALU_SUB  = 4'd1;
    localparam ALU_AND   = 4'd2;
    localparam ALU_OR    = 4'd3;
    localparam ALU_XOR   = 4'd4;
    localparam ALU_SLT   = 4'd5;
    localparam ALU_SLTU  = 4'd6;

    // ---- 立即数生成（按指令格式）----
    wire [WIDTH-1:0] imm_i = {{20{imem_rdata[31]}}, imem_rdata[31:20]};
    wire [WIDTH-1:0] imm_s = {{20{imem_rdata[31]}}, imem_rdata[31:25], imem_rdata[11:7]};
    wire [WIDTH-1:0] imm_b = {{19{imem_rdata[31]}}, imem_rdata[31], imem_rdata[7],
                               imem_rdata[30:25], imem_rdata[11:8], 1'b0};
    wire [WIDTH-1:0] imm_u = {imem_rdata[31:12], 12'b0};
    wire [WIDTH-1:0] imm_j = {{11{imem_rdata[31]}}, imem_rdata[31], imem_rdata[19:12],
                               imem_rdata[20], imem_rdata[30:21], 1'b0};

    // ---- PC 寄存器 ----
    reg [WIDTH-1:0] pc;
    assign imem_addr = pc;
    assign dbg_pc    = pc;
    assign dbg_instr = imem_rdata;

    // ---- 寄存器堆例化 ----
    wire [WIDTH-1:0] rs1_data, rs2_data;
    wire             rf_we;
    wire [WIDTH-1:0] rf_wdata;

    ch1_riscv_regfile u_regfile (
        .clk     (clk),
        .rst_n   (rst_n),
        .raddr1  (rs1),
        .rdata1  (rs1_data),
        .raddr2  (rs2),
        .rdata2  (rs2_data),
        .we      (rf_we),
        .waddr   (rd),
        .wdata   (rf_wdata)
    );

    // ---- ALU 例化 ----
    reg  [3:0]        alu_op;
    reg  [WIDTH-1:0]  alu_b;       // ALU 第二操作数：rs2 或立即数
    wire [WIDTH-1:0]  alu_y;
    wire              alu_zero;

    ch1_riscv_alu u_alu (
        .a    (rs1_data),
        .b    (alu_b),
        .alu_op (alu_op),
        .y    (alu_y),
        .zero (alu_zero)
    );

    // ---- 控制器：根据 opcode/funct3 选通数据通路 ----
    reg  [WIDTH-1:0] next_pc;
    reg             branch_taken;

    // ALU 第二操作数：R 型用 rs2，其余（立即数/加载/存储）用立即数
    always @(*) begin
        if (opcode == OP_OP)
            alu_b = rs2_data;
        else
            alu_b = imm_i;   // I 型运算 / LW / JALR 都用 imm_i
    end

    // ALU 操作选择
    always @(*) begin
        case (opcode)
            OP_LUI, OP_AUIPC, OP_JAL, OP_JALR:
                alu_op = ALU_ADD;                 // 仅做加法
            OP_LOAD, OP_STORE:
                alu_op = ALU_ADD;                 // 地址 = rs1 + imm
            OP_OP: begin                          // R 型
                case (funct3)
                    3'b000: alu_op = (funct7[5]) ? ALU_SUB : ALU_ADD;
                    3'b111: alu_op = ALU_AND;
                    3'b110: alu_op = ALU_OR;
                    3'b100: alu_op = ALU_XOR;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    default: alu_op = ALU_ADD;
                endcase
            end
            OP_OPIMM: begin                       // I 型立即数运算
                case (funct3)
                    3'b000: alu_op = ALU_ADD;     // ADDI
                    3'b111: alu_op = ALU_AND;     // ANDI
                    3'b110: alu_op = ALU_OR;      // ORI
                    3'b100: alu_op = ALU_XOR;     // XORI
                    3'b010: alu_op = ALU_SLT;     // SLTI
                    3'b011: alu_op = ALU_SLTU;    // SLTIU
                    default: alu_op = ALU_ADD;
                endcase
            end
            default: alu_op = ALU_ADD;
        endcase
    end

    // ---- 分支判定：BEQ/BNE ----
    always @(*) begin
        branch_taken = 1'b0;
        if (opcode == OP_BRANCH) begin
            case (funct3)
                3'b000: branch_taken = (rs1_data == rs2_data);      // BEQ
                3'b001: branch_taken = (rs1_data != rs2_data);      // BNE
                default: branch_taken = 1'b0;
            endcase
        end
    end

    // ---- 下一条 PC ----
    always @(*) begin
        case (opcode)
            OP_JAL:            next_pc = pc + imm_j;
            OP_JALR:           next_pc = (rs1_data + imm_i) & ~32'h1;
            OP_BRANCH:         next_pc = branch_taken ? (pc + imm_b) : (pc + 4);
            default:           next_pc = pc + 4;
        endcase
    end

    // ---- 存储器写 ----
    assign dmem_addr = alu_y;                 // LW/SW 有效地址
    assign dmem_wdata = rs2_data;
    assign dmem_we   = (opcode == OP_STORE);

    // ---- 写回寄存器堆 ----
    //   写回来源：LW->dmem_rdata；LUI->imm_u；AUIPC->pc+imm_u；
    //             JAL/JALR->pc+4；其余->alu_y
    reg [WIDTH-1:0] wb_data;
    always @(*) begin
        case (opcode)
            OP_LOAD:   wb_data = dmem_rdata;
            OP_LUI:    wb_data = imm_u;
            OP_AUIPC:  wb_data = pc + imm_u;
            OP_JAL,
            OP_JALR:   wb_data = pc + 4;
            default:   wb_data = alu_y;
        endcase
    end

    // 除 STORE/BRANCH 外都写回 rd
    assign rf_we   = (opcode != OP_STORE) && (opcode != OP_BRANCH);
    assign rf_wdata = wb_data;

    // ---- PC 更新（同步复位 + 同步更新）----
    always @(posedge clk) begin
        if (!rst_n)
            pc <= RESET_VECTOR;
        else
            pc <= next_pc;
    end

endmodule
