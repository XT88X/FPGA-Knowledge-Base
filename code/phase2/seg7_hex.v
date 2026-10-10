//==============================================================================
// seg7_hex.v  —  可综合：一位七段数码管十六进制译码（0~F + 小数点）
// 目标器件：通用 Xilinx Artix-7 / Zynq（7 系列）
//
// 原理：4 位输入 hex[3:0] 译出 7 段段选 seg[6:0]，seg[0]=a ... seg[6]=g。
//   * 共阴(COMMON_ANODE=0)：段给高电平点亮；
//   * 共阳(COMMON_ANODE=1)：段给低电平点亮，输出整体取反。
//   dp_i 为小数点输入，同样按共阴/共阳极性取反后输出 dp。
// 段码表按 gfedcba(bit6..bit0) 共阴极性给出：
//   0=3F 1=06 2=5B 3=4F 4=66 5=6D 6=7D 7=07
//   8=7F 9=6F A=77 b=7C C=39 d=5E E=79 F=71
//==============================================================================
`default_nettype none

module seg7_hex #(
    parameter COMMON_ANODE = 1'b0   // 0=共阴(段高点亮) 1=共阳(段低点亮)
)(
    input  wire [3:0] hex,    // 待显示的 0~F
    input  wire       dp_i,   // 小数点输入（共阴极性：1=点亮小数点）
    output reg  [6:0] seg,    // 段选 a..g（seg[0]=a ... seg[6]=g）
    output reg        dp      // 小数点输出
);

    reg [6:0] seg_cathode;     // 共阴极性段码

    always @(*) begin
        case (hex)
            4'h0: seg_cathode = 7'h3F;
            4'h1: seg_cathode = 7'h06;
            4'h2: seg_cathode = 7'h5B;
            4'h3: seg_cathode = 7'h4F;
            4'h4: seg_cathode = 7'h66;
            4'h5: seg_cathode = 7'h6D;
            4'h6: seg_cathode = 7'h7D;
            4'h7: seg_cathode = 7'h07;
            4'h8: seg_cathode = 7'h7F;
            4'h9: seg_cathode = 7'h6F;
            4'hA: seg_cathode = 7'h77;
            4'hB: seg_cathode = 7'h7C;
            4'hC: seg_cathode = 7'h39;
            4'hD: seg_cathode = 7'h5E;
            4'hE: seg_cathode = 7'h79;
            4'hF: seg_cathode = 7'h71;
            default: seg_cathode = 7'h00;
        endcase
    end

    always @(*) begin
        if (COMMON_ANODE) begin
            seg = ~seg_cathode;   // 共阳：取反
            dp  = ~dp_i;
        end else begin
            seg = seg_cathode;    // 共阴：直接输出
            dp  = dp_i;
        end
    end

endmodule

`default_nettype wire
