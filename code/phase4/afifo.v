//==============================================================================
// afifo.v — 异步 FIFO（双时钟，跨时钟域传数据）
//------------------------------------------------------------------------------
// 原理（经典 Gray-code 异步 FIFO）：
//   * 存储体：真正双口 RAM，写在 wr_clk、读在 rd_clk。
//   * 指针：二进制指针 + 格雷码指针；格雷码每次只变 1 位，跨域采样不会采到"跳变中间态"。
//   * 跨域：把写指针格雷码打两拍到读时钟域做 empty；把读指针格雷码打两拍到写时钟域做 full。
//   * 空：读域当前格雷码 == 同步过来的写格雷码。
//   * 满：写指针的"下一个格雷码" == 同步过来的读格雷码（最高两位取反）。
//==============================================================================
module afifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH  = 4                 // 深度 = 2^4 = 16
)(
    // 写时钟域（位宽与默认参数一致 DATA_WIDTH=8）
    input  wire                    wr_clk,
    input  wire                    wr_rst_n,
    input  wire                    wr_en,
    input  wire [7:0]              wr_data,
    output wire                    wr_full,
    // 读时钟域
    input  wire                    rd_clk,
    input  wire                    rd_rst_n,
    input  wire                    rd_en,
    output wire [7:0]              rd_data,
    output wire                    rd_empty
);
    localparam DEPTH = 1 << ADDR_WIDTH;

    reg [DATA_WIDTH-1:0] ram [0:DEPTH-1];

    // ---- 写域指针 ----
    reg  [ADDR_WIDTH:0] wr_ptr_bin;
    reg  [ADDR_WIDTH:0] wr_ptr_gray;
    wire [ADDR_WIDTH:0] wr_bin_next  = wr_ptr_bin + 1'b1;
    wire [ADDR_WIDTH:0] wr_gray_next = wr_bin_next ^ (wr_bin_next >> 1);

    // ---- 读域指针 ----
    reg  [ADDR_WIDTH:0] rd_ptr_bin;
    reg  [ADDR_WIDTH:0] rd_ptr_gray;
    wire [ADDR_WIDTH:0] rd_bin_next  = rd_ptr_bin + 1'b1;
    wire [ADDR_WIDTH:0] rd_gray_next = rd_bin_next ^ (rd_bin_next >> 1);

    // ---- 跨域两级同步寄存器 ----
    reg [ADDR_WIDTH:0] wr2rd_gray0, wr2rd_gray1;  // 写指针格雷码 -> 读域
    reg [ADDR_WIDTH:0] rd2wr_gray0, rd2wr_gray1;  // 读指针格雷码 -> 写域

    // 空标志：读域当前格雷码 == 同步过来的写格雷码
    assign rd_empty = (rd_ptr_gray == wr2rd_gray1);

    // 满标志：写指针下一格雷码 == 同步过来的读格雷码（最高两位取反）
    assign wr_full  = (wr_gray_next ==
                       {~rd2wr_gray1[ADDR_WIDTH],
                        ~rd2wr_gray1[ADDR_WIDTH-1],
                        rd2wr_gray1[ADDR_WIDTH-2:0]});

    // 读数据：异步组合读（小深度模型；上板可换 Block Memory Generator IP）
    assign rd_data = ram[rd_ptr_bin[ADDR_WIDTH-1:0]];

    // ---- 写域逻辑 ----
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin  <= 0;
            wr_ptr_gray <= 0;
        end else if (wr_en && !wr_full) begin
            ram[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
            wr_ptr_bin  <= wr_bin_next;
            wr_ptr_gray <= wr_gray_next;
        end
    end

    // ---- 读域逻辑 ----
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin  <= 0;
            rd_ptr_gray <= 0;
        end else if (rd_en && !rd_empty) begin
            rd_ptr_bin  <= rd_bin_next;
            rd_ptr_gray <= rd_gray_next;
        end
    end

    // ---- 写指针格雷码 -> 读域两级同步 ----
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr2rd_gray0 <= 0;
            wr2rd_gray1 <= 0;
        end else begin
            wr2rd_gray0 <= wr_ptr_gray;
            wr2rd_gray1 <= wr2rd_gray0;
        end
    end

    // ---- 读指针格雷码 -> 写域两级同步 ----
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd2wr_gray0 <= 0;
            rd2wr_gray1 <= 0;
        end else begin
            rd2wr_gray0 <= rd_ptr_gray;
            rd2wr_gray1 <= rd2wr_gray0;
        end
    end

endmodule
