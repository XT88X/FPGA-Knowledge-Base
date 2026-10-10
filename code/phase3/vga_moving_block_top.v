//==============================================================================
// vga_moving_block_top.v - VGA 移动方块（碰边反弹）
// 方块 40x40，在 640x480 可视区内移动，碰到左右/上下边界反弹。
//==============================================================================
`default_nettype none

module vga_moving_block_top (
    input  wire clk,
    input  wire rst_n,
    output wire hsync,
    output wire vsync,
    output reg  [2:0] rgb
);

    wire       video_on;
    wire [9:0] pixel_x, pixel_y;

    reg [9:0]  block_x;
    reg [9:0]  block_y;
    reg        dir_x;   // 1=向右, 0=向左
    reg        dir_y;   // 1=向下, 0=向上

    localparam BLOCK_SIZE = 40;
    localparam H_MAX = 640 - BLOCK_SIZE;
    localparam V_MAX = 480 - BLOCK_SIZE;

    vga_sync u_sync (
        .clk(clk), .rst_n(rst_n),
        .hsync(hsync), .vsync(vsync),
        .video_on(video_on),
        .pixel_x(pixel_x), .pixel_y(pixel_y)
    );

    // 位置更新（每帧移动 2 像素）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            block_x <= 10'd0;
            block_y <= 10'd0;
            dir_x   <= 1'b1;
            dir_y   <= 1'b1;
        end else begin
            // 简化：每个像素时钟更新一次位置（实际应按帧）
            // 这里用 pixel_y==0 && pixel_x==0 作为帧开始标志
            if (pixel_x == 10'd0 && pixel_y == 10'd0) begin
                if (dir_x) begin
                    if (block_x >= H_MAX) dir_x <= 1'b0;
                    else block_x <= block_x + 2'd2;
                end else begin
                    if (block_x <= 10'd2) dir_x <= 1'b1;
                    else block_x <= block_x - 2'd2;
                end

                if (dir_y) begin
                    if (block_y >= V_MAX) dir_y <= 1'b0;
                    else block_y <= block_y + 2'd2;
                end else begin
                    if (block_y <= 10'd2) dir_y <= 1'b1;
                    else block_y <= block_y - 2'd2;
                end
            end
        end
    end

    // 输出 RGB：方块内红色，背景蓝色
    always @(*) begin
        if (!video_on)
            rgb = 3'b000;
        else if (pixel_x >= block_x && pixel_x < block_x + BLOCK_SIZE &&
                 pixel_y >= block_y && pixel_y < block_y + BLOCK_SIZE)
            rgb = 3'b111;  // 白方块
        else
            rgb = 3'b001;  // 蓝背景
    end

endmodule

`default_nettype wire
