//============================================================================
// ch5_snake_top.v — VGA 贪吃蛇顶层（可综合）
//   vga_sync + snake_core + render 互连；含 25MHz 像素使能、帧节拍分频、
//   按键同步/方向编码。引脚见 code/common/fpga_common.xdc（不编造引脚号）。
//============================================================================
module ch5_snake_top #(
    parameter integer FRAME_DIV = 6_250_000   // 50MHz/8Hz ≈ 6.25M
)(
    input  wire      clk,
    input  wire      rst_n,
    input  wire [3:0] btn,        // {up,down,left,right}，高有效（板级需消抖）
    output wire      hsync,
    output wire      vsync,
    output wire [3:0] vga_r,
    output wire [3:0] vga_g,
    output wire [3:0] vga_b
);
    wire       pxl_en;
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire       video_on;
    wire       hsync_raw;
    wire       vsync_raw;

    ch5_vga_sync u_vga (
        .clk(clk), .rst_n(rst_n),
        .hsync(hsync_raw), .vsync(vsync_raw), .video_on(video_on),
        .pixel_x(pixel_x), .pixel_y(pixel_y), .pxl_en(pxl_en)
    );

    // 帧节拍分频
    reg [22:0] frame_cnt;
    reg        frame_tick;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_cnt  <= 23'd0;
            frame_tick <= 1'b0;
        end else if (frame_cnt == FRAME_DIV - 1) begin
            frame_cnt  <= 23'd0;
            frame_tick <= 1'b1;
        end else begin
            frame_cnt  <= frame_cnt + 1'b1;
            frame_tick <= 1'b0;
        end
    end

    // 按键两级同步 + 方向锁存（无键时保持上一次方向）
    reg [3:0] btn_s1, btn_s2;
    reg [1:0] dir_cmd;
    localparam D_UP = 2'b00, D_DOWN = 2'b01, D_LEFT = 2'b10, D_RIGHT = 2'b11;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_s1 <= 4'b0000;
            btn_s2 <= 4'b0000;
            dir_cmd <= D_RIGHT;
        end else begin
            btn_s1 <= btn;
            btn_s2 <= btn_s1;
            if (btn_s2 != 4'b0000) begin
                if      (btn_s2[0]) dir_cmd <= D_RIGHT;
                else if (btn_s2[1]) dir_cmd <= D_LEFT;
                else if (btn_s2[2]) dir_cmd <= D_DOWN;
                else if (btn_s2[3]) dir_cmd <= D_UP;
            end
        end
    end

    wire [4:0] gx;
    wire [3:0] gy;
    wire [4:0] core_head_x;
    wire [3:0] core_head_y;
    wire [4:0] core_food_x;
    wire [3:0] core_food_y;
    wire       snake_hit;
    wire       game_over;
    wire [7:0] score;
    wire       food_eaten;

    ch5_snake_core u_core (
        .clk(clk), .rst_n(rst_n),
        .frame_tick(frame_tick), .dir_cmd(dir_cmd), .restart(1'b0),
        .game_over(game_over), .score(score),
        .food_x(core_food_x), .food_y(core_food_y),
        .head_x(core_head_x), .head_y(core_head_y),
        .qx(gx), .qy(gy), .snake_hit(snake_hit),
        .food_eaten(food_eaten)
    );

    ch5_render u_render (
        .clk(clk), .rst_n(rst_n), .pxl_en(pxl_en),
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .hsync_in(hsync_raw), .vsync_in(vsync_raw), .video_on(video_on),
        .head_x(core_head_x), .head_y(core_head_y),
        .food_x(core_food_x), .food_y(core_food_y),
        .snake_hit(snake_hit), .game_over(game_over),
        .gx(gx), .gy(gy),
        .hsync(hsync), .vsync(vsync),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b)
    );
endmodule
