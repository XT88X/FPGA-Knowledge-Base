# 4.2 BRAM 与 FIFO 缓存

系统级设计里，数据很少"随产随用"：收发速度不匹配、两个时钟域、要先攒一批再处理——都需要一块**片上缓存**。FPGA 里最大的片上存储就是 **BRAM**，而最常用的缓存结构就是 **FIFO**。本节讲清 BRAM 原理、同步/异步 FIFO，以及异步 FIFO 如何靠**格雷码**安全地跨时钟域传数据。

## 一、块存储器 BRAM 原理

Artix-7 里有两种片上存储资源（见 `bram_structure.svg`）：

| | Block RAM (BRAM) | Distributed RAM (LUT RAM) |
|---|---|---|
| 本质 | 专用存储块（每块 36Kb，可拆成两个 18Kb） | 用 LUT 当小存储 |
| 容量 | 大（几十~几百 Kb） | 小（几十 bit~几 Kb） |
| 读 | 同步读（寄存输出） | 可异步读 |
| 用途 | FIFO、帧缓冲、大查表、队列 | 小 FIFO、小移位寄存器 |

**BRAM 三种端口模式**：

- **单口 (Single Port)**：一个端口，同一时刻只能读或写。
- **简单双口 (Simple Dual Port)**：A 口只写、B 口只读——最常用，正好匹配 FIFO。
- **真双口 (True Dual Port)**：A、B 两口都可独立读写。

**如何"推断"BRAM**：不用直接例化原语，只要写出特定写法的数组，Vivado 会自动映射到 BRAM。关键写法（本仓库 `sfifo.v` 即如此）：

```verilog
reg [DATA_WIDTH-1:0] ram [0:DEPTH-1];
always @(posedge clk) begin
    if (we) ram[addr] <= din;        // 同步写
end
// 同步读：下一拍给出 ram[raddr]
```

写成这样综合器就会把它识别成 Block RAM；若写得不像（比如组合读、带异步复位 ram），可能被降级成分布式 RAM 甚至触发器。

## 二、FIFO 的数据组织

FIFO（First-In-First-Out，先进先出）就是一块**环形缓冲 + 两个指针**（见 `fifo_organization.svg`）：

- **写指针 wr_ptr**：指向下一个可写位置，写一个就 +1，到头回绕。
- **读指针 rd_ptr**：指向下一个可读位置，读一个就 +1。
- **empty**：wr_ptr == rd_ptr（没数据可读）。
- **full**：写指针追到读指针一圈。实现技巧是指针多存一位：最高位相反、低位相等即满。
- **count**：wr_ptr - rd_ptr = 当前数据个数。

### 同步 FIFO（单时钟）

读写共用一个时钟，逻辑最简单：在同一个 `clk` 下根据 `wr_en/rd_en` 更新两个指针。本仓库 `sfifo.v` 就是同步 FIFO（8bit×16 深，可改参数），提供 `empty/full/almost_full/count`。`tb_sfifo.v` 验证了写满→再写被忽略→读空→数据顺序正确→回环。

### 异步 FIFO（双时钟）

读写各用一个时钟（如写 50MHz、读 25MHz），这才是跨时钟域传数据的主角。

## 三、异步 FIFO 与格雷码跨时钟域

**问题**：读写指针是多 bit 的二进制数，要跨到对方时钟域去判断 empty/full。但二进制指针加 1 时**多位同时跳变**（如 011→100），对方时钟在中间采，可能采到乱七八糟的值。

**解法——格雷码 (Gray Code)**：相邻两个数之间**只有 1 bit 不同**。

```
二进制: 000 001 010 011 100 101 ...
格雷码: 000 001 011 010 110 111 ...   (每次只变一位)
```

二进制转格雷码：`gray = bin ^ (bin >> 1)`。

跨域流程（见 `afifo_gray_cdc.svg`）：

1. 写域把写指针转成格雷码，**打两拍同步器**送到读域 → 读域用它和自己的读格雷码比，判断 `empty`。
2. 读域把读指针格雷码**打两拍**送到写域 → 写域用它判断 `full`。
3. 因为格雷码每次只变一位，跨域采样最多采到"旧值或新值"，绝不会采到跳变中间态；再配两级同步器打拍，亚稳态被吸收。

本仓库 `afifo.v` 就是经典格雷码异步 FIFO（双口 RAM + 二进制/格雷指针 + 两级同步 + empty/full），`tb_afifo.v` 用 50MHz 写、25MHz 读验证 16 个数据完整读出、顺序正确。

> 为什么是"打两拍"而不是一拍？第一拍可能进入亚稳态，第二拍让它稳定下来——这就是阶段2 按键消抖里同步器的思路，对多 bit 格雷码同样适用。

## 四、纯 RTL 还是官方 IP？

| 场景 | 建议 |
|---|---|
| 学习原理、小深度 FIFO、单时钟 | 纯 RTL（本节代码） |
| 产品级、大深度、异步、要 FWFT/标志齐全 | Vivado IP：Block Memory Generator、FIFO Generator |

**何时必须用 IP**：深度大、要精确的可编程 almost 阈值、FWFT(First-Word Fall-Through)、标准复位时序、或综合器没把数组推断成 BRAM 时。纯 RTL 异步 FIFO 在工程上可用，但产品级建议直接调 IP 并让 Vivado 做 CDC 检查。

## 五、Vivado IP 调用步骤（可照做）

### Block Memory Generator (PG058)

1. IP Catalog 搜 `Block Memory Generator`，双击。
2. **Basic** 页：Interface Type 选 `Native`；Memory Type 选 `Simple Dual Port RAM`（一只写一只读）；Write Width/Read Width 填数据位宽；Depth 填深度。
3. **Port A 写 / Port B 读**页：使能、复位、输出寄存器按需勾选；Operating Mode 保持 "Write First"/"Read First"。
4. OK → Generate，例化模板里端口典型为 `clka/addina/dina/ena/wea` 与 `clkb/addinb/doutb`。

### FIFO Generator (PG057)

1. IP Catalog 搜 `FIFO Generator`。
2. **Native** 页：FIFO Implementation 选 `Independent Clocks - Block RAM`（异步 FIFO）；Read Mode 选 Standard / FWFT。
3. 填 Write Width/Depth；勾选必要标志位 `Full/Empty/Almost_Full/Almost_Empty/Data_Count`。
4. OK → Generate。异步 FIFO 的端口分两组：写组 `wr_clk/wr_en/din/full`，读组 `rd_clk/rd_en/dout/empty`。

### 上板注意

- IP 会自动生成约束（generated clock 等），一般不用手写；综合后跑 `report_clocks` 和 `report_cdc` 检查跨域。
- 本仓库 `sfifo.v/afifo.v` 是**纯 RTL 行为模型**，可仿真可综合；上板大容量/产品级设计建议替换为上述 IP。

## 六、官方手册（已核实，访问日期 2026-10-10）

- **PG058 Block Memory Generator Product Guide (v8.4)**：https://docs.amd.com/v/u/en-US/pg058-blk-mem-gen （产品页：https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/block_memory_generator.html ）
- **PG057 FIFO Generator Product Guide (v13.2)**：https://docs.amd.com/v/u/en-US/pg057-fifo-generator （产品页：https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/fifo_generator.html ）
- 跨域时序约束相关见 4.3 的 **UG903**。
