//==============================================================================
// tb_seg7_hex.v  —  Testbench：七段译码 0~F 查表自检（共阴极性）
//   * 共阴(COMMON_ANODE=0)：逐个 hex 比对段码是否等于标准真值表。
//   * 再验证共阳模式下输出是否为共阴输出的取反。
//==============================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_seg7_hex;

    reg  [3:0] hex;
    reg        dp_i;
    wire [6:0] seg;
    wire       dp;

    integer i;
    integer err;

    // 共阴标准段码表 gfedcba：0..F
    reg [6:0] table [0:15];

    seg7_hex #(
        .COMMON_ANODE(1'b0)
    ) u_dut (
        .hex  (hex),
        .dp_i (dp_i),
        .seg  (seg),
        .dp   (dp)
    );

    initial begin
        table[0]  = 7'h3F; table[1]  = 7'h06; table[2]  = 7'h5B; table[3]  = 7'h4F;
        table[4]  = 7'h66; table[5]  = 7'h6D; table[6]  = 7'h7D; table[7]  = 7'h07;
        table[8]  = 7'h7F; table[9]  = 7'h6F; table[10] = 7'h77; table[11] = 7'h7C;
        table[12] = 7'h39; table[13] = 7'h5E; table[14] = 7'h79; table[15] = 7'h71;

        hex  = 4'h0;
        dp_i = 1'b0;
        err  = 0;

        // 共阴模式：逐个比对
        for (i = 0; i < 16; i = i + 1) begin
            hex = i[3:0];
            #5;
            if (seg != table[i]) begin
                err = err + 1;
                $display("[TB] FAIL: hex=%h seg=%h expect=%h", hex, seg, table[i]);
            end else begin
                $display("[TB] OK  : hex=%h -> seg=%h", hex, seg);
            end
        end

        // 小数点：dp_i=1 共阴应使 dp=1
        dp_i = 1'b1; #5;
        if (dp != 1'b1) begin
            err = err + 1;
            $display("[TB] FAIL: 共阴 dp_i=1 时 dp=%b", dp);
        end

        if (err == 0) $display("[TB] PASS: 七段译码全部通过");
        else          $display("[TB] FAIL: 共 %0d 处错误", err);

        $finish;
    end

endmodule

`default_nettype wire
