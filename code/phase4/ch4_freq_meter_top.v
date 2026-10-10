//============================================================================
// ch4_freq_meter_top.v — 数字频率计顶层（可综合）
//   gate_gen -> event_counter -> freq_fsm -> seg7_scan
//   端口按板卡接：clk(50MHz)、rst_n、sig_in(被测信号)、seg[7:0]、sel[5:0]、unit_led[1:0]
//   引脚号不写死，见 code/common/fpga_common.xdc 与 docs/board-adaptation.md。
//============================================================================
module ch4_freq_meter_top #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer GATE_TICKS  = 50_000_000,
    parameter integer HOLD_TICKS  = 5_000_000,
    parameter integer CNT_WIDTH   = 27
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire             sig_in,     // 被测脉冲输入
    output wire [7:0]      seg,        // 数码管段选
    output wire [5:0]      sel,        // 数码管位选
    output wire [1:0]       unit_led    // 单位指示 LED：0 Hz,1 kHz,2 MHz
);
    wire                  gate;
    wire                  gate_done;
    wire [CNT_WIDTH-1:0]  count;
    wire [CNT_WIDTH-1:0]  latched;
    wire                  overflow;
    wire                  latch;
    wire                  clr;
    wire [CNT_WIDTH-1:0]  freq_value;
    wire [1:0]            unit_sel;
    wire [23:0]           bcd_digits;
    wire                  update_stb;

    ch4_gate_gen #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .GATE_TICKS(GATE_TICKS),
        .HOLD_TICKS(HOLD_TICKS)
    ) u_gate (
        .clk(clk), .rst_n(rst_n),
        .gate(gate), .gate_done(gate_done)
    );

    ch4_event_counter #(
        .CNT_WIDTH(CNT_WIDTH)
    ) u_cnt (
        .clk(clk), .rst_n(rst_n), .sig_in(sig_in), .gate(gate),
        .latch(latch), .clr(clr),
        .count(count), .latched(latched), .overflow(overflow)
    );

    ch4_freq_fsm #(
        .CNT_WIDTH(CNT_WIDTH)
    ) u_fsm (
        .clk(clk), .rst_n(rst_n), .gate_done(gate_done), .raw_count(count),
        .latch(latch), .clr(clr), .freq_value(freq_value), .unit_sel(unit_sel),
        .bcd_digits(bcd_digits), .update_stb(update_stb)
    );

    ch4_seg7_scan #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ)
    ) u_seg (
        .clk(clk), .rst_n(rst_n),
        .bcd_digits(bcd_digits), .unit_sel(unit_sel),
        .seg(seg), .sel(sel)
    );

    assign unit_led = unit_sel;
endmodule
