//============================================================================
// ch4_seg7_scan.v — 6 位数码管动态扫描 + 七段译码（可综合）
//   每一位约 SCAN_HZ 赫兹轮流通亮，利用人眼视觉暂留看起来常亮。
//   输入 6 位 BCD，输出段选 seg[7:0]={dp,g,f,e,d,c,b,a} 与位选 sel[5:0]。
//   共阴数码管段码；共阳板卡需按原理图把段码取反。
//============================================================================
module ch4_seg7_scan #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer SCAN_HZ      = 1000,   // 每位刷新频率 Hz
    parameter integer DIGITS       = 6
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [23:0] bcd_digits,  // [3:0]个位 ... [23:20]十万位
    input  wire [1:0]  unit_sel,    // 0 Hz,1 kHz,2 MHz（预留单位指示）
    output reg  [7:0]  seg,         // {dp,g,f,e,d,c,b,a}
    output reg  [5:0]  sel          // 位选，高有效
);
    localparam integer CNT_MAX = CLK_FREQ_HZ / (SCAN_HZ * DIGITS);

    reg [15:0] div_cnt;
    reg [2:0]  digit_sel;           // 0..5
    reg [3:0]  bcd;

    // 扫描分频：每位停留 CNT_MAX 个时钟
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt    <= 16'd0;
            digit_sel  <= 3'd0;
        end else begin
            if (div_cnt == CNT_MAX - 1) begin
                div_cnt <= 16'd0;
                if (digit_sel == DIGITS - 1)
                    digit_sel <= 3'd0;
                else
                    digit_sel <= digit_sel + 1'b1;
            end else begin
                div_cnt <= div_cnt + 1'b1;
            end
        end
    end

    // 选通当前位的 BCD
    always @(*) begin
        case (digit_sel)
            3'd0:    bcd = bcd_digits[3:0];
            3'd1:    bcd = bcd_digits[7:4];
            3'd2:    bcd = bcd_digits[11:8];
            3'd3:    bcd = bcd_digits[15:12];
            3'd4:    bcd = bcd_digits[19:16];
            default: bcd = bcd_digits[23:20];
        endcase
    end

    // 七段译码（共阴）：seg = {dp,g,f,e,d,c,b,a}
    always @(*) begin
        case (bcd)
            4'd0:    seg = 8'b00111111;
            4'd1:    seg = 8'b00000110;
            4'd2:    seg = 8'b01011011;
            4'd3:    seg = 8'b01001111;
            4'd4:    seg = 8'b01100110;
            4'd5:    seg = 8'b01101101;
            4'd6:    seg = 8'b01111101;
            4'd7:    seg = 8'b00000111;
            4'd8:    seg = 8'b01111111;
            4'd9:    seg = 8'b01101111;
            default: seg = 8'b00000000;
        endcase
    end

    // 位选：高有效（按板卡硬件可改为低有效）
    always @(*) begin
        sel        = 6'b000000;
        sel[digit_sel] = 1'b1;
    end

    // 注：unit_sel 由顶层接到外部 LED/小数点做单位指示，本模块保留该输入。
endmodule
