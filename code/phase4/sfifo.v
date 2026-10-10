//==============================================================================
// sfifo.v — 同步 FIFO（单时钟，推断双口 BRAM）
//------------------------------------------------------------------------------
// 特点：
//   * 读写共用一个 clk，指针用多一位(ADDR_WIDTH+1)区分空/满。
//   * 存储体用可综合数组描述，Vivado 会推断成 Block RAM（同步读）。
//   * 提供 empty / full / almost_full / 当前数据个数 count。
//   * 写满时 wr_en 无效，读空时 rd_en 无效。
//==============================================================================
module sfifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH  = 4                 // 深度 = 2^4 = 16
)(
    // 端口位宽用数字字面量（与默认参数一致：DATA_WIDTH=8, ADDR_WIDTH=4）
    input  wire                    clk,
    input  wire                    rst_n,
    // 写端口
    input  wire                    wr_en,
    input  wire [7:0]              wr_data,
    // 读端口
    input  wire                    rd_en,
    output wire [7:0]              rd_data,
    // 状态
    output wire                    empty,
    output wire                    full,
    output wire                    almost_full,
    output wire [4:0]              count   // ADDR_WIDTH+1 = 5 位
);
    localparam DEPTH = 1 << ADDR_WIDTH;

    reg [DATA_WIDTH-1:0] ram [0:DEPTH-1];   // 推断为 BRAM
    reg [ADDR_WIDTH:0]   wr_ptr;            // 多 1 位作为满标志位
    reg [ADDR_WIDTH:0]   rd_ptr;
    reg [DATA_WIDTH-1:0] rd_data_r;

    wire [ADDR_WIDTH:0] wr_next = wr_ptr + 1'b1;
    wire [ADDR_WIDTH:0] rd_next = rd_ptr + 1'b1;

    // 空：读写指针完全相等；满：低 ADDR_WIDTH 位相等且最高位相反
    assign empty       = (wr_ptr == rd_ptr);
    assign full        = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) &&
                         (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);
    assign almost_full = (count >= DEPTH - 2);
    assign count       = wr_ptr - rd_ptr;
    assign rd_data     = rd_data_r;

    // 写存储体（不复位 BRAM，便于推断）
    always @(posedge clk) begin
        if (wr_en && !full)
            ram[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
    end

    // 同步读：rd_en 有效时下一拍输出 ram[rd_ptr]
    always @(posedge clk) begin
        if (rd_en && !empty)
            rd_data_r <= ram[rd_ptr[ADDR_WIDTH-1:0]];
    end

    // 读写指针
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
        end else begin
            if (wr_en && !full) wr_ptr <= wr_next;
            if (rd_en && !empty) rd_ptr <= rd_next;
        end
    end

endmodule
