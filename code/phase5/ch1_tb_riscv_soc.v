// =============================================================================
// ch1_tb_riscv_soc.v — RV32I 最小 SoC 测试平台
//   做法：例化 ch1_riscv_soc，给 50MHz 时钟与同步复位；
//         监视 UART 打印口，统计打印字符；运行足够周期后断言：
//           1) RAM[0] == 0x0000_0037（1..10 求和 = 55）
//           2) UART 恰好打印两个字符 '5'(0x35)
//   机器码由 ch1_riscv_soc 内 $readmemh("ch1_firmware.hex") 加载。
// =============================================================================
`timescale 1ns/1ps
module ch1_tb_riscv_soc;

    reg         clk;
    reg         rst_n;
    wire [7:0]  uart_tx_data;
    wire        uart_tx_valid;

    // 例化 DUT
    ch1_riscv_soc u_dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .uart_tx_data (uart_tx_data),
        .uart_tx_valid(uart_tx_valid)
    );

    // 50MHz 时钟：周期 20ns
    initial clk = 1'b0;
    always #10 clk = ~clk;

    // 统计 UART 打印
    integer uart_count;
    reg [7:0] uart_chars [0:3];
    integer i;

    initial begin
        uart_count = 0;
        for (i = 0; i < 4; i = i + 1) uart_chars[i] = 8'h00;
    end

    always @(posedge clk) begin
        if (uart_tx_valid && rst_n) begin
            if (uart_count < 4) uart_chars[uart_count] = uart_tx_data;
            uart_count = uart_count + 1;
            $display("[UART] print char = 0x%02x ('%c')", uart_tx_data, uart_tx_data);
        end
    end

    // 主流程
    reg [31:0] expected_sum;
    initial begin
        expected_sum = 32'h0000_0037;

        // 复位
        rst_n = 1'b0;
        clk   = 1'b0;
        #50;
        rst_n = 1'b1;

        // 跑足够多周期：循环约 10 次，每轮 4~5 拍 + 收尾
        #2000;

        // ---- 断言 ----
        $display("---- TB CHECK ----");
        $display("RAM[0] = 0x%08x (expect 0x00000037)", u_dut.ram[0]);
        $display("UART chars = 0x%02x 0x%02x (expect 0x35 0x35), count=%0d",
                 uart_chars[0], uart_chars[1], uart_count);

        if (u_dut.ram[0] !== expected_sum)
            $display("FAIL: RAM[0] sum mismatch");
        else if (uart_count !== 2)
            $display("FAIL: UART print count mismatch");
        else if (uart_chars[0] !== 8'h35 || uart_chars[1] !== 8'h35)
            $display("FAIL: UART char mismatch");
        else
            $display("PASS: RV32I core sum & UART print OK");

        $finish;
    end

endmodule
