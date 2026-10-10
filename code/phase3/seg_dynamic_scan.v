//==============================================================================
// seg_dynamic_scan.v - 数码管动态扫描
// 6 位数码管（HH-MM-SS）：段选 8 位（a~g+dp），位选 6 位。
// 每 ~1ms 切一位，利用视觉暂留实现 6 位同时亮。
//==============================================================================
`default_nettype none

module seg_dynamic_scan #(
    parameter integer CLK_FREQ_HZ = 50_000_000
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [3:0] digit0,   // 最右位
    input  wire [3:0] digit1,
    input  wire [3:0] digit2,
    input  wire [3:0] digit3,
    input  wire [3:0] digit4,
    input  wire [3:0] digit5,   // 最左位
    output reg  [7:0] seg,      // 段选 {dp,g,f,e,d,c,b,a}
    output reg  [5:0] seg_sel    // 位选（低有效）
);

    localparam integer SCAN_MAX = CLK_FREQ_HZ / 1000;  // 1ms

    reg [15:0] scan_cnt;
    reg [2:0]  sel;
    reg [3:0]  cur_digit;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_cnt <= 16'd0;
            sel      <= 3'd0;
        end else begin
            scan_cnt <= scan_cnt + 1'b1;
            if (scan_cnt >= SCAN_MAX) begin
                scan_cnt <= 16'd0;
                sel <= sel + 1'b1;
                if (sel == 3'd5) sel <= 3'd0;
            end
        end
    end

    always @(*) begin
        case (sel)
            3'd0: begin cur_digit = digit0; seg_sel = 6'b111110; end
            3'd1: begin cur_digit = digit1; seg_sel = 6'b111101; end
            3'd2: begin cur_digit = digit2; seg_sel = 6'b111011; end
            3'd3: begin cur_digit = digit3; seg_sel = 6'b110111; end
            3'd4: begin cur_digit = digit4; seg_sel = 6'b101111; end
            3'd5: begin cur_digit = digit5; seg_sel = 6'b011111; end
            default: begin cur_digit = 4'd0; seg_sel = 6'b111111; end
        endcase
    end

    // 共阴数码管段码（a~g，dp=0）
    always @(*) begin
        case (cur_digit)
            4'd0: seg = 8'b00111111;
            4'd1: seg = 8'b00000110;
            4'd2: seg = 8'b01011011;
            4'd3: seg = 8'b01001111;
            4'd4: seg = 8'b01100110;
            4'd5: seg = 8'b01101101;
            4'd6: seg = 8'b01111101;
            4'd7: seg = 8'b00000111;
            4'd8: seg = 8'b01111111;
            4'd9: seg = 8'b01101111;
            default: seg = 8'b00000000;
        endcase
    end

endmodule

`default_nettype wire
