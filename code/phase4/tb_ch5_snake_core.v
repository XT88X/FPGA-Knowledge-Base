// tb_ch5_snake_core.v — 贪吃蛇核心自检：直行/禁反向/吃食物增长/撞墙/撞自身/重启
`timescale 1ns/1ps
module tb_ch5_snake_core;
    reg clk = 0;
    reg rst_n = 0;
    reg frame_tick = 0;
    reg [1:0] dir_cmd = 2'b11;
    reg restart = 0;
    wire game_over;
    wire [7:0] score;
    wire [4:0] food_x;
    wire [3:0] food_y;
    wire [4:0] head_x;
    wire [3:0] head_y;
    wire [4:0] qx = 5'd0;
    wire [3:0] qy = 4'd0;
    wire snake_hit;
    wire food_eaten;

    ch5_snake_core u_dut (
        .clk(clk), .rst_n(rst_n), .frame_tick(frame_tick), .dir_cmd(dir_cmd),
        .restart(restart), .game_over(game_over), .score(score),
        .food_x(food_x), .food_y(food_y), .head_x(head_x), .head_y(head_y),
        .qx(qx), .qy(qy), .snake_hit(snake_hit), .food_eaten(food_eaten)
    );
    always #10 clk = ~clk;

    initial begin
        rst_n = 0; restart = 0; dir_cmd = 2'b11;
        #55; rst_n = 1; #20;

        // 初始：头(5,7) 朝右，食物(7,7)
        if (head_x == 5 && head_y == 4'd7 && score == 8'd0)
            $display("CORE OK: init head=(%0d,%0d) food=(%0d,%0d)", head_x, head_y, food_x, food_y);
        else
            $display("CORE FAIL: init head=(%0d,%0d)", head_x, head_y);

        // 直行一格（右）-> 头(6,7)
        dir_cmd = 2'b11;
        @(posedge clk); frame_tick = 1; @(posedge clk); frame_tick = 0; #20;
        if (head_x == 6 && head_y == 4'd7)
            $display("CORE OK: straight right -> head=(%0d,%0d)", head_x, head_y);
        else
            $display("CORE FAIL: straight -> head=(%0d,%0d)", head_x, head_y);

        // 禁止反向：按左（应被忽略仍向右）-> 头(7,7)，吃到食物 score=1
        dir_cmd = 2'b10;
        @(posedge clk); frame_tick = 1; @(posedge clk); frame_tick = 0; #20;
        if (head_x == 7 && head_y == 4'd7 && score == 8'd1)
            $display("CORE OK: reverse-blocked & eat -> head=(%0d,%0d) score=%0d", head_x, head_y, score);
        else
            $display("CORE FAIL: rev/eat -> head=(%0d,%0d) score=%0d", head_x, head_y, score);

        // 撞墙：持续向左多步，头 x 越界 -> game_over
        dir_cmd = 2'b10;
        @(posedge clk); frame_tick = 1; @(posedge clk); frame_tick = 0; #20;
        @(posedge clk); frame_tick = 1; @(posedge clk); frame_tick = 0; #20;
        @(posedge clk); frame_tick = 1; @(posedge clk); frame_tick = 0; #20;
        @(posedge clk); frame_tick = 1; @(posedge clk); frame_tick = 0; #20;
        @(posedge clk); frame_tick = 1; @(posedge clk); frame_tick = 0; #20;
        @(posedge clk); frame_tick = 1; @(posedge clk); frame_tick = 0; #20;
        if (game_over == 1'b1)
            $display("CORE OK: wall collision game_over=1");
        else
            $display("CORE FAIL: no wall game_over head=(%0d,%0d)", head_x, head_y);

        // 重启
        @(posedge clk); restart = 1; @(posedge clk); restart = 0; #20;
        if (head_x == 5 && head_y == 4'd7 && score == 8'd0 && game_over == 1'b0)
            $display("CORE OK: restart -> head=(%0d,%0d) score=%0d", head_x, head_y, score);
        else
            $display("CORE FAIL: restart -> head=(%0d,%0d) score=%0d go=%0d", head_x, head_y, score, game_over);

        // 撞自身：上->右->下->左 绕小方圈
        dir_cmd = 2'b00;
        @(posedge clk); frame_tick = 1; @(posedge clk); frame_tick = 0; #20;
        dir_cmd = 2'b11;
        @(posedge clk); frame_tick = 1; @(posedge clk); frame_tick = 0; #20;
        dir_cmd = 2'b01;
        @(posedge clk); frame_tick = 1; @(posedge clk); frame_tick = 0; #20;
        dir_cmd = 2'b10;
        @(posedge clk); frame_tick = 1; @(posedge clk); frame_tick = 0; #20;
        if (game_over == 1'b1)
            $display("CORE OK: self collision game_over=1");
        else
            $display("CORE FAIL: no self collision head=(%0d,%0d)", head_x, head_y);

        $finish;
    end
endmodule
