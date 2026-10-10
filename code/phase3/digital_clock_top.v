//==============================================================================
// digital_clock_top.v - 数字电子钟顶层
// 时分秒计数 + 按键消抖 + 数码管动态扫描。
// 按键：key_mode 切换模式（0走时/1调分/2调时），key_add 加一。
//==============================================================================
`default_nettype none

module digital_clock_top #(
    parameter integer CLK_FREQ_HZ = 50_000_000
)(
    input  wire clk,
    input  wire rst_n,
    input  wire key_mode,
    input  wire key_add,
    output wire [7:0] seg,
    output wire [5:0] seg_sel
);

    wire [5:0] sec, min, hour;
    wire       mode_db;
    wire       add_db;

    reg  [1:0] mode_reg;
    reg        add_pulse;
    reg        add_last;

    // 按键消抖
    clk_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) u_mode (
        .clk(clk), .rst_n(rst_n), .key_in(key_mode), .key_out(mode_db)
    );
    clk_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) u_add (
        .clk(clk), .rst_n(rst_n), .key_in(key_add), .key_out(add_db)
    );

    // mode_db 上升沿切换模式
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode_reg <= 2'b00;
        end else if (mode_db == 1'b0) begin
            if (mode_reg == 2'b10) mode_reg <= 2'b00;
            else mode_reg <= mode_reg + 1'b1;
        end
    end

    // add_db 上升沿产生一个拍脉冲
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            add_last  <= 1'b1;
            add_pulse <= 1'b0;
        end else begin
            add_pulse <= (add_last == 1'b1 && add_db == 1'b0);
            add_last  <= add_db;
        end
    end

    // 时分秒计数器
    time_counter #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) u_cnt (
        .clk(clk), .rst_n(rst_n),
        .mode(mode_reg), .add_pulse(add_pulse),
        .sec(sec), .min(min), .hour(hour)
    );

    // BCD 拆分
    wire [3:0] sec_lo = sec % 10;
    wire [3:0] sec_hi = sec / 10;
    wire [3:0] min_lo = min % 10;
    wire [3:0] min_hi = min / 10;
    wire [3:0] hour_lo = hour % 10;
    wire [3:0] hour_hi = hour / 10;

    // 动态扫描
    seg_dynamic_scan #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) u_scan (
        .clk(clk), .rst_n(rst_n),
        .digit0(sec_lo), .digit1(sec_hi),
        .digit2(min_lo), .digit3(min_hi),
        .digit4(hour_lo), .digit5(hour_hi),
        .seg(seg), .seg_sel(seg_sel)
    );

endmodule

`default_nettype wire
