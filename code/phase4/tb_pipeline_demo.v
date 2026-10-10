//==============================================================================
// tb_pipeline_demo.v — 校验无流水线与三级流水线功能等价
//------------------------------------------------------------------------------
// 喂入一组序列，比较：
//   result_unpipe 应等于当拍的 f(a,b,c,d)；
//   result_pipe   应等于晚一拍的 f(a,b,c,d)（流水线多一拍延迟）。
//==============================================================================
`timescale 1ns/1ps
module tb_pipeline_demo;

    reg              clk;
    reg              rst_n;
    reg  [7:0]       a, b, c, d;
    wire [7:0]       result_unpipe, result_pipe;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    pipeline_demo #(.WIDTH(8)) dut (
        .clk(clk), .rst_n(rst_n),
        .a(a), .b(b), .c(c), .d(d),
        .result_unpipe(result_unpipe),
        .result_pipe(result_pipe)
    );

    integer i;
    integer errors;
    reg [7:0] expect0;   // 当拍 f
    reg [7:0] expect1;   // 延迟一拍的 f，用于对齐 result_pipe

    initial begin
        rst_n = 1'b0;
        a = 8'd0; b = 8'd0; c = 8'd1; d = 8'd0;
        errors = 0;
        expect0 = 8'd0; expect1 = 8'd0;
        #23;
        rst_n = 1'b1;
    end

    // 每拍给输入并更新期望值
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a <= 8'd0; b <= 8'd0; c <= 8'd2; d <= 8'd0;
        end else begin
            a <= a + 8'd1;
            b <= b + 8'd1;
            c <= 8'd2;
            d <= d + 8'd1;
        end
    end

    // 自检
    always @(posedge clk or negedge rst_n) begin
        if (rst_n) begin
            // 当拍期望（用当前输入）
            expect0 <= ((a + b) * c) + d;
            // 流水线晚一拍：上一拍 expect0
            expect1 <= expect0;
            // 第 4 拍起开始比较（等流水线填满）
            if (errors >= 0 && expect1 != 8'd0) begin
                if (result_unpipe !== expect0) errors <= errors + 1;
                if (result_pipe   !== expect1) errors <= errors + 1;
            end
        end
    end

    initial begin
        #300;
        $display("---- tb_pipeline_demo ----");
        $display("result_unpipe=%0d result_pipe=%0d errors=%0d",
                 result_unpipe, result_pipe, errors);
        if (errors == 0)
            $display("TB_PIPELINE: PASS (两路径功能等价)");
        else
            $display("TB_PIPELINE: FAIL");
        $finish;
    end

endmodule
