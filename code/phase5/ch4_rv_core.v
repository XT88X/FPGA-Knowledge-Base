// =============================================================================
// ch4_rv_core.v — 教学型单周期 RV32I 核心（5.4 自制 SoC 自用自包含版）
//
//   与 5.1 同级的基础指令子集（可替换为 5.1 完整核）：
//     LUI/AUIPC
//     ADDI/ANDI/ORI/XORI/SLTI/SLTIU
//     ADD/SUB/AND/OR/XOR/SLT/SLTU
//     LW/SW（按字）
//     BEQ/BNE/JAL/JALR
//
//   教学简化中断（非完整特权架构）：
//     * irq_i 为高且 mie=1 时，下一拍取指跳转到 TRAP_VEC=0x100；
//     * 被打断指令的"返回地址 pc+4"写入 x5(t0)；
//     * ISR 末尾用 `JALR x0, x5, 0`（= jr x5）返回。
//     * 无 Cause CSR、无栈切换、无 mstatus——只为讲清"中断=跳转到 ISR 再回来"。
//
//   同步低电平复位 rst_n；组合取指/访存读，时钟沿写回。
// =============================================================================
module ch4_rv_core #(
    parameter [31:0] RESET_VECTOR = 32'h0000_0000,
    parameter [31:0] TRAP_VEC     = 32'h0000_0100
)(
    input  wire         clk,
    input  wire         rst_n,

    // 指令口（组合读）
    output wire [31:0]  imem_addr,
    input  wire [31:0]  imem_rdata,

    // 数据口（组合读 / 同步写）
    output wire [31:0]  dmem_addr,
    output wire [31:0]  dmem_wdata,
    output wire         dmem_we,
    input  wire [31:0]  dmem_rdata,

    // 中断输入（来自中断汇总）
    input  wire         irq_i,
    input  wire         mie,          // 全局中断使能（SoC INTE[0] 提供）

    output wire [31:0]  dbg_pc
);

    // ---- 指令字段 ----
    wire [6:0]  opcode = imem_rdata[6:0];
    wire [4:0]  rd     = imem_rdata[11:7];
    wire [2:0]  funct3 = imem_rdata[14:12];
    wire [4:0]  rs1    = imem_rdata[19:15];
    wire [4:0]  rs2    = imem_rdata[24:20];
    wire [6:0]  funct7 = imem_rdata[31:25];

    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_OPIMM  = 7'b0010011;
    localparam OP_OP     = 7'b0110011;

    // ---- 寄存器堆（32x32，x0 恒零）----
    reg [31:0] rf [0:31];
    integer ri;
    initial for (ri = 0; ri < 32; ri = ri + 1) rf[ri] = 32'd0;
    wire [31:0] rs1_data = (rs1 == 5'd0) ? 32'd0 : rf[rs1];
    wire [31:0] rs2_data = (rs2 == 5'd0) ? 32'd0 : rf[rs2];

    // ---- 立即数 ----
    wire [31:0] imm_i = {{20{imem_rdata[31]}}, imem_rdata[31:20]};
    wire [31:0] imm_s = {{20{imem_rdata[31]}}, imem_rdata[31:25], imem_rdata[11:7]};
    wire [31:0] imm_b = {{19{imem_rdata[31]}}, imem_rdata[31], imem_rdata[7],
                         imem_rdata[30:25], imem_rdata[11:8], 1'b0};
    wire [31:0] imm_u = {imem_rdata[31:12], 12'b0};
    wire [31:0] imm_j = {{11{imem_rdata[31]}}, imem_rdata[31], imem_rdata[19:12],
                         imem_rdata[20], imem_rdata[30:21], 1'b0};

    // ---- PC ----
    reg [31:0] pc;
    assign imem_addr = pc;
    assign dbg_pc    = pc;

    // ---- ALU ----
    reg  [31:0] alu_b;
    reg  [3:0]  alu_op;
    localparam A_ADD=0, A_SUB=1, A_AND=2, A_OR=3, A_XOR=4, A_SLT=5, A_SLTU=6;
    reg  [31:0] alu_y;
    always @(*) begin
        case (alu_op)
            A_ADD:  alu_y = alu_a + alu_b;
            A_SUB:  alu_y = alu_a - alu_b;
            A_AND:  alu_y = alu_a & alu_b;
            A_OR:   alu_y = alu_a | alu_b;
            A_XOR:  alu_y = alu_a ^ alu_b;
            A_SLT:  alu_y = ($signed(alu_a) < $signed(alu_b)) ? 32'd1 : 32'd0;
            A_SLTU: alu_y = (alu_a < alu_b) ? 32'd1 : 32'd0;
            default:alu_y = 32'd0;
        endcase
    end
    reg [31:0] alu_a;

    // ALU 第二操作数选择
    always @(*) begin
        if (opcode == OP_OP) alu_b = rs2_data;
        else                 alu_b = imm_i;
    end
    always @(*) alu_a = rs1_data;

    // ALU 操作
    always @(*) begin
        case (opcode)
            OP_LUI, OP_AUIPC, OP_JAL, OP_JALR: alu_op = A_ADD;
            OP_LOAD, OP_STORE:                 alu_op = A_ADD;
            OP_OP: begin
                case (funct3)
                    3'b000: alu_op = funct7[5] ? A_SUB : A_ADD;
                    3'b111: alu_op = A_AND;
                    3'b110: alu_op = A_OR;
                    3'b100: alu_op = A_XOR;
                    3'b010: alu_op = A_SLT;
                    3'b011: alu_op = A_SLTU;
                    default: alu_op = A_ADD;
                endcase
            end
            OP_OPIMM: begin
                case (funct3)
                    3'b000: alu_op = A_ADD;
                    3'b111: alu_op = A_AND;
                    3'b110: alu_op = A_OR;
                    3'b100: alu_op = A_XOR;
                    3'b010: alu_op = A_SLT;
                    3'b011: alu_op = A_SLTU;
                    default: alu_op = A_ADD;
                endcase
            end
            default: alu_op = A_ADD;
        endcase
    end

    // ---- 分支判定 ----
    reg branch_taken;
    always @(*) begin
        branch_taken = 1'b0;
        if (opcode == OP_BRANCH) begin
            case (funct3)
                3'b000: branch_taken = (rs1_data == rs2_data);
                3'b001: branch_taken = (rs1_data != rs2_data);
                default: branch_taken = 1'b0;
            endcase
        end
    end

    // ---- 写回数据 ----
    reg [31:0] wb_data;
    always @(*) begin
        case (opcode)
            OP_LOAD:  wb_data = dmem_rdata;
            OP_LUI:   wb_data = imm_u;
            OP_AUIPC: wb_data = pc + imm_u;
            OP_JAL,
            OP_JALR:  wb_data = pc + 4;
            default:  wb_data = alu_y;
        endcase
    end
    wire rf_we = (opcode != OP_STORE) && (opcode != OP_BRANCH);

    // ---- 数据口 ----
    assign dmem_addr = alu_y;
    assign dmem_wdata = rs2_data;
    assign dmem_we   = (opcode == OP_STORE);

    // ---- 下一条 PC（含中断跳转）----
    reg [31:0] next_pc;
    always @(*) begin
        // 默认按指令流
        case (opcode)
            OP_JAL:    next_pc = pc + imm_j;
            OP_JALR:   next_pc = (rs1_data + imm_i) & ~32'h1;
            OP_BRANCH: next_pc = branch_taken ? (pc + imm_b) : (pc + 4);
            default:   next_pc = pc + 4;
        endcase
        // 中断优先：跳转到 ISR，并把返回地址写入 x5
        if (irq_i && mie) begin
            next_pc = TRAP_VEC;
        end
    end

    // ---- PC 更新 + x5 写回（中断时写返回地址）----
    always @(posedge clk) begin
        if (!rst_n) begin
            pc <= RESET_VECTOR;
        end else if (irq_i && mie) begin
            pc        <= TRAP_VEC;
            rf[5]     <= pc + 4;          // 返回地址存 x5
        end else begin
            pc <= next_pc;
            if (rf_we && rd != 5'd0)
                rf[rd] <= wb_data;
        end
    end

endmodule
