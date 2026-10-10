// =============================================================================
// ch2_axi_lite_gpio.v — 可综合 AXI4-Lite 从机：自定义 GPIO/LED 外设
//
//   寄存器映射（32-bit，基地址由 Vivado 地址编辑器分配）：
//     偏移 0x00  GPIO_DATA   (R/W)  写 -> 驱动 led_o；读 -> 返回当前锁存值
//     偏移 0x04  GPIO_INPUT  (R)    读 -> 返回 sw_i（按键/拨码开关）
//     偏移 0x08  VERSION     (R)    读 -> 固定版本号 0x20261010
//
//   握手严格遵循 AXI4-Lite：
//     * VALID 由驱动方拉高并保持，直到 READY 同时拉高（握手那拍被采样）；
//     * READY 由本设计用寄存 FSM 产生，保证不违例；
//     * AW/W 两通道可同时或先后到达，FSM 分别锁存地址与数据；
//     * 写响应 B 通道返回 OKAY(2'b00)；读 R 通道返回数据与 OKAY。
// =============================================================================
module ch2_axi_lite_gpio #(
    parameter C_AXI_ADDR_WIDTH = 32,
    parameter [31:0] VERSION_VALUE = 32'h2026_1010
)(
    input  wire                       s_axi_aclk,
    input  wire                       s_axi_aresetn,

    // 写地址通道 AW
    input  wire [C_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                       s_axi_awvalid,
    output reg                        s_axi_awready,

    // 写数据通道 W
    input  wire [31:0]                s_axi_wdata,
    input  wire [3:0]                 s_axi_wstrb,
    input  wire                       s_axi_wvalid,
    output reg                        s_axi_wready,

    // 写响应通道 B
    output reg  [1:0]                 s_axi_bresp,
    output reg                        s_axi_bvalid,
    input  wire                       s_axi_bready,

    // 读地址通道 AR
    input  wire [C_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire                       s_axi_arvalid,
    output reg                        s_axi_arready,

    // 读数据通道 R
    output reg  [31:0]                s_axi_rdata,
    output reg  [1:0]                 s_axi_rresp,
    output reg                        s_axi_rvalid,
    input  wire                       s_axi_rready,

    // 外设 I/O
    output reg  [3:0]                 led_o,
    input  wire [3:0]                 sw_i
);

    // 寄存器偏移（按字地址 [3:2] 译码）
    localparam ADDR_GPIO_DATA  = 2'b00;   // 0x00
    localparam ADDR_GPIO_INPUT = 2'b01;   // 0x04
    localparam ADDR_VERSION     = 2'b10;   // 0x08

    reg [1:0]  wr_addr;
    reg [31:0] wr_data;

    // 写 FSM
    localparam W_IDLE   = 2'd0;
    localparam W_WAIT_W = 2'd1;   // 已锁 AW，等 W
    localparam W_WAIT_A = 2'd2;   // 已锁 W，等 AW
    localparam W_RESP   = 2'd3;   // 回写响应
    reg [1:0] wstate;

    // 读 FSM
    localparam R_IDLE = 1'd0;
    localparam R_WAIT = 1'd1;
    reg       rstate;
    reg [1:0] rd_addr;

    // ---- 写 FSM（含寄存器写）----
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            wstate        <= W_IDLE;
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            led_o         <= 4'h0;
        end else begin
            case (wstate)
                W_IDLE: begin
                    s_axi_awready <= 1'b1;
                    s_axi_wready  <= 1'b1;

                    if (s_axi_awvalid && s_axi_wvalid) begin
                        // AW/W 同时到达：一拍完成写
                        if (s_axi_awaddr[3:2] == ADDR_GPIO_DATA)
                            led_o <= s_axi_wdata[3:0];
                        s_axi_awready <= 1'b0;
                        s_axi_wready  <= 1'b0;
                        s_axi_bvalid  <= 1'b1;
                        s_axi_bresp   <= 2'b00;
                        wstate        <= W_RESP;
                    end else if (s_axi_awvalid) begin
                        wr_addr       <= s_axi_awaddr[3:2];
                        s_axi_awready <= 1'b0;
                        wstate        <= W_WAIT_W;
                    end else if (s_axi_wvalid) begin
                        wr_data       <= s_axi_wdata;
                        s_axi_wready  <= 1'b0;
                        wstate        <= W_WAIT_A;
                    end
                end

                W_WAIT_W: begin
                    s_axi_wready <= 1'b1;
                    if (s_axi_wvalid) begin
                        if (wr_addr == ADDR_GPIO_DATA)
                            led_o <= s_axi_wdata[3:0];
                        s_axi_wready <= 1'b0;
                        s_axi_bvalid <= 1'b1;
                        s_axi_bresp  <= 2'b00;
                        wstate       <= W_RESP;
                    end
                end

                W_WAIT_A: begin
                    s_axi_awready <= 1'b1;
                    if (s_axi_awvalid) begin
                        if (s_axi_awaddr[3:2] == ADDR_GPIO_DATA)
                            led_o <= wr_data[3:0];
                        s_axi_awready <= 1'b0;
                        s_axi_bvalid  <= 1'b1;
                        s_axi_bresp   <= 2'b00;
                        wstate        <= W_RESP;
                    end
                end

                W_RESP: begin
                    s_axi_bvalid <= 1'b1;
                    if (s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        wstate       <= W_IDLE;
                    end
                end

                default: wstate <= W_IDLE;
            endcase
        end
    end

    // ---- 读 FSM ----
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            rstate       <= R_IDLE;
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= 32'h0;
        end else begin
            case (rstate)
                R_IDLE: begin
                    s_axi_arready <= 1'b1;
                    if (s_axi_arvalid) begin
                        rd_addr       <= s_axi_araddr[3:2];
                        s_axi_arready  <= 1'b0;
                        s_axi_rvalid  <= 1'b1;
                        s_axi_rresp   <= 2'b00;
                        case (s_axi_araddr[3:2])
                            ADDR_GPIO_DATA:  s_axi_rdata <= {28'h0, led_o};
                            ADDR_GPIO_INPUT: s_axi_rdata <= {28'h0, sw_i};
                            ADDR_VERSION:    s_axi_rdata <= VERSION_VALUE;
                            default:         s_axi_rdata <= 32'hDEAD_BEEF;
                        endcase
                        rstate <= R_WAIT;
                    end
                end

                R_WAIT: begin
                    if (s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        rstate       <= R_IDLE;
                    end
                end

                default: rstate <= R_IDLE;
            endcase
        end
    end

endmodule
