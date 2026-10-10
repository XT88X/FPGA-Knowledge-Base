//==============================================================================
// spi_master.v  —  可综合：SPI 主机（CPOL/CPHA 可配，MSB 先出）
// 说明：
//   - SCLK 由系统时钟分频：HALF = CLK/(2*SCLK_HZ)，sclk 每 HALF 个时钟翻转一次。
//   - CPOL：sclk 空闲电平（0 或 1）。
//   - CPHA=0（本仓库 OLED 使用）：数据在 sclk 空闲相位准备好(mosi)，
//     在 sclk 有效相位中间采样 miso。
//   - 片选 cs_n 传输期间拉低，结束拉高。
// 例：50MHz、SCLK=1MHz -> HALF=25，sclk 周期 50 个时钟 = 1us。
//==============================================================================
`default_nettype none

module spi_master #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer SCLK_HZ     = 1_000_000,
    parameter         CPOL         = 1'b0,
    parameter         CPHA        = 1'b0
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] tx_data,    // 待发送字节
    input  wire       tx_valid,   // 请求发送一字节
    output wire       tx_ready,   // 空闲可接收新字节
    output reg        sclk,
    output reg        mosi,
    input  wire       miso,
    output reg  [7:0] rx_data,   // 收到的字节
    output reg        cs_n
);

    localparam integer HALF = CLK_FREQ_HZ / (2 * SCLK_HZ);

    localparam S_IDLE  = 0;
    localparam S_LOAD  = 1;
    localparam S_SETUP  = 2;   // sclk 空闲相位，mosi 保持稳定
    localparam S_SAMPLE= 3;   // sclk 有效相位，采样 miso、移位
    localparam S_DONE  = 4;

    reg [2:0]  state;
    reg [15:0] div_cnt;
    reg [2:0]  bit_cnt;
    reg [7:0]  shift;
    reg        ready_q;

    wire cpha_unused = CPHA;   // 保留参数接口；本实现面向 CPHA=0

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= S_IDLE;
            div_cnt <= 16'd0;
            bit_cnt <= 3'd0;
            shift   <= 8'd0;
            sclk    <= CPOL;
            mosi    <= 1'b0;
            cs_n    <= 1'b1;
            rx_data <= 8'd0;
            ready_q <= 1'b1;
        end else begin
            case (state)
            S_IDLE: begin
                sclk    <= CPOL;
                cs_n    <= 1'b1;
                ready_q <= 1'b1;
                if (tx_valid) begin
                    shift   <= tx_data;
                    ready_q <= 1'b0;
                    state   <= S_LOAD;
                    div_cnt <= 16'd0;
                end
            end
            S_LOAD: begin
                cs_n  <= 1'b0;
                sclk  <= CPOL;
                mosi  <= shift[7];      // MSB 先出
                bit_cnt <= 3'd0;
                div_cnt <= 16'd0;
                state <= S_SETUP;
            end
            S_SETUP: begin
                cs_n <= 1'b0;
                sclk <= CPOL;           // 空闲相位：mosi 已稳定
                if (div_cnt >= HALF[15:0] - 1) begin
                    div_cnt <= 16'd0;
                    state   <= S_SAMPLE;
                end else begin
                    div_cnt <= div_cnt + 1'b1;
                end
            end
            S_SAMPLE: begin
                cs_n <= 1'b0;
                sclk <= ~CPOL;          // 有效相位
                if (div_cnt >= HALF[15:0] - 1) begin
                    div_cnt <= 16'd0;
                    rx_data <= {rx_data[6:0], miso};   // 采样 MISO
                    shift   <= {shift[6:0], 1'b0};
                    mosi    <= shift[6];               // 准备下一位
                    bit_cnt <= bit_cnt + 1'b1;
                    if (bit_cnt == 3'd7) state <= S_DONE;
                    else                 state <= S_SETUP;
                end else begin
                    div_cnt <= div_cnt + 1'b1;
                end
            end
            S_DONE: begin
                cs_n    <= 1'b1;
                sclk    <= CPOL;
                ready_q <= 1'b1;
                state   <= S_IDLE;
            end
            default: state <= S_IDLE;
            endcase
        end
    end

    assign tx_ready = ready_q;

endmodule

`default_nettype wire
