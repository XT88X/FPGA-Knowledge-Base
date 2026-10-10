//==============================================================================
// pipeline_demo.v — 无流水线 vs 三级流水线：同一条运算路径的时序对比
//------------------------------------------------------------------------------
// 计算功能：f(a,b,c,d) = ((a + b) * c) + d
//   * result_unpipe：整个 加->乘->加 组合链在一个时钟周期内完成，再寄存输出。
//                    组合路径长，建立时间紧张，高频易失败。
//   * result_pipe  ：在 加、乘、加 之间各插一级寄存器，把长路径切成三段，
//                    每级只需满足一个短路径的建立时间；代价是多一拍延迟。
// 参数化位宽 WIDTH。两者功能等价（流水线输出晚一拍），tb 校验一致性。
//==============================================================================
module pipeline_demo #(
    parameter WIDTH = 8
)(
    // 端口位宽用数字字面量（与默认参数 WIDTH=8 一致）
    input  wire              clk,
    input  wire              rst_n,
    input  wire [7:0]        a,
    input  wire [7:0]        b,
    input  wire [7:0]        c,
    input  wire [7:0]        d,
    output reg  [7:0]        result_unpipe,
    output reg  [7:0]        result_pipe
);

    // ---- 无流水线：长组合链，单周期完成 ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            result_unpipe <= {WIDTH{1'b0}};
        else
            result_unpipe <= ((a + b) * c) + d;
    end

    // ---- 三级流水线：逐级打拍，同时把 c/d 顺延对齐 ----
    reg [WIDTH-1:0] s1;     // 第一级：a+b
    reg [WIDTH-1:0] c_r1;    // c 延迟一拍对齐
    reg [WIDTH-1:0] s2;     // 第二级：s1 * c
    reg [WIDTH-1:0] d_r1;   // d 延迟两拍对齐到最后一级
    reg [WIDTH-1:0] d_r2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1    <= {WIDTH{1'b0}};
            c_r1  <= {WIDTH{1'b0}};
            s2    <= {WIDTH{1'b0}};
            d_r1  <= {WIDTH{1'b0}};
            d_r2  <= {WIDTH{1'b0}};
            result_pipe <= {WIDTH{1'b0}};
        end else begin
            s1    <= a + b;
            c_r1  <= c;
            s2    <= s1 * c_r1;
            d_r1  <= d;
            d_r2  <= d_r1;
            result_pipe <= s2 + d_r2;
        end
    end

endmodule
