//==============================================================================
// oled_top.v  —  可综合：OLED 显示顶层
//   上电初始化完成后，自动在 (col=0,page=0) 写 '0'、(col=8,page=0) 写 '1'。
//   实际项目里把 char_col/char_page/char_code/char_wr 接到自己的内容生成逻辑。
//==============================================================================
`default_nettype none

module oled_top #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer SCLK_HZ     = 1_000_000
)(
    input  wire clk,
    input  wire rst_n,
    output wire oled_cs_n,
    output wire oled_dc,
    output wire oled_sclk,
    output wire oled_mosi
);

    reg [6:0] char_col;
    reg [2:0] char_page;
    reg [7:0] char_code;
    reg       char_wr;
    wire      busy;

    reg [1:0] idx;       // 已写了几个字符
    reg [2:0] step;

    oled_ssd1306 #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .SCLK_HZ    (SCLK_HZ)
    ) u_oled (
        .clk      (clk),
        .rst_n    (rst_n),
        .char_col (char_col),
        .char_page(char_page),
        .char_code(char_code),
        .char_wr  (char_wr),
        .busy     (busy),
        .oled_cs_n(oled_cs_n),
        .oled_dc  (oled_dc),
        .oled_sclk(oled_sclk),
        .oled_mosi(oled_mosi)
    );

    // 极简写字序列：init 完成后依次写两个字符
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            idx     <= 2'd0;
            step    <= 3'd0;
            char_wr <= 1'b0;
            char_col <= 7'd0;
            char_page <= 3'd0;
            char_code <= 8'h30;
        end else begin
            case (step)
            3'd0: begin                 // 等待初始化完成（busy 变低）
                char_wr <= 1'b0;
                if (!busy) step <= 3'd1;
            end
            3'd1: begin                 // 设定字符参数
                char_col  <= (idx == 2'd0) ? 7'd0  : 7'd8;
                char_page <= 3'd0;
                char_code <= 8'h30 + {6'd0, idx};   // '0'/'1'
                char_wr   <= 1'b1;
                step      <= 3'd2;
            end
            3'd2: begin                 // 保持写请求一拍
                char_wr <= 1'b0;
                step    <= 3'd3;
            end
            3'd3: begin                 // 等待本次写完
                if (busy) step <= 3'd4;
            end
            3'd4: begin                 // 写完，等待 busy 重新变低
                if (!busy) begin
                    if (idx < 2'd1) begin
                        idx  <= idx + 1'b1;
                        step <= 3'd1;
                    end else begin
                        step <= 3'd5;   // 完成，停留
                    end
                end
            end
            default: step <= 3'd5;
            endcase
        end
    end

endmodule

`default_nettype wire
