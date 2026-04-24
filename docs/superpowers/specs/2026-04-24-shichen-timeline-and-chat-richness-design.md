# 设计文档：时辰能量轴 + 问道对话富化

**日期**：2026-04-24
**范围**：3 个互相独立但共享 codebase 的小改进，打包进一份 spec 一次实施。

## 背景

实机跑通 TestFlight/自签 Release 后，用户在日常使用中发现 3 个体验问题：

1. **首页的"十二时辰"方格**没有交互、含义不清，用户看不出价值。
2. **问道页面的 AI 回复完全没有流式输出**，用户需要等整段回复 fetch 完才能看到。
3. **问道页面的 AI 回复是纯文本**，markdown 标记（`##`、`**`、`-` 等）原样显示，视觉单调，缺少"岁吉"该有的质感。

3 项改进都在 **首页 tab** 和 **问道 tab** 两个现存视图里，相关性强，适合一份 spec。

## 目标

- **首页**：用"时辰能量轴"替代现有 12 时辰格子，横向滑动 + 个性化内容 + 易懂 + 诗意。
- **问道**：让流式真正工作，并在流式和最终结果里渲染一套风格统一、带结构化卡片的富文本。

## 非目标

- 重构整个日历页/问道页。
- 引入新的 AI provider 或改 system prompt。
- 把"宜/忌/古文"等结构化内容**强制写进 AI 的输出格式**（即不走 prompt engineering 的结构化标签方案，避免 AI 不听话导致的 UX 退化）。
- 个性化的"通用无命盘版本"时辰轴——本 spec 下，用户未配生辰时**不显示**时辰轴。

---

## 模块 1：时辰能量轴

### 展示逻辑

- **门槛**：只有 `store.mingPanCache` 有值时渲染。
- **未配生辰**：首页这个位置不出现占位，保留现有"今日格言 + 运势卡"即可。

### 布局

横向滚动列表（`FlatList` 或 `ScrollView`，取决于 perf 实测），12 张卡并列。

**普通卡**（约 110×150pt）：

```
   寅
  03–05
 ─────
  苏醒
  万物萌动
 ─────
    平
  宜 · 静思
```

内容顺序：
1. 地支大字（Georgia 36pt，墨色）
2. 时间范围（caption，墨次色）
3. 细分隔线
4. **两字意象**（20pt，墨色）
5. **诗化描述**（≤8 字，bodySmall，墨次色）
6. 细分隔线
7. **能量档位**：`旺 / 平 / 弱`，前面一个彩色小圆点（青瓷 / 灰 / 朱砂）
8. **宜 · [动词短语]**（朱砂色）

**当前时辰卡**（约 130×170pt）：
- 字号整体放大 ~15%
- 背景从 `Colors.surface` → `Colors.brandBg`
- 卡顶部一个朱砂 5pt 小三角，表示"当下"

### 个性化算法

每张卡的"能量档位"与"宜"动态计算。其余字段（地支、时间、意象、诗）静态。

**静态基底** `SHICHEN_MAP`（新文件 `lib/calendar/shichen.ts`）：

```ts
type ShichenEntry = {
  zhi: DiZhi;                    // 子/丑/寅…
  hours: string;                  // "23–01"
  image: string;                  // 意象，两字
  poem: string;                   // 诗句，≤8 字
  generalWuXing: WuXing;         // 本时辰主属性，用于对比喜忌
  defaultSuitable: string;        // "静思" / "筹划" …
};

const SHICHEN_MAP: ShichenEntry[] = [
  { zhi: '子', hours: '23–01', image: '夜藏', poem: '万物归元',  generalWuXing: '水', defaultSuitable: '入眠' },
  { zhi: '丑', hours: '01–03', image: '沉静', poem: '土凝寒气',  generalWuXing: '土', defaultSuitable: '深睡' },
  { zhi: '寅', hours: '03–05', image: '苏醒', poem: '万物萌动',  generalWuXing: '木', defaultSuitable: '静思' },
  { zhi: '卯', hours: '05–07', image: '日出', poem: '生气勃发',  generalWuXing: '木', defaultSuitable: '晨起' },
  { zhi: '辰', hours: '07–09', image: '勤奋', poem: '日精正升',  generalWuXing: '土', defaultSuitable: '专注' },
  { zhi: '巳', hours: '09–11', image: '昂扬', poem: '阳气渐盛',  generalWuXing: '火', defaultSuitable: '行动' },
  { zhi: '午', hours: '11–13', image: '鼎沸', poem: '阳极将衰',  generalWuXing: '火', defaultSuitable: '休整' },
  { zhi: '未', hours: '13–15', image: '和缓', poem: '土厚载物',  generalWuXing: '土', defaultSuitable: '沟通' },
  { zhi: '申', hours: '15–17', image: '收敛', poem: '金气渐锋',  generalWuXing: '金', defaultSuitable: '决断' },
  { zhi: '酉', hours: '17–19', image: '归栖', poem: '日落金收',  generalWuXing: '金', defaultSuitable: '复盘' },
  { zhi: '戌', hours: '19–21', image: '安宁', poem: '暮土藏火',  generalWuXing: '土', defaultSuitable: '陪伴' },
  { zhi: '亥', hours: '21–23', image: '归藏', poem: '水润归源',  generalWuXing: '水', defaultSuitable: '静读' },
];
```

**个性化叠加** `computeShichenVibe(zhi, mingPan)`：

| 条件 | 能量档位 | 宜（动词短语） |
|---|---|---|
| `entry.generalWuXing === yongShen` | 旺 | 强动词：行动 / 开启 / 进取 / 谈判 |
| `entry.generalWuXing === xiShen` | 旺 | 平动词：沟通 / 书写 / 学习 |
| `entry.generalWuXing === jiShen` | 弱 | 收敛动词：静心 / 休整 / 独处 |
| 其他 | 平 | 用 `entry.defaultSuitable` |

动词短语从每类 4–6 个候选里按 `dayOfYear(date) % N`（dayOfYear 的计算已在 `lib/bazi/TrueSolarTime.ts` 有实现，可复用/抽取到共享工具）选，做到**同一天稳定、跨日有变化**，避免每次重渲染都跳。

### 交互

- **自动定位**：页面 mount 时 `scrollToIndex(currentShichenIndex)`，并把当前时辰卡**居中**（通过 `contentOffset` + 卡宽计算）。
- **点击任一卡** → 弹出**底部半屏 Modal（slide up）**：
  - 大标题：`寅时 · 03:00–05:00`
  - 意象和诗（放大显示）
  - 长解读正文（80–120 字）：静态文案，把意象、诗、能量、宜/忌展开叙述
  - 如命盘存在 → 额外"对你来说"段落（个性化）
  - 底部关闭按钮

### 文件变动

- 新：`components/calendar/ShichenTimeline.tsx` —— 主组件，内部判断 `mingPanCache`
- 新：`components/calendar/ShichenCard.tsx` —— 单卡
- 新：`components/calendar/ShichenDetailSheet.tsx` —— 详情抽屉
- 新：`lib/calendar/shichen.ts` —— `SHICHEN_MAP` 常量 + `computeShichenVibe()`
- 改：`app/(tabs)/index.tsx` —— 删除 142–174 行的 `hoursArea` 块及相关 styles，替换为 `<ShichenTimeline />`

### 新增依赖

无。

---

## 模块 2：Chat 流式 + 停止键

### 根因修复

`lib/ai/chat.ts` 的三个 `stream*` 函数里用 `response.body?.getReader()` 读 SSE。React Native 的原生 fetch 对 `ReadableStream` 支持不稳（在 Hermes + RN 0.81 上表现会直接抛错或 body 为 undefined），所以当前代码在外层 `try/catch` 里被静默降级成 `fetchNonStream`。

**方案**：改用 `expo/fetch`（随 Expo SDK 54 内置，不需装新包）。它的 response 有可靠的 stream。

```ts
import { fetch as expoFetch } from 'expo/fetch';
```

`streamOpenAI / streamResponsesAPI / streamAnthropic` 三个生成器中的 `fetch()` 调用全部替换为 `expoFetch()`。`fetchNonStream` 作为**硬错误兜底**保留。

### AbortController 支持

`sendChat` 签名扩展：

```ts
export async function sendChat(
  messages: ChatMessage[],
  config: ChatConfig,
  mingPanJson: string | null,
  onChunk?: (chunk: string) => void,
  signal?: AbortSignal,        // 新增
): Promise<string>
```

`signal` 透传给所有 `expoFetch` 调用。被 abort 时抛的 `AbortError` 在 `sendChat` 内部捕获，**返回当时已累积的 `fullText`**（不是抛错），这样调用者能把已流出的文本落盘成正式消息。

### UI 行为

#### 流式光标

流式中的 AI 气泡末尾追加一个 `<StreamCursor />`：一个 `▍` 字符，用 reanimated 做 500ms 透明度在 1.0 ↔ 0.2 间脉冲。流式结束、`assistantMsg` 定型那一刻，该组件不再挂载。

#### 发送键 ↔ 停止键

现有 `SendButton` 改造为 `SendOrStopButton`，三态：

| 状态 | 外观 | 行为 |
|---|---|---|
| `idle + 有输入` | 朱砂圆 · ↑ | 发送 |
| `idle + 无输入` | 灰色圆 · ↑ 禁用 | — |
| `streaming` | 墨色圆 · ⏹ 可点 | `abortController.abort()` |

点停止后：
1. `abortController.abort()` 触发
2. `sendChat` 捕获 `AbortError` → 返回当前 `fullText`
3. 调用侧把这段文本以 assistantMsg 正式落盘
4. `loading = false`，光标消失，按钮切回 idle

#### Markdown 实时渲染

流式 `streamingText` 和定型的 `msg.content` **走同一个 `<RichContent>` 组件**（见模块 3）。流式过程中出现的半行 `##` 或 `*` 会被 markdown 渲染器当作普通文本短暂渲染，等配对符号到达再重新识别为结构元素。这个中间态抖动是**刻意接受的折中**。

### 文件变动

- 改：`lib/ai/chat.ts`
  - `import { fetch as expoFetch } from 'expo/fetch'`
  - 三个 stream 函数内部的 `fetch` 换成 `expoFetch`
  - `sendChat` 加 `signal?: AbortSignal` 参数，透传给所有 fetch
  - `sendChat` 捕获 `AbortError` 返回已累积文本
- 改：`app/(tabs)/insight.tsx`
  - `useRef<AbortController | null>(null)` 存当前流
  - 发送时 `new AbortController()`，传给 `sendChat`
  - 流式气泡末尾挂 `<StreamCursor />`
  - `SendButton` → `SendOrStopButton`（新组件或原地改造）
- 新：`components/ai/StreamCursor.tsx`

### 新增依赖

无。`expo/fetch` 随 SDK 54 自带，`reanimated` 已在依赖中。

---

## 模块 3：富文本输出

### 渲染管道

引入 `@ronradtke/react-native-markdown-display`（社区维护的 markdown-display fork，兼容 RN 0.81 + New Architecture）作为底层渲染器。其 `rules` 和 `styles` API 允许我们逐元素定制样式 + 插入自定义组件规则。

**主入口组件** `<RichContent content={string} />` —— 所有需要渲染 AI 文本的地方都用它：
- 问道聊天气泡的 `msg.content`
- 流式中间态 `streamingText`
- 未来八字 insight / 婚配 insight 里的 AI 段落（留接口，本 spec 不改）

### 第 1 层：Markdown 元素 → Design Tokens

所有样式集中在 `components/ai/richStyles.ts`：

| Markdown | 样式 |
|---|---|
| `# H1` | Georgia 28pt · `Colors.ink` · 上 Space.lg 下 Space.md |
| `## H2` | Georgia 22pt · `Colors.ink` · 上 Space.md |
| `### H3` | Georgia 18pt · `Colors.ink` · weight 500 |
| `**bold**` | `Colors.vermilion` · weight 600 |
| `*italic*` | `Colors.inkSecondary` · italic |
| `- list` | bullet 换成 `│`（朱砂） |
| `1. list` | 序号用 Georgia 衬线 |
| `> blockquote` | 基础版：`Colors.brandBg` 背景 + 左朱砂 2pt 线 + Space.base 缩进 |
| `---` | 两端渐淡的 1pt 朱砂线 |
| paragraph | lineHeight 28 · 段间 Space.md |
| `code` / `pre` | 暂不特殊处理，沿用库默认 |

`Type` / `Colors` / `Space` / `Radius` / `Shadow` 全部来自现有 `lib/design/tokens`。

### 第 2 层：结构化卡片（custom rules）

#### 宜 / 忌 双栏卡

**触发模式**（正则）：

```
^(\*\*)?宜(\*\*)?[：:]\s*(.+)$
^(\*\*)?忌(\*\*)?[：:]\s*(.+)$
```

两行**连续**出现（允许中间有空行）时匹配。单独出现的"宜"或"忌"**不触发**（降级为普通段落）。

**预处理**（`preprocessYiji.ts`）：扫描原文字符串，命中配对则把这两行整体替换为一个自定义 token：

```
::yiji
yi: 静心、写字、整理
ji: 争执、远行
::
```

再送给 markdown-display。fence 规则识别 `::yiji`，返回 `<YiJiCard yi={[...]} ji={[...]} />`。

**渲染**：横向双栏，左栏 `Colors.celadon` 系（青瓷）、右栏 `Colors.vermilion` 系，项目用顿号/逗号分词，每项一个 chip。

#### 古文引用

**触发**：所有 markdown blockquote（`> ...`）都走升级样式。正文里**尾部**出现 `——\s*(.+)$` 或 `《(.+)》` 时，额外解析为落款。

**渲染**：`<ClassicalQuote>`
- `Colors.brandBg` 背景 + `Shadow.sm`
- 正文 Georgia 16pt · 墨色 · 行距放松
- 有落款 → 右下角小字 + 上方 1pt 渐淡细线

#### 命盘关键词徽章

**词典**（`keywords.ts`）：
- 十神：`日主 正官 七杀 正印 偏印 正财 偏财 食神 伤官 比肩 劫财`
- 命理：`用神 喜神 忌神 格局`
- 五行（只在**前后是中文标点或空格**时匹配，避免误中"金色""水果"等）：`木 火 土 金 水`

**实现**：markdown-display 的 `textgroup` 规则里，对每个 text node 跑一次正则扫描，把匹配的词拆出成 inline `<MingPanBadge>`。

**渲染**：小号（bodySmall）· `Colors.brandBg` 背景 · `Colors.vermilion` 文字 · 2pt 圆角 · inline 行高不突破段落基线。

### 检测顺序

```
原文 string
  ↓ preprocessYiji：宜/忌 配对 → ::yiji fence token
  ↓ markdown-display 解析为 AST
  ↓ rules：
    - fence(::yiji)  → <YiJiCard>
    - blockquote     → <ClassicalQuote>（内部解析落款）
    - textgroup      → 扫描命盘关键词 → <MingPanBadge>
    - 其他元素        → 按 richStyles.ts 的样式渲染
```

规则互不冲突，因为前置扫描只动配对的宜/忌两行，其余 markdown 正常走 AST。

### 流式兼容性

- 半行 `##` 或 `**foo` → markdown-display 按 raw text 渲染，不崩
- 宜/忌只在**配对出现时**才触发卡片，半途中途不会过早渲染
- blockquote 行增长时会逐行扩展，视觉顺畅

### 文件变动

- 新：`components/ai/RichContent.tsx`（主入口）
- 新：`components/ai/richStyles.ts`（元素样式映射）
- 新：`components/ai/customRules/preprocessYiji.ts`（前置扫描）
- 新：`components/ai/customRules/YiJiCard.tsx`
- 新：`components/ai/customRules/ClassicalQuote.tsx`
- 新：`components/ai/customRules/MingPanBadge.tsx`
- 新：`components/ai/customRules/keywords.ts`
- 改：`app/(tabs)/insight.tsx`
  - AI 气泡 `<Text>{msg.content}</Text>` → `<RichContent content={msg.content} />`
  - 流式气泡同上

### 新增依赖

```
npm i @ronradtke/react-native-markdown-display
```

---

## 测试策略

- **模块 1**：
  - Unit：`computeShichenVibe()` 对 5 种用神/忌神组合返回正确档位 + 动词类别
  - 手测：配过生辰的用户看到个性化时辰轴；未配用户看不到
  - 手测：当前时辰卡自动居中、样式放大
  - 手测：点击任意卡 → 抽屉弹出，内容正确

- **模块 2**：
  - 手测：OpenAI provider 流式真正逐 token 到达（看光标跟着跳）
  - 手测：Anthropic provider 同上
  - 手测：Responses API (Azure Foundry / GPT-5) 同上
  - 手测：流式中点停止键 → 已到达的文本保留成正式消息
  - 手测：流式中后台切换、锁屏再回来不崩溃

- **模块 3**：
  - Unit：`preprocessYiji` 对几种配对/单出现/夹空行的 case 返回正确 token
  - Unit：命盘关键词词典扫描不误中"金色""水果"等假阳性
  - 手测：给 AI 故意让它输出带 `##` / `**` / `宜:/忌:` / `> 引用 —— xxx` 的一段，看渲染效果
  - 手测：流式过程中半行 markdown 不崩

## 实施顺序建议（给下一步的 plan 参考）

1. **模块 2 的根因修复**（换 `expo/fetch`） —— 最高优先级，用户感知最强，实现最快
2. **模块 3**（markdown 基础层 + 富样式）—— 让流式看起来也漂亮
3. **模块 3 的结构化卡片**（yiji / classicalQuote / mingPanBadge）—— 锦上添花
4. **模块 1 的时辰轴** —— 独立工作量最大，但不紧急

## 开放问题

- `@ronradtke/react-native-markdown-display` 在 RN 0.81 + New Architecture 下的实测兼容性 —— 需要在 plan 的第一个 checkpoint 验证；若不兼容，备选 `react-native-marked`（使用 `marked` 解析器 + 自己的 renderer），写法类似但 API 不同。
- 宜/忌正则的健壮性 —— AI 偶尔会写"宜：xxx；忌：yyy"合为一行；spec 规定必须两行。如果 AI 输出一行式，降级为普通段落渲染，不算 bug。
