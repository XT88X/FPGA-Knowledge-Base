// =============================================================================
// ch4_bus_mux.v — 轻量地址译码 + 读数据多路选择（教学总线互联）
//
//   CPU 数据口(dmem)进来，按地址片选各外设，并把被读外设的数据拼成一路。
//   地址映射（字节地址，32-bit）：
//     0x0000_0000 ~ 0x0000_0FFF  片上 RAM（4KB）
//     0x2000_0000                UART 数据（W=发字节 / R=收字节）
//     0x2000_0004                UART 状态（bit0 tx_ready, bit1 rx_avail）
//     0x2000_0010                GPIO_DIR
//     0x2000_0014                GPIO_OUT
//     0x2000_0018                GPIO_IN
//     0x2000_0020                TIMER_CTRL
//     0x2000_0024                TIMER_CMP
//     0x2000_0028                TIMER_CNT
//     0x2000_002C                TIMER_CLR
//     0x2000_0030                INTE（中断使能，bit0=timer）
//     0x2000_0034                INTF（中断标志，bit0=timer，W1C）
// =============================================================================
module ch4_bus_mux #(
    parameter [31:0] PERI_BASE = 32'h2000_0000
)(
    input  wire [31:0] addr,

    // 各外设读回数据
    input  wire [31:0] ram_rdata,
    input  wire [31:0] uart_rdata,
    input  wire [31:0] gpio_rdata,
    input  wire [31:0] timer_rdata,
    input  wire [31:0] int_rdata,

    // 片选输出（高有效）
    output wire        ram_sel,
    output wire        uart_data_sel,
    output wire        uart_stat_sel,
    output wire        gpio_dir_sel,
    output wire        gpio_out_sel,
    output wire        gpio_in_sel,
    output wire        timer_ctrl_sel,
    output wire        timer_cmp_sel,
    output wire        timer_cnt_sel,
    output wire        timer_clr_sel,
    output wire        inte_sel,
    output wire        intf_sel,

    // 合并后的读数据
    output reg  [31:0] m_rdata
);

    wire is_ram = (addr[31:12] == 20'h00000);           // 0x0000_0xxx
    wire is_peri= (addr[31:8]  == PERI_BASE[31:8]);     // 0x2000_00xx

    assign ram_sel        = is_ram;
    assign uart_data_sel  = is_peri & (addr[7:0] == 8'h00);
    assign uart_stat_sel  = is_peri & (addr[7:0] == 8'h04);
    assign gpio_dir_sel   = is_peri & (addr[7:0] == 8'h10);
    assign gpio_out_sel   = is_peri & (addr[7:0] == 8'h14);
    assign gpio_in_sel    = is_peri & (addr[7:0] == 8'h18);
    assign timer_ctrl_sel  = is_peri & (addr[7:0] == 8'h20);
    assign timer_cmp_sel  = is_peri & (addr[7:0] == 8'h24);
    assign timer_cnt_sel  = is_peri & (addr[7:0] == 8'h28);
    assign timer_clr_sel  = is_peri & (addr[7:0] == 8'h2C);
    assign inte_sel       = is_peri & (addr[7:0] == 8'h30);
    assign intf_sel       = is_peri & (addr[7:0] == 8'h34);

    always @(*) begin
        case (1'b1)
            ram_sel:        m_rdata = ram_rdata;
            uart_data_sel,
            uart_stat_sel:  m_rdata = uart_rdata;
            gpio_dir_sel,
            gpio_out_sel,
            gpio_in_sel:    m_rdata = gpio_rdata;
            timer_ctrl_sel,
            timer_cmp_sel,
            timer_cnt_sel,
            timer_clr_sel:  m_rdata = timer_rdata;
            inte_sel,
            intf_sel:       m_rdata = int_rdata;
            default:        m_rdata = 32'h0000_0000;
        endcase
    end

endmodule
