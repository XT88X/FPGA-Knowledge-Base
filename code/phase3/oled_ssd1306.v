//==============================================================================
// oled_ssd1306.v  —  可综合：0.96" 128x64 OLED（SSD1306，4 线 SPI）控制器
// 对外引脚：cs_n / dc(0=命令,1=数据) / sclk / mosi(din)。
// 流程：
//   1) 上电跑初始化命令序列（充电泵开、分辨率、扫描方向、显示开）；
//   2) 空闲时接收 char_wr，按"页/列定位命令 + 8x16 字模数据"写一个字符。
// 字模 ROM：内置数字 0/1 的 8x16 示例字模（上页8列 + 下页8列），
//           其余字符占位为 0，可按需扩展为完整 ASCII 字库。
//==============================================================================
`default_nettype none

module oled_ssd1306 #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer SCLK_HZ     = 1_000_000
)(
    input  wire       clk,
    input  wire       rst_n,
    // 写字符接口
    input  wire [6:0] char_col,    // 列 0..127
    input  wire [2:0] char_page,   // 页 0..7
    input  wire [7:0] char_code,   // ASCII（实现 '0'-'9'）
    input  wire       char_wr,     // 拉高一次：写一个字符
    output wire       busy,
    // OLED 物理引脚
    output wire       oled_cs_n,
    output reg        oled_dc,
    output wire       oled_sclk,
    output wire       oled_mosi
);

    // ---- 与 spi_master 的握手 ----
    wire        spi_ready;
    reg  [7:0]  spi_tx;
    reg         spi_req;
    wire [7:0]  spi_rx_unused;

    spi_master #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .SCLK_HZ    (SCLK_HZ),
        .CPOL       (1'b0),
        .CPHA       (1'b0)
    ) u_spi (
        .clk      (clk),
        .rst_n    (rst_n),
        .tx_data  (spi_tx),
        .tx_valid (spi_req),
        .tx_ready (spi_ready),
        .sclk     (oled_sclk),
        .mosi     (oled_mosi),
        .miso     (1'b0),
        .rx_data  (spi_rx_unused),
        .cs_n     (oled_cs_n)
    );

    // ---- 状态定义 ----
    localparam S_IDLE    = 0;
    localparam S_TX_START = 1;  // 等 spi_ready，发起一次发送
    localparam S_TX_WAIT = 2;  // 等本字节发完

    reg [1:0]  state;
    reg        mode;           // 0=初始化命令, 1=写字符
    reg [5:0]  step;
    reg [6:0]  cur_col;
    reg [2:0]  cur_page;
    reg [7:0]  glyph_idx;

    localparam INIT_LEN = 25;
    localparam CHAR_LEN = 20;

    // 初始化命令序列（dc=0）
    function [7:0] init_cmd;
        input [5:0] idx;
        begin
            case (idx)
            6'd0:  init_cmd = 8'hAE;  // display off
            6'd1:  init_cmd = 8'hD5;  // clock div
            6'd2:  init_cmd = 8'h80;
            6'd3:  init_cmd = 8'hA8;  // multiplex 1/64
            6'd4:  init_cmd = 8'h3F;
            6'd5:  init_cmd = 8'hD3;  // display offset
            6'd6:  init_cmd = 8'h00;
            6'd7:  init_cmd = 8'h40;  // start line = 0
            6'd8:  init_cmd = 8'h8D;  // charge pump
            6'd9:  init_cmd = 8'h14;
            6'd10: init_cmd = 8'h20;  // memory addressing mode
            6'd11: init_cmd = 8'h00;
            6'd12: init_cmd = 8'hA1;  // segment remap
            6'd13: init_cmd = 8'hC8;  // com scan dir
            6'd14: init_cmd = 8'hDA;  // com pins
            6'd15: init_cmd = 8'h12;
            6'd16: init_cmd = 8'h81;  // contrast
            6'd17: init_cmd = 8'hCF;
            6'd18: init_cmd = 8'hD9;  // pre-charge
            6'd19: init_cmd = 8'hF1;
            6'd20: init_cmd = 8'hDB;  // vcomh
            6'd21: init_cmd = 8'h40;
            6'd22: init_cmd = 8'hA4;  // resume to gddr
            6'd23: init_cmd = 8'hA6;  // normal display
            6'd24: init_cmd = 8'hAF;  // display on
            default: init_cmd = 8'h00;
            endcase
        end
    endfunction

    // ---- 字模 ROM：数字 0/1 的 8x16（上页8列 + 下页8列），其余占位 ----
    reg [7:0] font_rom [0:159];
    integer   fi;
    initial begin
        font_rom[ 0]=8'h3C; font_rom[ 1]=8'h42; font_rom[ 2]=8'h81; font_rom[ 3]=8'h81;
        font_rom[ 4]=8'h81; font_rom[ 5]=8'h81; font_rom[ 6]=8'h42; font_rom[ 7]=8'h3C;
        font_rom[ 8]=8'h3C; font_rom[ 9]=8'h42; font_rom[10]=8'h81; font_rom[11]=8'h81;
        font_rom[12]=8'h81; font_rom[13]=8'h81; font_rom[14]=8'h42; font_rom[15]=8'h3C;
        font_rom[16]=8'h08; font_rom[17]=8'h18; font_rom[18]=8'h08; font_rom[19]=8'h08;
        font_rom[20]=8'h08; font_rom[21]=8'h08; font_rom[22]=8'h08; font_rom[23]=8'h7F;
        font_rom[24]=8'h08; font_rom[25]=8'h18; font_rom[26]=8'h08; font_rom[27]=8'h08;
        font_rom[28]=8'h08; font_rom[29]=8'h08; font_rom[30]=8'h08; font_rom[31]=8'h7F;
        for (fi = 32; fi < 160; fi = fi + 1) font_rom[fi] = 8'h00;
    end

    // 字符编码 -> 字模索引：'0'-'9' -> 0..9
    always @(*) begin
        if (char_code >= 8'h30 && char_code <= 8'h39)
            glyph_idx = char_code - 8'h30;
        else
            glyph_idx = 8'd0;
    end

    // ---- 写字符时根据 step 计算要发的字节与 dc ----
    // step 0..2: 定位命令；3..10: 上页8列数据；11: 下页命令；12..19: 下页8列数据
    reg [7:0] char_byte;
    reg       char_dc;
    always @(*) begin
        case (step)
        6'd0:  begin char_byte = {4'h0, cur_col[3:0]};     char_dc = 1'b0; end
        6'd1:  begin char_byte = {4'h1, cur_col[7:4]};     char_dc = 1'b0; end
        6'd2:  begin char_byte = {4'hB, cur_page};         char_dc = 1'b0; end
        6'd3,6'd4,6'd5,6'd6,6'd7,6'd8,6'd9,6'd10:
               begin char_byte = font_rom[glyph_idx*16 + (step-3)]; char_dc = 1'b1; end
        6'd11: begin char_byte = {4'hB, cur_page + 3'd1};  char_dc = 1'b0; end
        6'd12,6'd13,6'd14,6'd15,6'd16,6'd17,6'd18,6'd19:
               begin char_byte = font_rom[glyph_idx*16 + 8 + (step-12)]; char_dc = 1'b1; end
        default: begin char_byte = 8'h00; char_dc = 1'b0; end
        endcase
    end

    // 当前要发送的字节：初始化用 init_cmd，写字符用 char_byte
    wire [7:0] cur_byte = mode ? char_byte : init_cmd(step);
    wire       cur_dc   = mode ? char_dc   : 1'b0;

    // ---- 主 FSM ----
    reg init_done;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            mode      <= 1'b0;
            step      <= 6'd0;
            spi_req   <= 1'b0;
            spi_tx    <= 8'd0;
            oled_dc  <= 1'b0;
            cur_col  <= 7'd0;
            cur_page <= 3'd0;
            init_done <= 1'b0;
        end else begin
            case (state)
            S_IDLE: begin
                spi_req <= 1'b0;
                if (!init_done) begin
                    // 初始化阶段：继续发命令
                    state <= S_TX_START;
                end else if (char_wr) begin
                    cur_col  <= char_col;
                    cur_page <= char_page;
                    step     <= 6'd0;
                    mode     <= 1'b1;
                    state    <= S_TX_START;
                end
            end

            S_TX_START: begin
                spi_tx  <= cur_byte;
                oled_dc <= cur_dc;
                if (spi_ready) begin
                    spi_req <= 1'b1;
                    state   <= S_TX_WAIT;
                end
            end

            S_TX_WAIT: begin
                spi_req <= 1'b0;
                if (spi_ready) begin
                    // 本字节发完，推进 step
                    if (mode == 1'b0) begin
                        if (step < INIT_LEN - 1) begin
                            step  <= step + 1'b1;
                            state <= S_TX_START;
                        end else begin
                            init_done <= 1'b1;   // 初始化全部发完
                            step     <= 6'd0;
                            state    <= S_IDLE;
                        end
                    end else begin
                        if (step < CHAR_LEN - 1) begin
                            step  <= step + 1'b1;
                            state <= S_TX_START;
                        end else begin
                            mode  <= 1'b0;       // 写字符结束
                            step  <= 6'd0;
                            state <= S_IDLE;
                        end
                    end
                end
            end

            default: state <= S_IDLE;
            endcase
        end
    end

    assign busy = (state != S_IDLE) || !init_done;

endmodule

`default_nettype wire
