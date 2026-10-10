//============================================================================
// ch5_snake_core.v — 贪吃蛇核心状态机（可综合）
//   网格 20(x) x 15(y)，每格 32px。蛇身存在 bx[]/by[] 数组，index0 为头。
//   frame_tick 推进一步：转向(禁180°) -> 算新头 -> 撞墙/撞自身判定 ->
//   吃食物(增长+计分+重投食物) 或 普通移动(去尾)。
//   对外提供组合查询 snake_hit(qx,qy)：该格是否蛇身，供渲染逐像素判定。
//============================================================================
module ch5_snake_core(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       frame_tick,     // 游戏步进（约 8~10Hz）
    input  wire [1:0] dir_cmd,        // 0上 1下 2左 3右
    input  wire       restart,
    output reg        game_over,
    output reg  [7:0] score,
    output reg  [4:0] food_x,
    output reg  [3:0] food_y,
    output reg  [4:0] head_x,
    output reg  [3:0] head_y,
    input  wire [4:0] qx,             // 渲染查询：网格列
    input  wire [3:0] qy,             // 渲染查询：网格行
    output reg        snake_hit,      // 组合：(qx,qy) 是否落在蛇身
    output reg        food_eaten      // 吃到食物的 1 拍脉冲
);
    localparam MAX_LEN = 6'd32;
    localparam GX_MAX  = 5'd19;   // 20 列：0..19
    localparam GY_MAX  = 4'd14;    // 15 行：0..14

    localparam D_UP    = 2'b00;
    localparam D_DOWN  = 2'b01;
    localparam D_LEFT  = 2'b10;
    localparam D_RIGHT = 2'b11;

    reg [4:0] bx [0:31];
    reg [3:0] by [0:31];
    reg [5:0] len;
    reg [1:0] cur_dir;

    wire [7:0] rng;
    reg        lfsr_en;

    ch5_lfsr u_lfsr (
        .clk(clk), .rst_n(rst_n), .en(lfsr_en), .rng(rng)
    );

    integer i;
    reg [1:0] next_dir;
    reg [4:0] nx;
    reg [3:0] ny;
    reg       wall;
    reg       self;
    reg       eat;

    // 1) 下一方向（禁止 180° 反向）
    always @(*) begin
        next_dir = cur_dir;
        if (dir_cmd != cur_dir) begin
            case (cur_dir)
                D_UP:    if (dir_cmd != D_DOWN)  next_dir = dir_cmd;
                D_DOWN:  if (dir_cmd != D_UP)    next_dir = dir_cmd;
                D_LEFT:  if (dir_cmd != D_RIGHT) next_dir = dir_cmd;
                D_RIGHT: if (dir_cmd != D_LEFT)  next_dir = dir_cmd;
                default: next_dir = dir_cmd;
            endcase
        end
    end

    // 2) 由 next_dir 推算新头坐标
    always @(*) begin
        case (next_dir)
            D_UP:    begin nx = head_x;       ny = head_y - 4'd1; end
            D_DOWN:  begin nx = head_x;       ny = head_y + 4'd1; end
            D_LEFT:  begin nx = head_x - 5'd1; ny = head_y;       end
            default: begin nx = head_x + 5'd1; ny = head_y;      end  // D_RIGHT
        endcase
    end

    // 3) 组合查询：(qx,qy) 是否落在当前蛇身
    always @(*) begin
        snake_hit = 1'b0;
        for (i = 0; i < 32; i = i + 1) begin
            if (i < len && bx[i] == qx && by[i] == qy)
                snake_hit = 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bx[0] = 5'd5; by[0] = 4'd7;
            bx[1] = 5'd4; by[1] = 4'd7;
            bx[2] = 5'd3; by[2] = 4'd7;
            bx[3] = 5'd0; by[3] = 4'd0;
            len        <= 6'd3;
            cur_dir    <= D_RIGHT;
            head_x     <= 5'd5; head_y <= 4'd7;
            food_x     <= 5'd7; food_y <= 4'd7;
            score      <= 8'd0;
            game_over  <= 1'b0;
            lfsr_en    <= 1'b0;
            food_eaten <= 1'b0;
        end else if (restart) begin
            bx[0] = 5'd5; by[0] = 4'd7;
            bx[1] = 5'd4; by[1] = 4'd7;
            bx[2] = 5'd3; by[2] = 4'd7;
            len        <= 6'd3;
            cur_dir    <= D_RIGHT;
            head_x     <= 5'd5; head_y <= 4'd7;
            food_x     <= 5'd7; food_y <= 4'd7;
            score      <= 8'd0;
            game_over  <= 1'b0;
            lfsr_en    <= 1'b0;
            food_eaten <= 1'b0;
        end else begin
            lfsr_en    <= 1'b0;
            food_eaten <= 1'b0;

            if (frame_tick && !game_over) begin
                cur_dir <= next_dir;

                // 撞墙（越界）
                wall = (nx > GX_MAX) || (ny > GY_MAX);

                // 撞自身
                self = 1'b0;
                for (i = 0; i < len; i = i + 1) begin
                    if (bx[i] == nx && by[i] == ny)
                        self = 1'b1;
                end

                if (wall || self) begin
                    game_over <= 1'b1;
                end else begin
                    // 是否吃到食物
                    eat = (nx == food_x && ny == food_y);

                    // 蛇身后移，新头入 index0
                    for (i = MAX_LEN - 1; i > 0; i = i - 1) begin
                        bx[i] = bx[i-1];
                        by[i] = by[i-1];
                    end
                    bx[0] = nx;
                    by[0] = ny;
                    head_x <= nx;
                    head_y <= ny;

                    if (eat) begin
                        if (len < MAX_LEN)
                            len <= len + 1'b1;
                        score      <= score + 1'b1;
                        food_eaten <= 1'b1;
                        lfsr_en    <= 1'b1;
                        food_x <= {1'b0, rng[4:0]};
                        food_y <= rng[7:4];
                    end
                end
            end
        end
    end
endmodule
