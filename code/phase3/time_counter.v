//==============================================================================
// time_counter.v - 时分秒计数器
// 秒 0~59、分 0~59、时 0~23；按键调时：mode=0 走时，mode=1 调分，mode=2 调时
//==============================================================================
`default_nettype none

module time_counter #(
    parameter integer CLK_FREQ_HZ = 50_000_000
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [1:0] mode,      // 0=走时, 1=调分, 2=调时
    input  wire add_pulse,        // 调时加一键脉冲
    output reg  [5:0] sec,       // 0~59
    output reg  [5:0] min,       // 0~59
    output reg  [5:0] hour        // 0~23
);

    localparam integer SEC_MAX = CLK_FREQ_HZ - 1;

    reg [31:0] sec_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sec_cnt <= 32'd0;
            sec     <= 6'd0;
            min     <= 6'd0;
            hour    <= 6'd0;
        end else begin
            if (mode == 2'b00) begin
                // 正常走时
                sec_cnt <= sec_cnt + 1'b1;
                if (sec_cnt >= SEC_MAX) begin
                    sec_cnt <= 32'd0;
                    if (sec == 6'd59) begin
                        sec <= 6'd0;
                        if (min == 6'd59) begin
                            min <= 6'd0;
                            if (hour == 6'd23)
                                hour <= 6'd0;
                            else
                                hour <= hour + 1'b1;
                        end else begin
                            min <= min + 1'b1;
                        end
                    end else begin
                        sec <= sec + 1'b1;
                    end
                end
            end else begin
                // 调时模式：add_pulse 上升沿加一
                if (add_pulse) begin
                    if (mode == 2'b01) begin
                        if (min == 6'd59) min <= 6'd0;
                        else min <= min + 1'b1;
                    end else if (mode == 2'b10) begin
                        if (hour == 6'd23) hour <= 6'd0;
                        else hour <= hour + 1'b1;
                    end
                end
                sec_cnt <= 32'd0;
            end
        end
    end

endmodule

`default_nettype wire
