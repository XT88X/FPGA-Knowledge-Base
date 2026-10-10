//============================================================================
// ch5_vga_sync.v — VGA 640x480@60 行场同步（可综合）
//   标准 VESA 时序（像素时钟 25.175MHz）：
//     行：可见 640 + 前肩 16 + 同步 96 + 后肩 48 = 800
//     场：可见 480 + 前肩 10 + 同步  2 + 后肩 33 = 525
//   板载 50MHz，这里用"25MHz 时钟使能"（每 2 个 50MHz 时钟推进一个像素），
//   不另起一个时钟域，便于时序约束。hsync/vsync 低电平有效。
//============================================================================
module ch5_vga_sync(
    input  wire      clk,
    input  wire      rst_n,
    output reg       hsync,
    output reg       vsync,
    output reg       video_on,
    output reg [9:0] pixel_x,   // 0..799
    output reg [9:0] pixel_y,  // 0..524
    output reg       pxl_en     // 25MHz 像素使能（1 拍脉冲）
);
    // 行参数
    localparam H_VIS  = 10'd640;
    localparam H_FP   = 10'd16;
    localparam H_SYNC = 10'd96;
    localparam H_BP   = 10'd48;
    localparam H_TOT  = H_VIS + H_FP + H_SYNC + H_BP;  // 800
    // 场参数
    localparam V_VIS  = 10'd480;
    localparam V_FP   = 10'd10;
    localparam V_SYNC = 10'd2;
    localparam V_BP   = 10'd33;
    localparam V_TOT  = V_VIS + V_FP + V_SYNC + V_BP;  // 525

    reg        div;
    reg [9:0]  h_cnt;
    reg [9:0]  v_cnt;

    // 50MHz -> 25MHz 使能（每两拍一个像素点）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div    <= 1'b0;
            pxl_en <= 1'b0;
        end else begin
            div    <= ~div;
            pxl_en <= (div == 1'b1);
        end
    end

    // 行/场计数器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_cnt <= 10'd0;
            v_cnt <= 10'd0;
        end else if (pxl_en) begin
            if (h_cnt == H_TOT - 1) begin
                h_cnt <= 10'd0;
                if (v_cnt == V_TOT - 1)
                    v_cnt <= 10'd0;
                else
                    v_cnt <= v_cnt + 1'b1;
            end else begin
                h_cnt <= h_cnt + 1'b1;
            end
        end
    end

    // 同步信号（低有效）与显示区
    always @(*) begin
        hsync    = ~((h_cnt >= H_VIS + H_FP) && (h_cnt < H_VIS + H_FP + H_SYNC));
        vsync    = ~((v_cnt >= V_VIS + V_FP) && (v_cnt < V_VIS + V_FP + V_SYNC));
        video_on = (h_cnt < H_VIS) && (v_cnt < V_VIS);
        pixel_x  = h_cnt;
        pixel_y  = v_cnt;
    end
endmodule
