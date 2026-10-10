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
