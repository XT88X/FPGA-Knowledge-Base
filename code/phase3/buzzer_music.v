//==============================================================================
// buzzer_music.v  —  可综合：蜂鸣器播放《小星星》
//   音符 -> 频率 -> 分频：buzzer 每 (CLK/(2*f)) 个时钟翻转一次，得到方波。
//   音名(中音)：C4=262 D4=294 E4=330 F4=349 G4=392 A4=440 Hz。
//   旋律按简谱 1 1 5 5 6 6 5 - | 4 4 3 3 2 2 1 - | ... 顺序播放。
//   DUR_DIV 控制每个音的时长（越小越快，便于仿真）。
//==============================================================================
`default_nettype none

module buzzer_music #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer DUR_DIV     = 20
)(
    input  wire clk,
    input  wire rst_n,
    output reg  buzzer_out
);

    // 音符分频表：索引 0..5 对应 C4 D4 E4 F4 G4 A4
    function [15:0] note_div;
        input [3:0] n;
        begin
            case (n)
            4'd0: note_div = 16'd95419;  // C4 262Hz
            4'd1: note_div = 16'd85034;  // D4 294Hz
            4'd2: note_div = 16'd75758;  // E4 330Hz
            4'd3: note_div = 16'd71633;  // F4 349Hz
            4'd4: note_div = 16'd63776;  // G4 392Hz
            4'd5: note_div = 16'd56818;  // A4 440Hz
            default: note_div = 16'd1;   // 休止
            endcase
        end
    endfunction

    // 《小星星》旋律（简谱 -> 音名索引）
    reg [3:0] melody [0:41];
    integer   mi;
    initial begin
        melody[ 0]=4'd0; melody[ 1]=4'd0; melody[ 2]=4'd4; melody[ 3]=4'd4;
        melody[ 4]=4'd5; melody[ 5]=4'd5; melody[ 6]=4'd4;
        melody[ 7]=4'd3; melody[ 8]=4'd3; melody[ 9]=4'd2; melody[10]=4'd2;
        melody[11]=4'd1; melody[12]=4'd1; melody[13]=4'd0;
        melody[14]=4'd4; melody[15]=4'd4; melody[16]=4'd3; melody[17]=4'd3;
        melody[18]=4'd2; melody[19]=4'd2;
        melody[20]=4'd4; melody[21]=4'd4; melody[22]=4'd3; melody[23]=4'd3;
        melody[24]=4'd2; melody[25]=4'd2;
        melody[26]=4'd0; melody[27]=4'd0; melody[28]=4'd4; melody[29]=4'd4;
        melody[30]=4'd5; melody[31]=4'd5; melody[32]=4'd4;
        melody[33]=4'd3; melody[34]=4'd3; melody[35]=4'd2; melody[36]=4'd2;
        melody[37]=4'd1; melody[38]=4'd1; melody[39]=4'd0;
        for (mi = 40; mi < 42; mi = mi + 1) melody[mi] = 4'd6;  // 尾部休止
    end

    reg [5:0]  note_idx;       // 0..41
    reg [15:0] dur_cnt;        // 当前音已持续的慢拍数
    reg [15:0] tone_cnt;       // 方波分频计数
    reg [15:0] cur_div;

    // 当前音符分频
    always @(*) begin
        if (melody[note_idx] >= 4'd6)
            cur_div = 16'd0;        // 休止：不发声
        else
            cur_div = note_div(melody[note_idx]);
    end

    // 音符时长计数：慢 tick 到来时累加，到 DUR_DIV 倍长后换音
    reg [DUR_DIV-1:0] slow_cnt;
    wire slow_tick = (slow_cnt == {DUR_DIV{1'b1}});

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) slow_cnt <= {DUR_DIV{1'b0}};
        else        slow_cnt <= slow_cnt + 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            note_idx <= 6'd0;
            dur_cnt  <= 16'd0;
        end else if (slow_tick) begin
            if (dur_cnt >= 16'd20) begin     // 每个音约 21 个慢拍
                dur_cnt  <= 16'd0;
                note_idx <= (note_idx == 6'd41) ? 6'd0 : note_idx + 1'b1;
            end else begin
                dur_cnt <= dur_cnt + 1'b1;
            end
        end
    end

    // 方波产生：按当前音符分频翻转
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tone_cnt   <= 16'd0;
            buzzer_out <= 1'b0;
        end else if (cur_div == 16'd0) begin
            buzzer_out <= 1'b0;            // 休止
            tone_cnt   <= 16'd0;
        end else if (tone_cnt >= cur_div - 1) begin
            tone_cnt   <= 16'd0;
            buzzer_out <= ~buzzer_out;
        end else begin
            tone_cnt <= tone_cnt + 1'b1;
        end
    end

endmodule

`default_nettype wire
