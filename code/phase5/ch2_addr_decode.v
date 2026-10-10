// =============================================================================
// ch2_addr_decode.v — 内存映射地址译码示例（组合逻辑）
//   把 32-bit 地址高位译码成各从机的片选，教学用。
//   真实 Vivado 工程里由 AXI Interconnect (PG059) 自动完成，
//   这里手写一份帮助理解"基地址 + 地址范围"是怎么切出来的。
//
//   示例映射：
//     0x0000_0000 ~ 0x0FFF_FFFF : RAM
//     0x4000_0000 ~ 0x4000_FFFF : AXI GPIO(本 ch2 外设)
//     0x8000_0000 ~ 0x8000_FFFF : UART
//     其它                       : 默认从机(返回错误)
// =============================================================================
module ch2_addr_decode #(
    parameter [31:0] RAM_BASE   = 32'h0000_0000,
    parameter [31:0] GPIO_BASE  = 32'h4000_0000,
    parameter [31:0] UART_BASE   = 32'h8000_0000
)(
    input  wire [31:0] addr,
    output reg         cs_ram,
    output reg         cs_gpio,
    output reg         cs_uart,
    output reg         cs_error
);

    // 取高位做粗译码（每块 64KB，即高 26 位相同即选中）
    wire [5:0] block = addr[31:26];

    always @(*) begin
        cs_ram   = 1'b0;
        cs_gpio  = 1'b0;
        cs_uart  = 1'b0;
        cs_error = 1'b0;
        case (block)
            RAM_BASE[31:26]   : cs_ram   = 1'b1;
            GPIO_BASE[31:26]  : cs_gpio  = 1'b1;
            UART_BASE[31:26]  : cs_uart  = 1'b1;
            default           : cs_error = 1'b1;
        endcase
    end

endmodule
