# 工具与环境总览（Vivado 流程）

> 访问日期：**2026-10-10**。以下 URL 均为 AMD/Xilinx 或厂商官方页面。
> 本知识系统**只围绕 Xilinx/AMD Vivado**（适用 Artix-7 / Zynq，7 系列通用），不涉及 Intel Quartus。

## 必装

| 工具 | 说明 | 官方地址 |
|---|---|---|
| **AMD Vivado ML Edition（设计套件）** | 综合 + 实现 + 比特流生成 + 内置仿真器（Vivado Simulator）。当前公开版本 **Vivado 2025.2**。 | 下载总页：https://www.xilinx.com/support/download.html <br>开发工具下载(2025.2)：https://www.amd.com/en/support/downloads/adaptive-socs-and-fpgas/development-tools/2025-2.html <br>产品页：https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html |
| **Vivado ML Standard（免费 WebPACK 等价版）** | 对 Artix-7 / Zynq-7000 常用型号**免费、无需 License**（2025.2 及更早版本；自 2026.1 起改为分级授权模型，免费额度以官方最新说明为准）。安装时选 "Vivado ML Standard" 即可。 | 授权说明(Licensing FAQ)：https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/licensing-faq.html |
| **电缆 / JTAG 驱动** | 下载线（Platform Cable USB / Digilent JTAG 等）的驱动。**Vivado 安装器自带电缆驱动**，安装时勾选 "Install Cable Drivers"；Digilent 板卡另需 Digilent Adept Runtime。 | Digilent 安装指南：https://digilent.com/reference/programmable-logic/guides/installing-vivado-and-vitis <br>FTDI 驱动（USB-JTAG 桥）：https://ftdichip.com/drivers/ |

## 可选

| 工具 | 说明 | 官方地址 |
|---|---|---|
| **Vivado Simulator（内置）** | 行为/时序仿真，无需单独安装；用 testbench 跑波形。文档随 Vivado DocNav。 | 随 Vivado 安装 |
| **Vivado Lab Edition** | 仅下载调试的轻量版，无需 License；机器跑不动完整版时可用。 | 同下载总页 https://www.xilinx.com/support/download.html |
| **在线 AI 助教增强（OpenAI 兼容 API）** | 在本页 index.html 右下角助教设置里填 baseURL/Key/model，仅存浏览器本地。 | 预设见下 |

### 在线 AI 助教预设端点（OpenAI 兼容 Chat Completions）

| 服务商 | baseURL | 模型示例 | 文档 |
|---|---|---|---|
| DeepSeek | `https://api.deepseek.com` | `deepseek-chat` | https://api-docs.deepseek.com/ |
| 火山方舟·豆包 | `https://ark.cn-beijing.volces.com/api/v3` | 接入点模型 ID（如 `doubao-...` 或 `ep-xxxxxxxx`） | https://docs.volcengine.com/docs/82379/1099455 |
| OpenAI | `https://api.openai.com/v1` | `gpt-4o-mini` 等 | https://platform.openai.com/docs |

> Key 只保存在你自己浏览器的 localStorage，**不会写入本仓库任何文件**；不填或请求失败时自动降级到离线检索，不影响使用。

## 安装要点速记

1. 注册免费 AMD 账号，下载 Vivado WebPACK/ML Standard 安装器。
2. 安装时产品选 **Artix-7 / Zynq-7000** 支持包，勾选 **Install Cable Drivers**。
3. ML Standard 版无需申请 License；若装了高级版需 License Manager 申请免费 WebPACK 授权。
4. 接好下载线后打开 Vivado **Hardware Manager**，能识别到 FPGA 即环境就绪。

<!-- AUTO-AGGREGATE-TOOLS -->

## 附录：全章节工具 / 资料链接汇总（由 data/fragments 自动聚合）

> 下列链接均为各章撰写时经 general_search/web.fetch 联网核实的官方/权威地址，访问日期 **2026-10-10**；版本与链接可能随官方更新变化，失效时以对应官网为准。

| 章节 | 工具 / 资料 | 类型 | 链接 | 说明 |
|---|---|---|---|---|
| 1.1 | AMD Vivado ML Edition 下载（2025.2） | 必装 | https://www.xilinx.com/support/download.html | 免费 ML Standard 版即可，支持 Artix-7/Zynq。 |
| 1.1 | Vivado 授权说明（ML Standard 免 License） | 必装 | https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/licensing-faq.html | 2025.2 及更早 Standard 版无需 License。 |
| 1.1 | 电缆/JTAG 驱动安装指南 | 参考 | https://digilent.com/reference/programmable-logic/guides/installing-vivado-and-vitis | 有开发板再装；纯仿真可略过。 |
| 1.2、2.1、2.2、2.3、2.4、3.1、3.2、3.3、3.4、3.5、4.1、4.4、4.5 | 通用引脚约束模板 fpga_common.xdc | 必装 | ../code/common/fpga_common.xdc | 相对本仓库；按开发板替换 PACKAGE_PIN。 |
| 1.2、2.1 | 板级适配方法（board-adaptation.md） | 必装 | ../docs/board-adaptation.md | 如何找正点原子/野火板的参考引脚。 |
| 1.3 | Vivado 内置 Simulator | 必装 | https://www.xilinx.com/support/download.html | 随 Vivado ML Standard 安装，无需额外下载。 |
| 2.1、2.2、2.3、2.4 | AMD Vivado ML Edition 下载 | 必装 | https://www.xilinx.com/support/download.html | 免费 ML Standard 版即可，支持 Artix-7/Zynq；访问日期 2026-10。 |
| 3.1、4.4、4.5 | 板级适配方法 board-adaptation.md | 必装 | ../docs/board-adaptation.md | 按开发板替换 UART 引脚号。 |
| 3.2 | SSD1306 产品页（Solomon Systech 官方） | 必装 | https://www.solomon-systech.com/product/ssd1306/ | 访问日期 2026-10-10；官方 datasheet 需向厂方索取。 |
| 3.2 | SSD1306 datasheet PDF（Mouser 托管） | 参考 | https://www.mouser.com/datasheet/2/813/SSD1306-2490209.pdf | 访问日期 2026-10-10；命令集与显存定义以此为准。 |
| 3.4 | Project F - VGA video timings | 参考 | https://projectf.io/posts/video-timings-vga-720p-1080p/ | 访问日期 2026-10-10；VGA 时序参数参考。 |
| 4.1 | PG065 Clocking Wizard Product Guide (v6.0) | 必装 | https://docs.amd.com/v/u/en-US/pg065-clocking-wizard | 访问日期 2026-10-10；MMCM/PLL IP 配置手册。 |
| 4.1 | Clocking Wizard 产品页 | 参考 | https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/clocking_wizard.html | 访问日期 2026-10-10。 |
| 4.2 | PG058 Block Memory Generator Product Guide (v8.4) | 必装 | https://docs.amd.com/v/u/en-US/pg058-blk-mem-gen | 访问日期 2026-10-10。 |
| 4.2 | PG057 FIFO Generator Product Guide (v13.2) | 必装 | https://docs.amd.com/v/u/en-US/pg057-fifo-generator | 访问日期 2026-10-10。 |
| 4.2 | Block Memory Generator 产品页 | 参考 | https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/block_memory_generator.html | 访问日期 2026-10-10。 |
| 4.3 | UG903 Vivado Using Constraints (v2022.2) | 必装 | https://docs.amd.com/v/u/en-US/ug903-vivado-using-constraints | 访问日期 2026-10-10；XDC 约束权威手册。 |
| 4.3 | UG938 Design Analysis and Closure Techniques (v2020.2) | 参考 | https://www.xilinx.com/support/documents/sw_manuals/xilinx2020_2/ug938-vivado-design-analysis-closure-tutorial.pdf | 访问日期 2026-10-10。 |
| 4.3 | 时序收敛专题导航 dh0006 | 参考 | https://www.xilinx.com/content/xilinx/en/support/documentation-navigation/design-hubs/dh0006-vivado-design-analysis-and-timing-closure-hub.html | 访问日期 2026-10-10。 |
| 4.4、4.5 | AMD/Xilinx Vivado 下载 | 必装 | https://www.xilinx.com/support/download.html | ML Standard 免费版；访问日期 2026-10。 |
| 4.5 | VGA 640x480 时序参考（MIT 6.111） | 参考 | https://web.mit.edu/6.111/www/s2004/NEWKIT/vga.shtml | 行 800/场 525、25.175MHz 像素时钟；访问日期 2026-10。 |
| 5.1 | RISC-V 非特权指令集规范 | 必装 | https://docs.riscv.org/reference/isa/unpriv/unpriv-index.html | 访问于 2026-10；RV32I 官方定义。 |
| 5.1 | xPack RISC-V 嵌入式 GCC（安装文档） | 必装 | https://xpack-dev-tools.github.io/riscv-none-elf-gcc-xpack/docs/install/ | 交叉工具链预编译二进制；访问于 2026-10。 |
| 5.1 | xPack RISC-V GCC GitHub 发布页 | 参考 | https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack | 访问于 2026-10。 |
| 5.1 | PicoRV32 开源软核 | 参考 | https://github.com/YosysHQ/picorv32 | 极小 RV32I/E/M/C 核；访问于 2026-10。 |
| 5.1 | NEORV32 开源 SoC | 参考 | https://github.com/stnolting/neorv32 | 类单片机 RISC-V SoC；访问于 2026-10。 |
| 5.2 | AXI Reference Guide (UG1037) | 必装 | https://docs.amd.com/r/en-US/ug1037-vivado-axi-reference-guide | AMD 官方 AXI 协议参考；访问于 2026-10。 |
| 5.2 | Creating and Packaging Custom IP (UG1118) | 必装 | https://docs.amd.com/r/en-US/ug1118-vivado-creating-packaging-custom-ip | 自定义 IP 打包流程；访问于 2026-10。 |
| 5.2 | Designing IP Subsystems Using IPI (UG994) | 参考 | https://docs.amd.com/r/en-US/ug994-vivado-ip-subsystems | IP Integrator 子系统设计；访问于 2026-10。 |
| 5.2 | AXI Interconnect Product Guide (PG059) | 参考 | https://www.xilinx.com/support/documents/ip_documentation/axi_interconnect/v2_1/pg059-axi-interconnect.pdf | AXI 互连 IP 手册；访问于 2026-10。 |
| 5.3 | AMD Vitis HLS 产品页(可选进阶) | 参考 | https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vitis/vitis-hls.html | 用 C/C++ 综合成硬件；可选，本仓库手写 Verilog 为主。访问于 2026-10。 |
| 5.3 | Vitis HLS 用户指南 UG1399 (PDF) | 参考 | https://www.xilinx.com/support/documents/sw_manuals/xilinx2022_2/ug1399-vitis-hls.pdf | HLS pipeline/unroll/dataflow pragma 参考。访问于 2026-10。 |
| 5.4 | RT-Thread 官网（OS 进阶参考） | 参考 | https://www.rt-thread.org/index.html | 开源 RTOS；本 SoC 当前跑裸机，OS 为进阶方向。访问于 2026-10。 |
| 5.4 | RT-Thread GitHub | 参考 | https://github.com/RT-Thread/rt-thread | RTOS 源码与移植 BSP。访问于 2026-10。 |
| 5.4 | NEORV32 开源类单片机 SoC | 参考 | https://github.com/stnolting/neorv32 | 自带 UART/GPIO/Timer/IRQ 的参考软核。访问于 2026-10。 |
