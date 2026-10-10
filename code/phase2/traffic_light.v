//==============================================================================
// traffic_light.v  —  可综合：十字路口交通灯（南北/东西，含黄灯）
// 目标器件：通用 Xilinx Artix-7 / Zynq（7 系列）
//
// 状态机（Moore，输出只由当前状态决定）：
//   S_NS_G  : 南北绿、东西红
//   S_NS_Y  : 南北黄、东西红
//   S_EW_G  : 东西绿、南北红
//   S_EW_Y  : 东西黄、南北红
// 顺序循环：NS_G -> NS_Y -> EW_G -> EW_Y -> NS_G ...
// 每个状态维持 T_GREEN / T_YELLOW 个时钟后切换。
//==============================================================================
`default_nettype none

module traffic_light #(
    parameter integer T_GREEN  = 25_000_000,   // 绿灯时长(时钟拍)
    parameter integer T_YELLOW = 5_000_000      // 黄灯时长(时钟拍)
)(
    input  wire clk,
    input  wire rst_n,
    output reg  red_ns,
    output reg  yellow_ns,
    output reg  green_ns,
    output reg  red_ew,
    output reg  yellow_ew,
    output reg  green_ew
);

    localparam S_NS_G = 2'd0;
    localparam S_NS_Y = 2'd1;
    localparam S_EW_G = 2'd2;
    localparam S_EW_Y = 2'd3;

    reg [1:0]  state;
    reg [31:0] cnt;

    // 节拍计数与状态跳转
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_NS_G;
            cnt   <= 32'd0;
        end else begin
            case (state)
                S_NS_G: if (cnt >= T_GREEN-1) begin cnt <= 32'd0; state <= S_NS_Y; end
                        else cnt <= cnt + 1'b1;
                S_NS_Y: if (cnt >= T_YELLOW-1) begin cnt <= 32'd0; state <= S_EW_G; end
                        else cnt <= cnt + 1'b1;
                S_EW_G: if (cnt >= T_GREEN-1) begin cnt <= 32'd0; state <= S_EW_Y; end
                        else cnt <= cnt + 1'b1;
                S_EW_Y: if (cnt >= T_YELLOW-1) begin cnt <= 32'd0; state <= S_NS_G; end
                        else cnt <= cnt + 1'b1;
                default: state <= S_NS_G;
            endcase
        end
    end

    // Moore 输出：互锁——任一方向同一时刻只亮一种灯，且必有红灯
    always @(*) begin
        red_ns    = 1'b0;
        yellow_ns = 1'b0;
        green_ns  = 1'b0;
        red_ew    = 1'b0;
        yellow_ew = 1'b0;
        green_ew  = 1'b0;
        case (state)
            S_NS_G: begin green_ns = 1'b1; red_ew   = 1'b1; end
            S_NS_Y: begin yellow_ns = 1'b1; red_ew = 1'b1; end
            S_EW_G: begin green_ew = 1'b1; red_ns   = 1'b1; end
            S_EW_Y: begin yellow_ew = 1'b1; red_ns = 1'b1; end
            default: red_ew = 1'b1;
        endcase
    end

endmodule

`default_nettype wire
