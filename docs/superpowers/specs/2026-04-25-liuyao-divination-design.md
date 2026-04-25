# 设计文档：六爻卜卦集成（Phase 2）

**日期**：2026-04-25
**作者**：通过 superpowers:brainstorming 与 Claude 协作产出
**范围**：在 Phase 1 编排架构基础上加六爻起卦工具 + AI 解卦 + 输入栏模式选择器
**性质**：功能扩展 + 一次跨页面的"去 emoji"清理

---

## 1. 背景

Phase 1 上线了八字 + 紫微的命理推演（"看人 / 时间线"维度）。但用户日常很多问题是**单一具体事件的决策**：

- "我应该接 X 公司的 offer 吗"
- "她下周会回我消息吗"
- "明天面试结果如何"
- "下个月会不会出差"

这类问题用八字流年只能给到"事业整体走向"层面的答案，**没法对单一事件给出具体回应**。六爻易经卜卦正是为这类"看事 / 此刻"问题设计的传统体系，作为命理 + 紫微的补充，能让用户对 AI 的信任和可用性大幅提升。

### 1.1 与 Phase 1 路线图的关系

`2026-04-25-ai-orchestration-and-divination-systems-design.md` §3 路线图明确：

| Phase | 范围 |
|---|---|
| Phase 1 ✅ | 编排重构 + 八字深度 + 紫微 |
| **Phase 2（本 spec）** | **六爻起卦 + AI 解卦** |
| Phase 3 | 奇门遁甲 + Pro 商业化 |
| Phase 4 | 紫微 12 宫可视化、抽签、黄历 |

Phase 1 ADR-1（用 Tool Use 而非全塞）在设计时就预留了 Phase 2/3 接入点 —— 加新工具不动 orchestrator 核心。

---

## 2. 设计决策（ADR）

下面 6 条决策决定 Phase 2 的形态。

### ADR-1：自实现六爻算法，不用第三方库

**问题**：六爻起卦 + 解卦数据从哪来？

**候选**：
- A. 用 npm 上的 `iching-mcp` / `divination-liuyao` / 类似库
- B. **自实现**

**选 B**。理由：
- 六爻数学非常简单：6 次摇币，每次 3 枚硬币 → 6/7/8/9 之一 → 推出阴/阳/动。整套核心算法约 50-80 行 TypeScript
- 卦辞 / 爻辞是固定文本（64 卦 + 384 爻），打成一份 JSON 即可，~30KB
- 用神 / 应期推算的逻辑虽然复杂但都是确定性规则
- npm 上的库都不是一线维护，依赖一个不稳定的库 vs. 自己写个稳定模块，**自实现的总维护成本反而更低**
- 自实现是 Phase 3 奇门的预演（奇门库更少更不靠谱，必然要自实现）

### ADR-2：后端档 4 全套推演，前端解读停在档 2

**问题**：六爻有 4 个层次（卦义 / 主变卦动爻 / 用神 / 应期），各档 AI 解读复杂度不同。

**决策**：
- 后端 `cast_liuyao` 工具返回**全套档 4 数据**（主卦 + 变卦 + 动爻爻辞 + 用神 + 应期 + 六亲分布）
- 前端 INTERPRETER 解读用**档 2 语言**（主卦现状 + 变卦走向 + 动爻关键节点的形象比喻）
- evidence 卡和 BottomSheet 显示档 3-4 的专业字段（"用神：官鬼·五爻·旺"、"应期：约 1-2 周"）给爱好者

理由：和 Phase 1 一致的"专业层 / 解读层"分离 —— 后端有真材实料保证差异化，前端用人话保证可读性。

### ADR-3：混合触发（默认自动，可强制）

**问题**：用户的问题该走六爻还是命理？

**候选**：
- A. AI 自动判断，全程无感
- B. 用户必须显式触发（命令前缀如 `/卜`）
- **C. 混合：默认 A，可强制为 B**
- D. AI 主动反问"要不要起一卦"

**选 C**。理由：
- 99% 体验是 A 的无感（用户不应该被"该用哪种工具"困扰）
- 出错时（AI 误判时）有兜底强制
- D 太啰嗦，A 太黑盒，B 学习成本高

强制方式：**Tool Picker BottomSheet**（参考 ADR-5），不用键盘前缀命令。

### ADR-4：起卦动画在 chat 气泡内（不开独立 ritual UI）

**问题**：起卦的"仪式感"通过什么形式体现？

**候选**：
- A. 无视觉，AI 直接给结果
- B. 独立 tab / 全屏页面：用户输入问题 → 全屏摇币动画 → 卦象 → AI 解卦
- **C. 在 chat 气泡里嵌入小动画**

**选 C**。理由：
- 用户直接在问道里问问题，不脱离 chat 流（不打断当前对话）
- 仪式感来自 3 秒的视觉过程（6 爻自下而上成爻）+ 古风视觉（朱砂铜钱意象）
- B 的独立 UI 工作量是 C 的 3-4 倍（新 tab、新输入页、新历史页），收益相近
- A 完全没有"卜卦感"，和 Phase 1 的 fortune-telling 工具体感无差别

### ADR-5：用 Tool Picker BottomSheet 替代 `/卜` 命令前缀

**问题**：用户怎么强制切换模式？

**决策**：仿 Gemini / Claude 的 Tool Picker 模式：
- 输入框底部一行加 sliders 风格 icon（不用 `+` —— `+` 留给未来的附件功能）
- 点 icon → BottomSheet 弹起 3 个模式选项：随心问 / 起一卦 / 看命盘
- 选定后输入框底部出现 ModeChip 标记（带 ✕ 可清除）
- 发送一条消息后**自动重置回随心问**（一事一卦传统）

理由：
- 比 `/卜` 命令前缀直观（用户不用学命令）
- 视觉化模式状态（ModeChip 显示）避免"忘了在哪个模式"
- 一发即重置避免连续问问题模式错乱

### ADR-6：全局清理 emoji 装饰

**背景**：Phase 1 在 CoT 卡 / Evidence 卡 / narrateTool() 等地方用了大量装饰性 emoji（🔍 🧠 🪙 🍃 📜 ✨ 等）。用户认为这种 emoji 堆叠是典型的 "AI slop"，稀释了产品的质感。

**决策**：**Phase 2 设计中全部不用 emoji**，并**回头清理 Phase 1 已有的装饰性 emoji**。

例外保留：
- 流式光标 `▍`（typographic 字符，非 emoji）
- 卦象动爻标记 `●`（朱砂圆点，几何符号）
- 任何用户的输入或 AI 输出本身（不限制 LLM 输出 emoji）

替代方案：用 design tokens 的颜色 + 字体重量做视觉锚（朱砂色文字、Georgia 衬线、letterSpacing），保留中式克制的视觉调性。

---

## 3. 数据层设计

### 3.1 HexagramEngine（六爻起卦引擎）

新建 `lib/divination/HexagramEngine.ts`：

```ts
export class HexagramEngine {
  /**
   * 根据问题起一卦
   * - 6 次三币掷出（每次 3 枚硬币 → 6/7/8/9 → 阴/阳 + 是否动）
   * - 推算主卦 / 变卦 / 卦辞 / 爻辞
   * - 根据问题类型取用神 + 推算应期
   */
  cast(opts: CastOptions): HexagramReading;
}

export interface CastOptions {
  question: string;
  questionType?: QuestionType;  // 用神选择依据；不传则 AI 通过分析问题指定
  castTime?: Date;              // 默认 now，用于日辰推算
}

export type QuestionType =
  | 'career'      // 工作/offer/项目 → 用神官鬼
  | 'wealth'      // 钱财/收入/投资 → 用神妻财
  | 'marriage'    // 婚姻/亲密关系 → 用神官鬼(女问)/妻财(男问)
  | 'kids'        // 子女/生育 → 用神子孙
  | 'parents'     // 父母/长辈 → 用神父母
  | 'health'      // 健康 → 用神子孙(他人)/世爻(自己)
  | 'event'       // 通用事件类 → 用神看具体
  | 'general';

export interface HexagramReading {
  question: string;
  castTime: string;             // ISO 时间
  castGanZhi: {
    day: string;                // 日辰，例 "丙午"
    month: string;              // 月建
    hour: string;               // 时辰
  };

  benGua: GuaInfo;              // 主卦
  bianGua: GuaInfo;             // 变卦（无动爻时 = benGua）
  changingYao: number[];        // 哪些爻动（1-6，无动爻则空数组）
  yaoCi: { yao: number; text: string }[];  // 仅动爻爻辞

  yongShen: YongShenAnalysis;
  yingQi: YingQiAnalysis;
  liuQin: Record<1|2|3|4|5|6, LiuQin>;     // 6 爻六亲分配
}

export interface GuaInfo {
  name: string;                 // "水山蹇"
  code: number;                 // 1-64
  yao: ('阴' | '阳')[];          // 初爻→上爻
  guaCi: string;                // 卦辞
  upperGong: string;            // 上卦宫名（用于六亲分配）
  lowerGong: string;
}

export interface YongShenAnalysis {
  type: LiuQin;                 // 用神类型（官鬼/子孙/...）
  yaoIndex: number;             // 在第几爻
  wuXing: WuXing;
  state: '旺' | '相' | '休' | '囚' | '死';
  interactions: string[];        // 与日辰/月建/动爻的关系
}

export interface YingQiAnalysis {
  description: string;          // 自然语言描述
  factors: string[];            // 推算依据
}

export type LiuQin = '父母' | '兄弟' | '子孙' | '妻财' | '官鬼';
export type WuXing = '金' | '木' | '水' | '火' | '土';
```

### 3.2 卦辞 / 爻辞 数据

`lib/divination/data/gua64.ts`：64 卦的 卦名 / 卦辞 / 卦象 / 上下宫位（基于《周易》传统文本，可参考通行版）

`lib/divination/data/yao384.ts`：384 爻的爻辞（每卦 6 爻，含初/二/三/四/五/上 + 阳爻"九"/阴爻"六"前缀）

`lib/divination/data/liuqin.ts`：六亲分配规则（八宫归属表）

总数据量约 30-40KB JSON，全部静态打包进 bundle，无运行时下载。

### 3.3 起卦算法核心

```
function castSingleYao(): { value: '阴'|'阳'; changing: boolean } {
  // 三币法：每枚硬币正面=2，反面=3
  const sum = [1,2,3].reduce(
    s => s + (Math.random() < 0.5 ? 2 : 3),
    0,
  );
  switch (sum) {
    case 6:  return { value: '阴', changing: true };   // 老阴
    case 7:  return { value: '阳', changing: false };  // 少阳
    case 8:  return { value: '阴', changing: false };  // 少阴
    case 9:  return { value: '阳', changing: true };   // 老阳
    default: throw new Error('unreachable');
  }
}
```

二项分布概率：1/8、3/8、3/8、1/8（与传统三币法一致）。

### 3.4 用神选择规则

| QuestionType | 用神 | 备注 |
|---|---|---|
| `career` | 官鬼 | 工作机会、职位、上司、项目主导权 |
| `wealth` | 妻财 | 钱、收入、投资 |
| `marriage`（女问） | 官鬼 | 配偶 |
| `marriage`（男问） | 妻财 | 配偶 |
| `kids` | 子孙 | 子女、晚辈 |
| `parents` | 父母 | 父母、长辈、契约 |
| `health` | 子孙 | 病情、医疗 |
| `event` | 看 AI 推断 | 由 THINKER 根据问题语境决定 |

`questionType` 留可选，AI 在调用工具时按问题分析自动指定。

---

## 4. AI 工具集成

### 4.1 新工具 `cast_liuyao`

```ts
{
  type: 'function',
  function: {
    name: 'cast_liuyao',
    description: '为单一具体事件起一卦（六爻易经卜卦）。用于"该不该 X / 会不会 Y / X 这件事的结果"等决策类问题。返回主卦+变卦+动爻+用神+应期。',
    parameters: {
      type: 'object',
      properties: {
        question: {
          type: 'string',
          description: '用户的具体问题（用于上下文，不影响起卦数学）',
        },
        questionType: {
          type: 'string',
          enum: ['career', 'wealth', 'marriage', 'kids', 'parents', 'health', 'event', 'general'],
          description: '问题类型，用于选用神。不确定时填 general',
        },
      },
      required: ['question'],
    },
  },
}
```

工具实现：在 `lib/ai/tools/liuyao.ts` 包装 `HexagramEngine.cast()`，返回数据格式与 ADR-2 一致（档 4 全套）。

### 4.2 工具策略追加

`TOOL_STRATEGY` 加一段：

```
6. 单一事件决策类问题（"该不该 X" / "会不会 Y" / "X 这件事的结果"
   / "她回我吗" / "明天面试结果"） → 用 cast_liuyao
7. 长期模式 / 时间节奏 / 性格画像 → 用 get_domain / get_timing / 等
8. user_force_mode=liuyao 时强制走 cast_liuyao；mingli 时禁用 cast_liuyao
```

### 4.3 THINKER_PROMPT 增量

加 ~15 行（详见 §6.1）。

### 4.4 INTERPRETER_PROMPT 增量

加六爻术语黑名单 + 三段式解读结构（详见 §6.2）。

---

## 5. UX 设计

### 5.1 起卦动画（HexagramAnimation 组件）

**视觉概念**：中式古钱币的水墨意象，无 3D 不花哨

时序（总 3 秒）：

```
T = 0.0s：6 条灰虚线（卦位轮廓）淡入

T = 0.5s：初爻位置浮现 3 颗朱砂圆点（铜钱意象，简化为实心圆，无方孔）

T = 0.7s：3 颗圆点合成定型为：
  - 阳爻：实线 ━━━━━━
  - 阴爻：断线 ━━ ━━
  - 动爻：实线/断线 + 旁边小圆点 ●

T = 1.0s 起：自下而上每爻 ~400ms，依次成爻

T = 3.0s：6 爻齐备，下方浮现卦名 "水山蹇 → 水地比"（变卦时显示箭头）
```

**实现**：纯 reanimated，无第三方动画库。fade-in + scale 0.7→1，无 spring 弹跳（保持克制）。

**色彩**：朱砂 (`Colors.vermilion`) + 灰底 (`Colors.bgSecondary`)。

**完成后**：卦象保留在 chat 气泡顶部作为视觉锚，与解读正文 + evidence 卡一起构成完整消息。

### 5.2 静态卦象组件（HexagramDisplay）

非动画版，用于已存历史消息回显：直接渲染 6 横线 + 卦名，无入场动画。

### 5.3 Tool Picker BottomSheet（ModePicker）

```
┌── 切换模式 ──────────────────┐
│                            │
│  随心问                ✓    │
│  AI 自动判断              │
│                            │
│  起一卦                    │
│  带具体问题让我卜一卦      │
│                            │
│  看命盘                    │
│  根据八字 / 紫微解读        │
│                            │
└────────────────────────┘
```

- 复用 `FullReasoningSheet` 的容器样式
- 每行：模式名（朱砂色，加粗）+ 短描述（次墨色）
- 选中态：左侧朱砂细竖线 `│` 替代勾选 emoji
- 点击行后 sheet 自动关闭并切换模式

### 5.4 输入栏改造

```
┌─── input rect（高度自适应增长）─────┐
│ 说说你想问的事...                  │
│                                  │
│                                  │  ← 文字区域往上长
│                                  │
│ [≡]  [起一卦  ✕]            [↑]  │  ← 底部固定行
└──────────────────────────────┘
```

底部行（`flexDirection: 'row'`，黏在输入框底部）：
- 左：`Ionicons.options-outline` 32×32 touchable，点击打开 ModePicker
- 中：ModeChip（仅当 forceMode 非默认时显示）
  - 朱砂背景 + 白字 + ✕ 可清除
  - 内容："起一卦" / "看命盘"（无 emoji）
- 右：发送/停止按钮（既有 SendOrStopButton 不变）

### 5.5 起卦完成后的气泡布局

```
┌─ AI 气泡 ─────────────────────────────┐
│ 岁吉                                  │
│                                      │
│ ┌── HexagramDisplay ──────┐          │
│ │  ━━ ━━                   │          │
│ │  ━━ ━━                   │          │
│ │  ━━ ━━                   │          │
│ │  ━━━━━━ ●                │          │
│ │  ━━━━━━                  │          │
│ │  ━━ ━━                   │          │
│ │  水山蹇 → 水地比          │          │
│ └─────────────────────┘          │
│                                      │
│ 推演过程（CoT 卡，折叠）              │
│                                      │
│ [interpretation 解读正文]            │
│                                      │
│ 推演依据（Evidence 卡，4-6 行）       │
│  动爻：九三                          │
│  用神：官鬼·五爻·旺                  │
│  应期：约 1-2 周                    │
│  ⌄ 查看完整推演                      │
└────────────────────────────────────┘
```

---

## 6. Prompt 工程

### 6.1 THINKER_PROMPT 路由块（追加）

```
# 工具路由

用户消息可能附带 user_force_mode 提示（系统注入）：
- user_force_mode=liuyao → 直接 cast_liuyao(question=用户原问题)，不调命理工具
- user_force_mode=mingli → 只调命理工具，禁用 cast_liuyao

未传 force（默认）时按问题形态判断：
- 单一具体事件决策类（"该不该 X" / "会不会 Y" / "X 这件事的结果"
  / "她回我吗" / "明天面试结果"） → cast_liuyao
- 长期模式 / 时间节奏 / 性格画像 / 关系长期相处 → 命理工具
- 无法分辨 → 默认走命理（命理可拼凑出大致答案，卜卦失效更明显）
```

### 6.2 INTERPRETER_PROMPT 增量

**追加术语黑名单**：

```
（六爻）卦辞、爻辞、动爻、用神、应期、官鬼、子孙、父母、妻财、兄弟、
旺相休囚、世应、月建、日辰、主卦、变卦、爻动……
```

**追加卜卦解读三段结构**（仅卜卦类问题适用）：

```
当推演引擎输出含主卦+变卦时（即卜卦类问题），解读结构遵循：
- 第 1 段：主卦给出的"现状画面"（用形象比喻，不点卦名）
  ✅ "这一卦像走在结冰的山路上 —— 慢、稳、一开始独自挣扎"
  ❌ "你卜得水山蹇"
- 第 2 段：变卦给出的"走向"（"这种状态在松动 / 在过渡到 X"）
  ✅ "这种独自挣扎的状态正在过渡 —— 走到一半会有同行的人出现"
- 第 3 段：如果有动爻，点出"关键节点"（不点"动爻"二字）
  ✅ "看起来这件事的关键节点在未来一两周内会浮现"
- 不下绝对断言（"100% 会"），留余地
```

---

## 7. 数据流

```
user input + forceMode (来自 ModePicker 状态)
  ↓
sendOrchestrated(question, forceMode?)
  ↓
THINKER prompt 注入 "user_force_mode=<mode>" (如有)
  ↓
THINKER 决定调用 cast_liuyao 还是命理工具
  ↓ (若 cast_liuyao)
HexagramEngine.cast() 返回 HexagramReading
  ↓
THINKER 输出推演（基于卦象 + 用神 + 应期）
  ↓
INTERPRETER 写 [interpretation]（档 2 风格）+ [evidence]（动爻/用神/应期）
  ↓
客户端：
  - 流式渲染 [interpretation]
  - 起卦类消息额外渲染 HexagramAnimation（一次性入场）+ HexagramDisplay 持久
  - Evidence 卡渲染卦象数据点
  - BottomSheet 全套档 4 数据
```

---

## 8. 文件结构

### 新增

```
lib/divination/
  HexagramEngine.ts             # 起卦 + 用神 + 应期推算
  types.ts                      # Hexagram / GuaInfo / YongShenAnalysis 等类型
  data/
    gua64.ts                    # 64 卦卦辞 + 卦象 + 上下宫
    yao384.ts                   # 384 爻爻辞
    liuqin.ts                   # 八宫六亲分配表
  __tests__/
    HexagramEngine.test.ts      # 5-6 个单测：6 爻分布概率、用神选择、应期描述

lib/ai/tools/
  liuyao.ts                     # cast_liuyao 工具实现（包装 HexagramEngine）
  __tests__/liuyao.test.ts      # 工具单测

components/divination/
  HexagramAnimation.tsx         # 起卦动效（3 秒入场）
  HexagramDisplay.tsx           # 静态卦象组件（已存消息回显）

components/chat/
  ModePicker.tsx                # 模式选择 BottomSheet
  ModeChip.tsx                  # 输入框底部当前模式 chip
```

### 修改

```
lib/ai/index.ts                 # THINKER_PROMPT 加路由块；INTERPRETER_PROMPT 加六爻术语黑名单 + 三段结构
lib/ai/tools/index.ts           # ALL_TOOLS / ALL_HANDLERS 加 cast_liuyao；TOOL_STRATEGY 加路由策略
lib/ai/chat.ts                  # SendOrchestratedOptions 加 forceMode?: 'liuyao' | 'mingli'
                                # sendOrchestrated 把 forceMode 注入 thinker system message
lib/store/chatStore.ts          # ChatMessage 持久化扩展支持 hexagram 字段（如有 cast 数据）
lib/ai/index.ts ChatMessage     # 给 assistant 消息加 hexagram?: HexagramReading 可选字段
app/(tabs)/insight.tsx          # 引入 ModePicker / ModeChip，输入栏底部加 sliders icon
                                # 起卦类消息渲染 HexagramAnimation + HexagramDisplay
components/ai/EvidenceCard.tsx  # 卜卦类 evidence 渲染（结构与命理一致，文字内容不同）

# emoji 清理（ADR-6）
components/ai/CoTCard.tsx       # 移除 🧠 / 📌 等装饰 emoji
components/ai/EvidenceCard.tsx  # 移除 🔍
components/ai/FullReasoningSheet.tsx  # 移除 📌
app/(tabs)/insight.tsx          # narrateTool() 内部所有 emoji 移除（保留古风文字）
```

---

## 9. 测试策略

### 9.1 单元测试

| 模块 | 测试目标 |
|---|---|
| `HexagramEngine.cast()` | 6 个测试：6 爻输出阴/阳/动符合期望、概率分布大致 1:3:3:1、用神选择按 questionType 正确、卦辞 / 爻辞文本能正确查表、应期描述非空 |
| `lib/ai/tools/liuyao.ts` | 4 个测试：工具签名包含 cast_liuyao、handler 接收 question 返回 HexagramReading、错误参数兜底、与 ALL_TOOLS 注册一致 |
| `HexagramAnimation` | 不写单测（presentation 组件） |

### 9.2 集成 / 设备测试

测试矩阵：

| 用户操作 | 期望 |
|---|---|
| 输入"我应该接 X offer 吗"（默认模式） | AI 自动选 cast_liuyao，看到 3 秒起卦动画，evidence 含动爻/用神/应期 |
| 切换"起一卦"模式后输入"我下个月会怎样" | 强制 cast_liuyao，即便问题偏长期 |
| 切换"看命盘"模式输入"她下周会回我吗" | 强制走命理，不调 cast_liuyao |
| 发送一条消息后 ModeChip 自动消失 | 模式重置生效 |
| 已存消息历史里的卜卦消息 | 用 HexagramDisplay 静态渲染，不重放动画 |
| BottomSheet 完整推演中显示用神 / 应期 / 六亲 | 档 4 数据齐备 |

---

## 10. 已知风险与回退方案

### R1：六爻数据 (gua64 + yao384) 文本是否准确

**风险**：错误的卦辞 / 爻辞文本会让懂行的用户立刻发现"假货感"。

**缓解**：
- 数据基于通行版《周易》文本（可参考标点本或网络高质量来源）
- 在 `__tests__/HexagramEngine.test.ts` 加 5 个 fixture 案例：固定卦号 → 验证卦名 + 卦辞首句正确
- 风险升级时（用户报错）单点修复某条数据即可

### R2：用神选择 / 应期推算逻辑过简

**风险**：传统六爻有大量细则（六亲变化、世应、伏神、空亡），简化版可能让答案偏离传统。

**缓解**：
- Phase 2 接受简化（只看用神是否旺、是否动、临何爻）
- 应期描述用模糊语言（"约 1-2 周"而非"X 月 X 日"）避免精确度欺诈
- Phase 3 起重新审视，必要时加复杂规则

### R3：AI 路由错误（模糊问题误判）

**风险**：默认模式下 AI 把命理问题当卜卦或反过来。

**缓解**：
- 用户可通过 ModePicker 强制纠正
- THINKER prompt 里给 4-5 条 ✅/❌ 例子帮助分类
- 模糊时优先命理（命理可给"概貌"答案，比错误起卦体感更稳）

### R4：动画在低端设备上掉帧

**风险**：reanimated worklet 在老 iPhone 上可能掉帧导致动画看起来卡顿。

**缓解**：
- 动画用 fade + scale 不用 transform 复杂变换
- 动画逻辑是 6 个独立 timing 而非每帧重计算
- 首次冒烟测试在用户的 iPhone 16 Plus 上跑通即可作为基准

### R5：起卦动画播放重复 / 历史消息触发动画

**风险**：返回 chat 后历史消息的卦象重新播一遍动画。

**缓解**：
- 动画组件 `HexagramAnimation` 只在**当前正在生成的消息**渲染
- 已存消息（`msg.hexagram` 存在）走 `HexagramDisplay`（静态版本），不带动画

---

## 11. 与既往 spec 的关系

### 与 `2026-04-25-ai-orchestration-and-divination-systems-design.md` 的关系

- 复用 Phase 1 的所有架构：tool-use orchestrator、双角色 prompt、preprocessOrchestration、CoT/Evidence/BottomSheet 三组件、流式光标
- 新增能力 = 加一个工具 + 加一个动画组件 + 加 ModePicker；架构核心不变
- ADR-6（去 emoji）是 Phase 2 的横切决策，回头清理 Phase 1 的装饰 emoji，让全 app 视觉调性一致

### Phase 3 / 4 接口预留

- ModePicker 已内置 3 个模式；Phase 3 加奇门时变成 4 个模式（"问决策" 切到奇门）
- HexagramEngine 模块化结构（types / data / engine 分离）是 Phase 3 奇门的预演（QimenEngine 同结构）
- 全套档 4 数据预留了"用户成长后想看更深"的扩展空间（Phase 4 可以做"卦象详情页"展示用神交互、伏神、空亡等）

---

## 12. 不在本 spec 范围

- 卜卦历史回顾页面（"我以往卜过什么卦"）—— Phase 4
- 多人合卦 / 替他人卜（"我帮我妈卜一卦"）—— 暂不做
- 实物摇币集成（设备摇晃触发起卦）—— 噱头大于实用
- AI 反问"你这个问题适合卜卦吗" —— ADR-3 已否决（D 选项）
- 卦象图的 SVG 美化版本（书法笔触感、纸纹）—— Phase 2 用极简版本，Phase 4 可升级
- Pro 订阅 / 付费墙
