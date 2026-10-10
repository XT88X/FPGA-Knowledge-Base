//==============================================================================
// uart_rx.v  —  可综合：UART 接收模块（8N1）
// 关键技术：
//   1) 两级寄存器同步 rx_in，防止亚稳态；
//   2) 16 倍过采样：OV_DIV = CLK/(BAUD*16)，例 50M/(115200*16) ≈ 27；
//   3) 检测起始位下降沿后，把过采样计数器复位，在每位中点(过采样计数=7)采样；
//   4) 中点附近连续 3 个过采样样本做"多数表决"，抗毛刺；
//   5) 停止位中点采到 0 -> frame_err=1（帧错误）。
//==============================================================================
`default_nettype none

module uart_rx #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer BAUD_RATE    = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_in,        // 串行接收线（空闲高电平）
    output reg  [7:0] rx_data,      // 并行收到的字节
    output reg        rx_valid,     // 收完一字节，拉高 1 拍
    output reg        frame_err     // 停止位不是高电平 -> 帧错误
);

    // 16 倍过采样分频
    localparam integer OV_DIV = CLK_FREQ_HZ / (BAUD_RATE * 16);

    // ---- 输入同步（防亚稳态）----
    reg rx_meta, rx_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx_in;
            rx_sync <= rx_meta;
        end
    end

    // ---- 16x 过采样 tick 发生器 ----
    reg [15:0] ov_cnt;      // 计数到 OV_DIV-1 产生 samp_tick
    reg        samp_tick;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ov_cnt    <= 16'd0;
            samp_tick <= 1'b0;
        end else if (!active_q) begin
            ov_cnt    <= 16'd0;
            samp_tick <= 1'b0;
        end else if (ov_cnt >= OV_DIV[15:0] - 1) begin
            ov_cnt    <= 16'd0;
            samp_tick <= 1'b1;
        end else begin
            ov_cnt    <= ov_cnt + 1'b1;
            samp_tick <= 1'b0;
        end
    end

    // ---- 接收状态 ----
    reg        active_q;     // 正在接收一帧
    reg [3:0]  bit_phase;    // 过采样相位 0..15
    reg [3:0]  bit_idx;      // 0=起始位, 1..8=数据位, 9=停止位
    reg [2:0]  samp_sh;      // 最近 3 个过采样样本（用于多数表决）

    // 多数表决：3 取 2
    wire bit_vote = (samp_sh[2] & samp_sh[1]) |
                    (samp_sh[2] & samp_sh[0]) |
                    (samp_sh[1] & samp_sh[0]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_q  <= 1'b0;
            bit_phase <= 4'd0;
            bit_idx   <= 4'd0;
            samp_sh   <= 3'b111;
            rx_data   <= 8'd0;
            rx_valid  <= 1'b0;
            frame_err <= 1'b0;
        end else begin
            rx_valid <= 1'b0;
            if (!active_q) begin
                // 空闲：检测起始位下降沿（rx_sync 由 1->0）
                bit_phase <= 4'd0;
                bit_idx   <= 4'd0;
                samp_sh   <= 3'b111;
                if (rx_sync == 1'b0) begin
                    active_q <= 1'b1;
                end
            end else if (samp_tick) begin
                // 移位记录最近 3 个样本
                samp_sh   <= {samp_sh[1:0], rx_sync};
                bit_phase <= bit_phase + 1'b1;
                if (bit_phase == 4'd15) begin
                    bit_phase <= 4'd0;
                    bit_idx   <= bit_idx + 1'b1;
                end
                // 每位中点 = bit_phase==7，用多数表决采样
                if (bit_phase == 4'd7) begin
                    case (bit_idx)
                    4'd0: begin                       // 起始位中点
                        if (bit_vote == 1'b1) begin   // 起点不是低 -> 错误，放弃
                            active_q  <= 1'b0;
                            frame_err <= 1'b1;
                        end
                    end
                    4'd1,4'd2,4'd3,4'd4,4'd5,4'd6,4'd7,4'd8: begin
                        rx_data[bit_idx - 4'd1] <= bit_vote;  // LSB 先收
                    end
                    4'd9: begin                       // 停止位中点
                        if (bit_vote == 1'b0)
                            frame_err <= 1'b1;
                        rx_valid <= 1'b1;
                        active_q <= 1'b0;
                    end
                    default: active_q <= 1'b0;
                    endcase
                end
            end
        end
    end

endmodule

`default_nettype wire
