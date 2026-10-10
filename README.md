# FPGA 从入门到高级 · 完整知识系统库

> 一个**自包含**的 FPGA 学习系统：打开 `index.html` 即可获得「章节知识讲解 + 可运行 Verilog 代码 + Testbench + 工具软件下载链接 + 交互式 AI 助教」，无需再到处搜资料。
>
> 工具链：**Xilinx / AMD Vivado**（Artix-7 / Zynq 通用）· 开发板：通用（引脚约束给出通用模板与主流开发板适配说明）

## 怎么用（30 秒上手）

1. 下载或克隆本仓库：`git clone https://github.com/XT88X/FPGA-Knowledge-Base.git`
2. 双击打开根目录 **`index.html`**（推荐 Chrome / Edge），无需联网、无需安装任何依赖
3. 按阶段学习，每章包含：知识详解 → 代码 → 仿真 → 上板 → 工具下载 → AI 助教提问
4. 学习进度自动保存在浏览器本地；成就徽章随阶段解锁

## AI 助教（混合模式）

- **开箱即用（离线）**：内置 FPGA 知识库检索，能回答章节问题、并**主动向你提问 / 出小测验**，学习不枯燥
- **在线增强（可选）**：在网页设置中填入你自己的大模型 API Key（OpenAI 兼容接口，如 DeepSeek / 豆包 / OpenAI），即可获得真正的在线智能答疑与个性化教学。Key 只保存在你本地浏览器，不上传

## 学习路线（5 阶段 / 20+ 章 / 50+ 实践）

| 阶段 | 主题 | 周期 | 核心产出 |
| --- | --- | --- | --- |
| 1 | 启蒙入门 | 1–3 天 | 点亮第一盏灯，跑通「设计→仿真→上板」全流程 |
| 2 | 基础逻辑设计 | 1 周 | 组合/时序逻辑、消抖、状态机 |
| 3 | 接口与通信 | 2 周 | UART、SPI/OLED、PWM、VGA、数字钟 |
| 4 | 系统级开发 | 2–4 周 | IP 核/PLL、BRAM/FIFO、时序约束、频率计、贪吃蛇 |
| 5 | 高阶进阶 | 长期 | RISC-V 软核、AXI 外设、硬件加速、自制 SoC |

## 目录结构

```
FPGA-Knowledge-Base/
├── index.html              # 单文件交互式知识系统主应用（含 AI 助教）
├── docs/                   # 各章节知识详解（Markdown），phase1~5
├── code/                   # 各章节 Verilog 源码 + Testbench，phase1~5
├── tools/                  # 工具软件清单、版本说明与官方下载链接
├── data/
│   └── knowledge-base.json # 网页内置离线知识库（供 AI 助教检索 / 出测验）
├── assets/                 # 图片、时序图、原理图、截图
└── scripts/                # 辅助脚本（构建知识库、校验等）
```

## 工具软件（详见 [tools/tools.md](tools/tools.md)）

- AMD **Vivado**（设计 / 综合 / 实现 / 下载）
- AMD **Vitis**（嵌入式 C 开发，阶段 5）
- 仿真：Vivado 自带仿真器（入门）/ ModelSim-Intel、Icarus Verilog + GTKWave（轻量替代）
- 串口助手、驱动等配套工具

> 所有下载均指向**官方地址**，安装与 License（含免费 WebPACK 说明）在工具章节逐步指引。

## 内容建设说明

本知识库采用「分章迭代、持续同步」方式建设：每完成一章（知识 + 代码 + 工具链接 + 入库 AI 知识库）即提交推送到 GitHub，可在 Commit 历史查看进度。

## 许可

仅供个人学习使用。引用的工具与 IP 版权归各自所有者。
