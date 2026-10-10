//==============================================================================
// uart_echo_top.v  —  可综合：串口回显顶层
//   FPGA 收到一字节 -> 锁存 -> 通过 tx 原样发回电脑。
//   用 echo_req 锁存请求，避免 tx 忙时丢失 rx_valid 脉冲。
//==============================================================================
`default_nettype none

module uart_echo_top #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer BAUD_RATE    = 115200
)(
    input  wire clk,
    input  wire rst_n,
    input  wire rx_in,     // 接 USB-UART 的 RX
    output wire tx_out      // 接 USB-UART 的 TX
);

    wire [7:0] rx_data;
    wire       rx_valid;
    wire       frame_err;
    wire       tx_ready;

    reg [7:0] echo_data;
    reg       echo_req;

    // 收到字节 -> 锁存并请求回发
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            echo_data <= 8'd0;
            echo_req  <= 1'b0;
        end else if (rx_valid) begin
            echo_data <= rx_data;
            echo_req  <= 1'b1;
        end else if (tx_ready && echo_req) begin
            echo_req  <= 1'b0;
        end
    end

    uart_rx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) u_rx (
        .clk       (clk),
        .rst_n     (rst_n),
        .rx_in     (rx_in),
        .rx_data   (rx_data),
        .rx_valid  (rx_valid),
        .frame_err (frame_err)
    );

    uart_tx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) u_tx (
        .clk      (clk),
        .rst_n    (rst_n),
        .tx_data  (echo_data),
        .tx_valid (echo_req),
        .tx_ready (tx_ready),
        .tx_out   (tx_out)
    );

endmodule

`default_nettype wire
