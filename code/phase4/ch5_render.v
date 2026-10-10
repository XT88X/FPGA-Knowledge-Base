//============================================================================
// ch5_render.v — 游戏渲染：网格->像素配色（可综合）
//   像素坐标换算网格格：gx = pixel_x / 32, gy = pixel_y / 32。
//   把 gx/gy 输出给 snake_core 做组合查询 snake_hit，再叠加背景/网格/蛇/食物。
//============================================================================
module ch5_render(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       pxl_en,
    input  wire [9:0] pixel_x,
    input  wire [9:0] pixel_y,
    input  wire       hsync_in,
    input  wire       vsync_in,
    input  wire       video_on,
    input  wire [4:0] head_x,
    input  wire [3:0] head_y,
    input  wire [4:0] food_x,
    input  wire [3:0] food_y,
    input  wire       snake_hit,
    input  wire       game_over,
    output wire [4:0] gx,        // 回送给 snake_core.qx
    output wire [3:0] gy,        // 回送给 snake_core.qy
    output reg        hsync,
    output reg        vsync,
    output reg  [3:0] vga_r,
    output reg  [3:0] vga_g,
    output reg  [3:0] vga_b
);
    // 坐标换算：每格 32px
    assign gx = pixel_x[9:5];
    assign gy = pixel_y[8:5];

    wire is_food  = (gx == food_x) && (gy == food_y);
    wire is_head  = (gx == head_x) && (gy == head_y);
    wire grid_line = (pixel_x[4] == 1'b0) || (pixel_y[4] == 1'b0);  // 每格左/上边界细线

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hsync  <= 1'b1;
            vsync  <= 1'b1;
            vga_r  <= 4'h0;
            vga_g  <= 4'h0;
            vga_b  <= 4'h0;
        end else if (pxl_en) begin
            hsync <= hsync_in;
            vsync <= vsync_in;
            if (!video_on) begin
                vga_r <= 4'h0; vga_g <= 4'h0; vga_b <= 4'h0;
            end else if (game_over) begin
                vga_r <= 4'h8; vga_g <= 4'h1; vga_b <= 4'h1;
            end else if (is_food) begin
                vga_r <= 4'hF; vga_g <= 4'h2; vga_b <= 4'h2;   // 食物红
            end else if (is_head) begin
                vga_r <= 4'hB; vga_g <= 4'hF; vga_b <= 4'h3;   // 蛇头亮黄绿
            end else if (snake_hit) begin
                vga_r <= 4'h2; vga_g <= 4'hC; vga_b <= 4'h2;    // 蛇身绿
            end else if (grid_line) begin
                vga_r <= 4'h1; vga_g <= 4'h2; vga_b <= 4'h3;    // 网格暗线
            end else begin
                vga_r <= 4'h0; vga_g <= 4'h0; vga_b <= 4'h1;    // 背景深蓝黑
            end
        end
    end
endmodule
