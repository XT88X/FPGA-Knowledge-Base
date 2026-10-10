//==============================================================================
// uart_tx.v  —  可综合：UART 发送模块（8N1：1 起始位 + 8 数据位 + 1 停止位）
// 波特率分频：每 BIT_DIV 个系统时钟发 1 个比特。
//   BIT_DIV = CLK_FREQ_HZ / BAUD_RATE
//   例：50MHz / 115200 ≈ 434（即每位约 434 个时钟，实测波特率略低 ~115193）。
// 状态机：IDLE -> START(发0) -> DATA(LSB 先出，共8位) -> STOP(发1) -> IDLE。
//==============================================================================
`default_nettype none

module uart_tx #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer BAUD_RATE    = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] tx_data,    // 待发送字节（上升沿被锁存）
    input  wire       tx_valid,    // 置高请求发送一字节（需 tx_ready=1）
    output wire       tx_ready,   // 空闲，可接收新字节
    output reg        tx_out       // 串行发送线，空闲为高电平
);

    // 每位所需的系统时钟数（整数分频）
    localparam integer BIT_DIV = CLK_FREQ_HZ / BAUD_RATE;

    localparam S_IDLE  = 0;
    localparam S_START = 1;
    localparam S_DATA  = 2;
    localparam S_STOP  = 3;

    reg [15:0] baud_cnt;
    reg        baud_tick;
    reg [1:0]  state;
    reg [2:0]  bit_cnt;
    reg [7:0]  shift;
    reg        ready_q;

    // ---- 波特率 tick：仅在发送期间计数，每 BIT_DIV 个时钟产生一拍 tick ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_cnt  <= 16'd0;
            baud_tick <= 1'b0;
        end else if (state == S_IDLE) begin
            baud_cnt  <= 16'd0;
            baud_tick <= 1'b0;
        end else if (baud_cnt >= BIT_DIV[15:0] - 1) begin
            baud_cnt  <= 16'd0;
            baud_tick <= 1'b1;
        end else begin
            baud_cnt  <= baud_cnt + 1'b1;
            baud_tick <= 1'b0;
        end
    end

    // ---- 发送 FSM ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= S_IDLE;
            bit_cnt <= 3'd0;
            shift   <= 8'd0;
            tx_out  <= 1'b1;      // 空闲高电平
            ready_q <= 1'b1;
        end else begin
            case (state)
            S_IDLE: begin
                tx_out  <= 1'b1;
                ready_q <= 1'b1;
                bit_cnt <= 3'd0;
                if (tx_valid) begin
                    shift   <= tx_data;
                    ready_q <= 1'b0;
                    state   <= S_START;
                end
            end
            S_START: begin
                tx_out <= 1'b0;            // 起始位：拉低
                if (baud_tick) state <= S_DATA;
            end
            S_DATA: begin
                tx_out <= shift[0];        // LSB 先发
                if (baud_tick) begin
                    shift   <= {1'b0, shift[7:1]};
                    bit_cnt <= bit_cnt + 1'b1;
                    if (bit_cnt == 3'd7) state <= S_STOP;
                end
            end
            S_STOP: begin
                tx_out <= 1'b1;            // 停止位：拉高
                if (baud_tick) begin
                    state   <= S_IDLE;
                    ready_q <= 1'b1;
                end
            end
            default: state <= S_IDLE;
            endcase
        end
    end

    assign tx_ready = ready_q;

endmodule

`default_nettype wire
