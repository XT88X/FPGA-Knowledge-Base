// =============================================================================
// ch1_riscv_soc.v — 教学型 RV32I 最小 SoC
//   组成：CPU 核心 + 统一指令/数据 RAM（von Neumann）+ 内存映射 UART 输出寄存器
//
//   内存映射（32-bit 字节地址）：
//     0x0000_0000 ~ 0x0000_0FFF : 片上统一 RAM（4KB = 1024 字）
//                                  取指与 LW/SW 都走这里；上电 $readmemh 加载固件
//     0x1000_0000               : UART 数据寄存器（写=发送一个字符；读=0）
//                                  （本处仅做"字符打印寄存器"，完整 UART 发送器在 5.4 集成）
//
//   对外：clk / rst_n；UART 字符观察口 uart_tx_data / uart_tx_valid。
//   上板时把 uart_tx_data/valid 接到阶段 3 写过的 UART 发送模块即可真正从串口出字符。
// =============================================================================
module ch1_riscv_soc #(
    parameter RAM_WORDS = 1024,                      // 4KB
    parameter [31:0] UART_BASE = 32'h1000_0000,
    parameter [31:0] RESET_VECTOR = 32'h0000_0000
)(
    input  wire        clk,
    input  wire        rst_n,

    // 简化 UART 观察口（上板接真实 UART 发送器）
    output wire [7:0]  uart_tx_data,
    output wire       uart_tx_valid
);

    localparam AW = 12;   // 字节地址线 12bit -> 4KB

    // ---- CPU 与存储器之间的连线 ----
    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire        dmem_we;
    wire [31:0] dmem_rdata;

    // ---- 片上统一 RAM（组合读 / 同步写）----
    reg [31:0] ram [0:RAM_WORDS-1];

    initial begin
        // 上电加载固件（仿真 & Vivado ROM 初始化均支持）
        $readmemh("ch1_firmware.hex", ram);
    end

    // 取指：组合读
    assign imem_rdata = ram[imem_addr[AW-1:2]];

    // 数据口地址译码
    wire ram_sel   = (dmem_addr[31:AW] == 10'h000);        // 0x0000_0xxx 区间
    wire uart_sel  = (dmem_addr[31:0] == UART_BASE);

    wire [31:0] ram_rdata = ram[dmem_addr[AW-1:2]];

    // 同步写 RAM
    always @(posedge clk) begin
        if (dmem_we && ram_sel)
            ram[dmem_addr[AW-1:2]] <= dmem_wdata;
    end

    // ---- UART 输出寄存器（写触发一拍 valid）----
    reg [7:0] uart_data_r;
    reg       uart_valid_r;

    always @(posedge clk) begin
        if (!rst_n) begin
            uart_data_r  <= 8'h00;
            uart_valid_r <= 1'b0;
        end else if (dmem_we && uart_sel) begin
            uart_data_r  <= dmem_wdata[7:0];   // 只取低 8 位作为字符
            uart_valid_r <= 1'b1;
        end else begin
            uart_valid_r <= 1'b0;
        end
    end

    assign uart_tx_data  = uart_data_r;
    assign uart_tx_valid = uart_valid_r;

    // ---- 数据读回译码：RAM 或 UART（UART 读返回 0）----
    assign dmem_rdata = ram_sel ? ram_rdata : 32'h0000_0000;

    // ---- CPU 核心例化 ----
    ch1_riscv_core #(
        .WIDTH(32),
        .RESET_VECTOR(RESET_VECTOR)
    ) u_core (
        .clk        (clk),
        .rst_n      (rst_n),
        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_we    (dmem_we),
        .dmem_rdata (dmem_rdata),
        .dbg_pc     (),
        .dbg_instr  ()
    );

endmodule
