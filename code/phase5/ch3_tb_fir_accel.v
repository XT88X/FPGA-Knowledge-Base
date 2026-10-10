// =============================================================================
// ch3_tb_fir_accel.v — ch3_fir_accel 的自检 testbench
//   系数全 1（4 点滑动平均）：y[n]=x[n]+x[n-1]+x[n-2]+x[n-3]，x[<0]=0
//   输入 x=1..6 -> 期望输出（延迟 3 拍后）：1,3,6,10,14,18
//   风格对齐 ch1_tb_riscv_soc：仅用 #delay 时序与 initial/always。
// =============================================================================
`timescale 1ns/1ps
module ch3_tb_fir_accel;

    reg         clk = 0;
    reg         rst_n = 0;
    reg         s_valid = 0;
    wire        s_ready;
    reg  [15:0] s_x = 0;
    wire        m_valid;
    wire [31:0] m_y;

    always #5 clk = ~clk;

    ch3_fir_accel #(.TAPS(4)) dut (
        .clk(clk), .rst_n(rst_n),
        .s_valid(s_valid), .s_ready(s_ready), .s_x(s_x),
        .m_valid(m_valid), .m_y(m_y)
    );

    integer errors = 0;
    integer out_cnt;
    reg signed [31:0] exp;
    reg signed [31:0] exp_tab [0:5];

    initial begin
        exp_tab[0]=1; exp_tab[1]=3; exp_tab[2]=6;
        exp_tab[3]=10; exp_tab[4]=14; exp_tab[5]=18;
    end

    // 后台：每个 m_valid 输出与期望比对
    always @(posedge clk) begin
        if (rst_n && m_valid) begin
            if (out_cnt < 6) begin
                exp = exp_tab[out_cnt];
                if (m_y !== exp) begin
                    $display("  [TB] FIR 输出错误 #%0d: got %0d expect %0d", out_cnt, m_y, exp);
                    errors = errors + 1;
                end else begin
                    $display("  [TB] FIR 输出正确 #%0d: %0d", out_cnt, m_y);
                end
            end
            out_cnt = out_cnt + 1;
        end
    end

    integer n;
    initial begin
        out_cnt = 0;
        errors = 0;
        rst_n = 0;
        #40;
        rst_n = 1;
        #10;

        // 喂入 6 个采样点 x=1..6，每拍一个
        for (n = 0; n < 6; n = n + 1) begin
            s_valid = 1'b1;
            s_x     = n + 1;
            #10;
        end
        s_valid = 1'b0;

        // 等流水线排空
        #120;

        if (out_cnt !== 6) begin
            $display("  [TB] FIR 输出个数异常 got %0d expect 6", out_cnt);
            errors = errors + 1;
        end
        if (errors == 0) $display("=== ch3_fir_accel TB: PASS ===");
        else $display("=== ch3_fir_accel TB: FAIL (%0d) ===", errors);
        $finish;
    end

    initial begin #8000; $display("  [TB] 超时护栏"); $finish; end

endmodule
