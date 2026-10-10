# =============================================================================
# ch3_timing_example.xdc — 4.3 时序约束示例（通用模板，引脚为占位）
# -----------------------------------------------------------------------------
# 说明：
#   * 本文件是"怎么写约束"的示例，真实引脚请按你的开发板修改，
#     并复用 code/common/fpga_common.xdc 里的引脚/电平约束。
#   * 时钟周期按通用 50MHz = 20ns 示例。
#   * 本文件不编造任何板卡引脚号；PACKAGE_PIN 用占位 <PIN_*>，上板前替换。
# 参考手册：UG903 Vivado Using Constraints（见章节文档链接）。
# =============================================================================

# ---------------------------------------------------------------------------
# 1) 主时钟约束（create_clock）——最基本、必写
#    板载 50MHz 晶振接在 clk_in1 引脚，周期 20ns。
# ---------------------------------------------------------------------------
create_clock -period 20.000 -name clk_in1 [get_ports clk_in1]

# 对应引脚与电平（占位；实际按板子填，通常已在 fpga_common.xdc 里）：
set_property PACKAGE_PIN <PIN_CLK>      [get_ports clk_in1]
set_property IOSTANDARD LVCMOS33        [get_ports clk_in1]

# ---------------------------------------------------------------------------
# 2) 生成时钟（create_generated_clock）
#    若用 MMCM/PLL IP，IP 一般自动生成；此处手写示例：
#    假设 clk_mmcm_out 是由 clk_in1 经 MMCM 倍频 2 倍得到的 100MHz。
#    真实工程里用 Clocking Wizard IP 后无需手写，综合后 report_clocks 查看。
# ---------------------------------------------------------------------------
# create_generated_clock -name clk_100m -source [get_pins mmcm_inst/CLKIN1] \
#     -multiply_by 2 [get_pins mmcm_inst/CLKOUT0]

# ---------------------------------------------------------------------------
# 3) 输入/输出延迟（set_input_delay / set_output_delay）
#    描述相对时钟，外部器件数据到达/要求稳定的时间，单位 ns。
# ---------------------------------------------------------------------------
# 输入：相对 clk_in1，外部数据在时钟沿前后 3ns 内有效
set_input_delay  -clock clk_in1 3.0 [get_ports data_in*]
# 输出：要求数据相对时钟沿偏移最大 2ns 送出
set_output_delay -clock clk_in1 2.0 [get_ports {led* data_out*}]

# 输出引脚/电平占位（按板子替换）：
set_property PACKAGE_PIN <PIN_LED0> [get_ports {led*}]
set_property IOSTANDARD LVCMOS33   [get_ports {led*}]

# ---------------------------------------------------------------------------
# 4) 时序例外约束（timing exceptions）
#    set_false_path：绝对不需要检查时序的路径（如异步复位、跨 CDC 的格雷码外的慢信号）
#    set_multicycle_path：需要多个时钟周期才能到达的路径
#    set_clock_groups：两个完全异步、互不交互的时钟组，工具不分析它们之间的路径
# ---------------------------------------------------------------------------
# 异步复位引脚：不必做 reg-to-reg 建立/保持检查
set_false_path -from [get_ports rst_n]

# 两个异步时钟域之间本来就用异步 FIFO 处理；
# 若确认两组时钟完全异步且无直接交互，可声明互斥时钟组（谨慎使用）：
# set_clock_groups -asynchronous -group {clk_in1} -group {clk_other}

# 一个慢使能触发的路径允许 2 个周期（多周期路径）：
# set_multicycle_path 2 -setup -from [get_pins en_reg/C] -to [get_pins data_reg/D]

# =============================================================================
# 上板流程提示：
#   1. 先写 create_clock（主时钟），这是时序分析的根；没它 Vivado 不分析 reg-to-reg。
#   2. 跑完 Synthesis + Implementation，看 Timing Summary：
#      WNS(建立裕量)、TNS、WHS(保持裕量)、THS，全部为 0 或正 = 收敛。
#   3. 若 WNS 为负：按 4.3 文档优化（流水线/降逻辑层级/复制高扇出/约束 IO）。
# =============================================================================
