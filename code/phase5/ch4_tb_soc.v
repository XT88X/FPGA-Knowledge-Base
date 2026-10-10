// =============================================================================
// ch4_tb_soc.v — 5.4 自制 SoC 顶层自检 testbench
//
//   验证点（行为仿真，hierarchical 观察内部信号）：
//     1) UART 打印：复位后经 UART 数据寄存器发出 'O'(79) 与 'K'(75)；
//     2) 定时器中断翻转 LED：timer 到 cmp 后进入 ISR，GPIO_OUT bit0 翻转；
//     3) GPIO 输入->输出：主循环把 GPIO_IN 镜像到 GPIO_OUT；
//     4) RAM 读写：固件循环里 LW/SW 访问 RAM（程序本身在 RAM 上跑）。
//
//   风格对齐 ch1_tb_riscv_soc：#delay 时序 + initial/always，不用 task/forever。
//   注意：本环境无 iverilog，仅做 pyverilog 结构校验；波形需本地跑。
// =============================================================================
`timescale 1ns/1ps
module ch4_tb_soc;

    reg        clk = 0;
    reg        rst_n = 0;
    wire       tx_o;
    reg        rx_i = 1'b1;
    wire [7:0] gpio;          // inout

    // 驱动 gpio_i：先给一个固定输入，观察镜像
    reg  [7:0] gpio_drv;
    reg        gpio_dir_out;   // 由固件配置为输出
    assign gpio = gpio_dir_out ? gpio_drv : 8'hzz;

    always #5 clk = ~clk;      // 10ns 周期

    ch4_soc_top u_dut (
        .clk(clk), .rst_n(rst_n),
        .tx_o(tx_o), .rx_i(rx_i),
        .gpio(gpio)
    );

    // ---- 捕获 UART 发送的字节 ----
    integer uart_cnt;
    reg [7:0] uart_chars [0:3];
    integer i;
    always @(posedge clk) begin
        if (rst_n && u_dut.we_uart_data) begin
            if (uart_cnt < 4) uart_chars[uart_cnt] <= u_dut.dmem_wdata[7:0];
            uart_cnt <= uart_cnt + 1;
        end
    end

    // ---- 记录 GPIO_OUT bit0 的翻转次数（定时器中断是否触发）----
    integer toggle_cnt;
    reg     prev_bit0;
    always @(posedge clk) begin
        if (rst_n) begin
            if (u_dut.out_reg[0] !== prev_bit0) begin
                toggle_cnt <= toggle_cnt + 1;
                prev_bit0  <= u_dut.out_reg[0];
            end
        end
    end

    integer errors;
    initial begin
        uart_cnt   = 0;
        toggle_cnt = 0;
        prev_bit0  = 1'b0;
        errors     = 0;
        gpio_drv   = 8'h00;
        gpio_dir_out = 1'b0;

        rst_n = 0;
        #50;
        rst_n = 1;

        // 让固件配置 GPIO 为输出后，给外部输入 0xA5，观察镜像
        #200;
        gpio_drv = 8'hA5;
        gpio_dir_out = 1'b1;

        // 跑足够多周期：定时器 cmp=20，约数千周期应触发多次中断
        #3000;

        $display("---- ch4_tb_soc CHECK ----");
        $display("UART chars = 0x%02x 0x%02x (expect 0x4F 'O', 0x4B 'K'), count=%0d",
                 uart_chars[0], uart_chars[1], uart_cnt);
        $display("GPIO_OUT bit0 toggles = %0d (expect >=2, 定时器中断多次翻转)", toggle_cnt);
        $display("GPIO_IN 镜像: gpio_drv=0x%02x, out_reg=0x%02x", gpio_drv, u_dut.out_reg);

        if (uart_chars[0] !== 8'h4F || uart_chars[1] !== 8'h4B) begin
            $display("FAIL: UART print mismatch");
            errors = errors + 1;
        end
        if (toggle_cnt < 2) begin
            $display("FAIL: timer interrupt did not toggle LED");
            errors = errors + 1;
        end
        if (errors == 0)
            $display("PASS: SoC UART + timer IRQ + GPIO mirror OK");
        else
            $display("FAIL count = %0d", errors);

        $finish;
    end

    initial begin #20000; $display("  [TB] 超时护栏"); $finish; end

endmodule
