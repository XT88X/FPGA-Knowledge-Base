// =============================================================================
// ch4_uart.v — 教学可综合 UART（发送 + 接收，简化波特率）
//
//   帧格式：1 起始位(0) + 8 数据位(LSB first) + 1 停止位(1)。
//   波特率由 BAUD_DIV 分频：每 bit 持续 BAUD_DIV 个 clk。
//   （BAUD_DIV = clk_hz / baud_rate；示例 50MHz/115200 ≈ 434。）
//
//   CPU 接口：
//     we=1 时把 din[7:0] 锁进发送缓冲并开始发送；
//     tx_ready=1 表示发送空闲（可收下一个字节）。
//     rx_done 脉冲表示收到一个字节，dout 为其值。
// =============================================================================
module ch4_uart #(
    parameter BAUD_DIV = 434      // 分频系数（示例值，按实际时钟/波特率改）
)(
    input  wire        clk,
    input  wire        rst_n,

    // CPU 发送接口
    input  wire        we,        // 写发送寄存器
    input  wire [7:0] din,
    output wire        tx_ready,

    // 串行脚
    output reg         tx_o,
    input  wire        rx_i,

    // 接收输出
    output reg  [7:0] dout,
    output reg         rx_done
);

    // ---------------- 发送 ----------------
    localparam TX_IDLE = 3'd0, TX_START = 3'd1, TX_DATA = 3'd2, TX_STOP = 3'd3;
    reg [2:0]  tx_state;
    reg [15:0] tx_cnt;
    reg [2:0]  tx_bit;
    reg [7:0]  tx_shift;

    assign tx_ready = (tx_state == TX_IDLE);

    always @(posedge clk) begin
        if (!rst_n) begin
            tx_state <= TX_IDLE;
            tx_cnt   <= 16'd0;
            tx_bit   <= 3'd0;
            tx_shift <= 8'd0;
            tx_o     <= 1'b1;        // 空闲线为高
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    tx_o <= 1'b1;
                    if (we) begin
                        tx_shift <= din;
                        tx_state <= TX_START;
                        tx_cnt  <= 16'd0;
                        tx_bit  <= 3'd0;
                    end
                end
                TX_START: begin
                    tx_o <= 1'b0;             // 起始位
                    if (tx_cnt == BAUD_DIV-1) begin tx_cnt <= 0; tx_state <= TX_DATA; end
                    else tx_cnt <= tx_cnt + 1'b1;
                end
                TX_DATA: begin
                    tx_o <= tx_shift[0];
                    if (tx_cnt == BAUD_DIV-1) begin
                        tx_cnt <= 0;
                        tx_shift <= {1'b0, tx_shift[7:1]};
                        if (tx_bit == 3'd7) tx_state <= TX_STOP;
                        tx_bit <= tx_bit + 1'b1;
                    end else tx_cnt <= tx_cnt + 1'b1;
                end
                TX_STOP: begin
                    tx_o <= 1'b1;             // 停止位
                    if (tx_cnt == BAUD_DIV-1) begin tx_cnt <= 0; tx_state <= TX_IDLE; end
                    else tx_cnt <= tx_cnt + 1'b1;
                end
                default: tx_state <= TX_IDLE;
            endcase
        end
    end

    // ---------------- 接收（简化：按中位采样）----------------
    localparam RX_IDLE = 2'd0, RX_START = 2'd1, RX_DATA = 2'd2, RX_STOP = 2'd3;
    reg [1:0]  rx_state;
    reg [15:0] rx_cnt;
    reg [2:0]  rx_bit;
    reg [7:0]  rx_shift;

    always @(posedge clk) begin
        if (!rst_n) begin
            rx_state <= RX_IDLE;
            rx_cnt   <= 16'd0;
            rx_bit   <= 3'd0;
            rx_shift <= 8'd0;
            dout     <= 8'd0;
            rx_done  <= 1'b0;
        end else begin
            rx_done <= 1'b0;
            case (rx_state)
                RX_IDLE: begin
                    if (rx_i == 1'b0) rx_state <= RX_START;   // 检测起始位
                end
                RX_START: begin
                    if (rx_cnt == BAUD_DIV/2 - 1) begin        // 中位确认
                        rx_cnt <= 0;
                        rx_state <= RX_DATA;
                        rx_bit <= 0;
                    end else rx_cnt <= rx_cnt + 1'b1;
                end
                RX_DATA: begin
                    if (rx_cnt == BAUD_DIV-1) begin
                        rx_cnt <= 0;
                        rx_shift <= {rx_i, rx_shift[7:1]};
                        if (rx_bit == 3'd7) rx_state <= RX_STOP;
                        rx_bit <= rx_bit + 1'b1;
                    end else rx_cnt <= rx_cnt + 1'b1;
                end
                RX_STOP: begin
                    if (rx_cnt == BAUD_DIV-1) begin
                        rx_cnt  <= 0;
                        dout    <= rx_shift;
                        rx_done <= 1'b1;
                        rx_state <= RX_IDLE;
                    end else rx_cnt <= rx_cnt + 1'b1;
                end
                default: rx_state <= RX_IDLE;
            endcase
        end
    end

endmodule
