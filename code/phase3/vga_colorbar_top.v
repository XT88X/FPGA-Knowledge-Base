//==============================================================================
// vga_colorbar_top.v - VGA 彩条输出
// 8 条竖彩条：白/黄/青/绿/品红/红/蓝/黑
//==============================================================================
`default_nettype none

module vga_colorbar_top (
    input  wire clk,
    input  wire rst_n,
    output wire hsync,
    output wire vsync,
    output reg  [2:0] rgb
);

    wire       video_on;
    wire [9:0] pixel_x, pixel_y;

    vga_sync u_sync (
        .clk(clk), .rst_n(rst_n),
        .hsync(hsync), .vsync(vsync),
        .video_on(video_on),
        .pixel_x(pixel_x), .pixel_y(pixel_y)
    );

    always @(*) begin
        if (!video_on)
            rgb = 3'b000;
        else begin
            // 8 条竖彩条，每条 80 像素宽
            case (pixel_x[9:7])
                3'd0: rgb = 3'b111;  // 白
                3'd1: rgb = 3'b110;  // 黄
                3'd2: rgb = 3'b101;  // 青
                3'd3: rgb = 3'b100;  // 绿
                3'd4: rgb = 3'b011;  // 品红
                3'd5: rgb = 3'b010;  // 红
                3'd6: rgb = 3'b001;  // 蓝
                3'd7: rgb = 3'b000;  // 黑
                default: rgb = 3'b000;
            endcase
        end
    end

endmodule

`default_nettype wire
