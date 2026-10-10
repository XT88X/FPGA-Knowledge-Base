// =============================================================================
// ch3_tb_vec_mac.v — ch3_vec_mac_accel 的自检 testbench
//   验证点：非整除长度(N=10)、软件 golden 比对、背压、流水线排空+累加器清零。
//   风格对齐 ch1_tb_riscv_soc：仅用 #delay 时序与 initial/always。
// =============================================================================
`timescale 1ns/1ps
module ch3_tb_vec_mac;

    reg         clk = 0;
    reg         rst_n = 0;
    reg         s_valid = 0;
    wire        s_ready;
    reg  [63:0] s_a = 0;
    reg  [63:0] s_b = 0;
    reg  [3:0]  s_keep = 4'b1111;
    reg         s_last = 0;
    wire        m_valid;
    reg         m_ready = 0;
    wire [31:0] m_data;

    always #5 clk = ~clk;   // 10ns 周期

    ch3_vec_mac_accel #(.LANES(4), .DATA_W(16), .ACC_W(32)) dut (
        .clk(clk), .rst_n(rst_n),
        .s_valid(s_valid), .s_ready(s_ready), .s_a(s_a), .s_b(s_b),
        .s_keep(s_keep), .s_last(s_last),
        .m_valid(m_valid), .m_ready(m_ready), .m_data(m_data)
    );

    integer errors = 0;
    integer golden;
    integer i;

    // 结果收集
    integer got_cnt;
    reg [31:0] got [0:1];
    always @(posedge clk) begin
        if (rst_n && m_valid && m_ready) begin
            if (got_cnt < 2) got[got_cnt] <= m_data;
            got_cnt <= got_cnt + 1;
        end
    end

    initial begin
        golden = 0;
        for (i = 1; i <= 10; i = i + 1) golden = golden + i * (i + 1);  // =440

        got_cnt = 0;
        rst_n = 0;
        #40;
        rst_n = 1;
        #10;

        // ---- 向量 0：N=10 ----
        // beat0: a=1,2,3,4 b=2,3,4,5
        s_a={16'd4,16'd3,16'd2,16'd1}; s_b={16'd5,16'd4,16'd3,16'd2};
        s_keep=4'b1111; s_last=1'b0; s_valid=1'b1; #10;
        // beat1: a=5,6,7,8 b=6,7,8,9
        s_a={16'd8,16'd7,16'd6,16'd5}; s_b={16'd9,16'd8,16'd7,16'd6};
        s_keep=4'b1111; s_last=1'b0; #10;
        // beat2: 仅 2 有效 a=9,10 b=10,11，last
        s_a={16'd0,16'd0,16'd10,16'd9}; s_b={16'd0,16'd0,16'd11,16'd10};
        s_keep=4'b0011; s_last=1'b1; #10;
        s_valid=1'b0; s_last=1'b0;

        // 流水线排空约 6 拍后结果有效；先背压再接收
        #60;   // 等 m_valid 拉起
        m_ready = 1'b0;
        #30;   // 背压 3 拍
        if (m_valid !== 1'b1) begin $display("  [TB] 背压失败：m_ready=0 时 m_valid 被撤销"); errors=errors+1; end
        m_ready = 1'b1;
        #10;
        if (m_data !== 32'd440) begin $display("  [TB] 向量0 错误 got %0d expect 440", m_data); errors=errors+1; end
        else $display("  [TB] 向量0 正确 %0d", m_data);
        m_ready = 1'b0;

        // ---- 向量 1：N=2，验证累加器清零 ----
        #20;
        s_a={16'd0,16'd0,16'd4,16'd3}; s_b={16'd0,16'd0,16'd4,16'd3};
        s_keep=4'b0011; s_last=1'b1; s_valid=1'b1; #10;
        s_valid=1'b0; s_last=1'b0;
        #60;
        m_ready = 1'b1;
        #10;
        if (m_data !== 32'd25) begin $display("  [TB] 向量1 错误 got %0d expect 25", m_data); errors=errors+1; end
        else $display("  [TB] 向量1 正确 %0d", m_data);
        m_ready = 1'b0;

        #100;
        if (errors == 0) $display("=== ch3_vec_mac_accel TB: PASS ===");
        else $display("=== ch3_vec_mac_accel TB: FAIL (%0d) ===", errors);
        $finish;
    end

    initial begin #20000; $display("  [TB] 超时护栏"); $finish; end

endmodule
