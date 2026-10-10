//==============================================================================
// clk_debounce.v - 按键消抖
// 原理：用同步寄存器把异步按键打两拍，再用计数器滤除 <20ms 的抖动。
//==============================================================================
`default_nettype none

module clk_debounce #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer DEBOUNCE_MS = 20
)(
    input  wire clk,
    input  wire rst_n,
    input  wire key_in,
    output reg  key_out
);

    localparam integer CNT_MAX = CLK_FREQ_HZ / 1000 * DEBOUNCE_MS;

    reg [1:0] sync_reg;
    reg       key_stable;
    reg [31:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_reg  <= 2'b11;
            key_stable <= 1'b1;
            cnt       <= 32'd0;
            key_out   <= 1'b1;
        end else begin
            sync_reg <= {sync_reg[0], key_in};
            if (sync_reg[1] != key_stable) begin
                cnt <= cnt + 1'b1;
                if (cnt >= CNT_MAX) begin
                    key_stable <= sync_reg[1];
                    cnt <= 32'd0;
                end
            end else begin
                cnt <= 32'd0;
            end
            key_out <= key_stable;
        end
    end

endmodule

`default_nettype wire
