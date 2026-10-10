// =============================================================================
// ch4_soc_top.v — 5.4 自制 SoC 单片机顶层
//
//   组成：
//     ch4_rv_core  (RV32I 教学核，含简化 vectored 中断)
//     片上 RAM 4KB  (von Neumann，取指+LW/SW 共用，$readmemh 加载)
//     ch4_bus_mux  (地址译码 + 读数据 mux)
//     ch4_uart     (串口 tx/rx)
//     ch4_gpio     (方向+数据寄存器)
//     ch4_timer    (周期匹配定时器 + 中断标志)
//     中断汇总    (timer irq & INTE[0] -> core irq_i)
//
//   对外引脚：clk / rst_n / tx_o / rx_i / gpio[7:0]。
//   上电 $readmemh("ch4_firmware.hex", ram) 加载裸机程序。
//
//   地址映射见 ch4_bus_mux.v 注释与文档表格。
// =============================================================================
module ch4_soc_top #(
    parameter RAM_WORDS = 1024,                 // 4KB
    parameter [31:0] RESET_VECTOR = 32'h0000_0000,
    parameter [31:0] TRAP_VEC     = 32'h0000_0100
)(
    input  wire        clk,
    input  wire        rst_n,

    output wire        tx_o,          // UART 发送脚
    input  wire        rx_i,          // UART 接收脚

    inout  wire [7:0]  gpio          // GPIO 双向脚（教学：仿真用 gpio_i/gpio_o 观察）
);

    // ---- CPU <-> 总线 ----
    wire [31:0] imem_addr, imem_rdata;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire        dmem_we;

    // ---- 片上 RAM ----
    reg [31:0] ram [0:RAM_WORDS-1];
    initial $readmemh("ch4_firmware.hex", ram);

    localparam AW = 12;   // 字节地址线 12bit -> 4KB
    wire ram_sel = (dmem_addr[31:AW] == 20'h000);

    // 取指：组合读
    assign imem_rdata = ram[imem_addr[AW-1:2]];
    wire [31:0] ram_rdata = ram[dmem_addr[AW-1:2]];
    always @(posedge clk) begin
        if (dmem_we && ram_sel)
            ram[dmem_addr[AW-1:2]] <= dmem_wdata;
    end

    // ---- 总线译码 ----
    wire        uart_data_sel, uart_stat_sel;
    wire        gpio_dir_sel, gpio_out_sel, gpio_in_sel;
    wire        timer_ctrl_sel, timer_cmp_sel, timer_cnt_sel, timer_clr_sel;
    wire        inte_sel, intf_sel;
    wire [31:0] m_rdata;

    ch4_bus_mux u_bus (
        .addr(dmem_addr),
        .ram_rdata(ram_rdata),
        .uart_rdata(uart_rdata),
        .gpio_rdata(gpio_rdata),
        .timer_rdata(timer_rdata),
        .int_rdata(int_rdata),
        .ram_sel(ram_sel),
        .uart_data_sel(uart_data_sel),
        .uart_stat_sel(uart_stat_sel),
        .gpio_dir_sel(gpio_dir_sel),
        .gpio_out_sel(gpio_out_sel),
        .gpio_in_sel(gpio_in_sel),
        .timer_ctrl_sel(timer_ctrl_sel),
        .timer_cmp_sel(timer_cmp_sel),
        .timer_cnt_sel(timer_cnt_sel),
        .timer_clr_sel(timer_clr_sel),
        .inte_sel(inte_sel),
        .intf_sel(intf_sel),
        .m_rdata(dmem_rdata)
    );

    // 写使能（CPU 写）
    wire wr = dmem_we;
    wire we_uart_data = wr & uart_data_sel;
    wire we_uart_stat = wr & uart_stat_sel;
    wire we_gpio_dir  = wr & gpio_dir_sel;
    wire we_gpio_out  = wr & gpio_out_sel;
    wire we_timer_ctrl= wr & timer_ctrl_sel;
    wire we_timer_cmp = wr & timer_cmp_sel;
    wire we_timer_clr = wr & timer_clr_sel;
    wire we_inte      = wr & inte_sel;
    wire we_intf      = wr & intf_sel;

    // ---- UART ----
    wire        tx_ready;
    wire [7:0]  uart_dout;
    wire        rx_done;
    reg  [7:0]  rx_data_r;
    reg         rx_avail_r;

    ch4_uart #(.BAUD_DIV(434)) u_uart (
        .clk(clk), .rst_n(rst_n),
        .we(we_uart_data), .din(dmem_wdata[7:0]), .tx_ready(tx_ready),
        .tx_o(tx_o), .rx_i(rx_i),
        .dout(uart_dout), .rx_done(rx_done)
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            rx_data_r  <= 8'h00;
            rx_avail_r <= 1'b0;
        end else if (rx_done) begin
            rx_data_r  <= uart_dout;
            rx_avail_r <= 1'b1;
        end else if (we_uart_data) begin
            rx_avail_r <= 1'b0;     // 读后清
        end
    end

    // UART 读回：数据口=rx_data，状态口={tx_ready,rx_avail}
    reg [31:0] uart_rdata;
    always @(*) begin
        if (uart_data_sel) uart_rdata = {24'h0, rx_data_r};
        else               uart_rdata = {30'h0, rx_avail_r, tx_ready};
    end

    // ---- GPIO ----
    wire [7:0] gpio_o, gpio_i;
    wire [7:0] dir_reg, out_reg;
    assign gpio_i = gpio;                 // 仿真观察：外部输入脚
    assign gpio   = (dir_reg != 8'h00) ? gpio_o : 8'hzz;

    ch4_gpio #(.WIDTH(8)) u_gpio (
        .clk(clk), .rst_n(rst_n),
        .we_dir(we_gpio_dir), .we_out(we_gpio_out), .wdata(dmem_wdata),
        .gpio_i(gpio_i), .gpio_o(gpio_o),
        .dir_reg(dir_reg), .out_reg(out_reg)
    );

    // GPIO 读回：DIR 口=dir_reg，OUT 口=out_reg，IN 口=gpio_i
    reg [31:0] gpio_rdata;
    always @(*) begin
        if (gpio_dir_sel)      gpio_rdata = {24'h0, dir_reg};
        else if (gpio_out_sel) gpio_rdata = {24'h0, out_reg};
        else                   gpio_rdata = {24'h0, gpio_i};
    end

    // ---- 定时器 ----
    wire [31:0] timer_cnt;
    wire        timer_irq_flag;
    wire        timer_irq_pulse;

    ch4_timer #(.RESET_CMP(32'd50)) u_timer (
        .clk(clk), .rst_n(rst_n),
        .we_ctrl(we_timer_ctrl), .we_cmp(we_timer_cmp), .we_clr(we_timer_clr),
        .wdata(dmem_wdata),
        .cnt(timer_cnt), .irq_flag(timer_irq_flag), .irq_pulse(timer_irq_pulse)
    );

    // 定时器读回
    reg [31:0] timer_rdata;
    always @(*) begin
        if (timer_cnt_sel)       timer_rdata = timer_cnt;
        else if (timer_ctrl_sel) timer_rdata = {31'h0, 1'b1};  // 始终"已使能"镜像
        else                     timer_rdata = 32'h0;
    end

    // ---- 中断汇总 ----
    reg inte_reg;          // INTE[0]
    reg intf_reg;          // INTF[0]
    always @(posedge clk) begin
        if (!rst_n) begin
            inte_reg <= 1'b0;
            intf_reg <= 1'b0;
        end else begin
            if (we_inte) inte_reg <= dmem_wdata[0];
            // 定时器匹配置位；写 INTF(W1C) 清零
            if (timer_irq_flag) intf_reg <= 1'b1;
            if (we_intf)        intf_reg <= intf_reg & ~dmem_wdata[0];
        end
    end

    wire irq_to_core = intf_reg & inte_reg;   // 定时器中断 & 全局使能

    reg [31:0] int_rdata;
    always @(*) begin
        if (inte_sel) int_rdata = {31'h0, inte_reg};
        else          int_rdata = {31'h0, intf_reg};   // intf_sel
    end

    // ---- CPU 例化 ----
    wire [31:0] dbg_pc;
    ch4_rv_core #(
        .RESET_VECTOR(RESET_VECTOR), .TRAP_VEC(TRAP_VEC)
    ) u_core (
        .clk(clk), .rst_n(rst_n),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata),
        .dmem_we(dmem_we), .dmem_rdata(dmem_rdata),
        .irq_i(irq_to_core), .mie(inte_reg),
        .dbg_pc(dbg_pc)
    );

endmodule
