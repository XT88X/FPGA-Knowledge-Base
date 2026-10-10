##==========================================================================
## fpga_common.xdc  —  通用引脚约束模板（Xilinx 7 系列 Artix-7 / Zynq）
##--------------------------------------------------------------------------
## 用法：
##   1) 本文件所有引脚号（PACKAGE_PIN）与电平标准（IOSTANDARD）都是占位，
##      必须按你手里那块开发板的「官方原理图 / 主 XDC」替换，禁止照搬。
##   2) 在 Vivado 里：Add Sources -> Constraints -> 把本文件加入工程，
##      或直接复制其中对应段落到你自己的 top.xdc。
##   3) 时钟周期约束是综合/实现时序分析的基础，务必按板载晶振频率填写。
##   4) 各板卡时钟/按键/LED/串口引脚的适配方法见 docs/board-adaptation.md。
##==========================================================================

##--------------------------------------------------------------------------
## 1. 系统时钟（示例：50 MHz 晶振，周期 20 ns）
##    把 SYS_CLK 改成你顶层模块的时钟端口名；PACKAGE_PIN 按板卡替换。
##--------------------------------------------------------------------------
create_clock -period 20.000 -name sys_clk [get_ports clk]
set_property PACKAGE_PIN [替换为板载时钟引脚，例如 E19] [get_ports clk]
set_property IOSTANDARD  LVCMOS33 [get_ports clk]

##--------------------------------------------------------------------------
## 2. 复位按键 / 按键输入（示例：1 个复位键，低有效）
##    按键默认外接上拉，按下为低；如需上拉电阻可加 PULLUP。
##--------------------------------------------------------------------------
set_property PACKAGE_PIN [替换为复位按键引脚] [get_ports rst_n]
set_property IOSTANDARD  LVCMOS33 [get_ports rst_n]
set_property PULLUP true [get_ports rst_n]

##--------------------------------------------------------------------------
## 3. LED（示例：4 个用户 LED）
##--------------------------------------------------------------------------
set_property PACKAGE_PIN [替换 LED0 引脚] [get_ports {led[0]}]
set_property PACKAGE_PIN [替换 LED1 引脚] [get_ports {led[1]}]
set_property PACKAGE_PIN [替换 LED2 引脚] [get_ports {led[2]}]
set_property PACKAGE_PIN [替换 LED3 引脚] [get_ports {led[3]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {led[*]}]

##--------------------------------------------------------------------------
## 4. UART 串口（示例：USB-UART，TX/RX 交叉连接到 PC）
##    txd/rxd 是 FPGA 视角；波特率在 RTL 里用时钟分频实现。
##--------------------------------------------------------------------------
set_property PACKAGE_PIN [替换 UART_TX 引脚] [get_ports txd]
set_property PACKAGE_PIN [替换 UART_RX 引脚] [get_ports rxd]
set_property IOSTANDARD  LVCMOS33 [get_ports {txd rxd}]

##--------------------------------------------------------------------------
## 5. 数码管（可选，示例：段选 8 位 + 位选 6 位）
##    共阴/共阳由硬件决定，段码电平逻辑随之相反，按板卡原理图确认。
##--------------------------------------------------------------------------
# set_property PACKAGE_PIN [替换] [get_ports {seg[0]}] ...
# set_property IOSTANDARD LVCMOS33 [get_ports {seg[*]}]

##--------------------------------------------------------------------------
## 6. VGA（可选，示例：RGB 各 4 位 + 行场同步）
##--------------------------------------------------------------------------
# set_property PACKAGE_PIN [替换] [get_ports {vga_r[0]}] ...
# set_property IOSTANDARD LVCMOS33 [get_ports {vga_*}]

##--------------------------------------------------------------------------
## 7. 常用例外约束（可选）：异步输入不作时序分析
##    按键/串口接收等异步信号，避免 Vivado 报 setup 违例。
##--------------------------------------------------------------------------
set_property INPUT_DELAY 0.0 [get_ports rst_n]
set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets {*}]
