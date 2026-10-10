//============================================================================
// ch5_lfsr.v — 8 位线性反馈移位寄存器（可综合，伪随机）
//   多项式 x^8+x^6+x^5+x^4+1，最长序列；en 脉冲到来时移位一次。
//   用于食物落点伪随机生成。上电固定种子，避免全 0 死锁。
//============================================================================
module ch5_lfsr(
    input  wire      clk,
    input  wire      rst_n,
    input  wire      en,
    output reg [7:0] rng
);
    localparam [7:0] SEED = 8'hAD;   // 非全 0

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rng <= SEED;
        else if (en) begin
            // 反馈 = q7 ^ q5 ^ q4 ^ q3
            rng <= {rng[6:0], rng[7] ^ rng[5] ^ rng[4] ^ rng[3]};
        end
    end
endmodule
