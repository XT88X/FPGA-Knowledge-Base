//============================================================================
// ch4_freq_fsm.v — 测量控制状态机 + 量程/单位自动切换 + BCD 转换（可综合）
//   状态：等闸门结束 -> 锁存 raw_count -> 清零计数器 -> 保持显示。
//   量程判定（1s 闸门时计数值 = 频率 Hz）：
//       >= 1_000_000  -> MHz，数值除以 1_000_000
//       >= 1_000       -> kHz，数值除以 1_000
//       否则           -> Hz
//   再用双 dabble（double-dabble）把量程缩放后的整数转 6 位 BCD，
//   供数码管动态扫描显示。
//============================================================================
module ch4_freq_fsm #(
    parameter integer CNT_WIDTH = 27
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  gate_done,   // 闸门结束脉冲
    input  wire [26:0]           raw_count,   // 事件计数器当前值
    output reg                   latch,        // 给 event_counter 的锁存脉冲
    output reg                   clr,           // 给 event_counter 的清零脉冲
    output wire [26:0]           freq_value,   // 量程缩放后的频率整数
    output wire [1:0]            unit_sel,     // 0=Hz, 1=kHz, 2=MHz
    output wire [23:0]           bcd_digits,  // 6 位 BCD：[23:20]...[3:0]
    output reg                   update_stb    // 新结果就绪脉冲
);
    localparam S_IDLE  = 2'd0;
    localparam S_LATCH = 2'd1;
    localparam S_CLR   = 2'd2;
    localparam S_HOLD  = 2'd3;

    reg [1:0] state;
    reg [CNT_WIDTH-1:0] value;   // 锁存的原始计数（=频率 Hz）

    // ---- 状态机：产生 latch / clr / update，并锁存 value ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_IDLE;
            latch      <= 1'b0;
            clr        <= 1'b0;
            value      <= {CNT_WIDTH{1'b0}};
            update_stb <= 1'b0;
        end else begin
            latch      <= 1'b0;
            clr        <= 1'b0;
            update_stb <= 1'b0;
            case (state)
                S_IDLE:
                    if (gate_done) state <= S_LATCH;
                S_LATCH: begin
                    value      <= raw_count;
                    latch      <= 1'b1;
                    update_stb <= 1'b1;
                    state      <= S_CLR;
                end
                S_CLR: begin
                    clr   <= 1'b1;
                    state <= S_HOLD;
                end
                S_HOLD:
                    state <= S_IDLE;   // 保持显示，等待下一次 gate_done
                default: state <= S_IDLE;
            endcase
        end
    end

    // ---- 量程/单位判定（组合逻辑，基于已锁存的 value）----
    reg [1:0]           unit_r;
    reg [CNT_WIDTH-1:0] scaled_r;
    always @(*) begin
        if (value >= 27'd1_000_000) begin
            unit_r   = 2'd2;
            scaled_r = value / 27'd1_000_000;
        end else if (value >= 27'd1_000) begin
            unit_r   = 2'd1;
            scaled_r = value / 27'd1_000;
        end else begin
            unit_r   = 2'd0;
            scaled_r = value;
        end
    end
    assign unit_sel   = unit_r;
    assign freq_value = scaled_r;

    // ---- 双 dabble：二进制 -> 6 位 BCD（组合逻辑）----
    integer bi;
    reg [23:0] bcd_tmp;
    reg [CNT_WIDTH-1:0] bin_tmp;
    always @(*) begin
        bin_tmp = scaled_r;
        bcd_tmp = 24'd0;
        for (bi = 0; bi < CNT_WIDTH; bi = bi + 1) begin
            if (bcd_tmp[3:0]    >= 4'd5) bcd_tmp[3:0]    = bcd_tmp[3:0]    + 4'd3;
            if (bcd_tmp[7:4]    >= 4'd5) bcd_tmp[7:4]    = bcd_tmp[7:4]    + 4'd3;
            if (bcd_tmp[11:8]   >= 4'd5) bcd_tmp[11:8]   = bcd_tmp[11:8]   + 4'd3;
            if (bcd_tmp[15:12]  >= 4'd5) bcd_tmp[15:12]  = bcd_tmp[15:12]  + 4'd3;
            if (bcd_tmp[19:16]  >= 4'd5) bcd_tmp[19:16]  = bcd_tmp[19:16]  + 4'd3;
            if (bcd_tmp[23:20]  >= 4'd5) bcd_tmp[23:20]  = bcd_tmp[23:20]  + 4'd3;
            {bcd_tmp, bin_tmp} = {bcd_tmp, bin_tmp} << 1;
        end
    end
    assign bcd_digits = bcd_tmp;
endmodule
