# CONVENTIONS — FPGA 知识系统数据约定（冻结）

> 本文件是多人并行写章节的**唯一契约**。任何人新增章节都按本文件操作；
> 不要改动"共享只读"文件，不要改 fragment JSON 字段名。

## 1. 目录与职责

```
FPGA-Knowledge-Base/
├── index.html                  # 【生成产物·根目录双击打开】勿手改
├── templates/index.template.html# 【共享只读】页面模板，含 /*__KB_DATA__*/ 占位符
├── scripts/
│   ├── build.py               # 【共享只读】构建：fragment+md+code+svg -> index.html + knowledge-base.json
│   ├── check_verilog.py        # Verilog 结构校验
│   └── CONVENTIONS.md          # 本文件
├── data/
│   ├── fragments/              # 每章一个 JSON：phaseN-chM.json
│   └── knowledge-base.json     # 【生成产物】聚合 JSON，勿手改
├── docs/phaseN/*.md           # 章节讲解 Markdown
├── code/phaseN/*.v            # 章节 Verilog（可综合 + testbench）
├── assets/phaseN/*.svg         # 章节图解（手写内联 SVG）
├── code/common/fpga_common.xdc # 【共享只读】通用引脚约束模板
├── docs/board-adaptation.md    # 【共享只读】板卡适配方法论
└── tools/tools.md              # 【共享只读】工具总清单
```

## 2. 冻结的 fragment JSON schema

每章一个文件：`data/fragments/phase{阶段}-ch{章序}.json`（如 `phase1-ch2.json`）。
字段固定如下，**不得增删字段名**：

| 字段 | 类型 | 说明 |
|---|---|---|
| `chapterId` | string | 如 `"1.2"`，与文件名对应 |
| `phase` | int | 阶段号 1..5 |
| `slug` | string | 英文短名，如 `"hdl-blink"` |
| `title` | string | 章节标题 |
| `summary` | string | 一句话摘要（卡片列表用） |
| `doc` | string | 讲解 Markdown 相对路径，如 `"docs/phase1/ch2-hdl-blink.md"` |
| `code` | array | `{file, type:"verilog", role:"synthesizable"|"testbench", title}` |
| `diagrams` | array | `{file:"assets/phaseN/xxx.svg", title, caption}`（svg 原文内联） |
| `tools` | array | `{name, url, required:true/false, note}`（url 必须官方真实地址） |
| `tasks` | array | `{id:"task-{phase}-{ch}-{序号}", text}`，id 沿用原追踪器规范 |
| `cards` | array | `{q, a, tags:[...]}`，建议 ≥8 条（助教问答语料） |
| `quiz` | array | `{q, options:[4项], answer:索引(0..3), explain}`，每章 ≥3 题 |

## 3. 命名 / 路径 / 转义规则

- 模块名一律**小写加下划线**（`led_blink`）；参数/localparam 用大写（`CLK_FREQ_HZ`）。check_verilog 据此区分模块与参数。
- `.v` 文件：可综合模块放 `code/phaseN/xxx.v`，testbench 以 `tb_` 开头。
- 路径相对仓库根；build.py 会把 doc md 渲染成 HTML、把 code 读入并 HTML 转义、把 svg 原文内联进 KB。
- 不要在 fragment 里写死 `file://` 或外链图片；图解一律 `assets/phaseN/*.svg`。
- Key/Token 严禁入仓库：在线 AI 的 baseURL/key/model 只存浏览器 localStorage（key=`fpga-ai-config`）。

## 4. 共享只读文件（禁止并行分片改动）

`index.html`、`data/knowledge-base.json`、`tools/tools.md`、`scripts/build.py`、
`templates/index.template.html`、`code/common/fpga_common.xdc`、`docs/board-adaptation.md`。
要改这些，单独提一个 commit，不要和章节内容混在一起。

## 5. 新增一章最小示例（照抄即可）

新建 `data/fragments/phase2-ch1.json`：

```json
{
  "chapterId": "2.1",
  "phase": 2,
  "slug": "combo-logic",
  "title": "组合逻辑设计",
  "summary": "与或非、3-8 译码器、MUX、竞争冒险入门。",
  "doc": "docs/phase2/ch1-combo.md",
  "code": [
    {"file": "code/phase2/decoder38.v", "type": "verilog", "role": "synthesizable", "title": "decoder38.v — 3-8 译码器"},
    {"file": "code/phase2/tb_decoder38.v", "type": "verilog", "role": "testbench", "title": "tb_decoder38.v"}
  ],
  "diagrams": [
    {"file": "assets/phase2/decoder38.svg", "title": "3-8 译码器结构", "caption": "3 输入译出 8 路独热输出。"}
  ],
  "tools": [
    {"name": "Vivado 下载", "url": "https://www.xilinx.com/support/download.html", "required": true, "note": "ML Standard 免费版"}
  ],
  "tasks": [
    {"id": "task-2-1-1", "text": "用 Verilog 实现 3-8 译码器"},
    {"id": "task-2-1-2", "text": "驱动一位数码管显示 0-F"}
  ],
  "cards": [
    {"q": "什么是组合逻辑？", "a": "输出只由当前输入决定、无记忆、无时钟的电路。", "tags": ["组合逻辑"]}
  ],
  "quiz": [
    {"q": "组合逻辑的输出取决于？", "options": ["仅当前输入", "时钟沿", "历史状态", "复位"], "answer": 0, "explain": "组合逻辑无记忆，输出仅由当前输入决定。"}
  ]
}
```

然后：
1. 写 `docs/phase2/ch1-combo.md`、`code/phase2/decoder38.v`、`code/phase2/tb_decoder38.v`、`assets/phase2/decoder38.svg`；
2. 运行 `python3 scripts/build.py` 重新生成 index.html；
3. 运行 `python3 scripts/check_verilog.py code/phase2` 确认通过；
4. 单独 commit：`phase2: 2.1 组合逻辑设计 知识+代码+入库`。

---

## 6. 通关考卷题库 schema（data/exam/phaseN.json）

每阶段一个文件：`data/exam/phase{阶段}.json`。build.py 会聚合进 `KB.exams[phase]`。
引擎为纯函数 `window.FPGAExam`（compose/shufflePaper/gradePaper/unlockState），与 DOM 解耦。

```json
{
  "phase": 1,
  "passScore": 85,
  "questions": [
    {"id":"p1-001","ch":"1.1","type":"single","pts":5,
     "q":"题干","options":["选项A","选项B","选项C","选项D"],
     "answer": 0, "explain":"解析"},
    {"id":"p1-002","ch":"1.2","type":"multi","pts":5,
     "q":"多选题干","options":["甲","乙","丙","丁"],
     "answer": [0,2], "explain":"全对才得分"},
    {"id":"p1-003","ch":"1.3","type":"judge","pts":5,
     "q":"判断题干（正确/错误）","answer": true, "explain":"解析"},
    {"id":"p1-004","ch":"1.1","type":"fill","pts":5,
     "q":"填空题干","answer": ["可接受写法1","写法2"], "explain":"归一化判分"}
  ]
}
```

规则：
- `type`：`single`（answer=正确下标）/ `multi`（answer=正确下标数组，全对得分）/ `judge`（answer=true/false，选项固定 正确/错误）/ `fill`（answer=可接受写法数组，判分去空白/标点/大小写后命中任一即对）。
- 组卷：每次随机抽 20 题（每题 5 分=100），按章节 round-robin 均衡 + 章内随机。
- 乱序：single/multi/judge 抽卷后随机打乱选项顺序，answer 自动重映射，题答严格对应。
- 通过线 `passScore`=85；阶段 N 解锁条件 = N==1 或 阶段 N-1 已通过。
- 存档 key `fpga-exam-state`：`{unlocked:{}, passed:{}, best:{}}`，与 `fpga-learning-progress` 互不干扰；重置按钮会一并清空。
- 题库量建议每阶段 ≥30 题（每章 ≥10），四种题型都要有，内容必须与该阶段 docs/code 严格一致，answer 必须正确。

---

## 7. 科目一刷题题库 schema（data/drill/<cat>.json）

每个知识大类一个文件，如 `data/drill/digital.json`：

```json
{
  "cat": "digital",
  "catName": "数字电路与电平标准",
  "cards": [
    {"id":"dig-c01","sub":"数制与编码","title":"二进制与十六进制","body":"速记正文，可用\\n与·/① 分点","src":"可选：手册名/URL"}
  ],
  "questions": [
    {"id":"dig-001","cat":"digital","sub":"数制与编码","type":"single","q":"…","options":["…","…","…","…"],"answer":1,"explain":"…","src":"可选"},
    {"id":"…","type":"multi","q":"…","options":[≥4],"answer":[0,2],"explain":"…"},
    {"id":"…","type":"judge","q":"…","answer":true,"explain":"…"},
    {"id":"…","type":"fill","q":"…","answer":["写法1","写法2"],"explain":"…"}
  ]
}
```

规则：
- id 全局唯一，大类英文前缀（dig-/sw-/hw-/sim-/tm-/proto-/adv-）；`sub` 是专项/组卷均衡的分组键。
- 判分语义同阶段考卷：single=下标；multi=下标数组全对；judge=布尔；fill=可接受写法数组（归一化判分）。drill 题不需要 pts。
- build.py 自动聚合：`KB.drill.categories`（卡片按大类）、`KB.drill.questions`（打平带 cat/catName/sub）、`KB.drill.allQuestions`（drill + 阶段课程 exam，exam 题 id 加前缀 `exam-p{阶段}-{原id}`、cat="phasecourse"、sub="阶段N"）。
- localStorage：刷题记录 `fpga-drill-state`={done,lastCorrect,wrong,fav,last}；模考成绩 `fpga-mock-state`={global,globalN,specials,各专项次数}；与 fpga-learning-progress / fpga-exam-state 隔离，重置按钮一并清空。
- 纯函数 `window.FPGADrill`：practiceSeq/practiceRandom/filterBy/composePool/isCorrect/recordAnswer/statsOf/levelGlobal。
- 题量建议：每大类 ≥30 题（每 sub ≥5），卡片 ≥8 张，四题型齐全；单选/多选选项≥4、多选≥2 正确项；内容事实准确、题答对应。
