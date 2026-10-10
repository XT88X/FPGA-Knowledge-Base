//==============================================================================
// vga_sync.v - VGA 640x480@60 时序发生器
// 水平：640 可见 + 16 前肩 + 96 同步 + 48 后肩 = 800 像素时钟
// 垂直：480 可见 + 10 前肩 + 2  同步 + 33 后肩 = 525 行
// 像素时钟 25.175MHz；本设计用 50MHz 计数使能得到 25MHz（不依赖 MMCM）。
//==============================================================================
`default_nettype none

module vga_sync #(
    parameter integer CLK_FREQ_HZ = 50_000_000
)(
    input  wire clk,
    input  wire rst_n,
    output reg  hsync,
    output reg  vsync,
    output reg  video_on,
    output reg  [9:0] pixel_x,
    output reg  [9:0] pixel_y
);

    // 水平参数
    localparam H_VISIBLE   = 640;
    localparam H_FRONT     = 16;
    localparam H_SYNC      = 96;
    localparam H_BACK      = 48;
    localparam H_TOTAL     = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;  // 800

    // 垂直参数
    localparam V_VISIBLE   = 480;
    localparam V_FRONT     = 10;
    localparam V_SYNC      = 2;
    localparam V_BACK      = 33;
    localparam V_TOTAL     = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;  // 525

    reg [9:0] h_cnt;
    reg [9:0] v_cnt;
    reg       pix_en;   // 25MHz 像素使能（50MHz 分频）

    // 50MHz -> 25MHz 使能：每 2 个时钟一个像素
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pix_en <= 1'b0;
        else
            pix_en <= ~pix_en;
    end

    // 水平计数器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_cnt <= 10'd0;
        end else if (pix_en) begin
            if (h_cnt == H_TOTAL - 1)
                h_cnt <= 10'd0;
            else
                h_cnt <= h_cnt + 1'b1;
        end
    end

    // 垂直计数器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_cnt <= 10'd0;
        end else if (pix_en && h_cnt == H_TOTAL - 1) begin
            if (v_cnt == V_TOTAL - 1)
                v_cnt <= 10'd0;
            else
                v_cnt <= v_cnt + 1'b1;
        end
    end

    // 同步信号（低有效）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hsync    <= 1'b1;
            vsync    <= 1'b1;
            video_on <= 1'b0;
            pixel_x  <= 10'd0;
            pixel_y  <= 10'd0;
        end else if (pix_en) begin
            // 水平同步：640+16=656 到 656+96=752 为低
            hsync <= (h_cnt >= H_VISIBLE + H_FRONT && h_cnt < H_VISIBLE + H_FRONT + H_SYNC) ? 1'b0 : 1'b1;
            // 垂直同步：480+10=490 到 490+2=492 为低
            vsync <= (v_cnt >= V_VISIBLE + V_FRONT && v_cnt < V_VISIBLE + V_FRONT + V_SYNC) ? 1'b0 : 1'b1;
            // 可见区域
            video_on <= (h_cnt < H_VISIBLE && v_cnt < V_VISIBLE);
            pixel_x  <= h_cnt;
            pixel_y  <= v_cnt;
        end
    end

endmodule

`default_nettype wire
